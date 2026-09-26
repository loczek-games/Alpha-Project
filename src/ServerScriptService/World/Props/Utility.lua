--[[
	Props.Utility (ModuleScript)
	Location: ServerScriptService/World/Props/Utility

	Back-of-house, bathroom, office, parking and structural props: lockers,
	desks, CCTV walls, electrical panels, cars, pillars, sinks, stalls,
	escalators, fountains, automatic doors, vending machines, investigation
	boards. Frames sit on the floor, front = -Z.
]]

local World = script.Parent.Parent
local Build = require(World.Build)

local C, M = Build.C, Build.M
local V = Vector3.new
local DECO = { deco = true }
local FRONT = Enum.NormalId.Front

local P = {}

---------------------------------------------------------------------------
-- office / staff
---------------------------------------------------------------------------

function P.Lockers(f: Build.Frame, rng: any, count: number, color: Color3?)
	local m = f:model("LockerRow")
	local c = color or Build.vary(rng, C.Teal, 0.1)
	for i = 0, count - 1 do
		local x = (i - (count - 1) / 2) * 2.2
		local body = m:box("Locker", V(2.1, 7.5, 2.2), V(x, 3.75, 0), c, M.Metal)
		local open = rng:Chance(0.25)
		local doorCF = if open then CFrame.new(x - 1.05, 3.75, -1.15) * CFrame.Angles(0, math.rad(rng:Range(40, 110)), 0) * CFrame.new(1.02, 0, 0) else CFrame.new(x, 3.75, -1.15)
		m:box("Door", V(2, 7.3, 0.12), doorCF, Build.shade(c, 0.05), M.Metal, DECO)
		for v = 0, 3 do
			m:box("Vent", V(1.2, 0.08, 0.05), doorCF * CFrame.new(0, 2.8 - v * 0.25, -0.08), C.Charcoal, M.Metal, DECO)
		end
		if open then
			m:box("Inside", V(1.9, 7.1, 0.05), V(x, 3.75, 1), C.Charcoal, M.SmoothPlastic, DECO)
			if rng:Chance(0.6) then
				m:box("Jacket", V(1.2, 2.4, 0.6), V(x, 5, 0.4), rng:Pick({ C.Navy, C.DarkRed, C.Charcoal }), M.Fabric, DECO)
			end
		end
		body.Name = "Locker"
	end
	m:box("Bench", V(count * 2.2, 0.4, 1.4), V(0, 1.8, -3), C.WoodLight, M.Wood)
	for _, x in ipairs({ -count * 1.1 + 0.5, count * 1.1 - 0.5 }) do
		m:box("BenchLeg", V(0.3, 1.8, 1.2), V(x, 0.9, -3), C.Charcoal, M.Metal, DECO)
	end
	return m
end

function P.Desk(f: Build.Frame, rng: any, width: number?)
	local m = f:model("Desk")
	local w = width or 7
	m:box("Top", V(w, 0.3, 3.4), V(0, 3.2, 0), C.WoodDark, M.WoodPlanks)
	m:box("Pedestal", V(2, 3, 3.2), V(w / 2 - 1.1, 1.5, 0), C.WoodDark, M.WoodPlanks)
	m:box("Modesty", V(w - 2.2, 2.2, 0.2), V(-1.1, 1.9, 1.5), C.WoodDark, M.WoodPlanks, DECO)
	for i = 0, 2 do
		m:box("Drawer", V(1.8, 0.8, 0.1), V(w / 2 - 1.1, 2.5 - i * 0.95, -1.62), C.Wood, M.WoodPlanks, { deco = true, tags = if i == 0 then { "DeskDrawer" } else nil })
	end
	for _ = 1, rng:Int(2, 5) do
		m:box("Papers", V(rng:Range(0.8, 1.2), 0.06, rng:Range(1, 1.4)), CFrame.new(rng:Range(-w / 2 + 0.8, w / 2 - 0.8), 3.4, rng:Range(-1, 1)) * Build.yaw(rng:Range(0, 360)), C.Paper, M.SmoothPlastic, DECO)
	end
	return m
end

function P.OfficeChair(f: Build.Frame, rng: any, fallen: boolean?)
	local m = f:model("OfficeChair")
	local root = if fallen then CFrame.new(0, 0.8, 0) * CFrame.Angles(math.rad(-80), rng:Range(0, 3), 0) * CFrame.new(0, -0.8, 0) else CFrame.Angles(0, rng:Range(-0.6, 0.6), 0)
	m:box("Seat", V(2, 0.5, 2), root * CFrame.new(0, 2, 0), C.Charcoal, M.Fabric)
	m:box("Back", V(1.9, 2.4, 0.4), root * CFrame.new(0, 3.5, 0.9), C.Charcoal, M.Fabric, DECO)
	m:box("Post", V(0.3, 1.5, 0.3), root * CFrame.new(0, 1.1, 0), C.Chrome, M.Metal, DECO)
	for i = 0, 4 do
		m:box("Leg", V(0.2, 0.2, 1.2), root * CFrame.Angles(0, i * math.pi * 2 / 5, 0) * CFrame.new(0, 0.3, -0.6), C.Charcoal, M.Metal, DECO)
	end
	return m
end

function P.FilingCabinet(f: Build.Frame, rng: any)
	local m = f:model("FilingCabinet")
	m:box("Body", V(2, 5, 2.4), V(0, 2.5, 0), C.MidGray, M.Metal)
	for i = 0, 3 do
		local open = rng:Chance(0.15)
		m:box("Drawer", V(1.8, 1.05, if open then 2 else 0.1), V(0, 4.3 - i * 1.2, if open then -1.4 else -1.22), C.LightGray, M.Metal, DECO)
		m:box("Label", V(0.6, 0.25, 0.05), V(0, 4.5 - i * 1.2, -1.3), C.Paper, M.SmoothPlastic, DECO)
	end
	return m
end

function P.CCTVWall(f: Build.Frame, rng: any, columns: number, rows: number, labels: { string }?)
	local m = f:model("CCTVWall")
	local w, h = 3, 2.2
	m:box("Rack", V(columns * (w + 0.3) + 0.6, rows * (h + 0.3) + 0.6, 1.2), V(0, 4 + rows * (h + 0.3) / 2, 0.6), C.Charcoal, M.Metal)
	local screens = {}
	local index = 0
	for r = 0, rows - 1 do
		for c = 0, columns - 1 do
			index += 1
			local x = (c - (columns - 1) / 2) * (w + 0.3)
			local y = 4.3 + r * (h + 0.3) + h / 2
			local screen = m:box("Monitor", V(w, h, 0.2), V(x, y, -0.05), C.Void, M.Glass, { deco = true, tags = { "CCTVMonitor" }, attrs = { Feed = index } })
			local label = if labels then labels[index] else nil
			Build.layout(screen, FRONT, Build.rgb(22, 26, 24), {
				{ Text = "CAM " .. string.format("%02d", index) .. (if label then " · " .. label else ""), X = 0, W = 1, Y = 0.04, H = 0.14, Color = C.OffWhite, Font = Enum.Font.Code, Align = "Left" },
				{ Text = "● REC", X = 0.7, W = 0.3, Y = 0.82, H = 0.12, Color = C.NeonRed, Font = Enum.Font.Code },
			}, true)
			table.insert(screens, screen)
		end
	end
	return m, screens
end

function P.Corkboard(f: Build.Frame, rng: any, width: number, height: number, notes: { string }?)
	local m = f:model("Corkboard")
	local board = m:box("Cork", V(width, height, 0.3), V(0, 0, 0), C.Tan, M.Fabric, DECO)
	m:box("Frame", V(width + 0.4, height + 0.4, 0.2), V(0, 0, 0.1), C.WoodDark, M.Wood, DECO)
	local items = {}
	local list = notes or {}
	for i = 1, math.max(6, #list) do
		local x = rng:Range(0.05, 0.75)
		local y = rng:Range(0.05, 0.72)
		local kind = rng:Int(1, 3)
		table.insert(items, {
			Bg = if kind == 1 then C.Paper elseif kind == 2 then C.OffWhite else Build.rgb(236, 220, 120),
			X = x,
			Y = y,
			W = rng:Range(0.14, 0.22),
			H = rng:Range(0.16, 0.24),
			Rot = rng:Range(-8, 8),
		})
		if list[i] then
			table.insert(items, { Text = list[i], X = x, Y = y + 0.02, W = 0.2, H = 0.14, Color = C.Black, Font = Enum.Font.PatrickHand, Rot = rng:Range(-6, 6) })
		end
	end
	Build.layout(board, FRONT, nil, items)
	return m, board
end

function P.ElectricalPanel(f: Build.Frame, rng: any)
	local m = f:model("ElectricalPanel")
	m:box("Cabinet", V(4, 6, 1.2), V(0, 4, 0), C.MidGray, M.Metal)
	m:box("Door", V(1.9, 5.6, 0.1), CFrame.new(-2, 4, -0.65) * CFrame.Angles(0, math.rad(-60), 0) * CFrame.new(0.95, 0, 0), C.LightGray, M.Metal, DECO)
	for r = 0, 5 do
		for c = 0, 3 do
			m:box("Breaker", V(0.6, 0.35, 0.2), V(-1.2 + c * 0.8, 6 - r * 0.7, -0.65), if rng:Chance(0.15) then C.Red else C.Charcoal, M.Plastic, DECO)
		end
	end
	local warn = m:box("Warning", V(1.6, 1, 0.05), V(1, 7.6, -0.62), C.Yellow, M.SmoothPlastic, DECO)
	Build.text(warn, FRONT, "⚡ DANGER\nHIGH VOLTAGE", { Color = C.Black, Font = Enum.Font.GothamBlack })
	P.Conduit(m, rng, 5)
	return m
end

function P.Conduit(f: Build.Frame, rng: any, height: number)
	local m = f:model("Conduit")
	for i = -1, 1 do
		m:cylY("Pipe", height, 0.3, V(i * 0.8, 7 + height / 2, 0.2), C.MidGray, M.Metal, DECO)
	end
	return m
end

function P.Generator(f: Build.Frame, rng: any)
	local m = f:model("Generator")
	m:box("Skid", V(8, 0.6, 4), V(0, 0.3, 0), C.Charcoal, M.Metal)
	m:box("Engine", V(5, 4, 3.4), V(-1, 2.6, 0), C.Mustard, M.Metal)
	m:box("Alternator", V(2.6, 3, 3), V(3, 2.1, 0), C.DarkGray, M.Metal)
	m:cylY("Exhaust", 3, 0.6, V(-2.5, 6, 1), C.Rust, M.Metal, DECO)
	local panel = m:box("Panel", V(1.8, 1.2, 0.1), V(-1, 3.4, -1.75), C.Black, M.SmoothPlastic, DECO)
	Build.text(panel, FRONT, "GEN-2 · OFF", { Color = C.NeonRed, Font = Enum.Font.Code, Glow = true })
	return m
end

function P.MetalShelf(f: Build.Frame, rng: any, length: number, height: number?)
	local m = f:model("StorageRack")
	local h = height or 8
	for _, x in ipairs({ -length / 2, length / 2 }) do
		for _, z in ipairs({ -1.2, 1.2 }) do
			m:box("Upright", V(0.25, h, 0.25), V(x, h / 2, z), C.Orange, M.Metal, DECO)
		end
	end
	m:box("Blocker", V(length, h, 2.6), V(0, h / 2, 0), C.Orange, M.Metal, { t = 1, shadow = false })
	for level = 0, 3 do
		local y = 0.4 + level * (h - 0.5) / 3
		m:box("Deck", V(length, 0.15, 2.6), V(0, y, 0), C.DarkGray, M.DiamondPlate, DECO)
		local x = -length / 2 + 0.4
		while x < length / 2 - 1.2 do
			local w = rng:Range(1.4, 2.8)
			if rng:Chance(0.7) and level < 3 then
				local bh = rng:Range(1, 1.9)
				m:box("Carton", V(w - 0.2, bh, 2.2), V(x + w / 2, y + 0.08 + bh / 2, rng:Range(-0.1, 0.1)), Build.vary(rng, C.Cardboard, 0.12), M.Cardboard, DECO)
			end
			x += w
		end
	end
	return m
end

function P.WaterCooler(f: Build.Frame, rng: any)
	local m = f:model("WaterCooler")
	m:box("Body", V(1.6, 3.6, 1.6), V(0, 1.8, 0), C.OffWhite, M.Plastic)
	m:cylY("Bottle", 1.8, 1.3, V(0, 4.5, 0), C.Glass, M.Glass, { deco = true, t = 0.4 })
	return m
end

function P.VendingMachine(f: Build.Frame, rng: any, lit: boolean?)
	local m = f:model("VendingMachine")
	m:box("Body", V(4, 8, 3), V(0, 4, 0.2), C.DarkRed, M.SmoothPlastic)
	local window = m:box("Window", V(2.8, 6, 0.1), V(-0.4, 4.4, -1.32), C.Glass, M.Glass, { deco = true, t = 0.3 })
	for r = 0, 4 do
		for c = 0, 3 do
			if rng:Chance(0.6) then
				m:box("Snack", V(0.5, 0.8, 0.4), V(-1.4 + c * 0.7, 2.2 + r * 1.1, -1), rng:Pick({ C.Red, C.Yellow, C.Blue, C.Green, C.Orange }), M.SmoothPlastic, DECO)
			end
		end
	end
	if lit then
		Build.surfaceLight(window, FRONT, C.ColdLight, 0.6, 8, 100)
	end
	m:box("Keypad", V(0.6, 1.2, 0.1), V(1.5, 5, -1.32), C.Charcoal, M.Metal, DECO)
	return m
end

function P.Couch(f: Build.Frame, rng: any, length: number?, color: Color3?)
	local m = f:model("Couch")
	local l = length or 8
	local c = color or Build.vary(rng, C.Navy, 0.1)
	m:box("Base", V(l, 1.6, 3.4), V(0, 0.8, 0), c, M.Fabric)
	m:box("Cushion", V(l - 1.2, 0.6, 2.6), V(0, 1.9, -0.2), Build.shade(c, 0.06), M.Fabric)
	m:box("Back", V(l, 2.4, 0.9), V(0, 2.6, 1.3), c, M.Fabric)
	for _, x in ipairs({ -l / 2 + 0.4, l / 2 - 0.4 }) do
		m:box("Arm", V(0.8, 2.4, 3.4), V(x, 1.6, 0), c, M.Fabric)
	end
	return m
end

function P.CoffeeTable(f: Build.Frame, rng: any)
	local m = f:model("CoffeeTable")
	m:box("Top", V(5, 0.3, 2.6), V(0, 1.8, 0), C.WoodDark, M.WoodPlanks)
	for _, x in ipairs({ -2.2, 2.2 }) do
		m:box("Leg", V(0.3, 1.7, 2.2), V(x, 0.85, 0), C.Charcoal, M.Metal, DECO)
	end
	for _ = 1, 3 do
		m:box("Magazine", V(1, 0.05, 1.3), CFrame.new(rng:Range(-1.5, 1.5), 1.98, rng:Range(-0.5, 0.5)) * Build.yaw(rng:Range(0, 360)), rng:Pick({ C.Red, C.Navy, C.Paper }), M.SmoothPlastic, DECO)
	end
	return m
end

function P.Bookshelf(f: Build.Frame, rng: any, width: number)
	local m = f:model("Bookshelf")
	m:box("Back", V(width, 9, 0.3), V(0, 4.5, 0.8), C.WoodDark, M.WoodPlanks)
	for _, x in ipairs({ -width / 2, width / 2 }) do
		m:box("Side", V(0.3, 9, 2), V(x, 4.5, 0), C.WoodDark, M.WoodPlanks)
	end
	for level = 0, 4 do
		local y = 0.2 + level * 1.9
		m:box("Board", V(width, 0.2, 2), V(0, y, 0), C.WoodDark, M.WoodPlanks, DECO)
		local x = -width / 2 + 0.3
		while x < width / 2 - 0.5 do
			local w = rng:Range(0.25, 0.5)
			if rng:Chance(0.85) then
				local h = rng:Range(1, 1.6)
				m:box("Book", V(w - 0.03, h, 1.4), CFrame.new(x + w / 2, y + 0.1 + h / 2, 0) * CFrame.Angles(0, 0, if rng:Chance(0.08) then 0.3 else 0), Build.vary(rng, rng:Pick({ C.DarkRed, C.Navy, C.DarkGreen, C.Tan, C.Charcoal, C.Mustard }), 0.1), M.SmoothPlastic, DECO)
			end
			x += w
		end
	end
	return m
end

function P.EquipmentCase(f: Build.Frame, rng: any, open: boolean?)
	local m = f:model("EquipmentCase")
	m:box("Case", V(4, 1.4, 2.8), V(0, 0.7, 0), C.Charcoal, M.Plastic)
	if open then
		m:box("Lid", V(4, 0.3, 2.8), CFrame.new(0, 1.4, 1.4) * CFrame.Angles(math.rad(-100), 0, 0) * CFrame.new(0, 0, -1.4), C.Charcoal, M.Plastic, DECO)
		m:box("Foam", V(3.7, 0.1, 2.5), V(0, 1.42, 0), C.Black, M.Fabric, DECO)
		m:box("Camera", V(1.4, 0.9, 0.8), V(-0.9, 1.7, 0), C.Black, M.SmoothPlastic, DECO)
		m:cylZ("Lens", 0.7, 0.6, V(-0.9, 1.7, -0.6), C.Charcoal, M.Metal, DECO)
		m:box("EMF", V(0.6, 0.2, 1.4), V(0.6, 1.55, 0), C.Charcoal, M.SmoothPlastic, DECO)
		m:cyl("Flashlight", 1.6, 0.4, V(1.2, 1.6, -0.6), C.DarkGray, M.Metal, DECO)
	end
	for _, x in ipairs({ -1.4, 1.4 }) do
		m:box("Latch", V(0.4, 0.3, 0.1), V(x, 1.2, -1.45), C.Chrome, M.Metal, DECO)
	end
	return m
end

---------------------------------------------------------------------------
-- bathrooms
---------------------------------------------------------------------------

function P.SinkCounter(f: Build.Frame, rng: any, sinks: number)
	local m = f:model("SinkCounter")
	local l = sinks * 4
	m:box("Counter", V(l, 0.5, 2.6), V(0, 3.2, 0), C.OffWhite, M.Marble)
	m:box("Apron", V(l, 1.2, 0.2), V(0, 2.4, -1.2), C.OffWhite, M.Marble, DECO)
	for i = 0, sinks - 1 do
		local x = -l / 2 + 2 + i * 4
		m:box("Basin", V(2.2, 0.1, 1.6), V(x, 3.47, -0.1), C.LightGray, M.SmoothPlastic, DECO)
		m:box("Faucet", V(0.25, 0.9, 0.25), V(x, 3.9, 0.8), C.Chrome, M.Metal, DECO)
		m:box("Spout", V(0.2, 0.2, 0.8), V(x, 4.25, 0.45), C.Chrome, M.Metal, DECO)
	end
	return m
end

function P.Stalls(f: Build.Frame, rng: any, count: number, color: Color3?)
	local m = f:model("Stalls")
	local w = 4.5
	local c = color or Build.vary(rng, C.Teal, 0.08)
	for i = 0, count do
		m:box("Partition", V(0.25, 6.4, 6), V(-count * w / 2 + i * w, 3.8, 0), c, M.SmoothPlastic)
	end
	for i = 0, count - 1 do
		local x = -count * w / 2 + (i + 0.5) * w
		local open = rng:Chance(0.5)
		local doorCF = if open then CFrame.new(x - w / 2 + 0.2, 3.8, -3) * CFrame.Angles(0, math.rad(rng:Range(-110, -40)), 0) * CFrame.new(w / 2 - 0.3, 0, 0) else CFrame.new(x, 3.8, -3)
		m:box("StallDoor", V(w - 0.6, 6, 0.2), doorCF, Build.shade(c, 0.05), M.SmoothPlastic, { tags = { "StallDoor" } })
		m:box("Toilet", V(1.6, 1.6, 2.2), V(x, 0.8, 1.6), C.OffWhite, M.SmoothPlastic, DECO)
		m:box("Tank", V(2, 1.6, 0.8), V(x, 2.2, 2.6), C.OffWhite, M.SmoothPlastic, DECO)
		if rng:Chance(0.3) then
			m:cylY("Paper", 0.5, 0.5, V(x + rng:Range(-1, 1), 0.25, rng:Range(-1, 1)), C.Paper, M.SmoothPlastic, DECO)
		end
	end
	return m
end

function P.Urinals(f: Build.Frame, rng: any, count: number)
	local m = f:model("Urinals")
	for i = 0, count - 1 do
		local x = (i - (count - 1) / 2) * 3.2
		m:box("Urinal", V(1.6, 2.4, 1.4), V(x, 3.2, 0.3), C.OffWhite, M.SmoothPlastic)
		if i < count - 1 then
			m:box("Divider", V(0.2, 3, 2), V(x + 1.6, 4, -0.2), C.MidGray, M.SmoothPlastic, DECO)
		end
	end
	return m
end

function P.HandDryer(f: Build.Frame, rng: any)
	local m = f:model("HandDryer")
	m:box("Body", V(1.6, 1.8, 1), V(0, 0, 0), C.Chrome, M.Metal, { deco = true, tags = { "HandDryer" } })
	m:box("Nozzle", V(0.5, 0.4, 0.4), V(0, -1, -0.2), C.Chrome, M.Metal, DECO)
	return m
end

---------------------------------------------------------------------------
-- parking
---------------------------------------------------------------------------

local CAR_COLORS = { C.DarkRed, C.Navy, C.Charcoal, C.OffWhite, C.Mustard, C.DarkGreen, C.Steel }

function P.Car(f: Build.Frame, rng: any, kind: string?, color: Color3?)
	local m = f:model("Car")
	local c = color or Build.vary(rng, rng:Pick(CAR_COLORS), 0.06)
	local van = kind == "Van"
	local length, width = if van then 15 else 13, 6
	local bodyHeight = if van then 5.4 else 2.6
	local body = m:box("Body", V(width, bodyHeight, length), V(0, 1.2 + bodyHeight / 2, 0), c, M.Metal)
	body.Name = "Body"
	if not van then
		m:box("Cabin", V(width - 0.6, 2.2, 6.4), V(0, 4.9, 0.6), c, M.Metal, DECO)
		m:box("Windshield", V(width - 1, 2, 0.2), CFrame.new(0, 4.8, -2.9) * CFrame.Angles(math.rad(-35), 0, 0), C.Charcoal, M.Glass, { deco = true, refl = 0.3, tags = { "CarWindow" } })
		m:box("RearGlass", V(width - 1, 2, 0.2), CFrame.new(0, 4.8, 4.1) * CFrame.Angles(math.rad(35), 0, 0), C.Charcoal, M.Glass, { deco = true, refl = 0.3 })
		for _, x in ipairs({ -width / 2 + 0.25, width / 2 - 0.25 }) do
			m:box("SideGlass", V(0.2, 1.6, 5.6), V(x, 5, 0.6), C.Charcoal, M.Glass, { deco = true, refl = 0.3 })
		end
	else
		m:box("Windshield", V(width - 0.6, 2.2, 0.2), V(0, 5.2, -length / 2 - 0.05), C.Charcoal, M.Glass, { deco = true, refl = 0.3, tags = { "CarWindow" } })
	end
	for _, x in ipairs({ -width / 2 + 0.6, width / 2 - 0.6 }) do
		for _, z in ipairs({ -length / 2 + 2.4, length / 2 - 2.4 }) do
			m:cyl("Wheel", 1.2, 2.4, V(x, 1.2, z), C.Black, M.Rubber, DECO)
		end
	end
	for _, x in ipairs({ -width / 2 + 1, width / 2 - 1 }) do
		m:box("Headlight", V(1.2, 0.6, 0.1), V(x, 2.6, -length / 2 - 0.02), C.OffWhite, M.Glass, { deco = true, tags = { "CarHeadlight" } })
		m:box("TailLight", V(1.2, 0.5, 0.1), V(x, 2.8, length / 2 + 0.02), C.DarkRed, M.Glass, { deco = true, tags = { "CarTaillight" } })
	end
	if rng:Chance(0.4) then
		m:box("Dust", V(width - 1, 0.05, length * 0.4), V(0, 1.2 + bodyHeight + 0.03, -length * 0.2), C.LightGray, M.Sand, { deco = true, t = 0.4 })
	end
	local model = m.Parent :: Model
	model:AddTag("ParkedCar")
	model.PrimaryPart = body
	return m
end

function P.Pillar(f: Build.Frame, rng: any, height: number, label: string?)
	local m = f:model("Pillar")
	local body = m:box("Pillar", V(3, height, 3), V(0, height / 2, 0), C.LightGray, M.Concrete)
	m:box("Stripe", V(3.1, 1.2, 3.1), V(0, 1.4, 0), C.Yellow, M.SmoothPlastic, DECO)
	m:box("Stripe", V(3.1, 0.5, 3.1), V(0, 2.4, 0), C.Black, M.SmoothPlastic, DECO)
	if label then
		for _, face in ipairs({ FRONT, Enum.NormalId.Back }) do
			Build.text(body, face, label, { Color = C.Navy, Font = Enum.Font.GothamBlack, PixelsPerStud = 20 }).Size = UDim2.new(1, 0, 0.12, 0)
		end
	end
	return m
end

function P.ParkingSign(f: Build.Frame, rng: any, text: string, color: Color3?)
	local m = f:model("ParkingSign")
	local board = m:box("Board", V(5, 2, 0.3), V(0, 0, 0), color or C.Blue, M.SmoothPlastic, DECO)
	Build.text(board, FRONT, text, { Color = C.OffWhite, Font = Enum.Font.GothamBlack })
	Build.text(board, Enum.NormalId.Back, text, { Color = C.OffWhite, Font = Enum.Font.GothamBlack })
	return m
end

function P.Cone(f: Build.Frame, rng: any)
	local m = f:model("Cone")
	m:box("Base", V(1.6, 0.2, 1.6), V(0, 0.1, 0), C.Orange, M.Plastic, DECO)
	m:cylY("Cone", 2.2, 0.9, V(0, 1.2, 0), C.Orange, M.Plastic, DECO)
	m:cylY("Band", 0.4, 0.95, V(0, 1.4, 0), C.OffWhite, M.Plastic, DECO)
	return m
end

function P.Barrier(f: Build.Frame, rng: any, length: number)
	local m = f:model("Barrier")
	m:box("Beam", V(length, 0.6, 0.3), V(0, 2.8, 0), C.OffWhite, M.Plastic)
	for x = -length / 2 + 0.6, length / 2 - 0.6, 2 do
		m:box("Stripe", V(0.9, 0.62, 0.32), V(x, 2.8, 0), C.Red, M.Plastic, DECO)
	end
	for _, x in ipairs({ -length / 2 + 0.4, length / 2 - 0.4 }) do
		m:box("Leg", V(0.3, 2.8, 1.6), V(x, 1.4, 0), C.OffWhite, M.Plastic, DECO)
	end
	return m
end

function P.ParkingBooth(f: Build.Frame, rng: any)
	local m = f:model("ParkingBooth")
	m:box("Floor", V(6, 0.6, 6), V(0, 0.3, 0), C.MidGray, M.Concrete)
	for _, x in ipairs({ -2.9, 2.9 }) do
		m:box("Wall", V(0.3, 3.4, 6), V(x, 2.3, 0), C.OffWhite, M.SmoothPlastic)
	end
	m:box("Back", V(6, 3.4, 0.3), V(0, 2.3, 2.9), C.OffWhite, M.SmoothPlastic)
	m:box("Glass", V(5.6, 3.8, 0.2), V(0, 5.9, -2.9), C.Glass, M.Glass, { t = 0.6, shadow = false })
	for _, x in ipairs({ -2.9, 2.9 }) do
		m:box("GlassSide", V(0.2, 3.8, 5.6), V(x, 5.9, 0), C.Glass, M.Glass, { t = 0.6, shadow = false })
	end
	m:box("Front", V(6, 3.4, 0.3), V(0, 2.3, -2.9), C.OffWhite, M.SmoothPlastic)
	local roof = m:box("Roof", V(7, 0.6, 7), V(0, 8.1, 0), C.Yellow, M.SmoothPlastic)
	Build.text(roof, FRONT, "PAY HERE", { Color = C.Black, Font = Enum.Font.GothamBlack })
	local lamp = m:box("Lamp", V(1, 0.2, 1), V(0, 7.7, 0), C.WarmLight, M.Neon, { deco = true, tags = { "FlickerLight" } })
	Build.point(lamp, C.WarmLight, 0.7, 14):SetAttribute("BaseBrightness", 0.7)
	return m
end

---------------------------------------------------------------------------
-- structures
---------------------------------------------------------------------------

-- escalator rising along local -Z from floor to `rise`
function P.Escalator(f: Build.Frame, rng: any, rise: number, run: number, direction: string)
	local m = f:model("Escalator")
	local model = m.Parent :: Model
	model:AddTag("Escalator")
	model:SetAttribute("Direction", direction)
	model:SetAttribute("Running", false)
	local width = 5
	local length = math.sqrt(rise * rise + run * run)
	local slope = math.atan2(rise, run)
	local incline = CFrame.new(0, rise / 2, -run / 2) * CFrame.Angles(slope, 0, 0)
	-- walkable ramp (hidden) + visible steps
	m:box("Ramp", V(width, 0.5, length), incline * CFrame.new(0, -0.1, 0), C.Charcoal, M.Metal, { t = 1, shadow = false })
	local steps = math.floor(length / 1.4)
	for i = 0, steps - 1 do
		local t = (i + 0.5) / steps
		local step = m:box("Step", V(width - 0.6, 0.35, 1.2), CFrame.new(0, rise * t, -run * t), C.DarkGray, M.DiamondPlate, { deco = true, tags = { "EscalatorStep" }, attrs = { T = t } })
		step.Name = "Step"
	end
	for _, x in ipairs({ -width / 2 - 0.3, width / 2 + 0.3 }) do
		m:box("Balustrade", V(0.4, 3.2, length + 4), incline * CFrame.new(x, 1.6, 0), C.Glass, M.Glass, { t = 0.65, shadow = false })
		m:box("Handrail", V(0.5, 0.35, length + 5), incline * CFrame.new(x, 3.4, 0), C.Black, M.Rubber, DECO)
		m:box("Skirt", V(0.5, 1.2, length), incline * CFrame.new(x, -0.3, 0), C.Chrome, M.Metal, DECO)
	end
	m:box("Truss", V(width + 1.2, 2.4, length), incline * CFrame.new(0, -1.6, 0), C.Steel, M.Metal, DECO)
	m:box("BottomPlate", V(width, 0.2, 3), V(0, 0.1, 1.5), C.Chrome, M.DiamondPlate)
	m:box("TopPlate", V(width, 0.2, 3), V(0, rise + 0.1, -run - 1.5), C.Chrome, M.DiamondPlate)
	return m
end

function P.Fountain(f: Build.Frame, rng: any, diameter: number)
	local m = f:model("Fountain")
	m:cylY("Rim", 2, diameter, V(0, 1, 0), C.LightGray, M.Marble)
	m:cylY("Water", 0.2, diameter - 1.6, V(0, 1.6, 0), C.Water, M.Glass, { t = 0.25, refl = 0.35, attrs = { FootstepSurface = "Water" } })
	m:cylY("Basin", 1.6, diameter * 0.45, V(0, 3, 0), C.LightGray, M.Marble, DECO)
	m:cylY("Pillar", 4, 1.6, V(0, 5, 0), C.LightGray, M.Marble, DECO)
	m:cylY("Bowl", 0.8, diameter * 0.25, V(0, 7.2, 0), C.LightGray, M.Marble, DECO)
	for _ = 1, 8 do
		m:cylY("Coin", 0.05, 0.3, V(rng:Range(-diameter / 3, diameter / 3), 1.72, rng:Range(-diameter / 3, diameter / 3)), C.Yellow, M.Metal, DECO)
	end
	m:box("Algae", V(diameter * 0.5, 0.05, diameter * 0.3), V(rng:Range(-2, 2), 1.73, rng:Range(-2, 2)), C.DarkGreen, M.Grass, { deco = true, t = 0.3 })
	return m
end

-- pair of glass sliding doors in a frame (width = total opening)
function P.AutoDoors(f: Build.Frame, rng: any, width: number, height: number, state: string?)
	local m = f:model("AutomaticDoors")
	local s = state or "Closed"
	m:box("Header", V(width + 1, 1.6, 1), V(0, height + 0.8, 0), C.Charcoal, M.Metal)
	local sensor = m:box("Sensor", V(1.2, 0.4, 0.3), V(0, height + 0.3, -0.6), C.Black, M.SmoothPlastic, DECO)
	Build.text(sensor, FRONT, "●", { Color = C.NeonRed, Glow = true })
	local half = width / 2
	for _, side in ipairs({ -1, 1 }) do
		local offset = if s == "Open" then half * 0.9 elseif s == "Jammed" then half * 0.35 else 0
		local panelX = side * (half / 2 + offset)
		if s == "Broken" and side == 1 then
			m:box("Frame", V(half, 0.4, 0.3), V(panelX, 0.2, 0), C.Charcoal, M.Metal, DECO)
			P.GlassShards(m:at(panelX, 0, -2), rng, half)
			m:box("Tape", V(half, 0.3, 0.05), CFrame.new(panelX, 3.5, -0.2) * CFrame.Angles(0, 0, 0.35), C.Yellow, M.SmoothPlastic, DECO)
			m:box("Tape", V(half, 0.3, 0.05), CFrame.new(panelX, 3.5, -0.2) * CFrame.Angles(0, 0, -0.35), C.Yellow, M.SmoothPlastic, DECO)
			m:box("Blocker", V(half, height, 0.3), V(panelX, height / 2, 0), C.Glass, M.Glass, { t = 1, shadow = false })
		else
			m:box("Panel", V(half - 0.1, height, 0.25), V(panelX, height / 2, 0), C.Glass, M.Glass, { t = 0.6, refl = 0.15, shadow = false, tags = { "AutoDoorPanel" }, attrs = { Side = side } })
			m:box("PanelFrame", V(half - 0.1, 0.4, 0.3), V(panelX, 0.2, 0), C.Charcoal, M.Metal, DECO)
		end
	end
	return m
end

function P.GlassShards(f: Build.Frame, rng: any, radius: number)
	local m = f:model("Shards")
	for _ = 1, 16 do
		m:box("Shard", V(rng:Range(0.2, 1.2), 0.05, rng:Range(0.2, 0.8)), CFrame.new(rng:Range(-radius, radius), 0.03, rng:Range(-radius, radius)) * Build.yaw(rng:Range(0, 360)), C.Glass, M.Glass, { deco = true, t = 0.3, refl = 0.3, attrs = { FootstepSurface = "Glass" } })
	end
	return m
end

function P.ElevatorDoors(f: Build.Frame, rng: any, label: string?)
	local m = f:model("Elevator")
	m:box("Surround", V(9, 11, 0.8), V(0, 5.5, 0.2), C.Steel, M.Metal)
	local left = m:box("DoorLeft", V(2.9, 8.6, 0.3), V(-1.5, 4.3, -0.35), C.Chrome, M.Metal, { tags = { "ElevatorDoor" }, attrs = { Side = -1 } })
	local right = m:box("DoorRight", V(2.9, 8.6, 0.3), V(1.5, 4.3, -0.35), C.Chrome, M.Metal, { tags = { "ElevatorDoor" }, attrs = { Side = 1 } })
	left.Name, right.Name = "DoorLeft", "DoorRight"
	local display = m:box("Display", V(3, 0.9, 0.1), V(0, 9.6, -0.25), C.Void, M.SmoothPlastic, DECO)
	Build.text(display, FRONT, label or "▼ 1", { Color = C.NeonOrange, Font = Enum.Font.Code, Glow = true })
	local panel = m:box("CallPanel", V(0.8, 1.6, 0.2), V(5.2, 4.2, -0.2), C.Chrome, M.Metal, { tags = { "ElevatorButton" } })
	panel.Name = "CallPanel"
	m:box("Button", V(0.35, 0.35, 0.1), V(5.2, 4.6, -0.35), C.OffWhite, M.Neon, DECO)
	m:box("Button", V(0.35, 0.35, 0.1), V(5.2, 3.9, -0.35), C.OffWhite, M.SmoothPlastic, DECO)
	return m
end

function P.Skylight(f: Build.Frame, rng: any, width: number, length: number)
	local m = f:model("Skylight")
	m:box("Glass", V(width, 0.3, length), V(0, 0, 0), C.Glass, M.Glass, { t = 0.55, refl = 0.1, shadow = false, tags = { "Skylight" } })
	for x = -width / 2, width / 2 + 0.01, width / 4 do
		m:box("Mullion", V(0.4, 0.6, length), V(x, -0.2, 0), C.Charcoal, M.Metal, DECO)
	end
	for z = -length / 2, length / 2 + 0.01, 8 do
		m:box("Purlin", V(width, 0.6, 0.4), V(0, -0.2, z), C.Charcoal, M.Metal, DECO)
	end
	return m
end

function P.InvestigationBoard(f: Build.Frame, rng: any, width: number, height: number, caption: string)
	local m = f:model("InvestigationBoard")
	local board = m:box("Board", V(width, height, 0.3), V(0, 0, 0), C.Tan, M.Fabric, DECO)
	m:box("Frame", V(width + 0.5, height + 0.5, 0.2), V(0, 0, 0.12), C.WoodDark, M.Wood, DECO)
	local items = { { Text = caption, Y = 0.02, H = 0.08, Color = C.DarkRed, Font = Enum.Font.SpecialElite } }
	local pins = {}
	for i = 1, 9 do
		local x = 0.06 + ((i - 1) % 3) * 0.32 + rng:Range(-0.03, 0.03)
		local y = 0.14 + math.floor((i - 1) / 3) * 0.28 + rng:Range(-0.02, 0.02)
		table.insert(items, { Bg = C.OffWhite, X = x, Y = y, W = 0.22, H = 0.22, Rot = rng:Range(-7, 7) })
		table.insert(items, { Bg = rng:Pick({ C.Charcoal, C.DarkGray, C.Navy }), X = x + 0.015, Y = y + 0.015, W = 0.19, H = 0.15, Rot = rng:Range(-7, 7) })
		table.insert(items, { Text = rng:Pick({ "CASE 014", "SEEN?", "3:07 AM", "??", "NOT HUMAN", "FOLLOW-UP", "MISSING", "DON'T LOOK UP", "SECTOR B" }), X = x, Y = y + 0.17, W = 0.22, H = 0.05, Color = C.Black, Font = Enum.Font.PatrickHand })
		table.insert(pins, V(-width / 2 + (x + 0.11) * width, height / 2 - (y + 0.02) * height, -0.25))
	end
	Build.layout(board, FRONT, nil, items)
	-- red strings between photos
	for i = 1, #pins - 1 do
		local j = rng:Int(i + 1, #pins)
		m:rod("String", pins[i], pins[j], 0.06, C.Red, M.Fabric, DECO)
	end
	for _, p in ipairs(pins) do
		m:ball("Pin", 0.25, p, C.NeonRed, M.SmoothPlastic, DECO)
	end
	return m, board
end

return P
