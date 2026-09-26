--[[
	FakeExit (ModuleScript)
	Location: ServerScriptService/Anomalies/Behaviors/FakeExit

	THE MOVING EXIT. One of the mall's EXIT signs flickers, tilts, spells
	itself wrong, points into the wall - and when nobody is looking it is
	suddenly hanging somewhere else.
	Fixture: the "Sign" part tagged "ExitSign" (SurfaceGuis with a "Text" label).
]]

local FakeExit = {}

local WRONG = { "TIXE", "EXlT", "EX1T", "NO EXIT", "EXIT ↓", "← EXIT", "STAY" }

function FakeExit.Spawn(ctx, record)
	local sign = ctx:PickFixture(record)
	if not sign or not sign:IsA("BasePart") then
		return false
	end
	local labels = {}
	for _, descendant in ipairs(sign:GetDescendants()) do
		if descendant:IsA("TextLabel") then
			table.insert(labels, { Label = descendant, Text = descendant.Text, Color = descendant.TextColor3 })
		end
	end
	if #labels == 0 then
		return false
	end
	record.Target = sign
	record.VisibilityRoot = sign.Parent or sign

	local original = sign.CFrame
	sign.CFrame = original * CFrame.Angles(0, 0, math.rad(if math.random() < 0.5 then -9 else 9))
	local green = labels[1].Color
	local red = Color3.fromRGB(255, 50, 50)
	local running = true
	local moved = 0
	local params = record.Params
	record.Cleaner:Add(task.spawn(function()
		while running do
			task.wait((params.FlickerMin or 0.25) + math.random() * ((params.FlickerMax or 1.1) - (params.FlickerMin or 0.25)))
			local glitch = math.random()
			for _, entry in ipairs(labels) do
				entry.Label.TextColor3 = if glitch < 0.35 then red else green
				entry.Label.Text = if glitch < 0.3 then WRONG[math.random(1, #WRONG)] else entry.Text
			end
			-- teleports along the ceiling when unobserved
			if moved < 3 and math.random() < 0.25 and not ctx.Objects.Observed(ctx, sign.Position) then
				moved += 1
				local offset = original.RightVector * math.random(-10, 10) + original.LookVector * math.random(-6, 6)
				sign.CFrame = original * CFrame.Angles(0, 0, math.rad(math.random(-12, 12))) + offset
				ctx.Kit.PlaySound3D(sign, "Environment.LightBuzz")
			end
		end
	end))
	record.Cleaner:Add(function()
		running = false
		sign.CFrame = original
		for _, entry in ipairs(labels) do
			entry.Label.Text = entry.Text
			entry.Label.TextColor3 = entry.Color
		end
	end)
	return true
end

return FakeExit
