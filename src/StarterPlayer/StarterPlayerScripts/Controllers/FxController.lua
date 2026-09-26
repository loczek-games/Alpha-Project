--[[
	FxController (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/FxController

	Client-side visual effects:
	  * camera flash + freeze-frame when you take a photo
	  * other players' camera flashes (you see flashes around the dark mall)
	  * Smiling Player  - creepy face on another player (never on yourself)
	  * One Behind You  - "DO NOT TURN AROUND." and it vanishes when you look
	  * Photographer    - you get photographed back, screen goes black
	  * Walking Painting - the figure moves only when YOU are not looking
	  * Sixth Sense whisper
	  * camera glitch / static (broken autofocus, night-vision interference)
	  * night vision (green grade + local light + scanlines)
	  * jumpscares when a sound-hunting anomaly catches you
	Respects the Reduced Flashes and Screen Shake settings.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"))

local FxController = {}
FxController.Smiles = {}
FxController.SmileTargets = {}
FxController.Paintings = {}

local player = Players.LocalPlayer

function FxController:Init(controllers)
	self.Controllers = controllers
	local UIKit = controllers.UIKit
	self.Overlay = UIKit.GetScreenGui("OverlayUI", 50, true)

	self.FlashFrame = UIKit.Frame({
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = self.Overlay,
	})
	self.BlackFrame = UIKit.Frame({
		Name = "Black",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 21,
		Parent = self.Overlay,
	})
	self.BlackText = UIKit.Label({
		Text = "",
		Font = UIKit.Theme.FontType,
		TextSize = 34,
		TextTransparency = 1,
		ZIndex = 22,
		Parent = self.BlackFrame,
	})
	-- Red vignette used while something is behind you.
	self.Vignette = UIKit.Frame({
		Name = "Vignette",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(120, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = self.Overlay,
	})
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.25, 1),
		NumberSequenceKeypoint.new(0.75, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	gradient.Parent = self.Vignette
	self.DoNotTurnLabel = UIKit.Label({
		Name = "DoNotTurn",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.16, 0),
		Size = UDim2.new(0.9, 0, 0, 70),
		Text = "DO NOT TURN AROUND.",
		Font = Enum.Font.Creepster,
		TextSize = 56,
		TextColor3 = Color3.fromRGB(255, 40, 40),
		TextStrokeTransparency = 0.2,
		TextTransparency = 1,
		ZIndex = 6,
		Parent = self.Overlay,
	})

	self.PhotoGrade = Instance.new("ColorCorrectionEffect")
	self.PhotoGrade.Name = "PhotoFreezeGrade"
	self.PhotoGrade.Enabled = false
	self.PhotoGrade.Parent = Lighting

	self:_buildGlitch()
	self:_buildNightVision()
	self:_buildJumpscare()

	Net.Event("AnomalyFx").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.Type == "SmilingPlayer" then
			self:_setSmile(payload.UserId, payload.On == true)
		elseif payload.Type == "DoNotTurn" then
			self:_setDoNotTurn(payload)
		elseif payload.Type == "PhotographedBack" then
			self:_photographedBack(payload)
		elseif payload.Type == "SenseHint" then
			self.Controllers.Sfx.Play("Whisper")
			self.Controllers.AnnouncementController:Toast("👂 You sense something nearby...", Color3.fromRGB(190, 140, 255), 2.5)
		elseif payload.Type == "Jumpscare" then
			self:Jumpscare(payload.Kind)
		elseif payload.Type == "FlashedBy" then
			self:_flashedBy()
		end
	end)

	Net.Event("PhotoFlash").OnClientEvent:Connect(function(photographer)
		if photographer ~= player and typeof(photographer) == "Instance" and photographer:IsA("Player") then
			self:_flashOtherCamera(photographer)
		end
	end)
end

function FxController:Start()
	local function watchPainting(painting: Instance)
		painting:GetAttributeChangedSignal("Haunted"):Connect(function()
			if painting:GetAttribute("Haunted") then
				self:_hauntPainting(painting)
			end
		end)
		if painting:GetAttribute("Haunted") then
			self:_hauntPainting(painting)
		end
	end
	for _, painting in ipairs(CollectionService:GetTagged("MallPainting")) do
		watchPainting(painting)
	end
	CollectionService:GetInstanceAddedSignal("MallPainting"):Connect(watchPainting)

	task.spawn(function()
		while true do
			task.wait(1)
			self:_maintainSmiles()
		end
	end)
end

---------------------------------------------------------------------------
-- Photo feedback
---------------------------------------------------------------------------

function FxController:Flash(strength: number?)
	local UIKit = self.Controllers.UIKit
	local reduced = self.Controllers.ClientState:GetSetting("ReducedFlashes") == true
	local peak = if reduced then 0.75 else 1 - (strength or 0.85)
	self.FlashFrame.BackgroundTransparency = peak
	UIKit.Tween(self.FlashFrame, if reduced then 0.25 else 0.35, { BackgroundTransparency = 1 })
end

-- Briefly freezes the view + desaturates it so every shot feels like a still photo.
function FxController:FreezeFrame(duration: number?)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local hold = duration or 0.16
	self.PhotoGrade.Enabled = true
	self.PhotoGrade.Saturation = -0.7
	self.PhotoGrade.Contrast = 0.25
	if camera.CameraType == Enum.CameraType.Custom and not self.Frozen then
		self.Frozen = true
		camera.CameraType = Enum.CameraType.Scriptable
		task.delay(hold, function()
			if camera.CameraType == Enum.CameraType.Scriptable then
				camera.CameraType = Enum.CameraType.Custom
			end
			self.Frozen = false
		end)
	end
	task.delay(hold + 0.1, function()
		self.PhotoGrade.Enabled = false
	end)
end

-- Someone else took a photo: their flash lights up the mall and you hear
-- the shutter in 3D from where they stand.
function FxController:_flashOtherCamera(photographer: Player)
	local character = photographer.Character
	local cameraTool = character and character:FindFirstChild("Camera")
	local bulb = cameraTool and cameraTool:FindFirstChild("FlashBulb")
	local light = bulb and bulb:FindFirstChild("Flash")
	local audio = self.Controllers.AudioController
	local source: Instance? = if bulb and bulb:IsA("BasePart") then bulb else (character and character:FindFirstChild("Head"))
	if source and source:IsA("BasePart") then
		audio:Play("Camera.Shutter", source)
		audio:Play("Camera.FlashTrigger", source)
	end
	if light and light:IsA("Light") then
		local reduced = self.Controllers.ClientState:GetSetting("ReducedFlashes") == true
		light.Brightness = if reduced then 2 else 8
		light.Enabled = true
		task.delay(0.12, function()
			light.Enabled = false
		end)
	end
end

---------------------------------------------------------------------------
-- Glitch & static (broken autofocus, night-vision interference)
---------------------------------------------------------------------------

function FxController:_buildGlitch()
	local UIKit = self.Controllers.UIKit
	self.GlitchFrame = UIKit.Frame({
		Name = "Glitch",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 15,
		Parent = self.Overlay,
	})
	self.GlitchBars = {}
	for i = 1, 14 do
		self.GlitchBars[i] = UIKit.Frame({
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.6,
			ZIndex = 15,
			Parent = self.GlitchFrame,
		})
	end
	self.GlitchGrade = Instance.new("ColorCorrectionEffect")
	self.GlitchGrade.Name = "GlitchGrade"
	self.GlitchGrade.Enabled = false
	self.GlitchGrade.Parent = Lighting
end

local GLITCH_COLORS = {
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 40, 80),
	Color3.fromRGB(40, 255, 200),
	Color3.fromRGB(20, 20, 20),
	Color3.fromRGB(120, 120, 140),
}

-- Screen-space interference: random bars + colour tearing for `duration`.
-- `intensity` 0..1 controls how much of the screen breaks up.
function FxController:Static(intensity: number, duration: number)
	local reduced = self.Controllers.ClientState:GetSetting("ReducedFlashes") == true
	intensity = math.clamp(intensity, 0, 1) * (if reduced then 0.4 else 1)
	self.StaticUntil = math.max(self.StaticUntil or 0, os.clock() + duration)
	self.StaticIntensity = math.max(if self.StaticThread then (self.StaticIntensity or 0) else 0, intensity)
	if self.StaticThread then
		return
	end
	self.GlitchFrame.Visible = true
	self.GlitchGrade.Enabled = true
	self.StaticThread = task.spawn(function()
		while os.clock() < self.StaticUntil do
			local level = self.StaticIntensity
			for i, bar in ipairs(self.GlitchBars) do
				local show = math.random() < level * (0.35 + i / 28)
				bar.Visible = show
				if show then
					bar.Position = UDim2.new(math.random() * 0.3 - 0.15, 0, math.random(), 0)
					bar.Size = UDim2.new(0.6 + math.random() * 0.8, 0, 0, math.random(2, math.floor(4 + 26 * level)))
					bar.BackgroundColor3 = GLITCH_COLORS[math.random(1, #GLITCH_COLORS)]
					bar.BackgroundTransparency = 0.25 + math.random() * 0.5
				end
			end
			self.GlitchGrade.Saturation = -level * 0.8
			self.GlitchGrade.Contrast = level * 0.4 * (math.random() * 2 - 1)
			self.GlitchGrade.TintColor = if math.random() < 0.5 then Color3.fromRGB(255, 230, 240) else Color3.fromRGB(225, 255, 250)
			task.wait(0.05)
		end
		self.GlitchFrame.Visible = false
		self.GlitchGrade.Enabled = false
		self.StaticIntensity = 0
		self.StaticThread = nil
	end)
end

function FxController:Glitch(duration: number?)
	self:Static(0.85, duration or 0.5)
end

---------------------------------------------------------------------------
-- Night vision goggles
---------------------------------------------------------------------------

function FxController:_buildNightVision()
	local UIKit = self.Controllers.UIKit
	self.NVGrade = Instance.new("ColorCorrectionEffect")
	self.NVGrade.Name = "NightVisionGrade"
	self.NVGrade.Enabled = false
	self.NVGrade.TintColor = Color3.fromRGB(120, 255, 130)
	self.NVGrade.Brightness = 0.12
	self.NVGrade.Contrast = 0.3
	self.NVGrade.Saturation = -0.6
	self.NVGrade.Parent = Lighting

	self.NVOverlay = UIKit.Frame({
		Name = "NightVision",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 4,
		Parent = self.Overlay,
	})
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.18, 1),
		NumberSequenceKeypoint.new(0.82, 1),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	gradient.Parent = self.NVOverlay
	for i = 0, 39 do
		UIKit.Frame({
			Position = UDim2.fromScale(0, i / 40),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Color3.fromRGB(0, 40, 0),
			BackgroundTransparency = 0.85,
			ZIndex = 4,
			Parent = self.NVOverlay,
		})
	end
	UIKit.Label({
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 18, 0, 70),
		Size = UDim2.fromOffset(120, 24),
		Text = "● NV",
		Font = Enum.Font.Code,
		TextSize = 20,
		TextColor3 = Color3.fromRGB(140, 255, 140),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Parent = self.NVOverlay,
	})
end

function FxController:SetNightVision(on: boolean)
	self.NVGrade.Enabled = on
	self.NVOverlay.Visible = on
	if self.NVConnection then
		self.NVConnection:Disconnect()
		self.NVConnection = nil
	end
	if self.NVLight then
		self.NVLight:Destroy()
		self.NVLight = nil
	end
	if not on then
		return
	end
	-- a light only this player sees: amplifies what's in front of the goggles
	local anchor = Instance.new("Part")
	anchor.Name = "COC_NightVisionLight"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(170, 255, 170)
	light.Brightness = 1.6
	light.Range = 40
	light.Shadows = false
	light.Parent = anchor
	anchor.Parent = Workspace.CurrentCamera or Workspace
	self.NVLight = anchor
	self.NVConnection = RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if camera and anchor.Parent then
			anchor.CFrame = camera.CFrame * CFrame.new(0, 0, -6)
		end
	end)
end

---------------------------------------------------------------------------
-- Jumpscares (sound-hunting anomalies) & the Photographer's flash
---------------------------------------------------------------------------

function FxController:_buildJumpscare()
	local UIKit = self.Controllers.UIKit
	local frame = UIKit.Frame({
		Name = "Jumpscare",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		Visible = false,
		ZIndex = 30,
		Parent = self.Overlay,
	})
	-- an eyeless, pale face with a huge dark mouth (drawn with frames: no images to upload)
	local face = UIKit.Frame({
		Name = "Face",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.62, 1.05),
		BackgroundColor3 = Color3.fromRGB(196, 190, 176),
		ZIndex = 31,
		Parent = frame,
	})
	UIKit.Corner(face, UDim.new(0.45, 0))
	for _, x in ipairs({ 0.3, 0.7 }) do
		local socket = UIKit.Frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.3),
			Size = UDim2.fromScale(0.2, 0.05),
			BackgroundColor3 = Color3.fromRGB(120, 112, 100),
			ZIndex = 32,
			Parent = face,
		})
		UIKit.Corner(socket, UDim.new(1, 0))
	end
	local mouth = UIKit.Frame({
		Name = "Mouth",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromScale(0.62, 0.42),
		BackgroundColor3 = Color3.fromRGB(10, 0, 0),
		ZIndex = 32,
		Parent = face,
	})
	UIKit.Corner(mouth, UDim.new(0.5, 0))
	for i = 1, 7 do
		UIKit.Frame({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(i / 8, 0),
			Size = UDim2.fromScale(0.06, 0.16),
			BackgroundColor3 = Color3.fromRGB(230, 225, 205),
			ZIndex = 33,
			Parent = mouth,
		})
	end
	self.ScareFrame = frame
	self.ScareFace = face
	self.ScareScale = UIKit.new("UIScale", { Parent = face })
end

function FxController:Jumpscare(kind: string?)
	local UIKit = self.Controllers.UIKit
	local state = self.Controllers.ClientState
	local reduced = state:GetSetting("ReducedFlashes") == true
	local shake = state:GetSetting("ScreenShake") == true
	local audio = self.Controllers.AudioController
	audio:Play(if kind == "Listener" then "Anomaly.ListenerAttack" else "Anomaly.Jumpscare", nil)
	self:Static(0.9, 0.5)

	local frame = self.ScareFrame
	frame.Visible = true
	frame.BackgroundTransparency = if reduced then 0.35 else 0
	self.ScareFace.Visible = not reduced -- reduced: just a dark hit + sound
	self.ScareScale.Scale = 0.6
	UIKit.Tween(self.ScareScale, 0.18, { Scale = 1.15 }, Enum.EasingStyle.Back)
	task.spawn(function()
		for _ = 1, 12 do
			if shake then
				self.ScareFace.Position = UDim2.new(0.5, math.random(-18, 18), 0.52, math.random(-12, 12))
			end
			task.wait(0.04)
		end
		self.ScareFace.Position = UDim2.fromScale(0.5, 0.52)
		UIKit.Tween(frame, 0.5, { BackgroundTransparency = 1 })
		self.ScareFace.Visible = false
		task.wait(0.5)
		frame.Visible = false
	end)
	self.Controllers.AnnouncementController:Toast("😱 IT HEARD YOU. (battery drained)", Color3.fromRGB(255, 90, 90), 3)
end

-- The Photographer flashes back at whoever is aiming a camera at it.
function FxController:_flashedBy()
	local UIKit = self.Controllers.UIKit
	local reduced = self.Controllers.ClientState:GetSetting("ReducedFlashes") == true
	self.FlashFrame.BackgroundTransparency = if reduced then 0.7 else 0
	UIKit.Tween(self.FlashFrame, if reduced then 0.3 else 0.9, { BackgroundTransparency = 1 })
	self:Static(0.5, 0.4)
end

---------------------------------------------------------------------------
-- Smiling Player (applied only on other players' screens)
---------------------------------------------------------------------------

local function buildSmile(head: BasePart): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "COC_Smile"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(100, 100)
	gui.LightInfluence = 0
	gui.Adornee = head
	local function dot(x: number, y: number, size: number, color: Color3, parent: Instance)
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromOffset(x, y)
		frame.Size = UDim2.fromOffset(size, size)
		frame.BackgroundColor3 = color
		frame.BorderSizePixel = 0
		frame.Parent = parent
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = frame
		return frame
	end
	dot(32, 36, 17, Color3.new(0, 0, 0), gui)
	dot(68, 36, 17, Color3.new(0, 0, 0), gui)
	dot(34, 34, 4, Color3.new(1, 1, 1), gui)
	dot(70, 34, 4, Color3.new(1, 1, 1), gui)
	local mouth = Instance.new("Frame")
	mouth.AnchorPoint = Vector2.new(0.5, 0)
	mouth.Position = UDim2.fromOffset(50, 56)
	mouth.Size = UDim2.fromOffset(88, 26)
	mouth.BackgroundColor3 = Color3.fromRGB(20, 0, 0)
	mouth.BorderSizePixel = 0
	mouth.Parent = gui
	local mouthCorner = Instance.new("UICorner")
	mouthCorner.CornerRadius = UDim.new(0.5, 0)
	mouthCorner.Parent = mouth
	local teeth = Instance.new("Frame")
	teeth.AnchorPoint = Vector2.new(0.5, 0)
	teeth.Position = UDim2.new(0.5, 0, 0, 3)
	teeth.Size = UDim2.new(0.86, 0, 0, 8)
	teeth.BackgroundColor3 = Color3.fromRGB(250, 250, 240)
	teeth.BorderSizePixel = 0
	teeth.Parent = mouth
	return gui
end

function FxController:_setSmile(userId: number, on: boolean)
	if userId == player.UserId then
		return -- the chosen player must never see their own smile
	end
	self:_removeSmile(userId)
	self.SmileTargets[userId] = if on then true else nil
	if on then
		self:_applySmile(userId)
	end
end

function FxController:_removeSmile(userId: number)
	local existing = self.Smiles[userId]
	if not existing then
		return
	end
	if existing.Gui then
		existing.Gui:Destroy()
	end
	if existing.Face and existing.Face.Parent then
		existing.Face.Transparency = existing.FaceTransparency
	end
	if existing.Neck and existing.Neck.Parent then
		existing.Neck.C0 = existing.NeckC0
	end
	self.Smiles[userId] = nil
end

-- Re-applies smiles whose character streamed in late / respawned.
function FxController:_maintainSmiles()
	for userId in pairs(self.SmileTargets) do
		local record = self.Smiles[userId]
		if not record or not record.Head or not record.Head.Parent then
			self:_removeSmile(userId)
			self:_applySmile(userId)
		end
	end
end

function FxController:_applySmile(userId: number)
	local target = Players:GetPlayerByUserId(userId)
	local character = target and target.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local record: any = { Head = head }
	local face = head:FindFirstChildOfClass("Decal")
	if face then
		record.Face = face
		record.FaceTransparency = face.Transparency
		face.Transparency = 1
	end
	local neck = head:FindFirstChild("Neck") or (character :: Model):FindFirstChild("Neck", true)
	if neck and neck:IsA("Motor6D") then
		record.Neck = neck
		record.NeckC0 = neck.C0
		neck.C0 = neck.C0 * CFrame.Angles(0, 0, math.rad(22))
	end
	record.Gui = buildSmile(head)
	record.Gui.Parent = player:WaitForChild("PlayerGui")
	self.Smiles[userId] = record
end

---------------------------------------------------------------------------
-- The One Behind You
---------------------------------------------------------------------------

local function setLocalHidden(model: Instance, hidden: boolean)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

function FxController:_setDoNotTurn(payload)
	local UIKit = self.Controllers.UIKit
	if self.DoNotTurnThread then
		pcall(task.cancel, self.DoNotTurnThread)
		self.DoNotTurnThread = nil
	end
	if self.DoNotTurnModel and self.DoNotTurnModel.Parent then
		setLocalHidden(self.DoNotTurnModel, false)
	end
	self.DoNotTurnModel = nil

	if not payload.On then
		UIKit.Tween(self.DoNotTurnLabel, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 })
		UIKit.Tween(self.Vignette, 0.8, { BackgroundTransparency = 1 })
		return
	end

	local model = payload.Model
	self.DoNotTurnModel = model
	self.Controllers.Sfx.Play("Heartbeat")
	self.DoNotTurnLabel.TextTransparency = 0
	self.DoNotTurnLabel.TextStrokeTransparency = 0.2
	self.DoNotTurnLabel.TextSize = 70
	UIKit.Tween(self.DoNotTurnLabel, 0.6, { TextSize = 56 }, Enum.EasingStyle.Back)
	UIKit.Tween(self.Vignette, 0.8, { BackgroundTransparency = 0.55 })
	task.delay(3, function()
		if self.DoNotTurnModel == model then
			UIKit.Tween(self.DoNotTurnLabel, 0.6, { TextSize = 30 })
		end
	end)

	self.DoNotTurnThread = task.spawn(function()
		local hidden = false
		local beat = 0
		local function findFigure(): Instance?
			local active = Workspace:FindFirstChild("ActiveAnomalies")
			if not active then
				return nil
			end
			for _, child in ipairs(active:GetChildren()) do
				if child:IsA("Model") and child:GetAttribute("AnomalyUid") == payload.Uid then
					return child
				end
			end
			return nil
		end
		while self.DoNotTurnModel == model do
			if typeof(model) ~= "Instance" or not model.Parent then
				-- not streamed in yet (or first payload arrived before the model)
				local found = findFigure()
				if found then
					model = found
					self.DoNotTurnModel = found
				end
			end
			local camera = Workspace.CurrentCamera
			if typeof(model) == "Instance" and model.Parent and camera then
				local pivot = (model :: Model):GetPivot().Position + Vector3.new(0, 5, 0)
				local toFigure = pivot - camera.CFrame.Position
				local looking = toFigure.Magnitude < 80 and camera.CFrame.LookVector:Dot(toFigure.Unit) > 0.45
				if looking ~= hidden then
					hidden = looking
					setLocalHidden(model, hidden)
					if hidden then
						self.Controllers.AnnouncementController:Toast("...nothing there?", Color3.fromRGB(200, 200, 200), 1.5)
					end
				end
			end
			beat += 1
			if beat % 12 == 0 then
				self.Controllers.Sfx.Play("Heartbeat")
			end
			task.wait(0.1)
		end
	end)
end

---------------------------------------------------------------------------
-- The Photographer took YOUR photo
---------------------------------------------------------------------------

function FxController:_photographedBack(payload)
	local UIKit = self.Controllers.UIKit
	local reduced = self.Controllers.ClientState:GetSetting("ReducedFlashes") == true
	self.Controllers.Sfx.Play("Shutter", 0.7)
	if not reduced then
		self.FlashFrame.BackgroundTransparency = 0
		UIKit.Tween(self.FlashFrame, 0.2, { BackgroundTransparency = 1 })
	end
	task.delay(if reduced then 0 else 0.15, function()
		self.BlackFrame.BackgroundTransparency = if reduced then 0.1 else 0
		self.BlackText.Text = "📸 IT TOOK YOUR PICTURE."
		self.BlackText.TextTransparency = 0
		task.wait(1.7)
		UIKit.Tween(self.BlackFrame, 0.6, { BackgroundTransparency = 1 })
		UIKit.Tween(self.BlackText, 0.6, { TextTransparency = 1 })
		if payload.NewAchievement then
			task.wait(0.6)
			self.Controllers.AnnouncementController:Banner("🏅 SPECIAL DISCOVERY", "PHOTOGRAPHED BACK", Color3.fromRGB(255, 215, 90), 3)
		end
	end)
end

---------------------------------------------------------------------------
-- Walking Painting: move the figure only while this player isn't looking
---------------------------------------------------------------------------

local FIGURE_SPOTS = {
	{ UDim2.fromScale(0.55, 0.8), UDim2.fromOffset(34, 86) },
	{ UDim2.fromScale(0.3, 0.84), UDim2.fromOffset(44, 112) },
	{ UDim2.fromScale(0.82, 0.76), UDim2.fromOffset(28, 70) },
	{ UDim2.fromScale(0.62, 0.95), UDim2.fromOffset(60, 150) },
	{ UDim2.fromScale(0.45, 1.05), UDim2.fromOffset(90, 220) },
}

function FxController:_hauntPainting(painting: Instance)
	if self.Paintings[painting] then
		return
	end
	self.Paintings[painting] = true
	task.spawn(function()
		local canvasPart = painting:FindFirstChild("Canvas")
		local gui = canvasPart and canvasPart:FindFirstChild("Canvas")
		local figure = gui and gui:FindFirstChild("Figure")
		if not (canvasPart and canvasPart:IsA("BasePart") and figure and figure:IsA("Frame")) then
			self.Paintings[painting] = nil
			return
		end
		local spot = 1
		local lookedAway = 0
		local seenSinceMove = false
		figure.Position = FIGURE_SPOTS[1][1]
		figure.Size = FIGURE_SPOTS[1][2]
		while painting.Parent and painting:GetAttribute("Haunted") do
			local camera = Workspace.CurrentCamera
			local looking = false
			if camera then
				local _, onScreen = camera:WorldToViewportPoint(canvasPart.Position)
				local distance = (camera.CFrame.Position - canvasPart.Position).Magnitude
				looking = onScreen and distance < 90
			end
			if looking then
				lookedAway = 0
				seenSinceMove = true
			else
				lookedAway += 0.25
				if seenSinceMove and lookedAway >= 0.75 then
					-- step closer each time you look away
					spot = math.min(spot + 1, #FIGURE_SPOTS)
					figure.Position = FIGURE_SPOTS[spot][1]
					figure.Size = FIGURE_SPOTS[spot][2]
					seenSinceMove = false
				end
			end
			task.wait(0.25)
		end
		self.Paintings[painting] = nil
	end)
end

return FxController
