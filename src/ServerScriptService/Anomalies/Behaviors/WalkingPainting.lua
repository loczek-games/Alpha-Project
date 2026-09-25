--[[
	WalkingPainting (ModuleScript)
	Location: ServerScriptService/Anomalies/Behaviors/WalkingPainting

	A dark figure appears inside one of the mall's paintings. The painting is
	marked "Haunted"; every client then moves the figure around the canvas
	whenever THAT player isn't looking at it (see FxController), so it truly
	only moves when you look away.
]]

local WalkingPainting = {}

function WalkingPainting.Spawn(ctx, record)
	local painting = ctx:PickFixture(record)
	if not painting then
		return false
	end
	local canvasPart = painting:FindFirstChild("Canvas")
	local gui = canvasPart and canvasPart:FindFirstChild("Canvas")
	local figure = gui and gui:FindFirstChild("Figure")
	if not (canvasPart and canvasPart:IsA("BasePart") and figure and figure:IsA("Frame")) then
		return false
	end

	figure.Position = UDim2.fromScale(0.55, 0.8)
	figure.Size = UDim2.fromOffset(34, 86)
	figure.Visible = true
	painting:SetAttribute("Haunted", true)

	record.Target = canvasPart
	record.VisibilityRoot = painting
	record.Cleaner:Add(function()
		figure.Visible = false
		figure.Position = UDim2.fromScale(0.55, 0.8)
		figure.Size = UDim2.fromOffset(34, 86)
		painting:SetAttribute("Haunted", false)
	end)
	return true
end

return WalkingPainting
