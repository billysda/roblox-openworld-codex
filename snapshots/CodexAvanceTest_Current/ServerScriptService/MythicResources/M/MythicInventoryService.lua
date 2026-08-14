local MythicInventoryService = {}
MythicInventoryService.__index = MythicInventoryService

local SessionInventories = {}

local function getUserId(player)
	if typeof(player) == "Instance" and player:IsA("Player") then
		return player.UserId
	end
	return nil
end

local function ensureInventory(userId)
	local inventory = SessionInventories[userId]
	if not inventory then
		inventory = {}
		SessionInventories[userId] = inventory
	end
	return inventory
end

function MythicInventoryService.new(catalog)
	local self = setmetatable({}, MythicInventoryService)
	self.Catalog = catalog
	return self
end

function MythicInventoryService:Add(player, resourceId, amount)
	local userId = getUserId(player)
	amount = math.max(math.floor(tonumber(amount) or 0), 0)
	if not userId or amount <= 0 or not self.Catalog.IsValid(resourceId) then
		return false, self:GetCount(player, resourceId)
	end

	local inventory = ensureInventory(userId)
	inventory[resourceId] = (inventory[resourceId] or 0) + amount
	return true, inventory[resourceId]
end

function MythicInventoryService:GetCount(player, resourceId)
	local userId = getUserId(player)
	if not userId or not self.Catalog.IsValid(resourceId) then
		return 0
	end
	local inventory = SessionInventories[userId]
	return inventory and (inventory[resourceId] or 0) or 0
end

function MythicInventoryService:GetSnapshot(player)
	local snapshot = {}
	for _, resourceId in ipairs(self.Catalog.Order) do
		snapshot[resourceId] = self:GetCount(player, resourceId)
	end
	return snapshot
end

function MythicInventoryService:ClearPlayer(player)
	local userId = getUserId(player)
	if userId then
		SessionInventories[userId] = nil
	end
end

return MythicInventoryService
