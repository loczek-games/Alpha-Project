--[[
	FirstPersonController (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/FirstPersonController

	The ONE place that decides the local camera mode.
	  * Lobby / HQ      third person (Classic, zoom GameConfig.Camera.LobbyMin/MaxZoom)
	  * Mission         locked first person (LockFirstPerson, zoom 0.5)
	The server sets the player attribute "InMission" (CharacterService); this
	controller applies it and keeps re-applying it every frame, so first
	person survives jumpscares, respawns, teleports, round transitions,
	equipment switches and character reloads on PC, mobile, tablet and console.

	Other controllers that need the camera for a moment (JumpscareController)
	call Suspend(key) / Resume(key) instead of touching CameraMode themselves.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))

local FirstPersonController = {}
FirstPersonController.InMission = false
FirstPersonController.Suspended = {} :: { [string]: boolean }
FirstPersonController.BaseFieldOfView = 70

local player = Players.LocalPlayer
local CAMERA = GameConfig.Camera

function FirstPersonController:Init(controllers)
	self.Controllers = controllers
	player:GetAttributeChangedSignal("InMission"):Connect(function()
		self:_apply()
	end)
	player.CharacterAdded:Connect(function(character)
		self:_onCharacter(character)
	end)
	if player.Character then
		self:_onCharacter(player.Character)
	end
	self:_apply()
end

function FirstPersonController:Start()
	RunService:BindToRenderStep("COC_FirstPerson", Enum.RenderPriority.Camera.Value - 1, function()
		self:_enforce()
	end)
end

function FirstPersonController:IsFirstPerson(): boolean
	return self.InMission
end

function FirstPersonController:IsSuspended(): boolean
	return next(self.Suspended) ~= nil
end

function FirstPersonController:Suspend(key: string)
	self.Suspended[key] = true
end

function FirstPersonController:Resume(key: string)
	self.Suspended[key] = nil
	if not self:IsSuspended() then
		local camera = Workspace.CurrentCamera
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			self:_restoreSubject()
		end
		self:_apply()
	end
end

function FirstPersonController:_apply()
	local inMission = player:GetAttribute("InMission") == true
	local changed = inMission ~= self.InMission
	self.InMission = inMission
	if inMission then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 0.5
	else
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMaxZoomDistance = CAMERA.LobbyMaxZoom
		player.CameraMinZoomDistance = CAMERA.LobbyMinZoom
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
	local camera = Workspace.CurrentCamera
	if camera and changed then
		self.BaseFieldOfView = if inMission then CAMERA.MissionFieldOfView else 70
		camera.FieldOfView = self.BaseFieldOfView
	end
end

function FirstPersonController:_restoreSubject()
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if camera and humanoid and camera.CameraSubject ~= humanoid then
		camera.CameraSubject = humanoid
	end
end

function FirstPersonController:_enforce()
	if self:IsSuspended() then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	if self.InMission then
		if player.CameraMode ~= Enum.CameraMode.LockFirstPerson then
			player.CameraMode = Enum.CameraMode.LockFirstPerson
		end
		if player.CameraMaxZoomDistance > 0.5 then
			player.CameraMinZoomDistance = 0.5
			player.CameraMaxZoomDistance = 0.5
		end
	end
	if camera.CameraType ~= Enum.CameraType.Custom then
		camera.CameraType = Enum.CameraType.Custom
	end
	self:_restoreSubject()
end

function FirstPersonController:_onCharacter(character: Model)
	-- hide prompts that belong to this player (e.g. your own REVIVE prompt)
	local function check(descendant: Instance)
		if descendant:IsA("ProximityPrompt") and descendant:GetAttribute("OwnerUserId") == player.UserId then
			descendant.Enabled = false
		end
	end
	for _, descendant in ipairs(character:GetDescendants()) do
		check(descendant)
	end
	character.DescendantAdded:Connect(check)
	task.defer(function()
		self:_apply()
		self:_restoreSubject()
	end)
end

return FirstPersonController
