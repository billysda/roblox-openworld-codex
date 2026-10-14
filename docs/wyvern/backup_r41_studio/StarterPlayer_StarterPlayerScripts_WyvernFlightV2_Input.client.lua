-- Input.client.lua
-- Captura de Input del Jugador y Telemetría Mínima de Vuelo (Fase R1)
-- Transmite la intención del jugador al servidor y muestra métricas de vuelo sin sobrecarga.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local wyvernFlightV2 = ReplicatedStorage:WaitForChild("WyvernFlightV2")
local WyvernFlightConfig = require(wyvernFlightV2:WaitForChild("Config"):WaitForChild("WyvernFlightConfig"))
local FlightAimState = require(wyvernFlightV2:WaitForChild("FlightAimState"))
local remotesFolder = wyvernFlightV2:WaitForChild("Remotes")
local flightInputRemote = remotesFolder:WaitForChild("FlightInput")
local resetRemote = remotesFolder:WaitForChild("ResetCommand")

local function getWyvern()
	return Workspace:FindFirstChild("wyvernfbx") or Workspace:FindFirstChild("DragonTierraRoblox")
end

local function getDTRoot()
	local wyvern = getWyvern()
	return wyvern and wyvern:FindFirstChild("DT_Root")
end

-- =============================================================================
-- 1. HUD TELEMÉTRICO MÍNIMO (Punto 26)
-- =============================================================================
local playerGui = player:WaitForChild("PlayerGui")
local existingHud = playerGui:FindFirstChild("WyvernFlightHUD_V2")
if existingHud then existingHud:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WyvernFlightHUD_V2"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Panel de Telemetría (Arriba a la derecha)
local telemetryFrame = Instance.new("Frame")
telemetryFrame.Name = "TelemetryPanel"
telemetryFrame.Size = UDim2.new(0, 340, 0, 340)
telemetryFrame.Position = UDim2.new(1, -360, 0, 20)
telemetryFrame.BackgroundColor3 = Color3.fromRGB(12, 16, 22)
telemetryFrame.BackgroundTransparency = 0.25
telemetryFrame.BorderSizePixel = 0
telemetryFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = telemetryFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 24)
title.BackgroundTransparency = 1
title.Text = "WYVERN FLIGHT V2 (MOUSE AIM R4.1)"
title.TextColor3 = Color3.fromRGB(245, 195, 65)
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.Parent = telemetryFrame

local dataLabel = Instance.new("TextLabel")
dataLabel.Size = UDim2.new(1, -20, 1, -28)
dataLabel.Position = UDim2.new(0, 10, 0, 24)
dataLabel.BackgroundTransparency = 1
dataLabel.TextColor3 = Color3.fromRGB(225, 235, 245)
dataLabel.Font = Enum.Font.Code
dataLabel.TextSize = 12
dataLabel.TextXAlignment = Enum.TextXAlignment.Left
dataLabel.TextYAlignment = Enum.TextYAlignment.Top
dataLabel.Parent = telemetryFrame

-- Panel de Controles (Arriba a la izquierda)
local controlsFrame = Instance.new("Frame")
controlsFrame.Name = "ControlsPanel"
controlsFrame.Size = UDim2.new(0, 240, 0, 205)
controlsFrame.Position = UDim2.new(0, 20, 0, 20)
controlsFrame.BackgroundColor3 = Color3.fromRGB(12, 16, 22)
controlsFrame.BackgroundTransparency = 0.35
controlsFrame.BorderSizePixel = 0
controlsFrame.Parent = screenGui

local controlsCorner = Instance.new("UICorner")
controlsCorner.CornerRadius = UDim.new(0, 8)
controlsCorner.Parent = controlsFrame

local controlsTitle = Instance.new("TextLabel")
controlsTitle.Size = UDim2.new(1, 0, 0, 24)
controlsTitle.BackgroundTransparency = 1
controlsTitle.Text = "FLIGHT CONTROLS (V2)"
controlsTitle.TextColor3 = Color3.fromRGB(110, 190, 255)
controlsTitle.Font = Enum.Font.GothamBold
controlsTitle.TextSize = 12
controlsTitle.Parent = controlsFrame

local controlsLabel = Instance.new("TextLabel")
controlsLabel.Size = UDim2.new(1, -20, 1, -28)
controlsLabel.Position = UDim2.new(0, 10, 0, 24)
controlsLabel.BackgroundTransparency = 1
controlsLabel.TextColor3 = Color3.fromRGB(205, 215, 230)
controlsLabel.Font = Enum.Font.Code
controlsLabel.TextSize = 11
controlsLabel.TextXAlignment = Enum.TextXAlignment.Left
controlsLabel.TextYAlignment = Enum.TextYAlignment.Top
controlsLabel.Text = "[Mouse]   : Dirigir Vuelo\n[Clic Izq]: Capturar Ratón\n[M]       : Liberar Ratón\n[W]       : Acelerar\n[S]       : Frenar\n[A] / [D] : Alabeo / Giro aux\n[Space]   : Ascender manual\n[LCtrl]   : Descender manual\n[Shift]   : BOOST (Impulso)\n[R]       : Reiniciar Spawn"
controlsLabel.Parent = controlsFrame

-- =============================================================================
-- 2. GESTIÓN DE ENTRADA Y AIM
-- =============================================================================
local activeInputs = {
	forward = 0,
	turn = 0,
	vertical = 0,
	boost = false
}

local currentAimTurnIntent = 0.0
local currentAimPitchIntent = 0.0
local currentYawAimError = 0.0
local currentPitchAimError = 0.0
local currentCamAimYaw = 0.0
local lastSyncClock = 0.0
local lastAimLogClock = 0.0

local function syncInputToServer()
	flightInputRemote:FireServer({
		forward = activeInputs.forward,
		turn = activeInputs.turn,
		vertical = activeInputs.vertical,
		boost = activeInputs.boost,
		aimTurn = currentAimTurnIntent,
		aimPitch = currentAimPitchIntent,
		aimYawError = currentYawAimError,
		aimPitchError = currentPitchAimError,
		camAimYaw = currentCamAimYaw
	})
	lastSyncClock = os.clock()
end

local function recomputeInputs()
	local forward = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then forward = forward + 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then forward = forward - 1 end

	local turn = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then turn = turn + 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then turn = turn - 1 end

	local vertical = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vertical = vertical + 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then vertical = vertical - 1 end

	local boost = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)

	if forward ~= activeInputs.forward or turn ~= activeInputs.turn or vertical ~= activeInputs.vertical or boost ~= activeInputs.boost then
		activeInputs.forward = forward
		activeInputs.turn = turn
		activeInputs.vertical = vertical
		activeInputs.boost = boost
		syncInputToServer()
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.R then
		resetRemote:FireServer()
	else
		recomputeInputs()
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	recomputeInputs()
end)

-- Captura de métricas físicas de movimiento del ratón
UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		FlightAimState.lastMouseDeltaX = input.Delta.X
		FlightAimState.lastMouseDeltaY = input.Delta.Y
	end
end)

-- =============================================================================
-- 3. CÁLCULO DE AIM Y ACTUALIZACIÓN DE TELEMETRÍA (RENDERSTEPPED)
-- =============================================================================
RunService.RenderStepped:Connect(function(dt)
	dt = math.clamp(dt, 0.001, 0.1)
	local dtRoot = getDTRoot()
	if not dtRoot then return end

	local rootCF = dtRoot.CFrame
	local wyvernForward = rootCF.LookVector
	local aimDir = FlightAimState:GetAimDirection()

	-- 1. Error Horizontal de Aim (Yaw Error entre Wyvern y Dirección de Aim)
	local wfHoriz = Vector3.new(wyvernForward.X, 0, wyvernForward.Z)
	local aimHoriz = Vector3.new(aimDir.X, 0, aimDir.Z)
	local yawAimErrorDeg = 0.0
	local camAimYawDeg = 0.0
	local dragonYaw = 0.0

	if wfHoriz.Magnitude > 0.001 and aimHoriz.Magnitude > 0.001 then
		local wfUnit = wfHoriz.Unit
		local aimUnit = aimHoriz.Unit
		dragonYaw = math.atan2(-wfUnit.X, -wfUnit.Z)
		local dot = math.clamp(wfUnit:Dot(aimUnit), -1, 1)
		local crossY = wfUnit.Z * aimUnit.X - wfUnit.X * aimUnit.Z
		local signedYaw = math.atan2(crossY, dot)
		yawAimErrorDeg = math.deg(signedYaw)
		camAimYawDeg = math.deg(math.atan2(-aimUnit.X, -aimUnit.Z))
	end

	-- 2. Error Vertical de Aim (Pitch Error entre Wyvern y Dirección de Aim)
	local wyvernPitchRad = math.asin(math.clamp(wyvernForward.Y, -0.999, 0.999))
	local aimPitchRad = math.asin(math.clamp(aimDir.Y, -0.999, 0.999))
	local pitchAimErrorDeg = math.deg(aimPitchRad - wyvernPitchRad)

	-- 3. Cálculo Progresivo de Aim Turn Intent con Deadzone (Fase R4 / R4.1)
	local targetAimTurn = 0.0
	local absYawErr = math.abs(yawAimErrorDeg)
	if absYawErr > WyvernFlightConfig.AimTurnDeadzone then
		local deadzone = WyvernFlightConfig.AimTurnDeadzone
		local maxErr = WyvernFlightConfig.AimMaxYawError
		local frac = math.clamp((absYawErr - deadzone) / (maxErr - deadzone), 0, 1)
		-- yawAimErrorDeg < 0 -> mirando a la derecha -> virar derecha (intent > 0)
		-- yawAimErrorDeg > 0 -> mirando a la izquierda -> virar izquierda (intent < 0)
		targetAimTurn = (yawAimErrorDeg > 0 and -1 or 1) * frac * WyvernFlightConfig.AimTurnStrength
	else
		-- Dentro de la zona muerta: auto-alinear suavemente FlightAimState con el dragon
		-- para evitar acumulación de deriva durante vuelos rectos prolongados
		FlightAimState:SoftAlignWithDragon(dragonYaw, 1.0 - math.exp(-2.0 * dt))
	end

	-- Si el jugador está virando manualmente con A/D, alinear el aim con el wyvern para no pelear
	if math.abs(activeInputs.turn) > 0.05 then
		FlightAimState:SoftAlignWithDragon(dragonYaw, 1.0 - math.exp(-8.0 * dt))
	end

	local aimTurnAlpha = 1.0 - math.exp(-WyvernFlightConfig.AimTurnResponse * dt)
	currentAimTurnIntent = currentAimTurnIntent + (targetAimTurn - currentAimTurnIntent) * aimTurnAlpha

	-- 4. Cálculo Progresivo de Aim Pitch Intent con Deadzone
	local targetAimPitch = 0.0
	local absPitchErr = math.abs(pitchAimErrorDeg)
	if absPitchErr > WyvernFlightConfig.AimPitchDeadzone then
		local deadzone = WyvernFlightConfig.AimPitchDeadzone
		local maxErr = WyvernFlightConfig.AimMaxPitchError
		local frac = math.clamp((absPitchErr - deadzone) / (maxErr - deadzone), 0, 1)
		targetAimPitch = (pitchAimErrorDeg > 0 and 1 or -1) * frac * WyvernFlightConfig.AimPitchStrength
	end

	local aimPitchAlpha = 1.0 - math.exp(-WyvernFlightConfig.AimTurnResponse * dt)
	currentAimPitchIntent = currentAimPitchIntent + (targetAimPitch - currentAimPitchIntent) * aimPitchAlpha

	currentYawAimError = yawAimErrorDeg
	currentPitchAimError = pitchAimErrorDeg
	currentCamAimYaw = camAimYawDeg

	FlightAimState.aimYawErrorDeg = yawAimErrorDeg
	FlightAimState.aimPitchErrorDeg = pitchAimErrorDeg
	FlightAimState.aimTurnIntent = currentAimTurnIntent
	FlightAimState.aimPitchIntent = currentAimPitchIntent

	-- Sincronización periódica con el servidor (~30 Hz)
	local nowClock = os.clock()
	if nowClock - lastSyncClock >= 0.033 then
		syncInputToServer()
	end

	-- Sampled logging cliente (5-10 Hz durante intención de aim activa o movimiento de mouse)
	if (nowClock - lastAimLogClock >= 0.15) and (math.abs(currentAimTurnIntent) > 0.01 or math.abs(currentAimPitchIntent) > 0.01 or math.abs(yawAimErrorDeg) > 1.0 or math.abs(FlightAimState.lastMouseDeltaX) > 0) then
		lastAimLogClock = nowClock
		print(string.format("[CLIENT SEND AIM] turn: %+5.2f | pitch: %+5.2f | yawErr: %+5.1f° | pitchErr: %+5.1f° | camYaw: %+5.1f° | mDX: %+d",
			currentAimTurnIntent, currentAimPitchIntent, yawAimErrorDeg, pitchAimErrorDeg, camAimYawDeg, FlightAimState.lastMouseDeltaX))
	end

	-- 5. Lectura y Despliegue de Telemetría Completa (R3 + R3.1 + R4.1)
	local speed = dtRoot:GetAttribute("Flight_Speed") or 0.0
	local vertSpeed = dtRoot:GetAttribute("Flight_VerticalSpeed") or 0.0
	local pitch = dtRoot:GetAttribute("Flight_Pitch") or 0.0
	local roll = dtRoot:GetAttribute("Flight_CurrentRoll") or (dtRoot:GetAttribute("Flight_Roll") or 0.0)
	local targetRoll = dtRoot:GetAttribute("Flight_TargetRoll") or 0.0
	local heading = dtRoot:GetAttribute("Flight_Heading") or (dtRoot:GetAttribute("Flight_Yaw") or 0.0)
	local yawRate = dtRoot:GetAttribute("Flight_YawRate") or 0.0
	local turnInput = dtRoot:GetAttribute("Flight_TurnInput") or 0.0
	local isTurning = dtRoot:GetAttribute("Flight_IsTurning") or false
	local isBoosting = dtRoot:GetAttribute("Flight_IsBoosting") or false
	local boostCooldown = dtRoot:GetAttribute("Flight_BoostCooldown") or 0.0

	local headingDelta = dtRoot:GetAttribute("Flight_HeadingDeltaPerSecond") or 0.0
	local velHeading = dtRoot:GetAttribute("Flight_VelocityHeading") or 0.0
	local headingError = dtRoot:GetAttribute("Flight_VelocityHeadingError") or 0.0

	local finalTurn = dtRoot:GetAttribute("Flight_FinalTurnIntent") or 0.0
	local finalPitch = dtRoot:GetAttribute("Flight_FinalPitchIntent") or 0.0

	local boostStatusText
	if isBoosting then
		boostStatusText = "ACTIVO! >>>"
	elseif boostCooldown > 0 then
		boostStatusText = string.format("Recarga (%.1fs)", boostCooldown)
	else
		boostStatusText = "LISTO [Shift]"
	end

	dataLabel.Text = string.format(
		"MOUSE DX     : %+4d | DY: %+4d\n" ..
		"MOUSE CAPTURE: %s | AIM: %s\n" ..
		"CamAimYaw    : %+5.1f° | Pitch: %+5.1f°\n" ..
		"AimYawError  : %+5.1f° | PitchErr: %+5.1f°\n" ..
		"AimTurnIntent: %+4.2f | PitchInt: %+4.2f\n" ..
		"FinalTurnInt : %+4.2f | PitchInt: %+4.2f\n" ..
		"Roll (Cur/Tgt): %+4.1f° / %+4.1f°\n" ..
		"YawRate      : %+4.1f°/s | Heading: %+5.1f°\n" ..
		"Vel Heading  : %+5.1f° (Err: %+4.1f°)\n" ..
		"Speed        : %5.1f st/s | %s\n" ..
		"Boost        : %s",
		FlightAimState.lastMouseDeltaX,
		FlightAimState.lastMouseDeltaY,
		FlightAimState.isMouseCaptured and "LOCKED [M:Lib]" or "FREE [Clic:Cap]",
		FlightAimState.isAimActive and "ON" or "OFF",
		camAimYawDeg,
		math.deg(FlightAimState.playerAimPitch),
		yawAimErrorDeg,
		pitchAimErrorDeg,
		currentAimTurnIntent,
		currentAimPitchIntent,
		finalTurn,
		finalPitch,
		roll,
		targetRoll,
		yawRate,
		heading,
		velHeading,
		headingError,
		speed,
		isTurning and "[TURN]" or "[STRAIGHT]",
		boostStatusText
	)
end)

print("[Input V2] Cliente de entrada listo (Fase R4.1). Controles: Mouse Aim + WASD + Space/LCtrl + Shift.")
