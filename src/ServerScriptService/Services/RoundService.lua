--[[
	RoundService (ModuleScript)
	Location: ServerScriptService/Services/RoundService

	Game loop:  Lobby countdown -> 8 minute exploration round -> Results -> repeat
	Tracks per-round stats and hands out several awards (not one winner) so
	many players have a reason to feel successful.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local RarityConfig = require(Config:WaitForChild("RarityConfig"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Net = require(Modules:WaitForChild("Net"))
local Format = require(Modules:WaitForChild("Format"))

local RoundService = {}
RoundService.State = "Intermission"
RoundService.EndsAt = 0
RoundService.RoundNumber = 0
RoundService.Waiting = false
RoundService.Participants = {}
RoundService.Stats = {}
RoundService.SkipRequested = false
RoundService.EndRequested = false

local ROUND = GameConfig.Round

local function now(): number
	return Workspace:GetServerTimeNow()
end

function RoundService:Init(services)
	self.Services = services
	self.RoundRemote = Net.Event("RoundUpdate")
	self.ResultsRemote = Net.Event("RoundResults")
	self.AnnounceRemote = Net.Event("Announce")

	services.DataService:OnClientReady(function(player)
		self.RoundRemote:FireClient(player, self:_payload())
	end)

	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			if self.State ~= "Round" then
				return
			end
			self:AddParticipant(player)
			local root = character:WaitForChild("HumanoidRootPart", 10)
			if root and self.State == "Round" then
				task.wait(0.1)
				services.CharacterService:Teleport(player, services.MapService:GetMallSpawnCFrame())
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

function RoundService:Start()
	-- Each phase is protected so one unexpected error can never stop the game loop.
	local phases = { "_intermission", "_round", "_results" }
	while true do
		for _, phase in ipairs(phases) do
			local ok, err = pcall(self[phase], self)
			if not ok then
				warn(string.format("[RoundService] %s failed: %s", phase, tostring(err)))
				task.wait(1)
			end
		end
	end
end

---------------------------------------------------------------------------
-- Phases
---------------------------------------------------------------------------

function RoundService:_intermission()
	self.State = "Intermission"
	local duration = if RunService:IsStudio() then ROUND.StudioIntermissionTime else ROUND.IntermissionTime
	while #Players:GetPlayers() < ROUND.MinPlayers do
		self.Waiting = true
		self.EndsAt = 0
		self:_broadcast()
		task.wait(1)
	end
	self.Waiting = false
	self.EndsAt = now() + duration
	self:_broadcast()
	while now() < self.EndsAt and not self.SkipRequested do
		task.wait(0.25)
	end
	self.SkipRequested = false
end

function RoundService:_round()
	local services = self.Services
	self.RoundNumber += 1
	self.State = "Round"
	self.EndsAt = now() + ROUND.RoundTime
	self.Participants = {}
	self.Stats = {}
	self.EndRequested = false

	services.DarkRoomService:EvictAll()
	for _, player in ipairs(Players:GetPlayers()) do
		self:AddParticipant(player)
		if player.Character then
			services.CharacterService:Teleport(player, services.MapService:GetMallSpawnCFrame())
		end
	end

	task.spawn(function()
		services.NPCService:SpawnAll()
	end)
	services.EventService:StartRound()
	services.AnomalyService:StartRound()
	self:_broadcast()

	self.AnnounceRemote:FireAllClients({
		Kind = "Banner",
		Text = "📸 THE DEAD MALL IS OPEN",
		SubText = "Find something WRONG. Take a PHOTO.",
		Color = Color3.fromRGB(255, 90, 90),
		Duration = 3.5,
	})

	while now() < self.EndsAt and not self.EndRequested do
		task.wait(0.25)
	end
	self.EndRequested = false
end

function RoundService:_results()
	local services = self.Services
	services.EventService:StopRound()
	services.AnomalyService:StopRound()
	services.NPCService:DespawnAll()

	self.State = "Results"
	self.EndsAt = now() + ROUND.ResultsTime
	self:_broadcast()

	local awards, personal = self:_computeResults()
	for _, player in ipairs(Players:GetPlayers()) do
		if self.Participants[player] then
			services.DataService:IncrementStat(player, "RoundsPlayed")
		end
		services.CharacterService:Teleport(player, services.MapService:GetLobbySpawnCFrame())
		self.ResultsRemote:FireClient(player, {
			RoundNumber = self.RoundNumber,
			Awards = awards,
			Personal = personal[player.UserId],
		})
	end
	self.Participants = {}

	while now() < self.EndsAt do
		task.wait(0.25)
	end
end

---------------------------------------------------------------------------
-- Participants + stats
---------------------------------------------------------------------------

function RoundService:AddParticipant(player: Player)
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
			Left = false,
		}
	end
end

function RoundService:IsParticipant(player: Player): boolean
	return self.Participants[player] == true
end

function RoundService:GetParticipants(): { Player }
	local list = {}
	for player in pairs(self.Participants) do
		if player:IsDescendantOf(Players) then
			table.insert(list, player)
		end
	end
	return list
end

function RoundService:RecordCapture(player: Player, info)
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

function RoundService:_computeResults()
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

	local personal = {}
	for _, entry in ipairs(entries) do
		local s = entry.Stats
		local highlights = {}
		for _, title in ipairs(winners[entry.UserId] or {}) do
			table.insert(highlights, "🏆 You won " .. title .. "!")
		end
		if s.NewDiscoveries > 0 then
			table.insert(highlights, string.format("📖 %d new album %s!", s.NewDiscoveries, s.NewDiscoveries == 1 and "entry" or "entries"))
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

function RoundService:_payload()
	return {
		State = self.State,
		EndsAt = self.EndsAt,
		RoundNumber = self.RoundNumber,
		Waiting = self.Waiting,
		MinPlayers = ROUND.MinPlayers,
	}
end

function RoundService:_broadcast()
	self.RoundRemote:FireAllClients(self:_payload())
end

function RoundService:ForceStart()
	if self.State == "Intermission" then
		self.SkipRequested = true
	end
end

function RoundService:ForceEnd()
	if self.State == "Round" then
		self.EndRequested = true
	end
end

return RoundService
