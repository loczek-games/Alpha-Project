--[[
	LightingController (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/LightingController

	The ONE place that sets Lighting on the client. Lighting objects live in
	the place file (Atmosphere "Atmosphere", ColorCorrection "Grade", Bloom
	"Glow", DepthOfField "Focus"); this controller blends between presets:

	  Lobby     warm agency HQ, readable, light haze
	  Mall      night, cold, dense haze, desaturated - dark but navigable:
	            ceiling panels, emergency lights and neon light the way and
	            the flashlight matters in the unlit stores
	  Blackout  the mall with the power cut (map attribute "Blackout")
	  DarkRoom  red safelight

	Map attributes set by MapService are applied here: TintColor /
	TintSaturation / TintContrast (event tints) and LightningAt (a lightning
	flash through the skylights). Depth of field is used sparingly: only a
	slight far blur in the mall on high-end devices.
]]

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LightingController = {}
LightingController.Preset = nil :: string?

local PRESETS = {
	Lobby = {
		Lighting = { Ambient = Color3.fromRGB(44, 40, 38), OutdoorAmbient = Color3.fromRGB(36, 38, 46), Brightness = 0.6, ExposureCompensation = 0.25, EnvironmentDiffuseScale = 0.35, EnvironmentSpecularScale = 0.4 },
		Atmosphere = { Density = 0.22, Haze = 0.7, Color = Color3.fromRGB(70, 66, 62), Decay = Color3.fromRGB(30, 28, 26) },
		Grade = { Brightness = 0.02, Contrast = 0.1, Saturation = -0.12, TintColor = Color3.fromRGB(255, 246, 236) },
		Glow = { Intensity = 0.6, Size = 22, Threshold = 1.5 },
		Focus = false,
	},
	Mall = {
		Lighting = { Ambient = Color3.fromRGB(17, 17, 20), OutdoorAmbient = Color3.fromRGB(22, 23, 30), Brightness = 0.35, ExposureCompensation = 0.12, EnvironmentDiffuseScale = 0.22, EnvironmentSpecularScale = 0.45 },
		Atmosphere = { Density = 0.36, Haze = 1.7, Color = Color3.fromRGB(46, 50, 58), Decay = Color3.fromRGB(18, 20, 26) },
		Grade = { Brightness = 0.01, Contrast = 0.16, Saturation = -0.3, TintColor = Color3.fromRGB(238, 246, 255) },
		Glow = { Intensity = 0.55, Size = 20, Threshold = 1.55 },
		Focus = true,
	},
	Blackout = {
		Lighting = { Ambient = Color3.fromRGB(6, 6, 8), OutdoorAmbient = Color3.fromRGB(10, 11, 16), Brightness = 0.2, ExposureCompensation = -0.05, EnvironmentDiffuseScale = 0.12, EnvironmentSpecularScale = 0.35 },
		Atmosphere = { Density = 0.42, Haze = 2.2, Color = Color3.fromRGB(26, 28, 34), Decay = Color3.fromRGB(10, 10, 14) },
		Grade = { Brightness = -0.02, Contrast = 0.2, Saturation = -0.4, TintColor = Color3.fromRGB(226, 236, 255) },
		Glow = { Intensity = 0.7, Size = 18, Threshold = 1.3 },
		Focus = true,
	},
	DarkRoom = {
		Lighting = { Ambient = Color3.fromRGB(40, 8, 8), OutdoorAmbient = Color3.fromRGB(20, 6, 6), Brightness = 0.3, ExposureCompensation = 0.2, EnvironmentDiffuseScale = 0.2, EnvironmentSpecularScale = 0.3 },
		Atmosphere = { Density = 0.25, Haze = 0.8, Color = Color3.fromRGB(60, 20, 20), Decay = Color3.fromRGB(30, 8, 8) },
		Grade = { Brightness = 0.02, Contrast = 0.12, Saturation = -0.05, TintColor = Color3.fromRGB(255, 220, 215) },
		Glow = { Intensity = 0.8, Size = 24, Threshold = 1.2 },
		Focus = false,
	},
}

local function ensure(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = Lighting
	return created
end

function LightingController:Init(controllers)
	self.Controllers = controllers
	self.Atmosphere = ensure("Atmosphere", "Atmosphere") :: Atmosphere
	self.Grade = ensure("ColorCorrectionEffect", "Grade") :: ColorCorrectionEffect
	self.Glow = ensure("BloomEffect", "Glow") :: BloomEffect
	self.Focus = ensure("DepthOfFieldEffect", "Focus") :: DepthOfFieldEffect
	self.Tint = Instance.new("ColorCorrectionEffect")
	self.Tint.Name = "EventTint"
	self.Tint.Parent = Lighting
	local state = controllers.ClientState
	state.RoundChanged:Connect(function()
		self:Refresh()
	end)
	state.DarkRoomChanged:Connect(function()
		self:Refresh()
	end)
end

function LightingController:Start()
	local map = Workspace:WaitForChild("ActiveMap", 20)
	if map then
		map:GetAttributeChangedSignal("Blackout"):Connect(function()
			self:Refresh()
		end)
		for _, key in ipairs({ "TintColor", "TintSaturation", "TintContrast" }) do
			map:GetAttributeChangedSignal(key):Connect(function()
				self:_applyTint(map)
			end)
		end
		map:GetAttributeChangedSignal("LightningAt"):Connect(function()
			self:Lightning()
		end)
		self:_applyTint(map)
	end
	self:Refresh(true)
end

-- The Dark Room's grade follows the owner's decor safelight colour.
function LightingController:SetSafelight(color: Color3)
	local preset = PRESETS.DarkRoom
	local function scale(k: number): Color3
		return Color3.new(color.R * k, color.G * k, color.B * k)
	end
	preset.Lighting.Ambient = scale(0.16)
	preset.Lighting.OutdoorAmbient = scale(0.08)
	preset.Atmosphere.Color = scale(0.24)
	preset.Atmosphere.Decay = scale(0.12)
	preset.Grade.TintColor = Color3.new(1, 1, 1):Lerp(color, 0.14)
	if self.Preset == "DarkRoom" then
		self.Preset = nil
		self:Refresh()
	end
end

function LightingController:_wanted(): string
	local state = self.Controllers.ClientState
	if state.InDarkRoom then
		return "DarkRoom"
	end
	if state:IsInMission() then
		local map = Workspace:FindFirstChild("ActiveMap")
		if map and map:GetAttribute("Blackout") then
			return "Blackout"
		end
		return "Mall"
	end
	return "Lobby"
end

function LightingController:Refresh(instant: boolean?)
	local name = self:_wanted()
	if name == self.Preset then
		return
	end
	self.Preset = name
	local preset = PRESETS[name]
	local info = TweenInfo.new(if instant then 0 else 1.2, Enum.EasingStyle.Sine)
	local function apply(target: Instance, goals)
		if instant then
			for key, value in pairs(goals) do
				(target :: any)[key] = value
			end
		else
			TweenService:Create(target, info, goals):Play()
		end
	end
	apply(Lighting, preset.Lighting)
	apply(self.Atmosphere, preset.Atmosphere)
	apply(self.Grade, preset.Grade)
	apply(self.Glow, preset.Glow)
	-- depth of field only where it helps, and never on low-end devices
	local quality = UserSettings().GameSettings.SavedQualityLevel.Value
	self.Focus.Enabled = preset.Focus and (quality == 0 or quality >= 7)
	self.Focus.FarIntensity = 0.1
	self.Focus.FocusDistance = 40
	self.Focus.InFocusRadius = 55
	self.Focus.NearIntensity = 0
end

function LightingController:_applyTint(map: Instance)
	local tint = map:GetAttribute("TintColor")
	local enabled = typeof(tint) == "Color3"
	self.Tint.Enabled = enabled
	if enabled then
		TweenService:Create(self.Tint, TweenInfo.new(1.5), {
			TintColor = tint,
			Saturation = map:GetAttribute("TintSaturation") or 0,
			Contrast = map:GetAttribute("TintContrast") or 0,
		}):Play()
	end
end

-- Lightning through the skylights (thunder comes from EnvironmentService).
function LightingController:Lightning()
	if not self.Controllers.ClientState:IsInMission() then
		return
	end
	local reduced = self.Controllers.ClientState:GetSetting("ReducedFlashes") == true
	local base = Lighting.OutdoorAmbient
	local baseExposure = Lighting.ExposureCompensation
	local flashes = if reduced then 1 else math.random(2, 3)
	task.spawn(function()
		for _ = 1, flashes do
			Lighting.OutdoorAmbient = Color3.fromRGB(150, 160, 190)
			Lighting.ExposureCompensation = baseExposure + (if reduced then 0.3 else 0.9)
			task.wait(0.05 + math.random() * 0.05)
			Lighting.OutdoorAmbient = base
			Lighting.ExposureCompensation = baseExposure
			task.wait(0.08 + math.random() * 0.12)
		end
	end)
end

return LightingController
