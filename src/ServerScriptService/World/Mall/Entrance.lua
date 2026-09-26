--[[
	Mall.Entrance (ModuleScript)
	Location: ServerScriptService/World/Mall/Entrance

	MAIN ENTRANCE: glass facade with jammed / shattered automatic doors,
	vestibule with cart corral, entry lobby with the mall directory, benches,
	dead planters, ATM, payphone, ad panels, a half-closed security shutter
	and scattered glass. Investigators spawn here.
]]

local World = script.Parent.Parent
local Build = require(World.Build)

local C, M = Build.C, Build.M
local V = Vector3.new
local DECO = { deco = true }

local Entrance = {}

function Entrance.Build(ctx)
	local rng = ctx.Rng
	local P, R, U = ctx.Props.Common, ctx.Props.Retail, ctx.Props.Utility
	local f = ctx:area("Entrance")
	local zone = "Entrance"

	-- outer facade: glass + two sets of automatic doors (blocked)
	P.GlassFront(f:at(-23.5, 0, -176), rng, 13, 12)
	P.GlassFront(f:at(0, 0, -176), rng, 14, 12)
	P.GlassFront(f:at(23.5, 0, -176), rng, 13, 12, true)
	U.AutoDoors(f:at(-12, 0, -176, 180), rng, 10, 10, "Closed")
	U.AutoDoors(f:at(12, 0, -176, 180), rng, 10, 10, "Broken")
	f:box("DoorChain", V(8, 0.3, 0.2), CFrame.new(-12, 4, -176.6) * CFrame.Angles(0, 0, 0.1), C.Steel, M.Metal, DECO)
	f:box("Padlock", V(0.6, 0.8, 0.4), V(-12, 3.7, -176.8), C.Yellow, M.Metal, DECO)
	local sign = f:box("ClosedSign", V(3.4, 2, 0.1), V(-12, 7, -175.8), C.OffWhite, M.SmoothPlastic, DECO)
	Build.text(sign, Enum.NormalId.Back, "CLOSED\nUNTIL FURTHER\nNOTICE", { Color = C.Red, Font = Enum.Font.GothamBlack })
	Build.text(sign, Enum.NormalId.Front, "CLOSED\nUNTIL FURTHER\nNOTICE", { Color = C.Red, Font = Enum.Font.GothamBlack })

	-- vestibule (Z -176..-164)
	f:box("VestibuleMat", V(56, 0.08, 10), V(0, 0.04, -170), C.Charcoal, M.Fabric, DECO)
	P.GlassFront(f:at(-23.5, 0, -164), rng, 13, 11)
	P.GlassFront(f:at(0, 0, -164), rng, 14, 11)
	P.GlassFront(f:at(23.5, 0, -164), rng, 13, 11)
	U.AutoDoors(f:at(-12, 0, -164, 180), rng, 10, 10, "Open")
	U.AutoDoors(f:at(12, 0, -164, 180), rng, 10, 10, "Jammed")
	f:box("VestibuleHeader", V(64, 7, 1), V(0, 14.5, -164), C.Charcoal, M.Metal)
	for _, x in ipairs({ -12, 12 }) do
		P.ExitSign(f:at(x, 12.4, -163.3), rng)
	end
	-- cart corral
	for i = 0, 3 do
		R.Cart(f:at(-27, 0, -172 + i * 0.9, 90), rng)
	end
	f:box("CorralRail", V(0.3, 3.6, 8), V(-24.5, 1.8, -170), C.Chrome, M.Metal)
	P.Litter(f:at(8, 0, -170), rng, 5, 10)
	for _ = 1, 8 do
		f:box("DeadLeaf", V(0.6, 0.04, 0.4), CFrame.new(rng:Range(0, 30), 0.03, rng:Range(-175, -166)) * Build.yaw(rng:Range(0, 360)), C.DeadPlant, M.Grass, DECO)
	end
	P.BrokenGlass(f:at(14, 0, -172), rng, 5, 22)

	-- lobby (Z -164..-130)
	P.Directory(f:at(0, 0, -150), rng, { "A1  FRESHWAY MARKET", "A2  VOLTZONE", "A3  NOIR & CO.", "B1  STARLIGHT CINEMA", "B2  PIXEL PALACE", "B3  TOY TOWN", "C   FOOD COURT", "P   PARKING (STAFF)" })
	for _, x in ipairs({ -20, 20 }) do
		P.Planter(f:at(x, 0, -146), rng, 8, 6, true)
		P.Bench(f:at(x, 0, -155, 0), rng)
		P.TrashCan(f:at(x + (if x < 0 then 6 else -6), 0, -155), rng, x > 0)
	end
	P.ATM(f:at(-30.2, 0, -140, -90), rng)
	P.Payphone(f:at(-30.4, 0, -157, -90), rng)
	P.AdPanel(f:at(-31.2, 0, -148, -90), rng, "SUMMER SALE", "EVERYTHING 70% OFF", C.DarkRed, false)
	P.AdPanel(f:at(31.2, 0, -140, 90), rng, "OAKRIDGE MALL", "OPEN LATE · 10AM-10PM", C.Navy, true)
	P.Poster(f:at(31.4, 7, -160, 90), rng, "MISSING", "HAVE YOU SEEN THIS PERSON?", C.OffWhite, true)
	P.Poster(f:at(-31.4, 7, -133, -90), rng, "MALL WALK", "EVERY SUNDAY 7AM", C.Teal, true)
	P.WetFloorSign(f:at(6, 0, -140), rng)
	P.Litter(f:at(-6, 0, -142), rng, 8, 14)
	P.CeilingPanelFallen(f:at(10, 0, -152), rng)

	-- staff closet behind a half-closed security shutter (east wall)
	P.Shutter(f:at(32.6, 0, -150, 90), rng, 6, 8.5, 0.45)
	f:wallX("ClosetWall", 32.5, 42, -157, 10, 1, C.DarkGray, M.Concrete)
	f:wallX("ClosetWall", 32.5, 42, -143, 10, 1, C.DarkGray, M.Concrete)
	f:wallZ("ClosetWall", -157, -143, 42, 10, 1, C.DarkGray, M.Concrete)
	f:slab("ClosetCeiling", 32, 42, -157, -143, 10, 1, C.DarkGray, M.Concrete, nil, true)
	f:slab("ClosetFloor", 32, 42, -157, -143, 0, 1, C.Asphalt, M.Concrete)
	P.Mop(f:at(38, 0, -154), rng)
	U.MetalShelf(f:at(40, 0, -150, 90), rng, 8, 8)
	P.EmergencyLight(f:at(37, 8.6, -156.2), rng, true)

	-- ceiling + lighting
	ctx:dropCeiling(f, zone, -32, 32, -164, -130, 18, { Dead = 0.35, Flicker = 0.25, Hanging = 0.1, Brightness = 0.8 })
	f:slab("VestibuleCeiling", -32, 32, -176, -164, 18, 1, C.Charcoal, M.Metal, nil, true)
	P.EmergencyLight(f:at(-31.4, 12, -135, -90), rng, true)
	P.EmergencyLight(f:at(31.4, 12, -160, 90), rng, false)
	P.SecurityCamera(f:at(30.5, 17, -133, 45), rng)
	P.FireExtinguisher(f:at(-31.4, 0, -162, -90), rng)
	local banner = f:box("WelcomeBanner", V(30, 4, 0.2), V(0, 15.5, -163.2), C.Navy, M.Fabric, DECO)
	Build.text(banner, Enum.NormalId.Back, "WELCOME TO OAKRIDGE MALL", { Color = C.OffWhite, Font = Enum.Font.GothamBlack })

	-- spawns & nodes
	for i = 0, 5 do
		ctx:playerSpawn(V(-12.5 + i * 5, 3, -142), V(0, 0, 1))
	end
	ctx:floorNode("Floor", zone, V(-8, 0, -158), V(0, 0, 1))
	ctx:floorNode("Floor", zone, V(24, 0, -138), V(-1, 0, 0))
	ctx:floorNode("Dark", zone, V(36, 0, -150), V(-1, 0, 0))
	ctx:floorNode("Glass", zone, V(-12, 0, -177.5), V(0, 0, 1), { Outside = true })
	ctx:floorNode("Glass", zone, V(20, 0, -178), V(0, 0, 1), { Outside = true })
	ctx:pickup(V(-24, 3.4, -140))
	ctx:pickup(V(38, 1, -152))
end

return Entrance
