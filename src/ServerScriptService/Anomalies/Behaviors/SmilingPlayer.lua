--[[
	SmilingPlayer (ModuleScript)
	Location: ServerScriptService/Anomalies/Behaviors/SmilingPlayer

	A random player gets an unnaturally wide smile and a tilted head - but
	ONLY on everybody else's screen (the effect is applied client-side by
	FxController). The chosen player has no idea until someone photographs
	them or starts screaming in chat.
]]

local SmilingPlayer = {}

function SmilingPlayer.Spawn(ctx, record)
	local target = ctx:PickTargetPlayer(record)
	if not target then
		return false
	end
	local _, head = ctx:GetCharacterParts(target)
	if not head then
		return false
	end

	record.Target = head
	record.VisibilityRoot = target.Character
	record.ExcludePhotographers[target.UserId] = true
	record.Silent = true -- no spawn sting: the target must not notice

	local payload = { Type = "SmilingPlayer", On = true, UserId = target.UserId, Uid = record.Uid }
	ctx:FireFxAll(payload, target)
	ctx:SetPersistentFx(record, payload, target)
	record.Cleaner:Add(function()
		ctx:FireFxAll({ Type = "SmilingPlayer", On = false, UserId = target.UserId, Uid = record.Uid })
	end)
	return true
end

return SmilingPlayer
