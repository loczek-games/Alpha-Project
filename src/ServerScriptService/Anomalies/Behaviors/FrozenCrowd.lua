--[[
	FrozenCrowd (ModuleScript)
	Location: ServerScriptService/Anomalies/Behaviors/FrozenCrowd

	Every shopper freezes mid-step. Exactly one keeps walking - that one is
	the anomaly. Photographing a frozen shopper earns a hint instead.
]]

local CollectionService = game:GetService("CollectionService")

local FrozenCrowd = {}

function FrozenCrowd.CanSpawn(ctx, def)
	return #ctx.Services.NPCService:GetAvailable() >= (def.Spawn.MinNPCs or 3)
end

function FrozenCrowd.Spawn(ctx, record)
	local npcService = ctx.Services.NPCService
	local available = npcService:GetAvailable()
	if #available < (record.Def.Spawn.MinNPCs or 3) then
		return false
	end
	local mover = available[math.random(1, #available)]
	npcService:Reserve(mover)
	mover.SpeedOverride = mover.BaseSpeed * 1.35

	local frozen = {}
	for _, npc in ipairs(npcService:GetAll()) do
		if npc ~= mover then
			npcService:SetFrozen(npc, true)
			npc.Model:SetAttribute("DecoyText", "Frozen solid... find the one that is STILL moving.")
			CollectionService:AddTag(npc.Model, "Decoy")
			table.insert(frozen, npc)
		end
	end

	record.Target = mover.Head
	record.VisibilityRoot = mover.Model
	record.Cleaner:Add(function()
		for _, npc in ipairs(frozen) do
			if npc.Model.Parent then
				CollectionService:RemoveTag(npc.Model, "Decoy")
				npc.Model:SetAttribute("DecoyText", nil)
				npcService:SetFrozen(npc, false)
			end
		end
		npcService:Release(mover)
	end)
	return true
end

return FrozenCrowd
