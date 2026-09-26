--[[
	CeilingWatcher (ModuleScript)
	Location: ServerScriptService/Anomalies/Behaviors/CeilingWatcher

	A long-limbed creature clings to the ceiling. Its head twists to follow
	the nearest player, and halfway through its short life it skitters.
]]

local CeilingWatcher = {}

local HEAD_OFFSET = CFrame.new(0, -1.9, -2.6)

function CeilingWatcher.Spawn(ctx, record)
	local marker = ctx:PickSpawn(record)
	if not marker then
		return false
	end
	local Kit = ctx.Kit
	local skin = Color3.fromRGB(46, 40, 44)
	local model = Kit.Model("CeilingWatcher")
	local root = Kit.Part(model, { Name = "Root", Size = Vector3.new(1, 0.2, 1), CFrame = CFrame.new(), Transparency = 1, CanQuery = false })
	local body = Kit.Part(model, { Name = "Body", Size = Vector3.new(1.6, 1, 4.2), CFrame = CFrame.new(0, -1, 0), Color = skin })
	local limbs = {}
	for _, x in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1, 1 }) do
			local limb = Kit.Part(model, {
				Name = "Limb",
				Size = Vector3.new(0.3, 0.3, 3.6),
				CFrame = CFrame.new(x * 1.9, -0.55, z * 1.6) * CFrame.Angles(math.rad(z * 12), math.rad(x * z * 40), 0),
				Color = skin,
			})
			table.insert(limbs, limb)
		end
	end
	Kit.WeldList(root, { body, table.unpack(limbs) })
	model.PrimaryPart = root

	local head = Kit.Part(model, { Name = "Head", Size = Vector3.new(1.3, 1.1, 1.3), CFrame = HEAD_OFFSET, Color = skin })
	local eyes = {}
	for _, side in ipairs({ -1, 1 }) do
		table.insert(eyes, Kit.Part(model, {
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.3, 0.3, 0.3),
			CFrame = HEAD_OFFSET * CFrame.new(side * 0.3, 0.1, -0.66),
			Color = Color3.fromRGB(255, 255, 240),
			Material = Enum.Material.Neon,
			CanQuery = false,
		}))
	end
	Kit.WeldList(head, eyes)

	model:PivotTo(CFrame.new(marker.Position) * CFrame.Angles(0, math.rad(math.random(0, 359)), 0))
	model.Parent = ctx.Services.MapService.Folders.ActiveAnomalies
	Kit.FadeIn(model, 0.3)

	record.Model = model
	record.Target = body
	record.State = { Root = root, Head = head, Skittered = false }
	return true
end

function CeilingWatcher.Update(ctx, record)
	local state: any = record.State
	local root: BasePart = state.Root
	local head: BasePart = state.Head
	local lifeFraction = (workspace:GetServerTimeNow() - record.SpawnTime) / record.Lifetime
	if not state.Skittered and lifeFraction > 0.45 then
		state.Skittered = true
		ctx.Kit.TweenCFrame(root, root.CFrame * CFrame.new(0, 0, -8) * CFrame.Angles(0, math.rad(35), 0), 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		ctx.Kit.PlaySound3D(root, "Anomaly.Skitter")
	end
	local headPosition = (root.CFrame * HEAD_OFFSET).Position
	local _, _, _, targetHead = ctx:GetNearestParticipant(headPosition, 80)
	if targetHead then
		head.CFrame = head.CFrame:Lerp(CFrame.lookAt(headPosition, targetHead.Position), 0.5)
	else
		head.CFrame = root.CFrame * HEAD_OFFSET
	end
end

return CeilingWatcher
