local InventoryService = {}
InventoryService.__index = InventoryService

local HomeCfg = require(script.Parent:WaitForChild("HomeCfg"))

local ITEM_IDS = {
	"Egg",
	"GoldenEgg",
	"ChickenFeed",
	"CuyFeed",
}

local DEFAULT_ITEMS = {}
for _, itemId in ipairs(ITEM_IDS) do
	DEFAULT_ITEMS[itemId] = 0
end

local SessionInventories = {}

local function getUserId(player)
	if typeof(player) == "Instance" and player:IsA("Player") then
		return player.UserId
	end

	return nil
end

local function normalizeAmount(amount)
	amount = tonumber(amount) or 0
	amount = math.floor(amount)
	return math.max(amount, 0)
end

local function copyInventory(inventory)
	local copy = {}
	for _, itemId in ipairs(ITEM_IDS) do
		copy[itemId] = inventory[itemId] or 0
	end
	return copy
end

function InventoryService.new()
	local self = setmetatable({}, InventoryService)
	self.Inventories = SessionInventories
	return self
end

function InventoryService:GetInventory(player)
	local userId = getUserId(player)
	if not userId then
		return copyInventory(DEFAULT_ITEMS)
	end

	local inventory = self.Inventories[userId]
	if not inventory then
		inventory = copyInventory(DEFAULT_ITEMS)
		self.Inventories[userId] = inventory
	end

	return copyInventory(inventory)
end

function InventoryService:AddItem(player, itemId, amount)
	local userId = getUserId(player)
	amount = normalizeAmount(amount)

	if not userId or amount <= 0 or DEFAULT_ITEMS[itemId] == nil then
		return false, self:GetItemCount(player, itemId)
	end

	local inventory = self.Inventories[userId]
	if not inventory then
		inventory = copyInventory(DEFAULT_ITEMS)
		self.Inventories[userId] = inventory
	end

	inventory[itemId] = (inventory[itemId] or 0) + amount

	if HomeCfg.Debug and HomeCfg.Debug.Inventory then
		print(string.format("[Inventory] %s +%d %s total=%d", player.Name, amount, itemId, inventory[itemId]))
	end

	return true, inventory[itemId]
end

function InventoryService:RemoveItem(player, itemId, amount)
	local userId = getUserId(player)
	amount = normalizeAmount(amount)

	if not userId or amount <= 0 or DEFAULT_ITEMS[itemId] == nil then
		return false, self:GetItemCount(player, itemId)
	end

	local inventory = self.Inventories[userId]
	if not inventory then
		inventory = copyInventory(DEFAULT_ITEMS)
		self.Inventories[userId] = inventory
	end

	local current = inventory[itemId] or 0
	if current < amount then
		return false, current
	end

	inventory[itemId] = current - amount
	return true, inventory[itemId]
end

function InventoryService:GetItemCount(player, itemId)
	local userId = getUserId(player)
	if not userId or DEFAULT_ITEMS[itemId] == nil then
		return 0
	end

	local inventory = self.Inventories[userId]
	if not inventory then
		return 0
	end

	return inventory[itemId] or 0
end

function InventoryService:ClearPlayer(player)
	local userId = getUserId(player)
	if userId then
		self.Inventories[userId] = nil
	end
end

function InventoryService.GetSessionItemTotal(itemId)
	if DEFAULT_ITEMS[itemId] == nil then
		return 0
	end

	local total = 0
	for _, inventory in pairs(SessionInventories) do
		total += inventory[itemId] or 0
	end

	return total
end

return InventoryService