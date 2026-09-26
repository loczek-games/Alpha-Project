--[[
	Rng (ModuleScript)
	Location: ReplicatedStorage/Modules/Rng

	Small deterministic random generator (xorshift32). World builders use it
	so the Dead Mall is decorated the same way every time it is built,
	whether it is built at runtime or baked with Lune.
]]

local Rng = {}
Rng.__index = Rng

export type Rng = typeof(setmetatable({} :: { State: number }, Rng))

function Rng.new(seed: number): Rng
	local state = math.floor(math.abs(seed)) % 4294967296
	if state == 0 then
		state = 2463534242
	end
	return setmetatable({ State = state }, Rng)
end

function Rng.NextInteger32(self: Rng): number
	local x = self.State
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self.State = x
	return x
end

-- [0, 1)
function Rng.Next(self: Rng): number
	return self:NextInteger32() / 4294967296
end

function Rng.Range(self: Rng, low: number, high: number): number
	return low + (high - low) * self:Next()
end

-- inclusive integer range
function Rng.Int(self: Rng, low: number, high: number): number
	return low + math.floor(self:Next() * (high - low + 1))
end

function Rng.Chance(self: Rng, probability: number): boolean
	return self:Next() < probability
end

function Rng.Pick<T>(self: Rng, list: { T }): T
	return list[self:Int(1, #list)]
end

function Rng.Sign(self: Rng): number
	return if self:Next() < 0.5 then -1 else 1
end

return Rng
