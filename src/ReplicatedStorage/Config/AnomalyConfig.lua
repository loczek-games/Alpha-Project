--[[
	AnomalyConfig (ModuleScript)
	Location: ReplicatedStorage/Config/AnomalyConfig

	Every anomaly in the game is defined here. To add a new anomaly:
	  1. Add an entry to AnomalyConfig.List below.
	  2. Create a ModuleScript with the same name as its `Behavior` inside
	     ServerScriptService/Anomalies/Behaviors (copy an existing one).
	No other script needs to change.

	Fields
	  Id               unique string id (also the save key - never rename after launch)
	  Name             display name
	  Rarity           tier id from RarityConfig
	  Weight           relative spawn weight (odds shown to players are derived from this)
	  Behavior         name of the behaviour ModuleScript
	  Lifetime         seconds the anomaly stays before disappearing
	  PhotoDistance    max distance (studs) from the photographer's head
	  Reward           optional Evidence override (default = rarity BaseReward)
	  Spawn            where it may appear:
	                     Kinds   = { "Floor" | "Ceiling" | "DoorSlot" | "Dark" | "RunLane" | "Skylight" }
	                     Zones   = { zone ids } (nil = any zone)
	                     Fixture = CollectionService tag of an existing map object it haunts
	                     NPC     = true when it possesses an ambient shopper
	                     Player  = true when it targets a player
	                     MinPlayers / MinNPCs = requirements for spawning
	  MaxActive        how many copies may exist at once (default 1)
	  RequiresEvent    only spawns while this server event is active (e.g. "Blackout")
	  EventWeightMultiplier  weight multiplier while RequiresEvent is active
	  RequiredAbility  camera ability needed to photograph it (see CameraConfig)
	  Announce         "Default" (use rarity rule) | "Server" | "Reveal" | "None"
	  TargetRadius     approximate size in studs; bigger = easier to frame
	  Params           free-form table passed to the behaviour ("Special Behavior" tuning)
	  Icon / Description  album + dark room presentation
	  Badge            optional key in GameConfig.Badges awarded on capture
	  Danger           0-1 how dangerous it feels: disturbs cameras, flashlights,
	                   night vision, and silences the music when close
	  EMF              1-5 peak EMF reading right next to it
	  Cold             true = shows as a cold spot on the Thermal Scanner
	  Residue          true = leaves a UV-only residue trail near it
	  Hearing          sound-sensitive anomalies only:
	                     Radius, Threshold, Kinds = { NoiseKind = multiplier }
	                   (NoiseKinds: Sneak, Footstep, Run, Land, Shutter, Flash, Focus,
	                    FlashlightClick, FlashlightMalfunction, DoorOpen, DoorClose,
	                    DoorSlam, Interaction, Voice, Radio, Phone, EMF)
]]

local RarityConfig = require(script.Parent:WaitForChild("RarityConfig"))

local AnomalyConfig = {}

AnomalyConfig.Defaults = {
	Lifetime = 20,
	PhotoDistance = 70,
	MaxActive = 1,
	Enabled = true,
	Announce = "Default",
	TargetRadius = 2,
	EventWeightMultiplier = 1,
	Danger = 0.3,
	EMF = 2,
	Cold = false,
	Residue = true,
}

AnomalyConfig.List = {
	----------------------------------------------------------------- COMMON
	{
		Id = "ReverseClock",
		Name = "Reverse Clock",
		Rarity = "Common",
		Weight = 300,
		Behavior = "ReverseClock",
		Lifetime = 25,
		PhotoDistance = 60,
		Spawn = { Fixture = "MallClock" },
		TargetRadius = 2.5,
		Params = { MinuteSpeed = 200, HourSpeed = 18 },
		Icon = "🕰️",
		Danger = 0.1, EMF = 2,
		Description = "Every clock in the mall stopped at 3:00. This one is running backwards.",
	},
	{
		Id = "FloatingCart",
		Name = "Floating Shopping Cart",
		Rarity = "Common",
		Weight = 280,
		Behavior = "FloatingCart",
		Lifetime = 22,
		PhotoDistance = 70,
		Spawn = { Kinds = { "Floor" }, Zones = { "MainHall", "FoodCourt", "ParkingGarage", "ToyStore" } },
		TargetRadius = 2.5,
		Params = { Height = 5, BobAmplitude = 0.8, SpinSpeed = 0.35 },
		Icon = "🛒",
		Danger = 0.2, EMF = 3,
		Description = "An abandoned cart that forgot about gravity.",
	},
	{
		Id = "FakeExit",
		Name = "Fake Exit",
		Rarity = "Common",
		Weight = 260,
		Behavior = "FakeExit",
		Lifetime = 25,
		PhotoDistance = 70,
		Spawn = { Fixture = "ExitSign" },
		TargetRadius = 1.8,
		Params = { FlickerMin = 0.25, FlickerMax = 1.1 },
		Icon = "🔀",
		Danger = 0.1, EMF = 1,
		Description = "The EXIT sign insists you walk into the wall.",
	},
	----------------------------------------------------------------- UNUSUAL
	{
		Id = "MovingDoor",
		Name = "Moving Door",
		Rarity = "Unusual",
		Weight = 110,
		Behavior = "MovingDoor",
		Lifetime = 22,
		PhotoDistance = 70,
		Spawn = { Kinds = { "DoorSlot" } },
		TargetRadius = 3,
		Params = { OpenAngle = 70, OpenTime = 3 },
		Icon = "🚪",
		Danger = 0.4, EMF = 3, Cold = true,
		Description = "There was never a door here. It is slowly opening.",
	},
	{
		Id = "BlinkingLights",
		Name = "Blinking Lights",
		Rarity = "Unusual",
		Weight = 100,
		Behavior = "BlinkingLights",
		Lifetime = 24,
		PhotoDistance = 80,
		Spawn = {
			Kinds = { "Floor" },
			Zones = { "FoodCourt", "Arcade", "ToyStore", "Bathrooms", "StorageHallway", "ParkingGarage", "Cinema" },
		},
		TargetRadius = 2.5,
		Params = { HiddenTransparency = 0.8 },
		Icon = "💡",
		Danger = 0.5, EMF = 4,
		Description = "Three short, three long, three short. Something stands where the dark was.",
	},
	{
		Id = "WalkingPainting",
		Name = "Walking Painting",
		Rarity = "Unusual",
		Weight = 105,
		Behavior = "WalkingPainting",
		Lifetime = 26,
		PhotoDistance = 60,
		Spawn = { Fixture = "MallPainting" },
		TargetRadius = 3,
		Icon = "🖼️",
		Danger = 0.3, EMF = 2, Cold = true,
		Description = "The person in the painting moves whenever nobody is looking.",
	},
	----------------------------------------------------------------- RARE
	{
		Id = "WatchingMannequin",
		Name = "Watching Mannequin",
		Rarity = "Rare",
		Weight = 36,
		Behavior = "WatchingMannequin",
		Lifetime = 24,
		PhotoDistance = 70,
		Spawn = { Kinds = { "Floor" }, Zones = { "ToyStore", "MainHall", "FoodCourt", "Arcade", "Cinema" } },
		TargetRadius = 2.5,
		Params = { TurnInterval = 0.8, WatchRange = 70 },
		Icon = "🧍",
		Danger = 0.4, EMF = 3, Cold = true,
		Description = "A mannequin where there was none. It turns to follow you.",
	},
	{
		Id = "FacelessShopper",
		Name = "Faceless Shopper",
		Rarity = "Rare",
		Weight = 34,
		Behavior = "FacelessShopper",
		Lifetime = 26,
		PhotoDistance = 60,
		Spawn = { NPC = true, MinNPCs = 1 },
		TargetRadius = 1.8,
		Icon = "😶",
		Danger = 0.3, EMF = 2,
		Description = "A shopper strolling through the mall. Look closer at the face.",
	},
	{
		Id = "FrozenCrowd",
		Name = "Frozen Crowd",
		Rarity = "Rare",
		Weight = 30,
		Behavior = "FrozenCrowd",
		Lifetime = 18,
		PhotoDistance = 90,
		Spawn = { NPC = true, MinNPCs = 3 },
		TargetRadius = 2.5,
		Icon = "🧊",
		Danger = 0.3, EMF = 3,
		Description = "Every shopper froze mid-step. Except one.",
	},
	----------------------------------------------------------------- EPIC
	{
		Id = "WrongReflection",
		Name = "Wrong Reflection",
		Rarity = "Epic",
		Weight = 12,
		Behavior = "WrongReflection",
		Lifetime = 22,
		PhotoDistance = 45,
		Spawn = { Fixture = "MallMirror", MinPlayers = 1 },
		TargetRadius = 2.2,
		Params = { WaveInterval = 4.5 },
		Icon = "👥",
		Danger = 0.6, EMF = 4, Cold = true,
		Description = "Your reflection is not copying you anymore. It is watching you.",
	},
	{
		Id = "CeilingWatcher",
		Name = "Ceiling Watcher",
		Rarity = "Epic",
		Weight = 12,
		Behavior = "CeilingWatcher",
		Lifetime = 14,
		PhotoDistance = 70,
		Spawn = { Kinds = { "Ceiling" } },
		TargetRadius = 3,
		Icon = "🕷️",
		Danger = 0.8, EMF = 4, Cold = true,
		Description = "Something long-limbed clings to the ceiling. Look up.",
	},
	{
		Id = "FakePlayer",
		Name = "Fake Player",
		Rarity = "Epic",
		Weight = 10,
		Behavior = "FakePlayer",
		Lifetime = 30,
		PhotoDistance = 70,
		Spawn = { Kinds = { "Floor" }, Zones = { "MainHall" }, MinPlayers = 1 },
		TargetRadius = 2.2,
		Params = { WalkSpeed = 9, HeadTwistInterval = 6 },
		Icon = "👤",
		Danger = 0.6, EMF = 3, Cold = true,
		Description = "It looks exactly like someone in this server. Almost exactly.",
	},
	----------------------------------------------------------------- MYTHIC
	{
		Id = "SmilingPlayer",
		Name = "Smiling Player",
		Rarity = "Mythic",
		Weight = 3,
		Behavior = "SmilingPlayer",
		Lifetime = 30,
		PhotoDistance = 60,
		Spawn = { Player = true, MinPlayers = 2 },
		TargetRadius = 1.8,
		Icon = "😁",
		Danger = 0.5, EMF = 2, Residue = false,
		Description = "One player is smiling far too wide. They have no idea.",
	},
	{
		Id = "OneBehindYou",
		Name = "The One Behind You",
		Rarity = "Mythic",
		Weight = 3,
		Behavior = "OneBehindYou",
		Lifetime = 20,
		PhotoDistance = 60,
		Spawn = { Player = true, MinPlayers = 2 },
		TargetRadius = 2.5,
		Params = { Distance = 4.5 },
		Icon = "👻",
		Danger = 0.9, EMF = 5, Cold = true, Residue = false,
		Description = "It follows one player closely. Whatever you do, do not turn around.",
	},
	----------------------------------------------------------------- NIGHTMARE
	{
		Id = "ThePhotographer",
		Name = "The Photographer",
		Rarity = "Nightmare",
		Weight = 0.5,
		Behavior = "ThePhotographer",
		Lifetime = 25,
		PhotoDistance = 70,
		Spawn = { Kinds = { "Floor" }, Zones = { "Cinema", "StorageHallway", "ParkingGarage", "Arcade" } },
		TargetRadius = 2.5,
		Icon = "📷",
		Badge = "PhotographedBack",
		Danger = 0.7, EMF = 4, Cold = true,
		Hearing = { Radius = 45, Threshold = 0.05, Kinds = { Focus = 1.6, Shutter = 2, Flash = 2 } },
		Description = "It collects evidence too. Of you.",
	},
	----------------------------------------------------------------- IMPOSSIBLE
	{
		Id = "TheObserver",
		Name = "The Observer",
		Rarity = "Impossible",
		Weight = 0.0148, -- keeps the displayed odds at 1 / 100,000
		Behavior = "TheObserver",
		Lifetime = 20,
		PhotoDistance = 220,
		Spawn = { Kinds = { "Skylight" } },
		TargetRadius = 13,
		Icon = "👁️",
		Badge = "ImpossibleFound",
		Danger = 1, EMF = 5, Cold = true, Residue = false,
		Description = "Look up through the skylight. It has always been looking down.",
	},
	----------------------------------------------------------------- ???
	{
		Id = "TheNightManager",
		Name = "The Night Manager",
		Rarity = "Unknown",
		Weight = 0.0013,
		Behavior = "TheNightManager",
		Lifetime = 26,
		PhotoDistance = 80,
		Spawn = { Kinds = { "Floor" }, Zones = { "MainHall", "FoodCourt" } },
		TargetRadius = 3,
		Params = { BlinkInterval = 6 },
		Icon = "🕴️",
		Badge = "ImpossibleFound",
		Danger = 1, EMF = 5, Cold = true,
		Description = "Attention shoppers. The mall is now closed.",
	},
	----------------------------------------------------------------- BLACKOUT ONLY
	{
		Id = "GlowingEyes",
		Name = "Glowing Eyes",
		Rarity = "Common",
		Weight = 220,
		Behavior = "GlowingEyes",
		Lifetime = 16,
		PhotoDistance = 60,
		MaxActive = 2,
		RequiresEvent = "Blackout",
		EventWeightMultiplier = 1.5,
		Spawn = { Kinds = { "Dark" } },
		TargetRadius = 1.5,
		Icon = "👀",
		Danger = 0.4, EMF = 2,
		Description = "Only appears in a blackout. Two lights that blink back.",
	},
	{
		Id = "ShadowRunner",
		Name = "Shadow Runner",
		Rarity = "Unusual",
		Weight = 90,
		Behavior = "ShadowRunner",
		Lifetime = 14,
		PhotoDistance = 80,
		RequiresEvent = "Blackout",
		EventWeightMultiplier = 1.5,
		Spawn = { Kinds = { "RunLane" } },
		TargetRadius = 4,
		Params = { RunTime = 1.6, Pause = 1.4 },
		Icon = "🏃",
		Danger = 0.6, EMF = 3, Cold = true, Residue = false,
		Description = "Only appears in a blackout. Too fast to be a shopper.",
	},
	----------------------------------------------------------------- SOUND-REACTIVE
	{
		Id = "TheListener",
		Name = "The Listener",
		Rarity = "Rare",
		Weight = 30,
		Behavior = "TheListener",
		Lifetime = 45,
		PhotoDistance = 70,
		Spawn = { Kinds = { "Floor" }, Zones = { "MainHall", "FoodCourt", "ParkingGarage", "StorageHallway", "Cinema" } },
		TargetRadius = 2.5,
		Danger = 0.8,
		EMF = 4,
		Cold = true,
		Hearing = {
			Radius = 80,
			Threshold = 0.06,
			Kinds = {
				Run = 1.4, Land = 1.3, DoorSlam = 1.5, DoorOpen = 1, DoorClose = 0.6, Shutter = 1.6, Flash = 0.6, Focus = 0.8,
				Voice = 1.5, Footstep = 1, Sneak = 0.4, FlashlightClick = 0.15, FlashlightMalfunction = 0.4,
				Interaction = 1, Radio = 1.4, Phone = 1.4, EMF = 0.8,
			},
		},
		Params = { ChaseSpeed = 15, AttackRange = 4.5, BatteryDrain = 25 },
		Icon = "👂",
		Description = "Blind. It hunts by sound. Photograph it... if the shutter doesn't give you away.",
	},
	{
		Id = "LightCreature",
		Name = "Light Creature",
		Rarity = "Unusual",
		Weight = 70,
		Behavior = "LightCreature",
		Lifetime = 30,
		PhotoDistance = 60,
		Spawn = { Kinds = { "Dark" } },
		TargetRadius = 2,
		Danger = 0.5,
		EMF = 2,
		Cold = true,
		Hearing = { Radius = 22, Threshold = 0.03, Kinds = { FlashlightClick = 1.5, FlashlightMalfunction = 1.2 } },
		Params = { BeamRange = 30, BeamConeDeg = 28 },
		Icon = "🦎",
		Description = "Lives in the dark. Point a flashlight at it and it's gone.",
	},
	{
		Id = "Echo",
		Name = "Echo",
		Rarity = "Unusual",
		Weight = 60,
		Behavior = "Echo",
		Lifetime = 40,
		PhotoDistance = 65,
		Spawn = { Kinds = { "Floor", "Dark" } },
		TargetRadius = 2,
		Danger = 0.4,
		EMF = 3,
		Params = { ListenRadius = 70, RepeatCount = 3, RepeatWindow = 8, Cooldown = 6 },
		Icon = "🎭",
		Description = "Repeat a sound and it repeats it back... from somewhere else.",
	},
	{
		Id = "Mimic",
		Name = "Mimic",
		Rarity = "Rare",
		Weight = 25,
		Behavior = "Mimic",
		Lifetime = 45,
		PhotoDistance = 60,
		Spawn = { Kinds = { "Dark" } },
		TargetRadius = 2,
		Danger = 0.6,
		EMF = 3,
		Cold = true,
		Params = { TrickInterval = { 5, 9 }, LureRange = 60 },
		Icon = "👄",
		Description = "That camera click wasn't your friend. Neither were those footsteps.",
	},
}
---------------------------------------------------------------------------
-- Lookups & helpers (no need to edit below this line when adding anomalies)
---------------------------------------------------------------------------

AnomalyConfig.ById = {}

for _, def in ipairs(AnomalyConfig.List) do
	for key, value in pairs(AnomalyConfig.Defaults) do
		if def[key] == nil then
			def[key] = value
		end
	end
	def.Spawn = def.Spawn or {}
	def.Params = def.Params or {}
	assert(RarityConfig.Tiers[def.Rarity], "Unknown rarity for anomaly " .. tostring(def.Id))
	assert(AnomalyConfig.ById[def.Id] == nil, "Duplicate anomaly id " .. tostring(def.Id))
	AnomalyConfig.ById[def.Id] = def
end

local function computeBaseWeight(): number
	local total = 0
	for _, def in ipairs(AnomalyConfig.List) do
		if def.Enabled and not def.RequiresEvent then
			total += def.Weight
		end
	end
	return total
end

AnomalyConfig.BaseWeight = computeBaseWeight()

function AnomalyConfig.Get(id: string)
	return AnomalyConfig.ById[id]
end

function AnomalyConfig.Count(): number
	local count = 0
	for _, def in ipairs(AnomalyConfig.List) do
		if def.Enabled then
			count += 1
		end
	end
	return count
end

-- All enabled anomalies sorted from most common to rarest.
function AnomalyConfig.GetSorted()
	local list = {}
	for _, def in ipairs(AnomalyConfig.List) do
		if def.Enabled then
			table.insert(list, def)
		end
	end
	table.sort(list, function(a, b)
		local ra, rb = RarityConfig.GetRank(a.Rarity), RarityConfig.GetRank(b.Rarity)
		if ra ~= rb then
			return ra < rb
		end
		if a.Weight ~= b.Weight then
			return a.Weight > b.Weight
		end
		return a.Id < b.Id
	end)
	return list
end

function AnomalyConfig.GetReward(def): number
	return def.Reward or RarityConfig.Get(def.Rarity).BaseReward
end

-- "1 in N" chance of a single spawn roll being this anomaly (base pool, no events).
function AnomalyConfig.GetOdds(id: string): number
	local def = AnomalyConfig.ById[id]
	if not def or def.Weight <= 0 then
		return math.huge
	end
	local pool = AnomalyConfig.BaseWeight
	if def.RequiresEvent then
		pool += def.Weight
	end
	return pool / def.Weight
end

local function niceRound(n: number): number
	if n < 100 then
		return math.max(2, math.floor(n + 0.5))
	end
	local magnitude = 10 ^ math.floor(math.log10(n) - 1)
	return math.floor(n / magnitude + 0.5) * magnitude
end

local function withCommas(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return formatted
end

function AnomalyConfig.GetOddsText(id: string): string
	local def = AnomalyConfig.ById[id]
	if not def then
		return "1 / ???"
	end
	if RarityConfig.Get(def.Rarity).HideOdds then
		return "1 / ???"
	end
	return "1 / " .. withCommas(niceRound(AnomalyConfig.GetOdds(id)))
end

-- Should capturing this anomaly be announced? Returns "None" | "Server" | "Reveal".
function AnomalyConfig.GetAnnounceMode(def): string
	if def.Announce and def.Announce ~= "Default" then
		return def.Announce
	end
	local tier = RarityConfig.Get(def.Rarity)
	if tier.DramaticReveal then
		return "Reveal"
	elseif tier.AnnounceToServer then
		return "Server"
	end
	return "None"
end

return AnomalyConfig
