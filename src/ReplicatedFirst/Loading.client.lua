--[[
	Loading (LocalScript)
	Location: ReplicatedFirst/Loading

	Replaces the default Roblox loading screen with the cinematic case file
	as early as possible (also shown when arriving from a lobby <-> mission
	teleport). LoadingController (StarterPlayerScripts) takes over the same
	screen through `shared.COC_LoadingScreen`, preloads the game and fades
	it out.
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "COC_Loading"
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None
gui.DisplayOrder = 1000
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local black = Instance.new("Frame")
black.Name = "Black"
black.Size = UDim2.fromScale(1, 1)
black.BackgroundColor3 = Color3.new(0, 0, 0)
black.BorderSizePixel = 0
black.Parent = gui
gui.Parent = playerGui

ReplicatedFirst:RemoveDefaultLoadingScreen()

local arriving = nil
pcall(function()
	arriving = TeleportService:GetArrivingTeleportGui()
end)
if arriving then
	arriving.Parent = playerGui
end

local ok, err = pcall(function()
	local modules = ReplicatedStorage:WaitForChild("Modules", 20)
	local config = ReplicatedStorage:WaitForChild("Config", 20)
	local CaseFileUI = require(modules:WaitForChild("CaseFileUI"))
	local MapConfig = require(config:WaitForChild("MapConfig"))
	local map = MapConfig.Maps.DeadMall
	local tips = map.Tips or {}
	local screen = CaseFileUI.new(black, {
		Case = map.Case,
		Name = map.Name,
		Location = map.Location,
		Status = map.Status,
		LastActivity = map.LastActivity,
		Danger = map.Danger,
		Tip = if #tips > 0 then tips[math.random(1, #tips)] else nil,
		Headline = "LOADING INVESTIGATION",
	})
	shared.COC_LoadingScreen = screen
	shared.COC_LoadingGui = gui
	if arriving then
		arriving:Destroy()
	end
	local progress = 0.05
	while not game:IsLoaded() do
		progress = math.min(progress + 0.02, 0.35)
		screen:SetProgress(progress)
		screen:SetStatus("CONNECTING TO P.I.A. SERVERS...")
		task.wait(0.2)
	end
	screen:SetProgress(0.4)
	screen:SetStatus("RECEIVING CASE FILES...")
end)
if not ok then
	warn("[Loading]", err)
end
