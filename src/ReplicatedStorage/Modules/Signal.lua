--[[
	Signal (ModuleScript)
	Location: ReplicatedStorage/Modules/Signal

	Minimal pure-Luau event object used for client state changes.
]]

local Signal = {}
Signal.__index = Signal

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(callback: (...any) -> ())
	local handler = { Callback = callback, Connected = true }
	table.insert(self._handlers, handler)
	local signal = self
	local connection = {}
	connection.Connected = true
	function connection.Disconnect()
		if not handler.Connected then
			return
		end
		handler.Connected = false
		connection.Connected = false
		local index = table.find(signal._handlers, handler)
		if index then
			table.remove(signal._handlers, index)
		end
	end
	return connection
end

function Signal:Fire(...)
	for _, handler in ipairs(table.clone(self._handlers)) do
		if handler.Connected then
			task.spawn(handler.Callback, ...)
		end
	end
end

return Signal
