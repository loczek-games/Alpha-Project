--[[
	MissionService (ModuleScript)
	Location: ServerScriptService/Services/MissionService

	One investigation ("mission") from deployment to the results screen.
	Replaces the old automatic round loop: missions now start from the
	physical queue zones in the lobby (LobbyService).

	  Lobby  -> Intro (black screen, case file, first person, equipment)
	         -> Round (investigate the map)
	         -> Results (awards) -> back to HQ

	Place roles (MapConfig.Places / MapService.Role):
	  Combined  lobby + map in one server. One mission at a time; the queued
	            investigators are moved into the map, everyone else stays in HQ.
	  Lobby     the queue reserves a private Gameplay server and teleports the
	            whole team (parties stay together) with TeleportService.
	  Gameplay  waits for the team to arrive, runs the mission, then sends
	            everyone back to the lobby place.

	The public API (State, EndsAt, IsParticipant, GetParticipants,
	RecordCapture, ForceStart, ForceEnd) is what the rest of the game uses.
]]

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local MapConfig = require(Config:WaitForChild("MapConfig"))
local RarityConfig = require(Config:WaitForChild("RarityConfig"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Net = require(Modules:WaitForChild("Net"))
local Format = require(Modules:WaitForChild("Format"))

local MissionService = {}
MissionService.State = "Lobby" -- Lobby | Intro | Round | Results
MissionService.EndsAt = 0
MissionService.RoundNumber = 0
MissionService.MapId = "DeadMall"
MissionService.Participants = {} :: { [Player]: boolean }
MissionService.Stats = {}
MissionService.EndRequested = false
MissionService.Role = "Combined"

local MISSION = MapConfig.Mission
local MISSION_STORE = "COC_Missions_v1"

local function now(): number
	return Workspace:GetServerTimeNow()
end

function MissionService:Init(services)
	self.Services = services
	self.Role = services.MapService.Role
	self.RoundRemote = Net.Event("RoundUpdate")
	self.ResultsRemote = Net.Event("RoundResults")
	self.AnnounceRemote = Net.Event("Announce")
	self.IntroRemote = Net.Event("MissionIntro")

	services.DataService:OnClientReady(function(player)
		self.RoundRemote:FireClient(player, self:_payloadFor(player))
	end)

	Net.Event("MissionRequest").OnServerEvent:Connect(function(player, action)
		if action == "Leave" then
			self:LeaveMission(player)
		end
	end)

	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			local root = character:WaitForChild("HumanoidRootPart", 10)
			if not root then
				return
			end
			task.wait(0.1)
			if self.Participants[player] and (self.State == "Intro" or self.State == "Round") then
				-- respawned during a mission: back into the map, still in first person
				services.CharacterService:SetMissionMode(player, true)
				if self.State == "Round" then
					services.CharacterService:Teleport(player, services.MapService:GetMallSpawnCFrame())
				end
			else
				services.CharacterService:SetMissionMode(player, false)
				services.CharacterService:Teleport(player, services.MapService:GetLobbySpawnCFrame())
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		self.Participants[player] = nil
		local stats = self.Stats[player.UserId]
		if stats then
			stats.Left = true
		end
	end)
end

function MissionService:Start()
	if self.Role == "Gameplay" then
		self:_gameplayServerLoop()
	end
end

---------------------------------------------------------------------------
-- Launching (called by LobbyService when a queue zone fills / its timer ends)
---------------------------------------------------------------------------

function MissionService:CanLaunch(): (boolean, string?)
	if self.Role == "Lobby" then
		return true
	end
	if self.State ~= "Lobby" then
		return false, "INVESTIGATION IN PROGRESS"
	end
	return true
end

-- team: players standing in the queue zone. parties: { { LeaderId, Members = { userIds } } }
function MissionService:Launch(mapId: string, team: { Player }, parties: { any }?): (boolean, string?)
	local map = MapConfig.Get(mapId)
	if not map or not map.Available then
		return false, "This location is not available yet"
	end
	local valid = {}
	for _, player in ipairs(team) do
		if player:IsDescendantOf(Players) and not self.Participants[player] then
			table.insert(valid, player)
		end
	end
	if #valid == 0 then
		return false, "Nobody to deploy"
	end
	if self.Role == "Lobby" then
		task.spawn(function()
			self:_teleportTeam(mapId, valid, parties or {})
		end)
		return true
	end
	local ok, reason = self:CanLaunch()
	if not ok then
		return false, reason
	end
	self.State = "Intro" -- claim the map right away
	task.spawn(function()
		local success, err = pcall(self._runMission, self, mapId, valid)
		if not success then
			warn("[MissionService] mission failed:", err)
			self:_abort()
		end
	end)
	return true
end

function MissionService:_introPayload(mapId: string, kind: string, duration: number)
	local map = MapConfig.Get(mapId) or MapConfig.Maps.DeadMall
	local tips = map.Tips or {}
	return {
		Kind = kind, -- "Deploy" | "Return" | "Teleport"
		MapId = mapId,
		Name = map.Name,
		Case = map.Case,
		Location = map.Location,
		Status = map.Status,
		LastActivity = map.LastActivity,
		Danger = map.Danger,
		Tip = if #tips > 0 then tips[math.random(1, #tips)] else nil,
		Duration = duration,
	}
end

---------------------------------------------------------------------------
-- Lobby place: reserved gameplay server per team
---------------------------------------------------------------------------

function MissionService:_teleportTeam(mapId: string, team: { Player }, parties: { any })
	local placeId = MapConfig.Places.GameplayPlaceId
	for _, player in ipairs(team) do
		self.IntroRemote:FireClient(player, self:_introPayload(mapId, "Teleport", 12))
	end
	local reserved, code, privateId = false, nil, nil
	for attempt = 1, MapConfig.Queue.TeleportRetries do
		local ok, a, b = pcall(TeleportService.ReserveServer, TeleportService, placeId)
		if ok then
			reserved, code, privateId = true, a, b
			break
		end
		warn(string.format("[MissionService] ReserveServer failed (%d): %s", attempt, tostring(a)))
		task.wait(1.5 * attempt)
	end
	if not reserved then
		self:_teleportFailed(team, "Could not reserve a server. Try again.")
		return
	end
	local userIds = {}
	for _, player in ipairs(team) do
		table.insert(userIds, player.UserId)
	end
	local info = { MapId = mapId, Team = userIds, Parties = parties, CreatedAt = os.time() }
	pcall(function()
		MemoryStoreService:GetHashMap(MISSION_STORE):SetAsync(privateId, info, 3600)
	end)
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code
	options:SetTeleportData(info)
	-- save progress now so the gameplay server loads the newest data
	for _, player in ipairs(team) do
		task.spawn(function()
			self.Services.DataService:SaveNow(player)
		end)
	end
	for attempt = 1, MapConfig.Queue.TeleportRetries do
		local stillHere = {}
		for _, player in ipairs(team) do
			if player:IsDescendantOf(Players) then
				table.insert(stillHere, player)
			end
		end
		if #stillHere == 0 then
			return
		end
		local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, placeId, stillHere, options)
		if ok then
			return
		end
		warn(string.format("[MissionService] TeleportAsync failed (%d): %s", attempt, tostring(err)))
		task.wait(2 * attempt)
	end
	self:_teleportFailed(team, "Teleport failed. You are still at HQ - step into the zone again.")
end

function MissionService:_teleportFailed(team: { Player }, message: string)
	for _, player in ipairs(team) do
		if player:IsDescendantOf(Players) then
			self.IntroRemote:FireClient(player, { Kind = "Cancel" })
			self.AnnounceRemote:FireClient(player, { Kind = "Toast", Text = "⚠️ " .. message, Color = Color3.fromRGB(255, 120, 110) })
		end
	end
end

---------------------------------------------------------------------------
-- Gameplay place: wait for the team, investigate, go home
---------------------------------------------------------------------------

function MissionService:_readMissionInfo(player: Player)
	local info = nil
	if game.PrivateServerId ~= "" then
		pcall(function()
			info = MemoryStoreService:GetHashMap(MISSION_STORE):GetAsync(game.PrivateServerId)
		end)
	end
	if type(info) ~= "table" then
		local ok, joinData = pcall(function()
			return player:GetJoinData()
		end)
		local data = ok and joinData and joinData.TeleportData
		if type(data) == "table" then
			info = data
		end
	end
	return if type(info) == "table" then info else {}
end

function MissionService:_gameplayServerLoop()
	while true do
		while #Players:GetPlayers() == 0 do
			task.wait(0.5)
		end
		local first = Players:GetPlayers()[1]
		local info = self:_readMissionInfo(first)
		local mapId = if type(info.MapId) == "string" and MapConfig.Get(info.MapId) then info.MapId else "DeadMall"
		local expected = if type(info.Team) == "table" then info.Team else {}
		self.Services.PartyService:RestoreParties(info.Parties)
		-- wait for the whole team (or the timeout)
		local deadline = os.clock() + MISSION.ArrivalTimeout
		while os.clock() < deadline do
			local missing = 0
			for _, userId in ipairs(expected) do
				local player = Players:GetPlayerByUserId(userId)
				if not player or not self.Services.DataService:IsClientReady(player) then
					missing += 1
				end
			end
			if missing == 0 then
				break
			end
			task.wait(0.5)
		end
		local team = Players:GetPlayers()
		if #team == 0 then
			continue
		end
		self.State = "Intro"
		local ok, err = pcall(self._runMission, self, mapId, team)
		if not ok then
			warn("[MissionService] mission failed:", err)
			self:_abort()
		end
		self:_sendEveryoneHome()
		task.wait(5)
	end
end

function MissionService:_sendEveryoneHome()
	local lobbyId = MapConfig.Places.LobbyPlaceId
	local players = Players:GetPlayers()
	if lobbyId == 0 or #players == 0 then
		return
	end
	for _, player in ipairs(players) do
		self.IntroRemote:FireClient(player, self:_introPayload(self.MapId, "Teleport", 12))
		task.spawn(function()
			self.Services.DataService:SaveNow(player)
		end)
	end
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({ Parties = self.Services.PartyService:ExportParties(), FromMission = true })
	for attempt = 1, MapConfig.Queue.TeleportRetries do
		local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, lobbyId, Players:GetPlayers(), options)
		if ok then
			return
		end
		warn(string.format("[MissionService] return teleport failed (%d): %s", attempt, tostring(err)))
		task.wait(3 * attempt)
	end
end

---------------------------------------------------------------------------
-- The mission itself (Combined + Gameplay)
---------------------------------------------------------------------------

function MissionService:_runMission(mapId: string, team: { Player })
	local services = self.Services
	self.MapId = mapId
	self.RoundNumber += 1
	self.Participants = {}
	self.Stats = {}
	self.EndRequested = false
	self.State = "Intro"
	self.EndsAt = now() + MISSION.IntroTime
	for _, player in ipairs(team) do
		self:AddParticipant(player)
		self.IntroRemote:FireClient(player, self:_introPayload(mapId, "Deploy", MISSION.IntroTime))
	end
	self:_broadcast()

	services.EquipmentService:ResetForRound(team)
	services.InteractionService:ResetForRound()
	task.wait(1.1) -- screens are black now

	for index, player in ipairs(team) do
		if player:IsDescendantOf(Players) then
			services.DarkRoomService:Evict(player)
			services.CharacterService:SetMissionMode(player, true)
			services.CharacterService:Teleport(player, services.MapService:GetMallSpawnCFrame(index))
		end
	end
	while now() < self.EndsAt do
		task.wait(0.1)
	end

	self.State = "Round"
	self.EndsAt = now() + MISSION.RoundTime
	services.EventService:StartRound()
	services.AnomalyService:StartRound()
	services.EnvironmentService:StartRound()
	self:_broadcast()

	local lastCheck = 0
	while now() < self.EndsAt and not self.EndRequested do
		task.wait(0.25)
		if os.clock() - lastCheck > 2 then
			lastCheck = os.clock()
			if #self:GetParticipants() == 0 then
				break -- everybody left
			end
		end
	end
	self.EndRequested = false
	self:_finish()
end

function MissionService:_finish()
	local services = self.Services
	services.EnvironmentService:StopRound()
	services.EventService:StopRound()
	services.AnomalyService:StopRound()
	services.InteractionService:EndRound()

	self.State = "Results"
	self.EndsAt = now() + MISSION.ResultsTime
	local team = self:GetParticipants()
	local awards, personal = self:_computeResults()

	for _, player in ipairs(team) do
		services.DataService:IncrementStat(player, "RoundsPlayed")
		services.CharacterService:Revive(player, nil, true)
	end

	if self.Role == "Gameplay" and MapConfig.Places.LobbyPlaceId ~= 0 then
		-- results are shown inside the map, then everybody flies home together
		self:_broadcast()
		for _, player in ipairs(team) do
			self.ResultsRemote:FireClient(player, { RoundNumber = self.RoundNumber, MapId = self.MapId, Awards = awards, Personal = personal[player.UserId] })
		end
		while now() < self.EndsAt do
			task.wait(0.25)
		end
		self.Participants = {}
		return
	end

	-- Combined (and a Gameplay place without a lobby): fade out, back to HQ, results there
	for _, player in ipairs(team) do
		self.IntroRemote:FireClient(player, self:_introPayload(self.MapId, "Return", 1.6))
	end
	task.wait(0.9)
	for _, player in ipairs(team) do
		if player:IsDescendantOf(Players) then
			services.CharacterService:SetMissionMode(player, false)
			services.CharacterService:Teleport(player, services.MapService:GetLobbySpawnCFrame())
		end
	end
	self.Participants = {}
	if self.Role == "Gameplay" then
		-- no lobby place configured: keep investigating in a loop
		self.State = "Results"
	else
		self.State = "Lobby"
		self.EndsAt = 0
	end
	self:_broadcast()
	task.wait(0.4)
	for _, player in ipairs(team) do
		if player:IsDescendantOf(Players) then
			self.ResultsRemote:FireClient(player, { RoundNumber = self.RoundNumber, MapId = self.MapId, Awards = awards, Personal = personal[player.UserId] })
		end
	end
	if self.Role == "Gameplay" then
		task.wait(MISSION.ResultsTime)
	end
end

-- Something went wrong mid-mission: make sure nobody is stuck in the map.
function MissionService:_abort()
	local services = self.Services
	pcall(function()
		services.EnvironmentService:StopRound()
		services.EventService:StopRound()
		services.AnomalyService:StopRound()
		services.InteractionService:EndRound()
	end)
	for player in pairs(self.Participants) do
		if player:IsDescendantOf(Players) then
			services.CharacterService:SetMissionMode(player, false)
			services.CharacterService:Teleport(player, services.MapService:GetLobbySpawnCFrame())
			self.IntroRemote:FireClient(player, { Kind = "Cancel" })
		end
	end
	self.Participants = {}
	self.State = "Lobby"
	self.EndsAt = 0
	self:_broadcast()
end

-- A single investigator walks out (menu button).
function MissionService:LeaveMission(player: Player)
	if not self.Participants[player] or self.State ~= "Round" then
		return
	end
	if self.Role == "Gameplay" and MapConfig.Places.LobbyPlaceId ~= 0 then
		self.Participants[player] = nil
		self.IntroRemote:FireClient(player, self:_introPayload(self.MapId, "Teleport", 10))
		task.spawn(function()
			self.Services.DataService:SaveNow(player)
			pcall(TeleportService.TeleportAsync, TeleportService, MapConfig.Places.LobbyPlaceId, { player })
		end)
		return
	end
	self.Participants[player] = nil
	local stats = self.Stats[player.UserId]
	if stats then
		stats.Left = true
	end
	self.IntroRemote:FireClient(player, self:_introPayload(self.MapId, "Return", 1.4))
	task.delay(0.8, function()
		if player:IsDescendantOf(Players) then
			self.Services.CharacterService:Revive(player, nil, true)
			self.Services.CharacterService:SetMissionMode(player, false)
			self.Services.CharacterService:Teleport(player, self.Services.MapService:GetLobbySpawnCFrame())
			self.RoundRemote:FireClient(player, self:_payloadFor(player))
		end
	end)
end

---------------------------------------------------------------------------
-- Participants + stats
---------------------------------------------------------------------------

function MissionService:AddParticipant(player: Player)
	self.Participants[player] = true
	if not self.Stats[player.UserId] then
		self.Stats[player.UserId] = {
			Name = player.DisplayName,
			Evidence = 0,
			Captures = 0,
			NewDiscoveries = 0,
			Groups = 0,
			Firsts = 0,
			BestStars = 0,
			BestStarsRank = 0,
			BestStarsName = nil,
			RarestRank = 0,
			RarestWeight = math.huge,
			RarestName = nil,
			RarestRarity = nil,
			Downs = 0,
			Revives = 0,
			Left = false,
		}
	end
end

function MissionService:IsParticipant(player: Player): boolean
	return self.Participants[player] == true
end

-- Investigating right now (in the map, mission running)?
function MissionService:IsInvestigating(player: Player): boolean
	return self.State == "Round" and self.Participants[player] == true
end

function MissionService:GetParticipants(): { Player }
	local list = {}
	for player in pairs(self.Participants) do
		if player:IsDescendantOf(Players) then
			table.insert(list, player)
		end
	end
	return list
end

function MissionService:RecordCapture(player: Player, info)
	local stats = self.Stats[player.UserId]
	if not stats then
		return
	end
	local def = info.Def
	local rank = RarityConfig.GetRank(def.Rarity)
	stats.Evidence += info.Reward
	stats.Captures += 1
	if info.IsNew then
		stats.NewDiscoveries += 1
	end
	if info.Group > 0 then
		stats.Groups += 1
	end
	if info.First then
		stats.Firsts += 1
	end
	if rank > stats.RarestRank or (rank == stats.RarestRank and def.Weight < stats.RarestWeight) then
		stats.RarestRank = rank
		stats.RarestWeight = def.Weight
		stats.RarestName = def.Name
		stats.RarestRarity = def.Rarity
	end
	if info.Stars > stats.BestStars or (info.Stars == stats.BestStars and rank > stats.BestStarsRank) then
		stats.BestStars = info.Stars
		stats.BestStarsRank = rank
		stats.BestStarsName = def.Name
	end
end

function MissionService:RecordStat(player: Player, key: string, amount: number?)
	local stats = self.Stats[player.UserId]
	if stats and type(stats[key]) == "number" then
		stats[key] += amount or 1
	end
end

function MissionService:_computeResults()
	local entries = {}
	for userId, stats in pairs(self.Stats) do
		if not stats.Left then
			table.insert(entries, { UserId = userId, Stats = stats })
		end
	end

	local winners = {}
	local function award(title: string, icon: string, score: (any) -> number, describe: (any) -> string, color: Color3?)
		local bestScore, bestEntries = 0, {}
		for _, entry in ipairs(entries) do
			local value = score(entry.Stats)
			if value > bestScore then
				bestScore, bestEntries = value, { entry }
			elseif value == bestScore and value > 0 then
				table.insert(bestEntries, entry)
			end
		end
		if bestScore <= 0 or #bestEntries == 0 then
			return nil
		end
		local names = bestEntries[1].Stats.Name
		if #bestEntries > 1 then
			names ..= string.format(" +%d", #bestEntries - 1)
		end
		for _, entry in ipairs(bestEntries) do
			winners[entry.UserId] = winners[entry.UserId] or {}
			table.insert(winners[entry.UserId], title)
		end
		return {
			Title = title,
			Icon = icon,
			Winner = names,
			Value = describe(bestEntries[1].Stats),
			Color = color,
		}
	end

	local awards = {}
	local function add(result)
		if result then
			table.insert(awards, result)
		end
	end
	add(award("MOST EVIDENCE", "💰", function(s)
		return s.Evidence
	end, function(s)
		return "+" .. Format.Money(s.Evidence)
	end, Color3.fromRGB(120, 230, 140)))
	add(award("RAREST DISCOVERY", "👁️", function(s)
		if s.RarestRank == 0 then
			return 0
		end
		return s.RarestRank * 1e6 + (1e6 - math.min(s.RarestWeight * 1000, 999999))
	end, function(s)
		return string.format("%s (%s)", s.RarestName or "?", RarityConfig.GetDisplayName(s.RarestRarity or "Common"))
	end, Color3.fromRGB(185, 95, 255)))
	add(award("BEST PHOTO", "⭐", function(s)
		return s.BestStars * 100 + s.BestStarsRank
	end, function(s)
		return string.format("%s %s", Format.Stars(s.BestStars), s.BestStarsName or "")
	end, Color3.fromRGB(255, 215, 60)))
	add(award("MOST PHOTOS TAKEN", "📸", function(s)
		return s.Captures
	end, function(s)
		return string.format("%d photos", s.Captures)
	end, Color3.fromRGB(80, 165, 255)))
	add(award("MOST NEW DISCOVERIES", "📖", function(s)
		return s.NewDiscoveries
	end, function(s)
		return string.format("%d new", s.NewDiscoveries)
	end, Color3.fromRGB(255, 95, 175)))
	add(award("GROUP PHOTOGRAPHER", "👥", function(s)
		return s.Groups
	end, function(s)
		return string.format("%d group photos", s.Groups)
	end, Color3.fromRGB(255, 170, 60)))
	add(award("FIELD MEDIC", "🩹", function(s)
		return s.Revives
	end, function(s)
		return string.format("%d revives", s.Revives)
	end, Color3.fromRGB(110, 220, 255)))

	local personal = {}
	for _, entry in ipairs(entries) do
		local s = entry.Stats
		local highlights = {}
		for _, title in ipairs(winners[entry.UserId] or {}) do
			table.insert(highlights, "🏆 You won " .. title .. "!")
		end
		if s.NewDiscoveries > 0 then
			table.insert(highlights, string.format("📖 %d new archive %s!", s.NewDiscoveries, s.NewDiscoveries == 1 and "entry" or "entries"))
		end
		if s.BestStars >= 5 then
			table.insert(highlights, "⭐ You took a perfect 5-star photo!")
		end
		if s.Groups > 0 then
			table.insert(highlights, string.format("👥 %d group %s", s.Groups, s.Groups == 1 and "photo" or "photos"))
		end
		if s.Firsts > 0 then
			table.insert(highlights, string.format("⚡ First on the scene %d %s", s.Firsts, s.Firsts == 1 and "time" or "times"))
		end
		if s.Downs > 0 then
			table.insert(highlights, string.format("🩸 Attacked %d %s", s.Downs, s.Downs == 1 and "time" or "times"))
		end
		if #highlights == 0 then
			table.insert(highlights, "🔦 Rarer anomalies hide in dark corners. Keep looking!")
		end
		personal[entry.UserId] = {
			Evidence = s.Evidence,
			Captures = s.Captures,
			NewDiscoveries = s.NewDiscoveries,
			BestStars = s.BestStars,
			BestName = s.BestStarsName,
			RarestName = s.RarestName,
			RarestRarity = s.RarestRarity,
			Highlights = highlights,
		}
	end
	return awards, personal
end

---------------------------------------------------------------------------
-- Networking + admin
---------------------------------------------------------------------------

function MissionService:_payloadFor(player: Player)
	return {
		State = self.State,
		EndsAt = self.EndsAt,
		RoundNumber = self.RoundNumber,
		MapId = self.MapId,
		Participant = self.Participants[player] == true,
		Role = self.Role,
	}
end

function MissionService:_broadcast()
	for _, player in ipairs(Players:GetPlayers()) do
		self.RoundRemote:FireClient(player, self:_payloadFor(player))
	end
end

-- /round start: deploy everyone who is in the lobby right now.
function MissionService:ForceStart(): (boolean, string?)
	local team = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if not self.Participants[player] then
			table.insert(team, player)
		end
	end
	return self:Launch("DeadMall", team, self.Services.PartyService:ExportParties())
end

function MissionService:ForceEnd()
	if self.State == "Round" then
		self.EndRequested = true
	end
end

function MissionService:IsStudio(): boolean
	return RunService:IsStudio()
end

return MissionService
