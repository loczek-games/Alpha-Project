--[[
	JumpscareController (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/JumpscareController

	First-person jumpscares. Every major anomaly has its own style (STYLES):
	sound, how the face lunges, shake, FOV punch, blur / distortion,
	chromatic split, static, black frames, red flash, scratch marks and
	STYLISED blood (flat dark-red splatter shapes - never realistic gore).

	The attacking anomaly's real model is cloned locally and pushed right in
	front of your camera, so the face literally fills the screen with the
	map's own lighting. The CEILING CRAWLER has a full sequence:
	  ceiling noise -> silence -> the camera tilts up -> it drops -> its face
	  fills the screen -> impact -> shake + blood + distortion -> the camera
	  falls to the floor.

	Settings: BLOOD EFFECTS on/off, JUMPSCARE INTENSITY full/reduced (no
	shake, no strobing black frames, shorter, softer), Reduced Flashes.
	Always first person: the camera is borrowed from FirstPersonController
	(Suspend / Resume) and always handed back.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local JumpscareController = {}
JumpscareController.Playing = false

local player = Players.LocalPlayer

local BLOOD = Color3.fromRGB(96, 6, 10)
local BLOOD_DARK = Color3.fromRGB(52, 2, 6)

local STYLES = {
	CeilingCrawler = { Sequence = "Crawler" },
	Titan = { Sound = "Jumpscare.Titan", Lunge = { 6, 1.4 }, LungeTime = 0.22, Shake = 1.3, Fov = -18, Blur = 18, Blood = true, Scratches = true, BlackFrames = 1, Static = 0.3, Fall = true, Color = Color3.fromRGB(150, 20, 10) },
	Smile = { Sound = "Jumpscare.Smile", Lunge = { 2.4, 0.9 }, LungeTime = 0.09, Shake = 0.5, Fov = 14, Blur = 6, Chromatic = true, BlackFrames = 4, Static = 0.8, Color = Color3.fromRGB(230, 220, 200) },
	Possessed = { Sound = "Jumpscare.Possessed", Lunge = { 4, 1 }, LungeTime = 0.14, Shake = 1, Fov = -10, Blur = 12, Blood = true, Chromatic = true, RedFlash = true, BlackFrames = 2, Static = 0.5, Fall = true, Color = Color3.fromRGB(200, 30, 20) },
	Slacker = { Sound = "Jumpscare.Slacker", Lunge = { 3, 1.1 }, LungeTime = 0.3, Shake = 0.6, Fov = -6, Blur = 10, Static = 1, BlackFrames = 6, Chromatic = true, Color = Color3.fromRGB(120, 140, 160) },
	Listener = { Sound = "Anomaly.ListenerAttack", Lunge = { 3.5, 1.1 }, LungeTime = 0.12, Shake = 0.9, Fov = -12, Blur = 10, Scratches = true, RedFlash = true, Static = 0.4, Color = Color3.fromRGB(120, 10, 10) },
	Mannequin = { Sound = "Jumpscare.Impact", Lunge = { 1.6, 0.95 }, LungeTime = 0.05, Shake = 0.7, Fov = 10, Blur = 4, BlackFrames = 3, Static = 0.2, Color = Color3.fromRGB(220, 210, 190) },
	Shadow = { Sound = "Jumpscare.Screech", Lunge = { 5, 1 }, LungeTime = 0.12, Shake = 0.8, Fov = -12, Blur = 14, Static = 0.6, BlackFrames = 2, Color = Color3.fromRGB(10, 10, 12) },
	Generic = { Sound = "Jumpscare.Impact", Lunge = { 3, 1.1 }, LungeTime = 0.14, Shake = 0.8, Fov = -10, Blur = 10, Static = 0.5, RedFlash = true, BlackFrames = 1, Color = Color3.fromRGB(160, 20, 20) },
}

function JumpscareController:Init(controllers)
	self.Controllers = controllers
	local gui = Instance.new("ScreenGui")
	gui.Name = "COC_Jumpscare"
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.DisplayOrder = 60
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	self.Gui = gui
	self:_buildOverlays()
	self.Blur = Instance.new("BlurEffect")
	self.Blur.Name = "COC_JumpscareBlur"
	self.Blur.Size = 0
	self.Blur.Enabled = false
	self.Blur.Parent = Lighting
	self.Grade = Instance.new("ColorCorrectionEffect")
	self.Grade.Name = "COC_JumpscareGrade"
	self.Grade.Enabled = false
	self.Grade.Parent = Lighting
end

function JumpscareController:Preload()
	-- overlays are built in Init; sounds are preloaded by AudioController
end

---------------------------------------------------------------------------
-- Overlay construction (frames only, nothing to upload)
---------------------------------------------------------------------------

local function frame(parent: Instance, props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for key, value in pairs(props) do
		(f :: any)[key] = value
	end
	f.Parent = parent
	return f
end

function JumpscareController:_buildOverlays()
	local gui = self.Gui
	self.Red = frame(gui, { Name = "Red", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(170, 0, 0), BackgroundTransparency = 1, ZIndex = 5 })
	self.Black = frame(gui, { Name = "Black", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 20 })
	-- vignette
	self.Vignette = frame(gui, { Name = "Vignette", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(40, 0, 0), BackgroundTransparency = 1, ZIndex = 4 })
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 1),
		NumberSequenceKeypoint.new(0.7, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	gradient.Parent = self.Vignette
	-- chromatic split: red + cyan edge ghosts that jitter sideways
	self.ChromaRed = frame(gui, { Name = "ChromaRed", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 0, 40), BackgroundTransparency = 1, ZIndex = 6 })
	self.ChromaBlue = frame(gui, { Name = "ChromaBlue", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(0, 230, 255), BackgroundTransparency = 1, ZIndex = 6 })
	for _, chroma in ipairs({ self.ChromaRed, self.ChromaBlue }) do
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(0.15, 1),
			NumberSequenceKeypoint.new(0.85, 1),
			NumberSequenceKeypoint.new(1, 0.4),
		})
		g.Parent = chroma
	end
	-- static
	self.StaticHolder = frame(gui, { Name = "Static", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 8, Visible = false })
	self.StaticBars = {}
	for i = 1, 22 do
		self.StaticBars[i] = frame(self.StaticHolder, { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.5, ZIndex = 8 })
	end
	-- scratches (three claw marks)
	self.Scratches = frame(gui, { Name = "Scratches", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 9, Visible = false })
	for i = 1, 3 do
		frame(self.Scratches, {
			Name = "Claw" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.36 + i * 0.09, 0.48 + (i - 2) * 0.04),
			Size = UDim2.new(0.012, 0, 0.9, 0),
			Rotation = 28,
			BackgroundColor3 = BLOOD,
			ZIndex = 9,
		})
		frame(self.Scratches, {
			Name = "ClawEdge" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.365 + i * 0.09, 0.48 + (i - 2) * 0.04),
			Size = UDim2.new(0.004, 0, 0.86, 0),
			Rotation = 28,
			BackgroundColor3 = Color3.fromRGB(230, 200, 190),
			BackgroundTransparency = 0.3,
			ZIndex = 9,
		})
	end
	-- stylised blood: flat splats + drips around the edges
	self.BloodHolder = frame(gui, { Name = "Blood", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 7, Visible = false })
	self.Splats = {}
	for i = 1, 14 do
		local size = math.random(60, 190)
		local splat = frame(self.BloodHolder, { Name = "Splat" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size, size * math.random(60, 100) / 100), BackgroundColor3 = if i % 3 == 0 then BLOOD_DARK else BLOOD, ZIndex = 7 })
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = splat
		for d = 1, math.random(1, 3) do
			frame(splat, {
				Name = "Drip" .. d,
				Position = UDim2.new(math.random(20, 80) / 100, 0, 0.6, 0),
				Size = UDim2.new(0, math.random(6, 14), math.random(60, 160) / 100, 0),
				BackgroundColor3 = BLOOD,
				ZIndex = 7,
			})
		end
		table.insert(self.Splats, splat)
	end
	-- 2D fallback face (when the anomaly model is not available)
	local face = frame(gui, { Name = "Face", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.62, 1.05), BackgroundColor3 = Color3.fromRGB(196, 190, 176), Visible = false, ZIndex = 3 })
	local faceCorner = Instance.new("UICorner")
	faceCorner.CornerRadius = UDim.new(0.45, 0)
	faceCorner.Parent = face
	for _, x in ipairs({ 0.3, 0.7 }) do
		local socket = frame(face, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.3), Size = UDim2.fromScale(0.2, 0.07), BackgroundColor3 = Color3.fromRGB(12, 8, 8), ZIndex = 3 })
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = socket
	end
	local mouth = frame(face, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.64), Size = UDim2.fromScale(0.62, 0.4), BackgroundColor3 = Color3.fromRGB(10, 0, 0), ZIndex = 3 })
	local mc = Instance.new("UICorner")
	mc.CornerRadius = UDim.new(0.5, 0)
	mc.Parent = mouth
	for i = 1, 7 do
		frame(mouth, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(i / 8, 0), Size = UDim2.fromScale(0.06, 0.16), BackgroundColor3 = Color3.fromRGB(230, 225, 205), ZIndex = 3 })
	end
	self.Face = face
	self.FaceScale = Instance.new("UIScale")
	self.FaceScale.Parent = face
end

---------------------------------------------------------------------------
-- Settings helpers
---------------------------------------------------------------------------

function JumpscareController:_settings()
	local state = self.Controllers.ClientState
	return {
		Reduced = state:GetSetting("ReducedJumpscares") == true,
		Blood = state:GetSetting("BloodEffects") ~= false,
		Shake = state:GetSetting("ScreenShake") ~= false,
		Flashes = state:GetSetting("ReducedFlashes") ~= true,
	}
end

---------------------------------------------------------------------------
-- Effects
---------------------------------------------------------------------------

function JumpscareController:_splatter(amount: number)
	self.BloodHolder.Visible = true
	for index, splat in ipairs(self.Splats) do
		local show = index <= math.floor(#self.Splats * amount)
		splat.Visible = show
		if show then
			-- keep the centre clear: splats hug the edges
			local edge = math.random(1, 4)
			local x = if edge == 1 then math.random(0, 18) / 100 elseif edge == 2 then math.random(82, 100) / 100 else math.random(0, 100) / 100
			local y = if edge == 3 then math.random(0, 16) / 100 elseif edge == 4 then math.random(84, 100) / 100 else math.random(0, 100) / 100
			splat.Position = UDim2.fromScale(x, y)
			splat.Rotation = math.random(0, 360)
			splat.BackgroundTransparency = 0.05
			for _, drip in ipairs(splat:GetChildren()) do
				if drip:IsA("Frame") then
					drip.BackgroundTransparency = 0.05
				end
			end
		end
	end
end

function JumpscareController:_fadeOverlays(time: number)
	local info = TweenInfo.new(time, Enum.EasingStyle.Sine)
	for _, splat in ipairs(self.Splats) do
		TweenService:Create(splat, info, { BackgroundTransparency = 1 }):Play()
		for _, drip in ipairs(splat:GetChildren()) do
			if drip:IsA("Frame") then
				TweenService:Create(drip, info, { BackgroundTransparency = 1 }):Play()
			end
		end
	end
	TweenService:Create(self.Red, info, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(self.Vignette, info, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(self.ChromaRed, info, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(self.ChromaBlue, info, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(self.Blur, info, { Size = 0 }):Play()
	task.delay(time, function()
		if not self.Playing then
			self.BloodHolder.Visible = false
			self.Scratches.Visible = false
			self.Blur.Enabled = false
			self.Grade.Enabled = false
		end
	end)
end

-- runs `fn(alpha)` every frame for `duration` seconds
local function animate(duration: number, fn: (number) -> ())
	local start = os.clock()
	while true do
		local alpha = math.clamp((os.clock() - start) / duration, 0, 1)
		fn(alpha)
		if alpha >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
end

function JumpscareController:_static(level: number, duration: number)
	if level <= 0 then
		return
	end
	task.spawn(function()
		self.StaticHolder.Visible = true
		local stop = os.clock() + duration
		while os.clock() < stop do
			for i, bar in ipairs(self.StaticBars) do
				local show = math.random() < level * (0.3 + i / 40)
				bar.Visible = show
				if show then
					bar.Position = UDim2.new(math.random() * 0.2 - 0.1, 0, math.random(), 0)
					bar.Size = UDim2.new(1.2, 0, 0, math.random(2, 22))
					local shade = math.random(0, 255)
					bar.BackgroundColor3 = Color3.fromRGB(shade, shade, shade)
					bar.BackgroundTransparency = 0.2 + math.random() * 0.6
				end
			end
			task.wait(0.04)
		end
		self.StaticHolder.Visible = false
	end)
end

function JumpscareController:_blackFrames(count: number)
	task.spawn(function()
		for _ = 1, count do
			self.Black.BackgroundTransparency = 0
			task.wait(0.03 + math.random() * 0.04)
			self.Black.BackgroundTransparency = 1
			task.wait(0.05 + math.random() * 0.12)
		end
	end)
end

function JumpscareController:_chromatic(duration: number)
	task.spawn(function()
		local stop = os.clock() + duration
		while os.clock() < stop do
			local offset = math.random(-24, 24)
			self.ChromaRed.Position = UDim2.fromOffset(offset, 0)
			self.ChromaBlue.Position = UDim2.fromOffset(-offset, 0)
			self.ChromaRed.BackgroundTransparency = 0.55 + math.random() * 0.3
			self.ChromaBlue.BackgroundTransparency = 0.6 + math.random() * 0.3
			task.wait(0.03)
		end
		self.ChromaRed.BackgroundTransparency = 1
		self.ChromaBlue.BackgroundTransparency = 1
	end)
end

---------------------------------------------------------------------------
-- The attacker's face in front of the camera (local clone)
---------------------------------------------------------------------------

function JumpscareController:_findModel(uid: string?): Model?
	local active = Workspace:FindFirstChild("ActiveAnomalies")
	if not active or not uid then
		return nil
	end
	for _, child in ipairs(active:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("AnomalyUid") == uid then
			return child
		end
	end
	return nil
end

function JumpscareController:_cloneFace(source: Model?)
	if not source then
		return nil
	end
	local was = source.Archivable
	source.Archivable = true
	local ok, clone = pcall(function()
		return source:Clone()
	end)
	source.Archivable = was
	if not ok or not clone then
		return nil
	end
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.LocalTransparencyModifier = 0
			local base = descendant:GetAttribute("BaseTransparency")
			if type(base) == "number" then
				descendant.Transparency = base
			end
		elseif descendant:IsA("BaseScript") or descendant:IsA("Sound") or descendant:IsA("BillboardGui") then
			descendant:Destroy()
		elseif descendant:IsA("Constraint") or descendant:IsA("AlignPosition") or descendant:IsA("AlignOrientation") then
			descendant:Destroy()
		end
	end
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	-- the face: "Head" if there is one, otherwise the model's top
	local head = clone:FindFirstChild("Head", true)
	local focus: CFrame
	if head and head:IsA("BasePart") then
		focus = head.CFrame
	else
		local box, size = clone:GetBoundingBox()
		focus = box * CFrame.new(0, size.Y * 0.35, 0)
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 190, 170)
	light.Brightness = 1.4
	light.Range = 8
	light.Shadows = false
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	light.Parent = anchor
	anchor.Parent = clone
	return { Model = clone, Focus = focus, Light = anchor }
end

-- Places the clone so its face sits `distance` studs in front of the camera, facing it.
local function placeFace(face, camera: Camera, distance: number, jitter: Vector3?)
	local model: Model = face.Model
	local target = camera.CFrame * CFrame.new(jitter or Vector3.zero) * CFrame.new(0, 0, -distance) * CFrame.Angles(0, math.pi, 0)
	local offset = model:GetPivot():ToObjectSpace(face.Focus)
	model:PivotTo(target * offset:Inverse())
	face.Light.CFrame = camera.CFrame * CFrame.new(0, 0.4, -math.max(distance - 1.2, 0.3))
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------

function JumpscareController:Play(payload)
	if self.Playing then
		return
	end
	local kind = if type(payload) == "table" then payload.Kind else payload
	local style = STYLES[kind] or STYLES.Generic
	self.Playing = true
	local ok, err = pcall(function()
		if style.Sequence == "Crawler" then
			self:_crawler(payload)
		else
			self:_generic(payload, style)
		end
	end)
	if not ok then
		warn("[JumpscareController]", err)
	end
	self:_release()
	self.Playing = false
end

function JumpscareController:_borrowCamera(): Camera?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	self.Controllers.FirstPersonController:Suspend("Jumpscare")
	self.SavedFov = self.Controllers.FirstPersonController.BaseFieldOfView
	camera.CameraType = Enum.CameraType.Scriptable
	return camera
end

function JumpscareController:_release()
	local camera = Workspace.CurrentCamera
	if self.FaceClone then
		self.FaceClone.Model:Destroy()
		self.FaceClone = nil
	end
	if camera then
		camera.FieldOfView = self.SavedFov or 70
	end
	self.Face.Visible = false
	self.Black.BackgroundTransparency = 1
	self.StaticHolder.Visible = false
	self.Controllers.AudioController:SetDuck("Music", 1, 3)
	self.Controllers.AudioController:SetDuck("Ambience", 1, 3)
	self.Controllers.FirstPersonController:Resume("Jumpscare")
	self:_fadeOverlays(if self.Controllers.ClientState:GetSetting("ReducedJumpscares") then 0.8 else 2.5)
end

function JumpscareController:_generic(payload, style)
	local settings = self:_settings()
	local audio = self.Controllers.AudioController
	local camera = self:_borrowCamera()
	if not camera then
		return
	end
	local startCFrame = camera.CFrame
	local reduced = settings.Reduced
	audio:SetDuck("Music", 0, 0.1)
	audio:SetDuck("Ambience", 0.1, 0.1)

	-- snap the view towards the attacker
	local attackerPosition = if type(payload) == "table" and typeof(payload.Position) == "Vector3" then payload.Position else nil
	if attackerPosition then
		local look = CFrame.lookAt(startCFrame.Position, Vector3.new(attackerPosition.X, startCFrame.Position.Y + 0.3, attackerPosition.Z))
		animate(if reduced then 0.2 else 0.1, function(alpha)
			camera.CFrame = startCFrame:Lerp(look, alpha)
		end)
		startCFrame = camera.CFrame
	end

	local source = self:_findModel(if type(payload) == "table" then payload.Uid else nil)
	local face = self:_cloneFace(source)
	self.FaceClone = face
	if face then
		face.Model.Parent = camera
	else
		self.Face.Visible = true
		self.FaceScale.Scale = 0.5
	end
	audio:Play(style.Sound, nil)
	audio:Play("Jumpscare.Impact", nil, { Volume = 0.6 })
	if style.RedFlash and settings.Flashes then
		self.Red.BackgroundTransparency = if reduced then 0.75 else 0.35
	end
	self.Vignette.BackgroundTransparency = 0.2
	if not reduced then
		if style.Chromatic then
			self:_chromatic(0.9)
		end
		self:_blackFrames(style.BlackFrames or 0)
		self:_static(style.Static or 0, 0.8)
	else
		self:_static((style.Static or 0) * 0.3, 0.4)
	end
	if style.Blood and settings.Blood then
		self:_splatter(if reduced then 0.4 else 0.85)
	end
	if style.Scratches and not reduced then
		self.Scratches.Visible = true
	end
	self.Blur.Enabled = true
	self.Blur.Size = if reduced then (style.Blur or 8) * 0.4 else (style.Blur or 8)
	self.Grade.Enabled = true
	self.Grade.Contrast = if reduced then 0.1 else 0.35
	self.Grade.Saturation = -0.3
	self.Grade.TintColor = Color3.fromRGB(255, 225, 220)

	local lunge = style.Lunge or { 3, 1.1 }
	local duration = if reduced then 0.7 else 1.25
	local baseFov = self.SavedFov or 70
	local shake = if settings.Shake and not reduced then (style.Shake or 0.8) else 0
	animate(duration, function(alpha)
		local lungeAlpha = math.clamp(alpha / math.max((style.LungeTime or 0.14) / duration, 0.01), 0, 1)
		local distance = lunge[1] + (lunge[2] - lunge[1]) * (1 - (1 - lungeAlpha) ^ 3)
		local fovAlpha = math.sin(math.clamp(alpha * 2.2, 0, 1) * math.pi)
		camera.FieldOfView = baseFov + (style.Fov or 0) * fovAlpha * (if reduced then 0.4 else 1)
		local amount = shake * (1 - alpha * 0.7)
		local jitter = Vector3.new((math.random() - 0.5) * 0.35, (math.random() - 0.5) * 0.35, 0) * amount
		camera.CFrame = startCFrame * CFrame.Angles(math.rad((math.random() - 0.5) * 6 * amount), math.rad((math.random() - 0.5) * 6 * amount), math.rad((math.random() - 0.5) * 4 * amount))
		if face then
			placeFace(face, camera, distance, jitter)
		else
			self.FaceScale.Scale = 0.5 + 0.8 * lungeAlpha
			self.Face.Position = UDim2.new(0.5, jitter.X * 60, 0.52, jitter.Y * 60)
		end
	end)
	if face then
		face.Model:Destroy()
		self.FaceClone = nil
	end
	self.Face.Visible = false

	if style.Fall and payload and payload.Downed then
		self:_cameraFall(camera, settings)
	else
		self.Black.BackgroundTransparency = 0
		task.wait(if reduced then 0.1 else 0.25)
		TweenService:Create(self.Black, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
	end
end

-- The camera drops to the floor and rolls (you were knocked down).
function JumpscareController:_cameraFall(camera: Camera, settings)
	local audio = self.Controllers.AudioController
	audio:Play("Jumpscare.Fall", nil)
	audio:Play("Jumpscare.Ringing", nil)
	local from = camera.CFrame
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local floorY = if root then root.Position.Y - 2.6 else from.Position.Y - 4.5
	local to = CFrame.new(from.Position.X, floorY + 0.4, from.Position.Z) * (from - from.Position) * CFrame.Angles(math.rad(-25), 0, math.rad(if settings.Reduced then 25 else 78))
	self.Blur.Enabled = true
	animate(if settings.Reduced then 0.5 else 0.7, function(alpha)
		local eased = alpha * alpha
		camera.CFrame = from:Lerp(to, eased)
		self.Blur.Size = 8 + 16 * alpha
	end)
	TweenService:Create(self.Black, TweenInfo.new(0.6), { BackgroundTransparency = 0.15 }):Play()
	task.wait(if settings.Reduced then 0.6 else 1.1)
	TweenService:Create(self.Black, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
end

---------------------------------------------------------------------------
-- CEILING CRAWLER: the full sequence
---------------------------------------------------------------------------

function JumpscareController:_crawler(payload)
	local settings = self:_settings()
	local reduced = settings.Reduced
	local audio = self.Controllers.AudioController
	local camera = self:_borrowCamera()
	if not camera then
		return
	end
	local start = camera.CFrame
	local above = start.Position + Vector3.new(0, 7, 0)

	-- 1. ceiling noise right above you
	audio:Play("Anomaly.CeilingCreak", above)
	task.wait(0.25)
	audio:Play("Anomaly.CeilingScuttle", above)
	-- 2. ...then silence
	audio:SetDuck("Music", 0, 0.3)
	audio:SetDuck("Ambience", 0, 0.3)
	task.wait(if reduced then 0.4 else 0.9)
	audio:Play("Anomaly.DustFall", above, { Volume = 0.8 })

	-- 3. the camera slowly tilts up
	local lookUp = start * CFrame.Angles(math.rad(72), 0, 0)
	animate(if reduced then 0.35 else 0.55, function(alpha)
		local eased = alpha * alpha * (3 - 2 * alpha)
		camera.CFrame = start:Lerp(lookUp, eased)
	end)
	task.wait(if reduced then 0.1 else 0.25)

	-- 4. it drops
	local source = self:_findModel(if type(payload) == "table" then payload.Uid else nil)
	local face = self:_cloneFace(source)
	self.FaceClone = face
	if face then
		face.Model.Parent = camera
	end
	audio:Play("Jumpscare.CrawlerDrop", nil)
	local dropFrom = lookUp
	local faceView = start * CFrame.Angles(math.rad(10), 0, 0)
	animate(0.22, function(alpha)
		local eased = 1 - (1 - alpha) ^ 2
		camera.CFrame = dropFrom:Lerp(faceView, eased)
		if face then
			placeFace(face, camera, 5.5 - 4.4 * eased, Vector3.new(0, 2.5 * (1 - eased), 0))
		end
	end)

	-- 5. face fills the screen: screech, shake, blood, distortion
	audio:Play("Jumpscare.CrawlerScreech", nil)
	audio:Play("Jumpscare.Impact", nil, { Volume = 0.8 })
	if settings.Flashes then
		self.Red.BackgroundTransparency = if reduced then 0.8 else 0.45
	end
	self.Vignette.BackgroundTransparency = 0.1
	if settings.Blood then
		self:_splatter(if reduced then 0.35 else 1)
	end
	if not reduced then
		self.Scratches.Visible = true
		self:_chromatic(1.1)
		self:_blackFrames(2)
		self:_static(0.6, 1.0)
	end
	self.Blur.Enabled = true
	self.Grade.Enabled = true
	self.Grade.Contrast = if reduced then 0.1 else 0.4
	self.Grade.Saturation = -0.4
	self.Grade.TintColor = Color3.fromRGB(255, 215, 210)
	local baseFov = self.SavedFov or 70
	local shake = if settings.Shake and not reduced then 1.4 else 0
	local hold = camera.CFrame
	animate(if reduced then 0.6 else 1.0, function(alpha)
		camera.FieldOfView = baseFov - (if reduced then 6 else 20) * math.sin(math.min(alpha * 2, 1) * math.pi * 0.5)
		self.Blur.Size = (if reduced then 4 else 10) * alpha
		local amount = shake * (1 - alpha * 0.5)
		camera.CFrame = hold * CFrame.Angles(math.rad((math.random() - 0.5) * 7 * amount), math.rad((math.random() - 0.5) * 7 * amount), math.rad((math.random() - 0.5) * 5 * amount))
		if face then
			local breathe = 0.05 * math.sin(alpha * 40)
			placeFace(face, camera, 1.05 + breathe, Vector3.new((math.random() - 0.5) * 0.08 * amount, 0, 0))
		end
	end)
	if face then
		face.Model:Destroy()
		self.FaceClone = nil
	end

	-- 6. the camera falls
	self.Black.BackgroundTransparency = 0
	task.wait(0.06)
	self.Black.BackgroundTransparency = 1
	self:_cameraFall(camera, settings)
end

return JumpscareController
