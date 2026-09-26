--[[
	Mock Roblox services for the headless play tests (tools/test/place.luau).
	They behave like a Studio session without published assets: DataStores
	work in memory, nothing is owned or purchasable, catalog/asset loads fail
	(so the game uses its fallbacks), pathfinding finds no path.
]]

local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local task = require("@lune/task")

return function(engine: any)
	local Signal = engine.Signal
	local Enum = engine.Enum
	local mocks = {}

	-- DataStores (in memory, shared by every key)
	local stores = {}
	local function dataStore(name: string)
		stores[name] = stores[name] or {}
		local data = stores[name]
		local store = {}
		function store:GetAsync(key)
			task.wait(0.01)
			return data[key]
		end
		function store:SetAsync(key, value)
			data[key] = value
		end
		function store:UpdateAsync(key, fn)
			task.wait(0.01)
			local result = fn(data[key])
			if result ~= nil then
				data[key] = result
			end
			return result
		end
		function store:RemoveAsync(key)
			local old = data[key]
			data[key] = nil
			return old
		end
		function store:IncrementAsync(key, delta)
			data[key] = (data[key] or 0) + (delta or 1)
			return data[key]
		end
		return store
	end
	mocks.DataStoreService = {
		GetDataStore = function(_, name)
			return dataStore(name)
		end,
		GetOrderedDataStore = function(_, name)
			return dataStore("ordered:" .. name)
		end,
		GetRequestBudgetForRequestType = function()
			return 100
		end,
	}

	mocks.MarketplaceService = {
		PromptGamePassPurchaseFinished = Signal.new("PromptGamePassPurchaseFinished"),
		PromptProductPurchaseFinished = Signal.new("PromptProductPurchaseFinished"),
		UserOwnsGamePassAsync = function()
			return false
		end,
		PlayerOwnsAsset = function()
			return false
		end,
		GetProductInfo = function()
			error("HTTP 400 (mock: no published products)")
		end,
		PromptGamePassPurchase = function() end,
		PromptProductPurchase = function() end,
	}

	mocks.TeleportService = {
		GetArrivingTeleportGui = function()
			return nil
		end,
		SetTeleportGui = function() end,
		GetLocalPlayerTeleportData = function()
			return nil
		end,
		ReserveServer = function()
			error("mock: cannot reserve servers in a test")
		end,
		TeleportAsync = function()
			error("mock: cannot teleport in a test")
		end,
		TeleportInitFailed = Signal.new("TeleportInitFailed"),
	}

	mocks.MemoryStoreService = {
		GetHashMap = function()
			local map = {}
			local data = {}
			function map:GetAsync(key)
				return data[key]
			end
			function map:SetAsync(key, value)
				data[key] = value
				return true
			end
			function map:UpdateAsync(key, fn)
				data[key] = fn(data[key])
				return data[key]
			end
			function map:RemoveAsync(key)
				data[key] = nil
			end
			return map
		end,
	}

	mocks.SocialService = {
		CanSendGameInviteAsync = function()
			return false
		end,
		PromptGameInvite = function() end,
		GameInvitePromptClosed = Signal.new("GameInvitePromptClosed"),
	}

	mocks.VoiceChatService = {
		IsVoiceEnabledForUserIdAsync = function()
			return false
		end,
	}

	mocks.ContentProvider = {
		RequestQueueSize = 0,
		PreloadAsync = function(_, list, callback)
			task.wait(0.05)
			if callback then
				for _, item in list do
					if typeof(item) == "Instance" and item:IsA("Sound") then
						callback(item.SoundId, Enum.AssetFetchStatus.Success)
					end
				end
			end
		end,
	}

	local groups = { Default = true }
	local collidable = {}
	mocks.PhysicsService = {
		RegisterCollisionGroup = function(_, name)
			groups[name] = true
		end,
		IsCollisionGroupRegistered = function(_, name)
			return groups[name] == true
		end,
		CollisionGroupSetCollidable = function(_, a, b, value)
			assert(groups[a] and groups[b], "CollisionGroupSetCollidable on an unregistered group")
			collidable[a .. "|" .. b] = value
		end,
		CollisionGroupsAreCollidable = function(_, a, b)
			local value = collidable[a .. "|" .. b]
			if value == nil then
				value = collidable[b .. "|" .. a]
			end
			return value ~= false
		end,
		GetRegisteredCollisionGroups = function()
			local list = {}
			for name in groups do
				table.insert(list, { name = name })
			end
			return list
		end,
	}
	engine.collisionGroups = groups

	mocks.PathfindingService = {
		CreatePath = function()
			local path = { Status = Enum.PathStatus.NoPath, Blocked = Signal.new("Path.Blocked") }
			function path:ComputeAsync()
				task.wait(0.01)
			end
			function path:GetWaypoints()
				return {}
			end
			return path
		end,
	}

	mocks.InsertService = {
		LoadAsset = function()
			error("mock: LoadAsset not allowed in tests")
		end,
	}
	mocks.AssetService = {
		GetBundleDetailsAsync = function()
			error("mock: HTTP 403")
		end,
		CreateEditableMesh = function()
			error("mock")
		end,
	}
	mocks.BadgeService = {
		AwardBadge = function()
			return false
		end,
		UserHasBadgeAsync = function()
			return false
		end,
	}
	mocks.Debris = {
		AddItem = function(_, instance, lifetime)
			task.delay(lifetime or 10, function()
				pcall(function()
					instance:Destroy()
				end)
			end)
		end,
	}
	mocks.ProximityPromptService = {
		PromptShown = Signal.new("PromptShown"),
		PromptHidden = Signal.new("PromptHidden"),
		PromptTriggered = Signal.new("PromptTriggered"),
		PromptButtonHoldBegan = Signal.new("PromptButtonHoldBegan"),
	}
	mocks.HttpService = {
		GenerateGUID = function(_, braces)
			local id = string.format("%08x-%04x-%04x-%04x-%012x", math.random(0, 0xffffffff), math.random(0, 0xffff), math.random(0, 0xffff), math.random(0, 0xffff), math.random(0, 0xffffffffffff))
			return if braces == false then id else "{" .. id .. "}"
		end,
		JSONEncode = function(_, value)
			return serde.encode("json", value)
		end,
		JSONDecode = function(_, text)
			return serde.decode("json", text)
		end,
	}
	mocks.GuiService = {
		MenuOpened = Signal.new("MenuOpened"),
		MenuClosed = Signal.new("MenuClosed"),
		GetGuiInset = function()
			return roblox.Vector2.new(0, 58), roblox.Vector2.new(0, 0)
		end,
		IsTenFootInterface = function()
			return false
		end,
	}
	mocks.LocalizationService = { RobloxLocaleId = "en-us", SystemLocaleId = "en-us" }
	mocks.PolicyService = {
		GetPolicyInfoForPlayerAsync = function()
			return { ArePaidRandomItemsRestricted = false, IsSubjectToChinaPolicies = false, AllowedExternalLinkReferences = {} }
		end,
	}

	return mocks
end
