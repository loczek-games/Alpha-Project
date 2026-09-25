--[[
	GameConfig (ModuleScript)
	Location: ReplicatedStorage/Config/GameConfig

	Tuning values for rounds, spawning, photography, events, saving,
	sounds and admin/debug tools.
]]

local GameConfig = {}

GameConfig.GameName = "CAUGHT ON CAMERA"
GameConfig.MallName = "DEAD MALL"

GameConfig.Round = {
	MinPlayers = 1,
	IntermissionTime = 25,
	StudioIntermissionTime = 10, -- faster iteration while testing in Studio
	RoundTime = 480, -- 8 minutes
	ResultsTime = 12,
}

GameConfig.Spawning = {
	FirstSpawnDelay = 3, -- first anomaly appears within seconds so new players "get it"
	InitialBurst = 2,
	IntervalMin = 8,
	IntervalMax = 13,
	BaseMaxConcurrent = 4,
	PlayersPerExtraSlot = 3,
	HardMaxConcurrent = 9,
	MinDistanceFromPlayers = 12,
	PickAttempts = 4,
	DespawnFadeTime = 0.6,
	PhotoGraceAfterDespawn = 0.5, -- latency tolerance for photos taken just as it vanished
	UpdateRate = 10, -- behaviour Update() calls per second
}

GameConfig.Photo = {
	MaxAngleDeg = 22, -- how far from the centre of the view an anomaly may be
	PerfectAngleDeg = 4,
	IdealDistanceFraction = 0.4, -- closer than 40% of max range = perfect distance
	MaxCameraDistanceFromHead = 26,
	TimingBonusWindow = 0.35, -- photographed in the first 35% of its life = bonus
	MaxShotsPerAnomaly = 3, -- per player per anomaly instance
	FirstPhotographerBonus = 0.25,
	GroupBonusPerPlayer = 0.1,
	GroupBonusMax = 0.5,
	GroupPhotoMaxDistance = 60,
	GroupPhotoMaxAngleDeg = 32,
	NewDiscoveryMultiplier = 2,
	StarMultipliers = { 0.6, 0.8, 1, 1.25, 1.5 },
	CooldownTolerance = 0.75, -- server accepts shots at 75% of the camera cooldown (latency)
	RateLimitBurst = 6, -- max requests per window
	RateLimitWindow = 4,
	DecoyCheckDistance = 70,
}

GameConfig.Events = {
	RandomEventsEnabled = true,
	FirstEventDelay = { 75, 130 },
	EventInterval = { 95, 150 },
	MaxRandomEventsPerRound = 3,
	MinTimeLeftToStart = 30,
	RandomWeights = {
		Surge = 35,
		Blackout = 25,
		FalseAlarm = 25,
		RareAnomaly = 15,
	},
	Definitions = {
		Surge = {
			Name = "PARANORMAL SURGE",
			Icon = "⚠️",
			Banner = "⚠️ PARANORMAL ACTIVITY IS RISING",
			Duration = 120,
			Color = Color3.fromRGB(170, 90, 255),
			SpawnIntervalMultiplier = 0.45,
			ExtraConcurrent = 3,
			BurstSpawns = 2,
		},
		Blackout = {
			Name = "BLACKOUT",
			Icon = "🔦",
			Banner = "🔦 BLACKOUT - THE LIGHTS ARE OUT",
			Duration = 75,
			Color = Color3.fromRGB(90, 110, 160),
			SpawnIntervalMultiplier = 0.8,
			ExtraConcurrent = 1,
			BurstSpawns = 1,
		},
		FalseAlarm = {
			Name = "FALSE ALARM?",
			Icon = "🔔",
			Banner = "🔔 THINGS ARE CHANGING... ONLY ONE IS REAL",
			Duration = 45,
			Color = Color3.fromRGB(255, 170, 60),
			DecoyCount = 4,
		},
		RareAnomaly = {
			Name = "SOMETHING RARE",
			Icon = "❗",
			Banner = "⚠️ SOMETHING RARE IS HERE.",
			Duration = 40,
			Color = Color3.fromRGB(255, 70, 70),
			MinRarity = "Rare",
			MaxRarity = "Mythic",
			LifetimeMultiplier = 1.6,
		},
	},
}

GameConfig.Data = {
	StoreName = "CaughtOnCamera_PlayerData_v1",
	KeyPrefix = "Player_",
	AutosaveInterval = 120,
	LoadRetries = 5,
	SaveRetries = 3,
	RetryDelay = 2,
	SessionLockTimeout = 300,
	SessionLockRetries = 6,
	SessionLockRetryDelay = 4,
	MaxStoredReceipts = 100,
	PhotoRollBaseCapacity = 12,
	PhotoRollPassCapacity = 60,
	DarkRoomBaseFrames = 5,
	DarkRoomPassFrames = 10,
}

GameConfig.Player = {
	WalkSpeed = 18,
	MaxZoomDistance = 20,
}

GameConfig.NPC = {
	Count = 6,
	WalkSpeedMin = 5,
	WalkSpeedMax = 7.5,
	PauseMin = 1,
	PauseMax = 4,
	BodyColors = {
		Color3.fromRGB(210, 200, 190),
		Color3.fromRGB(180, 170, 165),
		Color3.fromRGB(150, 140, 135),
		Color3.fromRGB(200, 185, 160),
	},
	ClothingColors = {
		Color3.fromRGB(70, 80, 110),
		Color3.fromRGB(110, 60, 60),
		Color3.fromRGB(60, 90, 70),
		Color3.fromRGB(95, 90, 80),
		Color3.fromRGB(120, 110, 70),
	},
}

GameConfig.Zones = {
	MainHall = "MAIN HALL",
	FoodCourt = "FOOD COURT",
	ToyStore = "TOY STORE",
	Arcade = "ARCADE",
	Cinema = "CINEMA",
	Bathrooms = "BATHROOMS",
	ParkingGarage = "PARKING GARAGE",
	StorageHallway = "STORAGE HALLWAY",
}

GameConfig.Map = {
	AutoBuild = true, -- build the Dead Mall + Lobby from code when the folders are empty
	RemoveBaseplate = true, -- the default template Baseplate z-fights with the mall floor
	RemoveStraySpawns = true, -- SpawnLocations outside Workspace.Lobby are removed
}

-- Default Roblox R15 animations (owned by Roblox, usable in every experience).
GameConfig.Animations = {
	Walk = "rbxassetid://507777826",
	Idle = "rbxassetid://507766666",
	Wave = "rbxassetid://507770239",
	Point = "rbxassetid://507770453",
}

--[[
	Sounds. Built-in rbxasset:// sounds work in every place. Replace any of these
	with your own uploaded audio ids (rbxassetid://...) for extra polish.
	An empty string disables that sound.
]]
GameConfig.Sounds = {
	Shutter = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.9, Speed = 0.85 },
	Capture = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, Speed = 1.25 },
	NewDiscovery = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.7, Speed = 1.6 },
	Fail = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.35, Speed = 0.5 },
	Button = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.35, Speed = 1.3 },
	Announce = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Speed = 0.7 },
	Reveal = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.9, Speed = 0.35 },
	Whisper = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.25, Speed = 0.3 },
	AnomalySting = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.45, Speed = 0.25 },
	Tick = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.4, Speed = 1.8 },
	Slam = { Id = "rbxasset://sounds/clickfast.wav", Volume = 1, Speed = 0.3 },
	Heartbeat = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.5, Speed = 0.4 },
	Ambience = { Id = "", Volume = 0.25, Speed = 1 },
}

-- Badge ids from the Creator Dashboard. 0 = disabled.
GameConfig.Badges = {
	PhotographedBack = 0,
	ImpossibleFound = 0,
	FirstPhoto = 0,
}

GameConfig.Admin = {
	AllowEveryoneInStudio = true, -- chat commands work for everyone in Studio play tests
	AllowGameCreator = true,
	UserIds = {}, -- extra admin user ids for live servers
}

GameConfig.Debug = {
	StudioGrantAllPasses = false, -- pretend every game pass is owned while in Studio
}

GameConfig.Settings = {
	-- Allowed player settings and their defaults. Only these keys are accepted from clients.
	ReducedFlashes = false,
	ScreenShake = true,
	Hints = true,
	Ambience = true,
}

return GameConfig
