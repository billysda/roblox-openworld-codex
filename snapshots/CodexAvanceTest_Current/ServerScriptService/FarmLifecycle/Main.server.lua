local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Root = script.Parent
local M = Root:WaitForChild("M")

local Catalog = require(ReplicatedStorage:WaitForChild("FarmLifecycleCatalog"))
local Registry = require(ServerScriptService:WaitForChild("Shared"):WaitForChild("FarmAnimalRegistry"))
local FarmLifecycleService = require(M:WaitForChild("FarmLifecycleService"))

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if folder then
		assert(folder:IsA("Folder"), name .. " debe ser Folder")
		return folder
	end
	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function ensureRemoteEvent(parent, name)
	local remote = parent:FindFirstChild(name)
	if remote then
		assert(remote:IsA("RemoteEvent"), name .. " debe ser RemoteEvent")
		return remote
	end
	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = parent
	return remote
end

local function ensureRemoteFunction(parent, name)
	local remote = parent:FindFirstChild(name)
	if remote then
		assert(remote:IsA("RemoteFunction"), name .. " debe ser RemoteFunction")
		return remote
	end
	remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = parent
	return remote
end

local remotes = ensureFolder(ReplicatedStorage, "FarmLifecycleRemote")
local requestSnapshot = ensureRemoteFunction(remotes, "RequestSnapshot")
local processAnimal = ensureRemoteEvent(remotes, "ProcessAnimal")
local requestRecoveryPair = ensureRemoteEvent(remotes, "RequestRecoveryPair")
local stateChanged = ensureRemoteEvent(remotes, "StateChanged")

local service = FarmLifecycleService.new(Catalog, Registry, stateChanged)

requestSnapshot.OnServerInvoke = function(player)
	return service:GetSnapshot(player)
end

processAnimal.OnServerEvent:Connect(function(player, speciesId)
	if typeof(speciesId) ~= "string" then
		return
	end
	service:ProcessOne(player, speciesId)
end)

requestRecoveryPair.OnServerEvent:Connect(function(player, speciesId)
	if typeof(speciesId) ~= "string" then
		return
	end
	service:RequestRecoveryPair(player, speciesId)
end)

Players.PlayerRemoving:Connect(function(player)
	service:ClearPlayer(player)
end)

task.spawn(function()
	while Root.Parent do
		service:Step()
		task.wait(Catalog.TickInterval or 1)
	end
end)

print("[FarmLifecycle] v0 iniciado. TestFastMode=" .. tostring(Catalog.TestFastMode == true))
