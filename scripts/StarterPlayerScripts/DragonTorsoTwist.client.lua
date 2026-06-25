local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local DRAGON_NAME = "DragonModel"
local ENABLE_DRAGON_TORSO_TWIST = true
local TORSO_TWIST_DEBUG = false
local DEBUG_APPLY_TRANSFORM = false
local DEBUG_WALK_SPINE_ANIMATION = false
local SHOW_TORSO_TWIST_PROBES = false
local AUTO_CALIBRATE_TORSO_TWIST = false
local MANUAL_AXIS_TEST_ENABLED = true
local USE_HEARTBEAT_LATE_APPLY_FALLBACK = true

local TORSO_TWIST_PROFILE = "FollowThrough"
local TORSO_TWIST_PROFILES = {
	FollowThrough = {
		{
			name = "Bip01-Spine1_53",
			role = "front",
			burstDegrees = 46,
			sustainDegrees = 24,
			response = 10.0,
		},

		{
			name = "Bip01-Spine2_52",
			role = "front",
			burstDegrees = 16,
			sustainDegrees = 8,
			response = 12.0,
		},

		{
			name = "Bip01-Spine_64",
			role = "rear",
			maxDegrees = 18,
			response = 4.2,
			followDelay = 0.12,
		},

		{
			name = "Bip01-Pelvis_71",
			role = "rear",
			maxDegrees = 7,
			response = 3.2,
			followDelay = 0.22,
		},
	},

	Spine1Only = {
		{ name = "Bip01-Spine1_53", role = "front", burstDegrees = 70, sustainDegrees = 70, response = 9.0 },
	},

	Spine1PlusSpine2 = {
		{ name = "Bip01-Spine1_53", role = "front", burstDegrees = 70, sustainDegrees = 70, response = 9.0 },
		{ name = "Bip01-Spine2_52", role = "front", burstDegrees = 21, sustainDegrees = 21, response = 11.0 },
	},
}
local TORSO_TWIST_PROFILE_ORDER = {
	"FollowThrough",
	"Spine1Only",
	"Spine1PlusSpine2",
}

local TORSO_TWIST_AXIS = "Z"
local TORSO_TWIST_SIGN = -1
local FORCE_TORSO_TWIST_AXIS = nil
local FORCE_TORSO_TWIST_SIGN = nil
local MAX_TORSO_TWIST_DEGREES = 70
local TEST_TORSO_TWIST_DEGREES = 85
local TORSO_TWIST_RESPONSE = 9
local TORSO_TWIST_RETURN_RESPONSE = 6
local AUTO_CALIBRATE_TEST_DEGREES = 45
local AUTO_CALIBRATE_EPSILON = 0.01
local AXIS_TEST_KEY_X = Enum.KeyCode.Z
local AXIS_TEST_KEY_Y = Enum.KeyCode.X
local AXIS_TEST_KEY_Z = Enum.KeyCode.C
local SIGN_TEST_KEY = Enum.KeyCode.V
local PROFILE_CYCLE_KEY = Enum.KeyCode.B
local FORCE_VISIBLE_TWIST_KEY = Enum.KeyCode.H
local DEBUG_INTERVAL = 1.0
local RENDER_STEP_NAME = "DragonTorsoTwist_LateApply"
local PROBE_FOLDER_NAME = "DragonTorsoTwistProbes"

local player = Players.LocalPlayer
local dragon = nil
local root = nil
local entries = {}
local entryByName = {}
local applied = {}
local probes = {}
local torsoIntent = 0
local turnHoldTime = 0
local lastTurnSign = 0
local debugAccumulator = 0
local autoCalibrated = not AUTO_CALIBRATE_TORSO_TWIST
local autoCalibrating = false
local initialized = false
local heartbeatConnection = nil
local preAnimationConnection = nil
local lateRenderConnection = nil
local lateAppliedThisFrame = false

local lastState = "Grounded"
local lastLocalManualTurn = 0
local lastServerTurnInput = 0
local lastServerUTurnIntent = 0
local lastFinalTurn = 0
local lastTestMode = false
local lastMounted = false
local lastFrontScale = 1
local lastRearScale = 0

local function safeNumber(value, fallback)
	if typeof(value) ~= "number" or value ~= value then
		return fallback or 0
	end

	return value
end

local function isNearZero(value)
	return math.abs(value) < 0.001
end

local function smooth01(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function axisRotation(axisName, amount)
	if axisName == "X" then
		return CFrame.Angles(amount, 0, 0)
	elseif axisName == "Y" then
		return CFrame.Angles(0, amount, 0)
	end

	return CFrame.Angles(0, 0, amount)
end

local function removeAppliedAdditives()
	for bone, additive in pairs(applied) do
		if bone and bone.Parent then
			bone.Transform = bone.Transform * additive:Inverse()
		end
	end

	table.clear(applied)
	lateAppliedThisFrame = false
end

local function applyAdditiveLate(bone, additive)
	bone.Transform = bone.Transform * additive
	applied[bone] = additive
end

local function clearAdditives()
	removeAppliedAdditives()
end

local function findBone(name)
	if not dragon then
		return nil
	end

	for _, descendant in ipairs(dragon:GetDescendants()) do
		if descendant:IsA("Bone") and descendant.Name == name then
			return descendant
		end
	end

	return nil
end

local function signedYawBetween(rootPart, fromDir, toDir)
	local fromLocal = rootPart.CFrame:VectorToObjectSpace(fromDir)
	local toLocal = rootPart.CFrame:VectorToObjectSpace(toDir)

	local fromFlat = Vector3.new(fromLocal.X, 0, fromLocal.Z)
	local toFlat = Vector3.new(toLocal.X, 0, toLocal.Z)

	if fromFlat.Magnitude < 0.01 or toFlat.Magnitude < 0.01 then
		return 0
	end

	fromFlat = fromFlat.Unit
	toFlat = toFlat.Unit

	local crossY = fromFlat:Cross(toFlat).Y
	local dot = math.clamp(fromFlat:Dot(toFlat), -1, 1)

	return math.atan2(crossY, dot)
end

local function getMountedState()
	return tostring(player:GetAttribute("DragonMountedState") or "Grounded")
end

local function isMountedState(state)
	return state ~= nil and state ~= "" and state ~= "Grounded"
end

local function getManualTurn()
	local left = UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0
	local right = UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0
	return right - left
end

local function applyForcedAxisIfNeeded()
	if FORCE_TORSO_TWIST_AXIS then
		TORSO_TWIST_AXIS = FORCE_TORSO_TWIST_AXIS
	end

	if FORCE_TORSO_TWIST_SIGN then
		TORSO_TWIST_SIGN = FORCE_TORSO_TWIST_SIGN
	end
end

local function rebuildEntries()
	entries = {}
	entryByName = {}
	clearAdditives()

	local profile = TORSO_TWIST_PROFILES[TORSO_TWIST_PROFILE]
	if not profile then
		warn("[DragonTorsoTwist] Missing profile: " .. tostring(TORSO_TWIST_PROFILE))
		TORSO_TWIST_PROFILE = "FollowThrough"
		profile = TORSO_TWIST_PROFILES[TORSO_TWIST_PROFILE]
	end

	for _, config in ipairs(profile) do
		local bone = findBone(config.name)
		if bone then
			local entry = {
				bone = bone,
				name = config.name,
				role = config.role or "front",
				burstDegrees = config.burstDegrees or 0,
				sustainDegrees = config.sustainDegrees or config.burstDegrees or 0,
				maxDegrees = config.maxDegrees or config.burstDegrees or 0,
				response = config.response or 8,
				followDelay = config.followDelay or 0,
				current = 0,
			}
			table.insert(entries, entry)
			entryByName[config.name] = entry
		else
			warn("[DragonTorsoTwist] Missing bone: " .. config.name)
		end
	end
end

local function createProbe(name, color)
	local folder = Workspace:FindFirstChild(PROBE_FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = PROBE_FOLDER_NAME
		folder.Parent = Workspace
	end

	local probe = folder:FindFirstChild(name)
	if not probe then
		probe = Instance.new("Part")
		probe.Name = name
		probe.Shape = Enum.PartType.Ball
		probe.Size = Vector3.new(0.45, 0.45, 0.45)
		probe.Material = Enum.Material.Neon
		probe.Anchored = true
		probe.CanCollide = false
		probe.CanTouch = false
		probe.CanQuery = false
		probe.Parent = folder
	end

	probe.Color = color
	return probe
end

local function setupProbes()
	if not SHOW_TORSO_TWIST_PROBES then
		return
	end

	probes.Spine1 = createProbe("Spine1Probe", Color3.fromRGB(255, 45, 45))
	probes.Spine2 = createProbe("Spine2Probe", Color3.fromRGB(255, 145, 35))
	probes.Spine64 = createProbe("Spine64Probe", Color3.fromRGB(60, 135, 255))
	probes.Pelvis = createProbe("PelvisProbe", Color3.fromRGB(180, 85, 255))
	probes.Neck = createProbe("NeckProbe", Color3.fromRGB(255, 240, 60))
end

local function updateProbes()
	if not SHOW_TORSO_TWIST_PROBES then
		return
	end

	local spine1Bone = findBone("Bip01-Spine1_53")
	local spine2Bone = findBone("Bip01-Spine2_52")
	local spine64Bone = findBone("Bip01-Spine_64")
	local pelvisBone = findBone("Bip01-Pelvis_71")
	local neckBone = findBone("Bip01-Neck_32")

	if probes.Spine1 and spine1Bone then
		probes.Spine1.Position = spine1Bone.TransformedWorldCFrame.Position
	end
	if probes.Spine2 and spine2Bone then
		probes.Spine2.Position = spine2Bone.TransformedWorldCFrame.Position
	end
	if probes.Spine64 and spine64Bone then
		probes.Spine64.Position = spine64Bone.TransformedWorldCFrame.Position
	end
	if probes.Pelvis and pelvisBone then
		probes.Pelvis.Position = pelvisBone.TransformedWorldCFrame.Position
	end
	if probes.Neck and neckBone then
		probes.Neck.Position = neckBone.TransformedWorldCFrame.Position
	end
end

local function cycleProfile()
	local currentIndex = table.find(TORSO_TWIST_PROFILE_ORDER, TORSO_TWIST_PROFILE) or 1
	local nextIndex = currentIndex + 1
	if nextIndex > #TORSO_TWIST_PROFILE_ORDER then
		nextIndex = 1
	end

	TORSO_TWIST_PROFILE = TORSO_TWIST_PROFILE_ORDER[nextIndex]
	turnHoldTime = 0
	lastTurnSign = 0
	removeAppliedAdditives()
	rebuildEntries()
	--print('[DragonTorsoTwist][Profile] " .. TORSO_TWIST_PROFILE)
end

local function setManualAxis(axisName)
	TORSO_TWIST_AXIS = axisName
	print(("[DragonTorsoTwist][ManualAxis] axis=%s sign=%d"):format(TORSO_TWIST_AXIS, TORSO_TWIST_SIGN))
end

local function invertManualSign()
	TORSO_TWIST_SIGN *= -1
	print(("[DragonTorsoTwist][ManualAxis] axis=%s sign=%d"):format(TORSO_TWIST_AXIS, TORSO_TWIST_SIGN))
end

local function onInputBegan(input, gameProcessed)
	if gameProcessed and UserInputService:GetFocusedTextBox() then
		return
	end

	if MANUAL_AXIS_TEST_ENABLED then
		if input.KeyCode == AXIS_TEST_KEY_X then
			setManualAxis("X")
		elseif input.KeyCode == AXIS_TEST_KEY_Y then
			setManualAxis("Y")
		elseif input.KeyCode == AXIS_TEST_KEY_Z then
			setManualAxis("Z")
		elseif input.KeyCode == SIGN_TEST_KEY then
			invertManualSign()
		end
	end

	if input.KeyCode == PROFILE_CYCLE_KEY then
		cycleProfile()
	end
end

local function connectPreAnimationCleanup()
	if preAnimationConnection then
		preAnimationConnection:Disconnect()
		preAnimationConnection = nil
	end

	if RunService.PreAnimation then
		preAnimationConnection = RunService.PreAnimation:Connect(function()
			removeAppliedAdditives()
		end)
	else
		preAnimationConnection = RunService.Stepped:Connect(function()
			removeAppliedAdditives()
		end)
	end
end

local function tryInitialize()
	dragon = Workspace:FindFirstChild(DRAGON_NAME)
	if not dragon then
		return false
	end

	root = dragon:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end

	rebuildEntries()
	setupProbes()
	applyForcedAxisIfNeeded()
	connectPreAnimationCleanup()
	print(("[DragonTorsoTwist] Ready. Late apply axis=%s sign=%d profile=%s probes=%s cleanup=PreAnimation"):format(
		TORSO_TWIST_AXIS,
		TORSO_TWIST_SIGN,
		TORSO_TWIST_PROFILE,
		tostring(SHOW_TORSO_TWIST_PROBES)
	))
	return true
end

local function runAutoCalibrate()
	if autoCalibrating or autoCalibrated or not root then
		return
	end

	local testBone = findBone("Bip01-Spine1_53")
	local measureBone = findBone("Bip01-Neck_32")
	if not testBone or not measureBone then
		warn("[DragonTorsoTwist][AutoCalib] Missing Bip01-Spine1_53 or Bip01-Neck_32.")
		autoCalibrated = true
		applyForcedAxisIfNeeded()
		return
	end

	autoCalibrating = true
	local tests = {
		{ axis = "X", sign = 1 },
		{ axis = "X", sign = -1 },
		{ axis = "Y", sign = 1 },
		{ axis = "Y", sign = -1 },
		{ axis = "Z", sign = 1 },
		{ axis = "Z", sign = -1 },
	}

	task.spawn(function()
		local bestAxis = TORSO_TWIST_AXIS
		local bestSign = TORSO_TWIST_SIGN
		local bestScore = -math.huge

		--print('[DragonTorsoTwist][AutoCalib] testBone=Bip01-Spine1_53 measureBone=Bip01-Neck_32")
		RunService.Heartbeat:Wait()

		for _, test in ipairs(tests) do
			clearAdditives()
			RunService.Heartbeat:Wait()

			local beforeVector = measureBone.TransformedWorldCFrame.Position - testBone.TransformedWorldCFrame.Position
			local beforeDir = beforeVector.Magnitude > 0.01 and beforeVector.Unit or root.CFrame.LookVector

			applyAdditiveLate(testBone, axisRotation(test.axis, math.rad(AUTO_CALIBRATE_TEST_DEGREES) * test.sign))
			RunService.Heartbeat:Wait()

			local afterVector = measureBone.TransformedWorldCFrame.Position - testBone.TransformedWorldCFrame.Position
			local afterDir = afterVector.Magnitude > 0.01 and afterVector.Unit or beforeDir
			local yawDelta = signedYawBetween(root, beforeDir, afterDir)
			local score = yawDelta

			print(("[DragonTorsoTwist][AutoCalib] axis=%s sign=%d yawDelta=%.4f"):format(
				test.axis,
				test.sign,
				yawDelta
			))

			if score > bestScore then
				bestScore = score
				bestAxis = test.axis
				bestSign = test.sign
			end
		end

		clearAdditives()
		TORSO_TWIST_AXIS = bestAxis
		TORSO_TWIST_SIGN = bestSign
		applyForcedAxisIfNeeded()
		autoCalibrated = true
		autoCalibrating = false

		print(("[DragonTorsoTwist][AutoCalib] BEST axis=%s sign=%d yawDelta=%.4f forcedAxis=%s forcedSign=%s"):format(
			TORSO_TWIST_AXIS,
			TORSO_TWIST_SIGN,
			bestScore,
			tostring(FORCE_TORSO_TWIST_AXIS),
			tostring(FORCE_TORSO_TWIST_SIGN)
		))

		if math.abs(bestScore) < AUTO_CALIBRATE_EPSILON then
			warn("[DragonTorsoTwist][DIAG] Spine1_53 rotation does not visibly affect Neck_32 direction. Check skin/axis.")
		end
	end)
end

local function updateTurnHoldTime(dt)
	local absTurn = math.abs(lastFinalTurn)
	local currentSign = absTurn > 0.08 and math.sign(lastFinalTurn) or 0

	if currentSign ~= 0 then
		if currentSign ~= lastTurnSign then
			turnHoldTime = 0
		else
			turnHoldTime += dt
		end
	else
		turnHoldTime = 0
	end

	lastTurnSign = currentSign
	local hold01 = smooth01(turnHoldTime / 0.45)
	lastFrontScale = 1 - hold01
	lastRearScale = smooth01(math.max(0, turnHoldTime - 0.10) / 0.45)
end

local function updateTorsoValues(dt)
	lastState = getMountedState()
	lastMounted = isMountedState(lastState)
	lastLocalManualTurn = getManualTurn()
	lastServerTurnInput = safeNumber(player:GetAttribute("DragonTurnInput"), 0)
	lastServerUTurnIntent = safeNumber(player:GetAttribute("DragonUTurnIntent"), 0)
	lastFinalTurn = lastLocalManualTurn
	lastTestMode = UserInputService:IsKeyDown(FORCE_VISIBLE_TWIST_KEY)

	if math.abs(lastServerUTurnIntent) > 0.05 then
		lastFinalTurn = lastServerUTurnIntent
	elseif math.abs(lastServerTurnInput) > math.abs(lastFinalTurn) then
		lastFinalTurn = lastServerTurnInput
	end

	if not lastMounted then
		lastFinalTurn = 0
	end

	if lastTestMode then
		lastFinalTurn = 1
	end

	updateTurnHoldTime(dt)

	local targetIntent = lastMounted and lastFinalTurn or 0
	if lastTestMode then
		targetIntent = 1
	end

	local response = math.abs(targetIntent) > 0.05 and TORSO_TWIST_RESPONSE or TORSO_TWIST_RETURN_RESPONSE
	torsoIntent += (targetIntent - torsoIntent) * (1 - math.exp(-response * dt))

	if autoCalibrating then
		return
	end

	for _, entry in ipairs(entries) do
		local targetDegrees = 0

		if lastTestMode then
			if entry.name == "Bip01-Spine1_53" then
				targetDegrees = TEST_TORSO_TWIST_DEGREES
			elseif entry.name == "Bip01-Spine2_52" then
				targetDegrees = TEST_TORSO_TWIST_DEGREES * 0.25
			else
				targetDegrees = 0
			end
		else
			if entry.role == "front" then
				local dynamicDegrees = entry.sustainDegrees + (entry.burstDegrees - entry.sustainDegrees) * lastFrontScale
				targetDegrees = dynamicDegrees
			elseif entry.role == "rear" then
				local delayedRearScale = smooth01(math.max(0, turnHoldTime - entry.followDelay) / 0.45)
				targetDegrees = entry.maxDegrees * delayedRearScale
			end
		end

		local target = lastFinalTurn * math.rad(targetDegrees)
		entry.current += (target - entry.current) * (1 - math.exp(-entry.response * dt))
	end
end

local function applyTorsoAdditives()
	if not initialized or autoCalibrating then
		return
	end

	for _, entry in ipairs(entries) do
		local amount = entry.current
		if not isNearZero(amount) then
			local additive = axisRotation(TORSO_TWIST_AXIS, amount * TORSO_TWIST_SIGN)
			applyAdditiveLate(entry.bone, additive)
		end
	end
end

local function debugTorso(dt)
	debugAccumulator += dt
	if not TORSO_TWIST_DEBUG or debugAccumulator < DEBUG_INTERVAL then
		return
	end

	debugAccumulator = 0
	local spine1 = entryByName["Bip01-Spine1_53"]
	local spine2 = entryByName["Bip01-Spine2_52"]
	local spine64 = entryByName["Bip01-Spine_64"]
	local pelvis = entryByName["Bip01-Pelvis_71"]
	local appliedSpine1 = spine1 and applied[spine1.bone] ~= nil
	print(("[DragonTorsoTwist] state=%s profile=%s finalTurn=%.2f hold=%.2f frontScale=%.2f rearScale=%.2f spine1=%.1f spine2=%.1f spine64=%.1f pelvis=%.1f appliedSpine1=%s test=%s"):format(
		lastState,
		TORSO_TWIST_PROFILE,
		lastFinalTurn,
		turnHoldTime,
		lastFrontScale,
		lastRearScale,
		math.deg(spine1 and spine1.current or 0),
		math.deg(spine2 and spine2.current or 0),
		math.deg(spine64 and spine64.current or 0),
		math.deg(pelvis and pelvis.current or 0),
		tostring(appliedSpine1),
		tostring(lastTestMode)
	))

	if DEBUG_APPLY_TRANSFORM then
		print(("[DragonTorsoTwist][Apply] state=%s profile=%s spine1Current=%.1f applied=%s transform=%s"):format(
			lastState,
			TORSO_TWIST_PROFILE,
			math.deg(spine1 and spine1.current or 0),
			tostring(appliedSpine1),
			tostring(spine1 and spine1.bone.Transform)
		))
	end

	if DEBUG_WALK_SPINE_ANIMATION and lastState == "GroundWalk" and math.abs(lastFinalTurn) < 0.05 then
		local spine1Bone = findBone("Bip01-Spine1_53")
		local spine2Bone = findBone("Bip01-Spine2_52")
		print(("[DragonTorsoTwist][WalkAnim] spine1Transform=%s spine2Transform=%s"):format(
			tostring(spine1Bone and spine1Bone.Transform),
			tostring(spine2Bone and spine2Bone.Transform)
		))
	end
end

local lateRenderUpdate
local function heartbeatUpdate(dt)
	if not initialized then
		initialized = tryInitialize()
		return
	end

	if AUTO_CALIBRATE_TORSO_TWIST and not autoCalibrated and not autoCalibrating then
		runAutoCalibrate()
	end

	updateTorsoValues(dt)
	if USE_HEARTBEAT_LATE_APPLY_FALLBACK then
		task.defer(function()
			if initialized and not lateAppliedThisFrame then
				lateRenderUpdate(dt)
			end
		end)
	end
end

lateRenderUpdate = function(dt)
	if not initialized or lateAppliedThisFrame then
		return
	end

	lateAppliedThisFrame = true
	applyTorsoAdditives()
	updateProbes()
	debugTorso(dt)
end

local function shutdownTorsoTwist()
	removeAppliedAdditives()
	pcall(function()
		RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
	end)
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	if preAnimationConnection then
		preAnimationConnection:Disconnect()
		preAnimationConnection = nil
	end
	if lateRenderConnection then
		lateRenderConnection:Disconnect()
		lateRenderConnection = nil
	end
end

if not ENABLE_DRAGON_TORSO_TWIST then
	return
end

UserInputService.InputBegan:Connect(onInputBegan)
script.Destroying:Connect(shutdownTorsoTwist)

pcall(function()
	RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
end)

heartbeatConnection = RunService.Heartbeat:Connect(heartbeatUpdate)
if RunService.PreRender then
	lateRenderConnection = RunService.PreRender:Connect(lateRenderUpdate)
else
	lateRenderConnection = RunService.RenderStepped:Connect(lateRenderUpdate)
end
RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Last.Value + 100, function(dt)
	lateRenderUpdate(dt)
end)
