--[[
	LobbyService (ModuleScript)
	Location: ServerScriptService/Services/LobbyService

	The PARANORMAL INVESTIGATION AGENCY headquarters (Workspace.Lobby).

	  STATIONS     terminals tagged "LobbyStation" (attribute Station) get a
	               ProximityPrompt; using one opens its menu on the client
	               (Shop, Upgrades, Flashlight, Archive, Store, Settings,
	               Party, Invite).
	  QUEUE ZONES  parts tagged "MissionZone" (attribute MapId). Walk in to
	               queue, walk out to leave. The first investigator starts a
	               countdown (MapConfig.Queue.Countdown); a full zone or an
	               all-READY team launches sooner. The board above the zone
	               shows "[ DEAD MALL ] 3 / 6 INVESTIGATORS · STARTING IN 8".
	               When a party leader steps in, the party is pulled in too.
	  PARANORMAL   rare harmless events in HQ (flicker, a photo that changes,
	               a figure behind the glass). Clients render them.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local MapConfig = require(Config:WaitForChild("MapConfig"))
local Net = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"))

local LobbyService = {}
LobbyService.Zones = {} :: { any }
LobbyService.QueueOf = {} :: { [Player]: any }
LobbyService._lastSent = {} :: { [Player]: string }
LobbyService._toastTimes = {} :: { [string]: number }

local QUEUE = MapConfig.Queue

local STATION_ACTIONS = {
	Shop = "Browse equipment",
	Upgrades = "Upgrade camera",
	Flashlight = "Upgrade flashlight",
	Archive = "Open archive",
	Store = "Open supply store",
	Settings = "Settings",
	Party = "Party",
	Invite = "Invite friends",
}

local PARANORMAL = { "Flicker", "Photo", "Apparition", "Flicker", "Whisper", "Photo" }

local function now(): number
	return Workspace:GetServerTimeNow()
end

function LobbyService:Init(services)
	self.Services = services
	self.QueueRemote = Net.Event("QueueUpdate")
	self.ActionRemote = Net.Event("LobbyAction")
	self.AnnounceRemote = Net.Event("Announce")
	self.Lobby = services.MapService.Folders.Lobby

	for _, station in ipairs(CollectionService:GetTagged("LobbyStation")) do
		self:_setupStation(station)
	end
	CollectionService:GetInstanceAddedSignal("LobbyStation"):Connect(function(station)
		self:_setupStation(station)
	end)
	for _, zonePart in ipairs(CollectionService:GetTagged("MissionZone")) do
		self:_setupZone(zonePart)
	end

	Net.Event("MissionRequest").OnServerEvent:Connect(function(player, action)
		if action == "LeaveQueue" then
			self:LeaveQueue(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local zone = self.QueueOf[player]
		if zone then
			self:_removeMember(zone, player)
		end
		self._lastSent[player] = nil
	end)
end

function LobbyService:Start()
	if not self.Lobby then
		return -- gameplay-only server
	end
	task.spawn(function()
		while true do
			local ok, err = pcall(self._tick, self)
			if not ok then
				warn("[LobbyService] queue tick error:", err)
			end
			task.wait(QUEUE.CheckInterval)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(math.random(35, 80))
			self:_paranormal()
		end
	end)
end

---------------------------------------------------------------------------
-- Stations
---------------------------------------------------------------------------

function LobbyService:_setupStation(station: Instance)
	local stationName = station:GetAttribute("Station")
	if type(stationName) ~= "string" then
		return
	end
	local part = if station:IsA("Model") then station.PrimaryPart else station
	if not part or not part:IsA("BasePart") or part:FindFirstChild("StationPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StationPrompt"
	prompt.ActionText = STATION_ACTIONS[stationName] or "Use"
	prompt.ObjectText = station:GetAttribute("Title") or stationName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		if self.Services.MissionService:IsInvestigating(player) then
			return
		end
		self.ActionRemote:FireClient(player, stationName)
	end)
end

---------------------------------------------------------------------------
-- Queue zones
---------------------------------------------------------------------------

function LobbyService:_setupZone(zonePart: Instance)
	if not zonePart:IsA("BasePart") then
		return
	end
	local mapId = zonePart:GetAttribute("MapId")
	local map = MapConfig.Get(mapId)
	if not map then
		return
	end
	local board = nil
	for _, candidate in ipairs(CollectionService:GetTagged("MissionBoard")) do
		if candidate:GetAttribute("MapId") == mapId then
			board = candidate:FindFirstChild("QueueBoard")
		end
	end
	table.insert(self.Zones, {
		Part = zonePart,
		MapId = mapId,
		Map = map,
		Title = zonePart:GetAttribute("Title") or map.Name,
		Active = zonePart:GetAttribute("Active") ~= false and map.Available,
		Max = map.MaxPlayers or 6,
		Board = board,
		Members = {} :: { Player },
		EndsAt = 0,
		Cooldown = 0,
		LastBoard = "",
	})
end

local function insideZone(zonePart: BasePart, position: Vector3): boolean
	local localPoint = zonePart.CFrame:PointToObjectSpace(position)
	local half = zonePart.Size / 2
	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Z) <= half.Z and math.abs(localPoint.Y) <= half.Y + 2
end

function LobbyService:_eligible(player: Player): boolean
	local services = self.Services
	if services.MissionService:IsParticipant(player) then
		return false
	end
	if services.DarkRoomService.Inside[player] then
		return false
	end
	return services.DataService:IsClientReady(player)
end

function LobbyService:_rootOf(player: Player): BasePart?
	local root = self.Services.CharacterService:GetParts(player)
	return root
end

function LobbyService:_addMember(zone, player: Player)
	if table.find(zone.Members, player) then
		return
	end
	local previous = self.QueueOf[player]
	if previous and previous ~= zone then
		self:_removeMember(previous, player)
	end
	table.insert(zone.Members, player)
	self.QueueOf[player] = zone
	self.Services.AudioService:Play("UI.QueueJoin", nil, { Only = player })
	self.Services.PartyService:RefreshPlayer(player)
end

function LobbyService:_removeMember(zone, player: Player)
	local index = table.find(zone.Members, player)
	if index then
		table.remove(zone.Members, index)
	end
	if self.QueueOf[player] == zone then
		self.QueueOf[player] = nil
		if player:IsDescendantOf(Players) then
			self.QueueRemote:FireClient(player, nil)
			self._lastSent[player] = nil
			self.Services.PartyService:RefreshPlayer(player)
		end
	end
end

function LobbyService:_toastOnce(player: Player, key: string, text: string)
	local id = player.UserId .. key
	local t = os.clock()
	if self._toastTimes[id] and t - self._toastTimes[id] < 6 then
		return
	end
	self._toastTimes[id] = t
	self.AnnounceRemote:FireClient(player, { Kind = "Toast", Text = text, Color = Color3.fromRGB(255, 150, 120) })
end

-- The party leader stepped in: pull the rest of the party onto the pad.
function LobbyService:_pullParty(zone, leader: Player)
	local party = self.Services.PartyService:GetParty(leader)
	if party.Leader ~= leader or #party.Members <= 1 then
		return
	end
	local missing = {}
	for _, member in ipairs(party.Members) do
		if member ~= leader and not table.find(zone.Members, member) and self:_eligible(member) then
			table.insert(missing, member)
		end
	end
	if #missing == 0 then
		return
	end
	if #zone.Members + #missing > zone.Max then
		self:_toastOnce(leader, "partyfull", "⚠️ Not enough room in this queue for your whole party.")
		return
	end
	for index, member in ipairs(missing) do
		local offset = Vector3.new(((index % 3) - 1) * 3, 0, (math.floor(index / 3) - 0.5) * 3)
		self.Services.CharacterService:Teleport(member, CFrame.new(zone.Part.Position.X + offset.X, zone.Part.Position.Y - zone.Part.Size.Y / 2 + 0.5, zone.Part.Position.Z + offset.Z))
		self.AnnounceRemote:FireClient(member, { Kind = "Toast", Text = "👥 Your party leader is deploying to " .. zone.Title, Color = Color3.fromRGB(190, 200, 230) })
		self:_addMember(zone, member)
	end
end

function LobbyService:_tick()
	local t = now()
	for _, zone in ipairs(self.Zones) do
		-- who is standing inside?
		local inside = {}
		for _, player in ipairs(Players:GetPlayers()) do
			local root = self:_rootOf(player)
			if root and insideZone(zone.Part, root.Position) then
				if not zone.Active then
					self:_toastOnce(player, "inactive" .. zone.MapId, "🔒 " .. zone.Title .. " is not open yet. Try the DEAD MALL.")
				elseif self:_eligible(player) then
					inside[player] = true
				end
			end
		end
		for index = #zone.Members, 1, -1 do
			local member = zone.Members[index]
			if not inside[member] then
				self:_removeMember(zone, member)
			end
		end
		for _, player in ipairs(Players:GetPlayers()) do
			if inside[player] and not table.find(zone.Members, player) then
				if #zone.Members >= zone.Max then
					self:_toastOnce(player, "full" .. zone.MapId, "⚠️ This team is full (" .. zone.Max .. "/" .. zone.Max .. "). Wait for the next deployment.")
				else
					self:_addMember(zone, player)
					self:_pullParty(zone, player)
				end
			end
		end

		-- countdown
		local canLaunch, reason = self.Services.MissionService:CanLaunch()
		if #zone.Members == 0 or not canLaunch or t < zone.Cooldown then
			zone.EndsAt = 0
		else
			if zone.EndsAt == 0 then
				zone.EndsAt = t + (if RunService:IsStudio() then QUEUE.StudioCountdown else QUEUE.Countdown)
			end
			local allReady = true
			for _, member in ipairs(zone.Members) do
				if not self.Services.PartyService:IsReady(member) then
					allReady = false
					break
				end
			end
			if allReady then
				zone.EndsAt = math.min(zone.EndsAt, t + QUEUE.AllReadyCountdown)
			end
			if #zone.Members >= zone.Max then
				zone.EndsAt = math.min(zone.EndsAt, t + 2)
			end
			if t >= zone.EndsAt then
				self:_launch(zone)
			end
		end
		self:_updateBoard(zone, canLaunch, reason)
		self:_sendQueue(zone, canLaunch, reason)
	end
end

function LobbyService:_launch(zone)
	local team = table.clone(zone.Members)
	zone.EndsAt = 0
	zone.Cooldown = now() + 4
	local parties = {}
	local seen = {}
	for _, member in ipairs(team) do
		local party = self.Services.PartyService:GetParty(member)
		if not seen[party] and #party.Members > 1 then
			seen[party] = true
			local ids = {}
			for _, other in ipairs(party.Members) do
				table.insert(ids, other.UserId)
			end
			table.insert(parties, { LeaderId = party.Leader.UserId, Members = ids })
		end
	end
	for _, member in ipairs(team) do
		self:_removeMember(zone, member)
	end
	local ok, reason = self.Services.MissionService:Launch(zone.MapId, team, parties)
	if not ok then
		for _, member in ipairs(team) do
			self.AnnounceRemote:FireClient(member, { Kind = "Toast", Text = "⚠️ " .. tostring(reason), Color = Color3.fromRGB(255, 130, 110) })
		end
	end
end

function LobbyService:_status(zone, canLaunch: boolean, reason: string?): string
	if not zone.Active then
		return "COMING SOON"
	end
	if not canLaunch then
		local mission = self.Services.MissionService
		local left = math.max(0, math.ceil(mission.EndsAt - now()))
		return string.format("%s · %d:%02d", reason or "IN PROGRESS", left // 60, left % 60)
	end
	if zone.EndsAt > 0 then
		return string.format("STARTING IN %d", math.max(0, math.ceil(zone.EndsAt - now())))
	end
	return "STEP INSIDE THE MARKED AREA"
end

function LobbyService:_updateBoard(zone, canLaunch: boolean, reason: string?)
	local board = zone.Board
	if not board then
		return
	end
	local countText = if zone.Active then string.format("%d / %d INVESTIGATORS", #zone.Members, zone.Max) else "LOCKED"
	local statusText = self:_status(zone, canLaunch, reason)
	local key = countText .. "|" .. statusText
	if key == zone.LastBoard then
		return
	end
	zone.LastBoard = key
	local count = board:FindFirstChild("Line2")
	local status = board:FindFirstChild("Line3")
	if count and count:IsA("TextLabel") then
		count.Text = countText
	end
	if status and status:IsA("TextLabel") then
		status.Text = statusText
		status.TextColor3 = if zone.EndsAt > 0 then Color3.fromRGB(255, 90, 80) else Color3.fromRGB(200, 200, 205)
	end
end

function LobbyService:_sendQueue(zone, canLaunch: boolean, reason: string?)
	local names = {}
	for _, member in ipairs(zone.Members) do
		table.insert(names, member.DisplayName)
	end
	local payload = {
		MapId = zone.MapId,
		Title = zone.Title,
		Count = #zone.Members,
		Max = zone.Max,
		EndsAt = zone.EndsAt,
		Status = self:_status(zone, canLaunch, reason),
		Paused = not canLaunch,
		Names = names,
	}
	local key = string.format("%s|%d|%d|%s|%s", zone.MapId, payload.Count, math.floor(zone.EndsAt), payload.Status, table.concat(names, ","))
	for _, member in ipairs(zone.Members) do
		if self._lastSent[member] ~= key then
			self._lastSent[member] = key
			self.QueueRemote:FireClient(member, payload)
		end
	end
end

-- LEAVE QUEUE button: step the investigator out of the marked area.
function LobbyService:LeaveQueue(player: Player)
	local zone = self.QueueOf[player]
	if not zone then
		return
	end
	self:_removeMember(zone, player)
	-- step sideways, towards the aisle between the queue zones
	local part = zone.Part
	local centerX = 0
	for _, other in ipairs(self.Zones) do
		centerX += other.Part.Position.X / #self.Zones
	end
	local side = if part.Position.X <= centerX then 1 else -1
	local out = part.Position + Vector3.new(side * (part.Size.X / 2 + 3), -part.Size.Y / 2 + 0.5, 0)
	if #self.Zones == 1 then
		out = part.Position + Vector3.new(0, -part.Size.Y / 2 + 0.5, part.Size.Z / 2 + 4)
	end
	self.Services.CharacterService:Teleport(player, CFrame.new(out))
end

function LobbyService:GetQueueOf(player: Player): string?
	local zone = self.QueueOf[player]
	return zone and zone.MapId or nil
end

function LobbyService:OnReadyChanged(_player: Player)
	-- picked up on the next queue tick
end

---------------------------------------------------------------------------
-- Rare, harmless paranormal moments in HQ (rendered by LobbyController)
---------------------------------------------------------------------------

function LobbyService:_paranormal()
	local lobby = self.Lobby
	if not lobby or not lobby.Parent then
		return
	end
	local kind = PARANORMAL[math.random(1, #PARANORMAL)]
	lobby:SetAttribute("ParanormalSeed", math.random(1, 1e6))
	lobby:SetAttribute("ParanormalKind", kind)
	lobby:SetAttribute("ParanormalAt", now())
end

return LobbyService
