--[[
	FootstepController (ModuleScript)
	Location: StarterPlayer/StarterPlayerScripts/Controllers/FootstepController

	Material-based 3D footsteps for every nearby humanoid: players, the mall's
	shoppers and humanoid anomalies (a Fake Player walks exactly like a real
	one...). Steps follow the actual movement speed:
	  sneaking = very quiet, walking = normal, running = loud.
	Landings play a normal or heavy impact. The surface comes from the floor
	material (or a "FootstepSurface" attribute on the floor part).
	The matching world NOISE for anomalies is simulated on the server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local SoundConfig = require(Config:WaitForChild("SoundConfig"))
local GameConfig = require(Config:WaitForChild("GameConfig"))

local FootstepController = {}
FootstepController.Tracked = {}

local TRACK_RANGE = 75
local NOISE = GameConfig.Noise

function FootstepController:Init(controllers)
	self.Controllers = controllers
	self.RayParams = RaycastParams.new()
	self.RayParams.FilterType = Enum.RaycastFilterType.Exclude
end

function FootstepController:Start()
	task.spawn(function()
		while true do
			self:_refreshTracked()
			task.wait(1)
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		self:_step(dt)
	end)
end

function FootstepController:_refreshTracked()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local origin = camera.CFrame.Position
	local models = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then
			table.insert(models, other.Character)
		end
	end
	for _, path in ipairs({ { "Map", "DeadMall", "NPCs" }, { "ActiveAnomalies" } }) do
		local node: Instance? = Workspace
		for _, name in ipairs(path) do
			node = node and node:FindFirstChild(name)
		end
		if node then
			for _, child in ipairs(node:GetChildren()) do
				if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
					table.insert(models, child)
				end
			end
		end
	end
	local keep = {}
	local exclude: { Instance } = {}
	for _, model in ipairs(models) do
		table.insert(exclude, model)
		local root = model:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - origin).Magnitude < TRACK_RANGE then
			keep[model] = self.Tracked[model] or { Phase = 0.6, LastVY = 0, Root = root, Humanoid = model:FindFirstChildOfClass("Humanoid") }
		end
	end
	for _, name in ipairs({ "ActiveAnomalies", "Decoys" }) do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			table.insert(exclude, folder)
		end
	end
	self.RayParams.FilterDescendantsInstances = exclude
	self.Tracked = keep
end

function FootstepController:_surfaceBelow(root: BasePart): string?
	local result = Workspace:Raycast(root.Position, Vector3.new(0, -5.5, 0), self.RayParams)
	if not result then
		return nil
	end
	local override = result.Instance:GetAttribute("FootstepSurface")
	if type(override) == "string" and SoundConfig.Player.Footstep[override] then
		return override
	end
	if result.Material == Enum.Material.Water then
		return "Water"
	end
	return SoundConfig.MaterialSurfaces[result.Material.Name] or "Concrete"
end

function FootstepController:_step(dt: number)
	local audio = self.Controllers.AudioController
	for model, state in pairs(self.Tracked) do
		local root: BasePart = state.Root
		if not root.Parent or not model.Parent then
			self.Tracked[model] = nil
			continue
		end
		local velocity = root.AssemblyLinearVelocity
		local feet = root.Position - Vector3.new(0, 2.8, 0)

		-- jumps & landings
		if velocity.Y > 30 and state.LastVY < 6 then
			audio:Play("Player.Jump", feet)
		end
		if state.LastVY < -NOISE.LandVelocity and velocity.Y > -4 then
			local heavy = state.LastVY < -NOISE.HeavyLandVelocity
			audio:Play(if heavy then "Player.HeavyLand" else "Player.Land", feet)
			local surface = self:_surfaceBelow(root)
			if surface then
				audio:Play("Player.Footstep." .. surface, feet, { Volume = if heavy then 1.2 else 0.9 })
			end
			state.Phase = 0
		end
		state.LastVY = velocity.Y

		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		if speed < 1.5 or math.abs(velocity.Y) > 8 then
			state.Phase = 0.6 -- the first step comes quickly once moving
			continue
		end
		local mode = if speed >= NOISE.RunSpeedMin then "Run" elseif speed >= NOISE.SneakSpeedMax then "Walk" else "Sneak"
		local stride = if mode == "Run" then 6.4 elseif mode == "Walk" then 4.8 else 3.4
		state.Phase += speed * dt / stride
		if state.Phase >= 1 then
			state.Phase -= 1
			local surface = self:_surfaceBelow(root)
			if surface then
				audio:Play("Player.Footstep." .. surface, feet, { Volume = SoundConfig.StepVolume[mode] })
			end
		end
	end
end

return FootstepController
