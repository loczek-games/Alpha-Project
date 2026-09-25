--[[
	Cleaner (ModuleScript)
	Location: ReplicatedStorage/Modules/Cleaner

	Collects connections, instances, tweens, threads and callbacks so a
	temporary thing (an anomaly, an event, a UI effect) can be torn down with
	a single :Clean() call. Prevents leaks of anomaly instances and loops.
]]

local Cleaner = {}
Cleaner.__index = Cleaner

function Cleaner.new()
	return setmetatable({ _items = {}, _cleaning = false }, Cleaner)
end

function Cleaner:Add<T>(item: T): T
	table.insert(self._items, item)
	return item
end

local function cleanItem(item: any)
	local kind = typeof(item)
	if kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "Instance" then
		if item:IsA("Tween") then
			item:Cancel()
		end
		item:Destroy()
	elseif kind == "function" then
		local ok, err = pcall(item)
		if not ok then
			warn("[Cleaner] cleanup callback failed:", err)
		end
	elseif kind == "thread" then
		if coroutine.status(item) ~= "dead" then
			pcall(task.cancel, item)
		end
	elseif kind == "table" then
		if type(item.Disconnect) == "function" then
			item:Disconnect()
		elseif type(item.Clean) == "function" then
			item:Clean()
		elseif type(item.Destroy) == "function" then
			item:Destroy()
		end
	end
end

function Cleaner:Clean()
	if self._cleaning then
		return
	end
	self._cleaning = true
	local items = self._items
	self._items = {}
	for index = #items, 1, -1 do
		cleanItem(items[index])
	end
	self._cleaning = false
end

Cleaner.Destroy = Cleaner.Clean

return Cleaner
