--[[
	ClientState (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/ClientState

	The client's read-only mirror of server state (player data, round,
	current event, dark room). Controllers listen to its signals instead of
	remotes directly. Nothing here can grant anything - it is display only.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local CameraConfig = require(Config:WaitForChild("CameraConfig"))
local GameConfig = require(Config:WaitForChild("GameConfig"))
local AnomalyConfig = require(Config:WaitForChild("AnomalyConfig"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Net = require(Modules:WaitForChild("Net"))
local Signal = require(Modules:WaitForChild("Signal"))

local ClientState = {}
ClientState.Data = nil :: any
ClientState.Round = { State = "Intermission", EndsAt = 0, RoundNumber = 0, Waiting = false }
ClientState.Event = { Id = nil } :: any
ClientState.InDarkRoom = false

ClientState.DataChanged = Signal.new()
ClientState.RoundChanged = Signal.new()
ClientState.EventChanged = Signal.new()
ClientState.DarkRoomChanged = Signal.new()

function ClientState:Init()
	Net.Event("DataUpdate").OnClientEvent:Connect(function(data)
		local previous = self.Data
		self.Data = data
		self.DataChanged:Fire(data, previous)
	end)
	Net.Event("RoundUpdate").OnClientEvent:Connect(function(round)
		local previous = self.Round
		self.Round = round
		self.RoundChanged:Fire(round, previous)
	end)
	Net.Event("EventUpdate").OnClientEvent:Connect(function(event)
		self.Event = event or { Id = nil }
		self.EventChanged:Fire(self.Event)
	end)
	Net.Event("DarkRoomState").OnClientEvent:Connect(function(state)
		self.InDarkRoom = state and state.Inside == true
		self.DarkRoomChanged:Fire(self.InDarkRoom)
	end)
end

function ClientState:Now(): number
	return Workspace:GetServerTimeNow()
end

function ClientState:GetSetting(key: string): any
	local data = self.Data
	if data and data.Settings and data.Settings[key] ~= nil then
		return data.Settings[key]
	end
	return GameConfig.Settings[key]
end

function ClientState:HasPass(key: string): boolean
	local data = self.Data
	return data ~= nil and data.Passes ~= nil and data.Passes[key] == true
end

function ClientState:GetEquippedCameraId(): string
	local data = self.Data
	local id = data and data.EquippedCamera or CameraConfig.DefaultCamera
	if data and data.OwnedCameras and not data.OwnedCameras[id] then
		return CameraConfig.DefaultCamera
	end
	return id
end

function ClientState:GetCameraStats()
	local data = self.Data
	return CameraConfig.GetStats(self:GetEquippedCameraId(), data and data.Upgrades or nil)
end

function ClientState:GetDiscovery(id: string)
	local data = self.Data
	return data and data.Discoveries and data.Discoveries[id]
end

function ClientState:CountDiscovered(): number
	local data = self.Data
	if not data or not data.Discoveries then
		return 0
	end
	local count = 0
	for id in pairs(data.Discoveries) do
		if AnomalyConfig.Get(id) then
			count += 1
		end
	end
	return count
end

function ClientState:IsInRound(): boolean
	return self.Round.State == "Round"
end

return ClientState
