--[[
	CameraConfig (ModuleScript)
	Location: ReplicatedStorage/Config/CameraConfig

	Cameras unlock new ways to play instead of raw luck.
	Each camera can declare Abilities. An anomaly with RequiredAbility = "Night"
	(see AnomalyConfig) can only be photographed with a camera whose
	Abilities.Night == true. Set Implemented = true when a camera's ability has
	content that uses it, and it becomes purchasable in the shop.
]]

local CameraConfig = {}

CameraConfig.DefaultCamera = "Starter"

CameraConfig.Cameras = {
	Starter = {
		Name = "Starter Camera",
		Order = 1,
		Price = 0,
		Cooldown = 1.2,
		RangeMultiplier = 1,
		Noise = 0.15,
		Abilities = {},
		Implemented = true,
		BodyColor = Color3.fromRGB(38, 38, 44),
		AccentColor = Color3.fromRGB(205, 205, 210),
		Icon = "📷",
		Description = "A trusty point-and-shoot. It sees what you see.",
	},
	FastCam = {
		Name = "Pro Camera",
		Order = 2,
		Price = 25000,
		Cooldown = 0.55,
		RangeMultiplier = 1.15,
		Noise = 0.22, -- fast mechanical shutter: louder
		Abilities = {},
		Implemented = true,
		GamePass = "ProCamera",
		BodyColor = Color3.fromRGB(200, 40, 50),
		AccentColor = Color3.fromRGB(255, 220, 90),
		Icon = "⚡",
		Description = "Much shorter photo cooldown and a sharper zoom. Never miss a fleeting anomaly.",
	},
	NightCam = {
		Name = "NightCam",
		Order = 3,
		Price = 75000,
		Cooldown = 1,
		RangeMultiplier = 1,
		Noise = 0.15,
		Abilities = { Night = true },
		Implemented = false,
		BodyColor = Color3.fromRGB(30, 80, 40),
		AccentColor = Color3.fromRGB(120, 255, 140),
		Icon = "🌙",
		Description = "Clearly captures anomalies that only exist in darkness.",
	},
	ThermalCam = {
		Name = "ThermalCam",
		Order = 4,
		Price = 150000,
		Cooldown = 1,
		RangeMultiplier = 1,
		Noise = 0.3, -- old mechanical camera
		Abilities = { Thermal = true },
		Implemented = false,
		BodyColor = Color3.fromRGB(120, 40, 20),
		AccentColor = Color3.fromRGB(255, 140, 40),
		Icon = "🔥",
		Description = "Reveals invisible, heat-based anomalies.",
	},
	GlitchCam = {
		Name = "GlitchCam",
		Order = 5,
		Price = 300000,
		Cooldown = 1,
		RangeMultiplier = 1,
		Noise = 0.15,
		Abilities = { Glitch = true },
		Implemented = false,
		BodyColor = Color3.fromRGB(40, 20, 80),
		AccentColor = Color3.fromRGB(0, 255, 230),
		Icon = "👾",
		Description = "Photographs digital and glitch anomalies.",
	},
}

-- Permanent upgrades bought with Evidence. They change how you play, not luck.
CameraConfig.Upgrades = {
	Range = {
		Name = "Zoom Lens",
		Order = 1,
		Icon = "🔭",
		Description = "+15% photo range per level.",
		MaxLevel = 3,
		Prices = { 4000, 12000, 35000 },
		PerLevel = 0.15,
	},
	Steady = {
		Name = "Steady Grip",
		Order = 2,
		Icon = "🎯",
		Description = "Anomalies count further from the centre of your frame (+3° per level).",
		MaxLevel = 3,
		Prices = { 4000, 12000, 35000 },
		PerLevel = 3,
	},
	Silent = {
		Name = "Silent Shutter",
		Order = 4,
		Icon = "🤫",
		Description = "Quieter shutter + flash so sound-hunting anomalies are less likely to hear you.",
		MaxLevel = 2,
		Prices = { 8000, 22000 },
		NoiseMultipliers = { 0.6, 0.33 }, -- 0.15 -> 0.09 -> 0.05
	},
	Sense = {
		Name = "Sixth Sense",
		Order = 3,
		Icon = "👂",
		Description = "Hear a whisper when an anomaly appears near you. Bigger radius per level.",
		MaxLevel = 3,
		Prices = { 6000, 18000, 45000 },
		Radii = { 45, 70, 100 },
	},
}

for id, def in pairs(CameraConfig.Cameras) do
	def.Id = id
end
for id, def in pairs(CameraConfig.Upgrades) do
	def.Id = id
end

function CameraConfig.Get(id: string)
	return CameraConfig.Cameras[id]
end

function CameraConfig.GetSorted()
	local list = {}
	for _, def in pairs(CameraConfig.Cameras) do
		table.insert(list, def)
	end
	table.sort(list, function(a, b)
		return a.Order < b.Order
	end)
	return list
end

function CameraConfig.GetUpgrade(id: string)
	return CameraConfig.Upgrades[id]
end

function CameraConfig.GetSortedUpgrades()
	local list = {}
	for _, def in pairs(CameraConfig.Upgrades) do
		table.insert(list, def)
	end
	table.sort(list, function(a, b)
		return a.Order < b.Order
	end)
	return list
end

-- Derived gameplay stats for a player's equipped camera + upgrade levels.
function CameraConfig.GetStats(cameraId: string, upgrades: { [string]: number }?)
	local camera = CameraConfig.Cameras[cameraId] or CameraConfig.Cameras[CameraConfig.DefaultCamera]
	local levels = upgrades or {}
	local rangeLevel = levels.Range or 0
	local steadyLevel = levels.Steady or 0
	local senseLevel = levels.Sense or 0
	local silentLevel = levels.Silent or 0
	local noiseMultiplier = if silentLevel > 0 then CameraConfig.Upgrades.Silent.NoiseMultipliers[silentLevel] else 1
	return {
		Camera = camera,
		Cooldown = camera.Cooldown,
		RangeMultiplier = camera.RangeMultiplier * (1 + CameraConfig.Upgrades.Range.PerLevel * rangeLevel),
		ExtraAngle = CameraConfig.Upgrades.Steady.PerLevel * steadyLevel,
		SenseRadius = senseLevel > 0 and CameraConfig.Upgrades.Sense.Radii[senseLevel] or 0,
		ShutterNoise = (camera.Noise or 0.15) * noiseMultiplier,
		FlashNoise = 0.1 * noiseMultiplier,
		Abilities = camera.Abilities,
	}
end

return CameraConfig
