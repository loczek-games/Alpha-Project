--[[
	PartyController (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/PartyController

	PARTY panel + friend invites.
	  * Party leader, members (avatar, name, READY status, microphone status,
	    where they are: AT HQ / QUEUED / IN MISSION)
	  * INVITE FRIENDS  SocialService:CanSendGameInviteAsync ->
	                    SocialService:PromptGameInvite with LaunchData
	                    "party:<leaderId>" so the friend joins this party on
	                    arrival. Unsupported platforms / Studio / restricted
	                    accounts get a clear message instead of an error.
	  * READY, LEAVE PARTY, invite players already in this server,
	    accept / decline incoming invites (also shown as a pop-up card).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")

local Net = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"))

local PartyController = {}
PartyController.IsOpen = false
PartyController._seenInvites = {}

local player = Players.LocalPlayer

local MIC_TEXT = {
	On = "🎙 MIC ON",
	Off = "🔇 MUTED",
	None = "✕ NO VOICE",
}

local function headshot(userId: number): string
	return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", userId)
end

function PartyController:Init(controllers)
	self.Controllers = controllers
	local UIKit = controllers.UIKit
	self.Gui = UIKit.GetScreenGui("PartyUI", 10)
	self.Root = UIKit.ScaledRoot(self.Gui)
	self.ActionRemote = Net.Event("PartyAction")

	local panel, body, _tabs, subtitle = UIKit.BuildPanel(self.Root, "INVESTIGATION PARTY", function()
		UIKit.ClosePanel("Party")
	end)
	self.Panel, self.Body, self.Subtitle = panel, body, subtitle
	UIKit.RegisterPanel("Party", function()
		self.IsOpen = true
		self:Render()
		UIKit.AnimatePanel(panel, true)
		self.ActionRemote:FireServer("Refresh")
	end, function()
		self.IsOpen = false
		UIKit.AnimatePanel(panel, false)
	end)

	controllers.ClientState.PartyChanged:Connect(function(party)
		if self.IsOpen then
			self:Render()
		end
		self:_checkInvites(party)
	end)
	Players.PlayerAdded:Connect(function()
		if self.IsOpen then
			self:Render()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		if self.IsOpen then
			task.defer(function()
				self:Render()
			end)
		end
	end)
	SocialService.GameInvitePromptClosed:Connect(function(who, recipients)
		if who == player and type(recipients) == "table" and #recipients > 0 then
			controllers.AnnouncementController:Toast(string.format("📨 Invite sent to %d friend%s", #recipients, if #recipients == 1 then "" else "s"), Color3.fromRGB(200, 205, 220))
		end
	end)
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function PartyController:GetMe()
	local party = self.Controllers.ClientState.Party
	if party then
		for _, member in ipairs(party.Members or {}) do
			if member.UserId == player.UserId then
				return member
			end
		end
	end
	return nil
end

function PartyController:IsReady(): boolean
	local me = self:GetMe()
	return me ~= nil and me.Ready == true
end

function PartyController:ToggleReady()
	self.ActionRemote:FireServer("Ready", not self:IsReady())
	self.Controllers.AudioController:Play("UI.Button", nil)
end

function PartyController:InviteFriends()
	local announcements = self.Controllers.AnnouncementController
	local party = self.Controllers.ClientState.Party
	local leaderId = if party and party.LeaderId then party.LeaderId else player.UserId
	task.spawn(function()
		local ok, canSend = pcall(function()
			return SocialService:CanSendGameInviteAsync(player)
		end)
		if not ok or not canSend then
			local reason = if RunService:IsStudio() then "Friend invites do not work in Studio play tests - try it in the published game." else "Invites are not available for this account or device."
			announcements:Toast("📨 " .. reason, Color3.fromRGB(255, 170, 130), 5)
			return
		end
		local options = Instance.new("ExperienceInviteOptions")
		options.PromptMessage = "Join my paranormal investigation team!"
		options.LaunchData = "party:" .. tostring(leaderId)
		local prompted, err = pcall(function()
			SocialService:PromptGameInvite(player, options)
		end)
		if not prompted then
			warn("[PartyController] PromptGameInvite failed:", err)
			announcements:Toast("📨 Could not open the invite window. Try again.", Color3.fromRGB(255, 150, 120))
		end
	end)
end

---------------------------------------------------------------------------
-- Incoming invites (pop-up card)
---------------------------------------------------------------------------

function PartyController:_checkInvites(party)
	if not party then
		return
	end
	for _, invite in ipairs(party.Invites or {}) do
		local key = invite.LeaderId
		if not self._seenInvites[key] or os.clock() - self._seenInvites[key] > 60 then
			self._seenInvites[key] = os.clock()
			self:_showInviteCard(invite)
		end
	end
end

function PartyController:_showInviteCard(invite)
	local UIKit = self.Controllers.UIKit
	local theme = UIKit.Theme
	local hudRoot = self.Controllers.HUDController.Root
	self.Controllers.AudioController:Play("UI.Toast", nil)
	local card = UIKit.Card({
		Name = "InviteCard",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -150),
		Size = UDim2.fromOffset(300, 120),
		BackgroundColor3 = theme.Bg,
		Parent = hudRoot,
	})
	UIKit.new("ImageLabel", { Image = headshot(invite.LeaderId), BackgroundColor3 = theme.Panel3, Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(54, 54), Parent = card })
	UIKit.Label({ Text = "PARTY INVITE", Font = theme.FontType, TextSize = 16, TextColor3 = theme.AccentBright, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(74, 10), Size = UDim2.new(1, -84, 0, 20), Parent = card })
	UIKit.Label({ Text = string.format("%s (%d/6)", invite.Name, invite.Size or 1), Font = theme.Font, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(74, 34), Size = UDim2.new(1, -84, 0, 26), Parent = card })
	local function respond(action: string)
		self.ActionRemote:FireServer(action, invite.LeaderId)
		card:Destroy()
	end
	UIKit.Button({ Text = "ACCEPT", Font = theme.FontType, TextSize = 15, Position = UDim2.new(0, 10, 1, -46), Size = UDim2.new(0.5, -15, 0, 38), BackgroundColor3 = theme.Accent, Parent = card }, function()
		respond("Accept")
	end)
	UIKit.Button({ Text = "DECLINE", Font = theme.FontType, TextSize = 15, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 1, -46), Size = UDim2.new(0.5, -15, 0, 38), BackgroundColor3 = theme.Panel2, Parent = card }, function()
		respond("Decline")
	end)
	task.delay(30, function()
		if card.Parent then
			card:Destroy()
		end
	end)
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------

function PartyController:Render()
	local UIKit = self.Controllers.UIKit
	local theme = UIKit.Theme
	local party = self.Controllers.ClientState.Party or { Members = {}, Invites = {}, Max = 6, IsLeader = true }
	for _, child in ipairs(self.Body:GetChildren()) do
		child:Destroy()
	end
	self.Subtitle.Text = string.format("%d / %d MEMBERS", #party.Members, party.Max or 6)

	-- members (left)
	local left = UIKit.Frame({ Size = UDim2.new(0.6, -6, 1, 0), BackgroundTransparency = 1, Parent = self.Body })
	local scroll = UIKit.Scroller(left)
	UIKit.List(scroll, Enum.FillDirection.Vertical, 8)
	UIKit.Padding(scroll, 4)
	for order, member in ipairs(party.Members or {}) do
		local card = UIKit.Card({ LayoutOrder = order, Size = UDim2.new(1, -8, 0, 84), Parent = scroll })
		UIKit.new("ImageLabel", { Image = headshot(member.UserId), BackgroundColor3 = theme.Panel3, Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(64, 64), Parent = card })
		UIKit.Label({
			Text = (if member.Leader then "👑 " else "") .. member.Name .. (if member.UserId == player.UserId then "  (YOU)" else ""),
			Font = theme.FontType,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(86, 8),
			Size = UDim2.new(1, -96, 0, 24),
			Parent = card,
		})
		UIKit.Label({
			Text = if member.Leader then "PARTY LEADER · " .. (member.Status or "AT HQ") else (member.Status or "AT HQ"),
			Font = theme.Font,
			TextSize = 13,
			TextColor3 = theme.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(86, 32),
			Size = UDim2.new(1, -96, 0, 18),
			Parent = card,
		})
		local readyTag = UIKit.Label({
			Text = if member.Ready then "READY" else "NOT READY",
			Font = theme.Font,
			TextSize = 13,
			TextColor3 = if member.Ready then theme.Good else theme.AccentBright,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(86, 54),
			Size = UDim2.fromOffset(100, 20),
			Parent = card,
		})
		readyTag.Name = "Ready"
		UIKit.Label({
			Text = MIC_TEXT[member.Mic] or MIC_TEXT.None,
			Font = theme.Font,
			TextSize = 13,
			TextColor3 = if member.Mic == "On" then theme.CCTV else theme.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(190, 54),
			Size = UDim2.fromOffset(120, 20),
			Parent = card,
		})
		if party.IsLeader and member.UserId ~= player.UserId then
			UIKit.Button({ Text = "KICK", Font = theme.Font, TextSize = 12, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(62, 28), BackgroundColor3 = theme.Accent, Parent = card }, function()
				self.ActionRemote:FireServer("Kick", member.UserId)
			end)
			UIKit.Button({ Text = "LEADER", Font = theme.Font, TextSize = 12, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 44), Size = UDim2.fromOffset(62, 28), BackgroundColor3 = theme.Panel3, Parent = card }, function()
				self.ActionRemote:FireServer("Promote", member.UserId)
			end)
		end
	end

	-- actions (right)
	local right = UIKit.Frame({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.4, -6, 1, 0), BackgroundTransparency = 1, Parent = self.Body })
	local actions = UIKit.Scroller(right)
	UIKit.List(actions, Enum.FillDirection.Vertical, 8)
	UIKit.Padding(actions, 4)
	local order = 0
	local function button(text: string, color: Color3, callback: () -> ())
		order += 1
		return UIKit.Button({ LayoutOrder = order, Text = text, Font = theme.FontType, TextSize = 17, Size = UDim2.new(1, -8, 0, 48), BackgroundColor3 = color, Parent = actions }, callback)
	end
	local function heading(text: string)
		order += 1
		UIKit.Label({ LayoutOrder = order, Text = text, Font = theme.Font, TextSize = 13, TextColor3 = theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -8, 0, 22), Parent = actions })
	end
	button("INVITE FRIENDS", theme.Accent, function()
		self:InviteFriends()
	end)
	local ready = self:IsReady()
	local readyButton = button(if ready then "READY ✓" else "READY", if ready then theme.Good else theme.Panel3, function()
		self:ToggleReady()
	end)
	readyButton.TextColor3 = if ready then theme.Ink else theme.Text
	if #(party.Members or {}) > 1 then
		button("LEAVE PARTY", theme.Panel2, function()
			self.ActionRemote:FireServer("Leave")
		end)
	end

	if #(party.Invites or {}) > 0 then
		heading("INVITES")
		for _, invite in ipairs(party.Invites) do
			order += 1
			local row = UIKit.Card({ LayoutOrder = order, Size = UDim2.new(1, -8, 0, 44), Parent = actions })
			UIKit.Label({ Text = invite.Name, Font = theme.Font, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -110, 1, 0), Parent = row })
			UIKit.Button({ Text = "JOIN", Font = theme.Font, TextSize = 13, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(90, 32), BackgroundColor3 = theme.Accent, Parent = row }, function()
				self.ActionRemote:FireServer("Accept", invite.LeaderId)
			end)
		end
	end

	if party.IsLeader then
		heading("INVESTIGATORS IN THIS SERVER")
		local inParty = {}
		for _, member in ipairs(party.Members or {}) do
			inParty[member.UserId] = true
		end
		local any = false
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player and not inParty[other.UserId] then
				any = true
				order += 1
				local row = UIKit.Card({ LayoutOrder = order, Size = UDim2.new(1, -8, 0, 44), Parent = actions })
				UIKit.Label({ Text = other.DisplayName, Font = theme.Font, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -110, 1, 0), Parent = row })
				UIKit.Button({ Text = "INVITE", Font = theme.Font, TextSize = 13, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(90, 32), BackgroundColor3 = theme.Panel3, Parent = row }, function()
					self.ActionRemote:FireServer("Invite", other.UserId)
				end)
			end
		end
		if not any then
			order += 1
			UIKit.Label({ LayoutOrder = order, Text = "Nobody else here yet. Use INVITE FRIENDS.", Font = theme.Font, TextSize = 13, TextColor3 = theme.SubText, Size = UDim2.new(1, -8, 0, 40), Parent = actions })
		end
	end
end

return PartyController
