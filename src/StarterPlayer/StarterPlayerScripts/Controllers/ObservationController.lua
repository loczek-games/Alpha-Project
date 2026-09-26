--[[
	ObservationController (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/ObservationController

	Tells the server what this investigator is looking at (camera CFrame +
	field of view, ~6 times a second, unreliable). Anomalies use it for
	"moves only when nobody watches", "freezes when photographed through the
	zoom", the ceiling crawler noticing you looking up, etc.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"))

local ObservationController = {}

local player = Players.LocalPlayer
local INTERVAL = 1 / 6

function ObservationController:Init(controllers)
	self.Controllers = controllers
	self.Remote = Net.UnreliableEvent("CameraSync")
end

function ObservationController:Start()
	task.spawn(function()
		while true do
			task.wait(INTERVAL)
			local camera = Workspace.CurrentCamera
			if camera and player:GetAttribute("InMission") == true then
				self.Remote:FireServer(camera.CFrame, camera.FieldOfView)
			end
		end
	end)
end

return ObservationController
