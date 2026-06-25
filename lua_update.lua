
local sss = game:GetService("ServerScriptService")
local pasture = sss:FindFirstChild("Pasture")
local M = pasture:FindFirstChild("M")

local main = pasture:FindFirstChild("Main")
local cfg = M:FindFirstChild("Cfg")
local grazing = M:FindFirstChild("GrazingService")

if not grazing then
    grazing = Instance.new("ModuleScript")
    grazing.Name = "GrazingService"
    grazing.Parent = M
end

main.Source = [==========[-- Pasture Main v1.2
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
ensureRemote(remoteFolder, "RequestStats")
ensureRemote(remoteFolder, "StatsResponse")

local houseService = House.new(housesFolder, runtime, sheepTemplate)
local GrazingService = require(M:WaitForChild("GrazingService"))
local grazingService = GrazingService.new(houseService)

local lastWhistle = {}

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
]==========]
cfg.Source = [==========[local Cfg = {}

-- =========================================================================
-- PASTURE SYSTEM v1.0 PROFESSIONAL
-- Una sola fuente de configuración del sistema de ovejas.
-- =========================================================================

Cfg.Names = {
	Runtime = "SheepRuntime",

	Houses = "Houses",
	HousePromptPart = "ClaimPromptPart",
	HousePrompt = "ProximityPrompt",
	CorralCenter = "CorralCenter",
	SpawnFolder = "SheepSpawns",

	Assets = "Assets",
	SheepFolder = "Sheep",
	SheepTemplate = "SheepTemplate",

	RemoteFolder = "PastureRemote",
	WhistleRemote = "Whistle",
}

Cfg.Debug = {
	PrintInvalidActions = false,
	SetDebugAttributes = true,
	PrintLifecycle = true,
}

Cfg.Collision = {
	Enabled = true,
	SheepGroup = "PastureSheep",
	PlayerGroup = "PasturePlayer",
	SheepCollideWithSheep = false,
	SheepCollideWithPlayers = false,
}

Cfg.SheepPerFlock = 2
Cfg.SpawnYOffset = 3

Cfg.Radius = 15
Cfg.PlayerMoveSpeed = 1.2

Cfg.Hover = {
	TargetHeight = 3.2,
	RayLength = 11.2,
	Spring = 1400,
	Damping = 220,
	HeightSmoothing = 12,
	MaxCorrectionRatio = 0.75,
}

Cfg.Update = {
	-- Hover/altura física. 30 Hz reduce raycasts sin perder estabilidad.
	Physics = 1 / 30,

	-- IA de comportamiento. 10 Hz es suficiente para rebaños.
	AI = 0.1,

	-- Evita acumulación excesiva si el servidor tiene un pico.
	MaxPhysicsCatchUp = 2,
}

Cfg.IdleTime = {
	Min = 4,
	Max = 12,
}

Cfg.Flock = {
	PressureRadius = 28,
	MinMoveTime = 1.2,

	RecallDuration = 10,
	RecallStopDistance = 12,
	WhistleCooldown = 1.5,

	MoveSpeed = 10,
	LeaderSpeed = 11,
	RegroupSpeed = 7,

	FollowLeaderDistance = 7,
	CohesionRadius = 10,
	MaxGroupDistance = 20,
	SeparationRadius = 4,

	DirectionSmoothing = 0.22,

	WeightMove = 1.0,
	WeightLeader = 0.85,
	WeightCenter = 0.7,
	WeightSeparate = 1.35,
	WeightPlayerFlee = 1.15,
	WeightNatural = 0.12,
}

-- Movimiento de grupo por "zona de flujo", no siguiendo rígidamente a la líder.
Cfg.Flow = {
	TargetAhead = 13,
	SlotSpacing = 5,
	RowSpacing = 5,
	SlotPull = 1.05,
	ForwardWeight = 0.95,
	CenterWeight = 0.22,
	SeparationWeight = 1.2,
	PlayerFleeWeight = 1.1,
	NaturalWeight = 0.1,
	AheadSoftLimit = 7,
	SlotMaxPullDistance = 18,
	Columns = 5,
}

-- Recuperación cuando una oveja se queda demasiado lejos del rebaño.
Cfg.Lost = {
	LeaderDistance = 26,
	CenterDistance = 32,
	CriticalDistance = 45,

	RegroupSpeedMin = 9,
	RegroupSpeedMax = 13,

	CriticalSpeedMin = 13,
	CriticalSpeedMax = 17,

	WeightLeader = 1.35,
	WeightCenter = 0.85,
	WeightSeparate = 0.55,
}

-- Movimiento tranquilo cuando no hay presión del jugador.
Cfg.Calm = {
	MinWait = 1.2,
	MaxWait = 4.5,

	MoveDurationMin = 1.3,
	MoveDurationMax = 4.2,

	WanderChance = 0.8,

	WanderSpeed = 3.2,
	LeaderWanderSpeed = 2.4,

	WanderSpeedMin = 2.2,
	WanderSpeedMax = 4.8,

	BurstChance = 0.16,
	BurstSpeedMin = 6.5,
	BurstSpeedMax = 10.5,

	SoftReturnDistance = 12,
	MaxCalmDistanceFromCenter = 20,

	WeightCenter = 0.55,
	WeightSeparate = 1.15,
	WeightRandom = 0.85,
}

Cfg.MoveAnim = {
	TrotSpeedThreshold = 5.5,
	RunSpeedThreshold = 13,

	PanicDistance = 7,
	PanicSpeed = 16,

	WalkBaseSpeed = 3.2,
	TrotBaseSpeed = 10,
	RunBaseSpeed = 16,

	AdjustMin = 0.75,
	AdjustMax = 1.45,
}

-- Diferencias individuales: algunas reaccionan tarde, otras corren, otras trotan.
Cfg.Response = {
	LeaderDelayMin = 0.05,
	LeaderDelayMax = 0.25,

	FreeDelayMin = 0.05,
	FreeDelayMax = 1.4,

	BusyDelayMin = 0.8,
	BusyDelayMax = 3.2,

	EatDelayMin = 1.5,
	EatDelayMax = 5.5,

	LieDelayMin = 2.5,
	LieDelayMax = 7.5,

	SleepDelayMin = 4.5,
	SleepDelayMax = 11,

	MoveModeDurationMin = 1.6,
	MoveModeDurationMax = 3.8,

	WalkChance = 0.18,
	TrotChance = 0.62,
	RunChance = 0.20,

	PanicWalkChance = 0.08,
	PanicTrotChance = 0.24,
	PanicRunChance = 0.68,

	WalkSpeedMin = 3.2,
	WalkSpeedMax = 5.2,

	TrotSpeedMin = 7.5,
	TrotSpeedMax = 11.5,

	RunSpeedMin = 13.5,
	RunSpeedMax = 17,
}

-- IDs actuales de animación.
-- Es buena práctica tenerlas aquí en Cfg, NO dentro de la lógica de Sheep.
Cfg.Anim = {
	Walk = "rbxassetid://98801271365263",
	Trot = "rbxassetid://140710027312622",
	Run = "rbxassetid://77179937004940",

	Idle = "rbxassetid://121773693589116",

	LieStart = "rbxassetid://80336580004356",
	LieLoop1 = "rbxassetid://134401810460343",
	LieLoop2 = "rbxassetid://126790719773233",
	LieEnd = "rbxassetid://134697800065907",

	SleepStart = "rbxassetid://103165630829880",
	SleepLoop = "rbxassetid://111279793169124",

	-- Provisional hasta que publiques SleepEnd real.
	SleepEnd = "rbxassetid://134697800065907",

	EatStart = "rbxassetid://91017364750780",
	EatLoop1 = "rbxassetid://104614822864669",
	EatLoop2 = "rbxassetid://93086399005574",
	EatEnd = "rbxassetid://132441957725496",
}

Cfg.ActionLoop = {}

Cfg.IdleActions = {
	{ Name = "Eat", Weight = 55 },
	{ Name = "LieLook", Weight = 30 },
	{ Name = "Sleep", Weight = 15 },
}

Cfg.Sequences = {
	Eat = {
		Start = "EatStart",
		Loops = { "EatLoop1", "EatLoop2" },
		End = "EatEnd",

		MinTime = 18,
		MaxTime = 55,

		LoopSwitchMin = 7,
		LoopSwitchMax = 16,

		ExitBeforeMove = true,
	},

	LieLook = {
		Start = "LieStart",
		Loops = { "LieLoop1", "LieLoop2" },
		End = "LieEnd",

		MinTime = 25,
		MaxTime = 75,

		LoopSwitchMin = 8,
		LoopSwitchMax = 18,

		ExitBeforeMove = true,
	},

	Sleep = {
		Start = "SleepStart",
		Loops = { "SleepLoop" },
		End = "SleepEnd",
		FallbackEnd = "LieEnd",

		MinTime = 50,
		MaxTime = 140,

		LoopSwitchMin = 12,
		LoopSwitchMax = 25,

		ExitBeforeMove = true,
	},

	StartFade = 0.25,
	LoopFade = 0.25,
	EndFade = 0.25,
}

Cfg.Grazing = {
	Enabled = true,

	RuntimeFolder = "PastureGrazingRuntime",

	ZoneRadius = 18,
	ZoneHeight = 0.15,
	ZoneDistanceMin = 55,
	ZoneDistanceMax = 90,

	GrassGoal = 100,
	GrassPerSecond = 8,

	RequireAllSheep = true,
	MinSheepInside = 2,

	CheckInterval = 0.25,
	MarkerUpdateInterval = 0.5,

	XPPerZone = 25,
	XPToNextLevel = 100,

	ZoneYOffset = 0.08,
	LabelHeight = 8,

	Debug = true,
}

return Cfg
]==========]
grazing.Source = [==========[local GrazingService = {}
GrazingService.__index = GrazingService

local Cfg = require(script.Parent.Cfg)

function GrazingService.new(houseService)
	local self = setmetatable({}, GrazingService)
	self.HouseService = houseService
	
	self.RuntimeFolder = workspace:FindFirstChild(Cfg.Grazing.RuntimeFolder)
	if not self.RuntimeFolder then
		self.RuntimeFolder = Instance.new("Folder")
		self.RuntimeFolder.Name = Cfg.Grazing.RuntimeFolder
		self.RuntimeFolder.Parent = workspace
	end
	
	self.ActiveZones = {} -- userId -> data
	self.LastCheckTime = 0
	self.LastMarkerTime = 0
	
	return self
end

function GrazingService:_debug(msg)
	if Cfg.Grazing.Debug then
		print("[Grazing] " .. msg)
	end
end

function GrazingService:Step(clockTime)
	if not Cfg.Grazing.Enabled then return end
	
	local dtCheck = clockTime - self.LastCheckTime
	if dtCheck >= Cfg.Grazing.CheckInterval then
		self.LastCheckTime = clockTime
		self:_updateZones(dtCheck)
		self:_cleanupLostPlayers()
	end
	
	local dtMarker = clockTime - self.LastMarkerTime
	if dtMarker >= Cfg.Grazing.MarkerUpdateInterval then
		self.LastMarkerTime = clockTime
		self:_updateMarkers()
	end
end

function GrazingService:_cleanupLostPlayers()
	for userId, zoneData in pairs(self.ActiveZones) do
		local player = game.Players:GetPlayerByUserId(userId)
		local data = self.HouseService.PlayerData[userId]
		
		if not player or not data or not data.House or not data.Flock then
			if zoneData.Folder then
				zoneData.Folder:Destroy()
			end
			self.ActiveZones[userId] = nil
		end
	end
end

function GrazingService:_updateZones(dt)
	for userId, data in pairs(self.HouseService.PlayerData) do
		local player = game.Players:GetPlayerByUserId(userId)
		if player and data.House and data.Flock then
			self:_ensurePlayerAttributes(player)
			self:_handlePlayerZone(player, data.House, data.Flock, dt)
		end
	end
end

function GrazingService:_ensurePlayerAttributes(player)
	if player:GetAttribute("PastureFlockLevel") == nil then
		player:SetAttribute("PastureFlockLevel", 1)
		player:SetAttribute("PastureFlockXP", 0)
		player:SetAttribute("PastureGrassEaten", 0)
		player:SetAttribute("PastureGrassGoal", Cfg.Grazing.GrassGoal)
		player:SetAttribute("PastureSheepInside", 0)
		player:SetAttribute("PastureSheepRequired", Cfg.Grazing.MinSheepInside)
		player:SetAttribute("PastureZoneIndex", 1)
	end
end

function GrazingService:_handlePlayerZone(player, house, flock, dt)
	local userId = player.UserId
	local zoneData = self.ActiveZones[userId]
	
	if not zoneData then
		zoneData = self:_createZoneForPlayer(player, house, flock)
		if not zoneData then return end
		self.ActiveZones[userId] = zoneData
	end
	
	-- Count sheep inside
	local insideCount = 0
	local activeSheepCount = 0
	
	if flock.Sheep then
		for _, sheep in pairs(flock.Sheep) do
			if sheep.Model and not sheep.Model:GetAttribute("CapturedByDragon") and sheep.Root then
				activeSheepCount = activeSheepCount + 1
				-- Solo distancia horizontal
				local hDist = Vector3.new(sheep.Root.Position.X, 0, sheep.Root.Position.Z) - Vector3.new(zoneData.Position.X, 0, zoneData.Position.Z)
				if hDist.Magnitude <= Cfg.Grazing.ZoneRadius then
					insideCount = insideCount + 1
				end
			end
		end
	end
	
	local requiredCount = Cfg.Grazing.MinSheepInside
	if Cfg.Grazing.RequireAllSheep then
		requiredCount = math.max(Cfg.Grazing.MinSheepInside, activeSheepCount)
	end
	
	player:SetAttribute("PastureSheepInside", insideCount)
	player:SetAttribute("PastureSheepRequired", requiredCount)
	
	if insideCount >= requiredCount then
		local progress = player:GetAttribute("PastureGrassEaten") or 0
		progress = progress + (Cfg.Grazing.GrassPerSecond * dt)
		
		local goal = player:GetAttribute("PastureGrassGoal") or Cfg.Grazing.GrassGoal
		
		if progress >= goal then
			progress = 0
			local zoneIndex = (player:GetAttribute("PastureZoneIndex") or 1) + 1
			player:SetAttribute("PastureZoneIndex", zoneIndex)
			
			local xp = (player:GetAttribute("PastureFlockXP") or 0) + Cfg.Grazing.XPPerZone
			local level = player:GetAttribute("PastureFlockLevel") or 1
			
			self:_debug(string.format("Zona completada %s XP=%d Level=%d", player.Name, Cfg.Grazing.XPPerZone, level))
			
			if xp >= Cfg.Grazing.XPToNextLevel then
				xp = xp - Cfg.Grazing.XPToNextLevel
				level = level + 1
				player:SetAttribute("PastureFlockLevel", level)
				self:_debug(string.format("Rebaño subió de nivel %s Level=%d", player.Name, level))
			end
			player:SetAttribute("PastureFlockXP", xp)
			
			-- Remove old zone
			if zoneData.Folder then
				zoneData.Folder:Destroy()
			end
			self.ActiveZones[userId] = nil
		end
		
		player:SetAttribute("PastureGrassEaten", progress)
	end
end

function GrazingService:_createZoneForPlayer(player, house, flock)
	local basePos = nil
	if house.CorralCenter then
		basePos = house.CorralCenter.Position
	elseif flock.Center then
		basePos = flock.Center
	end
	
	if not basePos then return nil end
	
	local angle = math.random() * math.pi * 2
	local dist = Cfg.Grazing.ZoneDistanceMin + math.random() * (Cfg.Grazing.ZoneDistanceMax - Cfg.Grazing.ZoneDistanceMin)
	local offset = Vector3.new(math.cos(angle) * dist, 50, math.sin(angle) * dist)
	
	local rayStart = basePos + offset
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	
	-- No es necesario filtrar si solo queremos el suelo, pero si hay problemas
	-- con colisiones se podría usar FilterDescendantsInstances
	
	local raycastResult = workspace:Raycast(rayStart, Vector3.new(0, -100, 0))
	local zonePos = basePos + Vector3.new(offset.X, 0, offset.Z) + Vector3.new(0, Cfg.Grazing.ZoneYOffset, 0)
	
	if raycastResult then
		zonePos = raycastResult.Position + Vector3.new(0, Cfg.Grazing.ZoneYOffset, 0)
	end
	
	local folder = Instance.new("Folder")
	folder.Name = "Grazing_" .. player.UserId
	folder.Parent = self.RuntimeFolder
	
	local zonePart = Instance.new("Part")
	zonePart.Name = "GrazingZone"
	zonePart.Anchored = true
	zonePart.CanCollide = false
	zonePart.CanTouch = false
	zonePart.CanQuery = false
	zonePart.Shape = Enum.PartType.Cylinder
	zonePart.Size = Vector3.new(Cfg.Grazing.ZoneHeight, Cfg.Grazing.ZoneRadius * 2, Cfg.Grazing.ZoneRadius * 2)
	zonePart.CFrame = CFrame.new(zonePos) * CFrame.Angles(0, 0, math.pi/2)
	zonePart.Transparency = 0.55
	zonePart.Material = Enum.Material.Neon
	zonePart.Color = Color3.fromRGB(150, 255, 150)
	zonePart.Parent = folder
	
	local anchor = Instance.new("Part")
	anchor.Name = "FlockLabelAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1,1,1)
	anchor.Position = zonePos + Vector3.new(0, Cfg.Grazing.LabelHeight, 0)
	anchor.Parent = folder
	
	local bgui = Instance.new("BillboardGui")
	bgui.Name = "ProgressGui"
	bgui.Size = UDim2.new(0, 200, 0, 80)
	bgui.StudsOffset = Vector3.new(0, 0, 0)
	bgui.AlwaysOnTop = true
	
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.TextScaled = true
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextStrokeTransparency = 0
	textLabel.Parent = bgui
	
	bgui.Parent = anchor
	
	local zoneIndex = player:GetAttribute("PastureZoneIndex") or 1
	self:_debug(string.format("Zona creada %s #%d", player.Name, zoneIndex))
	
	return {
		Folder = folder,
		Position = zonePos,
		Anchor = anchor,
		TextLabel = textLabel
	}
end

function GrazingService:_updateMarkers()
	for userId, zoneData in pairs(self.ActiveZones) do
		local player = game.Players:GetPlayerByUserId(userId)
		local data = self.HouseService.PlayerData[userId]
		
		if player and data and data.Flock then
			if data.Flock.Center then
				zoneData.Anchor.Position = data.Flock.Center + Vector3.new(0, Cfg.Grazing.LabelHeight, 0)
			else
				zoneData.Anchor.Position = zoneData.Position + Vector3.new(0, Cfg.Grazing.LabelHeight, 0)
			end
			
			local eaten = math.floor(player:GetAttribute("PastureGrassEaten") or 0)
			local goal = player:GetAttribute("PastureGrassGoal") or Cfg.Grazing.GrassGoal
			local inside = player:GetAttribute("PastureSheepInside") or 0
			local req = player:GetAttribute("PastureSheepRequired") or 2
			local lvl = player:GetAttribute("PastureFlockLevel") or 1
			local xp = player:GetAttribute("PastureFlockXP") or 0
			
			zoneData.TextLabel.Text = string.format("Pasto consumido: %d/%d\nOvejas: %d/%d\nRebaño Nv.%d  XP %d/%d", 
				eaten, goal, inside, req, lvl, xp, Cfg.Grazing.XPToNextLevel)
		end
	end
end

return GrazingService
]==========]

return "Updated Studio Successfully"
