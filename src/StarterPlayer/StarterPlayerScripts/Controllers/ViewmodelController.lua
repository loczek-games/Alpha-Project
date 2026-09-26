--[[
	ViewmodelController (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/ViewmodelController

	First-person viewmodel: your arms holding the equipped Camera /
	Flashlight / EMF / Thermal / UV light in front of the camera.

	  * The held item is a clone of your real Tool (built by EquipmentModels on
	    the server, so skins always match). The real tool is hidden locally.
	  * Procedural animations: equip, unequip, idle breathing, walk bob, sprint,
	    aim (camera raised to the eye while zoomed), photo recoil, zoom ring,
	    battery swap, look sway.
	  * The camera's rear screen shows zoom, battery, focus, REC and
	    interference; the EMF LCD shows the reading.
	Only active in missions (first person). Everyone else sees the normal
	third-person tool.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local EquipmentConfig = require(Config:WaitForChild("EquipmentConfig"))

local ViewmodelController = {}
ViewmodelController.Item = nil :: string?
ViewmodelController.Model = nil :: Model?
ViewmodelController.Zoomed = false
ViewmodelController.Focus = "Idle"
ViewmodelController.FocusUntil = 0

local player = Players.LocalPlayer

-- where each item sits in camera space (x right, y up, -z forward)
local HOLD = {
	Camera = { Rest = CFrame.new(0.28, -0.62, -1.55) * CFrame.Angles(math.rad(4), math.rad(-4), 0), Aim = CFrame.new(0.06, -0.3, -1.05), TwoHands = true },
	Flashlight = { Rest = CFrame.new(0.78, -0.72, -1.55) * CFrame.Angles(math.rad(2), math.rad(3), 0), Aim = CFrame.new(0.6, -0.62, -1.5), TwoHands = false },
	UVLight = { Rest = CFrame.new(0.78, -0.72, -1.55) * CFrame.Angles(math.rad(2), math.rad(3), 0), Aim = CFrame.new(0.6, -0.62, -1.5), TwoHands = false },
	EMF = { Rest = CFrame.new(0.62, -0.95, -1.45) * CFrame.Angles(math.rad(-12), math.rad(-8), 0), Aim = CFrame.new(0.4, -0.8, -1.3) * CFrame.Angles(math.rad(-12), 0, 0), TwoHands = false },
	Thermal = { Rest = CFrame.new(0.42, -0.78, -1.4) * CFrame.Angles(math.rad(-4), 0, 0), Aim = CFrame.new(0.2, -0.55, -1.2), TwoHands = true },
}

local SLEEVE = Color3.fromRGB(34, 36, 40)
local GLOVE = Color3.fromRGB(26, 26, 28)

local function lerpCFrame(a: CFrame, b: CFrame, t: number): CFrame
	return a:Lerp(b, math.clamp(t, 0, 1))
end

local function makePart(parent: Instance, name: string, size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

function ViewmodelController:Init(controllers)
	self.Controllers = controllers
	self.Bob = 0
	self.Sway = CFrame.identity
	self.Recoil = 0
	self.EquipAlpha = 0
	self.AimAlpha = 0
	self.SprintAlpha = 0
	self.BatterySwap = 0
	self.LastCameraCFrame = nil
	controllers.EquipmentController.Changed:Connect(function()
		self:_sync()
	end)
	player:GetAttributeChangedSignal("InMission"):Connect(function()
		self:_sync()
	end)
end

function ViewmodelController:Start()
	RunService:BindToRenderStep("COC_Viewmodel", Enum.RenderPriority.Camera.Value + 2, function(dt)
		local ok, err = pcall(self._render, self, dt)
		if not ok then
			warn("[ViewmodelController]", err)
		end
	end)
end

function ViewmodelController:Preload()
	-- nothing to download: models are built from parts
end

---------------------------------------------------------------------------
-- API used by PhotoController / EquipmentController
---------------------------------------------------------------------------

function ViewmodelController:SetZoom(zoomed: boolean, factor: number?)
	self.Zoomed = zoomed
	self.ZoomFactor = if zoomed then (factor or 2) else 1
	self.ZoomRingTurn = (self.ZoomRingTurn or 0) + (if zoomed then 1 else -1)
end

function ViewmodelController:SetFocus(state: string)
	self.Focus = state
	self.FocusUntil = os.clock() + (if state == "Error" then 2.5 else 0.6)
end

function ViewmodelController:Shutter()
	self.Recoil = 1
	self.ShotAt = os.clock()
end

function ViewmodelController:BatteryChange()
	self.BatterySwap = 1
end

---------------------------------------------------------------------------
-- Building / tearing down
---------------------------------------------------------------------------

function ViewmodelController:_wanted(): string?
	if player:GetAttribute("InMission") ~= true then
		return nil
	end
	local item = self.Controllers.EquipmentController.Equipped
	if item and HOLD[item] then
		return item
	end
	return nil
end

function ViewmodelController:_findTool(itemId: string): Tool?
	local character = player.Character
	local tool = character and character:FindFirstChild(itemId)
	return if tool and tool:IsA("Tool") then tool else nil
end

function ViewmodelController:_hideRealTool(tool: Tool, hidden: boolean)
	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = if hidden then 1 else 0
		elseif descendant:IsA("SurfaceGui") then
			descendant.Enabled = not hidden
		end
	end
end

function ViewmodelController:_sync()
	local wanted = self:_wanted()
	if wanted == self.Item and self.Model and self.Model.Parent then
		return
	end
	self:_destroy()
	if not wanted then
		return
	end
	local tool = self:_findTool(wanted)
	if not tool then
		return
	end
	local wasArchivable = tool.Archivable
	tool.Archivable = true
	local ok, clone = pcall(function()
		return tool:Clone()
	end)
	tool.Archivable = wasArchivable
	if not ok or not clone then
		return
	end
	local model = Instance.new("Model")
	model.Name = "COC_Viewmodel"
	local item = Instance.new("Model")
	item.Name = "Item"
	for _, child in ipairs(clone:GetChildren()) do
		child.Parent = item
	end
	clone:Destroy()
	for _, descendant in ipairs(item:GetDescendants()) do
		if descendant:IsA("Light") or descendant:IsA("BaseScript") or descendant:IsA("Sound") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.CastShadow = false
			descendant.CanQuery = false
			descendant.LocalTransparencyModifier = 0
		end
	end
	local handle = item:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		model:Destroy()
		return
	end
	handle.Anchored = true
	item.PrimaryPart = handle
	item.Parent = model

	-- arms: sleeve + glove on each side
	local skin = Color3.fromRGB(200, 160, 130)
	local character = player.Character
	local colors = character and character:FindFirstChildOfClass("BodyColors")
	if colors then
		skin = colors.RightArmColor3
	end
	self.Arms = {}
	for _, side in ipairs({ "Right", "Left" }) do
		local sleeve = makePart(model, side .. "Sleeve", Vector3.new(0.38, 0.38, 1.6), SLEEVE, Enum.Material.Fabric)
		local hand = makePart(model, side .. "Hand", Vector3.new(0.34, 0.26, 0.42), GLOVE, Enum.Material.Fabric)
		local wrist = makePart(model, side .. "Wrist", Vector3.new(0.3, 0.3, 0.12), skin, Enum.Material.SmoothPlastic)
		self.Arms[side] = { Sleeve = sleeve, Hand = hand, Wrist = wrist }
	end
	model.Parent = Workspace.CurrentCamera
	self.Model = model
	self.ItemModel = item
	self.Item = wanted
	self.RealTool = tool
	self.EquipAlpha = 0
	self.Display = item:FindFirstChild("Display", true)
	self:_hideRealTool(tool, true)
end

function ViewmodelController:_destroy()
	if self.RealTool and self.RealTool.Parent then
		self:_hideRealTool(self.RealTool, false)
	end
	if self.Model then
		self.Model:Destroy()
	end
	self.Model = nil
	self.ItemModel = nil
	self.Item = nil
	self.RealTool = nil
	self.Display = nil
end

---------------------------------------------------------------------------
-- Per-frame animation
---------------------------------------------------------------------------

local function placeArm(arm, shoulder: Vector3, hand: Vector3, cameraCFrame: CFrame)
	local direction = hand - shoulder
	local length = math.max(direction.Magnitude - 0.2, 0.3)
	local armCFrame = CFrame.lookAt(shoulder, hand) * CFrame.new(0, 0, -length / 2)
	arm.Sleeve.Size = Vector3.new(0.38, 0.38, length)
	arm.Sleeve.CFrame = cameraCFrame * armCFrame
	arm.Wrist.CFrame = cameraCFrame * CFrame.lookAt(shoulder, hand) * CFrame.new(0, 0, -length - 0.02)
	arm.Hand.CFrame = cameraCFrame * CFrame.lookAt(shoulder, hand) * CFrame.new(0, 0, -length - 0.26)
end

function ViewmodelController:_render(dt: number)
	local wanted = self:_wanted()
	local fp = self.Controllers.FirstPersonController
	if wanted ~= self.Item or (self.Model and not self.Model.Parent) then
		self:_sync()
	end
	local model = self.Model
	local camera = Workspace.CurrentCamera
	if not model or not camera or not self.ItemModel then
		return
	end
	local visible = not fp:IsSuspended() and player:GetAttribute("Downed") ~= true
	if not visible then
		model.Parent = nil
		return
	elseif model.Parent ~= camera then
		model.Parent = camera
	end
	if self.RealTool and self.RealTool.Parent then
		-- keep the real tool hidden (respawns / re-equips reset it)
		local handle = self.RealTool:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") and handle.LocalTransparencyModifier < 1 then
			self:_hideRealTool(self.RealTool, true)
		end
	end

	local hold = HOLD[self.Item]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local speed = if root then Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude else 0
	local running = speed > 20
	local grounded = humanoid ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air

	-- blend states
	self.EquipAlpha = math.min(1, self.EquipAlpha + dt / 0.28)
	self.AimAlpha += ((if self.Zoomed then 1 else 0) - self.AimAlpha) * math.min(1, dt * 10)
	self.SprintAlpha += ((if running and not self.Zoomed then 1 else 0) - self.SprintAlpha) * math.min(1, dt * 6)
	self.Recoil = math.max(0, self.Recoil - dt * 7)
	self.BatterySwap = math.max(0, self.BatterySwap - dt / 1.1)

	-- bob (walk), breathing (idle)
	local moving = speed > 1 and grounded
	self.Bob += dt * (if running then 11 else 7.5) * (if moving then 1 else 0)
	local bobAmount = if moving then (if running then 0.07 else 0.035) * (1 - self.AimAlpha * 0.7) else 0
	local breath = math.sin(os.clock() * 1.6) * 0.012
	local bob = CFrame.new(math.cos(self.Bob) * bobAmount, math.abs(math.sin(self.Bob)) * bobAmount + breath, 0)

	-- sway: lag behind camera rotation
	local last = self.LastCameraCFrame or camera.CFrame
	local delta = last:ToObjectSpace(camera.CFrame)
	local rx, ry = delta:ToEulerAnglesXYZ()
	local targetSway = CFrame.Angles(math.clamp(rx, -0.12, 0.12) * 0.6, math.clamp(ry, -0.12, 0.12) * 0.6, 0)
	self.Sway = self.Sway:Lerp(targetSway, math.min(1, dt * 12))
	self.LastCameraCFrame = camera.CFrame

	local pose = lerpCFrame(hold.Rest, hold.Aim, self.AimAlpha)
	-- sprint: lower + tilt the device
	pose = pose * CFrame.new(0.1 * self.SprintAlpha, -0.25 * self.SprintAlpha, 0.1 * self.SprintAlpha) * CFrame.Angles(math.rad(-18) * self.SprintAlpha, math.rad(22) * self.SprintAlpha, 0)
	-- equip: rise from below
	local equip = 1 - (1 - self.EquipAlpha) ^ 3
	pose = CFrame.new(0, -1.1 * (1 - equip), 0.3 * (1 - equip)) * pose * CFrame.Angles(math.rad(-40) * (1 - equip), 0, 0)
	-- photo recoil: kick up + back
	local recoil = self.Recoil ^ 2
	pose = pose * CFrame.new(0, 0.05 * recoil, 0.12 * recoil) * CFrame.Angles(math.rad(6) * recoil, 0, 0)
	-- battery swap: dip and rotate
	local swap = math.sin(self.BatterySwap * math.pi)
	pose = pose * CFrame.new(0, -0.35 * swap, 0) * CFrame.Angles(math.rad(35) * swap, 0, math.rad(-25) * swap)
	-- downed / taken: nothing to render (handled by visibility)

	local final = bob * self.Sway * pose
	local cameraCFrame = camera.CFrame
	self.ItemModel:PivotTo(cameraCFrame * final)

	-- arms from off-screen shoulders to the grip
	local arms = self.Arms
	if arms then
		local handleCFrame = final
		local rightHand = (handleCFrame * CFrame.new(0.05, -0.18, 0.2)).Position
		placeArm(arms.Right, Vector3.new(0.95, -1.6, 0.8), rightHand, cameraCFrame)
		local leftVisible = hold.TwoHands
		for _, part in pairs(arms.Left) do
			part.Transparency = if leftVisible then 0 else 1
		end
		if leftVisible then
			local support = if self.Item == "Camera" then (handleCFrame * CFrame.new(-0.62, -0.22, -0.45)).Position else (handleCFrame * CFrame.new(-0.35, -0.2, 0)).Position
			placeArm(arms.Left, Vector3.new(-0.95, -1.6, 0.8), support, cameraCFrame)
		end
	end

	self:_updateScreens()
end

---------------------------------------------------------------------------
-- Device screens
---------------------------------------------------------------------------

function ViewmodelController:_danger(): number
	local camera = Workspace.CurrentCamera
	local beacons = Workspace:FindFirstChild("AnomalyBeacons")
	if not camera or not beacons then
		return 0
	end
	local strongest = 0
	for _, beacon in ipairs(beacons:GetChildren()) do
		if beacon:IsA("BasePart") then
			local distance = (beacon.Position - camera.CFrame.Position).Magnitude
			if distance < EquipmentConfig.InterferenceRadius then
				strongest = math.max(strongest, (beacon:GetAttribute("Danger") or 0) * (1 - distance / EquipmentConfig.InterferenceRadius))
			end
		end
	end
	return strongest
end

function ViewmodelController:_updateScreens()
	local display = self.Display
	if not display then
		return
	end
	local background = display:FindFirstChild("Background")
	if not background then
		return
	end
	local equipment = self.Controllers.EquipmentController
	local now = os.clock()
	if self.Item == "Camera" then
		local battery = equipment.Battery.Camera or 100
		local focus = if now < self.FocusUntil then self.Focus else "Idle"
		local danger = self:_danger()
		local top = background:FindFirstChild("Top") :: TextLabel?
		local zoom = background:FindFirstChild("Zoom") :: TextLabel?
		local batteryLabel = background:FindFirstChild("Battery") :: TextLabel?
		local status = background:FindFirstChild("Status") :: TextLabel?
		if top then
			local rec = if math.floor(now * 2) % 2 == 0 then "● REC" else "  REC"
			top.Text = rec .. (if focus == "Focusing" then "  AF ▣" elseif focus == "Error" then "  AF ERR" else "  AF")
			top.TextColor3 = if focus == "Error" then Color3.fromRGB(255, 70, 60) else Color3.fromRGB(150, 230, 170)
		end
		if zoom then
			zoom.Text = string.format("x%.1f", self.ZoomFactor or 1)
		end
		if batteryLabel then
			batteryLabel.Text = string.format("BAT %d%%", math.floor(battery))
			batteryLabel.TextColor3 = if battery <= EquipmentConfig.LowBattery then Color3.fromRGB(255, 90, 70) else Color3.fromRGB(150, 230, 170)
		end
		if status then
			if danger > 0.25 then
				status.Text = if math.random() < 0.5 then "!! INTERFERENCE" else "!! S1GN4L"
				status.TextColor3 = Color3.fromRGB(255, 70, 60)
			elseif self.ShotAt and now - self.ShotAt < 0.6 then
				status.Text = "SAVED ▮"
				status.TextColor3 = Color3.fromRGB(230, 230, 230)
			else
				status.Text = ""
			end
		end
		background.BackgroundColor3 = if danger > 0.4 and math.random() < danger * 0.3 then Color3.fromRGB(40, 40, 40) else Color3.fromRGB(6, 10, 8)
	elseif self.Item == "EMF" then
		local tool = self.RealTool
		local level = tool and tool:GetAttribute("EMFLevel") or 0
		local on = equipment.On.EMF == true
		local reading = background:FindFirstChild("Reading") :: TextLabel?
		if reading then
			reading.Text = if on then string.format("%.1f mG", level * 2.3 + math.random() * 0.4) else "OFF"
		end
		if self.ItemModel then
			for index = 1, 5 do
				local led = self.ItemModel:FindFirstChild("LED" .. index)
				if led and led:IsA("BasePart") then
					local lit = on and index <= level
					led.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
					led.Color = if lit then (led:GetAttribute("OnColor") or Color3.new(1, 1, 1)) else Color3.fromRGB(40, 40, 40)
				end
			end
		end
	end
	-- flashlight lens glow follows the real tool
	if (self.Item == "Flashlight" or self.Item == "UVLight") and self.ItemModel and self.RealTool then
		local lens = self.ItemModel:FindFirstChild("Lens")
		local realLens = self.RealTool:FindFirstChild("Lens")
		if lens and realLens and lens:IsA("BasePart") and realLens:IsA("BasePart") then
			lens.Material = realLens.Material
			lens.Color = realLens.Color
		end
	end
end

return ViewmodelController
