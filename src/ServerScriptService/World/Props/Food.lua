--[[
	Props.Food (ModuleScript)
	Location: ServerScriptService/World/Props/Food

	Food court and cinema fittings: menu boards, kitchen appliances, trays,
	popcorn machine, ticket booth, movie posters, cinema seats, projector.
	Frames sit on the floor (or a counter top), front = -Z.
]]

local World = script.Parent.Parent
local Build = require(World.Build)

local C, M = Build.C, Build.M
local V = Vector3.new
local DECO = { deco = true }
local FRONT = Enum.NormalId.Front

local P = {}

-- menu board with a title and item rows; items = { "BURGER  4.99", ... }
function P.MenuBoard(f: Build.Frame, rng: any, width: number, title: string, items: { string }, color: Color3, lit: boolean?)
	local m = f:model("MenuBoard")
	local h = 4.2
	local board = m:box("Board", V(width, h, 0.3), V(0, 0, 0), C.Void, M.SmoothPlastic, DECO)
	local rows = {
		{ Bg = color, Y = 0, H = 0.22 },
		{ Text = title, Y = 0.02, H = 0.18, Color = C.OffWhite, Font = Enum.Font.GothamBlack },
	}
	local columns = if #items > 5 then 2 else 1
	local perColumn = math.ceil(#items / columns)
	for i, item in ipairs(items) do
		local column = math.floor((i - 1) / perColumn)
		local row = (i - 1) % perColumn
		table.insert(rows, {
			Text = item,
			X = column / columns,
			W = 1 / columns,
			Y = 0.27 + row * (0.7 / perColumn),
			H = 0.6 / perColumn,
			Color = C.Paper,
			Font = Enum.Font.GothamBold,
			Align = "Left",
		})
	end
	Build.layout(board, FRONT, C.Void, rows, lit)
	if lit then
		Build.surfaceLight(board, FRONT, Build.shade(color, 0.3), 0.5, 10, 100)
	end
	return m
end

function P.Grill(f: Build.Frame, rng: any)
	local m = f:model("Grill")
	m:box("Body", V(5, 3.2, 3), V(0, 1.6, 0), C.Steel, M.Metal)
	m:box("Plate", V(4.6, 0.15, 2.6), V(0, 3.28, 0), C.Charcoal, M.Metal, DECO)
	for i = 1, rng:Int(0, 4) do
		m:cylY("Patty", 0.25, 0.9, V(-1.8 + i * 0.8, 3.45, rng:Range(-0.6, 0.6)), C.WoodDark, M.SmoothPlastic, DECO)
	end
	m:box("Hood", V(5.4, 1.4, 3.2), V(0, 8, 0.2), C.Steel, M.Metal, DECO)
	return m
end

function P.Fryer(f: Build.Frame, rng: any, tipped: boolean?)
	local m = f:model("Fryer")
	m:box("Body", V(3, 3.4, 3), V(0, 1.7, 0), C.Steel, M.Metal)
	m:box("Oil", V(2.4, 0.1, 2), V(0, 3.3, 0), Build.rgb(80, 60, 20), M.SmoothPlastic, DECO)
	local basketCF = if tipped then CFrame.new(-1.8, 0.4, -1.6) * CFrame.Angles(0, 0.6, math.rad(80)) else CFrame.new(0, 3.8, -0.3)
	m:box("Basket", V(1.4, 0.8, 1.2), basketCF, C.Chrome, M.DiamondPlate, { deco = true, t = 0.3 })
	if tipped then
		m:box("Fries", V(1.2, 0.05, 1.6), CFrame.new(-2.2, 0.03, -2.2) * Build.yaw(30), C.Yellow, M.SmoothPlastic, DECO)
	end
	return m
end

function P.SodaFountain(f: Build.Frame, rng: any)
	local m = f:model("SodaFountain")
	m:box("Body", V(3.6, 3, 2), V(0, 1.5, 0), C.Charcoal, M.Metal)
	local front = m:box("Front", V(3.4, 1.4, 0.1), V(0, 2.2, -1.02), C.Red, M.SmoothPlastic, DECO)
	Build.text(front, FRONT, "COLD DRINKS", { Color = C.OffWhite, Font = Enum.Font.GothamBlack })
	for i = -1, 1 do
		m:box("Nozzle", V(0.3, 0.5, 0.3), V(i * 1, 1, -0.9), C.Chrome, M.Metal, DECO)
	end
	m:box("Drip", V(3.2, 0.2, 1), V(0, 0.4, -0.7), C.Chrome, M.DiamondPlate, DECO)
	return m
end

function P.PizzaOven(f: Build.Frame, rng: any)
	local m = f:model("PizzaOven")
	m:box("Body", V(6, 6, 5), V(0, 3, 0), Build.rgb(120, 60, 44), M.Brick)
	m:box("Mouth", V(3, 1.8, 0.2), V(0, 3.4, -2.5), C.Void, M.SmoothPlastic, DECO)
	local glow = m:box("Embers", V(2.4, 0.2, 1.6), V(0, 2.6, -1.5), C.NeonOrange, M.Neon, { deco = true, tags = { "FlickerLight" } })
	Build.point(glow, C.NeonOrange, 0.8, 10):SetAttribute("BaseBrightness", 0.8)
	m:box("Chimney", V(1.6, 4, 1.6), V(0, 8, 1), C.Rust, M.Brick, DECO)
	return m
end

function P.WokStation(f: Build.Frame, rng: any)
	local m = f:model("WokStation")
	m:box("Range", V(6, 3.2, 3), V(0, 1.6, 0), C.Steel, M.Metal)
	for _, x in ipairs({ -1.6, 1.6 }) do
		m:cylY("Burner", 0.2, 1.8, V(x, 3.3, 0), C.Charcoal, M.Metal, DECO)
		m:cylY("Wok", 0.6, 2.2, V(x + rng:Range(-0.2, 0.2), 3.6, rng:Range(-0.2, 0.2)), C.Charcoal, M.Metal, DECO)
	end
	m:box("Hood", V(6.4, 1.4, 3.4), V(0, 8, 0.2), C.Steel, M.Metal, DECO)
	return m
end

function P.EspressoMachine(f: Build.Frame, rng: any)
	local m = f:model("EspressoMachine")
	m:box("Body", V(3, 2, 1.8), V(0, 1, 0), C.Chrome, M.Metal, DECO)
	m:box("Top", V(3, 0.3, 1.8), V(0, 2.15, 0), C.Charcoal, M.Metal, DECO)
	for _, x in ipairs({ -0.8, 0.8 }) do
		m:box("Group", V(0.5, 0.4, 0.5), V(x, 1.3, -1), C.Charcoal, M.Metal, DECO)
		m:cylY("Cup", 0.5, 0.4, V(x, 0.25, -1), C.OffWhite, M.SmoothPlastic, DECO)
	end
	for i = 0, 3 do
		m:cylY("CupStack", 0.3, 0.45, V(-1.2 + i * 0.1, 2.45 + i * 0.3, 0.3), C.OffWhite, M.SmoothPlastic, DECO)
	end
	return m
end

function P.IceCreamCase(f: Build.Frame, rng: any, length: number)
	local m = f:model("IceCreamCase")
	m:box("Body", V(length, 3.2, 3), V(0, 1.6, 0), C.OffWhite, M.Metal)
	m:wedge("Glass", V(length, 1.6, 1.8), CFrame.new(0, 4, -0.6) * CFrame.Angles(0, math.pi, 0), C.Glass, M.Glass, { t = 0.65, shadow = false })
	local flavors = { C.Pink, C.OffWhite, C.WoodDark, C.Green, C.Yellow, C.Purple, C.Red }
	for x = -length / 2 + 1, length / 2 - 1, 1.5 do
		m:box("Tub", V(1.3, 0.4, 1.2), V(x, 3.4, 0), rng:Pick(flavors), M.SmoothPlastic, DECO)
	end
	return m
end

function P.PrepTable(f: Build.Frame, rng: any, length: number)
	local m = f:model("PrepTable")
	m:box("Top", V(length, 0.2, 3), V(0, 3.2, 0), C.Chrome, M.Metal)
	m:box("Shelf", V(length, 0.15, 2.8), V(0, 0.8, 0), C.Steel, M.Metal, DECO)
	for _, x in ipairs({ -length / 2 + 0.3, length / 2 - 0.3 }) do
		for _, z in ipairs({ -1.3, 1.3 }) do
			m:box("Leg", V(0.2, 3.1, 0.2), V(x, 1.6, z), C.Steel, M.Metal, DECO)
		end
	end
	for _ = 1, rng:Int(1, 4) do
		local item = rng:Int(1, 3)
		local pos = V(rng:Range(-length / 2 + 0.8, length / 2 - 0.8), 3.3, rng:Range(-1, 1))
		if item == 1 then
			m:box("CuttingBoard", V(1.6, 0.12, 1.1), pos + V(0, 0.06, 0), C.WoodLight, M.Wood, DECO)
		elseif item == 2 then
			m:cylY("Pot", 1, 1.3, pos + V(0, 0.5, 0), C.Steel, M.Metal, DECO)
		else
			m:box("Container", V(1, 0.6, 0.8), pos + V(0, 0.3, 0), C.OffWhite, M.Plastic, { deco = true, t = 0.2 })
		end
	end
	for _ = 1, rng:Int(0, 3) do
		m:box("Box", V(1.4, 1, 1.2), V(rng:Range(-length / 2 + 0.8, length / 2 - 0.8), 1.4, 0), C.Cardboard, M.Cardboard, DECO)
	end
	return m
end

function P.Fridge(f: Build.Frame, rng: any, open: boolean?)
	local m = f:model("Fridge")
	m:box("Body", V(4, 8, 3), V(0, 4, 0.2), C.Chrome, M.Metal)
	if open then
		m:box("Door", V(2, 7.6, 0.3), CFrame.new(-2, 4, -1.4) * CFrame.Angles(0, math.rad(100), 0) * CFrame.new(1, 0, 0), C.Chrome, M.Metal, DECO)
		m:box("Inside", V(3.6, 7.2, 0.1), V(0, 4, -1.2), C.OffWhite, M.SmoothPlastic, DECO)
		local bulb = m:box("Bulb", V(0.3, 0.3, 0.3), V(0, 7.4, -1), C.SickLight, M.Neon, { deco = true, tags = { "FlickerLight" } })
		Build.point(bulb, C.SickLight, 0.6, 8):SetAttribute("BaseBrightness", 0.6)
		for _ = 1, 3 do
			m:box("Spoiled", V(rng:Range(0.6, 1.2), 0.6, 0.8), V(rng:Range(-1.2, 1.2), rng:Range(1, 6), -0.8), rng:Pick({ C.DeadPlant, C.Rust, C.OffWhite }), M.SmoothPlastic, DECO)
		end
	else
		m:box("Door", V(1.95, 7.6, 0.3), V(-1, 4, -1.4), C.Chrome, M.Metal, DECO)
		m:box("Door", V(1.95, 7.6, 0.3), V(1, 4, -1.4), C.Chrome, M.Metal, DECO)
	end
	return m
end

function P.TrayReturn(f: Build.Frame, rng: any)
	local m = f:model("TrayReturn")
	m:box("Cabinet", V(6, 4, 2.4), V(0, 2, 0), C.WoodDark, M.WoodPlanks)
	local sign = m:box("Top", V(6.2, 0.2, 2.6), V(0, 4.1, 0), C.Charcoal, M.Metal, DECO)
	Build.text(sign, Enum.NormalId.Top, "THANK YOU", { Color = C.OffWhite, Font = Enum.Font.Gotham })
	for i = 0, 6 do
		m:box("Tray", V(2.4, 0.1, 1.6), CFrame.new(-1.6, 4.25 + i * 0.12, 0) * Build.yaw(rng:Range(-5, 5)), C.Red, M.SmoothPlastic, DECO)
	end
	m:box("Bin", V(1.8, 1.8, 0.1), V(1.5, 2.6, -1.22), C.Black, M.SmoothPlastic, DECO)
	return m
end

function P.FoodTray(f: Build.Frame, rng: any)
	local m = f:model("FoodTray")
	local tray = m:box("Tray", V(2, 0.1, 1.4), V(0, 0.05, 0), rng:Pick({ C.Red, C.Orange, C.Navy }), M.SmoothPlastic, { deco = true, tags = { "FoodTray" } })
	tray.Name = "Tray"
	m:cylY("Cup", 0.8, 0.5, V(0.6, 0.5, 0.3), C.OffWhite, M.SmoothPlastic, DECO)
	m:box("Burger", V(0.8, 0.45, 0.8), V(-0.4, 0.33, 0), C.Tan, M.SmoothPlastic, DECO)
	m:box("Fries", V(0.5, 0.6, 0.3), V(0.1, 0.4, -0.35), C.Red, M.SmoothPlastic, DECO)
	return m
end

---------------------------------------------------------------------------
-- cinema
---------------------------------------------------------------------------

function P.PopcornMachine(f: Build.Frame, rng: any)
	local m = f:model("PopcornMachine")
	m:box("Cart", V(3, 3, 2.4), V(0, 1.5, 0), C.Red, M.SmoothPlastic)
	m:box("Glass", V(2.8, 3, 2.2), V(0, 4.5, 0), C.Glass, M.Glass, { t = 0.6, shadow = false })
	m:box("Popcorn", V(2.6, 0.9, 2), V(0, 3.45, 0), C.Yellow, M.SmoothPlastic, DECO)
	local top = m:box("Top", V(3.2, 0.8, 2.6), V(0, 6.4, 0), C.Red, M.SmoothPlastic, DECO)
	Build.text(top, FRONT, "POPCORN", { Color = C.Yellow, Font = Enum.Font.Bangers })
	local bulb = m:box("Heat", V(0.8, 0.2, 0.8), V(0, 5.8, 0), C.NeonOrange, M.Neon, DECO)
	Build.point(bulb, C.NeonOrange, 0.5, 8)
	return m
end

function P.MoviePoster(f: Build.Frame, rng: any, title: string, tagline: string, color: Color3, lit: boolean?)
	local m = f:model("MoviePoster")
	m:box("Case", V(4.6, 6.8, 0.4), V(0, 0, 0.1), C.Charcoal, M.Metal, DECO)
	local poster = m:box("Poster", V(4, 6.2, 0.05), V(0, 0, -0.12), Build.shade(color, -0.5), M.SmoothPlastic, DECO)
	Build.layout(poster, FRONT, nil, {
		{ Bg = color, X = 0.1, W = 0.8, Y = 0.08, H = 0.5 },
		{ Text = title, Y = 0.62, H = 0.16, Color = C.OffWhite, Font = Enum.Font.Creepster },
		{ Text = tagline, Y = 0.8, H = 0.08, Color = C.Paper, Font = Enum.Font.Gotham },
		{ Text = "COMING SOON", Y = 0.9, H = 0.06, Color = C.NeonRed, Font = Enum.Font.GothamBold },
	}, lit)
	if lit then
		Build.surfaceLight(poster, FRONT, Build.shade(color, 0.4), 0.4, 8, 90)
	end
	return m
end

function P.TicketBooth(f: Build.Frame, rng: any)
	local m = f:model("TicketBooth")
	m:box("Base", V(12, 3.5, 5), V(0, 1.75, 0), C.DarkRed, M.WoodPlanks)
	m:box("Top", V(12.4, 0.3, 5.4), V(0, 3.65, 0), C.Mustard, M.Metal)
	m:box("Glass", V(12, 4.2, 0.2), V(0, 5.9, -2), C.Glass, M.Glass, { t = 0.6, refl = 0.15, shadow = false })
	for _, x in ipairs({ -3.5, 3.5 }) do
		m:box("Hole", V(1.4, 0.5, 0.25), V(x, 4.1, -2), C.Void, M.SmoothPlastic, DECO)
	end
	m:box("Roof", V(13, 1.2, 6), V(0, 8.6, 0), C.DarkRed, M.SmoothPlastic)
	local sign = m:box("Sign", V(10, 1.6, 0.3), V(0, 10, -2.6), C.Void, M.SmoothPlastic, DECO)
	Build.text(sign, FRONT, "TICKETS", { Color = C.NeonYellow, Font = Enum.Font.Bangers, Glow = true })
	Build.surfaceLight(sign, FRONT, C.NeonYellow, 0.6, 10, 100)
	for _, x in ipairs({ -5.5, 5.5 }) do
		m:box("Wall", V(0.5, 8, 5), V(x, 4, 0), C.DarkRed, M.WoodPlanks)
	end
	m:box("Back", V(12, 8, 0.5), V(0, 4, 2.3), C.DarkRed, M.WoodPlanks)
	return m
end

function P.Stanchions(f: Build.Frame, rng: any, count: number, spacing: number)
	local m = f:model("Stanchions")
	for i = 0, count - 1 do
		local x = (i - (count - 1) / 2) * spacing
		local fallen = rng:Chance(0.2)
		if fallen then
			m:box("Post", V(0.3, 3, 0.3), CFrame.new(x, 0.25, 0) * CFrame.Angles(0, 0, math.rad(85)) * CFrame.new(0, 0, 0), C.Mustard, M.Metal, DECO)
		else
			m:cylY("Base", 0.2, 1.2, V(x, 0.1, 0), C.Mustard, M.Metal, DECO)
			m:box("Post", V(0.3, 3, 0.3), V(x, 1.6, 0), C.Mustard, M.Metal, DECO)
			if i < count - 1 then
				m:rod("Rope", V(x, 2.9, 0), V(x + spacing / 2, 2.4, 0), 0.2, C.DarkRed, M.Fabric, DECO)
				m:rod("Rope", V(x + spacing / 2, 2.4, 0), V(x + spacing, 2.9, 0), 0.2, C.DarkRed, M.Fabric, DECO)
			end
		end
	end
	return m
end

-- a row of theatre seats (seat bottoms flipped up or down randomly)
function P.SeatRow(f: Build.Frame, rng: any, count: number, color: Color3?)
	local m = f:model("SeatRow")
	local c = color or C.DarkRed
	for i = 0, count - 1 do
		local x = (i - (count - 1) / 2) * 2.6
		m:box("Back", V(2.3, 3.2, 0.5), CFrame.new(x, 2.9, 1) * CFrame.Angles(math.rad(-8), 0, 0), c, M.Fabric)
		local up = rng:Chance(0.6)
		m:box("Seat", V(2.2, 0.5, 2), if up then CFrame.new(x, 2.4, 0.3) * CFrame.Angles(math.rad(80), 0, 0) else CFrame.new(x, 1.7, -0.1), c, M.Fabric, DECO)
		if i % 2 == 0 then
			m:box("Arm", V(0.3, 2.2, 2.2), V(x + 1.3, 1.1, 0.2), C.Charcoal, M.Metal, DECO)
		end
	end
	return m
end

function P.Projector(f: Build.Frame, rng: any)
	local m = f:model("Projector")
	m:box("Pedestal", V(2.4, 3.6, 2.4), V(0, 1.8, 0), C.Charcoal, M.Metal)
	m:box("Body", V(2.2, 2.4, 4.2), V(0, 4.8, 0), C.DarkGray, M.Metal)
	m:cylZ("Lens", 1, 1, V(0, 5, -2.5), C.Black, M.Glass, DECO)
	for _, z in ipairs({ -1, 1.2 }) do
		m:cyl("Reel", 0.3, 3.2, V(0, 7.6, z), C.Steel, M.Metal, DECO)
	end
	return m
end

function P.FilmCans(f: Build.Frame, rng: any)
	local m = f:model("FilmCans")
	for i = 0, rng:Int(3, 7) do
		m:cylY("Can", 0.35, 2.4, V(rng:Range(-0.2, 0.2), 0.18 + i * 0.36, rng:Range(-0.2, 0.2)), C.Steel, M.Metal, DECO)
	end
	return m
end

return P
