--[[
	EquipmentController (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/EquipmentController

	Hotbar + equipment feel on the client.
	  * Hotbar (bottom centre): tap a slot or press 1-6. Switching plays the
	    unequip -> handling -> equip sounds and the item is usable after a
	    short delay (no instant teleporting items).
	  * The big action button uses the held item (PhotoController asks us).
	  * Battery bars, low/empty battery warnings.
	  * Everyone's devices are audible in 3D: EMF beeping (level 1 slow ...
	    level 5 frantic, with distortion), flashlight buzz near danger,
	    scanner and UV hums. EMF LEDs light up on the device itself.
	  * Your Thermal Scanner reading, UV residue reveal, Night Vision.
	All actions are only requests - EquipmentService validates them.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
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
EquipmentController.Slots = {}

local player = Players.LocalPlayer

local KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
}

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

function EquipmentController:Init(controllers)
	self.Controllers = controllers
	self.Remote = Net.Event("EquipmentAction")
	local UIKit = controllers.UIKit
	local hud = controllers.HUDController

	self.Hotbar = UIKit.Frame({
		Name = "Hotbar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(400, 66),
		BackgroundTransparency = 1,
		Parent = hud.Root,
	})
	UIKit.List(self.Hotbar, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom)

	self.Readout = UIKit.Label({
		Name = "Readout",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -84),
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
	controllers.ClientState.DataChanged:Connect(function()
		self:_buildSlots()
	end)
	-- usable everywhere: at HQ too (photos only count during investigations,
	-- batteries only drain on missions); hidden inside the Dark Room gallery
	local function refreshVisibility()
		self.Hotbar.Visible = not controllers.ClientState.InDarkRoom
	end
	controllers.ClientState.RoundChanged:Connect(refreshVisibility)
	controllers.ClientState.DarkRoomChanged:Connect(refreshVisibility)
	refreshVisibility()

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or controllers.ClientState.InDarkRoom then
			return
		end
		local index = KEYS[input.KeyCode]
		if index then
			self:SelectSlot(index)
		elseif input.KeyCode == Enum.KeyCode.ButtonR1 then
			self:Cycle(1)
		elseif input.KeyCode == Enum.KeyCode.ButtonL1 then
			self:Cycle(-1)
		end
	end)
	-- mouse wheel switches items (in first person the cursor is locked, so
	-- the hotbar cannot be clicked)
	UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if gameProcessed or controllers.ClientState.InDarkRoom or controllers.UIKit.IsAnyPanelOpen() then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseWheel and input.Position.Z ~= 0 then
			local now = os.clock()
			if now - (self.LastWheel or 0) > 0.15 then
				self.LastWheel = now
				self:Cycle(if input.Position.Z < 0 then 1 else -1)
			end
		end
	end)

	local function watchCharacter(character: Model)
		self.Equipped = nil
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and child:GetAttribute("COCEquipment") then
				self.Equipped = child.Name
				self:_refreshSlots()
				self.Changed:Fire(self.Equipped)
			end
		end)
		character.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") and child.Name == self.Equipped then
				self.Equipped = nil
				self:_refreshSlots()
				self.Changed:Fire(nil)
			end
		end)
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("COCEquipment") then
				self.Equipped = child.Name
			end
		end
		self.Changed:Fire(self.Equipped)
	end
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
end

function EquipmentController:Start()
	self:_buildSlots()
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
		end)
		if not ok then
			warn("[EquipmentController]", err)
		end
	end)
end

---------------------------------------------------------------------------
-- Hotbar
---------------------------------------------------------------------------

function EquipmentController:GetOwnedItems()
	local data = self.Controllers.ClientState.Data
	local list = {}
	for _, item in ipairs(EquipmentConfig.GetSorted()) do
		local owned = item.Price == 0 or (data and data.OwnedEquipment and data.OwnedEquipment[item.Id])
		if owned then
			table.insert(list, item)
		end
	end
	return list
end

function EquipmentController:_buildSlots()
	local UIKit = self.Controllers.UIKit
	local theme = UIKit.Theme
	local owned = self:GetOwnedItems()
	local signature = ""
	for _, item in ipairs(owned) do
		signature ..= item.Id .. ","
	end
	if signature == self.SlotSignature then
		self:_refreshSlots()
		return
	end
	self.SlotSignature = signature
	for _, slot in pairs(self.Slots) do
		slot.Button:Destroy()
	end
	self.Slots = {}
	local touch = UIKit.IsTouch()
	for index, item in ipairs(owned) do
		local button = UIKit.Button({
			Name = item.Id,
			LayoutOrder = index,
			Size = UDim2.fromOffset(58, 58),
			BackgroundColor3 = theme.Bg,
			BackgroundTransparency = 0.25,
			CornerRadius = 14,
			NoStroke = true, -- the selection stroke below is the only one
			Parent = self.Hotbar,
		}, function()
			self:SelectSlot(index)
		end)
		local stroke = UIKit.Stroke(button, theme.Stroke, 2, 0.3)
		UIKit.Label({ Text = item.Icon, TextSize = 28, Size = UDim2.new(1, 0, 1, -8), Parent = button })
		if not touch then
			UIKit.Label({
				Text = tostring(index),
				TextSize = 12,
				TextColor3 = theme.SubText,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Position = UDim2.fromOffset(5, 3),
				Size = UDim2.fromOffset(20, 14),
				Parent = button,
			})
		end
		local bar = UIKit.Frame({ Position = UDim2.new(0, 6, 1, -8), Size = UDim2.new(1, -12, 0, 4), BackgroundColor3 = Color3.fromRGB(50, 50, 60), Parent = button })
		UIKit.Corner(bar, 2)
		local fill = UIKit.Frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = theme.Good, Parent = bar })
		UIKit.Corner(fill, 2)
		local dot = UIKit.Frame({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -5, 0, 5), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = theme.Gold, Visible = false, Parent = button })
		UIKit.Corner(dot, 4)
		self.Slots[index] = { Item = item, Button = button, Stroke = stroke, Fill = fill, Dot = dot }
	end
	self.Hotbar.Size = UDim2.fromOffset(#owned * 66, 66)
	self:_refreshSlots()
end

function EquipmentController:_refreshSlots()
	local theme = self.Controllers.UIKit.Theme
	for _, slot in pairs(self.Slots) do
		local id = slot.Item.Id
		local battery = self.Battery[id] or 100
		slot.Fill.Size = UDim2.fromScale(math.clamp(battery / 100, 0, 1), 1)
		slot.Fill.BackgroundColor3 = if battery <= EquipmentConfig.CriticalBattery then theme.Accent elseif battery <= EquipmentConfig.LowBattery then theme.Gold else theme.Good
		slot.Dot.Visible = self.On[id] == true
		local selected = self.Equipped == id or (slot.Item.Wearable and self.On[id] == true)
		slot.Stroke.Color = if selected then theme.Gold else theme.Stroke
		slot.Stroke.Transparency = if selected then 0 else 0.3
	end
end

-- Next / previous hand item (wheel, R1 / L1).
function EquipmentController:Cycle(direction: number)
	local items = {}
	for _, slot in ipairs(self.Slots) do
		if not slot.Item.Wearable then
			table.insert(items, slot.Item.Id)
		end
	end
	if #items == 0 then
		return
	end
	local current = table.find(items, self.Equipped or "") or 0
	local nextIndex = if current == 0 then 1 else ((current - 1 + direction) % #items) + 1
	self:SelectItem(items[nextIndex])
end

function EquipmentController:SelectSlot(index: number)
	local slot = self.Slots[index]
	if slot then
		self:SelectItem(slot.Item.Id)
	end
end

function EquipmentController:SelectItem(itemId: string)
	local item = EquipmentConfig.Get(itemId)
	if not item then
		return
	end
	if item.Wearable then
		self:Toggle(itemId)
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not humanoid or not backpack then
		return
	end
	local tool = backpack:FindFirstChild(itemId)
	if not tool or not tool:IsA("Tool") then
		if self.Equipped == itemId and not player:GetAttribute("InMission") then
			-- same slot again at HQ: put it away
			local held = EquipmentConfig.Get(itemId)
			if held then
				self.Controllers.AudioController:Play(held.Sounds .. ".Unequip", nil)
			end
			humanoid:UnequipTools()
		end
		return -- already in hand (or not owned)
	end
	local audio = self.Controllers.AudioController
	local previous = self.Equipped and EquipmentConfig.Get(self.Equipped)
	if previous then
		audio:Play(previous.Sounds .. ".Unequip", nil)
	end
	audio:Play("Equipment.Handling", nil)
	humanoid:EquipTool(tool)
	self.EquipLockUntil = os.clock() + EquipmentConfig.EquipDelay
	task.delay(0.12, function()
		audio:Play(item.Sounds .. ".Equip", nil)
	end)
end

function EquipmentController:IsReady(): boolean
	return os.clock() >= self.EquipLockUntil
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

function EquipmentController:UseEquipped()
	if self.Equipped then
		self:Toggle(self.Equipped)
	end
end

function EquipmentController:GetEquippedItem()
	return self.Equipped and EquipmentConfig.Get(self.Equipped)
end

function EquipmentController:_onState(state)
	local audio = self.Controllers.AudioController
	local previous = self.Battery
	for id, value in pairs(state.Battery or {}) do
		local before = previous[id]
		if before and value > before + 5 and id == self.Equipped then
			self.Controllers.ViewmodelController:BatteryChange()
		end
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
	self:_refreshSlots()
	self.Changed:Fire(self.Equipped)
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
