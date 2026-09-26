--[[
	AnomalyAnimator (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/AnomalyAnimator

	Procedural animation for every anomaly body in Workspace.ActiveAnomalies
	(catalog bundle rigs, procedural rigs, the ceiling crawler). The server
	only moves the bodies; each client animates the joints (Motor6D.Transform)
	from the REAL velocity and these model attributes:

	  Gait        Walk | Sprint | Jerky | Limp | StopMotion | Crawl | Spider
	  Frozen      holds the current pose (photographed / watched statues)
	  Twitch      0-1 random head / shoulder snaps
	  Hunch       degrees of forward lean
	  LookAt      Vector3 the head turns towards
	  ZoomVisible almost invisible, clearly visible through a zoomed camera
	              (the ceiling crawler)
	Only bodies within 140 studs are animated.
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnomalyAnimator = {}
AnomalyAnimator.Tracked = {} :: { [Model]: any }

local RANGE = 140
local ZOOM_REVEAL_FOV = 48

local _JOINTS = {
	"Root", "Waist", "Neck",
	"LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow", "LeftWrist", "RightWrist",
	"LeftHip", "RightHip", "LeftKnee", "RightKnee", "LeftAnkle", "RightAnkle",
	"NeckJoint", "Tail", "Body",
}

local rad = math.rad
local sin = math.sin
local cos = math.cos

function AnomalyAnimator:Init(controllers)
	self.Controllers = controllers
end

function AnomalyAnimator:Start()
	local folder = Workspace:WaitForChild("ActiveAnomalies", 60)
	if not folder then
		return
	end
	local function add(child: Instance)
		if child:IsA("Model") then
			task.defer(function()
				self:_track(child)
			end)
		end
	end
	for _, child in ipairs(folder:GetChildren()) do
		add(child)
	end
	folder.ChildAdded:Connect(add)
	folder.ChildRemoved:Connect(function(child)
		self.Tracked[child :: Model] = nil
	end)
	RunService.RenderStepped:Connect(function(dt)
		local ok, err = pcall(self._step, self, dt)
		if not ok then
			warn("[AnomalyAnimator]", err)
		end
	end)
end

function AnomalyAnimator:_track(model: Model)
	if self.Tracked[model] or not model.Parent then
		return
	end
	local motors = {}
	local legs = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Motor6D") then
			motors[descendant.Name] = descendant
			local index = tonumber(string.match(descendant.Name, "^Hip(%d)$"))
			if index then
				legs[index] = legs[index] or {}
				legs[index].Hip = descendant
			end
			local kneeIndex = tonumber(string.match(descendant.Name, "^Knee(%d)$"))
			if kneeIndex then
				legs[kneeIndex] = legs[kneeIndex] or {}
				legs[kneeIndex].Knee = descendant
			end
		end
	end
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not root or not root:IsA("BasePart") then
		return
	end
	local parts = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	self.Tracked[model] = {
		Model = model,
		Root = root,
		Motors = motors,
		Legs = legs,
		Parts = parts,
		LastPosition = root.Position,
		Speed = 0,
		Phase = math.random() * 10,
		Seed = math.random() * 100,
		TwitchUntil = 0,
		TwitchPose = CFrame.identity,
		NextFrame = 0,
		Hidden = nil :: boolean?,
	}
end

local function setMotor(motors, name: string, transform: CFrame)
	local motor = motors[name]
	if motor then
		motor.Transform = transform
	end
end

---------------------------------------------------------------------------
-- humanoid gaits
---------------------------------------------------------------------------

local function humanoidPose(record, gait: string, speed: number, dt: number, now: number)
	local motors = record.Motors
	local model = record.Model
	local moving = speed > 0.6
	local cadence = if gait == "Sprint" then 11 elseif gait == "Crawl" then 7 elseif gait == "Limp" then 5.5 else 7.5
	if gait == "Jerky" then
		-- stop-go phase with random hitches
		if math.random() < 0.08 then
			record.Phase += math.random() * 1.5
		end
	end
	if moving then
		record.Phase += dt * cadence * math.clamp(speed / 10, 0.4, 1.8)
	end
	local phase = record.Phase
	local swing = if moving then (if gait == "Sprint" then 0.9 elseif gait == "Crawl" then 0.6 else 0.55) else 0
	local s = sin(phase)
	local hunch = rad(model:GetAttribute("Hunch") or 0)
	local breathe = sin(now * 1.7 + record.Seed) * 0.03

	if gait == "Crawl" then
		-- body flat on the floor, arms pulling, legs dragging
		setMotor(motors, "Root", CFrame.new(0, -1.6, 0.4) * CFrame.Angles(rad(-78), 0, sin(phase * 0.5) * 0.08))
		setMotor(motors, "Waist", CFrame.Angles(rad(10) + breathe, sin(phase) * 0.12, 0))
		setMotor(motors, "Neck", CFrame.Angles(rad(70), sin(now * 3 + record.Seed) * 0.15, 0))
		setMotor(motors, "LeftShoulder", CFrame.Angles(rad(160) + s * swing, 0, rad(-10)))
		setMotor(motors, "RightShoulder", CFrame.Angles(rad(160) - s * swing, 0, rad(10)))
		setMotor(motors, "LeftElbow", CFrame.Angles(math.max(0, s) * 0.9, 0, 0))
		setMotor(motors, "RightElbow", CFrame.Angles(math.max(0, -s) * 0.9, 0, 0))
		setMotor(motors, "LeftHip", CFrame.Angles(rad(8) + s * 0.1, 0, rad(-8)))
		setMotor(motors, "RightHip", CFrame.Angles(rad(8) - s * 0.1, 0, rad(8)))
		setMotor(motors, "LeftKnee", CFrame.Angles(rad(-20), 0, 0))
		setMotor(motors, "RightKnee", CFrame.Angles(rad(-30), 0, 0))
		return
	end

	local lean = hunch + (if gait == "Sprint" and moving then rad(16) else 0)
	local limp = gait == "Limp"
	local bob = if moving then math.abs(s) * 0.12 * (if gait == "Sprint" then 1.6 else 1) else 0
	setMotor(motors, "Root", CFrame.new(0, bob - (if limp then math.max(0, -s) * 0.2 else 0), 0) * CFrame.Angles(0, 0, if limp then s * 0.08 else 0))
	setMotor(motors, "Waist", CFrame.Angles(lean + breathe, if moving then -s * 0.15 else 0, 0))
	local rightLeg = if limp then s * swing * 0.25 else -s * swing
	setMotor(motors, "LeftHip", CFrame.Angles(s * swing, 0, 0))
	setMotor(motors, "RightHip", CFrame.Angles(rightLeg, 0, if limp then rad(6) else 0))
	setMotor(motors, "LeftKnee", CFrame.Angles(-math.max(0, -s) * swing * 1.4, 0, 0))
	setMotor(motors, "RightKnee", CFrame.Angles(if limp then 0 else -math.max(0, s) * swing * 1.4, 0, 0))
	local armSwing = if gait == "Jerky" then swing * 0.3 else swing * 0.8
	local hang = if hunch > rad(10) then rad(-12) else 0
	setMotor(motors, "LeftShoulder", CFrame.Angles(-s * armSwing + hang, 0, rad(-3)))
	setMotor(motors, "RightShoulder", CFrame.Angles(s * armSwing + hang, 0, rad(3)))
	setMotor(motors, "LeftElbow", CFrame.Angles(if gait == "Sprint" then rad(60) else rad(8), 0, 0))
	setMotor(motors, "RightElbow", CFrame.Angles(if gait == "Sprint" then rad(60) else rad(8), 0, 0))
end

local function applyHead(record, now: number)
	local model = record.Model
	local motors = record.Motors
	local neck = motors.Neck
	if not neck then
		return
	end
	local head = neck.Part1
	local lookAt = model:GetAttribute("LookAt")
	local base = CFrame.identity
	if typeof(lookAt) == "Vector3" and head then
		local local_ = head.CFrame:PointToObjectSpace(lookAt)
		local yaw = math.clamp(math.atan2(-local_.X, -local_.Z), rad(-70), rad(70))
		base = CFrame.Angles(0, yaw, 0)
	end
	local twitch = model:GetAttribute("Twitch") or 0
	if twitch > 0 then
		if now >= record.TwitchUntil and math.random() < twitch * 0.03 then
			record.TwitchUntil = now + 0.08 + math.random() * 0.25
			record.TwitchPose = CFrame.Angles(rad(math.random(-25, 25)), rad(math.random(-40, 40)), rad(math.random(-35, 35)) * twitch)
		end
		if now < record.TwitchUntil then
			base *= record.TwitchPose
		end
	end
	neck.Transform = base * neck.Transform
end

---------------------------------------------------------------------------
-- spider
---------------------------------------------------------------------------

local function spiderPose(record, speed: number, dt: number, now: number)
	local moving = speed > 0.5
	record.Phase += dt * (if moving then 9 * math.clamp(speed / 10, 0.5, 2) else 1.2)
	local phase = record.Phase
	for index, leg in pairs(record.Legs) do
		-- alternating tetrapod gait: legs 1,3,6,8 vs 2,4,5,7
		local group = if index == 1 or index == 3 or index == 6 or index == 8 then 0 else math.pi
		local t = phase + group
		local lift = if moving then math.max(0, sin(t)) * 0.5 else math.max(0, sin(t * 0.3 + index)) * 0.08
		local sweep = if moving then cos(t) * 0.35 else sin(now * 0.7 + index) * 0.04
		if leg.Hip then
			leg.Hip.Transform = CFrame.Angles(lift, sweep, 0)
		end
		if leg.Knee then
			leg.Knee.Transform = CFrame.Angles(-lift * 0.8, 0, 0)
		end
	end
	local motors = record.Motors
	setMotor(motors, "Tail", CFrame.Angles(sin(now * 1.3) * 0.06, sin(now * 0.8) * 0.05, 0))
	setMotor(motors, "Body", CFrame.new(0, sin(phase * 2) * 0.05, 0))
	local neckJoint = motors.NeckJoint
	if neckJoint then
		-- the face slowly turns towards the camera
		local camera = Workspace.CurrentCamera
		local yaw = 0
		if camera and neckJoint.Part0 then
			local offset = neckJoint.Part0.CFrame:PointToObjectSpace(camera.CFrame.Position)
			yaw = math.clamp(math.atan2(-offset.X, -offset.Z), -0.9, 0.9)
		end
		neckJoint.Transform = CFrame.Angles(sin(now * 2.1) * 0.08, yaw, 0)
	end
end

---------------------------------------------------------------------------
-- visibility (ceiling crawler: seen through the zoom)
---------------------------------------------------------------------------

local function applyVisibility(record, camera: Camera)
	local zoomed = camera.FieldOfView <= ZOOM_REVEAL_FOV
	local distance = (record.Root.Position - camera.CFrame.Position).Magnitude
	-- close up it cannot hide (the jumpscare), far away only the zoom sees it
	local hidden = not zoomed and distance > 14
	if hidden == record.Hidden then
		return
	end
	record.Hidden = hidden
	for _, part in ipairs(record.Parts) do
		if part.Parent then
			part.LocalTransparencyModifier = if hidden then 0.88 else 0
		end
	end
end

---------------------------------------------------------------------------
-- frame
---------------------------------------------------------------------------

function AnomalyAnimator:_step(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera or dt <= 0 then
		return
	end
	local origin = camera.CFrame.Position
	local now = os.clock()
	for model, record in pairs(self.Tracked) do
		if not model.Parent or not record.Root.Parent then
			self.Tracked[model] = nil
			continue
		end
		local position = record.Root.Position
		if (position - origin).Magnitude > RANGE then
			record.LastPosition = position
			continue
		end
		if model:GetAttribute("ZoomVisible") then
			applyVisibility(record, camera)
		end
		local velocity = (position - record.LastPosition) / dt
		record.LastPosition = position
		if velocity.Magnitude > 150 then
			velocity = Vector3.zero -- teleported
		end
		record.Speed += ((velocity * Vector3.new(1, 0, 1)).Magnitude - record.Speed) * math.min(1, dt * 8)
		if model:GetAttribute("Frozen") then
			continue
		end
		local gait = model:GetAttribute("Gait") or "Walk"
		if gait == "StopMotion" then
			-- the pose only updates a few times a second
			if now < record.NextFrame then
				continue
			end
			record.NextFrame = now + 1 / 6
			dt = 1 / 6
		end
		if gait == "Spider" then
			spiderPose(record, record.Speed, dt, now)
		else
			humanoidPose(record, if gait == "StopMotion" then "Walk" else gait, record.Speed, dt, now)
			applyHead(record, now)
		end
	end
end

return AnomalyAnimator
