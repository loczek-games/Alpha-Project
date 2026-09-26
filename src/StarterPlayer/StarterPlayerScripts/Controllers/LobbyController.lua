--[[
	LobbyController (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/LobbyController

	Client side of the agency headquarters:
	  * LobbyAction  a station terminal was used -> open its menu
	  * QUEUE PANEL  "DEAD MALL  3/6 INVESTIGATORS  STARTING IN 10  [LEAVE QUEUE]"
	                 while you stand in a mission zone (plus a tick each second)
	  * PARANORMAL   rare harmless moments picked by LobbyService: a light
	                 flickers above you, a photo on the wall changes, a figure
	                 stands behind the frosted glass, a whisper. Never attacks.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"))

local LobbyController = {}

local player = Players.LocalPlayer

function LobbyController:Init(controllers)
	self.Controllers = controllers
	local UIKit = controllers.UIKit
	local theme = UIKit.Theme
	local root = controllers.HUDController.Root

	Net.Event("LobbyAction").OnClientEvent:Connect(function(station)
		self:_openStation(station)
	end)

	-- queue panel ----------------------------------------------------------
	local panel = UIKit.Card({
		Name = "QueuePanel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(420, 112),
		BackgroundColor3 = theme.Bg,
		BackgroundTransparency = 0.08,
		Visible = false,
		Parent = root,
	})
	UIKit.Scanlines(panel, 20, 0.88, 1)
	UIKit.Frame({ Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = theme.Accent, Parent = panel })
	self.QueueTitle = UIKit.Label({
		Text = "DEAD MALL",
		Font = theme.FontType,
		TextSize = 26,
		TextColor3 = theme.AccentBright,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(18, 8),
		Size = UDim2.new(0.62, -18, 0, 30),
		ZIndex = 2,
		Parent = panel,
	})
	self.QueueCount = UIKit.Label({
		Text = "1/6 INVESTIGATORS",
		Font = theme.Font,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(18, 40),
		Size = UDim2.new(0.62, -18, 0, 22),
		ZIndex = 2,
		Parent = panel,
	})
	self.QueueStatus = UIKit.Label({
		Text = "STARTING IN 15",
		Font = theme.Font,
		TextSize = 17,
		TextColor3 = theme.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(18, 64),
		Size = UDim2.new(0.62, -18, 0, 22),
		ZIndex = 2,
		Parent = panel,
	})
	self.QueueNames = UIKit.Label({
		Text = "",
		Font = theme.Font,
		TextSize = 12,
		TextColor3 = theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(18, 88),
		Size = UDim2.new(1, -36, 0, 16),
		ZIndex = 2,
		Parent = panel,
	})
	UIKit.Button({
		Name = "Leave",
		Text = "LEAVE QUEUE",
		Font = theme.FontType,
		TextSize = 15,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 14),
		Size = UDim2.fromOffset(136, 40),
		BackgroundColor3 = theme.Panel3,
		ZIndex = 2,
		Parent = panel,
	}, function()
		Net.Event("MissionRequest"):FireServer("LeaveQueue")
	end)
	self.ReadyButton = UIKit.Button({
		Name = "Ready",
		Text = "READY",
		Font = theme.FontType,
		TextSize = 15,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 58),
		Size = UDim2.fromOffset(136, 40),
		BackgroundColor3 = theme.Accent,
		ZIndex = 2,
		Parent = panel,
	}, function()
		controllers.PartyController:ToggleReady()
	end)
	self.QueuePanel = panel

	controllers.ClientState.QueueChanged:Connect(function(queue)
		self:_renderQueue(queue)
	end)
	controllers.ClientState.PartyChanged:Connect(function()
		self:_renderQueue(controllers.ClientState.Queue)
	end)
end

function LobbyController:Start()
	task.spawn(function()
		local lastSecond = nil
		while true do
			local queue = self.Controllers.ClientState.Queue
			if queue and (queue.EndsAt or 0) > 0 then
				local left = math.max(0, math.ceil(queue.EndsAt - Workspace:GetServerTimeNow()))
				self.QueueStatus.Text = "STARTING IN " .. left
				if left ~= lastSecond and left <= 10 then
					lastSecond = left
					self.Controllers.AudioController:Play(if left <= 3 then "UI.QueueTickFinal" else "UI.QueueTick", nil)
				end
			else
				lastSecond = nil
			end
			task.wait(0.1)
		end
	end)
	-- paranormal HQ moments
	local lobby = Workspace:WaitForChild("Lobby", 30)
	if lobby then
		lobby:GetAttributeChangedSignal("ParanormalAt"):Connect(function()
			local ok, err = pcall(self._paranormal, self, lobby)
			if not ok then
				warn("[LobbyController]", err)
			end
		end)
	end
end

---------------------------------------------------------------------------
-- Stations
---------------------------------------------------------------------------

function LobbyController:_openStation(station: any)
	local controllers = self.Controllers
	local UIKit = controllers.UIKit
	controllers.AudioController:Play("UI.Terminal", nil)
	if station == "Shop" then
		controllers.ShopController:OpenTab("EQUIPMENT")
	elseif station == "Upgrades" then
		controllers.ShopController:OpenTab("CAMERA LAB")
	elseif station == "Flashlight" then
		controllers.ShopController:OpenTab("FLASHLIGHT")
	elseif station == "Store" then
		controllers.ShopController:OpenTab("STORE")
	elseif station == "Archive" then
		UIKit.OpenPanel("Album")
	elseif station == "Settings" then
		UIKit.OpenPanel("Settings")
	elseif station == "Party" then
		UIKit.OpenPanel("Party")
	elseif station == "Invite" then
		controllers.PartyController:InviteFriends()
	end
end

---------------------------------------------------------------------------
-- Queue panel
---------------------------------------------------------------------------

function LobbyController:_renderQueue(queue)
	local UIKit = self.Controllers.UIKit
	if not queue then
		if self.QueuePanel.Visible then
			self.QueuePanel.Visible = false
			self.Controllers.AudioController:Play("UI.QueueLeave", nil)
		end
		return
	end
	if not self.QueuePanel.Visible then
		self.QueuePanel.Visible = true
		self.QueuePanel.Position = UDim2.new(0.5, 0, 1, 60)
		UIKit.Tween(self.QueuePanel, 0.3, { Position = UDim2.new(0.5, 0, 1, -18) }, Enum.EasingStyle.Back)
	end
	self.QueueTitle.Text = queue.Title or "DEAD MALL"
	self.QueueCount.Text = string.format("%d/%d INVESTIGATORS", queue.Count or 0, queue.Max or 6)
	if (queue.EndsAt or 0) <= 0 then
		self.QueueStatus.Text = queue.Status or "WAITING"
	end
	self.QueueNames.Text = table.concat(queue.Names or {}, " · ")
	local ready = self.Controllers.PartyController:IsReady()
	self.ReadyButton.Text = if ready then "READY ✓" else "READY"
	self.ReadyButton.BackgroundColor3 = if ready then UIKit.Theme.Good else UIKit.Theme.Accent
	self.ReadyButton.TextColor3 = if ready then UIKit.Theme.Ink else UIKit.Theme.Text
end

---------------------------------------------------------------------------
-- Paranormal moments (harmless)
---------------------------------------------------------------------------

function LobbyController:_nearLobby(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and self.Controllers.ClientState:IsInLobby()
end

function LobbyController:_paranormal(lobby: Instance)
	if not self:_nearLobby() then
		return
	end
	local kind = lobby:GetAttribute("ParanormalKind")
	local audio = self.Controllers.AudioController
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	if kind == "Flicker" then
		-- the light closest to you stutters
		local best, bestDistance = nil, 45
		for _, panel in ipairs(CollectionService:GetTagged("MallLight")) do
			if panel:IsA("BasePart") and panel:IsDescendantOf(lobby) then
				local distance = (panel.Position - root.Position).Magnitude
				if distance < bestDistance then
					best, bestDistance = panel, distance
				end
			end
		end
		if best then
			local lights = {}
			for _, child in ipairs(best:GetChildren()) do
				if child:IsA("Light") then
					table.insert(lights, child)
				end
			end
			audio:Play("Environment.LightBuzz", best)
			for _ = 1, math.random(4, 7) do
				for _, light in ipairs(lights) do
					light.Enabled = false
				end
				task.wait(0.05 + math.random() * 0.1)
				for _, light in ipairs(lights) do
					light.Enabled = true
				end
				task.wait(0.08 + math.random() * 0.25)
			end
		end
	elseif kind == "Photo" then
		for _, photo in ipairs(CollectionService:GetTagged("ChangingPhoto")) do
			if photo:IsA("BasePart") and (photo.Position - root.Position).Magnitude < 40 then
				local gui = photo:FindFirstChildWhichIsA("SurfaceGui")
				local label = gui and gui:FindFirstChild("Line2")
				if label and label:IsA("TextLabel") then
					local original, color = label.Text, label.TextColor3
					label.Text = string.upper(player.DisplayName)
					label.TextColor3 = Color3.fromRGB(150, 0, 0)
					task.wait(2.5)
					label.Text, label.TextColor3 = original, color
				end
			end
		end
	elseif kind == "Apparition" then
		for _, figure in ipairs(CollectionService:GetTagged("LobbyApparition")) do
			if figure:IsA("BasePart") and (figure.Position - root.Position).Magnitude < 60 then
				figure.LocalTransparencyModifier = 0
				figure.Transparency = 0.25
				task.wait(1.1 + math.random())
				TweenService:Create(figure, TweenInfo.new(0.15), { Transparency = 1 }):Play()
			end
		end
	elseif kind == "Whisper" then
		local offset = -root.CFrame.LookVector * 6 + Vector3.new(math.random(-3, 3), 2, math.random(-3, 3))
		audio:Play("Anomaly.Whisper", root.Position + offset)
	end
end

return LobbyController
