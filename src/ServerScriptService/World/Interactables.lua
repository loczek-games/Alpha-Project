--[[
	Interactables (ModuleScript)
	Location: ServerScriptService/World/Interactables

	Builders for objects InteractionService brings to life (by tag):
	  Door             Model: Hinge (anchored) + Panel/Knob welded; attrs DoorType, Locked, StartsLocked, KeyId, Zone
	  Locker           Model: Body, Hinge, DoorPanel (+Vents) ; attr Zone
	  Drawer           Part ; attrs Slide (Vector3), Zone
	  SecurityComputer Part with SurfaceGui "SignGui" > TextLabel "Screen"
	  Radio            Part
	  Breaker          Model: Box (PrimaryPart) + Lever
	Elevators and payphones come from Props (Utility.ElevatorDoors / Common.Payphone).
]]

local World = script.Parent
local Build = require(World.Build)

local C, M = Build.C, Build.M
local V = Vector3.new
local FRONT = Enum.NormalId.Front

local I = {}

local function weld(anchor: BasePart, part: BasePart)
	part.Anchored = false
	part.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0 = anchor
	w.Part1 = part
	w.Parent = part
end

-- Door hinged at the frame's origin, swinging leaf extends along local +X.
-- The frame should sit on the floor at the hinge side of the opening, with
-- local -Z pointing to the side the door opens away from (players push it).
function I.Door(f: Build.Frame, width: number, height: number, doorType: string, color: Color3, material: Enum.Material, zone: string, locked: boolean?, windowed: boolean?, sign: string?)
	local m = f:model("Door")
	local door = m.Parent :: Model
	local hinge = m:box("Hinge", V(0.3, height, 0.3), V(0, height / 2, 0), C.Black, M.SmoothPlastic, { t = 1, collide = false, query = false, shadow = false })
	local panel = m:box("Panel", V(width - 0.1, height - 0.1, 0.35), V(width / 2, height / 2, 0), color, material, { shadow = false })
	local knob = m:box("Knob", V(0.3, 0.3, 0.8), V(width - 0.55, height / 2 - 0.3, 0), C.Chrome, M.Metal, { deco = true })
	weld(hinge, panel)
	weld(hinge, knob)
	if windowed then
		local window = m:box("Window", V(1.2, 2.2, 0.4), V(width / 2, height * 0.68, 0), C.Charcoal, M.Glass, { deco = true, refl = 0.2 })
		weld(hinge, window)
	end
	if sign then
		local plate = m:box("Sign", V(math.min(width - 0.8, 3.2), 0.8, 0.38), V(width / 2, height * 0.8, 0), C.OffWhite, M.SmoothPlastic, { deco = true })
		Build.text(plate, FRONT, sign, { Color = C.Black, Font = Enum.Font.GothamBold })
		Build.text(plate, Enum.NormalId.Back, sign, { Color = C.Black, Font = Enum.Font.GothamBold })
		weld(hinge, plate)
	end
	door.PrimaryPart = hinge
	Build.attrs(door, { DoorType = doorType, Locked = locked == true, StartsLocked = locked == true, Zone = zone })
	if locked then
		door:SetAttribute("KeyId", "SecurityKey")
	end
	door:AddTag("Door")
	return door
end

-- Door + frame filling an opening centred at the frame origin (opening along local X).
function I.DoorInOpening(f: Build.Frame, width: number, height: number, doorType: string, color: Color3, material: Enum.Material, zone: string, locked: boolean?, windowed: boolean?, sign: string?)
	local frameColor = if doorType == "Wood" then C.WoodDark else C.Charcoal
	f:box("Jamb", V(0.5, height + 0.4, 0.9), V(-width / 2 - 0.25, (height + 0.4) / 2, 0), frameColor, M.Metal, { deco = true })
	f:box("Jamb", V(0.5, height + 0.4, 0.9), V(width / 2 + 0.25, (height + 0.4) / 2, 0), frameColor, M.Metal, { deco = true })
	f:box("Head", V(width + 1, 0.5, 0.9), V(0, height + 0.15, 0), frameColor, M.Metal, { deco = true })
	return I.Door(f:at(-width / 2, 0, 0), width, height, doorType, color, material, zone, locked, windowed, sign)
end

function I.Locker(f: Build.Frame, zone: string, color: Color3?)
	local m = f:model("Locker")
	local locker = m.Parent :: Model
	local c = color or C.Steel
	m:box("Body", V(2.6, 7, 2), V(0, 3.5, 0), c, M.Metal, { shadow = false })
	local hinge = m:box("Hinge", V(0.2, 6.6, 0.2), V(-1.2, 3.5, -1.08), C.Black, M.SmoothPlastic, { t = 1, collide = false, query = false })
	local panel = m:box("DoorPanel", V(2.4, 6.6, 0.12), V(0, 3.5, -1.08), Build.shade(c, 0.08), M.Metal, { collide = false, shadow = false })
	weld(hinge, panel)
	for i = 0, 3 do
		local vent = m:box("Vent", V(1.4, 0.08, 0.05), V(0, 6 - i * 0.25, -1.16), C.Charcoal, M.Metal, { deco = true, query = false })
		weld(hinge, vent)
	end
	locker.PrimaryPart = hinge
	locker:SetAttribute("Zone", zone)
	locker:AddTag("Locker")
	return locker
end

-- a pull-out drawer (cash register drawer, desk drawer); slide = local direction it opens
function I.Drawer(f: Build.Frame, position: Vector3, slide: Vector3, zone: string)
	local cf = f:cf(position)
	local worldSlide = cf:VectorToWorldSpace(slide)
	local drawer = Build.part(f.Parent, "Drawer", V(1.6, 0.5, 1.6), cf, C.WoodDark, M.Wood, { deco = true })
	drawer.CanQuery = true
	Build.attrs(drawer, { Slide = worldSlide, Zone = zone })
	drawer:AddTag("Drawer")
	return drawer
end

function I.SecurityComputer(f: Build.Frame, where: any)
	local screen = f:box("SecurityComputer", V(2.4, 1.6, 0.3), where, C.Void, M.SmoothPlastic, { shadow = false })
	local gui = Build.surfaceGui(screen, FRONT, true, 50)
	gui.Name = "SignGui"
	local label = Instance.new("TextLabel")
	label.Name = "Screen"
	label.BackgroundColor3 = Build.rgb(8, 18, 10)
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.FontFace = Font.fromEnum(Enum.Font.Code)
	label.TextColor3 = C.NeonGreen
	label.Text = "CCTV\nOFFLINE"
	label.Parent = gui
	screen:AddTag("SecurityComputer")
	return screen
end

function I.Radio(f: Build.Frame, where: any)
	local radio = f:box("Radio", V(1.4, 0.9, 0.6), where, C.DarkGreen, M.Metal, { shadow = false })
	radio:AddTag("Radio")
	Build.part(f.Parent, "RadioAntenna", V(0.06, 1.4, 0.06), radio.CFrame * CFrame.new(0.5, 1.1, 0), C.Black, M.Metal, { deco = true, query = false })
	Build.part(f.Parent, "Dial", V(0.4, 0.4, 0.05), radio.CFrame * CFrame.new(-0.3, 0.1, -0.32), C.NeonOrange, M.Neon, { deco = true })
	return radio
end

function I.Breaker(f: Build.Frame)
	local m = f:model("Breaker")
	local breaker = m.Parent :: Model
	local box = m:box("Box", V(3, 4, 1), V(0, 5, 0), C.Steel, M.Metal)
	local lever = m:box("Lever", V(0.4, 1.4, 0.4), V(0.8, 5.3, -0.7), C.Red, M.Plastic, { deco = true })
	lever.Name = "Lever"
	local label = m:box("Label", V(2.4, 0.8, 0.05), V(0, 6.6, -0.53), C.Yellow, M.SmoothPlastic, { deco = true })
	Build.text(label, FRONT, "MAIN BREAKER", { Color = C.Black, Font = Enum.Font.GothamBlack })
	breaker.PrimaryPart = box
	breaker:AddTag("Breaker")
	return breaker
end

return I
