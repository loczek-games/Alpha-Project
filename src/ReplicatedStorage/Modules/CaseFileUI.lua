--[[
	CaseFileUI (ModuleScript)
	Location: ReplicatedStorage/Modules/CaseFileUI

	The cinematic black "case file" screen used by
	  * the loading screen (ReplicatedFirst/Loading)
	  * the mission intro ("INVESTIGATION STARTING")
	  * teleports between the lobby and gameplay places
	Pure Frames/TextLabels (no uploaded images): analog static, a red REC
	dot, a typed evidence card and a progress bar.

	  local screen = CaseFileUI.new(parentScreenGui, info)
	  screen:SetStatus("LOADING EVIDENCE"); screen:SetProgress(0.4)
	  screen:SetHeadline("INVESTIGATION STARTING"); screen:FadeOut(0.8)

	info = { Case, Name, Location, Status, LastActivity, Danger, Tip, Headline }
]]

local TweenService = game:GetService("TweenService")

local CaseFileUI = {}
CaseFileUI.__index = CaseFileUI

local INK = Color3.fromRGB(30, 26, 22)
local PAPER = Color3.fromRGB(214, 206, 188)
local RED = Color3.fromRGB(200, 30, 36)
local TEXT = Color3.fromRGB(226, 222, 214)
local DIM = Color3.fromRGB(128, 124, 118)

local TYPE_FONT = Font.fromEnum(Enum.Font.SpecialElite)
local CODE_FONT = Font.fromEnum(Enum.Font.Code)

local function new(className: string, props: { [string]: any }): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	instance.Parent = props.Parent
	return instance
end

local function label(parent: Instance, text: string, props: { [string]: any }): TextLabel
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = TEXT,
		FontFace = CODE_FONT,
		TextScaled = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent,
	}
	for key, value in pairs(props) do
		defaults[key] = value
	end
	local result = new("TextLabel", defaults)
	new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 28, Parent = result })
	return result
end

function CaseFileUI.new(parent: Instance, info: { [string]: any }?)
	local data = info or {}
	local self = setmetatable({}, CaseFileUI)
	self.Alive = true

	local root = new("Frame", {
		Name = "CaseFile",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 100,
		Parent = parent,
	})
	self.Root = root

	-- analog static: thin bars that jitter
	local static = new("Frame", { Name = "Static", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 101, Parent = root })
	self.Bars = {}
	for i = 1, 18 do
		self.Bars[i] = new("Frame", {
			BorderSizePixel = 0,
			BackgroundColor3 = Color3.fromRGB(200, 200, 200),
			BackgroundTransparency = 0.94,
			Size = UDim2.new(1, 0, 0, 2),
			Position = UDim2.fromScale(0, i / 18),
			ZIndex = 101,
			Parent = static,
		})
	end
	-- vignette
	local vignette = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 102, Parent = root })
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.3, 1),
			NumberSequenceKeypoint.new(0.7, 1),
			NumberSequenceKeypoint.new(1, 0.2),
		}),
		Parent = vignette,
	})

	-- header: agency + REC
	local rec = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.04, 0, 0.07, 0), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = RED, BorderSizePixel = 0, ZIndex = 104, Parent = root })
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = rec })
	self.Rec = rec
	label(root, "REC  P.I.A. · PARANORMAL INVESTIGATION AGENCY", { Position = UDim2.new(0.04, 22, 0.045, 0), Size = UDim2.new(0.7, 0, 0.05, 0), TextColor3 = DIM, ZIndex = 104, MaxTextSize = 20 })
	self.Clock = label(root, "00:00:00", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(0.96, 0, 0.045, 0), Size = UDim2.new(0.2, 0, 0.05, 0), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = DIM, ZIndex = 104, MaxTextSize = 20 })

	-- title
	label(root, "CAUGHT ON CAMERA", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.12),
		Size = UDim2.fromScale(0.8, 0.09),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = TYPE_FONT,
		TextColor3 = TEXT,
		ZIndex = 104,
		MaxTextSize = 64,
	})

	-- evidence card
	local card = new("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.62, 0.44),
		BackgroundColor3 = PAPER,
		BorderSizePixel = 0,
		Rotation = -1.2,
		ZIndex = 105,
		Parent = root,
	})
	new("UISizeConstraint", { MaxSize = Vector2.new(640, 330), MinSize = Vector2.new(280, 190), Parent = card })
	new("UIStroke", { Color = Color3.fromRGB(90, 80, 66), Thickness = 2, Parent = card })
	-- paper clip + red stamp
	new("Frame", { Position = UDim2.new(0.06, 0, 0, -10), Size = UDim2.fromOffset(10, 34), BackgroundColor3 = Color3.fromRGB(150, 150, 156), BorderSizePixel = 0, ZIndex = 107, Parent = card })
	local stamp = label(card, "CLASSIFIED", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0.97, 0, 0.06, 0),
		Size = UDim2.fromScale(0.36, 0.13),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = TYPE_FONT,
		TextColor3 = RED,
		Rotation = 8,
		ZIndex = 107,
		MaxTextSize = 30,
	})
	new("UIStroke", { Color = RED, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = stamp })
	self.Stamp = stamp

	local lines = {
		{ Key = "Case", Text = data.Case or "CASE #001", Size = 0.13, Font = TYPE_FONT, Color = INK },
		{ Key = "Name", Text = data.Name or "DEAD MALL", Size = 0.2, Font = TYPE_FONT, Color = INK },
		{ Key = "Status", Text = "STATUS: " .. (data.Status or "ABANDONED"), Size = 0.1, Font = CODE_FONT, Color = INK },
		{ Key = "Last", Text = "LAST REPORTED ACTIVITY: " .. (data.LastActivity or "UNKNOWN"), Size = 0.1, Font = CODE_FONT, Color = INK },
		{ Key = "Danger", Text = "DANGER LEVEL: " .. (data.Danger or "HIGH"), Size = 0.1, Font = CODE_FONT, Color = RED },
	}
	self.Lines = {}
	local y = 0.08
	for _, line in ipairs(lines) do
		local text = label(card, "", {
			Position = UDim2.fromScale(0.07, y),
			Size = UDim2.fromScale(0.6, line.Size),
			FontFace = line.Font,
			TextColor3 = line.Color,
			ZIndex = 106,
			MaxTextSize = if line.Key == "Name" then 44 else 24,
		})
		self.Lines[line.Key] = { Label = text, Full = line.Text }
		y += line.Size + 0.035
	end
	if data.Location then
		label(card, data.Location, { Position = UDim2.fromScale(0.07, 0.86), Size = UDim2.fromScale(0.86, 0.08), TextColor3 = Color3.fromRGB(96, 88, 76), ZIndex = 106, MaxTextSize = 18 })
	end

	-- headline + progress + tip
	self.Headline = label(root, data.Headline or "", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.77),
		Size = UDim2.fromScale(0.8, 0.055),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = TYPE_FONT,
		TextColor3 = RED,
		ZIndex = 104,
		MaxTextSize = 34,
	})
	local bar = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.84), Size = UDim2.new(0.5, 0, 0, 4), BackgroundColor3 = Color3.fromRGB(40, 38, 36), BorderSizePixel = 0, ZIndex = 104, Parent = root })
	self.Fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = RED, BorderSizePixel = 0, ZIndex = 105, Parent = bar })
	self.Status = label(root, "", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.855),
		Size = UDim2.fromScale(0.6, 0.035),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = DIM,
		ZIndex = 104,
		MaxTextSize = 18,
	})
	self.Tip = label(root, if data.Tip then "TIP: " .. data.Tip else "", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.96),
		Size = UDim2.fromScale(0.86, 0.045),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = TYPE_FONT,
		TextColor3 = Color3.fromRGB(170, 164, 156),
		ZIndex = 104,
		MaxTextSize = 22,
	})

	self.Thread = task.spawn(function()
		self:_animate()
	end)
	return self
end

function CaseFileUI:_animate()
	-- type the card, then keep the static + REC dot alive
	for _, key in ipairs({ "Case", "Name", "Status", "Last", "Danger" }) do
		local line = self.Lines[key]
		for i = 1, #line.Full do
			if not self.Alive then
				return
			end
			line.Label.Text = string.sub(line.Full, 1, i)
			if i % 2 == 0 then
				task.wait(0.012)
			end
		end
	end
	local t = 0
	while self.Alive do
		t += 1
		for _, bar in ipairs(self.Bars) do
			bar.Position = UDim2.fromScale(0, math.random())
			bar.BackgroundTransparency = 0.88 + math.random() * 0.1
			bar.Size = UDim2.new(1, 0, 0, math.random(1, 3))
		end
		self.Rec.Visible = (t // 8) % 2 == 0
		self.Clock.Text = os.date("!%H:%M:%S") :: string
		task.wait(0.06)
	end
end

function CaseFileUI:SetStatus(text: string)
	self.Status.Text = text
end

function CaseFileUI:SetHeadline(text: string)
	self.Headline.Text = text
end

function CaseFileUI:SetTip(text: string?)
	self.Tip.Text = if text then "TIP: " .. text else ""
end

function CaseFileUI:SetProgress(alpha: number, time: number?)
	TweenService:Create(self.Fill, TweenInfo.new(time or 0.25), { Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1) }):Play()
end

function CaseFileUI:FadeOut(time: number)
	self.Alive = false
	local info = TweenInfo.new(time)
	for _, descendant in ipairs(self.Root:GetDescendants()) do
		if descendant:IsA("TextLabel") then
			TweenService:Create(descendant, info, { TextTransparency = 1 }):Play()
		elseif descendant:IsA("Frame") then
			TweenService:Create(descendant, info, { BackgroundTransparency = 1 }):Play()
		elseif descendant:IsA("UIStroke") then
			TweenService:Create(descendant, info, { Transparency = 1 }):Play()
		end
	end
	TweenService:Create(self.Root, info, { BackgroundTransparency = 1 }):Play()
	task.delay(time + 0.05, function()
		self:Destroy()
	end)
end

function CaseFileUI:Destroy()
	self.Alive = false
	if self.Root then
		self.Root:Destroy()
	end
end

return CaseFileUI
