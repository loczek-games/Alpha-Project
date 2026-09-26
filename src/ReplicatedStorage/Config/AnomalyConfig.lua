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
	                     Kinds   = spawn node kinds of the map (AnomalyNodes/Spawns):
	                               Floor, Dark, RunLane, Skylight, Balcony, Glass, Mirror,
	                               Aisle, Kitchen, Table, Corridor, Hallway, Pillar,
	                               ClosedStore, MannequinGroup, ... (see World/Mall/*)
	                     Zones   = { zone ids } (nil = any zone)
	                     Fixture = CollectionService tag of an existing map object it haunts
	                     Player  = true when it targets a player
	                     MinPlayers = requirement for spawning
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

local ZONES_PUBLIC = { "GrandHall", "FoodCourt", "Entrance", "Supermarket", "Electronics", "Clothing", "ToyStore", "Arcade", "Cinema" }

local LISTENER_HEARING = {
	Radius = 80,
	Threshold = 0.06,
	Kinds = {
		Run = 1.4, Land = 1.3, DoorSlam = 1.5, DoorOpen = 1, DoorClose = 0.6, Shutter = 1.6, Flash = 0.6, Focus = 0.8,
		Voice = 1.5, Footstep = 1, Sneak = 0.4, FlashlightClick = 0.15, FlashlightMalfunction = 0.4,
		Interaction = 1, Radio = 1.4, Phone = 1.4, EMF = 0.8,
	},
}

AnomalyConfig.List = {
	------------------------------------------------------------------ COMMON
	{
		Id = "ReverseClock", Name = "Reverse Clock", Rarity = "Common", Weight = 260,
		Behavior = "ReverseClock", Lifetime = 25, PhotoDistance = 60,
		Spawn = { Fixture = "MallClock" }, TargetRadius = 2.5,
		Params = { MinuteSpeed = 200, HourSpeed = 18 },
		Icon = "🕰️", Danger = 0.1, EMF = 2,
		Description = "Every clock in the mall stopped at the same minute. This one is running backwards.",
	},
	{
		Id = "FloatingCart", Name = "Floating Shopping Cart", Rarity = "Common", Weight = 240,
		Behavior = "ObjectAnomaly", Lifetime = 24, PhotoDistance = 70,
		Spawn = { Fixture = "ShoppingCart" }, TargetRadius = 2.5,
		Params = { Mode = "Levitate", Height = 5, Bob = 0.7, Spin = 0.3 },
		Icon = "🛒", Danger = 0.2, EMF = 3,
		Description = "An abandoned cart that forgot about gravity.",
	},
	{
		Id = "FakeExit", Name = "Moving Exit", Rarity = "Common", Weight = 220,
		Behavior = "FakeExit", Lifetime = 28, PhotoDistance = 70,
		Spawn = { Fixture = "ExitSign" }, TargetRadius = 1.8,
		Params = { FlickerMin = 0.25, FlickerMax = 1.1 },
		Icon = "🔀", Danger = 0.1, EMF = 1,
		Description = "The EXIT sign keeps moving. The exit it points to does not exist.",
	},
	{
		Id = "MovingCart", Name = "Moving Cart", Rarity = "Common", Weight = 200,
		Behavior = "ObjectAnomaly", Lifetime = 30, PhotoDistance = 70,
		Spawn = { Fixture = "ShoppingCart" }, TargetRadius = 2.5,
		Params = { Mode = "Creep", Step = 2.2, Interval = 0.7, StopDistance = 4, Sound = "Anomaly.CartRoll" },
		Icon = "🛒", Danger = 0.3, EMF = 2,
		Description = "Every time you look back, the cart is closer.",
	},
	{
		Id = "FloatingFoodTray", Name = "Floating Food Tray", Rarity = "Common", Weight = 180,
		Behavior = "ObjectAnomaly", Lifetime = 24, PhotoDistance = 60,
		Spawn = { Fixture = "FoodTray" }, TargetRadius = 1.6,
		Params = { Mode = "Levitate", Height = 3, Bob = 0.4, Spin = 1.2 },
		Icon = "🍔", Danger = 0.1, EMF = 2,
		Description = "Someone's last meal, spinning slowly above the table.",
	},
	{
		Id = "ShoppingBagMovement", Name = "Shopping Bag Movement", Rarity = "Common", Weight = 170,
		Behavior = "ObjectAnomaly", Lifetime = 28, PhotoDistance = 50,
		Spawn = { Fixture = "ShoppingBag" }, TargetRadius = 1.4,
		Params = { Mode = "Creep", Step = 0.9, Interval = 0.8, StopDistance = 3, Sound = "Anomaly.BagRustle", Face = false },
		Icon = "🛍️", Danger = 0.2, EMF = 2,
		Description = "The bag rustles. Something inside is dragging it towards you.",
	},
	{
		Id = "MovingChair", Name = "Moving Chair", Rarity = "Common", Weight = 170,
		Behavior = "ObjectAnomaly", Lifetime = 30, PhotoDistance = 60,
		Spawn = { Kinds = { "Table" }, Zones = { "FoodCourt" } }, TargetRadius = 1.8,
		Params = { Mode = "Chair" },
		Icon = "🪑", Danger = 0.2, EMF = 2,
		Description = "A chair drags itself across the food court, always into your way.",
	},
	{
		Id = "RollingBall", Name = "Rolling Ball", Rarity = "Common", Weight = 150,
		Behavior = "ObjectAnomaly", Lifetime = 22, PhotoDistance = 50,
		Spawn = { Fixture = "ToyBall" }, TargetRadius = 1.4,
		Params = { Mode = "Roll", Speed = 7 },
		Icon = "🔴", Danger = 0.2, EMF = 2,
		Description = "A child's ball rolls after you. Nobody threw it.",
	},
	------------------------------------------------------------------ UNUSUAL
	{
		Id = "MovingDoor", Name = "Possessed Door", Rarity = "Unusual", Weight = 100,
		Behavior = "ObjectAnomaly", Lifetime = 24, PhotoDistance = 60,
		Spawn = { Fixture = "Door" }, TargetRadius = 2.5,
		Params = { Mode = "Door" },
		Icon = "🚪", Danger = 0.4, EMF = 3, Cold = true,
		Description = "It opens. It slams. Nobody is there.",
	},
	{
		Id = "BlinkingLights", Name = "Blinking Lights", Rarity = "Unusual", Weight = 95,
		Behavior = "BlinkingLights", Lifetime = 24, PhotoDistance = 80,
		Spawn = { Kinds = { "Floor" }, Zones = { "FoodCourt", "Arcade", "ToyStore", "Restrooms", "Supermarket", "ParkingGarage", "Cinema", "Electronics" } },
		TargetRadius = 2.5, Params = { HiddenTransparency = 0.8 },
		Icon = "💡", Danger = 0.5, EMF = 4,
		Description = "Three short, three long, three short. Something stands where the dark was.",
	},
	{
		Id = "WalkingPainting", Name = "Walking Painting", Rarity = "Unusual", Weight = 90,
		Behavior = "WalkingPainting", Lifetime = 26, PhotoDistance = 60,
		Spawn = { Fixture = "MallPainting" }, TargetRadius = 3,
		Icon = "🖼️", Danger = 0.3, EMF = 2, Cold = true,
		Description = "The person in the painting moves whenever nobody is looking.",
	},
	{
		Id = "TVEntity", Name = "TV Entity", Rarity = "Unusual", Weight = 95,
		Behavior = "ObjectAnomaly", Lifetime = 26, PhotoDistance = 60,
		Spawn = { Fixture = "MallTV", Zones = { "Electronics", "Arcade", "SecurityRoom" } }, TargetRadius = 2,
		Params = { Mode = "Screens", Radius = 26 },
		Icon = "📺", Danger = 0.4, EMF = 4,
		Description = "Every screen in the store switched on. They all show the same face.",
	},
	{
		Id = "PhoneCaller", Name = "Phone Caller", Rarity = "Unusual", Weight = 80,
		Behavior = "ObjectAnomaly", Lifetime = 30, PhotoDistance = 50,
		Spawn = { Fixture = "Payphone" }, TargetRadius = 1.8,
		Params = { Mode = "Phone", Silent = true },
		Icon = "☎️", Danger = 0.3, EMF = 3,
		Description = "A disconnected payphone is ringing. It is for you.",
	},
	{
		Id = "CarAlarm", Name = "Car Alarm", Rarity = "Unusual", Weight = 70,
		Behavior = "ObjectAnomaly", Lifetime = 26, PhotoDistance = 80,
		Spawn = { Fixture = "CarAlarm" }, TargetRadius = 3,
		Params = { Mode = "CarAlarm" },
		Icon = "🚨", Danger = 0.4, EMF = 3,
		Description = "The car has had no battery for years. Its alarm is screaming.",
	},
	{
		Id = "PossessedArcade", Name = "Possessed Arcade Machine", Rarity = "Unusual", Weight = 85,
		Behavior = "ObjectAnomaly", Lifetime = 26, PhotoDistance = 55,
		Spawn = { Fixture = "ArcadeCabinet" }, TargetRadius = 2,
		Params = { Mode = "Arcade" },
		Icon = "🕹️", Danger = 0.3, EMF = 3,
		Description = "PLAYER 2 HAS ENTERED THE GAME.",
	},
	{
		Id = "StatueTurns", Name = "The Statue", Rarity = "Unusual", Weight = 70,
		Behavior = "ObjectAnomaly", Lifetime = 30, PhotoDistance = 80,
		Spawn = { Fixture = "MallStatue" }, TargetRadius = 3,
		Params = { Mode = "Turn" },
		Icon = "🗿", Danger = 0.4, EMF = 3, Cold = true,
		Description = "The founder's statue always faces the entrance. Always faced.",
	},
	{
		Id = "LockerKnock", Name = "Locker Knocking", Rarity = "Unusual", Weight = 70,
		Behavior = "ObjectAnomaly", Lifetime = 26, PhotoDistance = 45,
		Spawn = { Fixture = "Locker" }, TargetRadius = 1.8,
		Params = { Mode = "Locker" },
		Icon = "🗄️", Danger = 0.5, EMF = 4, Cold = true,
		Description = "Knock. Knock. Knock. From the inside.",
	},
	{
		Id = "StoreAlarm", Name = "Store Alarm", Rarity = "Unusual", Weight = 70,
		Behavior = "ObjectAnomaly", Lifetime = 24, PhotoDistance = 70,
		Spawn = { Kinds = { "Floor" }, Zones = { "Clothing", "Electronics", "ToyStore", "Supermarket" } }, TargetRadius = 2.5,
		Params = { Mode = "StoreAlarm" },
		Icon = "🔔", Danger = 0.3, EMF = 3,
		Description = "The anti-theft gates are screaming. Nothing walked through them. Nothing you can see.",
	},
	{
		Id = "FlyingShelves", Name = "Flying Shelves", Rarity = "Unusual", Weight = 70,
		Behavior = "ObjectAnomaly", Lifetime = 20, PhotoDistance = 60,
		Spawn = { Fixture = "StoreShelf" }, TargetRadius = 3,
		Params = { Mode = "Burst" },
		Icon = "📦", Danger = 0.5, EMF = 4,
		Description = "The shelf shakes... and everything on it is thrown across the aisle.",
	},
	{
		Id = "CeilingWatcher", Name = "Ceiling Face", Rarity = "Unusual", Weight = 75,
		Behavior = "ObjectAnomaly", Lifetime = 22, PhotoDistance = 60,
		Spawn = { Fixture = "Vent" }, TargetRadius = 1.6,
		Params = { Mode = "CeilingFace" },
		Icon = "😮", Danger = 0.5, EMF = 4, Cold = true,
		Description = "A pale face pressed against the ventilation grille. Look up.",
	},
	------------------------------------------------------------------ RARE
	{
		Id = "WatchingMannequin", Name = "Watching Mannequin", Rarity = "Rare", Weight = 36,
		Behavior = "ObjectAnomaly", Lifetime = 26, PhotoDistance = 70,
		Spawn = { Fixture = "MallMannequin" }, TargetRadius = 2.2,
		Params = { Mode = "Turn", HeadOnly = true },
		Icon = "🧍", Danger = 0.4, EMF = 3, Cold = true,
		Description = "Its head turns to follow you. Only when you are not looking.",
	},
	{
		Id = "MannequinGroup", Name = "Mannequin Group", Rarity = "Rare", Weight = 30,
		Behavior = "ObjectAnomaly", Lifetime = 30, PhotoDistance = 70,
		Spawn = { Fixture = "MallMannequin", Zones = { "Clothing" } }, TargetRadius = 3,
		Params = { Mode = "Creep", Group = 30, GroupTag = "MallMannequin", Step = 1.2, Interval = 0.6, StopDistance = 5 },
		Icon = "👥", Danger = 0.6, EMF = 4, Cold = true,
		Description = "The whole display moved closer. All of them. Together.",
	},
	{
		Id = "FacelessShopper", Name = "Faceless Shopper", Rarity = "Rare", Weight = 32,
		Behavior = "Entity", Lifetime = 34, PhotoDistance = 60,
		Spawn = { Kinds = { "Floor" }, Zones = { "GrandHall", "FoodCourt", "Entrance", "Supermarket" } }, TargetRadius = 2,
		Params = {
			Appearance = "Faceless",
			AI = { States = { Idle = true, Observe = true, Disappear = true }, ShyWhenSeen = true, Aggression = 0, SightRange = 45, Speeds = { Walk = 5 }, Gaits = { Default = "Walk" } },
			OnPhoto = "Disappear",
		},
		Icon = "😶", Danger = 0.3, EMF = 2,
		Description = "A late shopper strolling through a closed mall. Look closer at the face.",
	},
	{
		Id = "FakeElevator", Name = "Fake Elevator", Rarity = "Rare", Weight = 30,
		Behavior = "ObjectAnomaly", Lifetime = 26, PhotoDistance = 60,
		Spawn = { Fixture = "ElevatorDoor" }, TargetRadius = 2.2,
		Params = { Mode = "Elevator" },
		Icon = "🛗", Danger = 0.6, EMF = 4, Cold = true,
		Description = "The elevator has been out of service since 1998. Ding.",
	},
	{
		Id = "CarWithSomeoneInside", Name = "Someone In The Car", Rarity = "Rare", Weight = 28,
		Behavior = "ObjectAnomaly", Lifetime = 30, PhotoDistance = 70,
		Spawn = { Fixture = "OccupiedCar" }, TargetRadius = 1.8,
		Params = { Mode = "OccupiedCar" },
		Icon = "🚗", Danger = 0.5, EMF = 3, Cold = true,
		Description = "Someone is sitting in the driver's seat. Its head turns with you.",
	},
	{
		Id = "SecurityCameraWatcher", Name = "Security Camera Watcher", Rarity = "Rare", Weight = 30,
		Behavior = "ObjectAnomaly", Lifetime = 26, PhotoDistance = 60,
		Spawn = { Fixture = "SecurityCamera" }, TargetRadius = 1.5,
		Params = { Mode = "SecurityCams" },
		Icon = "📹", Danger = 0.4, EMF = 3,
		Description = "Every camera in the area turned to follow you. The monitors show someone standing behind you.",
	},
	{
		Id = "ClosedStoreOpening", Name = "Closed Store Opening", Rarity = "Rare", Weight = 26,
		Behavior = "ObjectAnomaly", Lifetime = 34, PhotoDistance = 70,
		Spawn = { Fixture = "StoreShutter" }, TargetRadius = 2.5,
		Params = { Mode = "Shutter" },
		Icon = "🏪", Danger = 0.5, EMF = 4, Cold = true,
		Description = "The shutter that has been locked for years is rising. The lights inside are on.",
	},
	{
		Id = "BlackFigureBehindGlass", Name = "Black Figure Behind Glass", Rarity = "Rare", Weight = 28,
		Behavior = "Entity", Lifetime = 28, PhotoDistance = 80,
		Spawn = { Kinds = { "Glass" } }, TargetRadius = 2.5,
		Params = {
			Appearance = "Shadow", Placement = "Glass",
			AI = { States = { Idle = true, Observe = true, Disappear = true }, ShyWhenSeen = false, Aggression = 0, ObserveTime = { 12, 20 }, SightRange = 90, Speeds = { Walk = 0 } },
			OnPhoto = "Disappear",
		},
		Icon = "🧍‍♂️", Danger = 0.6, EMF = 3, Cold = true,
		Description = "Outside the entrance glass, in the rain, someone is watching you.",
	},
	{
		Id = "TheListener", Name = "The Listener", Rarity = "Rare", Weight = 26,
		Behavior = "Entity", Lifetime = 50, PhotoDistance = 70,
		Spawn = { Kinds = { "Floor", "Dark" }, Zones = { "GrandHall", "FoodCourt", "ParkingGarage", "ServiceHalls", "Cinema", "Supermarket" } },
		TargetRadius = 2.5, Danger = 0.8, EMF = 4, Cold = true,
		Hearing = LISTENER_HEARING,
		Params = {
			Appearance = "Listener", Loop = "Anomaly.ListenerBreath", Twitch = 0.3,
			AI = {
				States = { Idle = true, InvestigateNoise = true, Search = true, Chase = true, Attack = true, Disappear = true },
				SightRange = 0, Aggression = 1, Speeds = { Walk = 5, Chase = 15 }, Gaits = { Default = "Limp", InvestigateNoise = "Sprint" },
				Jumpscare = "Listener", Heavy = false, BatteryDrain = 25, AttackRange = 4.5,
				Sounds = { Alert = "Anomaly.ListenerAlert", Attack = "Anomaly.Groan" },
			},
		},
		Icon = "👂",
		Description = "Blind. It hunts by sound. Photograph it... if the shutter doesn't give you away.",
	},
	{
		Id = "WalkingStoreDummy", Name = "Walking Store Dummy", Rarity = "Rare", Weight = 24,
		Behavior = "Entity", Lifetime = 40, PhotoDistance = 60,
		Spawn = { Kinds = { "Floor", "Dark", "MannequinGroup" }, Zones = { "Clothing", "ToyStore", "Electronics" } }, TargetRadius = 2.2,
		Params = {
			Appearance = "StoreDummy",
			AI = {
				States = { Idle = true, Stalk = true, Chase = true, Attack = true, Disappear = true },
				FreezeWhenSeen = true, Aggression = 0.8, StalkDistance = 10, SightRange = 60,
				Speeds = { Walk = 6, Stalk = 10, Chase = 16 }, Gaits = { Default = "StopMotion" },
				Jumpscare = "Mannequin", Heavy = true,
			},
		},
		Icon = "🎎", Danger = 0.8, EMF = 4, Cold = true,
		Description = "It only moves when nobody is looking. Keep looking.",
	},
	{
		Id = "EscalatorFigure", Name = "Escalator Figure", Rarity = "Rare", Weight = 24,
		Behavior = "ObjectAnomaly", Lifetime = 20, PhotoDistance = 80,
		Spawn = { Fixture = "Escalator" }, TargetRadius = 2.5,
		Params = { Mode = "Escalator" },
		Icon = "🛗", Danger = 0.5, EMF = 3, Cold = true,
		Description = "The dead escalator started moving. Someone is riding it up.",
	},
	{
		Id = "WrongStore", Name = "Wrong Store", Rarity = "Rare", Weight = 22,
		Behavior = "ObjectAnomaly", Lifetime = 30, PhotoDistance = 80,
		Spawn = { Kinds = { "ClosedStore" } }, TargetRadius = 4,
		Params = { Mode = "WrongStore" },
		Icon = "🏬", Danger = 0.3, EMF = 3,
		Description = "That store was never in this mall. It knows your name.",
	},
	{
		Id = "Ratthew", Name = "Ratthew", Rarity = "Rare", Weight = 24,
		Behavior = "Entity", Lifetime = 36, PhotoDistance = 60,
		Spawn = { Kinds = { "Kitchen", "Dark" }, Zones = { "FoodCourt" } }, TargetRadius = 2,
		Hearing = { Radius = 40, Threshold = 0.08, Kinds = { Run = 1.2, Land = 1, DoorSlam = 1, Interaction = 1, Voice = 1.2, Footstep = 0.6 } },
		Params = {
			Appearance = "RatthewAnomaly", Twitch = 0.9,
			AI = {
				States = { Idle = true, Observe = true, InvestigateNoise = true, Hide = true, Chase = true, Attack = true, Disappear = true },
				Aggression = 0.45, Speeds = { Walk = 7, Chase = 20 }, Gaits = { Default = "Crawl", Observe = "Walk" },
				Jumpscare = "Generic", Heavy = true,
			},
			OnPhoto = "Chase",
		},
		Icon = "🐀", Danger = 0.7, EMF = 3,
		Description = "The old food court mascot. It still lives in the kitchens.",
	},
	------------------------------------------------------------------ EPIC
	{
		Id = "WrongReflection", Name = "Wrong Reflection", Rarity = "Epic", Weight = 12,
		Behavior = "WrongReflection", Lifetime = 22, PhotoDistance = 45,
		Spawn = { Fixture = "MallMirror", MinPlayers = 1 }, TargetRadius = 2.2,
		Params = { WaveInterval = 4.5 },
		Icon = "🪞", Danger = 0.6, EMF = 4, Cold = true,
		Description = "Your reflection is not copying you anymore. It is watching you.",
	},
	{
		Id = "MirrorDouble", Name = "Mirror Double", Rarity = "Epic", Weight = 10,
		Behavior = "Entity", Lifetime = 26, PhotoDistance = 60,
		Spawn = { Fixture = "MallMirror", Zones = { "Restrooms", "Clothing" }, Player = true, MinPlayers = 1 }, TargetRadius = 2,
		Params = {
			Placement = "Mirror",
			AI = { Start = "Follow", States = { Follow = true, Chase = true, Attack = true, Disappear = true }, Aggression = 0.2, Speeds = { Walk = 8, Stalk = 12, Chase = 17 }, Jumpscare = "Smile", Heavy = false },
			OnPhoto = "Disappear",
		},
		Icon = "👤", Danger = 0.7, EMF = 4, Cold = true,
		Description = "It stepped out of the mirror wearing your face. It follows you everywhere.",
	},
	{
		Id = "CeilingCrawler", Name = "Ceiling Crawler", Rarity = "Epic", Weight = 14,
		Behavior = "CeilingCrawler", Lifetime = 150, PhotoDistance = 70, MaxActive = 1,
		Spawn = {}, TargetRadius = 3.5,
		Icon = "🕷️", Danger = 1, EMF = 5, Cold = true, Residue = false,
		Description = "Long legs, a human face, and it lives on the ceiling. If you hear crawling above you, don't look up.",
	},
	{
		Id = "FakePlayer", Name = "Fake Player", Rarity = "Epic", Weight = 9,
		Behavior = "FakePlayer", Lifetime = 30, PhotoDistance = 70,
		Spawn = { Kinds = { "Floor" }, Zones = { "GrandHall", "FoodCourt" }, MinPlayers = 1 }, TargetRadius = 2.2,
		Params = { WalkSpeed = 9, HeadTwistInterval = 6 },
		Icon = "👥", Danger = 0.6, EMF = 3, Cold = true,
		Description = "It looks exactly like someone in this investigation. Almost exactly.",
	},
	{
		Id = "SmilingEntity", Name = "Smiling Entity", Rarity = "Epic", Weight = 11,
		Behavior = "Entity", Lifetime = 45, PhotoDistance = 80,
		Spawn = { Kinds = { "Dark", "Floor", "Balcony" }, Zones = ZONES_PUBLIC }, TargetRadius = 2.4,
		Params = {
			Appearance = "SmilingEntity", Twitch = 0.4, Loop = "Anomaly.EntityDrone",
			AI = {
				States = { Idle = true, Observe = true, Stalk = true, Chase = true, Attack = true, Hide = true, Disappear = true },
				FreezeWhenSeen = true, Aggression = 0.55, StalkDistance = 18, SightRange = 90, ObserveTime = { 3, 6 },
				Speeds = { Walk = 6, Stalk = 11, Chase = 18 }, Gaits = { Default = "StopMotion", Chase = "Sprint" },
				Jumpscare = "Smile", Heavy = true,
			},
		},
		Icon = "😁", Danger = 0.9, EMF = 5, Cold = true,
		Description = "It never stops smiling. It only moves when you blink.",
	},
	{
		Id = "PossessedCustomer", Name = "Possessed Customer", Rarity = "Epic", Weight = 11,
		Behavior = "Entity", Lifetime = 50, PhotoDistance = 70,
		Spawn = { Kinds = { "Floor", "Aisle", "Dark" }, Zones = { "Supermarket", "FoodCourt", "GrandHall", "Cinema" } }, TargetRadius = 2.2,
		Hearing = { Radius = 55, Threshold = 0.08, Kinds = { Run = 1.3, Land = 1.2, DoorSlam = 1.4, Shutter = 1.2, Voice = 1.3, Interaction = 0.8, Footstep = 0.7 } },
		Params = {
			Appearance = "PossessedEntity", Twitch = 1,
			AI = {
				States = { Idle = true, Observe = true, Stalk = true, Search = true, InvestigateNoise = true, Chase = true, Attack = true, Hide = true, Disappear = true },
				Aggression = 0.65, SightRange = 70, StalkDistance = 14,
				Speeds = { Walk = 5, Stalk = 8, Chase = 19 }, Gaits = { Default = "Jerky", Chase = "Crawl", Search = "Limp" },
				Jumpscare = "Possessed", Heavy = true,
				Sounds = { Alert = "Anomaly.Laugh", Attack = "Anomaly.Groan" },
			},
			OnPhoto = "Chase",
		},
		Icon = "🧟", Danger = 0.9, EMF = 5, Cold = true,
		Description = "The last customer never left. Something else is walking in them now.",
	},
	{
		Id = "ImpossibleHallway", Name = "Impossible Hallway", Rarity = "Epic", Weight = 8,
		Behavior = "ObjectAnomaly", Lifetime = 40, PhotoDistance = 160,
		Spawn = { Kinds = { "Hallway" } }, TargetRadius = 3,
		Params = { Mode = "Hallway", WallOffset = 10 },
		Icon = "🚪", Danger = 0.6, EMF = 4, Cold = true,
		Description = "The employee hallway used to end in a wall. Now it just keeps going.",
	},
	------------------------------------------------------------------ MYTHIC
	{
		Id = "SmilingPlayer", Name = "Smiling Player", Rarity = "Mythic", Weight = 3,
		Behavior = "SmilingPlayer", Lifetime = 30, PhotoDistance = 60,
		Spawn = { Player = true, MinPlayers = 2 }, TargetRadius = 1.8,
		Icon = "😃", Danger = 0.5, EMF = 2, Residue = false,
		Description = "One investigator is smiling far too wide. They have no idea.",
	},
	{
		Id = "OneBehindYou", Name = "The One Behind You", Rarity = "Mythic", Weight = 3,
		Behavior = "OneBehindYou", Lifetime = 20, PhotoDistance = 60,
		Spawn = { Player = true, MinPlayers = 2 }, TargetRadius = 2.5,
		Params = { Distance = 4.5 },
		Icon = "👻", Danger = 0.9, EMF = 5, Cold = true, Residue = false,
		Description = "It follows one investigator closely. Whatever you do, do not turn around.",
	},
	{
		Id = "ParkingGarageStalker", Name = "Parking Garage Stalker", Rarity = "Mythic", Weight = 3,
		Behavior = "Entity", Lifetime = 60, PhotoDistance = 110,
		Spawn = { Kinds = { "Pillar", "Dark", "Floor" }, Zones = { "ParkingGarage" } }, TargetRadius = 4,
		Hearing = { Radius = 70, Threshold = 0.07, Kinds = { Run = 1.3, Land = 1.3, DoorSlam = 1.3, Shutter = 1.1, Voice = 1.2, Footstep = 0.8, Interaction = 0.9 } },
		Params = {
			Appearance = "AbnormalTitan", Loop = "Anomaly.EntityDrone", AgentRadius = 3, AgentHeight = 11,
			AI = {
				States = { Idle = true, Observe = true, Stalk = true, Hide = true, Search = true, InvestigateNoise = true, Chase = true, Attack = true, Disappear = true },
				Aggression = 0.6, SightRange = 110, StalkDistance = 26, AttackRange = 6.5,
				Speeds = { Walk = 7, Stalk = 9, Chase = 20 }, Gaits = { Default = "Walk", Chase = "Sprint" },
				Jumpscare = "Titan", Heavy = true,
				Sounds = { Alert = "Anomaly.MetalGroan", Attack = "Anomaly.Groan" },
			},
			OnPhoto = "Chase",
		},
		Icon = "🦍", Danger = 1, EMF = 5, Cold = true,
		Description = "Something huge moves between the pillars on level B1. It is always one pillar closer.",
	},
	{
		Id = "EmployeeOnlyEntity", Name = "Employee Only Entity", Rarity = "Mythic", Weight = 3,
		Behavior = "Entity", Lifetime = 55, PhotoDistance = 70,
		Spawn = { Kinds = { "Corridor", "Dark", "Hallway" }, Zones = { "ServiceHalls", "BackOfHouse" } }, TargetRadius = 2.2,
		Hearing = { Radius = 60, Threshold = 0.06, Kinds = { Run = 1.4, Land = 1.3, DoorOpen = 1.2, DoorSlam = 1.5, Interaction = 1.2, Voice = 1.3, Footstep = 0.9, Radio = 1.4 } },
		Params = {
			Appearance = "SlackerEntity", Twitch = 0.6,
			AI = {
				States = { Idle = true, InvestigateNoise = true, Search = true, Stalk = true, Chase = true, Attack = true, Hide = true, Disappear = true },
				Aggression = 0.6, SightRange = 60, StalkDistance = 16,
				Speeds = { Walk = 6, Stalk = 8, Chase = 18 }, Gaits = { Default = "Limp", Chase = "Sprint" },
				Jumpscare = "Slacker", Heavy = true,
			},
			OnPhoto = "Chase",
		},
		Icon = "🪪", Danger = 1, EMF = 5, Cold = true,
		Description = "EMPLOYEES ONLY. It still works the night shift. You are not staff.",
	},
	------------------------------------------------------------------ NIGHTMARE
	{
		Id = "ThePhotographer", Name = "The Photographer", Rarity = "Nightmare", Weight = 0.5,
		Behavior = "ThePhotographer", Lifetime = 25, PhotoDistance = 70,
		Spawn = { Kinds = { "Floor", "Dark" }, Zones = { "Cinema", "Theaters", "ServiceHalls", "ParkingGarage", "Arcade" } }, TargetRadius = 2.5,
		Icon = "📷", Badge = "PhotographedBack",
		Danger = 0.7, EMF = 4, Cold = true,
		Hearing = { Radius = 45, Threshold = 0.05, Kinds = { Focus = 1.6, Shutter = 2, Flash = 2 } },
		Description = "It collects evidence too. Of you.",
	},
	------------------------------------------------------------------ IMPOSSIBLE
	{
		Id = "TheObserver", Name = "The Observer", Rarity = "Impossible", Weight = 0.0148, -- keeps the displayed odds at 1 / 100,000
		Behavior = "TheObserver", Lifetime = 20, PhotoDistance = 220,
		Spawn = { Kinds = { "Skylight" } }, TargetRadius = 13,
		Icon = "👁️", Badge = "ImpossibleFound",
		Danger = 1, EMF = 5, Cold = true, Residue = false,
		Description = "Look up through the skylight. It has always been looking down.",
	},
	------------------------------------------------------------------ ???
	{
		Id = "TheNightManager", Name = "The Night Manager", Rarity = "Unknown", Weight = 0.0013,
		Behavior = "TheNightManager", Lifetime = 26, PhotoDistance = 80,
		Spawn = { Kinds = { "Floor" }, Zones = { "GrandHall", "FoodCourt" } }, TargetRadius = 3,
		Params = { BlinkInterval = 6 },
		Icon = "🕴️", Badge = "ImpossibleFound",
		Danger = 1, EMF = 5, Cold = true,
		Description = "Attention shoppers. The mall is now closed.",
	},
	------------------------------------------------------------------ BLACKOUT ONLY
	{
		Id = "GlowingEyes", Name = "Glowing Eyes", Rarity = "Common", Weight = 220,
		Behavior = "GlowingEyes", Lifetime = 16, PhotoDistance = 60, MaxActive = 2,
		RequiresEvent = "Blackout", EventWeightMultiplier = 1.5,
		Spawn = { Kinds = { "Dark" } }, TargetRadius = 1.5,
		Icon = "👀", Danger = 0.4, EMF = 2,
		Description = "Only appears in a blackout. Two lights that blink back.",
	},
	{
		Id = "ShadowRunner", Name = "Shadow Runner", Rarity = "Unusual", Weight = 90,
		Behavior = "ShadowRunner", Lifetime = 14, PhotoDistance = 80,
		RequiresEvent = "Blackout", EventWeightMultiplier = 1.5,
		Spawn = { Kinds = { "RunLane" } }, TargetRadius = 4,
		Params = { RunTime = 1.6, Pause = 1.4 },
		Icon = "🏃", Danger = 0.6, EMF = 3, Cold = true, Residue = false,
		Description = "Only appears in a blackout. Too fast to be a person.",
	},
	------------------------------------------------------------------ SOUND-REACTIVE
	{
		Id = "LightCreature", Name = "Light Creature", Rarity = "Unusual", Weight = 60,
		Behavior = "LightCreature", Lifetime = 30, PhotoDistance = 60,
		Spawn = { Kinds = { "Dark" } }, TargetRadius = 2,
		Danger = 0.5, EMF = 2, Cold = true,
		Hearing = { Radius = 22, Threshold = 0.03, Kinds = { FlashlightClick = 1.5, FlashlightMalfunction = 1.2 } },
		Params = { BeamRange = 30, BeamConeDeg = 28 },
		Icon = "🦎",
		Description = "Lives in the dark. Point a flashlight at it and it's gone.",
	},
	{
		Id = "Echo", Name = "Echo", Rarity = "Unusual", Weight = 55,
		Behavior = "Echo", Lifetime = 40, PhotoDistance = 65,
		Spawn = { Kinds = { "Floor", "Dark" } }, TargetRadius = 2,
		Danger = 0.4, EMF = 3,
		Params = { ListenRadius = 70, RepeatCount = 3, RepeatWindow = 8, Cooldown = 6 },
		Icon = "🎭",
		Description = "Repeat a sound and it repeats it back... from somewhere else.",
	},
	{
		Id = "Mimic", Name = "Mimic", Rarity = "Rare", Weight = 22,
		Behavior = "Mimic", Lifetime = 45, PhotoDistance = 60,
		Spawn = { Kinds = { "Dark" } }, TargetRadius = 2,
		Danger = 0.6, EMF = 3, Cold = true,
		Params = { TrickInterval = { 5, 9 }, LureRange = 60 },
		Icon = "👄",
		Description = "That camera click wasn't your teammate. Neither were those footsteps.",
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
