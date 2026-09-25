--[[
	AdminService (ModuleScript)
	Location: ServerScriptService/Services/AdminService

	Chat commands for testing. Allowed for everyone inside Studio play tests,
	for the game creator, and for GameConfig.Admin.UserIds in live servers.
	All checks happen on the server.

	  /spawn <AnomalyId>      force-spawn an anomaly (round must be running)
	  /event <surge|blackout|falsealarm|rare>
	  /round <start|end>
	  /evidence <amount>
	  /anomalies              print every anomaly id to the output
	  /resetdata              wipe your own save (Studio only)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Config = ReplicatedStorage:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local AnomalyConfig = require(Config:WaitForChild("AnomalyConfig"))
local Net = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"))

local AdminService = {}
AdminService._recent = {}

local EVENT_ALIASES = {
	surge = "Surge",
	blackout = "Blackout",
	falsealarm = "FalseAlarm",
	false_alarm = "FalseAlarm",
	rare = "RareAnomaly",
	rareanomaly = "RareAnomaly",
}

function AdminService:Init(services)
	self.Services = services
	self.AnnounceRemote = Net.Event("Announce")

	-- TextChatService commands (default chat for new experiences)
	local ok, err = pcall(function()
		local folder = Instance.new("Folder")
		folder.Name = "CaughtOnCameraCommands"
		for _, name in ipairs({ "spawn", "event", "round", "evidence", "anomalies", "resetdata" }) do
			local command = Instance.new("TextChatCommand")
			command.Name = "COC_" .. name
			command.PrimaryAlias = "/" .. name
			command.Triggered:Connect(function(textSource, message)
				local player = Players:GetPlayerByUserId(textSource.UserId)
				if player then
					self:_run(player, message)
				end
			end)
			command.Parent = folder
		end
		folder.Parent = TextChatService
	end)
	if not ok then
		warn("[AdminService] TextChatCommand setup failed:", err)
	end

	-- Legacy chat fallback
	local function watch(player: Player)
		player.Chatted:Connect(function(message)
			if string.sub(message, 1, 1) == "/" then
				self:_run(player, message)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
end

function AdminService:IsAdmin(player: Player): boolean
	local admin = GameConfig.Admin
	if RunService:IsStudio() and admin.AllowEveryoneInStudio then
		return true
	end
	if table.find(admin.UserIds, player.UserId) then
		return true
	end
	if admin.AllowGameCreator and game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	return false
end

function AdminService:_reply(player: Player, text: string)
	self.AnnounceRemote:FireClient(player, { Kind = "Toast", Text = "🛠️ " .. text, Color = Color3.fromRGB(150, 200, 255) })
end

function AdminService:_run(player: Player, message: string)
	if not self:IsAdmin(player) then
		return
	end
	-- the same message can arrive through both chat systems; ignore duplicates
	local key = player.UserId .. ":" .. message
	local t = os.clock()
	if self._recent[key] and t - self._recent[key] < 1 then
		return
	end
	self._recent[key] = t

	local args = string.split(message, " ")
	local command = string.lower((string.gsub(args[1] or "", "^/", "")))
	local services = self.Services

	if command == "spawn" then
		local id = args[2]
		if not id or not AnomalyConfig.Get(id) then
			self:_reply(player, "Unknown anomaly. Try /anomalies")
			return
		end
		if services.RoundService.State ~= "Round" then
			self:_reply(player, "Start a round first: /round start")
			return
		end
		local record = services.AnomalyService:Spawn(id)
		self:_reply(player, record and ("Spawned " .. id .. " in " .. tostring(record.Zone)) or ("Could not spawn " .. id .. " (requirements not met)"))
	elseif command == "event" then
		local eventId = EVENT_ALIASES[string.lower(args[2] or "")]
		if not eventId then
			self:_reply(player, "Events: surge, blackout, falsealarm, rare")
			return
		end
		local started = services.EventService:Trigger(eventId, { Source = "Admin" })
		self:_reply(player, started and ("Started " .. eventId) or "Events only run during a round")
	elseif command == "round" then
		local sub = string.lower(args[2] or "")
		if sub == "start" then
			services.RoundService:ForceStart()
			self:_reply(player, "Starting round")
		elseif sub == "end" then
			services.RoundService:ForceEnd()
			self:_reply(player, "Ending round")
		else
			self:_reply(player, "Usage: /round start | /round end")
		end
	elseif command == "evidence" then
		local amount = tonumber(args[2])
		if not amount or amount <= 0 then
			self:_reply(player, "Usage: /evidence 10000")
			return
		end
		services.EconomyService:AddEvidence(player, math.floor(amount), "Admin")
		self:_reply(player, "Added Evidence")
	elseif command == "anomalies" then
		local ids = {}
		for _, def in ipairs(AnomalyConfig.GetSorted()) do
			table.insert(ids, def.Id)
		end
		print("[AdminService] Anomalies: " .. table.concat(ids, ", "))
		self:_reply(player, "Anomaly ids printed to the Output window")
	elseif command == "resetdata" then
		if not RunService:IsStudio() then
			self:_reply(player, "Only available in Studio")
			return
		end
		local profile = services.DataService:GetProfile(player)
		if profile then
			local keep = profile.Data.ProcessedReceipts
			for field in pairs(profile.Data) do
				profile.Data[field] = nil
			end
			profile.Data.ProcessedReceipts = keep
			player:Kick("Data reset. Rejoin to start fresh.")
		end
	end
end

return AdminService
