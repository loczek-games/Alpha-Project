--[[
	MapConfig (ModuleScript)
	Location: ReplicatedStorage/Config/MapConfig

	Maps (investigation locations), their case files, zones, and how
	investigators get there.

	PLACES
	  Leave both ids at 0 to run everything in ONE place (lobby HQ + map in the
	  same server; one investigation at a time per server). For the recommended
	  setup publish this same place file twice (a Lobby place and a Gameplay
	  place in the same experience) and paste both ids below: the lobby then
	  sends each mission team to its own reserved gameplay server.
]]

local MapConfig = {}

MapConfig.Places = {
	LobbyPlaceId = 0, -- PLACEHOLDER: place id of the lobby place
	GameplayPlaceId = 0, -- PLACEHOLDER: place id of the gameplay place
}

MapConfig.Queue = {
	Countdown = 15, -- seconds after the first investigator steps in
	AllReadyCountdown = 5, -- shortened when every queued player is ready
	StudioCountdown = 8,
	CheckInterval = 0.25,
	TeleportRetries = 3,
}

MapConfig.Mission = {
	IntroTime = 4.5, -- black screen: case file + "INVESTIGATION STARTING"
	RoundTime = 480,
	ResultsTime = 12,
	ArrivalTimeout = 25, -- gameplay server: wait this long for the whole team
}

-- Zone ids -> display names + reverb (bounds come from the map's Zones model)
MapConfig.ZoneNames = {
	Entrance = "MAIN ENTRANCE",
	GrandHall = "GRAND HALL",
	Supermarket = "FRESHWAY SUPERMARKET",
	Electronics = "VOLTZONE ELECTRONICS",
	Clothing = "NOIR & CO.",
	Restrooms = "RESTROOMS",
	Cinema = "STARLIGHT CINEMA",
	Theaters = "SCREENING ROOMS",
	Arcade = "PIXEL PALACE ARCADE",
	ToyStore = "TOY TOWN",
	BookNook = "THE BOOK NOOK",
	FoodCourt = "FOOD COURT",
	ServiceHalls = "EMPLOYEE HALLWAYS",
	BackOfHouse = "BACK OF HOUSE",
	SecurityRoom = "SECURITY ROOM",
	ParkingGarage = "PARKING GARAGE B1",
	Lobby = "P.I.A. HEADQUARTERS",
	DarkRoom = "DARK ROOM",
}

MapConfig.Maps = {
	DeadMall = {
		Id = "DeadMall",
		Name = "DEAD MALL",
		Case = "CASE #001",
		Location = "OAKRIDGE MALL",
		Status = "ABANDONED",
		LastActivity = "UNKNOWN",
		Danger = "HIGH",
		MaxPlayers = 6,
		Available = true,
		ModelName = "ActiveMap",
		Tips = {
			"If you hear crawling above you, don't look up.",
			"Mannequins don't move. Not while you're watching.",
			"Silence is worse than footsteps.",
			"Stay together. It picks the one who wanders off.",
			"If the TVs turn on by themselves, check behind you.",
			"Zoom in on dark corners. Something might be zooming back.",
			"Running is loud. Some things only hunt by sound.",
		},
		-- Zone bounds used by the builder (X, Z ranges; H = ceiling height)
		Zones = {
			{ Id = "Entrance", X = { -32, 32 }, Z = { -176, -130 }, H = 18 },
			{ Id = "GrandHall", X = { -32, 32 }, Z = { -130, 150 }, H = 36 },
			{ Id = "Supermarket", X = { -150, -32 }, Z = { -130, -30 }, H = 18 },
			{ Id = "Electronics", X = { -100, -32 }, Z = { -26, 40 }, H = 16 },
			{ Id = "Clothing", X = { -100, -32 }, Z = { 44, 118 }, H = 16 },
			{ Id = "Restrooms", X = { -100, -32 }, Z = { 122, 150 }, H = 12 },
			{ Id = "Cinema", X = { 32, 100 }, Z = { -130, -40 }, H = 20 },
			{ Id = "Theaters", X = { 112, 190 }, Z = { -130, -34 }, H = 24 },
			{ Id = "Arcade", X = { 32, 100 }, Z = { -36, 40 }, H = 16 },
			{ Id = "ToyStore", X = { 32, 100 }, Z = { 44, 118 }, H = 16 },
			{ Id = "BookNook", X = { 32, 100 }, Z = { 122, 150 }, H = 12 },
			{ Id = "FoodCourt", X = { -100, 100 }, Z = { 150, 244 }, H = 30 },
			{ Id = "ServiceHalls", X = { -112, 112 }, Z = { 244, 254 }, H = 12, Extra = { { X = { -112, -100 }, Z = { -30, 254 } }, { X = { 100, 112 }, Z = { -130, 254 } } } },
			{ Id = "BackOfHouse", X = { 112, 150 }, Z = { -30, 110 }, H = 12 },
			{ Id = "SecurityRoom", X = { 112, 150 }, Z = { 110, 150 }, H = 12 },
			{ Id = "ParkingGarage", X = { 150, 270 }, Z = { -20, 150 }, H = 14 },
		},
		Acoustics = {
			Entrance = "Hallway",
			GrandHall = "Hangar",
			Supermarket = "Arena",
			Electronics = "Room",
			Clothing = "Room",
			Restrooms = "Bathroom",
			Cinema = "Auditorium",
			Theaters = "Auditorium",
			Arcade = "CarpettedHallway",
			ToyStore = "Room",
			BookNook = "PaddedCell",
			FoodCourt = "ConcertHall",
			ServiceHalls = "StoneCorridor",
			BackOfHouse = "StoneRoom",
			SecurityRoom = "Room",
			ParkingGarage = "ParkingLot",
		},
	},
	Hospital = {
		Id = "Hospital",
		Name = "ST. AGNES HOSPITAL",
		Case = "CASE #002",
		Location = "ST. AGNES HOSPITAL",
		Status = "CONDEMNED",
		LastActivity = "3 DAYS AGO",
		Danger = "EXTREME",
		MaxPlayers = 6,
		Available = false, -- coming soon (a queue zone exists in the lobby, locked)
		ModelName = "HospitalMap",
		Tips = {},
		Zones = {},
		Acoustics = {},
	},
}

function MapConfig.Get(mapId: string)
	return MapConfig.Maps[mapId]
end

function MapConfig.GetZoneName(zoneId: string?): string
	if not zoneId then
		return ""
	end
	return MapConfig.ZoneNames[zoneId] or string.upper(zoneId)
end

-- "Combined" (one place), "Lobby" or "Gameplay"
function MapConfig.GetPlaceRole(placeId: number): string
	local places = MapConfig.Places
	if places.GameplayPlaceId ~= 0 and placeId == places.GameplayPlaceId then
		return "Gameplay"
	end
	if places.LobbyPlaceId ~= 0 and placeId == places.LobbyPlaceId and places.GameplayPlaceId ~= 0 then
		return "Lobby"
	end
	return "Combined"
end

return MapConfig
