--[[
	DarkRoomService (ModuleScript)
	Location: ServerScriptService/Services/DarkRoomService

	The DARK ROOM is a small showcase room reached from the Lobby. It displays
	a player's rarest discoveries as framed evidence photos. There is one
	physical room: each client renders whichever player's collection it is
	currently inspecting, so any number of players can visit and browse each
	other's rooms at the same time with zero extra parts.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Config")
local AnomalyConfig = require(Config:WaitForChild("AnomalyConfig"))
local RarityConfig = require(Config:WaitForChild("RarityConfig"))
local Net = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"))

local DarkRoomService = {}
DarkRoomService.Inside = {}
DarkRoomService._lastRequest = {}

function DarkRoomService:Init(services)
	self.Services = services
	self.StateRemote = Net.Event("DarkRoomState")

	local function hookPrompt(tag: string, callback: (Player) -> ())
		local function connect(instance: Instance)
			local prompt = instance:FindFirstChildWhichIsA("ProximityPrompt", true)
			if not prompt and instance:IsA("BasePart") then
				local created = Instance.new("ProximityPrompt")
				created.ActionText = if tag == "DarkRoomEntrance" then "Enter" else "Leave"
				created.ObjectText = "Dark Room"
				created.MaxActivationDistance = 9
				created.RequiresLineOfSight = false
				created.Parent = instance
				prompt = created
			end
			if prompt then
				prompt.Triggered:Connect(callback)
			end
		end
		for _, instance in ipairs(CollectionService:GetTagged(tag)) do
			connect(instance)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(connect)
	end
	hookPrompt("DarkRoomEntrance", function(player)
		self:Enter(player)
	end)
	hookPrompt("DarkRoomExit", function(player)
		self:Leave(player)
	end)

	Net.Function("DarkRoomRequest").OnServerInvoke = function(player, action, argument)
		return self:_handleRequest(player, action, argument)
	end

	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			if self.Inside[player] then
				self.Inside[player] = nil
				self.StateRemote:FireClient(player, { Inside = false })
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		self.Inside[player] = nil
		self._lastRequest[player] = nil
	end)
end

function DarkRoomService:Enter(player: Player): (boolean, string?)
	if self.Services.MissionService:IsParticipant(player) then
		return false, "The Dark Room is at HQ. Finish the investigation first."
	end
	if not self.Services.MapService.Folders.Lobby then
		return false, "The Dark Room is at HQ."
	end
	if self.Inside[player] then
		return true
	end
	self.Services.CharacterService:Teleport(player, self.Services.MapService:GetDarkRoomSpawnCFrame())
	self.Inside[player] = true
	local data = self.Services.DataService:GetData(player)
	if data then
		data.DarkRoom.Visits = (data.DarkRoom.Visits or 0) + 1
	end
	self.StateRemote:FireClient(player, { Inside = true })
	return true
end

function DarkRoomService:Leave(player: Player)
	if not self.Inside[player] then
		return
	end
	self.Inside[player] = nil
	self.Services.CharacterService:Teleport(player, self.Services.MapService:GetLobbySpawnCFrame())
	self.StateRemote:FireClient(player, { Inside = false })
end

-- Deployment: the investigator is pulled into the map; just clear the state.
function DarkRoomService:Evict(player: Player)
	if self.Inside[player] then
		self.Inside[player] = nil
		if player:IsDescendantOf(Players) then
			self.StateRemote:FireClient(player, { Inside = false })
		end
	end
end

function DarkRoomService:GetShowcase(owner: Player)
	local dataService = self.Services.DataService
	local data = dataService:GetData(owner)
	if not data then
		return nil
	end
	local frames = dataService:GetDarkRoomFrames(owner)
	local entries = {}
	for id, discovery in pairs(data.Discoveries) do
		local def = AnomalyConfig.Get(id)
		if def and def.Enabled then
			table.insert(entries, {
				Id = id,
				Name = def.Name,
				Rarity = def.Rarity,
				Icon = def.Icon,
				Stars = discovery.BestStars or 1,
				Count = discovery.Count or 1,
				FirstFound = discovery.FirstFound or 0,
				Odds = AnomalyConfig.GetOddsText(id),
				Rank = RarityConfig.GetRank(def.Rarity),
				Weight = def.Weight,
			})
		end
	end
	table.sort(entries, function(a, b)
		if a.Rank ~= b.Rank then
			return a.Rank > b.Rank
		end
		if a.Weight ~= b.Weight then
			return a.Weight < b.Weight
		end
		return a.Stars > b.Stars
	end)
	local shown = {}
	for index = 1, math.min(frames, #entries) do
		shown[index] = entries[index]
	end
	local monetization = self.Services.MonetizationService
	return {
		UserId = owner.UserId,
		Name = owner.DisplayName,
		VIP = monetization and monetization:HasPass(owner, "VIPInvestigator") or false,
		Frames = frames,
		Entries = shown,
		Decor = (dataService:GetData(owner) :: any).Cosmetics.Decor or "Classic",
		Discovered = dataService:CountDiscoveries(owner),
		Total = AnomalyConfig.Count(),
	}
end

function DarkRoomService:_handleRequest(player: Player, action: any, argument: any)
	-- small token bucket: at most 8 requests per 2 seconds per player
	local t = os.clock()
	local window = self._lastRequest[player]
	if not window then
		window = {}
		self._lastRequest[player] = window
	end
	for index = #window, 1, -1 do
		if t - window[index] > 2 then
			table.remove(window, index)
		end
	end
	if #window >= 8 then
		return nil
	end
	table.insert(window, t)

	if action == "Enter" then
		local ok, message = self:Enter(player)
		return { Ok = ok, Message = message }
	elseif action == "Leave" then
		self:Leave(player)
		return { Ok = true }
	elseif action == "GetShowcase" then
		if type(argument) ~= "number" then
			return nil
		end
		local owner = Players:GetPlayerByUserId(argument)
		if not owner then
			return nil
		end
		return self:GetShowcase(owner)
	elseif action == "ListOwners" then
		local list = {}
		for _, other in ipairs(Players:GetPlayers()) do
			if self.Services.DataService:GetData(other) then
				table.insert(list, { UserId = other.UserId, Name = other.DisplayName })
			end
		end
		return list
	end
	return nil
end

return DarkRoomService
