local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LOG_LEVEL = 1
local DRAGON_NAME = "DragonModel"

local ENABLE_DRAGON_MOUSE_AIM = true
local SHOW_MOUSE_AIM_TARGET = false
local SHOW_MOUSE_AIM_DEBUG = false
local AUTO_CALIBRATE_ON_MOUNT = false
local ENABLE_BODY_AIM = false
local DEBUG_SHOW_AIM_TARGET_KEY = Enum.KeyCode.Y
local NECK_IK_CHAIN_ROOT_NAME = "Bip01-Neck_32"
local NECK_IK_END_EFFECTOR_NAME = "Bip01-Head_8"
local NECK_IK_OFFSET_PRESET_NAME = "Pitch90"
local BODY_AIM_YAW_AXIS = "Y"
local BODY_AIM_PITCH_AXIS = "X"

local AIM_TARGET_DISTANCE = 65
local AIM_TARGET_HEIGHT = 4
local MAX_AIM_YAW_DEGREES = 65
local MAX_AIM_PITCH_UP_DEGREES = 35
local MAX_AIM_PITCH_DOWN_DEGREES = 30
local MOUSE_AIM_RESPONSIVENESS = 18
local DEBUG_LOG_INTERVAL = 2
local CALIBRATION_TARGET_DISTANCE = 60
local CALIBRATION_TARGET_HEIGHT = 4
local CALIBRATION_SETTLE_FRAMES = 2

local MAX_BODY_YAW = math.rad(35)
local MAX_BODY_PITCH_UP = math.rad(18)
local MAX_BODY_PITCH_DOWN = math.rad(22)
local BODY_AIM_RESPONSIVENESS = 10

local ACTION_MOUSE_AIM_TOGGLE = "DragonMouseAim_Toggle"

local IK_OFFSET_PRESETS = {
	Identity = CFrame.identity,
	Yaw90 = CFrame.Angles(0, math.rad(90), 0),
	YawMinus90 = CFrame.Angles(0, math.rad(-90), 0),
	Yaw180 = CFrame.Angles(0, math.rad(180), 0),
	Pitch90 = CFrame.Angles(math.rad(90), 0, 0),
	PitchMinus90 = CFrame.Angles(math.rad(-90), 0, 0),
	Roll90 = CFrame.Angles(0, 0, math.rad(90)),
	RollMinus90 = CFrame.Angles(0, 0, math.rad(-90)),
	Yaw90Pitch90 = CFrame.Angles(math.rad(90), math.rad(90), 0),
	YawMinus90Pitch90 = CFrame.Angles(math.rad(90), math.rad(-90), 0),
}

local IK_OFFSET_PRESET_ORDER = {
	"Identity",
	"Yaw90",
	"YawMinus90",
	"Yaw180",
	"Pitch90",
	"PitchMinus90",
	"Roll90",
	"RollMinus90",
	"Yaw90Pitch90",
	"YawMinus90Pitch90",
}

local BODY_AIM_BONES = {
	{ name = "Bip01-Spine_64", yawWeight = 0.10, pitchWeight = 0.10 },
	{ name = "Bip01-Spine1_53", yawWeight = 0.15, pitchWeight = 0.15 },
	{ name = "Bip01-Spine2_52", yawWeight = 0.20, pitchWeight = 0.20 },
}

local player = Players.LocalPlayer
local warned = {}
local mouseAimUserEnabled = true
local mouseAimActive = false
local rightMouseAimHeld = false
local debugAimTargetVisible = SHOW_MOUSE_AIM_TARGET
local wasActive = false
local ready = false
local targetPart = nil
local neckIK = nil
local bodyEntries = {}
local bodyApplied = {}
local bodyAimYaw = 0
local bodyAimPitch = 0
local latestState = "Grounded"
local latestController = ""
local debugLogTimer = 0
local debugFolder = nil
local pendingIKEnable = false
local pendingIKEnableFrames = 0
local autoCalib = {
	active = false,
	done = false,
	index = 0,
	pendingName = nil,
	settleFrames = 0,
	bestName = "Identity",
	bestPreset = CFrame.identity,
	bestDot = -math.huge,
	bestRef = "none",
}

local function log(level, tag, message)
	if LOG_LEVEL >= level then
		print(tag .. " " .. message)
	end
end

local function warnOnce(key, message)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(message)
end

local function logOnce(key, message)
	if warned[key] then
		return
	end
	warned[key] = true
	log(1, "[DragonMouseAim]", message)
end

local function getDragon()
	return Workspace:FindFirstChild(DRAGON_NAME)
end

local function getRoot()
	local dragon = getDragon()
	local root = dragon and dragon:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function getMesh()
	local dragon = getDragon()
	local mesh = dragon and dragon:FindFirstChild("DragonMesh")
	if mesh and mesh:IsA("MeshPart") then
		return mesh
	end
	return nil
end

local function findBone(name)
	local mesh = getMesh()
	local bone = mesh and mesh:FindFirstChild(name, true)
	if bone and bone:IsA("Bone") then
		return bone
	end
	return nil
end

local function axisRotation(axis, amount)
	if axis == "X" then
		return CFrame.Angles(amount, 0, 0)
	elseif axis == "Y" then
		return CFrame.Angles(0, amount, 0)
	end
	return CFrame.Angles(0, 0, amount)
end

local function styleTarget(target)
	target.Shape = Enum.PartType.Ball
	target.Anchored = true
	target.CanCollide = false
	target.CanTouch = false
	target.CanQuery = false
	target.Size = Vector3.new(1.4, 1.4, 1.4)
	target.Material = Enum.Material.Neon
	target.Color = Color3.fromRGB(255, 255, 0)
end

local function getOrCreateTarget()
	local dragon = getDragon()
	if not dragon then
		return nil
	end

	local target = dragon:FindFirstChild("DragonMouseAimTarget_Client")
	if target and not target:IsA("BasePart") then
		target:Destroy()
		target = nil
	end

	if not target then
		target = Instance.new("Part")
		target.Name = "DragonMouseAimTarget_Client"
		target.Transparency = 1
		target.Parent = dragon
	end

	styleTarget(target)
	targetPart = target
	return target
end

local function getAnimator()
	local dragon = getDragon()
	local controller = dragon and dragon:FindFirstChildOfClass("AnimationController")
	return controller and controller:FindFirstChildOfClass("Animator") or nil
end

local function applyIKOffset(ik, presetName)
	local preset = IK_OFFSET_PRESETS[presetName] or CFrame.identity
	NECK_IK_OFFSET_PRESET_NAME = presetName
	pcall(function()
		ik.EndEffectorOffset = preset
	end)
	return preset
end

local function getOrCreateIK(target)
	local animator = getAnimator()
	if not animator then
		return nil
	end

	local oldIK = animator:FindFirstChild("DragonNeckLookIK")
	if oldIK and oldIK:IsA("IKControl") then
		oldIK.Enabled = false
	end

	local chainRoot = findBone(NECK_IK_CHAIN_ROOT_NAME)
	local head = findBone(NECK_IK_END_EFFECTOR_NAME)
	if not chainRoot then
		log(2, "[DragonMouseAim][WARN]", "missing bone " .. NECK_IK_CHAIN_ROOT_NAME)
		return nil
	end
	if not head then
		log(2, "[DragonMouseAim][WARN]", "missing bone " .. NECK_IK_END_EFFECTOR_NAME)
		return nil
	end

	local ik = animator:FindFirstChild("DragonMouseAimNeckIK")
	if ik and not ik:IsA("IKControl") then
		ik:Destroy()
		ik = nil
	end
	if not ik then
		local ok, created = pcall(Instance.new, "IKControl")
		if not ok or not created then
			warnOnce("create_ik", "[DragonMouseAim][WARN] IKControl could not be created")
			return nil
		end
		ik = created
		ik.Name = "DragonMouseAimNeckIK"
		ik.Parent = animator
	end

	ik.Type = Enum.IKControlType.LookAt
	ik.ChainRoot = chainRoot
	ik.EndEffector = head
	ik.Target = target
	ik.Weight = 1
	ik.SmoothTime = 0.04
	ik.Enabled = false
	pcall(function()
		ik.Priority = 10
	end)
	applyIKOffset(ik, NECK_IK_OFFSET_PRESET_NAME)

	logOnce("chain_config", "ChainRoot=" .. NECK_IK_CHAIN_ROOT_NAME .. " EndEffector=" .. NECK_IK_END_EFFECTOR_NAME)

	local chainCount = 0
	pcall(function()
		chainCount = ik:GetChainCount()
	end)
	if chainCount <= 0 then
		log(2, "[DragonMouseAim][WARN]", "IK chain invalid")
	end

	neckIK = ik
	return ik
end

local function initializeBodyEntries()
	if #bodyEntries > 0 then
		return
	end

	for _, config in ipairs(BODY_AIM_BONES) do
		local bone = findBone(config.name)
		if bone then
			table.insert(bodyEntries, {
				bone = bone,
				name = config.name,
				yawWeight = config.yawWeight,
				pitchWeight = config.pitchWeight,
			})
		else
			warnOnce("missing_body_" .. config.name, "[DragonMouseAim][WARN] missing bone " .. config.name)
		end
	end
end

local function initialize()
	if ready then
		return
	end

	local target = getOrCreateTarget()
	if not target then
		return
	end
	local ik = getOrCreateIK(target)
	if not ik then
		return
	end
	initializeBodyEntries()
	ready = true
	log(1, "[DragonMouseAim]", "Ready")
end

local function applyBodyTransform(bone, additive)
	local previous = bodyApplied[bone] or CFrame.identity
	local base = bone.Transform * previous:Inverse()
	bone.Transform = base * additive
	bodyApplied[bone] = additive
end

local function clearBodyTransforms()
	for bone, previous in pairs(bodyApplied) do
		if bone and bone.Parent then
			bone.Transform = bone.Transform * previous:Inverse()
		end
		bodyApplied[bone] = nil
	end
	bodyAimYaw = 0
	bodyAimPitch = 0
end

local function setActiveState(active)
	local changed = active ~= wasActive
	mouseAimActive = active
	player:SetAttribute("DragonMouseAimActive", active)
	wasActive = active
	return changed
end

local function getOrCreateDebugFolder()
	local dragon = getDragon()
	if not dragon then
		return nil
	end

	local folder = dragon:FindFirstChild("DragonMouseAimDebug_Client")
	if folder and not folder:IsA("Folder") then
		folder:Destroy()
		folder = nil
	end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "DragonMouseAimDebug_Client"
		folder.Parent = dragon
	end
	debugFolder = folder
	return folder
end

local function getOrCreateDebugPart(folder, name, color, size)
	local part = folder:FindFirstChild(name)
	if part and not part:IsA("BasePart") then
		part:Destroy()
		part = nil
	end
	if not part then
		part = Instance.new("Part")
		part.Name = name
		part.Shape = Enum.PartType.Ball
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Material = Enum.Material.Neon
		part.Parent = folder
	end
	part.Size = Vector3.new(size, size, size)
	part.Color = color
	return part
end

local function getOrCreateAttachment(part, name)
	local attachment = part:FindFirstChild(name)
	if attachment and not attachment:IsA("Attachment") then
		attachment:Destroy()
		attachment = nil
	end
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = name
		attachment.Parent = part
	end
	return attachment
end

local function getOrCreateBeam(folder, name, color, attachment0, attachment1)
	local beam = folder:FindFirstChild(name)
	if beam and not beam:IsA("Beam") then
		beam:Destroy()
		beam = nil
	end
	if not beam then
		beam = Instance.new("Beam")
		beam.Name = name
		beam.Width0 = 0.12
		beam.Width1 = 0.12
		beam.FaceCamera = true
		beam.Parent = folder
	end
	beam.Color = ColorSequence.new(color)
	beam.Attachment0 = attachment0
	beam.Attachment1 = attachment1
	return beam
end

local function positionDebugPart(part, bone, visible)
	if bone then
		part.Position = bone.TransformedWorldCFrame.Position
		part.Transparency = visible and 0.1 or 1
	else
		part.Transparency = 1
	end
end

local function updateMouseAimDebug(target, visible)
	if not SHOW_MOUSE_AIM_DEBUG then
		return
	end

	local folder = getOrCreateDebugFolder()
	if not folder then
		return
	end

	local head = findBone("Bip01-Head_8")
	local mouth = findBone("mouse_bone_3")
	local tongue = findBone("tongue_bone03_0")
	local headPart = getOrCreateDebugPart(folder, "Head_8_Debug_Red", Color3.fromRGB(255, 40, 40), 1.0)
	local mouthPart = getOrCreateDebugPart(folder, "mouse_bone_3_Debug_Blue", Color3.fromRGB(40, 120, 255), 0.8)
	local tonguePart = getOrCreateDebugPart(folder, "tongue_bone03_0_Debug_Green", Color3.fromRGB(40, 255, 100), 0.7)

	positionDebugPart(headPart, head, visible)
	positionDebugPart(mouthPart, mouth, visible)
	positionDebugPart(tonguePart, tongue, visible)

	if target then
		styleTarget(target)
	end

	local headAttachment = getOrCreateAttachment(headPart, "BeamAttachment")
	local mouthAttachment = getOrCreateAttachment(mouthPart, "BeamAttachment")
	local targetAttachment = target and getOrCreateAttachment(target, "DebugBeamAttachment") or nil
	local headToTarget = targetAttachment and getOrCreateBeam(folder, "HeadToTarget_Yellow_Beam", Color3.fromRGB(255, 255, 0), headAttachment, targetAttachment)
	local headToMouth = getOrCreateBeam(folder, "HeadToMouth_Blue_Beam", Color3.fromRGB(40, 120, 255), headAttachment, mouthAttachment)

	if headToTarget then
		headToTarget.Enabled = visible and head ~= nil and target ~= nil
	end
	headToMouth.Enabled = visible and head ~= nil and mouth ~= nil
end

local function getFaceForward()
	local head = findBone("Bip01-Head_8")
	local mouth = findBone("mouse_bone_3")
	local tongue = findBone("tongue_bone03_0")

	if not head then
		return nil, "none"
	end

	local headPos = head.TransformedWorldCFrame.Position

	if mouth then
		local mouthVector = mouth.TransformedWorldCFrame.Position - headPos
		if mouthVector.Magnitude > 0.05 then
			return mouthVector.Unit, "mouse_bone_3"
		end
	end

	if tongue then
		local tongueVector = tongue.TransformedWorldCFrame.Position - headPos
		if tongueVector.Magnitude > 0.05 then
			return tongueVector.Unit, "tongue_bone03_0"
		end
	end

	return head.TransformedWorldCFrame.LookVector, "HeadLookVector"
end

local function autoCalibrateHeadIK()
	if autoCalib.done or autoCalib.active then
		return
	end

	autoCalib.active = true
	autoCalib.index = 0
	autoCalib.pendingName = nil
	autoCalib.settleFrames = 0
	autoCalib.bestName = NECK_IK_OFFSET_PRESET_NAME
	autoCalib.bestPreset = IK_OFFSET_PRESETS[NECK_IK_OFFSET_PRESET_NAME] or CFrame.identity
	autoCalib.bestDot = -math.huge
	autoCalib.bestRef = "none"
	clearBodyTransforms()
end

local function updateAutoCalibration(target, ik, root, head)
	if not autoCalib.active then
		return false
	end

	if not target or not ik or not root or not head then
		autoCalib.active = false
		return false
	end

	local headPos = head.TransformedWorldCFrame.Position
	target.Position = headPos + root.CFrame.LookVector * CALIBRATION_TARGET_DISTANCE + Vector3.new(0, CALIBRATION_TARGET_HEIGHT, 0)

	if autoCalib.pendingName then
		autoCalib.settleFrames += 1
		if autoCalib.settleFrames < CALIBRATION_SETTLE_FRAMES then
			return true
		end

		local faceForward, refName = getFaceForward()
		local currentHead = findBone(NECK_IK_END_EFFECTOR_NAME)
		local dot = -math.huge
		if faceForward and currentHead then
			local toTarget = target.Position - currentHead.TransformedWorldCFrame.Position
			if toTarget.Magnitude > 0.05 then
				dot = faceForward:Dot(toTarget.Unit)
			end
		end

		log(2, "[DragonMouseAim][AutoCalib]", ("testing %s dot=%.3f"):format(autoCalib.pendingName, dot))
		if dot > autoCalib.bestDot then
			autoCalib.bestName = autoCalib.pendingName
			autoCalib.bestPreset = IK_OFFSET_PRESETS[autoCalib.pendingName] or CFrame.identity
			autoCalib.bestDot = dot
			autoCalib.bestRef = refName or "none"
		end

		autoCalib.pendingName = nil
		autoCalib.settleFrames = 0
	end

	autoCalib.index += 1
	local nextName = IK_OFFSET_PRESET_ORDER[autoCalib.index]
	if nextName then
		applyIKOffset(ik, nextName)
		autoCalib.pendingName = nextName
		autoCalib.settleFrames = 0
		return true
	end

	NECK_IK_OFFSET_PRESET_NAME = autoCalib.bestName
	pcall(function()
		ik.EndEffectorOffset = autoCalib.bestPreset
	end)
	autoCalib.active = false
	autoCalib.done = true
	log(1, "[DragonMouseAim][AutoCalib]", ("BEST preset=%s ref=%s dot=%.3f"):format(autoCalib.bestName, autoCalib.bestRef, autoCalib.bestDot))
	return false
end

local function computeScreenConeTarget(camera, root, headBone)
	local viewportSize = camera.ViewportSize
	if viewportSize.X <= 0 or viewportSize.Y <= 0 then
		return nil
	end

	local mousePos = UserInputService:GetMouseLocation()
	local nx = ((mousePos.X / viewportSize.X) - 0.5) * 2
	local ny = -(((mousePos.Y / viewportSize.Y) - 0.5) * 2)

	nx = math.clamp(nx, -1, 1)
	ny = math.clamp(ny, -1, 1)

	local yaw = math.rad(MAX_AIM_YAW_DEGREES) * nx
	local pitch
	if ny >= 0 then
		pitch = math.rad(MAX_AIM_PITCH_UP_DEGREES) * ny
	else
		pitch = math.rad(MAX_AIM_PITCH_DOWN_DEGREES) * ny
	end

	local baseCFrame = root.CFrame
	local aimCFrame = baseCFrame * CFrame.Angles(pitch, yaw, 0)
	local aimDirection = aimCFrame.LookVector
	local headPos = headBone.TransformedWorldCFrame.Position
	local desiredTarget = headPos + aimDirection * AIM_TARGET_DISTANCE + Vector3.new(0, AIM_TARGET_HEIGHT, 0)

	return desiredTarget, nx, ny, yaw, pitch
end

local function keepTargetInFront(root, target)
	local localTarget = root.CFrame:PointToObjectSpace(target.Position)
	if localTarget.Z > -10 then
		localTarget = Vector3.new(localTarget.X, localTarget.Y, -AIM_TARGET_DISTANCE)
		target.Position = root.CFrame:PointToWorldSpace(localTarget)
	end
	return localTarget
end

local function setDragonAimDirection(direction)
	if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.01 then
		return
	end

	local aimDirection = direction.Unit
	player:SetAttribute("DragonAimDirectionX", aimDirection.X)
	player:SetAttribute("DragonAimDirectionY", aimDirection.Y)
	player:SetAttribute("DragonAimDirectionZ", aimDirection.Z)
end

local function resetMouseAimTargetAhead()
	local root = getRoot()
	local head = findBone(NECK_IK_END_EFFECTOR_NAME)
	local target = targetPart or getOrCreateTarget()
	if not root or not head or not target then
		return nil
	end

	local headPos = head.TransformedWorldCFrame.Position
	local forward = root.CFrame.LookVector
	target.Position = headPos + forward * AIM_TARGET_DISTANCE + Vector3.new(0, AIM_TARGET_HEIGHT, 0)
	setDragonAimDirection(forward)
	return target.Position
end

local function update(dt)
	if not ENABLE_DRAGON_MOUSE_AIM then
		return
	end

	initialize()
	local mounted = latestController == player.Name and latestState ~= "Grounded"
	local active = mouseAimUserEnabled and mounted
	local activeChanged = setActiveState(active)

	local target = getOrCreateTarget()
	local ik = target and getOrCreateIK(target)
	if not target or not ik then
		return
	end

	if pendingIKEnable or activeChanged or autoCalib.active then
		ik.Enabled = false
	else
		ik.Enabled = active
	end
	target.Transparency = active and (debugAimTargetVisible and 0.15 or 1) or 1
	if not active then
		if rightMouseAimHeld then
			rightMouseAimHeld = false
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		clearBodyTransforms()
		updateMouseAimDebug(target, false)
		return
	end

	local camera = Workspace.CurrentCamera
	local root = getRoot()
	local head = findBone(NECK_IK_END_EFFECTOR_NAME)
	if not camera or not root or not head then
		updateMouseAimDebug(target, false)
		return
	end

	if activeChanged then
		pendingIKEnable = true
		pendingIKEnableFrames = 0

		ik.Enabled = false
		clearBodyTransforms()

		resetMouseAimTargetAhead()
		applyIKOffset(ik, NECK_IK_OFFSET_PRESET_NAME)

		updateMouseAimDebug(target, true)
		return
	end

	if pendingIKEnable then
		pendingIKEnableFrames += 1

		resetMouseAimTargetAhead()
		clearBodyTransforms()
		applyIKOffset(ik, NECK_IK_OFFSET_PRESET_NAME)
		updateMouseAimDebug(target, true)

		if pendingIKEnableFrames < 2 then
			ik.Enabled = false
			return
		end

		pendingIKEnable = false
		ik.Enabled = true

		if AUTO_CALIBRATE_ON_MOUNT and not autoCalib.done then
			autoCalibrateHeadIK()
		else
			autoCalib.done = true
			applyIKOffset(ik, NECK_IK_OFFSET_PRESET_NAME)
		end
	end

	if autoCalib.active then
		updateAutoCalibration(target, ik, root, head)
		clearBodyTransforms()
		updateMouseAimDebug(target, true)
		return
	end

	local desired, nx, ny, aimYaw, aimPitch = computeScreenConeTarget(camera, root, head)
	local headPosForAim = head.TransformedWorldCFrame.Position
	local officialAimDirection = root.CFrame.LookVector

	if rightMouseAimHeld and camera then
		officialAimDirection = camera.CFrame.LookVector
		desired = headPosForAim + officialAimDirection * AIM_TARGET_DISTANCE
	elseif debugAimTargetVisible and desired then
		officialAimDirection = desired - headPosForAim
		if officialAimDirection.Magnitude > 0.01 then
			officialAimDirection = officialAimDirection.Unit
		else
			officialAimDirection = root.CFrame.LookVector
		end
	else
		desired = headPosForAim + officialAimDirection * AIM_TARGET_DISTANCE
	end

	if not desired then
		return
	end
	setDragonAimDirection(officialAimDirection)

	if activeChanged then
		target.Position = desired
	else
		local alpha = 1 - math.exp(-MOUSE_AIM_RESPONSIVENESS * dt)
		target.Position = target.Position:Lerp(desired, alpha)
	end

	local localTarget = keepTargetInFront(root, target)
	updateMouseAimDebug(target, true)

	if LOG_LEVEL >= 2 then
		debugLogTimer += dt
		if debugLogTimer >= DEBUG_LOG_INTERVAL then
			debugLogTimer = 0
			log(2, "[DragonMouseAim]", ("nx=%.2f ny=%.2f yaw=%.1f pitch=%.1f localTarget=(%.1f, %.1f, %.1f)"):format(
				nx,
				ny,
				math.deg(aimYaw),
				math.deg(aimPitch),
				localTarget.X,
				localTarget.Y,
				localTarget.Z
			))
		end
	end

	if not ENABLE_BODY_AIM then
		clearBodyTransforms()
		return
	end

	local headPos = head.TransformedWorldCFrame.Position
	local toTarget = target.Position - headPos
	if toTarget.Magnitude < 5 then
		clearBodyTransforms()
		return
	end

	local localDir = root.CFrame:VectorToObjectSpace(officialAimDirection)
	local yaw = math.atan2(localDir.X, -localDir.Z)
	local pitch = math.asin(math.clamp(localDir.Y, -1, 1))
	yaw = math.clamp(yaw, -MAX_BODY_YAW, MAX_BODY_YAW)
	pitch = math.clamp(pitch, -MAX_BODY_PITCH_DOWN, MAX_BODY_PITCH_UP)

	local bodyAlpha = 1 - math.exp(-BODY_AIM_RESPONSIVENESS * dt)
	bodyAimYaw += (yaw - bodyAimYaw) * bodyAlpha
	bodyAimPitch += (pitch - bodyAimPitch) * bodyAlpha

	for _, entry in ipairs(bodyEntries) do
		local yawCf = axisRotation(BODY_AIM_YAW_AXIS, bodyAimYaw * entry.yawWeight)
		local pitchCf = axisRotation(BODY_AIM_PITCH_AXIS, bodyAimPitch * entry.pitchWeight)
		applyBodyTransform(entry.bone, pitchCf * yawCf)
	end
end

local remotes = ReplicatedStorage:WaitForChild("DragonFlightRemotes")
local debugRemote = remotes:WaitForChild("FlightDebug")
debugRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	latestState = tostring(payload.state or "Grounded")
	latestController = tostring(payload.controller or "")
end)

local function isMountedByLocalPlayer()
	return latestController == player.Name and latestState ~= "Grounded"
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton2 and isMountedByLocalPlayer() then
		rightMouseAimHeld = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		return
	end

	if gameProcessed then
		return
	end

	if input.KeyCode == DEBUG_SHOW_AIM_TARGET_KEY then
		debugAimTargetVisible = not debugAimTargetVisible
		if targetPart then
			targetPart.Transparency = debugAimTargetVisible and 0.15 or 1
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		rightMouseAimHeld = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end)

ContextActionService:BindAction(ACTION_MOUSE_AIM_TOGGLE, function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		mouseAimUserEnabled = not mouseAimUserEnabled
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.N)

RunService.RenderStepped:Connect(update)
player:SetAttribute("DragonMouseAimActive", false)
