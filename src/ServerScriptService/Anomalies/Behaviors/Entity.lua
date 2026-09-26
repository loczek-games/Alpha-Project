--[[
	Entity (ModuleScript)
	Location: ServerScriptService/Anomalies/Behaviors/Entity

	Every walking creature: a body from Appearance (catalog bundle /
	ServerStorage override / procedural), moved by Movers.Floor and driven
	by the modular Brain. What makes each creature different lives in
	AnomalyConfig Params:

	  Appearance   Appearance.Library name ("SmilingEntity", "AbnormalTitan", ...)
	  Placement    "Marker" (default) | "Glass" (behind a shop window) |
	               "Mirror" (steps out of a mirror as YOUR double)
	  AI           Brain config (states, speeds, gaits, aggression, jumpscare)
	  Loop         looping sound on the body (breathing, drone)
	  OnPhoto      "Chase" | "Disappear" | "Freeze" | nil - reaction to a photo
	  Twitch       client-side head twitching amount (0-1)
]]

local Anomalies = script.Parent.Parent
local Movers = require(Anomalies:WaitForChild("Movers"))
local Brain = require(Anomalies:WaitForChild("Brain"))

local Entity = {}

local function torsoOf(model: Model): BasePart
	for _, name in ipairs({ "UpperTorso", "Torso", "HumanoidRootPart" }) do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return model.PrimaryPart :: BasePart
end

function Entity.CanSpawn(ctx, def): boolean
	local placement = def.Params.Placement
	if placement == "Mirror" then
		return #ctx:GetParticipants() > 0
	end
	return true
end

function Entity.Spawn(ctx, record)
	local params = record.Params
	local Kit = ctx.Kit
	local placement = params.Placement or "Marker"
	local floor: CFrame
	local model: Model
	local target: Player? = nil

	if placement == "Mirror" then
		-- your double steps out of a mirror
		local mirror = ctx:PickFixture(record)
		target = ctx:PickTargetPlayer(record)
		if not mirror or not target or not mirror:IsA("BasePart") then
			return false
		end
		local clone = Kit.CloneAvatar(target)
		if not clone then
			return false
		end
		clone.Name = target.DisplayName
		for _, descendant in ipairs(clone:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.CollisionGroup = Kit.CollisionGroup
				descendant.CanCollide = descendant.Name == "UpperTorso" or descendant.Name == "LowerTorso"
			end
		end
		model = clone
		local out = mirror.CFrame * CFrame.new(0, 0, -2.5)
		local ground = ctx.Objects.FloorBelow(ctx, out.Position, { mirror })
		floor = CFrame.lookAt(ground, ground + mirror.CFrame.LookVector)
	else
		local marker = ctx:PickSpawn(record)
		if not marker then
			return false
		end
		model = Kit.Walker(params.Appearance or "Shadow")
		floor = marker.CFrame
		if placement == "Glass" then
			-- stand just behind the glass, facing out
			floor = marker.CFrame * CFrame.new(0, 0, 3)
		end
	end

	model.Name = record.Def.Id
	Kit.PlaceWalker(model, floor)
	model.Parent = ctx.Services.MapService.Folders.ActiveAnomalies
	Kit.ClaimPhysics(model)
	if params.Twitch then
		model:SetAttribute("Twitch", params.Twitch)
	end
	if params.ZoomVisible then
		model:SetAttribute("ZoomVisible", true)
	end

	local mover = Movers.Floor(model, { AgentRadius = params.AgentRadius, AgentHeight = params.AgentHeight })
	local ai = table.clone(params.AI or {})
	if not ai.Gaits then
		ai.Gaits = { Default = "Walk" }
	end
	local brain = Brain.new(ctx, record, mover, ai)
	if target then
		brain:ForceTarget(target, ai.Start or "Follow")
	end

	local torso = torsoOf(model)
	record.Model = model
	record.Target = torso
	record.VisibilityRoot = model
	record.State.Brain = brain
	record.State.Mover = mover
	record.NoFade = false
	if params.Loop then
		torso:SetAttribute("LoopSound", params.Loop)
		torso:AddTag("LoopSound")
	end
	Kit.FadeIn(model, params.FadeIn or 0.8)
	return true
end

function Entity.Update(ctx, record, dt)
	local brain = record.State.Brain
	if brain then
		brain:Update(dt)
	end
end

function Entity.OnCaptured(ctx, record, player)
	local reaction = record.Params.OnPhoto
	local brain = record.State.Brain
	if not brain or not reaction then
		return
	end
	if reaction == "Chase" and brain:Allowed("Chase") then
		brain:ForceTarget(player, "Chase")
	elseif reaction == "Disappear" then
		task.delay(0.4, function()
			if not record.Despawning then
				ctx.Kit.PlaySound3D(record.Target, "Anomaly.Vanish")
				ctx:Despawn(record, "Photographed")
			end
		end)
	elseif reaction == "Freeze" then
		record.Model:SetAttribute("Frozen", true)
		record.State.Mover:Stop()
	end
end

function Entity.Despawn(_ctx, record)
	local torso = record.Target
	if torso and torso.Parent then
		torso:RemoveTag("LoopSound")
	end
	if record.Model then
		record.Model:SetAttribute("AIState", "Gone")
	end
end

return Entity
