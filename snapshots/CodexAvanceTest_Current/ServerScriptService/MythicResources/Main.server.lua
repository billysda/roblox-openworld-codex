local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = script.Parent
local M = Root:WaitForChild("M")

local Catalog = require(ReplicatedStorage:WaitForChild("MythicResourceCatalog"))
local MythicInventoryService = require(M:WaitForChild("MythicInventoryService"))
local CodexService = require(M:WaitForChild("CodexService"))
local MythicResourceService = require(M:WaitForChild("MythicResourceService"))

-- TEMPORAL PARA PRUEBAS DEL VERTICAL SLICE.
-- Poner en false cuando ya no sea necesario que las plantas aparezcan cerca del jugador.
local TEST_SPAWN_NEAR_PLAYER = true
local TEST_SPAWN_DELAY = 0.8

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
local characterConnections = {}

local function scheduleTestCluster(player, character)
	if not TEST_SPAWN_NEAR_PLAYER then
		return
	end

	task.delay(TEST_SPAWN_DELAY, function()
		if player.Parent ~= Players or player.Character ~= character then
			return
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
			or character:WaitForChild("HumanoidRootPart", 5)
		if not rootPart or not rootPart:IsA("BasePart") then
			warn("[MythicResources] No se pudo crear cluster de prueba: HumanoidRootPart ausente para", player.Name)
			return
		end

		local created = resourceService:SpawnTestClusterForPlayer(player, rootPart.CFrame)
		print(string.format("[MythicResources] Cluster de prueba cerca de %s: %d nodos", player.Name, created))
	end)
end

local function initPlayer(player)
	codexService:InitPlayer(player)

	if characterConnections[player] then
		characterConnections[player]:Disconnect()
	end
	characterConnections[player] = player.CharacterAdded:Connect(function(character)
		scheduleTestCluster(player, character)
	end)

	if player.Character then
		scheduleTestCluster(player, player.Character)
	end
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
	resourceService:ClearTestSpawnsForPlayer(player)
	inventoryService:ClearPlayer(player)
	codexService:ClearPlayer(player)
	if characterConnections[player] then
		characterConnections[player]:Disconnect()
		characterConnections[player] = nil
	end
end)

resourceService:Start()

print("[MythicResources] v0 iniciado: Mandrake / EmberBloom / MoonDewLotus")
if TEST_SPAWN_NEAR_PLAYER then
	print("[MythicResources] TEST_SPAWN_NEAR_PLAYER activo: cluster 3x3 cerca de cada jugador")
end
