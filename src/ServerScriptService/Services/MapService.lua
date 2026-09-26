--[[
	MapService (ModuleScript)
	Location: ServerScriptService/Services/MapService

	Owns the two physical places of the game:
	  Workspace.ActiveMap  the investigation map (DEAD MALL), baked into the
	                       place file (assets/baked/DeadMall.rbxm) or built at
	                       runtime by ServerScriptService/World/DeadMall
	  Workspace.Lobby      the agency headquarters (World/LobbyHQ)

	In a Lobby-only server the map is removed, in a Gameplay-only server the
	lobby is removed (see MapConfig.Places). Everything else asks MapService
	for markers, zones, spawns, fixtures and light control. Lighting LOOK
	(presets, tint, lightning, flicker) is applied on each client by
	LightingController from the attributes MapService sets on the map.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local MapConfig = require(Config:WaitForChild("MapConfig"))

local World = ServerScriptService:WaitForChild("World")

local MapService = {}
MapService.Folders = {} :: { [string]: any }
MapService.LightRecords = {}
MapService.Tints = {}
MapService.Blackout = false
MapService.Role = "Combined"
MapService.MapId = "DeadMall"

local function ensureFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function MapService:Init()
	self.Role = MapConfig.GetPlaceRole(game.PlaceId)
	Workspace:SetAttribute("PlaceRole", self.Role)

	-- template leftovers
	if GameConfig.Map.RemoveBaseplate then
		local baseplate = Workspace:FindFirstChild("Baseplate")
		if baseplate and baseplate:IsA("BasePart") then
			baseplate:Destroy()
		end
	end
	for _, name in ipairs({ "Map", "AnomalySpawns" }) do
		local legacy = Workspace:FindFirstChild(name)
		if legacy and #legacy:GetChildren() == 0 then
			legacy:Destroy()
		end
	end

	-- investigation map
	local map = Workspace:FindFirstChild("ActiveMap")
	if self.Role ~= "Lobby" then
		if not map then
			local ok, result = pcall(function()
				return require(World:WaitForChild("DeadMall")).Build()
			end)
			if ok then
				map = result
				map.Parent = Workspace
				print("[MapService] Built the Dead Mall at runtime (bake it with tools/bake for faster starts)")
			else
				warn("[MapService] Could not build the Dead Mall:", result)
			end
		end
	elseif map then
		map:Destroy()
		map = nil
	end
	-- lobby HQ
	local lobby = Workspace:FindFirstChild("Lobby")
	if self.Role ~= "Gameplay" then
		if not lobby or #lobby:GetChildren() == 0 then
			if lobby then
				lobby:Destroy()
			end
			local ok, result = pcall(function()
				return require(World:WaitForChild("LobbyHQ")).Build()
			end)
			if ok then
				lobby = result
				lobby.Parent = Workspace
			else
				warn("[MapService] Could not build the lobby:", result)
			end
		end
	elseif lobby then
		lobby:Destroy()
		lobby = nil
	end

	self.Folders.Map = map
	self.Folders.Lobby = lobby
	self.Folders.ActiveAnomalies = ensureFolder(Workspace, "ActiveAnomalies")
	self.Folders.Decoys = ensureFolder(Workspace, "Decoys")
	self.Folders.RoundItems = ensureFolder(Workspace, "RoundItems")
	if map then
		self.MapId = map:GetAttribute("MapId") or "DeadMall"
		local nodes = map:FindFirstChild("AnomalyNodes")
		self.Folders.Spawns = nodes and nodes:FindFirstChild("Spawns")
		self.Folders.CeilingNodes = nodes and nodes:FindFirstChild("CeilingCrawlerNodes")
		self.Folders.Zones = map:FindFirstChild("Zones")
		self.Folders.PlayerSpawns = map:FindFirstChild("PlayerSpawns")
		self.Folders.PickupSpots = map:FindFirstChild("PickupSpots")
		self.Folders.Interactables = map:FindFirstChild("Interactables")
	end
	self:_ensureSpawnLocation()
	self:IndexLights()
end

function MapService:Start()
	-- nothing periodic: light flicker, TVs and escalators are animated on clients
end

-- Roblox needs a SpawnLocation; characters are then placed by CharacterService.
function MapService:_ensureSpawnLocation()
	for _, spawnLocation in ipairs(Workspace:GetDescendants()) do
		if spawnLocation:IsA("SpawnLocation") then
			if spawnLocation:GetAttribute("COCSpawn") then
				return
			end
			spawnLocation:Destroy()
		end
	end
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "COCSpawn"
	spawnLocation.Anchored = true
	spawnLocation.CanCollide = false
	spawnLocation.Transparency = 1
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Size = Vector3.new(6, 1, 6)
	spawnLocation.CFrame = self:GetLobbySpawnCFrame() - Vector3.new(0, 2.5, 0)
	spawnLocation:SetAttribute("COCSpawn", true)
	local decal = spawnLocation:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawnLocation.Parent = Workspace
end

---------------------------------------------------------------------------
-- lights (blackout / flicker) - the look itself is client side
---------------------------------------------------------------------------

function MapService:IndexLights()
	table.clear(self.LightRecords)
	local map = self.Folders.Map
	if not map then
		return
	end
	for _, panel in ipairs(CollectionService:GetTagged("MallLight")) do
		if panel:IsA("BasePart") and panel:IsDescendantOf(map) then
			local lights = {}
			for _, child in ipairs(panel:GetChildren()) do
				if child:IsA("Light") then
					table.insert(lights, child)
				end
			end
			table.insert(self.LightRecords, {
				Part = panel,
				Zone = panel:GetAttribute("Zone"),
				Lights = lights,
				Material = panel.Material,
				Color = panel.Color,
				On = #lights > 0,
				Override = nil :: boolean?,
			})
		end
	end
end

function MapService:ApplyLight(record)
	local on = record.On and not self.Blackout
	if record.Override ~= nil then
		on = record.Override and not self.Blackout
	end
	for _, light in ipairs(record.Lights) do
		light.Enabled = on
	end
	if record.On then
		record.Part.Material = if on then record.Material else Enum.Material.SmoothPlastic
		record.Part.Color = if on then record.Color else Color3.fromRGB(90, 90, 90)
	end
end

function MapService:GetZoneLights(zone: string)
	local list = {}
	for _, record in ipairs(self.LightRecords) do
		if record.Zone == zone then
			table.insert(list, record)
		end
	end
	return list
end

function MapService:GetLightsNear(position: Vector3, radius: number)
	local list = {}
	for _, record in ipairs(self.LightRecords) do
		if record.On and (record.Part.Position - position).Magnitude <= radius then
			table.insert(list, record)
		end
	end
	return list
end

function MapService:SetLightOverride(record, value: boolean?)
	record.Override = value
	self:ApplyLight(record)
end

function MapService:Flicker(zone: string, times: number)
	self:FlickerRecords(self:GetZoneLights(zone), times)
end

function MapService:FlickerRecords(records, times: number)
	task.spawn(function()
		for _ = 1, times do
			for _, record in ipairs(records) do
				self:SetLightOverride(record, false)
			end
			task.wait(math.random(6, 16) / 100)
			for _, record in ipairs(records) do
				self:SetLightOverride(record, nil)
			end
			task.wait(math.random(10, 35) / 100)
		end
	end)
end

function MapService:SetBlackout(enabled: boolean)
	self.Blackout = enabled
	for _, record in ipairs(self.LightRecords) do
		self:ApplyLight(record)
	end
	if self.Folders.Map then
		self.Folders.Map:SetAttribute("Blackout", enabled)
	end
end

-- Event tints (Surge purple, Night Manager red...) are applied by clients inside the map.
function MapService:PushTint(key: string, tint: Color3, saturation: number?, contrast: number?)
	self:PopTint(key, true)
	table.insert(self.Tints, { Key = key, Tint = tint, Saturation = saturation or 0, Contrast = contrast or 0 })
	self:ApplyTint()
end

function MapService:PopTint(key: string, silent: boolean?)
	for index = #self.Tints, 1, -1 do
		if self.Tints[index].Key == key then
			table.remove(self.Tints, index)
		end
	end
	if not silent then
		self:ApplyTint()
	end
end

function MapService:ApplyTint()
	local map = self.Folders.Map
	if not map then
		return
	end
	local top = self.Tints[#self.Tints]
	map:SetAttribute("TintColor", if top then top.Tint else nil)
	map:SetAttribute("TintSaturation", if top then top.Saturation else nil)
	map:SetAttribute("TintContrast", if top then top.Contrast else nil)
end

function MapService:Lightning()
	if self.Folders.Map then
		self.Folders.Map:SetAttribute("LightningAt", Workspace:GetServerTimeNow())
	end
end

---------------------------------------------------------------------------
-- markers, fixtures, zones, spawns
---------------------------------------------------------------------------

function MapService:GetMarkers(kinds: { string }?, zones: { string }?)
	local list = {}
	local folder = self.Folders.Spawns
	if not folder then
		return list
	end
	for _, marker in ipairs(folder:GetChildren()) do
		if marker:IsA("BasePart") then
			local kind = marker:GetAttribute("Kind")
			local zone = marker:GetAttribute("Zone")
			if (kinds == nil or table.find(kinds, kind) ~= nil) and (zones == nil or table.find(zones, zone) ~= nil) then
				table.insert(list, marker)
			end
		end
	end
	return list
end

function MapService:GetCeilingNodes(): { BasePart }
	local list = {}
	local folder = self.Folders.CeilingNodes
	if folder then
		for _, node in ipairs(folder:GetChildren()) do
			if node:IsA("BasePart") then
				table.insert(list, node)
			end
		end
	end
	return list
end

local function positionOf(instance: Instance): Vector3?
	if instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	return nil
end

function MapService:GetFixtures(tag: string, zones: { string }?)
	local list = {}
	local map = self.Folders.Map
	if not map then
		return list
	end
	for _, instance in ipairs(CollectionService:GetTagged(tag)) do
		if instance:IsDescendantOf(map) then
			local ok = zones == nil
			if not ok then
				local position = positionOf(instance)
				local zone = position and self:GetZoneAt(position)
				ok = zone ~= nil and table.find(zones :: { string }, zone) ~= nil
			end
			if ok then
				table.insert(list, instance)
			end
		end
	end
	return list
end

function MapService:GetZoneAt(position: Vector3): string?
	local zones = self.Folders.Zones
	if not zones then
		return nil
	end
	for _, bounds in ipairs(zones:GetChildren()) do
		if bounds:IsA("BasePart") then
			local localPoint = bounds.CFrame:PointToObjectSpace(position)
			local half = bounds.Size / 2
			if math.abs(localPoint.X) <= half.X and math.abs(localPoint.Z) <= half.Z and localPoint.Y >= -half.Y - 2 and localPoint.Y <= half.Y + 2 then
				return bounds.Name
			end
		end
	end
	return nil
end

function MapService:IsInMall(position: Vector3): boolean
	return self:GetZoneAt(position) ~= nil
end

function MapService:IsInLobby(position: Vector3): boolean
	local lobby = self.Folders.Lobby
	if not lobby then
		return false
	end
	local origin = (require(World:WaitForChild("LobbyHQ")) :: any).Origin
	local offset = position - origin
	return math.abs(offset.X) < 90 and offset.Z > -80 and offset.Z < 70 and offset.Y > -20 and offset.Y < 40
end

function MapService:GetMallSpawnCFrame(index: number?): CFrame
	local spawns = {}
	local folder = self.Folders.PlayerSpawns
	if folder then
		for _, spawnPart in ipairs(folder:GetChildren()) do
			if spawnPart:IsA("BasePart") then
				table.insert(spawns, spawnPart)
			end
		end
	end
	if #spawns == 0 then
		return CFrame.new(0, 4, -140)
	end
	local chosen = spawns[((index or math.random(1, #spawns)) - 1) % #spawns + 1]
	return chosen.CFrame + Vector3.new(0, 1.5, 0)
end

function MapService:GetLobbySpawnCFrame(): CFrame
	local lobby = self.Folders.Lobby or Workspace:FindFirstChild("Lobby")
	local spawns = {}
	if lobby then
		for _, spawnPart in ipairs(lobby:GetDescendants()) do
			if spawnPart:IsA("BasePart") and spawnPart:GetAttribute("Spawn") then
				table.insert(spawns, spawnPart)
			end
		end
	end
	if #spawns == 0 then
		-- gameplay-only server: players "arrive" at the mall entrance
		return self:GetMallSpawnCFrame()
	end
	local chosen = spawns[math.random(1, #spawns)]
	return CFrame.new(chosen.Position + Vector3.new(math.random(-2, 2), 3, math.random(-2, 2))) * CFrame.Angles(0, math.pi, 0)
end

function MapService:GetDarkRoomSpawnCFrame(): CFrame
	local origin = (require(World:WaitForChild("LobbyHQ")) :: any).Origin
	return CFrame.new(origin + Vector3.new(50, 3, -10)) * CFrame.Angles(0, math.rad(-90), 0)
end

function MapService:GetPickupSpots(kind: string)
	local list = {}
	local folder = self.Folders.PickupSpots
	if folder then
		for _, spot in ipairs(folder:GetChildren()) do
			if spot:IsA("BasePart") and spot:GetAttribute("Kind") == kind then
				table.insert(list, spot)
			end
		end
	end
	return list
end

function MapService:GetPlayersInMall(): { Player }
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and self:IsInMall(root.Position) then
			table.insert(list, player)
		end
	end
	return list
end

return MapService
