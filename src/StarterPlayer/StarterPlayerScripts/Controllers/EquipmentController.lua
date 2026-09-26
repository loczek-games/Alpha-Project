--[[
	EquipmentController (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/EquipmentController

	Equipment are normal Roblox Tools in the normal Roblox backpack:
	  * the default hotbar picks them (1-9, click or tap a slot)
	  * using the held item is Tool.Activated (click / tap the screen):
	    Camera -> photo (PhotoController), Flashlight / UV / EMF / Thermal /
	    Night Vision -> on/off (EquipmentService validates every request)
	  * the held item's battery is shown above the hotbar; low/empty warnings
	  * the held camera's rear screen (REC, zoom, battery, focus) and the EMF
	    display update locally; in first person your torch beam follows
	    where you look
	  * everyone's devices are audible in 3D: EMF beeping (level 1 slow ...
	    level 5 frantic, with distortion), flashlight buzz near danger,
	    scanner and UV hums; EMF LEDs light up on the device itself
	  * your Thermal Scanner reading, UV residue reveal, Night Vision
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local EquipmentConfig = require(Config:WaitForChild("EquipmentConfig"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Net = require(Modules:WaitForChild("Net"))
local Signal = require(Modules:WaitForChild("Signal"))

local EquipmentController = {}
EquipmentController.Equipped = nil :: string?
EquipmentController.Battery = {}
EquipmentController.On = {}
EquipmentController.Failing = false
EquipmentController.EquipLockUntil = 0
EquipmentController.Changed = Signal.new()
EquipmentController.ToolAudio = {}
EquipmentController.Focus = "Idle"
EquipmentController.FocusUntil = 0
EquipmentController.ShotAt = 0
EquipmentController.ZoomFactor = 1

local player = Players.LocalPlayer

local CLICK_SOUNDS = {
	Flashlight = "Flashlight.ButtonClick",
	UVLight = "Flashlight.ButtonClick",
	EMF = "Camera.ButtonClick",
	Thermal = "Camera.ButtonClick",
	NightVision = "Camera.ButtonClick",
}

local LOW_BATTERY_SOUNDS = {
	Camera = "Camera.BatteryLow",
	Flashlight = "Flashlight.LowBattery",
	UVLight = "Flashlight.LowBattery",
	EMF = "Camera.BatteryLow",
	Thermal = "Thermal.BatteryWarning",
	NightVision = "NightVision.BatteryWarning",
}

local LIGHT_ITEMS = { Flashlight = true, UVLight = true }

function EquipmentController:Init(controllers)
	self.Controllers = controllers
	self.Remote = Net.Event("EquipmentAction")
	local UIKit = controllers.UIKit
	local hud = controllers.HUDController

	-- held item + battery, just above the Roblox hotbar
	self.BatteryLabel = UIKit.Label({
		Name = "HeldBattery",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -112),
		Size = UDim2.fromOffset(320, 22),
		Text = "",
		Font = Enum.Font.Code,
		TextSize = 16,
		TextStrokeTransparency = 0.4,
		Visible = false,
		Parent = hud.Root,
	})
	self.Readout = UIKit.Label({
		Name = "Readout",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -138),
		Size = UDim2.fromOffset(300, 30),
		Text = "",
		Font = Enum.Font.Code,
		TextSize = 22,
		TextStrokeTransparency = 0.3,
		Visible = false,
		Parent = hud.Root,
	})

	Net.Event("EquipmentState").OnClientEvent:Connect(function(state)
		if type(state) == "table" then
			self:_onState(state)
		end
	end)

	-- the Roblox backpack is the hotbar (hidden inside the Dark Room gallery)
	local function refreshBackpack()
		self:_setBackpackVisible(not controllers.ClientState.InDarkRoom)
	end
	controllers.ClientState.DarkRoomChanged:Connect(refreshBackpack)
	refreshBackpack()

	local function watchCharacter(character: Model)
		self:_setEquipped(nil)
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and child:GetAttribute("COCEquipment") then
				self:_setEquipped(child)
			end
		end)
		character.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") and child.Name == self.Equipped then
				self:_setEquipped(nil)
			end
		end)
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("COCEquipment") then
				self:_setEquipped(child)
			end
		end
	end
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
end

function EquipmentController:Start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.05 then
			return
		end
		local step = accumulator
		accumulator = 0
		local ok, err = pcall(function()
			self:_updateDevices(step)
			self:_updateOwnItems()
			self:_updateHeldScreen()
		end)
		if not ok then
			warn("[EquipmentController]", err)
		end
	end)
	-- the local torch beam must follow the camera every frame
	RunService:BindToRenderStep("COC_HeldBeam", Enum.RenderPriority.Camera.Value + 1, function()
		local ok, err = pcall(self._updateBeam, self)
		if not ok then
			warn("[EquipmentController] beam:", err)
		end
	end)
end

function EquipmentController:_setBackpackVisible(visible: boolean)
	task.spawn(function()
		for _ = 1, 10 do
			if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, visible) then
				return
			end
			task.wait(0.5)
		end
	end)
end

---------------------------------------------------------------------------
-- Held item
---------------------------------------------------------------------------

function EquipmentController:_setEquipped(tool: Tool?)
	if self.ActivatedConnection then
		self.ActivatedConnection:Disconnect()
		self.ActivatedConnection = nil
	end
	local previous = self.Equipped
	local itemId = if tool then tool.Name else nil
	self.Equipped = itemId
	self.HeldTool = tool
	local audio = self.Controllers.AudioController
	if tool and itemId ~= previous then
		local item = EquipmentConfig.Get(itemId :: string)
		if item and audio then
			audio:Play(item.Sounds .. ".Equip", nil)
		end
		self.EquipLockUntil = os.clock() + EquipmentConfig.EquipDelay
		-- click / tap with the item in hand = use it
		self.ActivatedConnection = tool.Activated:Connect(function()
			self:UseEquipped()
		end)
	elseif not tool and previous then
		local item = EquipmentConfig.Get(previous)
		if item and audio then
			audio:Play(item.Sounds .. ".Unequip", nil)
		end
	end
	self:_refreshBattery()
	self.Changed:Fire(self.Equipped)
end

-- Takes an item out of the backpack (PhotoController: Q / the touch button).
function EquipmentController:SelectItem(itemId: string)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not humanoid or not backpack then
		return
	end
	local tool = backpack:FindFirstChild(itemId)
	if tool and tool:IsA("Tool") then
		humanoid:EquipTool(tool)
	end
end

function EquipmentController:IsReady(): boolean
	return os.clock() >= self.EquipLockUntil
end

-- The held item was clicked / tapped.
function EquipmentController:UseEquipped()
	local itemId = self.Equipped
	if not itemId then
		return
	end
	if itemId == "Camera" then
		self.Controllers.PhotoController:Shoot()
	else
		self:Toggle(itemId)
	end
end

function EquipmentController:Toggle(itemId: string)
	local item = EquipmentConfig.Get(itemId)
	if not item or not item.Toggle then
		return
	end
	if not item.Wearable and (self.Equipped ~= itemId or not self:IsReady()) then
		return
	end
	-- the physical click is instant; the server decides if anything happens
	self.Controllers.AudioController:Play(CLICK_SOUNDS[itemId] or "Camera.ButtonClick", nil)
	self.Remote:FireServer("Toggle", itemId)
end

function EquipmentController:GetEquippedItem()
	return self.Equipped and EquipmentConfig.Get(self.Equipped)
end

-- PhotoController feedback for the camera's rear screen
function EquipmentController:SetFocus(state: string)
	self.Focus = state
	self.FocusUntil = os.clock() + (if state == "Error" then 2.5 else 0.6)
end

function EquipmentController:SetZoom(factor: number)
	self.ZoomFactor = factor
end

function EquipmentController:NoteShot()
	self.ShotAt = os.clock()
end

function EquipmentController:_refreshBattery()
	local item = self:GetEquippedItem()
	if not item then
		self.BatteryLabel.Visible = false
		return
	end
	local battery = math.floor(self.Battery[item.Id] or 100)
	local theme = self.Controllers.UIKit.Theme
	local on = if item.Toggle then (if self.On[item.Id] then "  ON" else "  OFF") else ""
	self.BatteryLabel.Text = string.format("%s %s%s  ·  🔋 %d%%", item.Icon, string.upper(item.Name), on, battery)
	self.BatteryLabel.TextColor3 = if battery <= EquipmentConfig.CriticalBattery then theme.Accent elseif battery <= EquipmentConfig.LowBattery then theme.Gold else theme.Text
	self.BatteryLabel.Visible = true
end

function EquipmentController:_onState(state)
	local audio = self.Controllers.AudioController
	local previous = self.Battery
	for id, value in pairs(state.Battery or {}) do
		local before = previous[id]
		if before then
			if before > EquipmentConfig.LowBattery and value <= EquipmentConfig.LowBattery and value > 0 then
				audio:Play(LOW_BATTERY_SOUNDS[id] or "Camera.BatteryLow", nil)
				local item = EquipmentConfig.Get(id)
				self.Controllers.AnnouncementController:Toast(string.format("🔋 %s battery low (%d%%)", item and item.Name or id, value), Color3.fromRGB(255, 200, 80), 2.5)
			elseif before > 0 and value <= 0 then
				audio:Play(if id == "Camera" then "Camera.BatteryEmpty" else (LOW_BATTERY_SOUNDS[id] or "Camera.BatteryEmpty"), nil)
				local item = EquipmentConfig.Get(id)
				self.Controllers.AnnouncementController:Toast(string.format("🪫 %s battery EMPTY - find a battery!", item and item.Name or id), Color3.fromRGB(255, 110, 110), 3.5)
			end
		end
	end
	self.Battery = state.Battery or {}
	local wasNV = self.On.NightVision == true
	self.On = state.On or {}
	self.Failing = state.Failing == true
	if (self.On.NightVision == true) ~= wasNV then
		self.Controllers.FxController:SetNightVision(self.On.NightVision == true)
	end
	self:_refreshBattery()
	self.Changed:Fire(self.Equipped)
end

-- The held camera's rear screen and the EMF display (local only).
function EquipmentController:_updateHeldScreen()
	local tool = self.HeldTool
	if not tool or not tool.Parent then
		return
	end
	local display = tool:FindFirstChild("Display", true)
	local background = display and display:FindFirstChild("Background")
	if not background then
		return
	end
	local now = os.clock()
	if self.Equipped == "Camera" then
		local battery = self.Battery.Camera or 100
		local focus = if now < self.FocusUntil then self.Focus else "Idle"
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
			status.Text = if now - self.ShotAt < 0.6 then "SAVED ▮" elseif focus == "Error" then "!! INTERFERENCE" else ""
		end
	elseif self.Equipped == "EMF" then
		local reading = background:FindFirstChild("Reading") :: TextLabel?
		if reading then
			local level = tool:GetAttribute("EMFLevel") or 0
			reading.Text = if self.On.EMF then string.format("%.1f mG", level * 2.3 + math.random() * 0.4) else "OFF"
		end
	end
end

-- First person: the hand-held beam points where the arm points, not where
-- you look, so your own view gets a local beam from the camera. The server
-- still decides on / off / flicker through the real beam (which everyone
-- else sees); only its brightness is hidden locally.
function EquipmentController:_updateBeam()
	local tool = self.HeldTool
	local camera = Workspace.CurrentCamera
	local real = tool and tool.Parent and LIGHT_ITEMS[tool.Name] and tool:FindFirstChild("Beam", true)
	local wanted = camera ~= nil and real ~= nil and real:IsA("SpotLight") and player:GetAttribute("InMission") == true
	if not wanted then
		if self.BeamPart then
			self.BeamPart:Destroy()
			self.BeamPart = nil
		end
		if self.HiddenBeam and self.HiddenBeam.Parent then
			local base = self.HiddenBeam:GetAttribute("BaseBrightness")
			self.HiddenBeam.Brightness = if type(base) == "number" then base else 2
		end
		self.HiddenBeam = nil
		return
	end
	local spot = real :: SpotLight
	if self.HiddenBeam ~= spot then
		self.HiddenBeam = spot
	end
	if not self.BeamPart or not self.BeamPart.Parent then
		local part = Instance.new("Part")
		part.Name = "COC_HeldBeam"
		part.Size = Vector3.new(0.1, 0.1, 0.1)
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		local light = Instance.new("SpotLight")
		light.Name = "Beam"
		light.Face = Enum.NormalId.Front
		light.Shadows = true
		light.Parent = part
		part.Parent = camera
		self.BeamPart = part
	end
	local light = self.BeamPart:FindFirstChildOfClass("SpotLight") :: SpotLight
	local base = spot:GetAttribute("BaseBrightness")
	light.Enabled = spot.Enabled
	light.Brightness = if type(base) == "number" then base else 2
	light.Range = spot.Range
	light.Angle = spot.Angle
	light.Color = spot.Color
	if spot.Brightness ~= 0 then
		spot.Brightness = 0
	end
	self.BeamPart.CFrame = (camera :: Camera).CFrame * CFrame.new(0.5, -0.5, -0.8)
end

---------------------------------------------------------------------------
-- Everyone's devices (3D audio + LEDs)
---------------------------------------------------------------------------

local function findLoop(record, key: string)
	return record.Loops[key]
end

function EquipmentController:_ensureLoop(record, key: string, path: string, parent: Instance, wanted: boolean, volume: number?)
	local audio = self.Controllers.AudioController
	local sound = findLoop(record, key)
	if wanted and not sound then
		record.Loops[key] = audio:StartLoop(path, parent, volume)
	elseif wanted and sound and volume then
		sound.Volume = volume * 0.35
	elseif not wanted and sound then
		audio:StopLoop(sound, 0.2)
		record.Loops[key] = nil
	end
end

function EquipmentController:_updateDevices(_dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local audio = self.Controllers.AudioController
	local now = os.clock()
	local seen = {}
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		if not character then
			continue
		end
		for _, tool in ipairs(character:GetChildren()) do
			if not tool:IsA("Tool") or not tool:GetAttribute("COCEquipment") then
				continue
			end
			local handle = tool:FindFirstChild("Handle")
			if not handle or not handle:IsA("BasePart") or (handle.Position - camera.CFrame.Position).Magnitude > 80 then
				continue
			end
			seen[tool] = true
			local record = self.ToolAudio[tool]
			if not record then
				record = { NextBeep = 0, Loops = {}, LastLevel = 0 }
				self.ToolAudio[tool] = record
			end
			local on = tool:GetAttribute("On") == true
			local id = tool.Name
			if id == "EMF" then
				local level = if on then (tool:GetAttribute("EMFLevel") or 0) else 0
				local distort = on and tool:GetAttribute("EMFDistort") == true
				if level > 0 and now >= record.NextBeep then
					local interval = EquipmentConfig.Items.EMF.BeepInterval[level] or 1
					if distort and math.random() < 0.45 then
						audio:Play(if math.random() < 0.5 then "EMF.Distort" else "EMF.BrokenBeep", handle)
						record.NextBeep = now + interval * (0.4 + math.random() * 1.6)
					else
						audio:Play("EMF.Level" .. level, handle)
						record.NextBeep = now + interval * (0.92 + math.random() * 0.16)
					end
				end
				record.LastLevel = level
				-- LEDs (local colour change only)
				for index = 1, 5 do
					local led = tool:FindFirstChild("LED" .. index)
					if led and led:IsA("BasePart") then
						local lit = index <= level and not (distort and math.random() < 0.3)
						led.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
						led.Color = if lit then (led:GetAttribute("OnColor") or Color3.new(1, 1, 1)) else Color3.fromRGB(40, 40, 40)
					end
				end
			elseif id == "Flashlight" or id == "UVLight" then
				local interference = tool:GetAttribute("Interference") or 0
				self:_ensureLoop(record, "Buzz", "Flashlight.Buzz", handle, on and interference >= 0.3, 0.4 + interference)
				if id == "UVLight" then
					self:_ensureLoop(record, "Hum", "UV.Hum", handle, on)
				end
			elseif id == "Thermal" then
				self:_ensureLoop(record, "Scan", "Thermal.ScanLoop", handle, on)
			end
		end
	end
	for tool, record in pairs(self.ToolAudio) do
		if not seen[tool] then
			for _, sound in pairs(record.Loops) do
				audio:StopLoop(sound, 0.2)
			end
			self.ToolAudio[tool] = nil
		end
	end
end

---------------------------------------------------------------------------
-- Your own devices: thermal reading, UV residue, night vision interference
---------------------------------------------------------------------------

local function beacons()
	local folder = Workspace:FindFirstChild("AnomalyBeacons")
	return if folder then folder:GetChildren() else {}
end

function EquipmentController:_updateOwnItems()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local audio = self.Controllers.AudioController
	local fx = self.Controllers.FxController
	local now = os.clock()
	local look = camera.CFrame.LookVector
	local origin = camera.CFrame.Position
	local readout = nil

	-- EMF readout
	if self.Equipped == "EMF" and self.On.EMF then
		local tool = player.Character and player.Character:FindFirstChild("EMF")
		local level = tool and tool:GetAttribute("EMFLevel") or 0
		readout = string.format("📟 EMF %s%s  %d", string.rep("■", level), string.rep("□", 5 - level), level)
	end

	-- Thermal scanner
	if self.Equipped == "Thermal" and self.On.Thermal then
		local config = EquipmentConfig.Items.Thermal
		local bestScore, bestUid, bestAngle, interference = 0, nil, 180, false
		for _, beacon in ipairs(beacons()) do
			if not beacon:IsA("BasePart") then
				continue
			end
			local offset = beacon.Position - origin
			local distance = offset.Magnitude
			if (beacon:GetAttribute("Danger") or 0) >= 0.7 and distance < 15 then
				interference = true
			end
			if beacon:GetAttribute("Cold") and distance < config.Range and distance > 0.1 then
				local angle = math.deg(math.acos(math.clamp(look:Dot(offset.Unit), -1, 1)))
				if angle < config.ConeDeg then
					local score = (1 - angle / config.ConeDeg) * (1 - distance / config.Range)
					if score > bestScore then
						bestScore, bestUid, bestAngle = score, beacon:GetAttribute("Uid"), angle
					end
				end
			end
		end
		local temperature = 21.4 - bestScore * 27 + math.sin(now * 3) * 0.2
		if interference and math.random() < 0.3 then
			readout = "🌡️ ERR --.-°C"
			if math.random() < 0.08 then
				audio:Play("Thermal.Interference", nil)
			end
		else
			readout = string.format("🌡️ %.1f°C", temperature)
		end
		if bestUid and bestUid ~= self.ThermalTarget then
			self.ThermalTarget = bestUid
			self.ThermalLocked = false
			audio:Play("Thermal.HeatDetected", nil)
		elseif not bestUid then
			self.ThermalTarget = nil
			self.ThermalLocked = false
		end
		if bestUid and bestAngle < config.LockDeg and not self.ThermalLocked then
			self.ThermalLocked = true
			audio:Play("Thermal.TargetLock", nil)
		end
		self.Readout.TextColor3 = Color3.fromRGB(255, 255, 255):Lerp(Color3.fromRGB(90, 170, 255), math.clamp(bestScore * 1.5, 0, 1))
	else
		self.Readout.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
	self.Readout.Text = readout or ""
	self.Readout.Visible = readout ~= nil

	-- UV residue: only visible inside your UV beam
	local residueFolder = Workspace:FindFirstChild("UVResidue")
	local uvOn = self.Equipped == "UVLight" and self.On.UVLight == true and not self.Failing
	if residueFolder and (uvOn or self.UVWasOn) then
		local config = EquipmentConfig.Items.UVLight
		local tool = player.Character and player.Character:FindFirstChild("UVLight")
		local handle = tool and tool:FindFirstChild("BeamEmitter", true)
		local beamOrigin = if handle and handle:IsA("BasePart") then handle.Position else origin
		local beamLook = if handle and handle:IsA("BasePart") then handle.CFrame.LookVector else look
		for _, residue in ipairs(residueFolder:GetChildren()) do
			if residue:IsA("BasePart") then
				local visible = false
				if uvOn then
					local offset = residue.Position - beamOrigin
					if offset.Magnitude < config.RevealRange and offset.Magnitude > 0.1 then
						visible = math.deg(math.acos(math.clamp(beamLook:Dot(offset.Unit), -1, 1))) < config.RevealConeDeg
					end
				end
				residue.Transparency = if visible then 0.1 else 1
			end
		end
	end
	self.UVWasOn = uvOn

	-- Night vision interference
	if self.On.NightVision then
		local nearest, danger = math.huge, 0
		for _, beacon in ipairs(beacons()) do
			if beacon:IsA("BasePart") then
				local distance = (beacon.Position - origin).Magnitude
				local value = beacon:GetAttribute("Danger") or 0
				if value >= 0.6 and distance < 25 and distance < nearest then
					nearest, danger = distance, value
				end
			end
		end
		if danger >= 0.9 and nearest < 12 then
			if now >= (self.NextSignalLoss or 0) then
				self.NextSignalLoss = now + 4
				audio:Play("NightVision.SignalLoss", nil)
				fx:Static(0.9, 0.8)
			end
		elseif danger > 0 and math.random() < 0.06 then
			audio:Play("NightVision.Static", nil)
			fx:Static(0.25 + danger * 0.3, 0.25)
		end
	end
end

return EquipmentController
