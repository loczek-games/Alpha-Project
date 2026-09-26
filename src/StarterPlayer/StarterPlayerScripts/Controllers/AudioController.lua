--[[
	AudioController (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/AudioController

	The client audio engine.
	  * Mixer: SoundGroups Master > Music, Ambience, PlayerSFX, EquipmentSFX,
	    AnomalySFX, Voice, Jumpscares, UI - scaled by the player's volume settings.
	  * Play(path, where): resolves SoundConfig (variation + pitch/volume jitter),
	    positions the sound in 3D and muffles it through walls (occlusion).
	  * Plays WorldSound messages from the server (other players' equipment,
	    doors, anomalies, phantom sounds...).
	  * Looping sounds on anything tagged "LoopSound" (e.g. the Listener's breathing).
	  * Zone acoustics: reverb + ambience beds per zone (open-space echo in the
	    Main Hall, bathroom reverb, parking-lot reverb...).
	  * SILENCE RULE: when something dangerous is close, music and ambience fade
	    out completely so small sounds become terrifying.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local SoundConfig = require(Config:WaitForChild("SoundConfig"))
local GameConfig = require(Config:WaitForChild("GameConfig"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local SoundResolver = require(Modules:WaitForChild("SoundResolver"))
local Net = require(Modules:WaitForChild("Net"))

local AudioController = {}
AudioController.Groups = {}
AudioController.Loops = {}
AudioController.Beds = {}
AudioController.Duck = { Music = 1, Ambience = 1 }

function AudioController:Init(controllers)
	self.Controllers = controllers
	local mixer = Instance.new("Folder")
	mixer.Name = "COC_Mixer"
	mixer.Parent = SoundService
	self.Mixer = mixer
	for _, name in ipairs(SoundConfig.GroupOrder) do
		local def = SoundConfig.Groups[name]
		local group = Instance.new("SoundGroup")
		group.Name = name
		group.Volume = def.Volume
		group.Parent = if def.Parent then self.Groups[def.Parent] else mixer
		self.Groups[name] = group
	end
	self.TwoD = Instance.new("Folder")
	self.TwoD.Name = "COC_2D"
	self.TwoD.Parent = SoundService

	self.OcclusionParams = RaycastParams.new()
	self.OcclusionParams.FilterType = Enum.RaycastFilterType.Exclude

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

function AudioController:Start()
	-- looping sounds attached to tagged parts
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
				warn("[AudioController]", err)
			end
			task.wait(0.5)
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
		walls += 1
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
}

-- where: nil (2D) | Vector3 | BasePart | Attachment
function AudioController:Play(path: string, where: any, options: PlayOptions?): Sound?
	local opts: PlayOptions = options or {}
	local resolved = SoundResolver.Resolve(path, opts.Variation)
	if not resolved then
		return nil
	end
	local entry = resolved.Entry
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
	if not looped then
		local lifetime = if resolved.Length > 0 then resolved.Length / math.max(sound.PlaybackSpeed, 0.05) + 0.5 else 10
		local function cleanup()
			if anchor then
				anchor:Destroy()
			else
				sound:Destroy()
			end
		end
		sound.Ended:Once(cleanup)
		task.delay(math.min(lifetime, 20), function()
			if sound.Parent then
				cleanup()
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
	self:Play(path, where, { Volume = payload.V, Speed = payload.S, Variation = payload.N })
end

---------------------------------------------------------------------------
-- Tagged loops (e.g. the Listener's breathing)
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
		zone = "Lobby"
	end
	local acoustics = SoundConfig.ZoneAcoustics[zone] or SoundConfig.ZoneAcoustics.MainHall
	local mapAcoustics = SoundConfig.MapAcoustics[SoundConfig.CurrentMap]
	SoundService.AmbientReverb = acoustics.Reverb or (mapAcoustics and mapAcoustics.DefaultReverb) or Enum.ReverbType.NoReverb

	local wanted = {}
	for _, path in ipairs(acoustics.Beds or {}) do
		wanted[path] = true
	end
	local inRound = state.Round.State == "Round"
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
