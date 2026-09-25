--[[
	PhotoMath (ModuleScript)
	Location: ReplicatedStorage/Modules/PhotoMath

	Pure functions for photo quality + rewards. Used by the server to grade
	photos. A valid photo ALWAYS earns at least 1 star.
]]

local Config = script.Parent.Parent:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))

local PhotoMath = {}

--[[
	distance         studs from the photographer's head to the anomaly
	maxDistance      the anomaly's allowed photo distance (after upgrades)
	angle            degrees from the centre of the view (after size leniency)
	maxAngle         allowed degrees (after upgrades)
	lifeFraction     0..1 how far through its lifetime the anomaly was
]]
function PhotoMath.ComputeStars(distance: number, maxDistance: number, angle: number, maxAngle: number, lifeFraction: number)
	local photo = GameConfig.Photo

	local ideal = maxDistance * photo.IdealDistanceFraction
	local distanceScore
	if distance <= ideal then
		distanceScore = 1
	else
		distanceScore = 1 - (distance - ideal) / math.max(maxDistance - ideal, 1)
	end
	distanceScore = math.clamp(distanceScore, 0, 1)

	local perfect = photo.PerfectAngleDeg
	local centerScore
	if angle <= perfect then
		centerScore = 1
	else
		centerScore = 1 - (angle - perfect) / math.max(maxAngle - perfect, 1)
	end
	centerScore = math.clamp(centerScore, 0, 1)

	local timingScore = if lifeFraction <= photo.TimingBonusWindow then 1 else 0

	local raw = 1 + distanceScore * 1.8 + centerScore * 1.8 + timingScore * 0.5
	local stars = math.clamp(math.floor(raw + 0.5), 1, 5)

	return stars, {
		Distance = distanceScore,
		Center = centerScore,
		Timing = timingScore,
	}
end

function PhotoMath.ComputeReward(baseReward: number, stars: number, isNew: boolean, groupCount: number, isFirst: boolean): number
	local photo = GameConfig.Photo
	local multiplier = photo.StarMultipliers[math.clamp(stars, 1, 5)] or 1
	if isNew then
		multiplier *= photo.NewDiscoveryMultiplier
	end
	if groupCount > 0 then
		multiplier *= 1 + math.min(photo.GroupBonusMax, groupCount * photo.GroupBonusPerPlayer)
	end
	if isFirst then
		multiplier *= 1 + photo.FirstPhotographerBonus
	end
	return math.max(1, math.floor(baseReward * multiplier + 0.5))
end

return PhotoMath
