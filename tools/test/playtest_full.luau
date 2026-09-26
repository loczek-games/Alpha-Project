--[[
	Headless play test of the whole game (server Main + every service,
	client Loading + ClientMain + every controller) in one process.

	  join -> loading screen goes away -> tools in the backpack
	  -> /round start -> intro -> first person, camera in hand, viewmodel
	  -> photo -> key 2 / key 1 -> mission ends -> back at HQ

	Usage:  rojo build default.project.json --output build/CaughtOnCamera.rbxl
	        lune run tools/test/playtest_full.luau [--verbose]
	Exit code 1 on a failed check or any script error.
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
local engine = session.Engine
local Enum = engine.Enum
session.Verbose = table.find(process.args, "--verbose") ~= nil
local dm = session.DataModel
local ReplicatedStorage = dm:GetService("ReplicatedStorage")
local ServerScriptService = dm:GetService("ServerScriptService")
local StarterPlayerScripts = dm:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local Services = ServerScriptService:FindFirstChild("Services")

local character = nil
local function frames(count: number)
	for _ = 1, count do
		local head = character and character:FindFirstChild("Head")
		if head then
			-- what the default camera scripts do: follow the head
			local player = engine.localPlayer
			if player and player:GetAttribute("InMission") then
				session.Camera.CFrame = head.CFrame
			else
				session.Camera.CFrame = head.CFrame * roblox.CFrame.new(0, 2, 10)
			end
		end
		session:frame(1 / 30)
		task.wait(1 / 30)
	end
end

---------------------------------------------------------------------------
print("\n== server start ==")
---------------------------------------------------------------------------
local server = session:context("server")
server.runScript(ServerScriptService:FindFirstChild("Main"))
frames(30)
local ready = table.find(session.Prints, "[CaughtOnCamera] Server ready") ~= nil
check(ready, "server printed 'Server ready'")

---------------------------------------------------------------------------
print("\n== join ==")
---------------------------------------------------------------------------
local player = session:join("Tester", 1001)
engine.localPlayer = player
local client = session:context("client", player)
client.runScript(dm:GetService("ReplicatedFirst"):FindFirstChild("Loading"))
frames(3)
client.runScript(StarterPlayerScripts:FindFirstChild("ClientMain"))
frames(10)
character = session:spawnCharacter(player)
frames(150)

local playerGui = player:FindFirstChildOfClass("PlayerGui")
check(playerGui:FindFirstChild("COC_Loading") == nil, "loading screen removed")
local Controllers = StarterPlayerScripts:FindFirstChild("Controllers")
local ClientState = client.require(Controllers.ClientState)
local Equipment = client.require(Controllers.EquipmentController)
local Viewmodel = client.require(Controllers.ViewmodelController)
check(ClientState.Data ~= nil, "client received the save data")
local backpack = player:FindFirstChildOfClass("Backpack")
local names = {}
for _, tool in backpack:GetChildren() do
	table.insert(names, tool.Name)
end
table.sort(names)
check(#names >= 3, "tools in the backpack: " .. table.concat(names, ", "))
check(#Equipment.Slots >= 3, "hotbar slots: " .. #Equipment.Slots)

---------------------------------------------------------------------------
print("\n== /round start ==")
---------------------------------------------------------------------------
local MissionService = server.require(Services.MissionService)
-- walk into the DEAD MALL queue zone at HQ and wait for the countdown
local zone = nil
for _, d in dm:GetDescendants() do
	if d:HasTag("MissionZone") and d:IsA("BasePart") and (d:GetAttribute("MapId") or "DeadMall") == "DeadMall" then
		zone = d
		break
	end
end
check(zone ~= nil, "found the DEAD MALL queue zone")
if zone then
	character:PivotTo(roblox.CFrame.new(zone.CFrame.Position))
end
local queued = false
local deadline = os.clock() + 25
while MissionService.State == "Lobby" and os.clock() < deadline do
	frames(15)
	local queue = ClientState.Queue
	if queue then
		queued = true
	end
end
check(queued, "client received a QueueUpdate while standing in the zone")
check(MissionService.State ~= "Lobby", "queue countdown launched the mission (" .. tostring(MissionService.State) .. ")")
if MissionService.State == "Lobby" then
	local ok, reason = MissionService:ForceStart()
	check(ok == true, "fallback /round start" .. (if ok then "" else ": " .. tostring(reason)))
end
deadline = os.clock() + 20
while MissionService.State ~= "Round" and os.clock() < deadline do
	frames(15)
end
frames(30)
check(MissionService.State == "Round", "mission state is Round (" .. tostring(MissionService.State) .. ")")
check(player:GetAttribute("InMission") == true, "player is InMission")
local round = ClientState.Round or {}
check(ClientState:IsInMission(), string.format("client thinks it is in a mission (Round.State=%s, Participant=%s)", tostring(round.State), tostring(round.Participant)))
local held = nil
for _, child in character:GetChildren() do
	if child:IsA("Tool") then
		held = child.Name
	end
end
check(held == "Camera", "camera in hand after deploying (" .. tostring(held) .. ")")
check(Equipment.Equipped == "Camera", "client Equipped = " .. tostring(Equipment.Equipped))
local model = Viewmodel.Model
local handle = Viewmodel.ItemModel and Viewmodel.ItemModel:FindFirstChild("Handle")
local localPos = handle and session.Camera.CFrame:PointToObjectSpace(handle.CFrame.Position)
check(model ~= nil and engine.unwrap(model.Parent) == session.Camera and localPos ~= nil and localPos.Z < -0.5 and localPos.Z > -3, "camera viewmodel in front of the camera" .. (if localPos then string.format(" (%.2f, %.2f, %.2f)", localPos.X, localPos.Y, localPos.Z) else ""))

---------------------------------------------------------------------------
print("\n== photo ==")
---------------------------------------------------------------------------
local input = client.Services.UserInputService
local before = #engine.remoteLog
Equipment.EquipLockUntil = 0
input:Press(Enum.KeyCode.Unknown, Enum.UserInputType.MouseButton1)
frames(20)
local sent, answered = false, false
for index = before + 1, #engine.remoteLog do
	local line = engine.remoteLog[index]
	if string.find(line, "C->S PhotoRequest", 1, true) then
		sent = true
	elseif string.find(line, "S->C PhotoResult", 1, true) then
		answered = true
	end
end
check(sent, "left click sent a PhotoRequest")
check(answered, "server answered with a PhotoResult")

---------------------------------------------------------------------------
print("\n== switching ==")
---------------------------------------------------------------------------
input:Press(Enum.KeyCode.Two)
frames(20)
check(Equipment.Equipped == "Flashlight", "key 2 -> Flashlight (" .. tostring(Equipment.Equipped) .. ")")
input:Press(Enum.KeyCode.One)
frames(20)
check(Equipment.Equipped == "Camera", "key 1 -> Camera (" .. tostring(Equipment.Equipped) .. ")")
-- first person on PC: the cursor is locked, so the camera must come back
-- without clicking the hotbar
input:Press(Enum.KeyCode.Two)
frames(20)
input:Press(Enum.KeyCode.Q)
frames(20)
check(Equipment.Equipped == "Camera", "holding the flashlight, Q takes the camera out (" .. tostring(Equipment.Equipped) .. ")")
input.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseWheel, KeyCode = Enum.KeyCode.Unknown, Position = roblox.Vector3.new(0, 0, -1) }, false)
frames(20)
check(Equipment.Equipped == "Flashlight", "mouse wheel down -> next item (" .. tostring(Equipment.Equipped) .. ")")
task.wait(0.2)
input.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseWheel, KeyCode = Enum.KeyCode.Unknown, Position = roblox.Vector3.new(0, 0, 1) }, false)
frames(20)
check(Equipment.Equipped == "Camera", "mouse wheel up -> camera again (" .. tostring(Equipment.Equipped) .. ")")
handle = Viewmodel.ItemModel and Viewmodel.ItemModel:FindFirstChild("Handle")
localPos = handle and session.Camera.CFrame:PointToObjectSpace(handle.CFrame.Position)
check(localPos ~= nil and localPos.Z < -0.5, "camera viewmodel back in front of the camera")

---------------------------------------------------------------------------
print("\n== end of mission ==")
---------------------------------------------------------------------------
MissionService:ForceEnd()
deadline = os.clock() + 25
while MissionService.State ~= "Lobby" and os.clock() < deadline do
	frames(15)
end
frames(30)
check(MissionService.State == "Lobby", "back to Lobby state (" .. tostring(MissionService.State) .. ")")
check(player:GetAttribute("InMission") == false, "InMission cleared")

---------------------------------------------------------------------------

local function unique(list: { string }, filter: (string) -> boolean): { string }
	local seen, out = {}, {}
	for _, line in list do
		local key = string.sub(line, 1, 200)
		if filter(line) and not seen[key] then
			seen[key] = true
			table.insert(out, line)
		end
	end
	return out
end
local errors = unique(engine.errors, function()
	return true
end)
if #errors > 0 then
	print("\n== script errors ==")
	for _, line in errors do
		print("  " .. string.sub(line, 1, 400))
	end
end
local warnings = unique(session.Warnings, function(line)
	return not string.find(line, "[AudioService]", 1, true)
end)
if #warnings > 0 then
	print("\n== warnings ==")
	for _, line in warnings do
		print("  " .. string.sub(line, 1, 400))
	end
end
print(string.format("\n%d failure(s), %d script error(s), %d warning(s)", failures, #errors, #warnings))
process.exit(if failures > 0 or #errors > 0 then 1 else 0)
