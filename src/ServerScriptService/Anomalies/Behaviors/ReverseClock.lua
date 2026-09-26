--[[
	ReverseClock (ModuleScript)
	Location: ServerScriptService/Anomalies/Behaviors/ReverseClock

	Every clock in the mall stopped at the same minute. This anomaly makes
	one of them tick loudly while its hands spin BACKWARDS.
	Fixture: the clock Face tagged "MallClock" (HourHand / MinuteHand siblings).
]]

local RunService = game:GetService("RunService")

local ReverseClock = {}

function ReverseClock.Spawn(ctx, record)
	local face = ctx:PickFixture(record)
	if not face or not face:IsA("BasePart") then
		return false
	end
	local clock = face.Parent
	local hour = clock and clock:FindFirstChild("HourHand")
	local minute = clock and clock:FindFirstChild("MinuteHand")
	if not (clock and hour and minute and hour:IsA("BasePart") and minute:IsA("BasePart")) then
		return false
	end
	record.Target = face
	record.VisibilityRoot = clock

	-- rotate around the dial's axis (the clock model's forward axis)
	local frame = if clock:IsA("Model") then clock:GetPivot() else face.CFrame
	local pivot = CFrame.new(face.Position) * (frame - frame.Position)
	local hourOffset = pivot:ToObjectSpace(hour.CFrame)
	local minuteOffset = pivot:ToObjectSpace(minute.CFrame)
	local minuteSpeed = math.rad(record.Params.MinuteSpeed or 200)
	local hourSpeed = math.rad(record.Params.HourSpeed or 18)
	local minuteAngle, hourAngle, tickTimer = 0, 0, 0

	record.Cleaner:Add(RunService.Heartbeat:Connect(function(dt)
		-- the dial's +Z axis points away from a viewer in front of the clock,
		-- so a NEGATIVE angle turns the hands anticlockwise as seen from the front
		minuteAngle -= minuteSpeed * dt
		hourAngle -= hourSpeed * dt
		minute.CFrame = pivot * CFrame.Angles(0, 0, minuteAngle) * minuteOffset
		hour.CFrame = pivot * CFrame.Angles(0, 0, hourAngle) * hourOffset
		tickTimer += dt
		if tickTimer >= 0.33 then
			tickTimer = 0
			ctx.Kit.PlaySound3D(face, "Anomaly.ClockTick")
		end
	end))
	record.Cleaner:Add(function()
		minute.CFrame = pivot * minuteOffset
		hour.CFrame = pivot * hourOffset
	end)
	return true
end

return ReverseClock
