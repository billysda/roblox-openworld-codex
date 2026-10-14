-- DragonCollisionRuntime.server.lua
-- Stable collision configuration for Phase4 dragon mount.
-- v8: DragonGroundCollider never collides while a player is mounted. Terrain climbing is handled by DragonGroundSurfaceSolver.

print("[DragonCollisionRuntime] Active v8 mounted collider passthrough")

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DRAGON_NAME = "DragonModel"
local DRAGON_GROUP = "DragonBody"
local RIDER_GROUP = "DragonRider"

pcall(function() PhysicsService:RegisterCollisionGroup(DRAGON_GROUP) end)
pcall(function() PhysicsService:RegisterCollisionGroup(RIDER_GROUP) end)
pcall(function()
	PhysicsService:CollisionGroupSetCollidable(DRAGON_GROUP, RIDER_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(RIDER_GROUP, RIDER_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(DRAGON_GROUP, "Default", true)
end)

local lastColliderKey = nil
local lastPrint = 0
local colliderDiagPrinted = false

local function setGroup(part, group)
	if part and part:IsA("BasePart") then
		pcall(function() part.CollisionGroup = group end)
	end
end

local function cfg(dragon, name, fallback)
	local folder = dragon and dragon:FindFirstChild("DragonMountConfig")
	local obj = folder and folder:FindFirstChild(name)
	if obj and obj:IsA("ValueBase") then
		return obj.Value
	end
	return fallback
end

local function getMountedFlightState()
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("DragonMounted") == true then
			return tostring(player:GetAttribute("DragonMountedState") or "")
		end
	end
	return ""
end

local function hasMountedPlayer()
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("DragonMounted") == true then
			return true
		end
	end
	return false
end

local function shouldColliderCollide()
	-- Important: do not let the physical box climb or hit Terrain while mounted.
	-- It caused intermittent bumps because this runtime rebuilt/toggled CanCollide while GroundSurfaceSolver was raycasting.
	if hasMountedPlayer() then
		return false
	end
	return true
end

local function configureDragon()
	local dragon = Workspace:FindFirstChild(DRAGON_NAME)
	if not dragon then return end
	local root = dragon:FindFirstChild("HumanoidRootPart")
	local mesh = dragon:FindFirstChild("DragonMesh")
	if not root or not root:IsA("BasePart") then return end
	if dragon:IsA("Model") and dragon.PrimaryPart ~= root then
		dragon.PrimaryPart = root
	end

	if mesh and mesh:IsA("BasePart") then
		mesh.CanCollide = false
		mesh.CanTouch = false
		mesh.CanQuery = true
		mesh.Massless = true
		setGroup(mesh, DRAGON_GROUP)
	end

	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = true
	-- Ground/flight authority belongs to DragonFlightService/GroundKinematic.
	setGroup(root, DRAGON_GROUP)

	local collider = dragon:FindFirstChild("DragonGroundCollider")
	if collider then
		collider:Destroy()
	end

	local now = os.clock()
	if now - lastPrint > 10 then
		lastPrint = now
		print(("[DragonCollisionRuntime] Lite active; mesh & root non-collidable; state=%s mounted=%s"):format(
			getMountedFlightState(),
			tostring(hasMountedPlayer())
		))
	end
end

local function configureRider(character)
	if not character then return end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
			setGroup(part, RIDER_GROUP)
		end
	end
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.2 then return end
	acc = 0
	configureDragon()
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("DragonMounted") == true then
			configureRider(player.Character)
		end
	end
end)
configureDragon()
