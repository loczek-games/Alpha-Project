--[[
	PhotoController (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/PhotoController

	The one-button core loop.
	  Mobile : big action button (placed next to the jump button, thumb-reachable)
	  PC     : Left Mouse Button or E (the on-screen button also works)
	  Gamepad: R2 / ButtonX
	The big button is PHOTO while the camera is held, otherwise it uses the
	held item (flashlight, EMF, ...). Zoom: Q / L2 / the 🔍 button.

	Camera sound design:  aim -> quiet autofocus "beep" + lens "zzzt"
	-> CLICK + FLASH -> flash recharge whine. Near a dangerous anomaly the
	autofocus breaks: "beep... beep... BEEEEP" + static + screen glitch,
	and the entity may react (the server hears the autofocus).

	The client only plays feedback and sends its camera CFrame. The server
	(PhotoService) decides whether anything was captured.
]]

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local AnomalyConfig = require(Config:WaitForChild("AnomalyConfig"))
local RarityConfig = require(Config:WaitForChild("RarityConfig"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Net = require(Modules:WaitForChild("Net"))
local Format = require(Modules:WaitForChild("Format"))

local PhotoController = {}
PhotoController.LastShot = 0
PhotoController.Zoomed = false
PhotoController.PromptsShown = 0
PhotoController.LastFocusDistance = 0
PhotoController.NextFocusCheck = 0
PhotoController.NextBrokenFocus = 0

local ZOOM_FOV = 34

local FAIL_MESSAGES = {
	NOTHING = "Nothing strange here... 🤔",
	TOO_FAR = "Too far away! Get closer 📏",
	OFF_CENTER = "Almost! Put it in the CENTRE 🎯",
	BLOCKED = "Something is in the way 🧱",
	NEEDS_CAMERA = "Your camera can't capture this one 📷",
	MAXED = "You already have 3 shots of this one 📚",
	NOT_IN_ROUND = "📸 Photos only count during an investigation",
	DECOY = "That's just... normal. Probably. 😅",
	NO_BATTERY = "🪫 Camera battery empty! Find a battery 🔋",
}

function PhotoController:Init(controllers)
	self.Controllers = controllers
	local UIKit = controllers.UIKit
	local theme = UIKit.Theme
	local hud = controllers.HUDController
	self.Remote = Net.Event("PhotoRequest")

	-- The PHOTO button lives directly in the HUD ScreenGui (pixel-positioned so it
	-- never overlaps the mobile jump button regardless of UI scale).
	local button = UIKit.new("TextButton", {
		Name = "PhotoButton",
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = Color3.fromRGB(20, 18, 18),
		AutoButtonColor = false,
		Text = "",
		Parent = hud.Gui,
	})
	UIKit.Corner(button, UDim.new(1, 0))
	UIKit.Stroke(button, Color3.fromRGB(200, 196, 188), 3, 0.1)
	local inner = UIKit.Frame({
		Name = "Inner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8),
		BackgroundColor3 = theme.Accent,
		Parent = button,
	})
	UIKit.Corner(inner, UDim.new(1, 0))
	self.ButtonInner = inner
	self.ButtonIcon = UIKit.Label({
		Name = "Icon",
		Text = "📸",
		TextScaled = true,
		Position = UDim2.fromScale(0.2, 0.12),
		Size = UDim2.fromScale(0.6, 0.48),
		Parent = inner,
	})
	self.ButtonCaption = UIKit.Label({
		Name = "Caption",
		Text = "PHOTO",
		Font = theme.FontBlack,
		TextScaled = true,
		Position = UDim2.fromScale(0.15, 0.6),
		Size = UDim2.fromScale(0.7, 0.2),
		Parent = inner,
	})
	self.Cooldown = UIKit.Frame({
		Name = "Cooldown",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Parent = button,
	})
	UIKit.Corner(self.Cooldown, UDim.new(1, 0))
	self.ButtonScale = UIKit.new("UIScale", { Parent = button })
	self.Hint = UIKit.Label({
		Name = "KeyHint",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 4),
		Size = UDim2.fromOffset(160, 18),
		Text = "CLICK / E",
		Font = theme.FontBlack,
		TextSize = 13,
		TextColor3 = theme.SubText,
		TextStrokeTransparency = 0.6,
		Parent = button,
	})
	self.Button = button
	self.FailLabel = UIKit.Label({
		Name = "FailLabel",
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(340, 28),
		Text = "",
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextStrokeTransparency = 0.3,
		TextTransparency = 1,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		Parent = hud.Gui,
	})

	-- small zoom button (touch only, while the camera is held)
	self.ZoomButton = UIKit.Button({
		Name = "ZoomButton",
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(52, 52),
		BackgroundColor3 = theme.Bg,
		BackgroundTransparency = 0.25,
		Text = "🔍",
		TextSize = 22,
		CornerRadius = 26,
		Visible = false,
		Parent = hud.Gui,
	}, function()
		self:ToggleZoom()
	end)

	button.Activated:Connect(function()
		self:Press()
	end)
	-- E also triggers ProximityPrompts (doors, lockers...): don't shoot while one is shown
	ProximityPromptService.PromptShown:Connect(function()
		self.PromptsShown += 1
	end)
	ProximityPromptService.PromptHidden:Connect(function()
		self.PromptsShown = math.max(0, self.PromptsShown - 1)
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or UIKit.IsAnyPanelOpen() or controllers.ClientState.InDarkRoom then
			return
		end
		-- at HQ the mouse / E only act while you hold an item
		if not controllers.ClientState:IsInMission() and not controllers.EquipmentController.Equipped then
			return
		end
		local key = input.KeyCode
		if input.UserInputType == Enum.UserInputType.MouseButton1 or key == Enum.KeyCode.ButtonR2 or key == Enum.KeyCode.ButtonX then
			self:Press()
		elseif key == Enum.KeyCode.E and self.PromptsShown == 0 then
			self:Press()
		elseif key == Enum.KeyCode.Q or key == Enum.KeyCode.ButtonL2 then
			self:ToggleZoom()
		end
	end)

	controllers.EquipmentController.Changed:Connect(function(itemId)
		self:_refreshButton(itemId)
	end)
	controllers.ClientState.RoundChanged:Connect(function()
		self:_layout()
	end)
	controllers.ClientState.DarkRoomChanged:Connect(function()
		self:_layout()
	end)

	hud.Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_layout()
	end)
	UserInputService.LastInputTypeChanged:Connect(function()
		self:_layout()
	end)
	self:_layout()

	Net.Event("PhotoResult").OnClientEvent:Connect(function(result)
		if type(result) ~= "table" then
			return
		end
		if result.Success then
			self:_onSuccess(result)
		else
			self:_onFail(result)
		end
	end)
end

-- Places the button beside the Roblox touch jump button (or bottom-right on PC).
function PhotoController:_layout()
	local gui = self.Controllers.HUDController.Gui
	local size = gui.AbsoluteSize
	local minDim = math.min(size.X, size.Y)
	local lastInput = UserInputService:GetLastInputType()
	local touch = self.Controllers.UIKit.IsTouch() or lastInput == Enum.UserInputType.Touch
	local diameter, right, bottom
	if touch then
		local small = minDim <= 500
		local jumpSize = if small then 70 else 120
		local jumpRight = if small then 25 else 50
		local jumpBottom = if small then 20 else 90
		diameter = if small then 100 else 140
		right = jumpRight + jumpSize + 16
		bottom = jumpBottom + 6
		self.Hint.Visible = false
	else
		diameter = math.clamp(math.floor(minDim * 0.11), 84, 120)
		right = 28
		bottom = 40
		self.Hint.Visible = true
	end
	self.Button.Size = UDim2.fromOffset(diameter, diameter)
	self.Button.Position = UDim2.new(1, -right, 1, -bottom)
	self.FailLabel.Position = UDim2.new(1, -right, 1, -(bottom + diameter + 8))
	self.ZoomButton.Position = UDim2.new(1, -(right + diameter + 8), 1, -bottom)
	self.Touch = touch
	self:_refreshButton(self.Controllers.EquipmentController and self.Controllers.EquipmentController.Equipped)
end

function PhotoController:Start()
	RunService.Heartbeat:Connect(function()
		local ok, err = pcall(function()
			self:_autofocus()
		end)
		if not ok then
			warn("[PhotoController] autofocus:", err)
		end
	end)
end

-- The big button mirrors the held item.
function PhotoController:_refreshButton(itemId: string?)
	if not self.ButtonIcon then
		return
	end
	local equipment = self.Controllers.EquipmentController
	local item = equipment and equipment:GetEquippedItem()
	local theme = self.Controllers.UIKit.Theme
	if not item or item.Id == "Camera" then
		self.ButtonIcon.Text = "📸"
		self.ButtonCaption.Text = if item then "PHOTO" else "CAMERA"
		self.ButtonInner.BackgroundColor3 = theme.Accent
	else
		local on = equipment.On[item.Id] == true
		self.ButtonIcon.Text = item.Icon
		self.ButtonCaption.Text = item.ActionLabel .. (if on then " ON" else "")
		self.ButtonInner.BackgroundColor3 = if on then Color3.fromRGB(230, 170, 40) else Color3.fromRGB(70, 70, 90)
	end
	local state = self.Controllers.ClientState
	local usable = not state.InDarkRoom and (state:IsInMission() or item ~= nil)
	self.Button.Visible = usable
	self.ZoomButton.Visible = usable and self.Touch == true and itemId == "Camera"
	if itemId ~= "Camera" and self.Zoomed then
		self:ToggleZoom(true)
	end
end

function PhotoController:Press()
	local equipment = self.Controllers.EquipmentController
	local held = equipment.Equipped
	if held == "Camera" then
		self:Shoot()
	elseif held then
		equipment:UseEquipped()
	else
		equipment:SelectItem("Camera")
	end
end

function PhotoController:ToggleZoom(silent: boolean?)
	local equipment = self.Controllers.EquipmentController
	if not self.Zoomed and equipment.Equipped ~= "Camera" then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	self.Zoomed = not self.Zoomed
	local normal = self.Controllers.FirstPersonController.BaseFieldOfView
	TweenService:Create(camera, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { FieldOfView = if self.Zoomed then ZOOM_FOV else normal }):Play()
	self.Controllers.ViewmodelController:SetZoom(self.Zoomed, normal / ZOOM_FOV)
	if not silent then
		local audio = self.Controllers.AudioController
		audio:Play(if self.Zoomed then "Camera.ZoomIn" else "Camera.ZoomOut", nil)
		audio:Play("Camera.LensMove", nil)
		equipment.Remote:FireServer("Zoom", if self.Zoomed then "In" else "Out")
	end
	self.ZoomButton.Text = if self.Zoomed then "🔎" else "🔍"
end

-- Real autofocus: re-focuses (beep + lens motor) when the distance in the
-- middle of the frame changes. Dangerous anomalies make it malfunction.
function PhotoController:_autofocus()
	local equipment = self.Controllers.EquipmentController
	local camera = Workspace.CurrentCamera
	local now = os.clock()
	if equipment.Equipped ~= "Camera" or not camera or now < self.NextFocusCheck then
		return
	end
	self.NextFocusCheck = now + 0.3
	local audio = self.Controllers.AudioController
	local origin = camera.CFrame.Position
	local look = camera.CFrame.LookVector

	-- something dangerous in view?
	local beacons = Workspace:FindFirstChild("AnomalyBeacons")
	if beacons and now >= self.NextBrokenFocus then
		for _, beacon in ipairs(beacons:GetChildren()) do
			if beacon:IsA("BasePart") and (beacon:GetAttribute("Danger") or 0) >= 0.6 then
				local offset = beacon.Position - origin
				if offset.Magnitude < 55 and offset.Magnitude > 0.1 and math.deg(math.acos(math.clamp(look:Dot(offset.Unit), -1, 1))) < 25 then
					self.NextBrokenFocus = now + 3.5
					self.Controllers.ViewmodelController:SetFocus("Error")
					task.spawn(function()
						audio:Play("Camera.Focus", nil)
						task.wait(0.4)
						audio:Play("Camera.Focus", nil)
						task.wait(0.3)
						audio:Play("Camera.FocusBroken", nil)
						audio:Play("Camera.Static", nil)
						self.Controllers.FxController:Glitch(0.6)
						equipment.Remote:FireServer("FocusBroken")
					end)
					return
				end
			end
		end
	end

	local params = self.FocusParams
	if not params then
		params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		self.FocusParams = params
	end
	local character = game:GetService("Players").LocalPlayer.Character
	params.FilterDescendantsInstances = if character then { character } else {}
	local result = Workspace:Raycast(origin, look * 150, params)
	local distance = if result then result.Distance else 150
	local last = self.LastFocusDistance
	if math.abs(distance - last) / math.max(distance, 4) > 0.25 then
		self.LastFocusDistance = distance
		self.Controllers.ViewmodelController:SetFocus("Focusing")
		-- "beep... zzzt"
		audio:Play("Camera.Focus", nil)
		task.delay(0.12, function()
			audio:Play("Camera.LensMove", nil, { Volume = 0.8 })
		end)
		if now >= (self.NextFocusRemote or 0) then
			self.NextFocusRemote = now + 1 -- others (and anomalies) hear it; the server rate-limits too
			equipment.Remote:FireServer("Focus")
		end
	end
end

function PhotoController:Shoot()
	local state = self.Controllers.ClientState
	local stats = state:GetCameraStats()
	local now = os.clock()
	local UIKit = self.Controllers.UIKit
	local equipment = self.Controllers.EquipmentController
	local audio = self.Controllers.AudioController
	if now - self.LastShot < stats.Cooldown or not equipment:IsReady() then
		self.ButtonScale.Scale = 0.9
		UIKit.Tween(self.ButtonScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	if state:IsInRound() and (equipment.Battery.Camera or 100) <= 0 then
		audio:Play("Camera.ButtonClick", nil)
		audio:Play("Camera.Error", nil)
		self:_onFail({ Success = false, Reason = "NO_BATTERY" })
		self.LastShot = now
		return
	end
	self.LastShot = now

	local fx = self.Controllers.FxController
	-- *click* -> CLICK - FLASH -> recharge whine
	audio:Play("Camera.ButtonClick", nil)
	audio:Play("Camera.Shutter", nil)
	audio:Play("Camera.FlashTrigger", nil)
	task.delay(0.15, function()
		audio:Play("Camera.FlashCharge", nil)
	end)
	fx:Flash(0.85)
	fx:FreezeFrame(0.1)
	self.Controllers.ViewmodelController:Shutter()
	self.Remote:FireServer(camera.CFrame)

	self.ButtonScale.Scale = 0.85
	UIKit.Tween(self.ButtonScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	self.Cooldown.BackgroundTransparency = 0.35
	UIKit.Tween(self.Cooldown, stats.Cooldown, { BackgroundTransparency = 1 }, Enum.EasingStyle.Linear)
end

function PhotoController:_onFail(result)
	local UIKit = self.Controllers.UIKit
	self.Controllers.AudioController:Play("UI.Fail", nil)
	local text = result.Message or FAIL_MESSAGES[result.Reason] or FAIL_MESSAGES.NOTHING
	if result.Reason == "DECOY" then
		text = "🔔 " .. text
	end
	self.FailLabel.Text = text
	self.FailLabel.TextTransparency = 0
	self.FailLabel.TextStrokeTransparency = 0.3
	local token = os.clock()
	self.FailToken = token
	task.delay(1.8, function()
		if self.FailToken == token then
			UIKit.Tween(self.FailLabel, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
	self.Controllers.HUDController:PulseReticle(Color3.fromRGB(255, 120, 120))
end

---------------------------------------------------------------------------
-- The polaroid capture card
---------------------------------------------------------------------------

local function stripClone(clone: Instance)
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("BaseScript") or descendant:IsA("Sound") or descendant:IsA("ProximityPrompt") or descendant:IsA("BillboardGui") or descendant:IsA("Light") or descendant:IsA("ForceField") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.LocalTransparencyModifier = 0
		end
	end
end

local function fillViewport(viewport: ViewportFrame, result): boolean
	local source = result.View
	if typeof(source) ~= "Instance" or not source.Parent then
		return false
	end
	local wasArchivable = source.Archivable
	source.Archivable = true
	local ok, clone = pcall(function()
		return source:Clone()
	end)
	source.Archivable = wasArchivable
	if not ok or not clone then
		return false
	end
	stripClone(clone)
	local model: Model
	if clone:IsA("Model") then
		model = clone
	elseif clone:IsA("BasePart") then
		model = Instance.new("Model")
		clone.Parent = model
	else
		clone:Destroy()
		return false
	end
	model.Parent = viewport

	local boxCFrame, boxSize = model:GetBoundingBox()
	local center: Vector3 = if typeof(result.TargetPosition) == "Vector3" then result.TargetPosition else boxCFrame.Position
	local shotCFrame: CFrame = if typeof(result.CameraCFrame) == "CFrame" then result.CameraCFrame else CFrame.lookAt(center + Vector3.new(0, 2, 8), center)
	local direction = center - shotCFrame.Position
	if direction.Magnitude < 0.1 then
		direction = Vector3.new(0, 0, -1)
	end
	local extent = math.max(boxSize.X, boxSize.Y, boxSize.Z)
	local distance = math.clamp(extent * 1.35, 4, 70)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(center - direction.Unit * distance, center)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return true
end

function PhotoController:_onSuccess(result)
	local controllers = self.Controllers
	local UIKit = controllers.UIKit
	local theme = UIKit.Theme
	local tier = RarityConfig.Get(result.Rarity)
	local def = AnomalyConfig.Get(result.Id)
	controllers.AudioController:Play(if tier.Rank >= RarityConfig.GetRank("Rare") then "Camera.CaptureRare" else "Camera.CaptureSuccess", nil)
	if result.IsNew then
		controllers.AudioController:Play("UI.NewDiscovery", nil)
	end
	controllers.HUDController:PulseReticle(tier.Color)

	if self.Card then
		self.Card:Destroy()
	end
	local root = controllers.HUDController.Root
	local card = UIKit.Frame({
		Name = "CaptureCard",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 60),
		Size = UDim2.fromOffset(252, 330),
		BackgroundColor3 = theme.Paper,
		Rotation = -6,
		Parent = root,
	})
	self.Card = card
	UIKit.Corner(card, 8)
	UIKit.Stroke(card, tier.Color, 3, 0)

	local header = UIKit.Frame({ Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = tier.Color, Parent = card })
	UIKit.Corner(header, 8)
	local verb = if result.IsNew then "DISCOVERED" else "CAPTURED"
	UIKit.Label({
		Text = string.format("%s ANOMALY %s", string.upper(tier.DisplayName), verb),
		Font = theme.FontBlack,
		TextSize = 13,
		TextColor3 = if tier.Id == "Common" or tier.Id == "Impossible" or tier.Id == "Unknown" then theme.Ink else Color3.new(1, 1, 1),
		Parent = header,
	})

	local photo = UIKit.new("ViewportFrame", {
		Name = "Photo",
		Position = UDim2.fromOffset(10, 38),
		Size = UDim2.new(1, -20, 0, 142),
		BackgroundColor3 = Color3.fromRGB(18, 18, 22),
		Ambient = Color3.fromRGB(150, 150, 160),
		LightColor = Color3.fromRGB(255, 245, 230),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
		Parent = card,
	})
	local rendered = fillViewport(photo, result)
	if not rendered then
		UIKit.Label({ Text = def and def.Icon or "❓", TextScaled = true, Size = UDim2.fromScale(1, 0.8), Position = UDim2.fromScale(0, 0.1), Parent = photo })
	end
	UIKit.Label({
		Text = "● REC  " .. DateTime.now():FormatLocalTime("HH:mm:ss", "en-us"),
		Font = Enum.Font.Code,
		TextSize = 12,
		TextColor3 = theme.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(6, 4),
		Size = UDim2.new(1, -12, 0, 14),
		Parent = photo,
	})
	UIKit.Label({
		Text = Format.Stars(result.Stars),
		TextSize = 22,
		TextColor3 = theme.Gold,
		TextStrokeTransparency = 0.4,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -2),
		Size = UDim2.new(1, 0, 0, 24),
		Parent = photo,
	})

	UIKit.Label({
		Text = string.upper(result.Name or "???"),
		Font = theme.FontBlack,
		TextSize = 20,
		TextColor3 = theme.Ink,
		Position = UDim2.fromOffset(8, 184),
		Size = UDim2.new(1, -16, 0, 26),
		Parent = card,
	})
	UIKit.Label({
		Text = result.Odds or "",
		Font = theme.FontType,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(90, 85, 80),
		Position = UDim2.fromOffset(8, 208),
		Size = UDim2.new(1, -16, 0, 20),
		Parent = card,
	})
	UIKit.Label({
		Text = if result.Reward > 0 then string.format("+%s Evidence", Format.Money(result.Reward)) else "Evidence already filed",
		Font = theme.FontBlack,
		TextSize = if result.Reward > 0 then 20 else 14,
		TextColor3 = Color3.fromRGB(30, 150, 60),
		Position = UDim2.fromOffset(8, 230),
		Size = UDim2.new(1, -16, 0, 26),
		Parent = card,
	})

	local tagText, tagColor
	if result.IsNew then
		tagText, tagColor = "NEW DISCOVERY!", theme.Accent
	elseif result.IsNewBest then
		tagText, tagColor = "NEW BEST PHOTO!  " .. Format.Stars(result.BestStars), Color3.fromRGB(200, 140, 0)
	else
		tagText, tagColor = string.format("BEST %s  ·  x%d", Format.Stars(result.BestStars), result.Count or 1), Color3.fromRGB(110, 105, 100)
	end
	local tag = UIKit.Label({
		Text = tagText,
		Font = theme.FontBlack,
		TextSize = 17,
		TextColor3 = tagColor,
		Position = UDim2.fromOffset(8, 258),
		Size = UDim2.new(1, -16, 0, 24),
		Parent = card,
	})
	local bonuses = {}
	if (result.Group or 0) > 0 then
		table.insert(bonuses, string.format("👥 GROUP PHOTO x%d", result.Group + 1))
	end
	if result.First then
		table.insert(bonuses, "⚡ FIRST!")
	end
	UIKit.Label({
		Text = table.concat(bonuses, "   "),
		Font = theme.Font,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(70, 70, 80),
		Position = UDim2.fromOffset(8, 286),
		Size = UDim2.new(1, -16, 0, 20),
		Parent = card,
	})

	local scale = UIKit.new("UIScale", { Scale = 0.5, Parent = card })
	UIKit.Tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	UIKit.Tween(card, 0.5, { Rotation = -2 }, Enum.EasingStyle.Back)

	if result.IsNew then
		task.spawn(function()
			for i = 1, 8 do
				if not tag.Parent then
					return
				end
				tag.TextColor3 = if i % 2 == 0 then theme.Accent else theme.Gold
				task.wait(0.18)
			end
		end)
	end

	task.delay(3.2, function()
		if self.Card == card then
			UIKit.Tween(card, 0.35, { Position = UDim2.new(1, 300, 0, 60), Rotation = 8 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			task.wait(0.4)
			if self.Card == card then
				self.Card = nil
			end
			card:Destroy()
		end
	end)
end

return PhotoController
