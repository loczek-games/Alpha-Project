--[[
	MapService (ModuleScript)
	Location: ServerScriptService/Services/MapService

	Builds the DEAD MALL, the Lobby and the Dark Room from code when
	Workspace.Map.DeadMall / Workspace.Lobby are empty, so the game is playable
	from an empty Baseplate. If you build your own map in Studio, keep the same
	folder names, CollectionService tags and attributes and this service will
	simply index it instead of building.

	Tags used by gameplay
	  MallLight         light panel (child PointLight), attribute Zone
	  FlickerLight      light that flickers on its own
	  MallClock         clock model (Face, HourPivot, MinutePivot)
	  MallPainting      painting model (Canvas part with SurfaceGui Canvas/Figure)
	  MallMirror        mirror model (Glass part, LookVector = into the room)
	  ExitSign          exit sign model (Sign part with SurfaceGui SignGui/Text/Arrow)
	  ArcadeCabinet     arcade machine (Screen part with SurfaceGui Display/Text)
	  DarkRoomFrame     frame canvas in the Dark Room, attribute Index
	  DarkRoomNameplate nameplate part in the Dark Room
	  DarkRoomEntrance  part with a ProximityPrompt in the Lobby
	  DarkRoomExit      part with a ProximityPrompt in the Dark Room
	Folders
	  Workspace.AnomalySpawns : marker parts with attributes Kind + Zone
	  Workspace.Map.DeadMall.Zones : zone bounds parts (Name = zone id)
	  Workspace.Map.DeadMall.PlayerSpawns / NPCWaypoints
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))

local MapService = {}
MapService.Folders = {}
MapService.Blackout = false
MapService.LightRecords = {}
MapService.Tints = {}

local WALL_T = 2
local WALL_H = 32
local EXTERIOR = Color3.fromRGB(70, 70, 74)

local ZONES = {
	MainHall = { X = { -30, 30 }, Z = { -120, 120 }, H = 30, Floor = Color3.fromRGB(206, 200, 188), FloorMat = Enum.Material.Marble, Wall = Color3.fromRGB(196, 188, 174), Ceiling = Color3.fromRGB(150, 148, 145) },
	Arcade = { X = { -100, -30 }, Z = { -120, -50 }, H = 20, Floor = Color3.fromRGB(45, 25, 70), FloorMat = Enum.Material.Fabric, Wall = Color3.fromRGB(40, 32, 58), Ceiling = Color3.fromRGB(25, 22, 35) },
	FoodCourt = { X = { -100, -30 }, Z = { -50, 40 }, H = 24, Floor = Color3.fromRGB(200, 188, 160), FloorMat = Enum.Material.SmoothPlastic, Wall = Color3.fromRGB(205, 150, 100), Ceiling = Color3.fromRGB(150, 140, 130) },
	Bathrooms = { X = { -100, -30 }, Z = { 40, 120 }, H = 18, Floor = Color3.fromRGB(215, 222, 222), FloorMat = Enum.Material.Marble, Wall = Color3.fromRGB(160, 195, 195), Ceiling = Color3.fromRGB(170, 175, 175) },
	ToyStore = { X = { 30, 100 }, Z = { -120, -60 }, H = 20, Floor = Color3.fromRGB(140, 185, 220), FloorMat = Enum.Material.SmoothPlastic, Wall = Color3.fromRGB(225, 205, 115), Ceiling = Color3.fromRGB(180, 170, 140) },
	Cinema = { X = { 30, 100 }, Z = { -60, 30 }, H = 26, Floor = Color3.fromRGB(95, 22, 30), FloorMat = Enum.Material.Fabric, Wall = Color3.fromRGB(55, 20, 28), Ceiling = Color3.fromRGB(30, 15, 18) },
	StorageHallway = { X = { 30, 160 }, Z = { 84, 100 }, H = 14, Floor = Color3.fromRGB(120, 120, 115), FloorMat = Enum.Material.Concrete, Wall = Color3.fromRGB(135, 135, 128), Ceiling = Color3.fromRGB(100, 100, 95) },
	ParkingGarage = { X = { 160, 260 }, Z = { 30, 150 }, H = 16, Floor = Color3.fromRGB(72, 72, 76), FloorMat = Enum.Material.Concrete, Wall = Color3.fromRGB(110, 110, 110), Ceiling = Color3.fromRGB(90, 90, 90) },
}

local LOBBY_CENTER = Vector3.new(-300, 0, 0)
local DARKROOM_CENTER = Vector3.new(-300, 0, -120)

---------------------------------------------------------------------------
-- Construction helpers
---------------------------------------------------------------------------

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, props: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for key, value in pairs(props) do
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end

local function decor(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, collide: boolean?): Part
	return part(parent, name, size, cframe, color, material, { CanCollide = collide ~= false, CastShadow = false })
end

local function cylinderUp(parent: Instance, name: string, height: number, diameter: number, position: Vector3, color: Color3, material: Enum.Material?): Part
	return part(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), color, material, { Shape = Enum.PartType.Cylinder, CastShadow = false })
end

local function folder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function faced(position: Vector3, normal: Vector3): CFrame
	return CFrame.lookAt(position, position + normal)
end

local function surfaceText(target: BasePart, text: string, textColor: Color3, font: Enum.Font, face: Enum.NormalId?, lightInfluence: number?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = lightInfluence or 0.2
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = textColor
	label.Font = font
	label.TextScaled = true
	label.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.PaddingTop = UDim.new(0.08, 0)
	padding.PaddingBottom = UDim.new(0.08, 0)
	padding.Parent = label
	return label
end

local function sign(parent: Instance, name: string, position: Vector3, normal: Vector3, size: Vector2, text: string, background: Color3, textColor: Color3, font: Enum.Font?): Part
	local p = part(parent, name, Vector3.new(size.X, size.Y, 0.3), faced(position, normal), background, Enum.Material.SmoothPlastic, { CanCollide = false, CastShadow = false })
	surfaceText(p, text, textColor, font or Enum.Font.GothamBlack)
	return p
end

type Opening = { Center: number, Width: number, Bottom: number?, Top: number }

-- Builds a two-layer wall so each side can have its own room colour.
local function wallSegment(parent: Instance, alongX: boolean, fixed: number, from: number, to: number, y0: number, y1: number, colorNeg: Color3, colorPos: Color3, material: Enum.Material?)
	local length = to - from
	local height = y1 - y0
	if length <= 0.05 or height <= 0.05 then
		return
	end
	local mid = (from + to) / 2
	local midY = (y0 + y1) / 2
	local half = WALL_T / 4
	if alongX then
		-- wall runs along X at constant Z
		part(parent, "Wall", Vector3.new(length, height, WALL_T / 2), CFrame.new(mid, midY, fixed - half), colorNeg, material)
		part(parent, "Wall", Vector3.new(length, height, WALL_T / 2), CFrame.new(mid, midY, fixed + half), colorPos, material)
	else
		-- wall runs along Z at constant X
		part(parent, "Wall", Vector3.new(WALL_T / 2, height, length), CFrame.new(fixed - half, midY, mid), colorNeg, material)
		part(parent, "Wall", Vector3.new(WALL_T / 2, height, length), CFrame.new(fixed + half, midY, mid), colorPos, material)
	end
end

local function wall(parent: Instance, alongX: boolean, fixed: number, from: number, to: number, openings: { Opening }, colorNeg: Color3, colorPos: Color3, material: Enum.Material?)
	table.sort(openings, function(a, b)
		return a.Center < b.Center
	end)
	local cursor = from
	for _, opening in ipairs(openings) do
		local left = opening.Center - opening.Width / 2
		local right = opening.Center + opening.Width / 2
		wallSegment(parent, alongX, fixed, cursor, left, 0, WALL_H, colorNeg, colorPos, material)
		wallSegment(parent, alongX, fixed, left, right, opening.Top, WALL_H, colorNeg, colorPos, material)
		if opening.Bottom and opening.Bottom > 0 then
			wallSegment(parent, alongX, fixed, left, right, 0, opening.Bottom, colorNeg, colorPos, material)
		end
		cursor = right
	end
	wallSegment(parent, alongX, fixed, cursor, to, 0, WALL_H, colorNeg, colorPos, material)
end

-- constant X wall (runs along Z). colorNeg faces -X, colorPos faces +X
local function wallX(parent: Instance, x: number, z1: number, z2: number, openings: { Opening }, colorNeg: Color3, colorPos: Color3, material: Enum.Material?)
	wall(parent, false, x, z1, z2, openings, colorNeg, colorPos, material)
end

-- constant Z wall (runs along X). colorNeg faces -Z, colorPos faces +Z
local function wallZ(parent: Instance, z: number, x1: number, x2: number, openings: { Opening }, colorNeg: Color3, colorPos: Color3, material: Enum.Material?)
	wall(parent, true, z, x1, x2, openings, colorNeg, colorPos, material)
end

---------------------------------------------------------------------------
-- Fixtures
---------------------------------------------------------------------------

local function weldTo(anchor: BasePart, child: BasePart)
	child.Anchored = false
	child.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = child
	weld.Parent = child
end

local function buildLight(parent: Instance, position: Vector3, zone: string, range: number, color: Color3, brightness: number, flicker: boolean?)
	local panel = part(parent, "LightPanel", Vector3.new(5, 0.3, 2), CFrame.new(position), color, Enum.Material.Neon, {
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	local light = Instance.new("PointLight")
	light.Range = range
	light.Brightness = brightness
	light.Color = color
	light.Shadows = false
	light.Parent = panel
	panel:SetAttribute("Zone", zone)
	CollectionService:AddTag(panel, "MallLight")
	if flicker then
		CollectionService:AddTag(panel, "FlickerLight")
	end
	return panel
end

local function buildClock(parent: Instance, center: Vector3, normal: Vector3, zone: string)
	local clock = model(parent, "Clock")
	local base = faced(center, normal)
	part(clock, "Rim", Vector3.new(0.3, 5.7, 5.7), base * CFrame.new(0, 0, 0.1) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(40, 35, 30), Enum.Material.Metal, { Shape = Enum.PartType.Cylinder, CanCollide = false })
	local face = part(clock, "Face", Vector3.new(0.4, 5, 5), base * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(236, 230, 214), Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder, CanCollide = false })
	for i = 0, 11 do
		local angle = i * math.pi / 6
		local length = (i % 3 == 0) and 0.6 or 0.3
		part(clock, "Tick", Vector3.new(0.18, length, 0.06), base * CFrame.Angles(0, 0, angle) * CFrame.new(0, 2.05, -0.22), Color3.fromRGB(30, 30, 30), nil, { CanCollide = false, CanQuery = false, CastShadow = false })
	end
	local hourPivot = part(clock, "HourPivot", Vector3.new(0.2, 0.2, 0.2), base * CFrame.new(0, 0, -0.28), Color3.new(), nil, { Transparency = 1, CanCollide = false, CanQuery = false })
	local minutePivot = part(clock, "MinutePivot", Vector3.new(0.2, 0.2, 0.2), base * CFrame.new(0, 0, -0.34), Color3.new(), nil, { Transparency = 1, CanCollide = false, CanQuery = false })
	-- stopped at 3:00
	local hourHand = part(clock, "HourHand", Vector3.new(0.24, 1.4, 0.06), hourPivot.CFrame * CFrame.Angles(0, 0, math.pi / 2) * CFrame.new(0, 0.6, 0), Color3.fromRGB(20, 20, 20), nil, { CanCollide = false, CanQuery = false })
	local minuteHand = part(clock, "MinuteHand", Vector3.new(0.16, 2.1, 0.06), minutePivot.CFrame * CFrame.new(0, 0.95, 0), Color3.fromRGB(20, 20, 20), nil, { CanCollide = false, CanQuery = false })
	weldTo(hourPivot, hourHand)
	weldTo(minutePivot, minuteHand)
	part(clock, "Cap", Vector3.new(0.15, 0.4, 0.4), base * CFrame.new(0, 0, -0.4) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(180, 40, 40), nil, { Shape = Enum.PartType.Cylinder, CanCollide = false, CanQuery = false })
	clock.PrimaryPart = face
	clock:SetAttribute("Zone", zone)
	CollectionService:AddTag(clock, "MallClock")
end

local function buildPainting(parent: Instance, center: Vector3, normal: Vector3, zone: string, palette: { Color3 })
	local painting = model(parent, "Painting")
	local base = faced(center, normal)
	local frameColor = Color3.fromRGB(150, 110, 50)
	part(painting, "FrameTop", Vector3.new(9, 0.6, 0.4), base * CFrame.new(0, 3.3, 0), frameColor, Enum.Material.Wood, { CanCollide = false })
	part(painting, "FrameBottom", Vector3.new(9, 0.6, 0.4), base * CFrame.new(0, -3.3, 0), frameColor, Enum.Material.Wood, { CanCollide = false })
	part(painting, "FrameLeft", Vector3.new(0.6, 7.2, 0.4), base * CFrame.new(-4.2, 0, 0), frameColor, Enum.Material.Wood, { CanCollide = false })
	part(painting, "FrameRight", Vector3.new(0.6, 7.2, 0.4), base * CFrame.new(4.2, 0, 0), frameColor, Enum.Material.Wood, { CanCollide = false })
	local canvas = part(painting, "Canvas", Vector3.new(7.8, 6, 0.2), base * CFrame.new(0, 0, 0.05), Color3.fromRGB(40, 40, 40), nil, { CanCollide = false })

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Canvas"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(390, 300)
	gui.LightInfluence = 0.7
	gui.Parent = canvas

	local sky = Instance.new("Frame")
	sky.Name = "Sky"
	sky.Size = UDim2.fromScale(1, 0.62)
	sky.BackgroundColor3 = palette[1]
	sky.BorderSizePixel = 0
	sky.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(palette[1], palette[2])
	gradient.Parent = sky

	local ground = Instance.new("Frame")
	ground.Name = "Ground"
	ground.Position = UDim2.fromScale(0, 0.62)
	ground.Size = UDim2.fromScale(1, 0.38)
	ground.BackgroundColor3 = palette[3]
	ground.BorderSizePixel = 0
	ground.Parent = gui

	local moon = Instance.new("Frame")
	moon.Name = "Moon"
	moon.Position = UDim2.fromScale(0.75, 0.12)
	moon.Size = UDim2.fromOffset(46, 46)
	moon.BackgroundColor3 = Color3.fromRGB(240, 235, 200)
	moon.BorderSizePixel = 0
	moon.Parent = gui
	local moonCorner = Instance.new("UICorner")
	moonCorner.CornerRadius = UDim.new(1, 0)
	moonCorner.Parent = moon

	local trunk = Instance.new("Frame")
	trunk.Name = "Trunk"
	trunk.AnchorPoint = Vector2.new(0.5, 1)
	trunk.Position = UDim2.fromScale(0.18, 0.75)
	trunk.Size = UDim2.fromOffset(16, 90)
	trunk.BackgroundColor3 = Color3.fromRGB(50, 35, 25)
	trunk.BorderSizePixel = 0
	trunk.Parent = gui
	local crown = Instance.new("Frame")
	crown.Name = "Crown"
	crown.AnchorPoint = Vector2.new(0.5, 0.5)
	crown.Position = UDim2.fromScale(0.18, 0.38)
	crown.Size = UDim2.fromOffset(90, 80)
	crown.BackgroundColor3 = palette[4]
	crown.BorderSizePixel = 0
	crown.Parent = gui
	local crownCorner = Instance.new("UICorner")
	crownCorner.CornerRadius = UDim.new(1, 0)
	crownCorner.Parent = crown

	-- The figure only appears while the WalkingPainting anomaly is active.
	local figure = Instance.new("Frame")
	figure.Name = "Figure"
	figure.AnchorPoint = Vector2.new(0.5, 1)
	figure.Position = UDim2.fromScale(0.55, 0.8)
	figure.Size = UDim2.fromOffset(34, 86)
	figure.BackgroundTransparency = 1
	figure.Visible = false
	figure.Parent = gui
	local head = Instance.new("Frame")
	head.Name = "Head"
	head.AnchorPoint = Vector2.new(0.5, 0)
	head.Position = UDim2.fromScale(0.5, 0)
	head.Size = UDim2.fromScale(0.85, 0.34)
	head.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
	head.BorderSizePixel = 0
	head.Parent = figure
	local headCorner = Instance.new("UICorner")
	headCorner.CornerRadius = UDim.new(1, 0)
	headCorner.Parent = head
	for _, x in ipairs({ 0.3, 0.7 }) do
		local eye = Instance.new("Frame")
		eye.AnchorPoint = Vector2.new(0.5, 0.5)
		eye.Position = UDim2.fromScale(x, 0.45)
		eye.Size = UDim2.fromScale(0.16, 0.16)
		eye.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		eye.BorderSizePixel = 0
		eye.Parent = head
	end
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.AnchorPoint = Vector2.new(0.5, 1)
	body.Position = UDim2.fromScale(0.5, 1)
	body.Size = UDim2.fromScale(1, 0.66)
	body.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
	body.BorderSizePixel = 0
	body.Parent = figure
	local bodyCorner = Instance.new("UICorner")
	bodyCorner.CornerRadius = UDim.new(0.3, 0)
	bodyCorner.Parent = body

	painting.PrimaryPart = canvas
	painting:SetAttribute("Zone", zone)
	CollectionService:AddTag(painting, "MallPainting")
end

local function buildExitSign(parent: Instance, center: Vector3, normal: Vector3, zone: string)
	local exitSign = model(parent, "ExitSign")
	local signPart = part(exitSign, "Sign", Vector3.new(3.4, 1.3, 0.35), faced(center, normal), Color3.fromRGB(18, 28, 20), nil, { CanCollide = false, CastShadow = false })
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(340, 130)
	gui.LightInfluence = 0
	gui.Parent = signPart
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(0.68, 1)
	text.Text = "EXIT"
	text.TextColor3 = Color3.fromRGB(70, 255, 120)
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.Parent = gui
	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.BackgroundTransparency = 1
	arrow.Position = UDim2.fromScale(0.68, 0)
	arrow.Size = UDim2.fromScale(0.32, 1)
	arrow.Text = "↑"
	arrow.TextColor3 = Color3.fromRGB(70, 255, 120)
	arrow.Font = Enum.Font.GothamBlack
	arrow.TextScaled = true
	arrow.Parent = gui
	exitSign.PrimaryPart = signPart
	exitSign:SetAttribute("Zone", zone)
	CollectionService:AddTag(exitSign, "ExitSign")
end

local function buildArcadeCabinet(parent: Instance, position: Vector3, normal: Vector3, color: Color3, text: string)
	local cabinet = model(parent, "ArcadeCabinet")
	local base = faced(position, normal)
	decor(cabinet, "Body", Vector3.new(4, 7, 3), base * CFrame.new(0, 3.5, 0), Color3.fromRGB(25, 20, 35))
	decor(cabinet, "Trim", Vector3.new(4.1, 0.3, 3.1), base * CFrame.new(0, 7.05, 0), color, Enum.Material.Neon, false)
	decor(cabinet, "Panel", Vector3.new(3.6, 0.6, 1.2), base * CFrame.new(0, 3.6, -1.8) * CFrame.Angles(math.rad(-20), 0, 0), Color3.fromRGB(40, 40, 50))
	local screen = part(cabinet, "Screen", Vector3.new(3.2, 2.6, 0.1), base * CFrame.new(0, 5.2, -1.52), Color3.fromRGB(10, 10, 20), Enum.Material.SmoothPlastic, { CanCollide = false })
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Display"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(320, 260)
	gui.LightInfluence = 0
	gui.Parent = screen
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(8, 8, 18)
	label.Text = text
	label.TextColor3 = color
	label.Font = Enum.Font.Arcade
	label.TextScaled = true
	label.Parent = gui
	CollectionService:AddTag(cabinet, "ArcadeCabinet")
end

local function buildBench(parent: Instance, position: Vector3, alongZ: boolean)
	local size = if alongZ then Vector3.new(2, 0.5, 6) else Vector3.new(6, 0.5, 2)
	decor(parent, "BenchSeat", size, CFrame.new(position + Vector3.new(0, 1.6, 0)), Color3.fromRGB(110, 75, 45), Enum.Material.Wood)
	local offset = if alongZ then Vector3.new(0, 0, 2.3) else Vector3.new(2.3, 0, 0)
	decor(parent, "BenchLeg", Vector3.new(1.6, 1.4, 0.6), CFrame.new(position + offset + Vector3.new(0, 0.7, 0)) * (if alongZ then CFrame.new() else CFrame.Angles(0, math.pi / 2, 0)), Color3.fromRGB(50, 50, 55), Enum.Material.Metal)
	decor(parent, "BenchLeg", Vector3.new(1.6, 1.4, 0.6), CFrame.new(position - offset + Vector3.new(0, 0.7, 0)) * (if alongZ then CFrame.new() else CFrame.Angles(0, math.pi / 2, 0)), Color3.fromRGB(50, 50, 55), Enum.Material.Metal)
end

local function buildPlanter(parent: Instance, position: Vector3)
	decor(parent, "Planter", Vector3.new(4, 2.4, 4), CFrame.new(position + Vector3.new(0, 1.2, 0)), Color3.fromRGB(120, 110, 100), Enum.Material.Concrete)
	decor(parent, "Soil", Vector3.new(3.4, 0.2, 3.4), CFrame.new(position + Vector3.new(0, 2.45, 0)), Color3.fromRGB(60, 45, 35), Enum.Material.Pebble, false)
	cylinderUp(parent, "DeadTrunk", 6, 0.5, position + Vector3.new(0, 5.4, 0), Color3.fromRGB(80, 65, 50), Enum.Material.Wood)
	decor(parent, "DeadLeaves", Vector3.new(3.2, 2.2, 3.2), CFrame.new(position + Vector3.new(0, 8.6, 0)), Color3.fromRGB(110, 100, 60), Enum.Material.Grass, false).Shape = Enum.PartType.Ball
end

local function buildTable(parent: Instance, position: Vector3)
	cylinderUp(parent, "TableTop", 0.3, 4, position + Vector3.new(0, 3, 0), Color3.fromRGB(225, 220, 210))
	cylinderUp(parent, "TableLeg", 2.9, 0.4, position + Vector3.new(0, 1.45, 0), Color3.fromRGB(80, 80, 85), Enum.Material.Metal)
	for _, dx in ipairs({ -2.6, 2.6 }) do
		decor(parent, "Chair", Vector3.new(1.6, 0.3, 1.6), CFrame.new(position + Vector3.new(dx, 1.8, 0)), Color3.fromRGB(200, 90, 60))
		decor(parent, "ChairBack", Vector3.new(0.3, 1.8, 1.6), CFrame.new(position + Vector3.new(dx + math.sign(dx) * 0.8, 2.8, 0)), Color3.fromRGB(200, 90, 60))
		decor(parent, "ChairLeg", Vector3.new(0.3, 1.7, 0.3), CFrame.new(position + Vector3.new(dx, 0.85, 0)), Color3.fromRGB(70, 70, 70), Enum.Material.Metal, false)
	end
end

local function buildCar(parent: Instance, position: Vector3, yaw: number, color: Color3)
	local base = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	decor(parent, "CarBody", Vector3.new(5, 2, 10), base * CFrame.new(0, 1.7, 0), color, Enum.Material.Metal)
	decor(parent, "CarCabin", Vector3.new(4.6, 1.7, 5), base * CFrame.new(0, 3.5, 0.5), color:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Metal)
	decor(parent, "CarWindow", Vector3.new(4.7, 1.2, 4.4), base * CFrame.new(0, 3.55, 0.5), Color3.fromRGB(30, 40, 50), Enum.Material.Glass, false)
	for _, offset in ipairs({ Vector3.new(-2.5, 0.9, -3.2), Vector3.new(2.5, 0.9, -3.2), Vector3.new(-2.5, 0.9, 3.2), Vector3.new(2.5, 0.9, 3.2) }) do
		part(parent, "Wheel", Vector3.new(0.8, 1.8, 1.8), base * CFrame.new(offset), Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder, CastShadow = false })
	end
end

local function buildShelf(parent: Instance, x1: number, x2: number, z: number)
	local length = x2 - x1
	local mid = (x1 + x2) / 2
	decor(parent, "Shelf", Vector3.new(length, 6, 2.6), CFrame.new(mid, 3, z), Color3.fromRGB(235, 235, 240))
	local colors = {
		Color3.fromRGB(230, 70, 70),
		Color3.fromRGB(70, 150, 240),
		Color3.fromRGB(250, 210, 60),
		Color3.fromRGB(90, 200, 110),
		Color3.fromRGB(200, 100, 220),
	}
	local count = math.floor(length / 5)
	for i = 1, count do
		local px = x1 + (i - 0.5) * (length / count)
		local color = colors[(i % #colors) + 1]
		local size = Vector3.new(1.6, 1.6, 1.6)
		local toy = decor(parent, "Toy", size, CFrame.new(px, 6.8, z) * CFrame.Angles(0, math.rad(i * 23), 0), color, Enum.Material.SmoothPlastic, false)
		if i % 3 == 0 then
			toy.Shape = Enum.PartType.Ball
		end
	end
end

---------------------------------------------------------------------------
-- Markers (anomaly spawn points)
---------------------------------------------------------------------------

local markerCount = 0
local function marker(kind: string, zone: string, cframe: CFrame, size: Vector3?)
	markerCount += 1
	local p = part(MapService.Folders.AnomalySpawns, string.format("%s_%s_%d", zone, kind, markerCount), size or Vector3.new(1, 1, 1), cframe, Color3.fromRGB(255, 0, 255), nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	p:SetAttribute("Kind", kind)
	p:SetAttribute("Zone", zone)
	return p
end

local function zoneCenter(zone: string): Vector3
	local z = ZONES[zone]
	return Vector3.new((z.X[1] + z.X[2]) / 2, 0, (z.Z[1] + z.Z[2]) / 2)
end

local function floorMarker(zone: string, x: number, z: number)
	local position = Vector3.new(x, 0, z)
	local center = zoneCenter(zone)
	local look = Vector3.new(center.X, 0, center.Z)
	if (look - position).Magnitude < 1 then
		look = position + Vector3.new(0, 0, -1)
	end
	marker("Floor", zone, CFrame.lookAt(position, look))
end

---------------------------------------------------------------------------
-- Dead Mall
---------------------------------------------------------------------------

local function buildMall(root: Instance)
	local structure = folder(root, "Structure")
	local decorFolder = folder(root, "Decor")
	local fixtures = folder(root, "Fixtures")
	local lights = folder(root, "Lights")
	local zonesFolder = Instance.new("Model")
	zonesFolder.Name = "Zones"
	zonesFolder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	zonesFolder.Parent = root
	local playerSpawns = folder(root, "PlayerSpawns")
	local waypoints = folder(root, "NPCWaypoints")
	folder(root, "NPCs")

	-- Floors, ceilings and zone bounds
	for zoneId, zone in pairs(ZONES) do
		local sizeX = zone.X[2] - zone.X[1]
		local sizeZ = zone.Z[2] - zone.Z[1]
		local center = zoneCenter(zoneId)
		part(structure, zoneId .. "Floor", Vector3.new(sizeX, 1, sizeZ), CFrame.new(center.X, -0.5, center.Z), zone.Floor, zone.FloorMat)
		if zoneId ~= "MainHall" then
			part(structure, zoneId .. "Ceiling", Vector3.new(sizeX, 1, sizeZ), CFrame.new(center.X, zone.H + 0.5, center.Z), zone.Ceiling, Enum.Material.SmoothPlastic, { CastShadow = false })
		end
		local bounds = part(zonesFolder, zoneId, Vector3.new(sizeX, zone.H, sizeZ), CFrame.new(center.X, zone.H / 2, center.Z), Color3.new(1, 1, 1), nil, {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
		bounds:SetAttribute("DisplayName", GameConfig.Zones[zoneId] or zoneId)
	end

	-- Main hall ceiling with a long skylight
	local main = ZONES.MainHall
	part(structure, "MainCeilingW", Vector3.new(18, 1, 240), CFrame.new(-21, main.H + 0.5, 0), main.Ceiling, nil, { CastShadow = false })
	part(structure, "MainCeilingE", Vector3.new(18, 1, 240), CFrame.new(21, main.H + 0.5, 0), main.Ceiling, nil, { CastShadow = false })
	part(structure, "MainCeilingN", Vector3.new(24, 1, 20), CFrame.new(0, main.H + 0.5, -110), main.Ceiling, nil, { CastShadow = false })
	part(structure, "MainCeilingS", Vector3.new(24, 1, 20), CFrame.new(0, main.H + 0.5, 110), main.Ceiling, nil, { CastShadow = false })
	part(structure, "Skylight", Vector3.new(24, 0.6, 200), CFrame.new(0, main.H + 0.3, 0), Color3.fromRGB(120, 150, 170), Enum.Material.Glass, {
		Transparency = 0.6,
		CanQuery = false,
		CastShadow = false,
	})
	for z = -80, 80, 20 do
		part(structure, "SkylightBeam", Vector3.new(24, 0.8, 0.8), CFrame.new(0, main.H + 0.6, z), Color3.fromRGB(60, 60, 65), Enum.Material.Metal, { CanQuery = false, CastShadow = false })
	end

	-- Walls ------------------------------------------------------------------
	local Z = ZONES
	-- west outer (x = -100)
	wallX(structure, -100, -120, -50, {}, EXTERIOR, Z.Arcade.Wall)
	wallX(structure, -100, -50, 40, {}, EXTERIOR, Z.FoodCourt.Wall)
	wallX(structure, -100, 40, 120, { { Center = 72, Width = 14, Bottom = 3.5, Top = 10.5 } }, Z.Bathrooms.Wall, Z.Bathrooms.Wall)
	-- main hall west (x = -30)
	wallX(structure, -30, -120, -50, { { Center = -85, Width = 20, Top = 14 } }, Z.Arcade.Wall, Z.MainHall.Wall)
	wallX(structure, -30, -50, 40, { { Center = -5, Width = 36, Top = 18 } }, Z.FoodCourt.Wall, Z.MainHall.Wall)
	wallX(structure, -30, 40, 120, { { Center = 80, Width = 12, Top = 12 } }, Z.Bathrooms.Wall, Z.MainHall.Wall)
	-- main hall east (x = 30)
	wallX(structure, 30, -120, -60, { { Center = -90, Width = 20, Top = 14 } }, Z.MainHall.Wall, Z.ToyStore.Wall)
	wallX(structure, 30, -60, 30, { { Center = -15, Width = 24, Top = 16 } }, Z.MainHall.Wall, Z.Cinema.Wall)
	wallX(structure, 30, 30, 120, { { Center = 92, Width = 14, Top = 11 } }, Z.MainHall.Wall, Z.StorageHallway.Wall)
	-- east outer (x = 100)
	wallX(structure, 100, -120, -60, {}, Z.ToyStore.Wall, EXTERIOR)
	wallX(structure, 100, -60, 30, {}, Z.Cinema.Wall, EXTERIOR)
	-- north outer (z = -120)
	wallZ(structure, -120, -100, -30, {}, EXTERIOR, Z.Arcade.Wall)
	wallZ(structure, -120, -30, 30, {}, EXTERIOR, Z.MainHall.Wall)
	wallZ(structure, -120, 30, 100, {}, EXTERIOR, Z.ToyStore.Wall)
	-- south outer (z = 120)
	wallZ(structure, 120, -100, -30, {}, Z.Bathrooms.Wall, EXTERIOR)
	wallZ(structure, 120, -30, 30, { { Center = 0, Width = 24, Top = 14 } }, Z.MainHall.Wall, EXTERIOR)
	wallZ(structure, 120, 30, 100, {}, EXTERIOR, EXTERIOR)
	-- dividers
	wallZ(structure, -50, -100, -30, { { Center = -65, Width = 14, Top = 12 } }, Z.Arcade.Wall, Z.FoodCourt.Wall)
	wallZ(structure, 40, -100, -30, {}, Z.FoodCourt.Wall, Z.Bathrooms.Wall)
	wallZ(structure, -60, 30, 100, {}, Z.ToyStore.Wall, Z.Cinema.Wall)
	wallZ(structure, 30, 30, 100, {}, Z.Cinema.Wall, EXTERIOR)
	-- storage hallway + parking garage
	wallZ(structure, 84, 30, 160, {}, EXTERIOR, Z.StorageHallway.Wall, Enum.Material.Concrete)
	wallZ(structure, 100, 30, 160, {}, Z.StorageHallway.Wall, EXTERIOR, Enum.Material.Concrete)
	wallX(structure, 160, 30, 150, { { Center = 92, Width = 14, Top = 11 } }, Z.StorageHallway.Wall, Z.ParkingGarage.Wall, Enum.Material.Concrete)
	wallX(structure, 260, 30, 150, {}, Z.ParkingGarage.Wall, EXTERIOR, Enum.Material.Concrete)
	wallZ(structure, 30, 160, 260, {}, EXTERIOR, Z.ParkingGarage.Wall, Enum.Material.Concrete)
	wallZ(structure, 150, 160, 260, {}, Z.ParkingGarage.Wall, EXTERIOR, Enum.Material.Concrete)

	-- Mirror alcove behind the bathroom mirror (the "reflection" room)
	local tile = Z.Bathrooms.Wall
	part(structure, "AlcoveFloor", Vector3.new(8, 1, 16), CFrame.new(-105, -0.5, 72), Z.Bathrooms.Floor, Enum.Material.Marble)
	part(structure, "AlcoveCeiling", Vector3.new(8, 1, 16), CFrame.new(-105, 12.5, 72), Z.Bathrooms.Ceiling)
	wallX(structure, -109, 64, 80, {}, EXTERIOR, tile)
	wallZ(structure, 64, -109, -101, {}, EXTERIOR, tile)
	wallZ(structure, 80, -109, -101, {}, tile, EXTERIOR)
	decor(structure, "AlcoveStall", Vector3.new(0.4, 8, 5), CFrame.new(-104, 4, 67), Color3.fromRGB(120, 150, 150))

	-- Main hall decor ----------------------------------------------------------
	cylinderUp(decorFolder, "FountainRim", 1.6, 15, Vector3.new(0, 0.8, 0), Color3.fromRGB(170, 165, 158), Enum.Material.Marble)
	cylinderUp(decorFolder, "FountainBasin", 0.3, 13.4, Vector3.new(0, 1.5, 0), Color3.fromRGB(70, 80, 80), Enum.Material.Slate)
	cylinderUp(decorFolder, "FountainPillar", 5, 1.8, Vector3.new(0, 3.5, 0), Color3.fromRGB(170, 165, 158), Enum.Material.Marble)
	cylinderUp(decorFolder, "FountainBowl", 0.7, 5.5, Vector3.new(0, 6.2, 0), Color3.fromRGB(170, 165, 158), Enum.Material.Marble)
	for _, z in ipairs({ -80, -40, 40, 80 }) do
		buildBench(decorFolder, Vector3.new(-8, 0, z), true)
		buildBench(decorFolder, Vector3.new(8, 0, z), true)
	end
	for _, z in ipairs({ -110, -60, -35, 30, 55, 110 }) do
		buildPlanter(decorFolder, Vector3.new(-25, 0, z))
		buildPlanter(decorFolder, Vector3.new(25, 0, z))
	end
	-- phone case kiosk
	decor(decorFolder, "Kiosk", Vector3.new(8, 3.5, 5), CFrame.new(0, 1.75, 62), Color3.fromRGB(60, 110, 160))
	decor(decorFolder, "KioskRoof", Vector3.new(9, 0.5, 6), CFrame.new(0, 7.5, 62), Color3.fromRGB(230, 230, 235))
	for _, offset in ipairs({ Vector3.new(-4, 0, -2.5), Vector3.new(4, 0, -2.5), Vector3.new(-4, 0, 2.5), Vector3.new(4, 0, 2.5) }) do
		decor(decorFolder, "KioskPost", Vector3.new(0.3, 4, 0.3), CFrame.new(Vector3.new(0, 5.5, 62) + offset), Color3.fromRGB(200, 200, 205), Enum.Material.Metal)
	end
	sign(decorFolder, "KioskSign", Vector3.new(0, 6.6, 58.9), Vector3.new(0, 0, -1), Vector2.new(7, 1.2), "PHONE CASES 50% OFF", Color3.fromRGB(240, 240, 240), Color3.fromRGB(200, 50, 60))
	-- mall directory (double sided)
	local directory = decor(decorFolder, "Directory", Vector3.new(6, 7, 0.6), CFrame.new(0, 4.5, -62), Color3.fromRGB(25, 25, 30))
	local directoryText = "MALL DIRECTORY\n\n← ARCADE · FOOD COURT · RESTROOMS\n→ TOYS · CINEMA · STAFF HALL\n→ PARKING GARAGE"
	surfaceText(directory, directoryText, Color3.fromRGB(230, 230, 230), Enum.Font.GothamBold, Enum.NormalId.Front, 0.3)
	surfaceText(directory, directoryText, Color3.fromRGB(230, 230, 230), Enum.Font.GothamBold, Enum.NormalId.Back, 0.3)
	-- entrance doors (chained shut)
	part(structure, "EntranceGlass", Vector3.new(24, 14, 0.4), CFrame.new(0, 7, 119.6), Color3.fromRGB(140, 170, 190), Enum.Material.Glass, { Transparency = 0.55, CanQuery = false })
	decor(structure, "EntranceChain", Vector3.new(6, 0.4, 0.4), CFrame.new(0, 4, 119.1) * CFrame.Angles(0, 0, math.rad(8)), Color3.fromRGB(90, 90, 95), Enum.Material.Metal, false)
	decor(structure, "EntranceBar", Vector3.new(0.4, 14, 0.6), CFrame.new(0, 7, 119.5), Color3.fromRGB(50, 50, 55), Enum.Material.Metal)

	-- store signs above openings (facing into the main hall)
	sign(decorFolder, "ArcadeSign", Vector3.new(-28.8, 16.5, -85), Vector3.xAxis, Vector2.new(18, 3.5), "ARCADE ZONE", Color3.fromRGB(35, 20, 60), Color3.fromRGB(255, 80, 230), Enum.Font.Arcade)
	sign(decorFolder, "FoodSign", Vector3.new(-28.8, 21, -5), Vector3.xAxis, Vector2.new(22, 4), "FOOD COURT", Color3.fromRGB(230, 140, 60), Color3.fromRGB(255, 250, 235))
	sign(decorFolder, "RestroomSign", Vector3.new(-28.8, 13.6, 80), Vector3.xAxis, Vector2.new(10, 2), "RESTROOMS", Color3.fromRGB(240, 240, 240), Color3.fromRGB(40, 80, 120))
	sign(decorFolder, "ToySign", Vector3.new(28.8, 16.5, -90), -Vector3.xAxis, Vector2.new(18, 3.5), "TOYZ PLANET", Color3.fromRGB(250, 210, 60), Color3.fromRGB(220, 50, 50))
	sign(decorFolder, "CinemaSign", Vector3.new(28.8, 19, -15), -Vector3.xAxis, Vector2.new(22, 4), "CINEMA 6", Color3.fromRGB(20, 10, 12), Color3.fromRGB(255, 220, 120))
	sign(decorFolder, "StaffSign", Vector3.new(28.8, 12.8, 92), -Vector3.xAxis, Vector2.new(12, 2), "STAFF ONLY", Color3.fromRGB(200, 40, 40), Color3.fromRGB(255, 255, 255))
	sign(decorFolder, "MallTitle", Vector3.new(0, 23, -118.8), Vector3.zAxis, Vector2.new(40, 6), "SUNNYVALE MALL", Color3.fromRGB(60, 50, 45), Color3.fromRGB(255, 200, 120))

	-- Food court -------------------------------------------------------------
	for index, z in ipairs({ -35, -5, 25 }) do
		decor(decorFolder, "Counter", Vector3.new(6, 4, 12), CFrame.new(-96, 2, z), Color3.fromRGB(180, 60, 50))
		local names = { "PIZZA PALACE", "LUCKY WOK", "BURGER BARN" }
		local colors = { Color3.fromRGB(220, 60, 40), Color3.fromRGB(200, 30, 30), Color3.fromRGB(250, 180, 40) }
		sign(decorFolder, "StallSign", Vector3.new(-98.8, 12, z), Vector3.xAxis, Vector2.new(11, 2.6), names[index], colors[index], Color3.fromRGB(255, 255, 255))
	end
	for _, x in ipairs({ -78, -62, -46 }) do
		for _, z in ipairs({ -35, -15, 5, 25 }) do
			buildTable(decorFolder, Vector3.new(x, 0, z))
		end
	end

	-- Arcade -------------------------------------------------------------------
	local arcadeColors = { Color3.fromRGB(255, 60, 200), Color3.fromRGB(60, 230, 255), Color3.fromRGB(255, 230, 60), Color3.fromRGB(120, 255, 90) }
	local arcadeTexts = { "INSERT COIN", "HIGH SCORE\n???", "GAME OVER", "PLAYER 2?" }
	for index, x in ipairs({ -92, -84, -76, -46, -38 }) do
		buildArcadeCabinet(fixtures, Vector3.new(x, 0, -117), Vector3.zAxis, arcadeColors[(index % 4) + 1], arcadeTexts[(index % 4) + 1])
	end
	for index, z in ipairs({ -104, -94, -84 }) do
		buildArcadeCabinet(fixtures, Vector3.new(-97, 0, z), Vector3.xAxis, arcadeColors[index], arcadeTexts[index])
	end
	decor(decorFolder, "ClawBase", Vector3.new(5, 3, 5), CFrame.new(-65, 1.5, -85), Color3.fromRGB(230, 60, 120))
	part(decorFolder, "ClawGlass", Vector3.new(5, 5, 5), CFrame.new(-65, 5.5, -85), Color3.fromRGB(180, 220, 255), Enum.Material.Glass, { Transparency = 0.6, CanQuery = false })
	decor(decorFolder, "ClawTop", Vector3.new(5.2, 0.6, 5.2), CFrame.new(-65, 8.3, -85), Color3.fromRGB(230, 60, 120))
	decor(decorFolder, "NeonStrip", Vector3.new(66, 0.3, 0.3), CFrame.new(-65, 18.5, -118.8), Color3.fromRGB(255, 60, 220), Enum.Material.Neon, false)
	decor(decorFolder, "NeonStrip", Vector3.new(0.3, 0.3, 66), CFrame.new(-98.8, 18.5, -85), Color3.fromRGB(60, 220, 255), Enum.Material.Neon, false)

	-- Toy store -----------------------------------------------------------------
	buildShelf(decorFolder, 45, 85, -110)
	buildShelf(decorFolder, 45, 85, -98)
	buildShelf(decorFolder, 45, 85, -72)
	decor(decorFolder, "Checkout", Vector3.new(4, 3.6, 8), CFrame.new(92, 1.8, -85), Color3.fromRGB(230, 90, 90))

	-- Cinema -------------------------------------------------------------------
	local screen = part(decorFolder, "CinemaScreen", Vector3.new(0.4, 14, 44), CFrame.new(98.7, 12, -15), Color3.fromRGB(200, 200, 212), Enum.Material.SmoothPlastic, { CastShadow = false })
	surfaceText(screen, "N O W   S H O W I N G\n\n. . .", Color3.fromRGB(70, 70, 80), Enum.Font.SpecialElite, Enum.NormalId.Left, 0.2)
	for _, x in ipairs({ 46, 54, 62, 70, 78 }) do
		decor(decorFolder, "SeatRow", Vector3.new(3, 2, 30), CFrame.new(x, 1, -33), Color3.fromRGB(140, 25, 35), Enum.Material.Fabric)
		decor(decorFolder, "SeatRow", Vector3.new(3, 2, 26), CFrame.new(x, 1, 5), Color3.fromRGB(140, 25, 35), Enum.Material.Fabric)
		decor(decorFolder, "SeatBack", Vector3.new(0.8, 4.2, 30), CFrame.new(x - 1.2, 2.1, -33), Color3.fromRGB(120, 20, 30), Enum.Material.Fabric)
		decor(decorFolder, "SeatBack", Vector3.new(0.8, 4.2, 26), CFrame.new(x - 1.2, 2.1, 5), Color3.fromRGB(120, 20, 30), Enum.Material.Fabric)
	end

	-- Bathrooms ------------------------------------------------------------------
	decor(decorFolder, "SinkCounter", Vector3.new(4, 3.4, 16), CFrame.new(-97, 1.7, 72), Color3.fromRGB(235, 235, 235), Enum.Material.Marble)
	for _, z in ipairs({ 67, 72, 77 }) do
		cylinderUp(decorFolder, "Sink", 0.2, 2.2, Vector3.new(-97, 3.45, z), Color3.fromRGB(200, 205, 210), Enum.Material.Metal)
		decor(decorFolder, "Tap", Vector3.new(0.9, 0.3, 0.3), CFrame.new(-98.4, 3.9, z), Color3.fromRGB(180, 180, 185), Enum.Material.Metal, false)
	end
	for _, x in ipairs({ -90, -80, -70, -60, -50, -40 }) do
		decor(decorFolder, "StallWall", Vector3.new(0.4, 8, 12), CFrame.new(x, 4, 114), Color3.fromRGB(120, 150, 150))
	end
	for index, x in ipairs({ -85, -75, -65, -55, -45 }) do
		local ajar = index % 2 == 0
		local cframe = CFrame.new(x - 2.4, 4, 108) * CFrame.Angles(0, ajar and math.rad(-35) or 0, 0) * CFrame.new(2.4, 0, 0)
		decor(decorFolder, "StallDoor", Vector3.new(4.8, 7, 0.3), cframe, Color3.fromRGB(110, 140, 140))
	end
	decor(decorFolder, "HandDryer", Vector3.new(1.2, 1.4, 0.8), CFrame.new(-60, 5, 41.4), Color3.fromRGB(220, 220, 225), Enum.Material.Metal)

	-- Storage hallway --------------------------------------------------------------
	for index, x in ipairs({ 45, 70, 95, 120, 145 }) do
		local z = (index % 2 == 0) and 86.5 or 97.5
		local stack = index % 3 + 1
		for level = 0, stack - 1 do
			decor(decorFolder, "Box", Vector3.new(3, 2.4, 2.6), CFrame.new(x + (level % 2) * 0.4, 1.2 + level * 2.4, z) * CFrame.Angles(0, math.rad(level * 7), 0), Color3.fromRGB(170, 130, 85), Enum.Material.SmoothPlastic)
		end
	end
	part(decorFolder, "Pipe", Vector3.new(130, 0.8, 0.8), CFrame.new(95, 12.8, 85.8) * CFrame.Angles(0, 0, 0), Color3.fromRGB(90, 95, 100), Enum.Material.Metal, { Shape = Enum.PartType.Cylinder, CanCollide = false, CastShadow = false })
	part(decorFolder, "Pipe", Vector3.new(130, 0.6, 0.6), CFrame.new(95, 12.6, 98.2), Color3.fromRGB(120, 60, 50), Enum.Material.Metal, { Shape = Enum.PartType.Cylinder, CanCollide = false, CastShadow = false })

	-- Parking garage ----------------------------------------------------------------
	for _, x in ipairs({ 185, 210, 235 }) do
		for _, z in ipairs({ 60, 90, 120 }) do
			decor(decorFolder, "Pillar", Vector3.new(2.4, 16, 2.4), CFrame.new(x, 8, z), Color3.fromRGB(140, 140, 135), Enum.Material.Concrete)
			decor(decorFolder, "PillarStripe", Vector3.new(2.5, 1, 2.5), CFrame.new(x, 2, z), Color3.fromRGB(240, 200, 40), Enum.Material.SmoothPlastic, false)
		end
	end
	for _, x in ipairs({ 170, 180, 190, 220, 230, 240, 250 }) do
		decor(decorFolder, "ParkingLine", Vector3.new(0.3, 0.05, 12), CFrame.new(x, 0.03, 42), Color3.fromRGB(230, 230, 230), Enum.Material.SmoothPlastic, false)
		decor(decorFolder, "ParkingLine", Vector3.new(0.3, 0.05, 12), CFrame.new(x, 0.03, 138), Color3.fromRGB(230, 230, 230), Enum.Material.SmoothPlastic, false)
	end
	buildCar(decorFolder, Vector3.new(175, 0, 42), 0, Color3.fromRGB(150, 30, 30))
	buildCar(decorFolder, Vector3.new(235, 0, 42), 0, Color3.fromRGB(40, 70, 130))
	buildCar(decorFolder, Vector3.new(185, 0, 138), math.pi, Color3.fromRGB(200, 200, 200))
	buildCar(decorFolder, Vector3.new(245, 0, 138), math.pi, Color3.fromRGB(30, 30, 35))
	decor(structure, "GarageShutter", Vector3.new(0.6, 12, 24), CFrame.new(258.9, 6, 90), Color3.fromRGB(80, 85, 90), Enum.Material.CorrodedMetal)

	-- Fixtures ------------------------------------------------------------------------
	buildClock(fixtures, Vector3.new(-28.7, 15, 25), Vector3.xAxis, "MainHall")
	buildClock(fixtures, Vector3.new(-98.7, 14, -20), Vector3.xAxis, "FoodCourt")
	buildClock(fixtures, Vector3.new(-61, 13, -118.7), Vector3.zAxis, "Arcade")

	buildPainting(fixtures, Vector3.new(-28.6, 10, -40), Vector3.xAxis, "MainHall", {
		Color3.fromRGB(40, 50, 90),
		Color3.fromRGB(120, 90, 120),
		Color3.fromRGB(50, 70, 45),
		Color3.fromRGB(40, 80, 50),
	})
	buildPainting(fixtures, Vector3.new(31.4, 11, 15), Vector3.xAxis, "Cinema", {
		Color3.fromRGB(90, 40, 40),
		Color3.fromRGB(200, 120, 70),
		Color3.fromRGB(80, 60, 40),
		Color3.fromRGB(120, 70, 30),
	})

	buildExitSign(fixtures, Vector3.new(0, 16, 118.8), -Vector3.zAxis, "MainHall")
	buildExitSign(fixtures, Vector3.new(28.8, 13, 78), -Vector3.xAxis, "MainHall")
	buildExitSign(fixtures, Vector3.new(-98.8, 16, 12), Vector3.xAxis, "FoodCourt")
	buildExitSign(fixtures, Vector3.new(258.6, 13.5, 90), -Vector3.xAxis, "ParkingGarage")
	buildExitSign(fixtures, Vector3.new(100, 10, 85.2), Vector3.zAxis, "StorageHallway")
	buildExitSign(fixtures, Vector3.new(98.8, 21, -45), -Vector3.xAxis, "Cinema")

	local mirror = model(fixtures, "Mirror")
	local glass = part(mirror, "Glass", Vector3.new(14, 7, 0.2), faced(Vector3.new(-99.1, 7, 72), Vector3.xAxis), Color3.fromRGB(185, 210, 222), Enum.Material.Glass, {
		Transparency = 0.45,
		Reflectance = 0.2,
		CanQuery = false,
		CastShadow = false,
	})
	mirror.PrimaryPart = glass
	mirror:SetAttribute("Zone", "Bathrooms")
	CollectionService:AddTag(mirror, "MallMirror")

	-- Lights ----------------------------------------------------------------------------
	local warm = Color3.fromRGB(255, 240, 215)
	for index, z in ipairs({ -90, -54, -18, 18, 54, 90 }) do
		local x = (index % 2 == 0) and 18 or -18
		buildLight(lights, Vector3.new(x, main.H - 0.2, z), "MainHall", 42, warm, 1.1)
	end
	for _, z in ipairs({ -30, 0, 28 }) do
		buildLight(lights, Vector3.new(-65, Z.FoodCourt.H - 0.2, z), "FoodCourt", 34, warm, 1)
	end
	buildLight(lights, Vector3.new(-65, Z.Arcade.H - 0.2, -100), "Arcade", 28, Color3.fromRGB(210, 160, 255), 0.9)
	buildLight(lights, Vector3.new(-65, Z.Arcade.H - 0.2, -68), "Arcade", 28, Color3.fromRGB(160, 220, 255), 0.9)
	buildLight(lights, Vector3.new(65, Z.ToyStore.H - 0.2, -104), "ToyStore", 30, warm, 1)
	buildLight(lights, Vector3.new(65, Z.ToyStore.H - 0.2, -78), "ToyStore", 30, warm, 1)
	buildLight(lights, Vector3.new(45, Z.Cinema.H - 0.2, -45), "Cinema", 26, Color3.fromRGB(255, 200, 170), 0.55)
	buildLight(lights, Vector3.new(45, Z.Cinema.H - 0.2, 15), "Cinema", 26, Color3.fromRGB(255, 200, 170), 0.55)
	buildLight(lights, Vector3.new(-65, Z.Bathrooms.H - 0.2, 60), "Bathrooms", 30, Color3.fromRGB(220, 255, 250), 1)
	buildLight(lights, Vector3.new(-65, Z.Bathrooms.H - 0.2, 100), "Bathrooms", 30, Color3.fromRGB(220, 255, 250), 1)
	buildLight(lights, Vector3.new(-105, 11.8, 72), "Bathrooms", 14, Color3.fromRGB(220, 255, 250), 0.5)
	buildLight(lights, Vector3.new(60, Z.StorageHallway.H - 0.2, 92), "StorageHallway", 24, Color3.fromRGB(255, 250, 220), 0.9)
	buildLight(lights, Vector3.new(125, Z.StorageHallway.H - 0.2, 92), "StorageHallway", 24, Color3.fromRGB(255, 250, 220), 0.9, true)
	for _, position in ipairs({ Vector3.new(185, 0, 75), Vector3.new(235, 0, 75), Vector3.new(185, 0, 105), Vector3.new(235, 0, 105) }) do
		buildLight(lights, position + Vector3.new(0, Z.ParkingGarage.H - 0.2, 0), "ParkingGarage", 32, Color3.fromRGB(215, 255, 225), 0.85)
	end

	-- Player spawns + NPC walking lanes -------------------------------------------------------
	for _, position in ipairs({ Vector3.new(10, 3, -14), Vector3.new(-10, 3, -14), Vector3.new(10, 3, 14), Vector3.new(-10, 3, 14), Vector3.new(0, 3, -20), Vector3.new(0, 3, 20) }) do
		local outward = Vector3.new(position.X, 3, position.Z) * 2
		part(playerSpawns, "MallSpawn", Vector3.new(2, 1, 2), CFrame.lookAt(position, outward), Color3.new(), nil, {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
	end
	for _, laneX in ipairs({ -17, 17 }) do
		for _, z in ipairs({ -105, -75, -45, -15, 15, 45, 75, 105 }) do
			local waypoint = part(waypoints, "Waypoint", Vector3.new(1, 1, 1), CFrame.new(laneX, 0.5, z), Color3.new(), nil, {
				Transparency = 1,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
			})
			waypoint:SetAttribute("Lane", laneX < 0 and "West" or "East")
		end
	end

	-- Anomaly spawn markers ---------------------------------------------------------------
	for _, p in ipairs({ { 11, -95 }, { -11, -70 }, { 11, -28 }, { -11, 25 }, { 11, 70 }, { -11, 100 } }) do
		floorMarker("MainHall", p[1], p[2])
	end
	for _, p in ipairs({ { -70, -25 }, { -54, 15 }, { -86, 15 }, { -70, 35 }, { -40, -42 } }) do
		floorMarker("FoodCourt", p[1], p[2])
	end
	for _, p in ipairs({ { 60, -104 }, { 75, -85 }, { 50, -85 }, { 90, -115 }, { 65, -64 } }) do
		floorMarker("ToyStore", p[1], p[2])
	end
	for _, p in ipairs({ { -65, -100 }, { -50, -70 }, { -85, -60 }, { -45, -105 } }) do
		floorMarker("Arcade", p[1], p[2])
	end
	for _, p in ipairs({ { 90, -50 }, { 90, 20 }, { 38, -45 }, { 38, 20 }, { 88, -15 } }) do
		floorMarker("Cinema", p[1], p[2])
	end
	for _, p in ipairs({ { -60, 60 }, { -45, 95 }, { -80, 90 }, { -88, 52 } }) do
		floorMarker("Bathrooms", p[1], p[2])
	end
	for _, p in ipairs({ { 55, 92 }, { 100, 92 }, { 140, 92 } }) do
		floorMarker("StorageHallway", p[1], p[2])
	end
	for _, p in ipairs({ { 172, 75 }, { 222, 100 }, { 248, 60 }, { 197, 105 }, { 247, 110 } }) do
		floorMarker("ParkingGarage", p[1], p[2])
	end

	local ceilingSpots = {
		{ "MainHall", 20, -60 },
		{ "MainHall", -20, 40 },
		{ "FoodCourt", -65, -10 },
		{ "FoodCourt", -80, 25 },
		{ "ToyStore", 65, -90 },
		{ "Arcade", -60, -85 },
		{ "Cinema", 60, -20 },
		{ "Cinema", 85, 10 },
		{ "Bathrooms", -65, 80 },
		{ "StorageHallway", 80, 92 },
		{ "StorageHallway", 135, 92 },
		{ "ParkingGarage", 200, 75 },
		{ "ParkingGarage", 225, 110 },
	}
	for _, spot in ipairs(ceilingSpots) do
		local zoneId = spot[1]
		local height = ZONES[zoneId].H
		local position = Vector3.new(spot[2], height, spot[3])
		marker("Ceiling", zoneId, CFrame.lookAt(position, position + Vector3.new(0, 0, 1)))
	end

	local doorSlots = {
		{ "MainHall", Vector3.new(28.9, 0, 45), -Vector3.xAxis },
		{ "MainHall", Vector3.new(28.9, 0, 68), -Vector3.xAxis },
		{ "MainHall", Vector3.new(-28.9, 0, 100), Vector3.xAxis },
		{ "FoodCourt", Vector3.new(-50, 0, 38.9), -Vector3.zAxis },
		{ "StorageHallway", Vector3.new(75, 0, 85.1), Vector3.zAxis },
		{ "StorageHallway", Vector3.new(125, 0, 85.1), Vector3.zAxis },
		{ "ParkingGarage", Vector3.new(258.9, 0, 60), -Vector3.xAxis },
		{ "ParkingGarage", Vector3.new(258.9, 0, 125), -Vector3.xAxis },
		{ "Arcade", Vector3.new(-98.9, 0, -65), Vector3.xAxis },
		{ "Cinema", Vector3.new(60, 0, 28.9), -Vector3.zAxis },
	}
	for _, slot in ipairs(doorSlots) do
		marker("DoorSlot", slot[1], faced(slot[2], slot[3]))
	end

	local darkSpots = {
		{ "Cinema", Vector3.new(96, 5, -56) },
		{ "Cinema", Vector3.new(96, 5, 26) },
		{ "Cinema", Vector3.new(35, 4, 26) },
		{ "StorageHallway", Vector3.new(157, 4, 88) },
		{ "StorageHallway", Vector3.new(40, 4, 97) },
		{ "ParkingGarage", Vector3.new(256, 5, 34) },
		{ "ParkingGarage", Vector3.new(164, 5, 146) },
		{ "ParkingGarage", Vector3.new(256, 5, 146) },
		{ "ParkingGarage", Vector3.new(212, 3, 92.5) },
		{ "Bathrooms", Vector3.new(-85, 3, 115) },
		{ "Bathrooms", Vector3.new(-55, 3, 115) },
		{ "Arcade", Vector3.new(-96, 4, -116) },
		{ "ToyStore", Vector3.new(96, 4, -116) },
		{ "FoodCourt", Vector3.new(-96, 4, 37) },
	}
	for _, spot in ipairs(darkSpots) do
		local center = zoneCenter(spot[1])
		local look = Vector3.new(center.X, spot[2].Y, center.Z)
		marker("Dark", spot[1], CFrame.lookAt(spot[2], look))
	end

	local lanes = {
		{ "StorageHallway", Vector3.new(95, 0, 92), 104 },
		{ "ParkingGarage", Vector3.new(210, 0, 75), 80 },
		{ "ParkingGarage", Vector3.new(210, 0, 105), 80 },
		{ "FoodCourt", Vector3.new(-65, 0, -45), 58 },
		{ "Arcade", Vector3.new(-62, 0, -60), 56 },
	}
	for _, lane in ipairs(lanes) do
		marker("RunLane", lane[1], CFrame.lookAt(lane[2], lane[2] + Vector3.xAxis), Vector3.new(1, 1, lane[3]))
	end

	marker("Skylight", "MainHall", CFrame.lookAt(Vector3.new(0, 46, 0), Vector3.new(0, 0, 0.01)))
end

---------------------------------------------------------------------------
-- Lobby + Dark Room
---------------------------------------------------------------------------

local function buildPrompt(target: BasePart, action: string, object: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = target
	return prompt
end

local function buildLobby(root: Instance)
	local c = LOBBY_CENTER
	local wallColor = Color3.fromRGB(46, 36, 34)
	local ext = EXTERIOR
	part(root, "LobbyFloor", Vector3.new(70, 1, 70), CFrame.new(c.X, -0.5, c.Z), Color3.fromRGB(70, 24, 32), Enum.Material.Fabric)
	part(root, "LobbyCeiling", Vector3.new(70, 1, 70), CFrame.new(c.X, 18.5, c.Z), Color3.fromRGB(30, 26, 26), nil, { CastShadow = false })
	wallX(root, c.X - 35, c.Z - 35, c.Z + 35, {}, ext, wallColor)
	wallX(root, c.X + 35, c.Z - 35, c.Z + 35, {}, wallColor, ext)
	wallZ(root, c.Z - 35, c.X - 35, c.X + 35, {}, ext, wallColor)
	wallZ(root, c.Z + 35, c.X - 35, c.X + 35, {}, wallColor, ext)

	for _, offset in ipairs({ Vector3.new(-8, 0, -6), Vector3.new(8, 0, -6), Vector3.new(-8, 0, 8), Vector3.new(8, 0, 8) }) do
		local spawnLocation = Instance.new("SpawnLocation")
		spawnLocation.Name = "LobbySpawn"
		spawnLocation.Anchored = true
		spawnLocation.Size = Vector3.new(6, 1, 6)
		spawnLocation.CFrame = CFrame.new(c + offset + Vector3.new(0, 0.5, 0))
		spawnLocation.Color = Color3.fromRGB(40, 40, 46)
		spawnLocation.Material = Enum.Material.SmoothPlastic
		spawnLocation.Duration = 0
		spawnLocation.Neutral = true
		spawnLocation.TopSurface = Enum.SurfaceType.Smooth
		spawnLocation.Parent = root
		local decal = spawnLocation:FindFirstChildOfClass("Decal")
		if decal then
			decal:Destroy()
		end
	end

	for _, offset in ipairs({ Vector3.new(-18, 0, -18), Vector3.new(18, 0, -18), Vector3.new(-18, 0, 18), Vector3.new(18, 0, 18) }) do
		local panel = part(root, "LobbyLight", Vector3.new(5, 0.3, 2), CFrame.new(c + offset + Vector3.new(0, 17.8, 0)), Color3.fromRGB(255, 225, 190), Enum.Material.Neon, { CanCollide = false, CanQuery = false })
		local light = Instance.new("PointLight")
		light.Range = 36
		light.Brightness = 1.1
		light.Color = Color3.fromRGB(255, 225, 190)
		light.Shadows = false
		light.Parent = panel
	end

	sign(root, "Title", c + Vector3.new(0, 14.5, -33.8), Vector3.zAxis, Vector2.new(40, 5), "CAUGHT ON CAMERA 📸", Color3.fromRGB(15, 12, 14), Color3.fromRGB(255, 80, 80))
	sign(root, "HowToPlay", c + Vector3.new(-33.8, 8, 0), Vector3.xAxis, Vector2.new(34, 10), "HOW TO PLAY\n1. EXPLORE THE DEAD MALL\n2. SPOT SOMETHING WRONG\n3. PRESS 📸 TO PHOTOGRAPH IT", Color3.fromRGB(240, 235, 220), Color3.fromRGB(30, 30, 35), Enum.Font.SpecialElite)
	sign(root, "Tips", c + Vector3.new(33.8, 8, 0), -Vector3.xAxis, Vector2.new(34, 10), "TIPS\n★ Closer + centred = better photo\n👥 Photos with friends earn bonus Evidence\n📖 Fill your ANOMALY ALBUM", Color3.fromRGB(240, 235, 220), Color3.fromRGB(30, 30, 35), Enum.Font.SpecialElite)
	sign(root, "MallDoorSign", c + Vector3.new(0, 13, 33.8), -Vector3.zAxis, Vector2.new(26, 3.5), "DEAD MALL → ROUND STARTS SOON", Color3.fromRGB(20, 20, 24), Color3.fromRGB(255, 230, 150))
	part(root, "MallDoorGlass", Vector3.new(16, 10, 0.4), CFrame.new(c + Vector3.new(0, 5, 33.6)), Color3.fromRGB(120, 150, 170), Enum.Material.Glass, { Transparency = 0.4, CanQuery = false })

	-- Dark Room entrance on the north wall
	local door = part(root, "DarkRoomDoor", Vector3.new(8, 10, 0.6), CFrame.new(c + Vector3.new(0, 5, -33.6)), Color3.fromRGB(90, 12, 18), Enum.Material.Wood, { CastShadow = false })
	sign(root, "DarkRoomSign", c + Vector3.new(0, 11, -33.8), Vector3.zAxis, Vector2.new(12, 1.8), "DARK ROOM 🎞️", Color3.fromRGB(20, 5, 8), Color3.fromRGB(255, 70, 70))
	local redLight = Instance.new("PointLight")
	redLight.Color = Color3.fromRGB(255, 40, 40)
	redLight.Range = 12
	redLight.Brightness = 1
	redLight.Parent = door
	buildPrompt(door, "Enter", "Dark Room")
	CollectionService:AddTag(door, "DarkRoomEntrance")
end

local function buildDarkRoom(root: Instance)
	local darkRoom = model(root, "DarkRoom")
	darkRoom.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local c = DARKROOM_CENTER
	local wallColor = Color3.fromRGB(45, 10, 14)
	part(darkRoom, "Floor", Vector3.new(50, 1, 40), CFrame.new(c.X, -0.5, c.Z), Color3.fromRGB(20, 18, 20), Enum.Material.Wood)
	part(darkRoom, "Ceiling", Vector3.new(50, 1, 40), CFrame.new(c.X, 14.5, c.Z), Color3.fromRGB(12, 10, 12), nil, { CastShadow = false })
	wallX(darkRoom, c.X - 25, c.Z - 20, c.Z + 20, {}, EXTERIOR, wallColor)
	wallX(darkRoom, c.X + 25, c.Z - 20, c.Z + 20, {}, wallColor, EXTERIOR)
	wallZ(darkRoom, c.Z - 20, c.X - 25, c.X + 25, {}, EXTERIOR, wallColor)
	wallZ(darkRoom, c.Z + 20, c.X - 25, c.X + 25, {}, wallColor, EXTERIOR)

	local safelight = part(darkRoom, "Safelight", Vector3.new(3, 0.4, 3), CFrame.new(c + Vector3.new(0, 14, 0)), Color3.fromRGB(255, 40, 30), Enum.Material.Neon, { CanCollide = false, CanQuery = false })
	local red = Instance.new("PointLight")
	red.Color = Color3.fromRGB(255, 50, 40)
	red.Brightness = 1.3
	red.Range = 40
	red.Shadows = false
	red.Parent = safelight

	-- Frames: 1-5 north wall, 6-8 west wall, 9-10 east wall
	local slots = {}
	for i = 1, 5 do
		table.insert(slots, { Vector3.new(c.X + (i - 3) * 9, 7, c.Z - 18.8), Vector3.zAxis })
	end
	for _, z in ipairs({ -10, 0, 10 }) do
		table.insert(slots, { Vector3.new(c.X - 23.8, 7, c.Z + z), Vector3.xAxis })
	end
	for _, z in ipairs({ -8, 8 }) do
		table.insert(slots, { Vector3.new(c.X + 23.8, 7, c.Z + z), -Vector3.xAxis })
	end
	for index, slot in ipairs(slots) do
		local base = faced(slot[1], slot[2])
		part(darkRoom, "FrameBorder", Vector3.new(7, 5.6, 0.3), base * CFrame.new(0, 0, 0.15), Color3.fromRGB(60, 40, 28), Enum.Material.Wood, { CanCollide = false })
		local canvas = part(darkRoom, "FrameCanvas", Vector3.new(6.2, 4.8, 0.1), base * CFrame.new(0, 0, -0.05), Color3.fromRGB(10, 10, 12), nil, { CanCollide = false })
		canvas:SetAttribute("Index", index)
		CollectionService:AddTag(canvas, "DarkRoomFrame")
		local lamp = part(darkRoom, "FrameLamp", Vector3.new(1.4, 0.3, 0.6), base * CFrame.new(0, 3.6, -0.8) * CFrame.Angles(math.rad(-35), 0, 0), Color3.fromRGB(30, 30, 30), Enum.Material.Metal, { CanCollide = false, CanQuery = false })
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Bottom
		spot.Angle = 70
		spot.Range = 9
		spot.Brightness = 1.4
		spot.Color = Color3.fromRGB(255, 235, 210)
		spot.Shadows = false
		spot.Parent = lamp
	end

	local nameplate = part(darkRoom, "Nameplate", Vector3.new(22, 2.2, 0.2), faced(Vector3.new(c.X, 12, c.Z - 18.8), Vector3.zAxis), Color3.fromRGB(15, 12, 12), nil, { CanCollide = false })
	CollectionService:AddTag(nameplate, "DarkRoomNameplate")

	local exitDoor = part(darkRoom, "ExitDoor", Vector3.new(7, 10, 0.6), CFrame.new(c + Vector3.new(0, 5, 18.6)), Color3.fromRGB(60, 10, 14), Enum.Material.Wood)
	sign(darkRoom, "ExitSign", c + Vector3.new(0, 11, 18.8), -Vector3.zAxis, Vector2.new(8, 1.4), "BACK TO LOBBY", Color3.fromRGB(15, 5, 8), Color3.fromRGB(255, 90, 90))
	buildPrompt(exitDoor, "Leave", "Dark Room")
	CollectionService:AddTag(exitDoor, "DarkRoomExit")

	local spawnPoint = part(darkRoom, "DarkRoomSpawn", Vector3.new(2, 1, 2), CFrame.lookAt(c + Vector3.new(0, 3, 14), c + Vector3.new(0, 3, 0)), Color3.new(), nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	spawnPoint:SetAttribute("DarkRoomSpawn", true)
end

---------------------------------------------------------------------------
-- Lighting
---------------------------------------------------------------------------

local BASE_LIGHTING = {
	ClockTime = 0,
	Brightness = 1,
	Ambient = Color3.fromRGB(78, 74, 88),
	OutdoorAmbient = Color3.fromRGB(45, 45, 60),
	FogColor = Color3.fromRGB(14, 14, 20),
	FogStart = 120,
	FogEnd = 520,
	EnvironmentDiffuseScale = 0.25,
	EnvironmentSpecularScale = 0.25,
}

local BLACKOUT_LIGHTING = {
	Brightness = 0,
	Ambient = Color3.fromRGB(10, 10, 16),
	OutdoorAmbient = Color3.fromRGB(6, 6, 10),
	EnvironmentDiffuseScale = 0,
	EnvironmentSpecularScale = 0,
}

local function setupLighting()
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Atmosphere") then
			child:Destroy() -- Atmosphere overrides fog; the mall uses fog for depth
		end
	end
	for key, value in pairs(BASE_LIGHTING) do
		(Lighting :: any)[key] = value
	end
	Lighting.GlobalShadows = true

	local grade = Lighting:FindFirstChild("BaseGrade") or Instance.new("ColorCorrectionEffect")
	grade.Name = "BaseGrade"
	grade.Saturation = -0.15
	grade.Contrast = 0.08
	grade.TintColor = Color3.fromRGB(236, 236, 255)
	grade.Parent = Lighting

	local tint = Lighting:FindFirstChild("AnomalyTint") or Instance.new("ColorCorrectionEffect")
	tint.Name = "AnomalyTint"
	tint.TintColor = Color3.new(1, 1, 1)
	tint.Saturation = 0
	tint.Contrast = 0
	tint.Parent = Lighting
	MapService.TintEffect = tint
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function MapService:Init()
	local map = folder(Workspace, "Map")
	local deadMall = folder(map, "DeadMall")
	local lobby = folder(Workspace, "Lobby")
	local spawns = folder(Workspace, "AnomalySpawns")
	self.Folders = {
		Map = map,
		DeadMall = deadMall,
		Lobby = lobby,
		AnomalySpawns = spawns,
		ActiveAnomalies = folder(Workspace, "ActiveAnomalies"),
		Decoys = folder(Workspace, "Decoys"),
	}

	if GameConfig.Map.RemoveBaseplate then
		local baseplate = Workspace:FindFirstChild("Baseplate")
		if baseplate and baseplate:IsA("BasePart") then
			baseplate:Destroy()
		end
	end
	if GameConfig.Map.RemoveStraySpawns then
		for _, descendant in ipairs(Workspace:GetDescendants()) do
			if descendant:IsA("SpawnLocation") and not descendant:IsDescendantOf(lobby) then
				descendant:Destroy()
			end
		end
	end

	if GameConfig.Map.AutoBuild then
		if #deadMall:GetChildren() == 0 then
			buildMall(deadMall)
		end
		if #lobby:GetChildren() == 0 then
			buildLobby(lobby)
			buildDarkRoom(lobby)
		end
	end
	self.Folders.NPCs = folder(deadMall, "NPCs")

	setupLighting()
	self:IndexLights()
end

function MapService:Start()
	-- Ambient flicker for lights tagged FlickerLight (cheap: one loop for all).
	task.spawn(function()
		while true do
			task.wait(math.random(15, 60) / 10)
			for _, record in ipairs(self.LightRecords) do
				if record.Flickers then
					for _ = 1, math.random(1, 3) do
						record.Flicker = true
						self:ApplyLight(record)
						task.wait(math.random(4, 12) / 100)
						record.Flicker = false
						self:ApplyLight(record)
						task.wait(math.random(4, 15) / 100)
					end
				end
			end
		end
	end)
end

function MapService:IndexLights()
	self.LightRecords = {}
	self.LightByPanel = {}
	for _, panel in ipairs(CollectionService:GetTagged("MallLight")) do
		if panel:IsA("BasePart") then
			local light = panel:FindFirstChildWhichIsA("Light")
			local record = {
				Panel = panel,
				Light = light,
				Zone = panel:GetAttribute("Zone") or "MainHall",
				OnColor = panel.Color,
				OnMaterial = panel.Material,
				Override = nil,
				Flicker = false,
				Flickers = CollectionService:HasTag(panel, "FlickerLight"),
			}
			table.insert(self.LightRecords, record)
			self.LightByPanel[panel] = record
		end
	end
end

function MapService:ApplyLight(record)
	local on = not self.Blackout and record.Override ~= false and not record.Flicker
	if record.Light then
		record.Light.Enabled = on
	end
	record.Panel.Material = if on then record.OnMaterial else Enum.Material.SmoothPlastic
	record.Panel.Color = if on then record.OnColor else Color3.fromRGB(60, 60, 64)
end

function MapService:GetZoneLights(zone: string)
	local list = {}
	for _, record in ipairs(self.LightRecords) do
		if record.Zone == zone then
			table.insert(list, record)
		end
	end
	return list
end

-- value: false = forced off, nil = normal
function MapService:SetLightOverride(record, value: boolean?)
	record.Override = value
	self:ApplyLight(record)
end

function MapService:Flicker(zone: string, times: number)
	local records = self:GetZoneLights(zone)
	task.spawn(function()
		for _ = 1, times do
			for _, record in ipairs(records) do
				self:SetLightOverride(record, false)
			end
			task.wait(math.random(6, 16) / 100)
			for _, record in ipairs(records) do
				self:SetLightOverride(record, nil)
			end
			task.wait(math.random(10, 35) / 100)
		end
	end)
end

function MapService:SetBlackout(enabled: boolean)
	self.Blackout = enabled
	for _, record in ipairs(self.LightRecords) do
		self:ApplyLight(record)
	end
	local goal = if enabled then BLACKOUT_LIGHTING else BASE_LIGHTING
	local tweenGoal = {}
	for key, value in pairs(goal) do
		if key ~= "ClockTime" and key ~= "FogStart" and key ~= "FogEnd" then
			tweenGoal[key] = value
		end
	end
	TweenService:Create(Lighting, TweenInfo.new(enabled and 0.4 or 2, Enum.EasingStyle.Quad), tweenGoal):Play()
end

-- Colour grading stack so several anomalies/events can tint the world safely.
function MapService:PushTint(key: string, tint: Color3, saturation: number?, contrast: number?)
	self:PopTint(key, true)
	table.insert(self.Tints, { Key = key, Tint = tint, Saturation = saturation or 0, Contrast = contrast or 0 })
	self:ApplyTint()
end

function MapService:PopTint(key: string, silent: boolean?)
	for index = #self.Tints, 1, -1 do
		if self.Tints[index].Key == key then
			table.remove(self.Tints, index)
		end
	end
	if not silent then
		self:ApplyTint()
	end
end

function MapService:ApplyTint()
	local effect = self.TintEffect
	if not effect then
		return
	end
	local top = self.Tints[#self.Tints]
	local goal = if top
		then { TintColor = top.Tint, Saturation = top.Saturation, Contrast = top.Contrast }
		else { TintColor = Color3.new(1, 1, 1), Saturation = 0, Contrast = 0 }
	TweenService:Create(effect, TweenInfo.new(0.8, Enum.EasingStyle.Sine), goal):Play()
end

function MapService:GetMarkers(kinds: { string }?, zones: { string }?)
	local list = {}
	for _, markerPart in ipairs(self.Folders.AnomalySpawns:GetChildren()) do
		if markerPart:IsA("BasePart") then
			local kind = markerPart:GetAttribute("Kind")
			local zone = markerPart:GetAttribute("Zone")
			local kindOk = kinds == nil or table.find(kinds, kind) ~= nil
			local zoneOk = zones == nil or table.find(zones, zone) ~= nil
			if kindOk and zoneOk then
				table.insert(list, markerPart)
			end
		end
	end
	return list
end

function MapService:GetFixtures(tag: string, zones: { string }?)
	local list = {}
	for _, fixture in ipairs(CollectionService:GetTagged(tag)) do
		if fixture:IsDescendantOf(Workspace) then
			local zone = fixture:GetAttribute("Zone")
			if zones == nil or table.find(zones, zone) ~= nil then
				table.insert(list, fixture)
			end
		end
	end
	return list
end

function MapService:GetWaypoints(lane: string?)
	local list = {}
	local waypoints = self.Folders.DeadMall:FindFirstChild("NPCWaypoints")
	if waypoints then
		for _, waypoint in ipairs(waypoints:GetChildren()) do
			if waypoint:IsA("BasePart") and (lane == nil or waypoint:GetAttribute("Lane") == lane) then
				table.insert(list, waypoint)
			end
		end
	end
	return list
end

function MapService:GetZoneAt(position: Vector3): string?
	local zones = self.Folders.DeadMall:FindFirstChild("Zones")
	if not zones then
		return nil
	end
	for _, bounds in ipairs(zones:GetChildren()) do
		if bounds:IsA("BasePart") then
			local localPoint = bounds.CFrame:PointToObjectSpace(position)
			local half = bounds.Size / 2
			if math.abs(localPoint.X) <= half.X and math.abs(localPoint.Z) <= half.Z and localPoint.Y >= -half.Y - 2 and localPoint.Y <= half.Y + 2 then
				return bounds.Name
			end
		end
	end
	return nil
end

function MapService:IsInMall(position: Vector3): boolean
	return self:GetZoneAt(position) ~= nil
end

function MapService:GetMallSpawnCFrame(): CFrame
	local spawns = self.Folders.DeadMall:FindFirstChild("PlayerSpawns")
	local list = spawns and spawns:GetChildren() or {}
	local valid = {}
	for _, spawnPart in ipairs(list) do
		if spawnPart:IsA("BasePart") then
			table.insert(valid, spawnPart)
		end
	end
	if #valid == 0 then
		return CFrame.new(0, 5, 0)
	end
	local chosen = valid[math.random(1, #valid)]
	return chosen.CFrame + Vector3.new(math.random(-20, 20) / 10, 0, math.random(-20, 20) / 10)
end

function MapService:GetLobbySpawnCFrame(): CFrame
	local valid = {}
	for _, descendant in ipairs(self.Folders.Lobby:GetDescendants()) do
		if descendant:IsA("SpawnLocation") then
			table.insert(valid, descendant)
		end
	end
	if #valid == 0 then
		return CFrame.new(LOBBY_CENTER + Vector3.new(0, 4, 0))
	end
	local chosen = valid[math.random(1, #valid)]
	return chosen.CFrame + Vector3.new(0, 3.5, 0)
end

function MapService:GetDarkRoomSpawnCFrame(): CFrame
	for _, descendant in ipairs(self.Folders.Lobby:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute("DarkRoomSpawn") then
			return descendant.CFrame
		end
	end
	return CFrame.new(DARKROOM_CENTER + Vector3.new(0, 3, 14))
end

return MapService
