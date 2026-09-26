--[[
	EconomyService (ModuleScript)
	Location: ServerScriptService/Services/EconomyService

	Owns the Evidence currency, camera ownership/equipping, upgrades and the
	leaderboard values. The client can only *ask* to buy/equip through the
	ShopRequest RemoteFunction; every rule is validated here.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Config")
local CameraConfig = require(Config:WaitForChild("CameraConfig"))
local EquipmentConfig = require(Config:WaitForChild("EquipmentConfig"))
local CosmeticsConfig = require(Config:WaitForChild("CosmeticsConfig"))
local Net = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"))
local Format = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Format"))

local EconomyService = {}
EconomyService._lastShop = {}

function EconomyService:Init(services)
	self.Services = services
	local dataService = services.DataService

	dataService:OnProfileLoaded(function(player, data)
		self:_setupLeaderstats(player, data)
	end)

	Net.Function("ShopRequest").OnServerInvoke = function(player, action, id)
		return self:_handleShop(player, action, id)
	end

	Players.PlayerRemoving:Connect(function(player)
		self._lastShop[player] = nil
	end)
end

function EconomyService:_setupLeaderstats(player: Player, data)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end
	local evidence = leaderstats:FindFirstChild("Evidence") or Instance.new("IntValue")
	evidence.Name = "Evidence"
	evidence.Parent = leaderstats
	local found = leaderstats:FindFirstChild("Found") or Instance.new("IntValue")
	found.Name = "Found"
	found.Parent = leaderstats
	self:UpdateLeaderstats(player)
end

function EconomyService:UpdateLeaderstats(player: Player)
	local data = self.Services.DataService:GetData(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not data or not leaderstats then
		return
	end
	local evidence = leaderstats:FindFirstChild("Evidence")
	if evidence and evidence:IsA("IntValue") then
		evidence.Value = data.Evidence
	end
	local found = leaderstats:FindFirstChild("Found")
	if found and found:IsA("IntValue") then
		found.Value = self.Services.DataService:CountDiscoveries(player)
	end
end

function EconomyService:GetEvidence(player: Player): number
	local data = self.Services.DataService:GetData(player)
	return data and data.Evidence or 0
end

function EconomyService:AddEvidence(player: Player, amount: number, _source: string?)
	local data = self.Services.DataService:GetData(player)
	if not data or type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return
	end
	amount = math.floor(amount)
	data.Evidence += amount
	data.LifetimeEvidence += amount
	self:UpdateLeaderstats(player)
	self.Services.DataService:MarkChanged(player)
end

function EconomyService:SpendEvidence(player: Player, amount: number): boolean
	local data = self.Services.DataService:GetData(player)
	if not data or amount < 0 or data.Evidence < amount then
		return false
	end
	data.Evidence -= amount
	self:UpdateLeaderstats(player)
	self.Services.DataService:MarkChanged(player)
	return true
end

function EconomyService:OwnsCamera(player: Player, cameraId: string): boolean
	local def = CameraConfig.Get(cameraId)
	if not def then
		return false
	end
	if def.Price == 0 then
		return true
	end
	local data = self.Services.DataService:GetData(player)
	if data and data.OwnedCameras[cameraId] then
		return true
	end
	local monetization = self.Services.MonetizationService
	if def.GamePass and monetization and monetization:HasPass(player, def.GamePass) then
		return true
	end
	return false
end

function EconomyService:GetEquippedCameraId(player: Player): string
	local data = self.Services.DataService:GetData(player)
	local id = data and data.EquippedCamera or CameraConfig.DefaultCamera
	local def = CameraConfig.Get(id)
	if not def or not def.Implemented or not self:OwnsCamera(player, id) then
		return CameraConfig.DefaultCamera
	end
	return id
end

function EconomyService:GetCameraStats(player: Player)
	local data = self.Services.DataService:GetData(player)
	return CameraConfig.GetStats(self:GetEquippedCameraId(player), data and data.Upgrades or nil)
end

function EconomyService:_handleShop(player: Player, action: any, id: any)
	local now = os.clock()
	if self._lastShop[player] and now - self._lastShop[player] < 0.3 then
		return false, "Slow down!"
	end
	self._lastShop[player] = now

	if type(action) ~= "string" or type(id) ~= "string" or #id > 40 then
		return false, "Invalid request"
	end
	local data = self.Services.DataService:GetData(player)
	if not data then
		return false, "Your data is still loading"
	end

	if action == "BuyCamera" then
		local def = CameraConfig.Get(id)
		if not def then
			return false, "Unknown camera"
		end
		if not def.Implemented then
			return false, "Coming soon!"
		end
		if self:OwnsCamera(player, id) then
			return false, "Already owned"
		end
		if not self:SpendEvidence(player, def.Price) then
			return false, "Not enough Evidence (" .. Format.Money(def.Price) .. ")"
		end
		data.OwnedCameras[id] = true
		data.EquippedCamera = id
		self:_afterCameraChange(player)
		return true, def.Name .. " unlocked!"
	elseif action == "EquipCamera" then
		local def = CameraConfig.Get(id)
		if not def or not def.Implemented then
			return false, "Unavailable"
		end
		if not self:OwnsCamera(player, id) then
			return false, "You don't own this camera"
		end
		data.EquippedCamera = id
		self:_afterCameraChange(player)
		return true, def.Name .. " equipped"
	elseif action == "BuyUpgrade" then
		local def = CameraConfig.GetUpgrade(id)
		if not def then
			return false, "Unknown upgrade"
		end
		local level = data.Upgrades[id] or 0
		if level >= def.MaxLevel then
			return false, "Max level"
		end
		local price = def.Prices[level + 1]
		if not self:SpendEvidence(player, price) then
			return false, "Not enough Evidence (" .. Format.Money(price) .. ")"
		end
		data.Upgrades[id] = level + 1
		self.Services.DataService:MarkChanged(player)
		return true, string.format("%s upgraded to level %d!", def.Name, level + 1)
	elseif action == "BuyFlashlightUpgrade" then
		local def = EquipmentConfig.FlashlightUpgrades[id]
		if not def then
			return false, "Unknown upgrade"
		end
		local level = data.FlashlightUpgrades[id] or 0
		if level >= def.MaxLevel then
			return false, "Max level"
		end
		local price = def.Prices[level + 1]
		if not self:SpendEvidence(player, price) then
			return false, "Not enough Evidence (" .. Format.Money(price) .. ")"
		end
		data.FlashlightUpgrades[id] = level + 1
		self.Services.DataService:MarkChanged(player)
		self.Services.EquipmentService:RefreshTools(player)
		return true, string.format("%s upgraded to level %d!", def.Name, level + 1)
	elseif action == "EquipSkin" then
		local skin = CosmeticsConfig.Skins[id]
		if not skin then
			return false, "Unknown skin"
		end
		if not self.Services.MonetizationService:OwnsCosmetic(player, id) then
			return false, "You don't own this skin yet"
		end
		data.Cosmetics.Equipped[skin.Item] = id
		self.Services.DataService:MarkChanged(player)
		self.Services.EquipmentService:RefreshTools(player)
		return true, skin.Name .. " equipped"
	elseif action == "EquipDecor" then
		local decor = CosmeticsConfig.Decor[id]
		if not decor then
			return false, "Unknown decoration"
		end
		if not self.Services.MonetizationService:OwnsCosmetic(player, id) then
			return false, "You don't own this decoration yet"
		end
		data.Cosmetics.Decor = id
		self.Services.DataService:MarkChanged(player)
		return true, decor.Name .. " set up in your Dark Room"
	elseif action == "BuyEquipment" then
		local item = EquipmentConfig.Get(id)
		if not item then
			return false, "Unknown equipment"
		end
		if item.Price == 0 or self.Services.EquipmentService:Owns(player, id) then
			return false, "Already owned"
		end
		if not self:SpendEvidence(player, item.Price) then
			return false, "Not enough Evidence (" .. Format.Money(item.Price) .. ")"
		end
		data.OwnedEquipment[id] = true
		self.Services.DataService:MarkChanged(player)
		if self.Services.EquipmentService then
			self.Services.EquipmentService:RefreshTools(player)
		end
		return true, item.Name .. " added to your hotbar!"
	end
	return false, "Unknown action"
end

function EconomyService:_afterCameraChange(player: Player)
	self.Services.DataService:MarkChanged(player)
	if self.Services.CharacterService then
		self.Services.CharacterService:RefreshCharacter(player)
	end
end

return EconomyService
