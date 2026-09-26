--[[
	EquipmentService (ModuleScript)
	Location: ServerScriptService/Services/EquipmentService

	Physical, audible equipment.
	  * Hand items (Camera, Flashlight, EMF, Thermal, UV Light) are real Tools,
	    so characters visibly hold them and equip/unequip has feedback.
	  * Night Vision is worn (goggles appear on the head while on).
	  * Batteries drain while items are on; photos cost camera battery.
	  * Dangerous anomalies make lights buzz, flicker and sometimes fail.
	  * EMF level is computed here and replicated through tool attributes so
	    every nearby player hears/sees the same beeping.
	  * Every toggle / click can become world noise (NoiseService).
	The client can only REQUEST actions (EquipmentAction); everything is
	validated here.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = ReplicatedStorage:WaitForChild("Config")
local EquipmentConfig = require(Config:WaitForChild("EquipmentConfig"))
local CameraConfig = require(Config:WaitForChild("CameraConfig"))
local CosmeticsConfig = require(Config:WaitForChild("CosmeticsConfig"))
local MonetizationConfig = require(Config:WaitForChild("MonetizationConfig"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Net = require(Modules:WaitForChild("Net"))
local EquipmentModels = require(Modules:WaitForChild("EquipmentModels"))

local EquipmentService = {}
EquipmentService.State = {}

local TOGGLE_SOUNDS = {
	Flashlight = { On = "Flashlight.On", Off = "Flashlight.Off", Click = "Flashlight.ButtonClick" },
	UVLight = { On = "UV.On", Off = "UV.Off", Click = "UV.Off" },
	EMF = { On = "EMF.PowerOn", Off = "EMF.PowerOff", Click = "EMF.PowerOff" },
	Thermal = { On = "Thermal.Activate", Off = "Thermal.Shutdown", Click = "Thermal.Shutdown" },
	NightVision = { On = "NightVision.PowerOn", Off = "NightVision.PowerOff", Click = "NightVision.PowerOff" },
}
local LIGHT_ITEMS = { Flashlight = true, UVLight = true }

---------------------------------------------------------------------------
-- Tool construction (models come from ReplicatedStorage/Modules/EquipmentModels,
-- the same builder the first-person viewmodel uses)
---------------------------------------------------------------------------

local function prop(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Parent = parent
	return p
end

local function beamOf(tool: Instance): SpotLight?
	local beam = tool:FindFirstChild("Beam", true)
	return if beam and beam:IsA("SpotLight") then beam else nil
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function EquipmentService:Init(services)
	self.Services = services
	self.StateRemote = Net.Event("EquipmentState")
	self._lastAction = {}

	Net.Event("EquipmentAction").OnServerEvent:Connect(function(player, action, argument)
		local ok, err = pcall(function()
			self:_onAction(player, action, argument)
		end)
		if not ok then
			warn("[EquipmentService] action error:", err)
		end
	end)

	local function watch(player: Player)
		-- tools themselves are (re)built by CharacterService -> RefreshTools
		player.CharacterAdded:Connect(function()
			local state = self:_state(player)
			for itemId in pairs(state.On) do
				state.On[itemId] = false
			end
			state.FailingUntil = 0
			self:_push(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		self.State[player] = nil
		self._lastAction[player] = nil
	end)
	services.DataService:OnClientReady(function(player)
		self:_push(player)
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.2 then
			return
		end
		local step = accumulator
		accumulator = 0
		self:_tick(step)
	end)
end

function EquipmentService:_state(player: Player)
	local state = self.State[player]
	if not state then
		state = {
			Battery = {},
			On = {},
			EquippedAt = 0,
			Toggles = {},
			FailingUntil = 0,
			LastMalfunctionNoise = 0,
			LastFocus = 0,
			DrainTimer = 0,
			NoiseTimer = 0,
		}
		for id, item in pairs(EquipmentConfig.Items) do
			state.Battery[id] = item.Battery.Capacity
			state.On[id] = false
		end
		self.State[player] = state
	end
	return state
end

function EquipmentService:Owns(player: Player, itemId: string): boolean
	local item = EquipmentConfig.Get(itemId)
	if not item then
		return false
	end
	if item.Price == 0 then
		return true
	end
	local monetization = self.Services.MonetizationService
	if monetization then
		for passKey, items in pairs(MonetizationConfig.PassEquipment) do
			if table.find(items, itemId) and monetization:HasPass(player, passKey) then
				return true
			end
		end
	end
	local data = self.Services.DataService:GetData(player)
	return data ~= nil and data.OwnedEquipment ~= nil and data.OwnedEquipment[itemId] == true
end

-- Flashlight / UV stats after bench upgrades + the Tactical Flashlight pass.
function EquipmentService:GetLightStats(player: Player, itemId: string)
	local data = self.Services.DataService:GetData(player)
	local monetization = self.Services.MonetizationService
	local tactical = monetization ~= nil and monetization:HasPass(player, "TacticalFlashlight")
	return EquipmentConfig.GetLightStats(itemId, data and data.FlashlightUpgrades or nil, tactical)
end

function EquipmentService:GetEquippedTool(player: Player): Tool?
	local character = player.Character
	if not character then
		return nil
	end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute("COCEquipment") then
			return child
		end
	end
	return nil
end

-- Finds the tool whether it is held or sitting in the backpack.
function EquipmentService:FindTool(player: Player, itemId: string): Tool?
	local containers: { Instance? } = { player.Character, player:FindFirstChildOfClass("Backpack") }
	for _, container in ipairs(containers) do
		if container then
			local tool = container:FindFirstChild(itemId)
			if tool and tool:IsA("Tool") and tool:GetAttribute("COCEquipment") then
				return tool
			end
		end
	end
	return nil
end

function EquipmentService:IsEquipped(player: Player, itemId: string): boolean
	local tool = self:GetEquippedTool(player)
	return tool ~= nil and tool.Name == itemId
end

function EquipmentService:IsOn(player: Player, itemId: string): boolean
	local state = self.State[player]
	return state ~= nil and state.On[itemId] == true
end

function EquipmentService:GetHandle(player: Player, itemId: string): BasePart?
	local tool = self:GetEquippedTool(player)
	if tool and tool.Name == itemId then
		local handle = tool:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			return handle
		end
	end
	return nil
end

-- Skin for a hand item: the equipped cosmetic, or the look of the equipped camera.
function EquipmentService:GetSkin(player: Player, itemId: string)
	local data = self.Services.DataService:GetData(player)
	local slot = if itemId == "UVLight" or itemId == "Thermal" then nil else itemId
	local skinId = if slot and data then data.Cosmetics.Equipped[slot] else nil
	local monetization = self.Services.MonetizationService
	local skin = CosmeticsConfig.GetSkin(skinId)
	if skin and not skin.Free and monetization and monetization:OwnsCosmetic(player, skin.Id) then
		return skin
	end
	if itemId == "Camera" then
		local economy = self.Services.EconomyService
		local cameraId = if economy then economy:GetEquippedCameraId(player) else CameraConfig.DefaultCamera
		local def = CameraConfig.Get(cameraId) or CameraConfig.Get(CameraConfig.DefaultCamera)
		local base = EquipmentModels.DefaultSkin("Camera")
		return { Body = def.BodyColor, Accent = base.Accent, Trim = def.AccentColor, Material = base.Material }
	end
	return (if skin then skin else nil) or EquipmentModels.DefaultSkin(itemId)
end

-- (Re)builds the player's equipment tools. Keeps the currently held item in hand.
function EquipmentService:RefreshTools(player: Player)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not backpack or not humanoid then
		return
	end
	local held = self:GetEquippedTool(player)
	local inMission = player:GetAttribute("InMission") == true
	local heldId = if held then held.Name elseif inMission then "Camera" else nil
	for _, container in ipairs({ backpack, character }) do
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("COCEquipment") then
				child:Destroy()
			end
		end
	end

	local toEquip = nil
	for _, item in ipairs(EquipmentConfig.GetSorted()) do
		if item.Wearable or not self:Owns(player, item.Id) then
			continue
		end
		local tool = Instance.new("Tool")
		tool.Name = item.Id
		tool.ToolTip = item.Name
		tool.RequiresHandle = true
		tool.CanBeDropped = false
		tool.ManualActivationOnly = true
		tool.Grip = CFrame.new(0, -0.1, 0.25)
		tool:SetAttribute("COCEquipment", true)
		tool:SetAttribute("On", false)
		local skin = self:GetSkin(player, item.Id)
		local model = EquipmentModels.Build(item.Id, skin)
		if not model then
			tool:Destroy()
			continue
		end
		for _, child in ipairs(model:GetChildren()) do
			child.Parent = tool
		end
		model:Destroy()
		local skinId = nil
		for id, candidate in pairs(CosmeticsConfig.Skins) do
			if candidate == skin then
				skinId = id
			end
		end
		tool:SetAttribute("Skin", skinId)
		if LIGHT_ITEMS[item.Id] then
			local stats = self:GetLightStats(player, item.Id)
			local beam = beamOf(tool)
			if beam then
				beam.Range = stats.Range
				beam.Angle = stats.Angle
				beam.Brightness = stats.Brightness
				beam:SetAttribute("BaseBrightness", stats.Brightness)
			end
		end
		self:_wireTool(player, tool, item)
		tool.Parent = backpack
		if item.Id == heldId then
			toEquip = tool
		end
	end
	if toEquip then
		humanoid:EquipTool(toEquip)
	end
	self:_applyGoggles(player)
end

-- Deploying puts the camera in your hand; returning to HQ switches everything
-- off and empties your hands (you can pick items up again at HQ).
function EquipmentService:OnMissionMode(player: Player, inMission: boolean)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if not inMission then
		for id in pairs(EquipmentConfig.Items) do
			if self:IsOn(player, id) then
				self:_setOn(player, id, false, true)
			end
		end
		humanoid:UnequipTools()
		return
	end
	local camera = self:FindTool(player, "Camera")
	if camera and camera.Parent ~= character then
		humanoid:EquipTool(camera)
	end
end

function EquipmentService:_wireTool(player: Player, tool: Tool, item)
	local audio = self.Services.AudioService
	tool.Equipped:Connect(function()
		local state = self:_state(player)
		state.EquippedAt = os.clock()
		-- the owner already heard this locally; everyone else hears it in 3D
		audio:Play(item.Sounds .. ".Equip", tool:FindFirstChild("Handle"), { Exclude = player })
	end)
	tool.Unequipped:Connect(function()
		local state = self.State[player]
		if state and item.Toggle and state.On[item.Id] then
			self:_setOn(player, item.Id, false, true)
		end
		audio:Play(item.Sounds .. ".Unequip", player.Character and player.Character:FindFirstChild("HumanoidRootPart"), { Exclude = player })
	end)
end

---------------------------------------------------------------------------
-- Switching items on/off
---------------------------------------------------------------------------

function EquipmentService:_applyVisuals(player: Player, itemId: string)
	local state = self:_state(player)
	local on = state.On[itemId] == true
	if itemId == "NightVision" then
		self:_applyGoggles(player)
		return
	end
	local tool = self:FindTool(player, itemId)
	if not tool then
		return
	end
	tool:SetAttribute("On", on)
	if LIGHT_ITEMS[itemId] then
		local beam = beamOf(tool)
		local lens = tool:FindFirstChild("Lens")
		local lit = on and os.clock() >= state.FailingUntil
		if beam then
			beam.Enabled = lit
		end
		if lens and lens:IsA("BasePart") then
			lens.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
			lens.Color = if lit then (lens:GetAttribute("OnColor") or Color3.new(1, 1, 1)) else Color3.fromRGB(70, 70, 75)
		end
	end
	if not on then
		tool:SetAttribute("EMFLevel", 0)
		tool:SetAttribute("Interference", 0)
	end
end

function EquipmentService:_applyGoggles(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local existing = head:FindFirstChild("NVGoggles")
	local on = self:IsOn(player, "NightVision")
	if not on then
		if existing then
			existing:Destroy()
		end
		return
	end
	if existing then
		return
	end
	local goggles = Instance.new("Model")
	goggles.Name = "NVGoggles"
	for _, side in ipairs({ -1, 1 }) do
		local tube = prop(goggles, "Tube", Vector3.new(0.35, 0.32, 0.32), head.CFrame * CFrame.new(side * 0.22, 0.15, -0.72) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(30, 34, 30), Enum.Material.Metal, Enum.PartType.Cylinder)
		local lens = prop(goggles, "Lens", Vector3.new(0.04, 0.26, 0.26), head.CFrame * CFrame.new(side * 0.22, 0.15, -0.9) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(90, 255, 110), Enum.Material.Neon, Enum.PartType.Cylinder)
		for _, part in ipairs({ tube, lens }) do
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = part
			weld.Parent = part
		end
	end
	goggles.Parent = head
end

function EquipmentService:_setOn(player: Player, itemId: string, on: boolean, quiet: boolean?)
	local state = self:_state(player)
	if state.On[itemId] == on then
		return
	end
	state.On[itemId] = on
	self:_applyVisuals(player, itemId)
	local sounds = TOGGLE_SOUNDS[itemId]
	if sounds and not quiet then
		local where = self:GetHandle(player, itemId) or (player.Character and player.Character:FindFirstChild("Head"))
		self.Services.AudioService:Play(if on then sounds.On else sounds.Off, where, { Source = player, Noise = 0 })
		if itemId == "NightVision" and on then
			self.Services.AudioService:Play("NightVision.Activation", where, {})
		end
	end
	self:_push(player)
end

function EquipmentService:_lightNoise(player: Player, itemId: string, position: Vector3)
	local state = self:_state(player)
	local noise = EquipmentConfig.Items[itemId].Noise
	local now = os.clock()
	table.insert(state.Toggles, now)
	while state.Toggles[1] and now - state.Toggles[1] > noise.RapidToggleWindow do
		table.remove(state.Toggles, 1)
	end
	local rapid = #state.Toggles >= noise.RapidToggleCount
	self.Services.NoiseService:Emit(position, if rapid then noise.Malfunction else noise.Toggle, if rapid then "FlashlightMalfunction" else "FlashlightClick", player)
end

function EquipmentService:_onAction(player: Player, action: any, argument: any)
	if type(action) ~= "string" then
		return
	end
	local now = os.clock()
	if self._lastAction[player] and now - self._lastAction[player] < 0.12 then
		return
	end
	self._lastAction[player] = now
	local state = self:_state(player)
	local audio = self.Services.AudioService

	if action == "Toggle" then
		if type(argument) ~= "string" then
			return
		end
		local item = EquipmentConfig.Get(argument)
		if not item or not item.Toggle or not self:Owns(player, argument) then
			return
		end
		local where
		if item.Wearable then
			where = player.Character and player.Character:FindFirstChild("Head")
		else
			if not self:IsEquipped(player, argument) or now - state.EquippedAt < EquipmentConfig.EquipDelay * 0.8 then
				return
			end
			where = self:GetHandle(player, argument)
		end
		if not where then
			return
		end
		local turningOn = not state.On[argument]
		if turningOn and state.Battery[argument] <= 0 then
			-- click... nothing. Dead battery.
			audio:Play(TOGGLE_SOUNDS[argument].Click, where, { Exclude = player })
			self:_push(player)
			return
		end
		if turningOn and LIGHT_ITEMS[argument] and now < state.FailingUntil then
			-- CLICK ... nothing. Something nearby is killing the power.
			audio:Play("Flashlight.ButtonClick", where, { Exclude = player })
			audio:Play("Flashlight.Interference", where, {})
			self.Services.NoiseService:Emit(where.Position, item.Noise.Malfunction, "FlashlightMalfunction", player)
			return
		end
		self:_setOn(player, argument, turningOn)
		if LIGHT_ITEMS[argument] then
			self:_lightNoise(player, argument, where.Position)
		end
	elseif action == "Focus" or action == "FocusBroken" then
		local handle = self:GetHandle(player, "Camera")
		if not handle or now - state.LastFocus < (if action == "Focus" then 0.6 else 1.5) then
			return
		end
		state.LastFocus = now
		audio:Play(if action == "Focus" then "Camera.Focus" else "Camera.FocusBroken", handle, { Source = player, Exclude = player })
	elseif action == "Zoom" then
		local handle = self:GetHandle(player, "Camera")
		if handle and (argument == "In" or argument == "Out") then
			audio:Play(if argument == "In" then "Camera.ZoomIn" else "Camera.ZoomOut", handle, { Exclude = player })
		end
	end
end

---------------------------------------------------------------------------
-- Batteries
---------------------------------------------------------------------------

function EquipmentService:ConsumeBattery(player: Player, itemId: string, amount: number): boolean
	local state = self:_state(player)
	if state.Battery[itemId] == nil or state.Battery[itemId] <= 0 then
		return false
	end
	state.Battery[itemId] = math.max(0, state.Battery[itemId] - amount)
	self:_push(player)
	return true
end

function EquipmentService:DrainEquipped(player: Player, amount: number)
	local tool = self:GetEquippedTool(player)
	local itemId = if tool then tool.Name else "Camera"
	local state = self:_state(player)
	if state.Battery[itemId] then
		state.Battery[itemId] = math.max(0, state.Battery[itemId] - amount)
		if state.Battery[itemId] <= 0 and state.On[itemId] then
			self:_setOn(player, itemId, false)
		end
		self:_push(player)
	end
end

-- Battery pickup: recharges the owned item with the lowest battery.
function EquipmentService:AddBattery(player: Player, amount: number): string?
	local state = self:_state(player)
	local lowestId, lowest = nil, math.huge
	for _, item in ipairs(EquipmentConfig.GetSorted()) do
		if self:Owns(player, item.Id) and state.Battery[item.Id] < lowest then
			lowestId, lowest = item.Id, state.Battery[item.Id]
		end
	end
	if not lowestId then
		return nil
	end
	local capacity = EquipmentConfig.Items[lowestId].Battery.Capacity
	state.Battery[lowestId] = math.min(capacity, state.Battery[lowestId] + amount)
	self:_push(player)
	return lowestId
end

function EquipmentService:ResetForRound(team: { Player }?)
	for _, player in ipairs(team or Players:GetPlayers()) do
		local state = self:_state(player)
		for id, item in pairs(EquipmentConfig.Items) do
			state.Battery[id] = item.Battery.Capacity
			if state.On[id] then
				self:_setOn(player, id, false, true)
			end
		end
		state.FailingUntil = 0
		self:_push(player)
	end
end

function EquipmentService:_push(player: Player)
	if not player:IsDescendantOf(Players) then
		return
	end
	local state = self:_state(player)
	local battery = {}
	for id, value in pairs(state.Battery) do
		battery[id] = math.floor(value + 0.5)
	end
	self.StateRemote:FireClient(player, {
		Battery = battery,
		On = table.clone(state.On),
		Failing = os.clock() < state.FailingUntil,
	})
end

---------------------------------------------------------------------------
-- Tick: drain, interference, EMF
---------------------------------------------------------------------------

function EquipmentService:_tick(dt: number)
	local anomalies = self.Services.AnomalyService
	local audio = self.Services.AudioService
	local now = os.clock()
	for player, state in pairs(self.State) do
		if not player:IsDescendantOf(Players) then
			continue
		end
		-- battery drain (once per second, only while investigating: HQ is safe)
		state.DrainTimer += dt
		local mission = self.Services.MissionService
		local investigating = mission ~= nil and mission:IsInvestigating(player)
		if state.DrainTimer >= 1 and not investigating then
			state.DrainTimer = 0
		elseif state.DrainTimer >= 1 then
			local elapsed = state.DrainTimer
			state.DrainTimer = 0
			local changed = false
			for itemId, on in pairs(state.On) do
				if on then
					local multiplier = if LIGHT_ITEMS[itemId] then self:GetLightStats(player, itemId).DrainMultiplier else 1
					local drain = EquipmentConfig.Items[itemId].Battery.DrainPerSecond * elapsed * multiplier
					if drain > 0 then
						state.Battery[itemId] = math.max(0, state.Battery[itemId] - drain)
						changed = true
						if state.Battery[itemId] <= 0 then
							local where = self:GetHandle(player, itemId)
							if LIGHT_ITEMS[itemId] and where then
								audio:Play("Flashlight.BulbFailure", where, { Source = player, Noise = EquipmentConfig.Items[itemId].Noise.Broken })
							end
							self:_setOn(player, itemId, false, LIGHT_ITEMS[itemId] == true)
						end
					end
				end
			end
			if changed then
				self:_push(player)
			end
		end

		-- lights: buzz, flicker and electrical failure near dangerous anomalies
		for itemId in pairs(LIGHT_ITEMS) do
			local tool = self:GetEquippedTool(player)
			if not state.On[itemId] or not tool or tool.Name ~= itemId then
				continue
			end
			local handle = tool:FindFirstChild("Handle")
			if not handle or not handle:IsA("BasePart") then
				continue
			end
			local danger = anomalies:GetDangerNear(handle.Position, EquipmentConfig.InterferenceRadius) * self:GetLightStats(player, itemId).InterferenceMultiplier
			local rounded = math.floor(danger * 10 + 0.5) / 10
			if tool:GetAttribute("Interference") ~= rounded then
				tool:SetAttribute("Interference", rounded)
			end
			local beam = beamOf(tool)
			if not beam then
				continue
			end
			if now < state.FailingUntil then
				beam.Enabled = false
			elseif danger > 0.75 and math.random() < 0.05 then
				state.FailingUntil = now + 2.5 + math.random() * 1.5
				self:_applyVisuals(player, itemId)
				audio:Play("Flashlight.ElectricalFailure", handle, { Source = player })
				task.delay(state.FailingUntil - now + 0.05, function()
					if self.State[player] == state and state.On[itemId] then
						self:_applyVisuals(player, itemId)
						audio:Play("Flashlight.On", handle, {})
					end
					self:_push(player)
				end)
				self:_push(player)
			elseif danger > 0.3 and math.random() < danger * 0.35 then
				beam.Enabled = false
				local makeNoise = now - state.LastMalfunctionNoise > 1.5
				if makeNoise then
					state.LastMalfunctionNoise = now
				end
				audio:Play("Flashlight.Flicker", handle, { Source = player, Noise = if makeNoise then nil else 0 })
				task.delay(0.05 + math.random() * 0.15, function()
					if state.On[itemId] and os.clock() >= state.FailingUntil and beam.Parent then
						beam.Enabled = true
					end
				end)
			end
		end

		-- EMF level (replicated through tool attributes so everyone hears the same beeps)
		local tool = self:GetEquippedTool(player)
		if tool and tool.Name == "EMF" and state.On.EMF then
			local handle = tool:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				local level, distort = anomalies:GetEMFLevel(handle.Position, EquipmentConfig.Items.EMF.Range)
				if tool:GetAttribute("EMFLevel") ~= level then
					tool:SetAttribute("EMFLevel", level)
				end
				if tool:GetAttribute("EMFDistort") ~= distort then
					tool:SetAttribute("EMFDistort", distort)
				end
				state.NoiseTimer += dt
				if state.NoiseTimer >= 1 and level > 0 then
					state.NoiseTimer = 0
					self.Services.NoiseService:Emit(handle.Position, level * EquipmentConfig.Items.EMF.NoisePerLevel, "EMF", player)
				end
			end
		end
	end
end

return EquipmentService
