--[[
	ObjectAnomaly (ModuleScript)
	Location: ServerScriptService/Anomalies/Behaviors/ObjectAnomaly

	Possessed mall objects, built from the reusable ObjectBehaviors. The
	anomaly definition picks a MODE (Params.Mode); the object comes from a
	tagged map fixture (Spawn.Fixture) or a spawn marker (Spawn.Kinds).

	  Levitate       floating shopping cart / food tray
	  Creep          moves closer while unobserved (cart, bag, chair, mannequins)
	  Roll           a ball rolls after you
	  Turn           rotates to watch you while unobserved (statue)
	  Door           a door opens and slams by itself
	  Screens        every TV around shows a face (TV Entity)
	  Arcade         a dead arcade cabinet boots up, rocks, shows a face
	  Burst          a shelf's contents fly off
	  CarAlarm       an alarm goes off, headlights flash
	  OccupiedCar    someone sits in a parked car, head turning to you
	  Phone          a payphone rings for you
	  StoreAlarm     anti-theft gates scream at an empty store entrance
	  Elevator       the dead elevator dings, doors open on someone
	  Shutter        a closed store's shutter slowly rises, lights inside
	  CeilingFace    a pale face presses against a ceiling vent
	  Hallway        an employee hallway that goes on forever
	  WrongStore     a store sign that was never there
	  Locker         knocking from inside a locker... it bursts open
	  SecurityCams   every camera in the area turns to follow you
	  Escalator      the escalator starts; a figure rides it
	  Chair          a food court chair drags itself into your way
]]

local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = ServerScriptService:WaitForChild("World")
local Build = require(World:WaitForChild("Build"))
local Rng = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Rng"))

local ObjectAnomaly = {}

local MODES = {}

local function nearby(tag: string, position: Vector3, radius: number)
	local list = {}
	for _, instance in ipairs(CollectionService:GetTagged(tag)) do
		local pivot = if instance:IsA("Model") then instance:GetPivot().Position elseif instance:IsA("BasePart") then instance.Position else nil
		if pivot and (pivot - position).Magnitude <= radius then
			table.insert(list, instance)
		end
	end
	return list
end

local function firstPart(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Model") and instance.PrimaryPart then
		return instance.PrimaryPart
	end
	return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function tween(instance: Instance, time: number, goal, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local t = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Sine, direction or Enum.EasingDirection.InOut), goal)
	t:Play()
	return t
end

-- a body (Kit.Body) placed at a CFrame, faded in; destroyed with the record
local function body(ctx, record, appearance: string, at: CFrame)
	local b = ctx.Kit.Body(appearance)
	b.Model:PivotTo(at)
	b.Model.Parent = ctx.Services.MapService.Folders.ActiveAnomalies
	ctx.Kit.FadeIn(b.Model, 0.6)
	record.Cleaner:Add(b.Model)
	return b
end

---------------------------------------------------------------------------
-- modes built directly on ObjectBehaviors
---------------------------------------------------------------------------

function MODES.Levitate(ctx, record, fixture, params)
	local prop = ctx.Objects.PropOf(fixture)
	ctx.Objects.Borrow(record, prop)
	record.Target = firstPart(fixture) :: BasePart
	record.VisibilityRoot = prop
	return { ctx.Objects.Levitate(ctx, record, prop, { Height = params.Height or 4.5, Bob = params.Bob or 0.5, Spin = params.Spin or 0.35, Sound = "Anomaly.MetalGroan" }) }
end

function MODES.Creep(ctx, record, fixture, params)
	local props = { ctx.Objects.PropOf(fixture) }
	if params.Group then
		-- every tagged object around the fixture joins in (mannequin group)
		for _, other in ipairs(nearby(params.GroupTag or "MallMannequin", ctx.Objects.PivotOf(props[1]).Position, params.Group)) do
			local prop = ctx.Objects.PropOf(other)
			if not table.find(props, prop) and ctx:IsFree(prop) then
				ctx:Reserve(record, prop)
				table.insert(props, prop)
			end
		end
	end
	local controllers = {}
	for _, prop in ipairs(props) do
		ctx.Objects.Borrow(record, prop)
		table.insert(controllers, ctx.Objects.MoveWhenNotObserved(ctx, record, prop, {
			Step = params.Step or 1.4,
			Interval = params.Interval or 0.6,
			StopDistance = params.StopDistance or 5,
			Sound = params.Sound,
			FaceBack = params.FaceBack,
			Face = params.Face,
		}))
	end
	record.Target = firstPart(fixture) :: BasePart
	record.VisibilityRoot = props[1]
	return controllers
end

function MODES.Roll(ctx, record, fixture, params)
	local prop = ctx.Objects.PropOf(fixture)
	ctx.Objects.Borrow(record, prop)
	record.Target = firstPart(fixture) :: BasePart
	record.VisibilityRoot = prop
	return { ctx.Objects.FollowPlayer(ctx, record, prop, { Distance = 3, Speed = params.Speed or 7, Roll = true, Radius = 0.8, Sound = "Anomaly.BallBounce", SoundInterval = 0.7, OnlyUnobserved = false }) }
end

function MODES.Turn(ctx, record, fixture, params)
	local prop = ctx.Objects.PropOf(fixture)
	ctx.Objects.Borrow(record, prop)
	record.Target = firstPart(fixture) :: BasePart
	record.VisibilityRoot = prop
	local head = if params.HeadOnly then prop:FindFirstChild("Head", true) else nil
	return { ctx.Objects.RotateWhenNotObserved(ctx, record, prop, { Part = if head and head:IsA("BasePart") then head else nil, Interval = 0.35, Sound = "Anomaly.Snap" }) }
end

function MODES.Door(ctx, record, fixture, _params)
	local panel = fixture:FindFirstChild("Panel")
	record.Target = (if panel and panel:IsA("BasePart") then panel else firstPart(fixture)) :: BasePart
	record.VisibilityRoot = fixture
	return { ctx.Objects.OpenClose(ctx, record, fixture, { Interval = 2.5, SlamChance = 0.7 }) }
end

function MODES.Screens(ctx, record, fixture, params)
	local screen = firstPart(fixture) :: BasePart
	local controller = ctx.Objects.ScreenBehavior(ctx, record, screen.Position, { Radius = params.Radius or 26, Mode = "Face", Flicker = true })
	ctx.Objects.TriggerSound(ctx, record, screen, "Anomaly.TVStatic", true)
	ctx.Kit.PlaySound3D(screen, "Anomaly.TVOn")
	record.Target = screen
	return { controller }
end

function MODES.Arcade(ctx, record, fixture, _params)
	local cabinet = ctx.Objects.PropOf(fixture)
	ctx.Objects.Borrow(record, cabinet)
	local screen = cabinet:FindFirstChild("Screen")
	local target = (if screen and screen:IsA("BasePart") then screen else firstPart(cabinet)) :: BasePart
	local controller = ctx.Objects.ScreenBehavior(ctx, record, target.Position, { Radius = 2, Mode = "Face", Flicker = true })
	ctx.Kit.PlaySound3D(target, "Anomaly.ArcadeJingle")
	local base = ctx.Objects.PivotOf(cabinet)
	local nextJingle = os.clock() + 4
	record.Target = target
	record.VisibilityRoot = cabinet
	return {
		controller,
		{
			Update = function()
				local t = os.clock()
				ctx.Objects.SetPivot(cabinet, base * CFrame.Angles(0, 0, math.sin(t * 9) * math.rad(2.5)))
				if t >= nextJingle then
					nextJingle = t + 4 + math.random() * 3
					ctx.Kit.PlaySound3D(target, "Anomaly.ArcadeJingle")
				end
			end,
			Stop = function() end,
		},
	}
end

function MODES.Burst(ctx, record, fixture, _params)
	local shelf = ctx.Objects.PropOf(fixture)
	local target = firstPart(fixture) :: BasePart
	record.Target = target
	record.VisibilityRoot = shelf
	local base = ctx.Objects.PivotOf(shelf)
	ctx.Objects.Borrow(record, shelf)
	local started = os.clock()
	local burst = false
	return {
		{
			Update = function()
				local t = os.clock() - started
				if not burst and t < 2.5 then
					-- rattling before it goes
					ctx.Objects.SetPivot(shelf, base * CFrame.new((math.random() - 0.5) * 0.12, 0, (math.random() - 0.5) * 0.12))
				elseif not burst then
					burst = true
					ctx.Objects.SetPivot(shelf, base)
					ctx.Objects.PhysicsBurst(ctx, record, shelf, { Force = 30, Lift = 18 })
				end
			end,
			Stop = function() end,
		},
	}
end

---------------------------------------------------------------------------
-- vehicles, phones, alarms
---------------------------------------------------------------------------

function MODES.CarAlarm(ctx, record, fixture, _params)
	local car = ctx.Objects.PropOf(fixture)
	local target = firstPart(car) :: BasePart
	local lights = {}
	for _, descendant in ipairs(car:GetDescendants()) do
		if descendant:IsA("BasePart") and (descendant:HasTag("CarHeadlight") or descendant:HasTag("CarTaillight")) then
			table.insert(lights, { Part = descendant, Material = descendant.Material, Color = descendant.Color })
		end
	end
	record.Cleaner:Add(function()
		for _, entry in ipairs(lights) do
			entry.Part.Material = entry.Material
			entry.Part.Color = entry.Color
		end
	end)
	ctx.Objects.TriggerSound(ctx, record, target, "Anomaly.CarAlarm", true)
	ctx.Services.NoiseService:SetMask("CarAlarm", 0.5, record.Lifetime, target.Position, 70)
	record.Target = lights[1] and lights[1].Part or target
	record.VisibilityRoot = car
	local on = false
	local nextBlink = 0
	return {
		{
			Update = function()
				if os.clock() < nextBlink then
					return
				end
				nextBlink = os.clock() + 0.45
				on = not on
				for _, entry in ipairs(lights) do
					entry.Part.Material = if on then Enum.Material.Neon else entry.Material
					entry.Part.Color = if on then (if entry.Part:HasTag("CarHeadlight") then Color3.fromRGB(255, 244, 210) else Color3.fromRGB(255, 40, 30)) else entry.Color
				end
				ctx.Services.NoiseService:Emit(target.Position, 0.35, "Interaction", nil)
			end,
			Stop = function() end,
		},
	}
end

function MODES.OccupiedCar(ctx, record, fixture, _params)
	local car = ctx.Objects.PropOf(fixture)
	local pivot = ctx.Objects.PivotOf(car)
	-- driver seat: front-left of the car (cars face -Z in their own frame)
	local seat = pivot * CFrame.new(-1.1, 0.2, -0.6)
	local b = body(ctx, record, "Shadow", seat)
	b.Model:ScaleTo(0.85)
	record.Target = b.Head
	record.VisibilityRoot = b.Model
	local controller = ctx.Objects.RotateWhenNotObserved(ctx, record, b.Model, { Part = b.Head, Interval = 0.3, Sound = "Anomaly.Snap" })
	return {
		controller,
		{
			Update = function()
				-- gone when you walk right up to the window
				local _, distance = ctx:GetNearestParticipant(b.Head.Position)
				if distance < 9 and not record.Despawning then
					ctx.Kit.PlaySound3D(b.Head, "Anomaly.Vanish")
					ctx:Despawn(record, "Vanished")
				end
			end,
			Stop = function() end,
		},
	}
end

function MODES.Phone(ctx, record, fixture, _params)
	local phone = ctx.Objects.PropOf(fixture)
	local target = (if phone:IsA("Model") and phone.PrimaryPart then phone.PrimaryPart else firstPart(phone)) :: BasePart
	record.Target = target
	record.VisibilityRoot = phone
	phone:SetAttribute("Ringing", true)
	record.Cleaner:Add(function()
		phone:SetAttribute("Ringing", false)
	end)
	local nextRing = 0
	return {
		{
			Update = function()
				if not phone:GetAttribute("Ringing") then
					-- someone answered
					if not record.Despawning then
						ctx:Despawn(record, "Answered")
					end
					return
				end
				if os.clock() >= nextRing then
					nextRing = os.clock() + 2.4
					ctx.Kit.PlaySound3D(target, "Interaction.PhoneRing")
					ctx.Services.NoiseService:Emit(target.Position, 0.3, "Phone", nil)
				end
			end,
			Stop = function() end,
		},
	}
end

function MODES.StoreAlarm(ctx, record, marker, _params)
	local f = Build.frame(ctx.Services.MapService.Folders.ActiveAnomalies, marker.CFrame)
	local gates = f:model("TheftGates")
	local model = gates.Parent :: Model
	local lamps = {}
	for _, x in ipairs({ -3, 3 }) do
		gates:box("Gate", Vector3.new(0.3, 5.2, 2), Vector3.new(x, 2.6, 0), Color3.fromRGB(220, 220, 224), Enum.Material.SmoothPlastic)
		local lamp = gates:box("Lamp", Vector3.new(0.4, 0.4, 2), Vector3.new(x, 5.4, 0), Color3.fromRGB(120, 20, 20), Enum.Material.SmoothPlastic, { deco = true })
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 30, 30)
		light.Range = 16
		light.Brightness = 2
		light.Parent = lamp
		table.insert(lamps, lamp)
	end
	record.Cleaner:Add(model)
	ctx.Objects.TriggerSound(ctx, record, lamps[1], "Anomaly.StoreAlarm", true)
	record.Target = lamps[1]
	record.VisibilityRoot = model
	local on = false
	local nextFlash = 0
	return {
		{
			Update = function()
				if os.clock() < nextFlash then
					return
				end
				nextFlash = os.clock() + 0.3
				on = not on
				for _, lamp in ipairs(lamps) do
					lamp.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
					lamp.Color = if on then Color3.fromRGB(255, 40, 40) else Color3.fromRGB(120, 20, 20)
					local light = lamp:FindFirstChildOfClass("PointLight")
					if light then
						light.Enabled = on
					end
				end
				ctx.Services.NoiseService:Emit(lamps[1].Position, 0.3, "Interaction", nil)
			end,
			Stop = function() end,
		},
	}
end

---------------------------------------------------------------------------
-- places that are wrong
---------------------------------------------------------------------------

function MODES.Elevator(ctx, record, fixture, _params)
	local doors = nearby("ElevatorDoor", (firstPart(fixture) :: BasePart).Position, 8)
	if #doors == 0 then
		return nil
	end
	local center = Vector3.zero
	for _, door in ipairs(doors) do
		center += (door :: BasePart).Position
	end
	center /= #doors
	local door = doors[1] :: BasePart
	local inside = CFrame.lookAt(center + door.CFrame.LookVector * 3.2 - Vector3.new(0, 4.3, 0), center - Vector3.new(0, 4.3, 0) - door.CFrame.LookVector * 10)
	local saved = {}
	for _, d in ipairs(doors) do
		saved[d] = (d :: BasePart).CFrame
	end
	record.Cleaner:Add(function()
		for d, cf in pairs(saved) do
			(d :: BasePart).CFrame = cf
		end
	end)
	ctx.Kit.PlaySound3D(door, "Interaction.ElevatorDing")
	local b = body(ctx, record, "Shadow", inside)
	record.Target = b.Torso
	record.VisibilityRoot = b.Model
	task.delay(1.2, function()
		if record.CleanedUp then
			return
		end
		for d, cf in pairs(saved) do
			local side = d:GetAttribute("Side") or 1
			tween(d, 2.4, { CFrame = cf + cf.RightVector * side * 2.6 })
		end
	end)
	return {
		{
			Update = function()
				local _, distance = ctx:GetNearestParticipant(center)
				if distance < 10 and not record.Despawning then
					for d, cf in pairs(saved) do
						tween(d, 0.5, { CFrame = cf }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
					end
					ctx.Kit.PlaySound3D(door, "Door.Metal.Slam")
					ctx:Despawn(record, "Closed")
				end
			end,
			Stop = function() end,
		},
	}
end

function MODES.Shutter(ctx, record, fixture, _params)
	local shutter = ctx.Objects.PropOf(fixture)
	local target = firstPart(shutter) :: BasePart
	ctx.Objects.Borrow(record, shutter)
	local pivot = ctx.Objects.PivotOf(shutter)
	ctx.Objects.TweenPivot(record, shutter, pivot + Vector3.new(0, 7, 0), 9, Enum.EasingStyle.Linear)
	ctx.Kit.PlaySound3D(target, "Anomaly.MetalGroan")
	-- light switching on inside + a mannequin that was not there
	local light = Instance.new("Part")
	light.Anchored = true
	light.CanCollide = false
	light.CanQuery = false
	light.Transparency = 1
	light.Size = Vector3.new(1, 1, 1)
	light.CFrame = pivot * CFrame.new(0, 8, 6)
	local point = Instance.new("PointLight")
	point.Color = Color3.fromRGB(255, 220, 170)
	point.Range = 22
	point.Brightness = 0
	point.Parent = light
	light.Parent = ctx.Services.MapService.Folders.ActiveAnomalies
	record.Cleaner:Add(light)
	tween(point, 4, { Brightness = 1.2 })
	local b = body(ctx, record, "Mannequin", pivot * CFrame.new(0, 0, 7) * CFrame.Angles(0, math.pi, 0))
	record.Target = b.Torso
	record.VisibilityRoot = b.Model
	return {}
end

function MODES.CeilingFace(ctx, record, fixture, _params)
	local grille = firstPart(fixture) :: BasePart
	local face = Instance.new("Part")
	face.Name = "CeilingFace"
	face.Anchored = true
	face.CanCollide = false
	face.CanTouch = false
	face.Size = Vector3.new(1.6, 0.4, 2)
	face.Color = Color3.fromRGB(214, 206, 196)
	face.CFrame = grille.CFrame * CFrame.new(0, 0.5, 0)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Bottom
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(100, 120)
	gui.LightInfluence = 0.3
	for _, x in ipairs({ 30, 70 }) do
		local eye = Instance.new("Frame")
		eye.AnchorPoint = Vector2.new(0.5, 0.5)
		eye.Position = UDim2.fromOffset(x, 40)
		eye.Size = UDim2.fromOffset(14, 18)
		eye.BackgroundColor3 = Color3.new(0, 0, 0)
		eye.BorderSizePixel = 0
		eye.Parent = gui
	end
	local mouth = Instance.new("Frame")
	mouth.AnchorPoint = Vector2.new(0.5, 0.5)
	mouth.Position = UDim2.fromOffset(50, 88)
	mouth.Size = UDim2.fromOffset(40, 12)
	mouth.BackgroundColor3 = Color3.fromRGB(20, 0, 0)
	mouth.BorderSizePixel = 0
	mouth.Parent = gui
	gui.Parent = face
	face.Parent = ctx.Services.MapService.Folders.ActiveAnomalies
	record.Cleaner:Add(face)
	tween(face, 3, { CFrame = grille.CFrame * CFrame.new(0, -0.1, 0) })
	ctx.Kit.PlaySound3D(face, "Anomaly.Breath")
	record.Target = face
	local seen = 0
	return {
		{
			Update = function(dt)
				if ctx.Objects.Observed(ctx, face.Position, { face }) then
					seen += dt
					if seen > 2.5 and not record.Despawning then
						tween(face, 0.3, { CFrame = grille.CFrame * CFrame.new(0, 0.8, 0) })
						ctx.Kit.PlaySound3D(face, "Anomaly.CeilingScuttle")
						task.delay(0.35, function()
							if not record.Despawning then
								ctx:Despawn(record, "Retreated")
							end
						end)
					end
				end
			end,
			Stop = function() end,
		},
	}
end

function MODES.Hallway(ctx, record, marker, params)
	-- the end wall of the service hall is suddenly an open doorway onto a
	-- corridor that never ends (built behind the wall, outside the mall)
	local back = params.WallOffset or 10
	local base = marker.CFrame * CFrame.new(0, 0, back) * CFrame.Angles(0, math.pi, 0)
	-- open the wall (restored afterwards)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { ctx.Services.MapService.Folders.Map }
	local opened = {}
	for _, part in ipairs(Workspace:GetPartBoundsInBox(base * CFrame.new(0, 4.5, 0), Vector3.new(5.6, 8.6, 2.5), overlap)) do
		if part:IsA("BasePart") and part.Transparency < 1 and part.Size.Y > 3 then
			table.insert(opened, { Part = part, Transparency = part.Transparency, CanCollide = part.CanCollide })
			part.Transparency = 1
			part.CanCollide = false
		end
	end
	record.Cleaner:Add(function()
		for _, entry in ipairs(opened) do
			entry.Part.Transparency = entry.Transparency
			entry.Part.CanCollide = entry.CanCollide
		end
	end)
	local f = Build.frame(ctx.Services.MapService.Folders.ActiveAnomalies, base)
	local m = f:model("ImpossibleHallway")
	local model = m.Parent :: Model
	local wall = Color3.fromRGB(70, 70, 66)
	local length = 150
	m:box("Floor", Vector3.new(6, 0.4, length), Vector3.new(0, -0.2, -length / 2), Color3.fromRGB(58, 56, 52), Enum.Material.Concrete)
	m:box("Ceiling", Vector3.new(6, 0.4, length), Vector3.new(0, 10.2, -length / 2), Color3.fromRGB(80, 80, 78), Enum.Material.Concrete)
	m:box("WallL", Vector3.new(0.4, 10, length), Vector3.new(-3.2, 5, -length / 2), wall, Enum.Material.Concrete)
	m:box("WallR", Vector3.new(0.4, 10, length), Vector3.new(3.2, 5, -length / 2), wall, Enum.Material.Concrete)
	m:box("End", Vector3.new(6, 10, 0.4), Vector3.new(0, 5, -length), Color3.fromRGB(10, 10, 10), Enum.Material.SmoothPlastic)
	for z = 10, length - 10, 14 do
		local lamp = m:box("Lamp", Vector3.new(1.2, 0.2, 3), Vector3.new(0, 9.9, -z), Color3.fromRGB(255, 230, 180), Enum.Material.Neon, { deco = true })
		local light = Instance.new("PointLight")
		light.Range = 12
		light.Brightness = 0.7 * (1 - z / length)
		light.Color = Color3.fromRGB(255, 220, 170)
		light.Parent = lamp
		if z > 40 then
			m:box("Door", Vector3.new(0.3, 7, 3.4), Vector3.new(if (z // 14) % 2 == 0 then -3 else 3, 3.5, -z), Color3.fromRGB(40, 40, 44), Enum.Material.Metal, { deco = true })
		end
	end
	local b = body(ctx, record, "Employee", base * CFrame.new(0, 0, -length + 14) * CFrame.Angles(0, math.pi, 0))
	record.Cleaner:Add(model)
	record.Target = b.Torso
	record.VisibilityRoot = model
	ctx.Kit.PlaySound3D(base.Position, "Anomaly.MetalGroan")
	return {
		{
			Update = function()
				-- whoever walks too far in is suddenly back at the start
				for _, player in ipairs(ctx:GetParticipants()) do
					local root = ctx:GetCharacterParts(player)
					if root then
						local localPosition = base:PointToObjectSpace(root.Position)
						if localPosition.Z < -45 and math.abs(localPosition.X) < 4 and math.abs(localPosition.Y) < 12 then
							ctx.Services.CharacterService:Teleport(player, marker.CFrame)
							ctx.Kit.PlaySound3D(marker.Position, "Anomaly.Whisper")
						end
					end
				end
			end,
			Stop = function() end,
		},
	}
end

function MODES.WrongStore(ctx, record, marker, params)
	local names = { "MEMORIES & CO.", "YOUR ROOM", "LOST CHILDREN", "EXIT (NOT HERE)", "WE MISS YOU", "GIFTS FOR THE DEAD" }
	-- in front of the store's closed shutter, facing the hall
	local f = Build.frame(ctx.Services.MapService.Folders.ActiveAnomalies, marker.CFrame * CFrame.new(0, 6, -(params.FrontDistance or 28.2)))
	local m = f:model("WrongStoreSign")
	local sign = m:box("Sign", Vector3.new(16, 2.4, 0.4), Vector3.new(0, 0, 0), Color3.fromRGB(10, 10, 12), Enum.Material.SmoothPlastic)
	local label = Build.text(sign, Enum.NormalId.Front, names[math.random(1, #names)], { Color = Color3.fromRGB(255, 70, 110), Font = Enum.Font.Arcade, Glow = true })
	local lightPart = m:box("Glow", Vector3.new(1, 1, 1), Vector3.new(0, 0, -1), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, { t = 1, deco = true })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 70, 110)
	light.Range = 20
	light.Brightness = 1.5
	light.Parent = lightPart
	record.Cleaner:Add(m.Parent)
	record.Target = sign
	local nextFlicker = 0
	return {
		{
			Update = function()
				if os.clock() >= nextFlicker then
					nextFlicker = os.clock() + 0.1 + math.random() * 1.5
					light.Enabled = math.random() > 0.15
					label.TextTransparency = if light.Enabled then 0 else 0.7
				end
			end,
			Stop = function() end,
		},
	}
end

function MODES.Locker(ctx, record, fixture, _params)
	local panel = fixture:FindFirstChild("DoorPanel")
	local target = (if panel and panel:IsA("BasePart") then panel else firstPart(fixture)) :: BasePart
	record.Target = target
	record.VisibilityRoot = fixture
	local knocks = 0
	local nextKnock = os.clock() + 1
	local burst = false
	return {
		{
			Update = function()
				if burst or os.clock() < nextKnock then
					return
				end
				knocks += 1
				nextKnock = os.clock() + 1.2 + math.random() * 1.5
				ctx.Kit.PlaySound3D(target, "Anomaly.Knock")
				ctx.Services.NoiseService:Emit(target.Position, 0.2, "Interaction", nil)
				local _, distance = ctx:GetNearestParticipant(target.Position)
				if knocks >= 4 and distance < 14 then
					burst = true
					ctx.Services.InteractionService:ForceDoor(fixture, true, true)
					ctx.Kit.PlaySound3D(target, "Anomaly.Laugh")
					task.delay(3, function()
						ctx.Services.InteractionService:ForceDoor(fixture, false, true)
					end)
				end
			end,
			Stop = function()
				ctx.Services.InteractionService:ForceDoor(fixture, false, false)
			end,
		},
	}
end

function MODES.SecurityCams(ctx, record, fixture, _params)
	local center = (firstPart(fixture) :: BasePart).Position
	local cams = {}
	for _, cam in ipairs(nearby("SecurityCamera", center, 60)) do
		if cam:IsA("BasePart") then
			table.insert(cams, { Part = cam, CFrame = cam.CFrame })
		end
	end
	record.Cleaner:Add(function()
		for _, entry in ipairs(cams) do
			entry.Part.CFrame = entry.CFrame
		end
	end)
	-- the security room monitors show YOU... and a face
	local monitors = {}
	for _, monitor in ipairs(CollectionService:GetTagged("CCTVMonitor")) do
		table.insert(monitors, { Part = monitor, Mode = monitor:GetAttribute("Mode") })
		monitor:SetAttribute("Mode", if math.random() < 0.3 then "Face" else "CCTV")
	end
	record.Cleaner:Add(function()
		for _, entry in ipairs(monitors) do
			entry.Part:SetAttribute("Mode", entry.Mode)
		end
	end)
	record.Target = (firstPart(fixture) :: BasePart)
	return {
		{
			Update = function()
				local _, _, root = ctx:GetNearestParticipant(center, 90)
				if not root then
					return
				end
				for _, entry in ipairs(cams) do
					local part = entry.Part
					local look = CFrame.lookAt(part.Position, root.Position + Vector3.new(0, 2, 0))
					part.CFrame = part.CFrame:Lerp(look, 0.25)
				end
			end,
			Stop = function() end,
		},
	}
end

function MODES.Escalator(ctx, record, fixture, _params)
	local escalator = ctx.Objects.PropOf(fixture)
	local steps = {}
	for _, step in ipairs(escalator:GetDescendants()) do
		if step:IsA("BasePart") and step:HasTag("EscalatorStep") then
			table.insert(steps, step)
		end
	end
	if #steps < 2 then
		return nil
	end
	table.sort(steps, function(a, b)
		return (a:GetAttribute("T") or 0) < (b:GetAttribute("T") or 0)
	end)
	escalator:SetAttribute("Running", true)
	record.Cleaner:Add(function()
		escalator:SetAttribute("Running", false)
	end)
	ctx.Kit.PlaySound3D(steps[1], "Anomaly.MetalGroan")
	local up = escalator:GetAttribute("Direction") ~= "Down"
	local first, last = steps[1], steps[#steps]
	local from = if up then first else last
	local to = if up then last else first
	local facing = (to.Position - from.Position) * Vector3.new(1, 0, 1)
	local b = body(ctx, record, "Shadow", CFrame.lookAt(from.Position + Vector3.new(0, 0.2, 0), from.Position + Vector3.new(0, 0.2, 0) + facing))
	record.Target = b.Torso
	record.VisibilityRoot = b.Model
	local started = os.clock()
	local ride = 14
	return {
		{
			Update = function()
				local alpha = math.clamp((os.clock() - started) / ride, 0, 1)
				local position = from.Position:Lerp(to.Position, alpha) + Vector3.new(0, 0.2, 0)
				b.Root.CFrame = CFrame.lookAt(position, position + facing)
				if alpha >= 1 and not record.Despawning then
					ctx:Despawn(record, "RodeAway")
				end
			end,
			Stop = function() end,
		},
	}
end

function MODES.Chair(ctx, record, marker, _params)
	-- a food court chair drags itself between you and the way out
	local f = Build.frame(ctx.Services.MapService.Folders.ActiveAnomalies, marker.CFrame * CFrame.new(2.5, 0, 0))
	local Props = require(World:WaitForChild("Props"):WaitForChild("Common"))
	local chair = Props.Chair(f:at(0, 0, 0, math.random(0, 360)), Rng.new(math.random(1, 1e6)))
	local model = chair.Parent :: Model
	record.Cleaner:Add(model)
	local target = model:FindFirstChildWhichIsA("BasePart", true) :: BasePart
	record.Target = target
	record.VisibilityRoot = model
	return { ctx.Objects.MoveWhenNotObserved(ctx, record, model, { Step = 2, Interval = 0.5, StopDistance = 3.5, Sound = "Anomaly.ChairScrape", Face = false }) }
end

---------------------------------------------------------------------------
-- the behaviour module
---------------------------------------------------------------------------

function ObjectAnomaly.Spawn(ctx, record)
	local params = record.Params
	local mode = MODES[params.Mode]
	if not mode then
		warn("[ObjectAnomaly] unknown mode", params.Mode, "for", record.Id)
		return false
	end
	local source = nil
	if record.Def.Spawn.Fixture then
		source = ctx:PickFixture(record)
	else
		source = ctx:PickSpawn(record)
	end
	if not source then
		return false
	end
	local controllers = mode(ctx, record, source, params)
	if controllers == nil or not record.Target then
		return false
	end
	record.State.Controllers = controllers
	if params.Silent then
		record.Silent = true
	end
	return true
end

function ObjectAnomaly.Update(_ctx, record, dt)
	for _, controller in ipairs(record.State.Controllers or {}) do
		controller.Update(dt)
	end
end

function ObjectAnomaly.Despawn(_ctx, record)
	for _, controller in ipairs(record.State.Controllers or {}) do
		controller.Stop()
	end
	record.NoFade = true
end

return ObjectAnomaly
