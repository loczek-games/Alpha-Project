--[[
	Build (ModuleScript)
	Location: ServerScriptService/World/Build

	Tiny construction toolkit shared by every world builder (Dead Mall,
	Lobby HQ). It only uses plain Instance APIs, so the same code runs inside
	Roblox (runtime build) and in Lune (tools/bake/bake.luau bakes the map
	into the place file).

	A Frame is a local coordinate system + a parent:
	    local f = Build.frame(parentModel, CFrame.new(10, 0, 20))
	    f:box("Counter", Vector3.new(8, 3.5, 2), Vector3.new(0, 1.75, 0), C.Wood, M.WoodPlanks)
	    local shelf = f:at(4, 0, 0, 90)        -- moved + rotated sub-frame
	Positions are part CENTRES in frame space (Vector3 or CFrame).
]]

local Build = {}

Build.M = Enum.Material

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end
Build.rgb = rgb

-- A grimy, desaturated palette with a few neon accents.
Build.C = {
	Black = rgb(12, 12, 14),
	Void = rgb(4, 4, 6),
	Charcoal = rgb(34, 34, 38),
	Asphalt = rgb(48, 48, 52),
	DarkGray = rgb(62, 63, 66),
	Gray = rgb(98, 98, 100),
	MidGray = rgb(128, 128, 126),
	LightGray = rgb(168, 167, 162),
	OffWhite = rgb(206, 202, 192),
	Paper = rgb(222, 216, 198),
	Cream = rgb(196, 186, 160),
	Beige = rgb(170, 156, 128),
	Tan = rgb(150, 124, 92),
	Cardboard = rgb(156, 118, 76),
	WoodLight = rgb(160, 122, 84),
	Wood = rgb(118, 84, 56),
	WoodDark = rgb(72, 50, 36),
	Steel = rgb(120, 124, 130),
	Chrome = rgb(176, 180, 186),
	Rust = rgb(118, 64, 40),
	Red = rgb(150, 34, 34),
	DarkRed = rgb(88, 20, 22),
	Blood = rgb(96, 10, 12),
	Orange = rgb(196, 102, 36),
	Yellow = rgb(214, 176, 56),
	Mustard = rgb(170, 138, 48),
	Green = rgb(58, 102, 64),
	DarkGreen = rgb(34, 60, 40),
	Plant = rgb(52, 82, 46),
	DeadPlant = rgb(96, 84, 52),
	Teal = rgb(44, 110, 112),
	Blue = rgb(46, 74, 128),
	Navy = rgb(26, 34, 62),
	Purple = rgb(84, 48, 112),
	Pink = rgb(196, 116, 150),
	Skin = rgb(214, 196, 176),
	Mannequin = rgb(222, 214, 200),
	Glass = rgb(170, 196, 206),
	Water = rgb(40, 56, 66),
	NeonRed = rgb(255, 40, 50),
	NeonPink = rgb(255, 70, 170),
	NeonBlue = rgb(60, 140, 255),
	NeonCyan = rgb(40, 230, 240),
	NeonGreen = rgb(60, 255, 110),
	NeonYellow = rgb(255, 220, 70),
	NeonOrange = rgb(255, 140, 40),
	NeonPurple = rgb(170, 70, 255),
	WarmLight = rgb(255, 214, 160),
	ColdLight = rgb(210, 230, 255),
	SickLight = rgb(200, 236, 190),
	EmergencyRed = rgb(255, 50, 40),
	ExitGreen = rgb(40, 255, 120),
}

function Build.shade(color: Color3, amount: number): Color3
	if amount >= 0 then
		return color:Lerp(Color3.new(1, 1, 1), amount)
	end
	return color:Lerp(Color3.new(0, 0, 0), -amount)
end

function Build.vary(rng: any, color: Color3, amount: number): Color3
	return Build.shade(color, (rng:Next() * 2 - 1) * amount)
end

-- CFrame.lookAt equivalent (built from fromMatrix, identical in Roblox and Lune).
function Build.lookAt(position: Vector3, target: Vector3): CFrame
	local look = target - position
	if look.Magnitude < 1e-4 then
		return CFrame.new(position)
	end
	look = look.Unit
	local worldUp = Vector3.new(0, 1, 0)
	if math.abs(look:Dot(worldUp)) > 0.999 then
		worldUp = Vector3.new(0, 0, 1)
	end
	local right = look:Cross(worldUp).Unit
	local up = right:Cross(look)
	return CFrame.fromMatrix(position, right, up, -look)
end

function Build.yaw(degrees: number): CFrame
	return CFrame.Angles(0, math.rad(degrees), 0)
end

function Build.tag(instance: Instance, ...: string)
	for _, tag in ipairs({ ... }) do
		instance:AddTag(tag)
	end
	return instance
end

function Build.attrs(instance: Instance, attributes: { [string]: any })
	for key, value in pairs(attributes) do
		instance:SetAttribute(key, value)
	end
	return instance
end

---------------------------------------------------------------------------
-- Parts
---------------------------------------------------------------------------

export type Opts = {
	deco: boolean?, -- small decoration: no collision, no shadow, not touchable
	collide: boolean?,
	shadow: boolean?,
	query: boolean?,
	t: number?, -- transparency
	refl: number?, -- reflectance
	tags: { string }?,
	attrs: { [string]: any }?,
	shape: string?, -- "Cylinder" | "Ball"
	class: string?, -- "Part" (default) | "WedgePart" | "CornerWedgePart"
}

local function applyOpts(part: BasePart, opts: Opts?)
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if not opts then
		return
	end
	if opts.deco then
		part.CanCollide = false
		part.CanTouch = false
		part.CastShadow = false
	end
	if opts.collide ~= nil then
		part.CanCollide = opts.collide
	end
	if opts.shadow ~= nil then
		part.CastShadow = opts.shadow
	end
	if opts.query ~= nil then
		part.CanQuery = opts.query
	end
	if opts.t then
		part.Transparency = opts.t
	end
	if opts.refl then
		part.Reflectance = opts.refl
	end
	if opts.tags then
		for _, tag in ipairs(opts.tags) do
			part:AddTag(tag)
		end
	end
	if opts.attrs then
		for key, value in pairs(opts.attrs) do
			part:SetAttribute(key, value)
		end
	end
end

function Build.part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, opts: Opts?): BasePart
	local className = opts and opts.class or "Part"
	local part = Instance.new(className) :: any
	part.Name = name
	if opts and opts.shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	elseif opts and opts.shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	end
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	applyOpts(part, opts)
	part.Parent = parent
	return part
end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------

local Frame = {}
Frame.__index = Frame

export type Frame = typeof(setmetatable({} :: { Parent: Instance, CF: CFrame, Defaults: Opts? }, Frame))

function Build.frame(parent: Instance, cframe: CFrame?, defaults: Opts?): Frame
	return setmetatable({ Parent = parent, CF = cframe or CFrame.new(), Defaults = defaults }, Frame)
end

local function merge(a: Opts?, b: Opts?): Opts?
	if not a then
		return b
	end
	if not b then
		return a
	end
	local result = table.clone(a) :: any
	for key, value in pairs(b :: any) do
		result[key] = value
	end
	return result
end

-- local position/CFrame -> world CFrame
function Frame.cf(self: Frame, where: any): CFrame
	if typeof(where) == "Vector3" then
		return self.CF * CFrame.new(where)
	end
	return self.CF * where
end

function Frame.point(self: Frame, where: Vector3): Vector3
	return self.CF * where
end

-- sub-frame moved by (x, y, z) and rotated by yaw degrees
function Frame.at(self: Frame, x: number, y: number?, z: number?, yawDegrees: number?): Frame
	local cf = self.CF * CFrame.new(x, y or 0, z or 0)
	if yawDegrees and yawDegrees ~= 0 then
		cf *= CFrame.Angles(0, math.rad(yawDegrees), 0)
	end
	return setmetatable({ Parent = self.Parent, CF = cf, Defaults = self.Defaults }, Frame)
end

function Frame.rel(self: Frame, cframe: CFrame): Frame
	return setmetatable({ Parent = self.Parent, CF = self.CF * cframe, Defaults = self.Defaults }, Frame)
end

function Frame.with(self: Frame, defaults: Opts): Frame
	return setmetatable({ Parent = self.Parent, CF = self.CF, Defaults = merge(self.Defaults, defaults) }, Frame)
end

function Frame.into(self: Frame, parent: Instance): Frame
	return setmetatable({ Parent = parent, CF = self.CF, Defaults = self.Defaults }, Frame)
end

-- new Model under the current parent; returned frame builds into it
function Frame.model(self: Frame, name: string): Frame
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = self.Parent
	return setmetatable({ Parent = model, CF = self.CF, Defaults = self.Defaults }, Frame)
end

function Frame.folder(self: Frame, name: string): Frame
	local existing = self.Parent:FindFirstChild(name)
	local folder = existing
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = self.Parent
	end
	return setmetatable({ Parent = folder :: Instance, CF = self.CF, Defaults = self.Defaults }, Frame)
end

function Frame.box(self: Frame, name: string, size: Vector3, where: any, color: Color3, material: Enum.Material?, opts: Opts?): BasePart
	return Build.part(self.Parent, name, size, self:cf(where), color, material, merge(self.Defaults, opts))
end

-- wedge: slope rises towards local -Z (Roblox WedgePart convention: high side at back)
function Frame.wedge(self: Frame, name: string, size: Vector3, where: any, color: Color3, material: Enum.Material?, opts: Opts?): BasePart
	return Build.part(self.Parent, name, size, self:cf(where), color, material, merge(merge(self.Defaults, opts), { class = "WedgePart" }))
end

-- cylinder along the frame's local X axis
function Frame.cyl(self: Frame, name: string, length: number, diameter: number, where: any, color: Color3, material: Enum.Material?, opts: Opts?): BasePart
	return Build.part(self.Parent, name, Vector3.new(length, diameter, diameter), self:cf(where), color, material, merge(merge(self.Defaults, opts), { shape = "Cylinder" }))
end

-- vertical cylinder centred at `center`
function Frame.cylY(self: Frame, name: string, height: number, diameter: number, center: Vector3, color: Color3, material: Enum.Material?, opts: Opts?): BasePart
	local cf = self:cf(center) * CFrame.Angles(0, 0, math.pi / 2)
	return Build.part(self.Parent, name, Vector3.new(height, diameter, diameter), cf, color, material, merge(merge(self.Defaults, opts), { shape = "Cylinder" }))
end

-- cylinder along local Z
function Frame.cylZ(self: Frame, name: string, length: number, diameter: number, center: Vector3, color: Color3, material: Enum.Material?, opts: Opts?): BasePart
	local cf = self:cf(center) * CFrame.Angles(0, math.pi / 2, 0)
	return Build.part(self.Parent, name, Vector3.new(length, diameter, diameter), cf, color, material, merge(merge(self.Defaults, opts), { shape = "Cylinder" }))
end

function Frame.ball(self: Frame, name: string, diameter: number, center: any, color: Color3, material: Enum.Material?, opts: Opts?): BasePart
	return Build.part(self.Parent, name, Vector3.new(diameter, diameter, diameter), self:cf(center), color, material, merge(merge(self.Defaults, opts), { shape = "Ball" }))
end

-- a beam/rod between two local points (square section)
function Frame.rod(self: Frame, name: string, a: Vector3, b: Vector3, thickness: number, color: Color3, material: Enum.Material?, opts: Opts?): BasePart
	local wa, wb = self:point(a), self:point(b)
	local length = (wb - wa).Magnitude
	local cf = Build.lookAt((wa + wb) / 2, wb)
	return Build.part(self.Parent, name, Vector3.new(thickness, thickness, length), cf, color, material, merge(self.Defaults, opts))
end

---------------------------------------------------------------------------
-- Architecture helpers (axis aligned, in frame space)
---------------------------------------------------------------------------

export type Opening = { Center: number, Width: number, Top: number?, Bottom: number? }

-- Wall running along X from x0 to x1 at z, from y=0 to height, with openings.
function Frame.wallX(self: Frame, name: string, x0: number, x1: number, z: number, height: number, thickness: number, color: Color3, material: Enum.Material?, openings: { Opening }?, opts: Opts?)
	local cuts = table.clone(openings or {})
	table.sort(cuts, function(a, b)
		return a.Center < b.Center
	end)
	local cursor = x0
	local function segment(from: number, to: number, bottom: number, top: number)
		if to - from > 0.05 and top - bottom > 0.05 then
			self:box(name, Vector3.new(to - from, top - bottom, thickness), Vector3.new((from + to) / 2, (bottom + top) / 2, z), color, material, opts)
		end
	end
	for _, cut in ipairs(cuts) do
		local left, right = cut.Center - cut.Width / 2, cut.Center + cut.Width / 2
		segment(cursor, left, 0, height)
		segment(left, right, cut.Top or height, height)
		if cut.Bottom and cut.Bottom > 0 then
			segment(left, right, 0, cut.Bottom)
		end
		cursor = right
	end
	segment(cursor, x1, 0, height)
end

-- Wall running along Z from z0 to z1 at x.
function Frame.wallZ(self: Frame, name: string, z0: number, z1: number, x: number, height: number, thickness: number, color: Color3, material: Enum.Material?, openings: { Opening }?, opts: Opts?)
	local cuts = table.clone(openings or {})
	table.sort(cuts, function(a, b)
		return a.Center < b.Center
	end)
	local cursor = z0
	local function segment(from: number, to: number, bottom: number, top: number)
		if to - from > 0.05 and top - bottom > 0.05 then
			self:box(name, Vector3.new(thickness, top - bottom, to - from), Vector3.new(x, (bottom + top) / 2, (from + to) / 2), color, material, opts)
		end
	end
	for _, cut in ipairs(cuts) do
		local left, right = cut.Center - cut.Width / 2, cut.Center + cut.Width / 2
		segment(cursor, left, 0, height)
		segment(left, right, cut.Top or height, height)
		if cut.Bottom and cut.Bottom > 0 then
			segment(left, right, 0, cut.Bottom)
		end
		cursor = right
	end
	segment(cursor, z1, 0, height)
end

-- Horizontal slab with its TOP at y (floors) or BOTTOM at y (ceilings, when below = false).
function Frame.slab(self: Frame, name: string, x0: number, x1: number, z0: number, z1: number, y: number, thickness: number, color: Color3, material: Enum.Material?, opts: Opts?, isCeiling: boolean?): BasePart
	local centerY = if isCeiling then y + thickness / 2 else y - thickness / 2
	return self:box(name, Vector3.new(x1 - x0, thickness, z1 - z0), Vector3.new((x0 + x1) / 2, centerY, (z0 + z1) / 2), color, material, opts)
end

---------------------------------------------------------------------------
-- Lights
---------------------------------------------------------------------------

function Build.point(part: Instance, color: Color3, brightness: number, range: number, shadows: boolean?): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = shadows == true
	light.Parent = part
	return light
end

function Build.spot(part: Instance, face: Enum.NormalId, color: Color3, brightness: number, range: number, angle: number, shadows: boolean?): SpotLight
	local light = Instance.new("SpotLight")
	light.Face = face
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Angle = angle
	light.Shadows = shadows == true
	light.Parent = part
	return light
end

function Build.surfaceLight(part: Instance, face: Enum.NormalId, color: Color3, brightness: number, range: number, angle: number?, shadows: boolean?): SurfaceLight
	local light = Instance.new("SurfaceLight")
	light.Face = face
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Angle = angle or 120
	light.Shadows = shadows == true
	light.Parent = part
	return light
end

---------------------------------------------------------------------------
-- Surface text (signs, menus, posters)
---------------------------------------------------------------------------

export type TextStyle = {
	Font: Enum.Font?,
	Color: Color3?,
	Background: Color3?,
	BackgroundTransparency: number?,
	Glow: boolean?, -- lit sign (ignores scene lighting)
	Stroke: number?, -- text stroke transparency
	StrokeColor: Color3?,
	PixelsPerStud: number?,
	Rotation: number?,
	Align: string?, -- "Left" | "Right" | "Center"
}

function Build.surfaceGui(part: Instance, face: Enum.NormalId, glow: boolean?, pixelsPerStud: number?): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Surface"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 40
	gui.LightInfluence = if glow then 0 else 1
	gui.Brightness = if glow then 1.6 else 1
	gui.MaxDistance = 140
	gui.ClipsDescendants = true
	gui.Parent = part
	return gui
end

-- Full-surface text. Returns the TextLabel.
function Build.text(part: Instance, face: Enum.NormalId, text: string, style: TextStyle?): TextLabel
	local s: TextStyle = style or {}
	local gui = Build.surfaceGui(part, face, s.Glow, s.PixelsPerStud)
	if s.Background then
		local bg = Instance.new("Frame")
		bg.Name = "Background"
		bg.Size = UDim2.fromScale(1, 1)
		bg.BorderSizePixel = 0
		bg.BackgroundColor3 = s.Background
		bg.BackgroundTransparency = s.BackgroundTransparency or 0
		bg.Parent = gui
	end
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.92, 0.86)
	label.Position = UDim2.fromScale(0.04, 0.07)
	label.Text = text
	label.TextScaled = true
	label.TextWrapped = true
	label.FontFace = Font.fromEnum(s.Font or Enum.Font.GothamBold)
	label.TextColor3 = s.Color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = s.Stroke or 1
	label.TextStrokeColor3 = s.StrokeColor or Color3.new(0, 0, 0)
	label.Rotation = s.Rotation or 0
	if s.Align == "Left" then
		label.TextXAlignment = Enum.TextXAlignment.Left
	elseif s.Align == "Right" then
		label.TextXAlignment = Enum.TextXAlignment.Right
	end
	label.Parent = gui
	return label
end

-- A laid-out surface: list of { Text, Y (0-1 top), H (0-1 height), Color, Font, X?, W?, Align?, Bg? }
function Build.layout(part: Instance, face: Enum.NormalId, background: Color3?, items: { any }, glow: boolean?, pixelsPerStud: number?): SurfaceGui
	local gui = Build.surfaceGui(part, face, glow, pixelsPerStud)
	if background then
		local bg = Instance.new("Frame")
		bg.Name = "Background"
		bg.Size = UDim2.fromScale(1, 1)
		bg.BorderSizePixel = 0
		bg.BackgroundColor3 = background
		bg.Parent = gui
	end
	for index, item in ipairs(items) do
		if item.Bg then
			local block = Instance.new("Frame")
			block.Name = "Block" .. index
			block.BorderSizePixel = 0
			block.BackgroundColor3 = item.Bg
			block.BackgroundTransparency = item.BgT or 0
			block.Position = UDim2.fromScale(item.X or 0, item.Y or 0)
			block.Size = UDim2.fromScale(item.W or 1, item.H or 0.1)
			block.Rotation = item.Rot or 0
			block.Parent = gui
		end
		if item.Text then
			local label = Instance.new("TextLabel")
			label.Name = "Line" .. index
			label.BackgroundTransparency = 1
			label.Position = UDim2.fromScale((item.X or 0) + 0.03, item.Y or 0)
			label.Size = UDim2.fromScale((item.W or 1) - 0.06, item.H or 0.1)
			label.Text = item.Text
			label.TextScaled = true
			label.TextWrapped = true
			label.FontFace = Font.fromEnum(item.Font or Enum.Font.GothamBold)
			label.TextColor3 = item.Color or Color3.new(1, 1, 1)
			label.Rotation = item.Rot or 0
			if item.Align == "Left" then
				label.TextXAlignment = Enum.TextXAlignment.Left
			elseif item.Align == "Right" then
				label.TextXAlignment = Enum.TextXAlignment.Right
			end
			label.Parent = gui
		end
	end
	return gui
end

return Build
