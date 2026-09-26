--[[
	AudioController (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/AudioController

	THE client audio engine (AudioService on the server only tells clients
	what to play). Everything audible goes through Play / StartLoop.

	  * MIXER    SoundService.Master > Music, Ambience, EquipmentSFX, PlayerSFX,
	             AnomalySFX, Jumpscares, Voice, UI (static SoundGroups in the
	             place file; created here if missing) scaled by the player's
	             volume settings.
	  * PRELOAD  every asset (uploaded ids, banks, loop files, built-in
	             fallbacks) is preloaded with ContentProvider. Failures are
	             reported ("[AudioService] Failed sound: Camera.Shutter") and the
	             sound switches to its next source (SoundResolver).
	  * VERIFY   a sound that does not load within a few seconds at runtime is
	             marked failed and replayed from its fallback.
	  * 3D       positional sounds with InverseTapered roll-off, muffled through
	             walls (occlusion); 2D sounds live in SoundService.
	  * WORLD    WorldSound messages from the server, tagged "LoopSound" parts,
	             zone reverb + ambience beds, and the SILENCE RULE (music and
	             ambience fade out when something dangerous is close).
	  * DEBUG    GetDiagnostics / PrintReport / TestSequence (Settings > Audio,
	             admin /soundtest).
]]

local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local SoundConfig = require(Config:WaitForChild("SoundConfig"))
local GameConfig = require(Config:WaitForChild("GameConfig"))
local MapConfig = require(Config:WaitForChild("MapConfig"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local SoundResolver = require(Modules:WaitForChild("SoundResolver"))
local Net = require(Modules:WaitForChild("Net"))

local AudioController = {}
AudioController.Groups = {} :: { [string]: SoundGroup }
AudioController.Loops = {}
AudioController.Beds = {}
AudioController.Duck = { Music = 1, Ambience = 1 }
AudioController.Warned = {} :: { [string]: boolean }
AudioController.Preloaded = false

local LOAD_TIMEOUT = 4

local function warnOnce(self, key: string, message: string)
	if not self.Warned[key] then
		self.Warned[key] = true
		warn(message)
	end
end

function AudioController:Init(controllers)
	self.Controllers = controllers
	self:_setupGroups()
	local twoD = SoundService:FindFirstChild("COC_2D")
	if not twoD then
		twoD = Instance.new("Folder")
		twoD.Name = "COC_2D"
		twoD.Parent = SoundService
	end
	self.TwoD = twoD

	self.OcclusionParams = RaycastParams.new()
	self.OcclusionParams.FilterType = Enum.RaycastFilterType.Exclude
	controllers.UIKit.ButtonSound = function()
		self:Play("UI.Button", nil)
	end

	local state = controllers.ClientState
	state.DataChanged:Connect(function()
		self:ApplyVolumes()
	end)
	self:ApplyVolumes()

	Net.Event("WorldSound").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			self:_onWorldSound(payload)
		end
	end)
end

-- The mixer lives in SoundService (default.project.json). Missing groups are
-- created so a hand-edited place can never break audio.
function AudioController:_setupGroups()
	local master = SoundService:FindFirstChild("Master")
	if not master or not master:IsA("SoundGroup") then
		warn("[AudioService] SoundService.Master SoundGroup missing - creating the mixer at runtime")
		local created = Instance.new("SoundGroup")
		created.Name = "Master"
		created.Parent = SoundService
		master = created
	end
	self.Groups.Master = master :: SoundGroup
	for _, name in ipairs(SoundConfig.GroupOrder) do
		if name ~= "Master" then
			local group = (master :: Instance):FindFirstChild(name)
			if not group or not group:IsA("SoundGroup") then
				local created = Instance.new("SoundGroup")
				created.Name = name
				created.Parent = master
				group = created
			end
			self.Groups[name] = group :: SoundGroup
		end
	end
end

function AudioController:Start()
	for _, instance in ipairs(CollectionService:GetTagged("LoopSound")) do
		self:_attachLoop(instance)
	end
	CollectionService:GetInstanceAddedSignal("LoopSound"):Connect(function(instance)
		self:_attachLoop(instance)
	end)
	CollectionService:GetInstanceRemovedSignal("LoopSound"):Connect(function(instance)
		self:_detachLoop(instance)
	end)

	-- mute Roblox's default plastic footsteps (FootstepController plays material steps)
	local function muteDefaults(character: Model)
		local function mute(descendant: Instance)
			if descendant:IsA("Sound") and (descendant.Name == "Running" or descendant.Name == "Landing") then
				descendant.Volume = 0
				descendant:GetPropertyChangedSignal("Volume"):Connect(function()
					if descendant.Volume ~= 0 then
						descendant.Volume = 0
					end
				end)
			end
		end
		for _, descendant in ipairs(character:GetDescendants()) do
			mute(descendant)
		end
		character.DescendantAdded:Connect(mute)
	end
	local function watchPlayer(other: Player)
		other.CharacterAdded:Connect(muteDefaults)
		if other.Character then
			muteDefaults(other.Character)
		end
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, other in ipairs(Players:GetPlayers()) do
		watchPlayer(other)
	end

	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				self:_updateAcoustics()
			end)
			if not ok then
				warn("[AudioService]", err)
			end
			task.wait(0.5)
		end
	end)
end

---------------------------------------------------------------------------
-- Preloading + diagnostics
---------------------------------------------------------------------------

function AudioController:PreloadAll()
	if self.Preloaded then
		return
	end
	self.Preloaded = true
	local users: { [string]: { string } } = {}
	for _, path in ipairs(SoundConfig.AllPaths()) do
		for _, candidate in ipairs(SoundResolver.Candidates(path)) do
			users[candidate.Id] = users[candidate.Id] or {}
			table.insert(users[candidate.Id], path)
		end
	end
	local sounds = {}
	for id in pairs(users) do
		local sound = Instance.new("Sound")
		sound.SoundId = id
		table.insert(sounds, sound)
	end
	local ok, err = pcall(function()
		ContentProvider:PreloadAsync(sounds, function(contentId: string, status: Enum.AssetFetchStatus)
			if status == Enum.AssetFetchStatus.Failure then
				SoundResolver.MarkFailed(contentId)
				local paths = users[contentId] or {}
				warn(string.format("[AudioService] Failed sound asset %s (used by %d sound(s), e.g. %s) - switching to fallbacks", contentId, #paths, paths[1] or "?"))
			end
		end)
	end)
	if not ok then
		warn("[AudioService] Preload error:", err)
	end
	for _, sound in ipairs(sounds) do
		sound:Destroy()
	end
	local report = self:GetDiagnostics()
	if report.BanksMissing > 0 then
		print(string.format("[AudioService] %d sounds ready (%d from uploads, %d built-in fallbacks). %d sound bank(s) not uploaded yet - see docs/AUDIO.md", report.Loaded + report.Fallback, report.Loaded, report.Fallback, report.BanksMissing))
	else
		print(string.format("[AudioService] %d sounds ready from the uploaded banks", report.Loaded))
	end
	if report.Failed > 0 then
		warn(string.format("[AudioService] %d sound(s) have NO playable source: %s", report.Failed, table.concat(report.FailedPaths, ", ")))
	end
end

function AudioController:GetDiagnostics()
	local report = { Loaded = 0, Fallback = 0, Failed = 0, FailedPaths = {}, BanksMissing = 0, Sources = {} }
	for bank in pairs(SoundConfig.Banks) do
		if not SoundResolver.GetBankId(bank) then
			report.BanksMissing += 1
		end
	end
	for _, path in ipairs(SoundConfig.AllPaths()) do
		local resolved = SoundResolver.Resolve(path)
		if not resolved then
			report.Failed += 1
			table.insert(report.FailedPaths, path)
			report.Sources[path] = "NONE"
		elseif resolved.Source == "Fallback" then
			report.Fallback += 1
			report.Sources[path] = "Fallback"
		else
			report.Loaded += 1
			report.Sources[path] = resolved.Source
		end
	end
	return report
end

function AudioController:PrintReport()
	local report = self:GetDiagnostics()
	print("[AudioService] ===== AUDIO REPORT =====")
	for bank in pairs(SoundConfig.Banks) do
		local id = SoundResolver.GetBankId(bank)
		print(string.format("  bank %-9s %s%s", bank, id or "NOT UPLOADED", if id and SoundResolver.IsFailed(id) then "  (FAILED TO LOAD)" else ""))
	end
	for name, group in pairs(self.Groups) do
		print(string.format("  group %-12s volume %.2f", name, group.Volume))
	end
	local paths = SoundConfig.AllPaths()
	for _, path in ipairs(paths) do
		local source = report.Sources[path]
		if source ~= "Bank" and source ~= "Ids" and source ~= "Loop" then
			print(string.format("  %-34s %s", path, source))
		end
	end
	print(string.format("[AudioService] %d from uploads, %d fallbacks, %d with no source", report.Loaded, report.Fallback, report.Failed))
end

-- Plays one sound from every family, in order, right where you stand.
function AudioController:TestSequence()
	local sequence = {
		"UI.Button",
		"Camera.Shutter",
		"Camera.FlashTrigger",
		"Flashlight.On",
		"EMF.Level3",
		"Player.Footstep.Concrete",
		"Door.Wood.Open",
		"Anomaly.Whisper",
		"Jumpscare.Impact",
	}
	task.spawn(function()
		local camera = Workspace.CurrentCamera
		for _, path in ipairs(sequence) do
			local where = if camera then camera.CFrame * CFrame.new(2, 0, -4) else nil
			local sound = self:Play(path, if where then where.Position else nil, { NoOcclusion = true })
			print(string.format("[AudioService] test %-26s %s", path, if sound then "playing (" .. sound.SoundId .. ")" else "FAILED"))
			task.wait(0.7)
		end
	end)
end

---------------------------------------------------------------------------
-- Mixer
---------------------------------------------------------------------------

function AudioController:ApplyVolumes()
	local state = self.Controllers.ClientState
	for name, group in pairs(self.Groups) do
		local def = SoundConfig.Groups[name]
		if not def then
			continue
		end
		local volume = def.Volume
		if def.Setting then
			local value = state:GetSetting(def.Setting)
			if type(value) == "number" then
				volume *= value
			end
		end
		if self.Duck[name] then
			volume *= self.Duck[name]
		end
		if name == "Ambience" and state:GetSetting("Ambience") == false then
			volume = 0
		end
		group.Volume = volume
	end
end

function AudioController:SetDuck(groupName: string, value: number, time: number)
	self.DuckTargets = self.DuckTargets or {}
	self.DuckTweens = self.DuckTweens or {}
	if self.DuckTargets[groupName] == value then
		return
	end
	self.DuckTargets[groupName] = value
	local previous = self.DuckTweens[groupName]
	if previous then
		previous:Cancel()
	end
	local holder = Instance.new("NumberValue")
	holder.Value = self.Duck[groupName] or 1
	holder.Changed:Connect(function(current)
		self.Duck[groupName] = current
		self:ApplyVolumes()
	end)
	local tween = TweenService:Create(holder, TweenInfo.new(time, Enum.EasingStyle.Sine), { Value = value })
	self.DuckTweens[groupName] = tween
	tween.Completed:Once(function()
		holder:Destroy()
	end)
	tween:Play()
end

---------------------------------------------------------------------------
-- Playback
---------------------------------------------------------------------------

function AudioController:CountWalls(position: Vector3): number
	local camera = Workspace.CurrentCamera
	if not camera then
		return 0
	end
	local exclude: { Instance } = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	for _, name in ipairs({ "ActiveAnomalies", "Decoys" }) do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			table.insert(exclude, folder)
		end
	end
	table.insert(exclude, camera)
	self.OcclusionParams.FilterDescendantsInstances = exclude
	local origin = camera.CFrame.Position
	local walls = 0
	for _ = 1, 2 do
		local remaining = position - origin
		if remaining.Magnitude < 1 then
			break
		end
		local result = Workspace:Raycast(origin, remaining, self.OcclusionParams)
		if not result then
			break
		end
		if result.Instance.Transparency < 0.5 then
			walls += 1
		end
		origin = result.Position + remaining.Unit * 0.6
	end
	return walls
end

export type PlayOptions = {
	Volume: number?,
	Speed: number?,
	Variation: number?,
	Looped: boolean?,
	NoOcclusion: boolean?,
	Retry: boolean?,
}

local function cleanupSound(sound: Sound, anchor: Instance?)
	if anchor then
		anchor:Destroy()
	elseif sound.Parent then
		sound:Destroy()
	end
end

-- where: nil (2D) | Vector3 | BasePart | Attachment
function AudioController:Play(path: string, where: any, options: PlayOptions?): Sound?
	local opts: PlayOptions = options or {}
	local entry = SoundConfig.Get(path)
	if not entry then
		warnOnce(self, "unknown:" .. path, "[AudioService] Unknown sound path: " .. tostring(path))
		return nil
	end
	local resolved = SoundResolver.Resolve(path, opts.Variation)
	if not resolved then
		warnOnce(self, "nosource:" .. path, "[AudioService] Failed sound: " .. path .. " (no playable source)")
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = path
	sound.SoundId = resolved.SoundId
	sound.Volume = resolved.Volume * (opts.Volume or 1)
	sound.PlaybackSpeed = resolved.Speed * (opts.Speed or 1)
	sound.SoundGroup = self.Groups[entry.Group] or self.Groups.Master
	local looped = opts.Looped or entry.Looped == true
	sound.Looped = looped
	if resolved.Region then
		sound.PlaybackRegionsEnabled = true
		sound.PlaybackRegion = resolved.Region
		if looped then
			sound.LoopRegion = resolved.Region
		end
	end

	local anchor: Instance? = nil
	local position: Vector3? = nil
	if entry.Spatial and where ~= nil then
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = entry.RollOff[1]
		sound.RollOffMaxDistance = entry.RollOff[2]
		if typeof(where) == "Instance" and where.Parent and (where:IsA("BasePart") or where:IsA("Attachment")) then
			sound.Parent = where
			position = if where:IsA("BasePart") then where.Position else (where :: Attachment).WorldPosition
		elseif typeof(where) == "Vector3" then
			local attachment = Instance.new("Attachment")
			attachment.Name = "COC_SoundAnchor"
			attachment.WorldPosition = where
			attachment.Parent = Workspace.Terrain
			sound.Parent = attachment
			anchor = attachment
			position = where
		else
			sound.Parent = self.TwoD
		end
	else
		sound.Parent = self.TwoD
	end

	if position and entry.Occlusion and not opts.NoOcclusion then
		local walls = self:CountWalls(position)
		if walls > 0 then
			sound.Volume *= 0.55 ^ walls
			local muffle = Instance.new("EqualizerSoundEffect")
			muffle.HighGain = -12 * walls
			muffle.MidGain = -4 * walls
			muffle.LowGain = 0
			muffle.Parent = sound
		end
	end

	sound:Play()

	-- runtime verification: a sound that never loads is reported and replaced
	if not sound.IsLoaded then
		local soundId = resolved.SoundId
		task.spawn(function()
			local started = os.clock()
			while sound.Parent and not sound.IsLoaded and os.clock() - started < LOAD_TIMEOUT do
				task.wait(0.1)
			end
			if sound.Parent and not sound.IsLoaded then
				SoundResolver.MarkFailed(soundId)
				warnOnce(self, "failed:" .. soundId .. path, string.format("[AudioService] Failed sound: %s (%s did not load) - using the next source", path, soundId))
				if not opts.Retry then
					local replacement = self:Play(path, where, { Volume = opts.Volume, Speed = opts.Speed, Looped = opts.Looped, NoOcclusion = opts.NoOcclusion, Retry = true })
					if replacement and looped then
						-- hand the new loop to whoever owns the old one
						sound:SetAttribute("ReplacedBy", replacement:GetFullName())
						self.Replacements = self.Replacements or {}
						self.Replacements[sound] = replacement
					end
				end
				if not looped then
					cleanupSound(sound, anchor)
				end
			end
		end)
	end

	if not looped then
		local lifetime = if resolved.Length > 0 then resolved.Length / math.max(sound.PlaybackSpeed, 0.05) + 0.5 else 10
		sound.Ended:Once(function()
			cleanupSound(sound, anchor)
		end)
		task.delay(math.min(lifetime, 20), function()
			if sound.Parent then
				cleanupSound(sound, anchor)
			end
		end)
	end
	return sound
end

-- Looped sound; the caller stops it with AudioController:StopLoop(sound).
function AudioController:StartLoop(path: string, where: any, volume: number?): Sound?
	return self:Play(path, where, { Looped = true, Volume = volume, NoOcclusion = true })
end

function AudioController:StopLoop(sound: Sound?, fade: number?)
	if not sound then
		return
	end
	local replacement = self.Replacements and self.Replacements[sound]
	if replacement then
		self.Replacements[sound] = nil
		self:StopLoop(replacement, fade)
	end
	local parent = sound.Parent
	local isAnchor = parent and parent:IsA("Attachment") and parent.Name == "COC_SoundAnchor"
	if fade and fade > 0 then
		local tween = TweenService:Create(sound, TweenInfo.new(fade), { Volume = 0 })
		tween.Completed:Once(function()
			if isAnchor and parent then
				parent:Destroy()
			else
				sound:Destroy()
			end
		end)
		tween:Play()
	elseif isAnchor and parent then
		parent:Destroy()
	else
		sound:Destroy()
	end
end

function AudioController:_onWorldSound(payload)
	local path = payload.K
	if type(path) ~= "string" then
		return
	end
	local where = payload.I
	if typeof(where) ~= "Instance" or not where.Parent then
		where = payload.P
	end
	local sequence = payload.Q
	if type(sequence) == "table" and typeof(payload.P) == "Vector3" and typeof(sequence.To) == "Vector3" then
		task.spawn(function()
			local count = math.clamp(sequence.Count or 4, 1, 16)
			for index = 1, count do
				local alpha = if count > 1 then (index - 1) / (count - 1) else 0
				self:Play(path, payload.P:Lerp(sequence.To, alpha), { Volume = payload.V })
				task.wait(sequence.Interval or 0.5)
			end
		end)
		return
	end
	if payload.L == true then
		-- server-driven loop on an instance (alarms, drones): stop with L = false
		self:_serverLoop(path, where, true)
		return
	elseif payload.L == false then
		self:_serverLoop(path, where, false)
		return
	end
	self:Play(path, where, { Volume = payload.V, Speed = payload.S, Variation = payload.N })
end

function AudioController:_serverLoop(path: string, where: any, on: boolean)
	self.ServerLoops = self.ServerLoops or {}
	local key = path .. tostring(where)
	local existing = self.ServerLoops[key]
	if on and not existing then
		self.ServerLoops[key] = self:StartLoop(path, where)
	elseif not on and existing then
		self.ServerLoops[key] = nil
		self:StopLoop(existing, 0.4)
	end
end

---------------------------------------------------------------------------
-- Tagged loops (breathing, alarms on parts...)
---------------------------------------------------------------------------

function AudioController:_attachLoop(instance: Instance)
	if self.Loops[instance] then
		return
	end
	local path = instance:GetAttribute("LoopSound")
	if type(path) ~= "string" then
		return
	end
	local sound = self:StartLoop(path, instance)
	if sound then
		self.Loops[instance] = sound
	end
end

function AudioController:_detachLoop(instance: Instance)
	local sound = self.Loops[instance]
	if sound then
		self.Loops[instance] = nil
		self:StopLoop(sound, 0.3)
	end
end

---------------------------------------------------------------------------
-- Zone acoustics, ambience beds, music and the silence rule
---------------------------------------------------------------------------

function AudioController:_dangerDistance(): number
	local camera = Workspace.CurrentCamera
	local beacons = Workspace:FindFirstChild("AnomalyBeacons")
	if not camera or not beacons then
		return math.huge
	end
	local nearest = math.huge
	for _, beacon in ipairs(beacons:GetChildren()) do
		if beacon:IsA("BasePart") and (beacon:GetAttribute("Danger") or 0) >= GameConfig.Environment.SilenceDanger then
			nearest = math.min(nearest, (beacon.Position - camera.CFrame.Position).Magnitude)
		end
	end
	return nearest
end

function AudioController:_setBed(path: string, wanted: boolean)
	local current = self.Beds[path]
	if wanted and not current then
		local sound = self:StartLoop(path, nil)
		if sound then
			local target = sound.Volume
			sound.Volume = 0
			TweenService:Create(sound, TweenInfo.new(2), { Volume = target }):Play()
			self.Beds[path] = sound
		end
	elseif not wanted and current then
		self.Beds[path] = nil
		self:StopLoop(current, 2)
	end
end

function AudioController:_updateAcoustics()
	local state = self.Controllers.ClientState
	local hud = self.Controllers.HUDController
	local zone = hud and hud.CurrentZoneId
	if state.InDarkRoom then
		zone = "DarkRoom"
	elseif not zone then
		zone = if state:IsInMission() then "GrandHall" else "Lobby"
	end
	local acoustics = SoundConfig.ZoneAcoustics[zone] or SoundConfig.ZoneAcoustics.GrandHall
	local map = MapConfig.Get(state.Round.MapId or "DeadMall")
	local reverbName = map and map.Acoustics and map.Acoustics[zone]
	local reverb = acoustics.Reverb
	if type(reverbName) == "string" then
		local ok, value = pcall(function()
			return (Enum.ReverbType :: any)[reverbName]
		end)
		if ok and value then
			reverb = value
		end
	end
	SoundService.AmbientReverb = reverb or Enum.ReverbType.NoReverb

	local wanted = {}
	for _, path in ipairs(acoustics.Beds or {}) do
		wanted[path] = true
	end
	local inRound = state:IsInRound()
	local danger = if inRound then self:_dangerDistance() else math.huge
	if acoustics.Music then
		wanted[acoustics.Music] = true
	elseif inRound and danger < 110 then
		wanted["Music.Tension"] = true
	end
	for path in pairs(self.Beds) do
		if not wanted[path] then
			self:_setBed(path, false)
		end
	end
	for path in pairs(wanted) do
		self:_setBed(path, true)
	end

	-- silence before an encounter
	local silent = danger < GameConfig.Environment.SilenceRadius
	self:SetDuck("Music", if silent then 0 else 1, if silent then 1.5 else 4)
	self:SetDuck("Ambience", if silent then 0.05 else 1, if silent then 2 else 4)
end

return AudioController
