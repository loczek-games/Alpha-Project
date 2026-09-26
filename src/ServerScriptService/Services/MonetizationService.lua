--[[
	MonetizationService (ModuleScript)
	Location: ServerScriptService/Services/MonetizationService

	Game Passes + Developer Products. Everything is granted on the server.
	ProcessReceipt is idempotent: every PurchaseId is stored in the buyer's
	save before PurchaseGranted is returned, so a receipt is never granted twice
	(Roblox re-sends receipts until PurchaseGranted is returned).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = ReplicatedStorage:WaitForChild("Config")
local MonetizationConfig = require(Config:WaitForChild("MonetizationConfig"))
local GameConfig = require(Config:WaitForChild("GameConfig"))
local CameraConfig = require(Config:WaitForChild("CameraConfig"))
local CosmeticsConfig = require(Config:WaitForChild("CosmeticsConfig"))

local MonetizationService = {}
MonetizationService.PassCache = {}

function MonetizationService:Init(services)
	self.Services = services

	MarketplaceService.ProcessReceipt = function(receiptInfo)
		return self:ProcessReceipt(receiptInfo)
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		if not wasPurchased then
			return
		end
		local pass = MonetizationConfig.GetPassByPassId(passId)
		if pass then
			self:_grantPass(player, pass.Key, true)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		self:_refreshPasses(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.PassCache[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:_refreshPasses(player)
		end)
	end
end

function MonetizationService:_refreshPasses(player: Player)
	local cache = self.PassCache[player] or {}
	self.PassCache[player] = cache
	local grantAll = RunService:IsStudio() and GameConfig.Debug.StudioGrantAllPasses
	for key, pass in pairs(MonetizationConfig.GamePasses) do
		if grantAll then
			cache[key] = true
		elseif MonetizationConfig.IsConfigured(pass) then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok and owns then
				cache[key] = true
			elseif not ok then
				warn("[MonetizationService] Pass check failed for", player.Name, key, owns)
			end
		end
	end
	self:_applyPassEffects(player)
end

function MonetizationService:_grantPass(player: Player, key: string, announce: boolean?)
	local cache = self.PassCache[player] or {}
	self.PassCache[player] = cache
	cache[key] = true
	if announce then
		-- a freshly bought camera pass equips that camera straight away
		local data = self.Services.DataService:GetData(player)
		if data then
			for cameraId, camera in pairs(CameraConfig.Cameras) do
				if camera.GamePass == key and camera.Implemented then
					data.EquippedCamera = cameraId
				end
			end
		end
	end
	self:_applyPassEffects(player)
	if announce then
		local pass = MonetizationConfig.GamePasses[key]
		local announceRemote = self.Services.EventService and self.Services.EventService.AnnounceRemote
		if announceRemote and pass then
			announceRemote:FireClient(player, {
				Kind = "Toast",
				Text = string.format("%s %s unlocked! Thank you!", pass.Icon, pass.Name),
				Color = Color3.fromRGB(255, 215, 90),
			})
		end
	end
end

function MonetizationService:_applyPassEffects(player: Player)
	if not player:IsDescendantOf(Players) then
		return
	end
	player:SetAttribute("VIP", self:HasPass(player, "VIPInvestigator"))
	local services = self.Services
	if services.CharacterService then
		services.CharacterService:RefreshCharacter(player)
	end
	if services.DataService then
		services.DataService:MarkChanged(player)
	end
end

function MonetizationService:HasPass(player: Player, key: string): boolean
	local cache = self.PassCache[player]
	return cache ~= nil and cache[key] == true
end

function MonetizationService:GetOwnedPasses(player: Player)
	local owned = {}
	for key in pairs(MonetizationConfig.GamePasses) do
		owned[key] = self:HasPass(player, key)
	end
	return owned
end

-- Skins / dark room decor: free, included in a pass, or bought as a product.
function MonetizationService:OwnsCosmetic(player: Player, cosmeticId: string): boolean
	local def = CosmeticsConfig.Skins[cosmeticId] or CosmeticsConfig.Decor[cosmeticId]
	if not def then
		return false
	end
	if def.Free then
		return true
	end
	if def.Pass and self:HasPass(player, def.Pass) then
		return true
	end
	local data = self.Services.DataService:GetData(player)
	return data ~= nil and data.Cosmetics.Owned[cosmeticId] == true
end

function MonetizationService:_grantProduct(player: Player, product): boolean
	local services = self.Services
	if product.Kind == "Evidence" then
		services.EconomyService:AddEvidence(player, product.Amount, "Purchase")
		return true
	elseif product.Kind == "ServerEvent" then
		return services.EventService:RequestPurchasedEvent(product.Event, player)
	elseif product.Kind == "Revive" then
		if services.CharacterService:IsDowned(player) then
			services.CharacterService:Revive(player, nil)
		else
			local data = services.DataService:GetData(player)
			if not data then
				return false
			end
			data.ReviveTokens = (data.ReviveTokens or 0) + 1
			services.DataService:MarkChanged(player)
		end
		self:_toast(player, "🩹 REVIVE ready. Thank you!")
		return true
	elseif product.Kind == "Cosmetic" then
		local data = services.DataService:GetData(player)
		if not data then
			return false
		end
		data.Cosmetics.Owned[product.Cosmetic] = true
		local skin = CosmeticsConfig.Skins[product.Cosmetic]
		if skin then
			data.Cosmetics.Equipped[skin.Item] = skin.Id
		elseif CosmeticsConfig.Decor[product.Cosmetic] then
			data.Cosmetics.Decor = product.Cosmetic
		end
		services.DataService:MarkChanged(player)
		services.EquipmentService:RefreshTools(player)
		self:_toast(player, string.format("%s %s unlocked!", product.Icon, product.Name))
		return true
	end
	warn("[MonetizationService] Unknown product kind", product.Kind)
	return false
end

function MonetizationService:_toast(player: Player, text: string)
	local announceRemote = self.Services.EventService and self.Services.EventService.AnnounceRemote
	if announceRemote then
		announceRemote:FireClient(player, { Kind = "Toast", Text = text, Color = Color3.fromRGB(222, 184, 96) })
	end
end

function MonetizationService:ProcessReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- Player left; Roblox will retry next time they join.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local dataService = self.Services.DataService
	local profile = dataService:WaitForProfile(player, 15)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receiptInfo.PurchaseId)
	if dataService:HasReceipt(player, purchaseId) then
		-- Already granted (possibly the save failed last time): just confirm.
		if dataService:SaveNow(player) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local product = MonetizationConfig.GetProductByProductId(receiptInfo.ProductId)
	if not product then
		warn("[MonetizationService] Receipt for unknown product id", receiptInfo.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, granted = pcall(function()
		return self:_grantProduct(player, product)
	end)
	if not ok or not granted then
		warn("[MonetizationService] Failed to grant", product.Key, ok and "" or granted)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Record the receipt BEFORE confirming. If saving fails the in-memory mark
	-- still prevents a double grant in this server, and Roblox retries later.
	dataService:MarkReceipt(player, purchaseId)
	if not dataService:SaveNow(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

return MonetizationService
