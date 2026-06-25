local ENABLE_DRAGON_BODY_CURL = false
if not ENABLE_DRAGON_BODY_CURL then
	return
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local DRAGON_NAME = "DragonModel"
local MAX_BODY_CURL_DEGREES = 65
local BODY_CURL_AXIS = "Y"
local BODY_CURL_SIGN = 1
local BODY_CURL_AUTO_CALIBRATE = true
local BODY_CURL_DEBUG = true
local BODY_CURL_TEST_KEY = Enum.KeyCode.U
local GROUND_CURL_SCALE = 1.0
local FLIGHT_CURL_SCALE = 0.45

local BODY_CURL_BONES = {
	{ name = "Bip01-Pelvis_71", yawWeight = -0.12, channel = "pelvis" },
	{ name = "Bip01-Spine_64", yawWeight = 0.18, channel = "chest" },
	{ name = "Bip01-Spine1_53", yawWeight = 0.28, channel = "chest" },
	{ name = "Bip01-Spine2_52", yawWeight = 0.38, channel = "chest" },
	{ name = "tail_Bone001_70", yawWeight = -0.45, channel = "tail" },
	{ name = "tail_Bone002_69", yawWeight = -0.70, channel = "tail" },
}

local player = Players.LocalPlayer
local chestCurl = 0
local pelvisCurl = 0
local tailCurl = 0
local entries = {}
local entryByName = {}
local applied = {}
local ready = false
local warned = {}
local debugElapsed = 0
local bestScore = 0
local autoCalibrated = false
local autoCalibrating = false

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

local function signedYawBetween(fromDir, toDir)
	local fromFlat = Vector3.new(fromDir.X, 0, fromDir.Z)
	local toFlat = Vector3.new(toDir.X, 0, toDir.Z)

	if fromFlat.Magnitude < 0.01 or toFlat.Magnitude < 0.01 then
		return 0
	end

	fromFlat = fromFlat.Unit
	toFlat = toFlat.Unit

	local crossY = fromFlat:Cross(toFlat).Y
	local dot = math.clamp(fromFlat:Dot(toFlat), -1, 1)
	return math.atan2(crossY, dot)
end

local function initialize()
	if ready then
		return
	end

	local mesh = getMesh()
	if not mesh then
		return
	end

	entries = {}
	entryByName = {}
	for _, config in ipairs(BODY_CURL_BONES) do
		local bone = findBone(config.name)
		if bone then
			local entry = {
				bone = bone,
				name = config.name,
				yawWeight = config.yawWeight,
				channel = config.channel,
			}
			table.insert(entries, entry)
			entryByName[config.name] = entry
		else
			warnOnce("missing_" .. config.name, "[DragonBodyCurl][WARN] missing bone " .. config.name)
		end
	end

	ready = true
	print("[DragonBodyCurl] Ready")
end

local function applyCurlTransform(bone, additive)
	local previous = applied[bone] or CFrame.identity
	local base = bone.Transform * previous:Inverse()
	bone.Transform = base * additive
	applied[bone] = additive
end

local function clearTransforms()
	for bone, previous in pairs(applied) do
		if bone and bone.Parent then
			bone.Transform = bone.Transform * previous:Inverse()
		end
		applied[bone] = nil
	end
end

local function applyEntryCurl(entry, amount)
	local additive = axisRotation(BODY_CURL_AXIS, amount)
	applyCurlTransform(entry.bone, additive)
end

local function applyCurlValues(chest, pelvis, tail)
	local maxCurl = math.rad(MAX_BODY_CURL_DEGREES)
	for _, entry in ipairs(entries) do
		local channelCurl = chest
		if entry.channel == "pelvis" then
			channelCurl = pelvis
		elseif entry.channel == "tail" then
			channelCurl = tail
		end

		local amount = channelCurl * maxCurl * entry.yawWeight * BODY_CURL_SIGN
		applyEntryCurl(entry, amount)
	end
end

local function isGroundState(state)
	return state == "MountedGround" or state == "GroundWalk" or state == "GroundTrot"
end

local function isMountedState(state)
	return state ~= nil and state ~= "" and state ~= "Grounded"
end

local function getBonePosition(name)
	local entry = entryByName[name]
	local bone = entry and entry.bone
	return bone and bone.TransformedWorldCFrame.Position or nil
end

local function runBodyCurlAutoCalibrate()
	if autoCalibrating then
		return
	end
	initialize()
	local root = getRoot()
	if not ready or not root or #entries == 0 then
		return
	end

	autoCalibrating = true
	task.spawn(function()
		local tests = {
			{ axis = "X", sign = 1 },
			{ axis = "X", sign = -1 },
			{ axis = "Y", sign = 1 },
			{ axis = "Y", sign = -1 },
			{ axis = "Z", sign = 1 },
			{ axis = "Z", sign = -1 },
		}
		local originalAxis = BODY_CURL_AXIS
		local originalSign = BODY_CURL_SIGN
		local bestAxis = originalAxis
		local bestSign = originalSign
		local best = -math.huge

		for _, test in ipairs(tests) do
			BODY_CURL_AXIS = test.axis
			BODY_CURL_SIGN = test.sign
			clearTransforms()
			RunService.RenderStepped:Wait()

			local pelvisBefore = getBonePosition("Bip01-Pelvis_71")
			local spine2Before = getBonePosition("Bip01-Spine2_52")
			local tail2Before = getBonePosition("tail_Bone002_69")
			applyCurlValues(1, 1, -1)
			RunService.RenderStepped:Wait()
			RunService.RenderStepped:Wait()

			local pelvisAfter = getBonePosition("Bip01-Pelvis_71")
			local spine2After = getBonePosition("Bip01-Spine2_52")
			local tail2After = getBonePosition("tail_Bone002_69")
			local right = root.CFrame.RightVector
			local chestDeltaRight = (spine2Before and spine2After) and right:Dot(spine2After - spine2Before) or 0
			local tailDeltaRight = (tail2Before and tail2After) and right:Dot(tail2After - tail2Before) or 0
			local pelvisDeltaRight = (pelvisBefore and pelvisAfter) and right:Dot(pelvisAfter - pelvisBefore) or 0
			local score = chestDeltaRight - tailDeltaRight - math.abs(pelvisDeltaRight) * 0.35
			print(("[DragonBodyCurl][AutoCalib] axis=%s sign=%d score=%.4f"):format(test.axis, test.sign, score))

			if score > best then
				best = score
				bestAxis = test.axis
				bestSign = test.sign
			end
			clearTransforms()
			RunService.RenderStepped:Wait()
		end

		BODY_CURL_AXIS = bestAxis
		BODY_CURL_SIGN = bestSign
		bestScore = best
		autoCalibrated = true
		autoCalibrating = false
		print(("[DragonBodyCurl][AutoCalib] BEST axis=%s sign=%d score=%.4f"):format(BODY_CURL_AXIS, BODY_CURL_SIGN, bestScore))
	end)
end

local function update(dt)
	initialize()
	if not ready then
		return
	end
	if #entries == 0 then
		if BODY_CURL_DEBUG then
			warnOnce("no_bones_diag", "[DragonBodyCurl][DIAG] No bones found")
		end
		return
	end

	if BODY_CURL_AUTO_CALIBRATE and not autoCalibrated and not autoCalibrating then
		runBodyCurlAutoCalibrate()
	end
	if autoCalibrating then
		return
	end

	local root = getRoot()
	if not root then
		clearTransforms()
		return
	end

	local state = tostring(player:GetAttribute("DragonMountedState") or "Grounded")
	local groundForward = getAttributeVector("DragonGroundForward", root.CFrame.LookVector)
	local aimDirection = getAttributeVector("DragonAimDirection", groundForward)
	local aimYaw = signedYawBetween(groundForward, aimDirection)
	local aimCurl = math.clamp(aimYaw / math.rad(70), -1, 1)

	local turnInput = player:GetAttribute("DragonTurnInput") or 0
	local uTurnIntent = player:GetAttribute("DragonUTurnIntent") or 0
	if typeof(turnInput) ~= "number" or turnInput ~= turnInput then
		turnInput = 0
	end
	if typeof(uTurnIntent) ~= "number" or uTurnIntent ~= uTurnIntent then
		uTurnIntent = 0
	end

	local scale = isGroundState(state) and GROUND_CURL_SCALE or FLIGHT_CURL_SCALE
	local targetCurl = 0
	if isMountedState(state) then
		targetCurl = math.clamp(aimCurl + turnInput * 0.35 + uTurnIntent * 0.85, -1, 1) * scale
	end

	chestCurl += (targetCurl - chestCurl) * (1 - math.exp(-10 * dt))
	pelvisCurl += (targetCurl - pelvisCurl) * (1 - math.exp(-4 * dt))
	tailCurl += ((-targetCurl) - tailCurl) * (1 - math.exp(-7 * dt))

	if math.abs(chestCurl) < 0.001 and math.abs(pelvisCurl) < 0.001 and math.abs(tailCurl) < 0.001 and targetCurl == 0 then
		chestCurl = 0
		pelvisCurl = 0
		tailCurl = 0
		clearTransforms()
	else
		applyCurlValues(chestCurl, pelvisCurl, tailCurl)
	end

	if BODY_CURL_DEBUG then
		debugElapsed += dt
		if debugElapsed >= 1 then
			debugElapsed = 0
			print(("[DragonBodyCurl] state=%s aimCurl=%.2f turn=%.2f uTurn=%.2f target=%.2f chest=%.2f pelvis=%.2f tail=%.2f axis=%s sign=%d entries=%d"):format(
				state,
				aimCurl,
				turnInput,
				uTurnIntent,
				targetCurl,
				chestCurl,
				pelvisCurl,
				tailCurl,
				BODY_CURL_AXIS,
				BODY_CURL_SIGN,
				#entries
			))

			if #entries == 0 then
				warn("[DragonBodyCurl][DIAG] No bones found")
			elseif math.abs(targetCurl) > 0.5 and math.abs(chestCurl) < 0.05 then
				warn("[DragonBodyCurl][DIAG] Curl input exists but smoothing/output is not moving")
			elseif math.abs(chestCurl) > 0.5 and bestScore < 0.01 then
				warn("[DragonBodyCurl][DIAG] Bone.Transform is changing but mesh deformation may be weak / wrong bones / wrong axis")
			end
		end
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == BODY_CURL_TEST_KEY then
		autoCalibrated = false
		runBodyCurlAutoCalibrate()
	end
end)

RunService.RenderStepped:Connect(update)
