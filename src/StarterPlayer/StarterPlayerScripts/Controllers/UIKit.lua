--[[
	UIKit (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/UIKit

	Tiny UI toolkit: instance builder, theme, responsive scaling (UIScale
	driven by screen size, mobile first), buttons with press feedback and a
	one-panel-at-a-time panel manager.
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UIKit = {}

UIKit.Theme = {
	Bg = Color3.fromRGB(12, 12, 16),
	Panel = Color3.fromRGB(22, 22, 30),
	Panel2 = Color3.fromRGB(34, 34, 46),
	Panel3 = Color3.fromRGB(48, 48, 64),
	Stroke = Color3.fromRGB(80, 80, 104),
	Text = Color3.fromRGB(242, 242, 248),
	SubText = Color3.fromRGB(165, 165, 182),
	Accent = Color3.fromRGB(235, 64, 64),
	Evidence = Color3.fromRGB(120, 230, 140),
	Gold = Color3.fromRGB(255, 210, 80),
	Good = Color3.fromRGB(110, 225, 130),
	Paper = Color3.fromRGB(244, 239, 228),
	Ink = Color3.fromRGB(28, 26, 24),
	Font = Enum.Font.GothamBold,
	FontBlack = Enum.Font.GothamBlack,
	FontBody = Enum.Font.GothamMedium,
	FontType = Enum.Font.SpecialElite,
}

UIKit.Panels = {}
UIKit.OpenPanelName = nil
UIKit.ButtonSound = nil :: ((...any) -> ())?

local player = Players.LocalPlayer

function UIKit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in pairs(props) do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UIKit.Corner(parent: Instance, radius: number | UDim?): UICorner
	local corner = Instance.new("UICorner")
	if typeof(radius) == "UDim" then
		corner.CornerRadius = radius
	else
		corner.CornerRadius = UDim.new(0, (radius :: number?) or 12)
	end
	corner.Parent = parent
	return corner
end

function UIKit.Stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or UIKit.Theme.Stroke
	stroke.Thickness = thickness or 2
	stroke.Transparency = transparency or 0
	if parent:IsA("GuiButton") or parent:IsA("Frame") or parent:IsA("ScrollingFrame") or parent:IsA("ViewportFrame") or parent:IsA("ImageLabel") then
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	stroke.Parent = parent
	return stroke
end

function UIKit.Padding(parent: Instance, all: number, horizontal: number?)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, all)
	padding.PaddingBottom = UDim.new(0, all)
	padding.PaddingLeft = UDim.new(0, horizontal or all)
	padding.PaddingRight = UDim.new(0, horizontal or all)
	padding.Parent = parent
	return padding
end

function UIKit.List(parent: Instance, direction: Enum.FillDirection?, spacing: number?, horizontal: Enum.HorizontalAlignment?, vertical: Enum.VerticalAlignment?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction or Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, spacing or 8)
	layout.HorizontalAlignment = horizontal or Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = vertical or Enum.VerticalAlignment.Top
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
	return layout
end

function UIKit.Label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = UIKit.Theme.Font,
		TextColor3 = UIKit.Theme.Text,
		TextSize = 18,
		TextWrapped = true,
		Size = UDim2.fromScale(1, 1),
	}
	for key, value in pairs(props) do
		defaults[key] = value
	end
	return UIKit.new("TextLabel", defaults)
end

function UIKit.Frame(props: { [string]: any }): Frame
	local defaults = {
		BackgroundColor3 = UIKit.Theme.Panel,
		BorderSizePixel = 0,
	}
	for key, value in pairs(props) do
		defaults[key] = value
	end
	return UIKit.new("Frame", defaults)
end

function UIKit.Tween(instance: Instance, duration: number, goals: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goals)
	tween:Play()
	return tween
end

-- A TextButton with rounded corners, press animation and click sound.
function UIKit.Button(props: { [string]: any }, onActivated: (() -> ())?): TextButton
	local defaults = {
		BackgroundColor3 = UIKit.Theme.Panel2,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = UIKit.Theme.FontBlack,
		TextColor3 = UIKit.Theme.Text,
		TextSize = 18,
		Text = "",
	}
	for key, value in pairs(props) do
		if key ~= "CornerRadius" then
			defaults[key] = value
		end
	end
	local button = UIKit.new("TextButton", defaults)
	UIKit.Corner(button, props.CornerRadius or 12)
	local scale = Instance.new("UIScale")
	scale.Parent = button
	button.MouseButton1Down:Connect(function()
		UIKit.Tween(scale, 0.08, { Scale = 0.92 })
	end)
	button.MouseButton1Up:Connect(function()
		UIKit.Tween(scale, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	button.MouseLeave:Connect(function()
		UIKit.Tween(scale, 0.12, { Scale = 1 })
	end)
	if onActivated then
		button.Activated:Connect(function()
			if UIKit.ButtonSound then
				UIKit.ButtonSound()
			end
			onActivated()
		end)
	end
	return button
end

function UIKit.IsTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Finds the ScreenGui cloned from StarterGui, or creates it if missing.
function UIKit.GetScreenGui(name: string, displayOrder: number?, fullscreen: boolean?): ScreenGui
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild(name)
	if not existing and StarterGui:FindFirstChild(name) then
		-- cloned from StarterGui when the character first spawns
		existing = playerGui:WaitForChild(name, 15)
	end
	local gui: ScreenGui
	if existing and existing:IsA("ScreenGui") then
		gui = existing
	else
		gui = Instance.new("ScreenGui")
		gui.Name = name
		gui.Parent = playerGui
	end
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = displayOrder or gui.DisplayOrder
	if fullscreen then
		gui.IgnoreGuiInset = true
		gui.ScreenInsets = Enum.ScreenInsets.None
	else
		gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	end
	return gui
end

-- Full-screen container whose contents scale with the screen (mobile first).
-- Design reference: ~600px short side = scale 1.
function UIKit.ScaledRoot(gui: ScreenGui): (Frame, UIScale)
	local root = UIKit.new("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local function update()
		local size = gui.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local value = math.clamp(math.min(size.X, size.Y) / 600, 0.7, 1.3)
		scale.Scale = value
		root.Size = UDim2.fromScale(1 / value, 1 / value)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	update()
	return root, scale
end

---------------------------------------------------------------------------
-- Panel manager: only one big panel (Album / Shop / ...) open at a time.
---------------------------------------------------------------------------

function UIKit.RegisterPanel(name: string, open: () -> (), close: () -> ())
	UIKit.Panels[name] = { Open = open, Close = close }
end

function UIKit.OpenPanel(name: string)
	if UIKit.OpenPanelName and UIKit.OpenPanelName ~= name then
		UIKit.ClosePanel(UIKit.OpenPanelName)
	end
	local panel = UIKit.Panels[name]
	if panel then
		UIKit.OpenPanelName = name
		panel.Open()
	end
end

function UIKit.ClosePanel(name: string)
	local panel = UIKit.Panels[name]
	if panel then
		panel.Close()
	end
	if UIKit.OpenPanelName == name then
		UIKit.OpenPanelName = nil
	end
end

function UIKit.TogglePanel(name: string)
	if UIKit.OpenPanelName == name then
		UIKit.ClosePanel(name)
	else
		UIKit.OpenPanel(name)
	end
end

function UIKit.IsAnyPanelOpen(): boolean
	return UIKit.OpenPanelName ~= nil
end

-- Standard modal panel: dark rounded card with a title bar and close button.
function UIKit.BuildPanel(parent: Instance, title: string, onClose: () -> ())
	local theme = UIKit.Theme
	local panel = UIKit.Frame({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.9),
		BackgroundColor3 = theme.Bg,
		BackgroundTransparency = 0.04,
		Visible = false,
		Parent = parent,
	})
	UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(980, 700), Parent = panel })
	UIKit.Corner(panel, 18)
	UIKit.Stroke(panel, theme.Stroke, 2, 0.2)

	local header = UIKit.Frame({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = theme.Panel,
		Parent = panel,
	})
	UIKit.Corner(header, 18)
	UIKit.Label({
		Name = "Title",
		Text = title,
		Font = theme.FontBlack,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(20, 0),
		Size = UDim2.new(0.6, 0, 1, 0),
		Parent = header,
	})
	local subtitle = UIKit.Label({
		Name = "Subtitle",
		Text = "",
		Font = theme.Font,
		TextSize = 18,
		TextColor3 = theme.Gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -72, 0, 0),
		Size = UDim2.new(0.4, -80, 1, 0),
		Parent = header,
	})
	UIKit.Button({
		Name = "Close",
		Text = "✕",
		TextSize = 24,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = theme.Accent,
		Parent = header,
	}, onClose)

	local tabs = UIKit.Frame({
		Name = "Tabs",
		Position = UDim2.fromOffset(12, 66),
		Size = UDim2.new(1, -24, 0, 44),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	UIKit.List(tabs, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

	local body = UIKit.Frame({
		Name = "Body",
		Position = UDim2.fromOffset(12, 118),
		Size = UDim2.new(1, -24, 1, -130),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = panel,
	})
	return panel, body, tabs, subtitle
end

function UIKit.AnimatePanel(panel: GuiObject, open: boolean)
	local scale = panel:FindFirstChild("PopScale") :: UIScale?
	if not scale then
		local created = Instance.new("UIScale")
		created.Name = "PopScale"
		created.Parent = panel
		scale = created
	end
	if open then
		panel.Visible = true;
		(scale :: UIScale).Scale = 0.9
		UIKit.Tween(scale :: UIScale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	else
		panel.Visible = false
	end
end

function UIKit.Scroller(parent: Instance): ScrollingFrame
	return UIKit.new("ScrollingFrame", {
		Name = "Scroll",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = UIKit.Theme.Stroke,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = parent,
	})
end

function UIKit.TabButton(parent: Instance, text: string, order: number, onClick: () -> ()): TextButton
	return UIKit.Button({
		Name = text,
		Text = text,
		TextSize = 16,
		LayoutOrder = order,
		Size = UDim2.fromOffset(150, 40),
		BackgroundColor3 = UIKit.Theme.Panel2,
		Parent = parent,
	}, onClick)
end

function UIKit.SetTabActive(tabs: Instance, activeName: string)
	for _, child in ipairs(tabs:GetChildren()) do
		if child:IsA("TextButton") then
			local active = child.Name == activeName
			child.BackgroundColor3 = if active then UIKit.Theme.Accent else UIKit.Theme.Panel2
		end
	end
end

return UIKit
