local EggService = {}
EggService.__index = EggService

local ServerStorage = game:GetService("ServerStorage")

local HomeCfg = require(script.Parent:WaitForChild("HomeCfg"))

local function findPath(parent, path)
	local current = parent

	for _, name in ipairs(path) do
		if not current then
			return nil
		end

		current = current:FindFirstChild(name)
	end

	return current
end

function EggService.new(inventoryService)
	local self = setmetatable({}, EggService)

	self.InventoryService = inventoryService
	self.EggTemplate = self:FindEggTemplate()
	self.NextSerial = 0
	self.CollectedByUser = {}

	if self.EggTemplate then
		print("[EggService] Egg template:", self.EggTemplate:GetFullName())
	else
		warn("[EggService] No encontrÃ© EggTemplate.")
	end

	return self
end

function EggService:FindEggTemplate()
	local candidates = {
		{ "Assets", "HomesteadAnimals", "EggTemplate" },
		{ "Assets", "HomesteadAnimals", "HuevoTemplate" },
		{ "Assets", "HomesteadAnimals", "Huevo" },
		{ "Assets", "EggTemplate" },
		{ "EggTemplate" },
	}

	for _, path in ipairs(candidates) do
		local obj = findPath(ServerStorage, path)

		if obj and (obj:IsA("Model") or obj:IsA("BasePart")) then
			return obj
		end
	end

	return nil
end

function EggService:GetEggFolder(homeData)
	local animals = homeData.RuntimeFolder:FindFirstChild("Animals")

	if not animals then
		animals = Instance.new("Folder")
		animals.Name = "Animals"
		animals.Parent = homeData.RuntimeFolder
	end

	local eggs = animals:FindFirstChild("Eggs")

	if not eggs then
		eggs = Instance.new("Folder")
		eggs.Name = "Eggs"
		eggs.Parent = animals
	end

	return eggs
end

function EggService:GetChickenEggCount(chicken)
	local model = chicken.Model
	if not model then
		return 0
	end

	return model:GetAttribute("ActiveEggs") or 0
end

function EggService:CanLayEgg(chicken)
	if not self.EggTemplate then
		return false
	end

	local maxEggs = HomeCfg.Animals.Chicken.MaxActiveEggsPerChicken or 4

	return self:GetChickenEggCount(chicken) < maxEggs
end

function EggService:PrepareEggModel(eggObject)
	local model

	if eggObject:IsA("Model") then
		model = eggObject
	else
		model = Instance.new("Model")
		model.Name = "EggModel"

		eggObject.Parent = model
		model.PrimaryPart = eggObject
	end

	if not model.PrimaryPart then
		local primary = model:FindFirstChildWhichIsA("BasePart", true)
		if primary then
			model.PrimaryPart = primary
		end
	end

	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Anchored = true
			desc.CanCollide = false
			desc.CanTouch = false
			desc.CanQuery = true
		end
	end

	return model
end

function EggService:LayEgg(chicken, eggPoint, homeData)
	if not self:CanLayEgg(chicken) then
		return nil
	end

	if not eggPoint or not eggPoint:IsA("BasePart") then
		return nil
	end

	local eggFolder = self:GetEggFolder(homeData)

	self.NextSerial += 1

	local clone = self.EggTemplate:Clone()
	local eggModel = self:PrepareEggModel(clone)

	local ownerId = chicken.Owner.UserId
	local chickenIndex = chicken.Index

	eggModel.Name = "Egg_" .. ownerId .. "_" .. chickenIndex .. "_" .. self.NextSerial
	eggModel.Parent = eggFolder

	local pos = eggPoint.Position + Vector3.new(0, 0.35, 0)
	eggModel:PivotTo(CFrame.new(pos))

	eggModel:SetAttribute("OwnerId", ownerId)
	eggModel:SetAttribute("OwnerName", chicken.Owner.Name)
	eggModel:SetAttribute("ChickenIndex", chickenIndex)
	eggModel:SetAttribute("Collected", false)

	local active = self:GetChickenEggCount(chicken) + 1
	chicken.Model:SetAttribute("ActiveEggs", active)

	local primary = eggModel.PrimaryPart

	if primary then
		local prompt = primary:FindFirstChildOfClass("ProximityPrompt")

		if not prompt then
			prompt = Instance.new("ProximityPrompt")
			prompt.Parent = primary
		end

		prompt.ActionText = HomeCfg.Eggs.PromptActionText
		prompt.ObjectText = HomeCfg.Eggs.PromptObjectText
		prompt.MaxActivationDistance = HomeCfg.Eggs.CollectDistance
		prompt.RequiresLineOfSight = false

		prompt.Triggered:Connect(function(player)
			if player.UserId ~= ownerId then
				return
			end

			if eggModel:GetAttribute("Collected") == true then
				return
			end

			eggModel:SetAttribute("Collected", true)

			self.CollectedByUser[ownerId] = (self.CollectedByUser[ownerId] or 0) + 1

			if self.InventoryService then
				local _, newEggCount = self.InventoryService:AddItem(player, "Egg", 1)
				player:SetAttribute("SlingshotEggAmmo", newEggCount or self.InventoryService:GetItemCount(player, "Egg"))
			end

			if chicken.Model then
				local current = math.max((chicken.Model:GetAttribute("ActiveEggs") or 1) - 1, 0)
				chicken.Model:SetAttribute("ActiveEggs", current)
			end

			if HomeCfg.Debug.PrintEggs then
				print("[EggService]", player.Name, "recogiÃ³ huevo. Total sesiÃ³n:", self.CollectedByUser[ownerId])
			end

			eggModel:Destroy()
		end)
	end

	if HomeCfg.Debug.PrintEggs then
		print("[EggService] Huevo puesto:", eggModel.Name, "activeEggs:", active)
	end

	return eggModel
end

function EggService:GetCollectedCount(player)
	return self.CollectedByUser[player.UserId] or 0
end

return EggService
