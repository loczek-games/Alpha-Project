--[[
	DarkRoomController (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/DarkRoomController

	Renders a player's showcase inside the DARK ROOM: their rarest discoveries
	as framed evidence photos on the walls, a nameplate, and VIP decor.
	Rendering is local, so every visitor can browse a different player's room
	(◀ ▶) at the same time in the same physical room.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Config")
local RarityConfig = require(Config:WaitForChild("RarityConfig"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Net = require(Modules:WaitForChild("Net"))
local Format = require(Modules:WaitForChild("Format"))

local DarkRoomController = {}
DarkRoomController.Owners = {}
DarkRoomController.OwnerIndex = 1
DarkRoomController.BorderColors = {}

local player = Players.LocalPlayer

function DarkRoomController:Init(controllers)
	self.Controllers = controllers
	local UIKit = controllers.UIKit
	local theme = UIKit.Theme
	self.Remote = Net.Function("DarkRoomRequest")
	self.Gui = UIKit.GetScreenGui("DarkRoomUI", 5)
	self.Root = UIKit.ScaledRoot(self.Gui)

	self.SurfaceFolder = Instance.new("Folder")
	self.SurfaceFolder.Name = "DarkRoomSurfaces"
	self.SurfaceFolder.Parent = player:WaitForChild("PlayerGui")

	local bar = UIKit.Frame({
		Name = "DarkRoomBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.fromOffset(620, 76),
		BackgroundColor3 = Color3.fromRGB(30, 8, 10),
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = self.Root,
	})
	self.Bar = bar
	UIKit.Corner(bar, 18)
	UIKit.Stroke(bar, Color3.fromRGB(255, 70, 70), 2, 0.3)
	UIKit.Button({ Text = "◀", TextSize = 26, Position = UDim2.fromOffset(10, 12), Size = UDim2.fromOffset(52, 52), BackgroundColor3 = theme.Panel2, Parent = bar }, function()
		self:_cycle(-1)
	end)
	self.OwnerLabel = UIKit.Label({
		Text = "",
		Font = theme.FontBlack,
		TextSize = 20,
		Position = UDim2.fromOffset(70, 8),
		Size = UDim2.new(1, -270, 0, 32),
		Parent = bar,
	})
	self.CountLabel = UIKit.Label({
		Text = "",
		TextSize = 14,
		TextColor3 = theme.SubText,
		Position = UDim2.fromOffset(70, 40),
		Size = UDim2.new(1, -270, 0, 24),
		Parent = bar,
	})
	UIKit.Button({ Text = "▶", TextSize = 26, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -130, 0, 12), Size = UDim2.fromOffset(52, 52), BackgroundColor3 = theme.Panel2, Parent = bar }, function()
		self:_cycle(1)
	end)
	UIKit.Button({ Text = "EXIT", TextSize = 18, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(106, 52), BackgroundColor3 = theme.Accent, Parent = bar }, function()
		pcall(function()
			self.Remote:InvokeServer("Leave")
		end)
	end)

	controllers.ClientState.DarkRoomChanged:Connect(function(inside)
		if inside then
			self:_enter()
		else
			self:_leave()
		end
	end)
end

function DarkRoomController:_enter()
	self.Bar.Visible = true
	local ok, owners = pcall(function()
		return self.Remote:InvokeServer("ListOwners")
	end)
	self.Owners = if ok and type(owners) == "table" then owners else { { UserId = player.UserId, Name = player.DisplayName } }
	self.OwnerIndex = 1
	for index, owner in ipairs(self.Owners) do
		if owner.UserId == player.UserId then
			self.OwnerIndex = index
		end
	end
	self:_show()
end

function DarkRoomController:_leave()
	self.Bar.Visible = false
	self.SurfaceFolder:ClearAllChildren()
	self:_applyVip(false)
end

function DarkRoomController:_cycle(direction: number)
	if #self.Owners == 0 then
		return
	end
	-- refresh the list in case players joined/left
	local ok, owners = pcall(function()
		return self.Remote:InvokeServer("ListOwners")
	end)
	if ok and type(owners) == "table" and #owners > 0 then
		local currentId = self.Owners[self.OwnerIndex] and self.Owners[self.OwnerIndex].UserId
		self.Owners = owners
		self.OwnerIndex = 1
		for index, owner in ipairs(owners) do
			if owner.UserId == currentId then
				self.OwnerIndex = index
			end
		end
	end
	self.OwnerIndex = ((self.OwnerIndex - 1 + direction) % #self.Owners) + 1
	self:_show()
end

function DarkRoomController:_show()
	local owner = self.Owners[self.OwnerIndex]
	if not owner then
		return
	end
	local ok, showcase = pcall(function()
		return self.Remote:InvokeServer("GetShowcase", owner.UserId)
	end)
	if not ok or type(showcase) ~= "table" then
		self.OwnerLabel.Text = "Could not load this Dark Room"
		return
	end
	self.OwnerLabel.Text = string.upper(showcase.Name) .. "'S DARK ROOM" .. (if showcase.VIP then "  ⭐" else "")
	self.CountLabel.Text = string.format("%d / %d discovered  ·  %d / %d visitors browsing", showcase.Discovered, showcase.Total, self.OwnerIndex, #self.Owners)
	self:_render(showcase)
end

function DarkRoomController:_frameCard(canvas: BasePart, entry, locked: boolean, vip: boolean)
	local UIKit = self.Controllers.UIKit
	local theme = UIKit.Theme
	local gui = UIKit.new("SurfaceGui", {
		Name = "Frame" .. tostring(canvas:GetAttribute("Index")),
		Adornee = canvas,
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		CanvasSize = Vector2.new(310, 240),
		LightInfluence = 0.15,
		Parent = self.SurfaceFolder,
	})
	if locked then
		local frame = UIKit.Frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(14, 12, 12), Parent = gui })
		UIKit.Label({ Text = "🔒\nBIGGER DARK ROOM", Font = theme.FontBlack, TextSize = 26, TextColor3 = Color3.fromRGB(120, 110, 100), Parent = frame })
		return
	end
	if not entry then
		local frame = UIKit.Frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(20, 18, 18), Parent = gui })
		UIKit.Label({ Text = "EMPTY FRAME\nkeep exploring...", Font = theme.FontType, TextSize = 26, TextColor3 = Color3.fromRGB(110, 100, 95), Parent = frame })
		return
	end
	local tier = RarityConfig.Get(entry.Rarity)
	local paper = UIKit.Frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = if vip then Color3.fromRGB(255, 245, 215) else theme.Paper, Parent = gui })
	local strip = UIKit.Frame({ Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = tier.Color, Parent = paper })
	UIKit.Label({ Text = string.upper(tier.DisplayName) .. "  ·  " .. entry.Odds, Font = theme.FontBlack, TextSize = 18, TextColor3 = theme.Ink, Parent = strip })
	local photo = UIKit.Frame({ Position = UDim2.fromOffset(12, 38), Size = UDim2.new(1, -24, 0, 110), BackgroundColor3 = Color3.fromRGB(16, 16, 20), Parent = paper })
	UIKit.Label({ Text = entry.Icon, TextSize = 80, Parent = photo })
	UIKit.Label({ Text = string.upper(entry.Name), Font = theme.FontBlack, TextSize = 24, TextColor3 = theme.Ink, Position = UDim2.fromOffset(8, 150), Size = UDim2.new(1, -16, 0, 30), Parent = paper })
	UIKit.Label({
		Text = string.format("%s   x%d   %s", Format.Stars(entry.Stars), entry.Count, Format.Date(entry.FirstFound)),
		Font = theme.FontType,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(90, 80, 70),
		Position = UDim2.fromOffset(8, 184),
		Size = UDim2.new(1, -16, 0, 40),
		Parent = paper,
	})
end

function DarkRoomController:_render(showcase, attempt: number?)
	self.SurfaceFolder:ClearAllChildren()
	local frames = CollectionService:GetTagged("DarkRoomFrame")
	if #frames == 0 and (attempt or 0) < 5 then
		-- frames may still be streaming in right after the teleport
		task.delay(0.6, function()
			if self.Bar.Visible then
				self:_render(showcase, (attempt or 0) + 1)
			end
		end)
		return
	end
	for _, canvas in ipairs(frames) do
		if canvas:IsA("BasePart") then
			local index = canvas:GetAttribute("Index") or 0
			local locked = index > showcase.Frames
			self:_frameCard(canvas, showcase.Entries[index], locked, showcase.VIP)
		end
	end
	for _, nameplate in ipairs(CollectionService:GetTagged("DarkRoomNameplate")) do
		if nameplate:IsA("BasePart") then
			local UIKit = self.Controllers.UIKit
			local gui = UIKit.new("SurfaceGui", {
				Name = "Nameplate",
				Adornee = nameplate,
				Face = Enum.NormalId.Front,
				SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
				PixelsPerStud = 30,
				LightInfluence = 0,
				Parent = self.SurfaceFolder,
			})
			UIKit.Label({
				Text = (if showcase.VIP then "⭐ " else "") .. string.upper(showcase.Name) .. "'S DARK ROOM",
				Font = UIKit.Theme.FontBlack,
				TextScaled = true,
				TextColor3 = if showcase.VIP then UIKit.Theme.Gold else Color3.fromRGB(255, 90, 90),
				Parent = gui,
			})
		end
	end
	self:_applyVip(showcase.VIP == true)
end

-- VIP owners get gold frames (local-only colour change on the frame borders).
function DarkRoomController:_applyVip(vip: boolean)
	local lobby = workspace:FindFirstChild("Lobby")
	local room = lobby and lobby:FindFirstChild("DarkRoom", true)
	if not room then
		return
	end
	for _, part in ipairs(room:GetDescendants()) do
		if part:IsA("BasePart") and part.Name == "FrameBorder" then
			if not self.BorderColors[part] then
				self.BorderColors[part] = { Color = part.Color, Material = part.Material }
			end
			local original = self.BorderColors[part]
			part.Color = if vip then Color3.fromRGB(255, 200, 60) else original.Color
			part.Material = if vip then Enum.Material.Metal else original.Material
		end
	end
end

return DarkRoomController
