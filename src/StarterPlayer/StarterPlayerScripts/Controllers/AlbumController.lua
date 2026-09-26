--[[
	AlbumController (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/AlbumController

	ANOMALY ARCHIVE - the collection screen (lobby archive terminal / menu).
	  ANOMALIES  : every anomaly; undiscovered ones are "?" silhouettes
	  PHOTO ROLL : your latest photos (capacity grows with Extra Photo Roll)
	(Settings live in SettingsController.)
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Config")
local AnomalyConfig = require(Config:WaitForChild("AnomalyConfig"))
local RarityConfig = require(Config:WaitForChild("RarityConfig"))
local MonetizationConfig = require(Config:WaitForChild("MonetizationConfig"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Format = require(Modules:WaitForChild("Format"))

local AlbumController = {}
AlbumController.Tab = "ANOMALIES"
AlbumController.IsOpen = false

local player = Players.LocalPlayer

function AlbumController:Init(controllers)
	self.Controllers = controllers
	local UIKit = controllers.UIKit
	self.Gui = UIKit.GetScreenGui("AlbumUI", 10)
	self.Root = UIKit.ScaledRoot(self.Gui)

	local panel, body, tabs, subtitle = UIKit.BuildPanel(self.Root, "ANOMALY ARCHIVE", function()
		UIKit.ClosePanel("Album")
	end)
	self.Panel, self.Body, self.Tabs, self.Subtitle = panel, body, tabs, subtitle

	for order, name in ipairs({ "ANOMALIES", "PHOTO ROLL" }) do
		UIKit.TabButton(tabs, name, order, function()
			self.Tab = name
			self:Render()
		end)
	end

	UIKit.RegisterPanel("Album", function()
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
		self:_updateSubtitle()
	end)
end

function AlbumController:_updateSubtitle()
	self.Subtitle.Text = string.format("DISCOVERED: %d / %d", self.Controllers.ClientState:CountDiscovered(), AnomalyConfig.Count())
end

function AlbumController:Render()
	local UIKit = self.Controllers.UIKit
	UIKit.SetTabActive(self.Tabs, self.Tab)
	self:_updateSubtitle()
	for _, child in ipairs(self.Body:GetChildren()) do
		child:Destroy()
	end
	if self.Tab == "PHOTO ROLL" then
		self:_renderPhotoRoll()
	else
		self:_renderAnomalies()
	end
end

function AlbumController:_renderAnomalies()
	local UIKit = self.Controllers.UIKit
	local theme = UIKit.Theme
	local state = self.Controllers.ClientState
	local scroll = UIKit.Scroller(self.Body)
	UIKit.Padding(scroll, 6)
	UIKit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(150, 200),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = scroll,
	})

	for order, def in ipairs(AnomalyConfig.GetSorted()) do
		local discovery = state:GetDiscovery(def.Id)
		local tier = RarityConfig.Get(def.Rarity)
		local card = UIKit.Button({
			Name = def.Id,
			LayoutOrder = order,
			BackgroundColor3 = theme.Panel2,
			CornerRadius = 14,
			Parent = scroll,
		}, function()
			if discovery then
				self:_showDetail(def, discovery)
			end
		end)
		UIKit.Stroke(card, if discovery then tier.Color else theme.Stroke, if discovery then 3 else 1.5, if discovery then 0 else 0.4)

		local photo = UIKit.Frame({
			Name = "Photo",
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(1, -16, 0, 104),
			BackgroundColor3 = if discovery then Color3.fromRGB(16, 16, 20) else Color3.fromRGB(8, 8, 10),
			Parent = card,
		})
		UIKit.Corner(photo, 10)
		if discovery then
			UIKit.Label({ Text = def.Icon, TextScaled = true, Position = UDim2.fromScale(0.15, 0.1), Size = UDim2.fromScale(0.7, 0.8), Parent = photo })
		else
			UIKit.Label({
				Text = "?",
				Font = theme.FontBlack,
				TextScaled = true,
				TextColor3 = Color3.fromRGB(45, 45, 55),
				Position = UDim2.fromScale(0.25, 0.08),
				Size = UDim2.fromScale(0.5, 0.84),
				Parent = photo,
			})
		end

		UIKit.Label({
			Text = if discovery then def.Name else "???",
			Font = theme.FontBlack,
			TextSize = 15,
			Position = UDim2.fromOffset(6, 116),
			Size = UDim2.new(1, -12, 0, 34),
			Parent = card,
		})
		local rarityText = if tier.HideOdds and not discovery then "???" else string.upper(tier.DisplayName)
		UIKit.Label({
			Text = rarityText,
			Font = theme.FontBlack,
			TextSize = 13,
			TextColor3 = if discovery then tier.Color else theme.SubText,
			Position = UDim2.fromOffset(6, 150),
			Size = UDim2.new(1, -12, 0, 16),
			Parent = card,
		})
		UIKit.Label({
			Text = if discovery then string.format("%s  x%d", Format.Stars(discovery.BestStars or 1), discovery.Count or 1) else "NOT FOUND",
			Font = theme.Font,
			TextSize = 14,
			TextColor3 = if discovery then theme.Gold else Color3.fromRGB(90, 90, 100),
			Position = UDim2.fromOffset(6, 170),
			Size = UDim2.new(1, -12, 0, 20),
			Parent = card,
		})
	end
end

function AlbumController:_showDetail(def, discovery)
	local UIKit = self.Controllers.UIKit
	local theme = UIKit.Theme
	local tier = RarityConfig.Get(def.Rarity)
	local overlay = UIKit.Button({
		Name = "Detail",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		CornerRadius = 12,
		ZIndex = 10,
		Parent = self.Body,
	}, function() end)
	local card = UIKit.Frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 360),
		BackgroundColor3 = theme.Paper,
		ZIndex = 11,
		Parent = overlay,
	})
	UIKit.Corner(card, 14)
	UIKit.Stroke(card, tier.Color, 4, 0)
	local function text(props)
		props.ZIndex = 12
		props.Parent = card
		return UIKit.Label(props)
	end
	text({ Text = def.Icon, TextSize = 64, Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 80) })
	text({ Text = string.upper(def.Name), Font = theme.FontBlack, TextSize = 26, TextColor3 = theme.Ink, Position = UDim2.fromOffset(12, 96), Size = UDim2.new(1, -24, 0, 32) })
	text({ Text = string.upper(tier.DisplayName) .. "   " .. AnomalyConfig.GetOddsText(def.Id), Font = theme.FontBlack, TextSize = 16, TextColor3 = tier.Color, TextStrokeTransparency = 0.7, Position = UDim2.fromOffset(12, 130), Size = UDim2.new(1, -24, 0, 20) })
	text({ Text = def.Description, Font = theme.FontType, TextSize = 17, TextColor3 = Color3.fromRGB(60, 56, 52), Position = UDim2.fromOffset(24, 158), Size = UDim2.new(1, -48, 0, 70) })
	text({
		Text = string.format("BEST PHOTO %s\nPHOTOGRAPHED %d TIMES\nFIRST FOUND %s", Format.Stars(discovery.BestStars or 1), discovery.Count or 1, Format.Date(discovery.FirstFound or 0)),
		Font = theme.FontBlack,
		TextSize = 15,
		TextColor3 = theme.Ink,
		Position = UDim2.fromOffset(12, 236),
		Size = UDim2.new(1, -24, 0, 60),
	})
	local close = UIKit.Button({
		Text = "CLOSE",
		TextSize = 16,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(140, 40),
		BackgroundColor3 = theme.Ink,
		ZIndex = 12,
		Parent = card,
	}, function()
		overlay:Destroy()
	end)
	close.ZIndex = 12
end

function AlbumController:_renderPhotoRoll()
	local UIKit = self.Controllers.UIKit
	local theme = UIKit.Theme
	local state = self.Controllers.ClientState
	local data = state.Data
	local roll = data and data.PhotoRoll or {}
	local capacity = data and data.PhotoRollCapacity or 12

	local header = UIKit.Frame({ Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Parent = self.Body })
	UIKit.Label({
		Text = string.format("PHOTO ROLL  %d / %d", #roll, capacity),
		Font = theme.FontBlack,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(0.5, 0, 1, 0),
		Parent = header,
	})
	local pass = MonetizationConfig.GamePasses.ExtraAlbumStorage
	if not state:HasPass("ExtraAlbumStorage") and MonetizationConfig.IsConfigured(pass) then
		UIKit.Button({
			Text = pass.Icon .. " MORE STORAGE",
			TextSize = 15,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -4, 0.5, 0),
			Size = UDim2.fromOffset(200, 38),
			BackgroundColor3 = theme.Gold,
			TextColor3 = theme.Ink,
			Parent = header,
		}, function()
			MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		end)
	end

	local listHolder = UIKit.Frame({ Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 1, -50), BackgroundTransparency = 1, Parent = self.Body })
	local scroll = UIKit.Scroller(listHolder)
	UIKit.List(scroll, Enum.FillDirection.Vertical, 8)
	UIKit.Padding(scroll, 4)

	if #roll == 0 then
		UIKit.Label({ Text = "No photos yet. Go find something WRONG in the Dead Mall! 📸", TextColor3 = theme.SubText, Size = UDim2.new(1, 0, 0, 60), Parent = scroll })
		return
	end
	for index, entry in ipairs(roll) do
		local def = AnomalyConfig.Get(entry.Id)
		if not def then
			continue
		end
		local tier = RarityConfig.Get(def.Rarity)
		local row = UIKit.Frame({ LayoutOrder = index, Size = UDim2.new(1, -8, 0, 56), BackgroundColor3 = theme.Panel2, Parent = scroll })
		UIKit.Corner(row, 12)
		UIKit.Stroke(row, tier.Color, 1.5, 0.3)
		UIKit.Label({ Text = def.Icon, TextSize = 30, Size = UDim2.fromOffset(56, 56), Parent = row })
		UIKit.Label({
			Text = def.Name,
			Font = theme.FontBlack,
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(60, 4),
			Size = UDim2.new(0.45, -60, 0, 26),
			Parent = row,
		})
		UIKit.Label({
			Text = string.upper(tier.DisplayName),
			TextSize = 13,
			TextColor3 = tier.Color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(60, 30),
			Size = UDim2.new(0.45, -60, 0, 20),
			Parent = row,
		})
		local extras = {}
		if entry.New then
			table.insert(extras, "🆕")
		end
		if (entry.Group or 0) > 0 then
			table.insert(extras, "👥" .. tostring(entry.Group + 1))
		end
		if entry.First then
			table.insert(extras, "⚡")
		end
		UIKit.Label({
			Text = Format.Stars(entry.Stars or 1) .. "  " .. table.concat(extras, " "),
			TextSize = 18,
			TextColor3 = theme.Gold,
			Position = UDim2.fromScale(0.45, 0),
			Size = UDim2.new(0.33, 0, 1, 0),
			Parent = row,
		})
		UIKit.Label({
			Text = Format.TimeAgo(entry.Time or os.time()),
			TextSize = 14,
			TextColor3 = theme.SubText,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 0),
			Size = UDim2.new(0.2, 0, 1, 0),
			Parent = row,
		})
	end
end

return AlbumController
