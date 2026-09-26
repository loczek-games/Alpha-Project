--[[
	SoundResolver (ModuleScript)
	Location: ReplicatedStorage/Modules/SoundResolver

	Turns a SoundConfig path ("Camera.Shutter") into concrete playback data:
	sound id, optional bank region, randomised playback speed and volume.
	Resolution order: explicit Ids -> loop file -> sound bank region -> built-in
	fallback. Random variation keeps repeated sounds from feeling copy-pasted.
]]

local Config = script.Parent.Parent:WaitForChild("Config")
local SoundConfig = require(Config:WaitForChild("SoundConfig"))
local SoundBankLayout = require(Config:WaitForChild("SoundBankLayout"))

local SoundResolver = {}

local random = Random.new()

local function isValidId(id: any): boolean
	return type(id) == "string" and id ~= "" and id ~= "rbxassetid://0"
end

local function randomIn(range: { number }?): number
	if not range then
		return 1
	end
	local low, high = range[1], range[2] or range[1]
	if high <= low then
		return low
	end
	return low + random:NextNumber() * (high - low)
end

export type Resolved = {
	SoundId: string,
	Region: NumberRange?,
	Speed: number,
	Volume: number,
	Entry: any,
	Length: number,
}

function SoundResolver.Resolve(path: string, variation: number?): Resolved?
	local entry = SoundConfig.Get(path)
	if not entry then
		return nil
	end
	local pitch = randomIn(entry.Pitch)
	local volume = entry.Volume * (1 + (random:NextNumber() * 2 - 1) * (entry.VolumeJitter or 0))

	-- 1. explicit uploaded variations
	local valid = {}
	for _, id in ipairs(entry.Ids) do
		if isValidId(id) then
			table.insert(valid, id)
		end
	end
	if #valid > 0 then
		local index = if variation then ((variation - 1) % #valid) + 1 else random:NextInteger(1, #valid)
		return { SoundId = valid[index], Region = nil, Speed = pitch, Volume = volume, Entry = entry, Length = 0 }
	end

	-- 2. dedicated loop file
	if entry.Loop and isValidId(SoundConfig.Loops[entry.Loop]) then
		return { SoundId = SoundConfig.Loops[entry.Loop], Region = nil, Speed = pitch, Volume = volume, Entry = entry, Length = 0 }
	end

	-- 3. region inside an uploaded sound bank
	local layout = SoundBankLayout.Sounds[path]
	if layout and isValidId(SoundConfig.Banks[layout.Bank]) and #layout.Regions > 0 then
		local regions = layout.Regions
		local index = if variation then ((variation - 1) % #regions) + 1 else random:NextInteger(1, #regions)
		local region = regions[index]
		return {
			SoundId = SoundConfig.Banks[layout.Bank],
			Region = NumberRange.new(region[1], region[2]),
			Speed = pitch,
			Volume = volume,
			Entry = entry,
			Length = region[2] - region[1],
		}
	end

	-- 4. built-in fallback so equipment is never silent
	if entry.Fallback then
		return {
			SoundId = entry.Fallback[1],
			Region = nil,
			Speed = entry.Fallback[2] * pitch,
			Volume = volume,
			Entry = entry,
			Length = 0,
		}
	end
	return nil
end

return SoundResolver
