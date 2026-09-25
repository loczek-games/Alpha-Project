--[[
	CharacterService (ModuleScript)
	Location: ServerScriptService/Services/CharacterService

	Per-character setup: walk speed, camera zoom limit (used by photo
	validation), the visible camera prop in the player's hand (skin reflects
	the equipped camera / VIP), the VIP name tag and Blackout flashlights.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local CameraConfig = require(Config:WaitForChild("CameraConfig"))

local CharacterService = {}
CharacterService.FlashlightsOn = false

local function prop(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Anchored = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

function CharacterService:Init(services)
	self.Services = services
	Players.PlayerAdded:Connect(function(player)
		self:_watchPlayer(player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		self:_watchPlayer(player)
	end
	-- equipped camera is only known once the save has loaded
	services.DataService:OnProfileLoaded(function(player)
		self:RefreshCharacter(player)
	end)
end

function CharacterService:_watchPlayer(player: Player)
	player.CameraMaxZoomDistance = GameConfig.Player.MaxZoomDistance
	player.CharacterAdded:Connect(function(character)
		self:_setupCharacter(player, character)
	end)
	if player.Character then
		task.spawn(function()
			self:_setupCharacter(player, player.Character :: Model)
		end)
	end
end

function CharacterService:_setupCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	humanoid.WalkSpeed = GameConfig.Player.WalkSpeed
	player.CameraMaxZoomDistance = GameConfig.Player.MaxZoomDistance
	character:WaitForChild("Head", 10)
	self:RefreshCharacter(player)
	if self.FlashlightsOn then
		self:_setFlashlight(character, true)
	end
end

function CharacterService:RefreshCharacter(player: Player)
	if not self.Services then
		return -- not initialised yet; _setupCharacter will run later
	end
	local character = player.Character
	if not character or not character.Parent then
		return
	end
	self:_attachCamera(player, character)
	self:_applyVipTag(player, character)
end

function CharacterService:_attachCamera(player: Player, character: Model)
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand or not hand:IsA("BasePart") then
		return
	end
	local existing = character:FindFirstChild("PlayerCamera")
	if existing then
		existing:Destroy()
	end

	local economy = self.Services.EconomyService
	local cameraId = if economy then economy:GetEquippedCameraId(player) else CameraConfig.DefaultCamera
	local def = CameraConfig.Get(cameraId) or CameraConfig.Get(CameraConfig.DefaultCamera)
	local bodyColor, accentColor, material = def.BodyColor, def.AccentColor, Enum.Material.SmoothPlastic
	if player:GetAttribute("VIP") then
		local skin = CameraConfig.Skins.VIP
		bodyColor, accentColor, material = skin.BodyColor, skin.AccentColor, skin.Material
	end

	local model = Instance.new("Model")
	model.Name = "PlayerCamera"

	local isR15 = hand.Name == "RightHand"
	local base = hand.CFrame * CFrame.new(0, if isR15 then -0.35 else -1.1, -0.45)
	local body = prop(model, "Body", Vector3.new(1.1, 0.72, 0.5), base, bodyColor, material)
	prop(model, "Lens", Vector3.new(0.35, 0.5, 0.5), base * CFrame.new(0, -0.02, -0.4) * CFrame.Angles(0, math.pi / 2, 0), accentColor, Enum.Material.Metal, Enum.PartType.Cylinder)
	prop(model, "Glass", Vector3.new(0.05, 0.38, 0.38), base * CFrame.new(0, -0.02, -0.59) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(40, 60, 90), Enum.Material.Glass, Enum.PartType.Cylinder)
	local bulb = prop(model, "FlashBulb", Vector3.new(0.3, 0.16, 0.08), base * CFrame.new(0.32, 0.26, -0.27), Color3.fromRGB(240, 240, 255), Enum.Material.Neon)
	prop(model, "Button", Vector3.new(0.18, 0.08, 0.18), base * CFrame.new(-0.3, 0.39, 0), Color3.fromRGB(220, 60, 60))

	local flash = Instance.new("PointLight")
	flash.Name = "Flash"
	flash.Enabled = false
	flash.Brightness = 8
	flash.Range = 18
	flash.Color = Color3.fromRGB(235, 240, 255)
	flash.Shadows = false
	flash.Parent = bulb

	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") and child ~= body then
			weld(body, child)
		end
	end
	weld(hand, body)
	model.PrimaryPart = body
	model.Parent = character
end

function CharacterService:_applyVipTag(player: Player, character: Model)
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local existing = head:FindFirstChild("VIPTag")
	if existing then
		existing:Destroy()
	end
	if not player:GetAttribute("VIP") then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "VIPTag"
	billboard.Size = UDim2.fromOffset(190, 26)
	billboard.StudsOffset = Vector3.new(0, 3.1, 0)
	billboard.MaxDistance = 70
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "⭐ VIP PHOTOGRAPHER"
	label.TextColor3 = Color3.fromRGB(255, 210, 70)
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Parent = billboard
	billboard.Parent = head
end

function CharacterService:_setFlashlight(character: Model, on: boolean)
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local existing = head:FindFirstChild("Flashlight")
	if on and not existing then
		local light = Instance.new("SpotLight")
		light.Name = "Flashlight"
		light.Face = Enum.NormalId.Front
		light.Angle = 60
		light.Range = 48
		light.Brightness = 2.6
		light.Color = Color3.fromRGB(255, 245, 220)
		light.Shadows = false
		light.Parent = head
	elseif not on and existing then
		existing:Destroy()
	end
end

function CharacterService:SetFlashlights(on: boolean)
	self.FlashlightsOn = on
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			self:_setFlashlight(player.Character, on)
		end
	end
end

function CharacterService:Teleport(player: Player, cframe: CFrame)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local target = cframe + Vector3.new(0, 3, 0)
	-- With StreamingEnabled the destination must be loaded on the client first,
	-- otherwise the character could fall through a floor that hasn't streamed in.
	task.spawn(function()
		if Workspace.StreamingEnabled then
			pcall(function()
				player:RequestStreamAroundAsync(target.Position, 2)
			end)
		end
		if character.Parent then
			character:PivotTo(target)
		end
	end)
end

function CharacterService:GetParts(player: Player)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	if not humanoid or humanoid.Health <= 0 or not root or not head then
		return nil, nil, nil
	end
	return root :: BasePart, head :: BasePart, humanoid
end

return CharacterService
