--[[
	Mall.GrandHall (ModuleScript)
	Location: ServerScriptService/World/Mall/GrandHall

	The central atrium: marble floor with inlays, upper balconies at y 16
	with glass railings, two bridges, an escalator pair, the fountain, the
	founder statue, abandoned kiosks, benches, lamp posts, an elevator that
	never comes, closed upper-level shops, banners, trusses and the long
	skylight (moonlight). Storefront signage is built by each store module.
]]

local World = script.Parent.Parent
local Build = require(World.Build)

local C, M = Build.C, Build.M
local V = Vector3.new
local DECO = { deco = true }

local GrandHall = {}

local BALCONY_Y = 16
local ROOF_Y = 36

function GrandHall.Build(ctx)
	local rng = ctx.Rng
	local P, R, U = ctx.Props.Common, ctx.Props.Retail, ctx.Props.Utility
	local f = ctx:area("GrandHall")
	local zone = "GrandHall"

	-- floor inlays
	for z = -110, 140, 40 do
		f:box("Inlay", V(64, 0.04, 2), V(0, 0.02, z), Build.rgb(80, 70, 62), M.Marble, { deco = true, query = false })
	end
	for x = -26, 26, 13 do
		f:box("Inlay", V(0.6, 0.04, 280), V(x, 0.02, 10), Build.rgb(150, 140, 126), M.Marble, { deco = true, query = false })
	end
	f:cylY("Medallion", 0.05, 30, V(0, 0.03, -90), Build.rgb(96, 82, 66), M.Marble, { deco = true, query = false })

	-- balconies + walkway ceilings + railings + support columns
	for _, side in ipairs({ -1, 1 }) do
		local inner = side * 22
		local outer = side * 32
		local x0, x1 = math.min(inner, outer), math.max(inner, outer)
		f:slab("Balcony", x0, x1, -130, 150, BALCONY_Y, 1.2, C.OffWhite, M.Marble)
		f:box("BalconyFascia", V(0.8, 2.2, 280), V(inner, BALCONY_Y - 1.1, 10), C.LightGray, M.Plaster)
		P.Railing(f:at(inner, BALCONY_Y, 10, 90), rng, 280, true)
		for z = -118, 142, 24 do
			P.Column(f:at(inner - side * 0.8, 0, z), rng, BALCONY_Y - 1.2, 2.2, C.LightGray)
		end
		-- downlights under the balcony (walkway along the storefronts)
		for z = -122, 148, 12 do
			local state = if rng:Chance(0.45) then "Dead" elseif rng:Chance(0.25) then "Flicker" else "On"
			P.CeilingLight(f:at((inner + outer) / 2, BALCONY_Y - 1.2, z, 90), rng, zone, 0.8, 18, state, C.WarmLight)
		end
		ctx:ceilingNodes(zone, x0 + 1, x1 - 1, -128, 148, BALCONY_Y - 1.2, 14)
		-- balcony-level floor nodes
		for z = -110, 140, 30 do
			ctx:floorNode("Balcony", zone, V((inner + outer) / 2, BALCONY_Y, z), V(-side, 0, 0))
		end
	end

	-- bridges
	for _, zc in ipairs({ -50, 60 }) do
		f:slab("Bridge", -22, 22, zc - 4, zc + 4, BALCONY_Y, 1.2, C.OffWhite, M.Marble)
		f:box("BridgeFascia", V(44, 2.2, 0.8), V(0, BALCONY_Y - 1.1, zc - 4), C.LightGray, M.Plaster)
		f:box("BridgeFascia", V(44, 2.2, 0.8), V(0, BALCONY_Y - 1.1, zc + 4), C.LightGray, M.Plaster)
		P.Railing(f:at(0, BALCONY_Y, zc - 4), rng, 44, true)
		P.Railing(f:at(0, BALCONY_Y, zc + 4), rng, 44, true)
		ctx:ceilingNodes(zone, -20, 20, zc - 3, zc + 3, BALCONY_Y - 1.2, 10)
	end
	-- hanging clock under the south bridge (Reverse Clock anomaly fixture)
	f:box("ClockRod", V(0.2, 3, 0.2), V(0, BALCONY_Y - 2.7, -50), C.Charcoal, M.Metal, DECO)
	P.Clock(f:at(0, BALCONY_Y - 5, -54.1), rng, 3.4)
	P.Clock(f:at(0, BALCONY_Y - 5, -45.9, 180), rng, 3.4)

	-- escalators (north bound up to the north bridge, landing at z 56)
	U.Escalator(f:at(-6.5, 0, 26, 180), rng, BALCONY_Y, 28, "Up")
	U.Escalator(f:at(6.5, 0, 26, 180), rng, BALCONY_Y, 28, "Down")
	f:box("EscalatorDivider", V(2, 1, 30), V(0, 0.5, 40), C.Charcoal, M.Metal)
	P.Plant(f:at(-12, 0, 22), rng, true, 1.2)
	P.Plant(f:at(12, 0, 22), rng, false, 1.2)

	-- fountain + medallion area
	U.Fountain(f:at(0, 0, -90), rng, 18)
	for _, a in ipairs({ 0, 90, 180, 270 }) do
		local cf = CFrame.Angles(0, math.rad(a), 0) * CFrame.new(0, 0, -14)
		P.Bench(f:rel(CFrame.new(0, 0, -90) * cf * CFrame.Angles(0, math.pi, 0)), rng, 7)
	end

	-- statue near the food court
	P.Statue(f:at(0, 0, 118), rng, "H. OAKRIDGE · FOUNDER · 1987")

	-- kiosks
	P.Kiosk(f:at(0, 0, -18), rng, "SUNGLASS SHACK", C.Teal, true)
	P.Kiosk(f:at(0, 0, 88), rng, "CASE CITY", C.Purple, false)
	P.Litter(f:at(0, 0, 82), rng, 6, 12)
	R.Cart(f:at(-14, 0, -30, 30), rng, true)

	-- benches, planters, lamps, trash along the hall
	for _, z in ipairs({ -118, -60, 5, 70, 136 }) do
		P.Planter(f:at(-13, 0, z), rng, 6, 10, rng:Chance(0.7))
		P.Planter(f:at(13, 0, z), rng, 6, 10, rng:Chance(0.7))
	end
	for _, z in ipairs({ -104, -36, 14, 100 }) do
		P.Bench(f:at(-14, 0, z, 90), rng)
		P.Bench(f:at(14, 0, z, -90), rng)
	end
	for _, z in ipairs({ -126, -70, -10, 44, 104, 146 }) do
		P.MallLamp(f:at(if z % 2 == 0 then -17 else 17, 0, z), rng, rng:Chance(0.4))
	end
	for _, z in ipairs({ -112, -44, 30, 96 }) do
		P.TrashCan(f:at(-19, 0, z), rng, rng:Chance(0.3))
		P.TrashCan(f:at(19, 0, z + 12), rng, rng:Chance(0.3))
	end
	P.WetFloorSign(f:at(-6, 0, -64), rng, true)
	P.CeilingPanelFallen(f:at(-26, 0, 20), rng)
	P.Litter(f:at(8, 0, -40), rng, 10, 16)
	P.Litter(f:at(-10, 0, 120), rng, 10, 12)
	P.Puddle(f:at(4, 0, 32), rng, 7)
	P.Puddle(f:at(-8, 0, -122), rng, 5)
	for _ = 1, 4 do
		R.ShoppingBag(f:at(rng:Range(-20, 20), 0, rng:Range(-120, 140)), rng)
	end

	-- elevator shaft at the south end
	f:box("ElevatorShaft", V(10, ROOF_Y, 8), V(0, ROOF_Y / 2, -125), Build.rgb(80, 82, 86), M.Metal)
	U.ElevatorDoors(f:at(0, 0, -120.7, 180), rng, "▼ 2")
	U.ElevatorDoors(f:at(0, BALCONY_Y, -120.7, 180), rng, "?")
	f:slab("ElevatorLanding", -6, 6, -121, -117, BALCONY_Y, 1.2, C.OffWhite, M.Marble)

	-- closed upper-level shops (balcony facades)
	local upper = {
		{ -1, -95, "LUXE BEAUTY", C.Pink }, { -1, -20, "OPTIX", C.Blue }, { -1, 40, "GOLDLEAF JEWELRY", C.Mustard }, { -1, 110, "SOLE STREET", C.DarkRed },
		{ 1, -100, "GAMEVAULT", C.Purple }, { 1, -15, "CAFÉ LUNA", C.Tan }, { 1, 30, "PET PALACE", C.Green }, { 1, 105, "PHOTO LAB", C.Navy },
	}
	for _, shop in ipairs(upper) do
		local side, z, name, color = shop[1], shop[2], shop[3], shop[4]
		local x = side * 31.4
		P.Shutter(f:at(x, BALCONY_Y, z, if side < 0 then -90 else 90), rng, 16, 9, if rng:Chance(0.2) then 0.3 else 0)
		-- most upper-level signs are dead; a few still buzz
		P.NeonSign(f:at(x, BALCONY_Y + 12, z, if side < 0 then -90 else 90), rng, name, 14, color, rng:Chance(0.5), Enum.Font.GothamBold, not rng:Chance(0.3))
	end
	P.Painting(f:at(-31.3, BALCONY_Y + 5.5, 72, -90), rng, "EVENING FIELD")
	P.Painting(f:at(31.3, BALCONY_Y + 5.5, -64, 90), rng, "THE FAMILY")
	P.Poster(f:at(-31.4, BALCONY_Y + 5, -60, -90), rng, "GRAND OPENING", "OAKRIDGE · 1987", C.DarkRed, true)

	-- hanging banners
	for _, banner in ipairs({ { -30, "EVERYTHING MUST GO", C.DarkRed }, { 20, "GRAND SALE", C.Navy }, { 110, "THANK YOU FOR 30 YEARS", C.Mustard } }) do
		local z, text, color = banner[1], banner[2], banner[3]
		local cloth = f:box("Banner", V(0.15, 10, 5), CFrame.new(rng:Range(-4, 4), 27, z) * CFrame.Angles(0, 0, math.rad(rng:Range(-4, 4))), color, M.Fabric, DECO)
		Build.text(cloth, Enum.NormalId.Left, text, { Color = C.OffWhite, Font = Enum.Font.GothamBlack, Rotation = 90 })
		Build.text(cloth, Enum.NormalId.Right, text, { Color = C.OffWhite, Font = Enum.Font.GothamBlack, Rotation = -90 })
		f:box("BannerWire", V(0.08, 4, 0.08), V(0, 34, z), C.Charcoal, M.Metal, DECO)
	end

	-- roof: solid sides + long skylight + trusses
	f:slab("Roof", -32, -12, -130, 150, ROOF_Y, 1.5, C.DarkGray, M.Concrete, nil, true)
	f:slab("Roof", 12, 32, -130, 150, ROOF_Y, 1.5, C.DarkGray, M.Concrete, nil, true)
	f:slab("Roof", -12, 12, -130, -122, ROOF_Y, 1.5, C.DarkGray, M.Concrete, nil, true)
	f:slab("Roof", -12, 12, 142, 150, ROOF_Y, 1.5, C.DarkGray, M.Concrete, nil, true)
	U.Skylight(f:at(0, ROOF_Y + 0.4, 10), rng, 24, 264)
	for z = -120, 140, 20 do
		f:box("Truss", V(64, 1.6, 1.2), V(0, ROOF_Y - 1.2, z), C.Charcoal, M.Metal, DECO)
		for x = -28, 28, 8 do
			f:rod("TrussWeb", V(x, ROOF_Y - 2, z), V(x + 4, ROOF_Y - 0.4, z), 0.35, C.Charcoal, M.Metal, DECO)
		end
	end
	-- moonlight through the skylight + a few dust columns
	for z = -110, 140, 50 do
		local moon = f:box("Moonlight", V(1, 1, 1), V(0, ROOF_Y - 2.5, z), C.Black, M.SmoothPlastic, { deco = true, t = 1, query = false })
		Build.spot(moon, Enum.NormalId.Bottom, Build.rgb(150, 170, 220), 1.4, 46, 50)
	end
	P.Dust(f:at(0, 0, -20), rng, V(20, 30, 40))
	P.Dust(f:at(0, 0, 100), rng, V(20, 30, 40))
	-- truss ceiling nodes (the crawler can hang from the roof structure)
	for z = -120, 140, 20 do
		for _, x in ipairs({ -24, -14, 14, 24 }) do
			ctx:ceilingNode(zone, V(x, ROOF_Y - 2.4, z))
		end
	end

	-- emergency lighting, cameras, exits
	for _, z in ipairs({ -100, -20, 60, 130 }) do
		P.EmergencyLight(f:at(-31.3, 12.5, z + 8, -90), rng, rng:Chance(0.6))
		P.EmergencyLight(f:at(31.3, 12.5, z - 8, 90), rng, rng:Chance(0.6))
	end
	for _, spot in ipairs({ { -21.5, -100, 45 }, { 21.5, -10, -135 }, { -21.5, 80, 135 }, { 21.5, 140, -45 } }) do
		P.SecurityCamera(f:at(spot[1], BALCONY_Y - 1.4, spot[2], spot[3]), rng)
	end
	P.FireExtinguisher(f:at(-31.4, 0, -122, -90), rng)
	P.FireExtinguisher(f:at(31.4, 0, 118, 90), rng)

	-- anomaly spawn markers
	for _, z in ipairs({ -120, -100, -70, -40, -5, 35, 75, 110, 140 }) do
		ctx:floorNode("Floor", zone, V(rng:Range(-10, 10), 0, z), V(rng:Range(-1, 1), 0, rng:Range(-1, 1)))
	end
	for _, z in ipairs({ -115, -55, 25, 95, 145 }) do
		ctx:floorNode("Dark", zone, V(-27, 0, z), V(1, 0, 0))
		ctx:floorNode("Dark", zone, V(27, 0, z + 10), V(-1, 0, 0))
	end
	ctx:floorNode("RunLane", zone, V(-26, 0, -120), V(0, 0, 1), { Length = 250 })
	ctx:floorNode("RunLane", zone, V(26, 0, 140), V(0, 0, -1), { Length = 250 })
	ctx:floorNode("Skylight", zone, V(0, ROOF_Y + 1, 30), V(0, -1, 0))
	ctx:floorNode("Skylight", zone, V(0, ROOF_Y + 1, -80), V(0, -1, 0))
	ctx:floorNode("Escalator", zone, V(-6.5, 0, 22), V(0, 0, 1))
	ctx:floorNode("Statue", zone, V(0, 0, 112), V(0, 0, -1))
	for _, z in ipairs({ -80, 0, 80 }) do
		ctx:pickup(V(rng:Range(-8, 8), 2.4, z + rng:Range(-10, 10)))
	end
	ctx:pickup(V(28, BALCONY_Y + 0.6, -30))
	ctx:pickup(V(-28, BALCONY_Y + 0.6, 100))
end

return GrandHall
