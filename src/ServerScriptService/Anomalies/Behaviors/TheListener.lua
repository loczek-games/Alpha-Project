--[[
	TheListener (ModuleScript)
	Location: ServerScriptService/Anomalies/Behaviors/TheListener

	A tall, eyeless thing that hunts by SOUND (NoiseService).
	  * It hears running, landings, door slams, camera shutters, chat, radios...
	    (see AnomalyConfig Hearing). Sneaking past it is almost silent.
	  * When it hears something it clicks, turns and rushes to where the noise
	    came from. Thunder or HVAC noise can mask you.
	  * If it reaches a player: jumpscare, short stun, drained battery - and it's gone.
	"I can photograph it... but the shutter might hear me."
]]

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local TheListener = {}

function TheListener.Spawn(ctx, record)
	local marker = ctx:PickSpawn(record)
	if not marker then
		return false
	end
	local Kit = ctx.Kit
	local skin = Color3.fromRGB(38, 32, 36)
	local figure = Kit.Figure({
		Name = "TheListener",
		Height = 8.2,
		Thin = 0.8,
		ArmLength = 0.55,
		Color = skin,
		HeadColor = Color3.fromRGB(62, 54, 58),
	})
	local head = figure.Head
	local extras = {}
	for _, side in ipairs({ -1, 1 }) do
		-- huge ear flaps
		table.insert(extras, Kit.Part(figure.Model, {
			Name = "Ear",
			Size = Vector3.new(0.15, 1.5, 1),
			CFrame = head.CFrame * CFrame.new(side * (head.Size.X / 2 + 0.1), 0.2, 0) * CFrame.Angles(0, 0, math.rad(side * -25)),
			Color = Color3.fromRGB(80, 60, 65),
		}))
	end
	table.insert(extras, Kit.Part(figure.Model, {
		Name = "Mouth",
		Size = Vector3.new(head.Size.X * 0.5, head.Size.Y * 0.35, 0.05),
		CFrame = head.CFrame * CFrame.new(0, -head.Size.Y * 0.15, -head.Size.Z / 2 - 0.02),
		Color = Color3.fromRGB(5, 0, 0),
		CanQuery = false,
	}))
	Kit.WeldList(figure.Root, extras)

	figure.Model:PivotTo(marker.CFrame)
	figure.Model.Parent = ctx.Services.MapService.Folders.ActiveAnomalies
	Kit.FadeIn(figure.Model, 1.2)

	-- breathing loop is played client-side from this attribute (3D, occluded)
	figure.Torso:SetAttribute("LoopSound", "Anomaly.ListenerBreath")
	CollectionService:AddTag(figure.Torso, "LoopSound")

	record.Model = figure.Model
	record.Target = figure.Torso
	record.State = {
		Root = figure.Root,
		FloorY = marker.Position.Y,
		Mode = "Idle",
		LastHeardId = 0,
		LastAlert = 0,
		HuntUntil = 0,
		SearchUntil = 0,
		NextWander = os.clock() + 4,
	}
	-- ignore everything that happened before it appeared
	local _, _, newest = ctx.Services.NoiseService:Listen(figure.Torso.Position, { Radius = 0 }, 0)
	record.State.LastHeardId = newest
	return true
end

local function moveTowards(root: BasePart, goal: Vector3, stepDistance: number, floorY: number)
	local position = root.Position
	local flatGoal = Vector3.new(goal.X, floorY + 0.1, goal.Z)
	local offset = flatGoal - Vector3.new(position.X, floorY + 0.1, position.Z)
	if offset.Magnitude < 0.1 then
		return 0
	end
	local step = math.min(stepDistance, offset.Magnitude)
	local nextPosition = Vector3.new(position.X, floorY + 0.1, position.Z) + offset.Unit * step
	TweenService:Create(root, TweenInfo.new(0.1, Enum.EasingStyle.Linear), {
		CFrame = CFrame.lookAt(nextPosition, nextPosition + offset.Unit),
	}):Play()
	return offset.Magnitude - step
end

function TheListener.Update(ctx, record, dt)
	local state: any = record.State
	local root: BasePart = state.Root
	local now = os.clock()
	local params = record.Params
	local hearingPosition = root.Position + Vector3.new(0, 5, 0)

	local event, _, newest = ctx.Services.NoiseService:Listen(hearingPosition, record.Def.Hearing, state.LastHeardId)
	state.LastHeardId = newest
	if event then
		state.Goal = event.Position
		state.Mode = "Hunting"
		state.HuntUntil = now + 7
		if now - state.LastAlert > 1.8 then
			state.LastAlert = now
			ctx.Kit.PlaySound3D(record.Target, "Anomaly.ListenerAlert")
		end
	end

	-- anyone within reach while it is hunting (or anyone who bumps into it) gets caught
	local alert = state.Mode ~= "Idle"
	local player, distance = ctx:GetNearestParticipant(root.Position, params.AttackRange or 4.5)
	if player and (alert or distance < 2.5) then
		ctx.Kit.PlaySound3D(record.Target, "Anomaly.Groan")
		ctx:AttackPlayer(player, "Listener", params.BatteryDrain or 25)
		ctx:Despawn(record, "Attacked")
		return
	end

	if state.Mode == "Hunting" and state.Goal then
		local remaining = moveTowards(root, state.Goal, (params.ChaseSpeed or 15) * dt, state.FloorY)
		if remaining < 1.5 then
			state.Mode = "Searching"
			state.SearchUntil = now + 3
		elseif now > state.HuntUntil then
			state.Mode = "Idle"
		end
	elseif state.Mode == "Searching" then
		-- listens, slowly turning its head
		root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(40) * dt, 0)
		if now > state.SearchUntil then
			state.Mode = "Idle"
		end
	elseif now >= state.NextWander then
		state.NextWander = now + 5 + math.random() * 4
		local angle = math.random() * math.pi * 2
		local goal = root.Position + Vector3.new(math.cos(angle) * 4, 0, math.sin(angle) * 4)
		ctx.Kit.TweenCFrame(root, CFrame.lookAt(Vector3.new(goal.X, state.FloorY + 0.1, goal.Z), Vector3.new(goal.X, state.FloorY + 0.1, goal.Z) + (goal - root.Position) * Vector3.new(1, 0, 1)), 2.5)
	end
end

return TheListener
