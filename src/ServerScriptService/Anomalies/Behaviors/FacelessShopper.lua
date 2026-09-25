--[[
	FacelessShopper (ModuleScript)
	Location: ServerScriptService/Anomalies/Behaviors/FacelessShopper

	One of the ambient shoppers quietly loses its face and keeps strolling
	as if nothing happened.
]]

local FacelessShopper = {}

function FacelessShopper.Spawn(ctx, record)
	local npcService = ctx.Services.NPCService
	local available = npcService:GetAvailable()
	if #available == 0 then
		return false
	end
	local npc = available[math.random(1, #available)]
	npcService:Reserve(npc)
	npc.SpeedOverride = npc.BaseSpeed * 0.8

	local face = npc.Head:FindFirstChildOfClass("Decal")
	local originalTransparency = face and face.Transparency or 0
	if face then
		face.Transparency = 1
	end

	record.Target = npc.Head
	record.VisibilityRoot = npc.Model
	record.TargetRadius = math.max(record.TargetRadius, 1.8)
	record.Cleaner:Add(function()
		if face and face.Parent then
			face.Transparency = originalTransparency
		end
		npcService:Release(npc)
	end)
	return true
end

return FacelessShopper
