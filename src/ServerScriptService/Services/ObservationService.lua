--[[
	ObservationService (ModuleScript)
	Location: ServerScriptService/Services/ObservationService

	Knows what every investigator is LOOKING at. Clients send their camera
	CFrame + field of view ~6 times a second (UnreliableRemoteEvent
	"CameraSync", ObservationController). Anomalies use it for
	"moves only when nobody is watching", "freezes when photographed through
	the zoom", "attacks from behind", etc.

	  GetView(player)                    -> CFrame, fov (falls back to the head)
	  CanSee(player, position, opts)     -> boolean  (inside the view cone + line of sight)
	  IsObserved(position, opts)         -> boolean, { Player }
	  IsZoomedAt(player, position)       -> boolean (camera zoomed in and aimed at it)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"))

local ObservationService = {}
ObservationService.Views = {} :: { [Player]: { CFrame: CFrame, Fov: number, Time: number } }

local DEFAULT_FOV = 70
local ZOOMED_FOV = 45

export type SeeOptions = {
	MaxDistance: number?,
	Margin: number?, -- extra degrees around the view cone
	LineOfSight: boolean?, -- default true
	Ignore: { Instance }?,
}

function ObservationService:Init(services)
	self.Services = services
	self.RayParams = RaycastParams.new()
	self.RayParams.FilterType = Enum.RaycastFilterType.Exclude
	self.RayParams.IgnoreWater = true

	Net.UnreliableEvent("CameraSync").OnServerEvent:Connect(function(player, cframe, fov)
		if typeof(cframe) ~= "CFrame" or type(fov) ~= "number" or fov ~= fov then
			return
		end
		local _, head = services.CharacterService:GetParts(player)
		if not head or (cframe.Position - head.Position).Magnitude > 40 then
			return
		end
		self.Views[player] = { CFrame = cframe, Fov = math.clamp(fov, 5, 120), Time = os.clock() }
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.Views[player] = nil
	end)
end

function ObservationService:GetView(player: Player): (CFrame?, number)
	local view = self.Views[player]
	local _, head = self.Services.CharacterService:GetParts(player)
	if view and os.clock() - view.Time < 1.5 then
		return view.CFrame, view.Fov
	end
	if head then
		return head.CFrame, DEFAULT_FOV
	end
	return nil, DEFAULT_FOV
end

function ObservationService:_filter(extra: { Instance }?)
	local list: { Instance } = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then
			table.insert(list, other.Character)
		end
	end
	local folders = self.Services.MapService.Folders
	for _, key in ipairs({ "ActiveAnomalies", "Decoys" }) do
		if folders[key] then
			table.insert(list, folders[key])
		end
	end
	if extra then
		for _, instance in ipairs(extra) do
			table.insert(list, instance)
		end
	end
	self.RayParams.FilterDescendantsInstances = list
	return self.RayParams
end

function ObservationService:HasLineOfSight(from: Vector3, to: Vector3, ignore: { Instance }?): boolean
	local direction = to - from
	if direction.Magnitude < 0.5 then
		return true
	end
	local result = Workspace:Raycast(from, direction, self:_filter(ignore))
	if not result then
		return true
	end
	-- glass does not block sight
	if result.Instance.Transparency > 0.5 then
		local rest = to - result.Position
		if rest.Magnitude > 0.5 then
			local second = Workspace:Raycast(result.Position + direction.Unit * 0.2, rest, self.RayParams)
			return second == nil or (second.Position - to).Magnitude < 1
		end
		return true
	end
	return (result.Position - to).Magnitude < 1
end

function ObservationService:CanSee(player: Player, position: Vector3, options: SeeOptions?): boolean
	local opts: SeeOptions = options or {}
	local cframe, fov = self:GetView(player)
	if not cframe then
		return false
	end
	local offset = position - cframe.Position
	local distance = offset.Magnitude
	if distance > (opts.MaxDistance or 160) then
		return false
	end
	if distance < 1 then
		return true
	end
	-- horizontal fov is wider than the vertical fov on landscape screens
	local halfAngle = math.rad(fov * 0.5 * 1.45 + (opts.Margin or 4))
	local dot = cframe.LookVector:Dot(offset.Unit)
	if dot < math.cos(halfAngle) then
		return false
	end
	if opts.LineOfSight == false then
		return true
	end
	return self:HasLineOfSight(cframe.Position, position, opts.Ignore)
end

function ObservationService:IsObserved(position: Vector3, options: SeeOptions?, candidates: { Player }?): (boolean, { Player })
	local observers = {}
	local list = candidates or self.Services.MissionService:GetParticipants()
	for _, player in ipairs(list) do
		if self:CanSee(player, position, options) then
			table.insert(observers, player)
		end
	end
	return #observers > 0, observers
end

-- Aiming a zoomed-in camera right at it (anomalies that react to the lens).
function ObservationService:IsZoomedAt(player: Player, position: Vector3, maxAngle: number?): boolean
	local cframe, fov = self:GetView(player)
	if not cframe or fov > ZOOMED_FOV then
		return false
	end
	local offset = position - cframe.Position
	if offset.Magnitude < 1 then
		return true
	end
	local angle = math.deg(math.acos(math.clamp(cframe.LookVector:Dot(offset.Unit), -1, 1)))
	return angle <= (maxAngle or fov * 0.5) and self:HasLineOfSight(cframe.Position, position)
end

-- Is this player looking roughly UP (for the ceiling crawler)?
function ObservationService:GetPitch(player: Player): number
	local cframe = self:GetView(player)
	if not cframe then
		return 0
	end
	return math.deg(math.asin(math.clamp(cframe.LookVector.Y, -1, 1)))
end

return ObservationService
