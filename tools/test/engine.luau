--[[
	Minimal headless Roblox engine for Lune play tests.

	@lune/roblox gives real Instances (hierarchy, properties, attributes -
	and it rejects unknown properties like Roblox does), but no engine: no
	events, no WaitForChild, no physics helpers. This fills in just enough of
	the engine for the game's server and client modules to run together in
	one process:

	  * Signals: instance events (ChildAdded, AncestryChanged, attribute and
	    property changed signals, Tool.Equipped, Player.CharacterAdded ...)
	    fire from engine.step(), which diffs what scripts are watching -
	    close to Roblox's deferred signal behaviour.
	  * RemoteEvents / RemoteFunctions between one server and one client.
	  * WaitForChild, Model pivots, BasePart.Position, Humanoid tools,
	    Players.LocalPlayer, RunService (Heartbeat / RenderStepped / BindToRenderStep).

	Anything not implemented errors loudly, which is what a test wants.
]]

local roblox = require("@lune/roblox")
local task = require("@lune/task")

local Instance = roblox.Instance
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

local engine = {}

-- Lune creates a new EnumItem object per access, so `KEYS[Enum.KeyCode.One]`
-- tables never match. engine.Enum hands out one shared object per item,
-- like Roblox does (scripts and tests must both use it).
local enumCache: { [string]: any } = {}
local function internItem(item: any): any
	local key = tostring(item)
	local cached = enumCache[key]
	if cached == nil then
		enumCache[key] = item
		cached = item
	end
	return cached
end
local enumTypes: { [string]: any } = {}
engine.Enum = setmetatable({}, {
	__index = function(_, enumName: string)
		local cached = enumTypes[enumName]
		if cached then
			return cached
		end
		local real = (roblox.Enum :: any)[enumName]
		local proxy = setmetatable({}, {
			__index = function(_, itemName: string)
				if itemName == "GetEnumItems" then
					return function()
						local list = {}
						for _, item in real:GetEnumItems() do
							table.insert(list, internItem(item))
						end
						return list
					end
				end
				return internItem(real[itemName])
			end,
			__tostring = function()
				return "Enum." .. enumName
			end,
		})
		enumTypes[enumName] = proxy
		return proxy
	end,
})
engine.internEnum = internItem

engine.localPlayer = nil :: any
engine.errors = {} :: { string }

---------------------------------------------------------------------------
-- Signals
---------------------------------------------------------------------------

local Signal = {}
Signal.__index = Signal

function Signal.new(name: string?)
	return setmetatable({ Name = name or "Signal", Handlers = {} }, Signal)
end

function Signal:Connect(fn)
	local connection = { Connected = true }
	local handlers = self.Handlers
	table.insert(handlers, connection)
	connection.Fn = fn
	function connection.Disconnect()
		connection.Connected = false
		local index = table.find(handlers, connection)
		if index then
			table.remove(handlers, index)
		end
	end
	return connection
end

function Signal:Once(fn)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

function Signal:Wait()
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:Fire(...)
	for _, connection in table.clone(self.Handlers) do
		if connection.Connected then
			local args = table.pack(...)
			for i = 1, args.n do
				args[i] = engine.wrap(args[i])
			end
			task.spawn(function()
				local ok, err = pcall(connection.Fn, table.unpack(args, 1, args.n))
				if not ok then
					local message = string.format("[%s handler] %s", self.Name, tostring(err))
					table.insert(engine.errors, message)
					print("  [engine] error in " .. message)
				end
			end)
		end
	end
end

engine.Signal = Signal

---------------------------------------------------------------------------
-- Instance identity (Lune hands out a new wrapper per property read)
---------------------------------------------------------------------------

local ID_ATTRIBUTE = "__engineId"
local registry: { [number]: any } = {}
local nextId = 0

local function idOf(instance: any): number
	local readable, id = pcall(function()
		return instance:GetAttribute(ID_ATTRIBUTE)
	end)
	if not readable then
		-- destroyed: Lune refuses every access; give it a throwaway id
		nextId += 1
		return -nextId
	end
	if type(id) == "number" and registry[id] == instance then
		return id
	end
	-- new, or a Clone() that copied its original's id
	nextId += 1
	instance:SetAttribute(ID_ATTRIBUTE, nextId)
	registry[nextId] = instance
	return nextId
end
engine.idOf = idOf

---------------------------------------------------------------------------
-- Instance proxies: one Lua object per Instance, like Roblox
---------------------------------------------------------------------------
-- Game code runs against proxies so tables keyed by instances
-- (Participants[player], State[player] ...) behave as in Roblox. Engine code
-- and implemented methods keep working with the raw Lune instances.

local proxies: { [number]: any } = {}
local rawOf = setmetatable({}, { __mode = "k" })
local ProxyMeta = {}
local methodCache: { [string]: any } = {}

local function unwrap(value: any): any
	local raw = rawOf[value]
	if raw ~= nil then
		return raw
	end
	return value
end
engine.unwrap = unwrap

local wrap
local function wrapMany(...)
	local results = table.pack(...)
	for i = 1, results.n do
		local value = results[i]
		if type(value) == "table" and rawOf[value] == nil and getmetatable(value) == nil then
			-- arrays / dictionaries of instances (GetChildren, GetTagged ...)
			local copy = {}
			for k, v in value do
				copy[k] = wrap(v)
			end
			results[i] = copy
		else
			results[i] = wrap(value)
		end
	end
	return table.unpack(results, 1, results.n)
end

wrap = function(value: any): any
	local kind = typeof(value)
	if kind == "Instance" then
		local id = idOf(value)
		local proxy = proxies[id]
		if proxy == nil then
			proxy = setmetatable({}, ProxyMeta)
			rawOf[proxy] = value
			proxies[id] = proxy
		else
			-- keep the freshest wrapper (same instance either way)
			rawOf[proxy] = value
		end
		return proxy
	elseif kind == "EnumItem" then
		return engine.internEnum(value)
	end
	return value
end
engine.wrap = wrap

ProxyMeta.__index = function(proxy, key)
	local raw = rawOf[proxy]
	local value = raw[key]
	if type(value) == "function" then
		local cached = methodCache[key]
		if not cached then
			cached = function(self, ...)
				local args = table.pack(...)
				for i = 1, args.n do
					args[i] = unwrap(args[i])
				end
				local target = rawOf[self] or self
				return wrapMany(target[key](target, table.unpack(args, 1, args.n)))
			end
			methodCache[key] = cached
		end
		return cached
	end
	return wrapMany(value)
end
ProxyMeta.__newindex = function(proxy, key, value)
	rawOf[proxy][key] = unwrap(value)
end
ProxyMeta.__tostring = function(proxy)
	return tostring(rawOf[proxy])
end
ProxyMeta.__type = "Instance"
engine.isProxy = function(value)
	return rawOf[value] ~= nil
end
engine.typeof = function(value)
	if rawOf[value] ~= nil then
		return "Instance"
	end
	return typeof(value)
end

-- per instance: { [signalName]: Signal } + snapshots for diffing
local signals: { [number]: { [string]: any } } = {}
local watched: { [number]: { Instance: any, Children: { any }?, Attributes: { [string]: any }?, Properties: { [string]: any }, Parent: any } } = {}

local function watch(instance: any)
	local id = idOf(instance)
	local record = watched[id]
	if not record then
		record = { Instance = instance, Properties = {} }
		watched[id] = record
	end
	return record
end

-- { [id]: instance } for fast diffs
local function idSet(list: { any }): { [number]: any }
	local result = {}
	for _, item in list do
		result[idOf(item)] = item
	end
	return result
end

local function signalFor(instance: any, name: string)
	local id = idOf(instance)
	local set = signals[id]
	if not set then
		set = {}
		signals[id] = set
	end
	local signal = set[name]
	if not signal then
		signal = Signal.new(instance.Name .. "." .. name)
		set[name] = signal
		local record = watch(instance)
		if name == "ChildAdded" or name == "ChildRemoved" then
			record.Children = record.Children or idSet(instance:GetChildren())
		elseif name == "DescendantAdded" or name == "DescendantRemoving" then
			record.Descendants = record.Descendants or idSet(instance:GetDescendants())
		elseif name == "AncestryChanged" or name == "Destroying" then
			record.Parent = instance.Parent
			record.HasParent = true
		elseif name == "AttributeChanged" or string.sub(name, 1, 10) == "Attribute:" then
			record.Attributes = record.Attributes or instance:GetAttributes()
		elseif string.sub(name, 1, 9) == "Property:" then
			local property = string.sub(name, 10)
			local ok, value = pcall(function()
				return instance[property]
			end)
			record.Properties[property] = if ok then { value } else { nil }
		end
	end
	return signal
end
engine.signalFor = signalFor

-- Fires the events for everything that changed since the last step.
function engine.step()
	for id, record in table.clone(watched) do
		local alive = pcall(function()
			return record.Instance.Name
		end)
		if not alive then
			-- destroyed: fire Destroying / AncestryChanged once, then forget it
			local set = signals[id] or {}
			if record.HasParent and record.Parent ~= nil then
				if set.AncestryChanged then
					set.AncestryChanged:Fire(record.Instance, nil)
				end
				if set.Destroying then
					set.Destroying:Fire()
				end
			end
			watched[id] = nil
			signals[id] = nil
			continue
		end
		local instance = record.Instance
		local set = signals[id] or {}
		if record.Children then
			local now = idSet(instance:GetChildren())
			for childId, child in now do
				if record.Children[childId] == nil and set.ChildAdded then
					set.ChildAdded:Fire(child)
				end
			end
			for childId, child in record.Children do
				if now[childId] == nil and set.ChildRemoved then
					set.ChildRemoved:Fire(child)
				end
			end
			record.Children = now
		end
		if record.Descendants then
			local now = idSet(instance:GetDescendants())
			for dId, d in now do
				if record.Descendants[dId] == nil and set.DescendantAdded then
					set.DescendantAdded:Fire(d)
				end
			end
			for dId, d in record.Descendants do
				if now[dId] == nil and set.DescendantRemoving then
					set.DescendantRemoving:Fire(d)
				end
			end
			record.Descendants = now
		end
		if record.HasParent then
			local parent = instance.Parent
			if parent ~= record.Parent then
				record.Parent = parent
				if set.AncestryChanged then
					set.AncestryChanged:Fire(instance, parent)
				end
				if parent == nil and set.Destroying then
					set.Destroying:Fire()
				end
			end
		end
		if record.Attributes then
			local now = instance:GetAttributes()
			local changed = {}
			for key, value in now do
				if record.Attributes[key] ~= value then
					changed[key] = true
				end
			end
			for key in record.Attributes do
				if now[key] == nil then
					changed[key] = true
				end
			end
			record.Attributes = now
			for key in changed do
				if key ~= ID_ATTRIBUTE then
					if set.AttributeChanged then
						set.AttributeChanged:Fire(key)
					end
					if set["Attribute:" .. key] then
						set["Attribute:" .. key]:Fire()
					end
				end
			end
		end
		for property, box in record.Properties do
			local ok, value = pcall(function()
				return instance[property]
			end)
			if ok and value ~= box[1] then
				box[1] = value
				local signal = set["Property:" .. property]
				if signal then
					signal:Fire()
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- Instance API
---------------------------------------------------------------------------

for _, name in { "ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving", "AncestryChanged", "Destroying", "AttributeChanged" } do
	roblox.implementProperty("Instance", name, function(instance)
		return signalFor(instance, name)
	end)
end

roblox.implementMethod("Instance", "GetAttributeChangedSignal", function(instance, attribute: string)
	return signalFor(instance, "Attribute:" .. attribute)
end)

roblox.implementMethod("Instance", "GetPropertyChangedSignal", function(instance, property: string)
	return signalFor(instance, "Property:" .. property)
end)

roblox.implementMethod("Instance", "WaitForChild", function(instance, name: string, timeout: number?)
	local started = os.clock()
	while true do
		local child = instance:FindFirstChild(name)
		if child then
			return child
		end
		if timeout and os.clock() - started >= timeout then
			return nil
		end
		if os.clock() - started > 5 and not timeout then
			error(string.format("WaitForChild(%q) on %s would wait forever", name, instance:GetFullName()))
		end
		task.wait(0.02)
	end
end)

-- one extra "Changed" style signal that scripts read as a property
roblox.implementProperty("Instance", "Changed", function(instance)
	return signalFor(instance, "Changed")
end)

-- BasePart.Position / Orientation-free helpers
roblox.implementProperty("BasePart", "Position", function(part)
	return part.CFrame.Position
end, function(part, value)
	part.CFrame = CFrame.new(value) * part.CFrame.Rotation
end)

local function pivotOf(model: any): any
	if model:IsA("BasePart") then
		return model.CFrame
	end
	local primary = model.PrimaryPart
	if primary then
		return primary.CFrame
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			return d.CFrame
		end
	end
	return CFrame.new()
end

roblox.implementMethod("PVInstance", "GetPivot", function(instance)
	return pivotOf(instance)
end)

roblox.implementMethod("PVInstance", "PivotTo", function(instance, target)
	if instance:IsA("BasePart") then
		instance.CFrame = target
		return
	end
	local current = pivotOf(instance)
	local delta = target * current:Inverse()
	for _, d in instance:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
end)

roblox.implementMethod("Model", "GetBoundingBox", function(model)
	local minV, maxV = nil, nil
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local p = d.CFrame.Position
			local h = d.Size / 2
			local lo, hi = p - h, p + h
			minV = if minV then Vector3.new(math.min(minV.X, lo.X), math.min(minV.Y, lo.Y), math.min(minV.Z, lo.Z)) else lo
			maxV = if maxV then Vector3.new(math.max(maxV.X, hi.X), math.max(maxV.Y, hi.Y), math.max(maxV.Z, hi.Z)) else hi
		end
	end
	if not minV then
		return CFrame.new(), Vector3.zero
	end
	return CFrame.new((minV + maxV) / 2), maxV - minV
end)

-- Properties Lune knows but has no default for ("missing default value"):
-- filled in when an instance is created (engine.newInstance) and refreshed
-- before every frame (engine.syncDerived). Derived ones (Position,
-- WorldPosition) are recomputed from the CFrame each frame.
local DEFAULTS = {
	Humanoid = { Health = 100, MaxHealth = 100, WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2, HipHeight = 2, UseJumpPower = true, AutoRotate = true, PlatformStand = false, Sit = false },
	Sound = { IsLoaded = true, TimeLength = 1, IsPlaying = false, IsPaused = false, PlaybackLoudness = 0, TimePosition = 0 },
}
local function fillDefaults(d: any)
	for class, values in DEFAULTS do
		if d:IsA(class) then
			for property, value in values do
				local ok = pcall(function()
					return d[property]
				end)
				if not ok then
					pcall(function()
						d[property] = value
					end)
				end
			end
		end
	end
	if d:IsA("Humanoid") then
		pcall(function()
			local _ = d.FloorMaterial
		end)
		if not pcall(function()
			return d.FloorMaterial
		end) then
			d.FloorMaterial = roblox.Enum.Material.Concrete
		end
		if not pcall(function()
			return d.MoveDirection
		end) then
			d.MoveDirection = Vector3.zero
		end
	elseif d:IsA("GuiBase2d") then
		if not pcall(function()
			return d.AbsoluteSize
		end) then
			pcall(function()
				d.AbsoluteSize = roblox.Vector2.new(1280, 720)
				d.AbsolutePosition = roblox.Vector2.new(0, 0)
			end)
		end
	elseif d:IsA("UIGridStyleLayout") then
		if not pcall(function()
			return d.AbsoluteContentSize
		end) then
			pcall(function()
				d.AbsoluteContentSize = roblox.Vector2.new(400, 400)
			end)
		end
	end
end
engine.fillDefaults = fillDefaults

function engine.newInstance(className: string, parent: any?)
	parent = unwrap(parent)
	local instance = Instance.new(className)
	fillDefaults(instance)
	if instance:IsA("BasePart") then
		instance.Position = instance.CFrame.Position
		instance.AssemblyLinearVelocity = Vector3.zero
		instance.AssemblyAngularVelocity = Vector3.zero
	end
	if parent then
		instance.Parent = parent
	end
	return wrap(instance)
end

function engine.syncDerived(root: any)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			local cframe = d.CFrame
			d.Position = cframe.Position
			local ok = pcall(function()
				return d.AssemblyLinearVelocity
			end)
			if not ok then
				d.AssemblyLinearVelocity = Vector3.zero
				d.AssemblyAngularVelocity = Vector3.zero
			end
		elseif d:IsA("Attachment") then
			local parent = d.Parent
			if parent and parent:IsA("BasePart") then
				local world = parent.CFrame * d.CFrame
				d.WorldCFrame = world
				d.WorldPosition = world.Position
			end
		else
			fillDefaults(d)
		end
	end
end

-- GUI input events (fired by tests: engine.click(button))
for _, name in { "Activated", "MouseButton1Down", "MouseButton1Up", "MouseButton1Click", "MouseButton2Click" } do
	roblox.implementProperty("GuiButton", name, function(button)
		return signalFor(button, "Gui." .. name)
	end)
end
for _, name in { "MouseEnter", "MouseLeave", "InputBegan", "InputEnded", "InputChanged" } do
	roblox.implementProperty("GuiObject", name, function(gui)
		return signalFor(gui, "Gui." .. name)
	end)
end
roblox.implementProperty("TextBox", "FocusLost", function(box)
	return signalFor(box, "Gui.FocusLost")
end)
function engine.click(button: any)
	for _, name in { "MouseButton1Down", "MouseButton1Up", "MouseButton1Click", "Activated" } do
		signalFor(button, "Gui." .. name):Fire()
	end
end

-- Tools
for _, name in { "Equipped", "Unequipped", "Activated", "Deactivated" } do
	roblox.implementProperty("Tool", name, function(tool)
		return signalFor(tool, "Tool." .. name)
	end)
end

local function ownerOf(character: any): any
	local players = engine.game and engine.game:GetService("Players")
	if not players then
		return nil
	end
	for _, player in players:GetChildren() do
		if player:IsA("Player") and player.Character == character then
			return player
		end
	end
	return nil
end

roblox.implementMethod("Humanoid", "UnequipTools", function(humanoid)
	local character = humanoid.Parent
	local player = character and ownerOf(character)
	local backpack = player and player:FindFirstChildOfClass("Backpack")
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			child.Parent = backpack
			signalFor(child, "Tool.Unequipped"):Fire()
		end
	end
end)

roblox.implementMethod("Humanoid", "EquipTool", function(humanoid, tool)
	assert(tool and tool:IsA("Tool"), "EquipTool expects a Tool")
	local character = humanoid.Parent
	if tool.RequiresHandle then
		local handle = tool:FindFirstChild("Handle")
		assert(handle and handle:IsA("BasePart"), "EquipTool: " .. tool.Name .. " has no Handle")
	end
	humanoid:UnequipTools()
	tool.Parent = character
	-- the grip: handle placed at the right hand
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local handle = tool:FindFirstChild("Handle")
	if hand and handle then
		local target = hand.CFrame * CFrame.new(0, -0.15, 0) * CFrame.Angles(-math.pi / 2, 0, 0) * tool.Grip:Inverse()
		tool:PivotTo(target * (handle.CFrame:Inverse() * tool:GetPivot()))
	end
	signalFor(tool, "Tool.Equipped"):Fire()
end)

roblox.implementMethod("Humanoid", "Move", function() end)
roblox.implementMethod("Humanoid", "MoveTo", function() end)
roblox.implementProperty("Humanoid", "MoveDirection", function()
	return Vector3.zero
end)
roblox.implementProperty("Humanoid", "FloorMaterial", function()
	return roblox.Enum.Material.Concrete
end)

-- Players
roblox.implementMethod("Players", "GetPlayers", function(players)
	local list = {}
	for _, child in players:GetChildren() do
		if child:IsA("Player") then
			table.insert(list, child)
		end
	end
	return list
end)
roblox.implementMethod("Players", "GetPlayerByUserId", function(players, userId)
	for _, child in players:GetChildren() do
		if child:IsA("Player") and child.UserId == userId then
			return child
		end
	end
	return nil
end)
for _, name in { "PlayerAdded", "PlayerRemoving" } do
	roblox.implementProperty("Players", name, function(players)
		return signalFor(players, name)
	end)
end
for _, name in { "CharacterAdded", "CharacterRemoving", "Chatted" } do
	roblox.implementProperty("Player", name, function(player)
		return signalFor(player, name)
	end)
end

-- Remotes: one server + one client (engine.localPlayer)
roblox.implementProperty("RemoteEvent", "OnServerEvent", function(remote)
	return signalFor(remote, "OnServerEvent")
end)
roblox.implementProperty("RemoteEvent", "OnClientEvent", function(remote)
	return signalFor(remote, "OnClientEvent")
end)
roblox.implementProperty("UnreliableRemoteEvent", "OnServerEvent", function(remote)
	return signalFor(remote, "OnServerEvent")
end)
roblox.implementProperty("UnreliableRemoteEvent", "OnClientEvent", function(remote)
	return signalFor(remote, "OnClientEvent")
end)
engine.remoteLog = {} :: { string }
local function logRemote(direction: string, remote: any, first: any)
	table.insert(engine.remoteLog, string.format("%s %s %s", direction, remote.Name, tostring(first)))
end
for _, class in { "RemoteEvent", "UnreliableRemoteEvent" } do
	roblox.implementMethod(class, "FireServer", function(remote, ...)
		logRemote("C->S", remote, (...))
		signalFor(remote, "OnServerEvent"):Fire(engine.localPlayer, ...)
	end)
	roblox.implementMethod(class, "FireClient", function(remote, player, ...)
		logRemote("S->C", remote, (...))
		if player == engine.localPlayer then
			signalFor(remote, "OnClientEvent"):Fire(...)
		end
	end)
	roblox.implementMethod(class, "FireAllClients", function(remote, ...)
		logRemote("S->*", remote, (...))
		signalFor(remote, "OnClientEvent"):Fire(...)
	end)
end
roblox.implementProperty("RemoteFunction", "OnServerInvoke", function(remote)
	return engine.invokeHandlers and engine.invokeHandlers[idOf(remote)]
end, function(remote, handler)
	engine.invokeHandlers = engine.invokeHandlers or {}
	engine.invokeHandlers[idOf(remote)] = handler
end)
roblox.implementMethod("RemoteFunction", "InvokeServer", function(remote, ...)
	local handler = engine.invokeHandlers and engine.invokeHandlers[idOf(remote)]
	assert(handler, "no OnServerInvoke for " .. remote.Name)
	return handler(engine.localPlayer, ...)
end)

---------------------------------------------------------------------------
-- More engine behaviour used by the game
---------------------------------------------------------------------------

local function signalProperty(class: string, name: string)
	roblox.implementProperty(class, name, function(instance)
		return signalFor(instance, class .. "." .. name)
	end)
end
engine.signalProperty = signalProperty

-- sounds: "play" instantly, report loaded
for _, name in { "Ended", "Played", "Loaded", "Paused", "Resumed", "Stopped", "DidLoop" } do
	signalProperty("Sound", name)
end
roblox.implementMethod("Sound", "Play", function(sound)
	engine.soundsPlayed = (engine.soundsPlayed or 0) + 1
	signalFor(sound, "Sound.Played"):Fire(sound.SoundId)
end)
roblox.implementMethod("Sound", "Stop", function(sound)
	signalFor(sound, "Sound.Stopped"):Fire(sound.SoundId)
end)
roblox.implementMethod("Sound", "Pause", function() end)
roblox.implementMethod("Sound", "Resume", function() end)

-- prompts, clicks, touches, bindables, chat commands
for _, name in { "Triggered", "TriggerEnded", "PromptButtonHoldBegan", "PromptButtonHoldEnded", "PromptShown", "PromptHidden" } do
	signalProperty("ProximityPrompt", name)
end
for _, name in { "MouseClick", "MouseHoverEnter", "MouseHoverLeave" } do
	signalProperty("ClickDetector", name)
end
for _, name in { "Touched", "TouchEnded" } do
	signalProperty("BasePart", name)
end
signalProperty("BindableEvent", "Event")
roblox.implementMethod("BindableEvent", "Fire", function(event, ...)
	signalFor(event, "BindableEvent.Event"):Fire(...)
end)
signalProperty("TextChatCommand", "Triggered")
signalProperty("TextChannel", "MessageReceived")
signalProperty("Humanoid", "Died")
signalProperty("Humanoid", "StateChanged")
signalProperty("Humanoid", "Running")
signalProperty("Humanoid", "HealthChanged")
signalProperty("Humanoid", "AnimationPlayed")

roblox.implementMethod("ReplicatedFirst", "RemoveDefaultLoadingScreen", function() end)
engine.coreGui = {} :: { [string]: boolean }
roblox.implementMethod("StarterGui", "SetCoreGuiEnabled", function(_, coreGuiType, enabled)
	engine.coreGui[tostring(coreGuiType)] = enabled
end)
roblox.implementMethod("StarterGui", "GetCoreGuiEnabled", function()
	return true
end)
roblox.implementMethod("StarterGui", "SetCore", function() end)
roblox.implementMethod("StarterGui", "GetCore", function()
	return nil
end)

-- players
roblox.implementMethod("Player", "Kick", function(player, message)
	table.insert(engine.errors, "[Kick] " .. player.Name .. ": " .. tostring(message))
end)
roblox.implementMethod("Player", "RequestStreamAroundAsync", function() end)
roblox.implementMethod("Player", "GetFriendsOnline", function()
	return {}
end)
roblox.implementMethod("Player", "IsFriendsWith", function()
	return false
end)
roblox.implementMethod("Player", "GetRankInGroup", function()
	return 0
end)
roblox.implementMethod("Player", "IsInGroup", function()
	return false
end)
roblox.implementMethod("Player", "GetJoinData", function()
	return {}
end)
roblox.implementMethod("Player", "HasAppearanceLoaded", function()
	return true
end)
roblox.implementMethod("Player", "LoadCharacter", function(player)
	assert(engine.spawnCharacter, "no character spawner")
	engine.spawnCharacter(player)
end)
roblox.implementMethod("Player", "GetMouse", function()
	return { Hit = CFrame.new(), Target = nil, Button1Down = Signal.new("Mouse.Button1Down"), Icon = "" }
end)
roblox.implementMethod("Players", "GetUserThumbnailAsync", function()
	return "rbxthumb://type=AvatarHeadShot&id=1&w=150&h=150", true
end)
roblox.implementMethod("Players", "GetNameFromUserIdAsync", function(_, userId)
	return "User" .. tostring(userId)
end)
roblox.implementMethod("Players", "GetHumanoidDescriptionFromUserId", function()
	return Instance.new("HumanoidDescription")
end)
roblox.implementMethod("Players", "CreateHumanoidModelFromDescription", function()
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Parent = model
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end)

-- humanoids and animation
roblox.implementMethod("Humanoid", "GetAppliedDescription", function()
	return Instance.new("HumanoidDescription")
end)
roblox.implementMethod("Humanoid", "ApplyDescription", function() end)
roblox.implementMethod("Humanoid", "ChangeState", function() end)
roblox.implementMethod("Humanoid", "SetStateEnabled", function() end)
roblox.implementMethod("Humanoid", "GetState", function()
	return Enum.HumanoidStateType.Running
end)
roblox.implementMethod("Humanoid", "TakeDamage", function(humanoid, amount)
	humanoid.Health = math.max(0, humanoid.Health - amount)
end)
local function animationTrack(animation: any)
	local track = { Animation = animation, IsPlaying = false, Length = 1, Looped = false, Speed = 1, TimePosition = 0, WeightCurrent = 0, Priority = Enum.AnimationPriority.Core }
	track.Stopped = Signal.new("Track.Stopped")
	track.Ended = Signal.new("Track.Ended")
	track.KeyframeReached = Signal.new("Track.KeyframeReached")
	function track:Play()
		self.IsPlaying = true
	end
	function track:Stop()
		self.IsPlaying = false
		self.Stopped:Fire()
	end
	function track:AdjustSpeed(speed)
		self.Speed = speed
	end
	function track:AdjustWeight() end
	function track:GetMarkerReachedSignal(name)
		return Signal.new("Marker." .. tostring(name))
	end
	function track:Destroy() end
	return track
end
roblox.implementMethod("Animator", "LoadAnimation", function(_, animation)
	return animationTrack(animation)
end)
roblox.implementMethod("Humanoid", "LoadAnimation", function(_, animation)
	return animationTrack(animation)
end)
roblox.implementMethod("Animator", "GetPlayingAnimationTracks", function()
	return {}
end)
roblox.implementMethod("Humanoid", "GetPlayingAnimationTracks", function()
	return {}
end)

-- physics ownership / forces (no physics here)
roblox.implementMethod("BasePart", "SetNetworkOwner", function() end)
roblox.implementMethod("BasePart", "SetNetworkOwnershipAuto", function() end)
roblox.implementMethod("BasePart", "GetNetworkOwner", function()
	return nil
end)
roblox.implementMethod("BasePart", "CanSetNetworkOwnership", function()
	return true
end)
roblox.implementMethod("BasePart", "ApplyImpulse", function() end)
roblox.implementMethod("BasePart", "ApplyAngularImpulse", function() end)
roblox.implementMethod("BasePart", "GetMass", function(part)
	return part.Size.X * part.Size.Y * part.Size.Z * 0.7
end)
roblox.implementMethod("BasePart", "GetConnectedParts", function()
	return {}
end)
roblox.implementMethod("BasePart", "BreakJoints", function() end)
roblox.implementMethod("Model", "ScaleTo", function() end)
roblox.implementMethod("Model", "GetScale", function()
	return 1
end)
roblox.implementMethod("Model", "GetExtentsSize", function(model)
	local _, size = model:GetBoundingBox()
	return size
end)
roblox.implementMethod("Instance", "GetActor", function()
	return nil
end)

-- cameras
roblox.implementMethod("Camera", "ScreenPointToRay", function(cam)
	return roblox.Ray.new(cam.CFrame.Position, cam.CFrame.LookVector)
end)
roblox.implementMethod("Camera", "ViewportPointToRay", function(cam)
	return roblox.Ray.new(cam.CFrame.Position, cam.CFrame.LookVector)
end)

---------------------------------------------------------------------------
-- Services that are not Instances in Lune: plain mocks
---------------------------------------------------------------------------

function engine.runService(isServer: boolean)
	local service = {
		Heartbeat = Signal.new("Heartbeat"),
		RenderStepped = Signal.new("RenderStepped"),
		Stepped = Signal.new("Stepped"),
		Bound = {} :: { [string]: { Priority: number, Fn: (number) -> () } },
	}
	function service:IsServer()
		return isServer
	end
	function service:IsClient()
		return not isServer
	end
	function service:IsStudio()
		return true
	end
	function service:IsRunning()
		return true
	end
	function service:BindToRenderStep(name: string, priority: number, fn)
		self.Bound[name] = { Priority = priority, Fn = fn }
	end
	function service:UnbindFromRenderStep(name: string)
		self.Bound[name] = nil
	end
	-- one frame: RenderStep bindings (client), then Heartbeat
	function service:Frame(dt: number)
		local list = {}
		for name, binding in self.Bound do
			table.insert(list, { Name = name, Priority = binding.Priority, Fn = binding.Fn })
		end
		table.sort(list, function(a, b)
			return a.Priority < b.Priority
		end)
		for _, binding in list do
			local ok, err = pcall(binding.Fn, dt)
			if not ok then
				table.insert(engine.errors, "[RenderStep " .. binding.Name .. "] " .. tostring(err))
			end
		end
		self.RenderStepped:Fire(dt)
		self.Heartbeat:Fire(dt)
	end
	return service
end

function engine.userInputService()
	local service = {
		InputBegan = Signal.new("InputBegan"),
		InputEnded = Signal.new("InputEnded"),
		InputChanged = Signal.new("InputChanged"),
		LastInputTypeChanged = Signal.new("LastInputTypeChanged"),
		TouchEnabled = false,
		KeyboardEnabled = true,
		MouseEnabled = true,
		GamepadEnabled = false,
		MouseBehavior = roblox.Enum.MouseBehavior.Default,
		MouseIconEnabled = true,
	}
	function service:GetLastInputType()
		return roblox.Enum.UserInputType.Keyboard
	end
	function service:IsKeyDown()
		return false
	end
	function service:GetFocusedTextBox()
		return nil
	end
	-- simulate a key press
	function service:Press(keyCode: any, userInputType: any?)
		self.InputBegan:Fire({ KeyCode = internItem(keyCode), UserInputType = internItem(userInputType or roblox.Enum.UserInputType.Keyboard), Position = Vector3.zero }, false)
	end
	return service
end

function engine.tweenService()
	local service = {}
	function service:Create(instance, _info, goals)
		local tween = { Completed = Signal.new("Tween.Completed"), PlaybackState = roblox.Enum.PlaybackState.Begin }
		function tween:Play()
			for key, value in goals do
				instance[key] = value
			end
			self.PlaybackState = roblox.Enum.PlaybackState.Completed
			self.Completed:Fire(roblox.Enum.PlaybackState.Completed)
		end
		function tween:Cancel() end
		function tween:Pause() end
		return tween
	end
	return service
end

-- Anything else: a permissive stub that records calls (for services the
-- scenario does not care about). Indexing returns more stubs; calling returns nil.
function engine.stub(name: string)
	local calls = {}
	local stub
	stub = setmetatable({ __calls = calls }, {
		__index = function(_, key)
			if key == "__name" then
				return name
			end
			local child = engine.stub(name .. "." .. tostring(key))
			rawset(stub, key, child)
			return child
		end,
		__call = function(_, ...)
			table.insert(calls, { ... })
			return nil
		end,
	})
	return stub
end

return engine
