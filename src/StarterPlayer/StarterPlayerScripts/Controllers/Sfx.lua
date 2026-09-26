--[[
	Sfx (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/Sfx

	Short names for common UI sounds. Everything is routed through
	AudioController (SoundConfig + mixer), so UI sounds respect the volume
	settings like every other sound.
]]

local Sfx = {}
Sfx.Controllers = nil :: any

-- legacy short names -> SoundConfig paths
local MAP = {
	Shutter = "Camera.Shutter",
	Capture = "Camera.CaptureSuccess",
	CaptureRare = "Camera.CaptureRare",
	NewDiscovery = "UI.NewDiscovery",
	Fail = "UI.Fail",
	Button = "UI.Button",
	Announce = "UI.Announce",
	Reveal = "UI.Reveal",
	Whisper = "UI.Whisper",
	Heartbeat = "UI.Heartbeat",
	Error = "UI.Error",
	Toast = "UI.Toast",
	Stinger = "UI.Stinger",
}

function Sfx:Init(controllers)
	Sfx.Controllers = controllers
	controllers.UIKit.ButtonSound = function()
		Sfx.Play("Button")
	end
end

-- key: a short name above or any SoundConfig path. Plays in 2D (UI).
function Sfx.Play(key: string, speedMultiplier: number?)
	local controllers = Sfx.Controllers
	if not controllers then
		return
	end
	controllers.AudioController:Play(MAP[key] or key, nil, { Speed = speedMultiplier })
end

return Sfx
