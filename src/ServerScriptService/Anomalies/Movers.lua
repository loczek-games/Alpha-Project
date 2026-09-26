--[[
	Movers (ModuleScript)
	Location: ServerScriptService/Anomalies/Movers

	How anomaly bodies move (server authoritative, smooth on clients):

	  Movers.Floor(model, opts)    Humanoid rigs. PathfindingService paths,
	      Humanoid:MoveTo along the waypoints, per-gait movement:
	        Walk / Sprint       normal
	        Jerky               stop-and-go with random pauses and bursts
	        Limp                slow, uneven
	        StopMotion          moves in short bursts, frozen in between
	        Crawl               low + slow (the client lays the body down)
	      Face(position), Teleport(cframe), Stop(), Arrived().
	  Movers.Ceiling(model, ctx)   the ceiling crawler. Walks a graph built at
	      runtime from Workspace.ActiveMap.AnomalyNodes.CeilingCrawlerNodes
	      (neighbours = nodes with a clear line between them), A* routes,
	      body held upside-down against the ceiling with AlignPosition +
	      AlignOrientation (physics-replicated = smooth for everyone).

	The client (AnomalyAnimator) animates legs/arms from the model's real
	velocity and its "Gait" attribute.
]]

local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")

local Movers = {}

---------------------------------------------------------------------------
-- FLOOR
---------------------------------------------------------------------------

local Floor = {}
Floor.__index = Floor

export type FloorOptions = {
	AgentRadius: number?,
	AgentHeight: number?,
}

function Movers.Floor(model: Model, opts: FloorOptions?)
	local o = opts or {}
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	assert(humanoid and root, "Floor mover needs a Humanoid + HumanoidRootPart")
	local self = setmetatable({}, Floor)
	self.Model = model
	self.Humanoid = humanoid
	self.Root = root
	self.Path = PathfindingService:CreatePath({
		AgentRadius = o.AgentRadius or 2,
		AgentHeight = o.AgentHeight or 6,
		AgentCanJump = false,
		AgentCanClimb = false,
		WaypointSpacing = 5,
	})
	self.Waypoints = nil :: { Vector3 }?
	self.Index = 1
	self.Goal = nil :: Vector3?
	self.LastCompute = 0
	self.Computing = false
	self.Speed = 8
	self.Gait = "Walk"
	self.BurstUntil = 0
	self.PauseUntil = 0
	humanoid.WalkSpeed = self.Speed
	humanoid.AutoRotate = true
	return self
end

function Floor:SetGait(gait: string, speed: number?)
	self.Gait = gait
	if speed then
		self.Speed = speed
	end
	self.Model:SetAttribute("Gait", gait)
	self.Model:SetAttribute("Speed", self.Speed)
end

function Floor:_compute(goal: Vector3)
	if self.Computing then
		return
	end
	self.Computing = true
	self.LastCompute = os.clock()
	task.spawn(function()
		local start = self.Root.Position
		local ok = pcall(function()
			self.Path:ComputeAsync(start, goal)
		end)
		if ok and self.Path.Status == Enum.PathStatus.Success then
			local list = {}
			for _, waypoint in ipairs(self.Path:GetWaypoints()) do
				table.insert(list, waypoint.Position)
			end
			self.Waypoints = list
			self.Index = math.min(2, #list)
		else
			-- no path (e.g. goal on a prop): walk straight at it
			self.Waypoints = { goal }
			self.Index = 1
		end
		self.Computing = false
	end)
end

-- repath: how old a path may get before recomputing while the goal moves
function Floor:MoveTo(goal: Vector3, repath: number?)
	local changed = self.Goal == nil or (self.Goal - goal).Magnitude > 3
	self.Goal = goal
	if changed or os.clock() - self.LastCompute > (repath or 1.2) then
		self:_compute(goal)
	end
end

function Floor:Stop()
	self.Goal = nil
	self.Waypoints = nil
	self.Humanoid:Move(Vector3.zero)
	self.Humanoid.WalkSpeed = 0
end

function Floor:Arrived(radius: number?): boolean
	if not self.Goal then
		return true
	end
	local flat = (self.Goal - self.Root.Position) * Vector3.new(1, 0, 1)
	return flat.Magnitude <= (radius or 3)
end

function Floor:Face(position: Vector3)
	local root = self.Root
	local flat = Vector3.new(position.X, root.Position.Y, position.Z)
	if (flat - root.Position).Magnitude < 0.2 then
		return
	end
	self.Humanoid.AutoRotate = false
	local target = CFrame.lookAt(root.Position, flat)
	root.CFrame = root.CFrame:Lerp(target, 0.35)
end

function Floor:Teleport(cframe: CFrame)
	self:Stop()
	self.Model:PivotTo(cframe)
	self.Root.AssemblyLinearVelocity = Vector3.zero
end

function Floor:Update(_dt: number)
	local humanoid = self.Humanoid
	local waypoints = self.Waypoints
	if not self.Goal or not waypoints then
		humanoid.WalkSpeed = 0
		return
	end
	humanoid.AutoRotate = true
	local now = os.clock()
	-- gait timing
	local speed = self.Speed
	if self.Gait == "StopMotion" then
		if now >= self.BurstUntil and now >= self.PauseUntil then
			self.BurstUntil = now + 0.18 + math.random() * 0.12
			self.PauseUntil = self.BurstUntil + 0.35 + math.random() * 0.4
		end
		speed = if now < self.BurstUntil then speed * 2.2 else 0
	elseif self.Gait == "Jerky" then
		if now >= self.PauseUntil and math.random() < 0.06 then
			self.PauseUntil = now + 0.2 + math.random() * 0.7
		end
		speed = if now < self.PauseUntil then 0 else speed * (0.7 + math.random() * 0.9)
	elseif self.Gait == "Limp" then
		speed *= 0.65 + 0.35 * math.abs(math.sin(now * 3.2))
	end
	humanoid.WalkSpeed = speed
	local waypoint = waypoints[self.Index]
	if not waypoint then
		self.Waypoints = nil
		return
	end
	local flat = (waypoint - self.Root.Position) * Vector3.new(1, 0, 1)
	if flat.Magnitude < 2.2 then
		self.Index += 1
		waypoint = waypoints[self.Index]
		if not waypoint then
			self.Waypoints = nil
			return
		end
	end
	humanoid:MoveTo(waypoint)
end

---------------------------------------------------------------------------
-- CEILING
---------------------------------------------------------------------------

local Graph = nil :: any

local function buildGraph(ctx)
	local nodes = {}
	for _, node in ipairs(ctx.Services.MapService:GetCeilingNodes()) do
		table.insert(nodes, { Part = node, Position = node.Position, Zone = node:GetAttribute("Zone"), Links = {} })
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	local folders = ctx.Services.MapService.Folders
	for _, key in ipairs({ "ActiveAnomalies", "CeilingNodes", "Decoys", "RoundItems" }) do
		if folders[key] then
			table.insert(exclude, folders[key])
		end
	end
	params.FilterDescendantsInstances = exclude
	-- decorative ceiling fixtures (lights, vents, signs) are non-collidable:
	-- the crawler climbs over them, only walls and solid beams split the graph
	params.RespectCanCollide = true
	local LINK = 30
	for i = 1, #nodes do
		local a = nodes[i]
		for j = i + 1, #nodes do
			local b = nodes[j]
			local offset = b.Position - a.Position
			local distance = offset.Magnitude
			-- same ceiling plane only: no leaping across an atrium between floors
			if distance <= LINK and distance > 0.1 and math.abs(offset.Y) <= 4 then
				-- slightly below the ceiling so the ceiling itself does not block
				local from = a.Position - Vector3.new(0, 0.6, 0)
				local to = b.Position - Vector3.new(0, 0.6, 0)
				local hit = Workspace:Raycast(from, to - from, params)
				if not hit then
					table.insert(a.Links, { Node = b, Cost = distance })
					table.insert(b.Links, { Node = a, Cost = distance })
				end
			end
		end
	end
	-- islands: rooms whose ceilings are separated by walls. Routes only exist
	-- inside an island; the crawler crosses between them while unseen.
	local islands = 0
	for _, start in ipairs(nodes) do
		if start.Island == nil then
			islands += 1
			start.Island = islands
			local stack = { start }
			while #stack > 0 do
				local node = table.remove(stack)
				for _, link in ipairs(node.Links) do
					if link.Node.Island == nil then
						link.Node.Island = islands
						table.insert(stack, link.Node)
					end
				end
			end
		end
	end
	return { Nodes = nodes, Islands = islands }
end

function Movers.GetCeilingGraph(ctx)
	if not Graph then
		Graph = buildGraph(ctx)
		local links = 0
		for _, node in ipairs(Graph.Nodes) do
			links += #node.Links
		end
		print(string.format("[Anomalies] Ceiling crawler graph: %d nodes, %d links, %d islands", #Graph.Nodes, links // 2, Graph.Islands))
	end
	return Graph
end

local function nearestNode(graph, position: Vector3, maxDistance: number?, zone: string?)
	local best, bestDistance = nil, maxDistance or math.huge
	for _, node in ipairs(graph.Nodes) do
		if (zone == nil or node.Zone == zone) and #node.Links > 0 then
			local flat = (node.Position - position) * Vector3.new(1, 0.35, 1)
			local distance = flat.Magnitude
			if distance < bestDistance then
				best, bestDistance = node, distance
			end
		end
	end
	return best, bestDistance
end
Movers.NearestCeilingNode = nearestNode

-- A* over the ceiling graph
local function route(from, to)
	if from == to then
		return { to }
	end
	local open = { from }
	local came = {}
	local g = { [from] = 0 }
	local f = { [from] = (to.Position - from.Position).Magnitude }
	local closed = {}
	local guard = 0
	while #open > 0 and guard < 4000 do
		guard += 1
		local bestIndex, best = 1, open[1]
		for index, node in ipairs(open) do
			if f[node] < f[best] then
				bestIndex, best = index, node
			end
		end
		if best == to then
			local path = { to }
			local current = to
			while came[current] do
				current = came[current]
				table.insert(path, 1, current)
			end
			return path
		end
		table.remove(open, bestIndex)
		closed[best] = true
		for _, link in ipairs(best.Links) do
			local neighbour = link.Node
			if not closed[neighbour] then
				local score = g[best] + link.Cost
				if g[neighbour] == nil or score < g[neighbour] then
					came[neighbour] = best
					g[neighbour] = score
					f[neighbour] = score + (to.Position - neighbour.Position).Magnitude
					if not table.find(open, neighbour) then
						table.insert(open, neighbour)
					end
				end
			end
		end
	end
	return nil
end

local Ceiling = {}
Ceiling.__index = Ceiling

function Movers.Ceiling(model: Model, ctx, startNode)
	local root = model.PrimaryPart :: BasePart
	local self = setmetatable({}, Ceiling)
	self.Model = model
	self.Root = root
	self.Graph = Movers.GetCeilingGraph(ctx)
	self.Node = startNode
	self.Route = nil :: { any }?
	self.Speed = 9
	self.Hang = 1.05 -- body centre below the ceiling node
	self.Facing = Vector3.new(0, 0, -1)
	self.Position = startNode.Position - Vector3.new(0, self.Hang, 0)
	self.Detached = false

	-- physics drive (smooth replication)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.Massless = descendant ~= root
			descendant.CanCollide = false
		end
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "Drive"
	attachment.Parent = root
	local align = Instance.new("AlignPosition")
	align.Mode = Enum.PositionAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxForce = 1e7
	align.Responsiveness = 30
	align.Position = self.Position
	align.Parent = root
	local orient = Instance.new("AlignOrientation")
	orient.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orient.Attachment0 = attachment
	orient.MaxTorque = 1e7
	orient.Responsiveness = 25
	orient.Parent = root
	self.Align = align
	self.Orient = orient
	model:PivotTo(self:_bodyCFrame(self.Position, self.Facing))
	self:_applyOrientation()
	return self
end

-- upside down: back against the ceiling, head towards `facing`
function Ceiling:_bodyCFrame(position: Vector3, facing: Vector3): CFrame
	local flat = Vector3.new(facing.X, 0, facing.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(position, position + flat.Unit) * CFrame.Angles(0, 0, math.pi)
end

function Ceiling:_applyOrientation()
	local cf = self:_bodyCFrame(self.Position, self.Facing)
	self.Orient.CFrame = cf - cf.Position
end

function Ceiling:SetSpeed(speed: number)
	self.Speed = speed
	self.Model:SetAttribute("Speed", speed)
end

-- Route to the ceiling node nearest to `position` (a player below, a vent...).
-- Returns false when the ceiling above `position` is not reachable from the
-- crawler's current island (see Ceiling:Relocate).
function Ceiling:MoveTo(position: Vector3): boolean
	local target = nearestNode(self.Graph, position)
	if not target or not self.Node then
		return false
	end
	if target.Island ~= self.Node.Island then
		return false
	end
	if self.Route and self.Route[#self.Route] == target then
		return true
	end
	local path = route(self.Node, target)
	if not path then
		return false
	end
	self.Route = path
	return true
end

function Ceiling:Stop()
	self.Route = nil
end

function Ceiling:Arrived(): boolean
	return self.Route == nil or #self.Route == 0
end

function Ceiling:Face(position: Vector3)
	local offset = (position - self.Position) * Vector3.new(1, 0, 1)
	if offset.Magnitude > 0.2 then
		self.Facing = offset.Unit
		self:_applyOrientation()
	end
end

-- Drop off the ceiling towards a point (attack). The mover stops steering.
function Ceiling:Drop(toward: Vector3)
	self.Detached = true
	self.Route = nil
	self.Align.Responsiveness = 60
	self.Align.Position = toward
	local down = CFrame.lookAt(self.Position, toward)
	self.Orient.CFrame = down - down.Position
end

function Ceiling:Teleport(node)
	self.Node = node
	self.Route = nil
	self.Detached = false
	self.Position = node.Position - Vector3.new(0, self.Hang, 0)
	self.Align.Responsiveness = 30
	self.Align.Position = self.Position
	self.Model:PivotTo(self:_bodyCFrame(self.Position, self.Facing))
	self:_applyOrientation()
end

function Ceiling:Update(dt: number)
	if self.Detached then
		return
	end
	local path = self.Route
	if path and #path > 0 then
		local nextNode = path[1]
		local goal = nextNode.Position - Vector3.new(0, self.Hang, 0)
		local offset = goal - self.Position
		local distance = offset.Magnitude
		local step = self.Speed * dt
		if distance <= step then
			self.Position = goal
			self.Node = nextNode
			table.remove(path, 1)
			if #path == 0 then
				self.Route = nil
			end
		else
			self.Position += offset.Unit * step
			local flat = offset * Vector3.new(1, 0, 1)
			if flat.Magnitude > 0.1 then
				self.Facing = self.Facing:Lerp(flat.Unit, math.min(1, dt * 6))
			end
		end
		self:_applyOrientation()
	end
	self.Align.Position = self.Position
end

-- Jumps to a node near `position` that `isHidden(nodePosition)` approves
-- (used to cross between islands while nobody is looking).
function Ceiling:Relocate(position: Vector3, minDistance: number, maxDistance: number, isHidden: (Vector3) -> boolean): boolean
	local target = nearestNode(self.Graph, position)
	local candidates = {}
	for _, node in ipairs(self.Graph.Nodes) do
		if #node.Links > 0 and (target == nil or node.Island == target.Island) then
			local distance = ((node.Position - position) * Vector3.new(1, 0, 1)).Magnitude
			if distance >= minDistance and distance <= maxDistance then
				table.insert(candidates, node)
			end
		end
	end
	for _ = 1, math.min(#candidates, 8) do
		local node = table.remove(candidates, math.random(1, #candidates))
		if isHidden(node.Position - Vector3.new(0, self.Hang, 0)) then
			self:Teleport(node)
			return true
		end
	end
	return false
end

-- Random neighbour hop (idle wandering)
function Ceiling:Wander()
	local node = self.Node
	if node and #node.Links > 0 then
		local link = node.Links[math.random(1, #node.Links)]
		self.Route = { link.Node }
	end
end

return Movers
