--[[
	Rig (ModuleScript)
	Location: ServerScriptService/Anomalies/Rig

	Procedural anomaly bodies built from parts - used when a catalog bundle
	cannot be loaded and no model was dropped into ServerStorage/AnomalyModels.

	  Rig.Humanoid(opts)  an R15-compatible rig (Humanoid, HumanoidRootPart,
	                      standard part + Motor6D names: Root, Waist, Neck,
	                      Left/RightShoulder, Elbow, Wrist, Hip, Knee, Ankle), so
	                      the client AnomalyAnimator animates it exactly like
	                      a real avatar / bundle rig.
	  Rig.Spider(opts)    the CEILING CRAWLER: long-legged, many-jointed body,
	                      pale face with too many eyes (Motor6D legs "Leg1..8").
	  Rig.Style(name)     the silhouettes: Smiler, Titan, Possessed, Slacker,
	                      Rat, Mannequin, Dummy, Faceless, Shadow, Employee,
	                      Double.
]]

local Rig = {}

export type Options = {
	Name: string?,
	Scale: number?,
	Height: number?, -- overall height before Scale (default 5.2 = a normal avatar)
	Thin: number?, -- width multiplier
	ArmLength: number?, -- multiplier
	LegLength: number?,
	Skin: Color3?,
	Shirt: Color3?,
	Pants: Color3?,
	Shoes: Color3?,
	Material: Enum.Material?,
	Hunch: number?, -- degrees the upper body leans forward
	Face: string?, -- "Smile" | "Blank" | "Hollow" | "Static" | "Rat" | "Eyes" | "None"
	EyeColor: Color3?,
	Transparency: number?,
}

local function part(model: Instance, name: string, size: Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = true
	p.Anchored = false
	p.Parent = model
	return p
end

local function motor(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = c0
	m.C1 = c1
	m.Parent = part1
	return m
end

local function weldDecoration(target: BasePart, decoration: BasePart, offset: CFrame)
	decoration.CFrame = target.CFrame * offset
	decoration.Massless = true
	decoration.CanQuery = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = target
	weld.Part1 = decoration
	weld.Parent = decoration
end

---------------------------------------------------------------------------
-- Faces (SurfaceGuis on the head's front, drawn with frames)
---------------------------------------------------------------------------

local function faceGui(head: BasePart): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Face"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(100, 100)
	gui.LightInfluence = 1
	gui.Parent = head
	return gui
end

local function dot(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, round: boolean?, name: string?): Frame
	local f = Instance.new("Frame")
	f.Name = name or "Mark"
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	if round ~= false then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = f
	end
	f.Parent = parent
	return f
end

local FACES = {}

function FACES.Smile(head: BasePart, eye: Color3)
	local gui = faceGui(head)
	dot(gui, 30, 36, 18, 22, Color3.new(0, 0, 0))
	dot(gui, 70, 36, 18, 22, Color3.new(0, 0, 0))
	dot(gui, 31, 34, 5, 5, eye)
	dot(gui, 71, 34, 5, 5, eye)
	local mouth = dot(gui, 50, 70, 92, 30, Color3.fromRGB(12, 0, 0))
	local teeth = dot(mouth, 46, 8, 84, 10, Color3.fromRGB(245, 240, 225), false)
	teeth.Name = "Teeth"
	for i = 1, 9 do
		dot(teeth, i * 9 - 3, 5, 1, 10, Color3.fromRGB(120, 110, 100), false)
	end
end

function FACES.Hollow(head: BasePart, eye: Color3)
	local gui = faceGui(head)
	dot(gui, 32, 38, 22, 26, Color3.new(0, 0, 0))
	dot(gui, 68, 38, 22, 26, Color3.new(0, 0, 0))
	dot(gui, 32, 40, 4, 4, eye)
	dot(gui, 68, 40, 4, 4, eye)
	dot(gui, 50, 76, 26, 34, Color3.new(0, 0, 0))
end

function FACES.Eyes(head: BasePart, eye: Color3)
	local gui = faceGui(head)
	gui.LightInfluence = 0
	dot(gui, 34, 42, 10, 6, eye)
	dot(gui, 66, 42, 10, 6, eye)
end

function FACES.Static(head: BasePart)
	local gui = faceGui(head)
	local bg = dot(gui, 50, 50, 100, 100, Color3.fromRGB(90, 90, 90), false)
	bg.Name = "Static"
	for i = 1, 8 do
		dot(bg, 50, i * 12, 100, 3, Color3.fromRGB(math.random(10, 220), math.random(10, 220), math.random(10, 220)), false)
	end
end

function FACES.Rat(head: BasePart, eye: Color3)
	local gui = faceGui(head)
	dot(gui, 30, 34, 12, 12, Color3.new(0, 0, 0))
	dot(gui, 70, 34, 12, 12, Color3.new(0, 0, 0))
	dot(gui, 31, 32, 4, 4, eye)
	dot(gui, 71, 32, 4, 4, eye)
	dot(gui, 44, 80, 7, 14, Color3.fromRGB(240, 230, 200), false)
	dot(gui, 56, 80, 7, 14, Color3.fromRGB(240, 230, 200), false)
end

function FACES.Blank(_head: BasePart) end
function FACES.None(_head: BasePart) end

---------------------------------------------------------------------------
-- The humanoid rig
---------------------------------------------------------------------------

function Rig.Humanoid(opts: Options): Model
	local scale = opts.Scale or 1
	local height = (opts.Height or 5.2) * scale
	local thin = opts.Thin or 1
	local skin = opts.Skin or Color3.fromRGB(200, 180, 160)
	local shirt = opts.Shirt or Color3.fromRGB(60, 60, 64)
	local pants = opts.Pants or Color3.fromRGB(34, 34, 40)
	local shoes = opts.Shoes or Color3.fromRGB(20, 20, 20)
	local material = opts.Material or Enum.Material.SmoothPlastic

	-- proportions (fractions of total height)
	local legScale = opts.LegLength or 1
	local foot = 0.05 * height
	local lowerLeg = 0.19 * height * legScale
	local upperLeg = 0.19 * height * legScale
	local lowerTorso = 0.08 * height
	local upperTorso = 0.24 * height
	local headSize = 0.2 * height
	local armScale = opts.ArmLength or 1
	local upperArm = 0.18 * height * armScale
	local lowerArm = 0.17 * height * armScale
	local hand = 0.06 * height * armScale
	local torsoWidth = 0.38 * height * thin
	local torsoDepth = 0.19 * height * thin
	local limb = 0.19 * height * thin * 0.55

	local model = Instance.new("Model")
	model.Name = opts.Name or "Entity"
	local hipY = foot + lowerLeg + upperLeg
	local ltCenter = hipY + lowerTorso / 2
	local waistY = hipY + lowerTorso
	local utCenter = waistY + upperTorso / 2
	local neckY = waistY + upperTorso
	local headCenter = neckY + headSize / 2
	local shoulderY = neckY - 0.03 * height

	local root = part(model, "HumanoidRootPart", Vector3.new(torsoWidth, 2 * scale, torsoDepth), skin)
	root.Transparency = 1
	root.CFrame = CFrame.new(0, ltCenter, 0)
	local lt = part(model, "LowerTorso", Vector3.new(torsoWidth * 0.95, lowerTorso, torsoDepth), pants, material)
	lt.CFrame = CFrame.new(0, ltCenter, 0)
	local ut = part(model, "UpperTorso", Vector3.new(torsoWidth, upperTorso, torsoDepth), shirt, material)
	ut.CFrame = CFrame.new(0, utCenter, 0)
	local head = part(model, "Head", Vector3.new(headSize * 0.82, headSize, headSize * 0.9), skin, material)
	head.CFrame = CFrame.new(0, headCenter, 0)

	motor("Root", root, lt, CFrame.new(0, 0, 0), CFrame.new(0, 0, 0))
	motor("Waist", lt, ut, CFrame.new(0, lowerTorso / 2, 0), CFrame.new(0, -upperTorso / 2, 0))
	motor("Neck", ut, head, CFrame.new(0, upperTorso / 2, 0), CFrame.new(0, -headSize / 2, 0))

	for _, side in ipairs({ "Left", "Right" }) do
		local sx = if side == "Left" then -1 else 1
		local armX = sx * (torsoWidth / 2 + limb / 2)
		local ua = part(model, side .. "UpperArm", Vector3.new(limb, upperArm, limb), shirt, material)
		ua.CFrame = CFrame.new(armX, shoulderY - upperArm / 2, 0)
		local la = part(model, side .. "LowerArm", Vector3.new(limb * 0.9, lowerArm, limb * 0.9), skin, material)
		la.CFrame = CFrame.new(armX, shoulderY - upperArm - lowerArm / 2, 0)
		local h = part(model, side .. "Hand", Vector3.new(limb * 0.85, hand, limb * 0.6), skin, material)
		h.CFrame = CFrame.new(armX, shoulderY - upperArm - lowerArm - hand / 2, 0)
		motor(side .. "Shoulder", ut, ua, CFrame.new(armX, shoulderY - utCenter, 0), CFrame.new(0, upperArm / 2, 0))
		motor(side .. "Elbow", ua, la, CFrame.new(0, -upperArm / 2, 0), CFrame.new(0, lowerArm / 2, 0))
		motor(side .. "Wrist", la, h, CFrame.new(0, -lowerArm / 2, 0), CFrame.new(0, hand / 2, 0))

		local legX = sx * torsoWidth * 0.26
		local ul = part(model, side .. "UpperLeg", Vector3.new(limb * 1.1, upperLeg, limb * 1.1), pants, material)
		ul.CFrame = CFrame.new(legX, hipY - upperLeg / 2, 0)
		local ll = part(model, side .. "LowerLeg", Vector3.new(limb, lowerLeg, limb), pants, material)
		ll.CFrame = CFrame.new(legX, foot + lowerLeg / 2, 0)
		local f = part(model, side .. "Foot", Vector3.new(limb * 1.05, foot, limb * 1.6), shoes, material)
		f.CFrame = CFrame.new(legX, foot / 2, -limb * 0.25)
		motor(side .. "Hip", lt, ul, CFrame.new(legX, -lowerTorso / 2, 0), CFrame.new(0, upperLeg / 2, 0))
		motor(side .. "Knee", ul, ll, CFrame.new(0, -upperLeg / 2, 0), CFrame.new(0, lowerLeg / 2, 0))
		motor(side .. "Ankle", ll, f, CFrame.new(0, -lowerLeg / 2, 0), CFrame.new(0, foot / 2, limb * 0.25))
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = ltCenter - root.Size.Y / 2
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.Parent = model
	Instance.new("Animator").Parent = humanoid
	model.PrimaryPart = root

	if opts.Hunch and opts.Hunch ~= 0 then
		model:SetAttribute("Hunch", opts.Hunch)
	end
	local face = FACES[opts.Face or "Blank"] or FACES.Blank
	face(head, opts.EyeColor or Color3.fromRGB(255, 255, 255))
	if opts.Transparency then
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant ~= root then
				descendant.Transparency = opts.Transparency
			end
		end
	end
	return model
end

---------------------------------------------------------------------------
-- Silhouettes
---------------------------------------------------------------------------

local STYLES = {}

-- tall, thin, pale, impossibly wide grin
function STYLES.Smiler()
	local model = Rig.Humanoid({ Name = "SmilingEntity", Height = 7.6, Thin = 0.72, ArmLength = 1.35, LegLength = 1.12, Skin = Color3.fromRGB(226, 220, 206), Shirt = Color3.fromRGB(226, 220, 206), Pants = Color3.fromRGB(210, 204, 190), Shoes = Color3.fromRGB(200, 194, 180), Face = "Smile", EyeColor = Color3.fromRGB(255, 255, 255), Hunch = 12 })
	return model
end

-- the ABNORMAL TITAN: huge, grey, eyeless, shoulders like a truck
function STYLES.Titan()
	local model = Rig.Humanoid({ Name = "AbnormalTitan", Height = 5.4, Scale = 1.9, Thin = 1.35, ArmLength = 1.2, Skin = Color3.fromRGB(120, 112, 108), Shirt = Color3.fromRGB(110, 102, 98), Pants = Color3.fromRGB(70, 64, 62), Shoes = Color3.fromRGB(90, 84, 80), Material = Enum.Material.Slate, Face = "Hollow", EyeColor = Color3.fromRGB(255, 60, 40), Hunch = 18 })
	local ut = model:FindFirstChild("UpperTorso") :: BasePart
	for _, side in ipairs({ -1, 1 }) do
		local lump = part(model, "Shoulder", Vector3.new(1.6, 1.3, 1.6), Color3.fromRGB(110, 100, 96), Enum.Material.Slate, Enum.PartType.Ball)
		weldDecoration(ut, lump, CFrame.new(side * ut.Size.X * 0.45, ut.Size.Y * 0.4, 0))
	end
	return model
end

-- POSSESSED CUSTOMER / possessed horror: pale, hunched, black eyes, torn clothes
function STYLES.Possessed()
	local model = Rig.Humanoid({ Name = "PossessedEntity", Height = 5.6, Thin = 0.88, ArmLength = 1.12, Skin = Color3.fromRGB(176, 168, 158), Shirt = Color3.fromRGB(70, 74, 84), Pants = Color3.fromRGB(46, 44, 50), Face = "Hollow", EyeColor = Color3.fromRGB(0, 0, 0), Hunch = 24 })
	local ut = model:FindFirstChild("UpperTorso") :: BasePart
	for i = 1, 3 do
		local rip = part(model, "Tear", Vector3.new(0.5, 0.05, 0.06), Color3.fromRGB(120, 20, 20), Enum.Material.SmoothPlastic)
		weldDecoration(ut, rip, CFrame.new(-0.3 + i * 0.25, -0.4 + i * 0.3, -ut.Size.Z / 2 - 0.02) * CFrame.Angles(0, 0, math.rad(30 + i * 10)))
	end
	return model
end

-- SLACKER CREEPY ENTITY / employee: store uniform + hoodie, face = static
function STYLES.Slacker()
	local model = Rig.Humanoid({ Name = "SlackerEntity", Height = 5.8, Thin = 0.82, ArmLength = 1.18, Skin = Color3.fromRGB(150, 140, 130), Shirt = Color3.fromRGB(40, 44, 52), Pants = Color3.fromRGB(34, 34, 38), Face = "Static", Hunch = 10 })
	local head = model:FindFirstChild("Head") :: BasePart
	local hood = part(model, "Hood", head.Size * Vector3.new(1.25, 1.15, 1.2), Color3.fromRGB(36, 40, 48), Enum.Material.Fabric)
	weldDecoration(head, hood, CFrame.new(0, 0.1, 0.12))
	local tag = part(model, "NameTag", Vector3.new(0.5, 0.25, 0.05), Color3.fromRGB(230, 220, 60), Enum.Material.SmoothPlastic)
	local ut = model:FindFirstChild("UpperTorso") :: BasePart
	weldDecoration(ut, tag, CFrame.new(0.35, 0.3, -ut.Size.Z / 2 - 0.03))
	return model
end

-- RAT: hunched rodent-headed thing
function STYLES.Rat()
	local model = Rig.Humanoid({ Name = "RatthewAnomaly", Height = 5, Thin = 0.9, Skin = Color3.fromRGB(110, 100, 96), Shirt = Color3.fromRGB(220, 220, 214), Pants = Color3.fromRGB(80, 110, 130), Face = "Rat", EyeColor = Color3.fromRGB(255, 40, 40), Hunch = 20 })
	local head = model:FindFirstChild("Head") :: BasePart
	local snout = part(model, "Snout", Vector3.new(head.Size.X * 0.5, head.Size.Y * 0.4, head.Size.Z * 0.7), Color3.fromRGB(120, 110, 104), Enum.Material.SmoothPlastic)
	weldDecoration(head, snout, CFrame.new(0, -head.Size.Y * 0.12, -head.Size.Z * 0.6))
	for _, side in ipairs({ -1, 1 }) do
		local ear = part(model, "Ear", Vector3.new(0.5, 0.6, 0.1), Color3.fromRGB(200, 140, 140), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		weldDecoration(head, ear, CFrame.new(side * head.Size.X * 0.45, head.Size.Y * 0.55, 0) * CFrame.Angles(0, math.rad(90), 0))
	end
	return model
end

-- glossy white store mannequin (no face)
function STYLES.Mannequin()
	local white = Color3.fromRGB(236, 232, 224)
	return Rig.Humanoid({ Name = "Mannequin", Height = 6.2, Thin = 0.8, Skin = white, Shirt = white, Pants = white, Shoes = white, Material = Enum.Material.SmoothPlastic, Face = "None" })
end

-- walking store dummy: tan fabric torso form, wooden limbs
function STYLES.Dummy()
	return Rig.Humanoid({ Name = "StoreDummy", Height = 6, Thin = 0.85, Skin = Color3.fromRGB(150, 120, 90), Shirt = Color3.fromRGB(196, 170, 130), Pants = Color3.fromRGB(150, 120, 90), Shoes = Color3.fromRGB(70, 60, 50), Material = Enum.Material.Wood, Face = "None", Hunch = 6 })
end

-- faceless shopper: ordinary clothes, perfectly blank face
function STYLES.Faceless()
	local shirts = { Color3.fromRGB(120, 40, 40), Color3.fromRGB(40, 70, 110), Color3.fromRGB(60, 90, 60), Color3.fromRGB(150, 140, 120) }
	return Rig.Humanoid({ Name = "FacelessShopper", Height = 5.3, Skin = Color3.fromRGB(214, 190, 160), Shirt = shirts[math.random(1, #shirts)], Pants = Color3.fromRGB(40, 44, 60), Face = "Blank" })
end

-- black figure / shadow people
function STYLES.Shadow()
	return Rig.Humanoid({ Name = "Shadow", Height = 6.6, Thin = 0.75, ArmLength = 1.2, Skin = Color3.fromRGB(4, 4, 6), Shirt = Color3.fromRGB(4, 4, 6), Pants = Color3.fromRGB(4, 4, 6), Shoes = Color3.fromRGB(4, 4, 6), Material = Enum.Material.SmoothPlastic, Face = "Eyes", EyeColor = Color3.fromRGB(255, 250, 235) })
end

-- a night-shift employee who never clocked out
function STYLES.Employee()
	return Rig.Humanoid({ Name = "Employee", Height = 5.5, Thin = 0.9, Skin = Color3.fromRGB(170, 150, 136), Shirt = Color3.fromRGB(120, 24, 24), Pants = Color3.fromRGB(30, 30, 34), Face = "Hollow", EyeColor = Color3.fromRGB(0, 0, 0), Hunch = 8 })
end

-- THE LISTENER: tall, eyeless, huge ears, a mouth that never closes
function STYLES.Listener()
	local model = Rig.Humanoid({ Name = "TheListener", Height = 8.2, Thin = 0.75, ArmLength = 1.3, Skin = Color3.fromRGB(62, 54, 58), Shirt = Color3.fromRGB(38, 32, 36), Pants = Color3.fromRGB(38, 32, 36), Shoes = Color3.fromRGB(30, 26, 28), Face = "None", Hunch = 16 })
	local head = model:FindFirstChild("Head") :: BasePart
	for _, side in ipairs({ -1, 1 }) do
		local ear = part(model, "Ear", Vector3.new(0.15, 1.6, 1.1), Color3.fromRGB(80, 60, 65), Enum.Material.SmoothPlastic)
		weldDecoration(head, ear, CFrame.new(side * (head.Size.X / 2 + 0.1), 0.25, 0) * CFrame.Angles(0, 0, math.rad(side * -25)))
	end
	local mouth = part(model, "Mouth", Vector3.new(head.Size.X * 0.5, head.Size.Y * 0.35, 0.05), Color3.fromRGB(5, 0, 0), Enum.Material.SmoothPlastic)
	weldDecoration(head, mouth, CFrame.new(0, -head.Size.Y * 0.15, -head.Size.Z / 2 - 0.02))
	return model
end

function Rig.Style(name: string): Model?
	local builder = STYLES[name]
	if not builder then
		return nil
	end
	local model = builder()
	model:SetAttribute("Style", name)
	return model
end

---------------------------------------------------------------------------
-- The CEILING CRAWLER
---------------------------------------------------------------------------

--[[
	Built upside-down-agnostic: the body's "up" is the root's +Y (the side
	that touches the ceiling is +Y when crawling on a ceiling, so the
	CeilingMover simply flips the root). Legs are Motor6D chains
	(LegN -> ShinN) that the client animates; the face hangs below.
]]
function Rig.Spider(opts: { Scale: number?, Color: Color3?, Skin: Color3? }?): Model
	local o = opts or {}
	local s = o.Scale or 1
	local shell = o.Color or Color3.fromRGB(34, 30, 32)
	local skin = o.Skin or Color3.fromRGB(206, 196, 186)
	local model = Instance.new("Model")
	model.Name = "CeilingCrawler"
	local root = part(model, "Root", Vector3.new(2.4, 1, 3.4) * s, shell)
	root.Transparency = 1
	root.CFrame = CFrame.new()
	local thorax = part(model, "Thorax", Vector3.new(2.2, 1.1, 2.6) * s, shell, Enum.Material.SmoothPlastic)
	thorax.CFrame = CFrame.new(0, 0, 0)
	motor("Body", root, thorax, CFrame.new(), CFrame.new())
	local abdomen = part(model, "Abdomen", Vector3.new(2.6, 1.9, 3.2) * s, Color3.fromRGB(24, 20, 22), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	abdomen.CFrame = CFrame.new(0, 0.2 * s, 2.6 * s)
	motor("Tail", thorax, abdomen, CFrame.new(0, 0.1 * s, 1.3 * s), CFrame.new(0, -0.1 * s, -1.3 * s))
	-- the human-ish face on a long neck, hanging towards the front/down
	local neck = part(model, "NeckSeg", Vector3.new(0.5, 0.5, 1.4) * s, skin, Enum.Material.SmoothPlastic)
	neck.CFrame = CFrame.new(0, -0.3 * s, -1.9 * s)
	motor("NeckJoint", thorax, neck, CFrame.new(0, -0.2 * s, -1.2 * s), CFrame.new(0, 0.1 * s, 0.7 * s))
	local head = part(model, "Head", Vector3.new(1.3, 1.5, 1.2) * s, skin, Enum.Material.SmoothPlastic)
	head.CFrame = CFrame.new(0, -0.6 * s, -2.9 * s)
	motor("Neck", neck, head, CFrame.new(0, 0, -0.7 * s), CFrame.new(0, 0.3 * s, 0.5 * s))
	-- face: many eyes + a vertical mouth
	local gui = faceGui(head)
	gui.LightInfluence = 0.4
	for i, spot in ipairs({ { 28, 30, 12 }, { 72, 30, 12 }, { 40, 20, 7 }, { 60, 20, 7 }, { 22, 46, 6 }, { 78, 46, 6 }, { 50, 12, 5 } }) do
		local eye = dot(gui, spot[1], spot[2], spot[3], spot[3], Color3.new(0, 0, 0))
		dot(eye, spot[3] / 2, spot[3] / 2, math.max(2, spot[3] / 3), math.max(2, spot[3] / 3), Color3.fromRGB(255, 250, 230)).Name = "Glint" .. i
	end
	local mouth = dot(gui, 50, 70, 30, 44, Color3.fromRGB(14, 0, 0))
	for i = 1, 5 do
		dot(mouth, 15, 4 + i * 7, 26, 2, Color3.fromRGB(230, 224, 200), false)
	end
	-- mandibles
	for _, side in ipairs({ -1, 1 }) do
		local mandible = part(model, "Mandible", Vector3.new(0.18, 0.9, 0.18) * s, Color3.fromRGB(60, 50, 44), Enum.Material.SmoothPlastic)
		weldDecoration(head, mandible, CFrame.new(side * 0.35 * s, -0.75 * s, -0.4 * s) * CFrame.Angles(math.rad(20), 0, math.rad(side * 15)))
	end
	-- 8 long legs: femur + tibia each, splayed around the thorax
	local angles = { -60, -25, 15, 50 }
	for index = 1, 8 do
		local side = if index <= 4 then -1 else 1
		local slot = ((index - 1) % 4) + 1
		local yaw = math.rad(angles[slot]) * -side
		local femur = part(model, "Leg" .. index, Vector3.new(0.34, 0.34, 3.2) * s, shell, Enum.Material.SmoothPlastic)
		local tibia = part(model, "Shin" .. index, Vector3.new(0.24, 0.24, 3.6) * s, Color3.fromRGB(44, 38, 40), Enum.Material.SmoothPlastic)
		local hip = CFrame.new(side * 1.0 * s, 0.1 * s, (-0.9 + (slot - 1) * 0.6) * s) * CFrame.Angles(0, math.rad(90) * side + yaw, 0) * CFrame.Angles(math.rad(35), 0, 0)
		femur.CFrame = hip * CFrame.new(0, 0, -1.6 * s)
		motor("Hip" .. index, thorax, femur, hip, CFrame.new(0, 0, 1.6 * s))
		local knee = CFrame.new(0, 0, -1.6 * s) * CFrame.Angles(math.rad(-98), 0, 0)
		tibia.CFrame = femur.CFrame * knee * CFrame.new(0, 0, -1.8 * s)
		motor("Knee" .. index, femur, tibia, knee, CFrame.new(0, 0, 1.8 * s))
		local claw = part(model, "Claw", Vector3.new(0.12, 0.12, 0.6) * s, Color3.fromRGB(200, 190, 170), Enum.Material.SmoothPlastic)
		weldDecoration(tibia, claw, CFrame.new(0, 0, -2 * s))
	end
	model.PrimaryPart = root
	model:SetAttribute("Style", "Spider")
	return model
end

return Rig
