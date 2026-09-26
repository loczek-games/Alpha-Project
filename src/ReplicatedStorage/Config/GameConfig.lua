--[[
	GameConfig (ModuleScript)
	Location: ReplicatedStorage/Config/GameConfig

	Tuning values for rounds, spawning, photography, events, movement and
	noise, environmental masking, saving and admin/debug tools.
	(Every sound id lives in SoundConfig.)
]]

local GameConfig = {}

GameConfig.GameName = "CAUGHT ON CAMERA"
GameConfig.MallName = "DEAD MALL"

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
	WalkSpeed = 16,
	DownedTime = 15, -- a heavy anomaly attack knocks you down this long (teammates can revive)
	ReviveHoldTime = 2.5,
}

-- Movement modes. Running is fast but LOUD; sneaking is slow and nearly silent.
GameConfig.Movement = {
	WalkSpeed = 16,
	RunSpeed = 24,
	SneakSpeed = 8,
	StunTime = 1.6, -- frozen after a sound-hunting anomaly catches you
}

--[[
	NOISE: every player action can make world noise (0-1) that sound-sensitive
	anomalies may hear. Perceived loudness falls off with distance, is halved
	per wall in between, and is hidden by environmental noise (thunder, HVAC...).
]]
GameConfig.Noise = {
	Sneak = 0.03,
	Walk = 0.1,
	Run = 0.35,
	Land = 0.4,
	HeavyLand = 0.6,
	LandVelocity = 25, -- falling faster than this makes a landing noise
	HeavyLandVelocity = 55,
	SneakSpeedMax = 11, -- horizontal speed thresholds (studs/s)
	RunSpeedMin = 20,
	MovementInterval = 0.5,
	Voice = 0.2, -- chatting makes noise near you
	EventLifetime = 2.5, -- seconds a noise stays "audible"
	MaskingFactor = 0.6, -- environmental noise level x this is subtracted from player noise
	WallDamping = 0.5, -- perceived noise multiplier per wall between source and listener
	MaxWalls = 2,
	SurfaceMultiplier = { Metal = 1.3, Wood = 1.1, Water = 1.25, Glass = 1.15, Carpet = 0.6, Grass = 0.7, Tile = 1, Concrete = 1, Hospital = 1.1, School = 1.05 },
}

-- Environmental sounds that mask player noise, plus paranormal "phantom" sounds.
GameConfig.Environment = {
	Thunder = { Interval = { 40, 85 }, Delay = { 0.4, 1.8 }, Masking = 0.8, MaskDuration = 2.5 },
	HVAC = { Interval = { 55, 110 }, Masking = 0.45, Radius = 60, Duration = 6 },
	Phone = { Interval = { 80, 160 }, Rings = 4, RingGap = 2.2 },
	Phantom = {
		Interval = { 26, 55 },
		Weights = { Footsteps = 30, Shutter = 15, FlashlightClick = 12, DoorOpen = 15, EMFBeep = 10, BatteryPickup = 8, Knock = 10 },
	},
	SilenceRadius = 55, -- music/ambience fade out when a dangerous anomaly is this close
	SilenceDanger = 0.7,
}

GameConfig.Interaction = {
	BatterySpawns = 8, -- battery pickups placed around the mall each round
	OfficeBatteries = 2, -- extra batteries inside the locked security office
	RadioCooldown = 20,
	PhoneHintChance = 0.8,
}

GameConfig.Map = {
	RemoveBaseplate = true, -- the template Baseplate would z-fight with the maps
}

--[[
	Standard Roblox R15 animation set (owned by Roblox, usable in every
	experience). During an investigation every character uses exactly this
	set, so avatar animation packages cannot cause floating, sliding or
	broken equipment poses. The avatar itself is never modified.
]]
GameConfig.Animations = {
	Idle = { "rbxassetid://507766666", "rbxassetid://507766951" },
	Walk = "rbxassetid://507777826",
	Run = "rbxassetid://507767714",
	Jump = "rbxassetid://507765000",
	Fall = "rbxassetid://507767968",
	Climb = "rbxassetid://507765644",
	Swim = "rbxassetid://507784897",
	SwimIdle = "rbxassetid://507785072",
	Wave = "rbxassetid://507770239",
	Point = "rbxassetid://507770453",
}

-- Camera rules: third person in the lobby, locked first person on missions.
GameConfig.Camera = {
	LobbyMinZoom = 6,
	LobbyMaxZoom = 16,
	MissionFieldOfView = 72,
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
	-- Booleans are toggles; numbers are volumes (clamped to 0..1 on the server).
	ReducedFlashes = false,
	ScreenShake = true,
	BloodEffects = true, -- stylised blood overlays during jumpscares
	ReducedJumpscares = false, -- JUMPSCARE INTENSITY: FULL (false) / REDUCED (true)
	Hints = true,
	Ambience = true,
	MasterVolume = 1,
	MusicVolume = 0.7,
	AmbienceVolume = 0.8,
	EquipmentVolume = 1,
	VoiceVolume = 1,
	JumpscareVolume = 1,
}

return GameConfig
