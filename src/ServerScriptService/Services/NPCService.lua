--[[
	NPCService (ModuleScript)
	Location: ServerScriptService/Services/NPCService

	A handful of slow "last shoppers" wander the main hall during a round.
	They make the mall feel alive and are the raw material for the Faceless
	Shopper and Frozen Crowd anomalies. Kept deliberately small for mobile:
	few NPCs, one cheap polling loop each, straight-line lanes (no pathfinding).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))

local NPCService = {}
NPCService.NPCs = {}
NPCService.Running = false

local NPC = GameConfig.NPC

local function randomColor(list: { Color3 }): Color3
	return list[math.random(1, #list)]
end

local function loadTrack(humanoid: Humanoid, animationId: string): AnimationTrack?
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		local created = Instance.new("Animator")
		created.Parent = humanoid
		animator = created
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(animation)
	end)
	if ok then
		return track
	end
	return nil
end

function NPCService:Init(services)
	self.Services = services
end

function NPCService:_createNPC(lane: string)
	local waypoints = self.Services.MapService:GetWaypoints(lane)
	if #waypoints == 0 then
		return nil
	end

	local description = Instance.new("HumanoidDescription")
	local skin = randomColor(NPC.BodyColors)
	local shirt = randomColor(NPC.ClothingColors)
	local pants = shirt:Lerp(Color3.new(0, 0, 0), 0.45)
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = shirt
	description.LeftLegColor = pants
	description.RightLegColor = pants

	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then
		warn("[NPCService] Could not create shopper:", rig)
		return nil
	end

	rig.Name = "Shopper"
	local humanoid = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart
	local head = rig:FindFirstChild("Head") :: BasePart
	if not humanoid or not root or not head then
		rig:Destroy()
		return nil
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.WalkSpeed = 0

	if not head:FindFirstChildOfClass("Decal") then
		local face = Instance.new("Decal")
		face.Name = "face"
		face.Texture = "rbxasset://textures/face.png"
		face.Face = Enum.NormalId.Front
		face.Parent = head
	end

	local start = waypoints[math.random(1, #waypoints)]
	rig:PivotTo(CFrame.new(start.Position + Vector3.new(0, 3, 0)))
	rig.Parent = self.Services.MapService.Folders.NPCs
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	local record = {
		Model = rig,
		Humanoid = humanoid,
		Root = root,
		Head = head,
		Lane = lane,
		Waypoints = waypoints,
		BaseSpeed = NPC.WalkSpeedMin + math.random() * (NPC.WalkSpeedMax - NPC.WalkSpeedMin),
		Frozen = false,
		Reserved = false,
		Alive = true,
		WalkTrack = loadTrack(humanoid, GameConfig.Animations.Walk),
		IdleTrack = loadTrack(humanoid, GameConfig.Animations.Idle),
	}
	if record.WalkTrack then
		record.WalkTrack.Looped = true
	end
	if record.IdleTrack then
		record.IdleTrack.Looped = true
		record.IdleTrack:Play()
	end
	record.Thread = task.spawn(function()
		self:_wander(record)
	end)
	return record
end

function NPCService:_setWalking(record, walking: boolean)
	if walking then
		if record.IdleTrack and record.IdleTrack.IsPlaying then
			record.IdleTrack:Stop(0.3)
		end
		if record.WalkTrack then
			if not record.WalkTrack.IsPlaying then
				record.WalkTrack:Play(0.3)
			end
			record.WalkTrack:AdjustSpeed(record.Humanoid.WalkSpeed / 14)
		end
	else
		if record.WalkTrack and record.WalkTrack.IsPlaying then
			record.WalkTrack:Stop(0.3)
		end
		if record.IdleTrack and not record.IdleTrack.IsPlaying then
			record.IdleTrack:Play(0.3)
		end
	end
end

function NPCService:_wander(record)
	local current = nil
	while record.Alive and record.Model.Parent do
		if record.Frozen then
			task.wait(0.3)
			continue
		end
		local target = record.Waypoints[math.random(1, #record.Waypoints)]
		if target == current then
			task.wait(0.2)
			continue
		end
		current = target
		record.Humanoid.WalkSpeed = record.SpeedOverride or record.BaseSpeed
		self:_setWalking(record, true)
		record.Humanoid:MoveTo(target.Position)
		local started = os.clock()
		while record.Alive and not record.Frozen do
			local flat = (target.Position - record.Root.Position) * Vector3.new(1, 0, 1)
			if flat.Magnitude < 2.5 or os.clock() - started > 20 then
				break
			end
			if os.clock() - started > 7 and os.clock() - started < 7.3 then
				record.Humanoid:MoveTo(target.Position) -- MoveTo times out after 8s
			end
			task.wait(0.25)
		end
		if not record.Alive then
			break
		end
		if not record.Frozen then
			self:_setWalking(record, false)
			task.wait(NPC.PauseMin + math.random() * (NPC.PauseMax - NPC.PauseMin))
		end
	end
end

function NPCService:SpawnAll()
	self:DespawnAll()
	self.Running = true
	for i = 1, NPC.Count do
		local lane = (i % 2 == 0) and "East" or "West"
		local record = self:_createNPC(lane)
		if record then
			table.insert(self.NPCs, record)
		end
	end
end

function NPCService:DespawnAll()
	self.Running = false
	for _, record in ipairs(self.NPCs) do
		record.Alive = false
		if record.Thread and coroutine.status(record.Thread) ~= "dead" then
			pcall(task.cancel, record.Thread)
		end
		if record.Model then
			record.Model:Destroy()
		end
	end
	table.clear(self.NPCs)
end

function NPCService:GetAll()
	local list = {}
	for _, record in ipairs(self.NPCs) do
		if record.Alive and record.Model.Parent then
			table.insert(list, record)
		end
	end
	return list
end

function NPCService:GetAvailable()
	local list = {}
	for _, record in ipairs(self:GetAll()) do
		if not record.Reserved then
			table.insert(list, record)
		end
	end
	return list
end

function NPCService:Reserve(record)
	record.Reserved = true
end

function NPCService:Release(record)
	record.Reserved = false
	record.SpeedOverride = nil
end

function NPCService:SetFrozen(record, frozen: boolean)
	if not record.Alive or record.Frozen == frozen then
		return
	end
	record.Frozen = frozen
	if frozen then
		record.Humanoid:MoveTo(record.Root.Position)
		record.Humanoid.WalkSpeed = 0
		if record.WalkTrack and record.WalkTrack.IsPlaying then
			record.WalkTrack:AdjustSpeed(0) -- freeze mid-stride
		end
		if record.IdleTrack and record.IdleTrack.IsPlaying then
			record.IdleTrack:AdjustSpeed(0)
		end
		record.Root.Anchored = true
	else
		record.Root.Anchored = false
		pcall(function()
			record.Root:SetNetworkOwner(nil)
		end)
		if record.IdleTrack then
			record.IdleTrack:AdjustSpeed(1)
		end
		if record.WalkTrack then
			record.WalkTrack:AdjustSpeed(1)
		end
	end
end

return NPCService
