--[[
	Mall.Garage (ModuleScript)
	Location: ServerScriptService/World/Mall/Garage

	PARKING GARAGE (level B1): concrete pillars, painted stalls, parked cars
	(one with its alarm armed, one with "someone" in it - anomaly fixtures),
	security booth + barrier at the sealed vehicle entrance, a blocked ramp,
	oil stains, carts, sodium lights, dumpster, maintenance doors.
]]

local World = script.Parent.Parent
local Build = require(World.Build)

local C, M = Build.C, Build.M
local V = Vector3.new
local DECO = { deco = true }
local FRONT = Enum.NormalId.Front

local Garage = {}

local SODIUM = Build.rgb(255, 176, 90)

function Garage.Build(ctx)
	local rng = ctx.Rng
	local P, R, U = ctx.Props.Common, ctx.Props.Retail, ctx.Props.Utility
	local f = ctx:area("ParkingGarage")
	local zone = "ParkingGarage"
	local H = 14

	-- ceiling + beams
	f:slab("GarageCeiling", 150, 270, -20, 150, H, 1.5, Build.rgb(84, 84, 82), M.Concrete, nil, true)
	for z = 0, 140, 24 do
		f:box("Beam", V(120, 1.4, 1.6), V(210, H - 0.7, z), Build.rgb(96, 96, 94), M.Concrete, DECO)
	end
	-- pillars
	local labels = { "A", "B", "C", "D", "E" }
	for ix, x in ipairs({ 172, 196, 220, 244 }) do
		for iz, z in ipairs({ 0, 30, 60, 90, 120 }) do
			U.Pillar(f:at(x, 0, z), rng, H, labels[iz] .. ix)
		end
	end
	-- parking stall lines (two banks of stalls between pillar rows) + wheel stops
	local stalls = {}
	for _, bank in ipairs({ { 160, 184 }, { 232, 256 } }) do
		for z = -14, 140, 10 do
			f:box("StallLine", V(bank[2] - bank[1], 0.04, 0.4), V((bank[1] + bank[2]) / 2, 0.03, z), C.OffWhite, M.SmoothPlastic, { deco = true, query = false })
			if z < 140 then
				table.insert(stalls, { X = (bank[1] + bank[2]) / 2, Z = z + 5, Facing = if bank[1] < 200 then 1 else -1 })
			end
		end
	end
	-- driving lane arrows
	for z = 0, 130, 32 do
		local arrow = f:box("LaneArrow", V(4, 0.04, 8), V(208, 0.03, z), C.OffWhite, M.SmoothPlastic, { deco = true, query = false })
		arrow.Transparency = 0.2
	end
	-- cars
	local specials = { Alarm = 6, Occupied = 14 }
	for i, stall in ipairs(stalls) do
		if rng:Chance(0.45) or i == specials.Alarm or i == specials.Occupied then
			local kind = if rng:Chance(0.2) then "Van" else "Sedan"
			local car = U.Car(f:at(stall.X + rng:Range(-1, 1), 0, stall.Z, if stall.Facing > 0 then -90 else 90 + rng:Range(-4, 4)), rng, kind)
			local model = car.Parent :: Model
			if i == specials.Alarm then
				model:AddTag("CarAlarm")
			elseif i == specials.Occupied then
				model:AddTag("OccupiedCar")
			end
		elseif rng:Chance(0.3) then
			P.Stain(f:at(stall.X, 0, stall.Z), rng, rng:Range(2, 4))
		end
	end
	for _ = 1, 10 do
		P.Stain(f:at(rng:Range(155, 265), 0, rng:Range(-15, 145)), rng, rng:Range(1.5, 5))
	end
	for _ = 1, 4 do
		P.Puddle(f:at(rng:Range(190, 230), 0, rng:Range(-10, 140)), rng, rng:Range(4, 8))
	end
	R.Cart(f:at(200, 0, 40, 30), rng)
	R.Cart(f:at(214, 0, 96, 200), rng, true)
	R.Cart(f:at(180, 0, 124, 120), rng, false, true)

	-- sealed vehicle entrance: shutter outside, barrier + booth inside
	P.Shutter(f:at(215, 0, -21, 180), rng, 24, 10, 0.05)
	U.Barrier(f:at(210, 0, -12), rng, 12)
	U.ParkingBooth(f:at(226, 0, -12, 180), rng)
	local exitSign = f:box("ExitSign", V(8, 2, 0.3), V(215, 11, -17), C.Void, M.SmoothPlastic, DECO)
	Build.text(exitSign, Enum.NormalId.Back, "EXIT · CLOSED", { Color = C.NeonRed, Font = Enum.Font.GothamBlack, Glow = true })
	for i = 0, 3 do
		U.Cone(f:at(200 + i * 3, 0, -6), rng)
	end
	-- ramp to level 2 (blocked)
	f:wedge("Ramp", V(20, 7, 40), CFrame.new(255, 3.5, 128), Build.rgb(76, 76, 78), M.Concrete)
	U.Barrier(f:at(255, 0, 106), rng, 18)
	local rampSign = f:box("RampSign", V(10, 2, 0.3), V(255, 11.5, 107), C.Blue, M.SmoothPlastic, DECO)
	Build.text(rampSign, FRONT, "LEVEL 2 CLOSED", { Color = C.OffWhite, Font = Enum.Font.GothamBlack })

	-- hanging signs
	for _, sign in ipairs({ { 208, 20, "← MALL ENTRANCE" }, { 208, 80, "LEVEL B1" }, { 208, 130, "NO PARKING" } }) do
		U.ParkingSign(f:at(sign[1], H - 2.5, sign[2]), rng, sign[3], if sign[3] == "NO PARKING" then C.Red else C.Blue)
		f:box("SignRod", V(0.1, 1.5, 0.1), V(sign[1], H - 0.75, sign[2]), C.Charcoal, M.Metal, DECO)
	end
	-- dumpster + maintenance doors + fire hose
	f:box("Dumpster", V(10, 5, 5), V(262, 2.5, 60), C.DarkGreen, M.Metal)
	f:box("DumpsterLid", V(10.2, 0.4, 5.2), CFrame.new(262, 5.4, 60) * CFrame.Angles(math.rad(12), 0, 0), C.DarkGreen, M.Metal, DECO)
	P.TrashBag(f:at(258, 0, 54), rng)
	P.TrashBag(f:at(256, 0, 55.5), rng)
	for _, z in ipairs({ 30, 100 }) do
		P.DoorFrame(f:at(268.8, 0, z, 90), rng, 5, 8.5)
		f:box("MaintenanceDoor", V(0.4, 8.5, 5), V(268.6, 4.25, z), C.Steel, M.Metal, { tags = { "GarageDoor" } })
		local label = f:box("DoorLabel", V(0.1, 0.8, 3), V(268.3, 7.2, z), C.Yellow, M.SmoothPlastic, DECO)
		Build.text(label, Enum.NormalId.Left, "MAINTENANCE", { Color = C.Black, Font = Enum.Font.GothamBold })
	end
	local hose = f:box("FireHose", V(0.6, 4, 3), V(151, 4, 40), C.Red, M.Metal, DECO)
	Build.text(hose, Enum.NormalId.Right, "FIRE HOSE", { Color = C.OffWhite, Font = Enum.Font.GothamBold })

	-- sodium lights (many dead / flickering)
	for x = 162, 258, 24 do
		for z = -8, 140, 24 do
			local state = if rng:Chance(0.5) then "Dead" elseif rng:Chance(0.35) then "Flicker" else "On"
			P.CeilingLight(f:at(x, H, z + 12, 90), rng, zone, 0.8, 26, state, SODIUM)
		end
	end
	P.EmergencyLight(f:at(151, 9, 10, -90), rng, true)
	P.SecurityCamera(f:at(152, H - 1, -18, -135), rng)
	P.SecurityCamera(f:at(268, H - 1, 148, 45), rng)
	P.PipeRun(f:at(210, H - 1.2, 146), rng, 116, 2)
	ctx:ceilingNodes(zone, 152, 268, -18, 148, H - 0.2, 18)

	for _, spot in ipairs({ { 208, 10 }, { 208, 60 }, { 208, 110 }, { 170, 80 }, { 246, 40 } }) do
		ctx:floorNode("Floor", zone, V(spot[1], 0, spot[2]), V(rng:Range(-1, 1), 0, rng:Range(-1, 1)))
	end
	ctx:floorNode("Dark", zone, V(262, 0, 140), V(-1, 0, 0))
	ctx:floorNode("Dark", zone, V(156, 0, -14), V(1, 0, 0))
	ctx:floorNode("RunLane", zone, V(208, 0, -10), V(0, 0, 1), { Length = 150 })
	ctx:floorNode("Pillar", zone, V(196, 0, 60), V(1, 0, 0))
	ctx:floorNode("Pillar", zone, V(244, 0, 90), V(-1, 0, 0))
	ctx:pickup(V(226, 1.2, -12))
	ctx:pickup(V(262, 5.8, 60))
	ctx:pickup(V(172, 0.6, 118))
end

return Garage
