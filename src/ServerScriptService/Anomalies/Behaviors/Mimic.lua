--[[
	Mimic (ModuleScript)
	Location: ServerScriptService/Anomalies/Behaviors/Mimic

	Hides in a dark corner and imitates normal gameplay sounds to trick
	players: a camera shutter, footsteps walking up behind you, a door opening,
	EMF beeps, a flashlight click, a battery pickup.
	  "I heard a camera... but nobody has one equipped."
	Its tricks usually come from where it hides - listen carefully to find it.
]]

local Mimic = {}

local TRICKS = { "Shutter", "Footsteps", "DoorOpen", "EMF", "FlashlightClick", "BatteryPickup", "Giggle" }
local ZONE_SURFACE = {
	MainHall = "Tile",
	FoodCourt = "Tile",
	ToyStore = "Tile",
	Bathrooms = "Tile",
	Arcade = "Carpet",
	Cinema = "Carpet",
	StorageHallway = "Concrete",
	ParkingGarage = "Concrete",
	SecurityOffice = "Tile",
}

function Mimic.Spawn(ctx, record)
	local marker = ctx:PickSpawn(record)
	if not marker then
		return false
	end
	local Kit = ctx.Kit
	local skin = Color3.fromRGB(58, 52, 50)
	local model = Kit.Model("Mimic")
	local root = Kit.Part(model, { Name = "Root", Size = Vector3.new(1, 0.2, 1), CFrame = CFrame.new(0, 0.1, 0), Transparency = 1, CanQuery = false })
	local body = Kit.Part(model, { Name = "Body", Size = Vector3.new(1.8, 2.2, 1.4), CFrame = CFrame.new(0, 1.6, 0) * CFrame.Angles(math.rad(-25), 0, 0), Color = skin })
	local head = Kit.Part(model, { Name = "Head", Size = Vector3.new(1.3, 1.3, 1.3), CFrame = CFrame.new(0.2, 3, -0.7) * CFrame.Angles(0, 0, math.rad(28)), Color = skin })
	Kit.Part(model, { Name = "Grin", Size = Vector3.new(1.1, 0.12, 0.05), CFrame = head.CFrame * CFrame.new(0, -0.25, -0.66), Color = Color3.fromRGB(240, 240, 230), Material = Enum.Material.Neon, CanQuery = false })
	for _, side in ipairs({ -1, 1 }) do
		Kit.Part(model, { Name = "Arm", Size = Vector3.new(0.25, 3.8, 0.25), CFrame = CFrame.new(side * 1.1, 1.7, -0.9) * CFrame.Angles(math.rad(20), 0, math.rad(side * 10)), Color = skin })
	end
	Kit.Weld(model, root)
	local floor = Vector3.new(marker.Position.X, 0, marker.Position.Z)
	model:PivotTo(CFrame.lookAt(floor, floor + marker.CFrame.LookVector * Vector3.new(1, 0, 1)))
	model.Parent = ctx.Services.MapService.Folders.ActiveAnomalies
	Kit.FadeIn(model, 1)

	record.Model = model
	record.Target = body
	local interval = record.Params.TrickInterval or { 5, 9 }
	record.State = { NextTrick = os.clock() + interval[1] }
	return true
end

function Mimic.Update(ctx, record)
	local state: any = record.State
	if os.clock() < state.NextTrick then
		return
	end
	local interval = record.Params.TrickInterval or { 5, 9 }
	state.NextTrick = os.clock() + interval[1] + math.random() * (interval[2] - interval[1])
	local here = record.Target.Position
	local victim, _, victimRoot = ctx:GetNearestParticipant(here, record.Params.LureRange or 60)
	if not victim or not victimRoot then
		return
	end
	local audio = ctx.Services.AudioService
	local trick = TRICKS[math.random(1, #TRICKS)]
	-- usually from its hiding spot, sometimes right behind the victim
	local origin = here
	if math.random() < 0.4 then
		origin = victimRoot.Position - victimRoot.CFrame.LookVector * (8 + math.random() * 6)
	end

	task.spawn(function()
		if trick == "Shutter" then
			audio:Play("Camera.ButtonClick", origin, {})
			task.wait(0.08)
			audio:Play("Camera.Shutter", origin, {})
			audio:Play("Camera.FlashCharge", origin, {})
		elseif trick == "Footsteps" then
			local surface = ZONE_SURFACE[record.Zone or ""] or "Concrete"
			local start = victimRoot.Position - victimRoot.CFrame.LookVector * 16 + Vector3.new(0, -2.5, 0)
			local finish = victimRoot.Position - victimRoot.CFrame.LookVector * 4 + Vector3.new(0, -2.5, 0)
			audio:PlaySequence("Player.Footstep." .. surface, start, finish, 6, 0.5, {})
		elseif trick == "DoorOpen" then
			local door = ctx.Services.InteractionService:GetNearestDoor(victimRoot.Position, 60)
			if door then
				audio:Play("Door." .. door.Type .. ".Handle", door.Panel, {})
				audio:Play("Door." .. door.Type .. ".Open", door.Panel, {})
			else
				audio:Play("Door.Wood.Creak", origin, {})
			end
		elseif trick == "EMF" then
			for _ = 1, 5 do
				audio:Play("EMF.Level4", origin, {})
				task.wait(0.38)
			end
		elseif trick == "FlashlightClick" then
			audio:Play("Flashlight.On", origin, {})
			task.wait(1 + math.random())
			audio:Play("Flashlight.Off", origin, {})
		elseif trick == "BatteryPickup" then
			audio:Play("Interaction.BatteryPickup", origin, {})
		else
			audio:Play("Anomaly.MimicGiggle", here, {})
		end
	end)
end

return Mimic
