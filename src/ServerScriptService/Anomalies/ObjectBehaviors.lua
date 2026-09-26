--[[
	ObjectBehaviors (ModuleScript)
	Location: ServerScriptService/Anomalies/ObjectBehaviors

	Reusable behaviours that possess ordinary mall objects. Each one returns
	a controller { Update(dt), Stop() } and registers everything it changes
	on record.Cleaner, so the map object is ALWAYS restored when the anomaly
	ends (position, anchoring, attributes, lights, sounds).

	  MoveWhenNotObserved   creeps towards a target while nobody looks at it
	  RotateWhenNotObserved turns to face you while nobody looks at it
	  Levitate              rises, bobs and slowly spins
	  FollowPlayer          slides / rolls after one investigator
	  FallSuddenly          drops to the floor with a crash
	  OpenClose             a door (or locker) opens and slams by itself
	  TeleportObject        is suddenly somewhere else when you look back
	  ScreenBehavior        TVs / monitors switch to static / a face / CCTV
	  TriggerSound          one-shot or looping sound on the object
	  PhysicsBurst          everything on it flies off (clones - the real
	                        props stay safe) and crashes to the floor
	(Mirror behaviour: see Behaviors/WrongReflection + Entity "MirrorDouble".)
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Objects = {}

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------

-- The prop model a tagged part belongs to (tags often sit on one part).
function Objects.PropOf(instance: Instance): Instance
	if instance:IsA("Model") then
		return instance
	end
	local parent = instance.Parent
	if parent and parent:IsA("Model") and parent.Name ~= "ActiveMap" and parent.Name ~= "Zones" then
		return parent
	end
	return instance
end

function Objects.PivotOf(instance: Instance): CFrame
	if instance:IsA("Model") then
		return instance:GetPivot()
	end
	return (instance :: BasePart).CFrame
end

function Objects.SetPivot(instance: Instance, cframe: CFrame)
	if instance:IsA("Model") then
		instance:PivotTo(cframe)
	elseif instance:IsA("BasePart") then
		instance.CFrame = cframe
	end
end

-- Remembers every part's CFrame / anchoring / transparency and restores it.
function Objects.Borrow(record, instance: Instance)
	local saved = {}
	local list = if instance:IsA("BasePart") then { instance } else {}
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(list, descendant)
		end
	end
	for _, part in ipairs(list) do
		saved[part] = { CFrame = part.CFrame, Anchored = part.Anchored, Transparency = part.Transparency, CanCollide = part.CanCollide }
	end
	record.Cleaner:Add(function()
		for part, state in pairs(saved) do
			if part.Parent then
				part.Anchored = state.Anchored
				part.AssemblyLinearVelocity = Vector3.zero
				part.CFrame = state.CFrame
				part.Transparency = state.Transparency
				part.CanCollide = state.CanCollide
			end
		end
	end)
	return saved
end

function Objects.Observed(ctx, position: Vector3, ignore: { Instance }?): boolean
	local seen = ctx.Services.ObservationService:IsObserved(position, { MaxDistance = 140, Ignore = ignore })
	return seen
end

local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Exclude

function Objects.FloorBelow(ctx, position: Vector3, ignore: { Instance }?): Vector3
	local exclude: { Instance } = { ctx.Services.MapService.Folders.ActiveAnomalies }
	for _, instance in ipairs(ignore or {}) do
		table.insert(exclude, instance)
	end
	floorParams.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -30, 0), floorParams)
	return if hit then hit.Position else position
end

local function controller(update: ((number) -> ())?, stop: (() -> ())?)
	return { Update = update or function() end, Stop = stop or function() end }
end

local function tween(instance: Instance, info: TweenInfo, goal)
	local t = TweenService:Create(instance, info, goal)
	t:Play()
	return t
end

-- Tweens a Model pivot through a CFrameValue.
function Objects.TweenPivot(record, instance: Instance, target: CFrame, time: number, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local value = Instance.new("CFrameValue")
	value.Value = Objects.PivotOf(instance)
	value.Changed:Connect(function(current)
		if instance.Parent then
			Objects.SetPivot(instance, current)
		end
	end)
	local t = tween(value, TweenInfo.new(time, style or Enum.EasingStyle.Sine, direction or Enum.EasingDirection.InOut), { Value = target })
	t.Completed:Once(function()
		value:Destroy()
	end)
	record.Cleaner:Add(function()
		t:Cancel()
		value:Destroy()
	end)
	return t
end

---------------------------------------------------------------------------
-- behaviours
---------------------------------------------------------------------------

--[[ opts: Step (studs per move), Interval, StopDistance, Sound, Target (Player),
	OnReach(player) - called when it gets within StopDistance ]]
function Objects.MoveWhenNotObserved(ctx, record, instance: Instance, opts)
	local o = opts or {}
	local nextMove = os.clock() + (o.Delay or 1)
	return controller(function()
		if os.clock() < nextMove then
			return
		end
		nextMove = os.clock() + (o.Interval or 0.5)
		local pivot = Objects.PivotOf(instance)
		if Objects.Observed(ctx, pivot.Position + Vector3.new(0, 1.5, 0), { instance }) then
			return
		end
		local player = o.Target or ctx:GetNearestParticipant(pivot.Position, o.Range or 90)
		local root = player and ctx:GetCharacterParts(player)
		if not root then
			return
		end
		local flat = (root.Position - pivot.Position) * Vector3.new(1, 0, 1)
		if flat.Magnitude <= (o.StopDistance or 4) then
			if o.OnReach then
				o.OnReach(player)
			end
			return
		end
		local step = math.min(o.Step or 1.5, flat.Magnitude - (o.StopDistance or 4) + 0.5)
		local position = pivot.Position + flat.Unit * step
		local facing = if o.Face ~= false then CFrame.lookAt(position, position + flat.Unit) * CFrame.Angles(0, if o.FaceBack then math.pi else 0, 0) else pivot - pivot.Position + position
		Objects.SetPivot(instance, if o.Face ~= false then facing else pivot + flat.Unit * step)
		if o.Sound then
			ctx.Kit.PlaySound3D(position, o.Sound)
		end
	end)
end

function Objects.RotateWhenNotObserved(ctx, record, instance: Instance, opts)
	local o = opts or {}
	local nextTurn = os.clock() + 1
	local part = o.Part -- rotate only this part (a head) instead of the whole prop
	return controller(function()
		if os.clock() < nextTurn then
			return
		end
		nextTurn = os.clock() + (o.Interval or 0.4)
		local pivot = if part then part.CFrame else Objects.PivotOf(instance)
		if Objects.Observed(ctx, pivot.Position, { instance }) then
			return
		end
		local _, _, root = ctx:GetNearestParticipant(pivot.Position, o.Range or 70)
		if not root then
			return
		end
		local target = Vector3.new(root.Position.X, pivot.Position.Y, root.Position.Z)
		if (target - pivot.Position).Magnitude < 0.5 then
			return
		end
		local look = CFrame.lookAt(pivot.Position, target) * (o.Offset or CFrame.identity)
		if ctx.Kit.YawDifference(pivot, look) > 6 then
			if part then
				part.CFrame = look
			else
				Objects.SetPivot(instance, look)
			end
			if o.Sound then
				ctx.Kit.PlaySound3D(pivot.Position, o.Sound)
			end
		end
	end)
end

function Objects.Levitate(ctx, record, instance: Instance, opts)
	local o = opts or {}
	local base = Objects.PivotOf(instance)
	local height = o.Height or 4
	local rise = o.RiseTime or 2.2
	local started = os.clock()
	Objects.TweenPivot(record, instance, base + Vector3.new(0, height, 0), rise, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	if o.Sound then
		ctx.Kit.PlaySound3D(base.Position, o.Sound)
	end
	local spin = 0
	return controller(function(dt)
		local t = os.clock() - started
		if t < rise then
			return
		end
		spin += dt * (o.Spin or 0.35)
		local bob = math.sin(t * 1.6) * (o.Bob or 0.5)
		Objects.SetPivot(instance, base * CFrame.new(0, height + bob, 0) * CFrame.Angles(math.sin(t * 0.7) * 0.08, spin, math.cos(t * 0.9) * 0.08))
	end, function()
		Objects.TweenPivot(record, instance, base, 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end)
end

function Objects.FollowPlayer(ctx, record, instance: Instance, opts)
	local o = opts or {}
	local target = o.Target
	local roll = 0
	local lastSound = 0
	return controller(function(dt)
		local player = target or ctx:GetNearestParticipant(Objects.PivotOf(instance).Position, 80)
		local root = player and ctx:GetCharacterParts(player)
		if not root then
			return
		end
		local pivot = Objects.PivotOf(instance)
		if o.OnlyUnobserved and Objects.Observed(ctx, pivot.Position, { instance }) then
			return
		end
		local flat = (root.Position - pivot.Position) * Vector3.new(1, 0, 1)
		local distance = flat.Magnitude
		if distance <= (o.Distance or 5) then
			return
		end
		local step = math.min((o.Speed or 6) * dt, distance - (o.Distance or 5))
		local position = pivot.Position + flat.Unit * step
		roll += step / math.max(o.Radius or 0.8, 0.1)
		if o.Roll then
			Objects.SetPivot(instance, CFrame.new(position) * CFrame.fromAxisAngle(Vector3.new(-flat.Unit.Z, 0, flat.Unit.X), roll))
		else
			Objects.SetPivot(instance, CFrame.lookAt(position, position + flat.Unit))
		end
		if o.Sound and os.clock() - lastSound > (o.SoundInterval or 1.2) then
			lastSound = os.clock()
			ctx.Kit.PlaySound3D(position, o.Sound)
		end
	end)
end

function Objects.FallSuddenly(ctx, record, instance: Instance, opts)
	local o = opts or {}
	local pivot = Objects.PivotOf(instance)
	local floor = Objects.FloorBelow(ctx, pivot.Position, { instance })
	local size: Vector3
	if instance:IsA("Model") then
		local _, extents = instance:GetBoundingBox()
		size = extents
	else
		size = (instance :: BasePart).Size
	end
	local landing = CFrame.new(floor + Vector3.new(0, size.Y / 2, 0)) * (pivot - pivot.Position) * CFrame.Angles(math.rad(math.random(-40, 40)), 0, math.rad(math.random(-60, 60)))
	task.delay(o.Delay or 0, function()
		if record.CleanedUp then
			return
		end
		Objects.TweenPivot(record, instance, landing, o.Time or 0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(o.Time or 0.45, function()
			ctx.Kit.PlaySound3D(floor, o.Sound or "Anomaly.Thud")
			ctx.Services.NoiseService:Emit(floor, 0.3, "Interaction", nil)
		end)
	end)
	return controller()
end

-- Possessed door / locker: uses InteractionService so prompts stay in sync.
function Objects.OpenClose(ctx, record, door: Instance, opts)
	local o = opts or {}
	local interaction = ctx.Services.InteractionService
	local nextToggle = os.clock() + (o.Delay or 1.5)
	local open = false
	return controller(function()
		if os.clock() < nextToggle then
			return
		end
		nextToggle = os.clock() + (o.Interval or (2 + math.random() * 3))
		open = not open
		interaction:ForceDoor(door, open, not open and math.random() < (o.SlamChance or 0.6))
	end, function()
		interaction:ForceDoor(door, false, false)
	end)
end

function Objects.TeleportObject(ctx, record, instance: Instance, opts)
	local o = opts or {}
	local nextJump = os.clock() + (o.Delay or 3)
	local jumps = 0
	return controller(function()
		if os.clock() < nextJump or jumps >= (o.MaxJumps or 6) then
			return
		end
		local pivot = Objects.PivotOf(instance)
		if Objects.Observed(ctx, pivot.Position, { instance }) then
			return
		end
		nextJump = os.clock() + (o.Interval or 2)
		local player = ctx:GetNearestParticipant(pivot.Position, 90)
		local root = player and ctx:GetCharacterParts(player)
		if not root then
			return
		end
		-- behind the investigator, a little closer every time
		local distance = math.max(4, (o.StartDistance or 18) - jumps * 3)
		local spot = root.Position - root.CFrame.LookVector * distance + root.CFrame.RightVector * (math.random() * 6 - 3)
		local floor = Objects.FloorBelow(ctx, spot, { instance })
		local offsetY = pivot.Position.Y - Objects.FloorBelow(ctx, pivot.Position, { instance }).Y
		Objects.SetPivot(instance, CFrame.lookAt(floor + Vector3.new(0, offsetY, 0), Vector3.new(root.Position.X, floor.Y + offsetY, root.Position.Z)))
		jumps += 1
		if o.Sound then
			ctx.Kit.PlaySound3D(floor, o.Sound)
		end
	end)
end

-- TVs / monitors in range switch to a mode (Static / Face / CCTV / Off). WorldController renders them.
function Objects.ScreenBehavior(ctx, record, center: Vector3, opts)
	local o = opts or {}
	local screens = {}
	for _, tag in ipairs({ "MallTV", "CCTVMonitor" }) do
		for _, screen in ipairs(CollectionService:GetTagged(tag)) do
			if screen:IsA("BasePart") and (screen.Position - center).Magnitude <= (o.Radius or 30) then
				table.insert(screens, { Part = screen, Mode = screen:GetAttribute("Mode") })
			end
		end
	end
	for _, entry in ipairs(screens) do
		entry.Part:SetAttribute("Mode", o.Mode or "Static")
	end
	record.Cleaner:Add(function()
		for _, entry in ipairs(screens) do
			if entry.Part.Parent then
				entry.Part:SetAttribute("Mode", entry.Mode)
			end
		end
	end)
	local flicker = o.Flicker
	local nextFlick = 0
	return controller(function()
		if not flicker or os.clock() < nextFlick then
			return
		end
		nextFlick = os.clock() + 0.5 + math.random() * 1.5
		for _, entry in ipairs(screens) do
			entry.Part:SetAttribute("Mode", if math.random() < 0.3 then "Static" else (o.Mode or "Face"))
		end
	end), screens
end

function Objects.TriggerSound(ctx, record, where: Instance, path: string, loop: boolean?)
	if loop then
		ctx.Services.AudioService:SetLoop(path, where, true)
		record.Cleaner:Add(function()
			ctx.Services.AudioService:SetLoop(path, where, false)
		end)
	else
		ctx.Kit.PlaySound3D(where, path)
	end
	return controller()
end

-- Clones the small parts of a prop, hides the originals and throws the clones around.
function Objects.PhysicsBurst(ctx, record, instance: Instance, opts)
	local o = opts or {}
	local maxSize = o.MaxSize or 2.2
	local clones = {}
	local hidden = {}
	local origin = Objects.PivotOf(instance).Position
	for _, part in ipairs(instance:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 0.9 and part.Size.Magnitude <= maxSize * 1.8 and #clones < (o.MaxParts or 26) then
			local clone = part:Clone()
			for _, child in ipairs(clone:GetChildren()) do
				if not child:IsA("SpecialMesh") and not child:IsA("SurfaceGui") and not child:IsA("Decal") then
					child:Destroy()
				end
			end
			clone.Anchored = false
			clone.CanCollide = true
			clone.CanQuery = false
			clone.CanTouch = false
			clone.CollisionGroup = ctx.Kit.CollisionGroup
			clone.Massless = false
			clone.Parent = ctx.Services.MapService.Folders.ActiveAnomalies
			pcall(function()
				clone:SetNetworkOwner(nil)
			end)
			local away = (part.Position - origin) * Vector3.new(1, 0, 1)
			local direction = if away.Magnitude > 0.1 then away.Unit else Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
			clone.AssemblyLinearVelocity = direction * (o.Force or 28) * (0.6 + math.random() * 0.8) + Vector3.new(0, (o.Lift or 22) * (0.5 + math.random()), 0)
			clone.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 18
			table.insert(clones, clone)
			hidden[part] = part.Transparency
			part.Transparency = 1
		end
	end
	ctx.Kit.PlaySound3D(origin, o.Sound or "Anomaly.ShelfCrash")
	ctx.Services.NoiseService:Emit(origin, 0.5, "Interaction", nil)
	record.Cleaner:Add(function()
		for part, transparency in pairs(hidden) do
			if part.Parent then
				part.Transparency = transparency
			end
		end
		for _, clone in ipairs(clones) do
			Debris:AddItem(clone, 0)
		end
	end)
	return controller()
end

return Objects
