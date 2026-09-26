--[[
	InteractionService (ModuleScript)
	Location: ServerScriptService/Services/InteractionService

	Everything players can physically interact with in the Dead Mall. Each
	interaction has satisfying sounds and most make NOISE:
	  Doors        Open / "Close quietly" (hold, 0.08 noise) / "Slam" (0.6 noise!)
	               Locked Mall Security Door opens with the Security Key.
	  Lockers      creak open; may hold a battery or the SECURITY KEY
	  Drawers      cash register drawers; may hold a battery or the key
	  Batteries    pickups that recharge your emptiest equipment
	  Elevator     call it... it never comes. Usually.
	  Payphone     rings on its own (EnvironmentService); answer for a whisper
	  Radio        static + a hint where something is (loud!)
	  Computer     CCTV check: how many anomalies are active and where
	  Breaker      restores power during a Blackout
	Objects are found by CollectionService tag, so custom maps just tag parts.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = ReplicatedStorage:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local EquipmentConfig = require(Config:WaitForChild("EquipmentConfig"))
local Net = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"))

local InteractionService = {}
InteractionService.Keys = {}
InteractionService.Contents = {}
InteractionService.Doors = {}
InteractionService.Containers = {}
InteractionService.Pickups = {}
InteractionService.Cooldowns = {}

local INTERACT = GameConfig.Interaction

local function makePrompt(parent: Instance, action: string, object: string, hold: number?, key: Enum.KeyCode?): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = hold or 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = key or Enum.KeyCode.E
	prompt.GamepadKeyCode = if key == Enum.KeyCode.F then Enum.KeyCode.ButtonY else Enum.KeyCode.ButtonX
	prompt.Parent = parent
	return prompt
end

local function tween(instance: Instance, duration: number, goal, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local t = TweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Sine, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

function InteractionService:Init(services)
	self.Services = services
	self.AnnounceRemote = Net.Event("Announce")

	local handlers = {
		Door = self._setupDoor,
		Locker = self._setupLocker,
		Drawer = self._setupDrawer,
		ElevatorButton = self._setupElevator,
		Payphone = self._setupPayphone,
		SecurityComputer = self._setupComputer,
		Radio = self._setupRadio,
		Breaker = self._setupBreaker,
	}
	for tag, setup in pairs(handlers) do
		for _, instance in ipairs(CollectionService:GetTagged(tag)) do
			setup(self, instance)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
			setup(self, instance)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		self.Keys[player] = nil
	end)
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

function InteractionService:_toast(player: Player, text: string, color: Color3?)
	self.AnnounceRemote:FireClient(player, { Kind = "Toast", Text = text, Color = color or Color3.fromRGB(220, 220, 230) })
end

function InteractionService:_canUse(player: Player, part: BasePart): boolean
	local root = self.Services.CharacterService:GetParts(player)
	return root ~= nil and (root.Position - part.Position).Magnitude < 16
end

function InteractionService:_cooldown(key: any, seconds: number): boolean
	local now = os.clock()
	if self.Cooldowns[key] and now < self.Cooldowns[key] then
		return false
	end
	self.Cooldowns[key] = now + seconds
	return true
end

function InteractionService:_randomAnomalyZone(): string?
	local anomalies = self.Services.AnomalyService:GetActiveList()
	if #anomalies == 0 then
		return nil
	end
	local record = anomalies[math.random(1, #anomalies)]
	return record.Zone and GameConfig.Zones[record.Zone] or nil
end

---------------------------------------------------------------------------
-- Doors
---------------------------------------------------------------------------

function InteractionService:_setupDoor(door: Instance)
	if self.Doors[door] then
		return
	end
	local hinge = door:FindFirstChild("Hinge")
	local panel = door:FindFirstChild("Panel")
	if not (hinge and hinge:IsA("BasePart") and panel and panel:IsA("BasePart")) then
		return
	end
	local state = {
		Door = door,
		Hinge = hinge,
		Panel = panel,
		Closed = hinge.CFrame,
		Open = false,
		Busy = false,
		Type = door:GetAttribute("DoorType") or "Wood",
	}
	state.OpenPrompt = makePrompt(panel, "Open", "Door")
	state.ClosePrompt = makePrompt(panel, "Close quietly", "Door", 0.9)
	state.SlamPrompt = makePrompt(panel, "Slam", "Door", 0, Enum.KeyCode.F)
	self.Doors[door] = state
	self:_refreshDoorPrompts(state)

	state.OpenPrompt.Triggered:Connect(function(player)
		self:_openDoor(state, player)
	end)
	state.ClosePrompt.Triggered:Connect(function(player)
		self:_closeDoor(state, player, false)
	end)
	state.SlamPrompt.Triggered:Connect(function(player)
		self:_closeDoor(state, player, true)
	end)
end

function InteractionService:_refreshDoorPrompts(state)
	state.OpenPrompt.Enabled = not state.Open
	state.ClosePrompt.Enabled = state.Open
	state.SlamPrompt.Enabled = state.Open
end

function InteractionService:_openDoor(state, player: Player)
	if state.Busy or state.Open or not self:_canUse(player, state.Panel) then
		return
	end
	local audio = self.Services.AudioService
	local sounds = "Door." .. state.Type
	if state.Door:GetAttribute("Locked") then
		if self.Keys[player] then
			state.Door:SetAttribute("Locked", false)
			audio:Play("Interaction.Unlock", state.Panel, { Source = player })
			self:_toast(player, "🔓 Unlocked with the SECURITY KEY", Color3.fromRGB(255, 215, 90))
		else
			audio:Play(sounds .. ".Locked", state.Panel, { Source = player })
			if self:_cooldown(player.UserId .. "locked", 3) then
				self:_toast(player, "🔒 Locked. The SECURITY KEY is hidden in a locker or register somewhere...", Color3.fromRGB(200, 200, 210))
			end
			return
		end
	end
	state.Busy = true
	local root = self.Services.CharacterService:GetParts(player)
	local normal = state.Closed.LookVector
	local side = if root and (root.Position - state.Closed.Position):Dot(normal) > 0 then -1 else 1
	audio:Play(sounds .. ".Handle", state.Panel, { Source = player })
	audio:Play(sounds .. ".Open", state.Panel, { Source = player })
	if (state.Type == "Wood" or state.Type == "Security") and math.random() < 0.6 then
		audio:Play(sounds .. ".Creak", state.Panel, { Source = player, Noise = 0 })
	end
	local t = tween(state.Hinge, 0.9, { CFrame = state.Closed * CFrame.Angles(0, side * math.rad(95), 0) })
	state.Open = true
	self:_refreshDoorPrompts(state)
	t.Completed:Once(function()
		state.Busy = false
	end)
end

function InteractionService:_closeDoor(state, player: Player, slam: boolean)
	if state.Busy or not state.Open or not self:_canUse(player, state.Panel) then
		return
	end
	state.Busy = true
	local audio = self.Services.AudioService
	local sounds = "Door." .. state.Type
	local t
	if slam then
		t = tween(state.Hinge, 0.16, { CFrame = state.Closed }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.14, function()
			audio:Play(sounds .. ".Slam", state.Panel, { Source = player })
		end)
	else
		t = tween(state.Hinge, 1.3, { CFrame = state.Closed }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		audio:Play(sounds .. ".Creak", state.Panel, { Source = player, Volume = 0.5, Noise = 0.03 })
		task.delay(1.2, function()
			audio:Play(sounds .. ".Close", state.Panel, { Source = player })
		end)
	end
	state.Open = false
	self:_refreshDoorPrompts(state)
	t.Completed:Once(function()
		state.Busy = false
	end)
end

-- Lets anomalies (Mimic) and phantom sounds find a real door.
function InteractionService:GetNearestDoor(position: Vector3, maxDistance: number)
	local best, bestDistance = nil, maxDistance
	for _, state in pairs(self.Doors) do
		local distance = (state.Panel.Position - position).Magnitude
		if distance < bestDistance then
			best, bestDistance = state, distance
		end
	end
	return best
end

---------------------------------------------------------------------------
-- Lockers + drawers (containers)
---------------------------------------------------------------------------

function InteractionService:_giveContents(player: Player, container: Instance, where: BasePart)
	local contents = self.Contents[container]
	self.Contents[container] = nil
	local audio = self.Services.AudioService
	if contents == "Battery" then
		self:_giveBattery(player, where)
	elseif contents == "SecurityKey" then
		self.Keys[player] = true
		audio:Play("Interaction.KeyPickup", where, { Source = player })
		self:_toast(player, "🔑 SECURITY KEY found! The Security Office is off the Storage Hallway.", Color3.fromRGB(255, 215, 90))
	elseif math.random() < 0.35 then
		self:_toast(player, "Empty...", Color3.fromRGB(160, 160, 170))
	end
end

function InteractionService:_setupLocker(locker: Instance)
	if self.Containers[locker] then
		return
	end
	local hinge = locker:FindFirstChild("Hinge")
	local panel = locker:FindFirstChild("DoorPanel")
	if not (hinge and hinge:IsA("BasePart") and panel and panel:IsA("BasePart")) then
		return
	end
	local state = { Kind = "Locker", Instance = locker, Hinge = hinge, Panel = panel, Closed = hinge.CFrame, Open = false, Busy = false }
	state.Prompt = makePrompt(panel, "Open", "Locker")
	self.Containers[locker] = state
	state.Prompt.Triggered:Connect(function(player)
		if state.Busy or not self:_canUse(player, panel) then
			return
		end
		state.Busy = true
		local audio = self.Services.AudioService
		if state.Open then
			tween(hinge, 0.3, { CFrame = state.Closed }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.25, function()
				audio:Play("Interaction.LockerClose", panel, { Source = player })
			end)
			state.Open = false
			state.Prompt.ActionText = "Open"
		else
			audio:Play("Door.Locker.Handle", panel, { Source = player, Noise = 0 })
			audio:Play("Interaction.LockerOpen", panel, { Source = player })
			tween(hinge, 0.45, { CFrame = state.Closed * CFrame.Angles(0, math.rad(105), 0) })
			state.Open = true
			state.Prompt.ActionText = "Close"
			task.delay(0.35, function()
				self:_giveContents(player, locker, panel)
			end)
		end
		task.delay(0.5, function()
			state.Busy = false
		end)
	end)
end

function InteractionService:_setupDrawer(drawer: Instance)
	if self.Containers[drawer] or not drawer:IsA("BasePart") then
		return
	end
	local slide = drawer:GetAttribute("Slide")
	if typeof(slide) ~= "Vector3" then
		return
	end
	local state = { Kind = "Drawer", Instance = drawer, Part = drawer, Closed = drawer.CFrame, Slide = slide, Open = false, Busy = false }
	state.Prompt = makePrompt(drawer, "Open", "Register")
	self.Containers[drawer] = state
	state.Prompt.Triggered:Connect(function(player)
		if state.Busy or not self:_canUse(player, drawer) then
			return
		end
		state.Busy = true
		local audio = self.Services.AudioService
		if state.Open then
			tween(drawer, 0.2, { CFrame = state.Closed }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			audio:Play("Interaction.DrawerClose", drawer, { Source = player })
			state.Open = false
			state.Prompt.ActionText = "Open"
		else
			tween(drawer, 0.25, { CFrame = state.Closed + slide })
			audio:Play("Interaction.DrawerOpen", drawer, { Source = player })
			state.Open = true
			state.Prompt.ActionText = "Close"
			task.delay(0.25, function()
				self:_giveContents(player, drawer, drawer)
			end)
		end
		task.delay(0.35, function()
			state.Busy = false
		end)
	end)
end

---------------------------------------------------------------------------
-- Batteries
---------------------------------------------------------------------------

function InteractionService:_giveBattery(player: Player, where: BasePart)
	local audio = self.Services.AudioService
	audio:Play("Interaction.BatteryPickup", where, { Source = player })
	local itemId = self.Services.EquipmentService:AddBattery(player, EquipmentConfig.BatteryPickupAmount)
	if itemId then
		task.delay(0.35, function()
			audio:Play("Flashlight.BatteryRemove", where, { Only = player })
			task.wait(0.35)
			audio:Play("Flashlight.BatteryInsert", where, { Only = player })
		end)
		local item = EquipmentConfig.Get(itemId)
		self:_toast(player, string.format("🔋 %s recharged (+%d%%)", item.Name, EquipmentConfig.BatteryPickupAmount), Color3.fromRGB(120, 230, 140))
	end
end

function InteractionService:_spawnBattery(spot: BasePart)
	local battery = Instance.new("Part")
	battery.Name = "Battery"
	battery.Shape = Enum.PartType.Cylinder
	battery.Size = Vector3.new(0.9, 0.42, 0.42)
	battery.CFrame = CFrame.new(spot.Position) * CFrame.Angles(0, math.rad(math.random(0, 359)), 0)
	battery.Color = Color3.fromRGB(30, 30, 32)
	battery.Material = Enum.Material.SmoothPlastic
	battery.Anchored = true
	battery.CanCollide = false
	battery.CastShadow = false
	local stripe = Instance.new("Part")
	stripe.Name = "Stripe"
	stripe.Shape = Enum.PartType.Cylinder
	stripe.Size = Vector3.new(0.25, 0.44, 0.44)
	stripe.CFrame = battery.CFrame * CFrame.new(0.2, 0, 0)
	stripe.Color = Color3.fromRGB(90, 255, 120)
	stripe.Material = Enum.Material.Neon
	stripe.Anchored = true
	stripe.CanCollide = false
	stripe.CanQuery = false
	stripe.CastShadow = false
	stripe.Parent = battery
	local glow = Instance.new("PointLight")
	glow.Range = 5
	glow.Brightness = 0.6
	glow.Color = Color3.fromRGB(90, 255, 120)
	glow.Shadows = false
	glow.Parent = battery
	local prompt = makePrompt(battery, "Take", "Battery")
	prompt.MaxActivationDistance = 8
	battery.Parent = self.Services.MapService.Folders.DeadMall
	table.insert(self.Pickups, battery)
	prompt.Triggered:Connect(function(player)
		if not battery.Parent or not self:_canUse(player, battery) then
			return
		end
		local position = battery.Position
		battery:Destroy()
		local marker = Instance.new("Part")
		marker.Anchored = true
		marker.Transparency = 1
		marker.CanCollide = false
		marker.CanQuery = false
		marker.Position = position
		marker.Parent = self.Services.MapService.Folders.Decoys
		self:_giveBattery(player, marker)
		task.delay(2, function()
			marker:Destroy()
		end)
	end)
end

---------------------------------------------------------------------------
-- Elevator, payphone, radio, computer, breaker
---------------------------------------------------------------------------

function InteractionService:_setupElevator(button: Instance)
	if not button:IsA("BasePart") then
		return
	end
	local prompt = makePrompt(button, "Call", "Elevator")
	prompt.Triggered:Connect(function(player)
		if not self:_canUse(player, button) or not self:_cooldown(button, 8) then
			return
		end
		local audio = self.Services.AudioService
		audio:Play("Interaction.ElevatorButton", button, { Source = player })
		task.delay(2.6, function()
			audio:Play("Interaction.ElevatorDing", button, {})
			self.Services.NoiseService:Emit(button.Position, 0.2, "Interaction", nil)
			if math.random() < 0.18 then
				-- the doors open a crack... then close
				for _, door in ipairs(CollectionService:GetTagged("ElevatorDoor")) do
					if door:IsA("BasePart") then
						local closed = door.CFrame
						local offset = if door.Name == "ElevatorLeft" then -0.5 else 0.5
						tween(door, 0.6, { CFrame = closed + Vector3.new(offset, 0, 0) })
						task.delay(1.4, function()
							tween(door, 0.4, { CFrame = closed })
						end)
					end
				end
				audio:Play("Anomaly.Whisper", button, {})
			end
		end)
	end)
end

function InteractionService:_setupPayphone(phone: Instance)
	local body = if phone:IsA("Model") then phone.PrimaryPart else nil
	if not body then
		return
	end
	local prompt = makePrompt(body, "Answer", "Payphone")
	prompt.Triggered:Connect(function(player)
		if not self:_canUse(player, body) or not self:_cooldown(phone, 3) then
			return
		end
		local audio = self.Services.AudioService
		audio:Play("Interaction.PhonePickup", body, { Source = player })
		if phone:GetAttribute("Ringing") then
			phone:SetAttribute("Ringing", false)
			task.delay(0.6, function()
				audio:Play("Interaction.RadioVoice", body, { Only = player })
				local zone = self:_randomAnomalyZone()
				if zone and math.random() < INTERACT.PhoneHintChance then
					self:_toast(player, string.format('📞 A voice whispers: "...%s..."', zone), Color3.fromRGB(200, 150, 255))
				else
					self:_toast(player, '📞 Breathing. Then: "...behind you..."', Color3.fromRGB(200, 150, 255))
				end
			end)
		else
			audio:Play("Interaction.Computer", body, { Only = player })
			self:_toast(player, "📞 Dead line. Just static.", Color3.fromRGB(170, 170, 180))
		end
	end)
end

function InteractionService:_setupRadio(radio: Instance)
	if not radio:IsA("BasePart") then
		return
	end
	local prompt = makePrompt(radio, "Use", "Radio")
	prompt.Triggered:Connect(function(player)
		if not self:_canUse(player, radio) then
			return
		end
		local audio = self.Services.AudioService
		if not self:_cooldown(radio, INTERACT.RadioCooldown) then
			audio:Play("Interaction.RadioStatic", radio, { Source = player, Volume = 0.5 })
			self:_toast(player, "📻 Only static right now...", Color3.fromRGB(170, 170, 180))
			return
		end
		audio:Play("Interaction.RadioStatic", radio, { Source = player })
		task.delay(1.2, function()
			audio:Play("Interaction.RadioVoice", radio, { Source = player })
			local zone = self:_randomAnomalyZone()
			if zone then
				self:_toast(player, string.format("📻 ...kssh... movement near the %s... kssh...", zone), Color3.fromRGB(150, 220, 255))
			else
				self:_toast(player, "📻 ...kssh... all quiet... for now... kssh...", Color3.fromRGB(150, 220, 255))
			end
		end)
	end)
end

function InteractionService:_setupComputer(computer: Instance)
	if not computer:IsA("BasePart") then
		return
	end
	local prompt = makePrompt(computer, "Check cameras", "Security PC")
	prompt.Triggered:Connect(function(player)
		if not self:_canUse(player, computer) or not self:_cooldown(player.UserId .. "pc", 2) then
			return
		end
		self.Services.AudioService:Play("Interaction.Computer", computer, { Source = player })
		local anomalies = self.Services.AnomalyService:GetActiveList()
		local zone = self:_randomAnomalyZone() or "NONE"
		local gui = computer:FindFirstChild("SignGui")
		local screen = gui and gui:FindFirstChild("Screen")
		local text = string.format("CCTV\nSIGNALS: %d\nSTRONGEST:\n%s", #anomalies, zone)
		if screen and screen:IsA("TextLabel") then
			screen.Text = text
		end
		self:_toast(player, string.format("🖥️ CCTV: %d signal(s). Strongest near the %s.", #anomalies, zone), Color3.fromRGB(120, 255, 150))
	end)
end

function InteractionService:_setupBreaker(breaker: Instance)
	local box = if breaker:IsA("Model") then breaker.PrimaryPart else nil
	if not box then
		return
	end
	local lever = breaker:FindFirstChild("Lever")
	local prompt = makePrompt(box, "Reset", "Breaker", 1.2)
	prompt.Triggered:Connect(function(player)
		if not self:_canUse(player, box) or not self:_cooldown(breaker, 3) then
			return
		end
		local audio = self.Services.AudioService
		local events = self.Services.EventService
		if lever and lever:IsA("BasePart") then
			local up = lever.CFrame
			tween(lever, 0.15, { CFrame = up * CFrame.new(0, -0.5, 0) })
			task.delay(0.6, function()
				tween(lever, 0.2, { CFrame = up })
			end)
		end
		if events:IsActive("Blackout") then
			audio:Play("Interaction.BreakerOn", box, { Source = player })
			task.delay(0.5, function()
				audio:Play("Interaction.GeneratorStart", box, { Source = player })
				events:EndEvent()
				self.AnnounceRemote:FireAllClients({
					Kind = "Toast",
					Text = string.format("⚡ %s restored the power!", player.DisplayName),
					Color = Color3.fromRGB(255, 230, 120),
				})
			end)
		else
			audio:Play("Interaction.BreakerOff", box, { Source = player, Noise = 0.1 })
			self:_toast(player, "⚡ The power is already on.", Color3.fromRGB(200, 200, 210))
		end
	end)
end

---------------------------------------------------------------------------
-- Round lifecycle
---------------------------------------------------------------------------

function InteractionService:ResetForRound()
	self.Keys = {}
	self.Contents = {}
	-- doors closed, security door locked again
	for _, state in pairs(self.Doors) do
		state.Hinge.CFrame = state.Closed
		state.Open = false
		state.Busy = false
		state.Door:SetAttribute("Locked", state.Door:GetAttribute("StartsLocked") == true)
		self:_refreshDoorPrompts(state)
	end
	-- containers closed, hide the key + a few batteries
	local keyCandidates, all = {}, {}
	for instance, state in pairs(self.Containers) do
		if state.Kind == "Locker" then
			state.Hinge.CFrame = state.Closed
		else
			state.Part.CFrame = state.Closed
		end
		state.Open = false
		state.Busy = false
		state.Prompt.ActionText = "Open"
		table.insert(all, instance)
		if instance:GetAttribute("Zone") ~= "SecurityOffice" then
			table.insert(keyCandidates, instance)
		end
	end
	if #keyCandidates > 0 then
		local keyHolder = keyCandidates[math.random(1, #keyCandidates)]
		self.Contents[keyHolder] = "SecurityKey"
	end
	for _ = 1, 3 do
		local container = all[math.random(1, math.max(1, #all))]
		if container and not self.Contents[container] then
			self.Contents[container] = "Battery"
		end
	end
	-- battery pickups
	self:_clearPickups()
	local mapService = self.Services.MapService
	local spots = mapService:GetPickupSpots("Battery")
	for _ = 1, math.min(INTERACT.BatterySpawns, #spots) do
		local spot = table.remove(spots, math.random(1, #spots))
		self:_spawnBattery(spot)
	end
	local officeSpots = mapService:GetPickupSpots("OfficeBattery")
	for index = 1, math.min(INTERACT.OfficeBatteries, #officeSpots) do
		self:_spawnBattery(officeSpots[index])
	end
end

function InteractionService:_clearPickups()
	for _, pickup in ipairs(self.Pickups) do
		pickup:Destroy()
	end
	table.clear(self.Pickups)
end

function InteractionService:EndRound()
	self:_clearPickups()
	self.Keys = {}
	for _, phone in ipairs(CollectionService:GetTagged("Payphone")) do
		phone:SetAttribute("Ringing", false)
	end
end

return InteractionService
