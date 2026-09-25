--[[
	OneBehindYou (ModuleScript)
	Location: ServerScriptService/Anomalies/Behaviors/OneBehindYou

	A tall thin figure follows directly behind one player. Everyone else can
	see and photograph it. The chosen player is told "DO NOT TURN AROUND." -
	and if they do look, it isn't there for them (hidden client-side), so
	only their friends can capture it.
]]

local RunService = game:GetService("RunService")

local OneBehindYou = {}

local function behindCFrame(root: BasePart, humanoid: Humanoid, distance: number): CFrame
	local feetY = root.Position.Y - (humanoid.HipHeight + root.Size.Y / 2)
	local behind = root.CFrame * CFrame.new(0, 0, distance)
	local look = root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 1e-3 then
		flatLook = Vector3.new(0, 0, -1)
	end
	local position = Vector3.new(behind.Position.X, feetY, behind.Position.Z)
	return CFrame.lookAt(position, position + flatLook.Unit)
end

function OneBehindYou.Spawn(ctx, record)
	local target = ctx:PickTargetPlayer(record)
	if not target then
		return false
	end
	local root, _, humanoid = ctx:GetCharacterParts(target)
	if not root or not humanoid then
		return false
	end
	local distance = record.Params.Distance or 4.5

	local figure = ctx.Kit.Figure({
		Name = "TheOneBehindYou",
		Height = 8.6,
		Thin = 0.7,
		ArmLength = 0.55,
		Color = Color3.fromRGB(8, 8, 10),
		EyeColor = Color3.fromRGB(255, 255, 255),
	})
	figure.Model:PivotTo(behindCFrame(root, humanoid, distance))
	figure.Model.Parent = ctx.Services.MapService.Folders.ActiveAnomalies
	ctx.Kit.FadeIn(figure.Model, 0.8)

	record.Model = figure.Model
	record.Target = figure.Torso
	record.ExcludePhotographers[target.UserId] = true

	local current = figure.Root.CFrame
	local accumulator = 0
	record.Cleaner:Add(RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 1 / 20 then
			return
		end
		accumulator = 0
		local r, _, h = ctx:GetCharacterParts(target)
		if not r or not h then
			return
		end
		current = current:Lerp(behindCFrame(r, h, distance), 0.35)
		figure.Root.CFrame = current
	end))

	ctx:FireFx(target, { Type = "DoNotTurn", On = true, Model = figure.Model, Uid = record.Uid })
	record.Cleaner:Add(function()
		if target.Parent then
			ctx:FireFx(target, { Type = "DoNotTurn", On = false, Uid = record.Uid })
		end
	end)
	return true
end

return OneBehindYou
