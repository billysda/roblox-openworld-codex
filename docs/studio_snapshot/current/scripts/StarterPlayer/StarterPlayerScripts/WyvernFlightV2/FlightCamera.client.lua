-- FlightCamera.client.lua
-- Cámara Cinematográfica de Persecución DragonWorld para Vuelo de Wyvern (Fase R2)
-- Reproduce fielmente ZoomCam.cs, CameraEffectsManager.cs y Cameras.cs:
-- 1. Órbitas verticales FreeLook (Top/Mid/Bot) adaptadas al cabeceo (Pitch).
-- 2. Damping separado de rotación (Yaw lag) y posición (Inercia y peso del wyvern).
-- 3. Curva de zoom no lineal y pullback dinámico en BOOST.
-- 4. Alabeo cinematográfico coordinado (Bank factor 35%).
-- 5. Pipeline de FOV idéntico a ZoomCam (+20° sostenido, +8° por batido al impulsarse).
-- 6. Shake procedural multicapa con Perlin Noise (Crucero tranquilo 0.25x, Boost 1.5x, Impulso cuadrático).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local wyvernFlightV2 = ReplicatedStorage:WaitForChild("WyvernFlightV2")
local WyvernFlightConfig = require(wyvernFlightV2:WaitForChild("Config"):WaitForChild("WyvernFlightConfig"))
local FlightAimState = require(wyvernFlightV2:WaitForChild("FlightAimState"))

-- Estado de la cámara
local customCameraEnabled = true
local isCameraInitialized = false

local currentFOV = WyvernFlightConfig.MaxFOV
local smoothBoost = 0.0
local currentCamYaw = 0.0
local currentCamPitch = 0.0
local currentCamRoll = 0.0
local currentOrbitHeight = WyvernFlightConfig.OrbitMidHeight
local currentOrbitRadius = WyvernFlightConfig.OrbitMidRadius
local smoothTargetPos = Vector3.zero
local currentLookTarget = Vector3.zero
local currentCamPos = Vector3.zero
local isMouseLocked = false

local function setMouseLock(locked)
	isMouseLocked = locked
	FlightAimState.isMouseCaptured = locked
	if customCameraEnabled then
		if locked then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		else
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end
end

-- Captura de ratón: Clic Izquierdo captura, tecla M alterna libre/capturado
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if not isMouseLocked then
			setMouseLock(true)
		end
	elseif input.KeyCode == Enum.KeyCode.M then
		setMouseLock(not isMouseLocked)
	elseif input.KeyCode == Enum.KeyCode.C then
		customCameraEnabled = not customCameraEnabled
		enforceScriptableCamera()
		if not customCameraEnabled then
			setMouseLock(false)
		end
	end
end)

-- Captura continua de movimiento del mouse (Fase R4.1: Fuente única FlightAimState)
UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		local rmbHeld = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
		if isMouseLocked or rmbHeld then
			FlightAimState:ApplyMouseDelta(
				input.Delta.X,
				input.Delta.Y,
				WyvernFlightConfig.MouseSensitivity,
				WyvernFlightConfig.MaxPitchUp,
				WyvernFlightConfig.MaxPitchDown
			)
		else
			FlightAimState.lastMouseDeltaX = input.Delta.X
			FlightAimState.lastMouseDeltaY = input.Delta.Y
		end
	end
end)

-- Conexión de diagnóstico para inyección de delta físico de mouse en el VM del Player
local debugMouseDelta = wyvernFlightV2:FindFirstChild("DebugMouseDelta")
if not debugMouseDelta then
	debugMouseDelta = Instance.new("BindableEvent")
	debugMouseDelta.Name = "DebugMouseDelta"
	debugMouseDelta.Parent = wyvernFlightV2
end
debugMouseDelta.Event:Connect(function(dx, dy)
	FlightAimState:ApplyMouseDelta(
		dx,
		dy,
		WyvernFlightConfig.MouseSensitivity,
		WyvernFlightConfig.MaxPitchUp,
		WyvernFlightConfig.MaxPitchDown
	)
end)

-- Auto-capturar el ratón al inicio del vuelo para que no quede libre por defecto
task.spawn(function()
	task.wait(0.5)
	if customCameraEnabled and not isMouseLocked then
		setMouseLock(true)
	end
end)

-- Seguimiento de impulsos y efectos
local lastBoostImpulseTick = 0
local impulseShakeElapsed = 999.0
local boostTimerLocal = 0.0

local function getWyvern()
	return Workspace:FindFirstChild("wyvernfbx") or Workspace:FindFirstChild("DragonTierraRoblox")
end

local function getDTRoot()
	local wyvern = getWyvern()
	return wyvern and wyvern:FindFirstChild("DT_Root")
end

-- =============================================================================
-- CONTROL AUTORITATIVO DE CÁMARA (EVITA SOBRESCRITURA DE ROBROX CAMERAMODULE)
-- =============================================================================
local function enforceScriptableCamera()
	camera = Workspace.CurrentCamera
	if not camera then return end
	local dtRoot = getDTRoot()

	if customCameraEnabled and dtRoot then
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		if camera.CameraSubject ~= dtRoot then
			camera.CameraSubject = dtRoot
		end
	elseif not customCameraEnabled then
		if camera.CameraType ~= Enum.CameraType.Custom then
			camera.CameraType = Enum.CameraType.Custom
		end
		if player.Character and player.Character:FindFirstChild("Humanoid") then
			camera.CameraSubject = player.Character.Humanoid
		end
	end
end

enforceScriptableCamera()

if player.Character then
	task.spawn(enforceScriptableCamera)
end
player.CharacterAdded:Connect(function()
	task.wait(0.2)
	enforceScriptableCamera()
end)

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	camera = Workspace.CurrentCamera
	enforceScriptableCamera()
end)

camera:GetPropertyChangedSignal("CameraSubject"):Connect(function()
	local dtRoot = getDTRoot()
	if customCameraEnabled and dtRoot and camera.CameraSubject ~= dtRoot then
		camera.CameraSubject = dtRoot
		camera.CameraType = Enum.CameraType.Scriptable
	end
end)

camera:GetPropertyChangedSignal("CameraType"):Connect(function()
	if customCameraEnabled and camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.C then
		customCameraEnabled = not customCameraEnabled
		enforceScriptableCamera()
	end
end)

-- =============================================================================
-- BUCLE CINEMATOGRÁFICO DE PERSECUCIÓN DRAGONWORLD (RENDERSTEPPED)
-- =============================================================================
RunService.RenderStepped:Connect(function(dt)
	local dtRoot = getDTRoot()
	if not dtRoot or not customCameraEnabled then return end

	if not camera or camera ~= Workspace.CurrentCamera then
		camera = Workspace.CurrentCamera
	end
	if not camera then return end

	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end

	dt = math.clamp(dt, 0.001, 0.1)

	local rootCF = dtRoot.CFrame
	local velocity = dtRoot.AssemblyLinearVelocity
	local speed = velocity.Magnitude
	local isBoosting = dtRoot:GetAttribute("Flight_IsBoosting") or false
	local boostImpulseTick = dtRoot:GetAttribute("Flight_BoostImpulseTick") or 0

	-- 1. Detección de Impulso Inicial para Shake Cuadrático
	if boostImpulseTick ~= lastBoostImpulseTick and boostImpulseTick > 0 then
		lastBoostImpulseTick = boostImpulseTick
		impulseShakeElapsed = 0.0
		boostTimerLocal = 0.0
	end

	if isBoosting then
		boostTimerLocal = boostTimerLocal + dt
	else
		boostTimerLocal = 0.0
	end
	impulseShakeElapsed = impulseShakeElapsed + dt

	-- 2. Transición Progresiva de Boost (DragonWorld smoothBoost: 0 -> 1 -> 0 over 1.5s)
	local boostTarget = isBoosting and 1.0 or 0.0
	local boostStep = dt / WyvernFlightConfig.BoostTransitionSpeed
	if smoothBoost < boostTarget then
		smoothBoost = math.min(boostTarget, smoothBoost + boostStep)
	elseif smoothBoost > boostTarget then
		smoothBoost = math.max(boostTarget, smoothBoost - boostStep)
	end

	-- 3. Centroide Visual del Dragón con Suavizado de Target (Torso Anchor)
	local dragonVisualCenter = rootCF:PointToWorldSpace(WyvernFlightConfig.VisualCenterOffset)
	if not isCameraInitialized or (smoothTargetPos - dragonVisualCenter).Magnitude > 60.0 then
		smoothTargetPos = dragonVisualCenter
		local forwardHoriz = Vector3.new(rootCF.LookVector.X, 0, rootCF.LookVector.Z)
		local initYaw = (forwardHoriz.Magnitude > 0.001) and math.atan2(-forwardHoriz.X, -forwardHoriz.Z) or 0.0
		local initPitch = math.asin(math.clamp(rootCF.LookVector.Y, -0.99, 0.99))
		FlightAimState:ResetAim(initYaw, initPitch)
		currentCamYaw = initYaw
		currentCamPitch = initPitch
		currentOrbitHeight = WyvernFlightConfig.OrbitMidHeight
		currentOrbitRadius = WyvernFlightConfig.OrbitMidRadius
		local camHorizDir = (CFrame.Angles(0, currentCamYaw, 0) * Vector3.new(0, 0, 1))
		currentCamPos = smoothTargetPos + (camHorizDir * currentOrbitRadius) + Vector3.new(0, currentOrbitHeight, 0)
		currentLookTarget = smoothTargetPos + (rootCF.LookVector * 10.0)
		currentFOV = WyvernFlightConfig.MaxFOV
		isCameraInitialized = true
	else
		local alphaTarget = 1.0 - math.exp(-WyvernFlightConfig.TargetSmooth * dt)
		smoothTargetPos = smoothTargetPos:Lerp(dragonVisualCenter, alphaTarget)
	end

	-- 4. Geometría de 3 Órbitas FreeLook según Cabeceo (Ascenso -> Top, Nivelado -> Mid, Picada -> Bot)
	local pitchAngle = math.asin(math.clamp(rootCF.LookVector.Y, -0.99, 0.99))
	local targetHeight, targetRadius

	if pitchAngle >= 0 then
		local t = math.clamp(pitchAngle / math.rad(WyvernFlightConfig.MaxPitchUp), 0, 1)
		targetHeight = WyvernFlightConfig.OrbitMidHeight + (WyvernFlightConfig.OrbitTopHeight - WyvernFlightConfig.OrbitMidHeight) * t
		targetRadius = WyvernFlightConfig.OrbitMidRadius + (WyvernFlightConfig.OrbitTopRadius - WyvernFlightConfig.OrbitMidRadius) * t
	else
		local t = math.clamp(-pitchAngle / math.rad(WyvernFlightConfig.MaxPitchDown), 0, 1)
		targetHeight = WyvernFlightConfig.OrbitMidHeight + (WyvernFlightConfig.OrbitBotHeight - WyvernFlightConfig.OrbitMidHeight) * t
		targetRadius = WyvernFlightConfig.OrbitMidRadius + (WyvernFlightConfig.OrbitBotRadius - WyvernFlightConfig.OrbitMidRadius) * t
	end

	local alphaOrbit = 1.0 - math.exp(-WyvernFlightConfig.PositionSmooth * dt)
	currentOrbitHeight = currentOrbitHeight + (targetHeight - currentOrbitHeight) * alphaOrbit
	currentOrbitRadius = currentOrbitRadius + (targetRadius - currentOrbitRadius) * alphaOrbit

	-- 5. Curva de Zoom No Lineal y Pullback en BOOST (DragonWorld ZoomCam)
	local zoomFactor = math.pow(math.clamp(WyvernFlightConfig.DefaultZAxis, 0, 1), WyvernFlightConfig.ZoomCurvePower)
	local currentZoom = WyvernFlightConfig.MaxZoom + (WyvernFlightConfig.MinZoom - WyvernFlightConfig.MaxZoom) * zoomFactor
	local boostPullback = smoothBoost * WyvernFlightConfig.BoostCameraPullback
	local totalOrbitDistance = (currentOrbitRadius * currentZoom) + boostPullback

	-- 6. Suavizado Cinematográfico de Orientación de Cámara hacia FlightAimState
	-- La cámara persigue el rumbo y la elevación apuntados por el jugador,
	-- sin recentrar sobre el heading del wyvern mientras el jugador apunta.
	local diffAimYaw = (FlightAimState.playerAimYaw - currentCamYaw)
	diffAimYaw = (diffAimYaw + math.pi) % (2 * math.pi) - math.pi
	local alphaCamRot = 1.0 - math.exp(-WyvernFlightConfig.RotationSmooth * dt)
	currentCamYaw = currentCamYaw + diffAimYaw * alphaCamRot

	local diffAimPitch = (FlightAimState.playerAimPitch - currentCamPitch)
	local alphaCamPitch = 1.0 - math.exp(-WyvernFlightConfig.PitchSmooth * dt)
	currentCamPitch = currentCamPitch + diffAimPitch * alphaCamPitch

	-- 7. Posición Base de Cámara con Retraso Dinámico (Position Lag con peso)
	local camHorizDir = (CFrame.Angles(0, currentCamYaw, 0) * Vector3.new(0, 0, 1))
	local desiredCamPos = smoothTargetPos + (camHorizDir * totalOrbitDistance) + Vector3.new(0, currentOrbitHeight - math.sin(currentCamPitch) * 6.0, 0)
	local alphaPos = 1.0 - math.exp(-WyvernFlightConfig.PositionSmooth * dt)
	currentCamPos = currentCamPos:Lerp(desiredCamPos, alphaPos)

	-- 8. Look-Ahead Dinámico hacia la dirección de aim (FlightAimState)
	local camAimDir = FlightAimState:GetAimDirection()
	local lookAheadDistance = math.clamp(speed * WyvernFlightConfig.LookAheadFactor, 4.0, 24.0)
	local desiredLookTarget = smoothTargetPos + (camAimDir * lookAheadDistance)
	local alphaTargetLook = 1.0 - math.exp(-WyvernFlightConfig.TargetSmooth * dt)
	currentLookTarget = currentLookTarget:Lerp(desiredLookTarget, alphaTargetLook)

	-- 9. Alabeo Cinematográfico (Camera Bank en giros coordinados)
	local dragonRollRad = math.rad(dtRoot:GetAttribute("Flight_Roll") or 0.0)
	local targetCamRoll = dragonRollRad * WyvernFlightConfig.CameraBankFactor
	currentCamRoll = currentCamRoll + (targetCamRoll - currentCamRoll) * (1.0 - math.exp(-8.0 * dt))

	local baseLookAtCF = CFrame.lookAt(currentCamPos, currentLookTarget)
	local bankedCF = baseLookAtCF * CFrame.Angles(0, 0, currentCamRoll)

	-- 10. Pipeline de FOV Dinámico (DragonWorld ZoomCam: num3 + sustained + flap)
	local flapWave = isBoosting and math.max(0, math.sin(boostTimerLocal * math.pi * 2 * 1.6)) or 0.0
	local targetFOV = WyvernFlightConfig.MaxFOV + (smoothBoost * WyvernFlightConfig.BoostSustainedFOV) + (smoothBoost * flapWave * WyvernFlightConfig.BoostImpulseFOV)
	local alphaFOV = 1.0 - math.exp(-WyvernFlightConfig.FOVSmooth * dt)
	currentFOV = currentFOV + (targetFOV - currentFOV) * alphaFOV
	camera.FieldOfView = math.clamp(currentFOV, 35.0, 100.0)

	-- 11. Camera Shake Multicapa con Perlin Noise (CameraEffectsManager)
	local extraImpulseAmp = 0.0
	if impulseShakeElapsed < WyvernFlightConfig.ImpulseShakeDuration then
		local tImpulse = impulseShakeElapsed / WyvernFlightConfig.ImpulseShakeDuration
		extraImpulseAmp = WyvernFlightConfig.ImpulseShakeAmp * math.pow(1.0 - tImpulse, 2.0)
	end

	local baseShakeAmp = (isBoosting and WyvernFlightConfig.BoostShakeAmpMult or WyvernFlightConfig.BaseShakeAmpMult)
	local totalShakeAmp = baseShakeAmp + extraImpulseAmp
	local shakeFreq = (isBoosting and WyvernFlightConfig.BoostShakeFreqMult or WyvernFlightConfig.BaseShakeFreqMult)

	local tNow = tick()
	local noisePitch = math.noise(tNow * shakeFreq * 5.2, 11.2, 0) * (0.007 * totalShakeAmp)
	local noiseYaw   = math.noise(tNow * shakeFreq * 4.7, 23.4, 0) * (0.007 * totalShakeAmp)
	local noiseRoll  = math.noise(tNow * shakeFreq * 6.1, 37.8, 0) * (0.010 * totalShakeAmp)
	local noiseX     = math.noise(tNow * shakeFreq * 7.0, 49.1, 0) * (0.10 * totalShakeAmp)
	local noiseY     = math.noise(tNow * shakeFreq * 6.5, 62.3, 0) * (0.10 * totalShakeAmp)

	local finalCameraCF = bankedCF * CFrame.new(noiseX, noiseY, 0) * CFrame.Angles(noisePitch, noiseYaw, noiseRoll)
	camera.CFrame = finalCameraCF
end)

print("[FlightCamera V2] Cámara cinematográfica DragonWorld (Fase R2) lista y activa.")
