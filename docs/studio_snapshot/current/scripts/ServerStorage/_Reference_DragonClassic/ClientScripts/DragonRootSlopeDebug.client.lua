local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local DRAGON_NAME = "DragonModel"
local ENABLE_DEBUG = false
local TICK_RATE = 0.5
local lastLogTime = 0

-- Helpers to create debug parts
local debugFolder = Workspace:FindFirstChild("DragonRootSlopeDebugFolder")
if not debugFolder then
	debugFolder = Instance.new("Folder")
	debugFolder.Name = "DragonRootSlopeDebugFolder"
	debugFolder.Parent = Workspace
end

local function createSphere(color, size)
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(size, size, size)
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = debugFolder
	return part
end

local function createLine(color)
	local part = Instance.new("Part")
	part.Size = Vector3.new(0.2, 0.2, 1)
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = debugFolder
	return part
end

local rootMarker = createSphere(Color3.fromRGB(255, 0, 0), 2)
local rootForwardLine = createLine(Color3.fromRGB(255, 255, 255))
local probeMarkers = {}

local function getProbeMarker(id, color)
    if not probeMarkers[id] then
        probeMarkers[id] = createSphere(color, 1)
    end
    return probeMarkers[id]
end

local function positionLine(line, p1, p2)
	local dist = (p2 - p1).Magnitude
	if dist < 0.001 then
		line.CFrame = CFrame.new(p1)
		line.Size = Vector3.new(0.2, 0.2, 0.2)
		return
	end
	line.Size = Vector3.new(0.2, 0.2, dist)
	line.CFrame = CFrame.lookAt(p1, p2) * CFrame.new(0, 0, -dist/2)
end

local function updateDebug()
	if not ENABLE_DEBUG then return end
	local dragon = Workspace:FindFirstChild(DRAGON_NAME)
	if not dragon then return end
	local root = dragon:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local slopeParams = RaycastParams.new()
	slopeParams.FilterType = Enum.RaycastFilterType.Exclude

	local slopeExclude = { dragon }
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			table.insert(slopeExclude, plr.Character)
		end
	end
	slopeParams.FilterDescendantsInstances = slopeExclude

	local BODY_FRONT = 15
	local BODY_REAR = 12
	local BODY_WIDTH = 5
	local RAY_UP = 18
	local RAY_DOWN = 80
	local ROOT_CLEARANCE = 8.6
	local MAX_ROOT_PITCH = math.rad(38)

	local flatForward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	flatForward = flatForward.Magnitude > 0.01 and flatForward.Unit or Vector3.new(0, 0, -1)

	local right = Vector3.new(root.CFrame.RightVector.X, 0, root.CFrame.RightVector.Z)
	right = right.Magnitude > 0.01 and right.Unit or Vector3.new(1, 0, 0)

	local probeOffsets = {
		{ id="front", offset = flatForward * BODY_FRONT, type = "front" },
		{ id="frontLeft", offset = flatForward * BODY_FRONT - right * BODY_WIDTH, type = "front" },
		{ id="frontRight", offset = flatForward * BODY_FRONT + right * BODY_WIDTH, type = "front" },

		{ id="center", offset = Vector3.zero, type = "center" },
		{ id="left", offset = -right * BODY_WIDTH, type = "center" },
		{ id="right", offset = right * BODY_WIDTH, type = "center" },

		{ id="rear", offset = -flatForward * BODY_REAR, type = "rear" },
		{ id="rearLeft", offset = -flatForward * BODY_REAR - right * BODY_WIDTH, type = "rear" },
		{ id="rearRight", offset = -flatForward * BODY_REAR + right * BODY_WIDTH, type = "rear" },
	}

	local frontSum, centerSum, rearSum = 0, 0, 0
	local frontCount, centerCount, rearCount = 0, 0, 0
	
	local highestHitY = -math.huge

	for _, probe in ipairs(probeOffsets) do
		local origin = root.Position + probe.offset + Vector3.new(0, RAY_UP, 0)
		local hit = Workspace:Raycast(origin, Vector3.new(0, -RAY_DOWN, 0), slopeParams)
		
		local markerColor = Color3.fromRGB(255, 255, 255)
		if probe.type == "front" then markerColor = Color3.fromRGB(255, 165, 0)
		elseif probe.type == "center" then markerColor = Color3.fromRGB(0, 0, 255)
		elseif probe.type == "rear" then markerColor = Color3.fromRGB(128, 0, 128) end
		
		local marker = getProbeMarker(probe.id, markerColor)

		if hit then
			if hit.Position.Y > highestHitY then highestHitY = hit.Position.Y end
			marker.Position = hit.Position
			if probe.type == "center" then
				centerSum += hit.Position.Y
				centerCount += 1
			elseif probe.type == "front" then
				frontSum += hit.Position.Y
				frontCount += 1
			elseif probe.type == "rear" then
				rearSum += hit.Position.Y
				rearCount += 1
			end
		else
			marker.Position = origin + Vector3.new(0, -RAY_DOWN, 0)
		end
	end

	local frontY, centerY, rearY = 0, 0, 0
	local hasFront, hasCenter, hasRear = false, false, false

	if centerCount > 0 then centerY = centerSum / centerCount; hasCenter = true end
	if frontCount > 0 then frontY = frontSum / frontCount; hasFront = true end
	if rearCount > 0 then rearY = rearSum / rearCount; hasRear = true end

	local bodyGroundY = centerY
	local targetPitch = 0

	if hasCenter then bodyGroundY = centerY
	elseif hasFront and hasRear then bodyGroundY = (frontY + rearY) * 0.5
	elseif hasFront then bodyGroundY = frontY
	elseif hasRear then bodyGroundY = rearY end

	local targetY = bodyGroundY + ROOT_CLEARANCE

	if hasFront and hasRear then
		local bodyLength = BODY_FRONT + BODY_REAR
		targetPitch = math.atan2(frontY - rearY, bodyLength)
		targetPitch = math.clamp(targetPitch, -MAX_ROOT_PITCH, MAX_ROOT_PITCH)
	end

	local pitchedForward = (flatForward + Vector3.new(0, math.tan(targetPitch), 0)).Unit

	rootMarker.Position = root.Position
	positionLine(rootForwardLine, root.Position, root.Position + pitchedForward * 10)

	if os.clock() - lastLogTime >= TICK_RATE then
		lastLogTime = os.clock()
		print(string.format("[RootBodyProbe] rootY=%.1f targetY=%.1f frontY=%.1f centerY=%.1f rearY=%.1f pitchDeg=%.1f",
			root.Position.Y, targetY, frontY, centerY, rearY, math.deg(targetPitch)))
	end
end

RunService.Heartbeat:Connect(updateDebug)
