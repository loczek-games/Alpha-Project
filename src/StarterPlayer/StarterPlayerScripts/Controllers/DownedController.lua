--[[
	DownedController (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/DownedController

	What you see after a heavy anomaly attack knocks you down:
	  * the view stays low (camera offset) and desaturated, heartbeat
	  * "A TEAMMATE CAN REVIVE YOU" + countdown until you wake up at the entrance
	  * REVIVE (Robux, Developer Product) or USE REVIVE (a stored token)
	The server decides everything (CharacterService); this only displays it.
]]

local Lighting = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local MonetizationConfig = require(Config:WaitForChild("MonetizationConfig"))
local Net = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"))

local DownedController = {}

local player = Players.LocalPlayer

function DownedController:Init(controllers)
	self.Controllers = controllers
	local UIKit = controllers.UIKit
	local theme = UIKit.Theme
	local gui = UIKit.GetScreenGui("DownedUI", 55, true)
	local root = UIKit.ScaledRoot(gui)
	self.Grade = Instance.new("ColorCorrectionEffect")
	self.Grade.Name = "COC_DownedGrade"
	self.Grade.Enabled = false
	self.Grade.Saturation = -0.85
	self.Grade.Contrast = 0.2
	self.Grade.TintColor = Color3.fromRGB(255, 200, 200)
	self.Grade.Parent = Lighting

	local panel = UIKit.Frame({ Name = "Downed", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = root })
	self.Panel = panel
	local vignette = UIKit.Frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(60, 0, 0), BackgroundTransparency = 0.2, Parent = panel })
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.35, 1), NumberSequenceKeypoint.new(0.65, 1), NumberSequenceKeypoint.new(1, 0) })
	gradient.Rotation = 90
	gradient.Parent = vignette
	self.Title = UIKit.Label({ Text = "YOU WERE ATTACKED", Font = theme.FontType, TextSize = 40, TextColor3 = theme.AccentBright, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.22), Size = UDim2.new(0.9, 0, 0, 50), Parent = panel })
	self.Sub = UIKit.Label({ Text = "A TEAMMATE CAN REVIVE YOU", Font = theme.Font, TextSize = 18, TextColor3 = theme.Text, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.new(0.9, 0, 0, 26), Parent = panel })
	local bar = UIKit.Frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(320, 6), BackgroundColor3 = theme.Panel3, Parent = panel })
	self.Fill = UIKit.Frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = theme.AccentBright, Parent = bar })
	self.Count = UIKit.Label({ Text = "", Font = theme.Font, TextSize = 14, TextColor3 = theme.SubText, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.375), Size = UDim2.fromOffset(320, 20), Parent = panel })
	self.ReviveButton = UIKit.Button({ Text = "REVIVE NOW", Font = theme.FontType, TextSize = 18, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(240, 50), BackgroundColor3 = theme.Accent, Parent = panel }, function()
		self:_revive()
	end)

	controllers.ClientState.DownedChanged:Connect(function(info)
		self:_onChanged(info)
	end)
end

function DownedController:_revive()
	local data = self.Controllers.ClientState.Data
	if data and (data.ReviveTokens or 0) > 0 then
		Net.Event("MissionRequest"):FireServer("UseRevive")
		return
	end
	local product = MonetizationConfig.Products.Revive
	if MonetizationConfig.IsConfigured(product) then
		MarketplaceService:PromptProductPurchase(player, product.Id)
	end
end

function DownedController:_onChanged(info)
	local controllers = self.Controllers
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if type(info) == "table" and info.Downed then
		self.Panel.Visible = true
		self.Grade.Enabled = true
		if humanoid then
			TweenService:Create(humanoid, TweenInfo.new(0.6), { CameraOffset = Vector3.new(0, -2.4, 0) }):Play()
		end
		local data = controllers.ClientState.Data
		local tokens = data and data.ReviveTokens or 0
		local product = MonetizationConfig.Products.Revive
		self.ReviveButton.Visible = tokens > 0 or MonetizationConfig.IsConfigured(product)
		self.ReviveButton.Text = if tokens > 0 then string.format("USE REVIVE (%d)", tokens) else "REVIVE NOW (R$)"
		local untilTime = info.Until or (Workspace:GetServerTimeNow() + 15)
		local total = math.max(1, untilTime - Workspace:GetServerTimeNow())
		self.Token = untilTime
		task.spawn(function()
			while self.Token == untilTime and self.Panel.Visible do
				local left = math.max(0, untilTime - Workspace:GetServerTimeNow())
				self.Fill.Size = UDim2.fromScale(left / total, 1)
				self.Count.Text = string.format("WAKING UP AT THE ENTRANCE IN %d", math.ceil(left))
				if math.floor(left * 10) % 12 == 0 then
					controllers.AudioController:Play("UI.Heartbeat", nil)
				end
				task.wait(0.1)
			end
		end)
	else
		self.Token = nil
		self.Panel.Visible = false
		self.Grade.Enabled = false
		if humanoid then
			TweenService:Create(humanoid, TweenInfo.new(0.5), { CameraOffset = Vector3.zero }):Play()
		end
		if type(info) == "table" and not info.Silent then
			if info.By then
				controllers.AudioController:Play("Interaction.Revive", nil)
				controllers.AnnouncementController:Toast("🩹 " .. info.By .. " got you back up!", Color3.fromRGB(150, 220, 170))
			elseif info.Taken then
				controllers.AnnouncementController:Toast("You wake up at the entrance. Your equipment is drained...", Color3.fromRGB(230, 150, 140), 4)
			end
		end
	end
end

return DownedController
