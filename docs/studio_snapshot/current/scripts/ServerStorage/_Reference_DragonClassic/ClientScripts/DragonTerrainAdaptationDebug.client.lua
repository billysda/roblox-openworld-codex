-- DragonTerrainAdaptationDebug.client.lua
-- Phase 1C & Phase 2: Leg IK + Visual Torso/Body Height + Pitch Alignment.
-- Active only when player:GetAttribute("DragonMounted") == true.
-- Does NOT modify root position, velocity, welds, constraints, or physics.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local DRAGON_NAME = "DragonModel"
local DEBUG_FOLDER_NAME = "DragonTerrainAdaptationDebug"
local TARGET_SMOOTH_SPEED = 28
local WEIGHT_SMOOTH_SPEED = 18
local LOG_INTERVAL = 1.0

-- Kill Switch
local ENABLE_BODY_ALIGNMENT = false
local SHOW_DEBUG_VISUALS = false

-- Configurations
local IK_TARGET_WEIGHT = 0.55
local MAX_TARGET_WEIGHT = 0.80

local IK_FRONT_TARGET_WEIGHT = 0.36
local MAX_FRONT_TARGET_WEIGHT = 0.62

local FOOT_SURFACE_OFFSET = 0.08
local MAX_TARGET_DELTA = 12.0

-- Body Alignment Configurations
local BODY_CLEARANCE = 14.03 -- calibrated vertical offset of visual mesh relative to ground
local BODY_HEIGHT_SMOOTH_SPEED = 14
local BODY_PITCH_SMOOTH_SPEED = 18
local MAX_BODY_PITCH_DEGREES = 45
local BODY_ALIGN_WEIGHT = 0.85
local MAX_BODY_ALIGN_WEIGHT = 1.0

local COLOR_TOE_REAL = Color3.fromRGB(255, 60, 60)      -- Red: Actual Toe Position
local COLOR_GROUND_HIT = Color3.fromRGB(60, 255, 90)    -- Green: Ground Hit Point
local COLOR_TARGET_SMOOTH = Color3.fromRGB(70, 220, 255) -- Cyan: Smoothed Target
local COLOR_RAY = Color3.fromRGB(255, 245, 80)           -- Yellow: Ray path
local COLOR_NORMAL = Color3.fromRGB(0, 255, 120)        -- Lime/Green: Ground Normal

local BONE_CHAINS = {
	RearLeft = {
		label = "RL",
		thigh = "Bip01-L-Thigh_58",
		calf = "Bip01-L-Calf_57",
		foot = "Bip01-L-Foot_55",
		toe = "Bip01-L-Toe0_54",
		isFront = false,
	},
	RearRight = {
		label = "RR",
		thigh = "Bip01-R-Thigh_63",
		calf = "Bip01-R-Calf_62",
		foot = "Bip01-R-Foot_60",
		toe = "Bip01-R-Toe0_59",
		isFront = false,
	},
	FrontLeft = {
		label = "FL",
		thigh = "Bip01-L-UpperArm_20",
		calf = "Bip01-L-Forearm_19",
		foot = "Bip01-L-Hand_18",
		toe = "Bip01-L-Finger1_15",
		isFront = true,
	},
	FrontRight = {
		label = "FR",
		thigh = "Bip01-R-UpperArm_30",
		calf = "Bip01-R-Forearm_29",
		foot = "Bip01-R-Hand_28",
		toe = "Bip01-R-Finger1_25",
		isFront = true,
	}
}

local dragon = nil
local animator = nil
local rootBone = nil
local debugFolder = nil
local entries = {}
local initialized = false
local logElapsed = 0
local bodyLogElapsed = 0

-- Alignment smoothing variables
local currentAlignWeight = 0
local smoothedHeightOffset = 0
local smoothedPitch = 0

local lastLogTime = 0

-- Parked Foot Lock Mem
local lastValidFoot = {
	RR = nil,
	RL = nil,
	FR = nil,
	FL = nil,
}

local parkedFoot = {
	RR = nil,
	RL = nil,
	FR = nil,
	FL = nil,
}

local lastValidWeight = {
	RR = 0,
	RL = 0,
	FR = 0,
	FL = 0,
}

local currentDragonState = nil
local previousDragonState = nil
local function getMountedState()
	local isMounted = false
	if player:GetAttribute("DragonMounted") == true then
		isMounted = true
	else
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.SeatPart and hum.SeatPart.Name == "DragonRiderSea" then
			isMounted = true
		end
	end

	if not dragon then
		dragon = Workspace:FindFirstChild(DRAGON_NAME)
	end

	local state = dragon and dragon:GetAttribute("DragonFlightState") or ""
	local shouldRunIK = isMounted or state == "MountedGround" or state == "GroundWalk" or state == "GroundTrot" or state == "GroundBack" or state == "ParkedGround"
	
	local now = os.clock()
	if now - lastLogTime >= 1 then
		lastLogTime = now
		print("[DragonIK] active=", shouldRunIK, "state=", state, "mounted=", isMounted)
	end
	
	return shouldRunIK
end

local function ensureDebugFolder()
	debugFolder = Workspace:FindFirstChild(DEBUG_FOLDER_NAME)
	if not debugFolder then
		debugFolder = Instance.new("Folder")
		debugFolder.Name = DEBUG_FOLDER_NAME
		debugFolder.Parent = Workspace
	end
	return debugFolder
end

local function cleanDebugFolder()
	local folder = Workspace:FindFirstChild(DEBUG_FOLDER_NAME)
	if folder then
		folder:Destroy()
	end
	debugFolder = nil
end

local function makePart(name, color, size, shape)
	local parent = ensureDebugFolder()
	local part = parent:FindFirstChild(name)
	if not part then
		part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Material = Enum.Material.Neon
		part.Parent = parent
	end
	part.Shape = shape or Enum.PartType.Ball
	part.Color = color
	part.Size = Vector3.new(size, size, size)
	part.Transparency = SHOW_DEBUG_VISUALS and 0.15 or 1
	return part
end

local function updateRayVisual(rayPart, fromPos, toPos, thickness)
	local mid = (fromPos + toPos) * 0.5
	local length = math.max((fromPos - toPos).Magnitude, 0.05)
	rayPart.Size = Vector3.new(thickness or 0.05, length, thickness or 0.05)
	rayPart.CFrame = CFrame.lookAt(mid, toPos) * CFrame.Angles(math.rad(90), 0, 0)
end

local function buildRaycastParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	
	local filter = { dragon }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(filter, p.Character)
		end
	end
	params.FilterDescendantsInstances = filter
	return params
end

local function getBone(mesh, name)
	local b = mesh:FindFirstChild(name, true)
	if b and b:IsA("Bone") then
		return b
	end
	return nil
end

local function tryInitialize()
	dragon = Workspace:FindFirstChild(DRAGON_NAME)
	if not dragon then return false end
	
	local mesh = dragon:FindFirstChild("DragonMesh")
	if not mesh then return false end
	
	rootBone = getBone(mesh, "Root_73")
	if not rootBone then
		warn("[DragonTerrainAdaptationDebug] Root_73 bone not found!")
		return false
	end
	
	local controller = dragon:FindFirstChildOfClass("AnimationController")
	animator = controller and controller:FindFirstChildOfClass("Animator")
	
	ensureDebugFolder()
	entries = {}
	local foundChains = 0
	
	for side, config in pairs(BONE_CHAINS) do
		local thighBone = getBone(mesh, config.thigh)
		local calfBone = getBone(mesh, config.calf)
		local footBone = getBone(mesh, config.foot)
		local toeBone = getBone(mesh, config.toe)
		
		if thighBone and calfBone and footBone and toeBone then
			foundChains += 1
			
			-- Visual probe parts
			local toePart = makePart(side .. "_ToeReal", COLOR_TOE_REAL, 0.35)
			local groundPart = makePart(side .. "_GroundHit", COLOR_GROUND_HIT, 0.25)
			local targetPart = makePart(side .. "_TargetSmooth", COLOR_TARGET_SMOOTH, 0.30)
			
			local rayPart = makePart(side .. "_Ray", COLOR_RAY, 0.05, Enum.PartType.Block)
			local normalPart = makePart(side .. "_Normal", COLOR_NORMAL, 0.06, Enum.PartType.Block)
			
			-- Setup target attachment inside targetPart for IK target CFrame alignment
			local targetAttachment = targetPart:FindFirstChild("IKTargetAttachment")
			if not targetAttachment then
				targetAttachment = Instance.new("Attachment")
				targetAttachment.Name = "IKTargetAttachment"
				targetAttachment.Parent = targetPart
			end
			
			-- Create IKControl targeting Foot/Hand bone (not Toe/Finger)
			local ikControl = nil
			if animator then
				ikControl = animator:FindFirstChild("AdaptationIK_" .. side)
				if not ikControl then
					ikControl = Instance.new("IKControl")
					ikControl.Name = "AdaptationIK_" .. side
					ikControl.Parent = animator
				end
				ikControl.Enabled = false
				ikControl.Weight = 0
				ikControl.Type = Enum.IKControlType.Position
				ikControl.ChainRoot = thighBone
				ikControl.EndEffector = footBone
				ikControl.Target = targetPart
			end
			
			table.insert(entries, {
				side = side,
				label = config.label,
				toeBone = toeBone,
				toePart = toePart,
				groundPart = groundPart,
				targetPart = targetPart,
				rayPart = rayPart,
				normalPart = normalPart,
				ikControl = ikControl,
				smoothedPosition = nil,
				currentWeight = 0,
				isFront = config.isFront,
				lastHitPosition = nil,
			})
		else
			warn(("[DragonTerrainAdaptationDebug] Missing bones for %s chain"):format(side))
		end
	end
	
	if foundChains > 0 then
		local fl = BONE_CHAINS.FrontLeft
		local fr = BONE_CHAINS.FrontRight
		print(("[DragonTerrainAdaptationDebug] Front chains FL=%s -> %s FR=%s -> %s"):format(fl.thigh, fl.foot, fr.thigh, fr.foot))
		print(("[DragonTerrainAdaptationDebug] RearIK enabled lowWeight=true maxWeight=%.2f endEffector=Foot"):format(IK_TARGET_WEIGHT))
		initialized = true
	end
	
	return initialized
end

local function setVisualsVisible(visible)
	if not debugFolder then return end
	local transparency = visible and (SHOW_DEBUG_VISUALS and 0.15 or 1) or 1
	for _, child in ipairs(debugFolder:GetChildren()) do
		if child:IsA("BasePart") then
			child.Transparency = transparency
		end
	end
end

local function updateLeg(entry, dt)
	local toePos = entry.toeBone.TransformedWorldCFrame.Position
	entry.toePart.Position = toePos
	
	local rayOrigin = toePos + Vector3.new(0, 12, 0)
	local rayDirection = Vector3.new(0, -40, 0)
	
	local params = buildRaycastParams()
	local hit = Workspace:Raycast(rayOrigin, rayDirection, params)
	
	local logData = {
		hit = false,
		dist = 999,
		normalY = 0,
		weight = 0,
		delta = 0
	}
	
	local targetWeight = 0
	local maxW = entry.isFront and MAX_FRONT_TARGET_WEIGHT or MAX_TARGET_WEIGHT
	local targetW = entry.isFront and IK_FRONT_TARGET_WEIGHT or IK_TARGET_WEIGHT
	
	local state = player:GetAttribute("DragonMountedState")
	local isGrounded = (
		state == "Grounded"
		or state == "MountedGround"
		or state == "GroundWalk"
		or state == "GroundTrot"
		or state == "GroundBack"
		or state == nil
	)
	
	if hit and isGrounded then
		logData.hit = true
		logData.dist = rayOrigin.Y - hit.Position.Y - 12
		logData.normalY = hit.Normal.Y
		entry.lastHitPosition = hit.Position
		
		-- Place ground hit indicator
		entry.groundPart.Transparency = SHOW_DEBUG_VISUALS and 0.15 or 1
		entry.groundPart.Position = hit.Position
		
		-- Normal visual indicator
		entry.normalPart.Transparency = SHOW_DEBUG_VISUALS and 0.15 or 1
		updateRayVisual(entry.normalPart, hit.Position, hit.Position + hit.Normal * 2, 0.08)
		
		-- Target Position calculation with surface offset
		local targetPos = hit.Position + hit.Normal * FOOT_SURFACE_OFFSET
		local deltaVec = targetPos - toePos
		local delta = deltaVec.Magnitude
		
		-- No apagar IK cuando la animación aleja demasiado la pata.
		-- En vez de peso 0, limitamos el target para evitar estiramiento extremo.
		if delta > MAX_TARGET_DELTA and deltaVec.Magnitude > 0.01 then
			targetPos = toePos + deltaVec.Unit * MAX_TARGET_DELTA
			delta = MAX_TARGET_DELTA
		end
		
		logData.delta = delta
		targetWeight = targetW
		
		-- Smoothed Target Position
		if not entry.smoothedPosition then
			entry.smoothedPosition = targetPos
		else
			local alpha = 1 - math.exp(-TARGET_SMOOTH_SPEED * dt)
			entry.smoothedPosition = entry.smoothedPosition:Lerp(targetPos, alpha)
		end
		entry.targetPart.Position = entry.smoothedPosition
		entry.targetPart.Transparency = SHOW_DEBUG_VISUALS and 0.15 or 1
		
		-- Ray line visual (Yellow)
		entry.rayPart.Transparency = SHOW_DEBUG_VISUALS and 0.15 or 1
		updateRayVisual(entry.rayPart, rayOrigin, hit.Position, 0.04)
		
		lastValidFoot[entry.label] = entry.targetPart.CFrame
		lastValidWeight[entry.label] = entry.currentWeight
	else
		-- No ground hit
		local legName = entry.label
		if currentDragonState == "ParkedGround" and parkedFoot[legName] then
			entry.targetPart.CFrame = parkedFoot[legName]
			entry.smoothedPosition = parkedFoot[legName].Position

			local holdWeight = lastValidWeight[legName] or 0
			if holdWeight <= 0 then
				local defaultWeight = entry.isFront and 0.36 or 0.55
				holdWeight = defaultWeight
			end

			entry.currentWeight = holdWeight
			if entry.ikControl then
				entry.ikControl.Weight = holdWeight
				entry.ikControl.Enabled = (holdWeight > 0.01)
			end

			logData.hit = false
			logData.weight = holdWeight
			logData.isParkedHold = true

			return logData
		end

		entry.lastHitPosition = nil
		entry.groundPart.Transparency = 1
		entry.normalPart.Transparency = 1
		entry.rayPart.Transparency = 1
		
		-- Lerp target back to actual toe position
		if entry.smoothedPosition then
			local alpha = 1 - math.exp(-TARGET_SMOOTH_SPEED * dt)
			entry.smoothedPosition = entry.smoothedPosition:Lerp(toePos, alpha)
			entry.targetPart.Position = entry.smoothedPosition
			
			if (entry.smoothedPosition - toePos).Magnitude < 0.1 then
				entry.targetPart.Transparency = 1
			end
		else
			entry.targetPart.Transparency = 1
		end
	end
	
	-- Weight smoothing logic
	local weightAlpha = 1 - math.exp(-WEIGHT_SMOOTH_SPEED * dt) -- transition weight smoothly
	entry.currentWeight = math.clamp(entry.currentWeight + (targetWeight - entry.currentWeight) * weightAlpha, 0, maxW)
	logData.weight = entry.currentWeight
	
	-- Apply IK parameters
	if entry.ikControl then
		entry.ikControl.Weight = entry.currentWeight
		if entry.currentWeight > 0.01 then
			entry.ikControl.Enabled = true
		else
			entry.ikControl.Enabled = false
		end
	end
	
	return logData
end

local function cleanIKControls()
	if animator then
		for _, name in ipairs({"AdaptationIK_RearLeft", "AdaptationIK_RearRight", "AdaptationIK_FrontLeft", "AdaptationIK_FrontRight"}) do
			local ik = animator:FindFirstChild(name)
			if ik then
				ik:Destroy()
			end
		end
	end
end

local function cleanBodyVisuals()
	if debugFolder then
		for _, name in ipairs({"Body_AvgFootY", "Body_TargetY", "Body_FrontRearLine"}) do
			local part = debugFolder:FindFirstChild(name)
			if part then
				part.Transparency = 1
			end
		end
	end
end

local function updateBodyVisuals(validHits, avgFootY, bodyTargetY)
	local dragModel = Workspace:FindFirstChild(DRAGON_NAME)
	local rootPart = dragModel and dragModel:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	
	local centerPos = rootPart.Position
	
	-- Yellow sphere: avgFootY
	local avgFootPart = makePart("Body_AvgFootY", Color3.fromRGB(255, 235, 40), 0.45)
	avgFootPart.Position = Vector3.new(centerPos.X, avgFootY, centerPos.Z)
	avgFootPart.Transparency = SHOW_DEBUG_VISUALS and 0.15 or 1
	
	-- Blue sphere: bodyTargetY
	local targetPart = makePart("Body_TargetY", Color3.fromRGB(40, 100, 255), 0.45)
	targetPart.Position = Vector3.new(centerPos.X, bodyTargetY, centerPos.Z)
	targetPart.Transparency = SHOW_DEBUG_VISUALS and 0.15 or 1
	
	-- Line connecting average front to average rear
	local frontSum = Vector3.zero
	local frontCount = 0
	local rearSum = Vector3.zero
	local rearCount = 0
	
	for _, entry in ipairs(entries) do
		if entry.lastHitPosition then
			if entry.isFront then
				frontSum = frontSum + entry.lastHitPosition
				frontCount = frontCount + 1
			else
				rearSum = rearSum + entry.lastHitPosition
				rearCount = rearCount + 1
			end
		end
	end
	
	if frontCount > 0 and rearCount > 0 then
		local frontCenter = frontSum / frontCount
		local rearCenter = rearSum / rearCount
		local linePart = makePart("Body_FrontRearLine", Color3.fromRGB(255, 120, 40), 0.1, Enum.PartType.Block)
		linePart.Transparency = SHOW_DEBUG_VISUALS and 0.15 or 1
		updateRayVisual(linePart, frontCenter, rearCenter, 0.1)
	else
		local linePart = debugFolder:FindFirstChild("Body_FrontRearLine")
		if linePart then
			linePart.Transparency = 1
		end
	end
end

local function resetEntriesWeight(dt)
	for _, entry in ipairs(entries) do
		if entry.ikControl then
			local weightAlpha = 1 - math.exp(-12 * dt)
			local maxW = entry.isFront and MAX_FRONT_TARGET_WEIGHT or MAX_TARGET_WEIGHT
			entry.currentWeight = math.clamp(entry.currentWeight + (0 - entry.currentWeight) * weightAlpha, 0, maxW)
			entry.ikControl.Weight = entry.currentWeight
			if entry.currentWeight <= 0.01 then
				entry.ikControl.Enabled = false
			end
		end
	end
end

local function shutdown()
	cleanDebugFolder()
	cleanIKControls()
	
	-- Ensure Root Bone is reset cleanly on shutdown
	if rootBone then
		rootBone.Transform = CFrame.identity
	end
	
	initialized = false
end

local function update(dt)
	local active = getMountedState()
	
	currentDragonState = dragon and dragon:GetAttribute("DragonFlightState") or nil

	if currentDragonState == "ParkedGround" and previousDragonState ~= "ParkedGround" then
		for legName, cf in pairs(lastValidFoot) do
			parkedFoot[legName] = cf
		end
		print("[DragonIK] parked foot lock captured")
	end

	if currentDragonState ~= "ParkedGround" then
		for legName in pairs(parkedFoot) do
			parkedFoot[legName] = nil
		end
	end

	previousDragonState = currentDragonState

	if not active then
		if initialized then
			resetEntriesWeight(dt)
			
			-- Smooth alignment back to 0
			local heightAlpha = 1 - math.exp(-BODY_HEIGHT_SMOOTH_SPEED * dt)
			smoothedHeightOffset = smoothedHeightOffset + (0 - smoothedHeightOffset) * heightAlpha
			local pitchAlpha = 1 - math.exp(-BODY_PITCH_SMOOTH_SPEED * dt)
			smoothedPitch = smoothedPitch + (0 - smoothedPitch) * pitchAlpha
			local weightAlpha = 1 - math.exp(-WEIGHT_SMOOTH_SPEED * dt)
			currentAlignWeight = currentAlignWeight + (0 - currentAlignWeight) * weightAlpha
			
			if rootBone then
				local appliedHeight = 0
				local appliedPitch = smoothedPitch * currentAlignWeight
				if math.abs(appliedHeight) > 0.01 or math.abs(appliedPitch) > 0.001 then
					rootBone.Transform = CFrame.Angles(appliedPitch, 0, 0)
				else
					rootBone.Transform = CFrame.identity
				end
			end
			
			cleanBodyVisuals()
			
			local allWeightGone = true
			for _, entry in ipairs(entries) do
				if entry.currentWeight > 0.01 then
					allWeightGone = false
					break
				end
			end
			if allWeightGone and currentAlignWeight < 0.01 then
				shutdown()
			end
		end
		return
	end
	
	if not initialized then
		tryInitialize()
		if not initialized then return end
	end
	
	setVisualsVisible(true)
	
	local logSamples = {}
	local validHits = {}
	local frontHits = {}
	local rearHits = {}
	
	local maxDelta = 0
	local lostHits = 0
	local hasAnyParkedFootLock = false
	
	for _, entry in ipairs(entries) do
		local data = updateLeg(entry, dt)
		if data.isParkedHold then
			table.insert(logSamples, string.format("parked hold %s cached=true w=%.2f", entry.label, data.weight))
			hasAnyParkedFootLock = true
		else
			table.insert(logSamples, string.format("%s hit=%s w=%.2f delta=%.2f", 
				entry.label, tostring(data.hit), data.weight, data.delta))
		end
		
		if data.delta and data.delta > maxDelta then
			maxDelta = data.delta
		end
		if not data.hit then
			lostHits = lostHits + 1
		end
			
		if entry.lastHitPosition then
			table.insert(validHits, entry.lastHitPosition)
			if entry.isFront then
				table.insert(frontHits, entry.lastHitPosition.Y)
			else
				table.insert(rearHits, entry.lastHitPosition.Y)
			end
		end
	end
	
	if dragon then
		dragon:SetAttribute("DragonIKMaxDelta", maxDelta)
		dragon:SetAttribute("DragonIKLostHits", lostHits)
		dragon:SetAttribute("DragonIKParkedLocked", currentDragonState == "ParkedGround" and hasAnyParkedFootLock)
	end
	
	-- Visual Body Terrain Alignment (Height + Pitch)
	local motor = dragon and dragon:FindFirstChild("HumanoidRootPart") and dragon.HumanoidRootPart:FindFirstChild("DragonMesh")
	local targetAlignWeight = 0
	
	if active and ENABLE_BODY_ALIGNMENT and #validHits >= 3 and rootBone then
		targetAlignWeight = BODY_ALIGN_WEIGHT
	end
	
	local weightAlpha = 1 - math.exp(-WEIGHT_SMOOTH_SPEED * dt)
	currentAlignWeight = currentAlignWeight + (targetAlignWeight - currentAlignWeight) * weightAlpha
	currentAlignWeight = math.clamp(currentAlignWeight, 0, MAX_BODY_ALIGN_WEIGHT)
	
	if currentAlignWeight > 0.01 and rootBone and motor and motor:IsA("Motor6D") then
		local targetHeightOffset = 0
		local targetPitch = 0
		local avgFootY = 0
		local frontAvgY = 0
		local rearAvgY = 0
		
		if #validHits >= 3 then
			local sumY = 0
			for _, pos in ipairs(validHits) do
				sumY = sumY + pos.Y
			end
			avgFootY = sumY / #validHits
			
			frontAvgY = avgFootY
			if #frontHits > 0 then
				local sumF = 0
				for _, y in ipairs(frontHits) do
					sumF = sumF + y
				end
				frontAvgY = sumF / #frontHits
			end
			
			rearAvgY = avgFootY
			if #rearHits > 0 then
				local sumR = 0
				for _, y in ipairs(rearHits) do
					sumR = sumR + y
				end
				rearAvgY = sumR / #rearHits
			end
			
			local defaultVisualRootCFrame = motor.Part0.CFrame * motor.C0
			local currentVisualY = defaultVisualRootCFrame.Position.Y
			
			local bodyTargetY = avgFootY + BODY_CLEARANCE
			targetHeightOffset = bodyTargetY - currentVisualY
			
			-- Pitch alignment calculation
			local deltaY = frontAvgY - rearAvgY
			
			-- Calculate bodyLength dynamically
			local frontSum = Vector3.zero
			local frontCount = 0
			local rearSum = Vector3.zero
			local rearCount = 0
			for _, entry in ipairs(entries) do
				if entry.lastHitPosition then
					if entry.isFront then
						frontSum = frontSum + entry.lastHitPosition
						frontCount = frontCount + 1
					else
						rearSum = rearSum + entry.lastHitPosition
						rearCount = rearCount + 1
					end
				end
			end
			
			local bodyLength = 9.0
			if frontCount > 0 and rearCount > 0 then
				local frontCenter = frontSum / frontCount
				local rearCenter = rearSum / rearCount
				bodyLength = (Vector3.new(frontCenter.X, 0, frontCenter.Z) - Vector3.new(rearCenter.X, 0, rearCenter.Z)).Magnitude
				if bodyLength < 1 then
					bodyLength = 9.0
				end
			end
			
			targetPitch = math.atan2(deltaY, math.max(bodyLength, 0.001))
			local maxPitchRad = math.rad(MAX_BODY_PITCH_DEGREES)
			targetPitch = math.clamp(targetPitch, -maxPitchRad, maxPitchRad)
			
			-- Update visual markers
			updateBodyVisuals(validHits, avgFootY, bodyTargetY)
		else
			cleanBodyVisuals()
		end
		
		-- Smooth alignments
		local heightAlpha = 1 - math.exp(-BODY_HEIGHT_SMOOTH_SPEED * dt)
		smoothedHeightOffset = smoothedHeightOffset + (targetHeightOffset - smoothedHeightOffset) * heightAlpha
		
		local pitchAlpha = 1 - math.exp(-BODY_PITCH_SMOOTH_SPEED * dt)
		smoothedPitch = smoothedPitch + (targetPitch - smoothedPitch) * pitchAlpha
		
		-- Blended outputs
		local appliedHeight = 0
		local appliedPitch = smoothedPitch * currentAlignWeight
		
		local hasNaN = false
		if appliedHeight ~= appliedHeight or appliedPitch ~= appliedPitch or math.abs(appliedHeight) == math.huge or math.abs(appliedPitch) == math.huge then
			hasNaN = true
		end
		
		if hasNaN then
			if not _G.WarnedTerrainNaN then
				warn("[DragonTerrainAdaptationDebug] NaN detected in alignment! Resetting.")
				_G.WarnedTerrainNaN = true
			end
			currentAlignWeight = 0
			smoothedPitch = 0
			smoothedHeightOffset = 0
			appliedHeight = 0
			appliedPitch = 0
			rootBone.Transform = CFrame.identity
		else
			rootBone.Transform = CFrame.new(0, appliedHeight, 0) * CFrame.Angles(appliedPitch, 0, 0)
		end
		
		-- Logging
		bodyLogElapsed = bodyLogElapsed + dt
		if bodyLogElapsed >= 1.0 then
			bodyLogElapsed = 0
			print(string.format("[DragonBodyAlign] avgY=%.2f frontY=%.2f rearY=%.2f pitch=%.2f appliedPitch=%.2f height=%.2f w=%.2f",
				avgFootY, frontAvgY, rearAvgY, math.deg(targetPitch), math.deg(appliedPitch), appliedHeight, currentAlignWeight))
		end
	else
		-- Smooth alignments back to 0
		local heightAlpha = 1 - math.exp(-BODY_HEIGHT_SMOOTH_SPEED * dt)
		smoothedHeightOffset = smoothedHeightOffset + (0 - smoothedHeightOffset) * heightAlpha
		
		local pitchAlpha = 1 - math.exp(-BODY_PITCH_SMOOTH_SPEED * dt)
		smoothedPitch = smoothedPitch + (0 - smoothedPitch) * pitchAlpha
		
		if rootBone then
			local appliedHeight = 0
			local appliedPitch = smoothedPitch * currentAlignWeight
			if math.abs(appliedHeight) > 0.01 or math.abs(appliedPitch) > 0.001 then
				rootBone.Transform = CFrame.Angles(appliedPitch, 0, 0)
			else
				rootBone.Transform = CFrame.identity
			end
		end
		
		cleanBodyVisuals()
	end
	
	logElapsed += dt
	if logElapsed >= LOG_INTERVAL then
		logElapsed = 0
		print("[DragonIK] " .. table.concat(logSamples, " | "))
	end
end

script.Destroying:Connect(shutdown)

RunService.Heartbeat:Connect(function(dt)
	update(math.clamp(dt, 1/240, 1/15))
end)
