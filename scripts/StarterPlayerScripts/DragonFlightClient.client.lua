local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local SEND_INTERVAL = 1 / 20
local TOGGLE_SEND_WINDOW = 3

local LOG_LEVEL = 1
local warnedKeys = {}

local function log(level, tag, message)
	if LOG_LEVEL >= level then
		print(tag .. " " .. message)
	end
end

local function warnOnce(key, message)
	if warnedKeys[key] then
		return
	end
	warnedKeys[key] = true
	warn(message)
end

local ENABLE_TURN_VISUALS = false
local ENABLE_BODY_CURVE_VISUALS = false
local ENABLE_HEAD_LOOK_VISUALS = false
local ENABLE_TAIL_VISUALS = false
local ENABLE_DRAGON_TURN_CALIBRATION = false
local ENABLE_NECK_LOOK_IK = false
local NECK_LOOK_TEST_MODE = true
local NECK_LOOK_DEBUG = true
local NECK_LOOK_DEBUG_INTERVAL = 1.2
local NECK_TARGET_MODE = "GroundTurnLook"
local NECK_TARGET_DISTANCE = 35
local NECK_TARGET_HEIGHT = 6
local ENABLE_DRAGON_CAMERA_V2 = false
local CAMERA_V2_BASE_FOV = 70
local CAMERA_V2_MAX_FOV = 90
local CAMERA_V2_FOV_RESPONSIVENESS = 8
local CAMERA_V2_ROLL_INFLUENCE = 0.15
local CAMERA_V2_ROLL_RESPONSIVENESS = 9
local CAMERA_V2_PULLBACK_DISTANCE = 8
local CAMERA_V2_PULLBACK_RESPONSIVENESS = 6
local CAMERA_V2_DEBUG_INTERVAL = 0.25
local IK_OFFSET_PRESETS = {
	{ name = "Identity", cf = CFrame.identity },
	{ name = "Yaw90", cf = CFrame.Angles(0, math.rad(90), 0) },
	{ name = "Yaw-90", cf = CFrame.Angles(0, math.rad(-90), 0) },
	{ name = "Yaw180", cf = CFrame.Angles(0, math.rad(180), 0) },
	{ name = "Pitch90", cf = CFrame.Angles(math.rad(90), 0, 0) },
	{ name = "Pitch-90", cf = CFrame.Angles(math.rad(-90), 0, 0) },
	{ name = "Roll90", cf = CFrame.Angles(0, 0, math.rad(90)) },
	{ name = "Roll-90", cf = CFrame.Angles(0, 0, math.rad(-90)) },
}
local NECK_CHAIN_ROOT_NAMES = {
	"Bip01-Neck_32",
	"Bip01-Neck1_11",
	"Bip01-Neck2_10",
	"Bip01-Neck3_9",
}
local TURN_VISUALS_TEST_MODE = true
local TURN_VISUAL_DEBUG = true
local TURN_VISUAL_DEBUG_INTERVAL = 0.3
local MAX_BODY_CURVE_DEGREES = 28
local MAX_TAIL_COUNTER_DEGREES = 35
local TURN_VISUAL_RESPONSIVENESS = 8
local BODY_CURVE_AXIS = "Y"
local TAIL_CURVE_AXIS = "Y"
local HEAD_LOOK_YAW_AXIS = "Y"
local HEAD_LOOK_PITCH_AXIS = "X"
local MAX_HEAD_YAW_DEGREES = 25
local MAX_HEAD_PITCH_UP_DEGREES = 18
local MAX_HEAD_PITCH_DOWN_DEGREES = 22
local HEAD_LOOK_RESPONSIVENESS = 10
local TURN_VISUAL_MODES = { "All", "RootTurnOnly", "BankOnly", "BodyCurveOnly", "HeadLookOnly", "TailOnly" }
local CALIBRATION_AXIS = "Y"
local CALIBRATION_BODY_CURVE_DEGREES = 45
local CALIBRATION_TAIL_CURVE_DEGREES = 55
local CALIBRATION_FREQUENCY = 1.5
local CALIBRATION_LOG_INTERVAL = 0.5
local CALIBRATION_WEIGHTS = {
	["Bip01-Spine_64"] = 0.10,
	["Bip01-Spine1_53"] = 0.16,
	["Bip01-Spine2_52"] = 0.22,
	["Bip01-Neck_32"] = 0.16,
	["Bip01-Neck1_11"] = 0.14,
	["Bip01-Neck2_10"] = 0.12,
	["Bip01-Neck3_9"] = 0.10,
	["Bip01-Head_8"] = 0.08,
	["tail_Bone001_70"] = -0.30,
	["tail_Bone002_69"] = -0.45,
}

local ACTION_TOGGLE = "DragonFlight_Toggle"
local ACTION_THROTTLE = "DragonFlight_Throttle"
local ACTION_BRAKE = "DragonFlight_Brake"
local ACTION_TURN_LEFT = "DragonFlight_TurnLeft"
local ACTION_TURN_RIGHT = "DragonFlight_TurnRight"
local ACTION_CLIMB = "DragonFlight_Climb"
local ACTION_DESCEND = "DragonFlight_Descend"
local ACTION_BOOST = "DragonFlight_Boost"
local ACTION_UNMOUNT = "DragonFlight_Unmount"
local ACTION_TURN_VISUAL_MODE = "DragonTurnVisual_Mode"
local ACTION_TURN_CALIBRATION = "DragonTurnCalibration_Toggle"
local ACTION_TURN_CALIBRATION_AXIS_X = "DragonTurnCalibration_AxisX"
local ACTION_TURN_CALIBRATION_AXIS_Y = "DragonTurnCalibration_AxisY"
local ACTION_TURN_CALIBRATION_AXIS_Z = "DragonTurnCalibration_AxisZ"
local ACTION_VISUAL_BANK_AXIS = "DragonFlightV2_BankAxis"
local ACTION_NECK_LOOK_TOGGLE = "DragonNeckIK_Toggle"
local ACTION_NECK_LOOK_CHAIN = "DragonNeckIK_ChainRoot"
local ACTION_NECK_LOOK_OFFSET = "DragonNeckIK_Offset"
local ACTION_NECK_LOOK_TARGET_MODE = "DragonNeckIK_TargetMode"
local ACTION_NECK_LOOK_AUTOCALIB = "DragonNeckIK_AutoCalibrate"
local ACTION_NECK_LOOK_OFFSET_PROPERTY = "DragonNeckIK_OffsetProperty"


local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("DragonFlightRemotes")
local toggleRemote = remotes:WaitForChild("FlightToggle")
local inputRemote = remotes:WaitForChild("FlightInput")
local debugRemote = remotes:WaitForChild("FlightDebug")
local unmountRemote = remotes:WaitForChild("FlightUnmount")


local buttonState = {
	throttle = 0,
	brake = 0,
	left = 0,
	right = 0,
	climb = 0,
	descend = 0,
	boost = 0,
}

local isControlling = false
local sendUntil = 0
local sendAccumulator = 0
local latestState = "Grounded"
local latestMode = "Grounded"
local latestSpeed = 0
local latestAltitude = 0
local latestTurnIntensity = 0
local latestTurnInput = 0
local latestTurnRateDeg = 0
local latestYawErrorDeg = 0
local latestBankDeg = 0
local latestVisualMotorBankAxis = "Z"
local latestSmoothedMoveDirection = Vector3.new(0, 0, -1)
local latestGroundForward = Vector3.new(0, 0, -1)

local turnVisualModeIndex = 1
local turnVisualMode = "All"
local smoothedTurnIntensity = 0
local smoothedHeadYaw = 0
local smoothedHeadPitch = 0
local turnVisualEntries = {}
local turnVisualApplied = {}
local turnVisualDebugElapsed = 0
local calibrationEnabled = false
local calibrationAxis = CALIBRATION_AXIS
local calibrationFakeTurn = 0
local calibrationDebugElapsed = 0
local visualBankAxes = { "Z", "X", "Y" }
local visualBankAxisIndex = 1
local visualMotorBankAxis = visualBankAxes[visualBankAxisIndex]
local currentCameraRoll = 0
local currentCameraPullback = 0
local cameraV2DebugElapsed = 0
local neckLookEnabled = false
local neckTargetMode = NECK_TARGET_MODE
local neckChainIndex = 1
local neckOffsetIndex = 1
local neckLookTarget = nil
local neckLookIK = nil
local neckLookInitialized = false
local neckLookInitElapsed = 0
local neckOffsetPropertyMode = "EndEffectorOffset"
local lastMouthDot = 0
local neckLookDebugElapsed = 0
local dragonMouseAimActive = false

local function findDragonBone(boneName)
	local dragon = Workspace:FindFirstChild("DragonModel")
	local mesh = dragon and dragon:FindFirstChild("DragonMesh")
	local bone = mesh and mesh:FindFirstChild(boneName, true)
	if bone and bone:IsA("Bone") then
		return bone
	end

	return nil
end

local function axisRotation(axisName, amount)
	if axisName == "X" then
		return CFrame.Angles(amount, 0, 0)
	elseif axisName == "Y" then
		return CFrame.Angles(0, amount, 0)
	end

	return CFrame.Angles(0, 0, amount)
end

local function addTurnVisualEntry(entries, boneName, weight, axisName, maxDegrees, groupName)
	local bone = findDragonBone(boneName)
	if bone then
		table.insert(entries, {
			bone = bone,
			weight = weight,
			axisName = axisName,
			maxRadians = math.rad(maxDegrees),
			groupName = groupName or "Body",
		})
	else
		warn("[DragonTurnCalibration][WARN] Missing bone: " .. boneName)
	end
end

local function describeTurnVisualEntries(entries)
	local names = {}
	for _, entry in ipairs(entries) do
		table.insert(names, ("%s=%d%%/%s"):format(entry.bone.Name, math.floor(entry.weight * 100 + 0.5), entry.axisName))
	end
	return #names > 0 and table.concat(names, ", ") or "none"
end

local function initializeDragonTurnVisuals()
	if not ENABLE_TURN_VISUALS or #turnVisualEntries > 0 then
		return
	end

	print("[DragonTurnCalibration] Ready")
	addTurnVisualEntry(turnVisualEntries, "Bip01-Spine_64", 0.10, BODY_CURVE_AXIS, MAX_BODY_CURVE_DEGREES, "Body")
	addTurnVisualEntry(turnVisualEntries, "Bip01-Spine1_53", 0.16, BODY_CURVE_AXIS, MAX_BODY_CURVE_DEGREES, "Body")
	addTurnVisualEntry(turnVisualEntries, "Bip01-Spine2_52", 0.20, BODY_CURVE_AXIS, MAX_BODY_CURVE_DEGREES, "Body")
	addTurnVisualEntry(turnVisualEntries, "Bip01-Neck_32", 0.14, BODY_CURVE_AXIS, MAX_BODY_CURVE_DEGREES, "Body")
	addTurnVisualEntry(turnVisualEntries, "Bip01-Neck1_11", 0.12, BODY_CURVE_AXIS, MAX_BODY_CURVE_DEGREES, "Body")
	addTurnVisualEntry(turnVisualEntries, "Bip01-Neck2_10", 0.10, BODY_CURVE_AXIS, MAX_BODY_CURVE_DEGREES, "Body")
	addTurnVisualEntry(turnVisualEntries, "Bip01-Neck3_9", 0.08, BODY_CURVE_AXIS, MAX_BODY_CURVE_DEGREES, "Body")
	addTurnVisualEntry(turnVisualEntries, "Bip01-Head_8", 0.05, BODY_CURVE_AXIS, MAX_BODY_CURVE_DEGREES, "Body")
	addTurnVisualEntry(turnVisualEntries, "tail_Bone001_70", -0.18, TAIL_CURVE_AXIS, MAX_TAIL_COUNTER_DEGREES, "Tail")
	addTurnVisualEntry(turnVisualEntries, "tail_Bone002_69", -0.25, TAIL_CURVE_AXIS, MAX_TAIL_COUNTER_DEGREES, "Tail")

	if #turnVisualEntries == 0 then
		warn("[DragonTurn][WARN] No body/tail bones found. DragonTurnVisuals disabled.")
		return
	end

	print("[DragonTurnCalibration] Bones loaded: " .. describeTurnVisualEntries(turnVisualEntries))
	print("[DragonTurn] DragonTurnVisuals ready")
	print("[DragonTurn] BodyCurve entries: " .. describeTurnVisualEntries(turnVisualEntries))
	print("[DragonTurn] BODY_CURVE_AXIS=" .. BODY_CURVE_AXIS .. " TAIL_CURVE_AXIS=" .. TAIL_CURVE_AXIS)
end

local function applyTurnAdditives(additives)
	for bone, additive in pairs(additives) do
		local previousAdditive = turnVisualApplied[bone] or CFrame.identity
		local animationTransform = bone.Transform * previousAdditive:Inverse()
		bone.Transform = animationTransform * additive
		turnVisualApplied[bone] = additive
	end

	for bone, previousAdditive in pairs(turnVisualApplied) do
		if not additives[bone] then
			local animationTransform = bone.Transform * previousAdditive:Inverse()
			bone.Transform = animationTransform
			turnVisualApplied[bone] = nil
		end
	end
end

local function computeLocalHeadAim(root)
	local camera = Workspace.CurrentCamera
	local cameraLook = camera and camera.CFrame.LookVector
	if not isControlling or not root or not cameraLook or cameraLook.Magnitude < 0.01 then
		return 0, 0, Vector3.new(0, 0, -1)
	end

	local localLook = root.CFrame:VectorToObjectSpace(cameraLook.Unit)
	local targetYaw = math.clamp(math.atan2(localLook.X, -localLook.Z), -math.rad(MAX_HEAD_YAW_DEGREES), math.rad(MAX_HEAD_YAW_DEGREES))
	local rawPitch = math.asin(math.clamp(localLook.Y, -1, 1))
	local targetPitch = math.clamp(rawPitch, -math.rad(MAX_HEAD_PITCH_DOWN_DEGREES), math.rad(MAX_HEAD_PITCH_UP_DEGREES))
	return targetYaw, targetPitch, localLook
end

local function updateDragonTurnCalibration(dt)
	local t = os.clock()
	calibrationFakeTurn = math.sin(t * CALIBRATION_FREQUENCY)
	local additives = {}

	for _, entry in ipairs(turnVisualEntries) do
		local weight = CALIBRATION_WEIGHTS[entry.bone.Name] or entry.weight
		local maxDegrees = entry.groupName == "Tail" and CALIBRATION_TAIL_CURVE_DEGREES or CALIBRATION_BODY_CURVE_DEGREES
		local amount = calibrationFakeTurn * math.rad(maxDegrees) * weight
		additives[entry.bone] = (additives[entry.bone] or CFrame.identity) * axisRotation(calibrationAxis, amount)
	end

	applyTurnAdditives(additives)

	calibrationDebugElapsed += dt
	if calibrationDebugElapsed >= CALIBRATION_LOG_INTERVAL then
		calibrationDebugElapsed = 0
		local curveDeg = calibrationFakeTurn * CALIBRATION_BODY_CURVE_DEGREES
		print(("[DragonTurnCalibration] axis=%s fakeTurn=%.2f curveDeg=%.1f"):format(calibrationAxis, calibrationFakeTurn, curveDeg))
	end
end

local function updateDragonTurnVisuals(dt)
	if not ENABLE_TURN_VISUALS then
		return
	end

	initializeDragonTurnVisuals()
	if #turnVisualEntries == 0 then
		return
	end

	if calibrationEnabled then
		updateDragonTurnCalibration(dt)
		return
	end

	local dragon = Workspace:FindFirstChild("DragonModel")
	local root = dragon and dragon:FindFirstChild("HumanoidRootPart")
	local targetTurnIntensity = isControlling and latestTurnIntensity or 0
	local turnAlpha = 1 - math.exp(-TURN_VISUAL_RESPONSIVENESS * dt)
	smoothedTurnIntensity += (targetTurnIntensity - smoothedTurnIntensity) * turnAlpha

	local headYawTarget, headPitchTarget, localLook = computeLocalHeadAim(root)
	local headAlpha = 1 - math.exp(-HEAD_LOOK_RESPONSIVENESS * dt)
	smoothedHeadYaw += (headYawTarget - smoothedHeadYaw) * headAlpha
	smoothedHeadPitch += (headPitchTarget - smoothedHeadPitch) * headAlpha

	local additives = {}
	local useBodyCurve = ENABLE_BODY_CURVE_VISUALS and (turnVisualMode == "All" or turnVisualMode == "BodyCurveOnly")
	local useTailCounterbalance = ENABLE_TAIL_VISUALS and (turnVisualMode == "All" or turnVisualMode == "TailOnly")
	local useHeadLook = ENABLE_HEAD_LOOK_VISUALS and (turnVisualMode == "All" or turnVisualMode == "HeadLookOnly")
	local bodyCurveDeg = smoothedTurnIntensity * MAX_BODY_CURVE_DEGREES

	for _, entry in ipairs(turnVisualEntries) do
		local shouldApply = (entry.groupName == "Tail" and useTailCounterbalance) or (entry.groupName ~= "Tail" and useBodyCurve)
		if shouldApply then
			local amount = smoothedTurnIntensity * entry.maxRadians * entry.weight
			additives[entry.bone] = (additives[entry.bone] or CFrame.identity) * axisRotation(entry.axisName, amount)
		end
	end

	if useHeadLook then
		local headBone = findDragonBone("Bip01-Head_8")
		local neck3 = findDragonBone("Bip01-Neck3_9")
		local neck2 = findDragonBone("Bip01-Neck2_10")
		local headLookTargets = {
			{ bone = neck2, weight = 0.20 },
			{ bone = neck3, weight = 0.25 },
			{ bone = headBone, weight = 0.55 },
		}

		for _, entry in ipairs(headLookTargets) do
			if entry.bone then
				local yaw = axisRotation(HEAD_LOOK_YAW_AXIS, smoothedHeadYaw * entry.weight)
				local pitch = axisRotation(HEAD_LOOK_PITCH_AXIS, smoothedHeadPitch * entry.weight)
				additives[entry.bone] = (additives[entry.bone] or CFrame.identity) * pitch * yaw
			end
		end
	end

	applyTurnAdditives(additives)

	turnVisualDebugElapsed += dt
	if TURN_VISUAL_DEBUG and turnVisualDebugElapsed >= TURN_VISUAL_DEBUG_INTERVAL then
		turnVisualDebugElapsed = 0
		print(("[DragonTurn] mode=%s turnIntensity=%.2f yawError=%.1f bank=%.1f bodyCurveDeg=%.1f localLook=(%.2f, %.2f, %.2f)"):format(
			turnVisualMode,
			latestTurnIntensity,
			latestYawErrorDeg,
			latestBankDeg,
			bodyCurveDeg,
			localLook.X,
			localLook.Y,
			localLook.Z
		))
	end
end

local function cycleTurnVisualMode()
	turnVisualModeIndex += 1
	if turnVisualModeIndex > #TURN_VISUAL_MODES then
		turnVisualModeIndex = 1
	end
	turnVisualMode = TURN_VISUAL_MODES[turnVisualModeIndex]
	print("[DragonTurn] Visual mode: " .. turnVisualMode)
end

local function setCalibrationAxis(axisName)
	calibrationAxis = axisName
	print("[DragonTurnCalibration] Axis set to " .. calibrationAxis)
end

local function toggleDragonTurnCalibration()
	if not ENABLE_DRAGON_TURN_CALIBRATION then
		calibrationEnabled = false
		print("[DragonTurnCalibration] disabled for DragonFlightV2_HTTYDStyle phase 1")
		return
	end

	calibrationEnabled = not calibrationEnabled
	calibrationDebugElapsed = CALIBRATION_LOG_INTERVAL
	print(("[DragonTurnCalibration] %s axis=%s"):format(calibrationEnabled and "ON" or "OFF", calibrationAxis))
end

local function cycleVisualMotorBankAxis()
	visualBankAxisIndex += 1
	if visualBankAxisIndex > #visualBankAxes then
		visualBankAxisIndex = 1
	end
	visualMotorBankAxis = visualBankAxes[visualBankAxisIndex]
	latestVisualMotorBankAxis = visualMotorBankAxis
	print("[DragonFlightV2] visualMotorBankAxis=" .. visualMotorBankAxis)
end

local function findDragonNeckBone(boneName)
	local dragon = Workspace:FindFirstChild("DragonModel")
	local mesh = dragon and dragon:FindFirstChild("DragonMesh")
	local bone = mesh and mesh:FindFirstChild(boneName, true)
	if bone and bone:IsA("Bone") then
		return bone
	end

	return nil
end

local function getDragonRoot()
	local dragon = Workspace:FindFirstChild("DragonModel")
	local root = dragon and dragon:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	return nil
end

local function getOrCreateNeckLookTarget()
	local dragon = Workspace:FindFirstChild("DragonModel")
	if not dragon then
		return nil
	end

	local target = dragon:FindFirstChild("DragonNeckLookTarget")
	if target and not target:IsA("BasePart") then
		target:Destroy()
		target = nil
	end

	if not target then
		target = Instance.new("Part")
		target.Name = "DragonNeckLookTarget"
		target.Parent = dragon
	end

	target.Anchored = true
	target.CanCollide = false
	target.CanTouch = false
	target.CanQuery = false
	target.Size = Vector3.new(1, 1, 1)
	target.Transparency = neckLookEnabled and 0.35 or 1
	target.Color = Color3.fromRGB(255, 255, 0)
	target.Material = Enum.Material.Neon
	neckLookTarget = target
	return target
end

local function getOrCreateNeckLookIK()
	local dragon = Workspace:FindFirstChild("DragonModel")
	local animationController = dragon and dragon:FindFirstChildOfClass("AnimationController")
	local animator = animationController and animationController:FindFirstChildOfClass("Animator")
	if not animator then
		warn("[DragonNeckIK][WARN] Animator missing")
		return nil
	end

	local ik = animator:FindFirstChild("DragonNeckLookIK")
	if ik and not ik:IsA("IKControl") then
		ik:Destroy()
		ik = nil
	end

	if not ik then
		local ok, created = pcall(Instance.new, "IKControl")
		if not ok or not created then
			warn("[DragonNeckIK][WARN] Could not create IKControl")
			return nil
		end
		ik = created
		ik.Name = "DragonNeckLookIK"
		ik.Parent = animator
	end

	neckLookIK = ik
	return ik
end

local function applyNeckLookOffset(ik)
	local preset = IK_OFFSET_PRESETS[neckOffsetIndex] or IK_OFFSET_PRESETS[1]
	local usedProperty = neckOffsetPropertyMode
	local ok
	if neckOffsetPropertyMode == "EndEffectorOffset" then
		ok = pcall(function()
			ik.EndEffectorOffset = preset.cf
		end)
	else
		ok = pcall(function()
			ik.Offset = preset.cf
		end)
	end
	if not ok then
		warnOnce("NeckOffsetProperty_" .. neckOffsetPropertyMode, "[DragonNeckIK][WARN] Offset property failed: " .. neckOffsetPropertyMode)
	end
	return usedProperty
end

local function applyNeckLookChain()
	local ik = getOrCreateNeckLookIK()
	local target = getOrCreateNeckLookTarget()
	local chainName = NECK_CHAIN_ROOT_NAMES[neckChainIndex]
	local chainRoot = findDragonNeckBone(chainName)
	local headBone = findDragonNeckBone("Bip01-Head_8")

	if not ik or not target or not chainRoot or not headBone then
		warnOnce("NeckApplyChainMissing", "[DragonNeckIK][WARN] Cannot apply chain. ik=" .. tostring(ik ~= nil) .. " target=" .. tostring(target ~= nil) .. " chain=" .. tostring(chainRoot ~= nil) .. " head=" .. tostring(headBone ~= nil))
		return
	end

	ik.Type = Enum.IKControlType.LookAt
	ik.ChainRoot = chainRoot
	ik.EndEffector = headBone
	ik.Target = target
	ik.Weight = NECK_LOOK_TEST_MODE and 1 or 0.8
	ik.SmoothTime = NECK_LOOK_TEST_MODE and 0.03 or 0.05
	ik.Enabled = neckLookEnabled
	pcall(function()
		ik.Priority = 10
	end)
	local usedOffset = applyNeckLookOffset(ik)

	local chainCount = "n/a"
	local chainLength = "n/a"
	pcall(function()
		chainCount = tostring(ik:GetChainCount())
	end)
	pcall(function()
		chainLength = tostring(ik:GetChainLength())
	end)

	log(1, "[DragonNeckIK]", "IKControl ready")
	log(1, "[DragonNeckIK]", "ChainRoot=" .. chainRoot.Name .. " EndEffector=" .. headBone.Name)
	log(2, "[DragonNeckIK]", "OffsetProperty=" .. usedOffset .. " ChainCount=" .. tostring(chainCount) .. " ChainLength=" .. tostring(chainLength))
end

local function initializeDragonNeckLookIK()
	if not ENABLE_NECK_LOOK_IK then
		return
	end

	local dragon = Workspace:FindFirstChild("DragonModel")
	local mesh = dragon and dragon:FindFirstChild("DragonMesh")
	if not dragon or not mesh then
		return
	end

	log(1, "[DragonNeckIK]", "DragonMesh found")

	local found = {}
	for _, name in ipairs(NECK_CHAIN_ROOT_NAMES) do
		local bone = findDragonNeckBone(name)
		if bone then
			table.insert(found, name)
		else
			warnOnce("MissingNeckBone_" .. name, "[DragonNeckIK][WARN] Missing neck bone: " .. name)
		end
	end
	log(1, "[DragonNeckIK]", "Neck bones found: " .. (#found > 0 and table.concat(found, ", ") or "none"))

	local headBone = findDragonNeckBone("Bip01-Head_8")
	if headBone then
		log(1, "[DragonNeckIK]", "Head bone found: " .. headBone.Name)
	else
		warnOnce("MissingHeadBone", "[DragonNeckIK][WARN] Missing head bone: Bip01-Head_8")
	end

	if getOrCreateNeckLookTarget() then
		log(1, "[DragonNeckIK]", "Target ready")
	end
	applyNeckLookChain()
	neckLookInitialized = neckLookIK ~= nil
end

local function setNeckLookEnabled(enabled)
	neckLookEnabled = enabled and ENABLE_NECK_LOOK_IK
	local target = getOrCreateNeckLookTarget()
	local ik = getOrCreateNeckLookIK()
	if target then
		target.Transparency = neckLookEnabled and 0.35 or 1
	end
	if ik then
		ik.Enabled = neckLookEnabled
	end
	log(1, "[DragonNeckIK]", neckLookEnabled and "ON" or "OFF")
end

local function cycleNeckLookChain()
	neckChainIndex += 1
	if neckChainIndex > #NECK_CHAIN_ROOT_NAMES then
		neckChainIndex = 1
	end
	applyNeckLookChain()
	log(1, "[DragonNeckIK]", "ChainRoot changed to " .. NECK_CHAIN_ROOT_NAMES[neckChainIndex])
end

local function cycleNeckLookOffset()
	neckOffsetIndex += 1
	if neckOffsetIndex > #IK_OFFSET_PRESETS then
		neckOffsetIndex = 1
	end
	local ik = getOrCreateNeckLookIK()
	if ik then
		applyNeckLookOffset(ik)
	end
	local preset = IK_OFFSET_PRESETS[neckOffsetIndex]
	log(1, "[DragonNeckIK]", "Offset preset changed to " .. tostring(preset and preset.name or neckOffsetIndex))
end

local function cycleNeckTargetMode()
	local modes = { "GroundTurnLook", "Camera", "MouseRay", "FIMSpaceLook" }
	local currentIndex = table.find(modes, neckTargetMode) or 1
	currentIndex += 1
	if currentIndex > #modes then
		currentIndex = 1
	end
	neckTargetMode = modes[currentIndex]
	log(1, "[DragonNeckIK]", "TargetMode changed to " .. neckTargetMode)
end

local function getHeadAndMouthBones()
	local headBone = findDragonNeckBone("Bip01-Head_8")
	local mouthBone = findDragonNeckBone("mouse_bone_3")
	return headBone, mouthBone
end

local function measureMouthDot(target)
	local headBone, mouthBone = getHeadAndMouthBones()
	if not headBone or not target then
		return 0, 0
	end

	local headPos = headBone.TransformedWorldCFrame.Position
	local toTarget = target.Position - headPos
	local dist = toTarget.Magnitude
	if dist < 0.01 then
		return 0, dist
	end
	local toTargetUnit = toTarget.Unit

	if mouthBone then
		local mouthVector = mouthBone.TransformedWorldCFrame.Position - headPos
		if mouthVector.Magnitude >= 0.01 then
			return mouthVector.Unit:Dot(toTargetUnit), dist
		end
	end

	local cf = headBone.TransformedWorldCFrame
	local candidates = {
		cf.LookVector,
		-cf.LookVector,
		cf.RightVector,
		-cf.RightVector,
		cf.UpVector,
		-cf.UpVector,
	}
	local bestDot = -math.huge
	for _, candidate in ipairs(candidates) do
		bestDot = math.max(bestDot, candidate.Unit:Dot(toTargetUnit))
	end
	return bestDot, dist
end

local function cycleNeckOffsetProperty()
	neckOffsetPropertyMode = neckOffsetPropertyMode == "EndEffectorOffset" and "Offset" or "EndEffectorOffset"
	local ik = getOrCreateNeckLookIK()
	if ik then
		applyNeckLookOffset(ik)
	end
	log(1, "[DragonNeckIK]", "Offset property changed to " .. neckOffsetPropertyMode)
end

local function autoCalibrateNeckIK()
	local ik = getOrCreateNeckLookIK()
	local target = getOrCreateNeckLookTarget()
	if not ik or not target then
		warnOnce("NeckAutoCalibMissing", "[DragonNeckIK][WARN] AutoCalib skipped because IK or target is missing")
		return
	end

	task.spawn(function()
		local previousIndex = neckOffsetIndex
		local bestIndex = previousIndex
		local bestDot = -math.huge
		for index, _ in ipairs(IK_OFFSET_PRESETS) do
			neckOffsetIndex = index
			applyNeckLookOffset(ik)
			RunService.RenderStepped:Wait()
			local dot = select(1, measureMouthDot(target))
			if dot > bestDot then
				bestDot = dot
				bestIndex = index
			end
		end
		neckOffsetIndex = bestIndex
		applyNeckLookOffset(ik)
		lastMouthDot = bestDot
		local preset = IK_OFFSET_PRESETS[bestIndex]
		log(1, "[DragonNeckIK]", ("AutoCalib best preset=%s mouthDot=%.2f"):format(preset and preset.name or tostring(bestIndex), bestDot))
	end)
end

local function updateDragonMouseAim(_dt)
	dragonMouseAimActive = player:GetAttribute("DragonMouseAimActive") == true
end

local function findVisualMotor()
	local dragon = Workspace:FindFirstChild("DragonModel")
	local root = dragon and dragon:FindFirstChild("HumanoidRootPart")
	local motor = root and root:FindFirstChildOfClass("Motor6D")
	if motor then
		return motor
	end

	return nil
end

local function updateVisualMotorBank()
	local motor = findVisualMotor()
	if not motor then
		return
	end

	if isControlling and latestState ~= "Grounded" then
		motor.Transform = axisRotation(visualMotorBankAxis, math.rad(latestBankDeg))
	else
		motor.Transform = CFrame.identity
	end
end

local function updateDragonCameraV2(dt)
	if not ENABLE_DRAGON_CAMERA_V2 then
		return
	end

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local speedAlpha = math.clamp((latestSpeed - 50) / 100, 0, 1)
	local targetFov = CAMERA_V2_BASE_FOV
	local targetRoll = 0
	local targetPullback = 0

	if isControlling and latestState ~= "Grounded" then
		targetFov = CAMERA_V2_BASE_FOV + speedAlpha * (CAMERA_V2_MAX_FOV - CAMERA_V2_BASE_FOV)
		targetRoll = math.rad(latestBankDeg) * CAMERA_V2_ROLL_INFLUENCE
		targetPullback = speedAlpha * CAMERA_V2_PULLBACK_DISTANCE
	end

	local fovAlpha = 1 - math.exp(-CAMERA_V2_FOV_RESPONSIVENESS * dt)
	local rollAlpha = 1 - math.exp(-CAMERA_V2_ROLL_RESPONSIVENESS * dt)
	local pullbackAlpha = 1 - math.exp(-CAMERA_V2_PULLBACK_RESPONSIVENESS * dt)

	camera.FieldOfView += (targetFov - camera.FieldOfView) * fovAlpha
	local baseCameraFrame = camera.CFrame * CFrame.new(0, 0, -currentCameraPullback) * CFrame.Angles(0, 0, -currentCameraRoll)
	currentCameraRoll += (targetRoll - currentCameraRoll) * rollAlpha
	currentCameraPullback += (targetPullback - currentCameraPullback) * pullbackAlpha
	camera.CFrame = baseCameraFrame * CFrame.Angles(0, 0, currentCameraRoll) * CFrame.new(0, 0, currentCameraPullback)

	cameraV2DebugElapsed += dt
	if cameraV2DebugElapsed >= CAMERA_V2_DEBUG_INTERVAL then
		cameraV2DebugElapsed = 0
		print(("[DragonCameraV2] fov=%.1f cameraRoll=%.2f pullback=%.1f"):format(camera.FieldOfView, math.deg(currentCameraRoll), currentCameraPullback))
	end
end

local function createDebugGui()
	local existing = playerGui:FindFirstChild("DragonFlightDebugGui")
	if existing then
		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DragonFlightDebugGui"
	screenGui.DisplayOrder = 50
	screenGui.IgnoreGuiInset = false
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0, 0)
	frame.Position = UDim2.fromOffset(14, 74)
	frame.Size = UDim2.fromOffset(230, 132)
	frame.BackgroundColor3 = Color3.fromRGB(18, 21, 26)
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(82, 96, 115)
	stroke.Transparency = 0.35
	stroke.Thickness = 1
	stroke.Parent = frame

	local labels = {}
	local function addLabel(key, y, text)
		local label = Instance.new("TextLabel")
		label.Name = key
		label.Position = UDim2.fromOffset(10, y)
		label.Size = UDim2.new(1, -20, 0, 20)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamMedium
		label.TextColor3 = Color3.fromRGB(235, 240, 246)
		label.TextSize = 14
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Text = text
		label.Parent = frame
		labels[key] = label
	end

	addLabel("State", 10, "Estado: Grounded")
	addLabel("Speed", 34, "Velocidad: 0")
	addLabel("Altitude", 58, "Altitud: 0")
	addLabel("Mounted", 82, "Mounted: NO")
	addLabel("MouseAim", 106, "MouseAim: OFF")
	return labels
end

local debugLabels = createDebugGui()

local function updateDebugLabels()
	debugLabels.State.Text = "Estado: " .. latestState
	debugLabels.Speed.Text = ("Velocidad: %d"):format(math.floor(latestSpeed + 0.5))
	debugLabels.Altitude.Text = ("Altitud: %d"):format(math.floor(latestAltitude + 0.5))
	debugLabels.Mounted.Text = "Mounted: " .. (isControlling and "YES" or "NO")
	debugLabels.MouseAim.Text = "MouseAim: " .. (player:GetAttribute("DragonMouseAimActive") == true and "ON" or "OFF")
end

local function shouldCaptureControls()
	return isControlling or os.clock() < sendUntil
end

local function actionIsDown(inputState)
	return inputState == Enum.UserInputState.Begin or inputState == Enum.UserInputState.Change
end

local function setDigitalValue(actionName, inputState)
	local value = actionIsDown(inputState) and 1 or 0

	if actionName == ACTION_THROTTLE then
		buttonState.throttle = value
	elseif actionName == ACTION_BRAKE then
		buttonState.brake = value
	elseif actionName == ACTION_TURN_LEFT then
		buttonState.left = value
	elseif actionName == ACTION_TURN_RIGHT then
		buttonState.right = value
	elseif actionName == ACTION_CLIMB then
		buttonState.climb = value
	elseif actionName == ACTION_DESCEND then
		buttonState.descend = value
	elseif actionName == ACTION_BOOST then
		buttonState.boost = value
	end
end

local function handleFlightAction(actionName, inputState)
	if actionName == ACTION_TURN_VISUAL_MODE then
		return Enum.ContextActionResult.Pass
	end

	if actionName == ACTION_NECK_LOOK_TOGGLE then
		return Enum.ContextActionResult.Pass
	end

	if actionName == ACTION_NECK_LOOK_CHAIN then
		if inputState == Enum.UserInputState.Begin then
			cycleNeckLookChain()
			updateDebugLabels()
		end

		return Enum.ContextActionResult.Sink
	end

	if actionName == ACTION_NECK_LOOK_OFFSET then
		if inputState == Enum.UserInputState.Begin then
			cycleNeckLookOffset()
			updateDebugLabels()
		end

		return Enum.ContextActionResult.Sink
	end

	if actionName == ACTION_NECK_LOOK_TARGET_MODE then
		if inputState == Enum.UserInputState.Begin then
			cycleNeckTargetMode()
			updateDebugLabels()
		end

		return Enum.ContextActionResult.Sink
	end

	if actionName == ACTION_NECK_LOOK_AUTOCALIB then
		if inputState == Enum.UserInputState.Begin then
			autoCalibrateNeckIK()
			updateDebugLabels()
		end

		return Enum.ContextActionResult.Sink
	end

	if actionName == ACTION_NECK_LOOK_OFFSET_PROPERTY then
		if inputState == Enum.UserInputState.Begin then
			cycleNeckOffsetProperty()
			updateDebugLabels()
		end

		return Enum.ContextActionResult.Sink
	end

	if actionName == ACTION_VISUAL_BANK_AXIS then
		if inputState == Enum.UserInputState.Begin then
			cycleVisualMotorBankAxis()
			updateDebugLabels()
		end

		return Enum.ContextActionResult.Sink
	end

	if actionName == ACTION_TURN_CALIBRATION then
		if inputState == Enum.UserInputState.Begin then
			toggleDragonTurnCalibration()
			updateDebugLabels()
		end

		return Enum.ContextActionResult.Sink
	end

	if actionName == ACTION_TURN_CALIBRATION_AXIS_X or actionName == ACTION_TURN_CALIBRATION_AXIS_Y or actionName == ACTION_TURN_CALIBRATION_AXIS_Z then
		if inputState == Enum.UserInputState.Begin then
			if actionName == ACTION_TURN_CALIBRATION_AXIS_X then
				setCalibrationAxis("X")
			elseif actionName == ACTION_TURN_CALIBRATION_AXIS_Y then
				setCalibrationAxis("Y")
			else
				setCalibrationAxis("Z")
			end
			updateDebugLabels()
		end

		return Enum.ContextActionResult.Sink
	end

	if actionName == ACTION_UNMOUNT then
		if inputState == Enum.UserInputState.Begin then
			unmountRemote:FireServer()
			isControlling = false
			sendUntil = 0
		end

		return Enum.ContextActionResult.Sink
	end

	if actionName == ACTION_TOGGLE then
		if inputState == Enum.UserInputState.Begin then
			sendUntil = os.clock() + TOGGLE_SEND_WINDOW
			toggleRemote:FireServer()
		end

		return Enum.ContextActionResult.Sink
	end

	setDigitalValue(actionName, inputState)

	if shouldCaptureControls() then
		return Enum.ContextActionResult.Sink
	end

	return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction(ACTION_TOGGLE, handleFlightAction, true, Enum.KeyCode.F)
ContextActionService:BindAction(ACTION_THROTTLE, handleFlightAction, true, Enum.KeyCode.W)
ContextActionService:BindAction(ACTION_BRAKE, handleFlightAction, true, Enum.KeyCode.S)
ContextActionService:BindAction(ACTION_TURN_LEFT, handleFlightAction, true, Enum.KeyCode.A)
ContextActionService:BindAction(ACTION_TURN_RIGHT, handleFlightAction, true, Enum.KeyCode.D)
ContextActionService:BindAction(ACTION_CLIMB, handleFlightAction, true, Enum.KeyCode.Space)
ContextActionService:BindAction(ACTION_DESCEND, handleFlightAction, true, Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl)
ContextActionService:BindAction(ACTION_BOOST, handleFlightAction, true, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift)
ContextActionService:BindAction(ACTION_UNMOUNT, handleFlightAction, true, Enum.KeyCode.X)
-- DragonMouseAim.client.lua owns N for the visual mouse aim toggle.

if UserInputService.TouchEnabled then
	ContextActionService:SetTitle(ACTION_TOGGLE, "Fly")
	ContextActionService:SetTitle(ACTION_THROTTLE, "W")
	ContextActionService:SetTitle(ACTION_BRAKE, "S")
	ContextActionService:SetTitle(ACTION_TURN_LEFT, "A")
	ContextActionService:SetTitle(ACTION_TURN_RIGHT, "D")
	ContextActionService:SetTitle(ACTION_CLIMB, "Up")
	ContextActionService:SetTitle(ACTION_DESCEND, "Down")
	ContextActionService:SetTitle(ACTION_BOOST, "Dive")
	ContextActionService:SetTitle(ACTION_UNMOUNT, "UNMOUNT")


	ContextActionService:SetPosition(ACTION_TOGGLE, UDim2.fromScale(0.84, 0.42))
	ContextActionService:SetPosition(ACTION_THROTTLE, UDim2.fromScale(0.72, 0.58))
	ContextActionService:SetPosition(ACTION_BRAKE, UDim2.fromScale(0.72, 0.72))
	ContextActionService:SetPosition(ACTION_TURN_LEFT, UDim2.fromScale(0.61, 0.66))
	ContextActionService:SetPosition(ACTION_TURN_RIGHT, UDim2.fromScale(0.83, 0.66))
	ContextActionService:SetPosition(ACTION_CLIMB, UDim2.fromScale(0.88, 0.54))
	ContextActionService:SetPosition(ACTION_DESCEND, UDim2.fromScale(0.88, 0.76))
	ContextActionService:SetPosition(ACTION_BOOST, UDim2.fromScale(0.52, 0.78))
	ContextActionService:SetPosition(ACTION_UNMOUNT, UDim2.fromScale(0.52, 0.62))

end

local function readControls()
	return {
		throttle = buttonState.throttle,
		brake = buttonState.brake,
		turn = buttonState.right - buttonState.left,
		climb = buttonState.climb - buttonState.descend,
		boost = buttonState.boost == 1,
	}
end

local function getCurrentDragonAimDirection(fallback)
	local x = player:GetAttribute("DragonAimDirectionX")
	local y = player:GetAttribute("DragonAimDirectionY")
	local z = player:GetAttribute("DragonAimDirectionZ")
	if typeof(x) == "number" and typeof(y) == "number" and typeof(z) == "number" then
		local aimDirection = Vector3.new(x, y, z)
		if aimDirection.Magnitude > 0.01 then
			return aimDirection.Unit
		end
	end
	return fallback
end

local function sendInputPacket()
	local camera = Workspace.CurrentCamera
	local cameraCFrame = camera and camera.CFrame or CFrame.new()
	local controls = readControls()
	local aimDirection = getCurrentDragonAimDirection(cameraCFrame.LookVector)

	inputRemote:FireServer({
		throttle = controls.throttle,
		brake = controls.brake,
		turn = controls.turn,
		climb = controls.climb,
		boost = controls.boost,
		cameraLook = cameraCFrame.LookVector,
		aimDirection = aimDirection,
		cameraRight = cameraCFrame.RightVector,
		visualBankAxis = visualMotorBankAxis,
	})
end

debugRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	latestState = tostring(payload.state or "Grounded")
	latestMode = tostring(payload.mode or latestState)
	latestSpeed = typeof(payload.speed) == "number" and payload.speed or 0
	latestAltitude = typeof(payload.altitude) == "number" and payload.altitude or 0
	latestTurnIntensity = typeof(payload.turnIntensity) == "number" and payload.turnIntensity or latestTurnIntensity
	latestTurnInput = typeof(payload.turnInput) == "number" and payload.turnInput or latestTurnInput
	latestTurnRateDeg = typeof(payload.turnRateDeg) == "number" and payload.turnRateDeg or latestTurnRateDeg
	latestYawErrorDeg = typeof(payload.yawErrorDeg) == "number" and payload.yawErrorDeg or latestYawErrorDeg
	latestBankDeg = typeof(payload.bankDeg) == "number" and payload.bankDeg or latestBankDeg
	local latestUTurnIntent = typeof(payload.uTurnIntent) == "number" and payload.uTurnIntent or 0
	player:SetAttribute("DragonTurnInput", latestTurnInput)
	player:SetAttribute("DragonYawErrorDeg", latestYawErrorDeg)
	player:SetAttribute("DragonUTurnIntent", latestUTurnIntent)
	player:SetAttribute("DragonMountedState", latestState)
	if typeof(payload.smoothedMoveDirection) == "Vector3" and payload.smoothedMoveDirection.Magnitude >= 0.01 then
		latestSmoothedMoveDirection = payload.smoothedMoveDirection.Unit
		player:SetAttribute("DragonSmoothedMoveDirectionX", latestSmoothedMoveDirection.X)
		player:SetAttribute("DragonSmoothedMoveDirectionY", latestSmoothedMoveDirection.Y)
		player:SetAttribute("DragonSmoothedMoveDirectionZ", latestSmoothedMoveDirection.Z)
	end
	if typeof(payload.groundForward) == "Vector3" and payload.groundForward.Magnitude >= 0.01 then
		latestGroundForward = payload.groundForward.Unit
		player:SetAttribute("DragonGroundForwardX", latestGroundForward.X)
		player:SetAttribute("DragonGroundForwardY", latestGroundForward.Y)
		player:SetAttribute("DragonGroundForwardZ", latestGroundForward.Z)
	end
	if typeof(payload.visualMotorBankAxis) == "string" then
		latestVisualMotorBankAxis = payload.visualMotorBankAxis
	end

	isControlling = payload.controller == player.Name and latestState ~= "Grounded"
	if isControlling then
		sendUntil = os.clock() + TOGGLE_SEND_WINDOW
	elseif latestState == "Grounded" then
		sendUntil = 0
	end

	updateDebugLabels()

	if typeof(payload.message) == "string" and payload.message ~= "" then
		warn("[DragonFlight] " .. payload.message)
	end
end)

RunService.RenderStepped:Connect(function(dt)
	sendAccumulator += dt
	if sendAccumulator >= SEND_INTERVAL then
		sendAccumulator = 0

		if isControlling or os.clock() < sendUntil then
			sendInputPacket()
		end
	end

	updateDragonTurnVisuals(dt)
	updateVisualMotorBank()
	updateDragonCameraV2(dt)
	updateDragonMouseAim(dt)
	updateDebugLabels()
end)

updateDebugLabels()
log(1, "[DragonFlight]", "Client ready. F toggles flight input for Workspace.DragonModel.")