--[[
	AnomalyKit (ModuleScript)
	Location: ServerScriptService/Anomalies/AnomalyKit

	Shared building blocks for anomaly behaviour modules: parts, welded
	models, humanoid silhouettes, fades, sounds, avatar clones.
	All anomaly geometry is anchored (or welded to an anchored root) and
	non-colliding, so anomalies never create physics work on mobile.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))

local Kit = {}
Kit.Audio = nil :: any -- set by AnomalyService (AudioService)

function Kit.Model(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	return model
end

-- Anchored, non-colliding, non-touching part. `props` may contain any Part property.
function Kit.Part(parent: Instance?, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

-- Welds every other BasePart in the model to `root` and anchors only the root,
-- so moving/tweening root.CFrame moves the whole anomaly.
function Kit.Weld(model: Model, root: BasePart)
	root.Anchored = true
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= root then
			Kit.WeldTo(root, descendant)
		end
	end
	model.PrimaryPart = root
end

function Kit.WeldTo(anchor: BasePart, part: BasePart)
	part.Anchored = false
	part.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
end

function Kit.WeldList(anchor: BasePart, parts: { BasePart })
	for _, part in ipairs(parts) do
		Kit.WeldTo(anchor, part)
	end
end

local function fadeTargets(model: Instance)
	local list = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			table.insert(list, descendant)
		end
	end
	return list
end

function Kit.FadeIn(model: Instance, duration: number)
	for _, item in ipairs(fadeTargets(model)) do
		local base = item:GetAttribute("BaseTransparency")
		if base == nil then
			base = (item :: any).Transparency
			item:SetAttribute("BaseTransparency", base)
		end
		if base < 1 then
			(item :: any).Transparency = 1
			TweenService:Create(item, TweenInfo.new(duration, Enum.EasingStyle.Quad), { Transparency = base }):Play()
		end
	end
end

function Kit.FadeOut(model: Instance, duration: number)
	for _, item in ipairs(fadeTargets(model)) do
		TweenService:Create(item, TweenInfo.new(duration, Enum.EasingStyle.Quad), { Transparency = 1 }):Play()
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Light") then
			TweenService:Create(descendant, TweenInfo.new(duration), { Brightness = 0 }):Play()
		end
	end
end

function Kit.TweenCFrame(part: BasePart, cframe: CFrame, duration: number, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(part, TweenInfo.new(duration, style or Enum.EasingStyle.Sine, direction or Enum.EasingDirection.InOut), { CFrame = cframe })
	tween:Play()
	return tween
end

-- Same position, rotated around Y to face `target`.
function Kit.YawTowards(cframe: CFrame, target: Vector3): CFrame
	local position = cframe.Position
	local flat = Vector3.new(target.X, position.Y, target.Z)
	if (flat - position).Magnitude < 0.05 then
		return cframe
	end
	return CFrame.lookAt(position, flat)
end

function Kit.YawDifference(a: CFrame, b: CFrame): number
	local la = Vector3.new(a.LookVector.X, 0, a.LookVector.Z)
	local lb = Vector3.new(b.LookVector.X, 0, b.LookVector.Z)
	if la.Magnitude < 1e-3 or lb.Magnitude < 1e-3 then
		return 0
	end
	return math.deg(math.acos(math.clamp(la.Unit:Dot(lb.Unit), -1, 1)))
end

-- Plays a SoundConfig sound at a part/position for nearby players (via AudioService).
-- Anomaly sounds are never counted as player noise.
function Kit.PlaySound3D(where: any, path: string, _maxDistance: number?, playbackSpeed: number?)
	if Kit.Audio then
		Kit.Audio:Play(path, where, { Speed = playbackSpeed })
	end
end

--[[
	A tall stylised silhouette built from blocks, feet at the model origin,
	facing -Z. Options: Height, Thin, Color, HeadColor, EyeColor, EyeGlow,
	Material, ArmLength, ArmSwing, LegSwing, Name.
]]
function Kit.Figure(opts: { [string]: any })
	local height = opts.Height or 7
	local thin = opts.Thin or 1
	local color = opts.Color or Color3.fromRGB(12, 12, 14)
	local headColor = opts.HeadColor or color
	local material = opts.Material or Enum.Material.SmoothPlastic

	local model = Kit.Model(opts.Name or "Figure")
	local root = Kit.Part(model, {
		Name = "Root",
		Size = Vector3.new(1, 0.2, 1),
		CFrame = CFrame.new(0, 0.1, 0),
		Transparency = 1,
		CanQuery = false,
	})

	local legH, torsoH, headS = 0.46 * height, 0.32 * height, 0.14 * height
	local torsoW, torsoD = 0.26 * height * thin, 0.13 * height * thin
	local legW = 0.1 * height * thin
	local armW, armH = 0.075 * height * thin, (opts.ArmLength or 0.42) * height
	local legSwing = math.rad(opts.LegSwing or 0)
	local armSwing = math.rad(opts.ArmSwing or 0)

	local hipY = legH
	local leftLeg = Kit.Part(model, {
		Name = "LeftLeg",
		Size = Vector3.new(legW, legH, legW),
		CFrame = CFrame.new(-0.06 * height * thin, hipY, 0) * CFrame.Angles(legSwing, 0, 0) * CFrame.new(0, -legH / 2, 0),
		Color = color,
		Material = material,
	})
	local rightLeg = Kit.Part(model, {
		Name = "RightLeg",
		Size = Vector3.new(legW, legH, legW),
		CFrame = CFrame.new(0.06 * height * thin, hipY, 0) * CFrame.Angles(-legSwing, 0, 0) * CFrame.new(0, -legH / 2, 0),
		Color = color,
		Material = material,
	})
	local torso = Kit.Part(model, {
		Name = "Torso",
		Size = Vector3.new(torsoW, torsoH, torsoD),
		CFrame = CFrame.new(0, legH + torsoH / 2, 0),
		Color = color,
		Material = material,
	})
	local shoulderY = legH + torsoH - 0.03 * height
	local armX = torsoW / 2 + armW / 2 + 0.01 * height
	local leftArm = Kit.Part(model, {
		Name = "LeftArm",
		Size = Vector3.new(armW, armH, armW),
		CFrame = CFrame.new(-armX, shoulderY, 0) * CFrame.Angles(armSwing, 0, 0) * CFrame.new(0, -armH / 2, 0),
		Color = color,
		Material = material,
	})
	local rightArm = Kit.Part(model, {
		Name = "RightArm",
		Size = Vector3.new(armW, armH, armW),
		CFrame = CFrame.new(armX, shoulderY, 0) * CFrame.Angles(-armSwing, 0, 0) * CFrame.new(0, -armH / 2, 0),
		Color = color,
		Material = material,
	})
	local head = Kit.Part(model, {
		Name = "Head",
		Size = Vector3.new(headS, headS * 1.12, headS),
		CFrame = CFrame.new(0, legH + torsoH + headS * 0.62, 0),
		Color = headColor,
		Material = material,
	})

	local eyes = {}
	if opts.EyeColor then
		for _, side in ipairs({ -1, 1 }) do
			local eye = Kit.Part(model, {
				Name = "Eye",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(headS * 0.2, headS * 0.2, headS * 0.2),
				CFrame = head.CFrame * CFrame.new(side * headS * 0.22, headS * 0.08, -headS / 2 - 0.02),
				Color = opts.EyeColor,
				Material = if opts.EyeGlow == false then Enum.Material.SmoothPlastic else Enum.Material.Neon,
				CanQuery = false,
			})
			table.insert(eyes, eye)
		end
	end

	Kit.Weld(model, root)
	return {
		Model = model,
		Root = root,
		Torso = torso,
		Head = head,
		LeftArm = leftArm,
		RightArm = rightArm,
		LeftLeg = leftLeg,
		RightLeg = rightLeg,
		Eyes = eyes,
		Height = height,
	}
end

-- R15 copy of a player's current avatar (yields while assets load).
function Kit.CloneAvatar(player: Player): Model?
	local description: HumanoidDescription? = nil
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local ok, result = pcall(function()
			return humanoid:GetAppliedDescription()
		end)
		if ok then
			description = result
		end
	end
	if not description and player.UserId > 0 then
		local ok, result = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(player.UserId)
		end)
		if ok then
			description = result
		end
	end
	local finalDescription = description or Instance.new("HumanoidDescription")
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(finalDescription, Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then
		warn("[AnomalyKit] Could not clone avatar:", rig)
		return nil
	end
	for _, descendant in ipairs(rig:GetDescendants()) do
		if descendant:IsA("BaseScript") or descendant:IsA("ForceField") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.CanTouch = false
		end
	end
	local rigHumanoid = rig:FindFirstChildOfClass("Humanoid")
	if rigHumanoid then
		rigHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		rigHumanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		rigHumanoid.BreakJointsOnDeath = false
	end
	rig.Name = player.DisplayName
	return rig
end

function Kit.LoadAnimation(humanoid: Humanoid, key: string, looped: boolean?): AnimationTrack?
	local animationId = GameConfig.Animations[key]
	if not animationId then
		return nil
	end
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
	if not ok then
		return nil
	end
	track.Looped = looped == true
	return track
end

-- "Kacper" -> "Kapcer", "Bill" -> "BiIl": close enough to fool you at a glance.
function Kit.Misspell(name: string): string
	local confusables = { l = "I", I = "l", O = "0", o = "0", S = "5", B = "8" }
	local positions = {}
	for index = 1, #name do
		if confusables[name:sub(index, index)] then
			table.insert(positions, index)
		end
	end
	if #positions > 0 and math.random() < 0.5 then
		local index = positions[math.random(1, #positions)]
		return name:sub(1, index - 1) .. confusables[name:sub(index, index)] .. name:sub(index + 1)
	end
	if #name >= 4 then
		for _ = 1, 6 do
			local index = math.random(2, #name - 2)
			local a, b = name:sub(index, index), name:sub(index + 1, index + 1)
			if a ~= b then
				return name:sub(1, index - 1) .. b .. a .. name:sub(index + 2)
			end
		end
	end
	return name .. "."
end

return Kit
