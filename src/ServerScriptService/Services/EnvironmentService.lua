--[[
	EnvironmentService (ModuleScript)
	Location: ServerScriptService/Services/EnvironmentService

	The mall's living soundscape during a round.
	  Thunder   lightning through the skylight, then thunder. For a moment the
	            environmental noise level is high enough to MASK player noise:
	            wait for the thunder, then run past the thing that hunts by sound.
	  HVAC      ventilation roars in one zone, masking nearby noise
	  Payphone  starts ringing on its own (loud - it attracts listeners)
	  Phantoms  deceptive sounds that are IDENTICAL to real gameplay sounds:
	            footsteps above you, a camera shutter, a flashlight click, a
	            door opening, EMF beeps, a battery pickup, knocking.
	            "Was that my teammate?"
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))

local EnvironmentService = {}
EnvironmentService.Threads = {}

local ENV = GameConfig.Environment

local function randomRange(range: { number }): number
	return range[1] + math.random() * (range[2] - range[1])
end

function EnvironmentService:Init(services)
	self.Services = services
	self.RayParams = RaycastParams.new()
	self.RayParams.FilterType = Enum.RaycastFilterType.Exclude
end

function EnvironmentService:StartRound()
	self:StopRound()
	self.Running = true
	local function loop(interval: { number }, action: () -> ())
		table.insert(self.Threads, task.spawn(function()
			while self.Running do
				task.wait(randomRange(interval))
				if not self.Running then
					break
				end
				local ok, err = pcall(action)
				if not ok then
					warn("[EnvironmentService]", err)
				end
			end
		end))
	end
	loop(ENV.Thunder.Interval, function()
		self:Thunder()
	end)
	loop(ENV.HVAC.Interval, function()
		self:HVACBurst()
	end)
	loop(ENV.Phone.Interval, function()
		self:RingPhone()
	end)
	loop(ENV.Phantom.Interval, function()
		self:Phantom()
	end)
end

function EnvironmentService:StopRound()
	self.Running = false
	for _, thread in ipairs(self.Threads) do
		if coroutine.status(thread) ~= "dead" and coroutine.running() ~= thread then
			pcall(task.cancel, thread)
		end
	end
	table.clear(self.Threads)
end

---------------------------------------------------------------------------
-- Masking sounds
---------------------------------------------------------------------------

function EnvironmentService:Thunder()
	local services = self.Services
	services.MapService:Lightning()
	services.AudioService:Play("Environment.LightningCrack", nil, { Global = true })
	task.wait(randomRange(ENV.Thunder.Delay))
	services.AudioService:Play("Environment.Thunder", nil, { Global = true })
	services.NoiseService:SetMask("Thunder", ENV.Thunder.Masking, ENV.Thunder.MaskDuration)
end

function EnvironmentService:HVACBurst()
	local zones = { "Bathrooms", "StorageHallway", "ParkingGarage", "FoodCourt", "Arcade", "Cinema" }
	local zoneId = zones[math.random(1, #zones)]
	local mall = self.Services.MapService.Folders.DeadMall
	local zonesModel = mall:FindFirstChild("Zones")
	local bounds = zonesModel and zonesModel:FindFirstChild(zoneId)
	if not bounds or not bounds:IsA("BasePart") then
		return
	end
	local position = bounds.Position + Vector3.new(0, bounds.Size.Y / 2 - 2, 0)
	self.Services.AudioService:Play("Environment.HVACBurst", position, {})
	self.Services.NoiseService:SetMask("HVAC", ENV.HVAC.Masking, ENV.HVAC.Duration, position, ENV.HVAC.Radius)
end

function EnvironmentService:RingPhone()
	local phones = CollectionService:GetTagged("Payphone")
	local phone = phones[1]
	if not phone or not phone:IsA("Model") or not phone.PrimaryPart then
		return
	end
	local body = phone.PrimaryPart
	phone:SetAttribute("Ringing", true)
	for _ = 1, ENV.Phone.Rings do
		if not self.Running or not phone:GetAttribute("Ringing") then
			break
		end
		self.Services.AudioService:Play("Interaction.PhoneRing", body, {})
		self.Services.NoiseService:Emit(body.Position, 0.3, "Phone", nil)
		task.wait(ENV.Phone.RingGap)
	end
	phone:SetAttribute("Ringing", false)
end

---------------------------------------------------------------------------
-- Phantom (deceptive) sounds
---------------------------------------------------------------------------

function EnvironmentService:_pickVictim(): (Player?, BasePart?)
	local participants = self.Services.AnomalyService:GetParticipants()
	if #participants == 0 then
		return nil, nil
	end
	local player = participants[math.random(1, #participants)]
	local root = self.Services.CharacterService:GetParts(player)
	return player, root
end

function EnvironmentService:Phantom(forcedKind: string?)
	local _, root = self:_pickVictim()
	if not root then
		return
	end
	local audio = self.Services.AudioService
	local kind = forcedKind
	if not kind then
		local total = 0
		for _, weight in pairs(ENV.Phantom.Weights) do
			total += weight
		end
		local roll = math.random() * total
		for name, weight in pairs(ENV.Phantom.Weights) do
			roll -= weight
			if roll <= 0 then
				kind = name
				break
			end
		end
	end
	local back = -root.CFrame.LookVector
	local behind = root.Position + back * (8 + math.random() * 6) + root.CFrame.RightVector * (math.random() * 8 - 4)

	if kind == "Footsteps" then
		-- someone walking on the floor above you... or right behind you
		local above = math.random() < 0.5
		local height = if above then 13 else -2.5
		local start = root.Position + back * 14 + Vector3.new(0, height, 0)
		local finish = root.Position + back * 3 + Vector3.new(0, height, 0)
		audio:PlaySequence("Player.Footstep.Concrete", start, finish, 6, 0.48, {})
	elseif kind == "Shutter" then
		audio:Play("Camera.Shutter", behind, {})
	elseif kind == "FlashlightClick" then
		audio:Play("Flashlight.On", behind, {})
		task.wait(0.8 + math.random())
		audio:Play("Flashlight.Off", behind, {})
	elseif kind == "DoorOpen" then
		local door = self.Services.InteractionService:GetNearestDoor(root.Position, 70)
		if door then
			local sounds = "Door." .. door.Type
			audio:Play(sounds .. ".Handle", door.Panel, {})
			audio:Play(sounds .. ".Open", door.Panel, {})
		else
			audio:Play("Door.Wood.Creak", behind, {})
		end
	elseif kind == "EMFBeep" then
		for _ = 1, math.random(3, 6) do
			audio:Play("EMF.Level" .. math.random(2, 4), behind, {})
			task.wait(0.3 + math.random() * 0.4)
		end
	elseif kind == "BatteryPickup" then
		audio:Play("Interaction.BatteryPickup", behind, {})
	elseif kind == "Knock" then
		self.RayParams.FilterDescendantsInstances = { self.Services.MapService.Folders.ActiveAnomalies }
		local side = if math.random() < 0.5 then root.CFrame.RightVector else -root.CFrame.RightVector
		local hit = Workspace:Raycast(root.Position, side * 40, self.RayParams)
		local position = if hit then hit.Position else root.Position + side * 20
		for _ = 1, 3 do
			audio:Play("Anomaly.Knock", position, {})
			task.wait(0.35)
		end
	end
end

return EnvironmentService
