--[[
	Format (ModuleScript)
	Location: ReplicatedStorage/Modules/Format

	Text formatting helpers shared by server announcements and client UI.
]]

local Format = {}

function Format.Number(value: number): string
	local negative = value < 0
	local s = tostring(math.floor(math.abs(value)))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return (negative and "-" or "") .. formatted
end

function Format.Money(value: number): string
	return "$" .. Format.Number(value)
end

function Format.Short(value: number): string
	local abs = math.abs(value)
	if abs >= 1e9 then
		return (string.format("%.1fB", value / 1e9):gsub("%.0B", "B"))
	elseif abs >= 1e6 then
		return (string.format("%.1fM", value / 1e6):gsub("%.0M", "M"))
	elseif abs >= 1e4 then
		return (string.format("%.1fK", value / 1e3):gsub("%.0K", "K"))
	end
	return Format.Number(value)
end

function Format.Time(seconds: number): string
	seconds = math.max(0, math.floor(seconds + 0.5))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function Format.Stars(count: number, max: number?): string
	local total = max or 5
	count = math.clamp(math.floor(count), 0, total)
	return string.rep("★", count) .. string.rep("☆", total - count)
end

function Format.TimeAgo(timestamp: number): string
	local delta = math.max(0, os.time() - timestamp)
	if delta < 60 then
		return "just now"
	elseif delta < 3600 then
		return string.format("%dm ago", delta // 60)
	elseif delta < 86400 then
		return string.format("%dh ago", delta // 3600)
	end
	return string.format("%dd ago", delta // 86400)
end

function Format.Date(timestamp: number): string
	local ok, result = pcall(function()
		return DateTime.fromUnixTimestamp(timestamp):FormatUniversalTime("ll", "en-us")
	end)
	return ok and result or ""
end

return Format
