--[[
	MonetizationConfig (ModuleScript)
	Location: ReplicatedStorage/Config/MonetizationConfig

	Every Game Pass and Developer Product id lives here and ONLY here.
	Create the passes/products on the Creator Dashboard, then paste their ids
	into the `Id` fields. An Id of 0 means "not configured": the shop shows
	the item as unavailable and nothing is ever prompted or granted for it.
	Everything is sold in the physical SUPPLY STORE terminal (lobby) and in
	the SHOP menu - the same data drives both.

	Design rules:
	  * The game is fully playable without purchases.
	  * No loot boxes, no selling anomalies, no paid rare-spawn luck.
	  * Server events bought with Robux benefit EVERY player in the server.
]]

local MonetizationConfig = {}

MonetizationConfig.GamePasses = {
	ProCamera = {
		Id = 0, -- PLACEHOLDER
		Name = "PRO CAMERA",
		Icon = "📷",
		Order = 1,
		Description = "The Pro camera forever: much shorter photo cooldown, sharper zoom and the Pro Black skin.",
	},
	TacticalFlashlight = {
		Id = 0, -- PLACEHOLDER
		Name = "TACTICAL FLASHLIGHT",
		Icon = "🔦",
		Order = 2,
		Description = "Brighter, longer beam, half the battery drain and it resists anomaly interference. Tactical skin included.",
	},
	InvestigatorPack = {
		Id = 0, -- PLACEHOLDER
		Name = "INVESTIGATOR PACK",
		Icon = "🎒",
		Order = 3,
		Description = "Unlocks the Thermal Scanner, UV Light and Night Vision forever.",
	},
	VIPInvestigator = {
		Id = 0, -- PLACEHOLDER
		Name = "VIP INVESTIGATOR",
		Icon = "⭐",
		Order = 4,
		Description = "VIP tag, gold camera / flashlight / EMF skins, the VIP Gallery dark room and a bigger photo roll.",
	},
	ExtraAlbumStorage = {
		Id = 0, -- PLACEHOLDER
		Name = "EXTRA PHOTO ROLL",
		Icon = "🗂️",
		Order = 5,
		Description = "Your Photo Roll keeps 60 photos instead of 12.",
	},
	BiggerDarkRoom = {
		Id = 0, -- PLACEHOLDER
		Name = "BIGGER DARK ROOM",
		Icon = "🖼️",
		Order = 6,
		Description = "Show off your 10 rarest discoveries instead of 5.",
	},
}

-- Equipment that a pass unlocks without buying it with Evidence.
MonetizationConfig.PassEquipment = {
	InvestigatorPack = { "Thermal", "UVLight", "NightVision" },
}

--[[
	Kind = "ServerEvent" -> starts EventService event `Event` for the whole server
	Kind = "Evidence"    -> adds `Amount` Evidence to the buyer
	Kind = "Revive"      -> revives you instantly when downed (otherwise stored as a token)
	Kind = "Cosmetic"    -> unlocks CosmeticsConfig skin / decor `Cosmetic` forever
]]
MonetizationConfig.Products = {
	Revive = {
		Id = 0, -- PLACEHOLDER
		Name = "REVIVE",
		Icon = "🩹",
		Order = 1,
		Kind = "Revive",
		Description = "Get back up instantly when an anomaly knocks you down. Kept for later if you are fine.",
	},
	ParanormalSurge = {
		Id = 0, -- PLACEHOLDER
		Name = "PARANORMAL SURGE",
		Icon = "👁️",
		Order = 2,
		Kind = "ServerEvent",
		Event = "Surge",
		Description = "Anomaly activity rises for EVERYONE in the investigation.",
	},
	BlackoutEvent = {
		Id = 0, -- PLACEHOLDER
		Name = "BLACKOUT",
		Icon = "🌑",
		Order = 3,
		Kind = "ServerEvent",
		Event = "Blackout",
		Description = "Kill the lights for the whole server. Darkness anomalies awaken.",
	},
	SmallEvidencePack = {
		Id = 0, -- PLACEHOLDER
		Name = "EVIDENCE CASE",
		Icon = "📁",
		Order = 4,
		Kind = "Evidence",
		Amount = 5000,
		Description = "+$5,000 Evidence.",
	},
	MediumEvidencePack = {
		Id = 0, -- PLACEHOLDER
		Name = "EVIDENCE CRATE",
		Icon = "🗄️",
		Order = 5,
		Kind = "Evidence",
		Amount = 20000,
		Description = "+$20,000 Evidence.",
	},
	-- equipment skins
	SkinCameraBone = { Id = 0, Name = "CAMERA · BONE WHITE", Icon = "📷", Order = 10, Kind = "Cosmetic", Cosmetic = "CameraBone", Description = "Camera skin." },
	SkinCameraCCTV = { Id = 0, Name = "CAMERA · NIGHT SHIFT", Icon = "📷", Order = 11, Kind = "Cosmetic", Cosmetic = "CameraCCTV", Description = "Camera skin." },
	SkinFlashlightCrimson = { Id = 0, Name = "FLASHLIGHT · CRIMSON", Icon = "🔦", Order = 12, Kind = "Cosmetic", Cosmetic = "FlashlightCrimson", Description = "Flashlight skin." },
	SkinFlashlightRust = { Id = 0, Name = "FLASHLIGHT · RUSTED", Icon = "🔦", Order = 13, Kind = "Cosmetic", Cosmetic = "FlashlightRust", Description = "Flashlight skin." },
	SkinEMFToxic = { Id = 0, Name = "EMF · TOXIC", Icon = "📟", Order = 14, Kind = "Cosmetic", Cosmetic = "EMFToxic", Description = "EMF detector skin." },
	SkinEMFGhost = { Id = 0, Name = "EMF · GHOST WHITE", Icon = "📟", Order = 15, Kind = "Cosmetic", Cosmetic = "EMFGhost", Description = "EMF detector skin." },
	-- dark room decorations
	DecorCrimeScene = { Id = 0, Name = "DARK ROOM · CRIME SCENE", Icon = "🚧", Order = 20, Kind = "Cosmetic", Cosmetic = "CrimeScene", Description = "Dark room decoration." },
	DecorOccult = { Id = 0, Name = "DARK ROOM · OCCULT STUDY", Icon = "🕯️", Order = 21, Kind = "Cosmetic", Cosmetic = "Occult", Description = "Dark room decoration." },
	DecorSurveillance = { Id = 0, Name = "DARK ROOM · SURVEILLANCE", Icon = "📺", Order = 22, Kind = "Cosmetic", Cosmetic = "Surveillance", Description = "Dark room decoration." },
}

for key, pass in pairs(MonetizationConfig.GamePasses) do
	pass.Key = key
end
for key, product in pairs(MonetizationConfig.Products) do
	product.Key = key
end

function MonetizationConfig.IsConfigured(entry): boolean
	return entry ~= nil and type(entry.Id) == "number" and entry.Id > 0
end

function MonetizationConfig.GetPassByPassId(passId: number)
	for _, pass in pairs(MonetizationConfig.GamePasses) do
		if pass.Id == passId and pass.Id > 0 then
			return pass
		end
	end
	return nil
end

function MonetizationConfig.GetProductByProductId(productId: number)
	for _, product in pairs(MonetizationConfig.Products) do
		if product.Id == productId and product.Id > 0 then
			return product
		end
	end
	return nil
end

function MonetizationConfig.GetProductForCosmetic(cosmeticId: string)
	for _, product in pairs(MonetizationConfig.Products) do
		if product.Kind == "Cosmetic" and product.Cosmetic == cosmeticId then
			return product
		end
	end
	return nil
end

local function sortedValues(map, filter: ((any) -> boolean)?)
	local list = {}
	for _, value in pairs(map) do
		if not filter or filter(value) then
			table.insert(list, value)
		end
	end
	table.sort(list, function(a, b)
		return a.Order < b.Order
	end)
	return list
end

function MonetizationConfig.GetSortedPasses()
	return sortedValues(MonetizationConfig.GamePasses)
end

function MonetizationConfig.GetSortedProducts(kind: string?)
	return sortedValues(MonetizationConfig.Products, function(product)
		if kind == nil then
			return product.Kind ~= "Cosmetic"
		end
		return product.Kind == kind
	end)
end

return MonetizationConfig
