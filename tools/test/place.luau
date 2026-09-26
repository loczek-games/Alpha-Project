--[[
	Loads the built place (build/CaughtOnCamera.rbxl) into Lune and runs its
	ModuleScripts on top of tools/test/engine.luau.

	  local place = require("./place")
	  local session = place.new()                      -- the DataModel + engine
	  local server = session:context("server")         -- require() for server code
	  local client = session:context("client", player) -- require() for client code
	  local EquipmentService = server.require(game.ServerScriptService.Services.EquipmentService)

	Each context has its own module cache and its own RunService /
	UserInputService, exactly like the server and a client do in Roblox.
	Services that are not Instances in Lune are mocks from engine.luau, or
	permissive stubs (session.stubs[name]) for things a test does not use.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local engine = require("./engine")
local createMocks = require("./services")

local place = {}

local GLOBALS = {
	"Instance", "Vector3", "Vector2", "CFrame", "Color3", "UDim", "UDim2", "Enum", "NumberSequence",
	"NumberSequenceKeypoint", "ColorSequence", "ColorSequenceKeypoint", "NumberRange", "Font", "BrickColor",
	"Rect", "PhysicalProperties", "Ray", "Region3", "Axes", "Faces", "Vector3int16", "Vector2int16",
}

-- datatypes Lune does not have
local TweenInfo = {
	new = function(time, style, direction, repeatCount, reverses, delay)
		return { Time = time or 1, EasingStyle = style, EasingDirection = direction, RepeatCount = repeatCount or 0, Reverses = reverses or false, DelayTime = delay or 0 }
	end,
}
local RaycastParams = {
	new = function()
		return { FilterType = roblox.Enum.RaycastFilterType.Exclude, FilterDescendantsInstances = {}, IgnoreWater = false, RespectCanCollide = false, CollisionGroup = "Default" }
	end,
}
local OverlapParams = RaycastParams
local Random = {
	new = function(seed: number?)
		local state = (seed or os.clock() * 1e6) % 2147483647
		local rng = {}
		local function nextFloat()
			state = (state * 16807) % 2147483647
			return state / 2147483647
		end
		function rng:NextNumber(min: number?, max: number?)
			local a, b = min or 0, max or 1
			return a + (b - a) * nextFloat()
		end
		function rng:NextInteger(min: number, max: number)
			return math.floor(min + (max - min + 1) * nextFloat())
		end
		function rng:Shuffle(list)
			for i = #list, 2, -1 do
				local j = rng:NextInteger(1, i)
				list[i], list[j] = list[j], list[i]
			end
		end
		return rng
	end,
}
local DateTime = {
	now = function()
		return { UnixTimestamp = os.time(), UnixTimestampMillis = os.time() * 1000 }
	end,
}

function place.new(path: string?)
	local file = path or "build/CaughtOnCamera.rbxl"
	assert(fs.isFile(file), file .. " missing - run `rojo build default.project.json --output " .. file .. "` first")
	local dataModel = roblox.deserializePlace(fs.readFile(file))
	engine.game = dataModel

	local session = { DataModel = dataModel, Engine = engine, Contexts = {}, Stubs = {}, Mocks = createMocks(engine) }
	engine.syncDerived(dataModel)

	-- Workspace helpers
	local workspace = dataModel:GetService("Workspace")
	local camera = roblox.Instance.new("Camera")
	camera.Name = "Camera"
	camera.CFrame = roblox.CFrame.new(0, 10, 0)
	camera.Parent = workspace
	workspace.CurrentCamera = camera
	if not workspace:FindFirstChildOfClass("Terrain") then
		local terrain = roblox.Instance.new("Terrain")
		terrain.Parent = workspace
		pcall(function()
			workspace.Terrain = terrain
		end)
	end
	roblox.implementMethod("Workspace", "Raycast", function()
		return nil
	end)
	roblox.implementMethod("Workspace", "GetServerTimeNow", function()
		return os.clock()
	end)
	roblox.implementMethod("Workspace", "GetPartBoundsInBox", function()
		return {}
	end)
	roblox.implementMethod("Workspace", "GetPartBoundsInRadius", function()
		return {}
	end)
	roblox.implementProperty("Camera", "ViewportSize", function()
		return roblox.Vector2.new(1280, 720)
	end)
	roblox.implementMethod("Camera", "WorldToViewportPoint", function(cam, point)
		local p = cam.CFrame:PointToObjectSpace(point)
		local depth = -p.Z
		local scale = 360 / math.tan(math.rad(cam.FieldOfView / 2))
		return roblox.Vector3.new(640 + p.X / math.max(depth, 1e-3) * scale, 360 - p.Y / math.max(depth, 1e-3) * scale, depth), depth > 0
	end)
	roblox.implementProperty("GuiBase2d", "AbsoluteSize", function()
		return roblox.Vector2.new(1280, 720)
	end)
	roblox.implementProperty("GuiBase2d", "AbsolutePosition", function()
		return roblox.Vector2.new(0, 0)
	end)
	session.Camera = camera

	-- CollectionService over the whole DataModel
	local collection = {}
	function collection:GetTagged(tag: string)
		local list = {}
		for _, d in dataModel:GetDescendants() do
			if d:HasTag(tag) then
				table.insert(list, engine.wrap(d))
			end
		end
		return list
	end
	function collection:HasTag(instance, tag)
		return engine.unwrap(instance):HasTag(tag)
	end
	function collection:AddTag(instance, tag)
		engine.unwrap(instance):AddTag(tag)
	end
	function collection:RemoveTag(instance, tag)
		engine.unwrap(instance):RemoveTag(tag)
	end
	function collection:GetTags(instance)
		return engine.unwrap(instance):GetTags()
	end
	local tagSignals = {}
	function collection:GetInstanceAddedSignal(tag)
		tagSignals[tag] = tagSignals[tag] or engine.Signal.new("Tag+" .. tag)
		return tagSignals[tag]
	end
	function collection:GetInstanceRemovedSignal(tag)
		tagSignals["-" .. tag] = tagSignals["-" .. tag] or engine.Signal.new("Tag-" .. tag)
		return tagSignals["-" .. tag]
	end
	session.CollectionService = collection

	local REAL = {
		Workspace = true, ReplicatedStorage = true, ReplicatedFirst = true, ServerScriptService = true,
		ServerStorage = true, StarterPlayer = true, StarterGui = true, StarterPack = true, Lighting = true,
		SoundService = true, Players = true, Teams = true, Chat = true, TextChatService = true,
	}

	function session:context(kind: string, localPlayer: any?)
		local context = { Kind = kind, Cache = {}, LocalPlayer = localPlayer }
		if localPlayer then
			-- one client per session: Players.LocalPlayer is that player
			dataModel:GetService("Players").LocalPlayer = localPlayer
		end
		local services = {
			RunService = engine.runService(kind == "server"),
			UserInputService = engine.userInputService(),
			TweenService = engine.tweenService(),
			CollectionService = collection,
		}
		context.Services = services
		local gameProxy = setmetatable({}, {
			__index = function(_, key)
				if key == "GetService" then
					return function(_, name: string)
						if services[name] then
							return services[name]
						end
						if REAL[name] then
							return engine.wrap(dataModel:GetService(name))
						end
						if session.Mocks[name] then
							return session.Mocks[name]
						end
						session.Stubs[name] = session.Stubs[name] or engine.stub(name)
						return session.Stubs[name]
					end
				elseif key == "PlaceId" or key == "GameId" or key == "CreatorId" or key == "JobId" or key == "PrivateServerId" or key == "PrivateServerOwnerId" then
					return if key == "JobId" or key == "PrivateServerId" then "" else 0
				elseif key == "CreatorType" then
					return roblox.Enum.CreatorType.User
				elseif key == "IsLoaded" then
					return function()
						return true
					end
				elseif key == "Loaded" or key == "Close" then
					return engine.Signal.new("game." .. key)
				elseif key == "BindToClose" then
					return function() end
				elseif key == "Workspace" then
					return engine.wrap(workspace)
				end
				return engine.wrap(dataModel)[key]
			end,
		})
		context.Game = gameProxy

		local requireModule
		local function makeEnv(scriptInstance: any)
			local env = {}
			for _, name in GLOBALS do
				env[name] = (roblox :: any)[name]
			end
			env.Enum = engine.Enum
			env.Instance = { new = engine.newInstance, fromExisting = function(existing)
				return existing:Clone()
			end }
			env.typeof = engine.typeof
			env.TweenInfo = TweenInfo
			env.UserSettings = function()
				return { GameSettings = { SavedQualityLevel = roblox.Enum.SavedQualitySetting.Automatic, MasterVolume = 1 } }
			end
			env.settings = function()
				return { Rendering = { QualityLevel = roblox.Enum.QualityLevel.Automatic } }
			end
			env.RaycastParams = RaycastParams
			env.OverlapParams = OverlapParams
			env.Random = Random
			env.DateTime = DateTime
			env.game = gameProxy
			env.workspace = engine.wrap(workspace)
			env.script = engine.wrap(scriptInstance)
			env.require = function(target)
				return requireModule(target)
			end
			env.task = task
			env.shared = session.Shared
			env._G = session.Shared
			env.tick = os.clock
			env.time = os.clock
			env.warn = function(...)
				local parts = {}
				for i = 1, select("#", ...) do
					table.insert(parts, tostring((select(i, ...))))
				end
				local line = table.concat(parts, " ")
				table.insert(session.Warnings, line)
				if session.Verbose then
					print("    [warn] " .. line)
				end
			end
			env.print = function(...)
				local parts = {}
				for i = 1, select("#", ...) do
					table.insert(parts, tostring((select(i, ...))))
				end
				table.insert(session.Prints, table.concat(parts, " "))
				if session.Verbose then
					print("    [print] " .. table.concat(parts, " "))
				end
			end
			return env
		end

		requireModule = function(module: any)
			module = engine.unwrap(module)
			assert(typeof(module) == "Instance" and module:IsA("ModuleScript"), "require expects a ModuleScript, got " .. tostring(module))
			local key = module:GetFullName()
			local cached = context.Cache[key]
			if cached ~= nil then
				return cached
			end
			local chunk = luau.load(module.Source, { debugName = key, environment = makeEnv(module) })
			local result = chunk()
			context.Cache[key] = result
			return result
		end
		context.require = requireModule

		-- runs a Script / LocalScript like the engine does (its own thread)
		function context.runScript(scriptInstance: any)
			scriptInstance = engine.unwrap(scriptInstance)
			local key = scriptInstance:GetFullName()
			local chunk = luau.load(scriptInstance.Source, { debugName = key, environment = makeEnv(scriptInstance) })
			task.spawn(function()
				local ok, err = pcall(chunk)
				if not ok then
					local message = "[script " .. key .. "] " .. tostring(err)
					table.insert(engine.errors, message)
					print("  [engine] " .. message)
				end
			end)
		end
		self.Contexts[kind] = context
		return context
	end

	session.Shared = {}
	session.Prints = {} :: { string }
	session.Warnings = {} :: { string }
	session.Verbose = false

	-- one simulated frame on every context
	local soundService = dataModel:GetService("SoundService")
	function session:frame(dt: number?)
		-- only what moves: characters, the camera (viewmodels), anomalies,
		-- round items; the static map was synced once at load
		for _, name in { "ActiveAnomalies", "RoundItems", "Decoys", "UVResidue", "AnomalyBeacons" } do
			local folder = workspace:FindFirstChild(name)
			if folder then
				engine.syncDerived(folder)
			end
		end
		engine.syncDerived(camera)
		engine.syncDerived(soundService)
		for _, player in dataModel:GetService("Players"):GetChildren() do
			engine.syncDerived(player)
			if player:IsA("Player") and player.Character then
				engine.syncDerived(player.Character)
			end
		end
		engine.step()
		for _, context in self.Contexts do
			context.Services.RunService:Frame(dt or 1 / 60)
		end
		task.wait(0)
		engine.step()
	end

	function session:run(seconds: number, dt: number?)
		local step = dt or 1 / 30
		local elapsed = 0
		while elapsed < seconds do
			self:frame(step)
			task.wait(step)
			elapsed += step
		end
	end

	-- builds a character at the SpawnLocation (like Players.CharacterAutoLoads)
	function session:spawnCharacter(player: any)
		local spawnPart = nil
		for _, d in workspace:GetDescendants() do
			if d:IsA("SpawnLocation") then
				spawnPart = d
				break
			end
		end
		local origin = if spawnPart then spawnPart.CFrame.Position + roblox.Vector3.new(0, 3, 0) else roblox.Vector3.new(0, 5, 0)
		local old = player.Character
		if old then
			old:Destroy()
		end
		local character = roblox.Instance.new("Model")
		character.Name = player.Name
		local function limb(limbName: string, size: any, offset: any)
			local part = roblox.Instance.new("Part")
			part.Name = limbName
			part.Size = size
			part.CFrame = roblox.CFrame.new(origin + offset)
			part.Parent = character
			return part
		end
		local root = limb("HumanoidRootPart", roblox.Vector3.new(2, 2, 1), roblox.Vector3.zero)
		limb("UpperTorso", roblox.Vector3.new(2, 1.6, 1), roblox.Vector3.new(0, 0.5, 0))
		limb("LowerTorso", roblox.Vector3.new(2, 0.4, 1), roblox.Vector3.new(0, -0.4, 0))
		local head = limb("Head", roblox.Vector3.new(1.2, 1.2, 1.2), roblox.Vector3.new(0, 1.9, 0))
		limb("RightHand", roblox.Vector3.new(0.3, 0.3, 0.3), roblox.Vector3.new(1.5, -0.8, 0))
		limb("LeftHand", roblox.Vector3.new(0.3, 0.3, 0.3), roblox.Vector3.new(-1.5, -0.8, 0))
		local face = roblox.Instance.new("Decal")
		face.Name = "face"
		face.Parent = head
		local humanoid = roblox.Instance.new("Humanoid")
		humanoid.Parent = character
		local animator = roblox.Instance.new("Animator")
		animator.Parent = humanoid
		local colors = roblox.Instance.new("BodyColors")
		colors.Parent = character
		character.PrimaryPart = root
		engine.syncDerived(character)
		character.Parent = workspace
		player.Character = character
		-- ResetOnSpawn guis from StarterGui
		local playerGui = player:FindFirstChildOfClass("PlayerGui")
		for _, gui in dataModel:GetService("StarterGui"):GetChildren() do
			if playerGui and not playerGui:FindFirstChild(gui.Name) then
				gui:Clone().Parent = playerGui
			end
		end
		engine.signalFor(player, "CharacterAdded"):Fire(character)
		-- Roblox gives every spawned character a fresh Backpack (refilled from
		-- StarterPack / StarterGear), replacing the old one right after
		-- CharacterAdded: anything put into the old Backpack is gone.
		task.delay(0.15, function()
			local old = player:FindFirstChildOfClass("Backpack")
			if old then
				old:Destroy()
			end
			local fresh = roblox.Instance.new("Backpack")
			local starterGear = player:FindFirstChild("StarterGear")
			for _, source in { dataModel:GetService("StarterPack"), starterGear } do
				if source then
					for _, tool in source:GetChildren() do
						tool:Clone().Parent = fresh
					end
				end
			end
			fresh.Parent = player
		end)
		return character
	end
	engine.spawnCharacter = function(player)
		return session:spawnCharacter(player)
	end

	-- a player joining the server (PlayerAdded fires; no character yet)
	function session:join(name: string, userId: number)
		local players = dataModel:GetService("Players")
		local player = roblox.Instance.new("Player")
		player.Name = name
		player.UserId = userId
		player.DisplayName = name
		roblox.Instance.new("Backpack").Parent = player
		roblox.Instance.new("PlayerGui").Parent = player
		roblox.Instance.new("PlayerScripts").Parent = player
		player.Parent = players
		engine.syncDerived(player)
		engine.signalFor(players, "PlayerAdded"):Fire(player)
		return player
	end

	-- a player with a simple R15-ish character standing at `position`
	function session:addPlayer(name: string, userId: number, position: any?)
		local players = dataModel:GetService("Players")
		local player = roblox.Instance.new("Player")
		player.Name = name
		player.UserId = userId
		player.DisplayName = name
		player.Parent = players
		local backpack = roblox.Instance.new("Backpack")
		backpack.Parent = player
		local playerGui = roblox.Instance.new("PlayerGui")
		playerGui.Parent = player
		local origin = position or roblox.Vector3.new(0, 3, 0)
		local character = roblox.Instance.new("Model")
		character.Name = name
		local function limb(limbName: string, size: any, offset: any)
			local part = roblox.Instance.new("Part")
			part.Name = limbName
			part.Size = size
			part.CFrame = roblox.CFrame.new(origin + offset)
			part.Parent = character
			return part
		end
		local root = limb("HumanoidRootPart", roblox.Vector3.new(2, 2, 1), roblox.Vector3.zero)
		limb("UpperTorso", roblox.Vector3.new(2, 1.6, 1), roblox.Vector3.new(0, 0.5, 0))
		limb("Head", roblox.Vector3.new(1.2, 1.2, 1.2), roblox.Vector3.new(0, 1.9, 0))
		limb("RightHand", roblox.Vector3.new(0.3, 0.3, 0.3), roblox.Vector3.new(1.5, -0.8, 0))
		limb("LeftHand", roblox.Vector3.new(0.3, 0.3, 0.3), roblox.Vector3.new(-1.5, -0.8, 0))
		local humanoid = roblox.Instance.new("Humanoid")
		humanoid.Parent = character
		character.PrimaryPart = root
		character.Parent = workspace
		player.Character = character
		return player, character
	end

	return session
end

return place
