--[[
	Mall.BackOfHouse (ModuleScript)
	Location: ServerScriptService/World/Mall/BackOfHouse

	EMPLOYEE HALLWAYS (west, north and east service corridors that loop
	behind the stores) and the back rooms: projection room, garage link,
	maintenance, locker room, electrical room (main breaker) and the locked
	SECURITY ROOM (CCTV wall, security desk + PC, radio, key board, mall
	blueprint).
]]

local World = script.Parent.Parent
local Build = require(World.Build)

local C, M = Build.C, Build.M
local V = Vector3.new
local DECO = { deco = true }
local FRONT = Enum.NormalId.Front

local BackOfHouse = {}

local function corridorDressing(ctx, f: Build.Frame, axis: string, fixed: number, from: number, to: number, zone: string)
	local rng = ctx.Rng
	local P, _U = ctx.Props.Common, ctx.Props.Utility
	local function at(t: number, y: number, side: number, yaw: number?)
		if axis == "Z" then
			return f:at(fixed + side, y, t, yaw)
		end
		return f:at(t, y, fixed + side, yaw)
	end
	local step = 14
	local t = from + 6
	while t < to - 4 do
		-- fluorescent tube (many dead / flickering)
		local state = if rng:Chance(0.45) then "Dead" elseif rng:Chance(0.35) then "Flicker" else "On"
		P.CeilingLight(at(t, 12, 0, if axis == "Z" then 90 else 0), rng, zone, 0.7, 16, state, C.SickLight)
		-- clutter on alternating sides
		local roll = rng:Next()
		local side = if rng:Chance(0.5) then -4.2 else 4.2
		if roll < 0.18 then
			P.BoxStack(at(t + 3, 0, side), rng, rng:Int(1, 3))
		elseif roll < 0.3 then
			P.TrashBag(at(t + 2, 0, side), rng)
		elseif roll < 0.38 then
			P.Mop(at(t + 2, 0, side * 0.9), rng)
		elseif roll < 0.46 then
			P.Pallet(at(t + 2, 0, side * 0.7, 90), rng)
		elseif roll < 0.52 then
			P.WetFloorSign(at(t + 1, 0, side * 0.6), rng, rng:Chance(0.4))
		end
		if rng:Chance(0.2) then
			P.FireExtinguisher(at(t + 5, 0, if axis == "Z" then 5.5 else -5.5, if axis == "Z" then 90 else 180), rng)
		end
		if rng:Chance(0.25) then
			P.Puddle(at(t + 4, 0, rng:Range(-2, 2)), rng, rng:Range(3, 6))
		end
		t += step
	end
	-- a long pipe run and cables along the ceiling
	local length = to - from
	local mid = (from + to) / 2
	if axis == "Z" then
		P.PipeRun(f:rel(CFrame.new(fixed + 3.5, 11.6, mid) * CFrame.Angles(0, math.rad(90), 0)), rng, length - 2, 2)
		P.CableBundle(f:rel(CFrame.new(fixed - 4, 11.2, mid) * CFrame.Angles(0, math.rad(90), 0)), rng, math.min(length - 2, 60), 1)
	else
		P.PipeRun(f:at(mid, 11.6, fixed + 3.5), rng, length - 2, 2)
		P.CableBundle(f:at(mid, 11.2, fixed - 4), rng, math.min(length - 2, 60), 1)
	end
end

function BackOfHouse.Build(ctx)
	local rng = ctx.Rng
	local P, _R, U, F, I = ctx.Props.Common, ctx.Props.Retail, ctx.Props.Utility, ctx.Props.Food, ctx.I
	local f = ctx:area("ServiceHalls")
	local zone = "ServiceHalls"

	-- service corridors
	corridorDressing(ctx, f, "Z", -106, -30, 254, zone)
	corridorDressing(ctx, f, "X", 249, -100, 100, zone)
	corridorDressing(ctx, f, "Z", 106, -38, 254, zone)
	ctx:ceilingNodes(zone, -111, -101, -28, 252, 12, 14)
	ctx:ceilingNodes(zone, -98, 98, 245, 253, 12, 14)
	ctx:ceilingNodes(zone, 101, 111, -36, 252, 12, 14)
	for _, sign in ipairs({ { -106, 11, -26, "← SUPERMARKET STOCK" }, { -106, 11, 240, "LOADING DOCK CLOSED" }, { 106, 11, 244, "SECURITY →" }, { 106, 11, -30, "EMPLOYEES ONLY" } }) do
		local board = f:box("CorridorSign", V(6, 1.2, 0.2), V(sign[1], sign[2], sign[3]), C.Navy, M.SmoothPlastic, DECO)
		Build.text(board, FRONT, sign[4], { Color = C.OffWhite, Font = Enum.Font.GothamBold })
		Build.text(board, Enum.NormalId.Back, sign[4], { Color = C.OffWhite, Font = Enum.Font.GothamBold })
	end
	-- time clock + notice board + vending alcove on the east corridor
	local clock = f:box("TimeClock", V(0.8, 2.4, 1.8), V(111.2, 5, 60), C.OffWhite, M.Metal, DECO)
	Build.text(clock, Enum.NormalId.Left, "03:07", { Color = C.NeonRed, Font = Enum.Font.Code, Glow = true })
	U.Corkboard(f:at(111.4, 6.5, 44, 90), rng, 6, 4, { "SHIFT SWAP?", "DON'T USE ELEVATOR", "CAMS 7-9 DOWN", "WHO LEFT THE LIGHTS ON" })
	U.VendingMachine(f:at(-110, 0, 180, -90), rng, true)
	U.WaterCooler(f:at(-110.5, 0, 172, -90), rng)
	P.Graffiti(f:at(-111.4, 6, 90, -90), rng, "IT CRAWLS", 6, C.NeonRed)
	P.Graffiti(f:at(111.4, 5, 200, 90), rng, "RUN", 4, C.OffWhite)
	for _, z in ipairs({ -10, 60, 130, 220 }) do
		ctx:floorNode("Corridor", zone, V(-106, 0, z), V(0, 0, 1))
		ctx:floorNode("Corridor", zone, V(106, 0, z + 10), V(0, 0, -1))
	end
	ctx:floorNode("Corridor", zone, V(-40, 0, 249), V(1, 0, 0))
	ctx:floorNode("Corridor", zone, V(50, 0, 249), V(-1, 0, 0))
	ctx:floorNode("RunLane", zone, V(106, 0, 250), V(0, 0, -1), { Length = 280 })
	ctx:floorNode("RunLane", zone, V(-106, 0, -26), V(0, 0, 1), { Length = 270 })
	for _, spot in ipairs({ V(-108, 0.6, 30), V(-104, 0.6, 210), V(0, 0.6, 251), V(108, 0.6, 150) }) do
		ctx:pickup(spot)
	end

	local b = ctx:area("BackRooms")
	-- room ceilings
	for _, room in ipairs({ { -30, -2 }, { 2, 18 }, { 22, 50 }, { 54, 82 }, { 86, 108 }, { 112, 150 } }) do
		b:slab("RoomCeiling", 112, 150, room[1], room[2], 12, 1, C.DarkGray, M.Concrete, nil, true)
		ctx:ceilingNodes(if room[1] == 112 then "SecurityRoom" else "BackOfHouse", 113, 149, room[1] + 1, room[2] - 1, 12, 12)
	end

	-- projection room (z -30..-2)
	F.Projector(b:at(122, 0, -24), rng)
	F.Projector(b:at(134, 0, -24), rng)
	for i = 0, 3 do
		F.FilmCans(b:at(140 + (i % 2) * 3, 0, -8 - math.floor(i / 2) * 3), rng)
	end
	U.MetalShelf(b:at(148, 0, -16, 90), rng, 10, 8)
	U.OfficeChair(b:at(128, 0, -18), rng)
	P.Poster(b:at(113.6, 6, -8, -90), rng, "SHOWTIMES", "7:00 · 9:30 · 3:07", C.DarkRed)
	P.CeilingLight(b:at(130, 12, -16), rng, "BackOfHouse", 0.6, 16, "Flicker", C.WarmLight)
	I.DoorInOpening(ctx.Interact:at(112, 0, -16, 90), 5, 8.5, "Metal", C.Steel, M.Metal, "BackOfHouse", false, false, "PROJECTION")
	ctx:floorNode("Dark", "BackOfHouse", V(146, 0, -26), V(-1, 0, 0))

	-- garage link (z 2..18) + door into the garage
	P.CeilingLight(b:at(130, 12, 10, 90), rng, "BackOfHouse", 0.6, 16, "Flicker", C.SickLight)
	P.ExitSign(b:at(149.3, 10, 10, 90), rng, "PARKING")
	I.DoorInOpening(ctx.Interact:at(150, 0, 10, 90), 6, 9, "Metal", C.Steel, M.Metal, "BackOfHouse", false, true, "PARKING B1")
	I.DoorInOpening(ctx.Interact:at(112, 0, 10, 90), 6, 9, "Metal", C.Steel, M.Metal, "BackOfHouse", false, true)

	-- maintenance (z 22..50)
	U.Generator(b:at(136, 0, 40), rng)
	b:box("Workbench", V(10, 3.2, 3), V(126, 1.6, 23.8), C.WoodDark, M.WoodPlanks)
	for _ = 1, 6 do
		b:box("Tool", V(rng:Range(0.3, 1.2), 0.25, rng:Range(0.3, 1.4)), CFrame.new(rng:Range(122, 130), 3.35, rng:Range(23, 25)) * Build.yaw(rng:Range(0, 180)), rng:Pick({ C.Red, C.Yellow, C.Steel, C.Black }), M.Metal, DECO)
	end
	b:box("Pegboard", V(10, 5, 0.2), V(126, 6.5, 22.4), C.Tan, M.WoodPlanks, DECO)
	P.Ladder(b:at(146, 0, 26, -90), rng, 9)
	U.MetalShelf(b:at(148, 0, 36, 90), rng, 10, 9)
	b:cylY("WaterHeater", 7, 3.4, V(116, 3.5, 46), C.OffWhite, M.Metal)
	P.Mop(b:at(120, 0, 30), rng)
	P.EmergencyLight(b:at(149.4, 9, 44, 90), rng, true)
	I.DoorInOpening(ctx.Interact:at(112, 0, 36, 90), 5, 8.5, "Metal", C.Steel, M.Metal, "BackOfHouse", false, false, "MAINTENANCE")
	ctx:floorNode("Dark", "BackOfHouse", V(118, 0, 26), V(1, 0, 0))

	-- locker room (z 54..82): interactive lockers + decorative rows
	for i = 0, 3 do
		I.Locker(ctx.Interact:at(116 + i * 2.7, 0, 80.5, 0), "BackOfHouse", C.Teal)
	end
	for i = 0, 3 do
		I.Locker(ctx.Interact:at(116 + i * 2.7, 0, 55.5, 180), "BackOfHouse", C.Teal)
	end
	U.Lockers(b:at(140, 0, 80.8, 0), rng, 4, C.Teal)
	b:box("Bench", V(10, 0.4, 1.6), V(122, 1.8, 68), C.WoodLight, M.Wood)
	for _, x in ipairs({ 118, 126 }) do
		b:box("BenchLeg", V(0.4, 1.8, 1.4), V(x, 0.9, 68), C.Charcoal, M.Metal, DECO)
	end
	U.Corkboard(b:at(149.4, 6, 64, 90), rng, 7, 4, { "LOCKER 12 SMELLS", "NIGHT SHIFT: 2 PPL MIN", "NOBODY GOES TO B1 ALONE" })
	b:box("Mirror", V(0.2, 4, 3), V(149.3, 5.5, 74), C.LightGray, M.Glass, { deco = true, refl = 0.5, tags = { "MallMirror" } })
	P.CeilingLight(b:at(130, 12, 68), rng, "BackOfHouse", 0.7, 18, "On", C.SickLight)
	I.DoorInOpening(ctx.Interact:at(112, 0, 68, 90), 5, 8.5, "Metal", C.Steel, M.Metal, "BackOfHouse", false, false, "STAFF LOCKERS")
	ctx:floorNode("Locker", "BackOfHouse", V(125, 0, 76), V(0, 0, -1))

	-- electrical room (z 86..108): panels + main breaker
	for i = 0, 2 do
		U.ElectricalPanel(b:at(126 + i * 6, 0, 107, 0), rng)
	end
	I.Breaker(b:at(148.9, 0, 97, 90))
	U.Generator(b:at(122, 0, 92, 90), rng)
	local hazard = b:box("Hazard", V(0.2, 2, 4), V(149.3, 9, 90), C.Yellow, M.SmoothPlastic, DECO)
	Build.text(hazard, Enum.NormalId.Left, "⚡ AUTHORIZED\nPERSONNEL ONLY", { Color = C.Black, Font = Enum.Font.GothamBlack })
	local bulb = b:box("CageLamp", V(0.8, 0.8, 0.8), V(136, 11.3, 97), C.WarmLight, M.Neon, { deco = true, tags = { "FlickerLight" } })
	Build.point(bulb, C.WarmLight, 0.7, 16):SetAttribute("BaseBrightness", 0.7)
	I.DoorInOpening(ctx.Interact:at(112, 0, 97, 90), 5, 8.5, "Metal", C.Yellow, M.Metal, "BackOfHouse", false, false, "ELECTRICAL")
	ctx:floorNode("Electrical", "BackOfHouse", V(132, 0, 96), V(1, 0, 0))

	-- SECURITY ROOM (z 112..150), locked: needs the security key
	local s = ctx:area("SecurityRoom")
	local labels = { "ENTRANCE", "GRAND HALL N", "GRAND HALL S", "FOOD COURT", "SUPERMARKET", "CINEMA", "ARCADE", "TOY TOWN", "GARAGE B1", "SERVICE HALL", "???", "YOU" }
	U.CCTVWall(s:at(131, 0, 148.8, 0), rng, 4, 3, labels)
	s:box("SecurityDesk", V(18, 3.4, 4), V(131, 1.7, 141), C.Charcoal, M.Metal)
	s:box("DeskTop", V(18.4, 0.2, 4.4), V(131, 3.5, 141), Build.rgb(60, 62, 66), M.Granite)
	I.SecurityComputer(ctx.Interact, V(126, 4.5, 141.6))
	I.Radio(ctx.Interact, V(134, 4.1, 141.2))
	I.Drawer(s, V(138, 2.8, 139), V(0, 0, -1.4), "SecurityRoom")
	U.OfficeChair(s:at(131, 0, 137, 180), rng)
	U.OfficeChair(s:at(124, 0, 136, 150), rng, true)
	s:box("CoffeeMaker", V(1.2, 1.6, 1.2), V(139, 4.4, 141.8), C.Black, M.SmoothPlastic, DECO)
	s:cylY("Mug", 0.6, 0.5, V(137.6, 3.9, 140.6), C.OffWhite, M.SmoothPlastic, DECO)
	-- key board
	local keys = s:box("KeyBoard", V(0.2, 3, 4), V(149.4, 6, 124), C.WoodDark, M.WoodPlanks, DECO)
	Build.layout(keys, Enum.NormalId.Left, nil, {
		{ Text = "KEYS", Y = 0.02, H = 0.16, Color = C.OffWhite, Font = Enum.Font.GothamBold },
		{ Text = "GARAGE · ROOF · B1 · STORE 14", Y = 0.8, H = 0.12, Color = C.OffWhite, Font = Enum.Font.Code },
	})
	for i = 0, 5 do
		s:box("KeyHook", V(0.3, 0.3, 0.2), V(149.2, 6.4 - math.floor(i / 3) * 1, 122.8 + (i % 3) * 1.2), C.Chrome, M.Metal, DECO)
		if i ~= 2 then
			s:box("Key", V(0.15, 0.6, 0.35), V(149.1, 5.9 - math.floor(i / 3) * 1, 122.8 + (i % 3) * 1.2), C.Yellow, M.Metal, DECO)
		end
	end
	-- mall blueprint on the wall (a readable floor plan)
	local plan = s:box("MallBlueprint", V(0.2, 7, 11), V(112.7, 6, 128), Build.rgb(26, 50, 90), M.SmoothPlastic, DECO)
	local items: { any } = { { Text = "OAKRIDGE MALL · LEVEL 1", Y = 0.02, H = 0.08, Color = C.OffWhite, Font = Enum.Font.Code } }
	local function block(label: string, x0: number, x1: number, z0: number, z1: number)
		-- map world x (-150..270) / z (-176..254) to the board
		local u0 = (x0 + 150) / 420
		local u1 = (x1 + 150) / 420
		local v0 = 1 - (z1 + 176) / 430
		local v1 = 1 - (z0 + 176) / 430
		table.insert(items, { Bg = Build.rgb(60, 110, 170), BgT = 0.4, X = u0, W = u1 - u0, Y = 0.1 + v0 * 0.88, H = (v1 - v0) * 0.88 })
		table.insert(items, { Text = label, X = u0, W = u1 - u0, Y = 0.1 + (v0 + v1) / 2 * 0.88 - 0.02, H = 0.04, Color = C.OffWhite, Font = Enum.Font.Code })
	end
	block("ENTRANCE", -32, 32, -176, -130)
	block("GRAND HALL", -32, 32, -130, 150)
	block("MARKET", -150, -32, -130, -30)
	block("VOLTZONE", -100, -32, -26, 40)
	block("NOIR", -100, -32, 44, 118)
	block("WC", -100, -32, 122, 150)
	block("CINEMA", 32, 100, -130, -40)
	block("SCREENS", 112, 190, -130, -34)
	block("ARCADE", 32, 100, -36, 40)
	block("TOYS", 32, 100, 44, 118)
	block("FOOD COURT", -100, 100, 150, 244)
	block("STAFF", 112, 150, -30, 150)
	block("PARKING B1", 150, 270, -20, 150)
	Build.layout(plan, Enum.NormalId.Right, nil, items)
	U.FilingCabinet(s:at(114, 0, 148, 0), rng)
	U.FilingCabinet(s:at(116.4, 0, 148, 0), rng)
	U.Lockers(s:at(146, 0, 114.2, 180), rng, 2, C.Navy)
	local lamp = s:box("DeskLamp", V(0.8, 0.5, 0.8), V(121, 4.4, 142), C.WarmLight, M.Neon, DECO)
	Build.spot(lamp, Enum.NormalId.Bottom, C.WarmLight, 1, 12, 90)
	P.CeilingLight(s:at(131, 12, 128), rng, "SecurityRoom", 0.5, 16, "Flicker", C.ColdLight)
	P.SecurityCamera(s:at(148, 11.5, 113, 135), rng)
	I.DoorInOpening(ctx.Interact:at(112, 0, 130, 90), 5, 8.5, "Security", Build.rgb(70, 80, 95), M.Metal, "SecurityRoom", true, true, "SECURITY")
	ctx:floorNode("CCTV", "SecurityRoom", V(131, 0, 138), V(0, 0, 1))
	ctx:floorNode("Dark", "SecurityRoom", V(146, 0, 118), V(-1, 0, 0))
	ctx:pickup(V(128, 3.8, 142), "OfficeBattery")
	ctx:pickup(V(140, 3.8, 142.4), "OfficeBattery")
end

return BackOfHouse
