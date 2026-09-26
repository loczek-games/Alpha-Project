--[[
	NoiseService (ModuleScript)
	Location: ServerScriptService/Services/NoiseService

	World noise simulation for sound-sensitive anomalies.

	  Emit(position, intensity, kind, source)   a player (or the world) makes noise
	  SetMask(key, level, duration, pos, radius) thunder / HVAC / alarms hide noise
	  Listen(position, hearing, sinceId)         what an anomaly can hear right now

	Perceived loudness at the listener:
	  intensity x kindMultiplier x (1 - distance/radius)
	  - environmental masking x MaskingFactor
	  x WallDamping ^ walls-in-between (max GameConfig.Noise.MaxWalls raycasts)

	It also generates noise from player movement (sneak / walk / run),
	landings (normal / heavy) and chat messages ("talking").
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local SoundConfig = require(Config:WaitForChild("SoundConfig"))

local NoiseService = {}
NoiseService.Events = {}
NoiseService.Masks = {}
NoiseService.History = {}
NoiseService.Movement = {}
NoiseService.NextId = 0

local NOISE = GameConfig.Noise

local function mapAcoustics()
	return SoundConfig.MapAcoustics[SoundConfig.CurrentMap] or SoundConfig.MapAcoustics.DeadMall
end

function NoiseService:Init(services)
	self.Services = services
	self.WallParams = RaycastParams.new()
	self.WallParams.FilterType = Enum.RaycastFilterType.Exclude
	self.FloorParams = RaycastParams.new()
	self.FloorParams.FilterType = Enum.RaycastFilterType.Exclude

	local function watch(player: Player)
		player.Chatted:Connect(function(message)
			if string.sub(message, 1, 1) == "/" then
				return
			end
			local _, head = services.CharacterService:GetParts(player)
			if head then
				self:Emit(head.Position, NOISE.Voice, "Voice", player)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		self.History[player] = nil
		self.Movement[player] = nil
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		accumulator = 0
		self:_movementTick()
	end)
end

function NoiseService:_refreshFilters()
	local exclude: { Instance } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	local folders = self.Services.MapService.Folders
	for _, key in ipairs({ "ActiveAnomalies", "Decoys", "NPCs" }) do
		if folders[key] then
			table.insert(exclude, folders[key])
		end
	end
	self.WallParams.FilterDescendantsInstances = exclude
	self.FloorParams.FilterDescendantsInstances = exclude
end

---------------------------------------------------------------------------
-- Emitting + masking
---------------------------------------------------------------------------

function NoiseService:_prune()
	local cutoff = os.clock() - NOISE.EventLifetime
	local events = self.Events
	local firstValid = 1
	while events[firstValid] and events[firstValid].Time < cutoff do
		firstValid += 1
	end
	if firstValid > 1 then
		table.move(events, firstValid, #events, 1)
		for index = #events - firstValid + 2, #events do
			events[index] = nil
		end
	end
end

function NoiseService:Emit(position: Vector3, intensity: number, kind: string, source: Player?, path: string?)
	if intensity <= 0 then
		return nil
	end
	self:_prune()
	local acoustics = mapAcoustics()
	self.NextId += 1
	local event = {
		Id = self.NextId,
		Position = position,
		Intensity = intensity * (acoustics.NoiseCarry or 1),
		Kind = kind,
		Source = source,
		Path = path,
		Time = os.clock(),
	}
	table.insert(self.Events, event)
	if source then
		local history = self.History[source]
		if not history then
			history = {}
			self.History[source] = history
		end
		table.insert(history, { Time = event.Time, Kind = kind, Path = path, Position = position })
		if #history > 16 then
			table.remove(history, 1)
		end
	end
	return event
end

-- position/radius nil = global mask (e.g. thunder)
function NoiseService:SetMask(key: string, level: number, duration: number, position: Vector3?, radius: number?)
	self.Masks[key] = { Level = level, EndsAt = os.clock() + duration, Position = position, Radius = radius }
end

function NoiseService:GetMasking(position: Vector3): number
	local level = mapAcoustics().BaseMasking or 0
	local now = os.clock()
	for key, mask in pairs(self.Masks) do
		if now > mask.EndsAt then
			self.Masks[key] = nil
		elseif not mask.Position or (mask.Position - position).Magnitude <= (mask.Radius or math.huge) then
			level = math.max(level, mask.Level)
		end
	end
	return level
end

function NoiseService:GetEnvironmentalNoiseLevel(position: Vector3): number
	return self:GetMasking(position)
end

---------------------------------------------------------------------------
-- Hearing
---------------------------------------------------------------------------

function NoiseService:CountWalls(from: Vector3, to: Vector3): number
	local walls = 0
	local origin = from
	local remaining = to - from
	for _ = 1, NOISE.MaxWalls do
		if remaining.Magnitude < 0.5 then
			break
		end
		local result = Workspace:Raycast(origin, remaining, self.WallParams)
		if not result then
			break
		end
		walls += 1
		local direction = remaining.Unit
		origin = result.Position + direction * 0.6
		remaining = to - origin
		if remaining:Dot(direction) <= 0 then
			break
		end
	end
	return walls
end

--[[
	hearing = { Radius, Threshold, Kinds = { Kind = multiplier }, Default }
	Returns the loudest event newer than sinceId that the listener perceives
	above its threshold, plus the perceived value and the newest event id.
]]
function NoiseService:Listen(position: Vector3, hearing, sinceId: number?)
	self:_prune()
	self:_refreshFilters()
	local best, bestPerceived = nil, 0
	local newest = sinceId or 0
	local radius = hearing.Radius or 60
	local threshold = hearing.Threshold or 0.05
	for index = #self.Events, 1, -1 do
		local event = self.Events[index]
		if event.Id <= (sinceId or 0) then
			break
		end
		newest = math.max(newest, event.Id)
		local multiplier = hearing.Kinds and hearing.Kinds[event.Kind] or hearing.Default or 0
		if multiplier <= 0 then
			continue
		end
		local distance = (event.Position - position).Magnitude
		if distance > radius then
			continue
		end
		local perceived = event.Intensity * multiplier * (1 - distance / radius)
		perceived -= self:GetMasking(event.Position) * NOISE.MaskingFactor
		if perceived < threshold or perceived <= bestPerceived then
			continue
		end
		local walls = self:CountWalls(event.Position, position)
		perceived *= NOISE.WallDamping ^ walls
		if perceived >= threshold and perceived > bestPerceived then
			best, bestPerceived = event, perceived
		end
	end
	return best, bestPerceived, newest
end

-- Recent noises made by a player (used by Echo to copy repeated sounds).
function NoiseService:GetRecentFrom(player: Player, window: number)
	local list = {}
	local cutoff = os.clock() - window
	for _, entry in ipairs(self.History[player] or {}) do
		if entry.Time >= cutoff then
			table.insert(list, entry)
		end
	end
	return list
end

---------------------------------------------------------------------------
-- Movement / landing noise
---------------------------------------------------------------------------

function NoiseService:_surfaceAt(root: BasePart): string
	local result = Workspace:Raycast(root.Position, Vector3.new(0, -8, 0), self.FloorParams)
	if not result then
		return "Concrete"
	end
	local override = result.Instance:GetAttribute("FootstepSurface")
	if type(override) == "string" then
		return override
	end
	return SoundConfig.MaterialSurfaces[result.Material.Name] or "Concrete"
end

function NoiseService:_movementTick()
	local round = self.Services.RoundService
	if not round or round.State ~= "Round" then
		return
	end
	self:_refreshFilters()
	local now = os.clock()
	for _, player in ipairs(round:GetParticipants()) do
		local root, _, humanoid = self.Services.CharacterService:GetParts(player)
		if not root or not humanoid then
			continue
		end
		local state = self.Movement[player]
		if not state then
			state = { LastEmit = 0, LastVY = 0 }
			self.Movement[player] = state
		end
		local velocity = root.AssemblyLinearVelocity
		-- landing
		if state.LastVY < -NOISE.LandVelocity and velocity.Y > -4 then
			local heavy = state.LastVY < -NOISE.HeavyLandVelocity
			self:Emit(root.Position - Vector3.new(0, 3, 0), if heavy then NOISE.HeavyLand else NOISE.Land, "Land", player)
		end
		state.LastVY = velocity.Y

		if now - state.LastEmit < NOISE.MovementInterval then
			continue
		end
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		if speed < 2 or humanoid.FloorMaterial == Enum.Material.Air then
			continue
		end
		state.LastEmit = now
		local kind, intensity
		if speed >= NOISE.RunSpeedMin then
			kind, intensity = "Run", NOISE.Run
		elseif speed >= NOISE.SneakSpeedMax then
			kind, intensity = "Footstep", NOISE.Walk
		else
			kind, intensity = "Sneak", NOISE.Sneak
		end
		local surface = self:_surfaceAt(root)
		local multiplier = NOISE.SurfaceMultiplier[surface] or 1
		if surface == "Metal" then
			multiplier *= mapAcoustics().MetalCarry or 1
		end
		self:Emit(root.Position - Vector3.new(0, 2.5, 0), intensity * multiplier, kind, player)
	end
end

return NoiseService
