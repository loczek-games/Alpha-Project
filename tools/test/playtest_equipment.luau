--[[
	Headless play test: equipment as normal Roblox Tools.

	Runs the real server (CharacterService + EquipmentService) and the real
	client (ClientState, UIKit, FirstPersonController, EquipmentController)
	against the built place. The Roblox hotbar is emulated the way the
	engine's Backpack does it (Humanoid:EquipTool / UnequipTools) and a
	click / tap is Tool.Activated.

	Usage:  rojo build default.project.json --output build/CaughtOnCamera.rbxl
	        lune run tools/test/playtest_equipment.luau [--verbose]
]]

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

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
local Controllers = dm:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts"):FindFirstChild("Controllers")

---------------------------------------------------------------------------
-- server
---------------------------------------------------------------------------

local server = session:context("server")
local rawPlayer, character = session:addPlayer("Tester", 1001, roblox.Vector3.new(-700, 3, 0))
engine.localPlayer = rawPlayer
local player = engine.wrap(rawPlayer) -- what game code sees
server.require(ReplicatedStorage.Modules.Net).Setup()

local data = {
	OwnedEquipment = { Camera = true, Flashlight = true, EMF = true, NightVision = true },
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
for _, name in { "AudioController", "AnnouncementController", "FxController", "LightingController" } do
	controllers[name] = engine.stub(name)
end
local shots = 0
controllers.PhotoController = {
	Shoot = function()
		shots += 1
	end,
}
local playerGui = player:FindFirstChildOfClass("PlayerGui")
local hudGui = engine.newInstance("ScreenGui")
hudGui.Name = "HUD"
hudGui.Parent = playerGui
local hudRoot = engine.newInstance("Frame")
hudRoot.Name = "Root"
hudRoot.Parent = hudGui
controllers.HUDController = { Gui = hudGui, Root = hudRoot }
local names = { "ClientState", "UIKit", "FirstPersonController", "EquipmentController" }
for _, name in names do
	controllers[name] = client.require(Controllers:FindFirstChild(name))
end
for _, phase in { "Init", "Start" } do
	for _, name in names do
		local controller = controllers[name]
		if controller[phase] then
			local ok, err = pcall(controller[phase], controller, if phase == "Init" then controllers else nil)
			check(ok, name .. ":" .. phase .. (if ok then "" else ": " .. tostring(err)))
		end
	end
end
local ClientState = controllers.ClientState
local Equipment = controllers.EquipmentController
ClientState.Data = data
ClientState.DataChanged:Fire(data)
local roundRemote = ReplicatedStorage.Remotes:FindFirstChild("RoundUpdate")
roundRemote:FireClient(rawPlayer, { State = "Lobby", Participant = false })

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------

local function frames(count: number)
	for _ = 1, count do
		local head = character:FindFirstChild("Head")
		if head and rawPlayer:GetAttribute("InMission") then
			session.Camera.CFrame = head.CFrame
		end
		session:frame(1 / 30)
		task.wait(1 / 60) -- real time passes too (equip delay, cooldowns)
	end
end

local function held(): any
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			return child
		end
	end
	return nil
end
local function heldName(): string?
	local tool = held()
	return tool and tool.Name
end

-- the Roblox hotbar: key / click on a slot
local function hotbar(itemId: string)
	local tool = rawPlayer:FindFirstChildOfClass("Backpack"):FindFirstChild(itemId)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if tool then
		humanoid:EquipTool(tool)
	else
		humanoid:UnequipTools() -- the held item's slot again puts it away
	end
	frames(25)
end

-- click / tap with the item in hand
local function activate()
	local tool = held()
	if tool then
		engine.signalFor(tool, "Tool.Activated"):Fire()
	end
	frames(10)
end

local function backpackNames(): string
	local list = {}
	for _, tool in rawPlayer:FindFirstChildOfClass("Backpack"):GetChildren() do
		table.insert(list, tool.Name)
	end
	table.sort(list)
	return table.concat(list, ",")
end

---------------------------------------------------------------------------
-- scenario
---------------------------------------------------------------------------

print("\n== join (HQ) ==")
services.CharacterService:_setupCharacter(player, engine.wrap(character))
frames(10)
check(backpackNames() == "Camera,EMF,Flashlight,NightVision", "backpack: " .. backpackNames())
check(engine.coreGui["Enum.CoreGuiType.Backpack"] ~= false, "the Roblox hotbar is shown")
check(heldName() == nil, "nothing in hand at HQ")
local nv = rawPlayer:FindFirstChildOfClass("Backpack"):FindFirstChild("NightVision")
check(nv ~= nil and nv.RequiresHandle == false, "Night Vision is a handleless tool")
for _, tool in rawPlayer:FindFirstChildOfClass("Backpack"):GetChildren() do
	check(tool.ManualActivationOnly == false, tool.Name .. ": click / tap activates it")
end
hotbar("Camera")
check(heldName() == "Camera" and Equipment.Equipped == "Camera", "hotbar -> camera in hand")
activate()
check(shots == 1, "click with the camera takes a photo (" .. shots .. ")")
hotbar("Camera")
check(heldName() == nil, "same slot again puts it away")

print("\n== deploy ==")
investigating = true
roundRemote:FireClient(rawPlayer, { State = "Intro", Participant = true })
services.CharacterService:SetMissionMode(player, true)
frames(20)
roundRemote:FireClient(rawPlayer, { State = "Round", Participant = true })
frames(20)
check(heldName() == "Camera", "camera in hand after deploying (" .. tostring(heldName()) .. ")")
check(Equipment.Equipped == "Camera", "client knows the camera is held")
check(Equipment.BatteryLabel.Visible and string.find(Equipment.BatteryLabel.Text, "CAMERA", 1, true) ~= nil, "battery shown: " .. Equipment.BatteryLabel.Text)
activate()
check(shots == 2, "click in first person takes a photo")

print("\n== flashlight ==")
hotbar("Flashlight")
check(heldName() == "Flashlight", "hotbar -> flashlight")
activate()
check(services.EquipmentService:IsOn(rawPlayer, "Flashlight") or services.EquipmentService:IsOn(player, "Flashlight"), "click switches it on")
frames(5)
local beamPart = session.Camera:FindFirstChild("COC_HeldBeam")
local light = beamPart and beamPart:FindFirstChildOfClass("SpotLight")
check(light ~= nil and light.Enabled, "first-person beam follows the camera and is on")
activate()
check(not (services.EquipmentService:IsOn(player, "Flashlight")), "click again switches it off")

print("\n== night vision ==")
hotbar("NightVision")
activate()
check(services.EquipmentService:IsOn(player, "NightVision"), "night vision on")
hotbar("Camera")
check(services.EquipmentService:IsOn(player, "NightVision"), "goggles stay on with the camera in hand")
check(heldName() == "Camera", "camera back in hand")

print("\n== back to HQ ==")
investigating = false
services.CharacterService:SetMissionMode(player, false)
roundRemote:FireClient(rawPlayer, { State = "Lobby", Participant = false })
frames(20)
check(heldName() == nil, "hands empty at HQ")
check(session.Camera:FindFirstChild("COC_HeldBeam") == nil, "no local beam at HQ")

---------------------------------------------------------------------------

if #engine.errors > 0 then
	print("\n== script errors ==")
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
