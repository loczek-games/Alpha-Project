--[[
	PartyService (ModuleScript)
	Location: ServerScriptService/Services/PartyService

	Friend parties. A party walks into a mission queue zone together and is
	always deployed into the same investigation.

	  * Everyone is the leader of their own party of one until they invite
	    someone (or accept an invite).
	  * In-server invites: PartyAction("Invite", userId) -> the other player
	    gets an invite card -> PartyAction("Accept", leaderId).
	  * Friends outside the server are invited from the client with
	    SocialService:PromptGameInvite (PartyController). The invite carries
	    LaunchData "party:<leaderUserId>", so the friend automatically joins
	    the inviter's party when they arrive.
	  * READY status (shortens the queue timer), leader, avatar and
	    microphone status are sent to every member (PartyUpdate).
	  * Parties survive teleports between the lobby and gameplay places
	    (ExportParties / RestoreParties through TeleportData).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VoiceChatService = game:GetService("VoiceChatService")

local Config = ReplicatedStorage:WaitForChild("Config")
local MapConfig = require(Config:WaitForChild("MapConfig"))
local Net = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"))

local PartyService = {}
PartyService.PartyOf = {} :: { [Player]: any }
PartyService.Invites = {} :: { [Player]: { [number]: number } } -- invitee -> leaderUserId -> expires
PartyService.Ready = {} :: { [Player]: boolean }
PartyService.Mic = {} :: { [Player]: string } -- "On" | "Off" | "None"
PartyService._pendingJoin = {} :: { [number]: number } -- userId -> leaderUserId (from TeleportData)
PartyService._lastAction = {}

local MAX_PARTY = 6
local INVITE_TIME = 60

function PartyService:Init(services)
	self.Services = services
	self.UpdateRemote = Net.Event("PartyUpdate")
	self.AnnounceRemote = Net.Event("Announce")

	Net.Event("PartyAction").OnServerEvent:Connect(function(player, action, argument)
		local t = os.clock()
		if self._lastAction[player] and t - self._lastAction[player] < 0.2 then
			return
		end
		self._lastAction[player] = t
		local ok, err = pcall(self._onAction, self, player, action, argument)
		if not ok then
			warn("[PartyService] action error:", err)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		self:_onJoin(player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:_onJoin(player)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		self:_leave(player, true)
		self.Invites[player] = nil
		self.Ready[player] = nil
		self.Mic[player] = nil
		self._lastAction[player] = nil
	end)
	services.DataService:OnClientReady(function(player)
		self:_push(player)
	end)
end

---------------------------------------------------------------------------
-- Joining the server: invite LaunchData / party restored after a teleport
---------------------------------------------------------------------------

function PartyService:_onJoin(player: Player)
	self:_newSolo(player)
	task.spawn(function()
		self:_checkMic(player)
	end)
	local leaderId = self._pendingJoin[player.UserId]
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	if ok and type(joinData) == "table" then
		local launch = joinData.LaunchData
		if type(launch) == "string" then
			local id = tonumber(string.match(launch, "^party:(%d+)$"))
			if id then
				leaderId = id
			end
		end
		local teleportData = joinData.TeleportData
		if type(teleportData) == "table" and type(teleportData.Parties) == "table" then
			self:RestoreParties(teleportData.Parties)
			leaderId = self._pendingJoin[player.UserId] or leaderId
		end
	end
	if leaderId and leaderId ~= player.UserId then
		self._pendingJoin[player.UserId] = leaderId
		self:_tryPendingJoin(player)
	end
	-- anyone waiting to join THIS player's party?
	for userId, wantedLeader in pairs(self._pendingJoin) do
		if wantedLeader == player.UserId then
			local member = Players:GetPlayerByUserId(userId)
			if member then
				self:_tryPendingJoin(member)
			end
		end
	end
end

function PartyService:_tryPendingJoin(player: Player)
	local leaderId = self._pendingJoin[player.UserId]
	local leader = leaderId and Players:GetPlayerByUserId(leaderId)
	if not leader then
		return
	end
	local party = self.PartyOf[leader]
	if not party or #party.Members >= MAX_PARTY then
		return
	end
	self._pendingJoin[player.UserId] = nil
	self:_join(player, party, true)
end

function PartyService:_checkMic(player: Player)
	local status = "None"
	local ok, enabled = pcall(function()
		return VoiceChatService:IsVoiceEnabledForUserIdAsync(player.UserId)
	end)
	if ok and enabled then
		status = "On"
	end
	self.Mic[player] = status
	local party = self.PartyOf[player]
	if party then
		self:_pushParty(party)
	end
end

---------------------------------------------------------------------------
-- Party bookkeeping
---------------------------------------------------------------------------

function PartyService:_newSolo(player: Player)
	local party = { Leader = player, Members = { player } }
	self.PartyOf[player] = party
	return party
end

function PartyService:_join(player: Player, party, silent: boolean?)
	if self.PartyOf[player] == party then
		return
	end
	self:_leave(player, true)
	local solo = self.PartyOf[player]
	if solo then
		-- drop the solo party
		self.PartyOf[player] = nil
	end
	table.insert(party.Members, player)
	self.PartyOf[player] = party
	self.Ready[player] = false
	if not silent then
		self:_toastParty(party, string.format("👥 %s joined the party", player.DisplayName))
	end
	self:_pushParty(party)
end

function PartyService:_leave(player: Player, silent: boolean?)
	local party = self.PartyOf[player]
	if not party or #party.Members <= 1 then
		return
	end
	local index = table.find(party.Members, player)
	if index then
		table.remove(party.Members, index)
	end
	if party.Leader == player then
		party.Leader = party.Members[1]
	end
	self.PartyOf[player] = nil
	if player:IsDescendantOf(Players) then
		self:_newSolo(player)
		self:_push(player)
	end
	if not silent then
		self:_toastParty(party, string.format("👥 %s left the party", player.DisplayName))
	end
	self:_pushParty(party)
end

function PartyService:_toastParty(party, text: string)
	for _, member in ipairs(party.Members) do
		self.AnnounceRemote:FireClient(member, { Kind = "Toast", Text = text, Color = Color3.fromRGB(190, 200, 230) })
	end
end

function PartyService:_onAction(player: Player, action: any, argument: any)
	if action == "Invite" then
		local target = if type(argument) == "number" then Players:GetPlayerByUserId(argument) else nil
		if not target or target == player then
			return
		end
		local party = self.PartyOf[player]
		if party.Leader ~= player then
			self.AnnounceRemote:FireClient(player, { Kind = "Toast", Text = "Only the party leader can invite.", Color = Color3.fromRGB(255, 160, 120) })
			return
		end
		if #party.Members >= MAX_PARTY then
			return
		end
		if self.PartyOf[target] == party then
			return
		end
		self.Invites[target] = self.Invites[target] or {}
		self.Invites[target][player.UserId] = os.clock() + INVITE_TIME
		self:_push(target)
		self.AnnounceRemote:FireClient(player, { Kind = "Toast", Text = "📨 Invite sent to " .. target.DisplayName, Color = Color3.fromRGB(190, 200, 230) })
	elseif action == "Accept" or action == "Decline" then
		local leaderId = argument
		if type(leaderId) ~= "number" then
			return
		end
		local invites = self.Invites[player]
		local expires = invites and invites[leaderId]
		if invites then
			invites[leaderId] = nil
		end
		if action == "Accept" and expires and os.clock() < expires then
			local leader = Players:GetPlayerByUserId(leaderId)
			local party = leader and self.PartyOf[leader]
			if party and #party.Members < MAX_PARTY and not self.Services.MissionService:IsInvestigating(player) then
				self:_join(player, party)
			end
		end
		self:_push(player)
	elseif action == "Leave" then
		self:_leave(player)
	elseif action == "Kick" then
		local party = self.PartyOf[player]
		local target = if type(argument) == "number" then Players:GetPlayerByUserId(argument) else nil
		if party and party.Leader == player and target and target ~= player and self.PartyOf[target] == party then
			self:_leave(target)
			self.AnnounceRemote:FireClient(target, { Kind = "Toast", Text = "You were removed from the party.", Color = Color3.fromRGB(255, 160, 120) })
		end
	elseif action == "Promote" then
		local party = self.PartyOf[player]
		local target = if type(argument) == "number" then Players:GetPlayerByUserId(argument) else nil
		if party and party.Leader == player and target and self.PartyOf[target] == party then
			party.Leader = target
			self:_toastParty(party, "👑 " .. target.DisplayName .. " is now the party leader")
			self:_pushParty(party)
		end
	elseif action == "Ready" then
		self.Ready[player] = argument == true
		self:_pushParty(self.PartyOf[player])
		self.Services.LobbyService:OnReadyChanged(player)
	elseif action == "Refresh" then
		self:_push(player)
	end
end

---------------------------------------------------------------------------
-- Queries used by LobbyService / MissionService
---------------------------------------------------------------------------

function PartyService:GetParty(player: Player)
	return self.PartyOf[player] or self:_newSolo(player)
end

function PartyService:GetMembers(player: Player): { Player }
	return table.clone(self:GetParty(player).Members)
end

function PartyService:IsLeader(player: Player): boolean
	return self:GetParty(player).Leader == player
end

function PartyService:IsReady(player: Player): boolean
	return self.Ready[player] == true
end

function PartyService:ExportParties()
	local list, seen = {}, {}
	for _, party in pairs(self.PartyOf) do
		if not seen[party] and #party.Members > 1 then
			seen[party] = true
			local members = {}
			for _, member in ipairs(party.Members) do
				table.insert(members, member.UserId)
			end
			table.insert(list, { LeaderId = party.Leader.UserId, Members = members })
		end
	end
	return list
end

function PartyService:RestoreParties(parties: any)
	if type(parties) ~= "table" then
		return
	end
	for _, entry in ipairs(parties) do
		if type(entry) == "table" and type(entry.LeaderId) == "number" and type(entry.Members) == "table" then
			for _, userId in ipairs(entry.Members) do
				if type(userId) == "number" and userId ~= entry.LeaderId then
					self._pendingJoin[userId] = entry.LeaderId
					local member = Players:GetPlayerByUserId(userId)
					if member then
						self:_tryPendingJoin(member)
					end
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- Client view
---------------------------------------------------------------------------

function PartyService:_view(player: Player)
	local party = self:GetParty(player)
	local members = {}
	for _, member in ipairs(party.Members) do
		local queue = self.Services.LobbyService and self.Services.LobbyService:GetQueueOf(member)
		table.insert(members, {
			UserId = member.UserId,
			Name = member.DisplayName,
			Leader = party.Leader == member,
			Ready = self.Ready[member] == true,
			Mic = self.Mic[member] or "None",
			Status = if self.Services.MissionService:IsParticipant(member) then "IN MISSION" elseif queue then "QUEUED · " .. (MapConfig.Get(queue) and MapConfig.Get(queue).Name or queue) else "AT HQ",
		})
	end
	local invites = {}
	local now = os.clock()
	for leaderId, expires in pairs(self.Invites[player] or {}) do
		local leader = Players:GetPlayerByUserId(leaderId)
		if leader and now < expires then
			table.insert(invites, { LeaderId = leaderId, Name = leader.DisplayName, Size = #self:GetParty(leader).Members })
		end
	end
	return {
		LeaderId = party.Leader.UserId,
		IsLeader = party.Leader == player,
		Members = members,
		Max = MAX_PARTY,
		Invites = invites,
	}
end

function PartyService:_push(player: Player)
	if player:IsDescendantOf(Players) and self.Services.DataService:IsClientReady(player) then
		self.UpdateRemote:FireClient(player, self:_view(player))
	end
end

function PartyService:_pushParty(party)
	if not party then
		return
	end
	for _, member in ipairs(party.Members) do
		self:_push(member)
	end
end

function PartyService:RefreshPlayer(player: Player)
	self:_pushParty(self:GetParty(player))
end

return PartyService
