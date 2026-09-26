--[[
	Appearance (ModuleScript)
	Location: ServerScriptService/Anomalies/Appearance

	Where every anomaly body comes from. For each entry in LIBRARY, the first
	source that works wins:

	  1. ServerStorage/AnomalyModels/<Name>   a Model YOU inserted (Studio:
	     Toolbox / Avatar Shop bundle, or your own rig). Always preferred.
	  2. the catalog bundle / item            AssetService:GetBundleDetailsAsync
	     -> outfit -> Players:GetHumanoidDescriptionFromOutfitId ->
	     Players:CreateHumanoidModelFromDescription (R15). A single catalog
	     item (e.g. a head) is applied to an otherwise dark body.
	  3. a procedural silhouette              Rig.Style / Rig.Spider

	Everything is loaded once at server start (in the background) and cached;
	Get() returns a fresh clone. A copy of each loaded template is placed in
	ReplicatedStorage/AnomalyPreload so clients can preload its meshes and
	textures on the loading screen (no pop-in).

	Console output tells you exactly what happened, e.g.
	  [AnomalyModels] SmilingEntity: bundle 218626722487791 loaded
	  [AnomalyModels] AbnormalTitan: bundle failed (HTTP 403) - using the procedural Titan
]]

local AssetService = game:GetService("AssetService")
local InsertService = game:GetService("InsertService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Rig = require(script.Parent:WaitForChild("Rig"))

local Appearance = {}
Appearance.Templates = {} :: { [string]: Model }
Appearance.Sources = {} :: { [string]: string }
Appearance.Loading = {} :: { [string]: boolean }

--[[
	Bundle = catalog bundle id, Asset = catalog item id (head / accessory /
	model), Style = procedural fallback, Height = target height in studs.
	Catalog pages:
	  Abnormal Titan              https://www.roblox.com/bundles/130669835003582
	  Recolorable Smiling Entity  https://www.roblox.com/bundles/218626722487791
	  Possessed Horror            https://www.roblox.com/bundles/946396
	  Slacker Creepy Entity       https://www.roblox.com/bundles/239940076376674
	  Ratthew Animal Hospital     https://www.roblox.com/catalog/77243079770705
]]
Appearance.Library = {
	AbnormalTitan = { Bundle = 130669835003582, Style = "Titan", Height = 10.5 },
	SmilingEntity = { Bundle = 218626722487791, Style = "Smiler", Height = 7.4 },
	PossessedEntity = { Bundle = 946396, Style = "Possessed", Height = 5.8 },
	SlackerEntity = { Bundle = 239940076376674, Style = "Slacker", Height = 6 },
	RatthewAnomaly = { Asset = 77243079770705, Style = "Rat", Height = 5.4 },
	CeilingCrawler = { Spider = true },
	Mannequin = { Style = "Mannequin" },
	StoreDummy = { Style = "Dummy" },
	Faceless = { Style = "Faceless" },
	Shadow = { Style = "Shadow" },
	Employee = { Style = "Employee" },
	Listener = { Style = "Listener" },
}

-- AssetTypeId -> HumanoidDescription property (single catalog items)
local ACCESSORY_FIELDS = {
	[8] = "HatAccessory",
	[41] = "HairAccessory",
	[42] = "FaceAccessory",
	[43] = "NeckAccessory",
	[44] = "ShouldersAccessory",
	[45] = "FrontAccessory",
	[46] = "BackAccessory",
	[47] = "WaistAccessory",
}
local BODY_FIELDS = {
	[17] = "Head",
	[79] = "Head", -- dynamic head
	[18] = "Face",
	[27] = "Torso",
	[28] = "RightArm",
	[29] = "LeftArm",
	[30] = "LeftLeg",
	[31] = "RightLeg",
	[11] = "Shirt",
	[12] = "Pants",
	[2] = "GraphicTShirt",
}

local function sanitize(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BaseScript") or descendant:IsA("ForceField") or descendant:IsA("Sound") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanTouch = false
			descendant.CanCollide = false
			descendant.CastShadow = true
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.NameDisplayDistance = 0
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
	end
end

-- Any model without a Humanoid (a statue, a mesh) gets a root + Humanoid so it can walk.
local function ensureWalker(model: Model): Model
	if model:FindFirstChildOfClass("Humanoid") and model:FindFirstChild("HumanoidRootPart") then
		return model
	end
	local boxCFrame, size = model:GetBoundingBox()
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(math.max(size.X * 0.5, 1), 2, math.max(size.Z * 0.5, 1))
	root.Transparency = 1
	root.CanCollide = false
	root.CFrame = CFrame.new(boxCFrame.Position.X, boxCFrame.Position.Y - size.Y / 2 + size.Y * 0.45, boxCFrame.Position.Z)
	root.Parent = model
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= root then
			descendant.Anchored = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = math.max(0.5, root.Position.Y - (boxCFrame.Position.Y - size.Y / 2) - 1)
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

local function scaleTo(model: Model, height: number?)
	if not height then
		return
	end
	local ok, size = pcall(function()
		return model:GetExtentsSize()
	end)
	if ok and size.Y > 0.5 then
		local factor = height / size.Y
		if math.abs(factor - 1) > 0.03 then
			pcall(function()
				model:ScaleTo(model:GetScale() * factor)
			end)
		end
	end
end

function Appearance:Init(services)
	self.Services = services
	local cache = Instance.new("Folder")
	cache.Name = "COC_AppearanceCache"
	cache.Parent = ServerStorage
	self.Cache = cache
	local preload = ReplicatedStorage:FindFirstChild("AnomalyPreload")
	if not preload then
		preload = Instance.new("Folder")
		preload.Name = "AnomalyPreload"
		preload.Parent = ReplicatedStorage
	end
	self.Preload = preload
	for name, def in pairs(self.Library) do
		self.Loading[name] = true
		task.spawn(function()
			local ok, err = pcall(self._load, self, name, def)
			if not ok then
				warn(string.format("[AnomalyModels] %s: load error %s - using the procedural model", name, tostring(err)))
				self:_setTemplate(name, self:_procedural(def), "Procedural")
			end
			self.Loading[name] = nil
		end)
	end
end

function Appearance:_procedural(def): Model
	if def.Spider then
		return Rig.Spider()
	end
	return Rig.Style(def.Style or "Shadow") or Rig.Style("Shadow") :: Model
end

function Appearance:_setTemplate(name: string, model: Model, source: string)
	sanitize(model)
	model.Name = name
	model:SetAttribute("AppearanceSource", source)
	model.Parent = self.Cache
	self.Templates[name] = model
	self.Sources[name] = source
	-- client preload copy (meshes / textures only matter for real catalog rigs)
	if source ~= "Procedural" then
		local copy = model:Clone()
		copy.Parent = self.Preload
	end
end

function Appearance:_override(name: string): Model?
	local folder = ServerStorage:FindFirstChild("AnomalyModels")
	local slot = folder and folder:FindFirstChild(name)
	if not slot then
		return nil
	end
	for _, child in ipairs(slot:GetChildren()) do
		if child:IsA("Model") then
			local clone = child:Clone()
			return ensureWalker(clone)
		end
	end
	return nil
end

function Appearance:_descriptionFromBundle(bundleId: number): (HumanoidDescription?, string?)
	local ok, details = pcall(function()
		return AssetService:GetBundleDetailsAsync(bundleId)
	end)
	if not ok or type(details) ~= "table" then
		return nil, "GetBundleDetailsAsync: " .. tostring(details)
	end
	for _, item in ipairs(details.Items or {}) do
		if item.Type == "UserOutfit" then
			local okOutfit, description = pcall(function()
				return Players:GetHumanoidDescriptionFromOutfitId(item.Id)
			end)
			if okOutfit and description then
				return description, nil
			end
			return nil, "outfit " .. tostring(item.Id) .. ": " .. tostring(description)
		end
	end
	-- no outfit in the bundle: assemble the description from its assets
	local description = Instance.new("HumanoidDescription")
	local applied = 0
	for _, item in ipairs(details.Items or {}) do
		if item.Type == "Asset" and self:_applyAsset(description, item.Id) then
			applied += 1
		end
	end
	if applied == 0 then
		description:Destroy()
		return nil, "bundle has no usable items"
	end
	return description, nil
end

function Appearance:_applyAsset(description: HumanoidDescription, assetId: number): boolean
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(assetId, Enum.InfoType.Asset)
	end)
	if not ok or type(info) ~= "table" then
		return false
	end
	local typeId = info.AssetTypeId
	local body = BODY_FIELDS[typeId]
	if body then
		(description :: any)[body] = assetId
		return true
	end
	local accessory = ACCESSORY_FIELDS[typeId]
	if accessory then
		local current = (description :: any)[accessory]
		;(description :: any)[accessory] = if current ~= "" then current .. "," .. tostring(assetId) else tostring(assetId)
		return true
	end
	if typeId and typeId >= 64 and typeId <= 72 then
		-- layered clothing
		local list = description:GetAccessories(true)
		table.insert(list, { AssetId = assetId, AccessoryType = Enum.AccessoryType.Unknown, IsLayered = true, Order = #list + 1 })
		pcall(function()
			description:SetAccessories(list, true)
		end)
		return true
	end
	return false
end

function Appearance:_rigFromDescription(description: HumanoidDescription): (Model?, string?)
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if ok and rig then
		return rig, nil
	end
	return nil, "CreateHumanoidModelFromDescription: " .. tostring(rig)
end

function Appearance:_load(name: string, def)
	local override = self:_override(name)
	if override then
		scaleTo(override, def.Height)
		self:_setTemplate(name, override, "Override")
		print(string.format("[AnomalyModels] %s: using your model from ServerStorage.AnomalyModels.%s", name, name))
		return
	end
	local description, reason = nil, nil
	if def.Bundle then
		description, reason = self:_descriptionFromBundle(def.Bundle)
	elseif def.Asset then
		-- a catalog item: try it as a bundle first, then as a single item on a dark body
		description, reason = self:_descriptionFromBundle(def.Asset)
		if not description then
			local base = Instance.new("HumanoidDescription")
			base.HeadColor = Color3.fromRGB(110, 100, 96)
			base.TorsoColor = Color3.fromRGB(40, 40, 44)
			base.LeftArmColor = Color3.fromRGB(110, 100, 96)
			base.RightArmColor = Color3.fromRGB(110, 100, 96)
			base.LeftLegColor = Color3.fromRGB(40, 40, 44)
			base.RightLegColor = Color3.fromRGB(40, 40, 44)
			if self:_applyAsset(base, def.Asset) then
				description, reason = base, nil
			else
				-- a model asset (only works if the place owner may insert it)
				local okModel, container = pcall(function()
					return InsertService:LoadAsset(def.Asset)
				end)
				local model = okModel and container and container:FindFirstChildWhichIsA("Model")
				if model then
					local walker = ensureWalker(model:Clone())
					scaleTo(walker, def.Height)
					self:_setTemplate(name, walker, "Asset")
					print(string.format("[AnomalyModels] %s: model asset %d inserted", name, def.Asset))
					return
				end
				base:Destroy()
				reason = (reason or "") .. " / item not usable"
			end
		end
	end
	if description then
		local rig, rigError = self:_rigFromDescription(description)
		if rig then
			scaleTo(rig, def.Height)
			self:_setTemplate(name, rig, "Catalog")
			print(string.format("[AnomalyModels] %s: catalog %s %d loaded", name, if def.Bundle then "bundle" else "item", def.Bundle or def.Asset))
			return
		end
		reason = rigError
	end
	if def.Bundle or def.Asset then
		warn(string.format("[AnomalyModels] %s: catalog %d could not be loaded (%s) - using the procedural %s. Insert the bundle into ServerStorage.AnomalyModels.%s to use it.", name, def.Bundle or def.Asset, tostring(reason), def.Style or "model", name))
	end
	self:_setTemplate(name, self:_procedural(def), "Procedural")
end

-- A fresh body for an anomaly. Waits briefly while the catalog load finishes.
function Appearance:Get(name: string): Model
	local deadline = os.clock() + 3
	while not self.Templates[name] and self.Loading[name] and os.clock() < deadline do
		task.wait(0.1)
	end
	local template = self.Templates[name]
	local model: Model
	if template then
		model = template:Clone()
	else
		local def = self.Library[name] or { Style = name }
		model = self:_procedural(def)
		sanitize(model)
	end
	model:SetAttribute("Appearance", name)
	return model
end

function Appearance:GetSource(name: string): string
	return self.Sources[name] or (if self.Loading[name] then "Loading" else "Procedural")
end

return Appearance
