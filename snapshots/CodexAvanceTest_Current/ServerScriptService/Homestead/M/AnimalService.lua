local AnimalService = {}
AnimalService.__index = AnimalService

local ServerStorage = game:GetService("ServerStorage")

local HomeCfg = require(script.Parent:WaitForChild("HomeCfg"))
local Chicken = require(script.Parent:WaitForChild("Chicken"))
local Cuy = require(script.Parent:WaitForChild("Cuy"))
local EggService = require(script.Parent:WaitForChild("EggService"))

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

local function unequipPlayerTools(player)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:UnequipTools()
	end
end

function AnimalService.new(homeService, inventoryService)
	local self = setmetatable({}, AnimalService)

	self.HomeService = homeService
	self.InventoryService = inventoryService
	self.PlayerAnimals = {}
	self.CarriedByUser = {}

	self.EggService = EggService.new(inventoryService)
	self.ChickenTemplate = self:FindChickenTemplate()
	self.CuyTemplate = self:FindCuyTemplate()

	if self.ChickenTemplate then
		print("[AnimalService] Chicken template:", self.ChickenTemplate:GetFullName())
	else
		warn("[AnimalService] No encontrÃ© ChickenTemplate/Gallina. ColÃ³calo en ServerStorage > Assets > HomesteadAnimals > ChickenTemplate")
	end

	if self.CuyTemplate then
		print("[AnimalService] Cuy template:", self.CuyTemplate:GetFullName())
	else
		warn("[AnimalService] No encontrÃ© CuyTemplate/Cuy. ColÃ³calo en ServerStorage > Assets > HomesteadAnimals > CuyTemplate")
	end

	return self
end

function AnimalService:FindChickenTemplate()
	local candidates = {
		{ "Assets", "HomesteadAnimals", "ChickenTemplate" },
		{ "Assets", "HomesteadAnimals", "Gallina" },
		{ "Assets", "Gallina" },
		{ "Gallina" },
	}

	for _, path in ipairs(candidates) do
		local obj = findPath(ServerStorage, path)
		if obj and obj:IsA("Model") then
			return obj
		end
	end

	return nil
end

function AnimalService:FindCuyTemplate()
	local candidates = {
		{ "Assets", "HomesteadAnimals", "CuyTemplate" },
		{ "Assets", "HomesteadAnimals", "Cuy" },
		{ "Assets", "Cuy" },
		{ "Cuy" },
	}

	for _, path in ipairs(candidates) do
		local obj = findPath(ServerStorage, path)
		if obj and obj:IsA("Model") then
			return obj
		end
	end

	return nil
end

function AnimalService:GetAnimalRoot(homeData)
	local animals = homeData.RuntimeFolder:FindFirstChild("Animals")
	if not animals then
		animals = Instance.new("Folder")
		animals.Name = "Animals"
		animals.Parent = homeData.RuntimeFolder
	end

	local chickens = animals:FindFirstChild("Chickens")
	if not chickens then
		chickens = Instance.new("Folder")
		chickens.Name = "Chickens"
		chickens.Parent = animals
	end

	local eggs = animals:FindFirstChild("Eggs")
	if not eggs then
		eggs = Instance.new("Folder")
		eggs.Name = "Eggs"
		eggs.Parent = animals
	end

	local cuys = animals:FindFirstChild("Cuys")
	if not cuys then
		cuys = Instance.new("Folder")
		cuys.Name = "Cuys"
		cuys.Parent = animals
	end

	return animals, chickens, eggs, cuys
end

function AnimalService:GetChickenSpawns(house)
	local animalSpawns = house:FindFirstChild(HomeCfg.Names.AnimalSpawns)
	local chickenSpawns = animalSpawns and animalSpawns:FindFirstChild(HomeCfg.Names.ChickenSpawns)
	local spawns = {}

	if chickenSpawns then
		for _, obj in ipairs(chickenSpawns:GetChildren()) do
			if obj:IsA("BasePart") then
				table.insert(spawns, obj)
			end
		end
	end

	table.sort(spawns, function(a, b)
		return a.Name < b.Name
	end)

	return spawns
end

function AnimalService:GetCuySpawns(house)
	local animalSpawns = house:FindFirstChild(HomeCfg.Names.AnimalSpawns)
	local cuySpawns = animalSpawns and animalSpawns:FindFirstChild(HomeCfg.Names.CuySpawns)
	local spawns = {}

	if cuySpawns then
		for _, obj in ipairs(cuySpawns:GetChildren()) do
			if obj:IsA("BasePart") then
				table.insert(spawns, obj)
			end
		end
	end

	table.sort(spawns, function(a, b)
		return a.Name < b.Name
	end)

	return spawns
end

function AnimalService:RefreshPlayer(player, homeData)
	if not homeData then
		self:Release(player)
		return
	end

	local _, chickenFolder, _, cuyFolder = self:GetAnimalRoot(homeData)

	local data = self.PlayerAnimals[player.UserId]
	if not data then
		data = {
			Chickens = {},
			Cuys = {},
			House = homeData.House,
		}
		self.PlayerAnimals[player.UserId] = data
	end

	data.Chickens = data.Chickens or {}
	data.Cuys = data.Cuys or {}

	if data.House ~= homeData.House then
		self:Release(player)
		data = {
			Chickens = {},
			Cuys = {},
			House = homeData.House,
		}
		self.PlayerAnimals[player.UserId] = data
	end

	if self.ChickenTemplate and #data.Chickens == 0 then
		local spawns = self:GetChickenSpawns(homeData.House)
		local count = math.min(HomeCfg.Animals.Chicken.Count, #spawns)

		for i = 1, count do
			local model = self.ChickenTemplate:Clone()
			model.Name = "Chicken_" .. player.UserId .. "_" .. i
			model.Parent = chickenFolder

			local chicken = Chicken.new(model, player, homeData.House, spawns[i], i, self.EggService, homeData, self)
			table.insert(data.Chickens, chicken)
		end

		if HomeCfg.Debug.PrintAnimalSpawn then
			print("[AnimalService] Gallinas creadas:", player.Name, count)
		end
	end

	if self.CuyTemplate and #data.Cuys == 0 then
		local spawns = self:GetCuySpawns(homeData.House)
		local count = math.min(HomeCfg.Animals.Cuy.Count, #spawns)

		for i = 1, count do
			local model = self.CuyTemplate:Clone()
			model.Name = "Cuy_" .. player.UserId .. "_" .. i
			model.Parent = cuyFolder

			local cuy = Cuy.new(model, player, homeData.House, spawns[i], i, self)
			table.insert(data.Cuys, cuy)
		end

		if HomeCfg.Debug.PrintAnimalSpawn then
			print("[AnimalService] Cuys creados:", player.Name, count)
		end
	end
end

function AnimalService:TryCarryChicken(player, chicken)
	if not player or not chicken then
		return false
	end

	if player.UserId ~= chicken.Owner.UserId then
		return false
	end

	if self.CarriedByUser[player.UserId] then
		return false
	end

	unequipPlayerTools(player)
	task.wait(0.08)

	local ok = chicken:StartCarry(player)

	if ok then
		self.CarriedByUser[player.UserId] = chicken

		if HomeCfg.Debug.PrintCarry then
			print("[AnimalService]", player.Name, "cargÃ³ gallina", chicken.Index)
		end
	end

	return ok
end

function AnimalService:DropCarriedChicken(player)
	local chicken = self.CarriedByUser[player.UserId]

	if not chicken then
		player:SetAttribute("CarryingChicken", false)
		return false
	end

	self.CarriedByUser[player.UserId] = nil

	local ok = false
	if chicken.Drop then
		ok = chicken:Drop(os.clock())
	end

	player:SetAttribute("CarryingChicken", false)

	if HomeCfg.Debug.PrintCarry then
		print("[AnimalService]", player.Name, "soltÃ³ gallina", chicken.Index, "state:", chicken.State)
	end

	return ok
end

function AnimalService:ForceDropCarriedChicken(player, reason)
	if not player then
		return false
	end

	local userId = player.UserId
	local chicken = self.CarriedByUser[userId]

	if not chicken then
		local data = self.PlayerAnimals[userId]
		local chickens = data and data.Chickens or {}
		for _, candidate in ipairs(chickens) do
			if candidate.CarriedBy == player then
				chicken = candidate
				break
			end
		end
	end

	self.CarriedByUser[userId] = nil
	player:SetAttribute("CarryingChicken", false)

	if not chicken then
		return false
	end

	if HomeCfg.Debug.PrintCarry then
		print(string.format("[ChickenCarry] ForceDrop %s reason=%s chicken=%s", player.Name, tostring(reason or "Unknown"), chicken.Model and chicken.Model.Name or "nil"))
	end

	local ok = false
	if chicken.ForceDrop then
		ok = pcall(function()
			chicken:ForceDrop(reason)
		end)
	else
		ok = pcall(function()
			chicken:Drop(os.clock())
		end)
	end

	return ok
end

function AnimalService:Step(dt)
	local now = os.clock()

	for _, data in pairs(self.PlayerAnimals) do
		data.Chickens = data.Chickens or {}
		data.Cuys = data.Cuys or {}

		for i = #data.Chickens, 1, -1 do
			local chicken = data.Chickens[i]
			local alive = chicken:Step(dt, now)

			if not alive then
				table.remove(data.Chickens, i)
			end
		end

		for i = #data.Cuys, 1, -1 do
			local cuy = data.Cuys[i]
			local alive = cuy:Step(dt, now)

			if not alive then
				table.remove(data.Cuys, i)
			end
		end
	end
end

function AnimalService:Release(player)
	self:ForceDropCarriedChicken(player, "Release")

	local data = self.PlayerAnimals[player.UserId]
	if data then
		data.Chickens = data.Chickens or {}
		data.Cuys = data.Cuys or {}

		for _, chicken in ipairs(data.Chickens) do
			chicken:Destroy()
		end

		for _, cuy in ipairs(data.Cuys) do
			cuy:Destroy()
		end

		self.PlayerAnimals[player.UserId] = nil
	end
end

function AnimalService:GetCollectedEggCount(player)
	return self.EggService:GetCollectedCount(player)
end

function AnimalService:GetInventory(player)
	if not self.InventoryService then
		return {}
	end

	return self.InventoryService:GetInventory(player)
end

return AnimalService
