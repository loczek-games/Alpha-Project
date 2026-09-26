--[[
	Module loader shared by the Lune tools (bake, validate).

	Runs ModuleScripts from src/ outside Roblox: `script`, `game` and
	`require(script.Parent.X)` / `require(ReplicatedStorage:WaitForChild("X"))`
	resolve to files under src/ (by their Rojo path), and the Roblox datatypes
	come from @lune/roblox.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local SRC = "src"

local GLOBALS = {
	"Instance", "Vector3", "Vector2", "CFrame", "Color3", "UDim", "UDim2", "Enum", "NumberSequence",
	"NumberSequenceKeypoint", "ColorSequence", "ColorSequenceKeypoint", "NumberRange", "Font", "BrickColor",
	"Rect", "PhysicalProperties",
}

local dataModel = roblox.Instance.new("DataModel")
local cache: { [string]: any } = {}

local function fileFor(path: string): string?
	for _, suffix in { ".lua", ".luau" } do
		if fs.isFile(SRC .. "/" .. path .. suffix) then
			return SRC .. "/" .. path .. suffix
		end
	end
	return nil
end

local loadModule: (path: string) -> any

-- A fake `script` hierarchy that resolves require(script.Parent.X) and
-- require(script.Parent:WaitForChild("X")) to files under src/.
local function join(a: string, b: string): string
	return if a == "" then b else a .. "/" .. b
end

local function node(path: string): any
	return setmetatable({ __path = path }, {
		__index = function(_, key: string)
			if key == "Parent" then
				return node(string.match(path, "^(.*)/[^/]+$") or "")
			elseif key == "WaitForChild" or key == "FindFirstChild" then
				return function(_, name: string)
					return node(join(path, name))
				end
			elseif key == "GetService" then
				return function(_, name: string)
					return node(name)
				end
			elseif key == "Name" then
				return string.match(path, "([^/]+)$")
			end
			return node(join(path, key))
		end,
	})
end

loadModule = function(path: string): any
	if cache[path] ~= nil then
		return cache[path]
	end
	local file = fileFor(path)
	assert(file, "[bake] module not found: " .. path)
	local env = {}
	for _, name in GLOBALS do
		env[name] = (roblox :: any)[name]
	end
	env.game = node("")
	env.workspace = dataModel:GetService("Workspace")
	env.script = node(path)
	env.require = function(target: any)
		if type(target) == "table" and target.__path then
			return loadModule(target.__path)
		end
		error("[bake] unsupported require target")
	end
	env.warn = function(...)
		print("[warn]", ...)
	end
	local chunk = luau.load(fs.readFile(file), { debugName = file, environment = env })
	local result = chunk()
	cache[path] = result
	return result
end

return {
	load = loadModule,
	dataModel = dataModel,
	fileFor = fileFor,
}
