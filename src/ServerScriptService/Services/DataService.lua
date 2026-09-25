--[[
	DataService (ModuleScript)
	Location: ServerScriptService/Services/DataService

	Saves and loads player progress with DataStoreService.
	  * pcall around every DataStore call, retries with back-off
	  * session locking (UpdateAsync) so two servers never overwrite each other
	  * autosave, PlayerRemoving save and BindToClose save
	  * template reconciliation so new fields appear for old saves
	In Studio without API access the game still runs with a temporary
	(non-saving) profile so everything can be tested.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = ReplicatedStorage:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local AnomalyConfig = require(Config:WaitForChild("AnomalyConfig"))
local CameraConfig = require(Config:WaitForChild("CameraConfig"))
local Net = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"))

local DataService = {}
DataService.Profiles = {}
DataService.ClientReady = {}
DataService._loadedCallbacks = {}
DataService._readyCallbacks = {}
DataService._pendingPush = {}

local DATA = GameConfig.Data

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in pairs(value) do
		copy[key] = deepCopy(inner)
	end
	return copy
end

local function buildTemplate()
	return {
		Version = 1,
		Evidence = 0,
		LifetimeEvidence = 0,
		Discoveries = {},
		OwnedCameras = { [CameraConfig.DefaultCamera] = true },
		EquippedCamera = CameraConfig.DefaultCamera,
		Upgrades = { Range = 0, Steady = 0, Sense = 0 },
		DarkRoom = { Theme = "Default", Visits = 0 },
		Settings = deepCopy(GameConfig.Settings),
		PhotoRoll = {},
		Stats = { PhotosTaken = 0, TotalCaptures = 0, RoundsPlayed = 0 },
		Achievements = {},
		ProcessedReceipts = {},
	}
end

-- Adds missing keys from the template without touching existing values.
local function reconcile(data, template)
	for key, value in pairs(template) do
		if data[key] == nil then
			data[key] = deepCopy(value)
		elseif type(value) == "table" and type(data[key]) == "table" and next(value) ~= nil and #value == 0 then
			reconcile(data[key], value)
		end
	end
	return data
end

local function sanitize(data)
	if type(data.Evidence) ~= "number" or data.Evidence ~= data.Evidence then
		data.Evidence = 0
	end
	data.Evidence = math.max(0, math.floor(data.Evidence))
	for id in pairs(data.Discoveries) do
		if not AnomalyConfig.Get(id) then
			-- keep unknown ids (maybe from a newer version) but make sure they're well-formed
			local entry = data.Discoveries[id]
			if type(entry) ~= "table" then
				data.Discoveries[id] = nil
			end
		end
	end
	if not CameraConfig.Get(data.EquippedCamera) then
		data.EquippedCamera = CameraConfig.DefaultCamera
	end
	for key, default in pairs(GameConfig.Settings) do
		if type(data.Settings[key]) ~= type(default) then
			data.Settings[key] = default
		end
	end
	return data
end

---------------------------------------------------------------------------
-- Loading / saving
---------------------------------------------------------------------------

function DataService:_keyFor(player: Player): string
	return DATA.KeyPrefix .. tostring(player.UserId)
end

function DataService:_load(player: Player)
	local key = self:_keyFor(player)
	local profile = {
		Player = player,
		Key = key,
		Data = nil,
		NoSave = false,
		Saving = false,
		Released = false,
		LastSave = os.clock(),
	}

	if not self.Store then
		profile.NoSave = true
		profile.Data = reconcile(buildTemplate(), buildTemplate())
		warn("[DataService] DataStores unavailable - using a temporary profile for", player.Name)
		return profile
	end

	local loaded = nil
	local errors = 0
	local lockWaits = 0
	local forceLock = false

	while not loaded do
		local lockedOut = false
		local ok, err = pcall(function()
			self.Store:UpdateAsync(key, function(old)
				local now = os.time()
				if type(old) == "table" and type(old.SessionLock) == "table" then
					local lock = old.SessionLock
					local foreign = lock.JobId ~= game.JobId
					local fresh = now - (tonumber(lock.Time) or 0) < DATA.SessionLockTimeout
					if foreign and fresh and not forceLock then
						lockedOut = true
						return nil -- cancel write, another server still owns this profile
					end
				end
				lockedOut = false
				local value = if type(old) == "table" then old else buildTemplate()
				value.SessionLock = { JobId = game.JobId, Time = now }
				loaded = value
				return value
			end)
		end)

		if not player:IsDescendantOf(Players) then
			-- left while loading; release lock if we took it
			if loaded and ok then
				profile.Data = loaded
				self:_save(profile, true)
			end
			return nil
		end

		if ok and loaded then
			break
		elseif ok and lockedOut then
			loaded = nil
			lockWaits += 1
			if lockWaits >= DATA.SessionLockRetries then
				warn("[DataService] Session lock timed out, taking over profile for", player.Name)
				forceLock = true
			end
			task.wait(DATA.SessionLockRetryDelay)
		else
			loaded = nil
			errors += 1
			warn(string.format("[DataService] Load attempt %d failed for %s: %s", errors, player.Name, tostring(err)))
			if errors >= DATA.LoadRetries then
				break
			end
			task.wait(DATA.RetryDelay * errors)
		end
	end

	if not loaded then
		if RunService:IsStudio() then
			profile.NoSave = true
			profile.Data = buildTemplate()
			warn("[DataService] Using temporary profile in Studio for", player.Name)
			return profile
		end
		player:Kick("Your save data could not be loaded right now. Please rejoin in a moment.")
		return nil
	end

	profile.Data = sanitize(reconcile(loaded, buildTemplate()))
	return profile
end

function DataService:_save(profile, release: boolean?): boolean
	if profile.NoSave or not self.Store or not profile.Data then
		return true
	end
	while profile.Saving do
		task.wait(0.1)
	end
	profile.Saving = true

	local success = false
	local stolen = false
	for attempt = 1, DATA.SaveRetries do
		local ok, err = pcall(function()
			self.Store:UpdateAsync(profile.Key, function(old)
				if type(old) == "table" and type(old.SessionLock) == "table" and old.SessionLock.JobId ~= game.JobId then
					stolen = true
					return nil -- another server owns this profile now; never overwrite it
				end
				stolen = false
				local data = profile.Data
				data.SessionLock = if release then nil else { JobId = game.JobId, Time = os.time() }
				return data
			end)
		end)
		if ok then
			success = not stolen
			break
		end
		warn(string.format("[DataService] Save attempt %d failed for %s: %s", attempt, profile.Key, tostring(err)))
		task.wait(DATA.RetryDelay * attempt)
	end

	if stolen then
		warn("[DataService] Profile", profile.Key, "is owned by another server; save skipped")
	end
	profile.LastSave = os.clock()
	profile.Saving = false
	return success
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function DataService:Init(services)
	self.Services = services

	local ok, storeOrErr = pcall(function()
		return DataStoreService:GetDataStore(DATA.StoreName)
	end)
	if ok then
		self.Store = storeOrErr
	else
		warn("[DataService] Could not access DataStores:", storeOrErr)
		self.Store = nil
	end

	self.DataUpdate = Net.Event("DataUpdate")
	self.SettingRequest = Net.Event("SettingRequest")

	Net.Event("ClientReady").OnServerEvent:Connect(function(player)
		if self.ClientReady[player] then
			return
		end
		self.ClientReady[player] = true
		if self.Profiles[player] then
			self:PushToClient(player, true)
		end
		for _, callback in ipairs(self._readyCallbacks) do
			task.spawn(callback, player)
		end
	end)

	local settingTimes = {}
	self.SettingRequest.OnServerEvent:Connect(function(player, key, value)
		local now = os.clock()
		if settingTimes[player] and now - settingTimes[player] < 0.15 then
			return
		end
		settingTimes[player] = now
		self:SetSetting(player, key, value)
	end)

	Players.PlayerAdded:Connect(function(player)
		self:_onPlayerAdded(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		settingTimes[player] = nil
		self:_onPlayerRemoving(player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:_onPlayerAdded(player)
		end)
	end

	game:BindToClose(function()
		self:_saveAllOnClose()
	end)
end

function DataService:Start()
	while true do
		task.wait(DATA.AutosaveInterval)
		for player, profile in pairs(self.Profiles) do
			if player:IsDescendantOf(Players) and not profile.Released then
				task.spawn(function()
					self:_save(profile, false)
				end)
				task.wait(1) -- stagger requests to respect DataStore budgets
			end
		end
	end
end

function DataService:_onPlayerAdded(player: Player)
	if self.Profiles[player] then
		return
	end
	local profile = self:_load(player)
	if not profile then
		return
	end
	if not player:IsDescendantOf(Players) then
		self:_save(profile, true)
		return
	end
	self.Profiles[player] = profile
	for _, callback in ipairs(self._loadedCallbacks) do
		task.spawn(callback, player, profile.Data)
	end
	if self.ClientReady[player] then
		self:PushToClient(player, true)
	end
end

function DataService:_onPlayerRemoving(player: Player)
	self.ClientReady[player] = nil
	self._pendingPush[player] = nil
	local profile = self.Profiles[player]
	if not profile then
		return
	end
	-- let other services finish their PlayerRemoving work first
	task.wait()
	profile.Released = true
	self:_save(profile, true)
	self.Profiles[player] = nil
end

function DataService:_saveAllOnClose()
	local pending = 0
	for _, profile in pairs(self.Profiles) do
		if not profile.Released then
			pending += 1
			task.spawn(function()
				profile.Released = true
				self:_save(profile, true)
				pending -= 1
			end)
		end
	end
	local started = os.clock()
	while pending > 0 and os.clock() - started < 25 do
		task.wait(0.2)
	end
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function DataService:OnProfileLoaded(callback: (Player, any) -> ())
	table.insert(self._loadedCallbacks, callback)
	for player, profile in pairs(self.Profiles) do
		task.spawn(callback, player, profile.Data)
	end
end

function DataService:OnClientReady(callback: (Player) -> ())
	table.insert(self._readyCallbacks, callback)
end

function DataService:GetProfile(player: Player)
	return self.Profiles[player]
end

function DataService:GetData(player: Player)
	local profile = self.Profiles[player]
	return profile and profile.Data
end

function DataService:WaitForProfile(player: Player, timeout: number?)
	local started = os.clock()
	local limit = timeout or 15
	while player:IsDescendantOf(Players) and os.clock() - started < limit do
		local profile = self.Profiles[player]
		if profile then
			return profile
		end
		task.wait(0.2)
	end
	return self.Profiles[player]
end

function DataService:SaveNow(player: Player): boolean
	local profile = self.Profiles[player]
	if not profile then
		return false
	end
	return self:_save(profile, false)
end

function DataService:IsClientReady(player: Player): boolean
	return self.ClientReady[player] == true
end

function DataService:GetPhotoRollCapacity(player: Player): number
	local monetization = self.Services.MonetizationService
	if monetization and monetization:HasPass(player, "ExtraAlbumStorage") then
		return DATA.PhotoRollPassCapacity
	end
	return DATA.PhotoRollBaseCapacity
end

function DataService:GetDarkRoomFrames(player: Player): number
	local monetization = self.Services.MonetizationService
	if monetization and monetization:HasPass(player, "BiggerDarkRoom") then
		return DATA.DarkRoomPassFrames
	end
	return DATA.DarkRoomBaseFrames
end

function DataService:RecordDiscovery(player: Player, anomalyId: string, stars: number)
	local data = self:GetData(player)
	if not data then
		return false, 0, nil
	end
	local entry = data.Discoveries[anomalyId]
	local isNew = entry == nil
	local previousBest = if entry then entry.BestStars or 0 else 0
	if isNew then
		entry = { Count = 0, BestStars = 0, FirstFound = os.time() }
		data.Discoveries[anomalyId] = entry
	end
	entry.Count = (entry.Count or 0) + 1
	entry.BestStars = math.max(entry.BestStars or 0, stars)
	data.Stats.TotalCaptures += 1
	self:MarkChanged(player)
	return isNew, previousBest, entry
end

function DataService:GetDiscovery(player: Player, anomalyId: string)
	local data = self:GetData(player)
	return data and data.Discoveries[anomalyId]
end

function DataService:CountDiscoveries(player: Player): number
	local data = self:GetData(player)
	if not data then
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

function DataService:AddPhotoRoll(player: Player, entry)
	local data = self:GetData(player)
	if not data then
		return
	end
	table.insert(data.PhotoRoll, 1, entry)
	local capacity = self:GetPhotoRollCapacity(player)
	while #data.PhotoRoll > capacity do
		table.remove(data.PhotoRoll)
	end
	self:MarkChanged(player)
end

function DataService:GrantAchievement(player: Player, key: string): boolean
	local data = self:GetData(player)
	if not data or data.Achievements[key] then
		return false
	end
	data.Achievements[key] = os.time()
	self:MarkChanged(player)
	return true
end

function DataService:SetSetting(player: Player, key: any, value: any)
	if type(key) ~= "string" then
		return
	end
	local default = GameConfig.Settings[key]
	if default == nil or type(value) ~= type(default) then
		return
	end
	local data = self:GetData(player)
	if not data then
		return
	end
	data.Settings[key] = value
	self:MarkChanged(player)
end

function DataService:IncrementStat(player: Player, key: string, amount: number?)
	local data = self:GetData(player)
	if not data then
		return
	end
	data.Stats[key] = (data.Stats[key] or 0) + (amount or 1)
end

function DataService:MarkReceipt(player: Player, purchaseId: string)
	local data = self:GetData(player)
	if not data then
		return
	end
	data.ProcessedReceipts[purchaseId] = os.time()
	local count = 0
	local oldestKey, oldestTime = nil, math.huge
	for key, time in pairs(data.ProcessedReceipts) do
		count += 1
		if time < oldestTime then
			oldestKey, oldestTime = key, time
		end
	end
	if count > DATA.MaxStoredReceipts and oldestKey then
		data.ProcessedReceipts[oldestKey] = nil
	end
end

function DataService:HasReceipt(player: Player, purchaseId: string): boolean
	local data = self:GetData(player)
	return data ~= nil and data.ProcessedReceipts[purchaseId] ~= nil
end

-- Sanitised copy of the save that the client is allowed to see.
function DataService:GetClientView(player: Player)
	local data = self:GetData(player)
	if not data then
		return nil
	end
	local services = self.Services
	local passes = {}
	if services.MonetizationService then
		passes = services.MonetizationService:GetOwnedPasses(player)
	end
	local owned = {}
	if services.EconomyService then
		for id in pairs(CameraConfig.Cameras) do
			owned[id] = services.EconomyService:OwnsCamera(player, id)
		end
	else
		owned = deepCopy(data.OwnedCameras)
	end
	local discoveries = {}
	for id, entry in pairs(data.Discoveries) do
		discoveries[id] = { Count = entry.Count, BestStars = entry.BestStars, FirstFound = entry.FirstFound }
	end
	return {
		Evidence = data.Evidence,
		LifetimeEvidence = data.LifetimeEvidence,
		Discoveries = discoveries,
		OwnedCameras = owned,
		EquippedCamera = data.EquippedCamera,
		Upgrades = deepCopy(data.Upgrades),
		Settings = deepCopy(data.Settings),
		PhotoRoll = deepCopy(data.PhotoRoll),
		PhotoRollCapacity = self:GetPhotoRollCapacity(player),
		DarkRoomFrames = self:GetDarkRoomFrames(player),
		Passes = passes,
		Achievements = deepCopy(data.Achievements),
		Stats = deepCopy(data.Stats),
	}
end

-- Batches rapid changes into a single DataUpdate.
function DataService:MarkChanged(player: Player)
	if self._pendingPush[player] then
		return
	end
	self._pendingPush[player] = true
	task.delay(0.1, function()
		self._pendingPush[player] = nil
		self:PushToClient(player, false)
	end)
end

function DataService:PushToClient(player: Player, force: boolean?)
	if not player:IsDescendantOf(Players) then
		return
	end
	if not force and not self.ClientReady[player] then
		return
	end
	if not self.ClientReady[player] then
		return
	end
	local view = self:GetClientView(player)
	if view then
		self.DataUpdate:FireClient(player, view)
	end
end

return DataService
