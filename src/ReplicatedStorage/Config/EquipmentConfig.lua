--[[
	EquipmentConfig (ModuleScript)
	Location: ReplicatedStorage/Config/EquipmentConfig

	Physical equipment. Hand items are real Roblox Tools (so characters get
	the "holding an item" pose); Night Vision is worn and toggles on its own.
	Every action has sounds (SoundConfig) and every sound can create NOISE
	that sound-sensitive anomalies may hear.

	Fields
	  Name, Icon, Order          hotbar presentation (Order = hotbar slot + key number)
	  Price                      Evidence price (0 = starter item)
	  Wearable                   true = not held; the hotbar slot toggles it
	  Toggle                     true = the action button switches it on/off
	  Battery.Capacity           100 = full
	  Battery.DrainPerSecond     while switched on
	  Battery.PerUse             per action (camera photo)
	  Noise                      world noise per action (see GameConfig.Noise for the scale)
	  Sounds                     SoundConfig category used for Equip/Unequip/etc.
]]

local EquipmentConfig = {}

EquipmentConfig.EquipDelay = 0.3 -- seconds after equipping before the item can be used
EquipmentConfig.LowBattery = 20 -- percent: warning sound + HUD colour
EquipmentConfig.CriticalBattery = 8
EquipmentConfig.BatteryPickupAmount = 60 -- percent restored by a battery pickup
EquipmentConfig.InterferenceRadius = 32 -- dangerous anomalies closer than this disturb electronics

EquipmentConfig.Items = {
	Camera = {
		Name = "Camera",
		Icon = "📷",
		Order = 1,
		Price = 0,
		Toggle = false,
		ActionLabel = "PHOTO",
		Sounds = "Camera",
		Battery = { Capacity = 100, PerUse = 1.5, DrainPerSecond = 0 },
		Description = "Your evidence. Every shot makes a sound.",
	},
	Flashlight = {
		Name = "Flashlight",
		Icon = "🔦",
		Order = 2,
		Price = 0,
		Toggle = true,
		ActionLabel = "LIGHT",
		Sounds = "Flashlight",
		Battery = { Capacity = 100, DrainPerSecond = 0.4 },
		Noise = { Toggle = 0.05, Malfunction = 0.15, Broken = 0.3, RapidToggleCount = 3, RapidToggleWindow = 3 },
		Light = { Brightness = 2.6, Range = 55, Angle = 55, Color = Color3.fromRGB(255, 244, 220) },
		Description = "Lights the dark. Dangerous things can make it buzz... or die.",
	},
	EMF = {
		Name = "EMF Detector",
		Icon = "📟",
		Order = 3,
		Price = 0,
		Toggle = true,
		ActionLabel = "EMF",
		Sounds = "EMF",
		Battery = { Capacity = 100, DrainPerSecond = 0.15 },
		Range = 45,
		-- seconds between beeps for EMF level 1..5 (level 0 = silent)
		BeepInterval = { 1.7, 1.15, 0.75, 0.38, 0.12 },
		NoisePerLevel = 0.012,
		Description = "Beeps faster the closer paranormal energy is. Silence can be worse.",
	},
	Thermal = {
		Name = "Thermal Scanner",
		Icon = "🌡️",
		Order = 4,
		Price = 15000,
		Toggle = true,
		ActionLabel = "SCAN",
		Sounds = "Thermal",
		Battery = { Capacity = 100, DrainPerSecond = 0.3 },
		Range = 50,
		ConeDeg = 28,
		LockDeg = 10,
		Description = "Point it around. Anomalies leave impossible cold spots.",
	},
	UVLight = {
		Name = "UV Light",
		Icon = "🟣",
		Order = 5,
		Price = 12000,
		Toggle = true,
		ActionLabel = "UV",
		Sounds = "UV",
		Battery = { Capacity = 100, DrainPerSecond = 0.35 },
		Noise = { Toggle = 0.05, Malfunction = 0.15, Broken = 0.3, RapidToggleCount = 3, RapidToggleWindow = 3 },
		Light = { Brightness = 3, Range = 40, Angle = 45, Color = Color3.fromRGB(150, 70, 255) },
		RevealRange = 32,
		RevealConeDeg = 38,
		Description = "Reveals glowing residue trails that anomalies leave behind.",
	},
	NightVision = {
		Name = "Night Vision",
		Icon = "🥽",
		Order = 6,
		Price = 20000,
		Toggle = true,
		Wearable = true,
		ActionLabel = "NV",
		Sounds = "NightVision",
		Battery = { Capacity = 100, DrainPerSecond = 0.5 },
		Description = "See in total darkness. Strong anomalies scramble the signal.",
	},
}

EquipmentConfig.StarterItems = { "Camera", "Flashlight", "EMF" }

for id, item in pairs(EquipmentConfig.Items) do
	item.Id = id
end

function EquipmentConfig.Get(id: string)
	return EquipmentConfig.Items[id]
end

function EquipmentConfig.GetSorted()
	local list = {}
	for _, item in pairs(EquipmentConfig.Items) do
		table.insert(list, item)
	end
	table.sort(list, function(a, b)
		return a.Order < b.Order
	end)
	return list
end

function EquipmentConfig.IsHandItem(id: string): boolean
	local item = EquipmentConfig.Items[id]
	return item ~= nil and not item.Wearable
end

return EquipmentConfig
