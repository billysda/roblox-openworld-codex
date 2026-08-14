local CodexService = {}
CodexService.__index = CodexService

local SessionDiscoveries = {}

local function getUserId(player)
	if typeof(player) == "Instance" and player:IsA("Player") then
		return player.UserId
	end
	return nil
end

local function ensureDiscovery(userId)
	local discovery = SessionDiscoveries[userId]
	if not discovery then
		discovery = {}
		SessionDiscoveries[userId] = discovery
	end
	return discovery
end

function CodexService.new(catalog)
	local self = setmetatable({}, CodexService)
	self.Catalog = catalog
	return self
end

function CodexService:Discover(player, resourceId)
	local userId = getUserId(player)
	if not userId or not self.Catalog.IsValid(resourceId) then
		return false
	end

	local discovery = ensureDiscovery(userId)
	local firstDiscovery = discovery[resourceId] ~= true
	discovery[resourceId] = true

	if firstDiscovery then
		player:SetAttribute("CodexKnownMythics", self:GetKnownCount(player))
	end

	return firstDiscovery
end

function CodexService:IsDiscovered(player, resourceId)
	local userId = getUserId(player)
	if not userId or not self.Catalog.IsValid(resourceId) then
		return false
	end
	local discovery = SessionDiscoveries[userId]
	return discovery and discovery[resourceId] == true or false
end

function CodexService:GetKnownCount(player)
	local count = 0
	for _, resourceId in ipairs(self.Catalog.Order) do
		if self:IsDiscovered(player, resourceId) then
			count += 1
		end
	end
	return count
end

function CodexService:GetSnapshot(player)
	local snapshot = {}
	for _, resourceId in ipairs(self.Catalog.Order) do
		snapshot[resourceId] = self:IsDiscovered(player, resourceId)
	end
	return snapshot
end

function CodexService:InitPlayer(player)
	ensureDiscovery(player.UserId)
	player:SetAttribute("CodexKnownMythics", self:GetKnownCount(player))
end

function CodexService:ClearPlayer(player)
	local userId = getUserId(player)
	if userId then
		SessionDiscoveries[userId] = nil
	end
end

return CodexService
