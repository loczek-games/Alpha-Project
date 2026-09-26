--[[
	DeadMall (ModuleScript)
	Location: ServerScriptService/World/DeadMall

	Builds the whole DEAD MALL map as one Model named "ActiveMap":

	  ActiveMap
	    Structure        floors, walls, ceilings, roof, skylights
	    Areas/<Area>     every room's props (one folder per area)
	    Interactables    doors, lockers, drawers, elevator, payphone, security PC, radio, breaker
	    Zones            (Model, Persistent) invisible bounds parts, one per zone id
	    AnomalyNodes
	      Spawns                marker parts (Kind + Zone attributes)
	      CeilingCrawlerNodes   ceiling navigation points for the Ceiling Crawler
	    PlayerSpawns     where investigators start
	    PickupSpots      battery spawn points

	Layout (studs, X east, Z north, floor top at y = 0):
	  Entrance       X -32..32    Z -176..-130
	  Grand Hall     X -32..32    Z -130..150   (36 high, balconies at y 16, escalators)
	  Supermarket    X -150..-32  Z -130..-30
	  Electronics    X -100..-32  Z  -26..40
	  Clothing       X -100..-32  Z   44..118
	  Restrooms      X -100..-32  Z  122..150
	  Cinema lobby   X  32..100   Z -130..-40   (+ 3 theatres X 112..190)
	  Arcade         X  32..100   Z  -36..40
	  Toy Store      X  32..100   Z   44..118
	  Book Nook      X  32..100   Z  122..150   (closed)
	  Food Court     X -100..100  Z  150..244   (5 restaurants on the north side)
	  Service halls  X -112..-100 / 100..112 (west/east) and Z 244..254 (north)
	  Back of house  X 112..150   Z  -30..150   (projection, garage link, maintenance, lockers, electrical, security)
	  Parking Garage X 150..270   Z  -20..150

	Build() only uses Instance APIs, so it runs in Roblox and in Lune (bake).
]]

local World = script.Parent
local Build = require(World.Build)
local Rng = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Rng"))

local DeadMall = {}

local C, M = Build.C, Build.M
local V = Vector3.new

DeadMall.MapId = "DeadMall"

local MapConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("MapConfig"))
local MAP = MapConfig.Maps.DeadMall

---------------------------------------------------------------------------
-- context shared with area builders
---------------------------------------------------------------------------

local Ctx = {}
Ctx.__index = Ctx

function Ctx.area(self, name: string): Build.Frame
	local folder = self.AreasFolder:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = self.AreasFolder
	end
	return Build.frame(folder)
end

function Ctx.spawnNode(self, kind: string, zone: string, cframe: CFrame, attrs: { [string]: any }?)
	local p = Build.part(self.SpawnsFolder, kind, V(1, 1, 1), cframe, C.Black, M.SmoothPlastic, { t = 1, collide = false, query = false, shadow = false })
	p.CanTouch = false
	Build.attrs(p, { Kind = kind, Zone = zone })
	if attrs then
		Build.attrs(p, attrs)
	end
	return p
end

-- facing = world direction the marker's front (-Z) should look
function Ctx.floorNode(self, kind: string, zone: string, position: Vector3, facing: Vector3?, attrs: { [string]: any }?)
	local look = facing or V(0, 0, -1)
	return self:spawnNode(kind, zone, Build.lookAt(position, position + V(look.X, 0, look.Z)), attrs)
end

function Ctx.ceilingNode(self, zone: string, position: Vector3)
	local p = Build.part(self.CrawlerFolder, "CeilingNode", V(1, 1, 1), CFrame.new(position), C.Black, M.SmoothPlastic, { t = 1, collide = false, query = false, shadow = false })
	p.CanTouch = false
	Build.attrs(p, { Zone = zone })
	return p
end

-- grid of ceiling nodes inside a rectangle at ceiling height y
function Ctx.ceilingNodes(self, zone: string, x0: number, x1: number, z0: number, z1: number, y: number, spacing: number?)
	local s = spacing or 16
	local nx = math.max(1, math.floor((x1 - x0) / s))
	local nz = math.max(1, math.floor((z1 - z0) / s))
	for i = 0, nx - 1 do
		for j = 0, nz - 1 do
			self:ceilingNode(zone, V(x0 + (i + 0.5) * (x1 - x0) / nx, y - 0.6, z0 + (j + 0.5) * (z1 - z0) / nz))
		end
	end
end

function Ctx.pickup(self, position: Vector3, kind: string?)
	local p = Build.part(self.PickupFolder, "PickupSpot", V(1, 1, 1), CFrame.new(position), C.Black, M.SmoothPlastic, { t = 1, collide = false, query = false, shadow = false })
	p.CanTouch = false
	p:SetAttribute("Kind", kind or "Battery")
	return p
end

function Ctx.playerSpawn(self, position: Vector3, facing: Vector3)
	local p = Build.part(self.PlayerSpawnFolder, "PlayerSpawn", V(4, 1, 4), Build.lookAt(position, position + facing), C.Black, M.SmoothPlastic, { t = 1, collide = false, query = false, shadow = false })
	p.CanTouch = false
	return p
end

-- drop ceiling: slab + grid + light troffers (some dead/flickering) + missing tiles
function Ctx.dropCeiling(self, f: Build.Frame, zone: string, x0: number, x1: number, z0: number, z1: number, y: number, opts: any?)
	local o = opts or {}
	local rng = self.Rng
	local color = o.Color or C.OffWhite
	f:slab("Ceiling", x0, x1, z0, z1, y, 1, color, M.Plaster, { shadow = true }, true)
	local grid = o.Grid ~= false
	if grid then
		for x = x0 + 8, x1 - 1, 8 do
			f:box("CeilingGrid", V(0.25, 0.15, z1 - z0), V(x, y - 0.07, (z0 + z1) / 2), C.LightGray, M.Metal, { deco = true, query = false })
		end
		for z = z0 + 8, z1 - 1, 8 do
			f:box("CeilingGrid", V(x1 - x0, 0.15, 0.25), V((x0 + x1) / 2, y - 0.07, z), C.LightGray, M.Metal, { deco = true, query = false })
		end
	end
	local spacing = o.LightSpacing or 16
	local lights = self.Props.Common
	for x = x0 + spacing / 2, x1 - 1, spacing do
		for z = z0 + spacing / 2, z1 - 1, spacing do
			local roll = rng:Next()
			local state = if roll < (o.Dead or 0.35) then "Dead" elseif roll < (o.Dead or 0.35) + (o.Flicker or 0.2) then "Flicker" else "On"
			if o.Hanging and rng:Chance(o.Hanging) then
				state = "Hanging"
			end
			lights.CeilingLight(f:at(x, y, z), rng, zone, o.Brightness or 0.9, o.Range or 22, state, o.LightColor)
		end
	end
	-- missing / fallen tiles
	for _ = 1, o.Missing or math.floor((x1 - x0) * (z1 - z0) / 900) do
		local x = rng:Range(x0 + 4, x1 - 4)
		local z = rng:Range(z0 + 4, z1 - 4)
		f:box("MissingTile", V(3.9, 0.3, 3.9), V(x, y - 0.1, z), C.Void, M.SmoothPlastic, { deco = true, query = false })
		if rng:Chance(0.5) then
			lights.CeilingPanelFallen(f:at(x + rng:Range(-2, 2), 0, z + rng:Range(-2, 2)), rng)
		end
	end
	if o.Vents ~= false then
		for _ = 1, math.max(1, math.floor((x1 - x0) * (z1 - z0) / 1200)) do
			lights.Vent(f:at(rng:Range(x0 + 4, x1 - 4), y, rng:Range(z0 + 4, z1 - 4)), rng)
		end
	end
	if o.Nodes ~= false then
		self:ceilingNodes(zone, x0 + 2, x1 - 2, z0 + 2, z1 - 2, y, o.NodeSpacing or 16)
	end
end

---------------------------------------------------------------------------
-- build
---------------------------------------------------------------------------

local function folder(parent: Instance, name: string, className: string?): Instance
	local f = Instance.new(className or "Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function DeadMall.Build(): Model
	local root = Instance.new("Model")
	root.Name = "ActiveMap"
	root:SetAttribute("MapId", DeadMall.MapId)
	root:SetAttribute("DisplayName", MAP.Name)

	local ctx = setmetatable({}, Ctx) :: any
	ctx.Root = root
	ctx.Rng = Rng.new(20241031)
	ctx.Build = Build
	ctx.Props = {
		Common = require(World.Props.Common),
		Retail = require(World.Props.Retail),
		Food = require(World.Props.Food),
		Utility = require(World.Props.Utility),
	}
	ctx.I = require(World.Interactables)
	ctx.StructureFolder = folder(root, "Structure")
	ctx.AreasFolder = folder(root, "Areas")
	ctx.InteractFolder = folder(root, "Interactables")
	local zones = folder(root, "Zones", "Model") :: Model
	zones.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	ctx.ZonesFolder = zones
	local nodes = folder(root, "AnomalyNodes")
	ctx.SpawnsFolder = folder(nodes, "Spawns")
	ctx.CrawlerFolder = folder(nodes, "CeilingCrawlerNodes")
	ctx.PlayerSpawnFolder = folder(root, "PlayerSpawns")
	ctx.PickupFolder = folder(root, "PickupSpots")
	ctx.S = Build.frame(ctx.StructureFolder)
	ctx.Interact = Build.frame(ctx.InteractFolder)

	-- zone bounds
	for _, zone in ipairs(MAP.Zones) do
		local boxes = { { X = zone.X, Z = zone.Z } }
		for _, extra in ipairs(zone.Extra or {}) do
			table.insert(boxes, extra)
		end
		for _, b in ipairs(boxes) do
			local part = Build.part(zones, zone.Id, V(b.X[2] - b.X[1], zone.H, b.Z[2] - b.Z[1]), CFrame.new((b.X[1] + b.X[2]) / 2, zone.H / 2, (b.Z[1] + b.Z[2]) / 2), C.Black, M.SmoothPlastic, { t = 1, collide = false, query = false, shadow = false })
			part.CanTouch = false
			Build.attrs(part, { DisplayName = MapConfig.GetZoneName(zone.Id), Height = zone.H, Reverb = MAP.Acoustics[zone.Id] or "Hangar" })
		end
	end

	local areas = World.Mall
	require(areas.Shell).Build(ctx)
	require(areas.Entrance).Build(ctx)
	require(areas.GrandHall).Build(ctx)
	require(areas.WestWing).Build(ctx)
	require(areas.EastWing).Build(ctx)
	require(areas.FoodCourt).Build(ctx)
	require(areas.BackOfHouse).Build(ctx)
	require(areas.Garage).Build(ctx)
	require(areas.Exterior).Build(ctx)

	return root
end

return DeadMall
