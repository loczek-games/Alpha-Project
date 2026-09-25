--[[
	FloatingCart (ModuleScript)
	Location: ServerScriptService/Anomalies/Behaviors/FloatingCart

	An abandoned shopping cart slowly lifts off the floor, bobbing and turning.
]]

local RunService = game:GetService("RunService")

local FloatingCart = {}

function FloatingCart.Spawn(ctx, record)
	local marker = ctx:PickSpawn(record)
	if not marker then
		return false
	end
	local Kit = ctx.Kit
	local metal = Color3.fromRGB(172, 178, 188)
	local model = Kit.Model("FloatingCart")

	local root = Kit.Part(model, { Name = "Basket", Size = Vector3.new(3, 0.2, 4.4), CFrame = CFrame.new(0, 1.2, 0), Color = metal, Material = Enum.Material.Metal })
	Kit.Part(model, { Name = "Side", Size = Vector3.new(0.15, 1.8, 4.4), CFrame = CFrame.new(-1.5, 2.1, 0), Color = metal, Material = Enum.Material.Metal, Transparency = 0.25 })
	Kit.Part(model, { Name = "Side", Size = Vector3.new(0.15, 1.8, 4.4), CFrame = CFrame.new(1.5, 2.1, 0), Color = metal, Material = Enum.Material.Metal, Transparency = 0.25 })
	Kit.Part(model, { Name = "Front", Size = Vector3.new(3, 1.8, 0.15), CFrame = CFrame.new(0, 2.1, -2.2), Color = metal, Material = Enum.Material.Metal, Transparency = 0.25 })
	Kit.Part(model, { Name = "Back", Size = Vector3.new(3, 1.8, 0.15), CFrame = CFrame.new(0, 2.1, 2.2), Color = metal, Material = Enum.Material.Metal, Transparency = 0.25 })
	Kit.Part(model, { Name = "Handle", Size = Vector3.new(3.2, 0.25, 0.25), CFrame = CFrame.new(0, 3.3, 2.6), Color = Color3.fromRGB(200, 40, 40) })
	for _, x in ipairs({ -1.2, 1.2 }) do
		for _, z in ipairs({ -1.8, 1.8 }) do
			Kit.Part(model, { Name = "Leg", Size = Vector3.new(0.12, 0.9, 0.12), CFrame = CFrame.new(x, 0.75, z), Color = metal, Material = Enum.Material.Metal })
			Kit.Part(model, {
				Name = "Wheel",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.3, 0.6, 0.6),
				CFrame = CFrame.new(x, 0.3, z),
				Color = Color3.fromRGB(25, 25, 25),
			})
		end
	end
	Kit.Weld(model, root)
	model:PivotTo(marker.CFrame * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, math.rad(math.random(0, 359)), 0))
	model.Parent = ctx.Services.MapService.Folders.ActiveAnomalies
	Kit.FadeIn(model, 0.5)

	record.Model = model
	record.Target = root

	local params = record.Params
	local height = params.Height or 5
	local amplitude = params.BobAmplitude or 0.8
	local spin = params.SpinSpeed or 0.35
	local base = root.CFrame
	local elapsed = 0
	record.Cleaner:Add(RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local rise = math.min(1, elapsed / 3)
		local eased = 1 - (1 - rise) ^ 3
		root.CFrame = base
			* CFrame.new(0, height * eased + math.sin(elapsed * 1.6) * amplitude * eased, 0)
			* CFrame.Angles(0, elapsed * spin, math.sin(elapsed * 1.1) * 0.08 * eased)
	end))
	return true
end

return FloatingCart
