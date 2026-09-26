--[[
	Brain (ModuleScript)
	Location: ServerScriptService/Anomalies/Brain

	Modular anomaly AI. One state machine, configured per anomaly
	(AnomalyConfig Params.AI). States:

	  Idle              stands / wanders a little near its spawn
	  Observe           stops and stares at an investigator
	  Stalk             keeps its distance and follows (optionally only while
	                    nobody is looking = "moves only when unseen")
	  Search            goes to the last place it saw someone and looks around
	  InvestigateNoise  walks to a sound it heard (NoiseService)
	  Follow            stays right behind one investigator
	  Hide              retreats into a dark corner out of sight
	  Chase             runs at its target
	  Attack            jumpscare + knock down (AnomalyService:AttackPlayer)
	  Disappear         vanishes

	Config (all optional):
	  States        { StateName = true } allowed states (default: all but Follow)
	  Start         first state ("Idle")
	  Speeds        { Walk, Stalk, Chase }
	  Gaits         { State = "Walk" | "Jerky" | "Limp" | "Crawl" | "Sprint" | "StopMotion" }
	  SightRange, StalkDistance, AttackRange, LoseTime, ObserveTime = {min, max}
	  Aggression    0..1 chance to escalate (Observe -> Stalk -> Chase)
	  ShyWhenSeen   hides / vanishes when looked at
	  FreezeWhenSeen  only moves while no investigator can see it
	  Jumpscare     JumpscareController style ("Possessed", "Smile", ...)
	  Heavy         attacks knock the investigator down (revive needed)
	  AfterAttack   "Disappear" (default) | "Hide"
	  Sounds        { Alert = path, Attack = path, Idle = path }
]]

local Workspace = game:GetService("Workspace")

local Brain = {}
Brain.__index = Brain

local DEFAULTS = {
	Start = "Idle",
	Speeds = { Walk = 6, Stalk = 8, Chase = 17 },
	Gaits = {},
	SightRange = 70,
	StalkDistance = 16,
	AttackRange = 4.2,
	LoseTime = 4,
	ObserveTime = { 2, 4 },
	Aggression = 0.5,
	AfterAttack = "Disappear",
	Jumpscare = "Generic",
	Heavy = true,
}

local ALL_STATES = { Idle = true, Observe = true, Stalk = true, Search = true, InvestigateNoise = true, Hide = true, Chase = true, Attack = true, Disappear = true }

local function range(value: any, fallback: number): number
	if type(value) == "table" then
		return value[1] + math.random() * ((value[2] or value[1]) - value[1])
	end
	return if type(value) == "number" then value else fallback
end

function Brain.new(ctx, record, mover, config)
	local self = setmetatable({}, Brain)
	local c = {}
	for key, value in pairs(DEFAULTS) do
		c[key] = value
	end
	for key, value in pairs(config or {}) do
		c[key] = value
	end
	c.States = c.States or ALL_STATES
	self.Config = c
	self.Ctx = ctx
	self.Record = record
	self.Mover = mover
	self.Model = mover.Model
	self.Root = mover.Root
	self.State = nil :: string?
	self.StateTime = 0
	self.Target = nil :: Player?
	self.LastSeenAt = nil :: Vector3?
	self.LastSeenTime = 0
	self.SeenBy = 0 -- seconds the target has been looking at us
	self.Home = self.Root.Position
	self.LastHeardId = 0
	if record.Def.Hearing then
		local _, _, newest = ctx.Services.NoiseService:Listen(self.Root.Position, { Radius = 0 }, 0)
		self.LastHeardId = newest
	end
	self:Enter(c.Start)
	return self
end

function Brain:Allowed(state: string): boolean
	return self.Config.States[state] == true
end

function Brain:Enter(state: string)
	if not self:Allowed(state) and state ~= "Idle" and state ~= "Disappear" then
		state = "Idle"
	end
	self.State = state
	self.StateTime = 0
	self.Model:SetAttribute("AIState", state)
	local gait = self.Config.Gaits[state] or self.Config.Gaits.Default or (if state == "Chase" then "Sprint" else "Walk")
	local speeds = self.Config.Speeds
	local speed = if state == "Chase" then speeds.Chase elseif state == "Stalk" or state == "Follow" then speeds.Stalk else speeds.Walk
	if self.Mover.SetGait then
		self.Mover:SetGait(gait, speed)
	elseif self.Mover.SetSpeed then
		self.Mover:SetSpeed(speed)
	end
	local sounds = self.Config.Sounds
	if sounds and state == "Chase" and sounds.Alert then
		self.Ctx.Kit.PlaySound3D(self.Record.Target, sounds.Alert)
	end
	if state == "Observe" then
		self.ObserveFor = range(self.Config.ObserveTime, 3)
	elseif state == "Idle" then
		self.Mover:Stop()
	elseif state == "Disappear" then
		self.Mover:Stop()
		self.Ctx:Despawn(self.Record, "Vanished")
	end
	if self.Config.OnState then
		self.Config.OnState(self, state)
	end
end

---------------------------------------------------------------------------
-- senses
---------------------------------------------------------------------------

function Brain:EyePosition(): Vector3
	local head = self.Model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end
	return self.Root.Position + Vector3.new(0, 2, 0)
end

-- nearest investigator it can see
function Brain:Look(): (Player?, BasePart?)
	local ctx = self.Ctx
	local eye = self:EyePosition()
	local best, bestRoot, bestDistance = nil, nil, self.Config.SightRange
	for _, player in ipairs(ctx:GetParticipants()) do
		local root = ctx:GetCharacterParts(player)
		if root then
			local distance = (root.Position - eye).Magnitude
			if distance < bestDistance and ctx.Services.ObservationService:HasLineOfSight(eye, root.Position + Vector3.new(0, 1.5, 0), { self.Model }) then
				best, bestRoot, bestDistance = player, root, distance
			end
		end
	end
	return best, bestRoot
end

function Brain:IsSeen(): boolean
	local observation = self.Ctx.Services.ObservationService
	local seen = observation:IsObserved(self.Record.Target.Position, { MaxDistance = 120, Ignore = { self.Model } })
	return seen
end

function Brain:TargetRoot(): BasePart?
	if not self.Target then
		return nil
	end
	local root = self.Ctx:GetCharacterParts(self.Target)
	return root
end

function Brain:_hear(): Vector3?
	local hearing = self.Record.Def.Hearing
	if not hearing then
		return nil
	end
	local event, _, newest = self.Ctx.Services.NoiseService:Listen(self:EyePosition(), hearing, self.LastHeardId)
	self.LastHeardId = newest
	return event and event.Position or nil
end

---------------------------------------------------------------------------
-- update
---------------------------------------------------------------------------

function Brain:Update(dt: number)
	if self.Record.Despawning then
		return
	end
	self.StateTime += dt
	local state = self.State
	local c = self.Config
	local frozen = false
	if c.FreezeWhenSeen and state ~= "Attack" then
		frozen = self:IsSeen()
		self.Model:SetAttribute("Frozen", frozen)
		if frozen then
			self.Mover:Stop()
		end
	end

	-- hearing interrupts calm states
	if (state == "Idle" or state == "Observe" or state == "Search") and self:Allowed("InvestigateNoise") then
		local heard = self:_hear()
		if heard then
			self.NoiseAt = heard
			self:Enter("InvestigateNoise")
			return
		end
	end

	-- anything that bumps into it while it is hunting gets caught (blind hunters)
	if (state == "InvestigateNoise" or state == "Search") and self:Allowed("Attack") then
		local player, distance = self.Ctx:GetNearestParticipant(self.Root.Position, c.AttackRange * 1.15)
		if player and distance then
			self.Target = player
			self:Enter("Attack")
			return
		end
	end

	local handler = (Brain :: any)["_" .. tostring(state)]
	if handler and not frozen then
		handler(self, dt)
	elseif handler and frozen and state ~= "Chase" and state ~= "Stalk" and state ~= "Follow" then
		handler(self, dt)
	elseif frozen and (state == "Chase" or state == "Stalk" or state == "Follow") then
		-- statue rule: while watched it only turns its head
		local root = self:TargetRoot()
		if root and root.Parent then
			self.Model:SetAttribute("LookAt", root.Position)
		end
		-- even frozen, a chaser that is already in reach attacks
		if state == "Chase" and root and (root.Position - self.Root.Position).Magnitude <= c.AttackRange then
			self:Enter("Attack")
		end
	end
	self.Mover:Update(dt)
end

function Brain:_Idle(_dt: number)
	local target = self:Look()
	if target then
		self.Target = target
		self:Enter(if self:Allowed("Observe") then "Observe" elseif self:Allowed("Stalk") then "Stalk" else "Chase")
		return
	end
	-- wander a little around home
	if self.StateTime > 3 and math.random() < 0.02 then
		local angle = math.random() * math.pi * 2
		self.Mover:MoveTo(self.Home + Vector3.new(math.cos(angle) * 8, 0, math.sin(angle) * 8))
	end
end

function Brain:_Observe(_dt: number)
	local root = self:TargetRoot()
	if not root then
		self:Enter("Idle")
		return
	end
	self.Mover:Stop()
	self.Mover:Face(root.Position)
	self.Model:SetAttribute("LookAt", root.Position)
	if self:IsSeen() then
		self.SeenBy += 0.1
		if self.Config.ShyWhenSeen and self.SeenBy > 0.6 then
			self.SeenBy = 0
			self:Enter(if self:Allowed("Hide") then "Hide" else "Disappear")
			return
		end
	end
	if self.StateTime >= (self.ObserveFor or 3) then
		if math.random() < self.Config.Aggression and self:Allowed("Stalk") then
			self:Enter("Stalk")
		elseif math.random() < self.Config.Aggression and self:Allowed("Chase") then
			self:Enter("Chase")
		elseif self:Allowed("Hide") and math.random() < 0.5 then
			self:Enter("Hide")
		else
			self:Enter("Idle")
		end
	end
end

function Brain:_Stalk(_dt: number)
	local root = self:TargetRoot()
	if not root then
		self:Enter(if self.LastSeenAt then "Search" else "Idle")
		return
	end
	local offset = root.Position - self.Root.Position
	local distance = offset.Magnitude
	self.LastSeenAt = root.Position
	self.LastSeenTime = os.clock()
	if distance > self.Config.StalkDistance then
		-- close in from behind: aim a bit behind the target
		local behind = root.Position - root.CFrame.LookVector * 6
		self.Mover:MoveTo(behind, 1.5)
	else
		self.Mover:Stop()
		self.Mover:Face(root.Position)
	end
	if self:IsSeen() then
		self.SeenBy += 0.1
	else
		self.SeenBy = math.max(0, self.SeenBy - 0.05)
	end
	if self.Config.ShyWhenSeen and self.SeenBy > 0.8 then
		self.SeenBy = 0
		self:Enter(if self:Allowed("Hide") then "Hide" else "Disappear")
		return
	end
	if self.StateTime > 4 and distance < self.Config.StalkDistance * 1.2 and math.random() < self.Config.Aggression * 0.08 and self:Allowed("Chase") then
		self:Enter("Chase")
	elseif self.StateTime > 25 then
		self:Enter(if self:Allowed("Hide") then "Hide" else "Idle")
	end
end

function Brain:_Follow(_dt: number)
	local root = self:TargetRoot()
	if not root then
		self:Enter("Disappear")
		return
	end
	local spot = root.Position - root.CFrame.LookVector * 4.5
	self.Mover:MoveTo(spot, 0.5)
	if self:IsSeen() then
		self:Enter(if self:Allowed("Chase") and math.random() < self.Config.Aggression then "Chase" else "Disappear")
	end
end

function Brain:_Chase(_dt: number)
	local root = self:TargetRoot()
	if not root then
		self:Enter(if self.LastSeenAt then "Search" else "Idle")
		return
	end
	local visible = self.Ctx.Services.ObservationService:HasLineOfSight(self:EyePosition(), root.Position + Vector3.new(0, 1.5, 0), { self.Model })
	if visible then
		self.LastSeenAt = root.Position
		self.LastSeenTime = os.clock()
	elseif os.clock() - self.LastSeenTime > self.Config.LoseTime then
		self:Enter("Search")
		return
	end
	if (root.Position - self.Root.Position).Magnitude <= self.Config.AttackRange then
		self:Enter("Attack")
		return
	end
	self.Mover:MoveTo(if visible then root.Position else (self.LastSeenAt or root.Position), 0.6)
	if self.StateTime > 30 then
		self:Enter(if self:Allowed("Hide") then "Hide" else "Disappear")
	end
end

function Brain:_Search(_dt: number)
	if self.LastSeenAt and not self.Mover:Arrived(3) then
		self.Mover:MoveTo(self.LastSeenAt)
	else
		self.Mover:Stop()
		self.Root.CFrame *= CFrame.Angles(0, math.rad(4), 0)
	end
	local target = self:Look()
	if target then
		self.Target = target
		self:Enter(if self:Allowed("Chase") and math.random() < self.Config.Aggression + 0.2 then "Chase" else "Stalk")
		return
	end
	if self.StateTime > 7 then
		self.LastSeenAt = nil
		self:Enter(if self:Allowed("Hide") and math.random() < 0.5 then "Hide" else "Idle")
	end
end

function Brain:_InvestigateNoise(_dt: number)
	if self.NoiseAt then
		self.Mover:MoveTo(self.NoiseAt)
		if self.Mover:Arrived(4) then
			self.LastSeenAt = self.NoiseAt
			self.NoiseAt = nil
			self:Enter("Search")
			return
		end
	end
	local heard = self:_hear()
	if heard then
		self.NoiseAt = heard
	end
	local target = self:Look()
	if target and self:Allowed("Chase") and math.random() < self.Config.Aggression then
		self.Target = target
		self:Enter("Chase")
	elseif self.StateTime > 14 then
		self:Enter("Idle")
	end
end

function Brain:_Hide(_dt: number)
	if not self.HideSpot then
		local markers = self.Ctx.Services.MapService:GetMarkers({ "Dark" }, nil)
		local best, bestDistance = nil, math.huge
		for _, marker in ipairs(markers) do
			local distance = (marker.Position - self.Root.Position).Magnitude
			if distance > 10 and distance < bestDistance and distance < 90 then
				best, bestDistance = marker, distance
			end
		end
		if not best then
			self:Enter("Disappear")
			return
		end
		self.HideSpot = best.Position
	end
	self.Mover:MoveTo(self.HideSpot)
	if self.Mover:Arrived(4) or self.StateTime > 12 then
		self.HideSpot = nil
		self.Home = self.Root.Position
		self:Enter("Idle")
	end
end

function Brain:_Attack(_dt: number)
	if self.Attacked then
		if self.StateTime > 1.6 then
			self.Attacked = false
			self:Enter(self.Config.AfterAttack or "Disappear")
		end
		return
	end
	local root = self:TargetRoot()
	if not root or (root.Position - self.Root.Position).Magnitude > self.Config.AttackRange * 1.8 then
		self:Enter("Chase")
		return
	end
	self.Attacked = true
	self.Mover:Stop()
	self.Mover:Face(root.Position)
	local sounds = self.Config.Sounds
	if sounds and sounds.Attack then
		self.Ctx.Kit.PlaySound3D(self.Record.Target, sounds.Attack)
	end
	self.Ctx:AttackPlayer(self.Target :: Player, self.Config.Jumpscare, {
		Record = self.Record,
		Heavy = self.Config.Heavy,
		BatteryDrain = self.Config.BatteryDrain,
	})
end

function Brain:_Disappear(_dt: number) end

-- used by behaviours to push the brain from outside (e.g. photographed)
function Brain:ForceTarget(player: Player, state: string)
	self.Target = player
	self:Enter(state)
end

function Brain:Now(): number
	return Workspace:GetServerTimeNow()
end

return Brain
