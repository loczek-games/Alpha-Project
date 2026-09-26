--[[
	LoadingController (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/LoadingController

	Black screens between worlds, all using the same case-file look
	(ReplicatedStorage/Modules/CaseFileUI):
	  * JOIN      takes over the ReplicatedFirst loading screen, preloads the
	              map, anomaly appearances, jumpscares, sounds and
	              equipment, then fades in.
	  * DEPLOY    fade to black -> CASE #001 / DEAD MALL / "INVESTIGATION
	              STARTING" -> (server moves you into the map, first person,
	              equipment) -> fade in.
	  * RETURN    fade to black -> "RETURNING TO HQ" -> fade in.
	  * TELEPORT  the case file stays on screen through TeleportService
	              (SetTeleportGui) while travelling between places.
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local MapConfig = require(Config:WaitForChild("MapConfig"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Net = require(Modules:WaitForChild("Net"))
local CaseFileUI = require(Modules:WaitForChild("CaseFileUI"))

local LoadingController = {}
LoadingController.Loaded = false

local player = Players.LocalPlayer

function LoadingController:Init(controllers)
	self.Controllers = controllers
	local gui = Instance.new("ScreenGui")
	gui.Name = "COC_Intro"
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.DisplayOrder = 900
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	self.Gui = gui
	self.Fade = Instance.new("Frame")
	self.Fade.Name = "Fade"
	self.Fade.Size = UDim2.fromScale(1, 1)
	self.Fade.BackgroundColor3 = Color3.new(0, 0, 0)
	self.Fade.BackgroundTransparency = 1
	self.Fade.BorderSizePixel = 0
	self.Fade.Parent = gui

	Net.Event("MissionIntro").OnClientEvent:Connect(function(info)
		if type(info) ~= "table" then
			return
		end
		local ok, err = pcall(function()
			if info.Kind == "Deploy" then
				self:_deploy(info)
			elseif info.Kind == "Return" then
				self:_return(info)
			elseif info.Kind == "Teleport" then
				self:_teleport(info)
			elseif info.Kind == "Cancel" then
				self:_close(0.4)
			end
		end)
		if not ok then
			warn("[LoadingController]", err)
			self:_close(0.2)
		end
	end)
end

function LoadingController:Start()
	local ok, err = pcall(function()
		self:_finishJoin()
	end)
	if not ok then
		warn("[LoadingController] join sequence failed:", err)
		self:_removeJoinScreen(0.3)
	end
end

-- Removes the ReplicatedFirst loading screen (also when it was never handed over).
function LoadingController:_removeJoinScreen(time: number)
	self.Loaded = true
	local screen = shared.COC_LoadingScreen
	shared.COC_LoadingScreen = nil
	if screen then
		pcall(function()
			screen:FadeOut(time)
		end)
	end
	local loadingGui = shared.COC_LoadingGui or player:WaitForChild("PlayerGui"):FindFirstChild("COC_Loading")
	shared.COC_LoadingGui = nil
	if loadingGui then
		task.delay(time + 0.1, function()
			loadingGui:Destroy()
		end)
	end
end

-- Runs `fn` but gives up waiting after `seconds` (PreloadAsync can stall on
-- slow or blocked assets; loading must never hang on it).
local function withTimeout(seconds: number, fn: () -> ()): (boolean, any)
	local done, ok, err = false, true, nil
	task.spawn(function()
		ok, err = pcall(fn)
		done = true
	end)
	local deadline = os.clock() + seconds
	while not done and os.clock() < deadline do
		task.wait(0.1)
	end
	if not done then
		return false, "timed out after " .. seconds .. " s"
	end
	return ok, err
end

---------------------------------------------------------------------------
-- Join: preload everything behind the ReplicatedFirst case file
---------------------------------------------------------------------------

function LoadingController:_finishJoin()
	local screen = shared.COC_LoadingScreen
	local function status(text: string, progress: number)
		if screen and screen.Alive ~= nil then
			screen:SetStatus(text)
			screen:SetProgress(progress)
		end
	end
	local steps = {
		{ "LOADING MAP...", function()
			local list = {}
			for _, name in ipairs({ "Lobby", "ActiveMap" }) do
				local model = Workspace:FindFirstChild(name)
				if model then
					table.insert(list, model)
				end
			end
			if #list > 0 then
				ContentProvider:PreloadAsync(list)
			end
		end },
		{ "LOADING ANOMALY FILES...", function()
			local folder = ReplicatedStorage:WaitForChild("AnomalyPreload", 6)
			if folder then
				ContentProvider:PreloadAsync({ folder })
			end
		end },
		{ "LOADING AUDIO...", function()
			self.Controllers.AudioController:PreloadAll()
		end },
		{ "PREPARING JUMPSCARES...", function()
			local jumpscares = self.Controllers.JumpscareController
			if jumpscares and jumpscares.Preload then
				jumpscares:Preload()
			end
		end },
		{ "CHECKING EQUIPMENT...", function()
			local list: { Instance } = { player:WaitForChild("PlayerGui") }
			local backpack = player:FindFirstChildOfClass("Backpack")
			if backpack then
				table.insert(list, backpack)
			end
			ContentProvider:PreloadAsync(list)
		end },
	}
	for index, step in ipairs(steps) do
		status(step[1], 0.4 + 0.5 * (index - 1) / #steps)
		local ok, err = withTimeout(8, step[2])
		if not ok then
			warn("[LoadingController] preload step failed:", step[1], err)
		end
	end
	status("WAITING FOR AGENT PROFILE...", 0.92)
	local deadline = os.clock() + 20
	while (not self.Controllers.ClientState.Data or not player.Character) and os.clock() < deadline do
		task.wait(0.2)
	end
	status("READY", 1)
	task.wait(0.4)
	self:_removeJoinScreen(1.1)
end

---------------------------------------------------------------------------
-- Mission screens
---------------------------------------------------------------------------

function LoadingController:_fadeTo(transparency: number, time: number)
	TweenService:Create(self.Fade, TweenInfo.new(time, Enum.EasingStyle.Sine), { BackgroundTransparency = transparency }):Play()
end

function LoadingController:_close(time: number)
	self.Token = nil
	if self.Screen then
		self.Screen:FadeOut(time)
		self.Screen = nil
	end
	self:_fadeTo(1, time)
end

function LoadingController:_caseFile(info, headline: string)
	if self.Screen then
		self.Screen:Destroy()
	end
	local map = MapConfig.Get(info.MapId) or MapConfig.Maps.DeadMall
	self.Screen = CaseFileUI.new(self.Fade, {
		Case = info.Case or map.Case,
		Name = info.Name or map.Name,
		Location = info.Location or map.Location,
		Status = info.Status or map.Status,
		LastActivity = info.LastActivity or map.LastActivity,
		Danger = info.Danger or map.Danger,
		Tip = info.Tip,
		Headline = headline,
	})
	return self.Screen
end

function LoadingController:_deploy(info)
	local token = {}
	self.Token = token
	local duration = math.max(2, tonumber(info.Duration) or 4.5)
	self:_fadeTo(0, 0.35)
	self.Controllers.AudioController:Play("UI.MissionStart", nil)
	task.wait(0.35)
	if self.Token ~= token then
		return
	end
	local screen = self:_caseFile(info, "INVESTIGATION STARTING")
	local statuses = { "LOCKING FIRST PERSON...", "LOADING EQUIPMENT...", "SYNCING BODY CAMERA...", "ENTERING " .. tostring(info.Name or "THE SITE") .. "..." }
	local start = os.clock()
	local total = duration - 1.2
	local index = 0
	while os.clock() - start < total and self.Token == token do
		local alpha = (os.clock() - start) / total
		local wanted = math.min(#statuses, 1 + math.floor(alpha * #statuses))
		if wanted ~= index then
			index = wanted
			screen:SetStatus(statuses[index])
		end
		screen:SetProgress(alpha, 0.1)
		task.wait(0.1)
	end
	if self.Token ~= token then
		return
	end
	screen:SetProgress(1)
	screen:SetHeadline("● REC")
	task.wait(0.35)
	self:_close(0.8)
end

function LoadingController:_return(info)
	local token = {}
	self.Token = token
	self:_fadeTo(0, 0.35)
	if self.Screen then
		self.Screen:Destroy()
		self.Screen = nil
	end
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "RETURNING TO HQ..."
	label.TextColor3 = Color3.fromRGB(200, 196, 188)
	label.FontFace = Font.fromEnum(Enum.Font.SpecialElite)
	label.TextSize = 30
	label.TextTransparency = 1
	label.Parent = self.Fade
	TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
	task.wait(math.max(0.8, (tonumber(info.Duration) or 1.6) - 0.3))
	if self.Token == token then
		TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		self:_fadeTo(1, 0.7)
	end
	task.delay(0.8, function()
		label:Destroy()
	end)
end

function LoadingController:_teleport(info)
	local token = {}
	self.Token = token
	self:_fadeTo(0, 0.4)
	local destination = if Workspace:GetAttribute("PlaceRole") == "Gameplay" then "RETURNING TO HQ" else "EN ROUTE TO " .. tostring(info.Name or "THE SITE")
	local screen = self:_caseFile(info, destination)
	screen:SetStatus("TRAVELLING...")
	screen:SetProgress(0.3, 3)
	-- keep the case file on screen during the teleport
	local teleportGui = Instance.new("ScreenGui")
	teleportGui.Name = "COC_TeleportScreen"
	teleportGui.IgnoreGuiInset = true
	teleportGui.DisplayOrder = 1000
	local black = Instance.new("Frame")
	black.Size = UDim2.fromScale(1, 1)
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BorderSizePixel = 0
	black.Parent = teleportGui
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Text = destination
	text.TextColor3 = Color3.fromRGB(200, 30, 36)
	text.FontFace = Font.fromEnum(Enum.Font.SpecialElite)
	text.TextSize = 30
	text.Parent = black
	pcall(function()
		TeleportService:SetTeleportGui(teleportGui)
	end)
	task.delay(30, function()
		if self.Token == token then
			self:_close(0.6)
		end
	end)
end

return LoadingController
