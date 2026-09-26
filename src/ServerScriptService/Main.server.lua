--[[
	Main (Script)
	Location: ServerScriptService/Main

	Server bootstrap. Creates remotes, then initialises and starts every
	service in dependency order. Services receive the shared `services`
	table in Init so they can call each other without circular requires.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"))
Net.Setup()

local ServicesFolder = ServerScriptService:WaitForChild("Services")

local ORDER = {
	"MapService",
	"DataService",
	"MonetizationService",
	"EconomyService",
	"AudioService",
	"NoiseService",
	"CharacterService",
	"ObservationService",
	"EquipmentService",
	"EventService",
	"AnomalyService",
	"PhotoService",
	"InteractionService",
	"EnvironmentService",
	"DarkRoomService",
	"PartyService",
	"MissionService",
	"LobbyService",
	"AdminService",
}

local services = {}

for _, name in ipairs(ORDER) do
	services[name] = require(ServicesFolder:WaitForChild(name))
end

for _, name in ipairs(ORDER) do
	local service = services[name]
	if service.Init then
		local ok, err = pcall(service.Init, service, services)
		if not ok then
			warn(string.format("[Main] %s:Init failed: %s", name, tostring(err)))
		end
	end
end

for _, name in ipairs(ORDER) do
	local service = services[name]
	if service.Start then
		task.spawn(function()
			local ok, err = pcall(service.Start, service)
			if not ok then
				warn(string.format("[Main] %s:Start failed: %s", name, tostring(err)))
			end
		end)
	end
end

print("[CaughtOnCamera] Server ready")
