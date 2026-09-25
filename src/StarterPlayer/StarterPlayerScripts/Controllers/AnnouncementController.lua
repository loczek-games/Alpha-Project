--[[
	AnnouncementController (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/AnnouncementController

	Server announcements:
	  Toast  - small stacked message under the timer
	  Banner - big centre-top headline ("⚠️ PARANORMAL ACTIVITY IS RISING")
	  Reveal - short full-screen dramatic reveal for Nightmare+ discoveries
	  Hint   - onboarding tip near the bottom of the screen
	Everything is short and never blocks input, so gameplay continues.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Net = require(Modules:WaitForChild("Net"))
local RarityConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("RarityConfig"))

local AnnouncementController = {}

local MAX_TOASTS = 3

function AnnouncementController:Init(controllers)
	self.Controllers = controllers
	local UIKit = controllers.UIKit
	local hud = controllers.HUDController
	self.Root = hud.Root

	self.ToastHolder = UIKit.Frame({
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 132),
		Size = UDim2.fromOffset(460, 150),
		BackgroundTransparency = 1,
		Parent = self.Root,
	})
	UIKit.List(self.ToastHolder, Enum.FillDirection.Vertical, 6)
	self.ToastCounter = 0

	self.Overlay = UIKit.GetScreenGui("OverlayUI", 50, true)
	self.OverlayRoot = UIKit.ScaledRoot(self.Overlay)

	Net.Event("Announce").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.Kind == "Toast" then
			self:Toast(payload.Text, payload.Color, payload.Duration)
		elseif payload.Kind == "Banner" then
			self:Banner(payload.Text, payload.SubText, payload.Color, payload.Duration)
		elseif payload.Kind == "Reveal" then
			self:Reveal(payload)
		elseif payload.Kind == "Hint" then
			self:Hint(payload.Text, payload.Duration)
		end
	end)

	-- first-time onboarding hints
	local state = controllers.ClientState
	state.RoundChanged:Connect(function(round, previous)
		if not state:GetSetting("Hints") then
			return
		end
		if round.State == "Round" and (not previous or previous.State ~= "Round") and state:CountDiscovered() < 3 then
			task.delay(4, function()
				local isTouch = UIKit.IsTouch()
				self:Hint(if isTouch then "📸 Spot something WRONG, aim at it and tap PHOTO!" else "📸 Spot something WRONG, aim at it and CLICK (or press E)!", 6)
			end)
		end
	end)
end

function AnnouncementController:Toast(text: string, color: Color3?, duration: number?)
	local UIKit = self.Controllers.UIKit
	local theme = UIKit.Theme
	self.ToastCounter += 1
	local toast = UIKit.Frame({
		Name = "Toast",
		LayoutOrder = self.ToastCounter,
		Size = UDim2.fromOffset(460, 40),
		BackgroundColor3 = theme.Bg,
		BackgroundTransparency = 1,
		Parent = self.ToastHolder,
	})
	UIKit.Corner(toast, 12)
	local bar = UIKit.Frame({
		Size = UDim2.new(0, 6, 1, 0),
		BackgroundColor3 = color or theme.Accent,
		BackgroundTransparency = 1,
		Parent = toast,
	})
	UIKit.Corner(bar, 3)
	local label = UIKit.Label({
		Text = text,
		TextSize = 17,
		TextTransparency = 1,
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -24, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = toast,
	})
	UIKit.Tween(toast, 0.2, { BackgroundTransparency = 0.2 })
	UIKit.Tween(bar, 0.2, { BackgroundTransparency = 0 })
	UIKit.Tween(label, 0.2, { TextTransparency = 0 })

	local toasts = {}
	for _, child in ipairs(self.ToastHolder:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #toasts > MAX_TOASTS do
		local oldest = table.remove(toasts, 1)
		if oldest then
			oldest:Destroy()
		end
	end

	task.delay(duration or 3.5, function()
		if toast.Parent then
			UIKit.Tween(toast, 0.3, { BackgroundTransparency = 1 })
			UIKit.Tween(bar, 0.3, { BackgroundTransparency = 1 })
			UIKit.Tween(label, 0.3, { TextTransparency = 1 })
			task.wait(0.32)
			toast:Destroy()
		end
	end)
end

function AnnouncementController:Banner(text: string, subText: string?, color: Color3?, duration: number?)
	local UIKit = self.Controllers.UIKit
	local theme = UIKit.Theme
	local Sfx = self.Controllers.Sfx
	if self.CurrentBanner then
		self.CurrentBanner:Destroy()
	end
	Sfx.Play("Announce")
	local holder = UIKit.Frame({
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(820, 110),
		BackgroundTransparency = 1,
		Parent = self.Root,
	})
	self.CurrentBanner = holder
	local main = UIKit.Label({
		Text = text,
		Font = theme.FontBlack,
		TextSize = 40,
		TextColor3 = color or theme.Accent,
		TextStrokeTransparency = 0.2,
		TextTransparency = 1,
		Size = UDim2.new(1, 0, 0, 64),
		Parent = holder,
	})
	local sub = UIKit.Label({
		Text = subText or "",
		Font = theme.Font,
		TextSize = 20,
		TextStrokeTransparency = 0.4,
		TextTransparency = 1,
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, 0, 0, 30),
		Parent = holder,
	})
	local scale = UIKit.new("UIScale", { Scale = 1.4, Parent = holder })
	UIKit.Tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	UIKit.Tween(main, 0.2, { TextTransparency = 0 })
	UIKit.Tween(sub, 0.3, { TextTransparency = 0 })
	if self.Controllers.ClientState:GetSetting("ScreenShake") then
		task.spawn(function()
			for _ = 1, 8 do
				if not holder.Parent then
					return
				end
				holder.Position = UDim2.new(0.5, math.random(-5, 5), 0.3, math.random(-3, 3))
				task.wait(0.03)
			end
			holder.Position = UDim2.fromScale(0.5, 0.3)
		end)
	end
	task.delay(duration or 3, function()
		if holder.Parent then
			UIKit.Tween(main, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
			UIKit.Tween(sub, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
			task.wait(0.45)
			holder:Destroy()
		end
	end)
end

function AnnouncementController:Hint(text: string, duration: number?)
	local UIKit = self.Controllers.UIKit
	local theme = UIKit.Theme
	if self.CurrentHint then
		self.CurrentHint:Destroy()
	end
	local hint = UIKit.Frame({
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(560, 48),
		BackgroundColor3 = theme.Paper,
		BackgroundTransparency = 0.05,
		Parent = self.Root,
	})
	self.CurrentHint = hint
	UIKit.Corner(hint, 14)
	UIKit.Label({ Text = text, Font = theme.FontBlack, TextSize = 18, TextColor3 = theme.Ink, Parent = hint })
	local scale = UIKit.new("UIScale", { Scale = 0.6, Parent = hint })
	UIKit.Tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(duration or 5, function()
		if hint.Parent then
			UIKit.Tween(scale, 0.2, { Scale = 0 })
			task.wait(0.22)
			hint:Destroy()
		end
	end)
end

--[[
	Dramatic reveal: ~3.5 seconds, full screen but non-blocking.
	  IMPOSSIBLE ANOMALY / THE OBSERVER / 1 / 100,000 / FOUND BY NAME
]]
function AnnouncementController:Reveal(payload)
	local UIKit = self.Controllers.UIKit
	local theme = UIKit.Theme
	local state = self.Controllers.ClientState
	local Sfx = self.Controllers.Sfx
	local reduced = state:GetSetting("ReducedFlashes") == true
	local shake = state:GetSetting("ScreenShake") == true
	local color = payload.Color or RarityConfig.GetColor(payload.Rarity or "Impossible")

	if self.CurrentReveal then
		self.CurrentReveal:Destroy()
	end
	Sfx.Play("Reveal")

	local holder = UIKit.Frame({
		Name = "Reveal",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Parent = self.OverlayRoot,
	})
	self.CurrentReveal = holder
	UIKit.Tween(holder, 0.25, { BackgroundTransparency = 0.4 })

	-- scanlines
	for i = 0, 23 do
		UIKit.Frame({
			Position = UDim2.fromScale(0, i / 24),
			Size = UDim2.new(1, 0, 0, 2),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.93,
			Parent = holder,
		})
	end

	local content = UIKit.Frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(900, 300),
		BackgroundTransparency = 1,
		Parent = holder,
	})
	local function line(text: string, y: number, size: number, textColor: Color3, font: Enum.Font?)
		return UIKit.Label({
			Text = text,
			Font = font or theme.FontBlack,
			TextSize = size,
			TextColor3 = textColor,
			TextStrokeTransparency = 0.3,
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, size + 10),
			Parent = content,
		})
	end
	line(payload.Title or "ANOMALY", 0, 30, color)
	local nameY = 44
	-- chromatic aberration copies of the name
	local red = line(payload.Name or "???", nameY, 64, Color3.fromRGB(255, 40, 60))
	local cyan = line(payload.Name or "???", nameY, 64, Color3.fromRGB(40, 240, 255))
	red.TextStrokeTransparency = 1
	cyan.TextStrokeTransparency = 1
	red.TextTransparency = 0.35
	cyan.TextTransparency = 0.35
	line(payload.Name or "???", nameY, 64, Color3.new(1, 1, 1))
	line(payload.Odds or "", 124, 30, theme.Text, theme.FontType)
	line("FOUND BY " .. string.upper(payload.Finder or "SOMEONE"), 168, 28, theme.Gold)

	local scale = UIKit.new("UIScale", { Scale = 1.6, Parent = content })
	UIKit.Tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)

	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "RevealGrade"
	grade.Saturation = if reduced then -0.3 else -0.8
	grade.Contrast = if reduced then 0.1 else 0.4
	grade.TintColor = color:Lerp(Color3.new(1, 1, 1), 0.6)
	grade.Parent = Lighting
	TweenService:Create(grade, TweenInfo.new(2.6, Enum.EasingStyle.Quad), { Saturation = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1) }):Play()

	local camera = Workspace.CurrentCamera
	if camera and shake then
		local fov = camera.FieldOfView
		camera.FieldOfView = fov - 12
		TweenService:Create(camera, TweenInfo.new(0.8, Enum.EasingStyle.Elastic), { FieldOfView = fov }):Play()
	end

	task.spawn(function()
		local elapsed = 0
		while elapsed < 1.2 and holder.Parent do
			local jitter = if reduced then 2 else 6
			red.Position = UDim2.fromOffset(math.random(-jitter, jitter), nameY + math.random(-2, 2))
			cyan.Position = UDim2.fromOffset(math.random(-jitter, jitter), nameY + math.random(-2, 2))
			if shake then
				content.Position = UDim2.new(0.5, math.random(-4, 4), 0.45, math.random(-3, 3))
			end
			elapsed += task.wait(0.04)
		end
		red.Position = UDim2.fromOffset(-2, nameY)
		cyan.Position = UDim2.fromOffset(2, nameY)
		content.Position = UDim2.fromScale(0.5, 0.45)
	end)

	task.delay(3.4, function()
		if holder.Parent then
			for _, descendant in ipairs(holder:GetDescendants()) do
				if descendant:IsA("TextLabel") then
					UIKit.Tween(descendant, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
				elseif descendant:IsA("Frame") then
					UIKit.Tween(descendant, 0.4, { BackgroundTransparency = 1 })
				end
			end
			UIKit.Tween(holder, 0.4, { BackgroundTransparency = 1 })
			task.wait(0.45)
			holder:Destroy()
		end
		grade:Destroy()
	end)
end

return AnnouncementController
