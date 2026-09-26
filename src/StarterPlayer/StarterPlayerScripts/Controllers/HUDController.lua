--[[
	HUDController (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/HUDController

	Mobile-first horror HUD with two modes:
	  HQ       agency badge, Evidence, and the main menu:
	           INVITE FRIENDS · PARTY · EQUIPMENT · ARCHIVE · SHOP · SETTINGS
	  MISSION  CCTV strip "● REC  CASE #001 · DEAD MALL  07:12", current event,
	           zone name, Evidence, a small menu (settings / leave mission)
	           and the viewfinder reticle.
	(The big PHOTO button is owned by PhotoController, the queue panel by
	LobbyController.)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local MapConfig = require(Config:WaitForChild("MapConfig"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Format = require(Modules:WaitForChild("Format"))
local Net = require(Modules:WaitForChild("Net"))

local HUDController = {}
HUDController.Mode = nil :: string?

local player = Players.LocalPlayer

local MENU = {
	{ Id = "Invite", Icon = "📨", Label = "INVITE FRIENDS" },
	{ Id = "Party", Icon = "👥", Label = "PARTY" },
	{ Id = "Equipment", Icon = "🎒", Label = "EQUIPMENT" },
	{ Id = "Archive", Icon = "🗂", Label = "ARCHIVE" },
	{ Id = "Shop", Icon = "💀", Label = "SHOP" },
	{ Id = "Settings", Icon = "⚙", Label = "SETTINGS" },
}

function HUDController:Init(controllers)
	self.Controllers = controllers
	local UIKit = controllers.UIKit
	local theme = UIKit.Theme
	local state = controllers.ClientState

	self.Gui = UIKit.GetScreenGui("HUD", 1)
	self.Root = UIKit.ScaledRoot(self.Gui)
	local root = self.Root

	---------------------------------------------------------------- top strip
	local strip = UIKit.Frame({
		Name = "CCTV",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(330, 40),
		BackgroundColor3 = theme.Bg,
		BackgroundTransparency = 0.25,
		Parent = root,
	})
	UIKit.Corner(strip, 3)
	UIKit.Stroke(strip, theme.Stroke, 1, 0.4)
	self.Strip = strip
	self.RecDot = UIKit.Frame({
		Name = "RecDot",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = theme.AccentBright,
		Parent = strip,
	})
	UIKit.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = self.RecDot })
	self.TimerLabel = UIKit.Label({
		Name = "Label",
		Text = "P.I.A. HQ",
		Font = theme.Font,
		TextSize = 15,
		TextColor3 = theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(0.7, -30, 1, 0),
		Parent = strip,
	})
	self.TimerText = UIKit.Label({
		Name = "Time",
		Text = "",
		Font = theme.Font,
		TextSize = 22,
		TextColor3 = theme.Text,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 0),
		Size = UDim2.new(0.3, 0, 1, 0),
		Parent = strip,
	})

	---------------------------------------------------------------- event + zone
	self.EventPill = UIKit.Frame({
		Name = "Event",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 54),
		Size = UDim2.fromOffset(320, 30),
		BackgroundColor3 = theme.Accent,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = root,
	})
	UIKit.Corner(self.EventPill, 3)
	self.EventText = UIKit.Label({ Text = "", Font = theme.FontType, TextSize = 16, Parent = self.EventPill })
	self.ZoneLabel = UIKit.Label({
		Name = "Zone",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.fromOffset(420, 28),
		Text = "",
		Font = theme.FontType,
		TextSize = 22,
		TextColor3 = theme.Text,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = root,
	})

	---------------------------------------------------------------- evidence
	local evidence = UIKit.Frame({
		Name = "Evidence",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(170, 44),
		BackgroundColor3 = theme.Bg,
		BackgroundTransparency = 0.25,
		Parent = root,
	})
	UIKit.Corner(evidence, 3)
	UIKit.Stroke(evidence, theme.Stroke, 1, 0.4)
	UIKit.Label({
		Text = "EVIDENCE",
		Font = theme.Font,
		TextSize = 11,
		TextColor3 = theme.SubText,
		Position = UDim2.fromOffset(10, 3),
		Size = UDim2.new(1, -20, 0, 12),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = evidence,
	})
	self.EvidenceText = UIKit.Label({
		Text = "$0",
		Font = theme.Font,
		TextSize = 22,
		TextColor3 = theme.Evidence,
		Position = UDim2.fromOffset(10, 15),
		Size = UDim2.new(1, -20, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = evidence,
	})
	self.EvidenceScale = UIKit.new("UIScale", { Parent = evidence })
	self.DisplayedEvidence = 0

	---------------------------------------------------------------- HQ menu
	local menu = UIKit.Frame({
		Name = "Menu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(150, 6 * 50),
		BackgroundTransparency = 1,
		Parent = root,
	})
	UIKit.List(menu, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Left)
	self.Menu = menu
	self.MenuButtons = {}
	for order, entry in ipairs(MENU) do
		local button = UIKit.Button({
			Name = entry.Id,
			LayoutOrder = order,
			Size = UDim2.fromOffset(150, 44),
			BackgroundColor3 = theme.Bg,
			BackgroundTransparency = 0.18,
			Text = "",
			Parent = menu,
		}, function()
			self:OpenMenu(entry.Id)
		end)
		UIKit.Label({ Text = entry.Icon, TextSize = 20, Position = UDim2.fromOffset(6, 0), Size = UDim2.new(0, 30, 1, 0), Parent = button })
		UIKit.Label({
			Text = entry.Label,
			Font = theme.FontType,
			TextSize = 14,
			TextColor3 = if entry.Id == "Invite" then theme.AccentBright else theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(40, 0),
			Size = UDim2.new(1, -44, 1, 0),
			Parent = button,
		})
		self.MenuButtons[entry.Id] = button
	end

	---------------------------------------------------------------- mission menu
	self.MissionMenuButton = UIKit.Button({
		Name = "MissionMenu",
		Text = "≡",
		TextSize = 26,
		Font = theme.Font,
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.fromOffset(44, 40),
		BackgroundColor3 = theme.Bg,
		BackgroundTransparency = 0.25,
		Visible = false,
		Parent = root,
	}, function()
		self:_toggleMissionMenu()
	end)
	local missionMenu = UIKit.Card({
		Name = "MissionMenuPanel",
		Position = UDim2.fromOffset(10, 54),
		Size = UDim2.fromOffset(190, 3 * 46 + 16),
		BackgroundColor3 = theme.Bg,
		Visible = false,
		ZIndex = 5,
		Parent = root,
	})
	UIKit.Padding(missionMenu, 8)
	UIKit.List(missionMenu, Enum.FillDirection.Vertical, 6)
	self.MissionMenu = missionMenu
	local function missionButton(order: number, text: string, color: Color3, callback: () -> ())
		UIKit.Button({
			LayoutOrder = order,
			Text = text,
			Font = theme.FontType,
			TextSize = 15,
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = color,
			ZIndex = 6,
			Parent = missionMenu,
		}, function()
			missionMenu.Visible = false
			callback()
		end)
	end
	missionButton(1, "SETTINGS", theme.Panel2, function()
		UIKit.OpenPanel("Settings")
	end)
	missionButton(2, "ARCHIVE", theme.Panel2, function()
		UIKit.OpenPanel("Album")
	end)
	missionButton(3, "LEAVE MISSION", theme.Accent, function()
		self:_confirmLeave()
	end)

	---------------------------------------------------------------- reticle
	local reticle = UIKit.Frame({
		Name = "Reticle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(120, 84),
		BackgroundTransparency = 1,
		Parent = root,
	})
	self.Reticle = reticle
	self.ReticleParts = {}
	local corners = {
		{ Vector2.new(0, 0), UDim2.fromScale(0, 0) },
		{ Vector2.new(1, 0), UDim2.fromScale(1, 0) },
		{ Vector2.new(0, 1), UDim2.fromScale(0, 1) },
		{ Vector2.new(1, 1), UDim2.fromScale(1, 1) },
	}
	for _, corner in ipairs(corners) do
		local horizontal = UIKit.Frame({ AnchorPoint = corner[1], Position = corner[2], Size = UDim2.fromOffset(18, 2), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.5, Parent = reticle })
		local vertical = UIKit.Frame({ AnchorPoint = corner[1], Position = corner[2], Size = UDim2.fromOffset(2, 18), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.5, Parent = reticle })
		table.insert(self.ReticleParts, horizontal)
		table.insert(self.ReticleParts, vertical)
	end
	local dot = UIKit.Frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(4, 4), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.35, Parent = reticle })
	UIKit.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })
	table.insert(self.ReticleParts, dot)
	self.ReticleScale = UIKit.new("UIScale", { Parent = reticle })

	---------------------------------------------------------------- state
	state.DataChanged:Connect(function(data, previous)
		self:_onData(data, previous)
	end)
	state.EventChanged:Connect(function()
		self:_refreshEvent()
	end)
	state.RoundChanged:Connect(function()
		self:_refreshMode()
		self:_refreshTimer()
	end)
	self:_refreshMode()
end

function HUDController:Start()
	task.spawn(function()
		while true do
			self:_refreshTimer()
			self:_refreshEvent()
			task.wait(0.2)
		end
	end)
	task.spawn(function()
		while true do
			self:_refreshZone()
			task.wait(0.5)
		end
	end)
end

---------------------------------------------------------------------------
-- Menu actions
---------------------------------------------------------------------------

function HUDController:OpenMenu(id: string)
	local controllers = self.Controllers
	local UIKit = controllers.UIKit
	if id == "Invite" then
		controllers.PartyController:InviteFriends()
	elseif id == "Party" then
		UIKit.TogglePanel("Party")
	elseif id == "Equipment" then
		controllers.ShopController:OpenTab("EQUIPMENT")
	elseif id == "Archive" then
		UIKit.TogglePanel("Album")
	elseif id == "Shop" then
		controllers.ShopController:OpenTab("STORE")
	elseif id == "Settings" then
		UIKit.TogglePanel("Settings")
	end
end

function HUDController:_toggleMissionMenu()
	self.MissionMenu.Visible = not self.MissionMenu.Visible
end

function HUDController:_confirmLeave()
	local announcements = self.Controllers.AnnouncementController
	announcements:Confirm("LEAVE THE INVESTIGATION?", "You keep your evidence. Your team stays inside.", "LEAVE", function()
		Net.Event("MissionRequest"):FireServer("Leave")
	end)
end

function HUDController:_refreshMode()
	local state = self.Controllers.ClientState
	local mode = if state:IsInMission() then "Mission" else "Lobby"
	if mode == self.Mode then
		return
	end
	self.Mode = mode
	local inMission = mode == "Mission"
	self.Menu.Visible = not inMission
	self.MissionMenuButton.Visible = inMission
	self.MissionMenu.Visible = false
	self.Reticle.Visible = inMission
	if not inMission then
		self.ZoneLabel.TextTransparency = 1
	end
end

---------------------------------------------------------------------------
-- Evidence
---------------------------------------------------------------------------

function HUDController:_onData(data, previous)
	if not data then
		return
	end
	local UIKit = self.Controllers.UIKit
	local target = data.Evidence or 0
	if not previous then
		self.DisplayedEvidence = target -- first load: no count-up animation
	end
	local start = self.DisplayedEvidence
	if target ~= start then
		self.DisplayedEvidence = target
		if target > start then
			self.EvidenceScale.Scale = 1.15
			UIKit.Tween(self.EvidenceScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			task.spawn(function()
				local steps = 12
				for i = 1, steps do
					if self.DisplayedEvidence ~= target then
						return
					end
					self.EvidenceText.Text = Format.Money(start + (target - start) * i / steps)
					task.wait(0.03)
				end
			end)
		else
			self.EvidenceText.Text = Format.Money(target)
		end
	else
		self.EvidenceText.Text = Format.Money(target)
	end
end

---------------------------------------------------------------------------
-- Timer strip
---------------------------------------------------------------------------

function HUDController:_refreshTimer()
	local state = self.Controllers.ClientState
	local round = state.Round
	local theme = self.Controllers.UIKit.Theme
	local remaining = math.max(0, (round.EndsAt or 0) - state:Now())
	local map = MapConfig.Get(round.MapId or "DeadMall") or MapConfig.Maps.DeadMall
	local blink = (math.floor(os.clock() * 2) % 2) == 0
	if state:IsInMission() then
		if round.State == "Round" then
			self.TimerLabel.Text = string.format("REC  %s · %s", map.Case, map.Name)
			self.TimerText.Text = Format.Time(remaining)
			self.TimerText.TextColor3 = if remaining <= 30 then theme.AccentBright else theme.Text
			self.RecDot.Visible = blink
		elseif round.State == "Intro" then
			self.TimerLabel.Text = "DEPLOYING · " .. map.Name
			self.TimerText.Text = ""
			self.RecDot.Visible = blink
		else
			self.TimerLabel.Text = "INVESTIGATION OVER"
			self.TimerText.Text = "REPORT"
			self.TimerText.TextColor3 = theme.Gold
			self.RecDot.Visible = false
		end
	else
		self.TimerLabel.Text = "CAM 01 · P.I.A. HQ"
		self.TimerText.TextColor3 = theme.SubText
		self.TimerText.Text = os.date("!%H:%M") :: string
		self.RecDot.Visible = blink
	end
end

function HUDController:_refreshEvent()
	local state = self.Controllers.ClientState
	local event = state.Event
	if not event or not event.Id or not state:IsInRound() then
		self.EventPill.Visible = false
		return
	end
	local remaining = math.max(0, (event.EndsAt or 0) - state:Now())
	self.EventPill.Visible = true
	self.EventPill.BackgroundColor3 = event.Color or self.Controllers.UIKit.Theme.Accent
	self.EventText.Text = string.format("%s %s  %s", event.Icon or "!", event.Name or "EVENT", Format.Time(remaining))
end

---------------------------------------------------------------------------
-- Zone name (read from the map's Zones model)
---------------------------------------------------------------------------

function HUDController:_refreshZone()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local zoneId = nil
	if root and root:IsA("BasePart") then
		local map = Workspace:FindFirstChild("ActiveMap")
		local zones = map and map:FindFirstChild("Zones")
		if zones then
			for _, bounds in ipairs(zones:GetChildren()) do
				if bounds:IsA("BasePart") then
					local localPoint = bounds.CFrame:PointToObjectSpace(root.Position)
					local half = bounds.Size / 2
					if math.abs(localPoint.X) <= half.X and math.abs(localPoint.Z) <= half.Z and math.abs(localPoint.Y) <= half.Y + 4 then
						zoneId = bounds.Name
						break
					end
				end
			end
		end
		if not zoneId then
			local lobby = Workspace:FindFirstChild("Lobby")
			if lobby and self.Controllers.ClientState.InDarkRoom then
				zoneId = "DarkRoom"
			elseif lobby then
				zoneId = "Lobby"
			end
		end
	end
	self.CurrentZoneId = zoneId
	if zoneId == self.CurrentZone then
		return
	end
	self.CurrentZone = zoneId
	if not zoneId or not self.Controllers.ClientState:IsInRound() then
		return
	end
	local UIKit = self.Controllers.UIKit
	self.ZoneLabel.Text = MapConfig.GetZoneName(zoneId)
	UIKit.Tween(self.ZoneLabel, 0.3, { TextTransparency = 0, TextStrokeTransparency = 0.4 })
	local token = os.clock()
	self.ZoneToken = token
	task.delay(2.6, function()
		if self.ZoneToken == token then
			UIKit.Tween(self.ZoneLabel, 0.6, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
end

-- Reticle feedback used by PhotoController.
function HUDController:PulseReticle(color: Color3)
	local UIKit = self.Controllers.UIKit
	for _, part in ipairs(self.ReticleParts) do
		part.BackgroundColor3 = color
		part.BackgroundTransparency = 0
		UIKit.Tween(part, 0.6, { BackgroundTransparency = 0.5, BackgroundColor3 = Color3.new(1, 1, 1) })
	end
	self.ReticleScale.Scale = 0.8
	UIKit.Tween(self.ReticleScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
end

return HUDController
