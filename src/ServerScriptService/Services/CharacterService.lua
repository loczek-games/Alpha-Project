--[[
	CharacterService (ModuleScript)
	Location: ServerScriptService/Services/CharacterService

	Per-character rules:
	  * CAMERA   lobby = third person (zoom GameConfig.Camera.LobbyMin/MaxZoom),
	             mission = LockFirstPerson (FirstPersonController re-applies it
	             on the client after jumpscares, teleports and respawns).
	  * ANIMATIONS  during a mission every character uses the standard R15
	             set from GameConfig.Animations (idle / walk / run / jump /
	             fall...). Only the values inside the character's Animate
	             script are swapped; the avatar is never modified and the
	             originals come back in the lobby.
	  * MOVEMENT  walk / run / sneak modes validated here (noise is based on
	             real speed), stuns from sound-hunting anomalies.
	  * DOWNED    heavy anomaly attacks knock an investigator down. Team
	             mates hold the REVIVE prompt; after GameConfig.Player.DownedTime
	             the investigator wakes up back at the entrance, drained.
	  * VIP name tag and stream-safe teleports.
]]

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local Net = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"))

local CharacterService = {}
CharacterService.Modes = {}
CharacterService.StunnedUntil = {}
CharacterService.Downed = {} :: { [Player]: any }
CharacterService._modeTimes = {}

local MOVEMENT = GameConfig.Movement
local CAMERA = GameConfig.Camera
local PLAYER = GameConfig.Player
local MODE_SPEED = {
	Walk = MOVEMENT.WalkSpeed,
	Run = MOVEMENT.RunSpeed,
	Sneak = MOVEMENT.SneakSpeed,
}

-- Animate script value -> GameConfig.Animations key
local ANIMATE_SLOTS = {
	{ "idle", "Animation1", "Idle", 1 },
	{ "idle", "Animation2", "Idle", 2 },
	{ "walk", "WalkAnim", "Walk" },
	{ "run", "RunAnim", "Run" },
	{ "jump", "JumpAnim", "Jump" },
	{ "fall", "FallAnim", "Fall" },
	{ "climb", "ClimbAnim", "Climb" },
	{ "swim", "Swim", "Swim" },
	{ "swimidle", "SwimIdle", "SwimIdle" },
}

function CharacterService:Init(services)
	self.Services = services
	-- anomalies (AnomalyKit.CollisionGroup) never collide with (push, block,
	-- trap) investigators. Registered here, before any character can spawn.
	local ok, err = pcall(function()
		for _, group in ipairs({ "COCPlayer", "COCAnomaly" }) do
			if not PhysicsService:IsCollisionGroupRegistered(group) then
				PhysicsService:RegisterCollisionGroup(group)
			end
		end
		PhysicsService:CollisionGroupSetCollidable("COCAnomaly", "COCPlayer", false)
		PhysicsService:CollisionGroupSetCollidable("COCAnomaly", "COCAnomaly", false)
	end)
	if not ok then
		warn("[CharacterService] collision groups:", err)
	end
	self.DownedRemote = Net.Event("PlayerDowned")
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
		self.Downed[player] = nil
	end)
	services.DataService:OnProfileLoaded(function(player)
		self:RefreshCharacter(player)
	end)

	Net.Event("MissionRequest").OnServerEvent:Connect(function(player, action)
		if action == "UseRevive" and self.Downed[player] then
			local data = services.DataService:GetData(player)
			if data and (data.ReviveTokens or 0) > 0 then
				data.ReviveTokens -= 1
				services.DataService:MarkChanged(player)
				self:Revive(player, nil)
			end
		end
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
	self:_applyCamera(player, false)
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
	if self.Downed[player] then
		self.Downed[player] = nil
		player:SetAttribute("Downed", false)
	end
	humanoid.BreakJointsOnDeath = false
	-- anomalies (COCAnomaly group) never collide with investigators
	local function group(descendant: Instance)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = "COCPlayer"
		end
	end
	for _, descendant in ipairs(character:GetDescendants()) do
		group(descendant)
	end
	character.DescendantAdded:Connect(group)
	self:_applySpeed(player)
	local inMission = player:GetAttribute("InMission") == true
	self:_applyCamera(player, inMission)
	character:WaitForChild("Head", 10)
	-- Animate is added by the engine right after the character spawns
	task.delay(0.2, function()
		if character.Parent then
			self:_applyAnimations(character, player:GetAttribute("InMission") == true)
		end
	end)
	self:RefreshCharacter(player)
end

---------------------------------------------------------------------------
-- Mission mode: first person + standard animations
---------------------------------------------------------------------------

function CharacterService:_applyCamera(player: Player, inMission: boolean)
	if inMission then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 0.5
	else
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMaxZoomDistance = CAMERA.LobbyMaxZoom
		player.CameraMinZoomDistance = CAMERA.LobbyMinZoom
	end
end

function CharacterService:SetMissionMode(player: Player, inMission: boolean)
	player:SetAttribute("InMission", inMission)
	self:_applyCamera(player, inMission)
	local character = player.Character
	if character then
		self:_applyAnimations(character, inMission)
	end
	if not inMission then
		self:Revive(player, nil, true)
	end
	self:_applySpeed(player)
	local equipment = self.Services.EquipmentService
	if equipment then
		equipment:OnMissionMode(player, inMission)
	end
end

function CharacterService:_applyAnimations(character: Model, standard: boolean)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animate = character:FindFirstChild("Animate")
	if not humanoid or not animate or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end
	for _, slot in ipairs(ANIMATE_SLOTS) do
		local folder = animate:FindFirstChild(slot[1])
		local animation = folder and folder:FindFirstChild(slot[2])
		if animation and animation:IsA("Animation") then
			local original = animation:GetAttribute("OriginalId")
			if original == nil then
				original = animation.AnimationId
				animation:SetAttribute("OriginalId", original)
			end
			local wanted
			if standard then
				local configured = GameConfig.Animations[slot[3]]
				wanted = if type(configured) == "table" then configured[slot[4] or 1] else configured
			else
				wanted = original
			end
			if wanted and animation.AnimationId ~= wanted then
				animation.AnimationId = wanted
			end
		end
	end
	character:SetAttribute("StandardAnimations", standard)
end

---------------------------------------------------------------------------
-- Movement
---------------------------------------------------------------------------

function CharacterService:_applySpeed(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local stunned = self.StunnedUntil[player] and os.clock() < self.StunnedUntil[player]
	local downed = self.Downed[player] ~= nil
	local frozen = stunned or downed
	humanoid.WalkSpeed = if frozen then 0 else MODE_SPEED[self.Modes[player] or "Walk"]
	humanoid.JumpPower = if frozen then 0 else 50
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

---------------------------------------------------------------------------
-- Downed / revive
---------------------------------------------------------------------------

function CharacterService:IsDowned(player: Player): boolean
	return self.Downed[player] ~= nil
end

function CharacterService:Down(player: Player, source: string?)
	if self.Downed[player] or player:GetAttribute("InMission") ~= true then
		return
	end
	local root, _, humanoid = self:GetParts(player)
	if not root or not humanoid then
		return
	end
	local token = {}
	local record = { Token = token, Source = source, Until = os.clock() + PLAYER.DownedTime }
	self.Downed[player] = record
	player:SetAttribute("Downed", true)
	player:SetAttribute("DownedUntil", Workspace:GetServerTimeNow() + PLAYER.DownedTime)
	self:_applySpeed(player)
	humanoid.Sit = false

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RevivePrompt"
	prompt.ActionText = "Revive"
	prompt.ObjectText = player.DisplayName
	prompt.HoldDuration = PLAYER.ReviveHoldTime
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt:SetAttribute("OwnerUserId", player.UserId)
	prompt.Parent = root
	record.Prompt = prompt
	prompt.Triggered:Connect(function(reviver)
		if reviver ~= player and not self.Downed[reviver] and self.Downed[player] == record then
			self:Revive(player, reviver)
		end
	end)

	local mission = self.Services.MissionService
	if mission then
		mission:RecordStat(player, "Downs")
	end
	self.DownedRemote:FireClient(player, { Downed = true, Until = player:GetAttribute("DownedUntil"), Source = source })
	task.delay(PLAYER.DownedTime, function()
		if self.Downed[player] == record then
			self:_taken(player)
		end
	end)
end

function CharacterService:Revive(player: Player, reviver: Player?, silent: boolean?)
	local record = self.Downed[player]
	if not record then
		return
	end
	self.Downed[player] = nil
	if record.Prompt then
		record.Prompt:Destroy()
	end
	player:SetAttribute("Downed", false)
	self:_applySpeed(player)
	if player:IsDescendantOf(Players) then
		self.DownedRemote:FireClient(player, { Downed = false, By = if reviver then reviver.DisplayName else nil, Silent = silent })
	end
	if reviver then
		local mission = self.Services.MissionService
		if mission then
			mission:RecordStat(reviver, "Revives")
		end
		self.Services.AudioService:Play("Interaction.Revive", player.Character and player.Character:FindFirstChild("HumanoidRootPart"), {})
	end
end

-- Nobody came: wake up at the entrance, equipment drained.
function CharacterService:_taken(player: Player)
	self:Revive(player, nil, true)
	if not player:IsDescendantOf(Players) or player:GetAttribute("InMission") ~= true then
		return
	end
	self.DownedRemote:FireClient(player, { Downed = false, Taken = true })
	task.delay(0.6, function()
		self:Teleport(player, self.Services.MapService:GetMallSpawnCFrame())
		for _ = 1, 3 do
			self.Services.EquipmentService:DrainEquipped(player, 15)
		end
	end)
end

---------------------------------------------------------------------------
-- Tools, VIP tag, teleports
---------------------------------------------------------------------------

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
	label.Text = "VIP INVESTIGATOR"
	label.TextColor3 = Color3.fromRGB(255, 210, 70)
	label.TextStrokeTransparency = 0.3
	label.FontFace = Font.fromEnum(Enum.Font.SpecialElite)
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
				player:RequestStreamAroundAsync(target.Position, 3)
			end)
		end
		if character.Parent then
			(root :: BasePart).AssemblyLinearVelocity = Vector3.zero
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
