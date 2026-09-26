--[[
	LobbyHQ (ModuleScript)
	Location: ServerScriptService/World/LobbyHQ

	The multiplayer headquarters of the PARANORMAL INVESTIGATION AGENCY.
	Built as one Model named "Lobby" around LobbyHQ.Origin:

	  BRIEFING HALL (spawn)   investigation board, case table, mission screens, CCTV TV
	  DEPLOY GARAGE (south)   agency vans + physical MISSION QUEUE ZONES ("DEAD MALL 0/6")
	  ARMORY (west)           equipment counter, camera upgrade bench, flashlight upgrade bench
	  ARCHIVE (east)          anomaly archive terminal, photo wall, filing cabinets
	  DARK ROOM (east)        red safelight room, drying lines = your best photos
	  LOUNGE (north)          friend party area: couches, party board, INVITE FRIENDS,
	                          supply terminal (Robux shop), settings terminal

	Station terminals carry a "Station" attribute (Shop/Upgrades/Flashlight/
	Archive/Store/Settings/Party/Invite); LobbyService adds the prompts.
	Queue zones are parts tagged "MissionZone" (attribute MapId).
]]

local World = script.Parent
local Build = require(World.Build)
local Rng = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Rng"))

local C, M = Build.C, Build.M
local V = Vector3.new
local DECO = { deco = true }
local FRONT = Enum.NormalId.Front

local LobbyHQ = {}

LobbyHQ.Origin = Vector3.new(-700, 0, 0)

local WALL = Build.rgb(58, 60, 62)
local TRIM = Build.rgb(34, 34, 38)
local FLOOR = Build.rgb(46, 44, 42)
local AGENCY_RED = Build.rgb(170, 30, 36)

local function terminal(f: Build.Frame, name: string, station: string, title: string, subtitle: string, color: Color3)
	local m = f:model(name)
	local model = m.Parent :: Model
	m:box("Stand", V(2.4, 3.4, 1.6), V(0, 1.7, 0), C.Charcoal, M.Metal)
	local screen = m:box("Screen", V(3.6, 2.4, 0.3), CFrame.new(0, 4.6, -0.2) * CFrame.Angles(math.rad(-12), 0, 0), C.Void, M.Glass, DECO)
	Build.layout(screen, FRONT, Build.rgb(8, 10, 12), {
		{ Text = title, Y = 0.1, H = 0.35, Color = color, Font = Enum.Font.SpecialElite },
		{ Text = subtitle, Y = 0.55, H = 0.2, Color = C.OffWhite, Font = Enum.Font.Code },
		{ Text = "[ E ]", Y = 0.78, H = 0.15, Color = C.LightGray, Font = Enum.Font.Code },
	}, true)
	Build.surfaceLight(screen, FRONT, color, 0.6, 10, 90)
	model.PrimaryPart = screen
	model:SetAttribute("Station", station)
	model:SetAttribute("Title", title)
	model:AddTag("LobbyStation")
	return m, screen
end

local function wallTrim(f: Build.Frame, x0: number, x1: number, z0: number, z1: number)
	-- baseboards + a dark wainscot band on the four inner faces of a room
	local t = 0.2
	f:box("Baseboard", V(x1 - x0, 0.8, t), V((x0 + x1) / 2, 0.4, z0 + 0.6), TRIM, M.WoodPlanks, DECO)
	f:box("Baseboard", V(x1 - x0, 0.8, t), V((x0 + x1) / 2, 0.4, z1 - 0.6), TRIM, M.WoodPlanks, DECO)
	f:box("Baseboard", V(t, 0.8, z1 - z0), V(x0 + 0.6, 0.4, (z0 + z1) / 2), TRIM, M.WoodPlanks, DECO)
	f:box("Baseboard", V(t, 0.8, z1 - z0), V(x1 - 0.6, 0.4, (z0 + z1) / 2), TRIM, M.WoodPlanks, DECO)
	f:box("Rail", V(x1 - x0, 0.3, t), V((x0 + x1) / 2, 4, z0 + 0.6), TRIM, M.WoodPlanks, DECO)
	f:box("Rail", V(x1 - x0, 0.3, t), V((x0 + x1) / 2, 4, z1 - 0.6), TRIM, M.WoodPlanks, DECO)
	f:box("Rail", V(t, 0.3, z1 - z0), V(x0 + 0.6, 4, (z0 + z1) / 2), TRIM, M.WoodPlanks, DECO)
	f:box("Rail", V(t, 0.3, z1 - z0), V(x1 - 0.6, 4, (z0 + z1) / 2), TRIM, M.WoodPlanks, DECO)
end

local function rainWindow(f: Build.Frame, width: number, height: number)
	-- a dark window with rain streaks outside (the HQ is on a stormy night)
	local m = f:model("Window")
	m:box("Frame", V(width + 0.8, height + 0.8, 0.5), V(0, 0, 0.1), TRIM, M.Metal, DECO)
	m:box("Glass", V(width, height, 0.15), V(0, 0, -0.1), Build.rgb(30, 40, 56), M.Glass, { t = 0.25, refl = 0.35 })
	m:box("Mullion", V(0.3, height, 0.3), V(0, 0, -0.1), TRIM, M.Metal, DECO)
	local outside = m:box("RainSheet", V(width, height, 0.05), V(0, 0, 0.6), Build.rgb(40, 50, 70), M.SmoothPlastic, { deco = true, tags = { "RainWindow" } })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Rain"
	emitter.Rate = 30
	emitter.Lifetime = NumberRange.new(0.4, 0.7)
	emitter.Speed = NumberRange.new(20, 30)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Size = NumberSequence.new(0.05)
	emitter.Transparency = NumberSequence.new(0.5)
	emitter.Color = ColorSequence.new(Build.rgb(170, 190, 220))
	emitter.LightEmission = 0.2
	emitter.Parent = outside
	return m
end

function LobbyHQ.Build(): Model
	local root = Instance.new("Model")
	root.Name = "Lobby"
	root:SetAttribute("Place", "Lobby")
	local rng = Rng.new(1999)
	local P = require(World.Props.Common)
	local R = require(World.Props.Retail)
	local U = require(World.Props.Utility)
	local _F = require(World.Props.Food)
	local S = Build.frame(root, CFrame.new(LobbyHQ.Origin))
	local struct = S:folder("Structure")
	local deco = S:folder("Decor")
	local stations = S:folder("Stations")
	local spawns = S:folder("Spawns")

	---------------------------------------------------------------------------
	-- shell: floors, walls, ceilings
	---------------------------------------------------------------------------
	local function floor(x0, x1, z0, z1, color, mat)
		local p = struct:slab("Floor", x0, x1, z0, z1, 0, 1, color, mat)
		p.CastShadow = false
	end
	floor(-30, 30, -25, 25, FLOOR, M.Concrete) -- briefing
	floor(-30, 30, -65, -25, Build.rgb(52, 52, 54), M.Concrete) -- garage
	floor(-70, -30, -25, 25, Build.rgb(60, 56, 50), M.WoodPlanks) -- armory
	floor(30, 70, -25, 25, Build.rgb(60, 56, 50), M.WoodPlanks) -- archive + dark room
	floor(-30, 30, 25, 55, Build.rgb(70, 40, 36), M.Fabric) -- lounge carpet

	local function wx(x0, x1, z, h, openings, color)
		struct:wallX("Wall", x0, x1, z, h, 1, color or WALL, M.Plaster, openings)
	end
	local function wz(z0, z1, x, h, openings, color)
		struct:wallZ("Wall", z0, z1, x, h, 1, color or WALL, M.Plaster, openings)
	end
	-- outer walls
	wx(-70, -30, -25, 16, nil)
	wx(30, 70, -25, 16, nil)
	wx(-30, 30, -65, 20, { { Center = 0, Width = 28, Top = 14 } }, Build.rgb(70, 70, 72)) -- roller door opening
	wz(-65, -25, -30, 20, nil)
	wz(-65, -25, 30, 20, nil)
	wz(-25, 25, -70, 16, { { Center = -10, Width = 12, Top = 11, Bottom = 4 }, { Center = 12, Width = 12, Top = 11, Bottom = 4 } })
	wz(-25, 25, 70, 16, nil)
	wx(-70, -30, 25, 16, nil)
	wx(30, 70, 25, 16, nil)
	wx(-30, 30, 55, 16, { { Center = -14, Width = 12, Top = 12, Bottom = 3 }, { Center = 14, Width = 12, Top = 12, Bottom = 3 } })
	wz(25, 55, -30, 16, nil)
	wz(25, 55, 30, 16, nil)
	-- inner walls with openings
	wz(-25, 25, -30, 16, { { Center = 0, Width = 14, Top = 10 } }) -- briefing <-> armory
	wz(-25, 25, 30, 16, { { Center = 12, Width = 10, Top = 10 }, { Center = -12, Width = 5, Top = 8.5 } }) -- briefing <-> archive / dark room
	wx(-30, 30, -25, 16, { { Center = 0, Width = 24, Top = 12 } }) -- briefing <-> garage
	wx(-30, 30, 25, 16, { { Center = 0, Width = 20, Top = 10 } }) -- briefing <-> lounge
	wx(30, 70, 0, 16, nil) -- archive | dark room divider
	-- ceilings
	struct:slab("Ceiling", -30, 30, -25, 25, 16, 1, Build.rgb(40, 40, 42), M.Concrete, nil, true)
	struct:slab("Ceiling", -30, 30, -65, -25, 20, 1, Build.rgb(40, 40, 42), M.Metal, nil, true)
	struct:slab("Ceiling", -70, -30, -25, 25, 16, 1, Build.rgb(40, 40, 42), M.Concrete, nil, true)
	struct:slab("Ceiling", 30, 70, -25, 25, 16, 1, Build.rgb(40, 40, 42), M.Concrete, nil, true)
	struct:slab("Ceiling", -30, 30, 25, 55, 16, 1, Build.rgb(40, 40, 42), M.Concrete, nil, true)
	for _, room in ipairs({ { -30, 30, -25, 25 }, { -70, -30, -25, 25 }, { 30, 70, 0, 25 }, { -30, 30, 25, 55 } }) do
		wallTrim(deco, room[1], room[2], room[3], room[4])
	end
	-- exterior: a wet street and the rain beyond the garage door / windows
	struct:slab("Street", -120, 120, -140, -65, 0, 1, C.Asphalt, M.Asphalt)
	struct:box("Blocker", V(30, 16, 1), V(0, 8, -66), C.Black, M.SmoothPlastic, { t = 1, shadow = false })

	---------------------------------------------------------------------------
	-- BRIEFING HALL
	---------------------------------------------------------------------------
	local b = deco
	-- agency logo on the floor
	b:cylY("Logo", 0.05, 18, V(0, 0.03, 0), Build.rgb(30, 30, 34), M.SmoothPlastic, { deco = true, query = false })
	local logo = b:box("LogoText", V(14, 0.05, 14), V(0, 0.06, 0), C.Black, M.SmoothPlastic, { deco = true, t = 1, query = false })
	Build.text(logo, Enum.NormalId.Top, "P.I.A.\nPARANORMAL\nINVESTIGATION AGENCY", { Color = Build.shade(AGENCY_RED, -0.1), Font = Enum.Font.SpecialElite })
	-- investigation board + clippings on the north wall
	U.InvestigationBoard(b:at(-12, 8.5, 24, 180), rng, 16, 9, "OAKRIDGE MALL - WHAT HAPPENED AT 3:07?")
	U.Corkboard(b:at(8, 8, 24.2, 180), rng, 8, 6, { "MALL CLOSED 1999", "3 GUARDS MISSING", "'IT MOVED'", "CAMERAS SHOW NOTHING" })
	local paper = b:box("Newspaper", V(4, 5, 0.1), CFrame.new(18, 8, 24.3) * Build.yaw(180) * CFrame.Angles(0, 0, math.rad(3)), C.Paper, M.SmoothPlastic, DECO)
	Build.layout(paper, FRONT, nil, {
		{ Text = "THE OAKRIDGE HERALD", Y = 0.03, H = 0.1, Color = C.Black, Font = Enum.Font.Garamond },
		{ Text = "MALL SHUTS DOWN AFTER NIGHT GUARDS VANISH", Y = 0.16, H = 0.2, Color = C.Black, Font = Enum.Font.GothamBlack },
		{ Bg = C.Gray, X = 0.08, W = 0.84, Y = 0.4, H = 0.3 },
		{ Text = "Police find security tapes 'blank after 3:07 AM'", Y = 0.75, H = 0.15, Color = C.Black, Font = Enum.Font.Garamond },
	})
	-- case table
	b:box("CaseTable", V(16, 0.4, 8), V(0, 3.2, 8), C.WoodDark, M.WoodPlanks)
	for _, x in ipairs({ -7, 7 }) do
		b:box("TableLeg", V(1.2, 3, 7), V(x, 1.5, 8), TRIM, M.Metal, DECO)
	end
	local map = b:box("MallMap", V(10, 0.05, 6), V(0, 3.43, 8), Build.rgb(20, 40, 70), M.SmoothPlastic, DECO)
	Build.layout(map, Enum.NormalId.Top, nil, {
		{ Text = "OAKRIDGE MALL - FLOOR PLAN", Y = 0.03, H = 0.12, Color = C.OffWhite, Font = Enum.Font.Code },
		{ Bg = Build.rgb(60, 110, 170), BgT = 0.3, X = 0.42, W = 0.16, Y = 0.18, H = 0.72 },
		{ Bg = Build.rgb(60, 110, 170), BgT = 0.3, X = 0.1, W = 0.3, Y = 0.3, H = 0.25 },
		{ Bg = Build.rgb(60, 110, 170), BgT = 0.3, X = 0.6, W = 0.3, Y = 0.3, H = 0.25 },
		{ Bg = Build.rgb(170, 60, 60), BgT = 0.2, X = 0.3, W = 0.4, Y = 0.18, H = 0.1 },
		{ Text = "X", X = 0.46, W = 0.08, Y = 0.5, H = 0.1, Color = C.NeonRed, Font = Enum.Font.PermanentMarker },
	})
	for _ = 1, 5 do
		b:box("CaseFile", V(1.6, 0.1, 2.2), CFrame.new(rng:Range(-7, 7), 3.45, rng:Range(5, 11)) * Build.yaw(rng:Range(0, 360)), Build.rgb(196, 170, 110), M.SmoothPlastic, DECO)
	end
	U.EquipmentCase(b:at(-5, 3.4, 10.5, 10), rng, true)
	R.Computer(b:at(5, 3.4, 11, 180), rng, true, "CASE #001\nSTATUS: ACTIVE")
	-- mission screens on the south wall (above the garage opening)
	local missions = {
		{ -21, "CASE #001", "DEAD MALL", "ACTIVE", C.NeonRed },
		{ 21, "CASE #002", "ST. AGNES HOSPITAL", "LOCKED", C.MidGray },
	}
	for _, mission in ipairs(missions) do
		local screen = b:box("MissionScreen", V(12, 7, 0.4), V(mission[1], 9, -24.3), C.Void, M.SmoothPlastic, DECO)
		Build.layout(screen, Enum.NormalId.Back, Build.rgb(10, 10, 12), {
			{ Text = mission[2], Y = 0.06, H = 0.14, Color = C.LightGray, Font = Enum.Font.Code },
			{ Text = mission[3], Y = 0.24, H = 0.26, Color = mission[5], Font = Enum.Font.SpecialElite },
			{ Text = "STATUS: " .. mission[4], Y = 0.56, H = 0.14, Color = C.OffWhite, Font = Enum.Font.Code },
			{ Text = if mission[4] == "ACTIVE" then "DEPLOY FROM THE GARAGE ↓" else "COMING SOON", Y = 0.76, H = 0.12, Color = C.LightGray, Font = Enum.Font.Code },
		}, true)
		Build.surfaceLight(screen, Enum.NormalId.Back, mission[5], 0.5, 12, 100)
	end
	-- CCTV TV on the west side
	local _, tv = R.TV(b:at(-29.3, 8, -8, -90), rng, 8, "Static")
	tv:SetAttribute("Mode", "CCTV")
	-- desks + chairs
	for i, spot in ipairs({ { -20, -14 }, { 20, -14 } }) do
		U.Desk(b:at(spot[1], 0, spot[2], if i == 1 then 90 else -90), rng, 7)
		R.Computer(b:at(spot[1] + (if i == 1 then -0.4 else 0.4), 3.4, spot[2], if i == 1 then 90 else -90), rng, rng:Chance(0.5), "SIGNAL LOST")
		U.OfficeChair(b:at(spot[1] + (if i == 1 then 3 else -3), 0, spot[2]), rng)
	end
	U.WaterCooler(b:at(-27, 0, 22), rng)
	P.Plant(b:at(27, 0, 22), rng, false, 1.3)
	P.FireExtinguisher(b:at(29.4, 0, -20, 90), rng)
	-- lights (one flickers)
	for x = -18, 18, 18 do
		for z = -12, 12, 24 do
			P.CeilingLight(b:at(x, 16, z), rng, "Lobby", 1.1, 26, if x == 18 and z == 12 then "Flicker" else "On", C.WarmLight)
		end
	end
	-- spawns
	for i = 0, 7 do
		local x = -14 + (i % 4) * 9.3
		local z = -8 - math.floor(i / 4) * 6
		local sp = Build.part(spawns.Parent, "LobbySpawn", V(6, 1, 6), CFrame.new(LobbyHQ.Origin + V(x, 0.5, z)), FLOOR, M.Concrete, { t = 1, collide = false, query = false })
		sp:SetAttribute("Spawn", true)
	end

	---------------------------------------------------------------------------
	-- DEPLOY GARAGE + mission queue zones
	---------------------------------------------------------------------------
	local g = deco
	-- roller door (closed) with rain light behind
	P.Shutter(g:at(0, 0, -65, 180), rng, 28, 14, 0)
	for x = -26, 26, 13 do
		P.CeilingLight(g:at(x, 20, -45), rng, "Lobby", 1, 28, "On", C.ColdLight)
	end
	-- van 1: DEAD MALL (active)
	local function van(x: number, label: string, color: Color3, active: boolean)
		local v = g:model("AgencyVan")
		U.Car(v:at(x, 0, -48, 0), rng, "Van", color)
		local decal = v:box("VanDecal", V(0.1, 2.4, 8), V(x - 3.06, 4.4, -48), color, M.SmoothPlastic, DECO)
		Build.text(decal, Enum.NormalId.Left, "P.I.A. · " .. label, { Color = C.OffWhite, Font = Enum.Font.SpecialElite })
		local decal2 = v:box("VanDecal", V(0.1, 2.4, 8), V(x + 3.06, 4.4, -48), color, M.SmoothPlastic, DECO)
		Build.text(decal2, Enum.NormalId.Right, "P.I.A. · " .. label, { Color = C.OffWhite, Font = Enum.Font.SpecialElite })
		v:box("BeaconLight", V(1, 0.5, 0.6), V(x, 7.9, -44), if active then C.NeonRed else C.MidGray, if active then M.Neon else M.SmoothPlastic, DECO)
		return v
	end
	van(-14, "DEAD MALL", Build.rgb(26, 28, 32), true)
	van(14, "HOSPITAL", Build.rgb(40, 44, 50), false)
	-- queue zones (walk in to queue)
	local function queueZone(x: number, mapId: string, title: string, active: boolean)
		local zoneSize = V(12, 10, 10)
		local center = V(x, 5, -33.5)
		local zonePart = Build.part(stations.Parent, "MissionZone", zoneSize, CFrame.new(LobbyHQ.Origin + center), C.Black, M.SmoothPlastic, { t = 1, collide = false, query = false, shadow = false })
		zonePart.CanTouch = false
		Build.attrs(zonePart, { MapId = mapId, Title = title, Active = active })
		zonePart:AddTag("MissionZone")
		local color = if active then AGENCY_RED else C.MidGray
		local floorMark = g:box("ZoneFloor", V(12, 0.06, 10), V(x, 0.04, -33.5), Build.shade(color, -0.55), M.SmoothPlastic, { deco = true, query = false })
		Build.text(floorMark, Enum.NormalId.Top, if active then "▲ STEP IN TO DEPLOY ▲" else "UNAVAILABLE", { Color = Build.shade(color, 0.3), Font = Enum.Font.GothamBlack })
		for _, edge in ipairs({ { V(12, 0.1, 0.3), V(x, 0.07, -28.6) }, { V(12, 0.1, 0.3), V(x, 0.07, -38.4) }, { V(0.3, 0.1, 10), V(x - 5.9, 0.07, -33.5) }, { V(0.3, 0.1, 10), V(x + 5.9, 0.07, -33.5) } }) do
			g:box("ZoneEdge", edge[1], edge[2], color, M.Neon, { deco = true, query = false, tags = { "MissionZoneEdge" }, attrs = { MapId = mapId } })
		end
		-- status board above the zone (LobbyService writes into it)
		local board = g:box("ZoneBoard", V(12, 4.6, 0.4), V(x, 14.5, -26.2), C.Void, M.SmoothPlastic, DECO)
		local gui = Build.layout(board, Enum.NormalId.Back, Build.rgb(8, 8, 10), {
			{ Text = "[ " .. title .. " ]", Y = 0.06, H = 0.3, Color = if active then C.NeonRed else C.MidGray, Font = Enum.Font.SpecialElite },
			{ Text = if active then "0 / 6 INVESTIGATORS" else "COMING SOON", Y = 0.42, H = 0.22, Color = C.OffWhite, Font = Enum.Font.Code },
			{ Text = if active then "STEP INSIDE THE MARKED AREA" else "", Y = 0.7, H = 0.18, Color = C.LightGray, Font = Enum.Font.Code },
		}, true)
		gui.Name = "QueueBoard"
		board:SetAttribute("MapId", mapId)
		board:AddTag("MissionBoard")
		Build.surfaceLight(board, Enum.NormalId.Back, color, 0.6, 14, 100)
	end
	queueZone(-14, "DeadMall", "DEAD MALL", true)
	queueZone(14, "Hospital", "ST. AGNES HOSPITAL", false)
	P.ExitSign(g:at(0, 13, -25.8), rng, "DEPLOY")
	for i = 0, 3 do
		U.Cone(g:at(-27 + i * 1.8, 0, -62), rng)
	end
	U.MetalShelf(g:at(27.5, 0, -45, -90), rng, 14, 9)
	U.EquipmentCase(g:at(-26, 0, -30, 90), rng, false)
	U.EquipmentCase(g:at(-26, 1.4, -30, 80), rng, false)
	local stripe = g:box("FloorStripe", V(0.6, 0.05, 36), V(0, 0.04, -45), C.Yellow, M.SmoothPlastic, { deco = true, query = false })
	stripe.Name = "FloorStripe"

	---------------------------------------------------------------------------
	-- ARMORY: equipment shop + upgrade benches
	---------------------------------------------------------------------------
	local a = deco
	P.Counter(a:at(-50, 0, -10, -90), rng, 16, Build.rgb(40, 36, 32), C.Charcoal)
	local banner = a:box("ArmorySign", V(0.3, 2.4, 18), V(-69.3, 12, -10), AGENCY_RED, M.SmoothPlastic, DECO)
	Build.text(banner, Enum.NormalId.Right, "ARMORY · EQUIPMENT", { Color = C.OffWhite, Font = Enum.Font.SpecialElite })
	for i = 0, 2 do
		local z = -20 + i * 8
		U.MetalShelf(a:at(-67, 0, z, -90), rng, 7, 9)
	end
	-- equipment displayed on the counter
	U.EquipmentCase(a:at(-50, 3.6, -14, -90), rng, true)
	U.EquipmentCase(a:at(-50, 3.6, -6, -90), rng, true)
	terminal(stations:at(-44, 0, -10, -90), "EquipmentTerminal", "Shop", "EQUIPMENT", "buy gear · cameras", C.NeonGreen)
	-- camera upgrade bench
	a:box("CameraBench", V(10, 3.2, 4), V(-58, 1.6, 20), C.WoodDark, M.WoodPlanks)
	for i = 0, 3 do
		a:box("CameraBody", V(1.4, 0.9, 0.9), V(-62 + i * 2.6, 3.65, 20), C.Black, M.SmoothPlastic, DECO)
		a:cylZ("Lens", 0.8, 0.7, V(-62 + i * 2.6, 3.65, 19.2), C.Charcoal, M.Metal, DECO)
	end
	a:box("LensRack", V(10, 4, 0.4), V(-58, 7, 24.2), C.Charcoal, M.Metal, DECO)
	for i = 0, 5 do
		a:cylZ("SpareLens", 0.6, rng:Range(0.8, 1.4), V(-62 + i * 1.6, 7, 23.8), C.Black, M.Metal, DECO)
	end
	terminal(stations:at(-50, 0, 18, 180), "CameraStation", "Upgrades", "CAMERA LAB", "upgrades · lenses", C.NeonCyan)
	-- flashlight bench
	a:box("FlashlightBench", V(10, 3.2, 4), V(-58, 1.6, 2.5), C.WoodDark, M.WoodPlanks)
	for i = 0, 4 do
		a:cyl("Flashlight", 1.8, 0.5, V(-62 + i * 2, 3.5, 2.5), C.DarkGray, M.Metal, DECO)
	end
	local glow = a:box("TestBeam", V(1, 1, 1), V(-53, 4, 2.5), C.WarmLight, M.Neon, DECO)
	Build.spot(glow, Enum.NormalId.Left, C.WarmLight, 1.5, 20, 30)
	terminal(stations:at(-50, 0, 8, 0), "FlashlightStation", "Flashlight", "FLASHLIGHT BENCH", "beam · battery", C.NeonYellow)
	P.CeilingLight(a:at(-50, 16, -10), rng, "Lobby", 1, 24, "On", C.WarmLight)
	P.CeilingLight(a:at(-50, 16, 12), rng, "Lobby", 1, 24, "On", C.WarmLight)
	rainWindow(a:at(-69.6, 7.5, -10, -90), 11, 6)
	rainWindow(a:at(-69.6, 7.5, 12, -90), 11, 6)

	---------------------------------------------------------------------------
	-- ARCHIVE (north-east) + DARK ROOM (south-east)
	---------------------------------------------------------------------------
	local ar = deco
	for i = 0, 5 do
		U.FilingCabinet(ar:at(34 + i * 2.2, 0, 23.4, 0), rng)
	end
	-- photo wall of past cases (one photo sometimes changes: tag ChangingPhoto)
	ar:box("PhotoWall", V(0.3, 9, 20), V(69.3, 8, 12.5), Build.rgb(40, 36, 32), M.Fabric, DECO)
	for row = 0, 2 do
		for col = 0, 5 do
			local photo = ar:box("Polaroid", V(0.1, 2.2, 2), CFrame.new(69.1, 5.5 + row * 2.8, 5 + col * 3.1) * CFrame.Angles(math.rad(rng:Range(-6, 6)), 0, 0), C.OffWhite, M.SmoothPlastic, DECO)
			local tint = rng:Pick({ Build.rgb(30, 34, 40), Build.rgb(46, 30, 30), Build.rgb(24, 36, 30) })
			local label = rng:Pick({ "3:07", "B1", "??", "AISLE 6", "MIRROR", "SEEN AGAIN", "CEILING" })
			Build.layout(photo, Enum.NormalId.Left, nil, {
				{ Bg = tint, X = 0.08, W = 0.84, Y = 0.08, H = 0.66 },
				{ Text = label, Y = 0.78, H = 0.16, Color = C.Black, Font = Enum.Font.PatrickHand },
			})
			if row == 1 and col == 3 then
				photo:AddTag("ChangingPhoto")
			end
		end
	end
	terminal(stations:at(50, 0, 14, 0), "ArchiveTerminal", "Archive", "ANOMALY ARCHIVE", "your collection", C.NeonOrange)
	U.Bookshelf(ar:at(34, 0, 12, -90), rng, 10)
	P.CeilingLight(ar:at(50, 16, 12), rng, "Lobby", 0.9, 22, "On", C.WarmLight)
	-- dark room (z -25..0): red safelight, drying lines (the DarkRoomService frames), enlarger
	local dr = S:folder("DarkRoom")
	local safelight = dr:box("Safelight", V(1.4, 0.8, 0.8), V(50, 14.5, -12), C.NeonRed, M.Neon, DECO)
	Build.point(safelight, Build.rgb(255, 40, 30), 1.4, 36)
	dr:box("DevelopingTable", V(12, 3.2, 4), V(50, 1.6, -22), C.Charcoal, M.Metal)
	for i = 0, 2 do
		dr:box("Tray", V(2.6, 0.4, 2), V(46 + i * 4, 3.4, -22), C.OffWhite, M.Plastic, DECO)
	end
	dr:box("Enlarger", V(2, 6, 2), V(62, 6.2, -22), C.Black, M.Metal, DECO)
	for i = 1, 10 do
		local x = 36 + ((i - 1) % 5) * 7
		local z = if i <= 5 then -6 else -14
		dr:box("Line", V(7, 0.05, 0.05), V(x, 10.6, z), C.OffWhite, M.Fabric, DECO)
		local frame = dr:box("Photo", V(3, 3.6, 0.1), V(x, 8.6, z), C.OffWhite, M.SmoothPlastic, { deco = true, tags = { "DarkRoomFrame" }, attrs = { Index = i } })
		frame.Name = "Photo" .. i
		dr:box("Clip", V(0.3, 0.4, 0.2), V(x, 10.4, z), C.Charcoal, M.Metal, DECO)
	end
	dr:box("Nameplate", V(0.2, 1.6, 8), V(69.3, 12, -12), C.Charcoal, M.SmoothPlastic, { deco = true, tags = { "DarkRoomNameplate" } })
	dr:box("DarkRoomDoor", V(1, 8.5, 5), V(30, 4.25, -12), C.DarkRed, M.Wood, { tags = { "DarkRoomEntrance" } })
	local sign = dr:box("DarkRoomSign", V(0.2, 1.4, 5), V(29.4, 10, -12), C.Void, M.SmoothPlastic, DECO)
	Build.text(sign, Enum.NormalId.Left, "● DARK ROOM", { Color = C.NeonRed, Font = Enum.Font.SpecialElite, Glow = true })
	dr:box("DarkRoomExit", V(1, 8.5, 5), V(31.2, 4.25, -12), C.DarkRed, M.Wood, { tags = { "DarkRoomExit" } })

	---------------------------------------------------------------------------
	-- LOUNGE: friend party area, supply terminal, settings
	---------------------------------------------------------------------------
	local l = deco
	U.Couch(l:at(-12, 0, 44, 180), rng, 10, Build.rgb(70, 30, 30))
	U.Couch(l:at(12, 0, 44, 180), rng, 10, Build.rgb(70, 30, 30))
	U.Couch(l:at(-24, 0, 36, -90), rng, 8, Build.rgb(70, 30, 30))
	U.CoffeeTable(l:at(0, 0, 38), rng)
	local _, loungeTv = R.TV(l:at(0, 8, 26, 180), rng, 10, "Logo")
	loungeTv:SetAttribute("Mode", "CCTV")
	local invite = l:box("InviteSign", V(18, 2.6, 0.4), V(0, 13, 54.3), C.Void, M.SmoothPlastic, DECO)
	Build.text(invite, FRONT, "+ INVITE FRIENDS +", { Color = C.NeonGreen, Font = Enum.Font.GothamBlack, Glow = true })
	Build.surfaceLight(invite, FRONT, C.NeonGreen, 0.8, 14, 100)
	terminal(stations:at(-6, 0, 51, 0), "PartyTerminal", "Party", "PARTY", "ready · leader", C.NeonGreen)
	terminal(stations:at(6, 0, 51, 0), "InviteTerminal", "Invite", "INVITE FRIENDS", "bring your crew", C.NeonGreen)
	terminal(stations:at(26, 0, 30, -90), "SupplyTerminal", "Store", "SUPPLY DROP", "passes · packs", C.NeonYellow)
	terminal(stations:at(-26, 0, 50, 90), "SettingsTerminal", "Settings", "SETTINGS", "audio · effects", C.LightGray)
	U.VendingMachine(l:at(27, 0, 46, -90), rng, true)
	P.Plant(l:at(-27, 0, 28), rng, false, 1.2)
	rainWindow(l:at(-14, 7.5, 54.6, 180), 11, 8)
	rainWindow(l:at(14, 7.5, 54.6, 180), 11, 8)
	for _, x in ipairs({ -14, 14 }) do
		P.CeilingLight(l:at(x, 16, 40), rng, "Lobby", 0.8, 22, "On", C.WarmLight)
	end
	-- the apparition behind the frosted window (client shows it very rarely)
	l:box("Apparition", V(2.2, 6.5, 0.6), V(14, 6.2, 57.5), C.Black, M.SmoothPlastic, { deco = true, t = 1, tags = { "LobbyApparition" } })

	return root
end

return LobbyHQ
