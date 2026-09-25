--[[
	Net (ModuleScript)
	Location: ReplicatedStorage/Modules/Net

	Single source of truth for every RemoteEvent / RemoteFunction.
	The server creates any missing remotes inside ReplicatedStorage/Remotes
	(so nothing has to be created by hand), clients wait for them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

Net.Events = {
	"ClientReady", -- C->S  client UI is ready for initial state
	"PhotoRequest", -- C->S  (cameraCFrame)
	"PhotoResult", -- S->C  result of a photo
	"PhotoFlash", -- S->C  another player took a photo (flash their camera)
	"DataUpdate", -- S->C  player's saved data (client view)
	"RoundUpdate", -- S->C  round state + timer
	"EventUpdate", -- S->C  current server event
	"Announce", -- S->C  toasts / banners / dramatic reveals
	"AnomalyFx", -- S->C  client-side anomaly effects
	"RoundResults", -- S->C  end of round report
	"SettingRequest", -- C->S  (key, value)
	"DarkRoomState", -- S->C  entered / left the dark room
}

Net.Functions = {
	"ShopRequest", -- C->S  (action, id) -> ok, message
	"DarkRoomRequest", -- C->S  (action, arg) -> result
}

local cachedFolder: Instance? = nil

local function getFolder(): Instance
	local cached = cachedFolder
	if cached then
		return cached
	end
	local result: Instance
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild("Remotes")
		if not existing then
			local created = Instance.new("Folder")
			created.Name = "Remotes"
			created.Parent = ReplicatedStorage
			existing = created
		end
		result = existing :: Instance
	else
		result = ReplicatedStorage:WaitForChild("Remotes")
	end
	cachedFolder = result
	return result
end

-- Server only: create every remote up front.
function Net.Setup()
	assert(RunService:IsServer(), "Net.Setup must run on the server")
	local remotes = getFolder()
	for _, name in ipairs(Net.Events) do
		if not remotes:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = remotes
		end
	end
	for _, name in ipairs(Net.Functions) do
		if not remotes:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = remotes
		end
	end
end

function Net.Event(name: string): RemoteEvent
	local remotes = getFolder()
	local remote = if RunService:IsServer() then remotes:FindFirstChild(name) else remotes:WaitForChild(name, 60)
	assert(remote and remote:IsA("RemoteEvent"), "Missing RemoteEvent " .. name)
	return remote :: RemoteEvent
end

function Net.Function(name: string): RemoteFunction
	local remotes = getFolder()
	local remote = if RunService:IsServer() then remotes:FindFirstChild(name) else remotes:WaitForChild(name, 60)
	assert(remote and remote:IsA("RemoteFunction"), "Missing RemoteFunction " .. name)
	return remote :: RemoteFunction
end

return Net
