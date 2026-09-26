--[[
	Offline validation of the game data (Lune script).

	Checks that the configs, the baked maps and the code agree with each
	other, so a broken reference shows up here instead of as a silent
	failure in a play test:

	  * every anomaly has a behavior module, a valid appearance, and at least
	    one free fixture / spawn marker in its allowed zones on the baked map
	  * the ceiling crawler node graph is connected (with the same 30-stud
	    line-of-sight links the server builds)
	  * every sound path written in the code exists in SoundConfig
	  * the lobby has its queue zones, stations and dark room fixtures
	  * every equipment item builds a model; shop products point at real items

	Usage (from the repository root, after `lune run tools/bake/bake.luau`):
	    lune run tools/test/validate.luau [--verbose]

	Exit code 1 when an error is found (warnings do not fail).
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local loader = require("../lib/loader")

local Vector3 = roblox.Vector3

local VERBOSE = table.find(process.args, "--verbose") ~= nil
local errors, warnings, passed = 0, 0, 0

local function fail(message: string)
	errors += 1
	print("  [FAIL] " .. message)
end

local function warn(message: string)
	warnings += 1
	print("  [WARN] " .. message)
end

local function ok(message: string)
	passed += 1
	print("  [ ok ] " .. message)
end

local function section(title: string)
	print("\n== " .. title .. " ==")
end

local function loadModel(path: string): any
	assert(fs.isFile(path), path .. " is missing - run `lune run tools/bake/bake.luau` first")
	return roblox.deserializeModel(fs.readFile(path))[1]
end

local function listFiles(dir: string, out: { string }?): { string }
	local list = out or {}
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			listFiles(path, list)
		elseif string.match(name, "%.luau?$") then
			table.insert(list, path)
		end
	end
	return list
end

local AnomalyConfig = loader.load("ReplicatedStorage/Config/AnomalyConfig")
local SoundConfig = loader.load("ReplicatedStorage/Config/SoundConfig")
local EquipmentConfig = loader.load("ReplicatedStorage/Config/EquipmentConfig")
local MonetizationConfig = loader.load("ReplicatedStorage/Config/MonetizationConfig")
local CosmeticsConfig = loader.load("ReplicatedStorage/Config/CosmeticsConfig")
local MapConfig = loader.load("ReplicatedStorage/Config/MapConfig")

local mall = loadModel("assets/baked/DeadMall.rbxm")
local lobby = loadModel("assets/baked/LobbyHQ.rbxm")

---------------------------------------------------------------------------
-- map helpers (same rules as MapService)
---------------------------------------------------------------------------

local zoneParts = {}
local zonesFolder = mall:FindFirstChild("Zones")
if zonesFolder then
	for _, part in zonesFolder:GetChildren() do
		if part:IsA("BasePart") then
			table.insert(zoneParts, part)
		end
	end
end

local function zoneAt(position: any): string?
	for _, bounds in zoneParts do
		local p = bounds.CFrame:PointToObjectSpace(position)
		local half = bounds.Size / 2
		if math.abs(p.X) <= half.X and math.abs(p.Z) <= half.Z and p.Y >= -half.Y - 2 and p.Y <= half.Y + 2 then
			return bounds.Name
		end
	end
	return nil
end

local function positionOf(instance: any): any
	if instance:IsA("BasePart") then
		return instance.CFrame.Position
	elseif instance:IsA("Model") then
		if instance.PrimaryPart then
			return instance.PrimaryPart.CFrame.Position
		end
		for _, d in instance:GetDescendants() do
			if d:IsA("BasePart") then
				return d.CFrame.Position
			end
		end
	end
	return nil
end

local tagged: { [string]: { any } } = {}
for _, d in mall:GetDescendants() do
	for _, tag in d:GetTags() do
		tagged[tag] = tagged[tag] or {}
		table.insert(tagged[tag], d)
	end
end

local nodes = mall:FindFirstChild("AnomalyNodes")
local spawns = nodes and nodes:FindFirstChild("Spawns")
local markers = {}
if spawns then
	for _, marker in spawns:GetChildren() do
		if marker:IsA("BasePart") then
			table.insert(markers, marker)
		end
	end
end

---------------------------------------------------------------------------
section("Dead Mall layout")
---------------------------------------------------------------------------

for _, name in { "Zones", "AnomalyNodes", "PlayerSpawns", "PickupSpots", "Interactables" } do
	if mall:FindFirstChild(name) then
		ok("folder " .. name)
	else
		fail("map folder missing: " .. name)
	end
end
local zoneIds = {}
for _, part in zoneParts do
	zoneIds[part.Name] = true
end
local mapDef = MapConfig.Get("DeadMall")
if mapDef and mapDef.Zones then
	for _, zone in mapDef.Zones do
		local id = if type(zone) == "table" then zone.Id else zone
		if id and not zoneIds[id] then
			fail("MapConfig zone " .. tostring(id) .. " has no bounds part in the baked map")
		end
	end
end
ok(string.format("%d zones, %d spawn markers", #zoneParts, #markers))
local playerSpawns = mall:FindFirstChild("PlayerSpawns")
if playerSpawns and #playerSpawns:GetChildren() >= 6 then
	ok(#playerSpawns:GetChildren() .. " player spawns (6 investigators)")
else
	fail("fewer than 6 player spawns")
end

---------------------------------------------------------------------------
section("Anomalies")
---------------------------------------------------------------------------

local appearanceSource = fs.readFile("src/ServerScriptService/Anomalies/Appearance.lua")
local appearanceNames = {}
local librarySource = string.match(appearanceSource, "Appearance%.Library = (%b{})") or ""
for name in string.gmatch(librarySource, "\n%s*([%w_]+) = {") do
	appearanceNames[name] = true
end

local seen = {}
local total = 0
for _, def in AnomalyConfig.GetSorted() do
	total += 1
	local label = def.Id
	if seen[def.Id] then
		fail(label .. ": duplicate id")
	end
	seen[def.Id] = true
	if not loader.fileFor("ServerScriptService/Anomalies/Behaviors/" .. def.Behavior) then
		fail(label .. ": behavior module " .. tostring(def.Behavior) .. " does not exist")
	end
	local params = def.Params or {}
	if params.Appearance and not appearanceNames[params.Appearance] then
		fail(label .. ": unknown appearance " .. params.Appearance)
	end
	for _, key in { "Loop", "Sound", "AttackSound" } do
		local path = params[key]
		if type(path) == "string" and string.find(path, "%.") and not SoundConfig.Get(path) then
			fail(label .. ": Params." .. key .. " sound " .. path .. " is not in SoundConfig")
		end
	end
	local spawn = def.Spawn or {}
	for _, zone in spawn.Zones or {} do
		if not zoneIds[zone] then
			fail(label .. ": spawn zone " .. zone .. " does not exist on the map")
		end
	end
	local function inZones(instance: any): boolean
		if not spawn.Zones then
			return true
		end
		local position = positionOf(instance)
		local zone = position and zoneAt(position)
		return zone ~= nil and table.find(spawn.Zones, zone) ~= nil
	end
	local where = {}
	if spawn.Fixture then
		local count = 0
		for _, instance in tagged[spawn.Fixture] or {} do
			if inZones(instance) then
				count += 1
			end
		end
		table.insert(where, string.format("%d x %s", count, spawn.Fixture))
		if count == 0 then
			fail(label .. ": no '" .. spawn.Fixture .. "' fixture in zones " .. table.concat(spawn.Zones or { "any" }, ","))
		end
	end
	if spawn.Kinds then
		local count = 0
		for _, marker in markers do
			local zone = marker:GetAttribute("Zone")
			if table.find(spawn.Kinds, marker:GetAttribute("Kind")) and (spawn.Zones == nil or table.find(spawn.Zones, zone)) then
				count += 1
			end
		end
		table.insert(where, string.format("%d markers (%s)", count, table.concat(spawn.Kinds, "/")))
		if count == 0 then
			fail(label .. ": no spawn marker of kind " .. table.concat(spawn.Kinds, "/") .. " in zones " .. table.concat(spawn.Zones or { "any" }, ","))
		end
	end
	if #where > 0 then
		passed += 1
	end
end
ok(string.format("%d anomalies checked (behaviors, appearances, spawn points)", total))
if total < 30 then
	fail("fewer than 30 anomalies in AnomalyConfig")
end
for name in appearanceNames do
	local folder = "src/ServerStorage/AnomalyModels/" .. name
	if ({ AbnormalTitan = true, SmilingEntity = true, PossessedEntity = true, SlackerEntity = true })[name] and not fs.isDir(folder) then
		warn("placeholder folder missing: " .. folder)
	end
end

---------------------------------------------------------------------------
section("Ceiling crawler graph")
---------------------------------------------------------------------------

local ceiling = nodes and nodes:FindFirstChild("CeilingCrawlerNodes")
local ceilingNodes = {}
if ceiling then
	for _, node in ceiling:GetChildren() do
		if node:IsA("BasePart") then
			table.insert(ceilingNodes, { Part = node, Position = node.CFrame.Position, Links = {} })
		end
	end
end
if #ceilingNodes < 20 then
	fail("only " .. #ceilingNodes .. " CeilingCrawlerNodes")
else
	-- blockers: solid parts (the server raycasts with RespectCanCollide)
	local blockers = {}
	for _, d in mall:GetDescendants() do
		if d:IsA("BasePart") and d.CanQuery and d.CanCollide and not d:IsDescendantOf(nodes) and not (zonesFolder and d:IsDescendantOf(zonesFolder)) then
			local half = d.Size / 2
			local extent = half.Magnitude
			local p = d.CFrame.Position
			table.insert(blockers, { Part = d, CFrame = d.CFrame, Half = half, Min = p - Vector3.new(extent, extent, extent), Max = p + Vector3.new(extent, extent, extent) })
		end
	end
	local function blocked(from: any, to: any): any
		local lo = Vector3.new(math.min(from.X, to.X), math.min(from.Y, to.Y), math.min(from.Z, to.Z))
		local hi = Vector3.new(math.max(from.X, to.X), math.max(from.Y, to.Y), math.max(from.Z, to.Z))
		for _, box in blockers do
			if box.Max.X < lo.X or box.Min.X > hi.X or box.Max.Y < lo.Y or box.Min.Y > hi.Y or box.Max.Z < lo.Z or box.Min.Z > hi.Z then
				continue
			end
			-- segment vs oriented box (slab test in the box's space)
			local a = box.CFrame:PointToObjectSpace(from)
			local b = box.CFrame:PointToObjectSpace(to)
			local d = b - a
			local t0, t1 = 0, 1
			local hit = true
			for _, axis in { "X", "Y", "Z" } do
				local origin, delta, half = (a :: any)[axis], (d :: any)[axis], (box.Half :: any)[axis]
				if math.abs(delta) < 1e-9 then
					if origin < -half or origin > half then
						hit = false
						break
					end
				else
					local e0 = (-half - origin) / delta
					local e1 = (half - origin) / delta
					if e0 > e1 then
						e0, e1 = e1, e0
					end
					t0 = math.max(t0, e0)
					t1 = math.min(t1, e1)
					if t0 > t1 then
						hit = false
						break
					end
				end
			end
			if hit then
				return box
			end
		end
		return nil
	end
	local links = 0
	local blockedBy = {}
	for i = 1, #ceilingNodes do
		local a = ceilingNodes[i]
		for j = i + 1, #ceilingNodes do
			local b = ceilingNodes[j]
			local distance = (b.Position - a.Position).Magnitude
			if distance <= 30 and distance > 0.1 and math.abs(b.Position.Y - a.Position.Y) <= 4 then
				local offset = Vector3.new(0, 0.6, 0)
				local blocker = blocked(a.Position - offset, b.Position - offset)
				if not blocker then
					table.insert(a.Links, b)
					table.insert(b.Links, a)
					links += 1
				elseif VERBOSE and a.Part:GetAttribute("Zone") == b.Part:GetAttribute("Zone") then
					local key = blocker.Part:GetFullName()
					blockedBy[key] = (blockedBy[key] or 0) + 1
				end
			end
		end
	end
	if VERBOSE then
		local list = {}
		for name, count in blockedBy do
			table.insert(list, { name, count })
		end
		table.sort(list, function(x, y)
			return x[2] > y[2]
		end)
		for index = 1, math.min(25, #list) do
			print(string.format("         blocked %3d x by %s", list[index][2], list[index][1]))
		end
	end
	-- connected components
	local component = {}
	local sizes = {}
	for _, start in ceilingNodes do
		if component[start] then
			continue
		end
		local id = #sizes + 1
		sizes[id] = 0
		local stack = { start }
		component[start] = id
		while #stack > 0 do
			local node = table.remove(stack)
			sizes[id] += 1
			for _, other in node.Links do
				if not component[other] then
					component[other] = id
					table.insert(stack, other)
				end
			end
		end
	end
	table.sort(sizes, function(x, y)
		return x > y
	end)
	local isolated = 0
	for _, node in ceilingNodes do
		if #node.Links == 0 then
			isolated += 1
		end
	end
	if VERBOSE then
		for _, node in ceilingNodes do
			if #node.Links == 0 then
				local p = node.Position
				print(string.format("         isolated node in %s at (%.0f, %.0f, %.0f)", tostring(node.Part:GetAttribute("Zone")), p.X, p.Y, p.Z))
			end
		end
	end
	local share = sizes[1] / #ceilingNodes
	local summary = string.format("%d nodes, %d links, %d component(s), largest %d (%.0f%%), %d isolated", #ceilingNodes, links, #sizes, sizes[1], share * 100, isolated)
	-- rooms are separate islands (walls); the crawler relocates between them
	-- while unseen, but each island must be big enough to stalk in
	local tiny = 0
	for _, size in sizes do
		if size < 3 then
			tiny += size
		end
	end
	if isolated > #ceilingNodes * 0.05 or tiny > #ceilingNodes * 0.1 then
		fail("ceiling graph has too many stranded nodes: " .. summary)
	elseif isolated > 0 then
		warn("ceiling graph: " .. summary)
	else
		ok("ceiling graph: " .. summary)
	end
end

---------------------------------------------------------------------------
section("Sounds referenced in code")
---------------------------------------------------------------------------

local categories = {}
for _, path in SoundConfig.AllPaths() do
	categories[string.match(path, "^([^%.]+)")] = true
end
local missing = {}
local checked = 0
for _, file in listFiles("src") do
	local source = fs.readFile(file)
	for path, after in string.gmatch(source, '"([%a][%w]*%.[%w%.]+)"(%s*%.?%.?)') do
		local category = string.match(path, "^([^%.]+)")
		local concatenated = string.find(after, "..", 1, true) ~= nil
		if categories[category] and not concatenated and not string.match(path, "%.$") and not string.match(path, "%.lua$") then
			checked += 1
			if not SoundConfig.Get(path) then
				missing[path] = (missing[path] or "") .. " " .. string.gsub(file, "^src/", "")
			end
		end
	end
end
local missingCount = 0
for path, files in missing do
	missingCount += 1
	fail("sound " .. path .. " is not in SoundConfig (used in" .. files .. ")")
end
if missingCount == 0 then
	ok(string.format("%d sound references resolve (%d paths in SoundConfig)", checked, #SoundConfig.AllPaths()))
end
local fallbackless = {}
for _, path in SoundConfig.AllPaths() do
	local def = SoundConfig.Get(path)
	if def and def.Loop and not def.Fallback and not def.Ids then
		table.insert(fallbackless, path)
	end
end
if #fallbackless > 0 then
	warn("loops without a built-in fallback: " .. table.concat(fallbackless, ", "))
end

---------------------------------------------------------------------------
section("Lobby HQ")
---------------------------------------------------------------------------

local lobbyTags: { [string]: number } = {}
for _, d in lobby:GetDescendants() do
	for _, tag in d:GetTags() do
		lobbyTags[tag] = (lobbyTags[tag] or 0) + 1
	end
end
for tag, minimum in { MissionZone = 1, MissionBoard = 1, LobbyStation = 5, DarkRoomFrame = 10, DarkRoomNameplate = 1, DarkRoomEntrance = 1, DarkRoomExit = 1 } do
	local count = lobbyTags[tag] or 0
	if count >= minimum then
		ok(string.format("%s x%d", tag, count))
	else
		fail(string.format("lobby needs %d '%s', found %d", minimum, tag, count))
	end
end
if lobby:FindFirstChild("Safelight", true) then
	ok("dark room safelight (decor colour target)")
else
	fail("dark room Safelight part missing (DarkRoomController decor)")
end

---------------------------------------------------------------------------
section("Equipment, shop and cosmetics")
---------------------------------------------------------------------------

local EquipmentModels = loader.load("ReplicatedStorage/Modules/EquipmentModels")
for id, item in EquipmentConfig.Items do
	if item.Wearable then
		continue -- worn, not held: no viewmodel
	end
	local built, model = pcall(EquipmentModels.Build, id)
	if not built then
		fail("EquipmentModels.Build(" .. id .. ") errored: " .. tostring(model))
	elseif not model then
		warn("no 3D model for equipment " .. id)
	else
		-- a Tool can only be held when it has a "Handle" part and everything
		-- else is welded to it (EquipmentService moves these parts into the Tool)
		local tool = roblox.Instance.new("Tool")
		tool.RequiresHandle = true
		tool.CanBeDropped = false
		tool.ManualActivationOnly = true
		for _, child in model:GetChildren() do
			child.Parent = tool
		end
		local handle = tool:FindFirstChild("Handle")
		-- (Lune hands out a new wrapper per property read: compare with ==)
		local welded = {}
		for _, d in tool:GetDescendants() do
			if d:IsA("WeldConstraint") and d.Part0 == handle and d.Part1 then
				table.insert(welded, d.Part1)
			end
		end
		local function isWelded(part: any): boolean
			for _, other in welded do
				if other == part then
					return true
				end
			end
			return false
		end
		local problems = {}
		if not handle or not handle:IsA("BasePart") then
			table.insert(problems, "no Handle part")
		end
		for _, d in tool:GetDescendants() do
			if d:IsA("BasePart") then
				if d.Anchored then
					table.insert(problems, d.Name .. " is anchored")
				end
				if d ~= handle and not isWelded(d) then
					table.insert(problems, d.Name .. " is not welded to Handle")
				end
			end
		end
		if #problems > 0 then
			fail("equipment tool " .. id .. " cannot be held: " .. table.concat(problems, ", "))
		else
			passed += 1
		end
	end
end
for id, skin in CosmeticsConfig.Skins do
	if not EquipmentConfig.Items[skin.Item] then
		fail("skin " .. id .. " targets unknown item " .. tostring(skin.Item))
	end
	local built, result = pcall(EquipmentModels.Build, skin.Item, skin)
	if not built then
		fail("skin " .. id .. " does not build: " .. tostring(result))
	end
end
ok("equipment models + skins build")
for passId, item in MonetizationConfig.PassEquipment or {} do
	for _, equipment in (if type(item) == "table" then item else { item }) do
		if not EquipmentConfig.Items[equipment] then
			fail("pass " .. passId .. " grants unknown equipment " .. tostring(equipment))
		end
	end
end
local unset = {}
for id, pass in MonetizationConfig.GamePasses or {} do
	if not pass.Id or pass.Id == 0 then
		table.insert(unset, "pass " .. id)
	end
end
for id, product in MonetizationConfig.Products or {} do
	if not product.Id or product.Id == 0 then
		table.insert(unset, "product " .. id)
	end
	if product.Cosmetic and not (CosmeticsConfig.Skins[product.Cosmetic] or CosmeticsConfig.Decor[product.Cosmetic]) then
		fail("product " .. id .. " sells unknown cosmetic " .. product.Cosmetic)
	end
end
if #unset > 0 then
	table.sort(unset)
	warn(#unset .. " passes/products still have Id 0 (create them on the Creator Dashboard): " .. table.concat(unset, ", "))
end

---------------------------------------------------------------------------
section("Instance properties set through helper tables")
---------------------------------------------------------------------------
-- Helpers such as UIKit.new("TextLabel", { ... }) assign every key of a table
-- to a new instance through an `any` cast, so the type checker cannot see a
-- misspelled or non-existent property. Roblox throws at runtime ("X is not a
-- valid member of TextLabel") - here every key is checked against the API.

local reflection = roblox.getReflectionDatabase()

local function hasProperty(className: string, property: string): boolean?
	local class = reflection:GetClass(className)
	if not class then
		return nil
	end
	while class do
		if class.Properties[property] then
			return true
		end
		class = class.Superclass and reflection:GetClass(class.Superclass)
	end
	return false
end

-- keys at depth 1 of the table literal starting at `open` (index of "{")
local function tableKeys(source: string, open: number): ({ string }, number)
	local keys = {}
	local depth = 0
	local i = open
	local length = #source
	while i <= length do
		local c = string.sub(source, i, i)
		if c == '"' or c == "'" then
			local close = i + 1
			while close <= length and string.sub(source, close, close) ~= c do
				if string.sub(source, close, close) == "\\" then
					close += 1
				end
				close += 1
			end
			i = close
		elseif c == "-" and string.sub(source, i, i + 1) == "--" then
			local close = string.find(source, "\n", i, true) or length
			i = close
		elseif c == "{" or c == "(" or c == "[" then
			depth += 1
			if depth == 2 and c == "{" and false then
				break
			end
		elseif c == "}" or c == ")" or c == "]" then
			depth -= 1
			if depth == 0 then
				return keys, i
			end
		elseif depth == 1 then
			local key, rest = string.match(source, "^([%a_][%w_]*)%s*=([^=])", i)
			local before = string.sub(source, i - 1, i - 1)
			if key and rest and not string.match(before, "[%w_%.]") then
				table.insert(keys, key)
				i += #key - 1
			end
		end
		i += 1
	end
	return keys, length
end

-- call pattern -> class (nil = first string argument) + keys the helper consumes itself
local HELPERS = {
	{ Pattern = "UIKit%.new%(%s*\"(%w+)\"%s*,%s*{", Class = nil },
	{ Pattern = "[^%w_%.]new%(%s*\"(%w+)\"%s*,%s*{", Class = nil },
	{ Pattern = "UIKit%.Label%(%s*{", Class = "TextLabel" },
	{ Pattern = "UIKit%.Frame%(%s*{", Class = "Frame" },
	{ Pattern = "UIKit%.Card%(%s*{", Class = "Frame" },
	{ Pattern = "UIKit%.Button%(%s*{", Class = "TextButton", Skip = { CornerRadius = true, NoStroke = true } },
	{ Pattern = "[^%w_%.]label%([^{}]-,%s*{", Class = "TextLabel", Skip = { MaxTextSize = true }, Files = { "CaseFileUI" } },
	{ Pattern = "[^%w_%.]frame%([^{}]-,%s*{", Class = "Frame", Files = { "JumpscareController" } },
	{ Pattern = "Kit%.Part%([^{}]-,%s*{", Class = "Part" },
}

local checkedCalls, badProperties = 0, 0
for _, file in listFiles("src") do
	local source = fs.readFile(file)
	for _, helper in HELPERS do
		if helper.Files then
			local match = false
			for _, name in helper.Files do
				if string.find(file, name, 1, true) then
					match = true
				end
			end
			if not match then
				continue
			end
		end
		local start = 1
		while true do
			local first, last, captured = string.find(source, helper.Pattern, start)
			if not first then
				break
			end
			start = last + 1
			local className = helper.Class or captured
			local keys = tableKeys(source, last)
			checkedCalls += 1
			local line = select(2, string.gsub(string.sub(source, 1, first), "\n", "")) + 1
			for _, key in keys do
				if key == "Parent" or (helper.Skip and helper.Skip[key]) then
					continue
				end
				local has = hasProperty(className, key)
				if has == nil then
					warn(string.format("%s:%d unknown class %s", file, line, className))
					break
				elseif not has then
					badProperties += 1
					fail(string.format("%s:%d  %s has no property '%s'", string.gsub(file, "^src/", ""), line, className, key))
				end
			end
		end
	end
end
-- LightingController presets are applied key by key too
do
	local source = fs.readFile("src/StarterPlayer/StarterPlayerScripts/Controllers/LightingController.lua")
	local targets = { Lighting = "Lighting", Atmosphere = "Atmosphere", Grade = "ColorCorrectionEffect", Glow = "BloomEffect" }
	for name, className in targets do
		local start = 1
		while true do
			local first, last = string.find(source, "\n%s*" .. name .. " = {", start)
			if not first then
				break
			end
			start = last + 1
			checkedCalls += 1
			for _, key in (tableKeys(source, last)) do
				if not hasProperty(className, key) then
					badProperties += 1
					fail(string.format("LightingController preset %s has no property '%s'", className, key))
				end
			end
		end
	end
end
if badProperties == 0 then
	ok(string.format("%d helper-built instances only set real properties", checkedCalls))
end

---------------------------------------------------------------------------
section("UI built at join")
---------------------------------------------------------------------------
-- Instances from @lune/roblox reject unknown properties exactly like Roblox,
-- so building the screens here catches errors that would leave players on a
-- black loading screen.

do
	local CaseFileUI = loader.load("ReplicatedStorage/Modules/CaseFileUI")
	local map = MapConfig.Maps.DeadMall
	local holder = roblox.Instance.new("Frame")
	local built, result = pcall(CaseFileUI.new, holder, {
		Case = map.Case,
		Name = map.Name,
		Location = map.Location,
		Status = map.Status,
		LastActivity = map.LastActivity,
		Danger = map.Danger,
		Tip = "test",
		Headline = "LOADING INVESTIGATION",
	})
	if built then
		result.Alive = false
		ok("CaseFileUI loading screen builds (" .. #holder:GetDescendants() .. " instances)")
	else
		fail("CaseFileUI.new errors - the loading screen would stay black: " .. tostring(result))
	end
end

---------------------------------------------------------------------------

print(string.format("\n%d checks passed, %d warnings, %d errors", passed, warnings, errors))
if errors > 0 then
	process.exit(1)
end
