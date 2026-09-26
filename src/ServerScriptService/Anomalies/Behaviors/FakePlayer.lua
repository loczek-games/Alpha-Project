--[[
	FakePlayer (ModuleScript)
	Location: ServerScriptService/Anomalies/Behaviors/FakePlayer

	A copy of a real player in this server walks around the mall. It is
	*subtly* wrong: its name is misspelled, it walks while facing the
	nearest real player (moonwalking), and every few seconds its head
	twists almost all the way around.
]]

local FakePlayer = {}

function FakePlayer.Spawn(ctx, record)
	local participants = ctx:GetParticipants()
	if #participants == 0 then
		return false
	end
	local marker = ctx:PickSpawn(record)
	if not marker then
		return false
	end
	local original = participants[math.random(1, #participants)]
	local rig = ctx.Kit.CloneAvatar(original)
	if not rig then
		return false
	end
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	local root = rig:FindFirstChild("HumanoidRootPart")
	local head = rig:FindFirstChild("Head")
	if not (humanoid and root and root:IsA("BasePart") and head and head:IsA("BasePart")) then
		rig:Destroy()
		return false
	end

	humanoid.DisplayName = ctx.Kit.Misspell(original.DisplayName)
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.NameDisplayDistance = 60
	humanoid.WalkSpeed = record.Params.WalkSpeed or 9
	humanoid.AutoRotate = false

	rig:PivotTo(marker.CFrame + Vector3.new(0, 3, 0))
	rig.Parent = ctx.Services.MapService.Folders.ActiveAnomalies
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local align = Instance.new("AlignOrientation")
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxTorque = 1e7
	align.Responsiveness = 25
	align.CFrame = root.CFrame.Rotation
	align.Parent = root

	local neck = head:FindFirstChild("Neck")
	record.Model = rig
	record.Target = head
	record.State = {
		Humanoid = humanoid,
		Root = root,
		Align = align,
		Neck = if neck and neck:IsA("Motor6D") then neck else nil,
		NeckC0 = if neck and neck:IsA("Motor6D") then neck.C0 else nil,
		Walk = ctx.Kit.LoadAnimation(humanoid, "Walk", true),
		Idle = ctx.Kit.LoadAnimation(humanoid, "Idle", true),
		NextTwist = os.clock() + (record.Params.HeadTwistInterval or 6),
	}
	if record.State.Idle then
		record.State.Idle:Play()
	end

	-- Movement brain: creep towards the nearest real player, stop a few studs away and stare.
	local waypoints = ctx.Services.MapService:GetWaypoints(nil)
	record.Cleaner:Add(task.spawn(function()
		while rig.Parent do
			local _, distance, targetRoot = ctx:GetNearestParticipant(root.Position, 45)
			if targetRoot then
				if distance > 8 then
					local direction = (targetRoot.Position - root.Position) * Vector3.new(1, 0, 1)
					humanoid:MoveTo(targetRoot.Position - direction.Unit * 7)
				else
					humanoid:MoveTo(root.Position)
				end
				task.wait(0.6)
			elseif #waypoints > 0 then
				humanoid:MoveTo(waypoints[math.random(1, #waypoints)].Position)
				task.wait(3)
			else
				task.wait(1)
			end
		end
	end))
	return true
end

function FakePlayer.Update(ctx, record)
	local state: any = record.State
	local root: BasePart = state.Root
	local _, _, _, targetHead = ctx:GetNearestParticipant(root.Position, 80)
	if targetHead then
		state.Align.CFrame = ctx.Kit.YawTowards(root.CFrame, targetHead.Position).Rotation
	end

	local moving = state.Humanoid.MoveDirection.Magnitude > 0.1
	if moving and state.Walk and not state.Walk.IsPlaying then
		state.Walk:Play(0.2)
		state.Walk:AdjustSpeed(state.Humanoid.WalkSpeed / 14)
		if state.Idle then
			state.Idle:Stop(0.2)
		end
	elseif not moving and state.Walk and state.Walk.IsPlaying then
		state.Walk:Stop(0.2)
		if state.Idle then
			state.Idle:Play(0.2)
		end
	end

	if state.Neck and os.clock() >= state.NextTwist then
		state.NextTwist = os.clock() + (record.Params.HeadTwistInterval or 6)
		local neck: Motor6D = state.Neck
		local baseC0: CFrame = state.NeckC0
		neck.C0 = baseC0 * CFrame.Angles(0, math.rad(165), 0)
		task.delay(1.1, function()
			if neck.Parent then
				neck.C0 = baseC0
			end
		end)
	end
end

return FakePlayer
