--[[
	CharacterService (ModuleScript)
	Location: ServerScriptService/Services/CharacterService

	Per-character setup: movement modes (walk / run / sneak - validated here
	so noise is based on real speed), the stun used by sound-hunting
	anomalies, camera zoom limit (used by photo validation), the VIP name
	tag and stream-safe teleports. Equipment tools are handled by
	EquipmentService.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local Net = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"))

local CharacterService = {}
CharacterService.Modes = {}
CharacterService.StunnedUntil = {}
CharacterService._modeTimes = {}

local MOVEMENT = GameConfig.Movement
local MODE_SPEED = {
	Walk = MOVEMENT.WalkSpeed,
	Run = MOVEMENT.RunSpeed,
	Sneak = MOVEMENT.SneakSpeed,
}

function CharacterService:Init(services)
	self.Services = services
	Players.PlayerAdded:Connect(function(player)
		self:_watchPlayer(player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		self:_watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		self.Modes[player] = nil
		self.StunnedUntil[player] = nil
		self._modeTimes[player] = nil
	end)
	services.DataService:OnProfileLoaded(function(player)
		self:RefreshCharacter(player)
	end)

	Net.Event("MovementMode").OnServerEvent:Connect(function(player, mode)
		if type(mode) ~= "string" or MODE_SPEED[mode] == nil then
			return
		end
		local now = os.clock()
		if self._modeTimes[player] and now - self._modeTimes[player] < 0.08 then
			return
		end
		self._modeTimes[player] = now
		self.Modes[player] = mode
		self:_applySpeed(player)
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
	self.Modes[player] = "Walk"
	self.StunnedUntil[player] = nil
	self:_applySpeed(player)
	player.CameraMaxZoomDistance = GameConfig.Player.MaxZoomDistance
	character:WaitForChild("Head", 10)
	self:RefreshCharacter(player)
end

function CharacterService:_applySpeed(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local stunned = self.StunnedUntil[player] and os.clock() < self.StunnedUntil[player]
	humanoid.WalkSpeed = if stunned then 0 else MODE_SPEED[self.Modes[player] or "Walk"]
	humanoid.JumpPower = if stunned then 0 else 50
	humanoid.UseJumpPower = true
end

function CharacterService:GetMode(player: Player): string
	return self.Modes[player] or "Walk"
end

-- Freezes a player briefly (caught by a sound-hunting anomaly).
function CharacterService:Stun(player: Player, duration: number)
	local untilTime = os.clock() + duration
	self.StunnedUntil[player] = untilTime
	self:_applySpeed(player)
	task.delay(duration, function()
		if self.StunnedUntil[player] == untilTime then
			self.StunnedUntil[player] = nil
			self:_applySpeed(player)
		end
	end)
end

function CharacterService:RefreshCharacter(player: Player)
	if not self.Services then
		return -- not initialised yet; _setupCharacter will run later
	end
	local character = player.Character
	if not character or not character.Parent then
		return
	end
	self:_applyVipTag(player, character)
	local equipment = self.Services.EquipmentService
	if equipment and equipment.RefreshTools then
		equipment:RefreshTools(player)
	end
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
