local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local DRAGON_NAME = "DragonModel"
local ENABLE_DRAGON_SERPENT_TURN = false
local AUTO_CALIBRATE_SERPENT_TURN = true
local SERPENT_DEBUG = true

local SERPENT_TURN_AXIS = "Y"
local SERPENT_TURN_SIGN = 1
local MAX_SERPENT_TURN_DEGREES = 70
local SERPENT_RETURN_RESPONSE = 5.0
local SERPENT_INPUT_RESPONSE = 8.0
local AUTO_CALIBRATE_TURN_DEGREES = 45
local AUTO_CALIBRATE_EPSILON = 0.01
local DEBUG_INTERVAL = 1.0

local SERPENT_BONES = {
	{ name = "Bip01-Spine_64", weight = 0.18, response = 4.0, phase = 0.65 },
	{ name = "Bip01-Spine1_53", weight = 0.42, response = 5.2, phase = 1.00 },
	{ name = "Bip01-Spine2_52", weight = 0.34, response = 6.8, phase = 1.15 },

	{ name = "Bip01-Pelvis_71", weight = -0.16, response = 3.2, phase = 0.45 },

	{ name = "tail_Bone001_70", weight = -0.45, response = 5.0, phase = 1.00 },
	{ name = "tail_Bone002_69", weight = -0.72, response = 6.0, phase = 1.20 },
}

local player = Players.LocalPlayer
local dragon = nil
local root = nil
local entries = {}
local entryByName = {}
local applied = {}
local serpentIntent = 0
local debugAccumulator = 0
local autoCalibrated = false
local autoCalibrating = false

local function axisRotation(axis, angle)
	if axis == "X" then
		return CFrame.Angles(angle, 0, 0)
	elseif axis == "Y" then
		return CFrame.Angles(0, angle, 0)
	elseif axis == "Z" then
		return CFrame.Angles(0, 0, angle)
	end

	return CFrame.identity
end

local function applyAdditive(bone, additive)
	local previous = applied[bone] or CFrame.identity
	local base = bone.Transform * previous:Inverse()
	bone.Transform = base * additive
	applied[bone] = additive
end

local function clearAppliedTransforms()
	for bone, previous in pairs(applied) do
		if bone and bone.Parent then
			local base = bone.Transform * previous:Inverse()
			bone.Transform = base
		end
	end
	table.clear(applied)
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
	return state ~= "Grounded" and state ~= ""
end

local function rebuildEntries()
	entries = {}
	entryByName = {}
	clearAppliedTransforms()

	for _, config in ipairs(SERPENT_BONES) do
		local bone = findBone(config.name)
		if bone then
			local entry = {
				bone = bone,
				name = config.name,
				weight = config.weight,
				response = config.response,
				phase = config.phase or 1,
				current = 0,
			}
			table.insert(entries, entry)
			entryByName[config.name] = entry
		else
			warn("[DragonSerpentTurn] Missing bone: " .. config.name)
		end
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
	print("[DragonSerpentTurn] Ready. A/D drives procedural body turn + banking + tail counterbalance.")
	return true
end

local function applySerpentSample(axis, sign, amount)
	local turnRadians = math.rad(AUTO_CALIBRATE_TURN_DEGREES) * amount

	for _, entry in ipairs(entries) do
		local target = turnRadians * entry.weight * entry.phase
		applyAdditive(entry.bone, axisRotation(axis, target * sign))
	end
end

local function runAutoCalibrate()
	if autoCalibrating or autoCalibrated or not root then
		return
	end

	local spine1 = entryByName["Bip01-Spine1_53"]
	local spine2 = entryByName["Bip01-Spine2_52"]
	local tail2 = entryByName["tail_Bone002_69"]
	if not spine1 or not spine2 or not tail2 then
		warn("[DragonSerpentTurn][AutoCalib] Missing required measure bones.")
		autoCalibrated = true
		return
	end

	autoCalibrating = true
	local tests = {
		{ axis = "Y", sign = 1 },
		{ axis = "Y", sign = -1 },
		{ axis = "X", sign = 1 },
		{ axis = "X", sign = -1 },
		{ axis = "Z", sign = 1 },
		{ axis = "Z", sign = -1 },
	}

	local bestAxis = SERPENT_TURN_AXIS
	local bestSign = SERPENT_TURN_SIGN
	local bestScore = -math.huge

	task.spawn(function()
		RunService.RenderStepped:Wait()

		for _, test in ipairs(tests) do
			clearAppliedTransforms()
			RunService.RenderStepped:Wait()

			local spine1Before = spine1.bone.TransformedWorldCFrame.Position
			local spine2Before = spine2.bone.TransformedWorldCFrame.Position
			local tail2Before = tail2.bone.TransformedWorldCFrame.Position
			applySerpentSample(test.axis, test.sign, 1)
			RunService.RenderStepped:Wait()

			local rightVector = root.CFrame.RightVector
			local spine1After = spine1.bone.TransformedWorldCFrame.Position
			local spine2After = spine2.bone.TransformedWorldCFrame.Position
			local tail2After = tail2.bone.TransformedWorldCFrame.Position
			local chestScore = rightVector:Dot(spine2After - spine2Before) + 0.35 * rightVector:Dot(spine1After - spine1Before)
			local tailScore = -rightVector:Dot(tail2After - tail2Before)
			local score = chestScore + tailScore

			print(("[DragonSerpentTurn][AutoCalib] axis=%s sign=%d score=%.4f chest=%.4f tail=%.4f"):format(
				test.axis,
				test.sign,
				score,
				chestScore,
				tailScore
			))

			if score > bestScore then
				bestScore = score
				bestAxis = test.axis
				bestSign = test.sign
			end
		end

		clearAppliedTransforms()
		SERPENT_TURN_AXIS = bestAxis
		SERPENT_TURN_SIGN = bestSign
		autoCalibrated = true
		autoCalibrating = false

		print(("[DragonSerpentTurn][AutoCalib] BEST axis=%s sign=%d score=%.4f"):format(
			SERPENT_TURN_AXIS,
			SERPENT_TURN_SIGN,
			bestScore
		))

		if math.abs(bestScore) < AUTO_CALIBRATE_EPSILON then
			warn("[DragonSerpentTurn][DIAG] Bone.Transform changes are not visibly moving the mesh enough.")
		end
	end)
end

local function getManualTurn()
	local left = UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0
	local right = UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0
	return right - left
end

local function updateSerpentTurn(dt)
	local state = getMountedState()
	local mounted = isMountedState(state)
	local manualTurn = getManualTurn()
	local targetIntent = mounted and manualTurn or 0
	local response = math.abs(targetIntent) > 0.05 and SERPENT_INPUT_RESPONSE or SERPENT_RETURN_RESPONSE
	serpentIntent += (targetIntent - serpentIntent) * (1 - math.exp(-response * dt))

	if autoCalibrating then
		return state, manualTurn
	end

	for _, entry in ipairs(entries) do
		local target = serpentIntent * math.rad(MAX_SERPENT_TURN_DEGREES) * entry.weight * entry.phase
		entry.current += (target - entry.current) * (1 - math.exp(-entry.response * dt))

		local additive = axisRotation(SERPENT_TURN_AXIS, entry.current * SERPENT_TURN_SIGN)
		applyAdditive(entry.bone, additive)
	end

	if not mounted and math.abs(serpentIntent) < 0.001 then
		local shouldClear = true
		for _, entry in ipairs(entries) do
			if math.abs(entry.current) >= 0.001 then
				shouldClear = false
				break
			end
		end
		if shouldClear then
			clearAppliedTransforms()
		end
	end

	return state, manualTurn
end

if not ENABLE_DRAGON_SERPENT_TURN then
	return
end

local initialized = false
RunService.RenderStepped:Connect(function(dt)
	if not initialized then
		initialized = tryInitialize()
		return
	end

	if AUTO_CALIBRATE_SERPENT_TURN and not autoCalibrated and not autoCalibrating then
		runAutoCalibrate()
	end

	local state, manualTurn = updateSerpentTurn(dt)

	debugAccumulator += dt
	if SERPENT_DEBUG and debugAccumulator >= DEBUG_INTERVAL then
		debugAccumulator = 0
		local spine1 = entryByName["Bip01-Spine1_53"]
		local spine2 = entryByName["Bip01-Spine2_52"]
		local tail2 = entryByName["tail_Bone002_69"]
		print(("[DragonSerpentTurn] state=%s manualTurn=%.2f intent=%.2f axis=%s sign=%d spine1=%.1f spine2=%.1f tail2=%.1f"):format(
			state,
			manualTurn,
			serpentIntent,
			SERPENT_TURN_AXIS,
			SERPENT_TURN_SIGN,
			math.deg(spine1 and spine1.current or 0),
			math.deg(spine2 and spine2.current or 0),
			math.deg(tail2 and tail2.current or 0)
		))
	end
end)
