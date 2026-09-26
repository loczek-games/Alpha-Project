--[[
	SettingsController (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/SettingsController

	SETTINGS panel (lobby terminal, HQ menu, mission menu).
	  GAMEPLAY  JUMPSCARE INTENSITY FULL / REDUCED, BLOOD EFFECTS ON / OFF,
	            reduced flashes, screen shake, hints, ambience
	  AUDIO     volume per SoundGroup + a TEST SOUND button and the audio
	            diagnostics (how many sounds loaded / failed / use fallbacks)
	Every change is a request; DataService validates and saves it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"))

local SettingsController = {}
SettingsController.Tab = "GAMEPLAY"
SettingsController.IsOpen = false

-- Invert = the saved boolean means the opposite of the label (REDUCED jumpscares)
local TOGGLES = {
	{ Key = "ReducedJumpscares", Label = "JUMPSCARE INTENSITY", Description = "FULL: shake, flashes, distortion. REDUCED: short, softer, no strobing.", On = "REDUCED", Off = "FULL" },
	{ Key = "BloodEffects", Label = "BLOOD EFFECTS", Description = "Stylised blood splatter on the screen during attacks (never realistic gore)." },
	{ Key = "ReducedFlashes", Label = "REDUCED FLASHES", Description = "Softer camera flashes and reveal effects." },
	{ Key = "ScreenShake", Label = "SCREEN SHAKE", Description = "Camera shake on impacts and discoveries." },
	{ Key = "Hints", Label = "HINTS", Description = "Show tips for new investigators." },
	{ Key = "Ambience", Label = "AMBIENCE", Description = "Background hum, rain and ventilation." },
}

local VOLUMES = {
	{ Key = "MasterVolume", Label = "MASTER" },
	{ Key = "MusicVolume", Label = "MUSIC" },
	{ Key = "AmbienceVolume", Label = "AMBIENCE" },
	{ Key = "EquipmentVolume", Label = "EQUIPMENT + FOOTSTEPS" },
	{ Key = "VoiceVolume", Label = "ANOMALY VOICES" },
	{ Key = "JumpscareVolume", Label = "JUMPSCARES" },
}

function SettingsController:Init(controllers)
	self.Controllers = controllers
	local UIKit = controllers.UIKit
	self.Gui = UIKit.GetScreenGui("SettingsUI", 12)
	self.Root = UIKit.ScaledRoot(self.Gui)
	self.SettingRemote = Net.Event("SettingRequest")

	local panel, body, tabs, subtitle = UIKit.BuildPanel(self.Root, "SETTINGS", function()
		UIKit.ClosePanel("Settings")
	end)
	self.Panel, self.Body, self.Tabs, self.Subtitle = panel, body, tabs, subtitle
	for order, name in ipairs({ "GAMEPLAY", "AUDIO" }) do
		UIKit.TabButton(tabs, name, order, function()
			self.Tab = name
			self:Render()
		end)
	end
	UIKit.RegisterPanel("Settings", function()
		self.IsOpen = true
		self:Render()
		UIKit.AnimatePanel(panel, true)
	end, function()
		self.IsOpen = false
		UIKit.AnimatePanel(panel, false)
	end)
	controllers.ClientState.DataChanged:Connect(function()
		if self.IsOpen then
			self:Render()
		end
	end)
end

function SettingsController:Render()
	local UIKit = self.Controllers.UIKit
	UIKit.SetTabActive(self.Tabs, self.Tab)
	for _, child in ipairs(self.Body:GetChildren()) do
		child:Destroy()
	end
	local scroll = UIKit.Scroller(self.Body)
	UIKit.List(scroll, Enum.FillDirection.Vertical, 8)
	UIKit.Padding(scroll, 6)
	if self.Tab == "AUDIO" then
		self:_renderAudio(scroll)
	else
		self:_renderGameplay(scroll)
	end
end

function SettingsController:_renderGameplay(scroll: Instance)
	local UIKit = self.Controllers.UIKit
	local theme = UIKit.Theme
	local state = self.Controllers.ClientState
	self.Subtitle.Text = ""
	for order, setting in ipairs(TOGGLES) do
		local value = state:GetSetting(setting.Key) == true
		local row = UIKit.Card({ LayoutOrder = order, Size = UDim2.new(1, -12, 0, 70), Parent = scroll })
		UIKit.Label({ Text = setting.Label, Font = theme.FontType, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -170, 0, 26), Parent = row })
		UIKit.Label({ Text = setting.Description, Font = theme.Font, TextSize = 13, TextColor3 = theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(16, 36), Size = UDim2.new(1, -170, 0, 28), Parent = row })
		local text = if setting.On then (if value then setting.On else setting.Off) else (if value then "ON" else "OFF")
		local highlighted = if setting.On then not value else value
		UIKit.Button({
			Text = text,
			Font = theme.FontType,
			TextSize = 17,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(130, 44),
			BackgroundColor3 = if highlighted then theme.Accent else theme.Panel3,
			Parent = row,
		}, function()
			self.SettingRemote:FireServer(setting.Key, not value)
		end)
	end
end

function SettingsController:_renderAudio(scroll: Instance)
	local UIKit = self.Controllers.UIKit
	local theme = UIKit.Theme
	local state = self.Controllers.ClientState
	local audio = self.Controllers.AudioController
	local report = audio:GetDiagnostics()
	self.Subtitle.Text = string.format("AUDIO %d OK · %d FALLBACK · %d FAILED", report.Loaded, report.Fallback, report.Failed)
	for index, volume in ipairs(VOLUMES) do
		local value = tonumber(state:GetSetting(volume.Key)) or 1
		local row = UIKit.Card({ LayoutOrder = index, Size = UDim2.new(1, -12, 0, 56), Parent = scroll })
		UIKit.Label({ Text = volume.Label, Font = theme.FontType, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -230, 1, 0), Parent = row })
		local bar = UIKit.Frame({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -66, 0.5, 0), Size = UDim2.fromOffset(84, 28), BackgroundColor3 = theme.Panel3, Parent = row })
		local fill = UIKit.Frame({ Size = UDim2.fromScale(value, 1), BackgroundColor3 = theme.Accent, Parent = bar })
		fill.Name = "Fill"
		UIKit.Label({ Text = string.format("%d%%", math.floor(value * 100 + 0.5)), Font = theme.Font, TextSize = 15, TextStrokeTransparency = 0.4, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = bar })
		local function step(delta: number)
			local nextValue = math.clamp(math.floor((value + delta) * 10 + 0.5) / 10, 0, 1)
			if nextValue ~= value then
				self.SettingRemote:FireServer(volume.Key, nextValue)
			end
		end
		UIKit.Button({ Text = "-", TextSize = 22, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -156, 0.5, 0), Size = UDim2.fromOffset(44, 40), BackgroundColor3 = theme.Panel3, Parent = row }, function()
			step(-0.1)
		end)
		UIKit.Button({ Text = "+", TextSize = 22, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(44, 40), BackgroundColor3 = theme.Panel3, Parent = row }, function()
			step(0.1)
		end)
	end
	-- test + diagnostics
	local tools = UIKit.Card({ LayoutOrder = 100, Size = UDim2.new(1, -12, 0, 110), Parent = scroll })
	UIKit.Label({
		Text = if report.BanksMissing > 0 then string.format("%d sound banks not uploaded yet - built-in fallback sounds are used. See docs/AUDIO.md.", report.BanksMissing) else "All sound banks configured.",
		Font = theme.Font,
		TextSize = 13,
		TextColor3 = if report.BanksMissing > 0 then theme.Gold else theme.Good,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -32, 0, 40),
		Parent = tools,
	})
	UIKit.Button({ Text = "TEST SOUND", Font = theme.FontType, TextSize = 16, Position = UDim2.new(0, 16, 1, -52), Size = UDim2.fromOffset(170, 42), BackgroundColor3 = theme.Accent, Parent = tools }, function()
		audio:TestSequence()
	end)
	UIKit.Button({ Text = "PRINT REPORT", Font = theme.FontType, TextSize = 16, Position = UDim2.new(0, 200, 1, -52), Size = UDim2.fromOffset(170, 42), BackgroundColor3 = theme.Panel3, Parent = tools }, function()
		audio:PrintReport()
		self.Controllers.AnnouncementController:Toast("Audio report printed to the Developer Console (F9).", Color3.fromRGB(200, 200, 210))
	end)
end

return SettingsController
