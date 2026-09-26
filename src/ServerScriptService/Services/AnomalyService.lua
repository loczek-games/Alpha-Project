--[[
	AnomalyService (ModuleScript)
	Location: ServerScriptService/Services/AnomalyService

	Spawns, updates and cleans up anomalies. Anomaly definitions live in
	ReplicatedStorage/Config/AnomalyConfig; the visual/behavioural logic for
	each lives in its own ModuleScript in ServerScriptService/Anomalies/Behaviors.

	Behaviour module interface (all functions optional except Spawn):
	  Spawn(ctx, record) -> boolean     build it, set record.Target (BasePart)
	  CanSpawn(ctx, def) -> boolean     extra spawn conditions
	  Update(ctx, record, dt)           called ~10x/second (must not yield)
	  OnCaptured(ctx, record, player, result)
	  Despawn(ctx, record, reason)      restore anything borrowed from the map
	  CanPhotograph(ctx, record, player) -> boolean, reason?

	`ctx` is this service. Useful fields: ctx.Kit (bodies, parts, fades,
	sounds), ctx.Objects (ObjectBehaviors), ctx.Services, ctx.Config.
	Generic behaviours: Entity (creatures: Appearance + Movers + Brain),
	ObjectAnomaly (possessed objects), CeilingCrawler.
	Anything added to record.Cleaner is cleaned up automatically, and
	record.Model (if set) is faded out and destroyed on despawn - never set
	record.Model to a map object (use VisibilityRoot for those).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local AnomalyConfig = require(Config:WaitForChild("AnomalyConfig"))
local RarityConfig = require(Config:WaitForChild("RarityConfig"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Net = require(Modules:WaitForChild("Net"))
local Cleaner = require(Modules:WaitForChild("Cleaner"))

local AnomaliesFolder = ServerScriptService:WaitForChild("Anomalies")
local Kit = require(AnomaliesFolder:WaitForChild("AnomalyKit"))
local Appearance = require(AnomaliesFolder:WaitForChild("Appearance"))
local ObjectBehaviors = require(AnomaliesFolder:WaitForChild("ObjectBehaviors"))

local AnomalyService = {}
AnomalyService.Active = {}
AnomalyService.CountById = {}
AnomalyService.InUse = {}
AnomalyService.PersistentFx = {}
AnomalyService.Behaviors = {}
AnomalyService.Running = false
AnomalyService.Kit = Kit
AnomalyService.Objects = ObjectBehaviors
AnomalyService.Appearance = Appearance
AnomalyService.Config = GameConfig

local SPAWNING = GameConfig.Spawning
local uidCounter = 0

local function now(): number
	return Workspace:GetServerTimeNow()
end

function AnomalyService:Init(services)
	self.Services = services
	self.FxRemote = Net.Event("AnomalyFx")
	self.AnnounceRemote = Net.Event("Announce")
	Kit.Audio = services.AudioService
	Kit.Appearance = Appearance
	Appearance:Init(services)

	-- collision groups (COCAnomaly never collides with COCPlayer) are
	-- registered by CharacterService:Init, before any character spawns

	-- Invisible markers that let client equipment (thermal scanner, camera
	-- autofocus glitches, UV, "silence before an encounter") sense anomalies.
	local beacons = Instance.new("Model")
	beacons.Name = "AnomalyBeacons"
	beacons.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	beacons.Parent = Workspace
	self.BeaconFolder = beacons
	local residue = Instance.new("Folder")
	residue.Name = "UVResidue"
	residue.Parent = Workspace
	self.ResidueFolder = residue
	self.FloorParams = RaycastParams.new()
	self.FloorParams.FilterType = Enum.RaycastFilterType.Exclude

	local behaviorsFolder = AnomaliesFolder:WaitForChild("Behaviors")
	for _, moduleScript in ipairs(behaviorsFolder:GetChildren()) do
		if moduleScript:IsA("ModuleScript") then
			local ok, behavior = pcall(require, moduleScript)
			if ok and type(behavior) == "table" and type(behavior.Spawn) == "function" then
				self.Behaviors[moduleScript.Name] = behavior
			else
				warn("[AnomalyService] Invalid behaviour module", moduleScript:GetFullName(), behavior)
			end
		end
	end
	for _, def in ipairs(AnomalyConfig.List) do
		if def.Enabled and not self.Behaviors[def.Behavior] then
			warn(string.format("[AnomalyService] Anomaly %s has no behaviour module named %s", def.Id, def.Behavior))
		end
	end

	services.DataService:OnClientReady(function(player)
		for _, payload in pairs(self.PersistentFx) do
			if payload.Except ~= player.UserId then
				self.FxRemote:FireClient(player, payload.Data)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		for _, record in pairs(self.Active) do
			if record.TargetPlayer == player then
				self:Despawn(record, "PlayerLeft")
			end
		end
		self.InUse[player] = nil
	end)

	local accumulator = 0
	local interval = 1 / SPAWNING.UpdateRate
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < interval then
			return
		end
		local step = accumulator
		accumulator = 0
		self:_update(step)
	end)
end

---------------------------------------------------------------------------
-- Round control
---------------------------------------------------------------------------

function AnomalyService:StartRound()
	self.Running = true
	if self.SpawnThread then
		pcall(task.cancel, self.SpawnThread)
	end
	self.SpawnThread = task.spawn(function()
		task.wait(SPAWNING.FirstSpawnDelay)
		local function safeSpawn(options)
			local ok, err = pcall(self.SpawnRandom, self, options)
			if not ok then
				warn("[AnomalyService] spawn error:", err)
			end
		end
		for _ = 1, SPAWNING.InitialBurst do
			if not self.Running then
				return
			end
			safeSpawn({ MaxRarity = "Rare" })
			task.wait(1.5)
		end
		while self.Running do
			local modifiers = self.Services.EventService:GetModifiers()
			local wait = (SPAWNING.IntervalMin + math.random() * (SPAWNING.IntervalMax - SPAWNING.IntervalMin)) * modifiers.SpawnIntervalMultiplier
			task.wait(wait)
			if self.Running and self:CountActive() < self:GetMaxConcurrent() then
				safeSpawn(nil)
			end
		end
	end)
end

function AnomalyService:StopRound()
	self.Running = false
	if self.SpawnThread and coroutine.status(self.SpawnThread) ~= "dead" then
		pcall(task.cancel, self.SpawnThread)
	end
	self.SpawnThread = nil
	self:DespawnAll("RoundEnd")
end

function AnomalyService:CountActive(): number
	local count = 0
	for _, record in pairs(self.Active) do
		if not record.Despawning then
			count += 1
		end
	end
	return count
end

function AnomalyService:GetMaxConcurrent(): number
	local modifiers = self.Services.EventService:GetModifiers()
	local players = #self:GetParticipants()
	local max = SPAWNING.BaseMaxConcurrent + math.floor(players / SPAWNING.PlayersPerExtraSlot) + modifiers.ExtraConcurrent
	return math.min(max, SPAWNING.HardMaxConcurrent)
end

---------------------------------------------------------------------------
-- Picking + spawning
---------------------------------------------------------------------------

function AnomalyService:_meetsRequirements(def): boolean
	local spawn = def.Spawn
	local participants = self:GetParticipants()
	if #participants == 0 then
		return false
	end
	if spawn.MinPlayers and #participants < spawn.MinPlayers then
		return false
	end
	if spawn.Player and #self:_freeTargetPlayers() == 0 then
		return false
	end
	if spawn.Fixture and #self:_freeFixtures(def) == 0 then
		return false
	end
	if spawn.Kinds and #self:_freeMarkers(def) == 0 then
		return false
	end
	if def.RequiredAbility then
		local anyone = false
		for _, player in ipairs(participants) do
			local stats = self.Services.EconomyService:GetCameraStats(player)
			if stats.Abilities[def.RequiredAbility] then
				anyone = true
				break
			end
		end
		if not anyone then
			return false
		end
	end
	return true
end

function AnomalyService:PickDefinition(options, exclude)
	local opts = options or {}
	local modifiers = self.Services.EventService:GetModifiers()
	local minRank = opts.MinRarity and RarityConfig.GetRank(opts.MinRarity) or 1
	local maxRank = opts.MaxRarity and RarityConfig.GetRank(opts.MaxRarity) or math.huge
	local candidates = {}
	local total = 0

	for _, def in ipairs(AnomalyConfig.List) do
		if not def.Enabled or (exclude and exclude[def.Id]) then
			continue
		end
		if opts.OnlyId and def.Id ~= opts.OnlyId then
			continue
		end
		if def.RequiresEvent and not opts.OnlyId and not self.Services.EventService:IsActive(def.RequiresEvent) then
			continue
		end
		if opts.RequireEvent and def.RequiresEvent ~= opts.RequireEvent then
			continue
		end
		local rank = RarityConfig.GetRank(def.Rarity)
		if rank < minRank or rank > maxRank then
			continue
		end
		if (self.CountById[def.Id] or 0) >= def.MaxActive then
			continue
		end
		local behavior = self.Behaviors[def.Behavior]
		if not behavior then
			continue
		end
		if not self:_meetsRequirements(def) then
			continue
		end
		if behavior.CanSpawn and not behavior.CanSpawn(self, def) then
			continue
		end
		local weight = def.Weight * (modifiers.Luck[def.Rarity] or 1)
		if def.RequiresEvent then
			weight *= def.EventWeightMultiplier
		end
		if weight > 0 then
			total += weight
			table.insert(candidates, { Def = def, Weight = weight })
		end
	end

	if total <= 0 then
		return nil
	end
	local roll = math.random() * total
	for _, candidate in ipairs(candidates) do
		roll -= candidate.Weight
		if roll <= 0 then
			return candidate.Def
		end
	end
	return candidates[#candidates].Def
end

function AnomalyService:SpawnRandom(options)
	local exclude = {}
	for _ = 1, SPAWNING.PickAttempts do
		local def = self:PickDefinition(options, exclude)
		if not def then
			return nil
		end
		local record = self:Spawn(def.Id, options)
		if record then
			return record
		end
		exclude[def.Id] = true
	end
	return nil
end

function AnomalyService:Spawn(anomalyId: string, options)
	local def = AnomalyConfig.Get(anomalyId)
	if not def then
		return nil
	end
	local behavior = self.Behaviors[def.Behavior]
	if not behavior then
		return nil
	end
	local opts = options or {}

	uidCounter += 1
	local record: any = {
		Uid = "A" .. uidCounter,
		Id = def.Id,
		Def = def,
		Params = def.Params,
		Cleaner = Cleaner.new(),
		Captures = {},
		CaptureCount = 0,
		State = {},
		Reserved = {},
		ExcludePhotographers = {},
		TargetRadius = def.TargetRadius,
		Lifetime = def.Lifetime * (opts.LifetimeMultiplier or 1),
		SpawnTime = now(),
		Ready = false,
	}
	self.Active[record.Uid] = record
	self.CountById[def.Id] = (self.CountById[def.Id] or 0) + 1

	local ok, result = pcall(behavior.Spawn, self, record)
	if record.CleanedUp then
		-- the round ended while the behaviour was still building (e.g. loading an avatar)
		record.Cleaner:Clean()
		if record.Model then
			record.Model:Destroy()
		end
		return nil
	end
	if not ok or result == false or not record.Target or not record.Target:IsDescendantOf(Workspace) and not (record.Model and record.Target:IsDescendantOf(record.Model)) then
		if not ok then
			warn(string.format("[AnomalyService] %s failed to spawn: %s", def.Id, tostring(result)))
		end
		self:_cleanup(record)
		return nil
	end

	if record.Model then
		record.Model:SetAttribute("AnomalyUid", record.Uid)
		record.Model:SetAttribute("AnomalyId", def.Id)
		CollectionService:AddTag(record.Model, "Anomaly")
		if not record.Model.Parent then
			record.Model.Parent = self.Services.MapService.Folders.ActiveAnomalies
		end
	end
	record.VisibilityRoot = record.VisibilityRoot or record.Model or record.Target
	record.Zone = record.Zone or self.Services.MapService:GetZoneAt(record.Target.Position)
	record.SpawnTime = now()
	record.ExpireTime = record.SpawnTime + record.Lifetime
	record.Ready = true

	self:_createBeacon(record)
	if def.Residue then
		self:_createResidue(record)
	end
	if not def.Params.Silent and not record.Silent then
		Kit.PlaySound3D(record.Target, "Anomaly.Sting", 70)
	end
	self:_sendSenseHints(record)
	return record
end

function AnomalyService:_sendSenseHints(record)
	local position = record.Target.Position
	for _, player in ipairs(self:GetParticipants()) do
		if record.ExcludePhotographers[player.UserId] then
			continue
		end
		local stats = self.Services.EconomyService:GetCameraStats(player)
		if stats.SenseRadius > 0 then
			local root = self:GetCharacterParts(player)
			if root and (root.Position - position).Magnitude <= stats.SenseRadius then
				self.FxRemote:FireClient(player, { Type = "SenseHint" })
			end
		end
	end
end

---------------------------------------------------------------------------
-- Update + despawn
---------------------------------------------------------------------------

function AnomalyService:_update(dt: number)
	local time = now()
	for _, record in pairs(self.Active) do
		if not record.Ready or record.Despawning then
			continue
		end
		if time >= record.ExpireTime then
			self:Despawn(record, "Expired")
			continue
		end
		if not record.Target or not record.Target:IsDescendantOf(Workspace) then
			self:Despawn(record, "Lost")
			continue
		end
		local beacon = record.Beacon
		if beacon and (beacon.Position - record.Target.Position).Magnitude > 0.5 then
			beacon.CFrame = CFrame.new(record.Target.Position)
		end
		local behavior = self.Behaviors[record.Def.Behavior]
		if behavior and behavior.Update then
			local ok, err = pcall(behavior.Update, self, record, dt)
			if not ok then
				warn(string.format("[AnomalyService] %s update error: %s", record.Id, tostring(err)))
			end
		end
	end
end

function AnomalyService:Despawn(record, reason: string?)
	if record.Despawning then
		return
	end
	record.Despawning = true
	record.DespawnTime = now()
	task.spawn(function()
		local behavior = self.Behaviors[record.Def.Behavior]
		if behavior and behavior.Despawn then
			local ok, err = pcall(behavior.Despawn, self, record, reason)
			if not ok then
				warn(string.format("[AnomalyService] %s despawn error: %s", record.Id, tostring(err)))
			end
		end
		if record.Model and record.Model.Parent and not record.NoFade then
			Kit.FadeOut(record.Model, SPAWNING.DespawnFadeTime)
			task.wait(SPAWNING.DespawnFadeTime)
		end
		self:_cleanup(record)
	end)
end

function AnomalyService:DespawnAll(reason: string?)
	for _, record in pairs(self.Active) do
		self:Despawn(record, reason)
	end
end

function AnomalyService:_cleanup(record)
	if record.CleanedUp then
		return
	end
	record.CleanedUp = true
	record.Cleaner:Clean()
	if record.Beacon then
		record.Beacon:Destroy()
	end
	for _, part in ipairs(record.ResidueParts or {}) do
		part:Destroy()
	end
	if record.Model then
		record.Model:Destroy()
	end
	for _, instance in ipairs(record.Reserved) do
		if self.InUse[instance] == record.Uid then
			self.InUse[instance] = nil
		end
	end
	if self.PersistentFx[record.Uid] then
		self.PersistentFx[record.Uid] = nil
	end
	self.Active[record.Uid] = nil
	self.CountById[record.Id] = math.max(0, (self.CountById[record.Id] or 1) - 1)
end

function AnomalyService:GetActiveList()
	local list = {}
	for _, record in pairs(self.Active) do
		if record.Ready and not record.CleanedUp then
			table.insert(list, record)
		end
	end
	return list
end

-- Can a photo still count? (alive, or vanished within the latency grace window)
function AnomalyService:IsPhotographable(record): boolean
	if not record.Ready or record.CleanedUp then
		return false
	end
	if record.Despawning then
		return now() - (record.DespawnTime or 0) <= SPAWNING.PhotoGraceAfterDespawn
	end
	return true
end

---------------------------------------------------------------------------
-- Helpers for behaviour modules
---------------------------------------------------------------------------

function AnomalyService:GetParticipants(): { Player }
	local mission = self.Services.MissionService
	local list = {}
	if not mission or mission.State ~= "Round" then
		return list
	end
	for _, player in ipairs(mission:GetParticipants()) do
		local root = self:GetCharacterParts(player)
		if root and not self.Services.CharacterService:IsDowned(player) then
			table.insert(list, player)
		end
	end
	return list
end

function AnomalyService:GetCharacterParts(player: Player)
	return self.Services.CharacterService:GetParts(player)
end

function AnomalyService:GetNearestParticipant(position: Vector3, maxDistance: number?, exclude: Player?)
	local best, bestDistance, bestRoot, bestHead = nil, maxDistance or math.huge, nil, nil
	for _, player in ipairs(self:GetParticipants()) do
		if player ~= exclude then
			local root, head = self:GetCharacterParts(player)
			if root then
				local distance = (root.Position - position).Magnitude
				if distance < bestDistance then
					best, bestDistance, bestRoot, bestHead = player, distance, root, head
				end
			end
		end
	end
	return best, bestDistance, bestRoot, bestHead
end

function AnomalyService:Reserve(record, instance: any)
	self.InUse[instance] = record.Uid
	table.insert(record.Reserved, instance)
end

function AnomalyService:IsFree(instance: any): boolean
	return self.InUse[instance] == nil
end

function AnomalyService:_freeMarkers(def)
	local list = {}
	for _, markerPart in ipairs(self.Services.MapService:GetMarkers(def.Spawn.Kinds, def.Spawn.Zones)) do
		if self:IsFree(markerPart) then
			table.insert(list, markerPart)
		end
	end
	return list
end

function AnomalyService:_freeFixtures(def)
	local list = {}
	for _, fixture in ipairs(self.Services.MapService:GetFixtures(def.Spawn.Fixture, def.Spawn.Zones)) do
		if self:IsFree(fixture) then
			table.insert(list, fixture)
		end
	end
	return list
end

function AnomalyService:_freeTargetPlayers()
	local list = {}
	for _, player in ipairs(self:GetParticipants()) do
		if self:IsFree(player) then
			table.insert(list, player)
		end
	end
	return list
end

-- Picks + reserves a spawn marker, preferring ones no player is standing next to.
function AnomalyService:PickSpawn(record): BasePart?
	local markers = self:_freeMarkers(record.Def)
	if #markers == 0 then
		return nil
	end
	local preferred = {}
	for _, markerPart in ipairs(markers) do
		local _, distance = self:GetNearestParticipant(markerPart.Position)
		if distance >= SPAWNING.MinDistanceFromPlayers then
			table.insert(preferred, markerPart)
		end
	end
	local pool = if #preferred > 0 then preferred else markers
	local chosen = pool[math.random(1, #pool)]
	self:Reserve(record, chosen)
	record.Zone = chosen:GetAttribute("Zone")
	record.Marker = chosen
	return chosen
end

function AnomalyService:PickFixture(record): Instance?
	local fixtures = self:_freeFixtures(record.Def)
	if #fixtures == 0 then
		return nil
	end
	local chosen = fixtures[math.random(1, #fixtures)]
	self:Reserve(record, chosen)
	record.Zone = chosen:GetAttribute("Zone")
	return chosen
end

function AnomalyService:PickTargetPlayer(record): Player?
	local players = self:_freeTargetPlayers()
	if #players == 0 then
		return nil
	end
	local chosen = players[math.random(1, #players)]
	self:Reserve(record, chosen)
	record.TargetPlayer = chosen
	return chosen
end

function AnomalyService:FireFx(player: Player, payload)
	self.FxRemote:FireClient(player, payload)
end

function AnomalyService:FireFxAll(payload, except: Player?)
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= except then
			self.FxRemote:FireClient(player, payload)
		end
	end
end

-- Effects that late joiners must also receive (e.g. the Smiling Player face).
function AnomalyService:SetPersistentFx(record, payload, except: Player?)
	self.PersistentFx[record.Uid] = { Data = payload, Except = except and except.UserId or nil }
end

function AnomalyService:Announce(payload)
	self.AnnounceRemote:FireAllClients(payload)
end

---------------------------------------------------------------------------
-- Sensing helpers (equipment interference, EMF, beacons, UV residue)
---------------------------------------------------------------------------

function AnomalyService:_createBeacon(record)
	local def = record.Def
	local beacon = Instance.new("Part")
	beacon.Name = def.Id
	beacon.Size = Vector3.new(0.5, 0.5, 0.5)
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanQuery = false
	beacon.CanTouch = false
	beacon.Transparency = 1
	beacon.CFrame = CFrame.new(record.Target.Position)
	beacon:SetAttribute("Uid", record.Uid)
	beacon:SetAttribute("AnomalyId", def.Id)
	beacon:SetAttribute("Danger", def.Danger)
	beacon:SetAttribute("EMF", def.EMF)
	beacon:SetAttribute("Cold", def.Cold == true)
	beacon.Parent = self.BeaconFolder
	record.Beacon = beacon
end

-- A few glowing hand/foot prints on the floor near the anomaly, visible only through a UV light.
function AnomalyService:_createResidue(record)
	record.ResidueParts = {}
	local origin = record.Target.Position
	self.FloorParams.FilterDescendantsInstances = { self.Services.MapService.Folders.ActiveAnomalies, self.ResidueFolder, self.BeaconFolder }
	local angle = math.random() * math.pi * 2
	for index = 1, 5 do
		local distance = 3 + index * 2.2
		angle += (math.random() - 0.5) * 0.8
		local flat = origin + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local result = Workspace:Raycast(flat + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0), self.FloorParams)
		if result then
			local print_ = Instance.new("Part")
			print_.Name = "Residue"
			print_.Size = Vector3.new(0.9, 0.05, 1.4)
			print_.CFrame = CFrame.new(result.Position + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, -angle + math.pi / 2 + (index % 2) * 0.3, 0)
			print_.Anchored = true
			print_.CanCollide = false
			print_.CanQuery = false
			print_.CanTouch = false
			print_.CastShadow = false
			print_.Material = Enum.Material.Neon
			print_.Color = Color3.fromRGB(120, 255, 210)
			print_.Transparency = 1 -- clients reveal it locally under UV light
			print_:SetAttribute("Residue", true)
			print_.Parent = self.ResidueFolder
			table.insert(record.ResidueParts, print_)
		end
	end
end

-- 0..1: how strongly dangerous anomalies disturb electronics at this position.
function AnomalyService:GetDangerNear(position: Vector3, radius: number): number
	local strongest = 0
	for _, record in pairs(self.Active) do
		if record.Ready and not record.Despawning and record.Target then
			local distance = (record.Target.Position - position).Magnitude
			if distance < radius then
				strongest = math.max(strongest, record.Def.Danger * (1 - distance / radius))
			end
		end
	end
	return strongest
end

-- EMF level 0-5 at a position, plus whether the reading distorts.
function AnomalyService:GetEMFLevel(position: Vector3, range: number): (number, boolean)
	local level, distort = 0, false
	for _, record in pairs(self.Active) do
		if record.Ready and not record.Despawning and record.Target then
			local distance = (record.Target.Position - position).Magnitude
			if distance < range then
				local value = math.ceil(record.Def.EMF * (1 - distance / range) ^ 0.7)
				if value > level then
					level = value
					distort = value >= 5 and record.Def.Danger >= 0.7
				end
			end
		end
	end
	return math.clamp(level, 0, 5), distort
end

--[[
	An anomaly catches an investigator:
	  * first-person jumpscare in the anomaly's own style (JumpscareController)
	  * everyone nearby hears it
	  * Heavy = knocked down after the scare (team mates can revive),
	    otherwise a short stun; optional battery drain
	options: { Record, Heavy, BatteryDrain, Delay } (a number = battery drain, legacy)
]]
function AnomalyService:AttackPlayer(player: Player, kind: string, options: any)
	local opts = if type(options) == "table" then options else { BatteryDrain = options }
	local character = self.Services.CharacterService
	if character:IsDowned(player) then
		return
	end
	local record = opts.Record
	local target = record and record.Target
	local root = self:GetCharacterParts(player)
	self:FireFx(player, {
		Type = "Jumpscare",
		Kind = kind,
		Uid = record and record.Uid,
		Position = if target and target.Parent then target.Position else nil,
		Downed = opts.Heavy == true,
	})
	if root then
		self.Services.AudioService:Play("Anomaly.Groan", root, { Exclude = player })
		self.Services.NoiseService:Emit(root.Position, 0.5, "Voice", nil)
	end
	if opts.BatteryDrain and opts.BatteryDrain > 0 then
		self.Services.EquipmentService:DrainEquipped(player, opts.BatteryDrain)
	end
	if opts.Heavy then
		character:Stun(player, (opts.Delay or 1.6) + 0.2)
		task.delay(opts.Delay or 1.6, function()
			if player:IsDescendantOf(Players) then
				character:Down(player, kind)
			end
		end)
	else
		character:Stun(player, GameConfig.Movement.StunTime)
	end
end

return AnomalyService
