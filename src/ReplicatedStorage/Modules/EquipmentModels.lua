--[[
	EquipmentModels (ModuleScript)
	Location: ReplicatedStorage/Modules/EquipmentModels

	THE builder for every piece of hand equipment, used by
	  * EquipmentService      the Tools other players see in your hands
	  * ViewmodelController   your own first-person viewmodel
	so both always match. Built from parts (no uploads needed).

	  EquipmentModels.Build(itemId, skin) -> Model (PrimaryPart "Handle")
	Orientation: device front (lens / beam) = -Z, up = +Y, the Handle part
	is the grip. All parts are welded to Handle, massless, non-colliding.

	Named parts the game uses:
	  Camera      FlashBulb (PointLight "Flash"), RearScreen (SurfaceGui "Display"),
	              ShutterButton, LensBarrel, LensGlass, ZoomRing
	  Flashlight  Lens (neon when on), Handle has SpotLight "Beam", Switch
	  UVLight     same as Flashlight
	  EMF         LED1..LED5, Screen (SurfaceGui "Display")
	  Thermal     Screen (SurfaceGui "Display"), Lens
]]

local EquipmentModels = {}

export type Skin = {
	Body: Color3,
	Accent: Color3,
	Trim: Color3,
	Material: Enum.Material?,
	Lens: Color3?,
}

local DEFAULT_SKINS: { [string]: Skin } = {
	Camera = { Body = Color3.fromRGB(34, 34, 36), Accent = Color3.fromRGB(70, 70, 74), Trim = Color3.fromRGB(150, 150, 156), Material = Enum.Material.SmoothPlastic },
	Flashlight = { Body = Color3.fromRGB(38, 38, 42), Accent = Color3.fromRGB(90, 90, 96), Trim = Color3.fromRGB(160, 160, 166), Material = Enum.Material.Metal },
	UVLight = { Body = Color3.fromRGB(45, 25, 70), Accent = Color3.fromRGB(24, 16, 36), Trim = Color3.fromRGB(150, 90, 230), Material = Enum.Material.Metal, Lens = Color3.fromRGB(170, 90, 255) },
	EMF = { Body = Color3.fromRGB(214, 180, 40), Accent = Color3.fromRGB(28, 28, 30), Trim = Color3.fromRGB(60, 60, 64), Material = Enum.Material.SmoothPlastic },
	Thermal = { Body = Color3.fromRGB(58, 60, 66), Accent = Color3.fromRGB(28, 28, 30), Trim = Color3.fromRGB(230, 120, 40), Material = Enum.Material.SmoothPlastic },
}

local RUBBER = Color3.fromRGB(22, 22, 23)
local GLASS = Color3.fromRGB(30, 44, 64)

local function part(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- cylinder along Z (Roblox cylinders run along X)
local function cylZ(model: Model, name: string, length: number, diameter: number, position: Vector3, color: Color3, material: Enum.Material?): Part
	return part(model, name, Vector3.new(length, diameter, diameter), CFrame.new(position) * CFrame.Angles(0, math.rad(90), 0), color, material, Enum.PartType.Cylinder)
end

local function cylY(model: Model, name: string, length: number, diameter: number, position: Vector3, color: Color3, material: Enum.Material?): Part
	return part(model, name, Vector3.new(length, diameter, diameter), CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), color, material, Enum.PartType.Cylinder)
end

local function display(target: BasePart, face: Enum.NormalId, lines: { { string } }, color: Color3?): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Display"
	gui.Face = face
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 220
	gui.ZOffset = 0.2
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(6, 10, 8)
	background.BorderSizePixel = 0
	background.Parent = gui
	for index, line in ipairs(lines) do
		local label = Instance.new("TextLabel")
		label.Name = line[1]
		label.BackgroundTransparency = 1
		label.Text = line[2]
		label.TextColor3 = color or Color3.fromRGB(150, 230, 170)
		label.FontFace = Font.fromEnum(Enum.Font.Code)
		label.TextScaled = true
		label.TextXAlignment = if line[3] == "Right" then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
		label.Position = UDim2.fromScale(0.06, 0.06 + (index - 1) * (0.88 / #lines))
		label.Size = UDim2.fromScale(0.88, 0.8 / #lines)
		label.Parent = background
	end
	gui.Parent = target
	return gui
end

local function weldTo(model: Model, handle: BasePart)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= handle then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
	model.PrimaryPart = handle
end

---------------------------------------------------------------------------
-- Camera: a mirrorless/DSLR body with lens, hot-shoe flash, rear screen.
---------------------------------------------------------------------------

local function buildCamera(model: Model, skin: Skin): BasePart
	local body, accent, trim = skin.Body, skin.Accent, skin.Trim
	local material = skin.Material or Enum.Material.SmoothPlastic
	-- the handle is the right-hand grip
	local handle = part(model, "Handle", Vector3.new(0.34, 0.74, 0.5), CFrame.new(0.52, -0.02, 0), RUBBER, Enum.Material.Fabric)
	part(model, "Body", Vector3.new(1.3, 0.78, 0.42), CFrame.new(0, 0, 0.02), body, material)
	part(model, "TopPlate", Vector3.new(1.18, 0.1, 0.4), CFrame.new(-0.02, 0.43, 0.02), accent, material)
	part(model, "ViewfinderHump", Vector3.new(0.42, 0.24, 0.38), CFrame.new(-0.05, 0.56, 0.04), body, material)
	part(model, "Eyecup", Vector3.new(0.3, 0.2, 0.1), CFrame.new(-0.05, 0.56, 0.27), RUBBER, Enum.Material.Fabric)
	-- lens: mount ring, barrel, zoom ring, focus ring, hood, glass
	cylZ(model, "LensMount", 0.08, 0.6, Vector3.new(-0.08, -0.02, -0.23), trim, Enum.Material.Metal)
	cylZ(model, "LensBarrel", 0.62, 0.54, Vector3.new(-0.08, -0.02, -0.56), accent, Enum.Material.SmoothPlastic)
	cylZ(model, "ZoomRing", 0.2, 0.58, Vector3.new(-0.08, -0.02, -0.48), RUBBER, Enum.Material.Fabric)
	cylZ(model, "FocusRing", 0.1, 0.57, Vector3.new(-0.08, -0.02, -0.74), RUBBER, Enum.Material.Fabric)
	cylZ(model, "RedRing", 0.02, 0.555, Vector3.new(-0.08, -0.02, -0.34), Color3.fromRGB(190, 30, 30), Enum.Material.SmoothPlastic)
	cylZ(model, "LensHood", 0.14, 0.62, Vector3.new(-0.08, -0.02, -0.92), RUBBER, Enum.Material.SmoothPlastic)
	local glass = cylZ(model, "LensGlass", 0.02, 0.44, Vector3.new(-0.08, -0.02, -0.9), GLASS, Enum.Material.Glass)
	glass.Reflectance = 0.35
	-- controls
	cylY(model, "ShutterButton", 0.06, 0.13, Vector3.new(0.5, 0.49, -0.06), trim, Enum.Material.Metal).Color = Color3.fromRGB(190, 30, 30)
	cylY(model, "ModeDial", 0.09, 0.26, Vector3.new(-0.42, 0.52, 0.02), accent, Enum.Material.Metal)
	cylY(model, "CommandDial", 0.05, 0.2, Vector3.new(0.28, 0.5, 0.02), trim, Enum.Material.Metal)
	for i, x in ipairs({ 0.45, 0.45, 0.45 }) do
		cylZ(model, "Button" .. i, 0.03, 0.07, Vector3.new(x, 0.18 - (i - 1) * 0.12, 0.25), trim, Enum.Material.Metal)
	end
	part(model, "StrapLugL", Vector3.new(0.06, 0.1, 0.08), CFrame.new(-0.67, 0.3, 0.04), trim, Enum.Material.Metal)
	part(model, "StrapLugR", Vector3.new(0.06, 0.1, 0.08), CFrame.new(0.69, 0.3, 0.04), trim, Enum.Material.Metal)
	-- hot-shoe flash
	part(model, "FlashFoot", Vector3.new(0.3, 0.06, 0.26), CFrame.new(-0.05, 0.71, 0.04), trim, Enum.Material.Metal)
	part(model, "FlashBody", Vector3.new(0.4, 0.34, 0.3), CFrame.new(-0.05, 0.9, 0.04), body, material)
	part(model, "FlashHead", Vector3.new(0.46, 0.22, 0.34), CFrame.new(-0.05, 1.16, 0.0), body, material)
	local bulb = part(model, "FlashBulb", Vector3.new(0.4, 0.16, 0.03), CFrame.new(-0.05, 1.16, -0.18), Color3.fromRGB(235, 238, 245), Enum.Material.Glass)
	bulb.Transparency = 0.1
	local flash = Instance.new("PointLight")
	flash.Name = "Flash"
	flash.Enabled = false
	flash.Brightness = 8
	flash.Range = 22
	flash.Color = Color3.fromRGB(235, 240, 255)
	flash.Shadows = false
	flash.Parent = bulb
	part(model, "FlashReady", Vector3.new(0.05, 0.05, 0.02), CFrame.new(0.1, 0.9, 0.2), Color3.fromRGB(255, 60, 40), Enum.Material.Neon)
	-- rear screen (the viewmodel shows zoom / battery / focus / REC / interference)
	local screen = part(model, "RearScreen", Vector3.new(0.7, 0.46, 0.02), CFrame.new(-0.12, 0.02, 0.245), Color3.fromRGB(6, 10, 8), Enum.Material.Glass)
	display(screen, Enum.NormalId.Back, {
		{ "Top", "● REC   AF" },
		{ "Zoom", "x1.0" },
		{ "Battery", "BAT 100%" },
		{ "Status", "" },
	})
	return handle
end

---------------------------------------------------------------------------
-- Flashlight / UV light: machined tube, bezel, knurled grip, tail switch.
---------------------------------------------------------------------------

local function buildTorch(model: Model, skin: Skin, lightColor: Color3): BasePart
	local body, accent, trim = skin.Body, skin.Accent, skin.Trim
	local material = skin.Material or Enum.Material.Metal
	local handle = cylZ(model, "Handle", 1.2, 0.36, Vector3.new(0, 0, 0.1), body, material)
	for i = 0, 4 do
		cylZ(model, "Knurl", 0.06, 0.39, Vector3.new(0, 0, 0.42 - i * 0.14), accent, Enum.Material.DiamondPlate)
	end
	cylZ(model, "Neck", 0.3, 0.44, Vector3.new(0, 0, -0.62), body, material)
	cylZ(model, "Head", 0.34, 0.6, Vector3.new(0, 0, -0.9), body, material)
	cylZ(model, "Bezel", 0.08, 0.64, Vector3.new(0, 0, -1.08), trim, Enum.Material.Metal)
	local reflector = cylZ(model, "Reflector", 0.02, 0.5, Vector3.new(0, 0, -1.1), Color3.fromRGB(200, 200, 205), Enum.Material.Foil)
	reflector.Reflectance = 0.5
	local lens = cylZ(model, "Lens", 0.03, 0.48, Vector3.new(0, 0, -1.12), Color3.fromRGB(70, 70, 75), Enum.Material.Glass)
	lens:SetAttribute("OnColor", skin.Lens or lightColor)
	cylZ(model, "TailCap", 0.14, 0.4, Vector3.new(0, 0, 0.76), accent, material)
	part(model, "Switch", Vector3.new(0.12, 0.08, 0.18), CFrame.new(0, 0.2, -0.3), RUBBER, Enum.Material.Fabric)
	part(model, "Clip", Vector3.new(0.05, 0.03, 0.6), CFrame.new(0, 0.19, 0.3), trim, Enum.Material.Metal)
	-- the lens cylinder is rotated, so the beam lives on a tiny unrotated part facing -Z
	local emitter = part(model, "BeamEmitter", Vector3.new(0.05, 0.05, 0.05), CFrame.new(0, 0, -1.13), lightColor, Enum.Material.SmoothPlastic)
	emitter.Transparency = 1
	local beam = Instance.new("SpotLight")
	beam.Name = "Beam"
	beam.Face = Enum.NormalId.Front
	beam.Enabled = false
	beam.Brightness = 2.4
	beam.Range = 52
	beam.Angle = 50
	beam.Color = lightColor
	beam.Shadows = true
	beam.Parent = emitter
	return handle
end

---------------------------------------------------------------------------
-- EMF meter: K-II style body, 5 LEDs, sensor head, LCD.
---------------------------------------------------------------------------

local LED_COLORS = {
	Color3.fromRGB(80, 255, 90),
	Color3.fromRGB(170, 255, 70),
	Color3.fromRGB(255, 230, 60),
	Color3.fromRGB(255, 150, 40),
	Color3.fromRGB(255, 50, 40),
}

local function buildEMF(model: Model, skin: Skin): BasePart
	local body, accent, trim = skin.Body, skin.Accent, skin.Trim
	local material = skin.Material or Enum.Material.SmoothPlastic
	local handle = part(model, "Handle", Vector3.new(0.5, 0.9, 0.3), CFrame.new(0, -0.1, 0), body, material)
	part(model, "Head", Vector3.new(0.56, 0.5, 0.32), CFrame.new(0, 0.58, -0.01), body, material)
	part(model, "Faceplate", Vector3.new(0.48, 0.42, 0.02), CFrame.new(0, 0.58, -0.17), accent, Enum.Material.SmoothPlastic)
	for index = 1, 5 do
		local led = part(model, "LED" .. index, Vector3.new(0.07, 0.07, 0.04), CFrame.new(-0.18 + (index - 1) * 0.09, 0.74, -0.19), Color3.fromRGB(40, 40, 40), Enum.Material.SmoothPlastic)
		led:SetAttribute("OnColor", LED_COLORS[index])
	end
	local screen = part(model, "Screen", Vector3.new(0.4, 0.16, 0.02), CFrame.new(0, 0.52, -0.185), Color3.fromRGB(6, 10, 8), Enum.Material.Glass)
	display(screen, Enum.NormalId.Front, { { "Reading", "0.0 mG" } }, Color3.fromRGB(255, 200, 80))
	part(model, "Sensor", Vector3.new(0.3, 0.12, 0.28), CFrame.new(0, 0.9, -0.01), trim, Enum.Material.SmoothPlastic)
	part(model, "Button", Vector3.new(0.14, 0.14, 0.04), CFrame.new(0, 0.12, -0.17), Color3.fromRGB(190, 30, 30), Enum.Material.SmoothPlastic)
	part(model, "Grip", Vector3.new(0.52, 0.5, 0.26), CFrame.new(0, -0.22, 0.03), RUBBER, Enum.Material.Fabric)
	return handle
end

---------------------------------------------------------------------------
-- Thermal scanner: pistol grip, screen facing the user, germanium lens.
---------------------------------------------------------------------------

local function buildThermal(model: Model, skin: Skin): BasePart
	local body, accent, trim = skin.Body, skin.Accent, skin.Trim
	local material = skin.Material or Enum.Material.SmoothPlastic
	local handle = part(model, "Handle", Vector3.new(0.3, 0.62, 0.36), CFrame.new(0, -0.5, 0.06) * CFrame.Angles(math.rad(-12), 0, 0), RUBBER, Enum.Material.Fabric)
	part(model, "Body", Vector3.new(0.78, 0.6, 0.62), CFrame.new(0, 0, 0), body, material)
	local screen = part(model, "Screen", Vector3.new(0.62, 0.44, 0.02), CFrame.new(0, 0.04, 0.32), Color3.fromRGB(10, 6, 4), Enum.Material.Glass)
	display(screen, Enum.NormalId.Back, { { "Temp", "21.4°C" }, { "Mode", "SCAN" } }, Color3.fromRGB(255, 150, 60))
	cylZ(model, "LensHousing", 0.22, 0.4, Vector3.new(0, 0.04, -0.4), accent, Enum.Material.Metal)
	cylZ(model, "Lens", 0.02, 0.32, Vector3.new(0, 0.04, -0.52), Color3.fromRGB(40, 30, 50), Enum.Material.Glass).Reflectance = 0.4
	part(model, "Trigger", Vector3.new(0.08, 0.16, 0.1), CFrame.new(0, -0.3, -0.12), trim, Enum.Material.SmoothPlastic)
	return handle
end

local BUILDERS = {
	Camera = buildCamera,
	Flashlight = function(model: Model, skin: Skin)
		return buildTorch(model, skin, Color3.fromRGB(255, 240, 214))
	end,
	UVLight = function(model: Model, skin: Skin)
		return buildTorch(model, skin, Color3.fromRGB(150, 70, 255))
	end,
	EMF = buildEMF,
	Thermal = buildThermal,
}

function EquipmentModels.DefaultSkin(itemId: string): Skin
	return DEFAULT_SKINS[itemId] or DEFAULT_SKINS.Camera
end

function EquipmentModels.Has(itemId: string): boolean
	return BUILDERS[itemId] ~= nil
end

-- Builds the model at the origin. Parent it yourself.
function EquipmentModels.Build(itemId: string, skin: Skin?): Model?
	local builder = BUILDERS[itemId]
	if not builder then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = itemId
	local handle = builder(model, skin or EquipmentModels.DefaultSkin(itemId))
	weldTo(model, handle)
	return model
end

return EquipmentModels
