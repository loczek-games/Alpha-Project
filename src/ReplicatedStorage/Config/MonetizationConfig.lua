--[[
	MonetizationConfig (ModuleScript)
	Location: ReplicatedStorage/Config/MonetizationConfig

	Every Game Pass and Developer Product id lives here and ONLY here.
	Create the passes/products on the Creator Dashboard, then paste their ids
	into the `Id` fields. An Id of 0 means "not configured": the store shows
	the item as unavailable and nothing is ever prompted or granted for it.

	Design rules:
	  * No loot boxes, no selling anomalies, no paid rare-spawn luck.
	  * Server events bought with Robux benefit EVERY player in the server.
]]

local MonetizationConfig = {}

MonetizationConfig.GamePasses = {
	FastCamera = {
		Id = 0,
		Name = "Fast Camera",
		Icon = "⚡",
		Order = 1,
		Description = "Unlock FastCam forever: much shorter photo cooldown.",
	},
	ExtraAlbumStorage = {
		Id = 0,
		Name = "Extra Album Storage",
		Icon = "🗂️",
		Order = 2,
		Description = "Your Photo Roll keeps 60 photos instead of 12.",
	},
	BiggerDarkRoom = {
		Id = 0,
		Name = "Bigger Dark Room",
		Icon = "🖼️",
		Order = 3,
		Description = "Show off your 10 rarest discoveries instead of 5.",
	},
	VIPPhotographer = {
		Id = 0,
		Name = "VIP Photographer",
		Icon = "⭐",
		Order = 4,
		Description = "VIP chat + name tag, gold camera skin and exclusive Dark Room decor.",
	},
}

--[[
	Kind = "ServerEvent" -> starts EventService event `Event` for the whole server
	Kind = "Evidence"    -> adds `Amount` Evidence to the buyer
]]
MonetizationConfig.Products = {
	ParanormalSurge = {
		Id = 0,
		Name = "Paranormal Surge",
		Icon = "👁️",
		Order = 1,
		Kind = "ServerEvent",
		Event = "Surge",
		Description = "Anomaly activity rises for EVERYONE in the server.",
	},
	BlackoutEvent = {
		Id = 0,
		Name = "Blackout",
		Icon = "🔦",
		Order = 2,
		Kind = "ServerEvent",
		Event = "Blackout",
		Description = "Kill the lights for the whole server. Darkness anomalies awaken.",
	},
	SmallEvidencePack = {
		Id = 0,
		Name = "Small Evidence Pack",
		Icon = "📁",
		Order = 3,
		Kind = "Evidence",
		Amount = 5000,
		Description = "+$5,000 Evidence.",
	},
	MediumEvidencePack = {
		Id = 0,
		Name = "Medium Evidence Pack",
		Icon = "🗄️",
		Order = 4,
		Kind = "Evidence",
		Amount = 20000,
		Description = "+$20,000 Evidence.",
	},
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

local function sortedValues(map)
	local list = {}
	for _, value in pairs(map) do
		table.insert(list, value)
	end
	table.sort(list, function(a, b)
		return a.Order < b.Order
	end)
	return list
end

function MonetizationConfig.GetSortedPasses()
	return sortedValues(MonetizationConfig.GamePasses)
end

function MonetizationConfig.GetSortedProducts()
	return sortedValues(MonetizationConfig.Products)
end

return MonetizationConfig
