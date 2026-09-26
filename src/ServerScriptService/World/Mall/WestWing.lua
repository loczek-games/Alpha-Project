--[[
	Mall.WestWing (ModuleScript)
	Location: ServerScriptService/World/Mall/WestWing

	FRESHWAY SUPERMARKET, VOLTZONE ELECTRONICS, NOIR & CO. clothing store and
	the RESTROOMS: storefronts, full interiors, back rooms, doors, nodes.
]]

local World = script.Parent.Parent
local Build = require(World.Build)

local C, M = Build.C, Build.M
local V = Vector3.new
local DECO = { deco = true }
local FRONT = Enum.NormalId.Front

local WestWing = {}

-- storefront facade on the hall wall (x = -32), facing +X into the hall
local function storefront(ctx, f: Build.Frame, z0: number, z1: number, top: number, name: string, color: Color3, state: string, font: Enum.Font?)
	local P = ctx.Props.Common
	local center = (z0 + z1) / 2
	P.NeonSign(f:at(-31.2, top + 1.3, center, -90), ctx.Rng, name, math.min(z1 - z0 - 4, 36), color, state == "Flicker", font, state == "Dead")
	f:box("Bulkhead", V(0.6, 0.5, z1 - z0), V(-31.3, top - 0.25, center), C.Charcoal, M.Metal, DECO)
end

-- supermarket gondola with bigger stock blocks (keeps the part count sane)
local function shelfUnit(ctx, f: Build.Frame, length: number, palette: { Color3 }, emptyChance: number)
	local rng = ctx.Rng
	local m = f:model("Shelf")
	local h = 7.5
	m:box("Back", V(length, h, 0.3), V(0, h / 2, 0), C.OffWhite, M.Metal)
	m:box("Base", V(length, 0.7, 3.4), V(0, 0.35, 0), C.LightGray, M.Metal)
	for level = 1, 4 do
		local y = 0.7 + (level - 1) * 1.7
		m:box("Board", V(length, 0.12, 3.4), V(0, y + 0.06, 0), C.LightGray, M.Metal, DECO)
		for _, side in ipairs({ -1, 1 }) do
			local x = -length / 2 + 0.3
			while x < length / 2 - 1 do
				local w = rng:Range(1.8, 4)
				if x + w > length / 2 - 0.3 then
					w = length / 2 - 0.3 - x
				end
				if w > 0.6 and not rng:Chance(emptyChance) then
					local ph = rng:Range(0.8, 1.4)
					m:box("Stock", V(w - 0.15, ph, 1.3), V(x + w / 2, y + 0.12 + ph / 2, side * 0.95), Build.vary(rng, rng:Pick(palette), 0.18), M.SmoothPlastic, DECO)
				end
				x += w
			end
		end
	end
	m:box("PriceStrip", V(length, 0.3, 0.05), V(0, 1.1, -1.72), C.Yellow, M.SmoothPlastic, DECO)
	m:box("PriceStrip", V(length, 0.3, 0.05), V(0, 1.1, 1.72), C.Yellow, M.SmoothPlastic, DECO)
	local model = m.Parent :: Model
	model:AddTag("StoreShelf")
	return m
end

---------------------------------------------------------------------------

local function supermarket(ctx)
	local rng = ctx.Rng
	local P, R, U, I = ctx.Props.Common, ctx.Props.Retail, ctx.Props.Utility, ctx.I
	local f = ctx:area("Supermarket")
	local zone = "Supermarket"

	storefront(ctx, f, -110, -50, 13, "FRESHWAY MARKET", C.NeonGreen, "Flicker")
	P.GlassFront(f:at(-32, 0, -98, 90), rng, 24, 13)
	P.GlassFront(f:at(-32, 0, -62, 90), rng, 24, 13, true)
	U.AutoDoors(f:at(-32, 0, -80, -90), rng, 10, 10, "Jammed")
	f:box("DoorHeader", V(1, 3, 12), V(-32, 11.5, -80), C.Charcoal, M.Metal)

	-- checkout lanes
	for i, z in ipairs({ -120, -110, -100, -90 }) do
		R.CheckoutLane(f:at(-44, 0, z, 90), rng, i, rng:Chance(0.5))
	end
	for i = 0, 4 do
		R.Cart(f:at(-38, 0, -64 + i * 1.1, 90), rng)
	end
	R.Cart(f:at(-52, 0, -70, 35), rng, false, true)
	R.Cart(f:at(-60, 0, -96, 160), rng, true, true)
	R.Cart(f:at(-90, 0, -62, 80), rng)
	local sign = f:box("ServiceSign", V(0.3, 2, 10), V(-36, 15, -80), C.DarkGreen, M.SmoothPlastic, DECO)
	Build.text(sign, Enum.NormalId.Left, "CUSTOMER SERVICE", { Color = C.OffWhite, Font = Enum.Font.GothamBold })

	-- aisles
	local palettes = {
		{ C.Red, C.Yellow, C.Orange, C.Cream },
		{ C.Blue, C.OffWhite, C.Teal },
		{ C.Green, C.Mustard, C.Tan },
		{ C.Purple, C.Pink, C.Red },
		{ C.Cardboard, C.Tan, C.Cream, C.Wood },
		{ C.OffWhite, C.Teal, C.Navy },
	}
	local aisleNames = { "CEREAL · BREAKFAST", "DRINKS · WATER", "CANNED GOODS", "SNACKS · CANDY", "BAKERY · BREAD", "CLEANING · PAPER" }
	for i, z in ipairs({ -118, -108, -98, -88, -78, -68 }) do
		local palette = palettes[i]
		for _, segment in ipairs({ { -114, 26 }, { -80, 30 } }) do
			local x, length = segment[1], segment[2]
			if i == 4 and x == -80 then
				-- toppled shelf across the aisle
				local fallen = f:rel(CFrame.new(x, 0, z) * CFrame.Angles(math.rad(-78), 0, 0) * CFrame.new(0, 0, 0))
				shelfUnit(ctx, fallen, length, palette, 0.6)
				P.Spill(f:at(x, 0, z - 3), rng, length, 26, palette)
			else
				shelfUnit(ctx, f:at(x, 0, z), length, palette, 0.45)
				if rng:Chance(0.35) then
					P.Spill(f:at(x + rng:Range(-8, 8), 0, z - 1.6), rng, 8, 8, palette)
				end
			end
		end
		local aisleSign = f:box("AisleSign", V(10, 2.2, 0.3), V(-97, 13.5, z), C.DarkGreen, M.SmoothPlastic, DECO)
		Build.text(aisleSign, FRONT, string.format("%d · %s", i, aisleNames[i]), { Color = C.OffWhite, Font = Enum.Font.GothamBold })
		Build.text(aisleSign, Enum.NormalId.Back, string.format("%d · %s", i, aisleNames[i]), { Color = C.OffWhite, Font = Enum.Font.GothamBold })
		f:box("SignWire", V(0.06, 3.4, 0.06), V(-97, 16.3, z), C.Charcoal, M.Metal, DECO)
		ctx:floorNode("Aisle", zone, V(-97, 0, z - 5), V(1, 0, 0), { ShelfZ = z })
	end

	-- freezers along the back wall
	for i, z in ipairs({ -120, -104, -88, -72 }) do
		R.Freezer(f:at(-146.8, 0, z, -90), rng, 4, i % 2 == 1)
	end
	P.Puddle(f:at(-140, 0, -100), rng, 8)
	-- produce
	for i = 0, 3 do
		R.ProduceBin(f:at(-60 + (i % 2) * 14, 0, -54 + math.floor(i / 2) * 10, 180), rng)
	end
	local produce = f:box("ProduceSign", V(14, 2.4, 0.3), V(-53, 13, -40), C.DarkGreen, M.SmoothPlastic, DECO)
	Build.text(produce, Enum.NormalId.Back, "FRESH PRODUCE", { Color = C.Yellow, Font = Enum.Font.GothamBlack })
	Build.text(produce, FRONT, "FRESH PRODUCE", { Color = C.Yellow, Font = Enum.Font.GothamBlack })

	-- storage room + manager office (north-west)
	f:wallX("StorageWall", -150, -112, -58, 18, 1, C.DarkGray, M.Concrete, { { Center = -124, Width = 8, Top = 10 } })
	f:wallZ("StorageWall", -58, -30, -112, 18, 1, C.DarkGray, M.Concrete)
	f:box("StripCurtain", V(8, 9.8, 0.2), V(-124, 5, -58), C.Glass, M.SmoothPlastic, { t = 0.5, collide = false })
	for i = 0, 2 do
		U.MetalShelf(f:at(-146, 0, -52 + i * 8, -90), rng, 6, 10)
	end
	P.Pallet(f:at(-130, 0, -40), rng)
	P.BoxStack(f:at(-130, 0.9, -40), rng, 3)
	P.BoxStack(f:at(-120, 0, -48), rng, 4)
	P.Mop(f:at(-116, 0, -36), rng)
	I.DoorInOpening(ctx.Interact:at(-106, 0, -30), 5, 8.5, "Metal", C.Steel, M.Metal, zone, false, false, "STAFF ONLY")
	-- manager office
	f:wallX("OfficeWall", -112, -96, -44, 11, 1, C.OffWhite, M.Plaster, { { Center = -99, Width = 4, Top = 8.5 }, { Center = -106, Width = 6, Top = 8, Bottom = 4 } })
	f:wallZ("OfficeWall", -44, -30, -96, 11, 1, C.OffWhite, M.Plaster)
	f:slab("OfficeCeiling", -112, -96, -44, -30, 11, 0.6, C.OffWhite, M.Plaster, nil, true)
	f:box("OfficeWindow", V(6, 4, 0.2), V(-106, 6, -44), C.Glass, M.Glass, { t = 0.6 })
	U.Desk(f:at(-104, 0, -34), rng, 7)
	R.Computer(f:at(-104, 3.35, -33.6), rng, true, "INVENTORY: ERROR\n> 3:07 AM_")
	U.OfficeChair(f:at(-104, 0, -38, 180), rng)
	U.FilingCabinet(f:at(-110.5, 0, -40, -90), rng)
	I.Drawer(f, V(-101.6, 2.5, -35.7), V(0, 0, -1.4), zone)
	P.Poster(f:at(-97, 6, -37, 90), rng, "EMPLOYEE OF THE MONTH", "MAY 1998", C.Navy)
	P.CeilingLight(f:at(-104, 10.4, -37), rng, zone, 0.6, 12, "Flicker", C.SickLight)
	ctx:floorNode("Dark", zone, V(-140, 0, -40), V(1, 0, 0))
	ctx:floorNode("Office", zone, V(-107, 0, -40), V(0, 0, 1))

	-- industrial ceiling with hanging strip lights
	f:slab("Ceiling", -150, -32, -130, -30, 18, 1, C.Charcoal, M.Metal, nil, true)
	for z = -124, -36, 16 do
		P.PipeRun(f:at(-91, 17.6, z), rng, 110, 1)
	end
	for x = -140, -40, 14 do
		for z = -122, -62, 12 do
			local state = if rng:Chance(0.45) then "Dead" elseif rng:Chance(0.25) then "Flicker" else "On"
			P.CeilingLight(f:at(x, 15, z, 90), rng, zone, 0.9, 22, state, C.SickLight)
			f:box("Chain", V(0.06, 3, 0.06), V(x, 16.5, z), C.Charcoal, M.Metal, DECO)
		end
	end
	ctx:ceilingNodes(zone, -148, -34, -128, -32, 18, 16)
	P.EmergencyLight(f:at(-148.9, 12, -110, -90), rng, true)
	P.EmergencyLight(f:at(-33, 12, -118, 90), rng, false)
	P.ExitSign(f:at(-106, 10, -31), rng)
	P.SecurityCamera(f:at(-148, 16.5, -128, -135), rng)
	P.FireExtinguisher(f:at(-148.6, 0, -64, -90), rng)
	P.Graffiti(f:at(-149, 6, -92, -90), rng, "IT WATCHES FROM ABOVE", 12, C.NeonRed)

	for _, z in ipairs({ -123, -113, -103, -93, -83, -73, -63 }) do
		ctx:floorNode("Floor", zone, V(rng:Range(-125, -60), 0, z), V(rng:Range(-1, 1), 0, rng:Range(-1, 1)))
	end
	ctx:floorNode("Freezer", zone, V(-142, 0, -95), V(1, 0, 0))
	ctx:pickup(V(-44, 3.8, -104))
	ctx:pickup(V(-140, 4.2, -48))
	ctx:pickup(V(-80, 0.6, -84))
end

---------------------------------------------------------------------------

local function electronics(ctx)
	local rng = ctx.Rng
	local P, R, U, I = ctx.Props.Common, ctx.Props.Retail, ctx.Props.Utility, ctx.I
	local f = ctx:area("Electronics")
	local zone = "Electronics"

	storefront(ctx, f, -18, 32, 12, "VOLTZONE", C.NeonBlue, "Flicker", Enum.Font.Michroma)
	P.GlassFront(f:at(-32, 0, -10.5, 90), rng, 15, 12)
	P.GlassFront(f:at(-32, 0, 24.5, 90), rng, 15, 12)
	for _, z in ipairs({ -1, 15 }) do
		f:box("SecurityGate", V(1.6, 5, 0.4), V(-34, 2.5, z), C.LightGray, M.SmoothPlastic)
	end

	-- TV wall
	R.TVWall(f:at(-99, 0, 0, -90), rng, 5, 3, 4)
	local tvSign = f:box("TVSign", V(0.3, 1.6, 22), V(-99, 12.8, 0), C.Navy, M.SmoothPlastic, DECO)
	Build.text(tvSign, Enum.NormalId.Right, "4K ULTRA · HOME CINEMA", { Color = C.OffWhite, Font = Enum.Font.Michroma })
	-- display tables
	for i, spot in ipairs({ { -76, -14 }, { -76, 6 }, { -58, -14 }, { -58, 6 } }) do
		if i % 2 == 0 then
			R.LaptopTable(f:at(spot[1], 0, spot[2]), rng, 10)
		else
			R.PhoneDisplay(f:at(spot[1], 0, spot[2]), rng, 10)
		end
	end
	-- computer desks along the north wall
	for i = 0, 2 do
		local x = -78 + i * 10
		f:box("PCDesk", V(8, 3.2, 3), V(x, 1.6, 36.5), C.WoodLight, M.WoodPlanks)
		R.Computer(f:at(x, 3.2, 37, 0), rng, rng:Chance(0.5), if i == 1 then "CAM 04\nMOTION DETECTED" else nil)
	end
	-- security camera display (a wall of cameras + a monitor showing the store)
	for i = 0, 5 do
		P.SecurityCamera(f:at(-88 + i * 6, 9, -24.2, 180), rng, 5)
	end
	local camSign = f:box("CamSign", V(20, 1.4, 0.3), V(-73, 12, -24.3), C.Charcoal, M.SmoothPlastic, DECO)
	Build.text(camSign, Enum.NormalId.Back, "HOME SECURITY", { Color = C.OffWhite, Font = Enum.Font.Michroma })
	f:box("CamShelf", V(34, 0.3, 1.6), V(-73, 8.3, -24.6), C.Charcoal, M.Metal, DECO)
	-- counter
	P.Counter(f:at(-46, 0, 30, 90), rng, 12, C.Charcoal, C.Navy)
	P.Register(f:at(-46.5, 3.6, 27, 90), rng, true)
	I.Drawer(f, V(-45.2, 3.1, 27), V(-1.2, 0, 0), zone)
	R.CRT(f:at(-47, 3.6, 33, 90), rng, true)
	P.BoxStack(f:at(-40, 0, 36), rng, 3)
	P.Litter(f:at(-60, 0, 0), rng, 12, 14)
	R.ShoppingBag(f:at(-50, 0, -6), rng, C.Navy)
	P.Poster(f:at(-60, 7, 39.6), rng, "PHONE X", "PRE-ORDER NOW", C.Navy)
	P.Poster(f:at(-68, 7, -23.8, 180), rng, "BLACK FRIDAY", "DOORS OPEN 5AM", C.Black)

	-- back office (x -100..-86, z 20..40)
	f:wallZ("OfficeWall", 20, 40, -86, 16, 1, C.OffWhite, M.Plaster, { { Center = 25, Width = 4, Top = 8.5 } })
	f:wallX("OfficeWall", -100, -86, 20, 16, 1, C.OffWhite, M.Plaster)
	U.Desk(f:at(-93, 0, 36, 180), rng, 7)
	R.Computer(f:at(-93, 3.35, 37, 180), rng, true, "BACKUP FAILED\nCAM 07 · CAM 08")
	U.OfficeChair(f:at(-93, 0, 33), rng, true)
	U.FilingCabinet(f:at(-98.5, 0, 24, -90), rng)
	P.BoxStack(f:at(-90, 0, 23), rng, 2)
	I.DoorInOpening(ctx.Interact:at(-100, 0, 30, 90), 5, 8.5, "Metal", C.Steel, M.Metal, zone, false, false, "STAFF")

	ctx:dropCeiling(f, zone, -100, -32, -26, 40, 16, { Dead = 0.45, Flicker = 0.2, LightColor = C.ColdLight })
	P.EmergencyLight(f:at(-33, 12, -20, 90), rng, true)
	P.ExitSign(f:at(-86.5, 10, 25, 90), rng)
	P.FireExtinguisher(f:at(-99.4, 0, -20, -90), rng)
	for _, z in ipairs({ -18, 0, 20, 32 }) do
		ctx:floorNode("Floor", zone, V(rng:Range(-85, -50), 0, z), V(rng:Range(-1, 1), 0, rng:Range(-1, 1)))
	end
	ctx:floorNode("TVWall", zone, V(-90, 0, 0), V(-1, 0, 0))
	ctx:floorNode("Dark", zone, V(-96, 0, 30), V(1, 0, 0))
	ctx:pickup(V(-58, 3.6, 6))
	ctx:pickup(V(-94, 3.6, 36))
end

---------------------------------------------------------------------------

local function clothing(ctx)
	local rng = ctx.Rng
	local P, R, U, I = ctx.Props.Common, ctx.Props.Retail, ctx.Props.Utility, ctx.I
	local f = ctx:area("Clothing")
	local zone = "Clothing"

	storefront(ctx, f, 52, 110, 12, "NOIR & CO.", C.NeonPink, "Dead", Enum.Font.Bodoni)
	P.GlassFront(f:at(-32, 0, 61, 90), rng, 18, 12)
	P.GlassFront(f:at(-32, 0, 101, 90), rng, 18, 12, true)
	-- window displays with mannequins
	for _, z in ipairs({ 61, 101 }) do
		f:box("DisplayPlatform", V(8, 1, 16), V(-37, 0.5, z), C.Charcoal, M.Marble)
		for k = -1, 1 do
			R.Mannequin(f:at(-37 + rng:Range(-1, 1), 1, z + k * 5, -90 + rng:Range(-30, 30)), rng, rng:Pick({ "Stand", "Wave", "Point", "Stand" }), nil, true)
		end
		local spot = f:box("DisplaySpot", V(1, 0.5, 1), V(-37, 11.6, z), C.WarmLight, M.Neon, DECO)
		Build.spot(spot, Enum.NormalId.Bottom, C.WarmLight, if z == 61 then 1.4 else 0, 16, 60)
	end
	for _, z in ipairs({ 74, 88 }) do
		f:box("SecurityGate", V(1.6, 5, 0.4), V(-34, 2.5, z), C.LightGray, M.SmoothPlastic)
	end

	-- racks
	for gx = 0, 2 do
		for gz = 0, 2 do
			local x = -84 + gx * 14
			local z = 58 + gz * 16
			if gx == 1 and gz == 1 then
				-- central mannequin island (Mannequin Group anomaly lives here)
				f:box("Island", V(10, 1, 10), V(x, 0.5, z), C.OffWhite, M.Marble)
				for k = 0, 3 do
					local a = k * 90 + rng:Range(-20, 20)
					local offset = CFrame.Angles(0, math.rad(a), 0) * CFrame.new(0, 0, -2.6)
					R.Mannequin(f:rel(CFrame.new(x, 1, z) * offset * CFrame.Angles(0, math.rad(rng:Range(-30, 30)), 0)), rng, rng:Pick({ "Stand", "Turn", "Point" }), nil, true)
				end
				ctx:floorNode("MannequinGroup", zone, V(x, 0, z), V(1, 0, 0))
			elseif rng:Chance(0.5) then
				R.ClothesRack(f:at(x, 0, z, rng:Range(-10, 10)), rng, nil, true, rng:Chance(0.12))
			else
				R.ClothesRack(f:at(x, 0, z, if rng:Chance(0.5) then 0 else 90), rng, 7, false, rng:Chance(0.15))
			end
		end
	end
	R.FoldedTable(f:at(-50, 0, 60), rng)
	R.FoldedTable(f:at(-50, 0, 102), rng)
	-- clothes on the floor
	for _ = 1, 14 do
		f:box("DroppedClothes", V(rng:Range(1, 2), 0.15, rng:Range(1, 1.8)), CFrame.new(rng:Range(-95, -40), 0.08, rng:Range(48, 114)) * Build.yaw(rng:Range(0, 360)), Build.vary(rng, rng:Pick({ C.DarkRed, C.Navy, C.Cream, C.Charcoal }), 0.1), M.Fabric, DECO)
	end
	R.Mannequin(f:rel(CFrame.new(-62, 1, 86) * CFrame.Angles(math.rad(-88), 0.4, 0)), rng, "Stand", nil, true)
	-- wall shelving (south wall) with folded stacks
	for i = 0, 4 do
		local x = -94 + i * 12
		f:box("WallShelf", V(10, 0.3, 2), V(x, 4, 45.2), C.WoodDark, M.WoodPlanks, DECO)
		f:box("WallShelf", V(10, 0.3, 2), V(x, 7, 45.2), C.WoodDark, M.WoodPlanks, DECO)
		for k = 0, 3 do
			if rng:Chance(0.7) then
				local color = rng:Pick({ C.DarkRed, C.Navy, C.OffWhite, C.Charcoal, C.Mustard })
				for s = 1, rng:Int(1, 3) do
					f:box("Folded", V(2, 0.28, 1.4), V(x - 3.6 + k * 2.4, 4.3 + s * 0.3, 45.2), Build.vary(rng, color, 0.05), M.Fabric, DECO)
				end
			end
		end
	end
	-- changing rooms + mirrors
	R.ChangingRooms(f:at(-72, 0, 114, 0), rng, 4)
	R.Mirror(f:at(-99.4, 0, 70, -90), rng, 6, 9, true)
	R.Mirror(f:at(-60, 0, 44.6, 180), rng, 4, 8)
	-- cash counter
	P.Counter(f:at(-46, 0, 84, 90), rng, 14, C.Charcoal, C.Charcoal)
	P.Register(f:at(-46.5, 3.6, 80, 90), rng)
	I.Drawer(f, V(-45.2, 3.1, 80), V(-1.2, 0, 0), zone)
	R.ShoppingBag(f:at(-44, 3.6, 88), rng, C.Black)
	P.Poster(f:at(-99.6, 8, 90, -90), rng, "NOIR", "THE FALL COLLECTION", C.Black)
	P.Poster(f:at(-60, 8, 117.6), rng, "FINAL SALE", "NO RETURNS", C.DarkRed, true)

	-- storage room (x -100..-84, z 96..118)
	f:wallZ("StorageWall", 96, 118, -84, 16, 1, C.OffWhite, M.Plaster, { { Center = 102, Width = 4.5, Top = 8.5 } })
	f:wallX("StorageWall", -100, -84, 96, 16, 1, C.OffWhite, M.Plaster)
	U.MetalShelf(f:at(-97.5, 0, 107, -90), rng, 12, 9)
	P.BoxStack(f:at(-88, 0, 114), rng, 4)
	P.Box(f:at(-90, 0, 100), rng, nil, true)
	R.Mannequin(f:at(-92, 0, 112, 160), rng, "Torso", nil, false)
	R.Mannequin(f:at(-88.5, 0, 108, 200), rng, "Stand", C.Cream, false)
	I.DoorInOpening(ctx.Interact:at(-100, 0, 110, 90), 5, 8.5, "Metal", C.Steel, M.Metal, zone, false, false, "STAFF")
	ctx:floorNode("Dark", zone, V(-92, 0, 104), V(1, 0, 0))

	ctx:dropCeiling(f, zone, -100, -32, 44, 118, 16, { Dead = 0.5, Flicker = 0.2, LightColor = C.WarmLight, Brightness = 0.8 })
	P.EmergencyLight(f:at(-33, 12, 112, 90), rng, false)
	P.ExitSign(f:at(-84.5, 10, 102, 90), rng)
	P.SecurityCamera(f:at(-98.5, 15, 46, -135), rng)
	for _, z in ipairs({ 50, 68, 94, 110 }) do
		ctx:floorNode("Floor", zone, V(rng:Range(-80, -45), 0, z), V(rng:Range(-1, 1), 0, rng:Range(-1, 1)))
	end
	ctx:floorNode("Mirror", zone, V(-97, 0, 70), V(1, 0, 0))
	ctx:floorNode("ChangingRoom", zone, V(-72, 0, 110), V(0, 0, -1))
	ctx:pickup(V(-50, 3.8, 102))
	ctx:pickup(V(-90, 0.6, 112))
end

---------------------------------------------------------------------------

local function restrooms(ctx)
	local rng = ctx.Rng
	local P, R, U, I = ctx.Props.Common, ctx.Props.Retail, ctx.Props.Utility, ctx.I
	local f = ctx:area("Restrooms")
	local zone = "Restrooms"
	local tile = Build.rgb(150, 176, 172)

	local sign = f:box("RestroomSign", V(0.3, 1.6, 8), V(-31.3, 11, 136), C.Navy, M.SmoothPlastic, DECO)
	Build.text(sign, Enum.NormalId.Right, "🚻 RESTROOMS", { Color = C.OffWhite, Font = Enum.Font.GothamBold })

	-- lobby (x -60..-32)
	f:wallZ("RestroomWall", 122, 150, -60, 12, 1, tile, M.SmoothPlastic, { { Center = 129, Width = 4.5, Top = 8.5 }, { Center = 143, Width = 4.5, Top = 8.5 } })
	U.WaterCooler(f:at(-40, 0, 123.5, 180), rng)
	P.Bench(f:at(-44, 0, 148.4, 0), rng, 6)
	P.TrashCan(f:at(-36, 0, 148), rng)
	local directions = f:box("Directions", V(0.2, 2.6, 8), V(-59.3, 9.8, 136), C.Charcoal, M.SmoothPlastic, DECO)
	Build.text(directions, Enum.NormalId.Right, "← WOMEN   ·   MEN →", { Color = C.OffWhite, Font = Enum.Font.GothamBold })
	P.Graffiti(f:at(-59.4, 5, 131, -90), rng, "DONT LOOK IN THE MIRROR", 8, C.NeonRed)
	P.Stain(f:at(-48, 0, 138), rng, 5, C.Water)

	-- divider between the two rooms
	f:wallX("RestroomDivider", -100, -60, 136, 12, 1, tile, M.SmoothPlastic)
	local signs = { { 129, "WOMEN" }, { 143, "MEN" } }
	for _, s in ipairs(signs) do
		local plate = f:box("DoorSign", V(0.2, 1.2, 2.4), V(-59.4, 9.6, s[1]), C.Navy, M.SmoothPlastic, DECO)
		Build.text(plate, Enum.NormalId.Right, s[2], { Color = C.OffWhite, Font = Enum.Font.GothamBold })
	end
	I.DoorInOpening(ctx.Interact:at(-60, 0, 129, 90), 4.5, 8.5, "Wood", Build.rgb(118, 84, 60), M.Wood, zone)
	I.DoorInOpening(ctx.Interact:at(-60, 0, 143, 90), 4.5, 8.5, "Wood", Build.rgb(118, 84, 60), M.Wood, zone)

	-- women's (z 122..136)
	U.Stalls(f:at(-86, 0, 125.6, 180), rng, 4, Build.rgb(170, 120, 130))
	U.SinkCounter(f:at(-76, 0, 133.8, 0), rng, 3)
	R.Mirror(f:at(-76, 3.4, 135.4, 0), rng, 12, 4.5, true)
	U.HandDryer(f:at(-64, 5, 135.3), rng)
	P.Graffiti(f:at(-99.4, 6, 130, -90), rng, "SHE IS STILL HERE", 7)

	-- men's (z 136..150)
	U.Stalls(f:at(-86, 0, 146.4, 0), rng, 3, tile)
	U.Urinals(f:at(-74, 0, 136.8, 180), rng, 3)
	U.SinkCounter(f:at(-66, 0, 148.6, 0), rng, 1)
	R.Mirror(f:at(-66, 3.4, 149.4, 0), rng, 3.6, 4.5)
	U.HandDryer(f:at(-62, 5, 149.4), rng)
	P.Graffiti(f:at(-86, 7, 149.4), rng, "3:07", 4, C.NeonGreen)
	P.Puddle(f:at(-80, 0, 142), rng, 6)
	I.DoorInOpening(ctx.Interact:at(-100, 0, 143, 90), 4.5, 8.5, "Metal", C.Steel, M.Metal, zone, false, false, "MAINTENANCE")

	ctx:dropCeiling(f, zone, -100, -32, 122, 150, 12, { Dead = 0.4, Flicker = 0.4, Hanging = 0.15, LightColor = C.SickLight, Brightness = 0.7, Range = 16, NodeSpacing = 12 })
	for _, spot in ipairs({ { -80, 129 }, { -80, 143 }, { -45, 136 } }) do
		ctx:floorNode("Floor", zone, V(spot[1], 0, spot[2]), V(1, 0, 0))
	end
	ctx:floorNode("Mirror", zone, V(-76, 0, 131), V(0, 0, 1))
	ctx:floorNode("Mirror", zone, V(-66, 0, 145), V(0, 0, 1))
	ctx:floorNode("Stall", zone, V(-90, 0, 126), V(0, 0, 1))
	ctx:pickup(V(-40, 3.8, 124))
end

function WestWing.Build(ctx)
	supermarket(ctx)
	electronics(ctx)
	clothing(ctx)
	restrooms(ctx)
end

return WestWing
