--[[
	Headless play test: equipment on a mission.

	Runs the real server (CharacterService + EquipmentService) and the real
	client (ClientState, UIKit, EquipmentController, ViewmodelController,
	FirstPersonController) against the built place, then plays:
	  join -> tools built -> deploy (first person, camera in hand)
	  -> 2 (flashlight) -> toggle it -> 1 (camera back) -> back to HQ -> 1 / 1

	Usage:  rojo build default.project.json --output build/CaughtOnCamera.rbxl
	        lune run tools/test/playtest_equipment.luau [--verbose]
]]

local process = require("@lune/process")
local roblox = require("@lune/roblox")

local place = require("./place")

local failures = 0
local function check(ok: boolean, message: string)
	if ok then
		print("  [ ok ] " .. message)
	else
		failures += 1
		print("  [FAIL] " .. message)
	end
end

local session = place.new()
local Enum = session.Engine.Enum
session.Verbose = table.find(process.args, "--verbose") ~= nil
local engine = session.Engine
local dm = session.DataModel
local ReplicatedStorage = dm:GetService("ReplicatedStorage")
local ServerScriptService = dm:GetService("ServerScriptService")
local StarterPlayerScripts = dm:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local Controllers = StarterPlayerScripts:FindFirstChild("Controllers")

---------------------------------------------------------------------------
-- server
---------------------------------------------------------------------------

local server = session:context("server")
local rawPlayer, character = session:addPlayer("Tester", 1001, roblox.Vector3.new(-700, 3, 0))
engine.localPlayer = rawPlayer
local player = engine.wrap(rawPlayer) -- what game code sees
server.require(ReplicatedStorage.Modules.Net).Setup()

local data = {
	OwnedEquipment = { Camera = true, Flashlight = true, EMF = true },
	Cosmetics = { Owned = {}, Equipped = { Camera = "CameraField", Flashlight = "FlashlightField", EMF = "EMFField" }, Decor = "Classic" },
	FlashlightUpgrades = {},
	EquippedCamera = "Starter",
	Upgrades = {},
	Settings = {},
	ReviveTokens = 0,
}
local investigating = false
local services = {}
services.DataService = {
	GetData = function()
		return data
	end,
	OnClientReady = function() end,
	OnProfileLoaded = function() end,
	MarkChanged = function() end,
	IncrementStat = function() end,
}
services.MonetizationService = {
	HasPass = function()
		return false
	end,
	OwnsCosmetic = function()
		return false
	end,
}
services.EconomyService = {
	GetEquippedCameraId = function()
		return "Starter"
	end,
}
services.AudioService = { Play = function() end }
services.NoiseService = { Emit = function() end }
services.MissionService = {
	IsInvestigating = function()
		return investigating
	end,
}
services.AnomalyService = {
	GetDangerNear = function()
		return 0
	end,
	GetEMFLevel = function()
		return 0, false
	end,
}
services.MapService = engine.stub("MapService")
services.EquipmentService = server.require(ServerScriptService.Services.EquipmentService)
services.CharacterService = server.require(ServerScriptService.Services.CharacterService)

for _, name in { "CharacterService", "EquipmentService" } do
	local ok, err = pcall(services[name].Init, services[name], services)
	check(ok, name .. ":Init" .. (if ok then "" else ": " .. tostring(err)))
end

---------------------------------------------------------------------------
-- client
---------------------------------------------------------------------------

local client = session:context("client", rawPlayer)
local controllers = {}
local stubs = { "AudioController", "AnnouncementController", "FxController", "LightingController" }
for _, name in stubs do
	controllers[name] = engine.stub(name)
end
local playerGui = player:FindFirstChildOfClass("PlayerGui")
local hudGui = engine.newInstance("ScreenGui")
hudGui.Name = "HUD"
hudGui.Parent = playerGui
local hudRoot = engine.newInstance("Frame")
hudRoot.Name = "Root"
hudRoot.Parent = hudGui
controllers.HUDController = { Gui = hudGui, Root = hudRoot }
for _, name in { "ClientState", "UIKit", "FirstPersonController", "EquipmentController", "ViewmodelController" } do
	controllers[name] = client.require(Controllers:FindFirstChild(name))
end
for _, name in { "ClientState", "UIKit", "FirstPersonController", "EquipmentController", "ViewmodelController" } do
	local controller = controllers[name]
	if controller.Init then
		local ok, err = pcall(controller.Init, controller, controllers)
		check(ok, name .. ":Init" .. (if ok then "" else ": " .. tostring(err)))
	end
end
for _, name in { "ClientState", "UIKit", "FirstPersonController", "EquipmentController", "ViewmodelController" } do
	local controller = controllers[name]
	if controller.Start then
		local ok, err = pcall(controller.Start, controller)
		check(ok, name .. ":Start" .. (if ok then "" else ": " .. tostring(err)))
	end
end
local ClientState = controllers.ClientState
local Equipment = controllers.EquipmentController
local Viewmodel = controllers.ViewmodelController
local input = client.Services.UserInputService

-- what the server would send on join
ClientState.Data = data
ClientState.DataChanged:Fire(data)
local roundRemote = ReplicatedStorage.Remotes:FindFirstChild("RoundUpdate")
roundRemote:FireClient(rawPlayer, { State = "Lobby", Participant = false })

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------

local function frames(count: number)
	for _ = 1, count do
		-- the camera follows the head (what the default camera script does)
		local head = character:FindFirstChild("Head")
		if head and player:GetAttribute("InMission") then
			session.Camera.CFrame = head.CFrame
		end
		session:frame(1 / 30)
	end
end

local function held(): string?
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			return child.Name
		end
	end
	return nil
end

local function backpackNames(): string
	local names = {}
	for _, tool in player:FindFirstChildOfClass("Backpack"):GetChildren() do
		table.insert(names, tool.Name)
	end
	table.sort(names)
	return table.concat(names, ",")
end

local function viewmodelReport(): (boolean, string)
	local model = Viewmodel.Model
	if not model then
		return false, "no viewmodel"
	end
	if engine.unwrap(model.Parent) ~= session.Camera then
		return false, "viewmodel not under the camera (parent " .. tostring(model.Parent) .. ")"
	end
	local item = Viewmodel.ItemModel
	local handle = item and item:FindFirstChild("Handle")
	if not handle then
		return false, "viewmodel has no Handle"
	end
	local localPos = session.Camera.CFrame:PointToObjectSpace(handle.CFrame.Position)
	local inFront = localPos.Z < -0.5 and localPos.Z > -3 and math.abs(localPos.X) < 1.5 and math.abs(localPos.Y) < 1.5
	local visibleParts = 0
	for _, d in item:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			visibleParts += 1
		end
	end
	return inFront and visibleParts > 3, string.format("%s at camera-space (%.2f, %.2f, %.2f), %d visible parts", Viewmodel.Item or "?", localPos.X, localPos.Y, localPos.Z, visibleParts)
end

---------------------------------------------------------------------------
-- scenario
---------------------------------------------------------------------------

print("\n== join ==")
services.CharacterService:_setupCharacter(player, engine.wrap(character))
frames(10)
check(backpackNames() == "Camera,EMF,Flashlight", "backpack has Camera, EMF, Flashlight (" .. backpackNames() .. ")")
check(held() == nil, "nothing in hand at HQ")
check(#Equipment.Slots == 3, "hotbar shows 3 slots (" .. #Equipment.Slots .. ")")

print("\n== deploy ==")
investigating = true
roundRemote:FireClient(rawPlayer, { State = "Intro", Participant = true })
services.CharacterService:SetMissionMode(player, true)
frames(20)
roundRemote:FireClient(rawPlayer, { State = "Round", Participant = true })
frames(20)
check(player:GetAttribute("InMission") == true, "InMission attribute set")
check(held() == "Camera", "server put the camera in hand (" .. tostring(held()) .. ")")
check(Equipment.Equipped == "Camera", "client knows the camera is held (" .. tostring(Equipment.Equipped) .. ")")
local ok, report = viewmodelReport()
check(ok, "camera viewmodel visible in front of the camera: " .. report)

print("\n== key 2: flashlight ==")
input:Press(Enum.KeyCode.Two)
frames(20)
check(held() == "Flashlight", "flashlight in hand (" .. tostring(held()) .. ")")
check(Equipment.Equipped == "Flashlight", "client Equipped = Flashlight (" .. tostring(Equipment.Equipped) .. ")")
ok, report = viewmodelReport()
check(ok, "flashlight viewmodel visible: " .. report)
Equipment.EquipLockUntil = 0
services.EquipmentService:_state(player).EquippedAt = 0
Equipment:UseEquipped()
frames(10)
check(services.EquipmentService:IsOn(player, "Flashlight"), "flashlight switched on")
check(Viewmodel.Beam ~= nil and Viewmodel.Beam.Enabled, "first-person beam follows the camera and is on")

print("\n== key 1: camera again ==")
input:Press(Enum.KeyCode.One)
frames(20)
check(held() == "Camera", "camera back in hand (" .. tostring(held()) .. ")")
check(Equipment.Equipped == "Camera", "client Equipped = Camera (" .. tostring(Equipment.Equipped) .. ")")
ok, report = viewmodelReport()
check(ok, "camera viewmodel visible again: " .. report)
check(not services.EquipmentService:IsOn(player, "Flashlight"), "flashlight switched off when put away")

print("\n== back to HQ ==")
investigating = false
services.CharacterService:SetMissionMode(player, false)
roundRemote:FireClient(rawPlayer, { State = "Lobby", Participant = false })
frames(20)
check(held() == nil, "hands empty at HQ")
check(Viewmodel.Model == nil, "no first-person viewmodel at HQ")
input:Press(Enum.KeyCode.One)
frames(10)
check(held() == "Camera", "key 1 at HQ takes the camera out (" .. tostring(held()) .. ")")
input:Press(Enum.KeyCode.One)
frames(10)
check(held() == nil, "key 1 again puts it away (" .. tostring(held()) .. ")")

---------------------------------------------------------------------------

if #engine.errors > 0 then
	print("\n== script errors during the test ==")
	for _, message in engine.errors do
		print("  " .. message)
	end
end
local interesting = {}
for _, line in session.Warnings do
	if not string.find(line, "AudioService", 1, true) then
		table.insert(interesting, line)
	end
end
if #interesting > 0 then
	print("\n== warnings ==")
	for index = 1, math.min(#interesting, 25) do
		print("  " .. interesting[index])
	end
end
print(string.format("\n%d failure(s), %d script error(s)", failures, #engine.errors))
process.exit(if failures > 0 or #engine.errors > 0 then 1 else 0)
