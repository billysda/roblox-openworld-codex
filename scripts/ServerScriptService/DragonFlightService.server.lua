print("[DragonFlightService][PATCH_ACTIVE] StabilityRuntime_v7_Base " .. script:GetFullName())
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DRAGON_NAME = "DragonModel"
local LOG_LEVEL = 0
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

local MAX_SPEED = 90
local MIN_GLIDE_SPEED = 35
local ACCELERATION = 35
local DECELERATION = 25
local TURN_RESPONSIVENESS = 6
local PITCH_RESPONSIVENESS = 4
local BANK_ANGLE = 35
local CLIMB_SPEED = 35
local DIVE_SPEED = 130
local GLIDE_DRAG = 0.985
local BOOST_ACCELERATION = 55

local MAX_TURN_RATE_DEGREES = 85
local TURN_ACCELERATION = 4.5
local TURN_DECELERATION = 5.5
local MAX_FLIGHT_BANK_DEGREES = 70
local MAX_BANK_DEGREES = 70
local BANK_RESPONSIVENESS = 10
local CAMERA_TURN_INFLUENCE = 1.0
local MANUAL_TURN_INFLUENCE = 0.65
local TURN_SPEED_LOSS = 0.10
local MIN_TURN_SPEED_FACTOR = 0.55
local MOVE_DIRECTION_SPRING_SPEED = 15
local MOVE_DIRECTION_DAMPER = 0.5
local MOVE_DIRECTION_RESPONSIVENESS = 15
local VISUAL_ROTATION_RESPONSIVENESS = 9
local ENABLE_FLIGHT_BANK = false
local ENABLE_MOUNTED_GROUND_MODE = true
local GROUND_WALK_SPEED = 16
local GROUND_TROT_SPEED = 28
local GROUND_BACK_SPEED = 8
local GROUND_TURN_RATE_DEGREES = 75
local GROUND_TURN_ACCELERATION = 8
local GROUND_TURN_DECELERATION = 10
local GROUND_ORIENTATION_RESPONSIVENESS = 8
local GROUND_HOVER_ENABLED = false
local AUTO_CALIBRATE_GROUND_HOVER_HEIGHT = false
local GROUND_HOVER_HEIGHT = 4.5
local GROUND_VISUAL_CLEARANCE = 0.6
local GROUND_RAY_DISTANCE = 18
local GROUND_RAY_ORIGIN_HEIGHT = 6
local GROUND_SPRING_STIFFNESS = 65
local GROUND_SPRING_DAMPING = 12
local GROUND_MAX_VERTICAL_SPEED = 18
local GROUND_STICK_TO_SLOPE = true
local DRAGON_MESH_COLLISION_MODE = "Original"
local CREATE_DRAGON_GROUND_COLLIDER = false
local GROUND_U_TURN_ENABLED = true
local GROUND_U_TURN_RATE_DEGREES = 135
local GROUND_U_TURN_SPEED_FACTOR = 0.62
local ENABLE_NECK_LOOK_IK = false
local NECK_LOOK_TEST_MODE = true
local NECK_LOOK_DEBUG = false

local SADDLE_OFFSET = CFrame.new(0, 11.5, 1.5)
local ENABLE_HEAD_LOOK = false
local HEAD_LOOK_CLIENT_SIDE = true
local HEAD_LOOK_TEST_MODE = true
local MAX_HEAD_YAW_DEGREES = 75
local MAX_HEAD_PITCH_UP_DEGREES = 35
local MAX_HEAD_PITCH_DOWN_DEGREES = 40
local HEAD_LOOK_RESPONSIVENESS = 14
local HEAD_LOOK_DEBUG = false
local BODY_TURN_RESPONSIVENESS_WHILE_MOUNTED = 2.8
local BODY_TURN_RESPONSIVENESS_DIVE = 4.5

local TAKEOFF_DURATION = 0.85
local LANDING_DESCENT_SPEED = 18
local GROUND_CHECK_DISTANCE = 10.5
local INPUT_TIMEOUT = 0.55
local DEBUG_INTERVAL = 0.12

local ZERO = Vector3.new(0, 0, 0)
local UP = Vector3.new(0, 1, 0)

local ANIMATION_IDS = {
	Takeoff = "rbxassetid://140705394176328",
	Fly = "rbxassetid://72958722100236",
	Glide = "rbxassetid://88588461978846",
	Dive = "rbxassetid://88588461978846",
	Walk = "rbxassetid://81299004723585",
}

local STATE_TO_ANIMATION = {
	GroundWalk = "Walk",
	GroundTrot = "Walk",
	Takeoff = "Takeoff",
	Fly = "Fly",
	Glide = "Glide",
	Dive = "Dive",
}

local dragon = Workspace:WaitForChild(DRAGON_NAME)
local root = dragon:WaitForChild("HumanoidRootPart")
assert(root:IsA("BasePart"), "DragonModel.HumanoidRootPart must be a BasePart")
local dragonMesh = dragon:WaitForChild("DragonMesh")
local visualMotor = root:FindFirstChildOfClass("Motor6D")
local groundCollider = nil
local calibratedGroundHoverHeight = nil

local animationController = dragon:FindFirstChildOfClass("AnimationController")
if not animationController then
	animationController = Instance.new("AnimationController")
	animationController.Name = "AnimationController"
	animationController.Parent = dragon
end

local animator = animationController:FindFirstChildOfClass("Animator")
if not animator then
	animator = Instance.new("Animator")
	animator.Name = "Animator"
	animator.Parent = animationController
end

local function getOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing
	end

	local created = Instance.new(className)
	created.Name = name
	created.Parent = parent

	if existing then
		warn(('[DragonFlight] Created %s named %s because an existing child had class %s.'):format(className, name, existing.ClassName))
	end

	return created
end

local remotes = getOrCreate(ReplicatedStorage, "Folder", "DragonFlightRemotes")
local toggleRemote = getOrCreate(remotes, "RemoteEvent", "FlightToggle")
local inputRemote = getOrCreate(remotes, "RemoteEvent", "FlightInput")
local debugRemote = getOrCreate(remotes, "RemoteEvent", "FlightDebug")
local unmountRemote = getOrCreate(remotes, "RemoteEvent", "FlightUnmount")


local attachment = getOrCreate(root, "Attachment", "FlightAttachment")
local linearVelocity = getOrCreate(root, "LinearVelocity", "LinearVelocity")
local alignOrientation = getOrCreate(root, "AlignOrientation", "AlignOrientation")

-- DragonMountRig_v1 persistent mount points
do
	local mountFolder = dragon:FindFirstChild("MountPoints")
	if not mountFolder then
		mountFolder = Instance.new("Folder")
		mountFolder.Name = "MountPoints"
		mountFolder.Parent = dragon
	end

	local function createMountPoint(name, offset, color, transparency)
		local part = mountFolder:FindFirstChild(name)

		if part and not part:IsA("BasePart") then
			part:Destroy()
			part = nil
		end

		if not part then
			part = Instance.new("Part")
			part.Name = name
			part.Parent = mountFolder
		end

		part.Size = Vector3.new(1.2, 1.2, 1.2)
		part.Shape = Enum.PartType.Ball
		part.Material = Enum.Material.Neon
		part.Color = color
		part.Transparency = transparency
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Anchored = false
		part.Massless = true
		part.CFrame = root.CFrame * offset

		local weld = part:FindFirstChild(name .. "_Weld")
		if weld and not weld:IsA("WeldConstraint") then
			weld:Destroy()
			weld = nil
		end

		if not weld then
			weld = Instance.new("WeldConstraint")
			weld.Name = name .. "_Weld"
			weld.Parent = part
		end

		weld.Part0 = root
		weld.Part1 = part

		return part
	end

	local driverMount = createMountPoint("DriverMount", CFrame.new(0, 11.5, 1.5), Color3.fromRGB(0, 255, 120), 0.45)
	createMountPoint("PassengerMount", CFrame.new(0, 10.8, -2.2), Color3.fromRGB(0, 170, 255), 0.55)
	local cameraMount = createMountPoint("CameraMount", CFrame.new(0, 15.5, 9.5), Color3.fromRGB(255, 230, 0), 0.55)
	createMountPoint("DismountRight", CFrame.new(7, 3, 1.5), Color3.fromRGB(255, 80, 80), 0.55)

	dragon:SetAttribute("MountRigVersion", "DragonMountRig_v1")
	dragon:SetAttribute("DriverMountPath", driverMount:GetFullName())
	dragon:SetAttribute("CameraMountPath", cameraMount:GetFullName())

	print("[DragonMountRig] MountPoints ready")
end
local riderSeat = getOrCreate(dragon, "Seat", "DragonRiderSeat")
riderSeat.Transparency = 1
riderSeat.CanCollide = false
riderSeat.CanTouch = false
riderSeat.CanQuery = false
riderSeat.Massless = true
riderSeat.Anchored = false
riderSeat.Size = Vector3.new(2, 1, 2)

local riderSeatWeld = getOrCreate(riderSeat, "WeldConstraint", "DragonRiderSeatWeld")
riderSeatWeld.Part0 = nil
riderSeatWeld.Part1 = nil
do
	local mountFolder = dragon:FindFirstChild("MountPoints")
	local driverMount = mountFolder and mountFolder:FindFirstChild("DriverMount")
	riderSeat.CFrame = driverMount and driverMount:IsA("BasePart") and driverMount.CFrame or root.CFrame * SADDLE_OFFSET
end
riderSeatWeld.Part0 = root
riderSeatWeld.Part1 = riderSeat
print("[DragonMount] RiderSeat ready")

local mountPrompt = getOrCreate(riderSeat, "ProximityPrompt", "DragonMountPrompt")
mountPrompt.ActionText = "Montar dragÃ³n"
mountPrompt.ObjectText = "DragÃ³n"
mountPrompt.KeyboardKeyCode = Enum.KeyCode.E
mountPrompt.MaxActivationDistance = 12
mountPrompt.HoldDuration = 0.25
mountPrompt.RequiresLineOfSight = false
print("[DragonMount] MountPrompt ready")
print("[DragonMount] FlightUnmount remote ready")


local function getAssemblyMass()
	local ok, mass = pcall(function()
		return root.AssemblyMass
	end)

	if ok and typeof(mass) == "number" and mass > 0 then
		return mass
	end

	return math.max(root:GetMass(), 1)
end

local function refreshConstraintSettings()
	local mass = getAssemblyMass()

	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	linearVelocity.MaxForce = math.max(250000, mass * 3500)

	alignOrientation.Attachment0 = attachment
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.RigidityEnabled = false
	alignOrientation.Responsiveness = TURN_RESPONSIVENESS
	alignOrientation.MaxAngularVelocity = 12
	alignOrientation.MaxTorque = math.max(250000, mass * 4500)
end

refreshConstraintSettings()
linearVelocity.Enabled = false
alignOrientation.Enabled = false

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.FilterDescendantsInstances = { dragon }

local function configureDragonPhysicalBody()
	if DRAGON_MESH_COLLISION_MODE == "VisualOnly" and dragonMesh and dragonMesh:IsA("BasePart") then
		dragonMesh.CanCollide = false
		dragonMesh.CanTouch = false
		dragonMesh.Massless = true
	end

	local collider = dragon:FindFirstChild("DragonGroundCollider")
	if collider and not collider:IsA("BasePart") then
		collider:Destroy()
		collider = nil
	end

	if not CREATE_DRAGON_GROUND_COLLIDER then
		if collider then
			collider.CanCollide = false
			collider.CanTouch = false
			collider.CanQuery = false
			collider.Transparency = 1
		end
		groundCollider = collider
		return
	end

	if not collider then
		collider = Instance.new("Part")
		collider.Name = "DragonGroundCollider"
		collider.Parent = dragon
	end

	collider.Size = Vector3.new(8, 5, 14)
	collider.Transparency = 1
	collider.CanCollide = true
	collider.CanTouch = false
	collider.CanQuery = false
	collider.Massless = false
	collider.Anchored = false
	collider.CFrame = root.CFrame

	local weld = collider:FindFirstChild("DragonGroundColliderWeld")
	if weld and not weld:IsA("WeldConstraint") then
		weld:Destroy()
		weld = nil
	end
	if not weld then
		weld = Instance.new("WeldConstraint")
		weld.Name = "DragonGroundColliderWeld"
		weld.Parent = collider
	end
	weld.Part0 = root
	weld.Part1 = collider
	groundCollider = collider
end

configureDragonPhysicalBody()

local activePlayer = nil
local mountedPlayer = nil
local isUnmounting = false

local riderCharacterState = {}
local stopFlight
local unmountPlayer

local currentState = "Grounded"
local currentMode = "Grounded"
local currentSpeed = 0
local smoothedLook = root.CFrame.LookVector
local flightForward = root.CFrame.LookVector
local targetMoveDirection = root.CFrame.LookVector
local smoothedMoveDirection = root.CFrame.LookVector
local visualRotation = root.CFrame.Rotation
local visualMotorBankAxis = "Z"
local groundForward = root.CFrame.LookVector
local currentGroundTurnRate = 0
local currentGroundSpeed = 0
local groundTurnVisual = 0
local neckLookTarget = nil
local neckLookIK = nil
local currentBank = 0
local currentTurnRate = 0
local currentTurnInput = 0
local currentYawError = 0
local currentTurnIntensity = 0
local currentUTurnIntent = 0
local arcadeTurnLogElapsed = 0
local aimDebugElapsed = 0
local takeoffEndsAt = 0
local debugElapsed = 0
local tracks = {}
local currentAnimState = nil
local takeoffAnimationComplete = false
local takeoffEndedConnection = nil
local setFlightState
local headLookYaw = 0
local headLookPitch = 0
local headLookDebugElapsed = 0
local headLookEntries = {}
local headLookApplied = {}

local function findBoneByName(boneName)
	local found = dragonMesh:FindFirstChild(boneName, true)
	if found and found:IsA("Bone") then
		return found
	end

	return nil
end

local function describeBoneList(bones)
	local names = {}
	for _, bone in ipairs(bones) do
		table.insert(names, bone.Name)
	end
	return #names > 0 and table.concat(names, ", ") or "none"
end

local function getOrCreateNeckLookTarget()
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
	target.Transparency = NECK_LOOK_TEST_MODE and 0.35 or 1
	target.Color = Color3.fromRGB(255, 255, 0)
	target.Material = Enum.Material.Neon
	neckLookTarget = target
	return target
end

local function initializeDragonNeckLookIK()
	if not ENABLE_NECK_LOOK_IK then
		return
	end

	local neckNames = {
		"Bip01-Neck_32",
		"Bip01-Neck1_11",
		"Bip01-Neck2_10",
		"Bip01-Neck3_9",
	}
	local foundNecks = {}
	for _, boneName in ipairs(neckNames) do
		local bone = findBoneByName(boneName)
		if bone then
			table.insert(foundNecks, bone)
		else
			warn("[DragonNeckIK][WARN] Missing neck bone: " .. boneName)
		end
	end

	local chainRoot = findBoneByName("Bip01-Neck_32")
	local headBone = findBoneByName("Bip01-Head_8")
	local target = getOrCreateNeckLookTarget()

	if dragonMesh then
		print("[DragonNeckIK] DragonMesh found")
	end
	print("[DragonNeckIK] Neck bones found: " .. describeBoneList(foundNecks))
	if headBone then
		print("[DragonNeckIK] Head bone found: " .. headBone.Name)
	else
		warn("[DragonNeckIK][WARN] Missing head bone: Bip01-Head_8")
	end
	print("[DragonNeckIK] Target ready")

	if not chainRoot or not headBone or not target then
		warn("[DragonNeckIK][WARN] IKControl not created because required references are missing")
		return
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
			return
		end
		ik = created
		ik.Name = "DragonNeckLookIK"
		ik.Parent = animator
	end

	ik.Type = Enum.IKControlType.LookAt
	ik.ChainRoot = chainRoot
	ik.EndEffector = headBone
	ik.Target = target
	ik.Weight = 1
	ik.SmoothTime = NECK_LOOK_TEST_MODE and 0.03 or 0.05
	ik.Enabled = true
	pcall(function()
		ik.Priority = 10
	end)

	neckLookIK = ik
	print("[DragonNeckIK] IKControl ready")
	print("[DragonNeckIK] ChainRoot=" .. chainRoot.Name .. " EndEffector=" .. headBone.Name)

	local chainCount = "n/a"
	local chainLength = "n/a"
	pcall(function()
		chainCount = tostring(ik:GetChainCount())
	end)
	pcall(function()
		chainLength = tostring(ik:GetChainLength())
	end)
	print("[DragonNeckIK] ChainCount=" .. tostring(chainCount) .. " ChainLength=" .. tostring(chainLength))
end

local function initializeHeadLookController()
	if not ENABLE_HEAD_LOOK then
		return
	end

	local neckBones = {
		findBoneByName("Bip01-Neck1_11"),
		findBoneByName("Bip01-Neck2_10"),
		findBoneByName("Bip01-Neck3_9"),
	}
	local headBone = findBoneByName("Bip01-Head_8")
	local validNeckBones = {}

	for _, bone in ipairs(neckBones) do
		if bone then
			table.insert(validNeckBones, bone)
		end
	end

	print("[DragonHeadLook] Bones found:")
	print("[DragonHeadLook] Neck bones: " .. describeBoneList(validNeckBones))
	print("[DragonHeadLook] Head bone: " .. (headBone and headBone.Name or "none"))

	if not headBone and #validNeckBones == 0 then
		warn("[DragonHeadLook][WARN] No head/neck bones found. Head look disabled.")
		return
	end

	if headBone and #validNeckBones >= 3 then
		headLookEntries = {
			{ bone = validNeckBones[#validNeckBones - 2], weight = 0.15 },
			{ bone = validNeckBones[#validNeckBones - 1], weight = 0.20 },
			{ bone = validNeckBones[#validNeckBones], weight = 0.25 },
			{ bone = headBone, weight = 0.40 },
		}
	elseif headBone and #validNeckBones >= 1 then
		headLookEntries = {
			{ bone = validNeckBones[#validNeckBones], weight = 0.45 },
			{ bone = headBone, weight = 0.55 },
		}
	elseif headBone then
		headLookEntries = {
			{ bone = headBone, weight = 1.0, yawScale = 0.65, pitchScale = 0.65 },
		}
	else
		local singleNeck = validNeckBones[#validNeckBones]
		headLookEntries = {
			{ bone = singleNeck, weight = 1.0, yawScale = 0.55, pitchScale = 0.55 },
		}
	end

	print("[DragonHeadLook] Controller ready")
end

local function updateHeadLook(dt, cameraLook)
	if not ENABLE_HEAD_LOOK or #headLookEntries == 0 then
		return
	end

	local targetYaw = 0
	local targetPitch = 0

	if mountedPlayer and activePlayer and cameraLook and cameraLook.Magnitude > 0.01 then
		local localLook = root.CFrame:VectorToObjectSpace(cameraLook.Unit)
		targetYaw = math.clamp(math.atan2(localLook.X, -localLook.Z), -math.rad(MAX_HEAD_YAW_DEGREES), math.rad(MAX_HEAD_YAW_DEGREES))
		local rawPitch = math.asin(math.clamp(localLook.Y, -1, 1))
		targetPitch = math.clamp(rawPitch, -math.rad(MAX_HEAD_PITCH_DOWN_DEGREES), math.rad(MAX_HEAD_PITCH_UP_DEGREES))
	end

	local alpha = 1 - math.exp(-HEAD_LOOK_RESPONSIVENESS * dt)
	headLookYaw += (targetYaw - headLookYaw) * alpha
	headLookPitch += (targetPitch - headLookPitch) * alpha

	for _, entry in ipairs(headLookEntries) do
		local bone = entry.bone
		local previousAdditive = headLookApplied[bone] or CFrame.identity
		local animationTransform = bone.Transform * previousAdditive:Inverse()
		local yawScale = entry.yawScale or 1
		local pitchScale = entry.pitchScale or 1
		local additive = CFrame.Angles(headLookPitch * entry.weight * pitchScale, headLookYaw * entry.weight * yawScale, 0)
		bone.Transform = animationTransform * additive
		headLookApplied[bone] = additive
	end

	headLookDebugElapsed += dt
	if HEAD_LOOK_DEBUG and headLookDebugElapsed >= 0.5 then
		headLookDebugElapsed = 0
		print(("[DragonHeadLook] yaw=%.1f pitch=%.1f"):format(math.deg(headLookYaw), math.deg(headLookPitch)))
	end
end

local function defaultInput()
	return {
		throttle = 0,
		brake = 0,
		turn = 0,
		climb = 0,
		boost = false,
		cameraLook = smoothedLook,
		aimDirection = smoothedLook,
		visualBankAxis = visualMotorBankAxis,
		lastUpdate = 0,
	}
end

local latestInput = defaultInput()

local function moveTowards(current, target, maxDelta)
	local delta = target - current
	if math.abs(delta) <= maxDelta then
		return target
	end

	return current + math.sign(delta) * maxDelta
end

local function expAlpha(responsiveness, dt)
	return 1 - math.exp(-responsiveness * dt)
end

local function sanitizeNumber(value, fallback, minValue, maxValue)
	if typeof(value) ~= "number" or value ~= value then
		return fallback
	end

	return math.clamp(value, minValue, maxValue)
end

local function sanitizeLook(value, fallback)
	if typeof(value) ~= "Vector3" or value.Magnitude < 0.01 then
		return fallback
	end

	return value.Unit
end

local function sanitizeAimDirection(value, fallback)
	local dir = sanitizeLook(value, fallback)
	dir = Vector3.new(dir.X, math.clamp(dir.Y, -0.75, 0.75), dir.Z)
	if dir.Magnitude < 0.01 then
		return fallback
	end
	return dir.Unit
end

local function sanitizeAxis(value, fallback)
	if value == "X" or value == "Y" or value == "Z" then
		return value
	end

	return fallback or "Z"
end

local function axisRotation(axisName, amount)
	if axisName == "X" then
		return CFrame.Angles(amount, 0, 0)
	elseif axisName == "Y" then
		return CFrame.Angles(0, amount, 0)
	end

	return CFrame.Angles(0, 0, amount)
end

local function applyVisualMotorBank()
	if not visualMotor or not visualMotor.Parent then
		visualMotor = root:FindFirstChildOfClass("Motor6D")
	end

	if visualMotor then
		visualMotor.Transform = axisRotation(visualMotorBankAxis, currentBank)
	end
end

local function horizontalUnit(vector, fallback)
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude >= 0.01 then
		return flat.Unit
	end

	local fallbackFlat = Vector3.new(fallback.X, 0, fallback.Z)
	if fallbackFlat.Magnitude >= 0.01 then
		return fallbackFlat.Unit
	end

	return Vector3.new(0, 0, -1)
end

local function isGrounded()
	return Workspace:Raycast(root.Position, Vector3.new(0, -GROUND_CHECK_DISTANCE, 0), raycastParams) ~= nil
end

local function raycastGround(distance)
	local rayOrigin = root.Position + Vector3.new(0, GROUND_RAY_ORIGIN_HEIGHT, 0)
	local rayDirection = Vector3.new(0, -((distance or GROUND_RAY_DISTANCE) + GROUND_RAY_ORIGIN_HEIGHT), 0)
	return Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
end

local function computeModelBottomY()
	if dragonMesh and dragonMesh:IsA("BasePart") then
		return dragonMesh.Position.Y - dragonMesh.Size.Y * 0.5
	end
	local cf, size = dragon:GetBoundingBox()
	return cf.Position.Y - size.Y * 0.5
end

local function computeAutoGroundHoverHeight()
	local bottomY = computeModelBottomY()
	local rootY = root.Position.Y
	local rootToBottom = rootY - bottomY

	if typeof(rootToBottom) ~= "number" or rootToBottom ~= rootToBottom then
		return GROUND_HOVER_HEIGHT
	end

	return math.max(2, rootToBottom + GROUND_VISUAL_CLEARANCE)
end

local function isGroundMovementState(state)
	return state == "MountedGround" or state == "GroundWalk" or state == "GroundTrot"
end

local function isFlightState(state)
	return state == "Takeoff" or state == "Fly" or state == "Glide" or state == "Dive" or state == "Landing"
end

local ANIMATION_SETTINGS = {
	Takeoff = {
		Looped = false,
		Priority = Enum.AnimationPriority.Action2,
		FadeIn = 0.15,
		FadeOut = 0.2,
	},
	Fly = {
		Looped = true,
		Priority = Enum.AnimationPriority.Movement,
		FadeIn = 0.25,
		FadeOut = 0.2,
	},
	Glide = {
		Looped = true,
		Priority = Enum.AnimationPriority.Action,
		FadeIn = 0.25,
		FadeOut = 0.2,
	},
	Dive = {
		Looped = true,
		Priority = Enum.AnimationPriority.Action2,
		FadeIn = 0.15,
		FadeOut = 0.15,
	},
	Walk = {
		Looped = true,
		Priority = Enum.AnimationPriority.Movement,
		FadeIn = 0.18,
		FadeOut = 0.2,
	},
}

local function normalizeAnimationId(animationId)
	if typeof(animationId) ~= "string" or animationId == "" then
		return ""
	end

	if tonumber(animationId) then
		return "rbxassetid://" .. animationId
	end

	return animationId
end

local function loadDragonAnimations()
	tracks = {}

	if takeoffEndedConnection then
		takeoffEndedConnection:Disconnect()
		takeoffEndedConnection = nil
	end

	local printedGlideDiveSharedLog = false

	for state, animationId in pairs(ANIMATION_IDS) do
		local normalizedId = normalizeAnimationId(animationId)
		if normalizedId ~= "" then
			local animation = Instance.new("Animation")
			animation.Name = "DragonFlight_" .. state
			animation.AnimationId = normalizedId

			local ok, trackOrError = pcall(function()
				return animator:LoadAnimation(animation)
			end)

			animation:Destroy()

			if ok and trackOrError then
				local settings = ANIMATION_SETTINGS[state]
				if not settings then
					warnOnce("AnimationSettings_" .. tostring(state), "[DragonFlight][WARN] Missing animation settings for " .. tostring(state))
					settings = { Looped = true, Priority = Enum.AnimationPriority.Movement }
				end
				trackOrError.Looped = settings.Looped
				trackOrError.Priority = settings.Priority
				tracks[state] = trackOrError

				if state == "Glide" and ANIMATION_IDS.Glide == ANIMATION_IDS.Dive then
					print("[DragonFlight] Animation Glide/Dive loaded: " .. normalizedId)
					printedGlideDiveSharedLog = true
				elseif state == "Dive" and printedGlideDiveSharedLog then
					print("[DragonFlight] Animation Dive loaded: " .. normalizedId .. " (shared asset with Glide)")
				else
					print(("[DragonFlight] Animation %s loaded: %s"):format(state, normalizedId))
				end
			else
				warnOnce("AnimationLoad_" .. tostring(state), "[DragonFlight][WARN] Failed to load animation " .. tostring(state) .. ": " .. normalizedId .. " " .. tostring(trackOrError))
			end
		end
	end

	if tracks.Takeoff then
		takeoffEndedConnection = tracks.Takeoff.Ended:Connect(function()
			takeoffAnimationComplete = true
			if activePlayer and currentState == "Takeoff" and setFlightState then
				setFlightState("Fly")
			end
		end)
	end
end

local function stopFlightAnimations(fadeTime)
	for _, track in pairs(tracks) do
		if track.IsPlaying then
			track:Stop(fadeTime or 0.2)
		end
	end

	currentAnimState = nil
end

local function playFlightAnimation(state)
	local track = tracks[state]
	if not track then
		return
	end

	if currentAnimState == state and track.IsPlaying then
		return
	end

	if state ~= "Takeoff" and currentAnimState == "Takeoff" and tracks.Takeoff and tracks.Takeoff.IsPlaying and not takeoffAnimationComplete then
		return
	end

	local settings = ANIMATION_SETTINGS[state]
	currentAnimState = state

	for name, otherTrack in pairs(tracks) do
		if name ~= state and otherTrack.IsPlaying then
			local otherSettings = ANIMATION_SETTINGS[name]
			otherTrack:Stop(otherSettings and otherSettings.FadeOut or 0.2)
		end
	end

	if not track.IsPlaying then
		track:Play(settings.FadeIn)
	end

	log(2, "[DragonFlight]", "Playing animation: " .. state)
end

local function updateAnimationSpeed(speed)
	if not currentAnimState then
		return
	end

	local track = tracks[currentAnimState]
	if not track or not track.IsPlaying then
		return
	end

	local ratio = math.clamp((speed - MIN_GLIDE_SPEED) / math.max(MAX_SPEED - MIN_GLIDE_SPEED, 1), 0, 1)
	local playbackSpeed = 1

	if currentAnimState == "Fly" then
		playbackSpeed = 0.85 + 0.3 * ratio
	elseif currentAnimState == "Glide" then
		playbackSpeed = 0.7 + 0.3 * ratio
	elseif currentAnimState == "Dive" then
		local diveRatio = math.clamp((speed - MAX_SPEED) / math.max(DIVE_SPEED - MAX_SPEED, 1), 0, 1)
		playbackSpeed = 1.1 + 0.25 * diveRatio
	elseif currentAnimState == "Walk" then
		local walkRatio = math.clamp(math.abs(speed) / math.max(GROUND_TROT_SPEED, 1), 0, 1)
		playbackSpeed = 0.7 + 0.55 * walkRatio
	end

	track:AdjustSpeed(playbackSpeed)
end

setFlightState = function(nextState)
	if currentState == nextState then
		return
	end

	currentState = nextState
	currentMode = nextState
	if isGroundMovementState(nextState) then
		log(1, "[DragonGround]", "State changed: " .. nextState)
	elseif nextState == "Grounded" then
		log(1, "[DragonFlight]", "State changed: Grounded")
	else
		log(1, "[DragonFlight]", "State changed: " .. nextState)
	end

	local animationState = STATE_TO_ANIMATION[nextState]
	if animationState then
		if animationState == "Takeoff" then
			takeoffAnimationComplete = false
		end
		playFlightAnimation(animationState)
	else
		stopFlightAnimations(nextState == "Grounded" and 0.2 or 0.25)
	end
end

local function setConstraintsEnabled(enabled)
	refreshConstraintSettings()
	linearVelocity.Enabled = enabled
	alignOrientation.Enabled = enabled
end

local function setNetworkOwner(player)
	pcall(function()
		root:SetNetworkOwner(player)
	end)
end

local function safeNumber(value, fallback)
	if typeof(value) ~= "number" or value ~= value then
		return fallback or 0
	end
	return value
end

local function safeDeg(value)
	return math.deg(safeNumber(value, 0))
end

local function buildDebugPayload(message)
	return {
		state = currentState,
		mode = currentMode,
		speed = root.AssemblyLinearVelocity.Magnitude,
		altitude = root.Position.Y,
		controller = activePlayer and activePlayer.Name or mountedPlayer and mountedPlayer.Name or "",
		turnIntensity = safeNumber(currentTurnIntensity, 0),
		turnInput = safeNumber(currentTurnInput, 0),
		turnRateDeg = safeDeg(currentTurnRate),
		yawErrorDeg = safeDeg(currentYawError),
		bankDeg = safeDeg(currentBank),
		visualMotorBankAxis = visualMotorBankAxis,
		smoothedMoveDirection = smoothedMoveDirection,
		groundForward = groundForward,
		groundTurnVisual = groundTurnVisual,
		uTurnIntent = safeNumber(currentUTurnIntent, 0),
		message = message or "",
	}
end

local function sendDebug(player, message)
	if player and player.Parent then
		debugRemote:FireClient(player, buildDebugPayload(message))
	end
end
local function setCharacterCollisionEnabled(character, enabled, savedState)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if savedState then
				savedState.parts[descendant] = {
					CanCollide = descendant.CanCollide,
					CanTouch = descendant.CanTouch,
				}
			end

			descendant.CanCollide = enabled
			descendant.CanTouch = enabled
		end
	end
end

local function restoreCharacterState(player, character, humanoid)
	local savedState = riderCharacterState[player]
	if humanoid then
		humanoid.AutoRotate = savedState and savedState.AutoRotate ~= nil and savedState.AutoRotate or true
		humanoid.Sit = false

		if savedState then
			if typeof(savedState.WalkSpeed) == "number" then
				humanoid.WalkSpeed = savedState.WalkSpeed
			end
			if typeof(savedState.UseJumpPower) == "boolean" then
				humanoid.UseJumpPower = savedState.UseJumpPower
			end
			if typeof(savedState.JumpPower) == "number" then
				humanoid.JumpPower = savedState.JumpPower
			end
			if typeof(savedState.JumpHeight) == "number" then
				humanoid.JumpHeight = savedState.JumpHeight
			end
			if typeof(savedState.PlatformStand) == "boolean" then
				humanoid.PlatformStand = savedState.PlatformStand
			end
		end
	end

	if savedState and savedState.parts then
		for part, partState in pairs(savedState.parts) do
			if part and part.Parent then
				part.CanCollide = partState.CanCollide
				part.CanTouch = partState.CanTouch
			end
		end
	elseif character then
		setCharacterCollisionEnabled(character, true)
	end

	riderCharacterState[player] = nil
end

local function resetGroundMovement()
	groundForward = horizontalUnit(root.CFrame.LookVector, Vector3.new(0, 0, -1))
	currentGroundTurnRate = 0
	currentGroundSpeed = 0
	groundTurnVisual = 0
	currentTurnRate = 0
	currentTurnInput = 0
	currentTurnIntensity = 0
	currentUTurnIntent = 0
	currentYawError = 0
	currentBank = 0
	smoothedMoveDirection = groundForward
	smoothedLook = groundForward
	visualRotation = CFrame.lookAt(root.Position, root.Position + groundForward, UP).Rotation
end

local function enterMountedGround(player, message)
	if not ENABLE_MOUNTED_GROUND_MODE or player ~= mountedPlayer then
		return
	end

	activePlayer = player
	latestInput = defaultInput()
	latestInput.cameraLook = root.CFrame.LookVector
	latestInput.aimDirection = root.CFrame.LookVector
	latestInput.lastUpdate = os.clock()
	resetGroundMovement()
	if AUTO_CALIBRATE_GROUND_HOVER_HEIGHT then
		calibratedGroundHoverHeight = computeAutoGroundHoverHeight()
		print(("[DragonGround] AutoHoverHeight=%.2f fixed=%.2f"):format(calibratedGroundHoverHeight, GROUND_HOVER_HEIGHT))
	end
	root.AssemblyAngularVelocity = ZERO
	linearVelocity.VectorVelocity = ZERO
	alignOrientation.CFrame = CFrame.lookAt(root.Position, root.Position + groundForward, UP)
	setNetworkOwner(player)
	setConstraintsEnabled(true)
	setFlightState("MountedGround")
	log(1, "[DragonGround]", "MountedGround ready")
	sendDebug(player, message or "[DragonGround] MountedGround ready")
end

local updateGroundMovement
updateGroundMovement = function(dt, input)
	-- v7b:
	-- No se usan helpers top-level para evitar el error de local registers.
	-- En tierra NO usamos input.aimDirection para controlar el cuerpo.
	-- La cÃ¡mara solo define el marco de referencia de W/A/S/D.

	local throttle = math.clamp(input.throttle or 0, 0, 1)
	local brake = math.clamp(input.brake or 0, 0, 1)
	local turn = math.clamp(input.turn or 0, -1, 1)
	local absTurn = math.abs(turn)

	local cameraForwardRaw = input.cameraLook
	if typeof(cameraForwardRaw) ~= "Vector3" or cameraForwardRaw.Magnitude < 0.01 then
		cameraForwardRaw = root.CFrame.LookVector
	end

	local cameraForward = Vector3.new(cameraForwardRaw.X, 0, cameraForwardRaw.Z)
	if cameraForward.Magnitude < 0.01 then
		cameraForward = Vector3.new(groundForward.X, 0, groundForward.Z)
	end
	if cameraForward.Magnitude < 0.01 then
		cameraForward = Vector3.new(0, 0, -1)
	end
	cameraForward = cameraForward.Unit

	local cameraRightRaw = input.cameraRight
	local cameraRight = nil

	if typeof(cameraRightRaw) == "Vector3" and cameraRightRaw.Magnitude > 0.01 then
		cameraRight = Vector3.new(cameraRightRaw.X, 0, cameraRightRaw.Z)
	end

	if not cameraRight or cameraRight.Magnitude < 0.01 then
		cameraRight = cameraForward:Cross(UP)
	end

	if cameraRight.Magnitude < 0.01 then
		cameraRight = Vector3.new(1, 0, 0)
	else
		cameraRight = cameraRight.Unit
	end

	-- Asegurar que cameraRight no llegue invertido.
	local expectedRight = cameraForward:Cross(UP)
	if expectedRight.Magnitude > 0.01 then
		expectedRight = expectedRight.Unit
		if cameraRight:Dot(expectedRight) < 0 then
			cameraRight = -cameraRight
		end
	end

	local hasForward = throttle > 0.05
	local hasBack = brake > 0.05 and not hasForward
	local turnOnly = (not hasForward) and (not hasBack) and absTurn > 0.15

	local moveIntent = ZERO

	if hasForward then
		moveIntent += cameraForward * throttle

		if absTurn > 0.05 then
			moveIntent += cameraRight * turn * 0.85
		end
	elseif hasBack then
		moveIntent += -cameraForward * brake

		if absTurn > 0.05 then
			moveIntent += cameraRight * turn * 0.55
		end
	elseif turnOnly then
		-- A/D solas: adelante + lado, no strafe puro ni giro clavado.
		moveIntent += cameraForward * 0.85
		moveIntent += cameraRight * turn * 0.65
	end

	local hasMoveIntent = moveIntent.Magnitude > 0.01
	local moveDirection = hasMoveIntent and moveIntent.Unit or groundForward

	local targetSpeed = 0

	if hasForward then
		targetSpeed = input.boost and GROUND_TROT_SPEED or GROUND_WALK_SPEED
	elseif hasBack then
		targetSpeed = GROUND_BACK_SPEED
	elseif turnOnly then
		targetSpeed = 12
	end

	-- U-turn automÃ¡tico apagado en tierra normal.
	currentUTurnIntent = 0

	local targetFacing = groundForward

	if hasMoveIntent then
		if hasBack and not hasForward then
			-- Retroceso: se mueve hacia atrÃ¡s, pero no gira 180Â° instantÃ¡neo.
			targetFacing = -moveDirection
		else
			targetFacing = moveDirection
		end
	end

	targetFacing = Vector3.new(targetFacing.X, 0, targetFacing.Z)
	if targetFacing.Magnitude < 0.01 then
		targetFacing = groundForward
	else
		targetFacing = targetFacing.Unit
	end

	local groundForwardFlat = Vector3.new(groundForward.X, 0, groundForward.Z)
	if groundForwardFlat.Magnitude < 0.01 then
		groundForwardFlat = root.CFrame.LookVector
		groundForwardFlat = Vector3.new(groundForwardFlat.X, 0, groundForwardFlat.Z)
	end
	if groundForwardFlat.Magnitude < 0.01 then
		groundForwardFlat = Vector3.new(0, 0, -1)
	else
		groundForwardFlat = groundForwardFlat.Unit
	end

	local crossY = groundForwardFlat:Cross(targetFacing).Y
	local dot = math.clamp(groundForwardFlat:Dot(targetFacing), -1, 1)
	local yawError = math.atan2(crossY, dot)

	local facingResponse = 7.5
	if turnOnly then
		facingResponse = 5.0
	elseif hasBack and not hasForward then
		facingResponse = 4.5
	end

	local facingAlpha = 1 - math.exp(-facingResponse * dt)
	groundForward = groundForwardFlat:Lerp(targetFacing, facingAlpha)
	if groundForward.Magnitude < 0.01 then
		groundForward = targetFacing
	else
		groundForward = groundForward.Unit
	end

	currentGroundTurnRate = yawError / math.max(dt, 1 / 240)

	currentGroundSpeed = moveTowards(currentGroundSpeed, targetSpeed, 38 * dt)
	currentSpeed = math.abs(currentGroundSpeed)

	local visualTurnInput = 0

	if absTurn > 0.05 then
		visualTurnInput = turn
	elseif hasMoveIntent then
		visualTurnInput = math.clamp(yawError / math.rad(70), -1, 1)
	end

	groundTurnVisual += (visualTurnInput - groundTurnVisual) * (1 - math.exp(-6 * dt))

	currentTurnInput = visualTurnInput
	currentTurnIntensity = visualTurnInput
	currentYawError = yawError
	currentTurnRate = currentGroundTurnRate
	currentBank = 0

	smoothedMoveDirection = moveDirection
	smoothedLook = groundForward

	local nextState = "MountedGround"

	if math.abs(currentGroundSpeed) > 1 then
		nextState = input.boost and currentGroundSpeed > 0 and "GroundTrot" or "GroundWalk"
	end

	setFlightState(nextState)
	updateAnimationSpeed(math.abs(currentGroundSpeed))

	linearVelocity.VectorVelocity = moveDirection * currentGroundSpeed
	alignOrientation.Responsiveness = GROUND_ORIENTATION_RESPONSIVENESS
	alignOrientation.CFrame = CFrame.lookAt(root.Position, root.Position + groundForward, Vector3.yAxis)

	applyVisualMotorBank()

	if activePlayer then
		activePlayer:SetAttribute("DragonTurnInput", visualTurnInput)
		activePlayer:SetAttribute("DragonUTurnIntent", 0)
	end

	-- Debug local dentro de la funciÃ³n para no gastar registros top-level.
	if not _G.__DragonGroundCameraRelative_v7b_DebugElapsed then
		_G.__DragonGroundCameraRelative_v7b_DebugElapsed = 0
	end

	_G.__DragonGroundCameraRelative_v7b_DebugElapsed += dt

	if false and _G.__DragonGroundCameraRelative_v7b_DebugElapsed >= 0.5 then
		_G.__DragonGroundCameraRelative_v7b_DebugElapsed = 0

		local rightDot = 0
		if cameraRight.Magnitude > 0.01 and linearVelocity.VectorVelocity.Magnitude > 0.01 then
			rightDot = cameraRight.Unit:Dot(linearVelocity.VectorVelocity.Unit)
		end

		print(("[DragonGroundCameraRelative_v7b] state=%s W=%.2f S=%.2f A_D=%.2f turnOnly=%s targetSpeed=%.1f currentSpeed=%.1f velMag=%.1f rightDot=%.2f uTurn=%.2f yawErr=%.1f visualTurn=%.2f moveDir=(%.2f,%.2f,%.2f) face=(%.2f,%.2f,%.2f)"):format(
			currentState,
			throttle,
			brake,
			turn,
			tostring(turnOnly),
			targetSpeed,
			currentGroundSpeed,
			linearVelocity.VectorVelocity.Magnitude,
			rightDot,
			currentUTurnIntent,
			math.deg(yawError),
			visualTurnInput,
			moveDirection.X, moveDirection.Y, moveDirection.Z,
			groundForward.X, groundForward.Y, groundForward.Z
		))
	end
end

local function mountPlayer(player)
	log(2, "[DragonMount]", "Mount requested by " .. player.Name)

	if mountedPlayer then
		sendDebug(player, "[DragonMount] Dragon already mounted by " .. mountedPlayer.Name)
		warnOnce("DragonAlreadyMounted", "[DragonMount] Dragon already mounted by " .. mountedPlayer.Name)
		return
	end

	local character = player.Character
	if not character then
		sendDebug(player, "[DragonMount] Character not ready")
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local characterRoot = character:FindFirstChild("HumanoidRootPart")
	local lowerTorso = character:FindFirstChild("LowerTorso")
	if not humanoid or not characterRoot or not characterRoot:IsA("BasePart") then
		sendDebug(player, "[DragonMount] Character missing Humanoid or HumanoidRootPart")
		return
	end

	if not lowerTorso or not lowerTorso:IsA("BasePart") then
		lowerTorso = characterRoot
		warn("[DragonRiderBoneConstraint] LowerTorso no encontrado; usando HumanoidRootPart como fallback.")
	end

	local function getConfigValue(name, fallback)
		local configFolder = dragon:FindFirstChild("DragonMountConfig")
		local obj = configFolder and configFolder:FindFirstChild(name)
		if obj and obj:IsA("ValueBase") then
			return obj.Value
		end
		return fallback
	end

	local mountBoneName = tostring(getConfigValue("MountBoneName", "Bip01-Spine1_53"))
	local offsetX = tonumber(getConfigValue("OffsetX", 0)) or 0
	local offsetY = tonumber(getConfigValue("OffsetY", 2.25)) or 2.25
	local offsetZ = tonumber(getConfigValue("OffsetZ", 0.35)) or 0.35
	local rotX = math.rad(tonumber(getConfigValue("RotX", 0)) or 0)
	local rotY = math.rad(tonumber(getConfigValue("RotY", 0)) or 0)
	local rotZ = math.rad(tonumber(getConfigValue("RotZ", 0)) or 0)
	local useSeatPose = getConfigValue("UseSeatPose", false) == true
	local showDebugMounts = getConfigValue("ShowDebugMounts", true) == true

	local function findBone(name)
		if not dragonMesh then
			return nil
		end

		local found = dragonMesh:FindFirstChild(name, true)
		if found and found:IsA("Bone") then
			return found
		end

		return nil
	end

	local chosenBone = findBone(mountBoneName)
	if not chosenBone then
		local candidates = {
			"Bip01-Spine1_53",
			"Bip01-Spine2_52",
			"Bip01-Spine_64",
			"Bip01-Pelvis_71",
			"Root_73",
		}

		for _, candidate in ipairs(candidates) do
			chosenBone = findBone(candidate)
			if chosenBone then
				mountBoneName = candidate
				warn("[DragonRiderBoneConstraint] MountBoneName no existe. Fallback a " .. candidate)
				break
			end
		end
	end

	if not chosenBone then
		warn("[DragonRiderBoneConstraint] No encontrÃ© ningÃºn bone vÃ¡lido. Fallback a RootWeld.")
	end

	-- Crear MountPoints bÃ¡sicos para debug/desmontaje.
	local mountFolder = dragon:FindFirstChild("MountPoints")
	if not mountFolder then
		mountFolder = Instance.new("Folder")
		mountFolder.Name = "MountPoints"
		mountFolder.Parent = dragon
	end

	local function ensurePoint(name, cf, color, transparency)
		local p = mountFolder:FindFirstChild(name)
		if p and not p:IsA("BasePart") then
			p:Destroy()
			p = nil
		end
		if not p then
			p = Instance.new("Part")
			p.Name = name
			p.Parent = mountFolder
		end
		p.Size = Vector3.new(1.2, 1.2, 1.2)
		p.Shape = Enum.PartType.Ball
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Transparency = showDebugMounts and transparency or 1
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Anchored = false
		p.Massless = true
		p.CFrame = cf
		local w = p:FindFirstChild(name .. "_Weld")
		if w and not w:IsA("WeldConstraint") then
			w:Destroy()
			w = nil
		end
		if not w then
			w = Instance.new("WeldConstraint")
			w.Name = name .. "_Weld"
			w.Parent = p
		end
		w.Part0 = root
		w.Part1 = p
		return p
	end

	local dismountRight = ensurePoint("DismountRight", root.CFrame * CFrame.new(7, 3, 1.5), Color3.fromRGB(255, 80, 80), 0.55)

	-- Crear socket de montura como Bone hijo del bone elegido.
	-- Esto da offset configurable sin editar el bone original del dragÃ³n.
	local mountSocket = nil
	local mountCFrame = CFrame.new(offsetX, offsetY, offsetZ) * CFrame.Angles(rotX, rotY, rotZ)

	if chosenBone then
		mountSocket = chosenBone:FindFirstChild("DragonRiderMountSocket")
		if mountSocket and not mountSocket:IsA("Bone") then
			mountSocket:Destroy()
			mountSocket = nil
		end

		if not mountSocket then
			mountSocket = Instance.new("Bone")
			mountSocket.Name = "DragonRiderMountSocket"
			mountSocket.Parent = chosenBone
		end

		mountSocket.CFrame = mountCFrame
	end

	-- Attachment del jugador: preferir cintura real R15.
	local waistAttachment = lowerTorso:FindFirstChild("WaistCenterAttachment")
		or lowerTorso:FindFirstChild("WaistRigAttachment")
		or lowerTorso:FindFirstChild("RootRigAttachment")
		or lowerTorso:FindFirstChild("DragonRiderWaistAttachment")

	if not waistAttachment or not waistAttachment:IsA("Attachment") then
		waistAttachment = Instance.new("Attachment")
		waistAttachment.Name = "DragonRiderWaistAttachment"
		waistAttachment.CFrame = CFrame.new(0, 0, 0)
		waistAttachment.Parent = lowerTorso
	end

	-- Limpiar restos viejos.
	for _, obj in ipairs(characterRoot:GetChildren()) do
		if obj.Name == "DragonRiderRootWeld" then
			obj:Destroy()
		end
	end

	for _, obj in ipairs(lowerTorso:GetChildren()) do
		if obj.Name:match("^DragonRiderMountRigidConstraint") then
			obj:Destroy()
		end
	end

	local oldSeatWeld = riderSeat:FindFirstChild("SeatWeld")
	if oldSeatWeld then
		oldSeatWeld:Destroy()
	end

	riderCharacterState[player] = {
		AutoRotate = humanoid.AutoRotate,
		WalkSpeed = humanoid.WalkSpeed,
		JumpPower = humanoid.JumpPower,
		JumpHeight = humanoid.JumpHeight,
		UseJumpPower = humanoid.UseJumpPower,
		PlatformStand = humanoid.PlatformStand,
		parts = {},
		massless = {},
		rigidConstraint = nil,
		rootWeld = nil,
		mountSocket = mountSocket,
		mountBoneName = mountBoneName,
	}

	setCharacterCollisionEnabled(character, false, riderCharacterState[player])

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			riderCharacterState[player].massless[descendant] = descendant.Massless
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.Massless = true
		end
	end

	humanoid.AutoRotate = false
	humanoid.PlatformStand = false
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.Sit = false

	local startCFrame = root.CFrame * CFrame.new(0, 11.5, 1.5)
	if mountSocket then
		local okSocketCFrame, socketWorld = pcall(function()
			return mountSocket.TransformedWorldCFrame
		end)

		if okSocketCFrame and typeof(socketWorld) == "CFrame" then
			startCFrame = socketWorld
		else
			startCFrame = mountSocket.WorldCFrame
		end
	end

	character:PivotTo(startCFrame)
	characterRoot.AssemblyLinearVelocity = ZERO
	characterRoot.AssemblyAngularVelocity = ZERO

	-- Seat solo para pose/compatibilidad si estÃ¡ activado.
	if useSeatPose then
		riderSeat.CFrame = startCFrame
		riderSeat.AssemblyLinearVelocity = ZERO
		riderSeat.AssemblyAngularVelocity = ZERO
		pcall(function()
			riderSeat:Sit(humanoid)
		end)
	else
		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end)
	end

	local mountedByRigid = false

	-- Intento principal: RigidConstraint desde Bone socket a la cintura.
	if false and mountSocket and waistAttachment then
		local rigid = Instance.new("RigidConstraint")
		rigid.Name = "DragonRiderMountRigidConstraint_" .. tostring(player.UserId)

		local okAssign, err = pcall(function()
			rigid.Attachment0 = mountSocket
			rigid.Attachment1 = waistAttachment
			rigid.Parent = lowerTorso
		end)

		if okAssign and rigid.Attachment0 == mountSocket and rigid.Attachment1 == waistAttachment then
			riderCharacterState[player].rigidConstraint = rigid
			mountedByRigid = true
			print("[DragonRiderBoneConstraint] RigidConstraint creado con bone:", mountBoneName, "socket=", mountSocket:GetFullName(), "waist=", waistAttachment:GetFullName())
		else
			rigid:Destroy()
			warn("[DragonRiderBoneConstraint] RigidConstraint con Bone fallÃ³. Roblox no aceptÃ³ el Bone como Attachment0. Error: " .. tostring(err))
		end
	end

	-- Fallback seguro: RootWeld para no dejar roto el sistema si Bone constraint no funciona.
	if not mountedByRigid then
		local rootWeld = Instance.new("WeldConstraint")
		rootWeld.Name = "DragonRiderRootWeld"
		rootWeld.Part0 = root
		rootWeld.Part1 = characterRoot
		rootWeld.Parent = characterRoot
		riderCharacterState[player].rootWeld = rootWeld
		warn("[DragonRiderBoneConstraint] Usando fallback RootWeld. No es la montura final, pero evita que el jugador quede atrÃ¡s.")
	end

	mountedPlayer = player
	player:SetAttribute("DragonMounted", true)
	player:SetAttribute("DragonMountRole", "Driver")
	player:SetAttribute("DragonMountedState", "MountedGround")
	player:SetAttribute("DragonMountRigVersion", "DragonRiderBoneConstraint_v3")
	player:SetAttribute("DragonMountBoneName", mountBoneName)
	player:SetAttribute("DragonMountMode", mountedByRigid and "BoneRigidConstraint" or "RootWeldFallback")

	dragon:SetAttribute("MountRigVersion", "DragonRiderBoneConstraint_v3")
	dragon:SetAttribute("DriverMountBoneName", mountBoneName)

	mountPrompt.Enabled = false

	print(("[DragonRiderBoneConstraint] Mounted %s mode=%s bone=%s offset=(%.2f, %.2f, %.2f) rot=(%.1f, %.1f, %.1f) useSeatPose=%s"):format(
		player.Name,
		mountedByRigid and "BoneRigidConstraint" or "RootWeldFallback",
		mountBoneName,
		offsetX, offsetY, offsetZ,
		math.deg(rotX), math.deg(rotY), math.deg(rotZ),
		tostring(useSeatPose)
	))

	enterMountedGround(player, "[DragonMount] Mounted BoneConstraint")
end
unmountPlayer = function(player, skipMove)
	if isUnmounting then
		return
	end

	if player ~= mountedPlayer then
		return
	end

	isUnmounting = true

	if activePlayer == player then
		setFlightState("Grounded")
		setConstraintsEnabled(false)
		linearVelocity.VectorVelocity = ZERO
		alignOrientation.CFrame = root.CFrame
		currentSpeed = 0
		currentGroundSpeed = 0
		currentGroundTurnRate = 0
		currentTurnRate = 0
		currentTurnInput = 0
		currentTurnIntensity = 0
		latestInput = defaultInput()
		activePlayer = nil
		setNetworkOwner(nil)
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local characterRoot = character and character:FindFirstChild("HumanoidRootPart")
	local lowerTorso = character and (character:FindFirstChild("LowerTorso") or characterRoot)
	local savedState = riderCharacterState[player]

	if savedState then
		if savedState.mountHeartbeat then
			savedState.mountHeartbeat:Disconnect()
			savedState.mountHeartbeat = nil
		end

		if savedState.rigidConstraint then
			savedState.rigidConstraint:Destroy()
			savedState.rigidConstraint = nil
		end

		if savedState.rootWeld then
			savedState.rootWeld:Destroy()
			savedState.rootWeld = nil
		end
	end

	if characterRoot then
		local weld = characterRoot:FindFirstChild("DragonRiderRootWeld")
		if weld then
			weld:Destroy()
		end
	end

	if lowerTorso then
		for _, obj in ipairs(lowerTorso:GetChildren()) do
			if obj.Name:match("^DragonRiderMountRigidConstraint") then
				obj:Destroy()
			end
		end
	end

	local seatWeld = riderSeat:FindFirstChild("SeatWeld")
	if seatWeld then
		seatWeld:Destroy()
	end

	if humanoid then
		humanoid.Sit = false
	end

	restoreCharacterState(player, character, humanoid)

	if savedState and savedState.massless then
		for part, oldMassless in pairs(savedState.massless) do
			if part and part.Parent and part:IsA("BasePart") then
				part.Massless = oldMassless
			end
		end
	end

	if humanoid then
		if savedState then
			if typeof(savedState.AutoRotate) == "boolean" then
				humanoid.AutoRotate = savedState.AutoRotate
			end
			if typeof(savedState.WalkSpeed) == "number" then
				humanoid.WalkSpeed = savedState.WalkSpeed
			end
			if typeof(savedState.UseJumpPower) == "boolean" then
				humanoid.UseJumpPower = savedState.UseJumpPower
			end
			if typeof(savedState.JumpPower) == "number" then
				humanoid.JumpPower = savedState.JumpPower
			end
			if typeof(savedState.JumpHeight) == "number" then
				humanoid.JumpHeight = savedState.JumpHeight
			end
			if typeof(savedState.PlatformStand) == "boolean" then
				humanoid.PlatformStand = savedState.PlatformStand
			else
				humanoid.PlatformStand = false
			end
		else
			humanoid.AutoRotate = true
			humanoid.PlatformStand = false
		end

		humanoid.Sit = false
	end

	player:SetAttribute("DragonMounted", false)
	player:SetAttribute("DragonMountRole", "")
	player:SetAttribute("DragonMountedState", "Grounded")
	player:SetAttribute("DragonMountRigVersion", "")
	player:SetAttribute("DragonMountBoneName", "")
	player:SetAttribute("DragonMountMode", "")

	mountedPlayer = nil
	mountPrompt.Enabled = true

	if character and not skipMove then
		local mountFolder = dragon:FindFirstChild("MountPoints")
		local dismountPoint = mountFolder and mountFolder:FindFirstChild("DismountRight")
		local dismountCFrame = root.CFrame * CFrame.new(5, 0, 0)

		if dismountPoint and dismountPoint:IsA("BasePart") then
			dismountCFrame = dismountPoint.CFrame
		end

		character:PivotTo(dismountCFrame)

		if characterRoot then
			characterRoot.AssemblyLinearVelocity = ZERO
			characterRoot.AssemblyAngularVelocity = ZERO
		end
	end

	riderCharacterState[player] = nil

	sendDebug(player, "[DragonMount] Unmounted BoneConstraint")
	log(1, "[DragonMount]", "Unmounted BoneConstraint: " .. player.Name)
	print("[DragonRiderBoneConstraint] Unmounted:", player.Name)

	isUnmounting = false
end
local function readInput(packet)
	local clean = defaultInput()

	if typeof(packet) ~= "table" then
		clean.lastUpdate = os.clock()
		return clean
	end

	clean.throttle = sanitizeNumber(packet.throttle, 0, 0, 1)
	clean.brake = sanitizeNumber(packet.brake, 0, 0, 1)
	clean.turn = sanitizeNumber(packet.turn, 0, -1, 1)
	clean.climb = sanitizeNumber(packet.climb, 0, -1, 1)
	clean.boost = packet.boost == true
	clean.cameraLook = sanitizeLook(packet.cameraLook, smoothedLook)
	clean.aimDirection = sanitizeAimDirection(packet.aimDirection, clean.cameraLook)
	clean.visualBankAxis = sanitizeAxis(packet.visualBankAxis, visualMotorBankAxis)
	clean.lastUpdate = os.clock()

	return clean
end

local function getActiveInput()
	if os.clock() - latestInput.lastUpdate <= INPUT_TIMEOUT then
		return latestInput
	end

	local staleSafeInput = defaultInput()
	staleSafeInput.cameraLook = smoothedLook
	staleSafeInput.aimDirection = smoothedLook
	staleSafeInput.visualBankAxis = visualMotorBankAxis
	return staleSafeInput
end

local function startFlight(player)
	if player ~= mountedPlayer then
		sendDebug(player, "You must mount the dragon first")
		log(2, "[DragonFlight]", "Reject startFlight: player is not mounted")
		return
	end

	activePlayer = player
	latestInput = defaultInput()
	latestInput.cameraLook = root.CFrame.LookVector
	latestInput.lastUpdate = os.clock()

	currentSpeed = math.clamp(math.max(root.AssemblyLinearVelocity.Magnitude, math.abs(currentGroundSpeed)), MIN_GLIDE_SPEED, MAX_SPEED)
	flightForward = horizontalUnit(root.CFrame.LookVector, Vector3.new(0, 0, -1))
	targetMoveDirection = flightForward
	smoothedMoveDirection = flightForward
	smoothedLook = flightForward
	visualRotation = CFrame.lookAt(root.Position, root.Position + smoothedMoveDirection, UP).Rotation
	currentBank = 0
	currentTurnRate = 0
	currentTurnInput = 0
	currentYawError = 0
	currentTurnIntensity = 0
	arcadeTurnLogElapsed = 0
	takeoffEndsAt = os.clock() + TAKEOFF_DURATION
	takeoffAnimationComplete = false
	debugElapsed = 0

	root.AssemblyAngularVelocity = ZERO
	currentGroundSpeed = 0
	currentGroundTurnRate = 0
	groundForward = horizontalUnit(root.CFrame.LookVector, groundForward)
	alignOrientation.CFrame = root.CFrame
	linearVelocity.VectorVelocity = smoothedLook * currentSpeed + UP * CLIMB_SPEED

	setNetworkOwner(player)
	setConstraintsEnabled(true)
	setFlightState("Takeoff")
	sendDebug(player)
end

local function requestLanding(player)
	if player ~= activePlayer then
		return
	end

	setFlightState("Landing")
	sendDebug(player)
end

stopFlight = function()
	local previousPlayer = activePlayer

	setConstraintsEnabled(false)
	linearVelocity.VectorVelocity = ZERO
	alignOrientation.CFrame = root.CFrame
	currentSpeed = 0
	currentBank = 0
	currentTurnRate = 0
	currentTurnInput = 0
	currentYawError = 0
	currentTurnIntensity = 0
	currentGroundSpeed = 0
	currentGroundTurnRate = 0
	flightForward = horizontalUnit(root.CFrame.LookVector, Vector3.new(0, 0, -1))
	groundForward = flightForward
	targetMoveDirection = flightForward
	smoothedMoveDirection = flightForward
	smoothedLook = flightForward
	visualRotation = root.CFrame.Rotation
	applyVisualMotorBank()
	if visualMotor then
		visualMotor.Transform = CFrame.identity
	end
	latestInput = defaultInput()
	activePlayer = nil

	setNetworkOwner(nil)

	if previousPlayer and previousPlayer == mountedPlayer then
		enterMountedGround(previousPlayer, "[DragonGround] Returned to MountedGround")
	else
		setFlightState("Grounded")
		if previousPlayer then
			sendDebug(previousPlayer)
		end
	end
end

local function updateFlightState(input)
	if currentState == "Takeoff" then
		local takeoffTrack = tracks.Takeoff
		local takeoffStillPlaying = takeoffTrack and takeoffTrack.IsPlaying
		if takeoffAnimationComplete or (not takeoffStillPlaying and os.clock() >= takeoffEndsAt) then
			setFlightState("Fly")
		end
		return
	end

	if currentState == "Landing" then
		return
	end

	local cameraLook = input.cameraLook or smoothedLook
	local wantsDive = input.boost or (cameraLook.Y < -0.22 and currentSpeed > MAX_SPEED * 0.85)

	if wantsDive then
		setFlightState("Dive")
	elseif input.throttle <= 0.05 then
		setFlightState("Glide")
	else
		setFlightState("Fly")
	end
end

local function getBodyTurnResponsiveness()
	if mountedPlayer then
		if currentState == "Dive" then
			return BODY_TURN_RESPONSIVENESS_DIVE
		end

		return BODY_TURN_RESPONSIVENESS_WHILE_MOUNTED
	end

	return TURN_RESPONSIVENESS
end

local function updateOrientation(dt, input)
	local bodyTurnResponsiveness = getBodyTurnResponsiveness()
	alignOrientation.Responsiveness = bodyTurnResponsiveness
	visualMotorBankAxis = sanitizeAxis(input.visualBankAxis, visualMotorBankAxis)

	local cameraLook = sanitizeLook(input.cameraLook, smoothedMoveDirection)
	local aimLook = sanitizeAimDirection(input.aimDirection, cameraLook or smoothedMoveDirection)
	local desiredFlat = horizontalUnit(aimLook, smoothedMoveDirection)
	local currentFlat = horizontalUnit(smoothedMoveDirection, flightForward)
	local crossY = currentFlat:Cross(desiredFlat).Y
	local dot = math.clamp(currentFlat:Dot(desiredFlat), -1, 1)
	local yawError = math.atan2(crossY, dot)

	local cameraTurn = math.clamp(yawError / math.rad(75), -1, 1)
	local manualTurn = -input.turn
	local desiredTurnInput = math.clamp(
		cameraTurn * CAMERA_TURN_INFLUENCE + manualTurn * MANUAL_TURN_INFLUENCE,
		-1,
		1
	)

	currentYawError = yawError
	currentTurnInput = desiredTurnInput
	currentTurnIntensity = desiredTurnInput

	local targetTurnRate = desiredTurnInput * math.rad(MAX_TURN_RATE_DEGREES)
	local turnAcceleration = math.abs(targetTurnRate) > math.abs(currentTurnRate) and TURN_ACCELERATION or TURN_DECELERATION
	currentTurnRate = moveTowards(currentTurnRate, targetTurnRate, turnAcceleration * dt)

	local yawStep = currentTurnRate * dt
	local rotatedForward = CFrame.fromAxisAngle(UP, yawStep):VectorToWorldSpace(flightForward)
	flightForward = horizontalUnit(rotatedForward, flightForward)

	local pitch = math.clamp(aimLook.Y, -0.55, 0.45)
	targetMoveDirection = flightForward + UP * pitch
	if targetMoveDirection.Magnitude < 0.01 then
		targetMoveDirection = flightForward
	end
	targetMoveDirection = targetMoveDirection.Unit

	local moveAlpha = expAlpha(MOVE_DIRECTION_RESPONSIVENESS, dt)
	smoothedMoveDirection = smoothedMoveDirection:Lerp(targetMoveDirection, moveAlpha)
	if smoothedMoveDirection.Magnitude < 0.01 then
		smoothedMoveDirection = targetMoveDirection
	else
		smoothedMoveDirection = smoothedMoveDirection.Unit
	end
	smoothedLook = smoothedMoveDirection

	local visualAlpha = expAlpha(VISUAL_ROTATION_RESPONSIVENESS, dt)
	local targetVisualRotation = CFrame.lookAt(root.Position, root.Position + smoothedMoveDirection, UP).Rotation
	visualRotation = visualRotation:Lerp(targetVisualRotation, visualAlpha)

	local normalizedTurnRate = math.clamp(currentTurnRate / math.rad(MAX_TURN_RATE_DEGREES), -1, 1)
	local targetBank = ENABLE_FLIGHT_BANK and (-math.rad(MAX_BANK_DEGREES) * normalizedTurnRate) or 0
	currentBank += (targetBank - currentBank) * expAlpha(BANK_RESPONSIVENESS, dt)

	alignOrientation.CFrame = CFrame.new(root.Position) * visualRotation
	applyVisualMotorBank()
end

local function updateVelocity(dt, input)
	local targetSpeed = currentSpeed
	local speedRate = DECELERATION
	local verticalVelocity = input.climb * CLIMB_SPEED
	local velocityDirection = smoothedMoveDirection
	local normalizedTurnRate = math.clamp(currentTurnRate / math.rad(MAX_TURN_RATE_DEGREES), -1, 1)

	if currentState == "Takeoff" then
		targetSpeed = math.max(MIN_GLIDE_SPEED + 20, MAX_SPEED * 0.62)
		speedRate = BOOST_ACCELERATION
		verticalVelocity = CLIMB_SPEED
	elseif currentState == "Landing" then
		targetSpeed = math.max(MIN_GLIDE_SPEED * 0.75, math.min(currentSpeed, 45))
		speedRate = DECELERATION
		verticalVelocity = -LANDING_DESCENT_SPEED
		velocityDirection = horizontalUnit(smoothedMoveDirection, root.CFrame.LookVector)
	elseif currentState == "Dive" then
		targetSpeed = DIVE_SPEED
		speedRate = BOOST_ACCELERATION
		verticalVelocity = -CLIMB_SPEED * 0.75
	elseif input.throttle > 0.05 then
		targetSpeed = input.boost and math.min(DIVE_SPEED, MAX_SPEED + 20) or MAX_SPEED
		speedRate = input.boost and BOOST_ACCELERATION or ACCELERATION
	elseif input.brake > 0.05 then
		targetSpeed = MIN_GLIDE_SPEED * 0.7
		speedRate = DECELERATION
	else
		targetSpeed = math.max(MIN_GLIDE_SPEED, currentSpeed * (GLIDE_DRAG ^ (dt * 60)))
		speedRate = DECELERATION * 0.45
	end

	if currentState ~= "Takeoff" and currentState ~= "Landing" then
		if input.climb > 0.05 then
			targetSpeed = math.max(MIN_GLIDE_SPEED, targetSpeed - 16 * input.climb)
			currentSpeed = math.max(MIN_GLIDE_SPEED, currentSpeed - 7 * input.climb * dt)
		elseif input.climb < -0.05 then
			targetSpeed = math.min(DIVE_SPEED, targetSpeed + 12 * math.abs(input.climb))
		end

		local aimLook = sanitizeAimDirection(input.aimDirection, input.cameraLook or smoothedMoveDirection)
		if aimLook.Y < -0.25 then
			targetSpeed = math.min(DIVE_SPEED, targetSpeed + 18 * math.abs(aimLook.Y))
		end
	end

	local turnLoss = 1 - math.abs(normalizedTurnRate) * TURN_SPEED_LOSS
	targetSpeed *= math.max(MIN_TURN_SPEED_FACTOR, turnLoss)
	currentSpeed = moveTowards(currentSpeed, targetSpeed, speedRate * dt)

	if currentState == "Glide" and input.climb <= 0 then
		local glideY = math.min(velocityDirection.Y, 0.06)
		velocityDirection = (horizontalUnit(smoothedMoveDirection, root.CFrame.LookVector) + UP * glideY).Unit
		verticalVelocity -= 5
	end

	linearVelocity.VectorVelocity = velocityDirection * currentSpeed + UP * verticalVelocity
end

initializeHeadLookController()
initializeDragonNeckLookIK()
loadDragonAnimations()

toggleRemote.OnServerEvent:Connect(function(player)
	if player ~= mountedPlayer then
		sendDebug(player, "Mount the dragon first")
		log(2, "[DragonFlight]", "Reject FlightToggle: player is not mounted")
		return
	end

	log(2, "[DragonFlight]", "FlightToggle accepted for mounted player: " .. player.Name)

	if activePlayer and activePlayer ~= player then
		sendDebug(player, "Dragon already controlled by " .. activePlayer.Name)
		return
	end

	if isGroundMovementState(currentState) or not activePlayer or currentState == "Grounded" then
		startFlight(player)
	elseif currentState == "Landing" then
		setFlightState("Fly")
		sendDebug(player)
	else
		requestLanding(player)
	end
end)

inputRemote.OnServerEvent:Connect(function(player, packet)
	if player ~= mountedPlayer or player ~= activePlayer then
		return
	end

	latestInput = readInput(packet)
end)

unmountRemote.OnServerEvent:Connect(function(player)
	if player == activePlayer and isFlightState(currentState) and currentState ~= "Landing" and not isGrounded() then
		requestLanding(player)
		return
	end

	unmountPlayer(player)
end)

mountPrompt.Triggered:Connect(function(player)
	mountPlayer(player)
end)

riderSeat:GetPropertyChangedSignal("Occupant"):Connect(function()
	if mountedPlayer and not riderSeat.Occupant then
		unmountPlayer(mountedPlayer)
	end
end)


Players.PlayerRemoving:Connect(function(player)
	if player == mountedPlayer then
		unmountPlayer(player, true)
	elseif player == activePlayer then
		stopFlight()
	end
end)

RunService.Heartbeat:Connect(function(rawDt)
	local dt = math.clamp(rawDt, 1 / 240, 1 / 15)

	if not activePlayer then
		updateHeadLook(dt, nil)
		return
	end

	if not activePlayer.Parent then
		stopFlight()
		updateHeadLook(dt, nil)
		return
	end

	local input = getActiveInput()

	if isGroundMovementState(currentState) then
		updateGroundMovement(dt, input)
		updateHeadLook(dt, nil)
	else
		updateFlightState(input)
		updateOrientation(dt, input)
		updateVelocity(dt, input)
		updateAnimationSpeed(currentSpeed)
		updateHeadLook(dt, input.cameraLook)
	end

	arcadeTurnLogElapsed += dt
	if LOG_LEVEL >= 2 and arcadeTurnLogElapsed >= 1.2 then
		arcadeTurnLogElapsed = 0
		log(2, "[DragonFlightV2]", ("smoothedMoveDirection=(%.2f, %.2f, %.2f) yawError=%.1f bankDeg=%.1f visualMotorBankAxis=%s speed=%.1f"):format(
			smoothedMoveDirection.X,
			smoothedMoveDirection.Y,
			smoothedMoveDirection.Z,
			math.deg(currentYawError),
			math.deg(currentBank),
			visualMotorBankAxis,
			currentSpeed
		))
	end

	aimDebugElapsed += dt
	if LOG_LEVEL >= 2 and aimDebugElapsed >= 2 then
		aimDebugElapsed = 0
		local aimDir = sanitizeAimDirection(input.aimDirection, input.cameraLook or smoothedMoveDirection)
		log(2, "[DragonAim]", ("aimDir=(%.2f, %.2f, %.2f) state=%s speed=%.1f"):format(
			aimDir.X,
			aimDir.Y,
			aimDir.Z,
			currentState,
			currentSpeed
		))
	end

	if currentState == "Landing" and isGrounded() and root.AssemblyLinearVelocity.Magnitude < 70 then
		stopFlight()
		return
	end

	debugElapsed += dt
	if debugElapsed >= DEBUG_INTERVAL then
		debugElapsed = 0
		sendDebug(activePlayer)
	end
end)

print("[DragonFlight] AimDirection enabled")
print("[DragonFlight] Service ready for Workspace.DragonModel using LinearVelocity and AlignOrientation.")