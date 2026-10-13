-- WyvernAerodynamics.server.lua
-- Motor Aerodinámico de 7 AeroSurfaces Distribuidas (Fase 5B.6 Calibration & Trim Core)
-- 100% gobernado por fuerzas físicas en el Roblox physics solver.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local wyvernFlightFolder = ReplicatedStorage:WaitForChild("WyvernFlight")
local WyvernAerodynamicsConfig = require(wyvernFlightFolder:WaitForChild("Config"):WaitForChild("WyvernAerodynamicsConfig"))
local WyvernAeroSurfaceConfig = require(wyvernFlightFolder:WaitForChild("Config"):WaitForChild("WyvernAeroSurfaceConfig"))
local WyvernFlappingConfig = require(wyvernFlightFolder:WaitForChild("Config"):WaitForChild("WyvernFlappingConfig"))
local remotesFolder = wyvernFlightFolder:WaitForChild("Remotes")

local testCommandRemote = remotesFolder:FindFirstChild("WyvernTestCommand")
if not testCommandRemote then
	testCommandRemote = Instance.new("RemoteEvent")
	testCommandRemote.Name = "WyvernTestCommand"
	testCommandRemote.Parent = remotesFolder
end

local wyvern = Workspace:WaitForChild("wyvernfbx", 10) or Workspace:WaitForChild("DragonTierraRoblox", 10)
if not wyvern then
	warn("[WyvernAero] ERROR: No se encontró wyvernfbx en Workspace.")
	return
end

local dtRoot = wyvern:WaitForChild("DT_Root", 10)
if not dtRoot then
	warn("[WyvernAero] ERROR: No se encontró DT_Root en wyvernfbx.")
	return
end

-- =====================================================================
-- 1. ACTUADORES FÍSICOS GLOBALES (DESACTIVADOS ESTRICTAMENTE)
-- =====================================================================
local liftAttachment = dtRoot:FindFirstChild("WyvernLiftAttachment")
if not liftAttachment then
	liftAttachment = Instance.new("Attachment")
	liftAttachment.Name = "WyvernLiftAttachment"
	liftAttachment.Position = WyvernAerodynamicsConfig.LIFT_ATTACHMENT_OFFSET
	liftAttachment.Parent = dtRoot
end

local globalLiftForce = dtRoot:FindFirstChild("WyvernLiftForce")
if not globalLiftForce then
	globalLiftForce = Instance.new("VectorForce")
	globalLiftForce.Name = "WyvernLiftForce"
	globalLiftForce.Attachment0 = liftAttachment
	globalLiftForce.RelativeTo = Enum.ActuatorRelativeTo.World
	globalLiftForce.ApplyAtCenterOfMass = true
	globalLiftForce.Force = Vector3.zero
	globalLiftForce.Parent = dtRoot
end

local globalDragForce = dtRoot:FindFirstChild("WyvernDragForce")
if not globalDragForce then
	globalDragForce = Instance.new("VectorForce")
	globalDragForce.Name = "WyvernDragForce"
	globalDragForce.Attachment0 = liftAttachment
	globalDragForce.RelativeTo = Enum.ActuatorRelativeTo.World
	globalDragForce.ApplyAtCenterOfMass = true
	globalDragForce.Force = Vector3.zero
	globalDragForce.Parent = dtRoot
end

local flightTorque = dtRoot:FindFirstChild("WyvernFlightTorque")
if not flightTorque then
	flightTorque = Instance.new("Torque")
	flightTorque.Name = "WyvernFlightTorque"
	flightTorque.Attachment0 = liftAttachment
	flightTorque.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
	flightTorque.Torque = Vector3.zero
	flightTorque.Parent = dtRoot
end

-- =====================================================================
-- 2. ACTUADORES DE SUPERFICIES AERODINÁMICAS DISTRIBUIDAS (7 AEROSURFACES)
-- =====================================================================
local surfaceInstances = {}
local surfaceFolder = dtRoot:FindFirstChild("DT_AeroSurfaces")
if surfaceFolder then surfaceFolder:Destroy() end

surfaceFolder = Instance.new("Folder")
surfaceFolder.Name = "DT_AeroSurfaces"
surfaceFolder.Parent = dtRoot

for sKey, sDef in pairs(WyvernAeroSurfaceConfig.SURFACES) do
	local att = Instance.new("Attachment")
	att.Name = "Att_" .. sKey
	att.Position = sDef.LocalOffset
	att.Parent = dtRoot

	local force = Instance.new("VectorForce")
	force.Name = "Force_" .. sKey
	force.Attachment0 = att
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = false
	force.Force = Vector3.zero
	force.Parent = surfaceFolder

	surfaceInstances[sKey] = {
		def = sDef,
		attachment = att,
		forceActuator = force
	}
end

-- =====================================================================
-- 3. ESTADÍSTICAS FORENSES DE CLAMPS (FUSIBLES DE EMERGENCIA)
-- =====================================================================
local clampStats = {
	totalFrames = 0,
	speedClampedFrames = 0,
	liftClampedFrames = 0,
	dragClampedFrames = 0,
	maxSpeedRaw = 0,
	maxLiftRaw = 0,
	maxDragRaw = 0
}

local function resetClampStats()
	clampStats.totalFrames = 0
	clampStats.speedClampedFrames = 0
	clampStats.liftClampedFrames = 0
	clampStats.dragClampedFrames = 0
	clampStats.maxSpeedRaw = 0
	clampStats.maxLiftRaw = 0
	clampStats.maxDragRaw = 0
end

-- =====================================================================
-- 4. MODELO AERODINÁMICO Y CINEMÁTICA
-- =====================================================================
local function computeLiftCoefficient(aoaDeg)
	local optAoA = WyvernAerodynamicsConfig.OPTIMAL_AOA_DEG       -- 12°
	local stallAoA = WyvernAerodynamicsConfig.STALL_AOA_DEG       -- 16°
	local maxCl = WyvernAerodynamicsConfig.MAX_LIFT_COEFFICIENT   -- 4.12
	local neutralFactor = WyvernAerodynamicsConfig.NEUTRAL_LIFT_FACTOR -- 0.40
	local postStallFactor = WyvernAerodynamicsConfig.POST_STALL_LIFT_FACTOR -- 0.25

	if aoaDeg < 0 then
		local normNeg = math.clamp(aoaDeg / optAoA, -1.5, 0)
		return maxCl * neutralFactor * (1.0 + normNeg)
	elseif aoaDeg <= optAoA then
		local t = aoaDeg / optAoA
		local clFactor = neutralFactor + (1.0 - neutralFactor) * math.sin(t * (math.pi / 2))
		return maxCl * clFactor
	elseif aoaDeg <= stallAoA then
		local t = (aoaDeg - optAoA) / (stallAoA - optAoA)
		local clFactor = 1.0 - 0.10 * (t ^ 2)
		return maxCl * clFactor
	else
		local stallExcess = math.clamp((aoaDeg - stallAoA) / 14.0, 0, 1)
		local clFactor = 0.90 - (0.90 - postStallFactor) * math.sin(stallExcess * (math.pi / 2))
		return maxCl * clFactor
	end
end

local function computeDragCoefficient(aoaDeg)
	local cd0 = WyvernAerodynamicsConfig.BASE_DRAG_COEFFICIENT
	local kInduced = WyvernAerodynamicsConfig.INDUCED_DRAG_COEFF
	local stallAoA = WyvernAerodynamicsConfig.STALL_AOA_DEG
	local stallMult = WyvernAerodynamicsConfig.STALL_DRAG_MULTIPLIER

	local absAoA = math.abs(aoaDeg)
	local inducedCd = kInduced * (absAoA ^ 1.4)

	if absAoA > stallAoA then
		local stallRatio = math.clamp((absAoA - stallAoA) / 14.0, 0, 1.5)
		inducedCd = inducedCd * (1.0 + (stallMult - 1.0) * stallRatio)
	end

	return cd0 + inducedCd
end

local controlInputs = {
	pitch = 0,
	roll = 0,
	yaw = 0
}

local function computeSurfaceAerodynamicsWithDeflection(sKey, sDef)
	local configMode = dtRoot:GetAttribute("Aero_ConfigMode") or "ALL"
	if configMode == "WINGS_ONLY" then
		if sKey ~= "LeftWingOuter" and sKey ~= "LeftWingInner" and sKey ~= "RightWingInner" and sKey ~= "RightWingOuter" then
			return { name = sKey, speed = 0, aoaGeom = 0, aoaEffective = 0, cl = 0, cd = 0, liftMag = 0, dragMag = 0, netForce = Vector3.zero, torque = Vector3.zero }
		end
	elseif configMode == "WINGS_TAIL" then
		if sKey == "Body" or sKey == "VerticalFin" then
			return { name = sKey, speed = 0, aoaGeom = 0, aoaEffective = 0, cl = 0, cd = 0, liftMag = 0, dragMag = 0, netForce = Vector3.zero, torque = Vector3.zero }
		end
	end

	local rootCF = dtRoot.CFrame
	local comVel = dtRoot.AssemblyLinearVelocity
	local angVel = dtRoot.AssemblyAngularVelocity

	local rWorld = rootCF:VectorToWorldSpace(sDef.LocalOffset)
	local tangentialVel = angVel:Cross(rWorld)
	local vAppPoint = comVel + tangentialVel

	local chordWorld  = rootCF:VectorToWorldSpace(sDef.LocalChord)
	local normalWorld = rootCF:VectorToWorldSpace(sDef.LocalNormal)

	local vFlapInduced = Vector3.zero
	local flapDefl = 0
	local isFlapEnabled = (dtRoot:GetAttribute("Flap_Enabled") == true)
	local allowAoAMod = (dtRoot:GetAttribute("Flap_AoAMod_Enabled") ~= false)
	local allowInducedVel = (dtRoot:GetAttribute("Flap_InducedVel_Enabled") ~= false)

	if isFlapEnabled then
		if sKey == "LeftWingOuter" or sKey == "LeftWingInner" then
			if allowAoAMod then flapDefl = dtRoot:GetAttribute("Flap_Angle_Left") or 0 end
			if allowInducedVel then
				local rateRad = dtRoot:GetAttribute("Flap_RateRad_Left") or math.rad(dtRoot:GetAttribute("Flap_Rate_Left") or 0)
				local spanRadius = math.abs(sDef.LocalOffset.X)
				vFlapInduced = normalWorld * (rateRad * spanRadius * WyvernFlappingConfig.SPAN_AERO_CENTER_FACTOR)
			end
		elseif sKey == "RightWingOuter" or sKey == "RightWingInner" then
			if allowAoAMod then flapDefl = dtRoot:GetAttribute("Flap_Angle_Right") or 0 end
			if allowInducedVel then
				local rateRad = dtRoot:GetAttribute("Flap_RateRad_Right") or math.rad(dtRoot:GetAttribute("Flap_Rate_Right") or 0)
				local spanRadius = math.abs(sDef.LocalOffset.X)
				vFlapInduced = normalWorld * (rateRad * spanRadius * WyvernFlappingConfig.SPAN_AERO_CENTER_FACTOR)
			end
		end
	end

	local vSurface = vAppPoint + vFlapInduced
	local speedRaw = vSurface.Magnitude
	if speedRaw > clampStats.maxSpeedRaw then clampStats.maxSpeedRaw = speedRaw end

	-- Fusible de emergencia (muy holgado: 500 st/s para no afectar vuelo real)
	local speed = math.clamp(speedRaw, 0, 500.0)
	if speedRaw > 500.0 then clampStats.speedClampedFrames = clampStats.speedClampedFrames + 1 end

	if speed < WyvernAerodynamicsConfig.MIN_AIRSPEED then
		return {
			name = sKey,
			speed = speed,
			aoaGeom = 0,
			aoaEffective = 0,
			deflectionDeg = 0,
			cl = 0,
			cd = 0,
			liftMag = 0,
			dragMag = 0,
			liftDir = Vector3.new(0, 1, 0),
			liftVector = Vector3.zero,
			dragVector = Vector3.zero,
			netForce = Vector3.zero,
			torque = Vector3.zero,
			vCoM = comVel,
			vTangential = tangentialVel,
			vFlapInduced = vFlapInduced,
			vSurface = vSurface,
			vAppPoint = vAppPoint,
			rWorld = rWorld
		}
	end

	local velocityUnit = vSurface / math.max(speedRaw, 0.001)
	local relativeAirflow = -velocityUnit

	local fwdDot = math.clamp(chordWorld:Dot(velocityUnit), -1.0, 1.0)
	local normDot = math.clamp(normalWorld:Dot(velocityUnit), -1.0, 1.0)
	local aoaGeom = math.deg(math.atan2(-normDot, fwdDot))

	local pDefl = controlInputs.pitch * (sDef.PitchControlWeight or 0) * WyvernAeroSurfaceConfig.MAX_PITCH_DEFLECTION_DEG
	local rDefl = controlInputs.roll  * (sDef.RollControlWeight  or 0) * WyvernAeroSurfaceConfig.MAX_ROLL_DEFLECTION_DEG
	local yDefl = controlInputs.yaw   * (sDef.YawControlWeight   or 0) * WyvernAeroSurfaceConfig.MAX_YAW_DEFLECTION_DEG

	local totalDeflection = pDefl + rDefl + yDefl + flapDefl
	local aoaEffective = aoaGeom + totalDeflection

	local cl = computeLiftCoefficient(aoaEffective)
	local cd = computeDragCoefficient(aoaEffective)

	local dynamicPressure = speed ^ 2
	local area = sDef.AreaFraction

	local liftRaw = cl * dynamicPressure * area
	local dragRaw = cd * dynamicPressure * area

	if liftRaw > clampStats.maxLiftRaw then clampStats.maxLiftRaw = liftRaw end
	if dragRaw > clampStats.maxDragRaw then clampStats.maxDragRaw = dragRaw end

	-- Fusibles de emergencia holgados (150 kN y 80 kN)
	local liftMag = math.clamp(liftRaw, 0, 150000.0)
	local dragMag = math.clamp(dragRaw, 0, 80000.0)

	if liftRaw > 150000.0 then clampStats.liftClampedFrames = clampStats.liftClampedFrames + 1 end
	if dragRaw > 80000.0 then clampStats.dragClampedFrames = clampStats.dragClampedFrames + 1 end

	local spanAxis = relativeAirflow:Cross(normalWorld)
	local liftDir = normalWorld
	if spanAxis.Magnitude > 0.001 then
		local normSpan = spanAxis.Unit
		local cLiftDir = normSpan:Cross(relativeAirflow)
		if cLiftDir.Magnitude > 0.001 then
			liftDir = cLiftDir.Unit
		end
	end

	local liftVector = liftDir * liftMag
	local dragVector = relativeAirflow * dragMag
	local netForce = liftVector + dragVector
	local torque = rWorld:Cross(netForce)

	return {
		name = sKey,
		speed = speed,
		aoaGeom = aoaGeom,
		aoaEffective = aoaEffective,
		deflectionDeg = totalDeflection,
		cl = cl,
		cd = cd,
		dynamicPressure = dynamicPressure,
		area = area,
		liftMag = liftMag,
		dragMag = dragMag,
		liftDir = liftDir,
		liftVector = liftVector,
		dragVector = dragVector,
		netForce = netForce,
		torque = torque,
		vCoM = comVel,
		vTangential = tangentialVel,
		vFlapInduced = vFlapInduced,
		vSurface = vSurface,
		vAppPoint = vAppPoint,
		rWorld = rWorld
	}
end

-- =====================================================================
-- 5. BUCLE FÍSICO PERMANENTE (HEARTBEAT)
-- =====================================================================
local function setAssemblyAnchored(anchored)
	for _, desc in ipairs(wyvern:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Anchored = anchored
		end
	end
end

RunService.Heartbeat:Connect(function()
	if dtRoot.Anchored then
		globalLiftForce.Force = Vector3.zero
		globalDragForce.Force = Vector3.zero
		flightTorque.Torque = Vector3.zero
		for _, sData in pairs(surfaceInstances) do
			sData.forceActuator.Force = Vector3.zero
		end
		return
	end

	if dtRoot.Position.Y < WyvernAerodynamicsConfig.MIN_SAFE_ALTITUDE then
		setAssemblyAnchored(true)
		dtRoot.AssemblyLinearVelocity = Vector3.zero
		dtRoot.AssemblyAngularVelocity = Vector3.zero
		flightTorque.Torque = Vector3.zero
		for _, sData in pairs(surfaceInstances) do
			sData.forceActuator.Force = Vector3.zero
		end
		dtRoot:SetAttribute("Aero_Stage", "TOUCHDOWN")
		return
	end

	clampStats.totalFrames = clampStats.totalFrames + 1
	flightTorque.Torque = Vector3.zero
	globalLiftForce.Force = Vector3.zero
	globalDragForce.Force = Vector3.zero

	local totalLift = 0
	local totalDrag = 0
	local leftLift = 0
	local rightLift = 0
	local totalTorque = Vector3.zero
	local tailTorqueX = 0
	local wingTorqueX = 0
	local bodyTorqueX = 0
	local bodyAoA = 0

	for sKey, sData in pairs(surfaceInstances) do
		local sRes = computeSurfaceAerodynamicsWithDeflection(sKey, sData.def)
		sData.forceActuator.Force = sRes.netForce
		totalLift = totalLift + (sRes.liftMag or 0)
		totalDrag = totalDrag + (sRes.dragMag or 0)
		totalTorque = totalTorque + (sRes.torque or Vector3.zero)

		if sKey == "LeftWingOuter" or sKey == "LeftWingInner" then
			leftLift = leftLift + (sRes.liftMag or 0)
			wingTorqueX = wingTorqueX + ((sRes.torque and sRes.torque.X) or 0)
		elseif sKey == "RightWingOuter" or sKey == "RightWingInner" then
			rightLift = rightLift + (sRes.liftMag or 0)
			wingTorqueX = wingTorqueX + ((sRes.torque and sRes.torque.X) or 0)
		elseif sKey == "Tail" then
			tailTorqueX = (sRes.torque and sRes.torque.X) or 0
		elseif sKey == "Body" then
			bodyTorqueX = (sRes.torque and sRes.torque.X) or 0
			bodyAoA = sRes.aoaEffective or 0
		end
	end

	dtRoot:SetAttribute("Aero_Speed", dtRoot.AssemblyLinearVelocity.Magnitude)
	dtRoot:SetAttribute("Aero_Lift", totalLift)
	dtRoot:SetAttribute("Aero_Drag", totalDrag)
	dtRoot:SetAttribute("Aero_AoA", bodyAoA)
	dtRoot:SetAttribute("Aero_LeftLift", leftLift)
	dtRoot:SetAttribute("Aero_RightLift", rightLift)
	dtRoot:SetAttribute("Aero_Torque_X", totalTorque.X)
	dtRoot:SetAttribute("Aero_Torque_Y", totalTorque.Y)
	dtRoot:SetAttribute("Aero_Torque_Z", totalTorque.Z)
	dtRoot:SetAttribute("Aero_TailTorque_X", tailTorqueX)
	dtRoot:SetAttribute("Aero_WingTorque_X", wingTorqueX)
	dtRoot:SetAttribute("Aero_BodyTorque_X", bodyTorqueX)
	dtRoot:SetAttribute("Aero_LWRatio", totalLift / (dtRoot.AssemblyMass * Workspace.Gravity))

	-- Telemetría de clamps
	dtRoot:SetAttribute("Clamp_TotalFrames", clampStats.totalFrames)
	dtRoot:SetAttribute("Clamp_SpeedFrames", clampStats.speedClampedFrames)
	dtRoot:SetAttribute("Clamp_LiftFrames", clampStats.liftClampedFrames)
	dtRoot:SetAttribute("Clamp_DragFrames", clampStats.dragClampedFrames)
	dtRoot:SetAttribute("Clamp_MaxSpeedRaw", clampStats.maxSpeedRaw)
	dtRoot:SetAttribute("Clamp_MaxLiftRaw", clampStats.maxLiftRaw)
	dtRoot:SetAttribute("Clamp_MaxDragRaw", clampStats.maxDragRaw)
end)

testCommandRemote.OnServerEvent:Connect(function(player, command, arg)
	if command == "RESET" or command == "SPAWN_AERIAL" then
		resetClampStats()
		setAssemblyAnchored(true)
		local spawnPos = Vector3.new(0, 300.0, 0)
		dtRoot.CFrame = CFrame.lookAt(spawnPos, spawnPos + Vector3.new(0, 0, -100))
		dtRoot.AssemblyLinearVelocity = Vector3.new(0, 0, -75.0)
		dtRoot.AssemblyAngularVelocity = Vector3.zero
		dtRoot:SetAttribute("FlightState", "CRUISE")
		dtRoot:SetAttribute("Thrust_Percent", 0.60)
		pcall(function() dtRoot:SetNetworkOwner(nil) end)
		task.wait(0.1)
		setAssemblyAnchored(false)
	elseif command == "RESET_CLAMP_STATS" then
		resetClampStats()
	elseif command == "SET_ROTATIONAL_INPUT" and type(arg) == "table" then
		controlInputs.pitch = math.clamp(tonumber(arg.pitch) or 0, -1, 1)
		controlInputs.roll  = math.clamp(tonumber(arg.roll)  or 0, -1, 1)
		controlInputs.yaw   = math.clamp(tonumber(arg.yaw)   or 0, -1, 1)
	end
end)
