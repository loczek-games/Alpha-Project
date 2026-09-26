--[[
	Mall.Shell (ModuleScript)
	Location: ServerScriptService/World/Mall/Shell

	Floors and walls of the whole Dead Mall (see DeadMall header for the
	layout). Room interiors, ceilings and roofs are built by the area modules.
	Openings are storefronts, archways and doorways; doors themselves are
	placed by the area modules (InteractionService doors).
]]

local World = script.Parent.Parent
local Build = require(World.Build)

local C, M = Build.C, Build.M

local Shell = {}

local WALL = Build.rgb(112, 106, 98)
local WALL_DARK = Build.rgb(70, 68, 66)
local EXTERIOR = Build.rgb(58, 56, 56)
local SERVICE = Build.rgb(96, 100, 96)

function Shell.Build(ctx)
	local S = ctx.S
	local structural = { shadow = true }

	---------------------------------------------------------------------------
	-- floors (top at y = 0)
	---------------------------------------------------------------------------
	local function floor(name: string, x0: number, x1: number, z0: number, z1: number, color: Color3, material: Enum.Material, surface: string?)
		local p = S:slab(name, x0, x1, z0, z1, 0, 1, color, material, structural)
		p.CastShadow = false
		if surface then
			p:SetAttribute("FootstepSurface", surface)
		end
		return p
	end
	floor("EntranceFloor", -32, 32, -176, -130, Build.rgb(188, 180, 164), M.Marble)
	floor("GrandHallFloor", -32, 32, -130, 150, Build.rgb(196, 190, 176), M.Marble)
	floor("SupermarketFloor", -150, -32, -130, -30, Build.rgb(176, 178, 170), M.SmoothPlastic)
	floor("ElectronicsFloor", -100, -32, -30, 42, Build.rgb(58, 60, 66), M.SmoothPlastic)
	floor("ClothingFloor", -100, -32, 42, 120, Build.rgb(118, 88, 62), M.WoodPlanks)
	floor("RestroomFloor", -100, -32, 120, 150, Build.rgb(196, 204, 202), M.SmoothPlastic, "Tile")
	floor("CinemaFloor", 32, 100, -130, -38, Build.rgb(84, 22, 30), M.Fabric)
	floor("TheaterFloor", 112, 190, -130, -34, Build.rgb(60, 18, 26), M.Fabric)
	floor("ArcadeFloor", 32, 100, -38, 42, Build.rgb(40, 26, 64), M.Fabric)
	floor("ToyFloor", 32, 100, 42, 120, Build.rgb(150, 190, 214), M.SmoothPlastic)
	floor("BookFloor", 32, 100, 120, 150, Build.rgb(104, 76, 54), M.WoodPlanks)
	floor("FoodCourtFloor", -100, 100, 150, 212, Build.rgb(204, 194, 170), M.Marble)
	floor("KitchenFloor", -100, 100, 212, 244, Build.rgb(120, 70, 56), M.Slate, "Tile")
	floor("WestHallFloor", -112, -100, -30, 254, Build.rgb(118, 118, 112), M.Concrete)
	floor("NorthHallFloor", -100, 100, 244, 254, Build.rgb(118, 118, 112), M.Concrete)
	floor("CinemaHallFloor", 100, 112, -130, -38, Build.rgb(84, 22, 30), M.Fabric)
	floor("EastHallFloor", 100, 112, -38, 254, Build.rgb(118, 118, 112), M.Concrete)
	floor("BackOfHouseFloor", 112, 150, -30, 150, Build.rgb(108, 110, 106), M.Concrete)
	floor("GarageFloor", 150, 270, -20, 150, Build.rgb(70, 70, 72), M.Asphalt)

	---------------------------------------------------------------------------
	-- walls
	---------------------------------------------------------------------------
	local function wx(name, x0, x1, z, h, t, color, mat, openings)
		S:wallX(name, x0, x1, z, h, t, color, mat or M.Plaster, openings, structural)
	end
	local function wz(name, z0, z1, x, h, t, color, mat, openings)
		S:wallZ(name, z0, z1, x, h, t, color, mat or M.Plaster, openings, structural)
	end

	-- entrance
	wx("EntranceFacadeHeader", -32, 32, -176, 18, 2, EXTERIOR, M.Concrete, { { Center = 0, Width = 60, Top = 12 } })
	wz("EntranceWall", -176, -130, -32, 18, 1, WALL, M.Plaster)
	wz("EntranceWall", -176, -130, 32, 18, 1, WALL, M.Plaster, { { Center = -150, Width = 6, Top = 8.5 } })
	wx("EntranceHeader", -32, 32, -130, 36, 1, WALL, M.Plaster, { { Center = 0, Width = 62, Top = 18 } })

	-- grand hall storefront walls (36 high; balconies at 16 are built by GrandHall)
	wz("HallWallWest", -130, 150, -32, 36, 1, WALL, M.Plaster, {
		{ Center = -80, Width = 60, Top = 13 }, -- supermarket
		{ Center = 7, Width = 50, Top = 12 }, -- electronics
		{ Center = 81, Width = 58, Top = 12 }, -- clothing
		{ Center = 136, Width = 8, Top = 10 }, -- restrooms
	})
	wz("HallWallEast", -130, 150, 32, 36, 1, WALL, M.Plaster, {
		{ Center = -85, Width = 50, Top = 14 }, -- cinema
		{ Center = 2, Width = 50, Top = 12 }, -- arcade
		{ Center = 81, Width = 56, Top = 12 }, -- toy store
		{ Center = 136, Width = 20, Top = 10 }, -- book nook (shuttered)
	})
	wx("FoodCourtHeader", -32, 32, 150, 36, 1, WALL, M.Plaster, { { Center = 0, Width = 62, Top = 30 } })

	-- supermarket
	wx("SupermarketSouth", -150, -32, -130, 18, 2, EXTERIOR, M.Concrete)
	wz("SupermarketWest", -130, -30, -150, 18, 2, EXTERIOR, M.Concrete)
	wx("SupermarketNorth", -150, -100, -30, 18, 1, WALL_DARK, M.Concrete, { { Center = -106, Width = 5, Top = 8.5 } })
	wx("Divider", -100, -32, -28, 18, 4, WALL, M.Plaster)

	-- west stores
	wz("ElectronicsBack", -26, 40, -100, 16, 1, WALL_DARK, M.Plaster, { { Center = 30, Width = 5, Top = 8.5 } })
	wx("Divider", -100, -32, 42, 16, 4, WALL, M.Plaster)
	wz("ClothingBack", 44, 118, -100, 16, 1, WALL_DARK, M.Plaster, { { Center = 110, Width = 5, Top = 8.5 } })
	wx("Divider", -100, -32, 120, 16, 4, WALL, M.Plaster)
	wz("RestroomBack", 122, 150, -100, 12, 1, WALL_DARK, M.Plaster, { { Center = 143, Width = 4.5, Top = 8.5 } })

	-- west service hall
	wz("WestHallOuter", -30, 254, -112, 12, 2, EXTERIOR, M.Concrete)

	-- food court shell
	wx("FoodCourtSouth", -100, -32, 150, 30, 1, WALL, M.Plaster)
	wx("FoodCourtSouth", 32, 100, 150, 30, 1, WALL, M.Plaster)
	wz("FoodCourtWest", 150, 244, -100, 30, 1, WALL, M.Plaster, { { Center = 200, Width = 5, Top = 8.5 } })
	wz("FoodCourtEast", 150, 244, 100, 30, 1, WALL, M.Plaster, { { Center = 200, Width = 5, Top = 8.5 } })
	wx("FoodCourtNorth", -100, 100, 244, 30, 1, WALL_DARK, M.Concrete, {
		{ Center = -80, Width = 5, Top = 8.5 },
		{ Center = -40, Width = 5, Top = 8.5 },
		{ Center = 0, Width = 5, Top = 8.5 },
		{ Center = 40, Width = 5, Top = 8.5 },
		{ Center = 80, Width = 5, Top = 8.5 },
	})
	wx("NorthHallOuter", -112, 112, 254, 12, 2, EXTERIOR, M.Concrete)

	-- cinema
	wx("CinemaSouth", 32, 112, -130, 20, 2, EXTERIOR, M.Concrete)
	wx("Divider", 32, 100, -38, 20, 4, WALL_DARK, M.Plaster)
	wz("CinemaEast", -130, -40, 100, 20, 1, Build.rgb(70, 30, 36), M.Fabric, { { Center = -85, Width = 12, Top = 10 } })
	wx("StaffDoorWall", 100, 112, -38, 12, 1, SERVICE, M.Concrete, { { Center = 106, Width = 5, Top = 8.5 } })

	-- theatres
	wx("TheaterSouth", 112, 190, -130, 24, 2, EXTERIOR, M.Concrete)
	wx("TheaterWall", 112, 190, -98.5, 24, 3, Build.rgb(40, 20, 24), M.Fabric)
	wx("TheaterWall", 112, 190, -65.5, 24, 3, Build.rgb(40, 20, 24), M.Fabric)
	wx("TheaterNorth", 112, 190, -34, 24, 1, WALL_DARK, M.Concrete)
	wz("TheaterEast", -130, -34, 190, 24, 2, EXTERIOR, M.Concrete)
	wz("TheaterWest", -130, -34, 112, 24, 1, Build.rgb(70, 30, 36), M.Fabric, {
		{ Center = -115, Width = 6, Top = 9 },
		{ Center = -82, Width = 6, Top = 9 },
		{ Center = -49, Width = 6, Top = 9 },
	})

	-- east stores
	wz("ArcadeBack", -36, 40, 100, 16, 1, WALL_DARK, M.Plaster, { { Center = 30, Width = 5, Top = 8.5 } })
	wx("Divider", 32, 100, 42, 16, 4, WALL, M.Plaster)
	wz("ToyBack", 44, 118, 100, 16, 1, WALL_DARK, M.Plaster, { { Center = 110, Width = 5, Top = 8.5 } })
	wx("Divider", 32, 100, 120, 16, 4, WALL, M.Plaster)
	wz("BookBack", 122, 150, 100, 12, 1, WALL_DARK, M.Plaster, { { Center = 140, Width = 5, Top = 8.5 } })
	wz("Filler", -38, -36, 100, 20, 1, WALL_DARK, M.Plaster)

	-- east service hall + back of house
	wz("EastHallOuter", 150, 254, 112, 12, 2, EXTERIOR, M.Concrete)
	wz("BackOfHouseWest", -30, 150, 112, 12, 1, SERVICE, M.Concrete, {
		{ Center = -16, Width = 5, Top = 8.5 }, -- projection
		{ Center = 10, Width = 6, Top = 9 }, -- garage link
		{ Center = 36, Width = 5, Top = 8.5 }, -- maintenance
		{ Center = 68, Width = 5, Top = 8.5 }, -- lockers
		{ Center = 97, Width = 5, Top = 8.5 }, -- electrical
		{ Center = 130, Width = 5, Top = 8.5 }, -- security (locked)
	})
	wz("Filler", -34, -30, 112, 24, 1, WALL_DARK, M.Concrete)
	wx("BackOfHouseSouth", 112, 150, -30, 12, 1, SERVICE, M.Concrete)
	for _, z in ipairs({ 0, 20, 52, 84, 110 }) do
		wx("BackOfHouseDivider", 112, 150, z, 12, 4, SERVICE, M.Concrete)
	end
	wx("BackOfHouseNorth", 112, 150, 150, 12, 1, SERVICE, M.Concrete)
	wz("BackOfHouseEast", -30, -20, 150, 12, 1, SERVICE, M.Concrete)

	-- garage
	wz("GarageWest", -20, 150, 150, 14, 1, Build.rgb(90, 90, 88), M.Concrete, { { Center = 10, Width = 6, Top = 9 } })
	wx("GarageSouth", 150, 270, -20, 14, 2, EXTERIOR, M.Concrete, { { Center = 215, Width = 24, Top = 10 } })
	wz("GarageEast", -20, 150, 270, 14, 2, EXTERIOR, M.Concrete)
	wx("GarageNorth", 150, 270, 150, 14, 2, EXTERIOR, M.Concrete)

	-- blank roof caps over thin service corridors
	S:slab("WestHallCeiling", -112, -100, -30, 254, 12, 1, C.DarkGray, M.Concrete, structural, true)
	S:slab("NorthHallCeiling", -100, 100, 244, 254, 12, 1, C.DarkGray, M.Concrete, structural, true)
	S:slab("EastHallCeiling", 100, 112, -38, 254, 12, 1, C.DarkGray, M.Concrete, structural, true)
end

return Shell
