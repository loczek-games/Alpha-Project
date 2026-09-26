--[[
	WatchingMannequin (ModuleScript)
	Location: ServerScriptService/Anomalies/Behaviors/WatchingMannequin

	A mannequin stands where there was none. It creaks around to face the
	nearest player.
]]

local WatchingMannequin = {}

function WatchingMannequin.Spawn(ctx, record)
	local marker = ctx:PickSpawn(record)
	if not marker then
		return false
	end
	local Kit = ctx.Kit
	local skin = Color3.fromRGB(236, 230, 220)
	local model = Kit.Model("Mannequin")
	local root = Kit.Part(model, { Name = "Root", Size = Vector3.new(1, 0.2, 1), CFrame = CFrame.new(0, 0.1, 0), Transparency = 1, CanQuery = false })
	Kit.Part(model, {
		Name = "Stand",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 2.4, 2.4),
		CFrame = CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(45, 45, 50),
		Material = Enum.Material.Metal,
	})
	Kit.Part(model, { Name = "LeftLeg", Size = Vector3.new(0.55, 2.8, 0.6), CFrame = CFrame.new(-0.35, 1.7, 0), Color = skin })
	Kit.Part(model, { Name = "RightLeg", Size = Vector3.new(0.55, 2.8, 0.6), CFrame = CFrame.new(0.35, 1.7, 0), Color = skin })
	Kit.Part(model, { Name = "Hips", Size = Vector3.new(1.3, 0.6, 0.7), CFrame = CFrame.new(0, 3.35, 0), Color = skin })
	local torso = Kit.Part(model, { Name = "Torso", Size = Vector3.new(1.45, 2, 0.75), CFrame = CFrame.new(0, 4.6, 0), Color = skin })
	Kit.Part(model, { Name = "LeftArm", Size = Vector3.new(0.4, 2.4, 0.45), CFrame = CFrame.new(-0.98, 5.5, 0) * CFrame.Angles(0, 0, math.rad(-8)) * CFrame.new(0, -1.1, 0), Color = skin })
	Kit.Part(model, { Name = "RightArm", Size = Vector3.new(0.4, 2.4, 0.45), CFrame = CFrame.new(0.98, 5.5, 0) * CFrame.Angles(math.rad(-25), 0, math.rad(8)) * CFrame.new(0, -1.1, 0), Color = skin })
	Kit.Part(model, { Name = "Neck", Size = Vector3.new(0.35, 0.4, 0.35), CFrame = CFrame.new(0, 5.8, 0), Color = skin })
	Kit.Part(model, { Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(1.15, 1.15, 1.15), CFrame = CFrame.new(0, 6.5, 0), Color = skin })
	Kit.Weld(model, root)

	model:PivotTo(marker.CFrame)
	model.Parent = ctx.Services.MapService.Folders.ActiveAnomalies
	Kit.FadeIn(model, 0.7)

	record.Model = model
	record.Target = torso
	record.State.Root = root
	record.State.NextTurn = os.clock() + 1
	return true
end

function WatchingMannequin.Update(ctx, record)
	local state: any = record.State
	if os.clock() < state.NextTurn then
		return
	end
	state.NextTurn = os.clock() + (record.Params.TurnInterval or 0.8)
	local root: BasePart = state.Root
	local _, _, targetRoot = ctx:GetNearestParticipant(root.Position, record.Params.WatchRange or 70)
	if not targetRoot then
		return
	end
	local desired = ctx.Kit.YawTowards(root.CFrame, targetRoot.Position)
	if ctx.Kit.YawDifference(root.CFrame, desired) > 5 then
		ctx.Kit.TweenCFrame(root, desired, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		ctx.Kit.PlaySound3D(record.Target, "Anomaly.DoorCreak", nil, 1.3)
	end
end

return WatchingMannequin
