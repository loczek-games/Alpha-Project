--[[
	GlowingEyes (ModuleScript)
	Location: ServerScriptService/Anomalies/Behaviors/GlowingEyes

	Blackout only. Two glowing eyes in a dark corner that follow you and blink.
]]

local TweenService = game:GetService("TweenService")

local GlowingEyes = {}

local EYE_COLORS = {
	Color3.fromRGB(255, 225, 90),
	Color3.fromRGB(255, 60, 60),
	Color3.fromRGB(140, 255, 160),
}

function GlowingEyes.Spawn(ctx, record)
	local marker = ctx:PickSpawn(record)
	if not marker then
		return false
	end
	local Kit = ctx.Kit
	local color = EYE_COLORS[math.random(1, #EYE_COLORS)]
	local model = Kit.Model("GlowingEyes")
	local root = Kit.Part(model, { Name = "Root", Size = Vector3.new(1.4, 0.8, 0.4), CFrame = CFrame.new(), Transparency = 1 })
	local eyes = {}
	for _, side in ipairs({ -1, 1 }) do
		table.insert(eyes, Kit.Part(model, {
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.45, 0.45, 0.45),
			CFrame = CFrame.new(side * 0.36, 0, -0.1),
			Color = color,
			Material = Enum.Material.Neon,
		}))
	end
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 7
	light.Brightness = 1.5
	light.Shadows = false
	light.Parent = root
	Kit.Weld(model, root)
	model:PivotTo(marker.CFrame)
	model.Parent = ctx.Services.MapService.Folders.ActiveAnomalies
	Kit.FadeIn(model, 0.8)

	record.Model = model
	record.Target = root
	record.State.Root = root

	record.Cleaner:Add(task.spawn(function()
		task.wait(1)
		while model.Parent do
			task.wait(1.5 + math.random() * 2)
			for _, eye in ipairs(eyes) do
				eye.Transparency = 1
			end
			task.wait(0.12)
			for _, eye in ipairs(eyes) do
				eye.Transparency = 0
			end
		end
	end))
	return true
end

function GlowingEyes.Update(ctx, record)
	local root: BasePart = record.State.Root
	local _, _, _, head = ctx:GetNearestParticipant(root.Position, 60)
	if head then
		TweenService:Create(root, TweenInfo.new(0.3), { CFrame = CFrame.lookAt(root.Position, head.Position) }):Play()
	end
end

return GlowingEyes
