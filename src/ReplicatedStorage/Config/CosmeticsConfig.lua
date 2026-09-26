--[[
	CosmeticsConfig (ModuleScript)
	Location: ReplicatedStorage/Config/CosmeticsConfig

	Purely visual items: equipment skins (camera / flashlight / EMF) and
	Dark Room decorations. They never change gameplay.

	Skins are unlocked by a Developer Product (MonetizationConfig.Products,
	Kind = "Cosmetic"), by a Game Pass (Pass = key) or are free (Free = true).
	Owned cosmetics are saved in Data.Cosmetics; equipping is done in the
	shop (EconomyService "EquipSkin" / "EquipDecor").

	Skin fields: Item ("Camera" | "Flashlight" | "EMF"), Name, Body, Accent,
	             Trim, Material, Lens (optional light colour)
	Decor fields: Name, Safelight (colour), Props (list of prop ids the
	              DarkRoomController adds), Description
]]

local CosmeticsConfig = {}

CosmeticsConfig.Skins = {
	-- defaults (free)
	CameraField = { Item = "Camera", Name = "Field Issue", Free = true, Body = Color3.fromRGB(34, 34, 36), Accent = Color3.fromRGB(70, 70, 74), Trim = Color3.fromRGB(150, 150, 156), Material = Enum.Material.SmoothPlastic },
	FlashlightField = { Item = "Flashlight", Name = "Field Issue", Free = true, Body = Color3.fromRGB(38, 38, 42), Accent = Color3.fromRGB(90, 90, 96), Trim = Color3.fromRGB(160, 160, 166), Material = Enum.Material.Metal },
	EMFField = { Item = "EMF", Name = "Field Issue", Free = true, Body = Color3.fromRGB(214, 180, 40), Accent = Color3.fromRGB(28, 28, 30), Trim = Color3.fromRGB(60, 60, 64), Material = Enum.Material.SmoothPlastic },

	-- game-pass skins
	CameraPro = { Item = "Camera", Name = "Pro Black", Pass = "ProCamera", Body = Color3.fromRGB(16, 16, 18), Accent = Color3.fromRGB(30, 30, 32), Trim = Color3.fromRGB(200, 40, 40), Material = Enum.Material.SmoothPlastic },
	FlashlightTactical = { Item = "Flashlight", Name = "Tactical", Pass = "TacticalFlashlight", Body = Color3.fromRGB(46, 50, 38), Accent = Color3.fromRGB(24, 26, 20), Trim = Color3.fromRGB(120, 130, 90), Material = Enum.Material.Metal },
	CameraGold = { Item = "Camera", Name = "VIP Gold", Pass = "VIPInvestigator", Body = Color3.fromRGB(212, 168, 60), Accent = Color3.fromRGB(26, 24, 20), Trim = Color3.fromRGB(255, 226, 140), Material = Enum.Material.Metal },
	FlashlightGold = { Item = "Flashlight", Name = "VIP Gold", Pass = "VIPInvestigator", Body = Color3.fromRGB(212, 168, 60), Accent = Color3.fromRGB(30, 26, 20), Trim = Color3.fromRGB(255, 226, 140), Material = Enum.Material.Metal },
	EMFGold = { Item = "EMF", Name = "VIP Gold", Pass = "VIPInvestigator", Body = Color3.fromRGB(212, 168, 60), Accent = Color3.fromRGB(26, 24, 20), Trim = Color3.fromRGB(255, 226, 140), Material = Enum.Material.Metal },

	-- product skins
	CameraBone = { Item = "Camera", Name = "Bone White", Body = Color3.fromRGB(214, 206, 188), Accent = Color3.fromRGB(60, 54, 48), Trim = Color3.fromRGB(150, 30, 30), Material = Enum.Material.SmoothPlastic },
	CameraCCTV = { Item = "Camera", Name = "Night Shift", Body = Color3.fromRGB(26, 40, 32), Accent = Color3.fromRGB(14, 20, 16), Trim = Color3.fromRGB(120, 255, 160), Material = Enum.Material.SmoothPlastic },
	FlashlightCrimson = { Item = "Flashlight", Name = "Crimson", Body = Color3.fromRGB(110, 16, 20), Accent = Color3.fromRGB(30, 10, 10), Trim = Color3.fromRGB(220, 60, 60), Material = Enum.Material.Metal, Lens = Color3.fromRGB(255, 225, 215) },
	FlashlightRust = { Item = "Flashlight", Name = "Rusted", Body = Color3.fromRGB(110, 70, 44), Accent = Color3.fromRGB(56, 40, 30), Trim = Color3.fromRGB(150, 110, 80), Material = Enum.Material.CorrodedMetal },
	EMFToxic = { Item = "EMF", Name = "Toxic", Body = Color3.fromRGB(80, 160, 40), Accent = Color3.fromRGB(20, 26, 16), Trim = Color3.fromRGB(190, 255, 90), Material = Enum.Material.SmoothPlastic },
	EMFGhost = { Item = "EMF", Name = "Ghost White", Body = Color3.fromRGB(220, 224, 228), Accent = Color3.fromRGB(40, 44, 50), Trim = Color3.fromRGB(120, 200, 255), Material = Enum.Material.SmoothPlastic },
}

CosmeticsConfig.DefaultSkins = { Camera = "CameraField", Flashlight = "FlashlightField", EMF = "EMFField" }

CosmeticsConfig.Decor = {
	Classic = { Name = "Classic Darkroom", Free = true, Safelight = Color3.fromRGB(255, 40, 30), Props = {}, Description = "Red safelight, drying lines." },
	CrimeScene = { Name = "Crime Scene", Safelight = Color3.fromRGB(255, 60, 40), Props = { "Tape", "Markers" }, Description = "Police tape and evidence markers." },
	Occult = { Name = "Occult Study", Safelight = Color3.fromRGB(150, 60, 255), Props = { "Candles", "Circle" }, Description = "Purple light, candles and a chalk circle." },
	Surveillance = { Name = "Surveillance Den", Safelight = Color3.fromRGB(80, 255, 140), Props = { "Monitors" }, Description = "Green CCTV glow and a wall of monitors." },
	VIPGold = { Name = "VIP Gallery", Pass = "VIPInvestigator", Safelight = Color3.fromRGB(255, 200, 90), Props = { "GoldFrames" }, Description = "Gold frames for your rarest evidence." },
}

for id, skin in pairs(CosmeticsConfig.Skins) do
	skin.Id = id
end
for id, decor in pairs(CosmeticsConfig.Decor) do
	decor.Id = id
end

function CosmeticsConfig.GetSkin(id: string?)
	return if id then CosmeticsConfig.Skins[id] else nil
end

function CosmeticsConfig.SkinsFor(item: string)
	local list = {}
	for _, skin in pairs(CosmeticsConfig.Skins) do
		if skin.Item == item then
			table.insert(list, skin)
		end
	end
	table.sort(list, function(a, b)
		if (a.Free == true) ~= (b.Free == true) then
			return a.Free == true
		end
		return a.Name < b.Name
	end)
	return list
end

return CosmeticsConfig
