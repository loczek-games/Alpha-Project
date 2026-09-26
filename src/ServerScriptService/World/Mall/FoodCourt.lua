--[[
	Mall.FoodCourt (ModuleScript)
	Location: ServerScriptService/World/Mall/FoodCourt

	FOOD COURT: five complete restaurants along the north side (counter,
	menu boards, kitchen, appliances, back room with a door to the service
	hall), seating with tables/booths/tray returns, an old carousel under a
	glass dome and pendant lights.
]]

local World = script.Parent.Parent
local Build = require(World.Build)

local C, M = Build.C, Build.M
local V = Vector3.new
local DECO = { deco = true }
local FRONT = Enum.NormalId.Front

local FoodCourt = {}

local FRONT_Z = 212
local KITCHEN_Z = 232
local BACK_Z = 244

local RESTAURANTS = {
	{
		Id = "Burger", X = { -100, -60 }, Name = "BIG BITE BURGERS", Color = C.NeonRed, Accent = C.Red, Font = Enum.Font.Bangers,
		Menu = { "CLASSIC BURGER  4.99", "DOUBLE BITE  6.49", "CHEESE FRIES  2.99", "CHICKEN BITES  3.99", "SHAKE  2.49", "KIDS MEAL  3.49" },
	},
	{
		Id = "Pizza", X = { -60, -20 }, Name = "PAPA'S PIZZA", Color = C.NeonGreen, Accent = C.DarkGreen, Font = Enum.Font.Fondamento,
		Menu = { "CHEESE SLICE  2.50", "PEPPERONI  2.99", "SUPREME  3.49", "GARLIC KNOTS  1.99", "COMBO  5.99" },
	},
	{
		Id = "Coffee", X = { -20, 20 }, Name = "BEAN THERE CAFÉ", Color = C.NeonOrange, Accent = C.WoodDark, Font = Enum.Font.Merriweather,
		Menu = { "ESPRESSO  1.99", "LATTE  3.49", "MOCHA  3.79", "CROISSANT  2.29", "MUFFIN  1.99" },
	},
	{
		Id = "Wok", X = { 20, 60 }, Name = "GOLDEN WOK", Color = C.NeonYellow, Accent = C.DarkRed, Font = Enum.Font.GothamBlack,
		Menu = { "ORANGE CHICKEN  5.99", "LO MEIN  4.99", "FRIED RICE  3.99", "SPRING ROLL  1.49", "COMBO PLATE  7.49" },
	},
	{
		Id = "IceCream", X = { 60, 100 }, Name = "FROSTY'S", Color = C.NeonCyan, Accent = C.Pink, Font = Enum.Font.FredokaOne,
		Menu = { "1 SCOOP  2.49", "2 SCOOPS  3.99", "SUNDAE  4.49", "MILKSHAKE  3.49", "SPRINKLES  0.50" },
	},
}

local function restaurant(ctx, spec)
	local rng = ctx.Rng
	local P, R, F, U, I = ctx.Props.Common, ctx.Props.Retail, ctx.Props.Food, ctx.Props.Utility, ctx.I
	local f = ctx:area("Restaurant_" .. spec.Id)
	local zone = "FoodCourt"
	local x0, x1 = spec.X[1], spec.X[2]
	local xc = (x0 + x1) / 2
	local working = rng:Chance(0.45)

	-- front facade: service opening + big sign
	f:wallX("RestaurantFront", x0, x1, FRONT_Z, 30, 1, Build.shade(spec.Accent, -0.35), M.Plaster, { { Center = xc, Width = x1 - x0 - 6, Top = 11 } })
	P.NeonSign(f:at(xc, 15, FRONT_Z - 0.8), rng, spec.Name, x1 - x0 - 6, spec.Color, not working, spec.Font, not working and rng:Chance(0.5))
	f:box("Awning", V(x1 - x0 - 4, 0.4, 3), CFrame.new(xc, 11.3, FRONT_Z - 1.4) * CFrame.Angles(math.rad(-15), 0, 0), spec.Accent, M.Fabric, DECO)
	-- side walls, kitchen partition, ceilings
	if x0 > -100 then
		f:wallZ("RestaurantSide", FRONT_Z, BACK_Z, x0, 30, 1, C.DarkGray, M.Plaster)
	end
	f:wallX("KitchenWall", x0, x1, KITCHEN_Z, 12, 1, C.OffWhite, M.SmoothPlastic, { { Center = xc + 8, Width = 4.5, Top = 8.5 } })
	f:slab("KitchenCeiling", x0, x1, FRONT_Z, BACK_Z, 12, 1, C.OffWhite, M.Plaster, nil, true)
	f:box("KitchenBacksplash", V(x1 - x0 - 1.2, 5, 0.2), V(xc, 5.5, KITCHEN_Z - 0.6), Build.rgb(210, 214, 206), M.SmoothPlastic, DECO)

	-- counter (gap on the west end so staff can walk in)
	local counterLength = x1 - x0 - 12
	P.Counter(f:at(xc + 3, 0, FRONT_Z - 1.6), rng, counterLength, spec.Accent, C.Charcoal)
	for k = 0, 1 do
		P.Register(f:at(xc - 2 + k * 10, 3.6, FRONT_Z - 1.2), rng, rng:Chance(0.3))
	end
	I.Drawer(f, V(xc - 2, 3.1, FRONT_Z - 0.3), V(0, 0, 1.2), zone)
	F.MenuBoard(f:at(xc - 8, 8.6, KITCHEN_Z - 0.8), rng, 14, "MENU", spec.Menu, spec.Accent, working)
	F.MenuBoard(f:at(xc + 8, 8.6, KITCHEN_Z - 0.8), rng, 12, "SPECIALS", { "ASK INSIDE", "OPEN LATE", "?" }, spec.Accent, false)

	-- kitchen line
	if spec.Id == "Burger" then
		F.Grill(f:at(xc - 10, 0, KITCHEN_Z - 3), rng)
		F.Fryer(f:at(xc - 3, 0, KITCHEN_Z - 3), rng)
		F.Fryer(f:at(xc + 1, 0, KITCHEN_Z - 3), rng, true)
		F.SodaFountain(f:at(xc + 9, 3.6, FRONT_Z - 1.4, 180), rng)
		F.PrepTable(f:at(xc + 6, 0, KITCHEN_Z - 10), rng, 8)
		for _ = 1, 4 do
			F.FoodTray(f:at(xc + rng:Range(-6, 12), 3.62, FRONT_Z - 1.8, rng:Range(-20, 20)), rng)
		end
	elseif spec.Id == "Pizza" then
		F.PizzaOven(f:at(xc - 9, 0, KITCHEN_Z - 3.5), rng)
		F.PrepTable(f:at(xc + 4, 0, KITCHEN_Z - 3), rng, 10)
		for i = 0, 5 do
			f:box("PizzaBox", V(2.4, 0.4, 2.4), V(xc + 2 + (i % 3) * 2.6, 3.8 + math.floor(i / 3) * 0.42, KITCHEN_Z - 3), C.OffWhite, M.Cardboard, DECO)
		end
		for i = 0, 2 do
			f:cylY("PizzaTray", 0.1, 2.2, V(xc + 4 + i * 3, 3.7, FRONT_Z - 1.6), C.Chrome, M.Metal, DECO)
			f:cylY("Pizza", 0.12, 1.9, V(xc + 4 + i * 3, 3.8, FRONT_Z - 1.6), if i == 1 then C.DeadPlant else C.Mustard, M.SmoothPlastic, DECO)
		end
	elseif spec.Id == "Coffee" then
		F.EspressoMachine(f:at(xc + 6, 3.6, FRONT_Z - 1, 180), rng)
		F.IceCreamCase(f:at(xc - 6, 0, FRONT_Z - 1.6), rng, 6)
		F.PrepTable(f:at(xc, 0, KITCHEN_Z - 3), rng, 12)
		for i = 0, 5 do
			f:cylY("CupStack", 1.2, 0.5, V(xc - 4 + i * 0.7, 4.2, KITCHEN_Z - 3), C.OffWhite, M.SmoothPlastic, DECO)
		end
		-- wooden café deck in front of the counter (Wood footsteps)
		f:box("CafeDeck", V(40, 0.12, 14), V(xc, 0.06, 203), C.WoodLight, M.WoodPlanks, { attrs = { FootstepSurface = "Wood" } }).CastShadow = false
		for _, spot in ipairs({ { -12, 200 }, { 0, 198 }, { 12, 200 } }) do
			P.DiningSet(f:at(spot[1], 0.12, spot[2]), rng, C.WoodDark, true)
		end
		local chalk = f:box("Chalkboard", V(4, 5, 0.3), CFrame.new(xc - 16, 2.5, FRONT_Z - 3.5) * CFrame.Angles(math.rad(-10), 0, 0), C.Charcoal, M.Slate, DECO)
		Build.text(chalk, FRONT, "TODAY:\nPUMPKIN LATTE\n~ closing soon ~", { Color = C.OffWhite, Font = Enum.Font.IndieFlower })
	elseif spec.Id == "Wok" then
		F.WokStation(f:at(xc - 6, 0, KITCHEN_Z - 3), rng)
		F.PrepTable(f:at(xc + 9, 0, KITCHEN_Z - 3), rng, 8)
		for i = 0, 2 do
			f:cylY("RiceCooker", 1.2, 1.4, V(xc + 6 + i * 2, 4.2, KITCHEN_Z - 3), C.OffWhite, M.Plastic, DECO)
		end
		for i = 0, 3 do
			f:cylY("SteamTray", 0.5, 2.6, V(xc - 4 + i * 3, 3.85, FRONT_Z - 1.6), C.Chrome, M.Metal, DECO)
		end
		for i = 0, 3 do
			local lantern = f:ball("Lantern", 1.6, V(x0 + 6 + i * 9, 10, FRONT_Z - 3), C.Red, M.Fabric, DECO)
			if working and i % 2 == 0 then
				Build.point(lantern, C.NeonRed, 0.4, 10)
			end
			f:box("LanternCord", V(0.05, 1.6, 0.05), V(x0 + 6 + i * 9, 11.2, FRONT_Z - 3), C.Black, M.SmoothPlastic, DECO)
		end
	elseif spec.Id == "IceCream" then
		F.IceCreamCase(f:at(xc + 2, 0, FRONT_Z - 1.6), rng, 16)
		R.Freezer(f:at(xc - 8, 0, KITCHEN_Z - 3), rng, 2, working)
		local cone = f:box("ConeSign", V(3, 6, 0.3), V(x1 - 5, 5, FRONT_Z - 2.5), C.Void, M.SmoothPlastic, DECO)
		Build.text(cone, FRONT, "🍦", { Glow = true })
		for _ = 1, 20 do
			f:box("Sprinkle", V(0.25, 0.05, 0.08), CFrame.new(xc + rng:Range(-8, 8), 0.03, FRONT_Z - rng:Range(3, 8)) * Build.yaw(rng:Range(0, 360)), rng:Pick({ C.NeonPink, C.NeonCyan, C.NeonYellow }), M.SmoothPlastic, DECO)
		end
	end
	F.Fridge(f:at(x0 + 3.5, 0, KITCHEN_Z - 5, -90), rng, rng:Chance(0.4))
	f:box("Shelf", V(x1 - x0 - 6, 0.3, 1.6), V(xc, 8, KITCHEN_Z - 1.4), C.Chrome, M.Metal, DECO)
	for _ = 1, 3 do
		f:box("Pan", V(1.6, 0.3, 1.2), V(xc + rng:Range(-10, 10), 8.3, KITCHEN_Z - 1.4), C.Steel, M.Metal, DECO)
	end
	P.CeilingLight(f:at(xc - 8, 12, FRONT_Z + 10), rng, zone, 0.7, 18, if working then "On" else "Flicker", C.SickLight)
	P.CeilingLight(f:at(xc + 8, 12, FRONT_Z + 10), rng, zone, 0.7, 18, "Dead")

	-- back room
	for _ = 1, rng:Int(2, 4) do
		P.BoxStack(f:at(rng:Range(x0 + 3, x1 - 3), 0, rng:Range(KITCHEN_Z + 3, BACK_Z - 3)), rng)
	end
	P.TrashBag(f:at(x1 - 4, 0, BACK_Z - 3), rng)
	P.TrashBag(f:at(x1 - 6, 0, BACK_Z - 2.5), rng)
	P.Mop(f:at(x0 + 4, 0, BACK_Z - 3), rng)
	U.MetalShelf(f:at(xc - 6, 0, BACK_Z - 2, 0), rng, 8, 8)
	local backLight = f:box("BackRoomBulb", V(0.6, 0.6, 0.6), V(xc, 11.5, KITCHEN_Z + 6), C.WarmLight, M.Neon, { deco = true, tags = { "FlickerLight" } })
	Build.point(backLight, C.WarmLight, 0.5, 14):SetAttribute("BaseBrightness", 0.5)
	I.DoorInOpening(ctx.Interact:at(xc + 8, 0, KITCHEN_Z), 4.5, 8.5, "Metal", C.OffWhite, M.Metal, zone, false, true)
	I.DoorInOpening(ctx.Interact:at(xc, 0, BACK_Z), 5, 8.5, "Metal", C.Steel, M.Metal, zone, false, false, "EXIT")
	ctx:ceilingNodes(zone, x0 + 2, x1 - 2, FRONT_Z + 2, BACK_Z - 2, 12, 14)
	ctx:floorNode("Kitchen", zone, V(xc, 0, KITCHEN_Z - 7), V(0, 0, -1), { Restaurant = spec.Id })
	ctx:floorNode("Dark", zone, V(x0 + 4, 0, BACK_Z - 6), V(1, 0, 0))
	ctx:pickup(V(xc + rng:Range(-8, 8), 3.8, KITCHEN_Z - 3))
end

function FoodCourt.Build(ctx)
	local rng = ctx.Rng
	local P, U, F = ctx.Props.Common, ctx.Props.Utility, ctx.Props.Food
	local f = ctx:area("FoodCourt")
	local zone = "FoodCourt"

	for _, spec in ipairs(RESTAURANTS) do
		restaurant(ctx, spec)
	end

	-- seating
	local chairColors = { C.Red, C.Mustard, C.Teal, C.OffWhite }
	for gx = -4, 4 do
		for gz = 0, 3 do
			local x = gx * 18 + rng:Range(-2, 2)
			local z = 160 + gz * 11 + rng:Range(-1.5, 1.5)
			local nearCarousel = math.abs(x) < 22 and z > 166 and z < 196
			local cafeDeck = math.abs(x) < 20 and z > 194
			if not nearCarousel and not cafeDeck and rng:Chance(0.82) then
				P.DiningSet(f:at(x, 0, z, rng:Range(-15, 15)), rng, rng:Pick(chairColors), true)
			end
		end
	end
	for z = 158, 204, 9 do
		P.Booth(f:at(-97.6, 0, z, -90), rng, C.DarkRed, 6)
		P.Booth(f:at(97.6, 0, z, 90), rng, C.Navy, 6)
	end
	F.TrayReturn(f:at(-88, 0, 151.8, 180), rng)
	F.TrayReturn(f:at(88, 0, 151.8, 180), rng)
	for _, x in ipairs({ -70, -36, 36, 70 }) do
		P.TrashCan(f:at(x, 0, 153), rng, rng:Chance(0.35))
	end
	P.Planter(f:at(-50, 0, 207), rng, 10, 4, true)
	P.Planter(f:at(50, 0, 207), rng, 10, 4, true)
	P.Litter(f:at(-40, 0, 180), rng, 20, 24)
	P.Litter(f:at(40, 0, 170), rng, 20, 24)
	P.WetFloorSign(f:at(30, 0, 204), rng)
	P.Puddle(f:at(-8, 0, 176), rng, 8)
	P.CeilingPanelFallen(f:at(60, 0, 190), rng)

	-- carousel under the dome
	local carousel = f:model("Carousel")
	local model = carousel.Parent :: Model
	model:AddTag("Carousel")
	carousel:cylY("Platform", 1.2, 30, V(0, 0.6, 181), Build.rgb(120, 40, 50), M.WoodPlanks)
	carousel:cylY("Center", 16, 4, V(0, 9, 181), C.Mustard, M.Metal)
	carousel:cylY("Canopy", 1.5, 32, V(0, 17.5, 181), C.DarkRed, M.Fabric)
	carousel:cylY("Crown", 3, 10, V(0, 19.5, 181), C.Mustard, M.Metal, DECO)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local x, z = math.cos(a) * 11, 181 + math.sin(a) * 11
		carousel:cylY("Pole", 16, 0.4, V(x, 9, z), C.Chrome, M.Metal, DECO)
		ctx.Props.Retail.RockingHorse(carousel:rel(CFrame.new(x, 1.2 + (i % 2) * 1.2, z) * CFrame.Angles(0, -a, 0) * CFrame.new(0, 0, 1.2)), rng)
		local bulb = carousel:ball("CarouselBulb", 0.6, V(math.cos(a) * 15.6, 16.6, 181 + math.sin(a) * 15.6), if i % 3 == 0 then C.WarmLight else C.MidGray, if i % 3 == 0 then M.Neon else M.Glass, DECO)
		bulb.Name = "CarouselBulb"
	end
	local sign = carousel:box("CarouselSign", V(12, 2, 0.3), V(0, 22, 175.8), C.Void, M.SmoothPlastic, DECO)
	Build.text(sign, FRONT, "MERRY-GO-ROUND · 50¢", { Color = C.NeonYellow, Font = Enum.Font.Fondamento, Glow = true })
	ctx:floorNode("Carousel", zone, V(0, 1.2, 168), V(0, 0, 1))

	-- roof with a glass dome over the carousel
	f:slab("FoodRoof", -100, -30, 150, 212, 30, 1.5, C.DarkGray, M.Concrete, nil, true)
	f:slab("FoodRoof", 30, 100, 150, 212, 30, 1.5, C.DarkGray, M.Concrete, nil, true)
	f:slab("FoodRoof", -30, 30, 150, 160, 30, 1.5, C.DarkGray, M.Concrete, nil, true)
	f:slab("FoodRoof", -30, 30, 202, 212, 30, 1.5, C.DarkGray, M.Concrete, nil, true)
	U.Skylight(f:at(0, 30.4, 181), rng, 60, 42)
	for _, dz in ipairs({ -10, 10 }) do
		f:box("DomeRib", V(62, 1, 1), V(0, 31.5, 181 + dz), C.Charcoal, M.Metal, DECO)
	end
	local moon = f:box("Moonlight", V(1, 1, 1), V(0, 28, 181), C.Black, M.SmoothPlastic, { deco = true, t = 1, query = false })
	Build.spot(moon, Enum.NormalId.Bottom, Build.rgb(150, 170, 220), 1.6, 40, 70)
	-- pendant lights over the seating
	for x = -84, 84, 24 do
		for _, z in ipairs({ 158, 200 }) do
			f:box("PendantCord", V(0.08, 12, 0.08), V(x, 24, z), C.Black, M.SmoothPlastic, DECO)
			local on = rng:Chance(0.4)
			local shade = f:box("Pendant", V(3, 1.4, 3), V(x, 17.4, z), if on then C.WarmLight else C.Charcoal, if on then M.Neon else M.Metal, { deco = true, tags = if on and rng:Chance(0.4) then { "FlickerLight" } else nil })
			if on then
				Build.spot(shade, Enum.NormalId.Bottom, C.WarmLight, 1.2, 26, 80):SetAttribute("BaseBrightness", 1.2)
			end
		end
	end
	local hanging = f:box("FoodCourtSign", V(30, 4, 0.4), V(0, 26, 152), C.Navy, M.SmoothPlastic, DECO)
	Build.text(hanging, Enum.NormalId.Back, "FOOD COURT", { Color = C.OffWhite, Font = Enum.Font.GothamBlack })
	Build.text(hanging, FRONT, "FOOD COURT", { Color = C.OffWhite, Font = Enum.Font.GothamBlack })
	for z = 160, 208, 16 do
		for x = -90, 90, 30 do
			ctx:ceilingNode(zone, V(x, 29, z))
		end
	end
	P.EmergencyLight(f:at(-99.4, 14, 180, -90), rng, true)
	P.EmergencyLight(f:at(99.4, 14, 170, 90), rng, true)
	P.SecurityCamera(f:at(-98, 20, 152, -135), rng)
	P.SecurityCamera(f:at(98, 20, 152, 135), rng)
	P.Clock(f:at(0, 22, 150.7, 180), rng, 4)
	P.ExitSign(f:at(-99.3, 10, 200, -90), rng)
	P.ExitSign(f:at(99.3, 10, 200, 90), rng)
	ctx.I.DoorInOpening(ctx.Interact:at(-100, 0, 200, 90), 5, 8.5, "Metal", C.Steel, M.Metal, zone, false, false, "STAFF")
	ctx.I.DoorInOpening(ctx.Interact:at(100, 0, 200, 90), 5, 8.5, "Metal", C.Steel, M.Metal, zone, false, false, "STAFF")

	for _, spot in ipairs({ { -70, 160 }, { -40, 190 }, { 40, 160 }, { 75, 195 }, { -80, 205 }, { 20, 156 } }) do
		ctx:floorNode("Floor", zone, V(spot[1], 0, spot[2]), V(rng:Range(-1, 1), 0, rng:Range(-1, 1)))
	end
	ctx:floorNode("Table", zone, V(-54, 3.1, 171), V(0, 0, 1))
	ctx:floorNode("Table", zone, V(36, 3.1, 182), V(0, 0, 1))
	for _, x in ipairs({ -60, 0, 60 }) do
		ctx:pickup(V(x + rng:Range(-6, 6), 3.4, 165 + rng:Range(0, 30)))
	end
end

return FoodCourt
