--[[
	ChatTagController (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/ChatTagController

	Adds a gold [⭐ VIP] prefix to chat messages from VIP Photographer pass
	owners. The server sets the "VIP" attribute on the Player after verifying
	pass ownership, so this is purely cosmetic.
]]

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local ChatTagController = {}

function ChatTagController:Init()
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		return
	end
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local source = message.TextSource
		if not source then
			return nil
		end
		local speaker = Players:GetPlayerByUserId(source.UserId)
		if not speaker or not speaker:GetAttribute("VIP") then
			return nil
		end
		local properties = Instance.new("TextChatMessageProperties")
		properties.PrefixText = "<font color='#FFD24A'>[⭐ VIP]</font> " .. message.PrefixText
		return properties
	end
end

return ChatTagController
