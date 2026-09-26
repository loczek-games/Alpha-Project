--[[
	Props.Retail (ModuleScript)
	Location: ServerScriptService/World/Props/Retail

	Store fittings: clothing racks, mannequins, changing rooms, toys, TVs,
	computers, supermarket fixtures, shopping carts and arcade machines.
	Frames sit on the floor, front = -Z.
]]

local World = script.Parent.Parent
local Build = require(World.Build)

local C, M = Build.C, Build.M
local V = Vector3.new
local DECO = { deco = true }
local FRONT = Enum.NormalId.Front

local P = {}

---------------------------------------------------------------------------
-- clothing
---------------------------------------------------------------------------

local CLOTH = { C.DarkRed, C.Navy, C.Charcoal, C.Cream, C.Mustard, C.Teal, C.Pink, C.OffWhite, C.Green, C.Purple }

function P.ClothesRack(f: Build.Frame, rng: any, length: number?, round: boolean?, knockedOver: boolean?)
	local m = f:model("ClothesRack")
	local l = length or 6
	local root = if knockedOver then CFrame.new(0, 0.6, 0) * CFrame.Angles(math.rad(80), 0, 0) * CFrame.new(0, -0.6, 0) else CFrame.new()
	if round then
		m:cylY("Base", 0.3, 1.6, V(0, 0.15, 0), C.Chrome, M.Metal)
		m:box("Pole", V(0.25, 4.6, 0.25), root * CFrame.new(0, 2.4, 0), C.Chrome, M.Metal, DECO)
		for i = 1, 14 do
			local a = i / 14 * math.pi * 2
			local color = Build.vary(rng, rng:Pick(CLOTH), 0.1)
			m:box("Garment", V(0.2, rng:Range(2.2, 3), 1.5), root * CFrame.new(0, 4.4, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, -1.3, -1.9), color, M.Fabric, DECO)
		end
		m:cylY("Ring", 0.15, 4, V(0, 4.6, 0), C.Chrome, M.Metal, DECO)
	else
		for _, x in ipairs({ -l / 2, l / 2 }) do
			m:box("Upright", V(0.2, 5, 0.2), root * CFrame.new(x, 2.5, 0), C.Chrome, M.Metal, DECO)
			m:box("Foot", V(0.3, 0.2, 2), root * CFrame.new(x, 0.1, 0), C.Chrome, M.Metal)
		end
		m:box("Bar", V(l, 0.15, 0.15), root * CFrame.new(0, 5, 0), C.Chrome, M.Metal, DECO)
		local x = -l / 2 + 0.4
		while x < l / 2 - 0.3 do
			if not rng:Chance(0.18) then
				local color = Build.vary(rng, rng:Pick(CLOTH), 0.1)
				local long = rng:Range(2.3, 3.4)
				m:box("Garment", V(0.22, long, 1.6), root * CFrame.new(x, 5 - long / 2 - 0.2, 0) * CFrame.Angles(0, 0, math.rad(rng:Range(-4, 4))), color, M.Fabric, DECO)
				m:box("Hanger", V(0.05, 0.25, 1.2), root * CFrame.new(x, 5.05, 0), C.Charcoal, M.Plastic, DECO)
			end
			x += rng:Range(0.3, 0.45)
		end
	end
	return m
end

-- faceless shop mannequin; pose = "Stand" | "Wave" | "Point" | "Turn" | "Torso"
function P.Mannequin(f: Build.Frame, rng: any, pose: string?, outfit: Color3?, noBase: boolean?)
	local m = f:model("Mannequin")
	local skin = C.Mannequin
	local cloth = outfit or Build.vary(rng, rng:Pick(CLOTH), 0.08)
	local p = pose or "Stand"
	local model = m.Parent :: Model
	model:AddTag("MallMannequin")
	if not noBase then
		m:cylY("Stand", 0.25, 2.2, V(0, 0.12, 0), C.Charcoal, M.Metal)
		m:box("Rod", V(0.2, 1.2, 0.2), V(0, 0.8, 0.5), C.Chrome, M.Metal, DECO)
	end
	if p ~= "Torso" then
		m:box("LegL", V(0.75, 3.1, 0.75), V(-0.45, 1.85, 0), skin, M.SmoothPlastic)
		m:box("LegR", V(0.75, 3.1, 0.75), V(0.45, 1.85, 0), skin, M.SmoothPlastic)
		m:box("Pants", V(1.8, 1.8, 0.95), V(0, 2.5, 0), Build.shade(cloth, -0.3), M.Fabric, DECO)
	else
		m:box("Pole", V(0.25, 3.4, 0.25), V(0, 1.9, 0), C.Chrome, M.Metal)
	end
	local torso = m:box("Torso", V(1.9, 2.4, 1), V(0, 4.6, 0), cloth, M.Fabric)
	torso.Name = "Torso"
	m:box("Neck", V(0.45, 0.4, 0.45), V(0, 6, 0), skin, M.SmoothPlastic, DECO)
	local head = m:ball("Head", 1.35, V(0, 6.8, 0), skin, M.SmoothPlastic)
	head.Name = "Head"
	local function arm(side: number, angle: number, forward: number)
		local a = m:box(if side < 0 then "ArmL" else "ArmR", V(0.55, 2.6, 0.55), CFrame.new(side * 1.25, 5.6, 0) * CFrame.Angles(math.rad(forward), 0, math.rad(side * angle)) * CFrame.new(0, -1.25, 0), skin, M.SmoothPlastic, DECO)
		return a
	end
	if p == "Wave" then
		arm(-1, 8, 0)
		arm(1, 150, 0)
	elseif p == "Point" then
		arm(-1, 8, 0)
		arm(1, 10, -85)
	elseif p == "Turn" then
		arm(-1, 25, 20)
		arm(1, 25, -20)
		head.CFrame = head.CFrame * CFrame.Angles(0, math.rad(140), 0)
	else
		arm(-1, 10, 0)
		arm(1, 10, 0)
	end
	model.PrimaryPart = torso
	return m
end

function P.FoldedTable(f: Build.Frame, rng: any, w: number?, d: number?)
	local m = f:model("DisplayTable")
	local width, depth = w or 6, d or 4
	m:box("Top", V(width, 0.3, depth), V(0, 3, 0), C.WoodLight, M.WoodPlanks)
	for _, x in ipairs({ -width / 2 + 0.3, width / 2 - 0.3 }) do
		for _, z in ipairs({ -depth / 2 + 0.3, depth / 2 - 0.3 }) do
			m:box("Leg", V(0.3, 2.85, 0.3), V(x, 1.43, z), C.WoodDark, M.Wood, DECO)
		end
	end
	for ix = -1, 1 do
		for iz = -1, 1, 2 do
			if not rng:Chance(0.2) then
				local stack = rng:Int(1, 4)
				local color = rng:Pick(CLOTH)
				for s = 1, stack do
					m:box("Folded", V(1.5, 0.25, 1.2), CFrame.new(ix * 1.8 + rng:Range(-0.1, 0.1), 3.15 + s * 0.26, iz * 0.9) * Build.yaw(rng:Range(-6, 6)), Build.vary(rng, color, 0.06), M.Fabric, DECO)
				end
			end
		end
	end
	return m
end

function P.Mirror(f: Build.Frame, rng: any, width: number, height: number, cracked: boolean?)
	local m = f:model("Mirror")
	m:box("Frame", V(width + 0.4, height + 0.4, 0.2), V(0, height / 2 + 1, 0.05), C.Charcoal, M.Metal, DECO)
	local glass = m:box("Glass", V(width, height, 0.1), V(0, height / 2 + 1, -0.06), C.LightGray, M.Glass, { deco = true, refl = 0.55, tags = { "MallMirror" } })
	glass.Name = "Glass"
	if cracked then
		for _ = 1, 4 do
			m:box("Crack", V(0.05, rng:Range(1, height * 0.6), 0.02), CFrame.new(rng:Range(-width / 4, width / 4), height / 2 + 1 + rng:Range(-1, 1), -0.13) * CFrame.Angles(0, 0, rng:Range(-1.2, 1.2)), C.Black, M.SmoothPlastic, DECO)
		end
	end
	return m, glass
end

function P.ChangingRooms(f: Build.Frame, rng: any, count: number)
	local m = f:model("ChangingRooms")
	local w = 5
	for i = 0, count do
		m:box("Divider", V(0.3, 8, 6), V(-count * w / 2 + i * w, 4, 0), C.OffWhite, M.SmoothPlastic)
	end
	m:box("Back", V(count * w, 8, 0.3), V(0, 4, 3), C.OffWhite, M.SmoothPlastic)
	for i = 0, count - 1 do
		local x = -count * w / 2 + (i + 0.5) * w
		m:box("CurtainRod", V(w, 0.15, 0.15), V(x, 7.6, -3), C.Chrome, M.Metal, DECO)
		local openness = rng:Range(0, 0.9)
		local curtain = m:box("Curtain", V(w * (1 - openness * 0.8), 7.2, 0.15), V(x - w * openness * 0.4, 3.9, -3), Build.vary(rng, C.DarkRed, 0.08), M.Fabric, { tags = { "ChangingCurtain" }, attrs = { Openness = openness } })
		curtain.CastShadow = true
		m:box("Seat", V(3, 0.4, 1.2), V(x, 1.8, 2.3), C.WoodLight, M.Wood, DECO)
		m:box("Mirror", V(2.4, 4.2, 0.1), V(x, 4.6, 2.8), C.LightGray, M.Glass, { deco = true, refl = 0.5, tags = { "MallMirror" } })
		m:box("Hook", V(0.2, 0.2, 0.5), V(x + 1.6, 5.8, 2.6), C.Chrome, M.Metal, DECO)
	end
	local sign = m:box("Sign", V(8, 1.2, 0.2), V(0, 9, -3), C.Charcoal, M.SmoothPlastic, DECO)
	Build.text(sign, FRONT, "FITTING ROOMS", { Color = C.OffWhite, Font = Enum.Font.Gotham })
	return m
end

---------------------------------------------------------------------------
-- toys
---------------------------------------------------------------------------

local TOY = { C.Red, C.Yellow, C.Blue, C.Green, C.Pink, C.Orange, C.Purple, C.Teal }

function P.Plush(f: Build.Frame, rng: any, scale: number?, color: Color3?)
	local m = f:model("Plush")
	local s = scale or 1
	local c = color or Build.vary(rng, rng:Pick({ C.Tan, C.Cardboard, C.Pink, C.OffWhite, C.WoodLight }), 0.1)
	m:ball("Body", 1.6 * s, V(0, 0.8 * s, 0), c, M.Fabric, DECO)
	local head = m:ball("Head", 1.2 * s, V(0, 1.9 * s, -0.1 * s), c, M.Fabric, DECO)
	head.Name = "Head"
	for _, x in ipairs({ -0.45, 0.45 }) do
		m:ball("Ear", 0.5 * s, V(x * s, 2.45 * s, 0), c, M.Fabric, DECO)
		m:ball("Eye", 0.2 * s, V(x * 0.55 * s, 2 * s, -0.66 * s), C.Black, M.Glass, DECO)
	end
	m:ball("Snout", 0.45 * s, V(0, 1.8 * s, -0.68 * s), C.Cream, M.Fabric, DECO)
	return m
end

function P.Doll(f: Build.Frame, rng: any, creepy: boolean?)
	local m = f:model("Doll")
	local dress = Build.vary(rng, rng:Pick({ C.Pink, C.DarkRed, C.Navy, C.Cream }), 0.1)
	m:box("Dress", V(0.9, 1.1, 0.6), V(0, 0.55, 0), dress, M.Fabric, DECO)
	local head = m:ball("Head", 0.75, V(0, 1.45, 0), C.Skin, M.SmoothPlastic, DECO)
	head.Name = "Head"
	m:box("Hair", V(0.8, 0.5, 0.8), V(0, 1.7, 0.08), rng:Pick({ C.Yellow, C.WoodDark, C.Black }), M.Fabric, DECO)
	for _, x in ipairs({ -0.15, 0.15 }) do
		m:ball("Eye", 0.14, V(x, 1.5, -0.33), if creepy then C.Void else C.Blue, M.Glass, DECO)
	end
	if creepy then
		head.CFrame = head.CFrame * CFrame.Angles(0, 0, math.rad(25))
	end
	return m
end

function P.ToyBoxShelf(f: Build.Frame, rng: any, length: number, height: number?)
	local m = f:model("ToyShelf")
	local h = height or 8
	m:box("Back", V(length, h, 0.3), V(0, h / 2, 0.8), C.OffWhite, M.SmoothPlastic)
	for _, x in ipairs({ -length / 2, length / 2 }) do
		m:box("Side", V(0.3, h, 2), V(x, h / 2, 0), C.OffWhite, M.SmoothPlastic)
	end
	local levels = math.floor(h / 2)
	for level = 0, levels - 1 do
		local y = 0.3 + level * 2
		m:box("Board", V(length, 0.2, 2), V(0, y, 0), C.OffWhite, M.SmoothPlastic, DECO)
		local x = -length / 2 + 0.4
		while x < length / 2 - 0.8 do
			local w = rng:Range(0.8, 1.6)
			local item = rng:Int(1, 7)
			if item <= 4 then
				local bh = rng:Range(0.8, 1.7)
				local box = m:box("ToyBox", V(w - 0.1, bh, 1.3), V(x + w / 2, y + 0.1 + bh / 2, 0), Build.vary(rng, rng:Pick(TOY), 0.1), M.SmoothPlastic, DECO)
				box.Name = "ToyBox"
			elseif item == 5 then
				P.Plush(m:at(x + w / 2, y + 0.1, 0), rng, 0.55)
			elseif item == 6 then
				P.Doll(m:at(x + w / 2, y + 0.1, 0), rng, rng:Chance(0.2))
			end
			x += w
		end
	end
	return m
end

function P.RockingHorse(f: Build.Frame, rng: any)
	local m = f:model("RockingHorse")
	local c = C.Tan
	for _, x in ipairs({ -0.9, 0.9 }) do
		m:box("Rocker", V(0.25, 0.3, 5), V(x, 0.2, 0), C.WoodDark, M.Wood, DECO)
	end
	m:box("Body", V(1.6, 1.6, 3.4), V(0, 2.2, 0), c, M.Wood)
	m:box("Neck", V(1, 2, 1), CFrame.new(0, 3.4, -1.5) * CFrame.Angles(math.rad(25), 0, 0), c, M.Wood, DECO)
	local head = m:box("Head", V(1, 1, 2), V(0, 4.3, -2.3), c, M.Wood, DECO)
	head.Name = "Head"
	for _, z in ipairs({ -1.2, 1.2 }) do
		for _, x in ipairs({ -0.6, 0.6 }) do
			m:box("Leg", V(0.35, 1.6, 0.35), V(x, 1, z), c, M.Wood, DECO)
		end
	end
	m:box("Mane", V(0.3, 1.6, 1.6), CFrame.new(0, 4.1, -1.3) * CFrame.Angles(math.rad(25), 0, 0), C.WoodDark, M.Fabric, DECO)
	return m
end

function P.GiantBear(f: Build.Frame, rng: any)
	local m = f:model("GiantTeddy")
	local s = 3
	P.Plush(m, rng, s, C.Tan)
	m:box("Bow", V(1.5, 0.7, 0.3), V(0, 4.9, -1.6), C.Red, M.Fabric, DECO)
	return m
end

function P.Ball(f: Build.Frame, rng: any, diameter: number?, color: Color3?)
	local m = f:model("ToyBall")
	local d = diameter or 1.6
	local ball = m:ball("Ball", d, V(0, d / 2, 0), color or rng:Pick(TOY), M.SmoothPlastic, { deco = true, tags = { "ToyBall" } })
	ball.Name = "Ball"
	m:ball("Stripe", d * 1.01, V(0, d / 2, 0), C.OffWhite, M.SmoothPlastic, { deco = true, t = 0.6 })
	return m
end

---------------------------------------------------------------------------
-- electronics
---------------------------------------------------------------------------

function P.TV(f: Build.Frame, rng: any, width: number, on: string?)
	local m = f:model("TV")
	local h = width * 0.58
	m:box("Bezel", V(width + 0.3, h + 0.3, 0.35), V(0, 0, 0.1), C.Black, M.SmoothPlastic, DECO)
	local screen = m:box("Screen", V(width, h, 0.05), V(0, 0, -0.1), C.Void, M.Glass, { deco = true, refl = 0.08, tags = { "MallTV" }, attrs = { Mode = on or "Off" } })
	screen.Name = "Screen"
	if on == "Static" then
		Build.text(screen, FRONT, "", { Background = C.Gray, Glow = true })
		Build.surfaceLight(screen, FRONT, C.ColdLight, 0.5, 8, 90)
	elseif on == "Logo" then
		Build.text(screen, FRONT, "NO SIGNAL", { Background = C.Navy, Color = C.OffWhite, Font = Enum.Font.Code, Glow = true })
		Build.surfaceLight(screen, FRONT, C.NeonBlue, 0.4, 8, 90)
	end
	return m, screen
end

function P.CRT(f: Build.Frame, rng: any, on: boolean?)
	local m = f:model("CRT")
	m:box("Case", V(2.4, 2, 2.2), V(0, 1, 0.2), C.Cream, M.Plastic, DECO)
	local screen = m:box("Screen", V(1.9, 1.5, 0.1), V(0, 1.05, -0.92), C.Void, M.Glass, { deco = true, tags = { "MallTV" }, attrs = { Mode = if on then "Static" else "Off" } })
	screen.Name = "Screen"
	if on then
		Build.text(screen, FRONT, "", { Background = C.Gray, Glow = true })
	end
	return m, screen
end

function P.TVWall(f: Build.Frame, rng: any, columns: number, rows: number, tvWidth: number)
	local m = f:model("TVWall")
	local h = tvWidth * 0.58
	m:box("Backboard", V(columns * (tvWidth + 0.6) + 0.6, rows * (h + 0.6) + 0.6, 0.4), V(0, rows * (h + 0.6) / 2 + 2.3, 0.4), C.Charcoal, M.SmoothPlastic)
	for c = 0, columns - 1 do
		for r = 0, rows - 1 do
			local x = (c - (columns - 1) / 2) * (tvWidth + 0.6)
			local y = 2.6 + r * (h + 0.6) + h / 2
			local mode = if rng:Chance(0.35) then "Static" elseif rng:Chance(0.2) then "Logo" else "Off"
			P.TV(m:at(x, y, 0), rng, tvWidth, mode)
		end
	end
	return m
end

function P.Computer(f: Build.Frame, rng: any, on: boolean?, text: string?)
	local m = f:model("Computer")
	m:box("Keyboard", V(2, 0.12, 0.7), V(0, 0.06, -0.8), C.Charcoal, M.Plastic, DECO)
	m:box("Stand", V(0.3, 0.9, 0.3), V(0, 0.45, 0.3), C.Charcoal, M.Plastic, DECO)
	local monitor = m:box("Monitor", V(2.6, 1.6, 0.2), V(0, 1.6, 0.25), C.Black, M.Plastic, DECO)
	local screen = m:box("Screen", V(2.4, 1.4, 0.05), V(0, 1.6, 0.13), C.Void, M.Glass, { deco = true, tags = { "MallTV" }, attrs = { Mode = if on then "Text" else "Off" } })
	screen.Name = "Screen"
	if on then
		Build.text(screen, FRONT, text or "> SYSTEM ERROR_", { Background = C.Void, Color = C.NeonGreen, Font = Enum.Font.Code, Glow = true, Align = "Left" })
		Build.surfaceLight(screen, FRONT, C.NeonGreen, 0.3, 6, 90)
	end
	m:box("Mouse", V(0.3, 0.12, 0.45), V(1.4, 0.06, -0.8), C.Charcoal, M.Plastic, DECO)
	return m, screen, monitor
end

function P.PhoneDisplay(f: Build.Frame, rng: any, length: number)
	local m = f:model("PhoneDisplay")
	m:box("Table", V(length, 3.2, 3), V(0, 1.6, 0), C.OffWhite, M.SmoothPlastic)
	for x = -length / 2 + 1, length / 2 - 1, 1.6 do
		if not rng:Chance(0.3) then
			local phone = m:box("Phone", V(0.6, 1.1, 0.1), CFrame.new(x, 3.8, 0) * CFrame.Angles(math.rad(-20), 0, 0), C.Black, M.Glass, { deco = true, tags = { "MallPhone" } })
			phone.Name = "Phone"
			m:box("Tether", V(0.08, 0.6, 0.08), V(x, 3.4, 0.3), C.Charcoal, M.Rubber, DECO)
		end
	end
	return m
end

function P.LaptopTable(f: Build.Frame, rng: any, length: number)
	local m = f:model("LaptopTable")
	m:box("Table", V(length, 3.2, 3.2), V(0, 1.6, 0), C.WoodLight, M.WoodPlanks)
	for x = -length / 2 + 1.5, length / 2 - 1.5, 3 do
		if not rng:Chance(0.25) then
			m:box("Base", V(2.2, 0.1, 1.5), V(x, 3.25, 0), C.Chrome, M.Metal, DECO)
			local screen = m:box("Lid", V(2.2, 1.4, 0.08), CFrame.new(x, 3.95, 0.7) * CFrame.Angles(math.rad(-15), 0, 0), C.Chrome, M.Metal, DECO)
			if rng:Chance(0.3) then
				Build.text(screen, FRONT, "", { Background = C.Navy, Glow = true })
			end
		end
	end
	return m
end

---------------------------------------------------------------------------
-- supermarket
---------------------------------------------------------------------------

function P.Freezer(f: Build.Frame, rng: any, doors: number, lit: boolean?)
	local m = f:model("Freezer")
	local w = doors * 3.2
	m:box("Cabinet", V(w + 0.6, 8, 3.2), V(0, 4, 0.2), C.OffWhite, M.Metal)
	local topSign = m:box("Header", V(w + 0.6, 1.2, 0.3), V(0, 8.6, -1.3), C.Blue, M.SmoothPlastic, DECO)
	Build.text(topSign, FRONT, "FROZEN FOODS", { Color = C.OffWhite, Font = Enum.Font.GothamBlack, Glow = lit })
	for i = 0, doors - 1 do
		local x = -w / 2 + 1.6 + i * 3.2
		local open = rng:Chance(0.12)
		local doorCF = if open then CFrame.new(x - 1.5, 4, -1.45) * CFrame.Angles(0, math.rad(70), 0) * CFrame.new(1.5, 0, 0) else CFrame.new(x, 4, -1.45)
		m:box("GlassDoor", V(3, 7, 0.15), doorCF, C.Glass, M.Glass, { t = 0.6, refl = 0.2, shadow = false, tags = { "FreezerDoor" } })
		m:box("Handle", V(0.15, 2, 0.2), doorCF * CFrame.new(1.2, 0, -0.15), C.Chrome, M.Metal, DECO)
		for level = 0, 3 do
			for k = 0, 2 do
				if not rng:Chance(0.35) then
					m:box("Carton", V(0.8, 1.1, 1.2), V(x - 0.9 + k * 0.9, 1.4 + level * 1.7, 0.3), Build.vary(rng, rng:Pick({ C.Blue, C.Red, C.OffWhite, C.Teal }), 0.12), M.SmoothPlastic, DECO)
				end
			end
		end
		if lit then
			local strip = m:box("LightStrip", V(0.2, 7, 0.1), V(x + 1.5, 4, -1.2), C.ColdLight, M.Neon, DECO)
			if i % 2 == 0 then
				Build.point(strip, C.ColdLight, 0.5, 8)
			end
		end
	end
	return m
end

function P.ProduceBin(f: Build.Frame, rng: any)
	local m = f:model("ProduceBin")
	m:wedge("Bin", V(6, 3, 4), CFrame.new(0, 1.5, 0), C.WoodLight, M.WoodPlanks)
	local rotten = { C.DeadPlant, C.Rust, C.WoodDark, Build.rgb(90, 70, 40) }
	for _ = 1, 10 do
		m:ball("Produce", rng:Range(0.6, 0.9), CFrame.new(rng:Range(-2.4, 2.4), 2.6 + rng:Range(-0.5, 0.4), rng:Range(-1, 1.5)), rng:Pick(rotten), M.SmoothPlastic, DECO)
	end
	local tag = m:box("PriceTag", V(1.4, 0.8, 0.1), CFrame.new(0, 1.5, -2) * CFrame.Angles(math.rad(-20), 0, 0), C.OffWhite, M.SmoothPlastic, DECO)
	Build.text(tag, FRONT, "$0.99/lb", { Color = C.Red, Font = Enum.Font.GothamBold })
	return m
end

function P.CheckoutLane(f: Build.Frame, rng: any, number: number, lit: boolean?)
	local m = f:model("CheckoutLane")
	m:box("Belt", V(2.6, 3.2, 9), V(0, 1.6, 0), C.Charcoal, M.Metal)
	m:box("BeltTop", V(2.2, 0.1, 7), V(0, 3.25, -0.8), C.Black, M.Rubber, DECO)
	m:box("Bagging", V(3.4, 3, 3), V(0, 1.5, 5.4), C.OffWhite, M.Metal)
	local reg = m:at(1.6, 3.3, 3.2, 90)
	reg:box("Base", V(1.6, 0.6, 1.4), V(0, 0.3, 0), C.Charcoal, M.SmoothPlastic, DECO)
	local screen = reg:box("Screen", V(1.2, 0.9, 0.1), V(0, 1.2, 0.4), C.Black, M.SmoothPlastic, DECO)
	if lit then
		Build.text(screen, FRONT, "LANE CLOSED", { Color = C.NeonRed, Font = Enum.Font.Code, Glow = true, Background = C.Void })
	end
	m:box("Pole", V(0.25, 6, 0.25), V(-1, 6, 4.5), C.Chrome, M.Metal, DECO)
	local number_ = m:box("Number", V(1.6, 1.6, 0.3), V(-1, 9.6, 4.5), C.Red, M.SmoothPlastic, DECO)
	local label = Build.text(number_, FRONT, tostring(number), { Color = C.OffWhite, Font = Enum.Font.GothamBlack, Glow = lit })
	label.Parent.Name = "LaneNumber"
	Build.text(number_, Enum.NormalId.Back, tostring(number), { Color = C.OffWhite, Font = Enum.Font.GothamBlack, Glow = lit })
	m:box("CandyRack", V(0.8, 4, 4), V(-1.8, 2, -1), C.Charcoal, M.Metal, DECO)
	for i = 0, 5 do
		m:box("Candy", V(0.6, 0.4, 0.8), V(-1.8, 1 + i * 0.6, -1 + rng:Range(-1.2, 1.2)), rng:Pick({ C.Red, C.Yellow, C.Purple, C.Orange }), M.SmoothPlastic, DECO)
	end
	return m
end

function P.Cart(f: Build.Frame, rng: any, tipped: boolean?, full: boolean?)
	local m = f:model("ShoppingCart")
	local root = if tipped then CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0, math.rad(92)) * CFrame.new(0, -1.3, 0) else CFrame.new()
	local metal = C.Chrome
	local basket = m:box("Basket", V(2.6, 2.1, 3.8), root * CFrame.new(0, 3.1, 0), metal, M.DiamondPlate, { t = 0.45, tags = { "ShoppingCart" } })
	basket.Name = "Basket"
	m:box("Handle", V(2.8, 0.2, 0.2), root * CFrame.new(0, 4.4, 2.2), C.Red, M.Plastic, DECO)
	m:box("Frame", V(2.2, 0.2, 3.6), root * CFrame.new(0, 1.2, 0), metal, M.Metal, DECO)
	for _, x in ipairs({ -1, 1 }) do
		m:box("Strut", V(0.15, 2, 0.15), root * CFrame.new(x, 1.6, 1.6), metal, M.Metal, DECO)
		for _, z in ipairs({ -1.5, 1.5 }) do
			m:cyl("Wheel", 0.25, 0.5, root * CFrame.new(x, 0.25, z), C.Black, M.Rubber, DECO)
		end
	end
	if full then
		for _ = 1, rng:Int(3, 7) do
			m:box("Groceries", V(rng:Range(0.6, 1.2), rng:Range(0.6, 1.2), rng:Range(0.5, 1)), root * CFrame.new(rng:Range(-0.8, 0.8), 3.1 + rng:Range(-0.4, 0.6), rng:Range(-1.4, 1.4)) * CFrame.Angles(rng:Range(0, 1), rng:Range(0, 3), 0), rng:Pick({ C.Red, C.OffWhite, C.Yellow, C.Blue, C.Cardboard }), M.SmoothPlastic, DECO)
		end
	end
	local model = m.Parent :: Model
	model.PrimaryPart = basket
	return m
end

function P.ShoppingBag(f: Build.Frame, rng: any, color: Color3?)
	local m = f:model("ShoppingBag")
	local bagCF = CFrame.new(0, 0.9, 0) * Build.yaw(rng:Range(0, 360))
	m:box("Bag", V(1.6, 1.8, 0.8), bagCF, color or rng:Pick({ C.OffWhite, C.Cardboard, C.DarkRed, C.Navy }), M.SmoothPlastic, { deco = true, tags = { "ShoppingBag" } })
	m:box("Handle", V(0.8, 0.5, 0.05), bagCF * CFrame.new(0, 1.1, 0), C.Charcoal, M.Plastic, DECO)
	return m
end

---------------------------------------------------------------------------
-- arcade
---------------------------------------------------------------------------

local ARCADE_TITLES = { "STAR RAIDER", "GHOST MAZE", "NEON RACER", "ROBO PUNCH", "SPACE PANIC", "DRAGON DUEL", "PIXEL QUEST", "ZOMBIE PARK", "TURBO KART", "BLOCK DROP" }

function P.ArcadeCabinet(f: Build.Frame, rng: any, broken: boolean?, title: string?)
	local m = f:model("ArcadeCabinet")
	local color = rng:Pick({ C.Navy, C.Purple, C.DarkRed, C.Black, C.Teal })
	local model = m.Parent :: Model
	model:AddTag("ArcadeCabinet")
	local body = m:box("Body", V(3, 7, 3.2), V(0, 3.5, 0.2), color, M.SmoothPlastic)
	body.Name = "Body"
	m:box("Control", V(3, 0.8, 1.4), CFrame.new(0, 3.6, -1.6) * CFrame.Angles(math.rad(-20), 0, 0), Build.shade(color, -0.3), M.SmoothPlastic, DECO)
	m:box("Stick", V(0.2, 0.6, 0.2), V(-0.6, 4.2, -1.8), C.Red, M.Plastic, DECO)
	m:ball("Button", 0.3, V(0.5, 4, -1.8), C.Yellow, M.Plastic, DECO)
	m:ball("Button", 0.3, V(0.9, 4, -1.8), C.Blue, M.Plastic, DECO)
	local screen = m:box("Screen", V(2.4, 2, 0.1), CFrame.new(0, 5.2, -1.35) * CFrame.Angles(math.rad(-12), 0, 0), C.Void, M.Glass, { deco = true, tags = { "MallTV" }, attrs = { Mode = if broken then "Off" else "Attract" } })
	screen.Name = "Screen"
	local marquee = m:box("Marquee", V(3, 1, 0.3), V(0, 6.6, -1.2), C.Black, M.SmoothPlastic, DECO)
	local name = title or rng:Pick(ARCADE_TITLES)
	Build.text(marquee, FRONT, name, { Color = rng:Pick({ C.NeonPink, C.NeonCyan, C.NeonYellow, C.NeonGreen }), Font = Enum.Font.Arcade, Glow = not broken })
	if not broken then
		Build.layout(screen, FRONT, C.Void, {
			{ Text = name, Y = 0.1, H = 0.25, Color = C.NeonYellow, Font = Enum.Font.Arcade },
			{ Text = "INSERT COIN", Y = 0.6, H = 0.18, Color = C.OffWhite, Font = Enum.Font.Arcade },
		}, true)
		Build.surfaceLight(screen, FRONT, C.NeonCyan, 0.45, 8, 100)
	else
		m:box("Crack", V(1.6, 0.05, 0.02), CFrame.new(0.2, 5.3, -1.42) * CFrame.Angles(math.rad(-12), 0, math.rad(35)), C.OffWhite, M.SmoothPlastic, DECO)
	end
	m:box("CoinDoor", V(1, 0.9, 0.1), V(0, 1.4, -1.42), C.Charcoal, M.Metal, DECO)
	return m, screen
end

function P.ClawMachine(f: Build.Frame, rng: any)
	local m = f:model("ClawMachine")
	m:box("Base", V(4, 3.6, 4), V(0, 1.8, 0), C.Pink, M.SmoothPlastic)
	m:box("Glass", V(3.8, 4.4, 3.8), V(0, 5.8, 0), C.Glass, M.Glass, { t = 0.7, refl = 0.15, shadow = false })
	m:box("Top", V(4, 1, 4), V(0, 8.5, 0), C.Pink, M.SmoothPlastic, DECO)
	local claw = m:box("Claw", V(0.4, 0.8, 0.4), V(rng:Range(-1, 1), 7.2, rng:Range(-1, 1)), C.Chrome, M.Metal, { deco = true })
	claw.Name = "Claw"
	for _ = 1, 9 do
		P.Plush(m:at(rng:Range(-1.3, 1.3), 3.6, rng:Range(-1.3, 1.3), rng:Range(0, 360)), rng, 0.45)
	end
	local sign = m:box("Sign", V(4, 0.8, 0.1), V(0, 8.5, -2.02), C.Pink, M.SmoothPlastic, DECO)
	Build.text(sign, FRONT, "GRAB-A-PAL", { Color = C.OffWhite, Font = Enum.Font.FredokaOne, Glow = true })
	return m
end

function P.AirHockey(f: Build.Frame, rng: any)
	local m = f:model("AirHockey")
	m:box("Table", V(5, 3, 9), V(0, 1.5, 0), C.Navy, M.SmoothPlastic)
	m:box("Surface", V(4.4, 0.1, 8.4), V(0, 3.05, 0), C.OffWhite, M.SmoothPlastic, DECO)
	m:box("CenterLine", V(4.4, 0.02, 0.2), V(0, 3.11, 0), C.Red, M.SmoothPlastic, DECO)
	m:cylY("Puck", 0.15, 0.8, V(rng:Range(-1.5, 1.5), 3.15, rng:Range(-3, 3)), C.Black, M.SmoothPlastic, DECO)
	return m
end

function P.PrizeCounter(f: Build.Frame, rng: any, length: number)
	local m = f:model("PrizeCounter")
	m:box("Counter", V(length, 3.4, 2.4), V(0, 1.7, 0), C.Purple, M.SmoothPlastic)
	m:box("Glass", V(length, 1.6, 2.2), V(0, 4.2, 0), C.Glass, M.Glass, { t = 0.65, shadow = false })
	for x = -length / 2 + 1, length / 2 - 1, 1.3 do
		if rng:Chance(0.6) then
			m:box("Prize", V(0.6, 0.6, 0.6), V(x, 3.7, rng:Range(-0.6, 0.6)), rng:Pick(TOY), M.SmoothPlastic, DECO)
		end
	end
	-- prize wall
	m:box("Wall", V(length + 2, 10, 0.4), V(0, 5, 3.6), C.Charcoal, M.SmoothPlastic)
	for row = 0, 3 do
		for x = -length / 2, length / 2, 2.2 do
			if rng:Chance(0.7) then
				P.Plush(m:at(x + rng:Range(-0.3, 0.3), 1 + row * 2.3, 3, 0), rng, 0.75)
			end
		end
		m:box("PegShelf", V(length + 1.6, 0.2, 1.2), V(0, 1 + row * 2.3, 3), C.DarkGray, M.Metal, DECO)
	end
	local sign = m:box("Sign", V(10, 1.8, 0.3), V(0, 11, 3.4), C.Black, M.SmoothPlastic, DECO)
	Build.text(sign, FRONT, "PRIZES · 5000 TICKETS", { Color = C.NeonYellow, Font = Enum.Font.Arcade, Glow = true })
	return m
end

function P.Tickets(f: Build.Frame, rng: any, radius: number)
	local m = f:model("Tickets")
	for _ = 1, 10 do
		m:box("TicketStrip", V(rng:Range(0.6, 2.4), 0.03, 0.35), CFrame.new(rng:Range(-radius, radius), 0.03, rng:Range(-radius, radius)) * Build.yaw(rng:Range(0, 360)), C.Orange, M.SmoothPlastic, DECO)
	end
	return m
end

return P
