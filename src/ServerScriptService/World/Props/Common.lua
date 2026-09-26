--[[
	Props.Common (ModuleScript)
	Location: ServerScriptService/World/Props/Common

	General purpose props used everywhere (mall + lobby). Every prop takes a
	Frame placed at the prop's base centre on the floor, facing -Z (the side
	a visitor looks at), plus the deterministic rng.
]]

local World = script.Parent.Parent
local Build = require(World.Build)

local C, M = Build.C, Build.M
local V = Vector3.new
local DECO = { deco = true }
local FRONT = Enum.NormalId.Front

local P = {}

---------------------------------------------------------------------------
-- seating & greenery
---------------------------------------------------------------------------

function P.Bench(f: Build.Frame, rng: any, length: number?)
	local m = f:model("Bench")
	local l = length or 8
	local wood = Build.vary(rng, C.Wood, 0.1)
	for i = 0, 3 do
		m:box("Slat", V(l, 0.25, 0.42), V(0, 1.9, -0.75 + i * 0.5), wood, M.WoodPlanks)
	end
	for i = 0, 2 do
		m:box("BackSlat", V(l, 0.42, 0.22), V(0, 2.6 + i * 0.55, 1.05), wood, M.WoodPlanks, DECO)
	end
	for _, x in ipairs({ -l / 2 + 0.6, l / 2 - 0.6 }) do
		m:box("Leg", V(0.35, 1.9, 2.3), V(x, 0.95, 0), C.Charcoal, M.Metal)
		m:box("BackPost", V(0.3, 2, 0.3), V(x, 2.8, 1.1), C.Charcoal, M.Metal, DECO)
	end
	return m
end

function P.Plant(f: Build.Frame, rng: any, dead: boolean?, scale: number?)
	local m = f:model("Plant")
	local s = scale or 1
	local green = if dead then Build.vary(rng, C.DeadPlant, 0.1) else Build.vary(rng, C.Plant, 0.1)
	m:cylY("Pot", 1.6 * s, 1.8 * s, V(0, 0.8 * s, 0), C.Charcoal, M.Slate, DECO)
	m:cylY("Soil", 0.1, 1.6 * s, V(0, 1.58 * s, 0), C.WoodDark, M.Ground, DECO)
	for i = 1, 5 do
		local angle = (i / 5) * math.pi * 2 + rng:Range(0, 0.6)
		local lean = rng:Range(0.25, 0.6)
		local leaf = m:box("Leaf", V(0.9 * s, 0.12, 2.6 * s), CFrame.new(0, 2.6 * s, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -0.9 * s) * CFrame.Angles(lean * (if dead then 2.2 else 1), 0, 0), green, M.Grass, DECO)
		leaf.Name = "Leaf"
	end
	m:cylY("Stem", 1.4 * s, 0.25, V(0, 2.2 * s, 0), C.DarkGreen, M.Wood, DECO)
	return m
end

function P.Planter(f: Build.Frame, rng: any, width: number, depth: number, dead: boolean?)
	local m = f:model("Planter")
	m:box("Box", V(width, 2.2, depth), V(0, 1.1, 0), C.LightGray, M.Concrete)
	m:box("Rim", V(width + 0.4, 0.3, depth + 0.4), V(0, 2.25, 0), C.MidGray, M.Concrete, DECO)
	m:box("Soil", V(width - 0.6, 0.2, depth - 0.6), V(0, 2.2, 0), C.WoodDark, M.Ground, DECO)
	local trees = math.max(1, math.floor(width * depth / 40))
	for i = 1, trees do
		local x = rng:Range(-width / 2 + 1.5, width / 2 - 1.5)
		local z = rng:Range(-depth / 2 + 1.5, depth / 2 - 1.5)
		local height = rng:Range(7, 11)
		m:cylY("Trunk", height, 0.6, V(x, 2.2 + height / 2, z), C.WoodDark, M.Wood, DECO)
		if dead then
			for b = 1, 4 do
				local y = 2.2 + height * rng:Range(0.55, 0.95)
				local angle = rng:Range(0, math.pi * 2)
				m:box("Branch", V(0.25, 0.25, rng:Range(2, 4)), CFrame.new(x, y, z) * CFrame.Angles(0, angle, 0) * CFrame.Angles(rng:Range(0.3, 0.9), 0, 0) * CFrame.new(0, 0, -1.2), C.WoodDark, M.Wood, DECO)
			end
		else
			m:ball("Canopy", rng:Range(5, 7), V(x, 2.2 + height, z), Build.vary(rng, C.Plant, 0.12), M.Grass, DECO)
		end
	end
	for i = 1, math.floor(width) do
		if rng:Chance(0.35) then
			m:box("Leaves", V(0.6, 0.05, 0.4), CFrame.new(rng:Range(-width / 2 + 0.6, width / 2 - 0.6), 2.32, rng:Range(-depth / 2 + 0.6, depth / 2 - 0.6)) * Build.yaw(rng:Range(0, 180)), C.DeadPlant, M.Grass, DECO)
		end
	end
	return m
end

---------------------------------------------------------------------------
-- trash & clutter
---------------------------------------------------------------------------

function P.TrashCan(f: Build.Frame, rng: any, tipped: boolean?)
	local m = f:model("TrashCan")
	local body = if tipped then CFrame.new(0, 1.2, 0) * CFrame.Angles(math.rad(90), 0, 0) else CFrame.new(0, 1.7, 0)
	local can = m:box("Body", V(2.2, 3.4, 2.2), body, C.DarkGray, M.Metal)
	can.Name = "Body"
	m:box("Lid", V(2.4, 0.4, 2.4), body * CFrame.new(0, 1.85, 0), C.Charcoal, M.Metal, DECO)
	m:box("Slot", V(1.4, 0.5, 0.1), body * CFrame.new(0, 1.2, -1.12), C.Black, M.SmoothPlastic, DECO)
	if tipped then
		for i = 1, 5 do
			m:box("Spill", V(rng:Range(0.4, 1.1), 0.08, rng:Range(0.4, 1.1)), CFrame.new(rng:Range(-1.5, 1.5), 0.05, -2 - rng:Range(0, 2.5)) * Build.yaw(rng:Range(0, 180)), rng:Pick({ C.Paper, C.Cardboard, C.OffWhite, C.Red }), M.SmoothPlastic, DECO)
		end
	end
	return m
end

function P.TrashBag(f: Build.Frame, rng: any)
	local m = f:model("TrashBag")
	local s = rng:Range(0.8, 1.2)
	m:ball("Bag", 2.4 * s, V(0, 1 * s, 0), C.Black, M.Plastic, DECO)
	m:ball("Knot", 0.7 * s, V(0, 2.1 * s, 0), C.Black, M.Plastic, DECO)
	return m
end

function P.Litter(f: Build.Frame, rng: any, radius: number, count: number)
	local m = f:model("Litter")
	for _ = 1, count do
		local kind = rng:Int(1, 5)
		local cf = CFrame.new(rng:Range(-radius, radius), 0.04, rng:Range(-radius, radius)) * Build.yaw(rng:Range(0, 360))
		if kind == 1 then
			m:box("Paper", V(0.9, 0.04, 1.2), cf, C.Paper, M.SmoothPlastic, DECO)
		elseif kind == 2 then
			m:cylY("Cup", 0.7, 0.45, (cf * CFrame.new(0, 0.3, 0)).Position, rng:Pick({ C.Red, C.OffWhite, C.Blue }), M.SmoothPlastic, DECO)
		elseif kind == 3 then
			m:box("Wrapper", V(0.6, 0.05, 0.4), cf, rng:Pick({ C.Yellow, C.Red, C.Orange }), M.Foil, DECO)
		elseif kind == 4 then
			m:box("Flyer", V(1.1, 0.03, 1.5), cf, rng:Pick({ C.Pink, C.Cream, C.Teal }), M.SmoothPlastic, DECO)
		else
			m:box("Box", V(1, 0.6, 0.7), cf * CFrame.new(0, 0.28, 0), C.Cardboard, M.Cardboard, DECO)
		end
	end
	return m
end

function P.Box(f: Build.Frame, rng: any, size: Vector3?, open: boolean?)
	local s = size or V(rng:Range(1.8, 3), rng:Range(1.4, 2.4), rng:Range(1.6, 2.6))
	local m = f:model("Box")
	local color = Build.vary(rng, C.Cardboard, 0.12)
	m:box("Carton", s, V(0, s.Y / 2, 0), color, M.Cardboard, if s.X * s.Y * s.Z < 8 then DECO else nil)
	m:box("Tape", V(s.X + 0.02, 0.05, 0.3), V(0, s.Y + 0.01, 0), C.Tan, M.SmoothPlastic, DECO)
	if open then
		m:box("Flap", V(s.X, 0.05, s.Z / 2), CFrame.new(0, s.Y, -s.Z / 2) * CFrame.Angles(math.rad(-110), 0, 0) * CFrame.new(0, 0, -s.Z / 4), color, M.Cardboard, DECO)
	end
	return m
end

function P.BoxStack(f: Build.Frame, rng: any, count: number?)
	local m = f:model("BoxStack")
	local y = 0
	for i = 1, count or rng:Int(2, 4) do
		local s = V(rng:Range(2.4, 3.2), rng:Range(1.6, 2.2), rng:Range(2.2, 2.8))
		m:box("Carton", s, CFrame.new(rng:Range(-0.25, 0.25), y + s.Y / 2, rng:Range(-0.25, 0.25)) * Build.yaw(rng:Range(-8, 8)), Build.vary(rng, C.Cardboard, 0.12), M.Cardboard, if i > 1 then DECO else nil)
		y += s.Y
	end
	return m
end

function P.Pallet(f: Build.Frame, rng: any)
	local m = f:model("Pallet")
	for i = -2, 2 do
		m:box("Board", V(4, 0.18, 0.7), V(0, 0.55, i * 0.9), C.WoodLight, M.WoodPlanks, DECO)
	end
	for _, x in ipairs({ -1.7, 0, 1.7 }) do
		m:box("Runner", V(0.5, 0.45, 4.2), V(x, 0.23, 0), C.Wood, M.WoodPlanks, DECO)
	end
	return m
end

function P.WetFloorSign(f: Build.Frame, rng: any, fallen: boolean?)
	local m = f:model("WetFloorSign")
	local base = if fallen then CFrame.new(0, 0.2, 0) * CFrame.Angles(math.rad(90), 0, 0) * CFrame.new(0, 1.3, 0) else CFrame.new(0, 1.3, 0)
	local front = m:box("Front", V(1.4, 2.6, 0.1), base * CFrame.new(0, 0, -0.4) * CFrame.Angles(math.rad(-12), 0, 0), C.Yellow, M.SmoothPlastic, DECO)
	m:box("Back", V(1.4, 2.6, 0.1), base * CFrame.new(0, 0, 0.4) * CFrame.Angles(math.rad(12), 0, 0), C.Yellow, M.SmoothPlastic, DECO)
	Build.text(front, FRONT, "⚠\nCAUTION\nWET FLOOR", { Color = C.Black, Font = Enum.Font.GothamBlack })
	return m
end

function P.BrokenGlass(f: Build.Frame, rng: any, radius: number, count: number)
	local m = f:model("BrokenGlass")
	for _ = 1, count do
		m:box("Shard", V(rng:Range(0.2, 1), 0.04, rng:Range(0.15, 0.6)), CFrame.new(rng:Range(-radius, radius), 0.03, rng:Range(-radius, radius)) * Build.yaw(rng:Range(0, 360)), C.Glass, M.Glass, { deco = true, t = 0.3, refl = 0.3, attrs = { FootstepSurface = "Glass" } })
	end
	return m
end

function P.Puddle(f: Build.Frame, rng: any, diameter: number)
	local m = f:model("Puddle")
	m:cylY("Water", 0.05, diameter, V(0, 0.03, 0), C.Water, M.Glass, { deco = true, t = 0.3, refl = 0.35, attrs = { FootstepSurface = "Water" } })
	m:cylY("Water", 0.05, diameter * 0.6, V(diameter * 0.3, 0.03, diameter * 0.15), C.Water, M.Glass, { deco = true, t = 0.3, refl = 0.35, attrs = { FootstepSurface = "Water" } })
	return m
end

function P.Stain(f: Build.Frame, rng: any, diameter: number, color: Color3?)
	local m = f:model("Stain")
	m:cylY("Stain", 0.03, diameter, V(0, 0.02, 0), color or C.Black, M.SmoothPlastic, { deco = true, t = 0.35, query = false })
	return m
end

---------------------------------------------------------------------------
-- tables & chairs
---------------------------------------------------------------------------

function P.Chair(f: Build.Frame, rng: any, color: Color3?, fallen: boolean?)
	local m = f:model("Chair")
	local seatColor = color or Build.vary(rng, C.Red, 0.1)
	local root = if fallen then CFrame.new(0, 1.1, 0) * CFrame.Angles(math.rad(-85), 0, 0) * CFrame.new(0, -1.1, 0) else CFrame.new()
	m:box("Seat", V(1.8, 0.25, 1.8), root * CFrame.new(0, 1.9, 0), seatColor, M.SmoothPlastic)
	m:box("Back", V(1.8, 1.8, 0.2), root * CFrame.new(0, 2.9, 0.85), seatColor, M.SmoothPlastic, DECO)
	for _, x in ipairs({ -0.75, 0.75 }) do
		for _, z in ipairs({ -0.75, 0.75 }) do
			m:box("Leg", V(0.15, 1.9, 0.15), root * CFrame.new(x, 0.95, z), C.Chrome, M.Metal, DECO)
		end
	end
	return m
end

function P.Table(f: Build.Frame, rng: any, round: boolean?, size: number?)
	local m = f:model("Table")
	local s = size or 3.6
	if round then
		m:cylY("Top", 0.2, s, V(0, 3, 0), C.OffWhite, M.Marble)
	else
		m:box("Top", V(s, 0.2, s), V(0, 3, 0), Build.vary(rng, C.OffWhite, 0.05), M.SmoothPlastic)
	end
	m:cylY("Post", 2.9, 0.35, V(0, 1.45, 0), C.Charcoal, M.Metal, DECO)
	m:cylY("Foot", 0.2, 1.8, V(0, 0.1, 0), C.Charcoal, M.Metal, DECO)
	return m
end

-- table with chairs around it + random leftovers
function P.DiningSet(f: Build.Frame, rng: any, chairColor: Color3?, messy: boolean?)
	local m = f:model("DiningSet")
	P.Table(m, rng, rng:Chance(0.4))
	local color = chairColor or Build.vary(rng, C.Red, 0.08)
	for i = 0, 3 do
		if rng:Chance(0.85) then
			local fallen = messy and rng:Chance(0.2)
			local a = i * 90 + rng:Range(-18, 18)
			P.Chair(m:rel(CFrame.Angles(0, math.rad(a), 0) * CFrame.new(0, 0, 2.5 + rng:Range(0, 0.5))), rng, color, fallen)
		end
	end
	if messy then
		for _ = 1, rng:Int(0, 3) do
			local item = rng:Int(1, 3)
			local cf = CFrame.new(rng:Range(-1.2, 1.2), 3.1, rng:Range(-1.2, 1.2)) * Build.yaw(rng:Range(0, 360))
			if item == 1 then
				m:box("Tray", V(1.6, 0.1, 1.1), cf * CFrame.new(0, 0.05, 0), C.Red, M.SmoothPlastic, DECO)
			elseif item == 2 then
				m:cylY("Cup", 0.7, 0.45, (cf * CFrame.new(0, 0.35, 0)).Position, C.OffWhite, M.SmoothPlastic, DECO)
			else
				m:box("Wrapper", V(0.6, 0.05, 0.5), cf, C.Yellow, M.Foil, DECO)
			end
		end
	end
	return m
end

function P.Stool(f: Build.Frame, rng: any, color: Color3?)
	local m = f:model("Stool")
	m:cylY("Seat", 0.3, 1.5, V(0, 3, 0), color or C.Red, M.Fabric)
	m:cylY("Post", 2.9, 0.25, V(0, 1.45, 0), C.Chrome, M.Metal, DECO)
	m:cylY("Foot", 0.15, 1.3, V(0, 0.08, 0), C.Chrome, M.Metal, DECO)
	return m
end

function P.Booth(f: Build.Frame, rng: any, color: Color3?, length: number?)
	local m = f:model("Booth")
	local l = length or 6
	local c = color or Build.vary(rng, C.DarkRed, 0.1)
	m:box("Seat", V(l, 1.9, 2.2), V(0, 0.95, 0), c, M.Fabric)
	m:box("Back", V(l, 2.4, 0.8), V(0, 3.1, 0.8), c, M.Fabric)
	if rng:Chance(0.35) then
		m:box("Tear", V(1.2, 0.05, 0.8), V(rng:Range(-l / 3, l / 3), 1.92, 0), C.Cream, M.Fabric, DECO)
	end
	return m
end

---------------------------------------------------------------------------
-- counters, registers, shelving
---------------------------------------------------------------------------

function P.Counter(f: Build.Frame, rng: any, length: number, color: Color3?, topColor: Color3?)
	local m = f:model("Counter")
	m:box("Body", V(length, 3.4, 2.2), V(0, 1.7, 0), color or C.WoodDark, M.WoodPlanks)
	m:box("Top", V(length + 0.3, 0.2, 2.6), V(0, 3.5, 0), topColor or C.Charcoal, M.Granite)
	m:box("Kick", V(length, 0.4, 0.1), V(0, 0.2, -1.12), C.Black, M.SmoothPlastic, DECO)
	return m
end

function P.Register(f: Build.Frame, rng: any, open: boolean?)
	local m = f:model("CashRegister")
	m:box("Base", V(1.6, 0.6, 1.4), V(0, 0.3, 0), C.Charcoal, M.SmoothPlastic, DECO)
	m:box("Keys", V(1.4, 0.2, 0.7), CFrame.new(0, 0.7, -0.2) * CFrame.Angles(math.rad(-15), 0, 0), C.DarkGray, M.SmoothPlastic, DECO)
	local screen = m:box("Screen", V(1, 0.7, 0.1), CFrame.new(0, 1.2, 0.3) * CFrame.Angles(math.rad(-10), 0, 0), C.Black, M.SmoothPlastic, DECO)
	Build.text(screen, FRONT, "0.00", { Color = C.NeonGreen, Font = Enum.Font.Code, Glow = true, Background = C.Void })
	if open then
		m:box("Drawer", V(1.4, 0.3, 1.1), V(0, 0.15, -1), C.DarkGray, M.Metal, DECO)
	end
	return m
end

-- gondola shelving unit (both faces stocked)
function P.Shelf(f: Build.Frame, rng: any, length: number, height: number?, palette: { Color3 }?, emptyChance: number?, doubleSided: boolean?)
	local m = f:model("Shelf")
	local h = height or 7
	local depth = if doubleSided then 3 else 1.6
	m:box("Back", V(length, h, 0.2), V(0, h / 2, 0), C.OffWhite, M.Metal)
	m:box("Base", V(length, 0.6, depth), V(0, 0.3, 0), C.LightGray, M.Metal)
	local levels = math.floor((h - 1) / 1.6)
	local colors = palette or { C.Red, C.Blue, C.Yellow, C.Green, C.Orange, C.Cream, C.Teal }
	for level = 1, levels do
		local y = 0.6 + level * 1.5
		m:box("Board", V(length, 0.12, depth), V(0, y - 0.9, 0), C.LightGray, M.Metal, DECO)
		for _, side in ipairs(if doubleSided then { -1, 1 } else { -1 }) do
			local x = -length / 2 + 0.2
			while x < length / 2 - 0.5 do
				local w = rng:Range(0.9, 2.2)
				if x + w > length / 2 - 0.2 then
					w = length / 2 - 0.2 - x
				end
				if w > 0.3 and not rng:Chance(emptyChance or 0.25) then
					local ph = rng:Range(0.6, 1.25)
					m:box("Stock", V(w - 0.1, ph, depth / 2 - 0.35), V(x + w / 2, y - 0.84 + ph / 2, side * (depth / 4 + 0.05)), Build.vary(rng, rng:Pick(colors), 0.15), M.SmoothPlastic, DECO)
				end
				x += w
			end
		end
	end
	m:box("Topper", V(length, 0.9, 0.15), V(0, h + 0.45, 0), C.Red, M.SmoothPlastic, DECO)
	return m
end

-- items spilled in front of a shelf (fallen shelves / looting)
function P.Spill(f: Build.Frame, rng: any, width: number, count: number, palette: { Color3 }?)
	local m = f:model("Spill")
	local colors = palette or { C.Red, C.Blue, C.Yellow, C.Green, C.Orange, C.Cream }
	for _ = 1, count do
		local s = V(rng:Range(0.4, 1.1), rng:Range(0.3, 0.9), rng:Range(0.3, 0.8))
		m:box("Item", s, CFrame.new(rng:Range(-width / 2, width / 2), s.Y / 2, rng:Range(-2.2, 0)) * CFrame.Angles(rng:Range(-0.4, 0.4), rng:Range(0, 6), rng:Range(-1.2, 1.2)), Build.vary(rng, rng:Pick(colors), 0.15), M.SmoothPlastic, DECO)
	end
	return m
end

---------------------------------------------------------------------------
-- walls, doors, shutters, glass
---------------------------------------------------------------------------

-- rolling security shutter covering an opening (width x height); openness 0..1
function P.Shutter(f: Build.Frame, rng: any, width: number, height: number, openness: number?)
	local m = f:model("SecurityShutter")
	local open = openness or 0
	local visible = height * (1 - open)
	m:box("Housing", V(width + 0.6, 1.4, 1.2), V(0, height + 0.7, 0), C.DarkGray, M.Metal)
	if visible > 0.3 then
		local slats = math.max(1, math.floor(visible / 0.8))
		local slatHeight = visible / slats
		for i = 0, slats - 1 do
			m:box("Slat", V(width, slatHeight - 0.08, 0.2), V(0, height - (i + 0.5) * slatHeight, 0), if i % 7 == 3 then C.Rust else C.MidGray, M.CorrodedMetal, if i == slats - 1 then nil else { shadow = false })
		end
		m:box("BottomBar", V(width, 0.35, 0.35), V(0, height - visible + 0.15, 0), C.Charcoal, M.Metal)
		-- single collider so the shutter blocks players cheaply
		m:box("Blocker", V(width, visible, 0.4), V(0, height - visible / 2, 0), C.Black, M.SmoothPlastic, { t = 1, shadow = false })
	end
	for _, x in ipairs({ -width / 2 - 0.2, width / 2 + 0.2 }) do
		m:box("Rail", V(0.3, height, 0.5), V(x, height / 2, 0), C.DarkGray, M.Metal, DECO)
	end
	return m
end

-- glass storefront panes between mullions (along local X)
function P.GlassFront(f: Build.Frame, rng: any, width: number, height: number, broken: boolean?)
	local m = f:model("GlassFront")
	local panes = math.max(1, math.floor(width / 7))
	local pw = width / panes
	for i = 0, panes - 1 do
		local x = -width / 2 + pw * (i + 0.5)
		if broken and rng:Chance(0.3) then
			m:box("GlassShard", V(pw * 0.4, height * 0.35, 0.15), CFrame.new(x - pw * 0.2, height * 0.8, 0) * CFrame.Angles(0, 0, 0.3), C.Glass, M.Glass, { deco = true, t = 0.55, refl = 0.2 })
			P.BrokenGlass(m:at(x, 0, -2.5), rng, 3, 14)
			m:box("Barrier", V(pw, height, 0.2), V(x, height / 2, 0), C.Glass, M.Glass, { t = 1, shadow = false })
		else
			m:box("Glass", V(pw - 0.3, height - 1.2, 0.2), V(x, height / 2 + 0.3, 0), C.Glass, M.Glass, { t = 0.62, refl = 0.15, shadow = false })
		end
		m:box("Mullion", V(0.35, height, 0.45), V(x - pw / 2, height / 2, 0), C.Charcoal, M.Metal, DECO)
	end
	m:box("Mullion", V(0.35, height, 0.45), V(width / 2, height / 2, 0), C.Charcoal, M.Metal, DECO)
	m:box("Sill", V(width, 0.6, 0.6), V(0, 0.3, 0), C.Charcoal, M.Metal)
	m:box("Head", V(width, 0.6, 0.6), V(0, height - 0.3, 0), C.Charcoal, M.Metal, DECO)
	return m
end

-- a simple framed door leaf (static; interactive doors are built by DeadMall with the Door tag)
function P.DoorFrame(f: Build.Frame, rng: any, width: number, height: number, color: Color3?)
	local m = f:model("DoorFrame")
	local c = color or C.Charcoal
	m:box("Jamb", V(0.4, height, 0.7), V(-width / 2 - 0.2, height / 2, 0), c, M.Metal, DECO)
	m:box("Jamb", V(0.4, height, 0.7), V(width / 2 + 0.2, height / 2, 0), c, M.Metal, DECO)
	m:box("Head", V(width + 0.8, 0.4, 0.7), V(0, height + 0.2, 0), c, M.Metal, DECO)
	return m
end

---------------------------------------------------------------------------
-- signage & safety
---------------------------------------------------------------------------

function P.ExitSign(f: Build.Frame, rng: any, text: string?)
	local m = f:model("ExitSign")
	local body = m:box("Sign", V(2.4, 0.9, 0.3), V(0, 0, 0), C.Black, M.SmoothPlastic, { deco = true, tags = { "ExitSign" } })
	Build.text(body, FRONT, text or "EXIT", { Color = C.ExitGreen, Font = Enum.Font.GothamBlack, Glow = true, Background = C.Void })
	Build.text(body, Enum.NormalId.Back, text or "EXIT", { Color = C.ExitGreen, Font = Enum.Font.GothamBlack, Glow = true, Background = C.Void })
	Build.point(body, C.ExitGreen, 0.35, 7)
	return m
end

function P.EmergencyLight(f: Build.Frame, rng: any, on: boolean?)
	local m = f:model("EmergencyLight")
	m:box("Box", V(1.6, 0.7, 0.5), V(0, 0, 0), C.OffWhite, M.SmoothPlastic, DECO)
	for _, x in ipairs({ -0.55, 0.55 }) do
		local lamp = m:box("Lamp", V(0.45, 0.35, 0.35), CFrame.new(x, -0.15, -0.35) * CFrame.Angles(math.rad(-30), 0, 0), if on then C.WarmLight else C.LightGray, if on then M.Neon else M.SmoothPlastic, { deco = true, tags = { "EmergencyLamp" } })
		if on and x < 0 then
			Build.spot(lamp, FRONT, C.WarmLight, 1.2, 22, 70)
		end
	end
	return m
end

function P.FireExtinguisher(f: Build.Frame, rng: any)
	local m = f:model("FireExtinguisher")
	m:box("Bracket", V(0.9, 1.4, 0.2), V(0, 3.6, 0.35), C.DarkGray, M.Metal, DECO)
	m:cylY("Tank", 1.7, 0.75, V(0, 3.6, 0), C.Red, M.SmoothPlastic, DECO)
	m:box("Handle", V(0.5, 0.3, 0.2), V(0, 4.6, 0), C.Charcoal, M.Metal, DECO)
	local sign = m:box("Sign", V(1.1, 1.1, 0.1), V(0, 5.6, 0.4), C.Red, M.SmoothPlastic, DECO)
	Build.text(sign, FRONT, "🧯\nFIRE", { Color = C.OffWhite, Font = Enum.Font.GothamBlack })
	return m
end

function P.SecurityCamera(f: Build.Frame, rng: any, pitchDegrees: number?)
	local m = f:model("SecurityCamera")
	m:box("Mount", V(0.5, 0.5, 0.8), V(0, 0, 0.4), C.OffWhite, M.SmoothPlastic, DECO)
	local bodyCF = CFrame.new(0, -0.35, -0.4) * CFrame.Angles(math.rad(-(pitchDegrees or 25)), 0, 0)
	m:box("Body", V(0.8, 0.7, 1.8), bodyCF, C.OffWhite, M.SmoothPlastic, { deco = true, tags = { "SecurityCamera" } })
	m:box("Lens", V(0.5, 0.5, 0.1), bodyCF * CFrame.new(0, 0, -0.92), C.Black, M.Glass, DECO)
	m:box("Led", V(0.12, 0.12, 0.05), bodyCF * CFrame.new(0.28, 0.25, -0.9), C.NeonRed, M.Neon, DECO)
	return m
end

function P.Clock(f: Build.Frame, rng: any, diameter: number?)
	local m = f:model("Clock")
	local d = diameter or 3
	local face = m:cylZ("Face", 0.3, d, V(0, 0, 0), C.OffWhite, M.SmoothPlastic, { deco = true, tags = { "MallClock" } })
	face.Name = "Face"
	m:cylZ("Rim", 0.35, d + 0.3, V(0, 0, 0.05), C.Charcoal, M.Metal, DECO)
	local hour = m:box("HourHand", V(0.16, d * 0.28, 0.05), CFrame.new(0, 0, -0.2) * CFrame.Angles(0, 0, math.rad(rng:Range(0, 360))) * CFrame.new(0, d * 0.14, 0), C.Black, M.SmoothPlastic, DECO)
	hour.Name = "HourHand"
	local minute = m:box("MinuteHand", V(0.1, d * 0.4, 0.05), CFrame.new(0, 0, -0.22) * CFrame.Angles(0, 0, math.rad(rng:Range(0, 360))) * CFrame.new(0, d * 0.2, 0), C.Black, M.SmoothPlastic, DECO)
	minute.Name = "MinuteHand"
	return m
end

function P.AdPanel(f: Build.Frame, rng: any, title: string, subtitle: string, color: Color3, lit: boolean?)
	local m = f:model("AdPanel")
	m:box("Frame", V(5.4, 8.4, 0.6), V(0, 4.8, 0), C.Charcoal, M.Metal)
	local screen = m:box("Screen", V(4.8, 7.6, 0.1), V(0, 4.9, -0.32), if lit then color else Build.shade(color, -0.45), M.SmoothPlastic, DECO)
	Build.layout(screen, FRONT, nil, {
		{ Text = title, Y = 0.08, H = 0.2, Color = C.OffWhite, Font = Enum.Font.GothamBlack },
		{ Bg = Build.shade(color, -0.4), Y = 0.34, H = 0.36, X = 0.12, W = 0.76 },
		{ Text = subtitle, Y = 0.76, H = 0.12, Color = C.Paper, Font = Enum.Font.Gotham },
	}, lit)
	if lit then
		Build.surfaceLight(screen, FRONT, color, 0.6, 10, 100)
	end
	return m
end

function P.Poster(f: Build.Frame, rng: any, title: string, subtitle: string?, color: Color3?, torn: boolean?)
	local m = f:model("Poster")
	local c = color or rng:Pick({ C.DarkRed, C.Navy, C.Purple, C.Teal, C.Mustard })
	local sheet = m:box("Sheet", V(3.2, 4.4, 0.06), CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(rng:Range(-3, 3))), c, M.SmoothPlastic, DECO)
	Build.layout(sheet, FRONT, nil, {
		{ Text = title, Y = 0.06, H = 0.22, Color = C.Paper, Font = Enum.Font.Bangers },
		{ Bg = Build.shade(c, -0.35), X = 0.1, W = 0.8, Y = 0.32, H = 0.4 },
		{ Text = subtitle, Y = 0.78, H = 0.12, Color = C.Paper, Font = Enum.Font.Gotham },
	})
	if torn then
		m:box("Tear", V(1.4, 1.3, 0.08), CFrame.new(0.9, -1.6, -0.01) * CFrame.Angles(0, 0, math.rad(35)), C.Paper, M.SmoothPlastic, DECO)
	end
	return m
end

-- neon lettering on a dark sign board (store names)
function P.NeonSign(f: Build.Frame, rng: any, text: string, width: number, color: Color3, flicker: boolean?, font: Enum.Font?, dead: boolean?)
	local m = f:model("NeonSign")
	local board = m:box("Board", V(width, 3.2, 0.5), V(0, 0, 0), C.Void, M.SmoothPlastic, DECO)
	local label = Build.text(board, FRONT, text, { Color = if dead then Build.shade(color, -0.55) else color, Font = font or Enum.Font.GothamBlack, Glow = not dead, Stroke = if dead then 1 else 0.4, StrokeColor = Build.shade(color, 0.5) })
	label.Size = UDim2.fromScale(0.94, 0.8)
	label.Position = UDim2.fromScale(0.03, 0.1)
	if dead then
		return m
	end
	local glow = Build.surfaceLight(board, FRONT, color, 1.4, 12, 110)
	if flicker then
		board:AddTag("FlickerLight")
		glow:SetAttribute("BaseBrightness", 1.4)
	end
	return m
end

function P.HangingSign(f: Build.Frame, rng: any, text: string, width: number, color: Color3?)
	local m = f:model("HangingSign")
	local board = m:box("Board", V(width, 1.6, 0.3), V(0, 0, 0), C.Charcoal, M.Metal, DECO)
	Build.text(board, FRONT, text, { Color = color or C.OffWhite, Font = Enum.Font.GothamBold })
	Build.text(board, Enum.NormalId.Back, text, { Color = color or C.OffWhite, Font = Enum.Font.GothamBold })
	for _, x in ipairs({ -width / 2 + 0.4, width / 2 - 0.4 }) do
		m:box("Wire", V(0.06, 3, 0.06), V(x, 2.3, 0), C.Charcoal, M.Metal, DECO)
	end
	return m
end

function P.Graffiti(f: Build.Frame, rng: any, text: string, width: number, color: Color3?)
	local m = f:model("Graffiti")
	local sheet = m:box("Paint", V(width, width * 0.4, 0.02), CFrame.Angles(0, 0, math.rad(rng:Range(-6, 6))), C.Black, M.SmoothPlastic, { deco = true, t = 1, query = false })
	local label = Build.text(sheet, FRONT, text, { Color = color or rng:Pick({ C.NeonRed, C.NeonGreen, C.NeonPink, C.Yellow, C.OffWhite }), Font = rng:Pick({ Enum.Font.PermanentMarker, Enum.Font.IndieFlower, Enum.Font.Bangers, Enum.Font.Creepster }) })
	label.TextTransparency = 0.15
	return m
end

---------------------------------------------------------------------------
-- ceiling & utilities
---------------------------------------------------------------------------

-- fluorescent troffer; working 0..1 (0 = dead, 1 = on); tagged for flicker/zone control
function P.CeilingLight(f: Build.Frame, rng: any, zone: string, brightness: number?, range: number?, state: string?, color: Color3?)
	local m = f:model("CeilingLight")
	local s = state or "On"
	local on = s ~= "Dead"
	local panel = m:box("Panel", V(4, 0.25, 2), V(0, -0.12, 0), if on then (color or C.ColdLight) else C.MidGray, if on then M.Neon else M.SmoothPlastic, { deco = true, tags = { "MallLight" }, attrs = { Zone = zone, State = s } })
	m:box("Housing", V(4.4, 0.3, 2.4), V(0, 0.1, 0), C.LightGray, M.Metal, DECO)
	if on then
		local light = Build.surfaceLight(panel, Enum.NormalId.Bottom, color or C.ColdLight, brightness or 1.1, range or 20, 125)
		light:SetAttribute("BaseBrightness", brightness or 1.1)
		if s == "Flicker" then
			panel:AddTag("FlickerLight")
		end
	end
	if s == "Hanging" then
		panel.CFrame = panel.CFrame * CFrame.new(1.2, -1.4, 0) * CFrame.Angles(0, 0, math.rad(40))
	end
	return m
end

function P.Vent(f: Build.Frame, rng: any)
	local m = f:model("Vent")
	m:box("Grille", V(2.4, 0.15, 2.4), V(0, -0.05, 0), C.LightGray, M.Metal, { deco = true, tags = { "Vent" } })
	for i = -2, 2 do
		m:box("Louver", V(2.2, 0.08, 0.12), V(0, -0.14, i * 0.42), C.MidGray, M.Metal, DECO)
	end
	return m
end

function P.PipeRun(f: Build.Frame, rng: any, length: number, count: number?)
	local m = f:model("Pipes")
	for i = 1, count or 3 do
		local d = rng:Range(0.4, 1.2)
		local color = rng:Pick({ C.Rust, C.MidGray, C.DarkGray, C.Red, C.Green })
		m:cyl("Pipe", length, d, V(0, -i * 1.2, 0), color, M.Metal, DECO)
		for x = -length / 2 + 3, length / 2 - 3, 8 do
			m:box("Hanger", V(0.15, 1.2 * i, 0.15), V(x, -i * 0.6 + 0.6, 0), C.Charcoal, M.Metal, DECO)
		end
	end
	return m
end

function P.CableBundle(f: Build.Frame, rng: any, length: number, droop: number?)
	local m = f:model("Cables")
	local d = droop or 1.5
	for c = 1, 3 do
		local steps = 6
		local offset = (c - 2) * 0.25
		for i = 0, steps - 1 do
			local t0, t1 = i / steps, (i + 1) / steps
			local function point(t: number)
				return V(-length / 2 + length * t, -d * 4 * t * (1 - t) - c * 0.12, offset)
			end
			m:rod("Cable", point(t0), point(t1), 0.12, rng:Pick({ C.Black, C.Charcoal, C.DarkRed }), M.Rubber, DECO)
		end
	end
	return m
end

function P.CeilingPanelFallen(f: Build.Frame, rng: any)
	local m = f:model("FallenCeilingTile")
	m:box("Tile", V(4, 0.2, 4), CFrame.new(0, 0.3, 0) * CFrame.Angles(math.rad(rng:Range(-12, 12)), rng:Range(0, 3), math.rad(rng:Range(-8, 8))), C.OffWhite, M.Plaster, DECO)
	for _ = 1, 6 do
		m:box("Debris", V(rng:Range(0.3, 0.9), 0.15, rng:Range(0.3, 0.9)), CFrame.new(rng:Range(-3, 3), 0.08, rng:Range(-3, 3)) * Build.yaw(rng:Range(0, 360)), C.OffWhite, M.Plaster, DECO)
	end
	return m
end

---------------------------------------------------------------------------
-- mall furniture
---------------------------------------------------------------------------

function P.ATM(f: Build.Frame, rng: any)
	local m = f:model("ATM")
	m:box("Body", V(3, 6.5, 2.2), V(0, 3.25, 0), C.DarkGray, M.Metal)
	local screen = m:box("Screen", V(1.8, 1.3, 0.1), CFrame.new(0, 4.6, -1.05) * CFrame.Angles(math.rad(-12), 0, 0), C.Navy, M.SmoothPlastic, DECO)
	Build.text(screen, FRONT, "OUT OF SERVICE", { Color = C.NeonRed, Font = Enum.Font.Code, Glow = true, Background = C.Void })
	m:box("Keypad", V(1.4, 0.2, 0.9), CFrame.new(0, 3.4, -1.3) * CFrame.Angles(math.rad(-25), 0, 0), C.Charcoal, M.Metal, DECO)
	local top = m:box("Header", V(3, 1, 2.3), V(0, 6.9, 0), C.Blue, M.SmoothPlastic, DECO)
	Build.text(top, FRONT, "ATM · 24H", { Color = C.OffWhite, Font = Enum.Font.GothamBlack, Glow = true })
	return m
end

function P.Directory(f: Build.Frame, rng: any, entries: { string })
	local m = f:model("MallDirectory")
	m:box("Base", V(5, 1, 1.6), V(0, 0.5, 0), C.Charcoal, M.Metal)
	local panel = m:box("Panel", V(4.4, 8, 1), V(0, 5, 0), C.Navy, M.SmoothPlastic)
	local items = {
		{ Text = "MALL DIRECTORY", Y = 0.03, H = 0.08, Color = C.OffWhite, Font = Enum.Font.GothamBlack },
		{ Text = "● YOU ARE HERE", Y = 0.11, H = 0.04, Color = C.NeonRed, Font = Enum.Font.GothamBold },
		{ Bg = C.Charcoal, X = 0.08, W = 0.84, Y = 0.17, H = 0.36 },
	}
	for i, entry in ipairs(entries) do
		table.insert(items, { Text = entry, Y = 0.55 + (i - 1) * 0.043, H = 0.04, Color = C.Paper, Font = Enum.Font.Gotham, Align = "Left" })
	end
	Build.layout(panel, FRONT, nil, items, true)
	Build.layout(panel, Enum.NormalId.Back, nil, items, true)
	Build.surfaceLight(panel, FRONT, C.ColdLight, 0.5, 8, 90)
	return m
end

function P.Payphone(f: Build.Frame, rng: any)
	local m = f:model("Payphone")
	local body = m:box("Body", V(1.8, 3, 1), V(0, 4.5, 0.4), C.Steel, M.Metal, { tags = { "Payphone" } })
	body.Name = "Body"
	m:box("Handset", V(0.35, 1.5, 0.35), V(-0.6, 4.6, -0.2), C.Black, M.SmoothPlastic, DECO)
	m:box("Keypad", V(0.8, 1, 0.1), V(0.2, 4.4, -0.12), C.Chrome, M.Metal, DECO)
	m:box("Hood", V(3, 4.5, 0.3), V(0, 4.8, 1), C.Charcoal, M.Metal, DECO)
	m:box("HoodSide", V(0.3, 4.5, 2.2), V(-1.5, 4.8, 0), C.Charcoal, M.Metal, DECO)
	m:box("HoodSide", V(0.3, 4.5, 2.2), V(1.5, 4.8, 0), C.Charcoal, M.Metal, DECO)
	local model = m.Parent :: Model
	model.PrimaryPart = body
	model:AddTag("Payphone")
	return m, body
end

function P.Statue(f: Build.Frame, rng: any, name: string)
	local m = f:model("Statue")
	local bronze = Build.rgb(102, 78, 52)
	m:box("Plinth", V(6, 3.5, 6), V(0, 1.75, 0), C.LightGray, M.Marble)
	local plaque = m:box("Plaque", V(3.4, 1, 0.1), V(0, 2, -3.02), bronze, M.Metal, DECO)
	Build.text(plaque, FRONT, name, { Color = C.Paper, Font = Enum.Font.Garamond })
	local body = m:model("StatueFigure")
	body.Parent:AddTag("MallStatue")
	body:box("Legs", V(2, 3.6, 1.2), V(0, 5.3, 0), bronze, M.Metal)
	body:box("Torso", V(2.4, 3, 1.4), V(0, 8.6, 0), bronze, M.Metal)
	body:ball("Head", 1.7, V(0, 10.9, 0), bronze, M.Metal)
	local arm = body:box("ArmRight", V(0.7, 3, 0.7), CFrame.new(1.6, 9.4, 0) * CFrame.Angles(0, 0, math.rad(150)) * CFrame.new(0, -1.2, 0), bronze, M.Metal, DECO)
	arm.Name = "ArmRight"
	local left = body:box("ArmLeft", V(0.7, 3, 0.7), CFrame.new(-1.6, 8.6, 0) * CFrame.new(0, -0.4, 0), bronze, M.Metal, DECO)
	left.Name = "ArmLeft"
	return m, body.Parent
end

function P.Kiosk(f: Build.Frame, rng: any, title: string, color: Color3, shuttered: boolean?)
	local m = f:model("Kiosk")
	m:box("Base", V(10, 3.4, 6), V(0, 1.7, 0), Build.shade(color, -0.3), M.SmoothPlastic)
	m:box("Top", V(10.6, 0.3, 6.6), V(0, 3.55, 0), C.OffWhite, M.Marble)
	for _, x in ipairs({ -4.8, 4.8 }) do
		for _, z in ipairs({ -2.8, 2.8 }) do
			m:box("Post", V(0.4, 5, 0.4), V(x, 6.2, z), C.Chrome, M.Metal, DECO)
		end
	end
	local roof = m:box("Roof", V(11, 1.4, 7), V(0, 9.3, 0), color, M.SmoothPlastic)
	Build.text(roof, FRONT, title, { Color = C.OffWhite, Font = Enum.Font.GothamBlack })
	Build.text(roof, Enum.NormalId.Back, title, { Color = C.OffWhite, Font = Enum.Font.GothamBlack })
	if shuttered then
		P.Shutter(m:at(0, 3.7, -3), rng, 9.6, 4.8, 0.15)
	else
		for _ = 1, 6 do
			m:box("Goods", V(rng:Range(0.4, 0.9), rng:Range(0.4, 1), 0.3), V(rng:Range(-4, 4), 4.1, rng:Range(-2, 2)), rng:Pick({ C.Pink, C.Blue, C.Yellow, C.Black }), M.SmoothPlastic, DECO)
		end
	end
	return m
end

function P.Railing(f: Build.Frame, rng: any, length: number, glass: boolean?)
	local m = f:model("Railing")
	m:box("TopRail", V(length, 0.3, 0.4), V(0, 3.6, 0), C.Chrome, M.Metal)
	if glass then
		m:box("Glass", V(length, 3.2, 0.12), V(0, 1.8, 0), C.Glass, M.Glass, { t = 0.7, refl = 0.1, shadow = false })
	else
		m:box("MidRail", V(length, 0.15, 0.2), V(0, 1.8, 0), C.Chrome, M.Metal, DECO)
		m:box("Blocker", V(length, 3.6, 0.2), V(0, 1.8, 0), C.Chrome, M.Metal, { t = 1, shadow = false })
	end
	for x = -length / 2, length / 2 + 0.01, 6 do
		m:box("Post", V(0.3, 3.6, 0.3), V(x, 1.8, 0), C.Chrome, M.Metal, DECO)
	end
	return m
end

function P.Column(f: Build.Frame, rng: any, height: number, diameter: number?, color: Color3?)
	local m = f:model("Column")
	local d = diameter or 3.2
	m:cylY("Shaft", height, d, V(0, height / 2, 0), color or C.OffWhite, M.Marble)
	m:box("Base", V(d + 1, 1, d + 1), V(0, 0.5, 0), C.LightGray, M.Marble, DECO)
	m:box("Capital", V(d + 1, 1, d + 1), V(0, height - 0.5, 0), C.LightGray, M.Marble, DECO)
	return m
end

-- framed painting; the canvas has a SurfaceGui "Canvas" with a Frame "Figure" (Walking Painting anomaly)
function P.Painting(f: Build.Frame, rng: any, title: string?)
	local m = f:model("Painting")
	local model = m.Parent :: Model
	model:AddTag("MallPainting")
	local frameColor = Build.rgb(92, 70, 40)
	m:box("FrameTop", V(9, 0.6, 0.4), V(0, 3.3, 0), frameColor, M.Wood, DECO)
	m:box("FrameBottom", V(9, 0.6, 0.4), V(0, -3.3, 0), frameColor, M.Wood, DECO)
	m:box("FrameLeft", V(0.6, 7.2, 0.4), V(-4.2, 0, 0), frameColor, M.Wood, DECO)
	m:box("FrameRight", V(0.6, 7.2, 0.4), V(4.2, 0, 0), frameColor, M.Wood, DECO)
	local canvas = m:box("Canvas", V(7.8, 6, 0.1), V(0, 0, 0.05), C.Cream, M.SmoothPlastic, DECO)
	local gui = Build.surfaceGui(canvas, Enum.NormalId.Front, false, 20)
	gui.Name = "Canvas"
	local sky = Instance.new("Frame")
	sky.Name = "Sky"
	sky.Size = UDim2.fromScale(1, 0.62)
	sky.BackgroundColor3 = Build.rgb(70, 86, 110)
	sky.BorderSizePixel = 0
	sky.Parent = gui
	local field = Instance.new("Frame")
	field.Name = "Field"
	field.Position = UDim2.fromScale(0, 0.62)
	field.Size = UDim2.fromScale(1, 0.38)
	field.BackgroundColor3 = Build.rgb(70, 92, 56)
	field.BorderSizePixel = 0
	field.Parent = gui
	local house = Instance.new("Frame")
	house.Name = "House"
	house.Position = UDim2.fromScale(0.62, 0.42)
	house.Size = UDim2.fromScale(0.22, 0.24)
	house.BackgroundColor3 = Build.rgb(140, 120, 100)
	house.BorderSizePixel = 0
	house.Parent = gui
	local figure = Instance.new("Frame")
	figure.Name = "Figure"
	figure.AnchorPoint = Vector2.new(0.5, 1)
	figure.Position = UDim2.fromScale(0.55, 0.8)
	figure.Size = UDim2.fromOffset(34, 86)
	figure.BackgroundColor3 = Build.rgb(12, 10, 10)
	figure.BorderSizePixel = 0
	figure.Parent = gui
	local plate = m:box("Plate", V(2.4, 0.5, 0.1), V(0, -4, 0.1), Build.rgb(150, 124, 70), M.Metal, DECO)
	Build.text(plate, Enum.NormalId.Front, title or "EVENING FIELD", { Color = C.Black, Font = Enum.Font.Garamond })
	return m
end

function P.MallLamp(f: Build.Frame, rng: any, lit: boolean?)
	local m = f:model("MallLamp")
	m:cylY("Base", 1.2, 2.2, V(0, 0.6, 0), C.Charcoal, M.Metal)
	m:cylY("Pole", 12, 0.6, V(0, 7, 0), C.Charcoal, M.Metal, DECO)
	for _, x in ipairs({ -1.6, 1.6 }) do
		m:box("Arm", V(3.2, 0.25, 0.25), V(x / 2, 12.6, 0), C.Charcoal, M.Metal, DECO)
		local globe = m:ball("Globe", 1.6, V(x, 12.2, 0), if lit then C.WarmLight else C.LightGray, if lit then M.Neon else M.Glass, { deco = true, t = if lit then 0 else 0.3 })
		if lit and x < 0 then
			Build.point(globe, C.WarmLight, 0.9, 26):SetAttribute("BaseBrightness", 0.9)
			globe:AddTag("FlickerLight")
		end
	end
	return m
end

function P.Mop(f: Build.Frame, rng: any)
	local m = f:model("MopBucket")
	m:box("Bucket", V(2, 1.6, 1.6), V(0, 1, 0), C.Yellow, M.Plastic)
	m:box("Wringer", V(1.2, 0.8, 1.2), V(0.3, 2.1, 0), C.Charcoal, M.Plastic, DECO)
	m:box("Handle", V(0.15, 5.5, 0.15), CFrame.new(-0.4, 3.6, 0.2) * CFrame.Angles(0, 0, math.rad(12)), C.WoodLight, M.Wood, DECO)
	for _, x in ipairs({ -0.8, 0.8 }) do
		m:cylZ("Wheel", 0.2, 0.4, V(x, 0.2, 0.7), C.Black, M.Rubber, DECO)
	end
	return m
end

function P.Ladder(f: Build.Frame, rng: any, height: number)
	local m = f:model("Ladder")
	local lean = CFrame.Angles(math.rad(-12), 0, 0)
	for _, x in ipairs({ -0.9, 0.9 }) do
		m:box("Rail", V(0.2, height, 0.25), CFrame.new(x, height / 2, 0) * lean, C.Yellow, M.Metal, DECO)
	end
	for y = 1, height - 0.5, 1.2 do
		m:box("Rung", V(1.8, 0.12, 0.2), CFrame.new(0, y, -math.tan(math.rad(12)) * (y - height / 2)), C.Steel, M.Metal, DECO)
	end
	return m
end

function P.Dust(f: Build.Frame, rng: any, area: Vector3)
	-- floating dust motes in a light beam (cheap: one emitter)
	local m = f:model("DustMotes")
	local volume = m:box("DustVolume", area, V(0, area.Y / 2, 0), C.Black, M.SmoothPlastic, { deco = true, t = 1, query = false })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Dust"
	emitter.Rate = 3
	emitter.Lifetime = NumberRange.new(6, 10)
	emitter.Speed = NumberRange.new(0.1, 0.4)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.06)
	emitter.LightEmission = 0.3
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.4), NumberSequenceKeypoint.new(1, 1) })
	emitter.Color = ColorSequence.new(C.Paper)
	emitter.Parent = volume
	return m
end

return P
