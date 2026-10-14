-- DragonTorsoTwist.client.lua
-- Procedural serpentine body motion for the dragon.
-- A/D creates a delayed body wave: chest -> torso -> pelvis -> tail.
-- DragonMouseAim keeps ownership of head/neck. This script does NOT touch Bip01-Neck_32 or Bip01-Head_8.
-- v3: shoulder-safe profile. Front-chest influence is reduced to avoid lifting front legs/head during W+D/A.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local DRAGON_NAME = "DragonModel"
local ENABLE_DRAGON_TORSO_TWIST = false
local TORSO_TWIST_DEBUG = false
local SHOW_TORSO_TWIST_PROBES = false
local MANUAL_AXIS_TEST_ENABLED = false

local RENDER_STEP_NAME = "DragonSerpentineGroundTurn_PrePhase4"
local RENDER_PRIORITY = Enum.RenderPriority.Last.Value - 20
local PROBE_FOLDER_NAME = "DragonTorsoTwistProbes"

local TORSO_TWIST_AXIS = "Z"
local TORSO_TWIST_SIGN = -1
local FRONT_ROLE_SIGN_MULTIPLIER = -1
local REAR_ROLE_SIGN_MULTIPLIER = 1
local TAIL_ROLE_SIGN_MULTIPLIER = 1

-- Shoulder-safe profile:
-- Spine2_52 is close to shoulders/neck/front legs, so keep it subtle.
-- The visible serpentine is now carried more by Spine1 -> Spine_64 -> pelvis -> tail.
local SERPENTINE_PROFILE = {
	{ name = "Bip01-Spine2_52", role = "front", delay = 0.00, degrees = 4, response = 5.8, idlePhase = 0.2 },
	{ name = "Bip01-Spine1_53", role = "front", delay = 0.12, degrees = 20, response = 5.6, idlePhase = 0.9 },
	{ name = "Bip01-Spine_64", role = "rear", delay = 0.26, degrees = 25, response = 4.8, idlePhase = 1.6 },
	{ name = "Bip01-Pelvis_71", role = "rear", delay = 0.42, degrees = 14, response = 3.8, idlePhase = 2.3 },
	{ name = "tail_Bone001_70", role = "tail", delay = 0.58, degrees = 18, response = 3.3, idlePhase = 3.0 },
	{ name = "tail_Bone002_69", role = "tail", delay = 0.76, degrees = 24, response = 2.8, idlePhase = 3.8 },
}

local HISTORY_SECONDS = 1.45
local TURN_ATTACK_RESPONSE = 3.8
local TURN_RELEASE_RESPONSE = 4.8
local BODY_RETURN_RESPONSE = 6.0
local IDLE_WAVE_DEGREES = 1.2
local IDLE_WAVE_SPEED = 1.35
local IDLE_WAVE_WHEN_TURNING_SCALE = 0.12
local IDLE_WAVE_WHEN_STILL_SCALE = 0.45
local AIM_TORSO_INFLUENCE_WHEN_TURNING = 0.05
local AIM_TORSO_INFLUENCE_WHEN_NOT_TURNING = 0.18
local MAX_AIM_TORSO_YAW_DEGREES = 55
local DEBUG_INTERVAL = 1.0

local AXIS_TEST_KEY_X = Enum.KeyCode.Z
local AXIS_TEST_KEY_Y = Enum.KeyCode.X
local AXIS_TEST_KEY_Z = Enum.KeyCode.C
local SIGN_TEST_KEY = Enum.KeyCode.V
local FORCE_VISIBLE_TWIST_KEY = Enum.KeyCode.H

local player = Players.LocalPlayer
local dragon = nil
local root = nil
local entries = {}
local entryByName = {}
local applied = {}
local probes = {}
local turnHistory = {}
local initialized = false
local heartbeatConnection = nil
local preAnimationConnection = nil
local debugAccumulator = 0
local lastRightMouseHeld = false
local lastState = "Grounded"
local lastMounted = false
local lastManualTurn = 0
local lastAimTurn = 0
local lastRawTurn = 0
local lastFinalTurn = 0
local smoothedTurn = 0
local lastTestMode = false

local function safeNumber(value, fallback)
	if typeof(value) ~= "number" or value ~= value then
		return fallback or 0
	end
	return value
end

local function expAlpha(response, dt)
	return 1 - math.exp(-response * dt)
end

local function isNearZero(value)
	return math.abs(value) < 0.001
end

local function axisRotation(axisName, amount)
	if axisName == "X" then
		return CFrame.Angles(amount, 0, 0)
	elseif axisName == "Y" then
		return CFrame.Angles(0, amount, 0)
	end
	return CFrame.Angles(0, 0, amount)
end

local function getRoleSignMultiplier(role)
	if role == "front" then
		return FRONT_ROLE_SIGN_MULTIPLIER
	elseif role == "tail" then
		return TAIL_ROLE_SIGN_MULTIPLIER
	end
	return REAR_ROLE_SIGN_MULTIPLIER
end

local function removeAppliedAdditives()
	for bone, additive in pairs(applied) do
		if bone and bone.Parent then
			bone.Transform = bone.Transform * additive:Inverse()
		end
	end
	table.clear(applied)
end

local function applyAdditiveLate(bone, additive)
	bone.Transform = bone.Transform * additive
	applied[bone] = additive
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

local function getAttributeVector(prefix)
	local x = player:GetAttribute(prefix .. "X")
	local y = player:GetAttribute(prefix .. "Y")
	local z = player:GetAttribute(prefix .. "Z")
	if typeof(x) == "number" and typeof(y) == "number" and typeof(z) == "number" then
		local v = Vector3.new(x, y, z)
		if v.Magnitude > 0.01 then
			return v.Unit
		end
	end
	return nil
end

local function getAimTurn()
	if not root or not lastRightMouseHeld then
		return 0
	end
	local aimDirection = getAttributeVector("DragonAimDirection")
	if not aimDirection then
		return 0
	end
	local localDir = root.CFrame:VectorToObjectSpace(aimDirection)
	local yaw = math.atan2(localDir.X, -localDir.Z)
	return math.clamp(yaw / math.rad(MAX_AIM_TORSO_YAW_DEGREES), -1, 1)
end

local function isGroundMountedState(state)
	return state == "MountedGround" or state == "GroundWalk" or state == "GroundTrot" or state == "GroundBack"
end

local function getStateScale(state)
	if not isMountedState(state) then
		return 0
	end
	if isGroundMountedState(state) then
		return 1
	end
	return 0.24
end

local function pushTurnHistory(now, value)
	table.insert(turnHistory, { t = now, v = value })
	local cutoff = now - HISTORY_SECONDS
	while #turnHistory > 2 and turnHistory[1].t < cutoff do
		table.remove(turnHistory, 1)
	end
end

local function sampleTurnHistory(delay)
	if #turnHistory == 0 then
		return lastFinalTurn
	end
	local targetTime = os.clock() - delay
	local previous = turnHistory[1]
	for i = 2, #turnHistory do
		local current = turnHistory[i]
		if current.t >= targetTime then
			local span = math.max(current.t - previous.t, 1 / 240)
			local alpha = math.clamp((targetTime - previous.t) / span, 0, 1)
			return previous.v + (current.v - previous.v) * alpha
		end
		previous = current
	end
	return turnHistory[#turnHistory].v
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
	probes.Spine2 = createProbe("Spine2Probe", Color3.fromRGB(255, 145, 35))
	probes.Spine1 = createProbe("Spine1Probe", Color3.fromRGB(255, 45, 45))
	probes.Spine64 = createProbe("Spine64Probe", Color3.fromRGB(60, 135, 255))
	probes.Pelvis = createProbe("PelvisProbe", Color3.fromRGB(180, 85, 255))
	probes.Tail1 = createProbe("Tail1Probe", Color3.fromRGB(60, 255, 160))
	probes.Tail2 = createProbe("Tail2Probe", Color3.fromRGB(60, 255, 220))
end

local function updateProbes()
	if not SHOW_TORSO_TWIST_PROBES then
		return
	end
	local map = {
		Spine2 = "Bip01-Spine2_52",
		Spine1 = "Bip01-Spine1_53",
		Spine64 = "Bip01-Spine_64",
		Pelvis = "Bip01-Pelvis_71",
		Tail1 = "tail_Bone001_70",
		Tail2 = "tail_Bone002_69",
	}
	for probeName, boneName in pairs(map) do
		local probe = probes[probeName]
		local bone = findBone(boneName)
		if probe and bone then
			probe.Position = bone.TransformedWorldCFrame.Position
		end
	end
end

local function rebuildEntries()
	entries = {}
	entryByName = {}
	removeAppliedAdditives()
	for _, config in ipairs(SERPENTINE_PROFILE) do
		local bone = findBone(config.name)
		if bone then
			local entry = {
				bone = bone,
				name = config.name,
				role = config.role,
				delay = config.delay or 0,
				degrees = config.degrees or 0,
				response = config.response or 8,
				idlePhase = config.idlePhase or 0,
				current = 0,
			}
			table.insert(entries, entry)
			entryByName[config.name] = entry
		else
			print("[DragonTorsoTwist] Optional/missing bone skipped: " .. config.name)
		end
	end
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
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		lastRightMouseHeld = true
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
	if input.KeyCode == FORCE_VISIBLE_TWIST_KEY then
		lastTestMode = true
	end
end

local function onInputEnded(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		lastRightMouseHeld = false
	elseif input.KeyCode == FORCE_VISIBLE_TWIST_KEY then
		lastTestMode = false
	end
end

local function connectPreAnimationCleanup()
	if preAnimationConnection then
		preAnimationConnection:Disconnect()
		preAnimationConnection = nil
	end
	if RunService.PreAnimation then
		preAnimationConnection = RunService.PreAnimation:Connect(removeAppliedAdditives)
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
	connectPreAnimationCleanup()
	print(("[DragonTorsoTwist] Serpentine v3 shoulder-safe ready. axis=%s sign=%d entries=%d manualKeys=%s"):format(
		TORSO_TWIST_AXIS,
		TORSO_TWIST_SIGN,
		#entries,
		tostring(MANUAL_AXIS_TEST_ENABLED)
	))
	print("[DragonTorsoTwist] Shoulder lift reduced: Spine2 subtle, wave carried by torso/pelvis/tail. Head/neck stay DragonMouseAim-owned.")
	return true
end

local function updateSerpentineValues(dt)
	lastState = getMountedState()
	lastMounted = isMountedState(lastState)
	lastManualTurn = getManualTurn()
	lastAimTurn = getAimTurn()

	local serverTurnInput = safeNumber(player:GetAttribute("DragonTurnInput"), 0)
	local serverUTurnIntent = safeNumber(player:GetAttribute("DragonUTurnIntent"), 0)
	local manualTurn = lastManualTurn
	if math.abs(serverUTurnIntent) > 0.05 then
		manualTurn = serverUTurnIntent
	elseif math.abs(serverTurnInput) > math.abs(manualTurn) then
		manualTurn = serverTurnInput
	end

	local aimInfluence = math.abs(manualTurn) > 0.05 and AIM_TORSO_INFLUENCE_WHEN_TURNING or AIM_TORSO_INFLUENCE_WHEN_NOT_TURNING
	lastRawTurn = math.clamp(manualTurn + lastAimTurn * aimInfluence, -1, 1)
	if not lastMounted then
		lastRawTurn = 0
	end
	if lastTestMode then
		lastRawTurn = 1
	end

	local response = math.abs(lastRawTurn) > math.abs(smoothedTurn) and TURN_ATTACK_RESPONSE or TURN_RELEASE_RESPONSE
	smoothedTurn += (lastRawTurn - smoothedTurn) * expAlpha(response, dt)
	lastFinalTurn = math.clamp(smoothedTurn, -1, 1)
	pushTurnHistory(os.clock(), lastFinalTurn)

	local stateScale = getStateScale(lastState)
	local turningAmount = math.abs(lastFinalTurn)
	local idleScale = turningAmount > 0.08 and IDLE_WAVE_WHEN_TURNING_SCALE or IDLE_WAVE_WHEN_STILL_SCALE
	local now = os.clock()

	for _, entry in ipairs(entries) do
		local delayedTurn = sampleTurnHistory(entry.delay)
		local bodyTarget = delayedTurn * math.rad(entry.degrees) * stateScale
		local idleWave = math.sin(now * IDLE_WAVE_SPEED - entry.idlePhase) * math.rad(IDLE_WAVE_DEGREES) * idleScale * stateScale
		local target = bodyTarget + idleWave
		local boneResponse = stateScale > 0 and entry.response or BODY_RETURN_RESPONSE
		entry.current += (target - entry.current) * expAlpha(boneResponse, dt)
	end
end

local function applySerpentineAdditives()
	if not initialized then
		return
	end
	for _, entry in ipairs(entries) do
		local amount = entry.current
		if not isNearZero(amount) then
			local multiplier = getRoleSignMultiplier(entry.role)
			local additive = axisRotation(TORSO_TWIST_AXIS, amount * TORSO_TWIST_SIGN * multiplier)
			applyAdditiveLate(entry.bone, additive)
		end
	end
end

local function debugSerpentine(dt)
	debugAccumulator += dt
	if not TORSO_TWIST_DEBUG or debugAccumulator < DEBUG_INTERVAL then
		return
	end
	debugAccumulator = 0
	print(("[DragonTorsoTwist] state=%s raw=%.2f smooth=%.2f manual=%.2f aim=%.2f entries=%d"):format(
		lastState,
		lastRawTurn,
		lastFinalTurn,
		lastManualTurn,
		lastAimTurn,
		#entries
	))
end

local function heartbeatUpdate(dt)
	if not initialized then
		initialized = tryInitialize()
		return
	end
	updateSerpentineValues(math.clamp(dt, 1 / 240, 1 / 15))
end

local function lateRenderUpdate(dt)
	if not initialized then
		return
	end
	applySerpentineAdditives()
	updateProbes()
	debugSerpentine(dt)
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
end

if not ENABLE_DRAGON_TORSO_TWIST then
	return
end

UserInputService.InputBegan:Connect(onInputBegan)
UserInputService.InputEnded:Connect(onInputEnded)
script.Destroying:Connect(shutdownTorsoTwist)

pcall(function()
	RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
end)
heartbeatConnection = RunService.Heartbeat:Connect(heartbeatUpdate)
RunService:BindToRenderStep(RENDER_STEP_NAME, RENDER_PRIORITY, lateRenderUpdate)
