--[[
	ThePhotographer (ModuleScript)
	Location: ServerScriptService/Anomalies/Behaviors/ThePhotographer

	A pale figure holding an old camera. When you photograph it, it turns
	to face you... and takes YOUR picture: a flash, then your screen goes
	black (client FxController). Awards the "Photographed Back" special
	discovery + badge.
]]

local ThePhotographer = {}

function ThePhotographer.Spawn(ctx, record)
	local marker = ctx:PickSpawn(record)
	if not marker then
		return false
	end
	local Kit = ctx.Kit
	local figure = Kit.Figure({
		Name = "ThePhotographer",
		Height = 7.8,
		Thin = 0.9,
		Color = Color3.fromRGB(34, 28, 26),
		HeadColor = Color3.fromRGB(222, 216, 206),
		EyeColor = Color3.fromRGB(5, 5, 5),
		EyeGlow = false,
		ArmSwing = 55,
	})
	local torsoCFrame = figure.Torso.CFrame
	local cameraBody = Kit.Part(figure.Model, {
		Name = "OldCamera",
		Size = Vector3.new(1.7, 1.3, 1.1),
		CFrame = torsoCFrame * CFrame.new(0, 0.3, -1.3),
		Color = Color3.fromRGB(20, 20, 22),
	})
	local lens = Kit.Part(figure.Model, {
		Name = "Lens",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.7, 0.8, 0.8),
		CFrame = cameraBody.CFrame * CFrame.new(0, 0, -0.85) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(60, 60, 64),
		Material = Enum.Material.Metal,
	})
	local bulb = Kit.Part(figure.Model, {
		Name = "Bulb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.6, 0.6, 0.6),
		CFrame = cameraBody.CFrame * CFrame.new(0.5, 0.95, -0.2),
		Color = Color3.fromRGB(230, 230, 220),
		Material = Enum.Material.Glass,
	})
	local flash = Instance.new("PointLight")
	flash.Name = "Flash"
	flash.Brightness = 12
	flash.Range = 40
	flash.Enabled = false
	flash.Shadows = false
	flash.Parent = bulb
	Kit.WeldList(figure.Root, { cameraBody, lens, bulb })

	figure.Model:PivotTo(marker.CFrame)
	figure.Model.Parent = ctx.Services.MapService.Folders.ActiveAnomalies
	Kit.FadeIn(figure.Model, 1)

	record.Model = figure.Model
	record.Target = figure.Torso
	record.State = {
		Root = figure.Root,
		Bulb = bulb,
		Flash = flash,
		NextLook = os.clock() + 3,
		LockedUntil = 0,
	}
	return true
end

-- It hears cameras: autofocus makes it stare at you, a shutter or flash makes it shoot back.
local function reactToCameras(ctx, record)
	local state: any = record.State
	local event, _, newest = ctx.Services.NoiseService:Listen(record.Target.Position, record.Def.Hearing, state.LastHeardId or 0)
	state.LastHeardId = newest
	if not event or not event.Source then
		return
	end
	local player = event.Source
	local _, head = ctx:GetCharacterParts(player)
	if not head then
		return
	end
	local root: BasePart = state.Root
	state.LockedUntil = os.clock() + 2.5
	ctx.Kit.TweenCFrame(root, ctx.Kit.YawTowards(root.CFrame, head.Position), 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	if event.Kind ~= "Focus" and os.clock() >= (state.NextFlashBack or 0) then
		state.NextFlashBack = os.clock() + 5
		task.delay(0.4, function()
			if record.Despawning or not state.Flash.Parent then
				return
			end
			state.Flash.Enabled = true
			ctx.Kit.PlaySound3D(state.Bulb, "Anomaly.PhotographerFlash")
			ctx:FireFx(player, { Type = "FlashedBy" })
			task.wait(0.12)
			if state.Flash.Parent then
				state.Flash.Enabled = false
			end
		end)
	end
end

function ThePhotographer.Update(ctx, record)
	local state: any = record.State
	reactToCameras(ctx, record)
	if os.clock() < state.LockedUntil or os.clock() < state.NextLook then
		return
	end
	state.NextLook = os.clock() + 3
	local root: BasePart = state.Root
	ctx.Kit.TweenCFrame(root, root.CFrame * CFrame.Angles(0, math.rad(math.random(-60, 60)), 0), 1.2)
end

function ThePhotographer.OnCaptured(ctx, record, player)
	local state: any = record.State
	local _, head = ctx:GetCharacterParts(player)
	if not head then
		return
	end
	state.LockedUntil = os.clock() + 3
	local root: BasePart = state.Root
	ctx.Kit.TweenCFrame(root, ctx.Kit.YawTowards(root.CFrame, head.Position), 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.wait(0.35)
	if not state.Flash.Parent then
		return
	end
	state.Flash.Enabled = true
	state.Bulb.Material = Enum.Material.Neon
	ctx.Kit.PlaySound3D(state.Bulb, "Anomaly.PhotographerFlash")
	ctx.Kit.PlaySound3D(state.Bulb, "Camera.Shutter")
	local newAchievement = ctx.Services.DataService:GrantAchievement(player, "PhotographedBack")
	ctx:FireFx(player, { Type = "PhotographedBack", NewAchievement = newAchievement })
	task.wait(0.15)
	if state.Flash.Parent then
		state.Flash.Enabled = false
		state.Bulb.Material = Enum.Material.Glass
	end
end

return ThePhotographer
