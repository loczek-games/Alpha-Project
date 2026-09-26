--[[
	ClientMain (LocalScript)
	Location: StarterPlayer/StarterPlayerScripts/ClientMain

	Client bootstrap. Initialises every controller, then tells the server the
	UI is ready so it can send the initial mission / data / party / event state.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"))
local Controllers = script.Parent:WaitForChild("Controllers")

local ORDER = {
	"ClientState",
	"UIKit",
	"AudioController",
	"LightingController",
	"WorldController",
	"FirstPersonController",
	"HUDController",
	"AnnouncementController",
	"LoadingController",
	"FxController",
	"JumpscareController",
	"DownedController",
	"EquipmentController",
	"PhotoController",
	"MovementController",
	"FootstepController",
	"ObservationController",
	"AnomalyAnimator",
	"AlbumController",
	"ShopController",
	"SettingsController",
	"PartyController",
	"LobbyController",
	"ResultsController",
	"DarkRoomController",
	"ChatTagController",
}

-- one broken controller must not take the whole client (and the loading
-- screen) down with it
local controllers = {}
for _, name in ipairs(ORDER) do
	local module = Controllers:WaitForChild(name, 10)
	local ok, result = pcall(function()
		return require(module :: ModuleScript)
	end)
	if ok and type(result) == "table" then
		controllers[name] = result
	else
		warn(string.format("[ClientMain] %s failed to load: %s", name, tostring(result)))
	end
end

for _, name in ipairs(ORDER) do
	local controller = controllers[name]
	if controller and controller.Init then
		local ok, err = pcall(controller.Init, controller, controllers)
		if not ok then
			warn(string.format("[ClientMain] %s:Init failed: %s", name, tostring(err)))
		end
	end
end

for _, name in ipairs(ORDER) do
	local controller = controllers[name]
	if controller and controller.Start then
		task.spawn(function()
			local ok, err = pcall(controller.Start, controller)
			if not ok then
				warn(string.format("[ClientMain] %s:Start failed: %s", name, tostring(err)))
			end
		end)
	end
end

Net.Event("ClientReady"):FireServer()
