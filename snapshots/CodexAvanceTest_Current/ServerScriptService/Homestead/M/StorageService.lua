local StorageService = {}
StorageService.__index = StorageService

local HomeCfg = require(script.Parent:WaitForChild("HomeCfg"))

local PROMPT_NAME = "StoragePrompt"

local function findFirstBasePart(instance)
	if not instance then
		return nil
	end

	if instance:IsA("BasePart") then
		return instance
	end

	if instance:IsA("Model") then
		if instance.PrimaryPart and instance.PrimaryPart:IsA("BasePart") then
			return instance.PrimaryPart
		end

		return instance:FindFirstChildWhichIsA("BasePart", true)
	end

	if instance:IsA("Folder") then
		return instance:FindFirstChildWhichIsA("BasePart", true)
	end

	return nil
end

local function unequipPlayerTools(player)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:UnequipTools()
	end
end

function StorageService.new(homeService, inventoryService, storageDataEvent)
	local self = setmetatable({}, StorageService)

	self.HomeService = homeService
	self.InventoryService = inventoryService
	self.StorageDataEvent = storageDataEvent
	self.PromptConnections = {}
	self.StorageLocations = {}
	self.MissingStorageParts = {}

	return self
end

function StorageService:FindStorageObject(house)
	if not house then
		return nil, ""
	end

	local stations = house:FindFirstChild(HomeCfg.Names.Stations)
	if stations then
		local storage = stations:FindFirstChild(HomeCfg.Names.StationStorage)
		if storage then
			return storage, house.Name .. "." .. HomeCfg.Names.Stations .. "." .. HomeCfg.Names.StationStorage
		end
	end

	local storage = house:FindFirstChild(HomeCfg.Names.StationStorage)
	if storage then
		return storage, house.Name .. "." .. HomeCfg.Names.StationStorage
	end

	local stationStorage = house:FindFirstChild("StationStorage")
	if stationStorage then
		return stationStorage, house.Name .. ".StationStorage"
	end

	return nil, ""
end

function StorageService:IsOwner(player, house)
	if not player or not house then
		return false
	end

	return house:GetAttribute("Taken") == true and house:GetAttribute("OwnerId") == player.UserId
end

function StorageService:GetStorageData(player)
	local inventory = self.InventoryService and self.InventoryService:GetInventory(player) or {}

	return {
		Inventory = {
			Egg = inventory.Egg or 0,
			GoldenEgg = inventory.GoldenEgg or 0,
			ChickenFeed = inventory.ChickenFeed or 0,
			CuyFeed = inventory.CuyFeed or 0,
		},
	}
end

function StorageService:OpenStorage(player, house)
	local targetHouse = house or (self.HomeService and self.HomeService:GetHouseByOwner(player))
	if not targetHouse then
		if HomeCfg.Debug and HomeCfg.Debug.Storage then
			warn("[Storage]", player and player.Name or "Unknown", "intentÃ³ abrir Storage sin casa.")
		end
		return false
	end

	if not self:IsOwner(player, targetHouse) then
		if HomeCfg.Debug and HomeCfg.Debug.Storage then
			warn("[Storage]", player and player.Name or "Unknown", "intentÃ³ abrir Storage ajeno:", targetHouse.Name)
		end
		return false
	end

	unequipPlayerTools(player)
	player:SetAttribute("HomesteadStorageOpen", true)

	local data = self:GetStorageData(player)
	if self.StorageDataEvent then
		self.StorageDataEvent:FireClient(player, data)
	end

	if HomeCfg.Debug and HomeCfg.Debug.Storage then
		print(string.format("[Storage] %s abriÃ³ Storage. Egg=%d", player.Name, data.Inventory.Egg or 0))
	end

	return true
end

function StorageService:SetupHouse(house)
	local storage, storagePath = self:FindStorageObject(house)
	if not storage then
		self.MissingStorageParts[house.Name] = "NoStorageStation"
		if HomeCfg.Debug and HomeCfg.Debug.Storage then
			warn("[Storage]", house.Name, "no tiene Storage station.")
		end
		return false
	end

	local promptPart = findFirstBasePart(storage)
	if not promptPart then
		self.StorageLocations[house.Name] = storagePath
		self.MissingStorageParts[house.Name] = storagePath
		if HomeCfg.Debug and HomeCfg.Debug.Storage then
			warn("[Storage]", house.Name, "Storage sin BasePart valido:", storagePath)
		end
		return false
	end

	local prompt = promptPart:FindFirstChild(PROMPT_NAME)
	if prompt and not prompt:IsA("ProximityPrompt") then
		warn("[Storage]", promptPart:GetFullName(), "tiene StoragePrompt pero no es ProximityPrompt.")
		return false
	end

	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = PROMPT_NAME
		prompt.Parent = promptPart
	end

	prompt.ActionText = "Abrir"
	prompt.ObjectText = "AlmacÃ©n"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false

	self.StorageLocations[house.Name] = promptPart:GetFullName()
	self.MissingStorageParts[house.Name] = nil

	if not self.PromptConnections[prompt] then
		self.PromptConnections[prompt] = prompt.Triggered:Connect(function(player)
			self:OpenStorage(player, house)
		end)
	end

	return true
end

function StorageService:Setup()
	local housesFolder = self.HomeService and self.HomeService.HousesFolder
	if not housesFolder then
		warn("[Storage] No encontrÃ© HousesFolder para configurar Storage.")
		return
	end

	for _, house in ipairs(housesFolder:GetChildren()) do
		if house:IsA("Model") or house:IsA("Folder") then
			self:SetupHouse(house)
		end
	end
end

return StorageService