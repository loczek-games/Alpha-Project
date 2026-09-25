--[[
	FakeExit (ModuleScript)
	Location: ServerScriptService/Anomalies/Behaviors/FakeExit

	One of the mall's EXIT signs starts flickering, tilts, and its arrow
	points somewhere no exit could ever be.
]]

local FakeExit = {}

local WRONG_ARROWS = { "↓", "←", "→", "↙", "↘" }

function FakeExit.Spawn(ctx, record)
	local exitSign = ctx:PickFixture(record)
	if not exitSign then
		return false
	end
	local signPart = exitSign:FindFirstChild("Sign")
	local gui = signPart and signPart:FindFirstChild("SignGui")
	local text = gui and gui:FindFirstChild("Text")
	local arrow = gui and gui:FindFirstChild("Arrow")
	if not (signPart and signPart:IsA("BasePart") and text and text:IsA("TextLabel") and arrow and arrow:IsA("TextLabel")) then
		return false
	end

	record.Target = signPart
	record.VisibilityRoot = exitSign

	local originalCFrame = signPart.CFrame
	local originalText, originalArrow = text.Text, arrow.Text
	local originalColor = text.TextColor3
	local green = originalColor
	local red = Color3.fromRGB(255, 50, 50)

	arrow.Text = WRONG_ARROWS[math.random(1, #WRONG_ARROWS)]
	signPart.CFrame = originalCFrame * CFrame.Angles(0, 0, math.rad(math.random() < 0.5 and -9 or 9))

	local running = true
	local params = record.Params
	record.Cleaner:Add(task.spawn(function()
		while running do
			task.wait((params.FlickerMin or 0.25) + math.random() * ((params.FlickerMax or 1.1) - (params.FlickerMin or 0.25)))
			local glitch = math.random()
			text.TextColor3 = if glitch < 0.35 then red else green
			arrow.TextColor3 = text.TextColor3
			text.Text = if glitch < 0.12 then "TIXE" elseif glitch < 0.2 then "EXlT" else "EXIT"
			if glitch > 0.85 then
				arrow.Text = WRONG_ARROWS[math.random(1, #WRONG_ARROWS)]
			end
		end
	end))
	record.Cleaner:Add(function()
		running = false
		signPart.CFrame = originalCFrame
		text.Text = originalText
		arrow.Text = originalArrow
		text.TextColor3 = originalColor
		arrow.TextColor3 = originalColor
	end)
	return true
end

return FakeExit
