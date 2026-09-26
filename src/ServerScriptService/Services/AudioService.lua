--[[
	AudioService (ModuleScript)
	Location: ServerScriptService/Services/AudioService

	Server entry point for world sounds. Instead of creating Sound objects on
	the server, it tells nearby clients to play a SoundConfig path at a
	position/part. Each client then applies its own mixer (SoundGroups +
	volume settings), random variation and wall occlusion.

	If the sound is made by a player (opts.Source) and the SoundConfig entry
	has a Noise value, the sound also becomes WORLD NOISE that sound-sensitive
	anomalies can hear (NoiseService).

	Deceptive "phantom" sounds use exactly the same keys as real ones, so
	clients cannot tell them apart.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SoundConfig"))
local Net = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"))

local AudioService = {}

export type PlayOptions = {
	Source: Player?, -- player who made the sound (for noise + echo tracking)
	Exclude: Player?, -- do not send to this player (they already played it locally)
	Only: Player?, -- send to this player only
	Volume: number?, -- volume multiplier
	Speed: number?, -- playback speed multiplier
	Noise: number?, -- override noise intensity (0 = silent to anomalies)
	NoiseKind: string?,
	Global: boolean?, -- ignore distance culling
	Variation: number?, -- force a specific variation index
}

local function positionOf(where: any): Vector3?
	if typeof(where) == "Vector3" then
		return where
	elseif typeof(where) == "Instance" then
		if where:IsA("BasePart") then
			return where.Position
		elseif where:IsA("Attachment") then
			return where.WorldPosition
		elseif where:IsA("Model") then
			return where:GetPivot().Position
		end
	end
	return nil
end

function AudioService:Init(services)
	self.Services = services
	self.Remote = Net.Event("WorldSound")
end

function AudioService:_send(payload, position: Vector3?, entry, opts: PlayOptions)
	if opts.Only then
		self.Remote:FireClient(opts.Only, payload)
		return
	end
	local cull = position ~= nil and entry.Spatial and not opts.Global
	local maxDistance = (entry.RollOff and entry.RollOff[2] or 80) + 30
	for _, player in ipairs(Players:GetPlayers()) do
		if player == opts.Exclude then
			continue
		end
		if cull then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and (root.Position - (position :: Vector3)).Magnitude > maxDistance then
				continue
			end
		end
		self.Remote:FireClient(player, payload)
	end
end

-- where: Vector3 | BasePart | Attachment | Model | nil (2D, everyone)
function AudioService:Play(path: string, where: any, options: PlayOptions?)
	local opts: PlayOptions = options or {}
	local entry = SoundConfig.Get(path)
	if not entry then
		warn("[AudioService] Unknown sound path", path)
		return
	end
	local position = positionOf(where)
	local instance = if typeof(where) == "Instance" and (where:IsA("BasePart") or where:IsA("Attachment")) then where else nil
	local payload = {
		K = path,
		P = position,
		I = instance,
		V = opts.Volume,
		S = opts.Speed,
		N = opts.Variation,
		U = if opts.Source then opts.Source.UserId else nil,
	}
	self:_send(payload, position, entry, opts)

	local noise = opts.Noise
	if noise == nil and opts.Source then
		noise = entry.Noise
	end
	if noise and noise > 0 and position then
		self.Services.NoiseService:Emit(position, noise, opts.NoiseKind or entry.NoiseKind or "Interaction", opts.Source, path)
	end
end

-- A moving series of sounds (e.g. footsteps walking from A to B).
function AudioService:PlaySequence(path: string, from: Vector3, to: Vector3, count: number, interval: number, options: PlayOptions?)
	local opts: PlayOptions = options or {}
	local entry = SoundConfig.Get(path)
	if not entry then
		return
	end
	local payload = {
		K = path,
		P = from,
		Q = { To = to, Count = count, Interval = interval },
		V = opts.Volume,
		U = if opts.Source then opts.Source.UserId else nil,
	}
	self:_send(payload, from, entry, opts)
end

return AudioService
