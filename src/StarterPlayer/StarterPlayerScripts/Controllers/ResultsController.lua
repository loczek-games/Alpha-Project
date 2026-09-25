--[[
	ResultsController (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/ResultsController

	End-of-round EVIDENCE REPORT: several award cards (Most Evidence, Rarest
	Discovery, Best Photo, Most Photos Taken, ...) plus a personal summary
	with highlights, so many players leave the round feeling successful.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Net = require(Modules:WaitForChild("Net"))
local Format = require(Modules:WaitForChild("Format"))

local ResultsController = {}

function ResultsController:Init(controllers)
	self.Controllers = controllers
	local UIKit = controllers.UIKit
	self.Gui = UIKit.GetScreenGui("ResultsUI", 20)
	self.Root = UIKit.ScaledRoot(self.Gui)

	Net.Event("RoundResults").OnClientEvent:Connect(function(results)
		if type(results) == "table" then
			self:Show(results)
		end
	end)
	controllers.ClientState.RoundChanged:Connect(function(round)
		if round.State == "Round" then
			self:Hide()
		end
	end)
end

function ResultsController:Hide()
	if self.Panel then
		self.Panel:Destroy()
		self.Panel = nil
	end
end

function ResultsController:Show(results)
	local UIKit = self.Controllers.UIKit
	local theme = UIKit.Theme
	self:Hide()
	UIKit.ClosePanel(UIKit.OpenPanelName or "")

	local panel = UIKit.Frame({
		Name = "Results",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.94, 0.86),
		BackgroundColor3 = theme.Bg,
		BackgroundTransparency = 0.04,
		Parent = self.Root,
	})
	self.Panel = panel
	UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(1000, 660), Parent = panel })
	UIKit.Corner(panel, 18)
	UIKit.Stroke(panel, theme.Gold, 2, 0.2)

	UIKit.Label({
		Text = string.format("📁 EVIDENCE REPORT — ROUND %d", results.RoundNumber or 0),
		Font = theme.FontBlack,
		TextSize = 28,
		Position = UDim2.fromOffset(20, 10),
		Size = UDim2.new(1, -100, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	UIKit.Button({
		Text = "✕",
		TextSize = 24,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = theme.Accent,
		Parent = panel,
	}, function()
		self:Hide()
	end)

	local awardsFrame = UIKit.Frame({
		Position = UDim2.fromOffset(16, 62),
		Size = UDim2.new(1, -32, 0.56, -62),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	UIKit.new("UIGridLayout", {
		CellSize = UDim2.new(0.32, 0, 0.47, 0),
		CellPadding = UDim2.new(0.02, 0, 0.04, 0),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = awardsFrame,
	})
	local awards = results.Awards or {}
	if #awards == 0 then
		UIKit.Label({ Text = "Nobody filed any evidence this round... the mall keeps its secrets. 👁️", TextColor3 = theme.SubText, Parent = awardsFrame })
	end
	for index, award in ipairs(awards) do
		local color = award.Color or theme.Gold
		local card = UIKit.Frame({ LayoutOrder = index, BackgroundColor3 = theme.Panel2, Parent = awardsFrame })
		UIKit.Corner(card, 14)
		UIKit.Stroke(card, color, 2, 0.1)
		UIKit.Label({ Text = award.Icon or "🏆", TextScaled = true, Size = UDim2.fromScale(0.26, 0.6), Position = UDim2.fromScale(0.02, 0.2), Parent = card })
		UIKit.Label({
			Text = award.Title,
			Font = theme.FontBlack,
			TextScaled = true,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromScale(0.3, 0.08),
			Size = UDim2.fromScale(0.66, 0.24),
			Parent = card,
		})
		UIKit.Label({
			Text = award.Winner or "",
			Font = theme.FontBlack,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromScale(0.3, 0.36),
			Size = UDim2.fromScale(0.66, 0.28),
			Parent = card,
		})
		UIKit.Label({
			Text = award.Value or "",
			Font = theme.Font,
			TextScaled = true,
			TextColor3 = theme.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromScale(0.3, 0.68),
			Size = UDim2.fromScale(0.66, 0.22),
			Parent = card,
		})
	end

	local personal = results.Personal
	local mine = UIKit.Frame({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(1, -32, 0.42, -16),
		BackgroundColor3 = theme.Paper,
		Parent = panel,
	})
	UIKit.Corner(mine, 14)
	UIKit.Label({
		Text = "YOUR ROUND",
		Font = theme.FontBlack,
		TextSize = 20,
		TextColor3 = theme.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(18, 8),
		Size = UDim2.new(1, -36, 0, 26),
		Parent = mine,
	})
	if not personal then
		UIKit.Label({ Text = "You joined after the round - catch the next one!", TextColor3 = theme.Ink, Position = UDim2.fromOffset(18, 40), Size = UDim2.new(1, -36, 0, 30), Parent = mine })
		return
	end
	local stats = {
		{ "EVIDENCE", "+" .. Format.Money(personal.Evidence or 0) },
		{ "PHOTOS", tostring(personal.Captures or 0) },
		{ "NEW", tostring(personal.NewDiscoveries or 0) },
		{ "BEST", if (personal.BestStars or 0) > 0 then Format.Stars(personal.BestStars) else "-" },
	}
	local statRow = UIKit.Frame({ Position = UDim2.fromOffset(12, 38), Size = UDim2.new(1, -24, 0, 56), BackgroundTransparency = 1, Parent = mine })
	UIKit.new("UIGridLayout", { CellSize = UDim2.new(0.24, 0, 1, 0), CellPadding = UDim2.new(0.013, 0, 0, 0), Parent = statRow })
	for _, stat in ipairs(stats) do
		local cell = UIKit.Frame({ BackgroundColor3 = Color3.fromRGB(230, 224, 210), Parent = statRow })
		UIKit.Corner(cell, 10)
		UIKit.Label({ Text = stat[1], Font = theme.FontBlack, TextSize = 12, TextColor3 = Color3.fromRGB(110, 100, 90), Size = UDim2.new(1, 0, 0.4, 0), Parent = cell })
		UIKit.Label({ Text = stat[2], Font = theme.FontBlack, TextScaled = true, TextColor3 = theme.Ink, Position = UDim2.fromScale(0.05, 0.38), Size = UDim2.fromScale(0.9, 0.56), Parent = cell })
	end
	local highlights = UIKit.Label({
		Text = table.concat(personal.Highlights or {}, "\n"),
		Font = theme.Font,
		TextSize = 17,
		TextColor3 = theme.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(18, 102),
		Size = UDim2.new(1, -36, 1, -108),
		Parent = mine,
	})
	highlights.TextScaled = false

	local scale = UIKit.new("UIScale", { Scale = 0.85, Parent = panel })
	UIKit.Tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
end

return ResultsController
