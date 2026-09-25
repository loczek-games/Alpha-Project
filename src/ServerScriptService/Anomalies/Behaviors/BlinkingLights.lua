--[[
	BlinkingLights (ModuleScript)
	Location: ServerScriptService/Anomalies/Behaviors/BlinkingLights

	The lights in one zone blink a recognisable pattern (short-short-short,
	long-long-long, short-short-short). Every time the lights go dark a
	figure is revealed standing where nothing was.
]]

local BlinkingLights = {}

local PATTERN = {
	{ false, 0.15 }, { true, 0.15 }, { false, 0.15 }, { true, 0.15 }, { false, 0.15 }, { true, 0.45 },
	{ false, 1.1 }, { true, 0.25 }, { false, 1.1 }, { true, 0.25 }, { false, 1.1 }, { true, 0.45 },
	{ false, 0.15 }, { true, 0.15 }, { false, 0.15 }, { true, 0.15 }, { false, 0.15 }, { true, 2.2 },
}

function BlinkingLights.Spawn(ctx, record)
	local marker = ctx:PickSpawn(record)
	if not marker then
		return false
	end
	local Kit = ctx.Kit
	local figure = Kit.Figure({
		Name = "HiddenFigure",
		Height = 7.5,
		Thin = 0.85,
		Color = Color3.fromRGB(10, 10, 12),
		EyeColor = Color3.fromRGB(255, 40, 40),
	})
	local _, _, nearestRoot = ctx:GetNearestParticipant(marker.Position)
	local facing = if nearestRoot then Kit.YawTowards(marker.CFrame, nearestRoot.Position) else marker.CFrame
	figure.Model:PivotTo(facing)
	figure.Model.Parent = ctx.Services.MapService.Folders.ActiveAnomalies

	record.Model = figure.Model
	record.Target = figure.Torso
	record.NoFade = true -- the lights snap back on and the figure is simply gone

	local hiddenTransparency = record.Params.HiddenTransparency or 0.8
	local bodyParts = { figure.Torso, figure.Head, figure.LeftArm, figure.RightArm, figure.LeftLeg, figure.RightLeg }
	local function setRevealed(revealed: boolean)
		for _, part in ipairs(bodyParts) do
			part.Transparency = if revealed then 0 else hiddenTransparency
		end
	end
	setRevealed(false)

	local mapService = ctx.Services.MapService
	local lights = mapService:GetZoneLights(record.Zone or "MainHall")
	local running = true
	record.Cleaner:Add(task.spawn(function()
		task.wait(0.6)
		while running do
			for _, step in ipairs(PATTERN) do
				if not running then
					break
				end
				local on = step[1]
				for _, light in ipairs(lights) do
					mapService:SetLightOverride(light, if on then nil else false)
				end
				setRevealed(not on or mapService.Blackout)
				task.wait(step[2])
			end
		end
	end))
	record.Cleaner:Add(function()
		running = false
		for _, light in ipairs(lights) do
			mapService:SetLightOverride(light, nil)
		end
	end)
	return true
end

function BlinkingLights.Update(ctx, record)
	local _, _, root = ctx:GetNearestParticipant(record.Target.Position, 60)
	if root and record.Model.PrimaryPart then
		local primary = record.Model.PrimaryPart
		primary.CFrame = primary.CFrame:Lerp(ctx.Kit.YawTowards(primary.CFrame, root.Position), 0.15)
	end
end

return BlinkingLights
