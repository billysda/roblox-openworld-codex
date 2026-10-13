-- DragonRearFootIK.client.lua
-- Rear foot IK phase 1: low-weight visual toe correction on ground only.
-- Does NOT touch root, HumanoidRootPart, DragonGroundCollider, physics, or animation playback.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local DRAGON_NAME = "DragonModel"
local TARGET_FOLDER_NAME = "DragonRearFootIKTargets"
local RENDER_STEP_NAME = "DragonRearFootIK_Late"
local RENDER_PRIORITY = Enum.RenderPriority.Last.Value - 10

local IK_WEIGHT = 0.18
local MAX_VERTICAL_CORRECTION = 1.25
local SMOOTH_SPEED = 10
local LOG_INTERVAL = 1.0
local RAY_UP = 8
local RAY_DOWN = 26
local SHOW_TARGETS = false

local COLOR_TOE = Color3.fromRGB(255, 60, 60)
local COLOR_GROUND = Color3.fromRGB(60, 255, 90)
local COLOR_TARGET = Color3.fromRGB(70, 220, 255)
local COLOR_RAY = Color3.fromRGB(255, 245, 80)

local FEET = {
	RearLeft = {
		label = "RL",
		boneName = "Bip01-L-Toe0_54",
	},
	RearRight = {
		label = "RR",
		boneName = "Bip01-R-Toe0_59",
	},
}

local dragon = nil
local mesh = nil
local targetsFolder = nil
local entries = {}
local applied = {}
local initialized = false
local readyPrinted = false
local logElapsed = 0
local lastLogRL = { err = 0, applied = 0 }
local lastLogRR = { err = 0, applied = 0 }

local function getMountedState()
	return tostring(player:GetAttribute("DragonMountedState") or "Grounded")
end

local function isMounted()
	return player:GetAttribute("DragonMounted") == true
end

local function isGroundState(state)
	return state == "MountedGround" or state == "GroundWalk" or state == "GroundTrot" or state == "GroundBack"
end

local function isActive()
	return isMounted() and isGroundState(getMountedState())
end

local function expSmooth(current, target, speed, dt)
	local alpha = 1 - math.exp(-speed * dt)
	return current + (target - current) * alpha
end

local function ensureFolder()
	targetsFolder = Workspace:FindFirstChild(TARGET_FOLDER_NAME)
	if not targetsFolder then
		targetsFolder = Instance.new("Folder")
		targetsFolder.Name = TARGET_FOLDER_NAME
		targetsFolder.Parent = Workspace
	end
	return targetsFolder
end

local function makePart(name, color, size, shape)
	local parent = ensureFolder()
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
	return part
end

local function setTargetsVisible(visible)
	if not targetsFolder then
		return
	end
	local transparency = visible and (SHOW_TARGETS and 0.12 or 1) or 1
	for _, child in ipairs(targetsFolder:GetDescendants()) do
		if child:IsA("BasePart") then
			child.Transparency = transparency
		end
	end
end

local function clearTargetsFolder()
	local folder = Workspace:FindFirstChild(TARGET_FOLDER_NAME)
	if folder then
		folder:Destroy()
	end
	targetsFolder = nil
end

local function findBone(name)
	if not mesh then
		return nil
	end
	local found = mesh:FindFirstChild(name, true)
	if found and found:IsA("Bone") then
		return found
	end
	return nil
end

local function buildRaycastParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { dragon }
	return params
end

local function raycastDown(position)
	local origin = position + Vector3.new(0, RAY_UP, 0)
	local direction = Vector3.new(0, -(RAY_UP + RAY_DOWN), 0)
	return Workspace:Raycast(origin, direction, buildRaycastParams())
end

local function getParentWorldCFrame(bone)
	local parent = bone.Parent
	if parent and parent:IsA("Bone") then
		return parent.TransformedWorldCFrame
	end
	if parent and parent:IsA("BasePart") then
		return parent.CFrame
	end
	return CFrame.identity
end

local function makeWorldDownAdditive(bone, amount)
	if amount <= 0.0001 then
		return CFrame.identity
	end
	local parentWorld = getParentWorldCFrame(bone)
	local localOffset = parentWorld:VectorToObjectSpace(Vector3.new(0, -amount, 0))
	return CFrame.new(localOffset)
end

local function removeAppliedAdditives()
	for bone, additive in pairs(applied) do
		if bone and bone.Parent then
			bone.Transform = bone.Transform * additive:Inverse()
		end
	end
	table.clear(applied)
end

local function applyAdditive(bone, additive)
	if additive == CFrame.identity then
		return
	end
	bone.Transform = bone.Transform * additive
	applied[bone] = additive
end

local function tryInitialize()
	dragon = Workspace:FindFirstChild(DRAGON_NAME)
	if not dragon then
		return false
	end
	mesh = dragon:FindFirstChild("DragonMesh")
	if not mesh then
		return false
	end

	ensureFolder()
	entries = {}
	local found = 0

	for footName, foot in pairs(FEET) do
		local bone = findBone(foot.boneName)
		if bone then
			found += 1
			local prefix = foot.label
			table.insert(entries, {
				footName = footName,
				label = foot.label,
				boneName = foot.boneName,
				bone = bone,
				toePart = makePart(prefix .. "_Toe", COLOR_TOE, 0.30),
				groundPart = makePart(prefix .. "_Ground", COLOR_GROUND, 0.22),
				targetPart = makePart(prefix .. "_Target", COLOR_TARGET, 0.26),
				rayPart = makePart(prefix .. "_Ray", COLOR_RAY, 0.06, Enum.PartType.Block),
				smoothedGroundY = nil,
				smoothedApplied = 0,
				err = 0,
				hasHit = false,
			})
		else
			warn(("[DragonRearFootIK] Missing bone %s: %s"):format(footName, foot.boneName))
		end
	end

	if not readyPrinted then
		readyPrinted = true
		print(("[DragonRearFootIK] Ready rearToeBones=%d/2 lowWeight=true noRootWrites=true"):format(found))
	end

	return found > 0
end

local function updateRayVisual(rayPart, toePos, groundPos)
	local mid = (toePos + groundPos) * 0.5
	local length = math.max((toePos - groundPos).Magnitude, 0.05)
	rayPart.Size = Vector3.new(0.05, length, 0.05)
	rayPart.CFrame = CFrame.lookAt(mid, groundPos) * CFrame.Angles(math.rad(90), 0, 0)
end

local function updateFoot(entry, dt, active)
	if not entry.bone or not entry.bone.Parent then
		return
	end

	local toeCF = entry.bone.TransformedWorldCFrame
	local toePos = toeCF.Position
	entry.toePart.Position = toePos

	local targetApplied = 0
	local hit = nil

	if active then
		hit = raycastDown(toePos)
	end

	if hit then
		entry.hasHit = true
		local groundPos = hit.Position
		entry.groundPart.Position = groundPos

		if entry.smoothedGroundY == nil then
			entry.smoothedGroundY = groundPos.Y
		else
			entry.smoothedGroundY = expSmooth(entry.smoothedGroundY, groundPos.Y, SMOOTH_SPEED, dt)
		end

		local targetPos = Vector3.new(toePos.X, entry.smoothedGroundY, toePos.Z)
		entry.targetPart.Position = targetPos
		updateRayVisual(entry.rayPart, toePos, groundPos)

		entry.err = toePos.Y - entry.smoothedGroundY
		targetApplied = math.clamp(entry.err, 0, MAX_VERTICAL_CORRECTION) * IK_WEIGHT
	else
		entry.hasHit = false
		entry.err = 0
		targetApplied = 0

		if entry.smoothedGroundY == nil then
			entry.smoothedGroundY = toePos.Y
		else
			entry.smoothedGroundY = expSmooth(entry.smoothedGroundY, toePos.Y, SMOOTH_SPEED, dt)
		end

		local targetPos = Vector3.new(toePos.X, entry.smoothedGroundY, toePos.Z)
		entry.groundPart.Position = targetPos
		entry.targetPart.Position = targetPos
		updateRayVisual(entry.rayPart, toePos, targetPos)
	end

	entry.smoothedApplied = expSmooth(entry.smoothedApplied, targetApplied, SMOOTH_SPEED, dt)

	if entry.label == "RL" then
		lastLogRL.err = entry.err
		lastLogRL.applied = entry.smoothedApplied
	elseif entry.label == "RR" then
		lastLogRR.err = entry.err
		lastLogRR.applied = entry.smoothedApplied
	end
end

local function applyFootCorrections()
	removeAppliedAdditives()

	for _, entry in ipairs(entries) do
		if entry.bone and entry.bone.Parent and entry.smoothedApplied > 0.0001 then
			local additive = makeWorldDownAdditive(entry.bone, entry.smoothedApplied)
			applyAdditive(entry.bone, additive)
		end
	end
end

local function resetFootState()
	for _, entry in ipairs(entries) do
		entry.smoothedApplied = 0
		entry.smoothedGroundY = nil
		entry.err = 0
		entry.hasHit = false
	end
	removeAppliedAdditives()
end

local function heartbeatUpdate(dt)
	if not initialized then
		initialized = tryInitialize()
		return
	end

	local active = isActive()
	setTargetsVisible(active)

	if not active then
		for _, entry in ipairs(entries) do
			entry.smoothedApplied = expSmooth(entry.smoothedApplied, 0, SMOOTH_SPEED, dt)
			if entry.label == "RL" then
				lastLogRL.applied = entry.smoothedApplied
			elseif entry.label == "RR" then
				lastLogRR.applied = entry.smoothedApplied
			end
		end
		if lastLogRL.applied <= 0.001 and lastLogRR.applied <= 0.001 then
			resetFootState()
		end
		return
	end

	for _, entry in ipairs(entries) do
		updateFoot(entry, dt, true)
	end

	logElapsed += dt
	if logElapsed >= LOG_INTERVAL then
		logElapsed = 0
		print(("[DragonRearFootIK] RL err=%.3f applied=%.3f | RR err=%.3f applied=%.3f"):format(
			lastLogRL.err,
			lastLogRL.applied,
			lastLogRR.err,
			lastLogRR.applied
		))
	end
end

local function lateRenderUpdate(_dt)
	if not initialized then
		return
	end
	applyFootCorrections()
end

local function shutdown()
	removeAppliedAdditives()
	pcall(function()
		RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
	end)
	clearTargetsFolder()
end

script.Destroying:Connect(shutdown)

pcall(function()
	RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
end)

RunService.Heartbeat:Connect(function(dt)
	heartbeatUpdate(math.clamp(dt, 1 / 240, 1 / 15))
end)
RunService:BindToRenderStep(RENDER_STEP_NAME, RENDER_PRIORITY, lateRenderUpdate)
