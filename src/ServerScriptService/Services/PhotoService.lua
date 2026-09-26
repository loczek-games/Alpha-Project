--[[
	PhotoService (ModuleScript)
	Location: ServerScriptService/Services/PhotoService

	Server-authoritative photography. The client only sends "I pressed the
	shutter, this is my camera CFrame". The server decides everything else:
	  * rate limit (camera cooldown + burst window)
	  * camera position must be near the player's head (no remote cameras)
	  * anomaly must be alive, within range, near the centre of the view,
	    and visible (raycast line-of-sight)
	  * star rating, Evidence reward, discoveries, announcements, badges
]]

local BadgeService = game:GetService("BadgeService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local AnomalyConfig = require(Config:WaitForChild("AnomalyConfig"))
local EquipmentConfig = require(Config:WaitForChild("EquipmentConfig"))
local RarityConfig = require(Config:WaitForChild("RarityConfig"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Net = require(Modules:WaitForChild("Net"))
local PhotoMath = require(Modules:WaitForChild("PhotoMath"))

local PhotoService = {}
PhotoService.State = {}

local PHOTO = GameConfig.Photo

local function isFiniteVector(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6
end

local function angleBetween(a: Vector3, b: Vector3): number
	return math.deg(math.acos(math.clamp(a:Dot(b), -1, 1)))
end

function PhotoService:Init(services)
	self.Services = services
	self.ResultRemote = Net.Event("PhotoResult")
	self.FlashRemote = Net.Event("PhotoFlash")
	self.AnnounceRemote = Net.Event("Announce")

	Net.Event("PhotoRequest").OnServerEvent:Connect(function(player, cameraCFrame)
		local ok, err = pcall(function()
			self:_onRequest(player, cameraCFrame)
		end)
		if not ok then
			warn("[PhotoService] request error:", err)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.State[player] = nil
	end)
end

function PhotoService:_rateLimit(player: Player, cooldown: number): boolean
	local state = self.State[player]
	if not state then
		state = { LastShot = 0, Window = {} }
		self.State[player] = state
	end
	local t = os.clock()
	if t - state.LastShot < cooldown * PHOTO.CooldownTolerance then
		return false
	end
	local window = state.Window
	for index = #window, 1, -1 do
		if t - window[index] > PHOTO.RateLimitWindow then
			table.remove(window, index)
		end
	end
	if #window >= PHOTO.RateLimitBurst then
		return false
	end
	table.insert(window, t)
	state.LastShot = t
	return true
end

function PhotoService:_onRequest(player: Player, cameraCFrame: any)
	if typeof(cameraCFrame) ~= "CFrame" then
		return
	end
	local cf = cameraCFrame :: CFrame
	if not isFiniteVector(cf.Position) or not isFiniteVector(cf.LookVector) then
		return
	end

	local services = self.Services
	local stats = services.EconomyService:GetCameraStats(player)
	if not self:_rateLimit(player, stats.Cooldown) then
		return
	end

	local _, head = services.CharacterService:GetParts(player)
	if not head then
		return
	end
	-- the camera must actually be in the player's hands
	if not services.EquipmentService:IsEquipped(player, "Camera") then
		return
	end

	local inRound = services.MissionService:IsInvestigating(player)
	if inRound and not services.EquipmentService:ConsumeBattery(player, "Camera", EquipmentConfig.Items.Camera.Battery.PerUse) then
		self:_fail(player, "NO_BATTERY")
		return
	end

	-- everyone sees the flash and hears the shutter; sound-hunting anomalies hear it too
	self.FlashRemote:FireAllClients(player)
	services.DataService:IncrementStat(player, "PhotosTaken")
	if inRound then
		services.NoiseService:Emit(head.Position, stats.ShutterNoise, "Shutter", player, "Camera.Shutter")
		services.NoiseService:Emit(head.Position, stats.FlashNoise, "Flash", player, "Camera.FlashTrigger")
	end

	if not inRound then
		self:_fail(player, "NOT_IN_ROUND")
		return
	end

	-- Validate the camera origin: it must be close to the head and not behind a wall.
	local origin = cf.Position
	if (origin - head.Position).Magnitude > PHOTO.MaxCameraDistanceFromHead then
		origin = head.Position
	else
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character :: Model }
		local blocked = Workspace:Raycast(head.Position, origin - head.Position, params)
		if blocked then
			origin = head.Position
		end
	end
	local look = cf.LookVector.Unit

	local best, bestInfo, bestScore = nil, nil, -math.huge
	local failReason, failPriority = "NOTHING", 0
	local function note(reason: string, priority: number)
		if priority > failPriority then
			failReason, failPriority = reason, priority
		end
	end

	local anomalies = services.AnomalyService
	local serverNow = Workspace:GetServerTimeNow()
	for _, record in ipairs(anomalies:GetActiveList()) do
		if not anomalies:IsPhotographable(record) or record.ExcludePhotographers[player.UserId] then
			continue
		end
		local target = record.Target
		if not target or not target.Parent then
			continue
		end
		local def = record.Def
		local targetPosition = target.Position
		local toTarget = targetPosition - origin
		local cameraDistance = toTarget.Magnitude
		if cameraDistance < 0.05 then
			continue
		end
		local headDistance = (targetPosition - head.Position).Magnitude
		local maxDistance = def.PhotoDistance * stats.RangeMultiplier
		local angle = angleBetween(look, toTarget.Unit)
		local leniency = math.deg(math.atan((record.TargetRadius or 2) / math.max(cameraDistance, 1)))
		local effectiveAngle = math.max(0, angle - leniency)
		local maxAngle = PHOTO.MaxAngleDeg + stats.ExtraAngle

		if effectiveAngle > maxAngle then
			if effectiveAngle <= maxAngle * 2 and headDistance <= maxDistance * 1.2 then
				note("OFF_CENTER", 2)
			end
			continue
		end
		if headDistance > maxDistance then
			if headDistance <= maxDistance * 2.5 then
				note("TOO_FAR", 3)
			end
			continue
		end
		if not self:_isVisible(origin, record) then
			note("BLOCKED", 4)
			continue
		end
		if def.RequiredAbility and not stats.Abilities[def.RequiredAbility] then
			note("NEEDS_CAMERA", 5)
			continue
		end
		local behavior = anomalies.Behaviors[def.Behavior]
		if behavior and behavior.CanPhotograph then
			local allowed = behavior.CanPhotograph(anomalies, record, player)
			if not allowed then
				note("NOTHING", 1)
				continue
			end
		end
		local shots = record.Captures[player.UserId] or 0
		if shots >= PHOTO.MaxShotsPerAnomaly then
			note("MAXED", 6)
			continue
		end

		local lifeFraction = (serverNow - record.SpawnTime) / math.max(record.Lifetime, 1)
		local stars = PhotoMath.ComputeStars(headDistance, maxDistance, effectiveAngle, maxAngle, lifeFraction)
		local score = RarityConfig.GetRank(def.Rarity) * 10 + stars
		if score > bestScore then
			best, bestScore = record, score
			bestInfo = { Stars = stars, Distance = headDistance }
		end
	end

	if best and bestInfo then
		self:_capture(player, best, bestInfo, origin, look, cf)
		return
	end

	-- Nothing real in frame: was the player fooled by a False Alarm decoy?
	if failPriority <= 1 then
		local decoyText = self:_findDecoy(origin, look)
		if decoyText then
			self:_fail(player, "DECOY", decoyText)
			return
		end
	end
	self:_fail(player, failReason)
end

function PhotoService:_buildExclude(root: Instance)
	local exclude: { Instance } = { self.Services.MapService.Folders.Decoys }
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		if character and character ~= root and not root:IsDescendantOf(character) then
			table.insert(exclude, character)
		end
	end
	return exclude
end

function PhotoService:_isVisible(origin: Vector3, record): boolean
	local root: Instance = record.VisibilityRoot or record.Target
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = self:_buildExclude(root)

	local samples = { record.Target.Position }
	if root:IsA("Model") then
		local boxCFrame, boxSize = root:GetBoundingBox()
		table.insert(samples, boxCFrame.Position)
		table.insert(samples, boxCFrame.Position + Vector3.new(0, boxSize.Y * 0.3, 0))
	end

	for _, sample in ipairs(samples) do
		local direction = sample - origin
		local result = Workspace:Raycast(origin, direction, params)
		if not result then
			return true
		end
		if result.Instance == record.Target or result.Instance:IsDescendantOf(root) then
			return true
		end
		if (result.Position - origin).Magnitude >= direction.Magnitude - 0.75 then
			return true
		end
	end
	return false
end

function PhotoService:_countGroup(player: Player, origin: Vector3, look: Vector3): number
	local count = 0
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Model, self.Services.MapService.Folders.ActiveAnomalies }
	for _, other in ipairs(self.Services.MissionService:GetParticipants()) do
		if other == player then
			continue
		end
		local _, head = self.Services.CharacterService:GetParts(other)
		if not head then
			continue
		end
		local offset = head.Position - origin
		if offset.Magnitude > PHOTO.GroupPhotoMaxDistance or offset.Magnitude < 0.5 then
			continue
		end
		if angleBetween(look, offset.Unit) > PHOTO.GroupPhotoMaxAngleDeg then
			continue
		end
		local result = Workspace:Raycast(origin, offset, params)
		if not result or result.Instance:IsDescendantOf(other.Character :: Model) then
			count += 1
		end
	end
	return count
end

function PhotoService:_findDecoy(origin: Vector3, look: Vector3): string?
	for _, decoy in ipairs(CollectionService:GetTagged("Decoy")) do
		local position
		if decoy:IsA("Model") then
			position = decoy:GetPivot().Position
		elseif decoy:IsA("BasePart") then
			position = decoy.Position
		end
		if position then
			local offset = position - origin
			if offset.Magnitude <= PHOTO.DecoyCheckDistance and offset.Magnitude > 0.1 and angleBetween(look, offset.Unit) <= PHOTO.MaxAngleDeg + 6 then
				return decoy:GetAttribute("DecoyText") or "That's just... normal. Probably."
			end
		end
	end
	return nil
end

function PhotoService:_capture(player: Player, record, info, origin: Vector3, look: Vector3, cameraCFrame: CFrame)
	local services = self.Services
	local def = record.Def
	local userId = player.UserId
	local stars = info.Stars

	local shotIndex = (record.Captures[userId] or 0) + 1
	record.Captures[userId] = shotIndex
	record.CaptureCount += 1
	local isFirst = false
	if record.FirstCapturer == nil then
		record.FirstCapturer = userId
		isFirst = true
	end

	local isNew, previousBest, entry = services.DataService:RecordDiscovery(player, def.Id, stars)
	local isNewBest = (not isNew) and stars > previousBest
	local groupCount = self:_countGroup(player, origin, look)

	local reward = 0
	if shotIndex == 1 then
		reward = PhotoMath.ComputeReward(AnomalyConfig.GetReward(def), stars, isNew, groupCount, isFirst)
		services.EconomyService:AddEvidence(player, reward, "Photo")
		services.MissionService:RecordCapture(player, {
			Def = def,
			Stars = stars,
			Reward = reward,
			IsNew = isNew,
			Group = groupCount,
			First = isFirst,
		})
	end
	services.EconomyService:UpdateLeaderstats(player)

	if shotIndex == 1 or isNewBest then
		services.DataService:AddPhotoRoll(player, {
			Id = def.Id,
			Stars = stars,
			Time = os.time(),
			Group = groupCount,
			First = isFirst,
			New = isNew,
		})
	end

	local behavior = services.AnomalyService.Behaviors[def.Behavior]
	if behavior and behavior.OnCaptured then
		task.spawn(function()
			local ok, err = pcall(behavior.OnCaptured, services.AnomalyService, record, player, { Stars = stars })
			if not ok then
				warn("[PhotoService] OnCaptured error:", err)
			end
		end)
	end

	local data = services.DataService:GetData(player)
	if data and data.Stats.TotalCaptures == 1 then
		self:AwardBadge(player, "FirstPhoto")
	end
	if def.Badge then
		self:AwardBadge(player, def.Badge)
	end

	local tier = RarityConfig.Get(def.Rarity)
	self.ResultRemote:FireClient(player, {
		Success = true,
		Uid = record.Uid,
		Id = def.Id,
		Name = def.Name,
		Rarity = def.Rarity,
		Stars = stars,
		BestStars = entry and entry.BestStars or stars,
		Count = entry and entry.Count or 1,
		IsNew = isNew,
		IsNewBest = isNewBest,
		Reward = reward,
		Shot = shotIndex,
		Odds = AnomalyConfig.GetOddsText(def.Id),
		Group = groupCount,
		First = isFirst,
		View = record.VisibilityRoot,
		TargetPosition = record.Target.Position,
		CameraCFrame = cameraCFrame,
	})

	if shotIndex == 1 then
		local mode = AnomalyConfig.GetAnnounceMode(def)
		if mode == "Reveal" and not record.Revealed then
			record.Revealed = true
			self.AnnounceRemote:FireAllClients({
				Kind = "Reveal",
				Rarity = def.Rarity,
				Title = string.upper(tier.DisplayName) .. " ANOMALY",
				Name = string.upper(def.Name),
				Odds = AnomalyConfig.GetOddsText(def.Id),
				Finder = player.DisplayName,
				Color = tier.Color,
			})
		elseif mode == "Server" or mode == "Reveal" then
			self.AnnounceRemote:FireAllClients({
				Kind = "Toast",
				Text = string.format("📸 %s captured %s (%s)", player.DisplayName, def.Name, string.upper(tier.DisplayName)),
				Color = tier.Color,
			})
		end
	end
end

function PhotoService:_fail(player: Player, reason: string, message: string?)
	self.ResultRemote:FireClient(player, {
		Success = false,
		Reason = reason,
		Message = message,
	})
end

function PhotoService:AwardBadge(player: Player, key: string)
	local badgeId = GameConfig.Badges[key]
	if type(badgeId) ~= "number" or badgeId <= 0 then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			if not BadgeService:UserHasBadgeAsync(player.UserId, badgeId) then
				BadgeService:AwardBadge(player.UserId, badgeId)
			end
		end)
		if not ok then
			warn("[PhotoService] Badge award failed:", err)
		end
	end)
end

return PhotoService
