--[[
	SoundResolver (ModuleScript)
	Location: ReplicatedStorage/Modules/SoundResolver

	Turns a SoundConfig path ("Camera.Shutter") into concrete playback data:
	sound id, optional bank region, randomised playback speed and volume.

	Resolution order (first source that has not FAILED wins):
	  1. entry.Ids                  explicit uploaded variations
	  2. SoundConfig.Loops[...]     dedicated loop file (looped entries)
	  3. sound bank region          SoundService attribute "SoundBank_<Bank>"
	                                or SoundConfig.Banks[<Bank>] + SoundBankLayout
	  4. entry.Fallback             built-in Roblox content sound
	Asset ids reported as failed (ContentProvider / Sound.Loaded timeout) are
	skipped from then on, so a broken upload never silences the game.
]]

local SoundService = game:GetService("SoundService")

local Config = script.Parent.Parent:WaitForChild("Config")
local SoundConfig = require(Config:WaitForChild("SoundConfig"))
local SoundBankLayout = require(Config:WaitForChild("SoundBankLayout"))

local SoundResolver = {}
SoundResolver.Failed = {} :: { [string]: boolean }

local random = Random.new()

local function isValidId(id: any): boolean
	return type(id) == "string" and id ~= "" and id ~= "rbxassetid://0" and (string.find(id, "^rbxasset") ~= nil or string.find(id, "^http") ~= nil)
end

local function usable(id: any): boolean
	return isValidId(id) and not SoundResolver.Failed[id]
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
	Source: string, -- "Ids" | "Loop" | "Bank" | "Fallback"
}

-- Bank id: SoundService attribute (set in Studio, no code) or SoundConfig.Banks.
function SoundResolver.GetBankId(bank: string): string?
	local attribute = SoundService:GetAttribute("SoundBank_" .. bank)
	if type(attribute) == "number" and attribute > 0 then
		return "rbxassetid://" .. tostring(attribute)
	elseif type(attribute) == "string" and attribute ~= "" then
		return if tonumber(attribute) then "rbxassetid://" .. attribute else attribute
	end
	local configured = SoundConfig.Banks[bank]
	return if isValidId(configured) then configured else nil
end

function SoundResolver.MarkFailed(id: string)
	SoundResolver.Failed[id] = true
end

function SoundResolver.IsFailed(id: string): boolean
	return SoundResolver.Failed[id] == true
end

-- Every candidate asset id of a path, in resolution order (for preloading).
function SoundResolver.Candidates(path: string): { { Id: string, Source: string } }
	local entry = SoundConfig.Get(path)
	local list = {}
	if not entry then
		return list
	end
	for _, id in ipairs(entry.Ids) do
		if isValidId(id) then
			table.insert(list, { Id = id, Source = "Ids" })
		end
	end
	if entry.Loop and isValidId(SoundConfig.Loops[entry.Loop]) then
		table.insert(list, { Id = SoundConfig.Loops[entry.Loop], Source = "Loop" })
	end
	local layout = SoundBankLayout.Sounds[path]
	if layout then
		local bankId = SoundResolver.GetBankId(layout.Bank)
		if bankId then
			table.insert(list, { Id = bankId, Source = "Bank" })
		end
	end
	if entry.Fallback then
		table.insert(list, { Id = entry.Fallback[1], Source = "Fallback" })
	end
	return list
end

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
		if usable(id) then
			table.insert(valid, id)
		end
	end
	if #valid > 0 then
		local index = if variation then ((variation - 1) % #valid) + 1 else random:NextInteger(1, #valid)
		return { SoundId = valid[index], Region = nil, Speed = pitch, Volume = volume, Entry = entry, Length = 0, Source = "Ids" }
	end

	-- 2. dedicated loop file
	if entry.Loop and usable(SoundConfig.Loops[entry.Loop]) then
		return { SoundId = SoundConfig.Loops[entry.Loop], Region = nil, Speed = pitch, Volume = volume, Entry = entry, Length = 0, Source = "Loop" }
	end

	-- 3. region inside an uploaded sound bank
	local layout = SoundBankLayout.Sounds[path]
	if layout and #layout.Regions > 0 then
		local bankId = SoundResolver.GetBankId(layout.Bank)
		if bankId and usable(bankId) then
			local regions = layout.Regions
			local index = if variation then ((variation - 1) % #regions) + 1 else random:NextInteger(1, #regions)
			local region = regions[index]
			return {
				SoundId = bankId,
				Region = NumberRange.new(region[1], region[2]),
				Speed = pitch,
				Volume = volume,
				Entry = entry,
				Length = region[2] - region[1],
				Source = "Bank",
			}
		end
	end

	-- 4. built-in fallback so nothing is ever silent
	if entry.Fallback and usable(entry.Fallback[1]) then
		return {
			SoundId = entry.Fallback[1],
			Region = nil,
			Speed = entry.Fallback[2] * pitch,
			Volume = volume,
			Entry = entry,
			Length = 0,
			Source = "Fallback",
		}
	end
	return nil
end

return SoundResolver
