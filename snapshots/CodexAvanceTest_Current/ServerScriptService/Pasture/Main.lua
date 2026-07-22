-- Pasture Main v1.2
-- Inicia el sistema, crea remotes y actualiza física/IA con throttling.

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

local Root = script.Parent
local M = Root:WaitForChild("M")

local Cfg = require(M:WaitForChild("Cfg"))
local House = require(M:WaitForChild("House"))

local function mustGet(parent, name)
	local obj = parent:WaitForChild(name, 10)

	if not obj then
		error("[Pasture] Falta " .. name .. " dentro de " .. parent:GetFullName())
	end

	return obj
end

local function ensureFolder(parent, name)
	local obj = parent:FindFirstChild(name)

	if not obj then
		obj = Instance.new("Folder")
		obj.Name = name
		obj.Parent = parent
	end

	return obj
end

local function ensureRemote(parent, name)
	local obj = parent:FindFirstChild(name)

	if not obj then
		obj = Instance.new("RemoteEvent")
		obj.Name = name
		obj.Parent = parent
	end

	return obj
end

local function registerCollisionGroup(name)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(name)
	end)
end

local function setupCollisionGroups()
	registerCollisionGroup("Sheep")
	registerCollisionGroup("Players")

	pcall(function()
		PhysicsService:CollisionGroupSetCollidable("Sheep", "Sheep", false)
	end)

	pcall(function()
		PhysicsService:CollisionGroupSetCollidable("Sheep", "Players", false)
	end)
end

setupCollisionGroups()

local runtime = mustGet(workspace, Cfg.Names.Runtime)
local housesFolder = mustGet(workspace, Cfg.Names.Houses)

local assets = mustGet(ServerStorage, Cfg.Names.Assets)
local sheepFolder = mustGet(assets, Cfg.Names.SheepFolder)
local sheepTemplate = mustGet(sheepFolder, Cfg.Names.SheepTemplate)

if not sheepTemplate:IsA("Model") then
	error("[Pasture] SheepTemplate debe ser un Model.")
end

if not sheepTemplate.PrimaryPart then
	local root = sheepTemplate:FindFirstChild("HumanoidRootPart")

	if root and root:IsA("BasePart") then
		sheepTemplate.PrimaryPart = root
	else
		error("[Pasture] SheepTemplate necesita PrimaryPart o HumanoidRootPart.")
	end
end

local remoteFolder = ensureFolder(ReplicatedStorage, "PastureRemote")
local whistleEvent = ensureRemote(remoteFolder, "Whistle")
local commandTargetEvent = ensureRemote(remoteFolder, Cfg.CommandTarget.RemoteName)
ensureRemote(remoteFolder, "RequestStats")
ensureRemote(remoteFolder, "StatsResponse")

local houseService = House.new(housesFolder, runtime, sheepTemplate)
local GrazingService = require(M:WaitForChild("GrazingService"))
local grazingService = GrazingService.new(houseService)

local lastWhistle = {}

local function isFiniteNumber(value)
	return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function isValidTargetPosition(value)
	return typeof(value) == "Vector3"
		and isFiniteNumber(value.X)
		and isFiniteNumber(value.Y)
		and isFiniteNumber(value.Z)
end

whistleEvent.OnServerEvent:Connect(function(player)
	local now = os.clock()
	local userId = player.UserId

	if lastWhistle[userId] and now - lastWhistle[userId] < Cfg.Flock.WhistleCooldown then
		return
	end

	lastWhistle[userId] = now

	if houseService.Whistle then
		houseService:Whistle(player)
	end
end)

commandTargetEvent.OnServerEvent:Connect(function(player, targetPosition)
	if not isValidTargetPosition(targetPosition) then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then
		return
	end

	local maxDistance = Cfg.CommandTarget.MaxDistanceFromPlayer or 80
	if (Vector3.new(targetPosition.X, 0, targetPosition.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude > maxDistance then
		return
	end

	if houseService.CommandTarget then
		houseService:CommandTarget(player, targetPosition)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastWhistle[player.UserId] = nil
	houseService:Release(player)
end)

local physicsInterval = Cfg.Update.Physics or (1 / 30)
local aiInterval = Cfg.Update.AI or 0.1
local maxPhysicsCatchUp = Cfg.Update.MaxPhysicsCatchUp or 2

local physicsTimer = 0
local aiTimer = 0

RunService.Heartbeat:Connect(function(dt)
	-- Física/hover a frecuencia fija.
	-- Antes era cada Heartbeat; con 100 ovejas eso podía subir mucho los raycasts.
	physicsTimer += dt

	local physicsSteps = 0

	while physicsTimer >= physicsInterval and physicsSteps < maxPhysicsCatchUp do
		physicsTimer -= physicsInterval
		physicsSteps += 1

		houseService:StepPhysics(physicsInterval)
	end

	if physicsSteps >= maxPhysicsCatchUp then
		physicsTimer = 0
	end

	-- IA a 10 Hz por defecto.
	aiTimer += dt

	if aiTimer >= aiInterval then
		aiTimer = 0
		houseService:StepAI(os.clock())
		grazingService:Step(os.clock())
	end
end)

print("[Pasture] Sistema iniciado correctamente. v1.2 PhysicsHz=" .. tostring(math.floor(1 / physicsInterval)) .. " AIInterval=" .. tostring(aiInterval))
