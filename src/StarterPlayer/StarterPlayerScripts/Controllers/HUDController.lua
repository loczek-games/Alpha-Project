--[[
	HUDController (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/HUDController

	Minimal, mobile-first HUD: round timer, current event, Evidence, Album
	and Camera buttons, a subtle viewfinder reticle and the current zone.
	(The big PHOTO button is owned by PhotoController.)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local CameraConfig = require(Config:WaitForChild("CameraConfig"))
local Format = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Format"))

local HUDController = {}

local player = Players.LocalPlayer

function HUDController:Init(controllers)
	self.Controllers = controllers
	local UIKit = controllers.UIKit
	local theme = UIKit.Theme
	local state = controllers.ClientState

	self.Gui = UIKit.GetScreenGui("HUD", 1)
	self.Root = UIKit.ScaledRoot(self.Gui)
	local root = self.Root

	-- Round timer ------------------------------------------------------------
	local timer = UIKit.Frame({
		Name = "Timer",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(250, 46),
		BackgroundColor3 = theme.Bg,
		BackgroundTransparency = 0.25,
		Parent = root,
	})
	UIKit.Corner(timer, 23)
	UIKit.Stroke(timer, theme.Stroke, 1.5, 0.4)
	self.RecDot = UIKit.Frame({
		Name = "RecDot",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = theme.Accent,
		Parent = timer,
	})
	UIKit.Corner(self.RecDot, 6)
	self.TimerLabel = UIKit.Label({
		Name = "Label",
		Text = "LOBBY",
		Font = theme.FontBlack,
		TextSize = 14,
		TextColor3 = theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(36, 0),
		Size = UDim2.new(0.55, -36, 1, 0),
		Parent = timer,
	})
	self.TimerText = UIKit.Label({
		Name = "Time",
		Text = "0:00",
		Font = theme.FontBlack,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 0),
		Size = UDim2.new(0.45, 0, 1, 0),
		Parent = timer,
	})

	-- Current event ------------------------------------------------------------
	self.EventPill = UIKit.Frame({
		Name = "Event",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(300, 34),
		BackgroundColor3 = Color3.fromRGB(120, 60, 200),
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = root,
	})
	UIKit.Corner(self.EventPill, 17)
	self.EventText = UIKit.Label({
		Text = "",
		Font = theme.FontBlack,
		TextSize = 16,
		Parent = self.EventPill,
	})

	-- Zone name (fades in when you walk into a new area) ---------------------------
	self.ZoneLabel = UIKit.Label({
		Name = "Zone",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 100),
		Size = UDim2.fromOffset(320, 26),
		Text = "",
		Font = theme.FontType,
		TextSize = 20,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = root,
	})

	-- Evidence -------------------------------------------------------------------------
	local evidence = UIKit.Frame({
		Name = "Evidence",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(190, 46),
		BackgroundColor3 = theme.Bg,
		BackgroundTransparency = 0.25,
		Parent = root,
	})
	UIKit.Corner(evidence, 14)
	UIKit.Stroke(evidence, theme.Evidence, 1.5, 0.5)
	UIKit.Label({
		Text = "EVIDENCE",
		Font = theme.FontBlack,
		TextSize = 11,
		TextColor3 = theme.SubText,
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -24, 0, 12),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = evidence,
	})
	self.EvidenceText = UIKit.Label({
		Text = "$0",
		Font = theme.FontBlack,
		TextSize = 24,
		TextColor3 = theme.Evidence,
		Position = UDim2.fromOffset(12, 16),
		Size = UDim2.new(1, -24, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = evidence,
	})
	self.EvidenceScale = UIKit.new("UIScale", { Parent = evidence })
	self.DisplayedEvidence = 0

	-- Left buttons: Album + Camera -------------------------------------------------------------
	local left = UIKit.Frame({
		Name = "LeftButtons",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.4, 0),
		Size = UDim2.fromOffset(84, 190),
		BackgroundTransparency = 1,
		Parent = root,
	})
	UIKit.List(left, Enum.FillDirection.Vertical, 12)
	local function sideButton(name: string, icon: string, label: string, order: number, callback: () -> ())
		local button = UIKit.Button({
			Name = name,
			LayoutOrder = order,
			Size = UDim2.fromOffset(84, 84),
			BackgroundColor3 = theme.Bg,
			BackgroundTransparency = 0.2,
			CornerRadius = 20,
			Parent = left,
		}, callback)
		UIKit.Stroke(button, theme.Stroke, 1.5, 0.3)
		UIKit.Label({ Text = icon, TextSize = 34, Size = UDim2.new(1, 0, 0.66, 0), Parent = button })
		local text = UIKit.Label({
			Name = "Caption",
			Text = label,
			Font = theme.FontBlack,
			TextSize = 12,
			Position = UDim2.fromScale(0, 0.62),
			Size = UDim2.new(1, 0, 0.34, 0),
			Parent = button,
		})
		return button, text
	end
	sideButton("Album", "📖", "ALBUM", 1, function()
		UIKit.TogglePanel("Album")
	end)
	local _, cameraCaption = sideButton("Camera", "📷", "CAMERA", 2, function()
		UIKit.TogglePanel("Shop")
	end)
	self.CameraCaption = cameraCaption

	-- Viewfinder reticle ------------------------------------------------------------------------
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
		local horizontal = UIKit.Frame({ AnchorPoint = corner[1], Position = corner[2], Size = UDim2.fromOffset(20, 3), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.45, Parent = reticle })
		local vertical = UIKit.Frame({ AnchorPoint = corner[1], Position = corner[2], Size = UDim2.fromOffset(3, 20), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.45, Parent = reticle })
		table.insert(self.ReticleParts, horizontal)
		table.insert(self.ReticleParts, vertical)
	end
	local dot = UIKit.Frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.35, Parent = reticle })
	UIKit.Corner(dot, 3)
	table.insert(self.ReticleParts, dot)
	self.ReticleScale = UIKit.new("UIScale", { Parent = reticle })

	-- Wire up state -------------------------------------------------------------------------
	state.DataChanged:Connect(function(data, previous)
		self:_onData(data, previous)
	end)
	state.EventChanged:Connect(function()
		self:_refreshEvent()
	end)
	state.RoundChanged:Connect(function()
		self:_refreshTimer()
	end)
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
	local camera = CameraConfig.Get(self.Controllers.ClientState:GetEquippedCameraId())
	if camera then
		self.CameraCaption.Text = (string.upper(camera.Name):gsub(" CAMERA", ""))
	end
end

function HUDController:_refreshTimer()
	local state = self.Controllers.ClientState
	local round = state.Round
	local remaining = math.max(0, (round.EndsAt or 0) - state:Now())
	local theme = self.Controllers.UIKit.Theme
	if round.State == "Round" then
		self.TimerLabel.Text = GameConfig.MallName
		self.TimerText.Text = Format.Time(remaining)
		self.TimerText.TextColor3 = if remaining <= 30 then theme.Accent else theme.Text
		self.RecDot.Visible = (math.floor(os.clock() * 2) % 2) == 0
	elseif round.State == "Results" then
		self.TimerLabel.Text = "ROUND OVER"
		self.TimerText.Text = "RESULTS"
		self.TimerText.TextColor3 = theme.Gold
		self.RecDot.Visible = false
	else
		self.RecDot.Visible = false
		self.TimerText.TextColor3 = theme.Text
		if round.Waiting then
			self.TimerLabel.Text = "WAITING FOR"
			self.TimerText.Text = "PLAYERS"
		else
			self.TimerLabel.Text = "NEXT ROUND"
			self.TimerText.Text = Format.Time(remaining)
		end
	end
end

function HUDController:_refreshEvent()
	local state = self.Controllers.ClientState
	local event = state.Event
	if not event or not event.Id then
		self.EventPill.Visible = false
		return
	end
	local remaining = math.max(0, (event.EndsAt or 0) - state:Now())
	self.EventPill.Visible = true
	self.EventPill.BackgroundColor3 = event.Color or Color3.fromRGB(120, 60, 200)
	self.EventText.Text = string.format("%s %s  %s", event.Icon or "⚠️", event.Name or "EVENT", Format.Time(remaining))
end

function HUDController:_refreshZone()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local zoneName = nil
	if root and root:IsA("BasePart") then
		local map = Workspace:FindFirstChild("Map")
		local mall = map and map:FindFirstChild("DeadMall")
		local zones = mall and mall:FindFirstChild("Zones")
		if zones then
			for _, bounds in ipairs(zones:GetChildren()) do
				if bounds:IsA("BasePart") then
					local localPoint = bounds.CFrame:PointToObjectSpace(root.Position)
					local half = bounds.Size / 2
					if math.abs(localPoint.X) <= half.X and math.abs(localPoint.Z) <= half.Z and math.abs(localPoint.Y) <= half.Y + 4 then
						zoneName = bounds:GetAttribute("DisplayName") or bounds.Name
						break
					end
				end
			end
		end
	end
	if zoneName == self.CurrentZone then
		return
	end
	self.CurrentZone = zoneName
	if not zoneName then
		return
	end
	local UIKit = self.Controllers.UIKit
	self.ZoneLabel.Text = "📍 " .. zoneName
	UIKit.Tween(self.ZoneLabel, 0.3, { TextTransparency = 0, TextStrokeTransparency = 0.5 })
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
		UIKit.Tween(part, 0.6, { BackgroundTransparency = 0.45, BackgroundColor3 = Color3.new(1, 1, 1) })
	end
	self.ReticleScale.Scale = 0.8
	UIKit.Tween(self.ReticleScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
end

return HUDController
