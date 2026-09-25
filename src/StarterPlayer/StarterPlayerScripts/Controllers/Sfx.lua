--[[
	Sfx (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/Sfx

	Local UI sounds (shutter, capture, fail, announcements) and the optional
	mall ambience loop. Sound ids come from GameConfig.Sounds.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))

local Sfx = {}
Sfx.Sounds = {}

function Sfx:Init(controllers)
	self.Controllers = controllers
	local folder = Instance.new("Folder")
	folder.Name = "CaughtOnCameraSfx"
	folder.Parent = SoundService
	for key, config in pairs(GameConfig.Sounds) do
		if config.Id ~= "" then
			local sound = Instance.new("Sound")
			sound.Name = key
			sound.SoundId = config.Id
			sound.Volume = config.Volume
			sound.PlaybackSpeed = config.Speed
			sound.Parent = folder
			self.Sounds[key] = sound
		end
	end
	local UIKit = controllers.UIKit
	UIKit.ButtonSound = function()
		Sfx.Play("Button")
	end

	local ambience = self.Sounds.Ambience
	if ambience then
		ambience.Looped = true
		local state = controllers.ClientState
		local function refresh()
			local wanted = state:GetSetting("Ambience") == true
			if wanted and not ambience.IsPlaying then
				ambience:Play()
			elseif not wanted and ambience.IsPlaying then
				ambience:Stop()
			end
		end
		state.DataChanged:Connect(refresh)
		refresh()
	end
end

function Sfx.Play(key: string, speedMultiplier: number?)
	local sound = Sfx.Sounds[key]
	if not sound then
		return
	end
	local config = GameConfig.Sounds[key]
	sound.PlaybackSpeed = config.Speed * (speedMultiplier or 1)
	sound.TimePosition = 0
	sound:Play()
end

return Sfx
