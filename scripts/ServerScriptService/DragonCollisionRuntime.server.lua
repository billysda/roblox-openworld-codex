print("[DragonCollisionRuntime] Active v7 stable collider")

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

local function setGroup(part, group)
	if part and part:IsA("BasePart") then
		pcall(function() part.CollisionGroup = group end)
	end
end

local function cfg(dragon, name, fallback)
	local folder = dragon and dragon:FindFirstChild("DragonMountConfig")
	local obj = folder and folder:FindFirstChild(name)
	if obj and obj:IsA("ValueBase") then return obj.Value end
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

local function shouldColliderCollide()
	local state = getMountedFlightState()
	if state == "Fly" or state == "Glide" or state == "Dive" or state == "Takeoff" or state == "Landing" then
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
	setGroup(root, DRAGON_GROUP)

	local sx = tonumber(cfg(dragon, "GroundColliderSizeX", 7)) or 7
	local sy = tonumber(cfg(dragon, "GroundColliderSizeY", 3.8)) or 3.8
	local sz = tonumber(cfg(dragon, "GroundColliderSizeZ", 11)) or 11
	local ox = tonumber(cfg(dragon, "GroundColliderOffsetX", 0)) or 0
	local oy = tonumber(cfg(dragon, "GroundColliderOffsetY", -3.1)) or -3.1
	local oz = tonumber(cfg(dragon, "GroundColliderOffsetZ", 0.4)) or 0.4
	local show = cfg(dragon, "ShowGroundCollider", false) == true
	local key = table.concat({sx, sy, sz, ox, oy, oz, tostring(show)}, "|")

	local collider = dragon:FindFirstChild("DragonGroundCollider")
	if collider and not collider:IsA("BasePart") then
		collider:Destroy()
		collider = nil
	end
	if not collider then
		collider = Instance.new("Part")
		collider.Name = "DragonGroundCollider"
		collider.Parent = dragon
		lastColliderKey = nil
	end

	if key ~= lastColliderKey then
		local oldWeld = collider:FindFirstChild("DragonGroundColliderWeld")
		if oldWeld then oldWeld:Destroy() end
		collider.Size = Vector3.new(sx, sy, sz)
		collider.Transparency = show and 0.45 or 1
		collider.Material = Enum.Material.ForceField
		collider.Color = Color3.fromRGB(0, 255, 255)
		collider.Anchored = false
		collider.Massless = false
		collider.CFrame = root.CFrame * CFrame.new(ox, oy, oz)
		local weld = Instance.new("WeldConstraint")
		weld.Name = "DragonGroundColliderWeld"
		weld.Part0 = root
		weld.Part1 = collider
		weld.Parent = collider
		lastColliderKey = key
		print(("[DragonCollisionRuntime] Collider rebuilt size=(%.1f, %.1f, %.1f) offset=(%.1f, %.1f, %.1f)"):format(sx, sy, sz, ox, oy, oz))
	end

	collider.CanCollide = shouldColliderCollide()
	collider.CanTouch = false
	collider.CanQuery = false
	setGroup(collider, DRAGON_GROUP)

	local now = os.clock()
	if now - lastPrint > 10 then
		lastPrint = now
		print("[DragonCollisionRuntime] stable; colliderCanCollide=" .. tostring(collider.CanCollide) .. " state=" .. getMountedFlightState())
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
