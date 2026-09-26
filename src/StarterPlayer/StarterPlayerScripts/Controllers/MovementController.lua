--[[
	MovementController (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/MovementController

	Walk / Run / Sneak. Running is fast but loud; sneaking is slow and almost
	silent (sound-hunting anomalies!). The server sets the actual speed.
	  PC      : hold Left Shift to run, hold Left Ctrl or C to sneak
	  Gamepad : press the left stick (L3) to toggle running
	  Mobile  : RUN toggle button; tilt the thumbstick only a little to sneak
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"))

local MovementController = {}
MovementController.Mode = "Walk"

function MovementController:Init(controllers)
	self.Controllers = controllers
	self.Remote = Net.Event("MovementMode")
	local UIKit = controllers.UIKit
	local theme = UIKit.Theme
	local hud = controllers.HUDController

	self.RunButton = UIKit.Button({
		Name = "RunButton",
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(64, 64),
		BackgroundColor3 = theme.Bg,
		BackgroundTransparency = 0.25,
		Text = "🏃\nRUN",
		TextSize = 13,
		CornerRadius = 32,
		Visible = false,
		Parent = hud.Gui,
	}, function()
		self:SetMode(if self.Mode == "Run" then "Walk" else "Run")
	end)
	UIKit.Stroke(self.RunButton, theme.Stroke, 1.5, 0.3)

	local held = { Run = false, Sneak = false }
	local function refreshHeld()
		if held.Sneak then
			self:SetMode("Sneak")
		elseif held.Run then
			self:SetMode("Run")
		else
			self:SetMode("Walk")
		end
	end
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftShift then
			held.Run = true
			refreshHeld()
		elseif input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.C then
			held.Sneak = true
			refreshHeld()
		elseif input.KeyCode == Enum.KeyCode.ButtonL3 then
			self:SetMode(if self.Mode == "Run" then "Walk" else "Run")
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift then
			held.Run = false
			refreshHeld()
		elseif input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.C then
			held.Sneak = false
			refreshHeld()
		end
	end)

	local function layout()
		local touch = UIKit.IsTouch() or UserInputService:GetLastInputType() == Enum.UserInputType.Touch
		self.RunButton.Visible = touch
		local photo = controllers.PhotoController and controllers.PhotoController.Button
		if photo then
			-- sits just above-left of the PHOTO button
			local size = photo.AbsoluteSize.X
			self.RunButton.Position = UDim2.new(photo.Position.X.Scale, photo.Position.X.Offset - size - 10, photo.Position.Y.Scale, photo.Position.Y.Offset - size * 0.55)
		end
	end
	hud.Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		task.defer(layout)
	end)
	UserInputService.LastInputTypeChanged:Connect(layout)
	task.defer(layout)

	-- the server resets the movement mode when the character respawns
	game:GetService("Players").LocalPlayer.CharacterAdded:Connect(function()
		self.Mode = "Walk"
		held.Run = false
		held.Sneak = false
		self:_refreshButton()
	end)
end

function MovementController:SetMode(mode: string)
	if self.Mode == mode then
		return
	end
	self.Mode = mode
	self.Remote:FireServer(mode)
	self:_refreshButton()
end

function MovementController:_refreshButton()
	local theme = self.Controllers.UIKit.Theme
	self.RunButton.BackgroundColor3 = if self.Mode == "Run" then theme.Accent else theme.Bg
end

return MovementController
