--[[
	RarityConfig (ModuleScript)
	Location: ReplicatedStorage/Config/RarityConfig

	Central definition of every rarity tier. Nothing else in the game hardcodes
	rarity colours, rewards, luck or announcement rules - they all read from here.
]]

local RarityConfig = {}

-- Lowest -> highest. The index in this list is the tier's Rank.
RarityConfig.Order = {
	"Common",
	"Unusual",
	"Rare",
	"Epic",
	"Mythic",
	"Nightmare",
	"Impossible",
	"Unknown",
}

--[[
	DisplayName      - text shown to players
	Color            - UI / highlight colour
	BaseReward       - Evidence for a 3-star first photo (before bonuses)
	SurgeLuck        - spawn weight multiplier while a Paranormal Surge is active
	AnnounceToServer - post a server-wide toast when someone photographs it
	DramaticReveal   - play the full-screen reveal animation for everyone
	HideOdds         - show "1 / ???" instead of the real odds
]]
RarityConfig.Tiers = {
	Common = {
		DisplayName = "Common",
		Color = Color3.fromRGB(196, 196, 206),
		BaseReward = 150,
		SurgeLuck = 1,
		AnnounceToServer = false,
		DramaticReveal = false,
		HideOdds = false,
	},
	Unusual = {
		DisplayName = "Unusual",
		Color = Color3.fromRGB(110, 225, 130),
		BaseReward = 400,
		SurgeLuck = 1.15,
		AnnounceToServer = false,
		DramaticReveal = false,
		HideOdds = false,
	},
	Rare = {
		DisplayName = "Rare",
		Color = Color3.fromRGB(80, 165, 255),
		BaseReward = 1600,
		SurgeLuck = 2,
		AnnounceToServer = false,
		DramaticReveal = false,
		HideOdds = false,
	},
	Epic = {
		DisplayName = "Epic",
		Color = Color3.fromRGB(185, 95, 255),
		BaseReward = 5000,
		SurgeLuck = 2.5,
		AnnounceToServer = true,
		DramaticReveal = false,
		HideOdds = false,
	},
	Mythic = {
		DisplayName = "Mythic",
		Color = Color3.fromRGB(255, 95, 175),
		BaseReward = 15000,
		SurgeLuck = 3,
		AnnounceToServer = true,
		DramaticReveal = false,
		HideOdds = false,
	},
	Nightmare = {
		DisplayName = "Nightmare",
		Color = Color3.fromRGB(235, 45, 45),
		BaseReward = 50000,
		SurgeLuck = 3,
		AnnounceToServer = true,
		DramaticReveal = true,
		HideOdds = false,
	},
	Impossible = {
		DisplayName = "Impossible",
		Color = Color3.fromRGB(255, 215, 60),
		BaseReward = 500000,
		SurgeLuck = 3,
		AnnounceToServer = true,
		DramaticReveal = true,
		HideOdds = false,
	},
	Unknown = {
		DisplayName = "???",
		Color = Color3.fromRGB(235, 235, 245),
		BaseReward = 1000000,
		SurgeLuck = 3,
		AnnounceToServer = true,
		DramaticReveal = true,
		HideOdds = true,
	},
}

local rankById = {}
for index, id in ipairs(RarityConfig.Order) do
	rankById[id] = index
	RarityConfig.Tiers[id].Id = id
	RarityConfig.Tiers[id].Rank = index
end

function RarityConfig.Get(id: string)
	return RarityConfig.Tiers[id] or RarityConfig.Tiers.Common
end

function RarityConfig.GetRank(id: string): number
	return rankById[id] or 1
end

function RarityConfig.GetColor(id: string): Color3
	return RarityConfig.Get(id).Color
end

function RarityConfig.GetDisplayName(id: string): string
	return RarityConfig.Get(id).DisplayName
end

return RarityConfig
