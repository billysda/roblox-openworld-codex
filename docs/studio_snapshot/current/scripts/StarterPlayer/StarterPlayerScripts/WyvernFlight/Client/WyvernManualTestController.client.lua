-- WyvernManualTestController.client.lua
-- Controlador de Vuelo Jugable / Prototipo de Gameplay en Play Mode (Fase 5E.4)
-- Conecta el input manual del jugador al sistema físico y aerodinámico sin alterar la física autoritativa.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local wyvernFlightFolder = ReplicatedStorage:WaitForChild("WyvernFlight")
local remotesFolder = wyvernFlightFolder:WaitForChild("Remotes")
local testCommandRemote = remotesFolder:WaitForChild("WyvernTestCommand", 10)

local followingDragon = true
local customCameraEnabled = true

local function getWyvern()
	return Workspace:FindFirstChild("wyvernfbx") or Workspace:FindFirstChild("DragonTierraRoblox")
end

local function getDTRoot()
	local wyvern = getWyvern()
	return wyvern and wyvern:FindFirstChild("DT_Root")
end

-- =============================================================================
-- 1. CREACIÓN DEL HUD TELEMÉTRICO LIVIANO (FASE 5E.4)
-- =============================================================================
local playerGui = player:WaitForChild("PlayerGui")
local existingHud = playerGui:FindFirstChild("WyvernFlightHUD")
if existingHud then existingHud:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WyvernFlightHUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Panel de Telemetría (Esquina superior derecha)
local telemetryFrame = Instance.new("Frame")
telemetryFrame.Name = "TelemetryPanel"
telemetryFrame.Size = UDim2.new(0, 260, 0, 270)
telemetryFrame.Position = UDim2.new(1, -280, 0, 20)
telemetryFrame.BackgroundColor3 = Color3.fromRGB(15, 20, 28)
telemetryFrame.BackgroundTransparency = 0.25
telemetryFrame.BorderSizePixel = 0
telemetryFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = telemetryFrame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 26)
title.BackgroundTransparency = 1
title.Text = "WYVERN FLIGHT TELEMETRY (5E.4)"
title.TextColor3 = Color3.fromRGB(240, 190, 80)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.Parent = telemetryFrame

local telemetryLabel = Instance.new("TextLabel")
telemetryLabel.Name = "Data"
telemetryLabel.Size = UDim2.new(1, -20, 1, -36)
telemetryLabel.Position = UDim2.new(0, 10, 0, 28)
telemetryLabel.BackgroundTransparency = 1
telemetryLabel.TextColor3 = Color3.fromRGB(230, 235, 245)
telemetryLabel.Font = Enum.Font.Code
telemetryLabel.TextSize = 12
telemetryLabel.TextXAlignment = Enum.TextXAlignment.Left
telemetryLabel.TextYAlignment = Enum.TextYAlignment.Top
telemetryLabel.Parent = telemetryFrame

-- Panel de Controles (Esquina superior izquierda)
local controlsFrame = Instance.new("Frame")
controlsFrame.Name = "ControlsPanel"
controlsFrame.Size = UDim2.new(0, 240, 0, 175)
controlsFrame.Position = UDim2.new(0, 20, 0, 20)
controlsFrame.BackgroundColor3 = Color3.fromRGB(15, 20, 28)
controlsFrame.BackgroundTransparency = 0.35
controlsFrame.BorderSizePixel = 0
controlsFrame.Parent = screenGui

local cornerControls = Instance.new("UICorner")
cornerControls.CornerRadius = UDim.new(0, 8)
cornerControls.Parent = controlsFrame

local controlsTitle = Instance.new("TextLabel")
controlsTitle.Size = UDim2.new(1, 0, 0, 24)
controlsTitle.BackgroundTransparency = 1
controlsTitle.Text = "MANUAL FLIGHT CONTROLS"
controlsTitle.TextColor3 = Color3.fromRGB(120, 200, 255)
controlsTitle.Font = Enum.Font.GothamBold
controlsTitle.TextSize = 12
controlsTitle.Parent = controlsFrame

local controlsLabel = Instance.new("TextLabel")
controlsLabel.Size = UDim2.new(1, -20, 1, -30)
controlsLabel.Position = UDim2.new(0, 10, 0, 26)
controlsLabel.BackgroundTransparency = 1
controlsLabel.TextColor3 = Color3.fromRGB(210, 220, 235)
controlsLabel.Font = Enum.Font.Code
controlsLabel.TextSize = 11
controlsLabel.TextXAlignment = Enum.TextXAlignment.Left
controlsLabel.TextYAlignment = Enum.TextYAlignment.Top
controlsLabel.Text = "[I] / [K] : Pitch Up / Down\n[J] / [L] : Roll Left / Right\n[U] / [O] : Yaw Left / Right\n[T] / [G] : Thrust +5% / -5%\n[0]       : Thrust 0% (Glide)\n[R]       : Reset Aerial Spawn\n[C]       : Toggle Camera Mode"
controlsLabel.Parent = controlsFrame

-- =============================================================================
-- 2. GESTIÓN DE INPUT ROTACIONAL Y PROPULSIÓN
-- =============================================================================
local inputs = {
	pitch = 0,
	roll = 0,
	yaw = 0
}

local function syncRotationalInput()
	if testCommandRemote then
		testCommandRemote:FireServer("SET_ROTATIONAL_INPUT", {
			pitch = inputs.pitch,
			roll = inputs.roll,
			yaw = inputs.yaw
		})
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	local keyCode = input.KeyCode

	-- Controles de Cabeceo (Pitch)
	if keyCode == Enum.KeyCode.I then
		inputs.pitch = 1.0
		syncRotationalInput()
	elseif keyCode == Enum.KeyCode.K then
		inputs.pitch = -1.0
		syncRotationalInput()

	-- Controles de Alabeo (Roll)
	elseif keyCode == Enum.KeyCode.J then
		inputs.roll = -1.0
		syncRotationalInput()
	elseif keyCode == Enum.KeyCode.L then
		inputs.roll = 1.0
		syncRotationalInput()

	-- Controles de Guiñada (Yaw)
	elseif keyCode == Enum.KeyCode.U then
		inputs.yaw = -1.0
		syncRotationalInput()
	elseif keyCode == Enum.KeyCode.O then
		inputs.yaw = 1.0
		syncRotationalInput()

	-- Controles de Propulsión
	elseif keyCode == Enum.KeyCode.T then
		if testCommandRemote then testCommandRemote:FireServer("INCREMENT_THRUST") end
	elseif keyCode == Enum.KeyCode.G then
		if testCommandRemote then testCommandRemote:FireServer("DECREMENT_THRUST") end
	elseif keyCode == Enum.KeyCode.Zero or keyCode == Enum.KeyCode.KeypadZero then
		if testCommandRemote then testCommandRemote:FireServer("ZERO_THRUST") end

	-- Comandos de Escenario
	elseif keyCode == Enum.KeyCode.R then
		if testCommandRemote then testCommandRemote:FireServer("SPAWN_AERIAL") end
	elseif keyCode == Enum.KeyCode.C then
		customCameraEnabled = not customCameraEnabled
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	local keyCode = input.KeyCode

	if keyCode == Enum.KeyCode.I or keyCode == Enum.KeyCode.K then
		inputs.pitch = 0
		syncRotationalInput()
	elseif keyCode == Enum.KeyCode.J or keyCode == Enum.KeyCode.L then
		inputs.roll = 0
		syncRotationalInput()
	elseif keyCode == Enum.KeyCode.U or keyCode == Enum.KeyCode.O then
		inputs.yaw = 0
		syncRotationalInput()
	end
end)

-- =============================================================================
-- 3. CÁMARA DE SEGUIMIENTO EN TERCERA PERSONA ESTABLE Y CENTRADA (FASE 5E.4-A)
-- =============================================================================
-- Centroide visual corporal del wyvern (Pecho/Alas/Cuerpo entre Z = -11 y Z = +31)
local VISUAL_CENTER_LOCAL_OFFSET = Vector3.new(0.0, 1.5, 2.0)
local CAMERA_FOLLOW_DISTANCE = 42.0 -- studs detrás del centroide
local CAMERA_FOLLOW_HEIGHT = 10.0   -- studs sobre el centroide
local CAMERA_SMOOTH_FACTOR = 30.0   -- escala exponencial frame-rate independent

local isCameraInitialized = false

local function setupCamera()
	if customCameraEnabled then
		camera.CameraType = Enum.CameraType.Scriptable
	else
		camera.CameraType = Enum.CameraType.Custom
		if player.Character and player.Character:FindFirstChild("Humanoid") then
			camera.CameraSubject = player.Character.Humanoid
		end
	end
end

setupCamera()

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.C then
		customCameraEnabled = not customCameraEnabled
		setupCamera()
	end
end)

RunService.RenderStepped:Connect(function(dt)
	local dtRoot = getDTRoot()
	if not dtRoot then return end

	-- 1. Actualización de Cámara de Persecución Centrada
	if customCameraEnabled and camera then
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end

		local rootCF = dtRoot.CFrame
		local visualCenterWorld = rootCF:PointToWorldSpace(VISUAL_CENTER_LOCAL_OFFSET)
		local idealCamPos = rootCF:PointToWorldSpace(VISUAL_CENTER_LOCAL_OFFSET + Vector3.new(0, CAMERA_FOLLOW_HEIGHT, CAMERA_FOLLOW_DISTANCE))

		-- Orientación de la cámara mirando directamente al centroide corporal visual
		-- El UpVector combina suavemente el mundo y el alabeo local del dragón
		local camUpVector = (Vector3.yAxis * 0.7 + rootCF.UpVector * 0.3).Unit
		local desiredCF = CFrame.lookAt(idealCamPos, visualCenterWorld, camUpVector)

		if not isCameraInitialized then
			camera.CFrame = desiredCF
			isCameraInitialized = true
		else
			local alpha = 1.0 - math.exp(-CAMERA_SMOOTH_FACTOR * math.clamp(dt, 0.001, 0.1))
			camera.CFrame = camera.CFrame:Lerp(desiredCF, alpha)
		end
	end

	-- 2. Telemetría de Vuelo en Tiempo Real (11 métricas requeridas)
	local linVel = dtRoot.AssemblyLinearVelocity
	local speed = linVel.Magnitude
	local vy = linVel.Y

	local rx, ry, rz = dtRoot.CFrame:ToOrientation()
	local pitchDeg = math.deg(rx)
	local yawDeg   = math.deg(ry)
	local rollDeg  = math.deg(rz)

	local state = dtRoot:GetAttribute("FlightState") or "CRUISE"
	local aoa = dtRoot:GetAttribute("Aero_AoA") or 0
	local lwRatio = dtRoot:GetAttribute("Aero_LWRatio") or 0
	local thrustPct = (dtRoot:GetAttribute("Thrust_Percent") or 0) * 100
	local flightEffort = dtRoot:GetAttribute("FlightEffort") or 0
	local flapPhase = dtRoot:GetAttribute("Flap_Phase") or 0

	telemetryLabel.Text = string.format(
		"State        : %s\n" ..
		"Speed        : %5.1f st/s\n" ..
		"Vert Speed   : %+5.1f st/s\n" ..
		"Pitch        : %+5.1f°\n" ..
		"Roll         : %+5.1f°\n" ..
		"Yaw          : %+5.1f°\n" ..
		"AoA          : %+5.1f°\n" ..
		"L/W Ratio    : %5.2f\n" ..
		"Thrust %%     : %5.0f%%\n" ..
		"FlightEffort : %5.2f\n" ..
		"FlapPhase    : %5.2f",
		tostring(state),
		speed,
		vy,
		pitchDeg,
		rollDeg,
		yawDeg,
		aoa,
		lwRatio,
		thrustPct,
		flightEffort,
		flapPhase
	)
end)

-- Spawn aéreo inicial al cargar el cliente
task.spawn(function()
	task.wait(0.5)
	if testCommandRemote then
		testCommandRemote:FireServer("SPAWN_AERIAL")
	end
end)

print("[WyvernManualTestController] Prototipo de Vuelo Jugable Listo (Fase 5E.4).")
