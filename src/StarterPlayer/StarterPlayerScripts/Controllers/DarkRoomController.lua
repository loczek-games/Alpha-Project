--[[
	DarkRoomController (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/DarkRoomController

	Renders a player's showcase inside the DARK ROOM: their rarest discoveries
	as framed evidence photos on the walls, a nameplate, VIP gold frames and
	the owner's purchased decor theme (safelight colour + props, see
	CosmeticsConfig.Decor).
	Rendering is local, so every visitor can browse a different player's room
	(◀ ▶) at the same time in the same physical room.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Config")
local RarityConfig = require(Config:WaitForChild("RarityConfig"))
local CosmeticsConfig = require(Config:WaitForChild("CosmeticsConfig"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Net = require(Modules:WaitForChild("Net"))
local Format = require(Modules:WaitForChild("Format"))

local DarkRoomController = {}
DarkRoomController.Owners = {}
DarkRoomController.OwnerIndex = 1
DarkRoomController.BorderColors = {}
DarkRoomController.DecorId = nil

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
	self:_applyDecor(nil)
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
	local decor = CosmeticsConfig.Decor[showcase.Decor or "Classic"] or CosmeticsConfig.Decor.Classic
	self:_applyVip(showcase.VIP == true or table.find(decor.Props, "GoldFrames") ~= nil)
	self:_applyDecor(decor.Id)
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

---------------------------------------------------------------------------
-- Decor (local only: each visitor sees the room of the owner they browse)
---------------------------------------------------------------------------

local function decoPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Shape = shape or Enum.PartType.Block
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function glow(part: BasePart, color: Color3, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = part
end

local function label(part: BasePart, face: Enum.NormalId, text: string, color: Color3, background: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	gui.Parent = part
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = if background then 0 else 1
	textLabel.BackgroundColor3 = background or Color3.new()
	textLabel.Text = text
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBlack
	textLabel.TextColor3 = color
	textLabel.Parent = gui
end

local DECOR_PROPS = {}

function DECOR_PROPS.Tape(folder: Folder, base: CFrame)
	local yellow = Color3.fromRGB(250, 205, 20)
	for _, spec in ipairs({ { 11.2, 5.2, 6 }, { 11.2, 7.4, -5 }, { -12.2, 9.4, 4 } }) do
		local strip = decoPart(folder, "CrimeTape", Vector3.new(34, 0.9, 0.06), base * CFrame.new(0, spec[2], spec[1]) * CFrame.Angles(0, 0, math.rad(spec[3])), yellow)
		label(strip, Enum.NormalId.Front, "CRIME SCENE · DO NOT CROSS · CRIME SCENE · DO NOT CROSS", Color3.new(0.05, 0.05, 0.05))
		label(strip, Enum.NormalId.Back, "CRIME SCENE · DO NOT CROSS · CRIME SCENE · DO NOT CROSS", Color3.new(0.05, 0.05, 0.05))
	end
end

function DECOR_PROPS.Markers(folder: Folder, base: CFrame)
	for index, spot in ipairs({ { -12, 2 }, { -6, 9 }, { 6, 2 }, { 12, 9 }, { 0, -6 } }) do
		local tent = decoPart(folder, "EvidenceMarker", Vector3.new(0.9, 0.9, 0.7), base * CFrame.new(spot[1], 0.45, spot[2]) * CFrame.Angles(0, math.rad(index * 37), 0), Color3.fromRGB(250, 200, 20))
		label(tent, Enum.NormalId.Front, tostring(index), Color3.new(0.05, 0.05, 0.05))
		label(tent, Enum.NormalId.Back, tostring(index), Color3.new(0.05, 0.05, 0.05))
	end
end

function DECOR_PROPS.Circle(folder: Folder, base: CFrame)
	local center = base * CFrame.new(0, 0.03, 2)
	local radius = 5
	local segments = 28
	local length = 2 * math.pi * radius / segments + 0.1
	for index = 1, segments do
		local angle = index / segments * math.pi * 2
		decoPart(folder, "Chalk", Vector3.new(length, 0.04, 0.18), center * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, radius), Color3.fromRGB(235, 232, 225), Enum.Material.Neon).Transparency = 0.35
	end
	-- five-pointed star inside
	for index = 0, 4 do
		local a = math.rad(90 + index * 144)
		local b = math.rad(90 + (index + 2) * 144)
		local from = center * Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		local to = center * Vector3.new(math.cos(b) * radius, 0, math.sin(b) * radius)
		local line = decoPart(folder, "Chalk", Vector3.new(0.14, 0.04, (to - from).Magnitude), CFrame.lookAt((from + to) / 2, to), Color3.fromRGB(235, 232, 225), Enum.Material.Neon)
		line.Transparency = 0.45
	end
end

function DECOR_PROPS.Candles(folder: Folder, base: CFrame)
	local spots = {}
	for index = 0, 4 do
		local a = math.rad(90 + index * 72)
		table.insert(spots, CFrame.new(math.cos(a) * 5.8, 0, 2 + math.sin(a) * 5.8))
	end
	table.insert(spots, CFrame.new(-4, 3.2, -10))
	table.insert(spots, CFrame.new(-3.2, 3.2, -10.6))
	table.insert(spots, CFrame.new(4.5, 3.2, -10.3))
	for index, offset in ipairs(spots) do
		local height = 0.8 + (index % 3) * 0.35
		local candle = decoPart(folder, "Candle", Vector3.new(height, 0.35, 0.35), base * offset * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(230, 220, 200), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		local flame = decoPart(folder, "Flame", Vector3.new(0.14, 0.3, 0.14), candle.CFrame * CFrame.Angles(0, 0, math.rad(-90)) * CFrame.new(0, height / 2 + 0.16, 0), Color3.fromRGB(255, 170, 70), Enum.Material.Neon)
		glow(flame, Color3.fromRGB(255, 150, 60), 0.9, 7)
	end
end

function DECOR_PROPS.Monitors(folder: Folder, base: CFrame)
	local green = Color3.fromRGB(80, 255, 140)
	local camera = 1
	for row = 0, 1 do
		for column = 0, 3 do
			local cf = base * CFrame.new(18.4, 4.2 + row * 3, -6 + column * 4) * CFrame.Angles(0, math.rad(90), 0)
			decoPart(folder, "Monitor", Vector3.new(3.6, 2.7, 1.2), cf, Color3.fromRGB(24, 24, 26), Enum.Material.Metal)
			local screen = decoPart(folder, "Screen", Vector3.new(3.2, 2.3, 0.05), cf * CFrame.new(0, 0, -0.62), Color3.fromRGB(10, 40, 20), Enum.Material.Neon)
			label(screen, Enum.NormalId.Front, string.format("CAM %02d  ● REC", camera), green, Color3.fromRGB(6, 22, 12))
			camera += 1
		end
	end
	local fill = decoPart(folder, "MonitorGlow", Vector3.new(0.2, 0.2, 0.2), base * CFrame.new(16, 6, 0), green)
	fill.Transparency = 1
	glow(fill, green, 1.2, 22)
end

function DECOR_PROPS.GoldFrames(folder: Folder, base: CFrame)
	local plaque = decoPart(folder, "VIPPlaque", Vector3.new(6, 1.2, 0.2), base * CFrame.new(0, 11.6, -12.3), Color3.fromRGB(255, 200, 60), Enum.Material.Metal)
	label(plaque, Enum.NormalId.Back, "★ VIP GALLERY ★", Color3.fromRGB(40, 24, 0))
	label(plaque, Enum.NormalId.Front, "★ VIP GALLERY ★", Color3.fromRGB(40, 24, 0))
end

function DarkRoomController:_applyDecor(decorId: string?)
	if decorId == self.DecorId then
		return
	end
	self.DecorId = decorId
	if self.DecorFolder then
		self.DecorFolder:Destroy()
		self.DecorFolder = nil
	end
	local lobby = workspace:FindFirstChild("Lobby")
	local room = lobby and lobby:FindFirstChild("DarkRoom", true)
	local safelight = room and room:FindFirstChild("Safelight")
	if not safelight or not safelight:IsA("BasePart") then
		return
	end
	if not self.SafelightOriginal then
		local light = safelight:FindFirstChildOfClass("PointLight")
		self.SafelightOriginal = { Color = safelight.Color, Light = if light then light.Color else nil }
	end
	local decor = if decorId then CosmeticsConfig.Decor[decorId] else nil
	local color = if decor then decor.Safelight else self.SafelightOriginal.Color
	safelight.Color = color
	local light = safelight:FindFirstChildOfClass("PointLight")
	if light then
		light.Color = if decor then decor.Safelight else (self.SafelightOriginal.Light or color)
	end
	self.Controllers.LightingController:SetSafelight(if decor then decor.Safelight else Color3.fromRGB(255, 40, 30))
	if not decor or #decor.Props == 0 then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "DarkRoomDecor"
	folder.Parent = workspace
	self.DecorFolder = folder
	-- props are laid out relative to the safelight (room centre, 14.5 studs above the floor)
	local base = safelight.CFrame * CFrame.new(0, -14.5, 0)
	for _, prop in ipairs(decor.Props) do
		local build = DECOR_PROPS[prop]
		if build then
			local ok, err = pcall(build, folder, base)
			if not ok then
				warn("[DarkRoom] decor prop failed:", prop, err)
			end
		end
	end
end

return DarkRoomController
