--[[
	ShopController (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/ShopController

	The SHOP panel. Opened by the physical terminals at HQ (equipment
	counter, camera lab, flashlight bench, supply store) and by the menu:
	  EQUIPMENT  : cameras + Thermal Scanner, UV Light, Night Vision (Evidence)
	  CAMERA LAB : Zoom Lens, Steady Grip, Sixth Sense, Silent Shutter
	  FLASHLIGHT : Wide Reflector, Lithium Cells, Shielded Wiring
	  SKINS      : camera / flashlight / EMF skins + Dark Room decorations
	  STORE      : Robux - PRO CAMERA, TACTICAL FLASHLIGHT, INVESTIGATOR PACK,
	               VIP INVESTIGATOR, REVIVE, PARANORMAL SURGE, ...
	The game is fully playable without purchases. Every request is validated
	by the server (EconomyService / MonetizationService).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Config")
local CameraConfig = require(Config:WaitForChild("CameraConfig"))
local EquipmentConfig = require(Config:WaitForChild("EquipmentConfig"))
local MonetizationConfig = require(Config:WaitForChild("MonetizationConfig"))
local CosmeticsConfig = require(Config:WaitForChild("CosmeticsConfig"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Net = require(Modules:WaitForChild("Net"))
local Format = require(Modules:WaitForChild("Format"))

local ShopController = {}
ShopController.Tab = "EQUIPMENT"
ShopController.IsOpen = false

local player = Players.LocalPlayer

function ShopController:Init(controllers)
	self.Controllers = controllers
	local UIKit = controllers.UIKit
	self.Gui = UIKit.GetScreenGui("ShopUI", 10)
	self.Root = UIKit.ScaledRoot(self.Gui)
	self.ShopRemote = Net.Function("ShopRequest")

	local panel, body, tabs, subtitle = UIKit.BuildPanel(self.Root, "FIELD SUPPLY", function()
		UIKit.ClosePanel("Shop")
	end)
	self.Panel, self.Body, self.Tabs, self.Subtitle = panel, body, tabs, subtitle
	subtitle.TextColor3 = UIKit.Theme.Evidence

	for order, name in ipairs({ "EQUIPMENT", "CAMERA LAB", "FLASHLIGHT", "SKINS", "STORE" }) do
		UIKit.TabButton(tabs, name, order, function()
			self.Tab = name
			self:Render()
		end)
	end

	UIKit.RegisterPanel("Shop", function()
		self.IsOpen = true
		self:Render()
		UIKit.AnimatePanel(panel, true)
	end, function()
		self.IsOpen = false
		UIKit.AnimatePanel(panel, false)
	end)

	controllers.ClientState.DataChanged:Connect(function()
		if self.IsOpen then
			self:Render()
		end
	end)
end

function ShopController:OpenTab(tab: string)
	self.Tab = tab
	local UIKit = self.Controllers.UIKit
	if UIKit.OpenPanelName == "Shop" then
		self:Render()
	else
		UIKit.OpenPanel("Shop")
	end
end

function ShopController:_request(action: string, id: string)
	local ok, success, message = pcall(function()
		return self.ShopRemote:InvokeServer(action, id)
	end)
	local announcements = self.Controllers.AnnouncementController
	local audio = self.Controllers.AudioController
	if not ok then
		audio:Play("UI.Error", nil)
		announcements:Toast("Shop is busy, try again.", Color3.fromRGB(255, 120, 120))
		return
	end
	if success and (string.sub(action, 1, 3) == "Buy") then
		audio:Play(if action == "BuyUpgrade" then "Interaction.Upgrade" else "Interaction.Purchase", nil)
	elseif not success then
		audio:Play("UI.Error", nil)
	end
	announcements:Toast(message or (success and "Done!" or "Could not do that"), if success then Color3.fromRGB(120, 230, 140) else Color3.fromRGB(255, 120, 120))
end

function ShopController:Render()
	local UIKit = self.Controllers.UIKit
	UIKit.SetTabActive(self.Tabs, self.Tab)
	local data = self.Controllers.ClientState.Data
	self.Subtitle.Text = "EVIDENCE " .. Format.Money(data and data.Evidence or 0)
	for _, child in ipairs(self.Body:GetChildren()) do
		child:Destroy()
	end
	local scroll = UIKit.Scroller(self.Body)
	UIKit.List(scroll, Enum.FillDirection.Vertical, 10)
	UIKit.Padding(scroll, 6)
	if self.Tab == "CAMERA LAB" then
		self:_renderUpgrades(scroll)
	elseif self.Tab == "FLASHLIGHT" then
		self:_renderFlashlight(scroll)
	elseif self.Tab == "SKINS" then
		self:_renderSkins(scroll)
	elseif self.Tab == "STORE" then
		self:_renderStore(scroll)
	else
		self:_renderCameras(scroll, 0)
		self:_renderEquipment(scroll, 100)
	end
end

-- Shared row layout: icon | title + description | action button(s)
function ShopController:_row(parent: Instance, order: number, icon: string, title: string, description: string, accent: Color3?)
	local UIKit = self.Controllers.UIKit
	local theme = UIKit.Theme
	local row = UIKit.Card({ LayoutOrder = order, Size = UDim2.new(1, -12, 0, 92), Parent = parent })
	if accent then
		local stroke = row:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = accent
			stroke.Transparency = 0
		end
	end
	UIKit.Label({ Text = icon, TextSize = 40, Size = UDim2.fromOffset(84, 92), Parent = row })
	UIKit.Label({
		Text = title,
		Font = theme.FontType,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(84, 10),
		Size = UDim2.new(1, -330, 0, 26),
		Parent = row,
	})
	UIKit.Label({
		Text = description,
		TextSize = 14,
		TextColor3 = theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(84, 38),
		Size = UDim2.new(1, -330, 0, 48),
		Parent = row,
	})
	local actions = UIKit.Frame({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(230, 76),
		BackgroundTransparency = 1,
		Parent = row,
	})
	UIKit.List(actions, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	return row, actions
end

function ShopController:_actionButton(parent: Instance, order: number, text: string, color: Color3, enabled: boolean, callback: (() -> ())?)
	local UIKit = self.Controllers.UIKit
	local theme = UIKit.Theme
	local button = UIKit.Button({
		LayoutOrder = order,
		Text = text,
		TextSize = 15,
		Size = UDim2.fromOffset(220, 34),
		BackgroundColor3 = if enabled then color else theme.Panel3,
		TextColor3 = if enabled and (color == theme.Gold or color == theme.Good or color == theme.Evidence) then theme.Ink else theme.Text,
		AutoButtonColor = false,
		Parent = parent,
	}, if enabled then callback else nil)
	return button
end

function ShopController:_renderCameras(scroll: Instance, orderBase: number?)
	local UIKit = self.Controllers.UIKit
	local theme = UIKit.Theme
	local state = self.Controllers.ClientState
	local data = state.Data
	local equipped = state:GetEquippedCameraId()
	for index, camera in ipairs(CameraConfig.GetSorted()) do
		local order = (orderBase or 0) + index
		local owned = data and data.OwnedCameras and data.OwnedCameras[camera.Id] == true
		local description = string.format("%s\nCooldown %.2fs", camera.Description, camera.Cooldown)
		local _, actions = self:_row(scroll, order, camera.Icon, camera.Name, description, if camera.Id == equipped then theme.Gold else nil)
		if not camera.Implemented then
			self:_actionButton(actions, 1, "COMING SOON", theme.Panel3, false)
		elseif camera.Id == equipped then
			self:_actionButton(actions, 1, "EQUIPPED ✓", theme.Good, false)
		elseif owned then
			self:_actionButton(actions, 1, "EQUIP", theme.Good, true, function()
				self:_request("EquipCamera", camera.Id)
			end)
		else
			local affordable = data and data.Evidence >= camera.Price
			self:_actionButton(actions, 1, "BUY " .. Format.Money(camera.Price), theme.Evidence, affordable == true, function()
				self:_request("BuyCamera", camera.Id)
			end)
			local pass = camera.GamePass and MonetizationConfig.GamePasses[camera.GamePass]
			if pass and MonetizationConfig.IsConfigured(pass) then
				self:_actionButton(actions, 2, pass.Icon .. " GAME PASS", theme.Gold, true, function()
					MarketplaceService:PromptGamePassPurchase(player, pass.Id)
				end)
			end
		end
	end
end

function ShopController:_renderUpgrades(scroll: Instance)
	local UIKit = self.Controllers.UIKit
	local theme = UIKit.Theme
	local data = self.Controllers.ClientState.Data
	for order, upgrade in ipairs(CameraConfig.GetSortedUpgrades()) do
		local level = data and data.Upgrades and data.Upgrades[upgrade.Id] or 0
		local pips = string.rep("■", level) .. string.rep("□", upgrade.MaxLevel - level)
		local _, actions = self:_row(scroll, order, upgrade.Icon, string.format("%s  %s", upgrade.Name, pips), upgrade.Description)
		if level >= upgrade.MaxLevel then
			self:_actionButton(actions, 1, "MAXED ✓", theme.Good, false)
		else
			local price = upgrade.Prices[level + 1]
			local affordable = data and data.Evidence >= price
			self:_actionButton(actions, 1, string.format("LV %d  %s", level + 1, Format.Money(price)), theme.Evidence, affordable == true, function()
				self:_request("BuyUpgrade", upgrade.Id)
			end)
		end
	end
end

function ShopController:_renderEquipment(scroll: Instance, orderBase: number?)
	local UIKit = self.Controllers.UIKit
	local theme = UIKit.Theme
	local data = self.Controllers.ClientState.Data
	for index, item in ipairs(EquipmentConfig.GetSorted()) do
		local order = (orderBase or 0) + index
		local owned = item.Price == 0 or (data and data.OwnedEquipment and data.OwnedEquipment[item.Id] == true)
		local keyHint = if item.Wearable then "wearable" else string.format("key %d", item.Order)
		local _, actions = self:_row(scroll, order, item.Icon, item.Name, string.format("%s\n%s · 🔋 battery powered", item.Description, keyHint))
		if owned then
			self:_actionButton(actions, 1, "OWNED ✓", theme.Good, false)
		else
			local affordable = data and data.Evidence >= item.Price
			self:_actionButton(actions, 1, "BUY " .. Format.Money(item.Price), theme.Evidence, affordable == true, function()
				self:_request("BuyEquipment", item.Id)
			end)
		end
	end
end

function ShopController:_renderFlashlight(scroll: Instance)
	local UIKit = self.Controllers.UIKit
	local theme = UIKit.Theme
	local state = self.Controllers.ClientState
	local data = state.Data
	local list = {}
	for id, def in pairs(EquipmentConfig.FlashlightUpgrades) do
		table.insert(list, { Id = id, Def = def })
	end
	table.sort(list, function(a, b)
		return a.Def.Order < b.Def.Order
	end)
	for order, entry in ipairs(list) do
		local upgrade = entry.Def
		local level = data and data.FlashlightUpgrades and data.FlashlightUpgrades[entry.Id] or 0
		local pips = string.rep("■", level) .. string.rep("□", upgrade.MaxLevel - level)
		local _, actions = self:_row(scroll, order, upgrade.Icon, string.format("%s  %s", upgrade.Name, pips), upgrade.Description)
		if level >= upgrade.MaxLevel then
			self:_actionButton(actions, 1, "MAXED ✓", theme.Good, false)
		else
			local price = upgrade.Prices[level + 1]
			local affordable = data and data.Evidence >= price
			self:_actionButton(actions, 1, string.format("LV %d  %s", level + 1, Format.Money(price)), theme.Evidence, affordable == true, function()
				self:_request("BuyFlashlightUpgrade", entry.Id)
			end)
		end
	end
	local pass = MonetizationConfig.GamePasses.TacticalFlashlight
	local _, actions = self:_row(scroll, 10, pass.Icon, pass.Name, pass.Description, theme.Gold)
	if state:HasPass("TacticalFlashlight") then
		self:_actionButton(actions, 1, "OWNED ✓", theme.Good, false)
	elseif MonetizationConfig.IsConfigured(pass) then
		self:_actionButton(actions, 1, "BUY WITH ROBUX", theme.Gold, true, function()
			MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		end)
	else
		self:_actionButton(actions, 1, "UNAVAILABLE", theme.Panel3, false)
	end
end

-- equipment skins + dark room decorations
function ShopController:_renderSkins(scroll: Instance)
	local UIKit = self.Controllers.UIKit
	local theme = UIKit.Theme
	local data = self.Controllers.ClientState.Data
	local cosmetics = data and data.Cosmetics or { Owned = {}, Equipped = {} }
	local order = 0
	local function section(text: string)
		order += 1
		UIKit.Label({ LayoutOrder = order, Text = text, Font = theme.FontType, TextSize = 18, TextColor3 = theme.Gold, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -12, 0, 28), Parent = scroll })
	end
	local function offer(actions: Instance, cosmeticId: string, passKey: string?)
		local product = MonetizationConfig.GetProductForCosmetic(cosmeticId)
		if passKey then
			local pass = MonetizationConfig.GamePasses[passKey]
			if pass and MonetizationConfig.IsConfigured(pass) then
				self:_actionButton(actions, 1, pass.Name, theme.Gold, true, function()
					MarketplaceService:PromptGamePassPurchase(player, pass.Id)
				end)
				return
			end
		elseif product and MonetizationConfig.IsConfigured(product) then
			self:_actionButton(actions, 1, "BUY WITH ROBUX", theme.Gold, true, function()
				MarketplaceService:PromptProductPurchase(player, product.Id)
			end)
			return
		end
		self:_actionButton(actions, 1, "UNAVAILABLE", theme.Panel3, false)
	end
	for _, item in ipairs({ "Camera", "Flashlight", "EMF" }) do
		section(string.upper(item) .. " SKINS")
		for _, skin in ipairs(CosmeticsConfig.SkinsFor(item)) do
			order += 1
			local owned = cosmetics.Owned[skin.Id] == true
			local equipped = cosmetics.Equipped[item] == skin.Id
			local row, actions = self:_row(scroll, order, "", skin.Name, if skin.Pass then "Included in " .. MonetizationConfig.GamePasses[skin.Pass].Name else (if skin.Free then "Standard issue." else "Cosmetic only."), if equipped then theme.Gold else nil)
			-- colour swatch instead of an icon
			local swatch = UIKit.Frame({ Position = UDim2.fromOffset(18, 20), Size = UDim2.fromOffset(52, 52), BackgroundColor3 = skin.Body, Parent = row })
			UIKit.Frame({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = skin.Trim, Parent = swatch })
			if equipped then
				self:_actionButton(actions, 1, "EQUIPPED ✓", theme.Good, false)
			elseif owned then
				self:_actionButton(actions, 1, "EQUIP", theme.Good, true, function()
					self:_request("EquipSkin", skin.Id)
				end)
			else
				offer(actions, skin.Id, skin.Pass)
			end
		end
	end
	section("DARK ROOM DECORATIONS")
	local decorList = {}
	for _, decor in pairs(CosmeticsConfig.Decor) do
		table.insert(decorList, decor)
	end
	table.sort(decorList, function(a, b)
		return a.Name < b.Name
	end)
	for _, decor in ipairs(decorList) do
		order += 1
		local owned = cosmetics.Owned[decor.Id] == true
		local active = cosmetics.Decor == decor.Id
		local _, actions = self:_row(scroll, order, "🖼", decor.Name, decor.Description, if active then theme.Gold else nil)
		if active then
			self:_actionButton(actions, 1, "ACTIVE ✓", theme.Good, false)
		elseif owned then
			self:_actionButton(actions, 1, "SET UP", theme.Good, true, function()
				self:_request("EquipDecor", decor.Id)
			end)
		else
			offer(actions, decor.Id, decor.Pass)
		end
	end
end

function ShopController:_renderStore(scroll: Instance)
	local UIKit = self.Controllers.UIKit
	local theme = UIKit.Theme
	local state = self.Controllers.ClientState
	local order = 0
	local function section(text: string)
		order += 1
		UIKit.Label({
			LayoutOrder = order,
			Text = text,
			Font = theme.FontBlack,
			TextSize = 18,
			TextColor3 = theme.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -12, 0, 28),
			Parent = scroll,
		})
	end

	section("GAME PASSES")
	for _, pass in ipairs(MonetizationConfig.GetSortedPasses()) do
		order += 1
		local _, actions = self:_row(scroll, order, pass.Icon, pass.Name, pass.Description)
		if state:HasPass(pass.Key) then
			self:_actionButton(actions, 1, "OWNED ✓", theme.Good, false)
		elseif MonetizationConfig.IsConfigured(pass) then
			self:_actionButton(actions, 1, "BUY WITH ROBUX", theme.Gold, true, function()
				MarketplaceService:PromptGamePassPurchase(player, pass.Id)
			end)
		else
			self:_actionButton(actions, 1, "UNAVAILABLE", theme.Panel3, false)
		end
	end

	section("REVIVES, EVENTS & EVIDENCE")
	for _, product in ipairs(MonetizationConfig.GetSortedProducts()) do
		order += 1
		local description = product.Description
		if product.Kind == "ServerEvent" then
			description ..= "\nEveryone in the server benefits!"
		end
		local _, actions = self:_row(scroll, order, product.Icon, product.Name, description)
		if MonetizationConfig.IsConfigured(product) then
			self:_actionButton(actions, 1, "BUY WITH ROBUX", theme.Gold, true, function()
				MarketplaceService:PromptProductPurchase(player, product.Id)
			end)
		else
			self:_actionButton(actions, 1, "UNAVAILABLE", theme.Panel3, false)
		end
	end
end

return ShopController
