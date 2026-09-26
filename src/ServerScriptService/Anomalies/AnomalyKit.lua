--[[
	AnomalyKit (ModuleScript)
	Location: ServerScriptService/Anomalies/AnomalyKit

	Shared building blocks for anomaly behaviour modules: parts, welded
	models, jointed bodies (Figure / Body / Walker), fades, sounds, avatar
	clones. Static anomalies are anchored (or welded to an anchored root);
	walkers are server-owned physics bodies in the "COCAnomaly" collision
	group, which never collides with investigators.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))

local Rig = require(script.Parent:WaitForChild("Rig"))

local Kit = {}
Kit.Audio = nil :: any -- set by AnomalyService (AudioService)
Kit.Appearance = nil :: any -- set by AnomalyService (Appearance)
Kit.CollisionGroup = "COCAnomaly"

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

local function feetRoot(model: Model, rigRoot: BasePart, groundY: number): BasePart
	-- an anchored "Root" at the feet drives the whole (welded) rig, so old
	-- behaviours can keep tweening Root.CFrame at floor level
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 0.2, 1)
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Anchored = true
	root.CFrame = CFrame.new(rigRoot.Position.X, groundY + 0.1, rigRoot.Position.Z)
	root.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = rigRoot
	weld.Parent = rigRoot
	model.PrimaryPart = root
	return root
end

local function anchoredBody(model: Model)
	local rigRoot = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local groundY = math.huge
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			groundY = math.min(groundY, descendant.Position.Y - descendant.Size.Y / 2)
		end
	end
	local root = feetRoot(model, rigRoot, if groundY == math.huge then 0 else groundY)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = true
	end
	local function find(...)
		for _, name in ipairs({ ... }) do
			local found = model:FindFirstChild(name)
			if found and found:IsA("BasePart") then
				return found
			end
		end
		return rigRoot
	end
	return {
		Model = model,
		Root = root,
		Torso = find("UpperTorso", "Torso"),
		Head = find("Head"),
		LeftArm = find("LeftUpperArm", "Left Arm"),
		RightArm = find("RightUpperArm", "Right Arm"),
		LeftLeg = find("LeftUpperLeg", "Left Leg"),
		RightLeg = find("RightUpperLeg", "Right Leg"),
		Eyes = {},
		Height = model:GetExtentsSize().Y,
	}
end

--[[
	A tall stylised silhouette: a jointed R15-style rig (Rig.Humanoid) the
	client animates, feet at the model origin, facing -Z, driven by an
	anchored Root at the feet. Options: Height, Thin, Color, HeadColor,
	EyeColor, EyeGlow, Material, ArmLength, Name, Face.
]]
function Kit.Figure(opts: { [string]: any })
	local color = opts.Color or Color3.fromRGB(12, 12, 14)
	local rig = Rig.Humanoid({
		Name = opts.Name or "Figure",
		Height = opts.Height or 7,
		Thin = opts.Thin,
		ArmLength = if opts.ArmLength then opts.ArmLength / 0.42 else nil,
		Skin = opts.HeadColor or color,
		Shirt = color,
		Pants = color,
		Shoes = color,
		Material = opts.Material,
		Face = opts.Face or (if opts.EyeColor then "Eyes" else "Blank"),
		EyeColor = opts.EyeColor,
		Hunch = opts.Hunch,
	})
	local head = rig:FindFirstChild("Head") :: BasePart
	head.Color = opts.HeadColor or color
	local body = anchoredBody(rig)
	body.Model:PivotTo(CFrame.new())
	return body
end

-- A catalog / override / procedural body (Appearance) driven by an anchored feet Root.
function Kit.Body(appearanceName: string)
	local model = Kit.Appearance:Get(appearanceName)
	return anchoredBody(model)
end

-- A free-walking body for Movers.Floor (unanchored Humanoid, server physics owner).
function Kit.Walker(appearanceName: string): Model
	local model = Kit.Appearance:Get(appearanceName)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanTouch = false
			descendant.CollisionGroup = Kit.CollisionGroup
			local name = descendant.Name
			descendant.CanCollide = name == "UpperTorso" or name == "LowerTorso" or name == "Torso" or name == "HumanoidRootPart"
		end
	end
	return model
end

-- Puts a walker's feet on a floor CFrame.
function Kit.PlaceWalker(model: Model, floor: CFrame)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local height = if humanoid then humanoid.HipHeight + root.Size.Y / 2 else 3
	local offset = model:GetPivot():ToObjectSpace(root.CFrame)
	model:PivotTo(floor * CFrame.new(0, height, 0) * offset:Inverse())
end

-- Server owns the physics of anomalies (no client can push them around).
function Kit.ClaimPhysics(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and not descendant.Anchored then
			pcall(function()
				descendant:SetNetworkOwner(nil)
			end)
			break
		end
	end
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
