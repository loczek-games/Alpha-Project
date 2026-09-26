--[[
	ReverseClock (ModuleScript)
	Location: ServerScriptService/Anomalies/Behaviors/ReverseClock

	Every clock in the mall is stopped at 3:00. This anomaly makes one of
	them tick loudly while its hands spin BACKWARDS.
]]

local RunService = game:GetService("RunService")

local ReverseClock = {}

function ReverseClock.Spawn(ctx, record)
	local clock = ctx:PickFixture(record)
	if not clock then
		return false
	end
	local face = clock:FindFirstChild("Face")
	local hourPivot = clock:FindFirstChild("HourPivot")
	local minutePivot = clock:FindFirstChild("MinutePivot")
	if not (face and hourPivot and minutePivot) then
		return false
	end

	record.Target = face
	record.VisibilityRoot = clock

	local hourBase: CFrame = hourPivot.CFrame
	local minuteBase: CFrame = minutePivot.CFrame
	local minuteSpeed = math.rad(record.Params.MinuteSpeed or 200)
	local hourSpeed = math.rad(record.Params.HourSpeed or 18)
	local minuteAngle, hourAngle, tickTimer = 0, 0, 0

	record.Cleaner:Add(RunService.Heartbeat:Connect(function(dt)
		-- negative angle = anticlockwise as seen from the front
		minuteAngle -= minuteSpeed * dt
		hourAngle -= hourSpeed * dt
		minutePivot.CFrame = minuteBase * CFrame.Angles(0, 0, minuteAngle)
		hourPivot.CFrame = hourBase * CFrame.Angles(0, 0, hourAngle)
		tickTimer += dt
		if tickTimer >= 0.33 then
			tickTimer = 0
			ctx.Kit.PlaySound3D(face, "Anomaly.ClockTick")
		end
	end))
	record.Cleaner:Add(function()
		minutePivot.CFrame = minuteBase
		hourPivot.CFrame = hourBase
	end)
	return true
end

return ReverseClock
