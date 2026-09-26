--[[
	MovingDoor (ModuleScript)
	Location: ServerScriptService/Anomalies/Behaviors/MovingDoor

	A door appears in a wall where there has never been a door. It creaks
	open onto pure darkness... and slams shut when it vanishes.
]]

local TweenService = game:GetService("TweenService")

local MovingDoor = {}

function MovingDoor.Spawn(ctx, record)
	local marker = ctx:PickSpawn(record)
	if not marker then
		return false
	end
	local Kit = ctx.Kit
	local base: CFrame = marker.CFrame -- at the wall surface, facing into the room
	local wood = Color3.fromRGB(92, 60, 40)
	local frameColor = Color3.fromRGB(60, 40, 28)
	local model = Kit.Model("MovingDoor")

	Kit.Part(model, { Name = "Lintel", Size = Vector3.new(6.2, 0.6, 0.6), CFrame = base * CFrame.new(0, 9.3, -0.3), Color = frameColor, Material = Enum.Material.Wood })
	Kit.Part(model, { Name = "Post", Size = Vector3.new(0.6, 9.3, 0.6), CFrame = base * CFrame.new(-2.8, 4.65, -0.3), Color = frameColor, Material = Enum.Material.Wood })
	Kit.Part(model, { Name = "Post", Size = Vector3.new(0.6, 9.3, 0.6), CFrame = base * CFrame.new(2.8, 4.65, -0.3), Color = frameColor, Material = Enum.Material.Wood })
	Kit.Part(model, { Name = "Void", Size = Vector3.new(5, 9, 0.1), CFrame = base * CFrame.new(0, 4.5, -0.06), Color = Color3.new(0, 0, 0), CanQuery = false })

	local hinge = Kit.Part(model, { Name = "Hinge", Size = Vector3.new(0.2, 9, 0.2), CFrame = base * CFrame.new(-2.5, 4.5, -0.3), Transparency = 1, CanQuery = false })
	local panel = Kit.Part(model, { Name = "Panel", Size = Vector3.new(5, 9, 0.35), CFrame = base * CFrame.new(0, 4.5, -0.3), Color = wood, Material = Enum.Material.Wood })
	local knob = Kit.Part(model, {
		Name = "Knob",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.45, 0.45, 0.45),
		CFrame = base * CFrame.new(1.9, 4.3, -0.6),
		Color = Color3.fromRGB(200, 170, 80),
		Material = Enum.Material.Metal,
	})
	Kit.WeldList(hinge, { panel, knob })
	model.PrimaryPart = panel
	model.Parent = ctx.Services.MapService.Folders.ActiveAnomalies
	Kit.FadeIn(model, 0.8)

	record.Model = model
	record.Target = panel
	record.State.Hinge = hinge
	record.State.Closed = hinge.CFrame

	local openAngle = math.rad(record.Params.OpenAngle or 70)
	local openTime = record.Params.OpenTime or 3
	record.Cleaner:Add(task.spawn(function()
		task.wait(1.2)
		while true do
			Kit.PlaySound3D(panel, "Anomaly.DoorCreak")
			Kit.TweenCFrame(hinge, record.State.Closed * CFrame.Angles(0, openAngle, 0), openTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			task.wait(openTime + 2.5)
			Kit.TweenCFrame(hinge, record.State.Closed * CFrame.Angles(0, openAngle * 0.35, 0), 1.6)
			task.wait(2.4)
		end
	end))
	return true
end

function MovingDoor.Despawn(ctx, record)
	local hinge = record.State.Hinge
	if hinge and hinge.Parent then
		local tween = TweenService:Create(hinge, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = record.State.Closed })
		tween:Play()
		ctx.Kit.PlaySound3D(hinge, "Door.Wood.Slam")
		task.wait(0.2)
	end
end

return MovingDoor
