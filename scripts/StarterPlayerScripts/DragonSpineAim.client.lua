local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DRAGON_NAME = "DragonModel"
local ENABLE_DRAGON_SPINE_AIM = false
local AUTO_CALIBRATE_SPINE_AIM = true
local SPINE_AIM_DEBUG = true

local SPINE_YAW_AXIS = "Z"
local SPINE_YAW_SIGN = 1
local SPINE_PITCH_AXIS = "X"
local SPINE_PITCH_SIGN = 1
local SPINE_CALIBRATION_BONE_NAME = "Bip01-Spine1_53"
local SPINE_CALIBRATION_MEASURE_BONE_NAME = "Bip01-Neck_32"

local MAX_SPINE_YAW = math.rad(24)
local MAX_SPINE_PITCH_UP = math.rad(14)
local MAX_SPINE_PITCH_DOWN = math.rad(12)
local YAW_RESPONSIVENESS = 5.5
local PITCH_RESPONSIVENESS = 5.0
local TEST_YAW_DEGREES = 24
local SPINE_AIM_PROFILE = "Spine1Main"

local SPINE_AIM_PROFILES = {
	Spine1Main = {
		{
			name = "Bip01-Spine1_53",
			yawWeight = 0.38,
			pitchWeight = 0.12,
			yawResponse = 4.2,
			pitchResponse = 4.0,
		},

		{
			name = "Bip01-Spine2_52",
			yawWeight = 0.20,
			pitchWeight = 0.08,
			yawResponse = 6.0,
			pitchResponse = 5.5,
		},
	},

	UpperSpineOnly = {
		{
			name = "Bip01-Spine1_53",
			yawWeight = 0.30,
			pitchWeight = 0.10,
			yawResponse = 4.5,
			pitchResponse = 4.2,
		},

		{
			name = "Bip01-Spine2_52",
			yawWeight = 0.26,
			pitchWeight = 0.10,
			yawResponse = 6.0,
			pitchResponse = 5.5,
		},
	},

	FullSoftSpine = {
		{
			name = "Bip01-Spine_64",
			yawWeight = 0.06,
			pitchWeight = 0.03,
			yawResponse = 3.4,
			pitchResponse = 3.2,
		},

		{
			name = "Bip01-Spine1_53",
			yawWeight = 0.24,
			pitchWeight = 0.08,
			yawResponse = 4.2,
			pitchResponse = 4.0,
		},

		{
			name = "Bip01-Spine2_52",
			yawWeight = 0.22,
			pitchWeight = 0.08,
			yawResponse = 5.8,
			pitchResponse = 5.4,
		},
	},
}

local player = Players.LocalPlayer
local entries = {}
local entryByName = {}
local applied = {}
local warned = {}
local ready = false
local autoCalibrated = false
local autoCalibrating = false
local bestScore = 0
local debugElapsed = 0
local hierarchyReported = false

local function warnOnce(key, message)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(message)
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

local function axisRotation(axisName, amount)
	if axisName == "X" then
		return CFrame.Angles(amount, 0, 0)
	elseif axisName == "Y" then
		return CFrame.Angles(0, amount, 0)
	end
	return CFrame.Angles(0, 0, amount)
end

local function getAttributeVector(prefix, fallback)
	local x = player:GetAttribute(prefix .. "X")
	local y = player:GetAttribute(prefix .. "Y")
	local z = player:GetAttribute(prefix .. "Z")

	if typeof(x) == "number" and typeof(y) == "number" and typeof(z) == "number" then
		local v = Vector3.new(x, y, z)
		if v.Magnitude > 0.01 then
			return v.Unit
		end
	end

	return fallback
end

local function applyAdditive(bone, additive)
	local previous = applied[bone] or CFrame.identity
	local base = bone.Transform * previous:Inverse()
	bone.Transform = base * additive
	applied[bone] = additive
end

local function clearAdditives()
	for bone, previous in pairs(applied) do
		if bone and bone.Parent then
			bone.Transform = bone.Transform * previous:Inverse()
		end
		applied[bone] = nil
	end
end

local function isAncestorOf(a, b)
	local current = b
	while current do
		if current == a then
			return true
		end
		current = current.Parent
	end
	return false
end

local function formatVector(position)
	return ("(%.2f, %.2f, %.2f)"):format(position.X, position.Y, position.Z)
end

local function reportBoneHierarchy()
	if hierarchyReported then
		return
	end

	local head = findBone("Bip01-Head_8")
	local neck = findBone("Bip01-Neck_32")
	if not head or not neck then
		return
	end

	local boneNames = {
		"Bip01-Pelvis_71",
		"Bip01-Spine_64",
		"Bip01-Spine1_53",
		"Bip01-Spine2_52",
		"Bip01-Neck_32",
		"Bip01-Neck1_11",
		"Bip01-Neck2_10",
		"Bip01-Neck3_9",
		"Bip01-Head_8",
	}

	local bones = {}
	for _, boneName in ipairs(boneNames) do
		local bone = findBone(boneName)
		bones[boneName] = bone
		if bone then
			local position = bone.TransformedWorldCFrame.Position
			local headDistance = (position - head.TransformedWorldCFrame.Position).Magnitude
			local neckDistance = (position - neck.TransformedWorldCFrame.Position).Magnitude
			local parentName = bone.Parent and bone.Parent.Name or "nil"
			print(("[DragonSpineAim][Hierarchy] %s full=%s parent=%s pos=%s distHead=%.2f distNeck=%.2f"):format(
				bone.Name,
				bone:GetFullName(),
				parentName,
				formatVector(position),
				headDistance,
				neckDistance
			))
		else
			print(("[DragonSpineAim][Hierarchy] %s missing"):format(boneName))
		end
	end

	local spine = bones["Bip01-Spine_64"]
	local spine1 = bones["Bip01-Spine1_53"]
	local spine2 = bones["Bip01-Spine2_52"]
	print(("[DragonSpineAim][Hierarchy] Spine_64 -> Spine1_53 = %s"):format(tostring(spine and spine1 and isAncestorOf(spine, spine1) or false)))
	print(("[DragonSpineAim][Hierarchy] Spine1_53 -> Spine2_52 = %s"):format(tostring(spine1 and spine2 and isAncestorOf(spine1, spine2) or false)))
	print(("[DragonSpineAim][Hierarchy] Spine2_52 -> Neck_32 = %s"):format(tostring(spine2 and neck and isAncestorOf(spine2, neck) or false)))	hierarchyReported = true
end

local function initialize()
	if ready then
		return
	end

	if not getMesh() then
		return
	end

	reportBoneHierarchy()

	entries = {}
	entryByName = {}
	local selectedProfile = SPINE_AIM_PROFILES[SPINE_AIM_PROFILE] or SPINE_AIM_PROFILES.Spine1Main
	for _, config in ipairs(selectedProfile) do
		local bone = findBone(config.name)
		if bone then
			local entry = {
				bone = bone,
				name = config.name,
				yawWeight = config.yawWeight,
				pitchWeight = config.pitchWeight,
				yawResponse = config.yawResponse or YAW_RESPONSIVENESS,
				pitchResponse = config.pitchResponse or PITCH_RESPONSIVENESS,
				currentYaw = 0,
				currentPitch = 0,
			}
			table.insert(entries, entry)
			entryByName[entry.name] = entry
		else
			warnOnce("missing_" .. config.name, "[DragonSpineAim][WARN] missing bone " .. config.name)
		end
	end

	ready = true
	print("[DragonSpineAim] Ready profile=" .. SPINE_AIM_PROFILE)
end

local function isMountedState(state)
	return state ~= nil and state ~= "" and state ~= "Grounded"
end

local function applyEntryAim(entry, targetYaw, targetPitch, dt)
	local targetEntryYaw = targetYaw * entry.yawWeight
	local targetEntryPitch = targetPitch * entry.pitchWeight
	entry.currentYaw += (targetEntryYaw - entry.currentYaw) * (1 - math.exp(-entry.yawResponse * dt))
	entry.currentPitch += (targetEntryPitch - entry.currentPitch) * (1 - math.exp(-entry.pitchResponse * dt))

	local yawCf = axisRotation(SPINE_YAW_AXIS, entry.currentYaw * SPINE_YAW_SIGN)
	local pitchCf = axisRotation(SPINE_PITCH_AXIS, entry.currentPitch * SPINE_PITCH_SIGN)
	applyAdditive(entry.bone, pitchCf * yawCf)
end

local function applyAllEntries(targetYaw, targetPitch, dt)
	for _, entry in ipairs(entries) do
		applyEntryAim(entry, targetYaw, targetPitch, dt)
	end
end

local function areEntriesAtRest()
	for _, entry in ipairs(entries) do
		if math.abs(entry.currentYaw) >= 0.001 or math.abs(entry.currentPitch) >= 0.001 then
			return false
		end
	end
	return true
end

local function runSpineAimAutoCalibrate()
	if autoCalibrating then
		return
	end
	initialize()
	local root = getRoot()
	local testBone = findBone(SPINE_CALIBRATION_BONE_NAME)
	local measureBone = findBone(SPINE_CALIBRATION_MEASURE_BONE_NAME)
	if not ready or not root or not testBone or not measureBone then
		return
	end

	autoCalibrating = true
	task.spawn(function()
		print(("[DragonSpineAim][AutoCalib] calibrationBone=%s measureBone=%s"):format(SPINE_CALIBRATION_BONE_NAME, SPINE_CALIBRATION_MEASURE_BONE_NAME))
		local tests = {
			{ axis = "Y", sign = 1 },
			{ axis = "Y", sign = -1 },
			{ axis = "X", sign = 1 },
			{ axis = "X", sign = -1 },
			{ axis = "Z", sign = 1 },
			{ axis = "Z", sign = -1 },
		}
		local bestAxis = SPINE_YAW_AXIS
		local bestSign = SPINE_YAW_SIGN
		local best = -math.huge

		for _, test in ipairs(tests) do
			clearAdditives()
			RunService.RenderStepped:Wait()
			local before = measureBone.TransformedWorldCFrame.Position
			local additive = axisRotation(test.axis, math.rad(TEST_YAW_DEGREES) * test.sign)
			applyAdditive(testBone, additive)
			RunService.RenderStepped:Wait()
			RunService.RenderStepped:Wait()
			local after = measureBone.TransformedWorldCFrame.Position
			local score = root.CFrame.RightVector:Dot(after - before)
			if SPINE_AIM_DEBUG then
				print(("[DragonSpineAim][AutoCalib] yawAxis=%s sign=%d score=%.4f"):format(test.axis, test.sign, score))
			end
			if score > best then
				best = score
				bestAxis = test.axis
				bestSign = test.sign
			end
			clearAdditives()
			RunService.RenderStepped:Wait()
		end

		SPINE_YAW_AXIS = bestAxis
		SPINE_YAW_SIGN = bestSign
		bestScore = best
		autoCalibrated = true
		autoCalibrating = false
		print(("[DragonSpineAim][AutoCalib] BEST yawAxis=%s sign=%d score=%.4f"):format(SPINE_YAW_AXIS, SPINE_YAW_SIGN, bestScore))
		if math.abs(bestScore) < 0.01 then
			warn("[DragonSpineAim][DIAG] Spine bones may not strongly deform upper body.")
		end
	end)
end

local function update(dt)
	if not ENABLE_DRAGON_SPINE_AIM then
		clearAdditives()
		return
	end

	initialize()
	if not ready or #entries == 0 then
		return
	end

	if AUTO_CALIBRATE_SPINE_AIM and not autoCalibrated and not autoCalibrating then
		runSpineAimAutoCalibrate()
	end
	if autoCalibrating then
		return
	end

	local root = getRoot()
	if not root then
		clearAdditives()
		return
	end

	local state = tostring(player:GetAttribute("DragonMountedState") or "Grounded")
	local targetYaw = 0
	local targetPitch = 0
	if isMountedState(state) then
		local aimDirection = getAttributeVector("DragonAimDirection", root.CFrame.LookVector)
		local localDir = root.CFrame:VectorToObjectSpace(aimDirection)
		targetYaw = math.atan2(localDir.X, -localDir.Z)
		targetPitch = math.atan2(localDir.Y, math.sqrt(localDir.X * localDir.X + localDir.Z * localDir.Z))
		targetYaw = math.clamp(targetYaw, -MAX_SPINE_YAW, MAX_SPINE_YAW)
		targetPitch = math.clamp(targetPitch, -MAX_SPINE_PITCH_DOWN, MAX_SPINE_PITCH_UP)
	end

	applyAllEntries(targetYaw, targetPitch, dt)
	if not isMountedState(state) and areEntriesAtRest() then
		clearAdditives()
	end

	if SPINE_AIM_DEBUG then
		debugElapsed += dt
		if debugElapsed >= 1 then
			debugElapsed = 0
			local spine1 = entryByName["Bip01-Spine1_53"]
			local spine2 = entryByName["Bip01-Spine2_52"]
			print(("[DragonSpineAim] profile=%s targetYaw=%.1f targetPitch=%.1f spine1Yaw=%.1f spine2Yaw=%.1f axis=%s sign=%d"):format(
				SPINE_AIM_PROFILE,
				math.deg(targetYaw),
				math.deg(targetPitch),
				math.deg(spine1 and spine1.currentYaw or 0),
				math.deg(spine2 and spine2.currentYaw or 0),
				SPINE_YAW_AXIS,
				SPINE_YAW_SIGN
			))
		end
	end
end

RunService.RenderStepped:Connect(update)
