local GroundKinematic = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local BODY_FRONT = 15
local BODY_REAR = 12
local BODY_WIDTH = 5
local RAY_UP = 18
local RAY_DOWN = 80
local ROOT_CLEARANCE = 8.6
local MAX_ROOT_PITCH = math.rad(38)
local UP = Vector3.yAxis

local MAX_WALKABLE_DROP = 6
local MAX_WALKABLE_STEP_UP = 7
local DROP_GRAVITY = 90
local MAX_DROP_SPEED = 65
local DROP_PITCH_LIMIT = math.rad(12)
local DROP_RECOVER_DISTANCE = 1.25

local dropVelocityByDragon = setmetatable({}, { __mode = "k" })
local previousPitchByDragon = setmetatable({}, { __mode = "k" })
local lastLogTimeByDragon = setmetatable({}, { __mode = "k" })

function GroundKinematic.enterGroundAuthority(root, linearVelocity, alignOrientation)
	linearVelocity.Enabled = false
	alignOrientation.Enabled = false

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero

	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	root.Anchored = true
end

function GroundKinematic.exitGroundAuthority(root, linearVelocity, alignOrientation, activePlayer)
	root.Anchored = false
	pcall(function()
		if activePlayer then
			root:SetNetworkOwner(activePlayer)
		else
			root:SetNetworkOwner(nil)
		end
	end)
	
	linearVelocity.Enabled = true
	alignOrientation.Enabled = true
end

function GroundKinematic.lockParkedDragon(dragon, root, linearVelocity, alignOrientation, pivotToKeep)
	if pivotToKeep then
		dragon:PivotTo(pivotToKeep)
	end

	linearVelocity.Enabled = false
	alignOrientation.Enabled = false

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero

	root.Anchored = true

	pcall(function()
		root:SetNetworkOwner(nil)
	end)
end

function GroundKinematic.resetGroundYawAuthority(dragon, root, linearVelocity, alignOrientation, reason, keepGroundAnchored)
	if linearVelocity then
		linearVelocity.Enabled = false
	end

	if alignOrientation then
		alignOrientation.Enabled = false
	end

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero

	if keepGroundAnchored then
		root.Anchored = true
	end

	local look = root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)

	if flatLook.Magnitude < 0.001 then
		flatLook = Vector3.new(0, 0, -1)
	else
		flatLook = flatLook.Unit
	end

	if dropVelocityByDragon then
		dropVelocityByDragon[dragon] = 0
	end

	if previousPitchByDragon then
		previousPitchByDragon[dragon] = 0
	end

	if lastForwardByDragon then
		lastForwardByDragon[dragon] = flatLook
	end

	if lastYawByDragon then
		lastYawByDragon[dragon] = math.atan2(-flatLook.X, -flatLook.Z)
	end

	dragon:SetAttribute("DragonDropActive", false)
	dragon:SetAttribute("DragonYawResetReason", reason or "unknown")
	dragon:SetAttribute("DragonYawResetTime", os.clock())

	print("[DragonYawReset] reason=", reason, "flatLook=", flatLook, "anchored=", root.Anchored)
end


function GroundKinematic.snapToGround(dragon, root, groundForward, activePlayer)
	local dt = 1/30
	local currentPosition = root.Position
	local currentVelocity = root.AssemblyLinearVelocity
	local flatForward = Vector3.new(groundForward.X, 0, groundForward.Z)
	if flatForward.Magnitude < 0.01 then
		flatForward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	flatForward = flatForward.Magnitude > 0.01 and flatForward.Unit or Vector3.new(0, 0, -1)
	
	local right = Vector3.new(root.CFrame.RightVector.X, 0, root.CFrame.RightVector.Z)
	right = right.Magnitude > 0.01 and right.Unit or Vector3.new(1, 0, 0)

	local highestHitY = -math.huge
	local hasHit = false
	local frontY, centerY, rearY = 0, 0, 0
	local hasFront, hasCenter, hasRear = false, false, false

	local slopeParams = RaycastParams.new()
	slopeParams.FilterType = Enum.RaycastFilterType.Exclude
	local slopeExclude = { dragon }
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then table.insert(slopeExclude, plr.Character) end
	end
	slopeParams.FilterDescendantsInstances = slopeExclude

	local probeOffsets = {
		{ offset = flatForward * BODY_FRONT, type = "front" },
		{ offset = flatForward * BODY_FRONT - right * BODY_WIDTH, type = "front" },
		{ offset = flatForward * BODY_FRONT + right * BODY_WIDTH, type = "front" },
		{ offset = Vector3.zero, type = "center" },
		{ offset = -right * BODY_WIDTH, type = "center" },
		{ offset = right * BODY_WIDTH, type = "center" },
		{ offset = -flatForward * BODY_REAR, type = "rear" },
		{ offset = -flatForward * BODY_REAR - right * BODY_WIDTH, type = "rear" },
		{ offset = -flatForward * BODY_REAR + right * BODY_WIDTH, type = "rear" },
	}

	local frontSum, centerSum, rearSum = 0, 0, 0
	local frontCount, centerCount, rearCount = 0, 0, 0

	for _, probe in ipairs(probeOffsets) do
		local origin = currentPosition + probe.offset + Vector3.new(0, RAY_UP, 0)
		local hit = Workspace:Raycast(origin, Vector3.new(0, -RAY_DOWN, 0), slopeParams)
		if hit then
			hasHit = true
			if hit.Position.Y > highestHitY then highestHitY = hit.Position.Y end
			if probe.type == "center" then centerSum += hit.Position.Y; centerCount += 1
			elseif probe.type == "front" then frontSum += hit.Position.Y; frontCount += 1
			elseif probe.type == "rear" then rearSum += hit.Position.Y; rearCount += 1 end
		end
	end

	if centerCount > 0 then centerY = centerSum / centerCount; hasCenter = true end
	if frontCount > 0 then frontY = frontSum / frontCount; hasFront = true end
	if rearCount > 0 then rearY = rearSum / rearCount; hasRear = true end

	local targetY
	local bodyGroundY = centerY
	local targetPitch = 0

	if hasHit then
		if hasCenter then bodyGroundY = centerY
		elseif hasFront and hasRear then bodyGroundY = (frontY + rearY) * 0.5
		elseif hasFront then bodyGroundY = frontY
		elseif hasRear then bodyGroundY = rearY end

		targetY = bodyGroundY + ROOT_CLEARANCE

		if hasFront and hasRear then
			local bodyLength = BODY_FRONT + BODY_REAR
			targetPitch = math.atan2(frontY - rearY, bodyLength)
			targetPitch = math.clamp(targetPitch, -MAX_ROOT_PITCH, MAX_ROOT_PITCH)
		end
	else
		local fallY = currentVelocity.Y - Workspace.Gravity * dt
		targetY = currentPosition.Y + math.clamp(fallY, -220, 0) * dt
		bodyGroundY = targetY - ROOT_CLEARANCE
	end

	local targetPosition = Vector3.new(currentPosition.X, targetY, currentPosition.Z)
	local pitchedForward = (flatForward + Vector3.new(0, math.tan(targetPitch), 0)).Unit
	local desiredRootCFrame = CFrame.lookAt(targetPosition, targetPosition + pitchedForward, Vector3.yAxis)
	
	local rootToPivot = root.CFrame:ToObjectSpace(dragon:GetPivot())
	local desiredModelPivot = desiredRootCFrame * rootToPivot
	dragon:PivotTo(desiredModelPivot)
	
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

function GroundKinematic.stepGround(dragon, root, activePlayer, moveDirection, groundForward, currentGroundSpeed, dt)
	local currentPosition = root.Position
	local displacement = moveDirection * currentGroundSpeed * dt
	local newPosX = currentPosition.X + displacement.X
	local newPosZ = currentPosition.Z + displacement.Z
	local probePosition = currentPosition + displacement
	local currentVelocity = root.AssemblyLinearVelocity

	local flatForward = Vector3.new(groundForward.X, 0, groundForward.Z)
	if flatForward.Magnitude < 0.01 then
		flatForward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	flatForward = flatForward.Magnitude > 0.01 and flatForward.Unit or Vector3.new(0, 0, -1)
	
	local right = Vector3.new(root.CFrame.RightVector.X, 0, root.CFrame.RightVector.Z)
	right = right.Magnitude > 0.01 and right.Unit or Vector3.new(1, 0, 0)

	local highestHitY = -math.huge
	local hasHit = false
	local frontY, centerY, rearY = 0, 0, 0
	local hasFront, hasCenter, hasRear = false, false, false

	local slopeParams = RaycastParams.new()
	slopeParams.FilterType = Enum.RaycastFilterType.Exclude
	local slopeExclude = { dragon }
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then table.insert(slopeExclude, plr.Character) end
	end
	slopeParams.FilterDescendantsInstances = slopeExclude

	local probeOffsets = {
		{ offset = flatForward * BODY_FRONT, type = "front" },
		{ offset = flatForward * BODY_FRONT - right * BODY_WIDTH, type = "front" },
		{ offset = flatForward * BODY_FRONT + right * BODY_WIDTH, type = "front" },
		{ offset = Vector3.zero, type = "center" },
		{ offset = -right * BODY_WIDTH, type = "center" },
		{ offset = right * BODY_WIDTH, type = "center" },
		{ offset = -flatForward * BODY_REAR, type = "rear" },
		{ offset = -flatForward * BODY_REAR - right * BODY_WIDTH, type = "rear" },
		{ offset = -flatForward * BODY_REAR + right * BODY_WIDTH, type = "rear" },
	}

	local frontSum, centerSum, rearSum = 0, 0, 0
	local frontCount, centerCount, rearCount = 0, 0, 0

	local expectedGroundY = currentPosition.Y - ROOT_CLEARANCE
	local dropLandingY = nil

	for _, probe in ipairs(probeOffsets) do
		local origin = probePosition + probe.offset + Vector3.new(0, RAY_UP, 0)
		local hit = Workspace:Raycast(origin, Vector3.new(0, -RAY_DOWN, 0), slopeParams)
		if hit then
			local hitY = hit.Position.Y
			if hitY < expectedGroundY - MAX_WALKABLE_DROP then
				-- esto NO es soporte caminable normal
				-- es suelo lejano / caída / borde
				if not dropLandingY or hitY > dropLandingY then
					dropLandingY = hitY
				end
			else
				-- soporte normal
				hasHit = true
				if hitY > highestHitY then highestHitY = hitY end
				if probe.type == "center" then centerSum += hitY; centerCount += 1
				elseif probe.type == "front" then frontSum += hitY; frontCount += 1
				elseif probe.type == "rear" then rearSum += hitY; rearCount += 1 end
			end
		end
	end

	if centerCount > 0 then centerY = centerSum / centerCount; hasCenter = true end
	if frontCount > 0 then frontY = frontSum / frontCount; hasFront = true end
	if rearCount > 0 then rearY = rearSum / rearCount; hasRear = true end

	local targetY
	local bodyGroundY = centerY
	local targetPitch = 0
	local isFalling = false

	if hasHit then
		if hasCenter then bodyGroundY = centerY
		elseif hasFront and hasRear then bodyGroundY = (frontY + rearY) * 0.5
		elseif hasFront then bodyGroundY = frontY
		elseif hasRear then bodyGroundY = rearY end

		targetY = bodyGroundY + ROOT_CLEARANCE

		local pitchSamplesValid = false
		local pitchDeltaY = 0
		local pitchDistance = 1

		if hasFront and hasRear then
			pitchDeltaY = frontY - rearY
			pitchDistance = BODY_FRONT + BODY_REAR
			pitchSamplesValid = true
		elseif hasFront and hasCenter then
			pitchDeltaY = frontY - centerY
			pitchDistance = BODY_FRONT
			pitchSamplesValid = true
		elseif hasCenter and hasRear then
			pitchDeltaY = centerY - rearY
			pitchDistance = BODY_REAR
			pitchSamplesValid = true
		end

		if pitchSamplesValid then
			targetPitch = math.atan2(pitchDeltaY, pitchDistance)
			targetPitch = math.clamp(targetPitch, -MAX_ROOT_PITCH, MAX_ROOT_PITCH)
		else
			targetPitch = previousPitchByDragon[dragon] or 0
		end

		local previousPitch = previousPitchByDragon[dragon] or targetPitch
		local pitchAlpha = 1 - math.exp(-10 * dt)
		targetPitch = previousPitch + (targetPitch - previousPitch) * pitchAlpha
	else
		isFalling = true
		if dropLandingY then
			targetY = dropLandingY + ROOT_CLEARANCE
			bodyGroundY = dropLandingY
		else
			local fallY = currentVelocity.Y - Workspace.Gravity * dt
			targetY = currentPosition.Y + math.clamp(fallY, -220, 0) * dt
			bodyGroundY = targetY - ROOT_CLEARANCE
		end

		-- During drop, smooth pitch towards 0
		local previousPitch = previousPitchByDragon[dragon] or 0
		targetPitch = previousPitch + (0 - previousPitch) * math.clamp(dt * 6, 0, 1)
		targetPitch = math.clamp(targetPitch, -DROP_PITCH_LIMIT, DROP_PITCH_LIMIT)
	end

	previousPitchByDragon[dragon] = targetPitch

	-- 2. Detectar caída
	local currentY = currentPosition.Y
	local deltaY = targetY - currentY
	local isBigDrop = deltaY < -MAX_WALKABLE_DROP
	local desiredY = targetY

	if isBigDrop or isFalling then
		local v = dropVelocityByDragon[dragon] or 0
		v = math.min(v + DROP_GRAVITY * dt, MAX_DROP_SPEED)
		dropVelocityByDragon[dragon] = v

		desiredY = math.max(targetY, currentY - v * dt)

		-- 4. Cuando el root ya esté cerca del target
		if math.abs(currentY - targetY) <= DROP_RECOVER_DISTANCE then
			dropVelocityByDragon[dragon] = 0
			desiredY = targetY
		end

		-- 5. Agregar logs temporales
		local now = os.clock()
		local lastLog = lastLogTimeByDragon[dragon] or 0
		if now - lastLog >= 0.25 then
			lastLogTimeByDragon[dragon] = now
			print(string.format("[DragonDrop] active currentY=%.2f targetY=%.2f desiredY=%.2f v=%.2f", currentY, targetY, desiredY, v))
		end
	else
		dropVelocityByDragon[dragon] = 0
	end

	dragon:SetAttribute("DragonBodyTargetY", targetY)
	dragon:SetAttribute("DragonBodyPitchDeg", math.deg(targetPitch or 0))
	dragon:SetAttribute("DragonDropActive", isBigDrop == true)

	local targetPosition = Vector3.new(newPosX, desiredY, newPosZ)
	local pitchedForward = (flatForward + Vector3.new(0, math.tan(targetPitch), 0)).Unit
	local desiredRootCFrame = CFrame.lookAt(targetPosition, targetPosition + pitchedForward, Vector3.yAxis)
	
	local rootToPivot = root.CFrame:ToObjectSpace(dragon:GetPivot())
	local desiredModelPivot = desiredRootCFrame * rootToPivot
	dragon:PivotTo(desiredModelPivot)
	
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero

	return desiredY, targetPitch, frontY, centerY, rearY
end

return GroundKinematic
