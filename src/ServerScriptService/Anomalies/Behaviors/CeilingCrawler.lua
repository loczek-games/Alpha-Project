--[[
	CeilingCrawler (ModuleScript)
	Location: ServerScriptService/Anomalies/Behaviors/CeilingCrawler

	THE CEILING CRAWLER. A long-legged thing with a human face that lives on
	the ceiling of the Dead Mall (Workspace.ActiveMap.AnomalyNodes.
	CeilingCrawlerNodes).

	  STALK   it secretly picks one investigator and follows above and behind
	          them. Clues it cannot help leaving: scratching in the ceiling,
	          dust trickling down, a light flickering, a shadow passing
	          overhead, breathing right above you.
	  SEE IT  in the dark it is almost invisible - through a ZOOMED camera
	          it is clearly visible (client: ZoomVisible). Looking straight up
	          at it from right below is a very bad idea.
	  PHOTO   photographed: it freezes, vanishes, and comes back later MORE
	          AGGRESSIVE (faster, shorter stalking, fewer warnings).
	  ATTACK  unpredictably it drops onto its target: the first-person
	          jumpscare (JumpscareController "CeilingCrawler") + knocked down.
]]

local Workspace = game:GetService("Workspace")

local Anomalies = script.Parent.Parent
local Movers = require(Anomalies:WaitForChild("Movers"))

local CeilingCrawler = {}

-- server-wide: every photo makes the next one angrier (reset each mission)
CeilingCrawler.Aggression = 0
CeilingCrawler.Mission = 0

local CLUES = { "Scratch", "Dust", "Flicker", "Shadow", "Breath" }

function CeilingCrawler.CanSpawn(ctx, _def): boolean
	return #Movers.GetCeilingGraph(ctx).Nodes > 8 and #ctx:GetParticipants() > 0
end

local function pickTarget(ctx)
	local list = ctx:GetParticipants()
	if #list == 0 then
		return nil
	end
	-- prefer someone who is alone
	local best, bestScore = nil, -math.huge
	for _, player in ipairs(list) do
		local root = ctx:GetCharacterParts(player)
		if root then
			local nearest = math.huge
			for _, other in ipairs(list) do
				if other ~= player then
					local otherRoot = ctx:GetCharacterParts(other)
					if otherRoot then
						nearest = math.min(nearest, (otherRoot.Position - root.Position).Magnitude)
					end
				end
			end
			local score = math.min(nearest, 80) + math.random() * 25
			if score > bestScore then
				best, bestScore = player, score
			end
		end
	end
	return best
end

function CeilingCrawler.Spawn(ctx, record)
	local mission = ctx.Services.MissionService
	if mission.RoundNumber ~= CeilingCrawler.Mission then
		CeilingCrawler.Mission = mission.RoundNumber
		CeilingCrawler.Aggression = 0
	end
	local graph = Movers.GetCeilingGraph(ctx)
	local target = pickTarget(ctx)
	local root = target and ctx:GetCharacterParts(target)
	if not root then
		return false
	end
	-- start on a node 25-60 studs away that the target is not looking at
	local candidates = {}
	for _, node in ipairs(graph.Nodes) do
		local distance = (node.Position - root.Position).Magnitude
		if #node.Links > 0 and distance > 25 and distance < 70 then
			if not ctx.Services.ObservationService:CanSee(target, node.Position, { LineOfSight = false }) then
				table.insert(candidates, node)
			end
		end
	end
	if #candidates == 0 then
		local node = Movers.NearestCeilingNode(graph, root.Position)
		if not node then
			return false
		end
		table.insert(candidates, node)
	end
	local start = candidates[math.random(1, #candidates)]

	local model = ctx.Kit.Appearance:Get("CeilingCrawler")
	model.Name = "CeilingCrawler"
	if not model.PrimaryPart then
		local first = model:FindFirstChildWhichIsA("BasePart", true)
		model.PrimaryPart = first
	end
	model:SetAttribute("ZoomVisible", true)
	model:SetAttribute("Gait", "Spider")
	model.Parent = ctx.Services.MapService.Folders.ActiveAnomalies
	local mover = Movers.Ceiling(model, ctx, start)
	ctx.Kit.ClaimPhysics(model)

	local aggression = CeilingCrawler.Aggression
	mover:SetSpeed(8 + aggression * 3)
	local body = model:FindFirstChild("Thorax") or model.PrimaryPart
	record.Model = model
	record.Target = body :: BasePart
	record.VisibilityRoot = model
	record.State = {
		Mover = mover,
		Victim = target,
		Mode = "Stalk",
		ModeTime = 0,
		StalkFor = math.max(12, (38 + math.random() * 20) - aggression * 9),
		NextClue = os.clock() + 3,
		CluesLeft = math.max(2, 6 - aggression),
		Aggression = aggression,
		RepathAt = 0,
	}
	ctx.Kit.FadeIn(model, 1.2)
	return true
end

function CeilingCrawler.CanPhotograph(_ctx, record)
	return record.State.Mode ~= "Gone"
end

---------------------------------------------------------------------------
-- clues
---------------------------------------------------------------------------

local function leaveClue(ctx, record, victimRoot: BasePart)
	local state = record.State
	local mover = state.Mover
	local above = mover.Position + Vector3.new(0, mover.Hang, 0)
	local clue = CLUES[math.random(1, #CLUES)]
	local Kit = ctx.Kit
	if clue == "Scratch" then
		Kit.PlaySound3D(above, "Anomaly.Scratch")
	elseif clue == "Dust" then
		Kit.PlaySound3D(above, "Anomaly.DustFall")
		local dust = Instance.new("Part")
		dust.Name = "Dust"
		dust.Anchored = true
		dust.CanCollide = false
		dust.CanQuery = false
		dust.CanTouch = false
		dust.Transparency = 1
		dust.Size = Vector3.new(3, 0.2, 3)
		dust.CFrame = CFrame.new(above - Vector3.new(0, 0.3, 0))
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(Color3.fromRGB(180, 176, 168))
		emitter.Size = NumberSequence.new(0.12, 0.05)
		emitter.Transparency = NumberSequence.new(0.2, 1)
		emitter.Lifetime = NumberRange.new(1.5, 2.5)
		emitter.Speed = NumberRange.new(2, 5)
		emitter.EmissionDirection = Enum.NormalId.Bottom
		emitter.SpreadAngle = Vector2.new(20, 20)
		emitter.Rate = 0
		emitter.Parent = dust
		dust.Parent = ctx.Services.MapService.Folders.ActiveAnomalies
		emitter:Emit(40)
		task.delay(3, function()
			dust:Destroy()
		end)
	elseif clue == "Flicker" then
		local lights = ctx.Services.MapService:GetLightsNear(victimRoot.Position, 26)
		ctx.Services.MapService:FlickerRecords(lights, math.random(2, 4))
	elseif clue == "Shadow" then
		-- scuttle fast across the ceiling above the victim
		mover:SetSpeed(26)
		mover:MoveTo(victimRoot.Position + victimRoot.CFrame.RightVector * (math.random() < 0.5 and -14 or 14))
		Kit.PlaySound3D(above, "Anomaly.CeilingScuttle")
		task.delay(1.2, function()
			if record.State.Mode == "Stalk" then
				mover:SetSpeed(8 + record.State.Aggression * 3)
			end
		end)
	elseif clue == "Breath" then
		Kit.PlaySound3D(victimRoot.Position + Vector3.new(0, 6, 0), "Anomaly.Breath")
	end
end

---------------------------------------------------------------------------
-- update
---------------------------------------------------------------------------

local function vanish(ctx, record, returnAfter: number?)
	local state = record.State
	state.Mode = "Gone"
	state.ModeTime = 0
	ctx.Kit.PlaySound3D(record.Target, "Anomaly.CeilingScuttle")
	ctx.Kit.FadeOut(record.Model, 0.5)
	state.ReturnAt = if returnAfter then os.clock() + returnAfter else nil
	-- hide far away, out of everyone's sight
	task.delay(0.6, function()
		if record.CleanedUp then
			return
		end
		local graph = Movers.GetCeilingGraph(ctx)
		local far, farDistance = nil, 0
		for _, node in ipairs(graph.Nodes) do
			if #node.Links > 0 then
				local _, nearest = ctx:GetNearestParticipant(node.Position)
				if nearest > farDistance then
					far, farDistance = node, nearest
				end
			end
		end
		if far then
			state.Mover:Teleport(far)
		end
	end)
end

local function reappear(ctx, record)
	local state = record.State
	state.Aggression = CeilingCrawler.Aggression
	state.Victim = pickTarget(ctx) or state.Victim
	state.Mode = "Stalk"
	state.ModeTime = 0
	state.StalkFor = math.max(8, (30 + math.random() * 15) - state.Aggression * 9)
	state.CluesLeft = math.max(1, 5 - state.Aggression)
	state.Mover:SetSpeed(8 + state.Aggression * 3)
	ctx.Kit.FadeIn(record.Model, 1)
	ctx.Kit.PlaySound3D(record.Target, "Anomaly.CeilingCreak")
	-- a returning crawler lives a while longer
	record.ExpireTime = math.max(record.ExpireTime, Workspace:GetServerTimeNow() + 60)
end

function CeilingCrawler.Update(ctx, record, dt)
	local state = record.State
	local mover = state.Mover
	state.ModeTime += dt
	mover:Update(dt)

	if state.Mode == "Gone" then
		if state.ReturnAt and os.clock() >= state.ReturnAt then
			reappear(ctx, record)
		end
		return
	elseif state.Mode == "Frozen" then
		if state.ModeTime > 1.4 then
			vanish(ctx, record, 20 + math.random() * 15 - state.Aggression * 3)
		end
		return
	elseif state.Mode == "Dropping" then
		if state.ModeTime > 2.6 then
			vanish(ctx, record, if state.Aggression >= 3 then nil else 35)
			if state.Aggression >= 3 then
				ctx:Despawn(record, "Attacked")
			end
		end
		return
	end

	local victim = state.Victim
	local victimRoot = victim and ctx:GetCharacterParts(victim)
	if not victimRoot then
		state.Victim = pickTarget(ctx)
		return
	end

	-- follow above and a little behind the victim
	if os.clock() >= state.RepathAt then
		state.RepathAt = os.clock() + 1
		local behind = victimRoot.Position - victimRoot.CFrame.LookVector * (if state.Mode == "Hunt" then 0 else 10 - math.min(state.Aggression, 3) * 2)
		if not mover:MoveTo(behind) then
			-- the victim is under another ceiling (a different room): slip
			-- across while nobody is looking and pick the trail up there
			local observation = ctx.Services.ObservationService
			local options = { MaxDistance = 80, Ignore = { record.Model } }
			if not observation:IsObserved(mover.Position, options) then
				local moved = mover:Relocate(victimRoot.Position, 18, 60, function(position)
					return not observation:IsObserved(position, options)
				end)
				if moved then
					ctx.Kit.PlaySound3D(record.Target, "Anomaly.CeilingScuttle")
				end
			end
		end
	end
	mover:Face(victimRoot.Position)

	local flat = (mover.Position - victimRoot.Position) * Vector3.new(1, 0, 1)
	local horizontal = flat.Magnitude
	local pitch = ctx.Services.ObservationService:GetPitch(victim)
	local seesIt = ctx.Services.ObservationService:CanSee(victim, mover.Position, { MaxDistance = 40, Ignore = { record.Model } })

	-- "don't look up": staring straight at it from right below makes it drop
	if seesIt and pitch > 50 and horizontal < 9 and state.ModeTime > 3 then
		CeilingCrawler.Attack(ctx, record, victim, victimRoot)
		return
	end

	if state.Mode == "Stalk" then
		if state.CluesLeft > 0 and os.clock() >= state.NextClue and horizontal < 30 then
			state.CluesLeft -= 1
			state.NextClue = os.clock() + math.max(3, 8 - state.Aggression) + math.random() * 4
			leaveClue(ctx, record, victimRoot)
		end
		if state.ModeTime >= state.StalkFor then
			state.Mode = "Hunt"
			state.ModeTime = 0
			mover:SetSpeed(14 + state.Aggression * 3)
			ctx.Kit.PlaySound3D(record.Target, "Anomaly.CeilingCreak")
		end
	elseif state.Mode == "Hunt" then
		-- unpredictable: drops as soon as it is above you, sometimes waits a little
		if horizontal < 3.5 and (math.random() < 0.15 + state.Aggression * 0.1 or state.ModeTime > 6) then
			CeilingCrawler.Attack(ctx, record, victim, victimRoot)
		elseif state.ModeTime > 25 then
			-- lost interest for now
			state.Mode = "Stalk"
			state.ModeTime = 0
			state.StalkFor = 20
		end
	end
end

function CeilingCrawler.Attack(ctx, record, victim: Player, victimRoot: BasePart)
	local state = record.State
	state.Mode = "Dropping"
	state.ModeTime = 0
	local head = victimRoot.Position + Vector3.new(0, 2.2, 0)
	state.Mover:Drop(head + victimRoot.CFrame.LookVector * 1.2)
	ctx:AttackPlayer(victim, "CeilingCrawler", { Record = record, Heavy = true, Delay = 3.2 })
end

function CeilingCrawler.OnCaptured(ctx, record, _player)
	local state = record.State
	if state.Mode == "Gone" or state.Mode == "Dropping" then
		return
	end
	-- freezes... vanishes... comes back angrier
	CeilingCrawler.Aggression += 1
	state.Mode = "Frozen"
	state.ModeTime = 0
	state.Mover:Stop()
	record.Model:SetAttribute("Frozen", true)
	task.delay(1.4, function()
		if record.Model then
			record.Model:SetAttribute("Frozen", false)
		end
	end)
end

return CeilingCrawler
