--[[
	ShadowRunner (ModuleScript)
	Location: ServerScriptService/Anomalies/Behaviors/ShadowRunner

	Blackout only. A pitch-black silhouette sprints down a corridor, stops,
	stares back, and sprints again. Hard to frame - that's the fun.
]]

local ShadowRunner = {}

function ShadowRunner.Spawn(ctx, record)
	local marker = ctx:PickSpawn(record)
	if not marker then
		return false
	end
	local Kit = ctx.Kit
	local figure = Kit.Figure({
		Name = "ShadowRunner",
		Height = 6.8,
		Thin = 0.8,
		Color = Color3.fromRGB(4, 4, 5),
		EyeColor = Color3.fromRGB(255, 60, 60),
		ArmSwing = 45,
		LegSwing = 30,
	})
	local halfLength = (marker:GetAttribute("Length") or marker.Size.Z) / 2
	local laneStart = marker.CFrame * CFrame.new(0, 0, halfLength)
	local laneEnd = marker.CFrame * CFrame.new(0, 0, -halfLength)
	figure.Model:PivotTo(CFrame.lookAt(laneStart.Position, laneEnd.Position))
	figure.Model.Parent = ctx.Services.MapService.Folders.ActiveAnomalies

	record.Model = figure.Model
	record.Target = figure.Torso

	local runTime = record.Params.RunTime or 1.6
	local pause = record.Params.Pause or 1.4
	local root = figure.Root
	record.Cleaner:Add(task.spawn(function()
		local from, to = laneStart.Position, laneEnd.Position
		task.wait(0.4)
		while figure.Model.Parent do
			root.CFrame = CFrame.lookAt(from, to)
			local tween = Kit.TweenCFrame(root, CFrame.lookAt(to, to + (to - from).Unit), runTime, Enum.EasingStyle.Linear)
			Kit.PlaySound3D(root, "Anomaly.Skitter", nil, 0.7)
			tween.Completed:Wait()
			-- stop and stare back
			root.CFrame = CFrame.lookAt(to, from)
			task.wait(pause)
			from, to = to, from
		end
	end))
	return true
end

return ShadowRunner
