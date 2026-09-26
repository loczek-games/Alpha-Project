--[[
	WorldController (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/WorldController

	Client-side life of the map fixtures (cheap, distance-limited, no server
	cost):
	  FlickerLight   stuttering fluorescent panels and lamps (+ buzz)
	  EmergencyLamp  slow red pulse
	  ExitSign       rare flicker
	  MallTV         Mode = Static (analog noise) / Attract (arcade) / CCTV /
	                 Face (anomaly) / Off
	  CCTVMonitor    security room monitors: camera label, timestamp, noise
	  Escalator      steps roll while the "Running" attribute is true
	Anomalies drive these purely through attributes (Mode, Running...).
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local WorldController = {}
WorldController.Screens = {}
WorldController.Escalators = {}

local SCREEN_RANGE = 70
local FLICKER_RANGE = 140

local CAM_NAMES = { "ENTRANCE", "GRAND HALL N", "GRAND HALL S", "FOOD COURT", "SUPERMARKET", "CINEMA", "ARCADE", "TOY TOWN", "SERVICE HALL", "LOADING DOCK", "GARAGE B1", "ROOF" }

local function lightsOf(part: Instance)
	local list = {}
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("Light") then
			table.insert(list, child)
		end
	end
	return list
end

function WorldController:Init(controllers)
	self.Controllers = controllers
end

function WorldController:Start()
	task.spawn(function()
		while true do
			local ok, err = pcall(self._flickerTick, self)
			if not ok then
				warn("[WorldController] flicker:", err)
			end
			task.wait(0.05)
		end
	end)
	task.spawn(function()
		while true do
			local ok, err = pcall(self._screenTick, self)
			if not ok then
				warn("[WorldController] screens:", err)
			end
			task.wait(0.1)
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		local ok, err = pcall(self._escalatorTick, self, dt)
		if not ok then
			warn("[WorldController] escalator:", err)
		end
	end)
end

local function cameraPosition(): Vector3?
	local camera = Workspace.CurrentCamera
	return camera and camera.CFrame.Position
end

---------------------------------------------------------------------------
-- Lights
---------------------------------------------------------------------------

function WorldController:_flickerTick()
	local origin = cameraPosition()
	if not origin then
		return
	end
	local now = os.clock()
	self.FlickerState = self.FlickerState or {}
	for _, part in ipairs(CollectionService:GetTagged("FlickerLight")) do
		if not part:IsA("BasePart") or (part.Position - origin).Magnitude > FLICKER_RANGE then
			continue
		end
		local state = self.FlickerState[part]
		if not state then
			state = { Next = now + math.random() * 3, On = true, Material = part.Material, Color = part.Color, Lights = lightsOf(part) }
			self.FlickerState[part] = state
		end
		if now >= state.Next then
			local map = Workspace:FindFirstChild("ActiveMap")
			local blackout = map and map:GetAttribute("Blackout") and part:IsDescendantOf(map)
			if state.On then
				state.On = false
				state.Next = now + 0.04 + math.random() * (if math.random() < 0.15 then 0.8 else 0.12)
			else
				state.On = true
				state.Next = now + (if math.random() < 0.3 then 0.05 + math.random() * 0.1 else 0.6 + math.random() * 4)
				if math.random() < 0.08 then
					self.Controllers.AudioController:Play("Environment.LightBuzz", part, { Volume = 0.6 })
				end
			end
			local lit = state.On and not blackout
			part.Material = if lit then state.Material else Enum.Material.SmoothPlastic
			part.Color = if lit then state.Color else state.Color:Lerp(Color3.new(0.2, 0.2, 0.2), 0.7)
			for _, light in ipairs(state.Lights) do
				light.Enabled = lit
			end
		end
	end
	-- emergency lamps pulse, exit signs stutter rarely
	local pulse = 0.55 + 0.45 * math.sin(now * 2.2)
	for _, part in ipairs(CollectionService:GetTagged("EmergencyLamp")) do
		if part:IsA("BasePart") and (part.Position - origin).Magnitude < FLICKER_RANGE then
			for _, light in ipairs(lightsOf(part)) do
				local base = light:GetAttribute("BaseBrightness")
				if base == nil then
					base = light.Brightness
					light:SetAttribute("BaseBrightness", base)
				end
				light.Brightness = (base :: number) * pulse
			end
		end
	end
end

---------------------------------------------------------------------------
-- Screens (TVs, arcade attract mode, CCTV monitors)
---------------------------------------------------------------------------

local function ensureScreenGui(part: BasePart)
	local gui = part:FindFirstChild("COC_Screen")
	if gui then
		return gui
	end
	local created = Instance.new("SurfaceGui")
	created.Name = "COC_Screen"
	created.Face = Enum.NormalId.Front
	created.LightInfluence = 0
	created.Brightness = 1.2
	created.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	created.CanvasSize = Vector2.new(160, 100)
	created.ZOffset = 1
	created.MaxDistance = SCREEN_RANGE
	local noise = Instance.new("Frame")
	noise.Name = "Noise"
	noise.Size = UDim2.fromScale(1, 1)
	noise.BackgroundColor3 = Color3.fromRGB(120, 120, 124)
	noise.BorderSizePixel = 0
	noise.Parent = created
	for i = 1, 8 do
		local bar = Instance.new("Frame")
		bar.Name = "Bar" .. i
		bar.BorderSizePixel = 0
		bar.Parent = noise
	end
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.FontFace = Font.fromEnum(Enum.Font.Code)
	label.TextColor3 = Color3.fromRGB(220, 220, 220)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = ""
	label.ZIndex = 3
	label.Parent = noise
	created.Parent = part
	return created
end

local FACE = [[
   ___
  (o o)
   \_/ ]]

function WorldController:_screenTick()
	local origin = cameraPosition()
	if not origin then
		return
	end
	local now = os.clock()
	local function update(part: Instance, mode: string, feed: number?)
		if not part:IsA("BasePart") then
			return
		end
		if (part.Position - origin).Magnitude > SCREEN_RANGE then
			local existing = part:FindFirstChild("COC_Screen")
			if existing then
				(existing :: SurfaceGui).Enabled = false
			end
			return
		end
		if mode == "Off" or mode == "Torn" then
			local existing = part:FindFirstChild("COC_Screen")
			if existing then
				(existing :: SurfaceGui).Enabled = false
			end
			return
		end
		local gui = ensureScreenGui(part)
		gui.Enabled = true
		local noise = gui:FindFirstChild("Noise") :: Frame
		local label = noise:FindFirstChild("Label") :: TextLabel
		if mode == "Static" or mode == "Face" or mode == "CCTV" then
			local grey = if mode == "CCTV" then math.random(14, 30) else math.random(80, 150)
			noise.BackgroundColor3 = if mode == "CCTV" then Color3.fromRGB(grey, grey + 8, grey) else Color3.fromRGB(grey, grey, grey + 4)
			for i = 1, 8 do
				local bar = noise:FindFirstChild("Bar" .. i) :: Frame
				bar.Visible = math.random() < (if mode == "CCTV" then 0.25 else 0.8)
				bar.Position = UDim2.fromScale(0, math.random())
				bar.Size = UDim2.new(1, 0, 0, math.random(1, if mode == "CCTV" then 3 else 12))
				local shade = math.random(20, 240)
				bar.BackgroundColor3 = Color3.fromRGB(shade, shade, shade)
				bar.BackgroundTransparency = math.random() * 0.5
			end
			if mode == "Face" then
				label.Text = FACE
				label.TextColor3 = Color3.fromRGB(10, 10, 10)
				label.TextXAlignment = Enum.TextXAlignment.Center
				label.TextYAlignment = Enum.TextYAlignment.Center
			elseif mode == "CCTV" then
				local index = feed or 1
				label.TextXAlignment = Enum.TextXAlignment.Left
				label.TextYAlignment = Enum.TextYAlignment.Top
				label.TextColor3 = Color3.fromRGB(170, 240, 190)
				label.Text = string.format("CAM %02d %s\n%s %s", index, CAM_NAMES[(index - 1) % #CAM_NAMES + 1], if math.floor(now * 2) % 2 == 0 then "●REC" else "    ", os.date("!%H:%M:%S") :: string)
			else
				label.Text = ""
			end
		elseif mode == "Attract" then
			noise.BackgroundColor3 = Color3.fromRGB(6, 6, 20)
			for i = 1, 8 do
				(noise:FindFirstChild("Bar" .. i) :: Frame).Visible = false
			end
			label.TextXAlignment = Enum.TextXAlignment.Center
			label.TextYAlignment = Enum.TextYAlignment.Bottom
			label.TextColor3 = Color3.fromRGB(255, 230, 90)
			label.Text = if math.floor(now * 1.5) % 2 == 0 then "INSERT COIN" else ""
			noise.BackgroundTransparency = 0.6
		end
	end
	for _, screen in ipairs(CollectionService:GetTagged("MallTV")) do
		update(screen, screen:GetAttribute("Mode") or "Off", nil)
	end
	for _, monitor in ipairs(CollectionService:GetTagged("CCTVMonitor")) do
		update(monitor, monitor:GetAttribute("Mode") or "CCTV", monitor:GetAttribute("Feed"))
	end
end

---------------------------------------------------------------------------
-- Escalators
---------------------------------------------------------------------------

function WorldController:_escalatorRecord(escalator: Instance)
	local record = self.Escalators[escalator]
	if record then
		return record
	end
	local steps = {}
	for _, step in ipairs(escalator:GetDescendants()) do
		if step:IsA("BasePart") and step:HasTag("EscalatorStep") then
			table.insert(steps, { Part = step, T = step:GetAttribute("T") or 0, Base = step.CFrame })
		end
	end
	if #steps < 2 then
		return nil
	end
	table.sort(steps, function(a, b)
		return a.T < b.T
	end)
	local first, last = steps[1], steps[#steps]
	local perT = (last.Base.Position - first.Base.Position) / math.max(last.T - first.T, 1e-3)
	record = { Steps = steps, PerT = perT, Origin = first.Base.Position - perT * first.T, Offset = 0 }
	self.Escalators[escalator] = record
	return record
end

function WorldController:_escalatorTick(dt: number)
	local origin = cameraPosition()
	if not origin then
		return
	end
	for _, escalator in ipairs(CollectionService:GetTagged("Escalator")) do
		if not escalator:GetAttribute("Running") then
			continue
		end
		local record = self:_escalatorRecord(escalator)
		if not record then
			continue
		end
		local first = record.Steps[1].Part
		if (first.Position - origin).Magnitude > 120 then
			continue
		end
		local direction = if escalator:GetAttribute("Direction") == "Down" then -1 else 1
		record.Offset = (record.Offset + dt * 0.05 * direction) % 1
		for _, step in ipairs(record.Steps) do
			local t = (step.T + record.Offset) % 1
			local rotation = step.Base - step.Base.Position
			step.Part.CFrame = CFrame.new(record.Origin + record.PerT * t) * rotation
		end
	end
end

return WorldController
