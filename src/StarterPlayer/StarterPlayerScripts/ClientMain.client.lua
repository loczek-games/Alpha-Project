--[[
	ClientMain (LocalScript)
	Location: StarterPlayer/StarterPlayerScripts/ClientMain

	Client bootstrap. Initialises every controller, then tells the server the
	UI is ready so it can send the initial round / data / event state.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Net = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"))
local Controllers = script.Parent:WaitForChild("Controllers")

local ORDER = {
	"ClientState",
	"UIKit",
	"Sfx",
	"HUDController",
	"AnnouncementController",
	"FxController",
	"PhotoController",
	"AlbumController",
	"ShopController",
	"ResultsController",
	"DarkRoomController",
	"ChatTagController",
}

-- No tools in this game - hide the backpack hotbar to keep the mobile screen clean.
task.spawn(function()
	for _ = 1, 10 do
		local ok = pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)
		if ok then
			break
		end
		task.wait(0.5)
	end
end)

local controllers = {}
for _, name in ipairs(ORDER) do
	controllers[name] = require(Controllers:WaitForChild(name))
end

for _, name in ipairs(ORDER) do
	local controller = controllers[name]
	if controller.Init then
		local ok, err = pcall(controller.Init, controller, controllers)
		if not ok then
			warn(string.format("[ClientMain] %s:Init failed: %s", name, tostring(err)))
		end
	end
end

for _, name in ipairs(ORDER) do
	local controller = controllers[name]
	if controller.Start then
		task.spawn(function()
			local ok, err = pcall(controller.Start, controller)
			if not ok then
				warn(string.format("[ClientMain] %s:Start failed: %s", name, tostring(err)))
			end
		end)
	end
end

Net.Event("ClientReady"):FireServer()
