--[[
	TheNightManager (ModuleScript)
	Location: ServerScriptService/Anomalies/Behaviors/TheNightManager

	???. The PA announces that the mall is closed and every light turns red.
	A very tall figure in a suit with a glowing MANAGER badge stands in the
	mall, facing the nearest shopper, and blinks to a new spot every few
	seconds.
]]

local TheNightManager = {}

local function surfaceLabel(part: BasePart, text: string, color: Color3, background: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = background
	label.Text = text
	label.TextColor3 = color
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Parent = gui
end

function TheNightManager.Spawn(ctx, record)
	local marker = ctx:PickSpawn(record)
	if not marker then
		return false
	end
	local Kit = ctx.Kit
	local figure = Kit.Figure({
		Name = "TheNightManager",
		Height = 8.8,
		Thin = 0.9,
		Color = Color3.fromRGB(24, 27, 44),
		HeadColor = Color3.fromRGB(235, 230, 224),
		EyeColor = Color3.fromRGB(255, 255, 255),
	})
	local torso = figure.Torso
	local head = figure.Head
	local shirt = Kit.Part(figure.Model, { Name = "Shirt", Size = Vector3.new(torso.Size.X * 0.3, torso.Size.Y * 0.9, 0.05), CFrame = torso.CFrame * CFrame.new(0, 0.05, -torso.Size.Z / 2 - 0.02), Color = Color3.fromRGB(240, 240, 240) })
	local tie = Kit.Part(figure.Model, { Name = "Tie", Size = Vector3.new(torso.Size.X * 0.1, torso.Size.Y * 0.75, 0.05), CFrame = torso.CFrame * CFrame.new(0, 0.1, -torso.Size.Z / 2 - 0.05), Color = Color3.fromRGB(200, 20, 30) })
	local badge = Kit.Part(figure.Model, { Name = "Badge", Size = Vector3.new(0.9, 0.35, 0.05), CFrame = torso.CFrame * CFrame.new(torso.Size.X * 0.28, torso.Size.Y * 0.25, -torso.Size.Z / 2 - 0.04), Color = Color3.fromRGB(255, 215, 90), Material = Enum.Material.Neon })
	surfaceLabel(badge, "MANAGER", Color3.fromRGB(20, 20, 20), Color3.fromRGB(255, 215, 90))
	local smile = Kit.Part(figure.Model, { Name = "Smile", Size = Vector3.new(head.Size.X * 0.7, 0.12, 0.05), CFrame = head.CFrame * CFrame.new(0, -head.Size.Y * 0.22, -head.Size.Z / 2 - 0.02), Color = Color3.fromRGB(10, 10, 10), CanQuery = false })
	Kit.WeldList(figure.Root, { shirt, tie, badge, smile })

	local _, _, nearest = ctx:GetNearestParticipant(marker.Position)
	figure.Model:PivotTo(if nearest then Kit.YawTowards(marker.CFrame, nearest.Position) else marker.CFrame)
	figure.Model.Parent = ctx.Services.MapService.Folders.ActiveAnomalies
	Kit.FadeIn(figure.Model, 0.6)

	local mapService = ctx.Services.MapService
	mapService:PushTint("TheNightManager", Color3.fromRGB(255, 130, 130), -0.35, 0.2)
	record.Cleaner:Add(function()
		mapService:PopTint("TheNightManager")
	end)
	ctx:Announce({
		Kind = "Banner",
		Text = "📢 ATTENTION SHOPPERS. THE MALL IS NOW CLOSED.",
		Color = Color3.fromRGB(255, 80, 80),
		Duration = 3.5,
	})

	record.Model = figure.Model
	record.Target = torso
	record.State = {
		Root = figure.Root,
		NextBlink = os.clock() + (record.Params.BlinkInterval or 6),
		Blinking = false,
	}
	return true
end

function TheNightManager.Update(ctx, record)
	local state: any = record.State
	local root: BasePart = state.Root
	if state.Blinking then
		return
	end
	local _, _, nearest = ctx:GetNearestParticipant(root.Position, 120)
	if nearest then
		root.CFrame = root.CFrame:Lerp(ctx.Kit.YawTowards(root.CFrame, nearest.Position), 0.3)
	end
	if os.clock() < state.NextBlink then
		return
	end
	state.NextBlink = os.clock() + (record.Params.BlinkInterval or 6)
	local markers = ctx.Services.MapService:GetMarkers(record.Def.Spawn.Kinds, record.Def.Spawn.Zones)
	local options = {}
	for _, markerPart in ipairs(markers) do
		if ctx:IsFree(markerPart) then
			table.insert(options, markerPart)
		end
	end
	if #options == 0 then
		return
	end
	local destination = options[math.random(1, #options)]
	state.Blinking = true
	task.spawn(function()
		ctx.Kit.FadeOut(record.Model, 0.25)
		task.wait(0.3)
		if record.Despawning or not record.Model.Parent then
			return
		end
		record.Model:PivotTo(destination.CFrame)
		ctx.Kit.FadeIn(record.Model, 0.25)
		state.Blinking = false
	end)
end

return TheNightManager
