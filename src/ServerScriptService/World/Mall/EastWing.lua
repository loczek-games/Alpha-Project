--[[
	Mall.EastWing (ModuleScript)
	Location: ServerScriptService/World/Mall/EastWing

	STARLIGHT CINEMA (lobby, ticket booth, concessions, hallway, three
	screening rooms with stadium seating), PIXEL PALACE arcade, TOY TOWN
	and THE BOOK NOOK (closed, shuttered).
]]

local World = script.Parent.Parent
local Build = require(World.Build)

local C, M = Build.C, Build.M
local V = Vector3.new
local DECO = { deco = true }
local _FRONT = Enum.NormalId.Front

local EastWing = {}

-- storefront signage on the hall wall (x = 32), facing -X into the hall
local function storefront(ctx, f: Build.Frame, z0: number, z1: number, top: number, name: string, color: Color3, state: string, font: Enum.Font?)
	local center = (z0 + z1) / 2
	ctx.Props.Common.NeonSign(f:at(31.2, top + 1.3, center, 90), ctx.Rng, name, math.min(z1 - z0 - 4, 36), color, state == "Flicker", font, state == "Dead")
	f:box("Bulkhead", V(0.6, 0.5, z1 - z0), V(31.3, top - 0.25, center), C.Charcoal, M.Metal, DECO)
end

local function starCeiling(f: Build.Frame, rng: any, x0: number, x1: number, z0: number, z1: number, y: number, count: number)
	for _ = 1, count do
		f:box("Star", V(0.15, 0.05, 0.15), V(rng:Range(x0, x1), y - 0.05, rng:Range(z0, z1)), rng:Pick({ C.OffWhite, C.NeonYellow, C.ColdLight }), M.Neon, { deco = true, query = false })
	end
end

---------------------------------------------------------------------------

local function cinema(ctx)
	local rng = ctx.Rng
	local P, R, F, U, I = ctx.Props.Common, ctx.Props.Retail, ctx.Props.Food, ctx.Props.Utility, ctx.I
	local f = ctx:area("Cinema")
	local zone = "Cinema"

	-- marquee on the hall (above the balcony) + bulkhead sign
	local marquee = f:box("Marquee", V(1.2, 9, 30), V(31.2, 22, -85), C.Void, M.SmoothPlastic, DECO)
	Build.layout(marquee, Enum.NormalId.Left, C.Void, {
		{ Text = "★ STARLIGHT CINEMA ★", Y = 0.05, H = 0.3, Color = C.NeonYellow, Font = Enum.Font.Bangers },
		{ Bg = Build.rgb(230, 220, 190), X = 0.08, W = 0.84, Y = 0.42, H = 0.5 },
		{ Text = "NOW SHOWING", X = 0.08, W = 0.84, Y = 0.44, H = 0.13, Color = C.Black, Font = Enum.Font.GothamBlack },
		{ Text = "THE LAST CUSTOMER  ·  7:00 PM", X = 0.08, W = 0.84, Y = 0.58, H = 0.12, Color = C.Black, Font = Enum.Font.GothamBold },
		{ Text = "MALL AFTER DARK  ·  3:07 AM", X = 0.08, W = 0.84, Y = 0.72, H = 0.12, Color = C.DarkRed, Font = Enum.Font.GothamBold },
	}, true)
	Build.surfaceLight(marquee, Enum.NormalId.Left, C.NeonYellow, 1.2, 18, 100)
	for z = -99, -71, 2 do
		local bulb = f:ball("MarqueeBulb", 0.5, V(30.5, 26.8, z), if rng:Chance(0.35) then C.WarmLight else C.MidGray, if rng:Chance(0.35) then M.Neon else M.Glass, DECO)
		bulb.Name = "MarqueeBulb"
	end
	storefront(ctx, f, -110, -60, 14, "CINEMA · TICKETS INSIDE", C.NeonYellow, "Flicker")
	P.GlassFront(f:at(32, 0, -104, -90), rng, 12, 14)
	P.GlassFront(f:at(32, 0, -66, -90), rng, 12, 14)
	U.AutoDoors(f:at(32, 0, -85, 90), rng, 20, 11, "Open")

	-- carpet pattern
	for _ = 1, 60 do
		f:box("CarpetStar", V(0.8, 0.03, 0.8), CFrame.new(rng:Range(36, 98), 0.02, rng:Range(-128, -42)) * Build.yaw(45), rng:Pick({ C.Mustard, C.Navy, C.Purple }), M.Fabric, { deco = true, query = false })
	end
	-- ticket booth + queue
	F.TicketBooth(f:at(56, 0, -85, 90), rng)
	F.Stanchions(f:at(44, 0, -96), rng, 5, 4)
	F.Stanchions(f:at(44, 0, -74), rng, 5, 4)
	-- concessions along the south wall
	P.Counter(f:at(70, 0, -124, 180), rng, 34, Build.rgb(100, 20, 30), C.Charcoal)
	F.PopcornMachine(f:at(58, 3.6, -125), rng)
	F.SodaFountain(f:at(70, 3.6, -125.5), rng)
	R.CRT(f:at(80, 3.6, -125), rng, false)
	F.IceCreamCase(f:at(92, 0, -126, 180), rng, 8)
	for i, text in ipairs({ { "SNACKS", { "POPCORN S  4.00", "POPCORN L  6.50", "NACHOS    5.00", "CANDY     3.00" } }, { "DRINKS", { "SODA S   3.50", "SODA L   5.00", "SLUSHIE  4.00", "WATER    2.50" } } }) do
		F.MenuBoard(f:at(58 + (i - 1) * 18, 13, -128.7, 180), rng, 14, text[1], text[2], C.DarkRed, i == 1)
	end
	I.Drawer(f, V(65, 3.1, -122.8), V(0, 0, 1.2), zone)
	-- posters along the north wall + east wall
	local films = {
		{ "THE LAST CUSTOMER", "SOME STORES NEVER CLOSE", C.DarkRed },
		{ "ESCALATOR", "GOING DOWN. FOREVER.", C.Navy },
		{ "MANNEQUIN", "THEY WAIT.", C.Purple },
		{ "NIGHT SHIFT", "HE NEVER CLOCKED OUT", C.DarkGreen },
		{ "3:07", "DON'T LOOK UP", C.Black },
	}
	for i, film in ipairs(films) do
		F.MoviePoster(f:at(42 + (i - 1) * 12, 7, -40.4, 0), rng, film[1], film[2], film[3], i % 2 == 1)
	end
	P.Bench(f:at(60, 0, -48, 180), rng)
	P.Bench(f:at(80, 0, -48, 180), rng)
	R.ArcadeCabinet(f:at(96, 0, -60, 90), rng, true, "SPACE PANIC")
	P.TrashCan(f:at(90, 0, -110), rng, true)
	P.Litter(f:at(70, 0, -100), rng, 14, 20)
	for _ = 1, 10 do
		f:box("Popcorn", V(0.35, 0.3, 0.35), V(rng:Range(55, 75), 0.15, rng:Range(-118, -108)), C.Yellow, M.SmoothPlastic, DECO)
	end
	-- ceiling: dark with stars + chandeliers
	f:slab("CinemaCeiling", 32, 100, -130, -40, 20, 1, Build.rgb(22, 12, 26), M.Fabric, nil, true)
	starCeiling(f, rng, 34, 98, -128, -42, 20, 140)
	for _, spot in ipairs({ { 50, -110 }, { 80, -85 }, { 50, -60 } }) do
		local lamp = f:ball("Chandelier", 3, V(spot[1], 16.5, spot[2]), C.WarmLight, M.Neon, { deco = true, tags = { "FlickerLight" } })
		Build.point(lamp, C.WarmLight, 0.8, 28):SetAttribute("BaseBrightness", 0.8)
		f:box("Chain", V(0.1, 3, 0.1), V(spot[1], 18.5, spot[2]), C.Mustard, M.Metal, DECO)
	end
	ctx:ceilingNodes(zone, 34, 98, -128, -42, 20, 16)
	P.SecurityCamera(f:at(98, 19, -128, 135), rng)
	P.EmergencyLight(f:at(98.6, 14, -100, 90), rng, true)

	-- hallway to the theatres (x 100..112) - sconces, posters, theatre signs
	for z = -124, -44, 16 do
		local sconce = f:box("Sconce", V(0.6, 1.2, 1), V(100.8, 7, z), C.WarmLight, M.Neon, { deco = true })
		if rng:Chance(0.6) then
			Build.point(sconce, C.WarmLight, 0.5, 12)
		else
			sconce.Material = M.Glass
			sconce.Color = C.MidGray
		end
	end
	for i, z in ipairs({ -115, -82, -49 }) do
		local plate = f:box("TheaterNumber", V(0.3, 2.4, 3), V(111.3, 11, z), C.Void, M.SmoothPlastic, DECO)
		Build.text(plate, Enum.NormalId.Left, tostring(i), { Color = C.NeonYellow, Font = Enum.Font.Bangers, Glow = true })
		P.ExitSign(f:at(111.3, 9.8, z + 4.5, 90), rng, "THEATER " .. i)
	end
	f:slab("CinemaHallCeiling", 100, 112, -130, -38, 12, 1, Build.rgb(22, 12, 26), M.Fabric, nil, true)
	ctx:ceilingNodes("ServiceHalls", 101, 111, -128, -40, 12, 14)
	I.DoorInOpening(ctx.Interact:at(106, 0, -38), 5, 8.5, "Metal", C.Steel, M.Metal, "ServiceHalls", false, true, "STAFF ONLY")

	-- screening rooms
	local theaters = { { -130, -100, "Static" }, { -97, -67, "Dark" }, { -64, -34, "Torn" } }
	for index, t in ipairs(theaters) do
		local z0, z1, screenState = t[1], t[2], t[3]
		local zc = (z0 + z1) / 2
		local tf = ctx:area("Theater" .. index)
		-- screen
		local screen = tf:box("Screen", V(0.4, 12, 24), V(188.6, 10, zc), if screenState == "Static" then C.Gray else Build.rgb(200, 198, 190), M.SmoothPlastic, { deco = true, tags = { "MallTV" }, attrs = { Mode = if screenState == "Static" then "Static" else "Off" } })
		screen.Name = "Screen"
		if screenState == "Static" then
			Build.text(screen, Enum.NormalId.Left, "", { Background = C.Gray, Glow = true })
			Build.surfaceLight(screen, Enum.NormalId.Left, C.ColdLight, 1.2, 60, 110)
		elseif screenState == "Torn" then
			tf:box("Tear", V(0.5, 7, 3), CFrame.new(188.3, 9, zc + 4) * CFrame.Angles(math.rad(12), 0, 0), C.Void, M.SmoothPlastic, DECO)
		end
		tf:box("Curtain", V(0.8, 16, 4), V(188, 10, zc - 14), C.DarkRed, M.Fabric, DECO)
		tf:box("Curtain", V(0.8, 16, 4), V(188, 10, zc + 14), C.DarkRed, M.Fabric, DECO)
		tf:box("Stage", V(6, 2, z1 - z0 - 1), V(186, 1, zc), Build.rgb(40, 20, 24), M.Wood)
		-- stadium seating (rows rise towards the back / west)
		for row = 0, 6 do
			local x = 172 - row * 6
			local y = row * 1.2
			if row > 0 then
				tf:box("Tier", V(6, y, z1 - z0 - 8), V(x, y / 2, zc + 3), Build.rgb(50, 18, 26), M.Fabric)
			end
			ctx.Props.Food.SeatRow(tf:at(x, y, zc + 3, -90), rng, 7, Build.vary(rng, C.DarkRed, 0.05))
		end
		-- aisle steps
		for row = 1, 6 do
			tf:box("AisleStep", V(6, row * 1.2 - 0.6, 3), V(172 - row * 6 + 0, (row * 1.2 - 0.6) / 2, z0 + 3.5), Build.rgb(44, 16, 22), M.Fabric)
		end
		for z = z0 + 1.5, z1 - 1.5, (z1 - z0 - 3) / 2 do
			local strip = tf:box("AisleLight", V(40, 0.08, 0.2), V(150, 0.05, z), C.NeonOrange, M.Neon, { deco = true, query = false })
			strip.Transparency = 0.3
		end
		for x = 120, 180, 20 do
			for _, z in ipairs({ z0 + 0.8, z1 - 0.8 }) do
				local sconce = tf:box("WallSconce", V(1, 1.2, 0.6), V(x, 12, z), C.WarmLight, M.Neon, DECO)
				if rng:Chance(0.4) then
					Build.point(sconce, C.WarmLight, 0.35, 10)
				else
					sconce.Material = M.Glass
				end
			end
		end
		P.ExitSign(tf:at(113, 10, zc + 6, -90), rng)
		tf:slab("TheaterCeiling", 112, 190, z0, z1, 24, 1, Build.rgb(18, 10, 14), M.Fabric, nil, true)
		ctx:ceilingNodes("Theaters", 114, 188, z0 + 1, z1 - 1, 24, 18)
		ctx:floorNode("Theater", "Theaters", V(150, 3.6, zc), V(1, 0, 0), { Theater = index })
		ctx:floorNode("Dark", "Theaters", V(184, 0, z0 + 3), V(-1, 0, 0))
		ctx:floorNode("Screen", "Theaters", V(186, 2, zc), V(-1, 0, 0), { Theater = index })
		P.Litter(tf:at(165, 0, zc), rng, 10, 10)
	end
	-- projection beam from the back of theatre 1
	local beam = ctx:area("Theater1"):box("ProjectorBeam", V(70, 6, 10), CFrame.new(150, 13, -115) * CFrame.Angles(0, 0, math.rad(-4)), C.ColdLight, M.SmoothPlastic, { deco = true, t = 0.93, query = false })
	beam.CastShadow = false

	for _, z in ipairs({ -120, -95, -60, -50 }) do
		ctx:floorNode("Floor", zone, V(rng:Range(40, 90), 0, z), V(rng:Range(-1, 1), 0, rng:Range(-1, 1)))
	end
	ctx:floorNode("Hallway", "ServiceHalls", V(106, 0, -120), V(0, 0, 1), { Length = 80 })
	ctx:pickup(V(64, 3.8, -122))
	ctx:pickup(V(150, 4.2, -82))
end

---------------------------------------------------------------------------

local function arcade(ctx)
	local rng = ctx.Rng
	local P, R, U, I = ctx.Props.Common, ctx.Props.Retail, ctx.Props.Utility, ctx.I
	local f = ctx:area("Arcade")
	local zone = "Arcade"

	storefront(ctx, f, -23, 27, 12, "PIXEL PALACE", C.NeonPurple, "Flicker", Enum.Font.Arcade)
	f:box("EntranceArch", V(0.6, 1.4, 20), V(31.2, 12.8, 2), C.NeonPink, M.Neon, DECO)
	-- carpet pattern
	for _ = 1, 90 do
		f:box("CarpetShape", V(rng:Range(0.6, 1.4), 0.03, rng:Range(0.6, 1.4)), CFrame.new(rng:Range(34, 98), 0.02, rng:Range(-34, 38)) * Build.yaw(rng:Range(0, 90)), rng:Pick({ C.NeonPink, C.NeonCyan, C.NeonYellow, C.Teal }), M.Fabric, { deco = true, query = false })
	end
	-- cabinet rows (back to back)
	for _, z in ipairs({ -22, -6 }) do
		for i = 0, 7 do
			local x = 44 + i * 4
			if rng:Chance(0.9) then
				R.ArcadeCabinet(f:at(x, 0, z - 2.2, 0), rng, rng:Chance(0.3))
			end
			if rng:Chance(0.85) then
				R.ArcadeCabinet(f:at(x, 0, z + 2.2, 180), rng, rng:Chance(0.3))
			end
		end
	end
	-- a cabinet knocked over
	local fallen = f:rel(CFrame.new(84, 1.6, 10) * CFrame.Angles(math.rad(-90), 0.4, 0) * CFrame.new(0, -1.6, 0))
	R.ArcadeCabinet(fallen, rng, true, "ROBO PUNCH")
	R.ClawMachine(f:at(40, 0, 18), rng)
	R.ClawMachine(f:at(46, 0, 18), rng)
	R.AirHockey(f:at(60, 0, 14, 90), rng)
	R.AirHockey(f:at(72, 0, 14, 90), rng)
	-- snack tables
	for _, spot in ipairs({ { 88, -28 }, { 94, -18 } }) do
		P.DiningSet(f:at(spot[1], 0, spot[2]), rng, C.Navy, true)
	end
	U.VendingMachine(f:at(98, 0, -8, 90), rng, true)
	R.PrizeCounter(f:at(58, 0, 33, 0), rng, 26)
	R.Tickets(f:at(60, 0, 26), rng, 8)
	R.Tickets(f:at(50, 0, -14), rng, 6)
	R.Ball(f:at(76, 0, 26), rng, 1.4)
	-- neon wall stripes
	for _, spec in ipairs({ { 66, -35.4, 64, C.NeonPink }, { 66, 39.4, 64, C.NeonCyan } }) do
		f:box("NeonStripe", V(spec[3], 0.3, 0.2), V(spec[1], 10, spec[2]), spec[4], M.Neon, DECO)
		f:box("NeonStripe", V(spec[3], 0.3, 0.2), V(spec[1], 10.8, spec[2]), C.NeonPurple, M.Neon, DECO)
	end
	local change = f:box("ChangeMachine", V(3, 6, 2), V(34, 3, -30), C.Mustard, M.Metal)
	Build.text(change, Enum.NormalId.Right, "CHANGE\n¢ TOKENS ¢", { Color = C.Black, Font = Enum.Font.Arcade })
	P.Poster(f:at(99.6, 7, -24, 90), rng, "HIGH SCORE", "AAA  999999", C.Purple)

	-- maintenance room (x 86..100, z 22..40)
	f:wallZ("MaintenanceWall", 22, 40, 86, 16, 1, C.DarkGray, M.Concrete, { { Center = 26, Width = 4.5, Top = 8.5 } })
	f:wallX("MaintenanceWall", 86, 100, 22, 16, 1, C.DarkGray, M.Concrete)
	R.ArcadeCabinet(f:at(92, 0, 37, 180), rng, true)
	U.MetalShelf(f:at(98, 0, 30, 90), rng, 8, 8)
	f:box("Workbench", V(6, 3.2, 2.6), V(90, 1.6, 24), C.WoodDark, M.WoodPlanks)
	P.BoxStack(f:at(96, 0, 24), rng, 2)
	I.DoorInOpening(ctx.Interact:at(86, 0, 26, 90), 4.5, 8.5, "Metal", C.Steel, M.Metal, zone, false, false, "MAINT.")
	I.DoorInOpening(ctx.Interact:at(100, 0, 30, 90), 5, 8.5, "Metal", C.Steel, M.Metal, zone, false, false, "STAFF")

	f:slab("ArcadeCeiling", 32, 100, -36, 40, 16, 1, Build.rgb(16, 12, 24), M.SmoothPlastic, nil, true)
	starCeiling(f, rng, 34, 98, -34, 38, 16, 60)
	for x = 44, 88, 16 do
		for z = -26, 30, 18 do
			local state = if rng:Chance(0.4) then "Dead" elseif rng:Chance(0.3) then "Flicker" else "On"
			P.CeilingLight(f:at(x, 16, z), rng, zone, 0.6, 18, state, C.NeonPurple)
		end
	end
	ctx:ceilingNodes(zone, 34, 98, -34, 38, 16, 16)
	P.EmergencyLight(f:at(33, 12, 34, -90), rng, true)
	P.SecurityCamera(f:at(98.5, 15, -34, 135), rng)
	for _, z in ipairs({ -30, -14, 2, 22 }) do
		ctx:floorNode("Floor", zone, V(rng:Range(40, 90), 0, z), V(rng:Range(-1, 1), 0, rng:Range(-1, 1)))
	end
	ctx:floorNode("ArcadeRow", zone, V(60, 0, -14), V(-1, 0, 0))
	ctx:floorNode("Dark", zone, V(94, 0, 34), V(-1, 0, 0))
	ctx:pickup(V(60, 3.6, 31))
	ctx:pickup(V(90, 3.6, 24))
end

---------------------------------------------------------------------------

local function toyStore(ctx)
	local rng = ctx.Rng
	local P, R, U, I = ctx.Props.Common, ctx.Props.Retail, ctx.Props.Utility, ctx.I
	local f = ctx:area("ToyStore")
	local zone = "ToyStore"

	storefront(ctx, f, 53, 109, 12, "TOY TOWN", C.NeonYellow, "On", Enum.Font.FredokaOne)
	P.GlassFront(f:at(32, 0, 62, -90), rng, 18, 12)
	P.GlassFront(f:at(32, 0, 100, -90), rng, 18, 12)
	-- window display: giant bear + balloons
	R.GiantBear(f:at(38, 0, 62, 90), rng)
	for _ = 1, 5 do
		local x, z = rng:Range(36, 40), rng:Range(96, 104)
		local y = rng:Range(5, 9)
		f:ball("Balloon", 1.6, V(x, y, z), rng:Pick({ C.Red, C.Blue, C.Yellow }), M.SmoothPlastic, DECO)
		f:box("String", V(0.05, y - 1, 0.05), V(x, (y - 1) / 2, z), C.OffWhite, M.SmoothPlastic, DECO)
	end

	-- shelving rows
	for i, z in ipairs({ 56, 70, 84 }) do
		R.ToyBoxShelf(f:at(62, 0, z), rng, 16)
		R.ToyBoxShelf(f:at(62, 0, z + 2.4, 180), rng, 16)
		if i == 2 then
			P.Spill(f:at(62, 0, z - 2), rng, 14, 12, { C.Red, C.Yellow, C.Blue, C.Pink })
		end
	end
	-- doll wall (south wall): rows of dolls all facing the door
	for row = 0, 2 do
		f:box("DollShelf", V(40, 0.3, 1.6), V(66, 3 + row * 2.4, 44.9), C.OffWhite, M.SmoothPlastic, DECO)
		for i = 0, 15 do
			if rng:Chance(0.8) then
				R.Doll(f:at(48 + i * 2.4, 3.15 + row * 2.4, 45, 180 + rng:Range(-20, 20)), rng, rng:Chance(0.25))
			end
		end
	end
	local dollSign = f:box("DollSign", V(20, 1.6, 0.2), V(66, 11, 44.2), C.Pink, M.SmoothPlastic, DECO)
	Build.text(dollSign, Enum.NormalId.Back, "BEST FRIENDS FOREVER", { Color = C.OffWhite, Font = Enum.Font.FredokaOne })
	-- plush pile + ball pit + rocking horses
	for _ = 1, 16 do
		R.Plush(f:at(rng:Range(60, 72), rng:Range(0, 1.2), rng:Range(100, 108), rng:Range(0, 360)), rng, rng:Range(0.6, 1))
	end
	f:box("PitWall", V(12, 2, 0.6), V(76, 1, 89.7), C.Blue, M.SmoothPlastic)
	f:box("PitWall", V(12, 2, 0.6), V(76, 1, 97.3), C.Blue, M.SmoothPlastic)
	f:box("PitWall", V(0.6, 2, 8), V(70.3, 1, 93.5), C.Blue, M.SmoothPlastic)
	f:box("PitWall", V(0.6, 2, 8), V(81.7, 1, 93.5), C.Blue, M.SmoothPlastic)
	for _ = 1, 36 do
		f:ball("PitBall", 0.8, V(rng:Range(71, 81), rng:Range(0.4, 1.6), rng:Range(90.3, 96.7)), rng:Pick({ C.Red, C.Yellow, C.Blue, C.Green }), M.SmoothPlastic, DECO)
	end
	R.RockingHorse(f:at(44, 0, 80, -60), rng)
	R.RockingHorse(f:at(44, 0, 88, -120), rng)
	R.Ball(f:at(52, 0, 94), rng, 2, C.Red)
	-- toy train loop
	for a = 0, 330, 30 do
		local r = 6
		local cf = CFrame.new(84, 0.06, 64) * CFrame.Angles(0, math.rad(a), 0) * CFrame.new(0, 0, -r)
		f:box("Track", V(3.3, 0.1, 0.8), cf, C.WoodDark, M.Wood, { deco = true, query = false })
	end
	f:box("Train", V(2, 1.2, 1.2), CFrame.new(84, 0.7, 58) * Build.yaw(90), C.Red, M.SmoothPlastic, DECO)
	-- register
	P.Counter(f:at(46, 0, 110, 90), rng, 10, C.Blue, C.OffWhite)
	P.Register(f:at(45.5, 3.6, 108, 90), rng)
	I.Drawer(f, V(46.8, 3.1, 108), V(-1.2, 0, 0), zone)
	P.Poster(f:at(99.6, 8, 60, 90), rng, "BOZO'S BIRTHDAY BASH", "FUN FOR ALL AGES", C.Red, true)
	P.Graffiti(f:at(99.4, 5, 76, 90), rng, "PLAY WITH US", 7, C.NeonRed)

	-- storage (x 86..100, z 96..118)
	f:wallZ("StorageWall", 96, 118, 86, 16, 1, C.OffWhite, M.Plaster, { { Center = 114, Width = 4.5, Top = 8.5 } })
	f:wallX("StorageWall", 86, 100, 96, 16, 1, C.OffWhite, M.Plaster)
	U.MetalShelf(f:at(98, 0, 106, 90), rng, 12, 9)
	P.BoxStack(f:at(90, 0, 100), rng, 3)
	R.Doll(f:at(92, 0, 112, 250), rng, true)
	I.DoorInOpening(ctx.Interact:at(100, 0, 110, 90), 5, 8.5, "Metal", C.Steel, M.Metal, zone, false, false, "STAFF")

	ctx:dropCeiling(f, zone, 32, 100, 44, 118, 16, { Dead = 0.35, Flicker = 0.25, LightColor = Build.rgb(255, 225, 200), Brightness = 0.9 })
	local red = f:box("RedNightLight", V(0.5, 0.5, 0.5), V(66, 12, 46), C.NeonRed, M.Neon, DECO)
	Build.point(red, C.NeonRed, 0.6, 16)
	P.SecurityCamera(f:at(98.5, 15, 116, 45), rng)
	for _, z in ipairs({ 50, 63, 77, 104 }) do
		ctx:floorNode("Floor", zone, V(rng:Range(40, 90), 0, z), V(rng:Range(-1, 1), 0, rng:Range(-1, 1)))
	end
	ctx:floorNode("DollWall", zone, V(66, 0, 48), V(0, 0, 1))
	ctx:floorNode("Dark", zone, V(94, 0, 102), V(-1, 0, 0))
	ctx:pickup(V(62, 4.2, 70))
	ctx:pickup(V(94, 0.6, 116))
end

---------------------------------------------------------------------------

local function bookNook(ctx)
	local rng = ctx.Rng
	local P, U = ctx.Props.Common, ctx.Props.Utility
	local f = ctx:area("BookNook")
	local zone = "BookNook"
	storefront(ctx, f, 126, 146, 10, "THE BOOK NOOK", C.NeonOrange, "Dead", Enum.Font.Garamond)
	local shutter = P.Shutter(f:at(32.6, 0, 136, -90), rng, 20, 10, 0.08)
	local model = shutter.Parent :: Model
	model:AddTag("StoreShutter")
	model:SetAttribute("Store", "BookNook")
	local notice = f:box("Notice", V(0.1, 2.4, 3.4), V(32.4, 5, 132), C.OffWhite, M.SmoothPlastic, DECO)
	Build.text(notice, Enum.NormalId.Left, "CLOSED\nFOR GOOD\nTHANK YOU", { Color = C.Black, Font = Enum.Font.SpecialElite })
	for i = 0, 3 do
		U.Bookshelf(f:at(48 + i * 12, 0, 148.6), rng, 10)
	end
	U.Bookshelf(f:at(99, 0, 130, 90), rng, 10)
	U.Couch(f:at(60, 0, 132, 180), rng, 6, C.DarkRed)
	U.CoffeeTable(f:at(60, 0, 128), rng)
	local lamp = f:box("ReadingLamp", V(1.2, 1, 1.2), V(52, 5, 128), C.WarmLight, M.Neon, { deco = true, tags = { "BookLamp" } })
	f:box("LampPole", V(0.2, 4.5, 0.2), V(52, 2.25, 128), C.Charcoal, M.Metal, DECO)
	local glow = Build.point(lamp, C.WarmLight, 0, 16)
	glow.Name = "LampGlow"
	for _ = 1, 10 do
		f:box("Book", V(1, 0.3, 1.4), CFrame.new(rng:Range(40, 95), 0.15, rng:Range(124, 146)) * Build.yaw(rng:Range(0, 360)), rng:Pick({ C.DarkRed, C.Navy, C.DarkGreen }), M.SmoothPlastic, DECO)
	end
	f:slab("BookCeiling", 32, 100, 122, 150, 12, 1, C.WoodDark, M.WoodPlanks, nil, true)
	ctx:ceilingNodes(zone, 34, 98, 124, 148, 12, 16)
	ctx:floorNode("ClosedStore", zone, V(60, 0, 138), V(-1, 0, 0))
	ctx.I.DoorInOpening(ctx.Interact:at(100, 0, 140, 90), 5, 8.5, "Wood", C.WoodDark, M.Wood, zone, false, false, "DELIVERIES")
end

function EastWing.Build(ctx)
	cinema(ctx)
	arcade(ctx)
	toyStore(ctx)
	bookNook(ctx)
end

return EastWing
