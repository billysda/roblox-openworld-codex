-- FlightController.server.lua
-- Controlador Físico-Arcade de Vuelo de Wyvern (Fase R1)
-- Gestiona velocidad, aceleración, convergencia angular, impulso de vuelo (boost) y límites físicos en servidor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local wyvernFlightV2 = ReplicatedStorage:WaitForChild("WyvernFlightV2")
local WyvernFlightConfig = require(wyvernFlightV2:WaitForChild("Config"):WaitForChild("WyvernFlightConfig"))

-- Crear o asegurar carpeta de Remotes
local remotesFolder = wyvernFlightV2:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = wyvernFlightV2
end

local flightInputRemote = remotesFolder:FindFirstChild("FlightInput")
if not flightInputRemote then
	flightInputRemote = Instance.new("RemoteEvent")
	flightInputRemote.Name = "FlightInput"
	flightInputRemote.Parent = remotesFolder
end

local resetRemote = remotesFolder:FindFirstChild("ResetCommand")
if not resetRemote then
	resetRemote = Instance.new("RemoteEvent")
	resetRemote.Name = "ResetCommand"
	resetRemote.Parent = remotesFolder
end

-- Localizar wyvernfbx
local wyvern = Workspace:WaitForChild("wyvernfbx", 15) or Workspace:WaitForChild("DragonTierraRoblox", 15)
if not wyvern then
	warn("[FlightController V2] ERROR: No se encontró wyvernfbx en Workspace.")
	return
end

local dtRoot = wyvern:WaitForChild("DT_Root", 15)
if not dtRoot then
	warn("[FlightController V2] ERROR: No se encontró DT_Root en wyvernfbx.")
	return
end

-- =============================================================================
-- 1. ACTUADORES FÍSICOS LIMPIOS (LINEARVELOCITY + ALIGNORIENTATION)
-- =============================================================================
-- Desactivar cualquier fuerza o actuador residual de V1
for _, desc in ipairs(dtRoot:GetDescendants()) do
	if desc:IsA("VectorForce") or desc:IsA("Torque") then
		desc.Enabled = false
	end
end

local rootAttachment = dtRoot:FindFirstChild("WyvernFlightAttachmentV2")
if not rootAttachment then
	rootAttachment = Instance.new("Attachment")
	rootAttachment.Name = "WyvernFlightAttachmentV2"
	rootAttachment.Position = Vector3.zero
	rootAttachment.Parent = dtRoot
end

local linearVelocity = dtRoot:FindFirstChild("WyvernLinearVelocityV2")
if not linearVelocity then
	linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "WyvernLinearVelocityV2"
	linearVelocity.Attachment0 = rootAttachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	linearVelocity.MaxForce = 1e6
	linearVelocity.VectorVelocity = Vector3.zero
	linearVelocity.Parent = dtRoot
end

local alignOrientation = dtRoot:FindFirstChild("WyvernAlignOrientationV2")
if not alignOrientation then
	alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Name = "WyvernAlignOrientationV2"
	alignOrientation.Attachment0 = rootAttachment
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.MaxTorque = 1e6
	alignOrientation.Responsiveness = 12
	alignOrientation.RigidityEnabled = false
	alignOrientation.CFrame = dtRoot.CFrame
	alignOrientation.Parent = dtRoot
end

-- =============================================================================
-- Aterrizaje v0.1: solo una autoridad de actuadores (este FlightController).
-- WyvernGroundV01 NO mueve partes: observa suelo y aporta sustentacion en tierra.
-- =============================================================================
local GroundV01 = require(script.Parent:WaitForChild("WyvernGroundV01"))
local groundV01 = GroundV01.new(wyvern, dtRoot, rootAttachment)
local GroundCollisionV022 = require(script.Parent:WaitForChild("GroundCollisionV022"))
local collisionV022 = GroundCollisionV022.new(wyvern, dtRoot)
local motionState = "FLIGHT" -- FLIGHT | APPROACH | LANDING | GROUNDED_IDLE | GROUNDED_RUN
local groundMoveSpeed = 0
local groundLostTime = 0
local takeoffTime = 0
local recoveryTime = 0
local recoveryPlanarSpeed = 0
local obstacleDistance = math.huge

-- Calibracion inicial Run v0.2: 30 studs/s a 1.0x.
-- La longitud de zancada real se revisara en Play con video.
local GROUND_RUN_SPEED = 30
local GROUND_SPRINT_SPEED = 39
local GROUND_TURN_RATE = math.rad(60)
local TAKEOFF_VERTICAL_SPEED = 38
local TAKEOFF_TRANSITION_DURATION = 0.55
local usingGroundHorizontalDrive = false

local function setGroundHorizontalDrive(enabled)
    if usingGroundHorizontalDrive == enabled then return end
    usingGroundHorizontalDrive = enabled
    linearVelocity.ForceLimitsEnabled = true
    if enabled then
        -- La gravedad y GroundSupport gobiernan Y, LinearVelocity solamente XZ.
        linearVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
        linearVelocity.MaxAxesForce = Vector3.new(1e6, 0, 1e6)
    else
        -- R4.1/R4.2 conserva su actuacion vectorial completa en vuelo.
        linearVelocity.ForceLimitMode = Enum.ForceLimitMode.Magnitude
        linearVelocity.MaxForce = 1e6
    end
end

-- =============================================================================
-- 2. ESTADO INTERNO DEL VUELO
-- =============================================================================
local currentSpeed = WyvernFlightConfig.CruiseSpeed
local currentPitch = 0.0 -- radianes
local currentYaw = 0.0   -- radianes
local currentRoll = 0.0  -- radianes
local currentVerticalVel = 0.0

-- Variables de Estado para Dirección Real (Fase R3: Wyvern Steering)
local currentTurnInput = 0.0
local currentYawRate = 0.0 -- rad/s
local currentFlightDir = WyvernFlightConfig.SpawnHeading.Unit

local isBoosting = false
local boostTimer = 0.0
local boostElapsed = 0.0
local boostCooldownTimer = 0.0
local boostStage = "NORMAL"

local playerInputs = {
	forward = 0,       -- W (+1), S (-1), neutro (0)
	turn = 0,          -- A (-1), D (+1), neutro (0)
	vertical = 0,      -- Space (+1), LCtrl (-1), neutro (0)
	boost = false,     -- Shift
	aimTurn = 0,       -- Intención de giro por mouse aim [-1, 1]
	aimPitch = 0,      -- Intención de cabeceo por mouse aim [-1, 1]
	aimYawError = 0,   -- Error angular horizontal (grados)
	aimPitchError = 0, -- Error angular vertical (grados)
	camAimYaw = 0      -- Rumbo de aim de la cámara (grados)
}

-- Función de desanclado de partes para física dinámica
local function setAssemblyAnchored(anchored)
	for _, p in ipairs(wyvern:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "WyvernPhysXRunway" then
			p.Anchored = anchored
		end
	end
end

-- Función de reinicio a posición aérea segura
local function resetToAerialSpawn()
    motionState = "FLIGHT"
    groundMoveSpeed = 0
    groundLostTime = 0
    takeoffTime = 0
    recoveryTime = 0
    recoveryPlanarSpeed = 0
    groundV01:DisableSupport()
    collisionV022:SetActive(false)
    setGroundHorizontalDrive(false)
    setAssemblyAnchored(true)
	
	local spawnPos = WyvernFlightConfig.SpawnPosition
	currentPitch = 0.0
	currentYaw = 0.0
	currentRoll = 0.0
	currentTurnInput = 0.0
	currentYawRate = 0.0
	currentFlightDir = WyvernFlightConfig.SpawnHeading.Unit
	currentSpeed = WyvernFlightConfig.CruiseSpeed
	currentVerticalVel = 0.0
	isBoosting = false
	boostTimer = 0.0
	boostElapsed = 0.0
	boostCooldownTimer = 0.0
	boostStage = "NORMAL"

	playerInputs.aimTurn = 0.0
	playerInputs.aimPitch = 0.0
	playerInputs.aimYawError = 0.0
	playerInputs.aimPitchError = 0.0
	playerInputs.camAimYaw = 0.0

	dtRoot.CFrame = CFrame.lookAt(spawnPos, spawnPos + WyvernFlightConfig.SpawnHeading)
	dtRoot.AssemblyLinearVelocity = WyvernFlightConfig.SpawnHeading * currentSpeed
	dtRoot.AssemblyAngularVelocity = Vector3.zero

	alignOrientation.CFrame = dtRoot.CFrame
	linearVelocity.VectorVelocity = WyvernFlightConfig.SpawnHeading * currentSpeed

	task.wait(0.1)
	setAssemblyAnchored(false)
	pcall(function() dtRoot:SetNetworkOwner(nil) end)
end

local lastServerAimLogClock = 0.0

-- =============================================================================
-- Transiciones de vuelo a tierra. Devuelve orden de velocidad/orientacion;
-- no crea un segundo Heartbeat ni escribe los actuadores por su cuenta.
-- =============================================================================
local function resolveSurfaceMotion(dt, sensor, defaultVelocity, defaultOrientation)
    local clearance = sensor.clearance

    if motionState == "FLIGHT" then
        -- Solo un DESCENSO deliberado solicita aterrizaje.
        if sensor.valid and clearance > 0.25 and clearance <= 25
            and playerInputs.vertical < -0.2 and not isBoosting then
            motionState = "APPROACH"
        else
            return defaultVelocity, defaultOrientation
        end
    end

    if motionState == "APPROACH" or motionState == "LANDING" then
        -- Permitir go-around si aun existe margen respecto al suelo.
        local goAround = playerInputs.vertical > 0.25 or isBoosting
        if not sensor.valid or (goAround and clearance > 2.5) then
            motionState = "FLIGHT"
            groundV01:DisableSupport()
            setGroundHorizontalDrive(false)
            return defaultVelocity, defaultOrientation
        end

        local targetSpeed
        if motionState == "APPROACH" then
            local fraction = math.clamp((clearance - 3.5) / 21.5, 0, 1)
            targetSpeed = 12 + 23 * fraction
        else
            targetSpeed = playerInputs.forward > 0.15 and 12 or 0
        end

        -- El controlador aereo calcula primero su crucero; aqui se frena
        -- de forma controlada, sin permitir que el vuelo imponga 80 studs/s.
        currentSpeed = math.max(targetSpeed, currentSpeed - 110 * dt)
        currentPitch += (0 - currentPitch) * math.clamp(5 * dt, 0, 1)
        currentRoll += (0 - currentRoll) * math.clamp(6 * dt, 0, 1)
        local orientation = CFrame.fromEulerAnglesYXZ(currentPitch, currentYaw, currentRoll)
        local dir = CFrame.fromEulerAnglesYXZ(0, currentYaw, 0).LookVector
        local descendSpeed = -math.clamp(0.5 + math.max(clearance, 0) * 0.75, 0.5, 9)
        local velocity = Vector3.new(dir.X * currentSpeed, descendSpeed, dir.Z * currentSpeed)

        if motionState == "APPROACH" and clearance <= 3.5 and currentSpeed <= 35 then
            motionState = "LANDING"
        end

        if motionState == "LANDING" and clearance <= 0.35 and currentSpeed <= 18
            and math.abs(dtRoot.AssemblyLinearVelocity.Y) <= 8 then
            motionState = "GROUNDED_IDLE"
            -- No trote accidental al tocar suelo si W no esta presionada.
            groundMoveSpeed = playerInputs.forward > 0.15
                and math.min(GROUND_RUN_SPEED, currentSpeed) or 0
            groundLostTime = 0
            setGroundHorizontalDrive(true)
        end

        return velocity, orientation
    end

    if motionState == "TAKEOFF" then
        takeoffTime += dt
        -- Ventana de transicion: evita que la gravedad y el sensor reactiven el apoyo.
        -- Utiliza los mismos actuadores originales, sin impulso/teletransporte directo.
        local heading = CFrame.fromEulerAnglesYXZ(0, currentYaw, 0)
        local forward = heading.LookVector
        if takeoffTime >= TAKEOFF_TRANSITION_DURATION then
            motionState = "FLIGHT"
        end
        return Vector3.new(forward.X * currentSpeed, TAKEOFF_VERTICAL_SPEED, forward.Z * currentSpeed),
            heading
    end

    -- Baches/acantilados: perder apoyo NO significa despegue voluntario.
    -- Primero se conserva la inercia terrestre y se permite caer por gravedad;
    -- solo si la caida continua se reincorpora el vuelo con velocidad inicial real.
    if motionState == "GROUND_RECOVERY" then
        recoveryTime += dt
        groundV01:DisableSupport()
        setGroundHorizontalDrive(true) -- Y libre: gravedad real

        local heading = CFrame.fromEulerAnglesYXZ(0, currentYaw, 0)
        local forward = heading.LookVector
        local supportAgain = sensor.valid and clearance <= 2.2
            and math.abs(dtRoot.CFrame.UpVector:Dot(Vector3.yAxis)) > 0.65

        if supportAgain then
            motionState = "GROUNDED_IDLE"
            groundLostTime = 0
            groundMoveSpeed = playerInputs.forward > 0.15 and recoveryPlanarSpeed or 0
            collisionV022:SetActive(true)
            groundV01:ApplyGroundSupport(sensor)
            return Vector3.new(forward.X * groundMoveSpeed, 0, forward.Z * groundMoveSpeed), heading
        end

        if recoveryTime >= 1.0 then
            motionState = "FLIGHT"
            groundLostTime = 0
            currentSpeed = math.clamp(recoveryPlanarSpeed, 15, 40)
            currentFlightDir = forward
            currentPitch = 0
            currentRoll = 0
            currentYawRate = 0
            currentTurnInput = 0
            setGroundHorizontalDrive(false)
            return Vector3.new(
                forward.X * currentSpeed,
                math.min(0, dtRoot.AssemblyLinearVelocity.Y),
                forward.Z * currentSpeed
            ), heading
        end

        return Vector3.new(
            forward.X * recoveryPlanarSpeed,
            0,  -- componente Y libre porque MaxAxesForce.Y=0
            forward.Z * recoveryPlanarSpeed
        ), heading
    end

    if motionState == "GROUNDED_IDLE" or motionState == "GROUNDED_RUN" then
        -- Despegue voluntario desde tierra: Space, sin reiniciar el mapa.
        if playerInputs.vertical > 0.5 then
            motionState = "TAKEOFF"
            takeoffTime = 0
            currentPitch = 0
            currentRoll = 0
            currentTurnInput = 0
            currentYawRate = 0
            groundMoveSpeed = 0
            currentFlightDir = CFrame.fromEulerAnglesYXZ(0, currentYaw, 0).LookVector
            currentSpeed = math.max(18, dtRoot.AssemblyLinearVelocity.Magnitude)
            currentVerticalVel = TAKEOFF_VERTICAL_SPEED
            groundV01:DisableSupport()
            setGroundHorizontalDrive(false)
            local heading = CFrame.fromEulerAnglesYXZ(0, currentYaw, 0)
            return currentFlightDir * currentSpeed + Vector3.new(0, TAKEOFF_VERTICAL_SPEED, 0),
                heading
        end
        if not sensor.valid or clearance > 3 then
            groundLostTime += dt
        else
            groundLostTime = 0
        end

        if groundLostTime >= 0.4 then
            -- Superficie perdida: recuperar control aereo, no teletransportar.
            motionState = "GROUND_RECOVERY"
            recoveryTime = 0
            local realVelocity = dtRoot.AssemblyLinearVelocity
            recoveryPlanarSpeed = Vector3.new(realVelocity.X,0,realVelocity.Z).Magnitude
            recoveryPlanarSpeed = math.clamp(recoveryPlanarSpeed, 0, GROUND_SPRINT_SPEED)
            groundMoveSpeed = recoveryPlanarSpeed
            groundV01:DisableSupport()
            setGroundHorizontalDrive(true)
            local heading = CFrame.fromEulerAnglesYXZ(0,currentYaw,0)
            local forward = heading.LookVector
            return Vector3.new(forward.X*recoveryPlanarSpeed,0,forward.Z*recoveryPlanarSpeed), heading
        end

        local movingForward = playerInputs.forward > 0.15
        local desiredSpeed = movingForward and
            (playerInputs.boost and GROUND_SPRINT_SPEED or GROUND_RUN_SPEED) or 0
        local approachRate = movingForward and 3.5 or 7.5
        -- Predictive collision braking: no usar fuerza de 39 studs/s contra un muro.
        -- El cast no toca el rig; reporta distancia hasta superficie solida.
        local obstacle = groundV01:ProbeObstacle(math.max(groundMoveSpeed, 1))
        obstacleDistance = obstacle.distance or math.huge
        if obstacle.blocked then
            local maxAllowed = math.sqrt(math.max(0, 2 * 62 * (obstacle.distance - 1.25)))
            desiredSpeed = math.min(desiredSpeed, maxAllowed)
            approachRate = 9
        end
        groundMoveSpeed += (desiredSpeed - groundMoveSpeed) * (1 - math.exp(-approachRate * dt))
        motionState = (movingForward and groundMoveSpeed > 2 or groundMoveSpeed > 3)
            and "GROUNDED_RUN" or "GROUNDED_IDLE"

        -- Giro terrestre: guiñada suave, sin alabeo de vuelo.
        currentYaw = (currentYaw - playerInputs.turn * GROUND_TURN_RATE * dt) % (2 * math.pi)
        currentPitch = 0
        currentRoll = 0
        local orientation = CFrame.fromEulerAnglesYXZ(0, currentYaw, 0)
        local forward = orientation.LookVector
        groundV01:ApplyGroundSupport(sensor)
        setGroundHorizontalDrive(true)
        return Vector3.new(forward.X * groundMoveSpeed, 0, forward.Z * groundMoveSpeed), orientation
    end

    return defaultVelocity, defaultOrientation
end

-- =============================================================================
-- 3. ESCUCHA DE INPUTS DESDE CLIENTE
-- =============================================================================
flightInputRemote.OnServerEvent:Connect(function(player, inputPacket)
	if type(inputPacket) == "table" then
		playerInputs.forward = math.clamp(tonumber(inputPacket.forward) or 0, -1, 1)
		playerInputs.turn = math.clamp(tonumber(inputPacket.turn) or 0, -1, 1)
		playerInputs.vertical = math.clamp(tonumber(inputPacket.vertical) or 0, -1, 1)
        playerInputs.boost = (inputPacket.boost == true)
		playerInputs.aimTurn = math.clamp(tonumber(inputPacket.aimTurn) or 0, -1, 1)
		playerInputs.aimPitch = math.clamp(tonumber(inputPacket.aimPitch) or 0, -1, 1)
		playerInputs.aimYawError = tonumber(inputPacket.aimYawError) or 0
		playerInputs.aimPitchError = tonumber(inputPacket.aimPitchError) or 0
		playerInputs.camAimYaw = tonumber(inputPacket.camAimYaw) or 0
		
		-- Sampled logging servidor (5-10 Hz durante intención de aim activa o error angular)
		local nowClock = os.clock()
		if (nowClock - lastServerAimLogClock >= 0.15) and (math.abs(playerInputs.aimTurn) > 0.01 or math.abs(playerInputs.aimPitch) > 0.01 or math.abs(playerInputs.aimYawError) > 1.0) then
			lastServerAimLogClock = nowClock
			print(string.format("[SERVER RECV AIM] player: %s | aimTurn: %+5.2f | aimPitch: %+5.2f | yawErr: %+5.1f° | pitchErr: %+5.1f° | camYaw: %+5.1f°",
				player.Name, playerInputs.aimTurn, playerInputs.aimPitch, playerInputs.aimYawError, playerInputs.aimPitchError, playerInputs.camAimYaw))
		end

		-- Disparo del Boost (Evento de Presentación Multietapa)
		if inputPacket.boost == true and motionState ~= "GROUNDED_IDLE" and motionState ~= "GROUNDED_RUN" and not isBoosting and boostCooldownTimer <= 0 then
			isBoosting = true
			boostTimer = WyvernFlightConfig.BoostDuration
			boostElapsed = 0.0
			boostStage = "START"
			dtRoot:SetAttribute("Flight_BoostImpulseTick", tick())
		end
	end
end)

resetRemote.OnServerEvent:Connect(function(player)
	resetToAerialSpawn()
end)

-- =============================================================================
-- 4. BUCLE DE INTEGRACIÓN FÍSICA (HEARTBEAT)
-- =============================================================================
RunService.Heartbeat:Connect(function(dt)
	dt = math.clamp(dt, 0.001, 0.1)

	-- 1. Gestión del Boost por Etapas (DragonWorld FSM: START -> ACCEL -> SUSTAIN -> RELEASE -> RECOVERY)
	if isBoosting then
		boostTimer = boostTimer - dt
		boostElapsed = boostElapsed + dt

		if boostElapsed < WyvernFlightConfig.BoostStartDuration then
			boostStage = "START"
		elseif boostElapsed < (WyvernFlightConfig.BoostStartDuration + 0.60) then
			boostStage = "ACCELERATING"
		elseif boostElapsed < (WyvernFlightConfig.BoostDuration - WyvernFlightConfig.BoostReleaseDuration) then
			boostStage = "SUSTAIN"
		else
			boostStage = "RELEASE"
		end

		if boostTimer <= 0 then
			isBoosting = false
			boostStage = "RECOVERY"
			boostCooldownTimer = WyvernFlightConfig.BoostCooldown
		end
	elseif boostCooldownTimer > 0 then
		boostCooldownTimer = math.max(0, boostCooldownTimer - dt)
		if boostCooldownTimer <= 0 then
			boostStage = "NORMAL"
		else
			boostStage = "RECOVERY"
		end
	else
		boostStage = "NORMAL"
	end

	-- 2. Dinámica de Velocidad Longitudinal (Convergencia con peso)
	local targetSpeed
	local currentAccel

	if isBoosting then
		targetSpeed = WyvernFlightConfig.BoostMaxSpeed
		currentAccel = WyvernFlightConfig.BoostAcceleration
	elseif playerInputs.forward > 0 then
		targetSpeed = WyvernFlightConfig.MaxSpeed
		currentAccel = WyvernFlightConfig.Acceleration
	elseif playerInputs.forward < 0 then
		targetSpeed = WyvernFlightConfig.MinSpeed
		currentAccel = WyvernFlightConfig.BrakeDeceleration
	else
		targetSpeed = WyvernFlightConfig.CruiseSpeed
		currentAccel = (currentSpeed > WyvernFlightConfig.CruiseSpeed) and WyvernFlightConfig.BoostReturnSmooth or WyvernFlightConfig.Deceleration
	end

	if currentSpeed < targetSpeed then
		currentSpeed = math.min(targetSpeed, currentSpeed + currentAccel * dt)
	elseif currentSpeed > targetSpeed then
		currentSpeed = math.max(targetSpeed, currentSpeed - currentAccel * dt)
	end

	-- Combinación autoritativa de control manual y aim (Sección 8)
	local finalTurnIntent = math.clamp(playerInputs.turn + playerInputs.aimTurn, -1, 1)
	local finalPitchIntent = math.clamp(playerInputs.vertical + playerInputs.aimPitch, -1, 1)

	-- 3. Interpolación Suave de Entrada de Giro (A/D + Aim Smoothing)
	local targetTurn = finalTurnIntent
	local turnAlpha = 1.0 - math.exp(-WyvernFlightConfig.TurnResponse * dt)
	currentTurnInput = currentTurnInput + (targetTurn - currentTurnInput) * turnAlpha

	-- 4. Roll / Bank Coordinado con Tasa Dinámica de Entrada/Salida
	local maxTurnRollRad = math.rad(WyvernFlightConfig.MaxTurnRoll)
	local targetRoll = -currentTurnInput * maxTurnRollRad

	local rollRateFactor = (math.abs(targetTurn) > 0.01) and WyvernFlightConfig.RollAcceleration or WyvernFlightConfig.RollReturn
	local rollAlpha = 1.0 - math.exp(-rollRateFactor * dt)
	currentRoll = currentRoll + (targetRoll - currentRoll) * rollAlpha

	-- 5. True Yaw Steering Coordinado y Escalonado (Biological Lean-First Steering)
	local bankFraction = math.clamp(math.abs(currentRoll) / maxTurnRollRad, 0, 1)
	-- Curva de autoridad: el alabeo visual inicia primero; la fuerza de guiñada entra progresivamente
	local turnAuthority = math.pow(bankFraction, 1.25)

	-- Modulación según velocidad (menos autoridad a baja velocidad, máxima en crucero/boost)
	local speedRatio = currentSpeed / WyvernFlightConfig.CruiseSpeed
	local speedFactor = math.clamp(speedRatio, WyvernFlightConfig.SpeedTurnMin, WyvernFlightConfig.SpeedTurnMax)

	-- Escalonamiento: el yaw base se acopla suavemente al banco para evitar giro plano instantáneo
	local effectiveBaseYaw = WyvernFlightConfig.BaseYawRate * (0.30 + 0.70 * turnAuthority)
	local calculatedYawRateDeg = (effectiveBaseYaw + WyvernFlightConfig.TurnYawBonus * turnAuthority) * speedFactor
	local targetYawRate = -currentTurnInput * math.rad(calculatedYawRateDeg)

	local yawSmoothAlpha = 1.0 - math.exp(-WyvernFlightConfig.YawSmoothing * dt)
	currentYawRate = currentYawRate + (targetYawRate - currentYawRate) * yawSmoothAlpha

	-- El mouse NO dirige al dragon en tierra: solo A/D gira el cuerpo.
    -- Impide que el aim aereo anterior acumule guiñada durante el estado suelo.
    if motionState == "GROUNDED_IDLE" or motionState == "GROUNDED_RUN" then
        currentYawRate = 0
        currentTurnInput = 0
    else
        currentYaw = (currentYaw + currentYawRate * dt) % (2 * math.pi)
    end

	-- 6. Dinámica de Cabeceo (Pitch) y Movimiento Vertical (Manual + Aim)
	local targetPitch
	if finalPitchIntent > 0 then
		targetPitch = math.rad(WyvernFlightConfig.MaxPitchUp) * finalPitchIntent
	elseif finalPitchIntent < 0 then
		targetPitch = math.rad(-WyvernFlightConfig.MaxPitchDown) * math.abs(finalPitchIntent)
	else
		targetPitch = 0.0
	end

	local pitchAlpha = 1.0 - math.exp(-WyvernFlightConfig.PitchSmooth * dt)
	currentPitch = currentPitch + (targetPitch - currentPitch) * pitchAlpha

	local targetVertVel = finalPitchIntent * WyvernFlightConfig.VerticalSpeed
	local vertAlpha = 1.0 - math.exp(-WyvernFlightConfig.VerticalSmooth * dt)
	currentVerticalVel = currentVerticalVel + (targetVertVel - currentVerticalVel) * vertAlpha

	-- 7. Curvatura Física de la Trayectoria de Velocidad (FlightDirectionResponse)
	local dragonOrientationCF = CFrame.fromEulerAnglesYXZ(currentPitch, currentYaw, 0)
	local desiredFlightDir = dragonOrientationCF.LookVector

	local dirAlpha = 1.0 - math.exp(-WyvernFlightConfig.FlightDirectionResponse * dt)
	currentFlightDir = currentFlightDir:Lerp(desiredFlightDir, dirAlpha).Unit

	local forwardVelocity = currentFlightDir * currentSpeed
	local finalVelocity = Vector3.new(
		forwardVelocity.X,
		currentVerticalVel + (math.sin(currentPitch) * currentSpeed * 0.4),
		forwardVelocity.Z
	)

	-- 8. Una sola autoridad fisica para aire, aproximacion y tierra.
    local sensedGround = groundV01:Sense()
    local velocityCommand, orientationCommand = resolveSurfaceMotion(
        dt, sensedGround, finalVelocity,
        CFrame.fromEulerAnglesYXZ(currentPitch, currentYaw, currentRoll)
    )
    linearVelocity.VectorVelocity = velocityCommand
    alignOrientation.CFrame = orientationCommand
    collisionV022:SetActive(motionState == "GROUNDED_RUN"
        or motionState == "GROUNDED_IDLE" or motionState == "GROUND_RECOVERY")
    dtRoot:SetAttribute("Wyvern_MotionState", motionState)
    dtRoot:SetAttribute("Wyvern_GroundClearance", sensedGround.valid and sensedGround.clearance or -999)
    dtRoot:SetAttribute("Wyvern_GroundProbeCount", sensedGround.hitCount)
    dtRoot:SetAttribute("Wyvern_GroundSpeed", groundMoveSpeed)
    dtRoot:SetAttribute("Wyvern_ObstacleDistance",
        obstacleDistance == math.huge and -1 or obstacleDistance)
    dtRoot:SetAttribute("Wyvern_RunNominalSpeed", GROUND_RUN_SPEED)
    dtRoot:SetAttribute("Wyvern_RunSprintSpeed", GROUND_SPRINT_SPEED)
    dtRoot:SetAttribute("Wyvern_CanLand", sensedGround.valid
        and sensedGround.clearance > 0.25 and sensedGround.clearance <= 30)

	-- 9. Sincronización de Atributos de Telemetría (Sensor de Estado Fase R3 / R3.1 / R4)
	local headingDeg = math.deg(currentYaw)
	local velHoriz = Vector3.new(currentFlightDir.X, 0, currentFlightDir.Z)
	local velHeadingDeg = (velHoriz.Magnitude > 0.001) and math.deg(math.atan2(-velHoriz.X, -velHoriz.Z)) or headingDeg
	local headingErrorDeg = ((headingDeg - velHeadingDeg + 180) % 360) - 180

	-- Telemetría de Dirección y Biología (R3 / R3.1)
	dtRoot:SetAttribute("Flight_TurnInput", math.floor(playerInputs.turn * 100) / 100)
	dtRoot:SetAttribute("Flight_CurrentRoll", math.floor(math.deg(currentRoll) * 10) / 10)
	dtRoot:SetAttribute("Flight_TargetRoll", math.floor(math.deg(targetRoll) * 10) / 10)
	dtRoot:SetAttribute("Flight_YawRate", math.floor(math.deg(currentYawRate) * 10) / 10)
	dtRoot:SetAttribute("Flight_Heading", math.floor(headingDeg * 10) / 10)
	dtRoot:SetAttribute("Flight_HeadingDeltaPerSecond", math.floor(math.deg(currentYawRate) * 10) / 10)
	dtRoot:SetAttribute("Flight_VelocityHeading", math.floor(velHeadingDeg * 10) / 10)
	dtRoot:SetAttribute("Flight_VelocityHeadingError", math.floor(headingErrorDeg * 10) / 10)
	dtRoot:SetAttribute("Flight_VelocityDirection", string.format("(%.2f, %.2f, %.2f)", currentFlightDir.X, currentFlightDir.Y, currentFlightDir.Z))
	dtRoot:SetAttribute("Flight_Speed", math.floor(currentSpeed * 10) / 10)
	dtRoot:SetAttribute("Flight_VerticalSpeed", math.floor(finalVelocity.Y * 10) / 10)
	dtRoot:SetAttribute("Flight_Pitch", math.floor(math.deg(currentPitch) * 10) / 10)
	dtRoot:SetAttribute("Flight_Roll", math.floor(math.deg(currentRoll) * 10) / 10)
	dtRoot:SetAttribute("Flight_Yaw", math.floor(headingDeg * 10) / 10)
	dtRoot:SetAttribute("Flight_IsTurning", math.abs(finalTurnIntent) > 0.05)
	dtRoot:SetAttribute("Flight_IsBoosting", isBoosting)
	dtRoot:SetAttribute("Flight_BoostStage", boostStage)
	dtRoot:SetAttribute("Flight_BoostCooldown", math.floor(boostCooldownTimer * 10) / 10)
	dtRoot:SetAttribute("Flight_State", isBoosting and "BOOST" or (finalPitchIntent > 0.2 and "CLIMB" or (finalPitchIntent < -0.2 and "DIVE" or (math.abs(finalTurnIntent) > 0.05 and "TURN" or "CRUISE"))))

	-- Telemetría de Mouse Aim (Fase R4 Diagnóstico - Sección 18)
	dtRoot:SetAttribute("Flight_AimYawError", math.floor(playerInputs.aimYawError * 10) / 10)
	dtRoot:SetAttribute("Flight_AimPitchError", math.floor(playerInputs.aimPitchError * 10) / 10)
	dtRoot:SetAttribute("Flight_AimTurnIntent", math.floor(playerInputs.aimTurn * 100) / 100)
	dtRoot:SetAttribute("Flight_AimPitchIntent", math.floor(playerInputs.aimPitch * 100) / 100)
	dtRoot:SetAttribute("Flight_FinalTurnIntent", math.floor(finalTurnIntent * 100) / 100)
	dtRoot:SetAttribute("Flight_FinalPitchIntent", math.floor(finalPitchIntent * 100) / 100)
	dtRoot:SetAttribute("Flight_CameraAimYaw", math.floor(playerInputs.camAimYaw * 10) / 10)
end)

-- Auto-montura del jinete en DT_NeckSeat para streaming y control visual
local Players = game:GetService("Players")

local function seatPlayerOnWyvern(player)
	local char = player.Character or player.CharacterAdded:Wait()
	local hum = char:WaitForChild("Humanoid", 10)
	local hrp = char:WaitForChild("HumanoidRootPart", 10)
	local seat = wyvern:FindFirstChild("DT_NeckSeat")
	if seat and hum and hrp then
		task.wait(0.2)
		hrp.CFrame = seat.CFrame + Vector3.new(0, 2, 0)
		seat:Sit(hum)
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		task.wait(0.5)
		seatPlayerOnWyvern(player)
	end)
	if player.Character then
		seatPlayerOnWyvern(player)
	end
end)

for _, p in ipairs(Players:GetPlayers()) do
	if p.Character then
		seatPlayerOnWyvern(p)
	end
end

-- Spawn aéreo inicial al arrancar el servidor
task.spawn(function()
	task.wait(1.5)
	resetToAerialSpawn()
	print("[FlightController V2] Servidor de Vuelo Listo en Spawn Aéreo (Fase R1).")
end)
