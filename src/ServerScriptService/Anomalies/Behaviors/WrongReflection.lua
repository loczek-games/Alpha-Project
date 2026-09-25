--[[
	WrongReflection (ModuleScript)
	Location: ServerScriptService/Anomalies/Behaviors/WrongReflection

	A reflection of a real player appears in the (normally empty) bathroom
	mirror. It follows the nearest player's position like a reflection
	should... but it keeps staring straight at them, and sometimes waves.
]]

local TweenService = game:GetService("TweenService")

local WrongReflection = {}

local function reflectedCFrame(glass: BasePart, watcherPosition: Vector3, rootHeight: number): CFrame
	local normal = glass.CFrame.LookVector
	local right = glass.CFrame.RightVector
	local mirrorPoint = glass.Position
	local offset = watcherPosition - mirrorPoint
	local inFront = math.max(offset:Dot(normal), 0)
	local behind = math.clamp(inFront, 2.8, 8.2)
	local lateral = math.clamp(offset:Dot(right), -6, 6)
	local position = mirrorPoint - normal * behind + right * lateral
	position = Vector3.new(position.X, rootHeight, position.Z)
	local lookAt = Vector3.new(watcherPosition.X, rootHeight, watcherPosition.Z)
	if (lookAt - position).Magnitude < 0.1 then
		lookAt = position + normal
	end
	return CFrame.lookAt(position, lookAt)
end

function WrongReflection.Spawn(ctx, record)
	local mirror = ctx:PickFixture(record)
	if not mirror then
		return false
	end
	local glass = mirror:FindFirstChild("Glass")
	if not glass or not glass:IsA("BasePart") then
		return false
	end
	local player = ctx:GetNearestParticipant(glass.Position, 90)
	if not player then
		local participants = ctx:GetParticipants()
		player = participants[math.random(1, #participants)]
	end
	if not player then
		return false
	end

	local rig = ctx.Kit.CloneAvatar(player)
	if not rig then
		return false
	end
	local root = rig:FindFirstChild("HumanoidRootPart")
	local head = rig:FindFirstChild("Head")
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and head and head:IsA("BasePart") and humanoid) then
		rig:Destroy()
		return false
	end
	rig.Name = "Reflection"
	root.Anchored = true
	local floorY = glass.Position.Y - glass.Size.Y / 2 - 3.5
	local rootHeight = floorY + humanoid.HipHeight + root.Size.Y / 2
	local _, _, watcherRoot = ctx:GetNearestParticipant(glass.Position, 90)
	local watchPosition = if watcherRoot then watcherRoot.Position else glass.Position + glass.CFrame.LookVector * 6
	rig:PivotTo(reflectedCFrame(glass, watchPosition, rootHeight))
	rig.Parent = ctx.Services.MapService.Folders.ActiveAnomalies

	local idle = ctx.Kit.LoadAnimation(humanoid, "Idle", true)
	if idle then
		idle:Play()
	end

	record.Model = rig
	record.Target = head
	record.VisibilityRoot = rig
	record.State = {
		Glass = glass,
		Root = root,
		RootHeight = rootHeight,
		Wave = ctx.Kit.LoadAnimation(humanoid, "Wave", false),
		NextWave = os.clock() + (record.Params.WaveInterval or 4.5),
	}
	ctx.Kit.FadeIn(rig, 1.2)
	return true
end

function WrongReflection.Update(ctx, record)
	local state = record.State
	local glass: BasePart = state.Glass
	local _, _, watcherRoot = ctx:GetNearestParticipant(glass.Position, 70)
	if watcherRoot then
		local goal = reflectedCFrame(glass, watcherRoot.Position, state.RootHeight)
		TweenService:Create(state.Root, TweenInfo.new(0.12, Enum.EasingStyle.Linear), { CFrame = goal }):Play()
	end
	if state.Wave and os.clock() >= state.NextWave then
		state.NextWave = os.clock() + (record.Params.WaveInterval or 4.5)
		state.Wave:Play()
	end
end

return WrongReflection
