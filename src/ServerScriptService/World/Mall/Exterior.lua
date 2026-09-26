--[[
	Mall.Exterior (ModuleScript)
	Location: ServerScriptService/World/Mall/Exterior

	What investigators see through the entrance glass: the empty night
	parking lot, abandoned cars, one working lamp, the broken mall sign
	pylon and a fence. Not reachable (the doors are chained / blocked).
]]

local World = script.Parent.Parent
local Build = require(World.Build)

local C, M = Build.C, Build.M
local V = Vector3.new
local DECO = { deco = true }

local Exterior = {}

function Exterior.Build(ctx)
	local rng = ctx.Rng
	local _P, U = ctx.Props.Common, ctx.Props.Utility
	local f = ctx:area("Exterior")

	f:slab("Sidewalk", -60, 60, -196, -176, 0.4, 1.4, C.LightGray, M.Concrete)
	f:slab("ParkingLot", -140, 140, -330, -196, 0, 1, C.Asphalt, M.Asphalt)
	-- canopy over the entrance with the mall name
	f:box("Canopy", V(70, 1.4, 16), V(0, 18.7, -184), C.Charcoal, M.Metal)
	for _, x in ipairs({ -33, 33 }) do
		f:box("CanopyPost", V(1.2, 18, 1.2), V(x, 9, -191), C.Charcoal, M.Metal, DECO)
	end
	local name = f:box("MallName", V(46, 5, 0.6), V(0, 22.5, -176.8), C.Void, M.SmoothPlastic, DECO)
	Build.text(name, Enum.NormalId.Front, "OAKR DGE  MALL", { Color = Build.shade(C.NeonRed, -0.5), Font = Enum.Font.GothamBlack })
	f:box("Facade", V(118, 26, 2), V(-91, 13, -177.5), Build.rgb(60, 56, 54), M.Brick)
	f:box("Facade", V(118, 26, 2), V(91, 13, -177.5), Build.rgb(60, 56, 54), M.Brick)
	f:box("FacadeTop", V(64, 8, 2), V(0, 22, -177.5), Build.rgb(60, 56, 54), M.Brick)
	-- lot markings, cars, lamps
	for x = -120, 120, 12 do
		f:box("LotLine", V(0.4, 0.04, 14), V(x, 0.03, -214), C.OffWhite, M.SmoothPlastic, { deco = true, query = false })
		f:box("LotLine", V(0.4, 0.04, 14), V(x, 0.03, -250), C.OffWhite, M.SmoothPlastic, { deco = true, query = false })
	end
	for _, spot in ipairs({ { -54, -214 }, { -30, -250 }, { 18, -214 }, { 66, -250 }, { 90, -214 } }) do
		U.Car(f:at(spot[1], 0, spot[2], rng:Range(-6, 6)), rng)
	end
	ctx.Props.Retail.Cart(f:at(8, 0, -228, 40), rng, true)
	for i, x in ipairs({ -80, 0, 80 }) do
		f:box("LampPost", V(1, 24, 1), V(x, 12, -232), C.Charcoal, M.Metal)
		f:box("LampHead", V(4, 1, 2), V(x, 24, -232), C.Charcoal, M.Metal, DECO)
		if i == 2 then
			local bulb = f:box("LampBulb", V(3, 0.3, 1.4), V(x, 23.4, -232), C.WarmLight, M.Neon, { deco = true, tags = { "FlickerLight" } })
			Build.spot(bulb, Enum.NormalId.Bottom, Build.rgb(255, 190, 120), 2, 60, 110):SetAttribute("BaseBrightness", 2)
		end
	end
	-- sign pylon
	f:box("Pylon", V(4, 40, 4), V(-100, 20, -300), C.Charcoal, M.Metal)
	local board = f:box("PylonSign", V(20, 10, 2), V(-100, 36, -300), C.Navy, M.SmoothPlastic, DECO)
	Build.text(board, Enum.NormalId.Back, "OAKRIDGE\nMALL", { Color = C.OffWhite, Font = Enum.Font.GothamBlack })
	-- fence + dead trees on the horizon
	for x = -140, 140, 10 do
		f:box("FencePost", V(0.4, 8, 0.4), V(x, 4, -326), C.Steel, M.Metal, DECO)
	end
	f:box("Fence", V(280, 8, 0.1), V(0, 4, -326), C.Steel, M.DiamondPlate, { deco = true, t = 0.6 })
	for _ = 1, 8 do
		local x = rng:Range(-130, 130)
		local h = rng:Range(10, 18)
		f:cylY("DeadTree", h, 1, V(x, h / 2, rng:Range(-322, -300)), C.WoodDark, M.Wood, DECO)
	end
	-- invisible barrier so nothing can wander outside
	f:box("Barrier", V(80, 30, 2), V(0, 15, -178.5), C.Black, M.SmoothPlastic, { t = 1, shadow = false })
end

return Exterior
