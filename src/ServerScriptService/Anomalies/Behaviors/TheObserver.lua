--[[
	TheObserver (ModuleScript)
	Location: ServerScriptService/Anomalies/Behaviors/TheObserver

	IMPOSSIBLE. A colossal eye fills the skylight above the main hall and
	follows the nearest player. The whole mall is tinted red while it looks.
]]

local TweenService = game:GetService("TweenService")

local TheObserver = {}

function TheObserver.Spawn(ctx, record)
	local marker = ctx:PickSpawn(record)
	if not marker then
		return false
	end
	local Kit = ctx.Kit
	local model = Kit.Model("TheObserver")
	local sclera = Kit.Part(model, {
		Name = "Sclera",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(26, 26, 26),
		CFrame = CFrame.new(),
		Color = Color3.fromRGB(238, 232, 222),
	})
	Kit.Part(model, {
		Name = "Iris",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(13, 13, 13),
		CFrame = CFrame.new(0, 0, -10.2),
		Color = Color3.fromRGB(150, 20, 34),
	})
	local pupil = Kit.Part(model, {
		Name = "Pupil",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(6, 6, 6),
		CFrame = CFrame.new(0, 0, -14.4),
		Color = Color3.fromRGB(5, 5, 5),
	})
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 60, 60)
	glow.Range = 60
	glow.Brightness = 2
	glow.Shadows = false
	glow.Parent = pupil
	Kit.Weld(model, sclera)

	local center = marker.Position
	model:PivotTo(CFrame.lookAt(center, center - Vector3.new(0, 1, 0.01)))
	model.Parent = ctx.Services.MapService.Folders.ActiveAnomalies
	Kit.FadeIn(model, 1.5)

	local mapService = ctx.Services.MapService
	mapService:PushTint("TheObserver", Color3.fromRGB(255, 200, 200), -0.25, 0.15)
	record.Cleaner:Add(function()
		mapService:PopTint("TheObserver")
	end)
	Kit.PlaySound3D(sclera, "Anomaly.ObserverDrone")

	record.Model = model
	record.Target = pupil
	record.State.Root = sclera
	record.State.Center = center
	return true
end

function TheObserver.Update(ctx, record)
	local state: any = record.State
	local _, _, _, head = ctx:GetNearestParticipant(state.Center, 260)
	local focus = if head then head.Position else state.Center - Vector3.new(0, 40, 0.01)
	TweenService:Create(state.Root, TweenInfo.new(0.35, Enum.EasingStyle.Sine), {
		CFrame = CFrame.lookAt(state.Center, focus),
	}):Play()
end

return TheObserver
