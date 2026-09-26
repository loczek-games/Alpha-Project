--[[
	LightCreature (ModuleScript)
	Location: ServerScriptService/Anomalies/Behaviors/LightCreature

	A pale crouching thing that lives in dark corners.
	  * Pointing a flashlight or UV beam at it makes it shriek and vanish:
	    approach with your light OFF and photograph it.
	  * It hears flashlight CLICKS nearby and scuttles to another dark corner.
	  * The camera flash of your photo burns it away (after the capture counts).
]]

local LightCreature = {}

local LIGHT_ITEMS = { "Flashlight", "UVLight" }

local function floorBelow(position: Vector3): Vector3
	return Vector3.new(position.X, 0, position.Z)
end

local function build(ctx)
	local Kit = ctx.Kit
	local pale = Color3.fromRGB(214, 212, 200)
	local model = Kit.Model("LightCreature")
	local root = Kit.Part(model, { Name = "Root", Size = Vector3.new(1, 0.2, 1), CFrame = CFrame.new(0, 0.1, 0), Transparency = 1, CanQuery = false })
	local body = Kit.Part(model, { Name = "Body", Size = Vector3.new(1.7, 1.3, 2.6), CFrame = CFrame.new(0, 1.3, 0.2) * CFrame.Angles(math.rad(-12), 0, 0), Color = pale })
	local head = Kit.Part(model, { Name = "Head", Size = Vector3.new(1.3, 1.1, 1.3), CFrame = CFrame.new(0, 1.9, -1.35), Color = pale })
	for _, side in ipairs({ -1, 1 }) do
		Kit.Part(model, { Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), CFrame = head.CFrame * CFrame.new(side * 0.32, 0.1, -0.6), Color = Color3.fromRGB(10, 10, 12), Material = Enum.Material.Glass, Reflectance = 0.6, CanQuery = false })
		Kit.Part(model, { Name = "Arm", Size = Vector3.new(0.22, 2.4, 0.22), CFrame = CFrame.new(side * 0.9, 1.1, -1.2) * CFrame.Angles(math.rad(25), 0, math.rad(side * 18)), Color = pale })
		Kit.Part(model, { Name = "Leg", Size = Vector3.new(0.3, 1.6, 0.3), CFrame = CFrame.new(side * 0.8, 0.8, 1.2) * CFrame.Angles(math.rad(-30), 0, 0), Color = pale })
	end
	Kit.Weld(model, root)
	return model, root, body
end

function LightCreature.Spawn(ctx, record)
	local marker = ctx:PickSpawn(record)
	if not marker then
		return false
	end
	local model, root, body = build(ctx)
	model:PivotTo(CFrame.lookAt(floorBelow(marker.Position), floorBelow(marker.Position) + marker.CFrame.LookVector * Vector3.new(1, 0, 1)))
	model.Parent = ctx.Services.MapService.Folders.ActiveAnomalies
	ctx.Kit.FadeIn(model, 0.8)

	record.Model = model
	record.Target = body
	record.State = { Root = root, LastHeardId = 0, NextHiss = os.clock() + 3, Burned = false }
	local _, _, newest = ctx.Services.NoiseService:Listen(body.Position, { Radius = 0 }, 0)
	record.State.LastHeardId = newest
	return true
end

local function burn(ctx, record, player: Player?)
	if record.State.Burned then
		return
	end
	record.State.Burned = true
	ctx.Kit.PlaySound3D(record.Target, "Anomaly.LightCreatureShriek")
	if player then
		ctx.AnnounceRemote:FireClient(player, { Kind = "Toast", Text = "💡 It shrieked and fled from your light!", Color = Color3.fromRGB(255, 240, 180) })
	end
	ctx:Despawn(record, "Light")
end

function LightCreature.Update(ctx, record)
	local state: any = record.State
	local position = record.Target.Position
	local equipment = ctx.Services.EquipmentService

	-- flashlight / UV beam on it = gone
	for _, player in ipairs(ctx:GetParticipants()) do
		for _, itemId in ipairs(LIGHT_ITEMS) do
			if equipment:IsOn(player, itemId) then
				local handle = equipment:GetHandle(player, itemId)
				local beam = handle and handle:FindFirstChild("Beam")
				if handle and beam and beam:IsA("SpotLight") and beam.Enabled then
					local offset = position - handle.Position
					local range = record.Params.BeamRange or 30
					if offset.Magnitude < range then
						local angle = math.deg(math.acos(math.clamp(handle.CFrame.LookVector:Dot(offset.Unit), -1, 1)))
						if angle < (record.Params.BeamConeDeg or 28) then
							burn(ctx, record, player)
							return
						end
					end
				end
			end
		end
	end

	-- a flashlight click nearby: scuttle to another dark corner
	local event, _, newest = ctx.Services.NoiseService:Listen(position, record.Def.Hearing, state.LastHeardId)
	state.LastHeardId = newest
	if event and not state.Moving then
		local options = {}
		for _, markerPart in ipairs(ctx.Services.MapService:GetMarkers({ "Dark" }, nil)) do
			if ctx:IsFree(markerPart) and (markerPart.Position - position).Magnitude > 15 and (markerPart.Position - position).Magnitude < 70 then
				table.insert(options, markerPart)
			end
		end
		if #options > 0 then
			state.Moving = true
			local destination = options[math.random(1, #options)]
			ctx.Kit.PlaySound3D(record.Target, "Anomaly.Skitter")
			task.spawn(function()
				ctx.Kit.FadeOut(record.Model, 0.2)
				task.wait(0.25)
				if record.Despawning or not record.Model.Parent then
					return
				end
				local floor = floorBelow(destination.Position)
				record.Model:PivotTo(CFrame.lookAt(floor, floor + destination.CFrame.LookVector * Vector3.new(1, 0, 1)))
				ctx.Kit.FadeIn(record.Model, 0.3)
				state.Moving = false
			end)
		end
	end

	if os.clock() >= state.NextHiss then
		state.NextHiss = os.clock() + 4 + math.random() * 4
		ctx.Kit.PlaySound3D(record.Target, "Anomaly.LightCreatureHiss")
	end
end

-- the camera flash burns it away (the photo still counts)
function LightCreature.OnCaptured(ctx, record, player)
	task.wait(0.35)
	burn(ctx, record, player)
end

return LightCreature
