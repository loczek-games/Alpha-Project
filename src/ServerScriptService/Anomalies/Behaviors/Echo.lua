--[[
	Echo (ModuleScript)
	Location: ServerScriptService/Anomalies/Behaviors/Echo

	A floating pale mask that listens for REPEATED sounds. If a player keeps
	clicking a flashlight, taking photos, beeping an EMF or talking, Echo moves
	somewhere else and plays those same sounds back from there.
	Follow the copied sounds to find it.
]]

local Echo = {}

-- noise kinds Echo copies (kinds without a sound path fall back to a voice)
local REPEATABLE = {
	Shutter = true,
	Flash = true,
	Focus = true,
	FlashlightClick = true,
	FlashlightMalfunction = true,
	Voice = true,
	EMF = true,
	DoorOpen = true,
	DoorSlam = true,
	Interaction = true,
	Radio = true,
}

function Echo.Spawn(ctx, record)
	local marker = ctx:PickSpawn(record)
	if not marker then
		return false
	end
	local Kit = ctx.Kit
	local model = Kit.Model("Echo")
	local mask = Kit.Part(model, { Name = "Mask", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2), CFrame = CFrame.new(), Color = Color3.fromRGB(232, 226, 214) })
	for _, side in ipairs({ -1, 1 }) do
		Kit.Part(model, { Name = "EyeHole", Size = Vector3.new(0.45, 0.25, 0.1), CFrame = CFrame.new(side * 0.42, 0.25, -1.05), Color = Color3.fromRGB(5, 5, 5), CanQuery = false })
	end
	Kit.Part(model, { Name = "Mouth", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.9, 0.3), CFrame = CFrame.new(0, -0.45, -1), Color = Color3.fromRGB(5, 5, 5), CanQuery = false })
	Kit.Weld(model, mask)
	local base = marker.CFrame + Vector3.new(0, if marker:GetAttribute("Kind") == "Floor" then 5 else 1.5, 0)
	model:PivotTo(base)
	model.Parent = ctx.Services.MapService.Folders.ActiveAnomalies
	Kit.FadeIn(model, 1)

	record.Model = model
	record.Target = mask
	record.State = { Mask = mask, Base = base, NextEcho = os.clock() + 2, Busy = false, Time = 0 }
	return true
end

local function findRepeater(ctx, record)
	local params = record.Params
	local position = record.Target.Position
	for _, player in ipairs(ctx:GetParticipants()) do
		local root = ctx:GetCharacterParts(player)
		if root and (root.Position - position).Magnitude <= (params.ListenRadius or 70) then
			local copies = {}
			for _, entry in ipairs(ctx.Services.NoiseService:GetRecentFrom(player, params.RepeatWindow or 8)) do
				if REPEATABLE[entry.Kind] then
					table.insert(copies, entry)
				end
			end
			if #copies >= (params.RepeatCount or 3) then
				return player, copies
			end
		end
	end
	return nil, nil
end

function Echo.Update(ctx, record, dt)
	local state: any = record.State
	state.Time += dt
	if not state.Busy then
		-- gentle float
		state.Mask.CFrame = state.Base * CFrame.new(0, math.sin(state.Time * 1.4) * 0.4, 0) * CFrame.Angles(0, math.sin(state.Time * 0.5) * 0.4, 0)
	end
	if state.Busy or os.clock() < state.NextEcho then
		return
	end
	local _, copies = findRepeater(ctx, record)
	if not copies then
		return
	end
	state.Busy = true
	state.NextEcho = os.clock() + (record.Params.Cooldown or 6)
	task.spawn(function()
		task.wait(1.2)
		if record.Despawning or not record.Model.Parent then
			return
		end
		-- move somewhere else first, so the copies come "from elsewhere"
		local here = record.Target.Position
		local options = {}
		for _, markerPart in ipairs(ctx.Services.MapService:GetMarkers({ "Floor", "Dark" }, nil)) do
			local distance = (markerPart.Position - here).Magnitude
			if ctx:IsFree(markerPart) and distance > 18 and distance < 50 then
				table.insert(options, markerPart)
			end
		end
		if #options > 0 then
			ctx.Kit.FadeOut(record.Model, 0.3)
			task.wait(0.35)
			if record.Despawning then
				return
			end
			local destination = options[math.random(1, #options)]
			state.Base = destination.CFrame + Vector3.new(0, if destination:GetAttribute("Kind") == "Floor" then 5 else 1.5, 0)
			record.Model:PivotTo(state.Base)
			ctx.Kit.FadeIn(record.Model, 0.4)
		end
		for index = math.max(1, #copies - 3), #copies do
			if record.Despawning then
				return
			end
			local entry = copies[index]
			local path = entry.Path or (if entry.Kind == "Voice" then "Anomaly.EchoVoice" else "Anomaly.EchoWhisper")
			ctx.Kit.PlaySound3D(record.Target, path)
			task.wait(0.45 + math.random() * 0.5)
		end
		ctx.Kit.PlaySound3D(record.Target, "Anomaly.EchoWhisper")
		state.Busy = false
	end)
end

return Echo
