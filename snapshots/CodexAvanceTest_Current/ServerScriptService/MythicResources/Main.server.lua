local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = script.Parent
local M = Root:WaitForChild("M")

local Catalog = require(ReplicatedStorage:WaitForChild("MythicResourceCatalog"))
local MythicInventoryService = require(M:WaitForChild("MythicInventoryService"))
local CodexService = require(M:WaitForChild("CodexService"))
local MythicResourceService = require(M:WaitForChild("MythicResourceService"))

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if folder then
		if folder:IsA("Folder") then
			return folder
		end
		error("[MythicResources] " .. name .. " existe pero no es Folder")
	end
	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function ensureRemoteEvent(parent, name)
	local remote = parent:FindFirstChild(name)
	if remote then
		if remote:IsA("RemoteEvent") then
			return remote
		end
		error("[MythicResources] " .. name .. " existe pero no es RemoteEvent")
	end
	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = parent
	return remote
end

local function ensureRemoteFunction(parent, name)
	local remote = parent:FindFirstChild(name)
	if remote then
		if remote:IsA("RemoteFunction") then
			return remote
		end
		error("[MythicResources] " .. name .. " existe pero no es RemoteFunction")
	end
	remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = parent
	return remote
end

local remotes = ensureFolder(ReplicatedStorage, "MythicResourceRemote")
local requestSnapshot = ensureRemoteFunction(remotes, "RequestSnapshot")
local stateChanged = ensureRemoteEvent(remotes, "StateChanged")

local inventoryService = MythicInventoryService.new(Catalog)
local codexService = CodexService.new(Catalog)
local resourceService = MythicResourceService.new(Catalog, inventoryService, codexService, stateChanged)

local function initPlayer(player)
	codexService:InitPlayer(player)
end

requestSnapshot.OnServerInvoke = function(player)
	return {
		Inventory = inventoryService:GetSnapshot(player),
		Discovered = codexService:GetSnapshot(player),
		KnownCount = codexService:GetKnownCount(player),
	}
end

for _, player in ipairs(Players:GetPlayers()) do
	initPlayer(player)
end

Players.PlayerAdded:Connect(initPlayer)
Players.PlayerRemoving:Connect(function(player)
	inventoryService:ClearPlayer(player)
	codexService:ClearPlayer(player)
end)

resourceService:Start()

print("[MythicResources] v0 iniciado: Mandrake / EmberBloom / MoonDewLotus")
