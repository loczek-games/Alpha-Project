--[[
	EventService (ModuleScript)
	Location: ServerScriptService/Services/EventService

	Server-wide events that change the whole mall for everybody:
	  Surge        - anomaly activity and rare luck rise
	  Blackout     - lights out: flashlights, darkness-only anomalies, breaker resets it
	  FalseAlarm   - several suspicious decoys, exactly one real anomaly
	  RareAnomaly  - "SOMETHING RARE IS HERE." (location is never revealed)
	Events fire randomly during rounds and can be bought as Developer Products
	(purchases queue up and start as soon as possible, for everyone).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local RarityConfig = require(Config:WaitForChild("RarityConfig"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Net = require(Modules:WaitForChild("Net"))
local Cleaner = require(Modules:WaitForChild("Cleaner"))

local EventService = {}
EventService.Active = nil
EventService.Queue = {}
EventService.RoundActive = false

local EVENTS = GameConfig.Events
local DEFS = EVENTS.Definitions

local function randomRange(range: { number }): number
	return range[1] + math.random() * (range[2] - range[1])
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

---------------------------------------------------------------------------
-- False Alarm decoys: suspicious-looking but NOT anomalies.
---------------------------------------------------------------------------

local function tagDecoy(instance: Instance, text: string)
	instance:SetAttribute("DecoyText", text)
	CollectionService:AddTag(instance, "Decoy")
end

local function decoyPart(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

function EventService:_pickFloorMarker(): BasePart?
	local markers = self.Services.MapService:GetMarkers({ "Floor" }, nil)
	if #markers == 0 then
		return nil
	end
	return markers[math.random(1, #markers)]
end

EventService.DecoyBuilders = {
	-- A knocked-over wet floor sign.
	function(self, cleaner)
		local marker = self:_pickFloorMarker()
		if not marker then
			return
		end
		local model = Instance.new("Model")
		model.Name = "WetFloorSign"
		local base = marker.CFrame * CFrame.new(2, 0.35, 0) * CFrame.Angles(math.rad(90), math.rad(math.random(0, 360)), 0)
		decoyPart(model, Vector3.new(2, 3, 0.2), base * CFrame.new(0, 0, 0.35), Color3.fromRGB(250, 210, 40))
		decoyPart(model, Vector3.new(2, 3, 0.2), base * CFrame.new(0, 0, -0.35), Color3.fromRGB(250, 210, 40))
		model.Parent = self.Services.MapService.Folders.Decoys
		tagDecoy(model, "It's... just a wet floor sign. 😅")
		cleaner:Add(model)
	end,
	-- An arcade machine glitching out.
	function(self, cleaner)
		local cabinets = CollectionService:GetTagged("ArcadeCabinet")
		if #cabinets == 0 then
			return
		end
		local cabinet = cabinets[math.random(1, #cabinets)]
		local screen = cabinet:FindFirstChild("Screen")
		local display = screen and screen:FindFirstChildWhichIsA("SurfaceGui")
		local label = display and display:FindFirstChild("Line2")
		if not label or not label:IsA("TextLabel") then
			return
		end
		local original = label.Text
		local originalColor = label.TextColor3
		tagDecoy(cabinet, "Just a broken arcade machine. Probably.")
		local running = true
		cleaner:Add(function()
			running = false
			CollectionService:RemoveTag(cabinet, "Decoy")
			label.Text = original
			label.TextColor3 = originalColor
		end)
		cleaner:Add(task.spawn(function()
			while running do
				label.Text = if math.random() < 0.5 then "GAME OVER" else "PLAY AGAIN?"
				label.TextColor3 = Color3.fromRGB(255, 40, 40)
				task.wait(0.4)
			end
		end))
	end,
	-- Lights flickering in a random zone.
	function(self, cleaner)
		local zones = { "FoodCourt", "Arcade", "ToyStore", "Restrooms", "ServiceHalls", "ParkingGarage", "Supermarket", "Electronics", "Cinema" }
		local zone = zones[math.random(1, #zones)]
		local running = true
		cleaner:Add(function()
			running = false
		end)
		cleaner:Add(task.spawn(function()
			while running do
				self.Services.MapService:Flicker(zone, math.random(2, 4))
				task.wait(math.random(4, 9))
			end
		end))
	end,
	-- A loud slam somewhere in the mall.
	function(self, cleaner)
		local marker = self:_pickFloorMarker()
		if not marker then
			return
		end
		self.Services.AudioService:Play("Environment.DistantBang", marker.Position)
		cleaner:Add(task.delay(math.random(4, 8), function()
			self.Services.AudioService:Play("Door.Metal.Slam", marker.Position)
		end))
	end,
	-- A bouncing ball in the toy store.
	function(self, cleaner)
		local markers = self.Services.MapService:GetMarkers({ "Floor" }, { "ToyStore", "GrandHall", "Arcade" })
		if #markers == 0 then
			return
		end
		local marker = markers[math.random(1, #markers)]
		local ball = decoyPart(self.Services.MapService.Folders.Decoys, Vector3.new(1.6, 1.6, 1.6), marker.CFrame * CFrame.new(-2, 0.8, 0), Color3.fromRGB(230, 60, 60))
		ball.Shape = Enum.PartType.Ball
		tagDecoy(ball, "A bouncy ball. Kids lose these all the time.")
		local tween = TweenService:Create(ball, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1, true), {
			CFrame = ball.CFrame + Vector3.new(0, 2.5, 0),
		})
		tween:Play()
		cleaner:Add(tween)
		cleaner:Add(ball)
	end,
	-- A chair balanced on a table.
	function(self, cleaner)
		local markers = self.Services.MapService:GetMarkers({ "Floor" }, { "FoodCourt" })
		if #markers == 0 then
			return
		end
		local marker = markers[math.random(1, #markers)]
		local model = Instance.new("Model")
		model.Name = "StackedChair"
		local base = marker.CFrame * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, math.rad(math.random(0, 360)), math.rad(180))
		decoyPart(model, Vector3.new(1.6, 0.3, 1.6), base, Color3.fromRGB(200, 90, 60))
		decoyPart(model, Vector3.new(0.3, 1.8, 1.6), base * CFrame.new(0.8, 1, 0), Color3.fromRGB(200, 90, 60))
		model.Parent = self.Services.MapService.Folders.Decoys
		tagDecoy(model, "Someone stacked the chairs. Weird, but normal.")
		cleaner:Add(model)
	end,
}

---------------------------------------------------------------------------
-- Event handlers
---------------------------------------------------------------------------

EventService.Handlers = {
	Surge = {
		Start = function(self, event)
			self.Services.MapService:PushTint("Surge", Color3.fromRGB(228, 210, 255), -0.05, 0.08)
			event.Cleaner:Add(function()
				self.Services.MapService:PopTint("Surge")
			end)
			for _ = 1, event.Def.BurstSpawns or 0 do
				self.Services.AnomalyService:SpawnRandom()
			end
		end,
	},
	Blackout = {
		Start = function(self, event)
			self.Services.MapService:SetBlackout(true)
			self.AnnounceRemote:FireAllClients({
				Kind = "Toast",
				Text = "🔦 Pull out your FLASHLIGHT (slot 2). The breaker is in the ELECTRICAL room, back of house...",
				Color = Color3.fromRGB(150, 180, 255),
				Duration = 5,
			})
			event.Cleaner:Add(function()
				self.Services.MapService:SetBlackout(false)
			end)
			for _ = 1, event.Def.BurstSpawns or 0 do
				self.Services.AnomalyService:SpawnRandom({ RequireEvent = "Blackout" })
			end
		end,
	},
	FalseAlarm = {
		Start = function(self, event)
			local builders = table.clone(EventService.DecoyBuilders)
			for _ = 1, math.min(event.Def.DecoyCount, #builders) do
				local builder = table.remove(builders, math.random(1, #builders))
				local ok, err = pcall(builder, self, event.Cleaner)
				if not ok then
					warn("[EventService] decoy failed:", err)
				end
			end
			self.Services.AnomalyService:SpawnRandom({ MaxRarity = "Unusual", LifetimeMultiplier = 1.5 })
		end,
	},
	RareAnomaly = {
		Start = function(self, event)
			local record = self.Services.AnomalyService:SpawnRandom({
				MinRarity = event.Def.MinRarity,
				MaxRarity = event.Def.MaxRarity,
				LifetimeMultiplier = event.Def.LifetimeMultiplier,
			})
			if not record then
				record = self.Services.AnomalyService:SpawnRandom({ MinRarity = "Unusual", LifetimeMultiplier = event.Def.LifetimeMultiplier })
			end
			event.Record = record
		end,
		IsDone = function(_self, event)
			return event.Record == nil or event.Record.Despawning == true
		end,
	},
}

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function EventService:Init(services)
	self.Services = services
	self.EventRemote = Net.Event("EventUpdate")
	self.AnnounceRemote = Net.Event("Announce")
	services.DataService:OnClientReady(function(player)
		self.EventRemote:FireClient(player, self:_payload())
	end)
end

function EventService:_payload()
	local event = self.Active
	if not event then
		return { Id = nil }
	end
	return {
		Id = event.Id,
		Name = event.Def.Name,
		Icon = event.Def.Icon,
		Color = event.Def.Color,
		EndsAt = event.EndsAt,
		Buyer = event.BuyerName,
	}
end

function EventService:_broadcast()
	self.EventRemote:FireAllClients(self:_payload())
end

function EventService:StartRound()
	self.RoundActive = true
	self.RandomCount = 0
	self.NextRandomAt = now() + randomRange(EVENTS.FirstEventDelay)
	if self.LoopThread then
		pcall(task.cancel, self.LoopThread)
	end
	self.LoopThread = task.spawn(function()
		while self.RoundActive do
			local ok, err = pcall(self._tick, self)
			if not ok then
				warn("[EventService] tick error:", err)
			end
			task.wait(1)
		end
	end)
end

function EventService:StopRound()
	self.RoundActive = false
	if self.LoopThread and coroutine.status(self.LoopThread) ~= "dead" and coroutine.running() ~= self.LoopThread then
		pcall(task.cancel, self.LoopThread)
	end
	self.LoopThread = nil
	self:EndEvent()
end

function EventService:_timeLeft(): number
	local round = self.Services.MissionService
	if not round or round.State ~= "Round" then
		return 0
	end
	return round.EndsAt - now()
end

function EventService:_tick()
	local event = self.Active
	if event then
		local handler = self.Handlers[event.Id]
		local done = handler and handler.IsDone and handler.IsDone(self, event)
		if now() >= event.EndsAt or done then
			self:EndEvent()
		end
		return
	end

	local timeLeft = self:_timeLeft()
	if timeLeft < EVENTS.MinTimeLeftToStart then
		return
	end

	if #self.Queue > 0 then
		local queued = table.remove(self.Queue, 1)
		self:Trigger(queued.Id, { Source = "Purchase", BuyerName = queued.BuyerName })
		return
	end

	if EVENTS.RandomEventsEnabled and self.RandomCount < EVENTS.MaxRandomEventsPerRound and now() >= self.NextRandomAt then
		local total = 0
		for _, weight in pairs(EVENTS.RandomWeights) do
			total += weight
		end
		local roll = math.random() * total
		local chosen = nil
		for id, weight in pairs(EVENTS.RandomWeights) do
			roll -= weight
			if roll <= 0 then
				chosen = id
				break
			end
		end
		if chosen then
			self.RandomCount += 1
			self.NextRandomAt = now() + randomRange(EVENTS.EventInterval)
			self:Trigger(chosen, { Source = "Random" })
		end
	end
end

-- Starts an event immediately (used by the scheduler, purchases and admin commands).
function EventService:Trigger(eventId: string, options: { [string]: any }?): boolean
	local def = DEFS[eventId]
	if not def or not self.RoundActive then
		return false
	end
	local opts = options or {}
	if self.Active then
		self:EndEvent()
	end
	local duration = def.Duration
	local timeLeft = self:_timeLeft()
	if timeLeft > 0 then
		duration = math.min(duration, math.max(10, timeLeft - 5))
	end
	local event = {
		Id = eventId,
		Def = def,
		StartedAt = now(),
		EndsAt = now() + duration,
		Cleaner = Cleaner.new(),
		Source = opts.Source or "Random",
		BuyerName = opts.BuyerName,
	}
	self.Active = event

	local handler = self.Handlers[eventId]
	if handler and handler.Start then
		local ok, err = pcall(handler.Start, self, event)
		if not ok then
			warn("[EventService] Failed to start", eventId, err)
		end
	end

	local bannerText = def.Banner
	if event.BuyerName then
		if eventId == "Surge" then
			bannerText = string.format("👁️ %s CAUSED A PARANORMAL SURGE", string.upper(event.BuyerName))
		elseif eventId == "Blackout" then
			bannerText = string.format("🔦 %s CAUSED A BLACKOUT", string.upper(event.BuyerName))
		else
			bannerText = string.format("%s %s STARTED: %s", def.Icon, string.upper(event.BuyerName), def.Name)
		end
	end
	self.AnnounceRemote:FireAllClients({
		Kind = "Banner",
		Text = bannerText,
		SubText = if eventId == "Surge" and event.BuyerName then "⚠️ PARANORMAL ACTIVITY IS RISING - EVERYONE BENEFITS" else nil,
		Color = def.Color,
		Duration = 3.2,
	})
	self:_broadcast()
	return true
end

function EventService:EndEvent()
	local event = self.Active
	if not event then
		return
	end
	self.Active = nil
	local handler = self.Handlers[event.Id]
	if handler and handler.Stop then
		pcall(handler.Stop, self, event)
	end
	event.Cleaner:Clean()
	self:_broadcast()
end

function EventService:RequestPurchasedEvent(eventId: string, player: Player): boolean
	if not DEFS[eventId] then
		return false
	end
	table.insert(self.Queue, { Id = eventId, BuyerName = player.DisplayName })
	local def = DEFS[eventId]
	local round = self.Services.MissionService
	local message
	if self.Active or not self.RoundActive or self:_timeLeft() < EVENTS.MinTimeLeftToStart then
		message = string.format("%s %s queued - it starts as soon as possible for EVERYONE!", def.Icon, def.Name)
	else
		message = string.format("%s %s incoming!", def.Icon, def.Name)
	end
	self.AnnounceRemote:FireClient(player, {
		Kind = "Toast",
		Text = message,
		Color = def.Color,
	})
	if round and round.State == "Round" and not self.Active then
		task.defer(function()
			self:_tick()
		end)
	end
	return true
end

function EventService:IsActive(eventId: string): boolean
	return self.Active ~= nil and self.Active.Id == eventId
end

function EventService:GetModifiers()
	local modifiers = {
		SpawnIntervalMultiplier = 1,
		ExtraConcurrent = 0,
		Luck = {},
	}
	local event = self.Active
	if not event then
		return modifiers
	end
	modifiers.SpawnIntervalMultiplier = event.Def.SpawnIntervalMultiplier or 1
	modifiers.ExtraConcurrent = event.Def.ExtraConcurrent or 0
	if event.Id == "Surge" then
		for id, tier in pairs(RarityConfig.Tiers) do
			modifiers.Luck[id] = tier.SurgeLuck
		end
	end
	return modifiers
end

return EventService
