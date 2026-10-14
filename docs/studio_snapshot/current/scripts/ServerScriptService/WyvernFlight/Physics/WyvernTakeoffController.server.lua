-- WyvernTakeoffController.server.lua
-- Actuador Físico de Despegue Autoritativo en Servidor (Fase 5E.3)
-- Aplica fuerza física vertical y empuje inicial transitorios para la transición GROUNDED -> TAKEOFF -> CLIMB.
-- Se desactiva automáticamente al salir de TAKEOFF.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local wyvernFlightFolder = ReplicatedStorage:WaitForChild("WyvernFlight")
local WyvernTakeoffConfig = require(wyvernFlightFolder:WaitForChild("Config"):WaitForChild("WyvernTakeoffConfig"))
local remotesFolder = wyvernFlightFolder:WaitForChild("Remotes")

local testCommandRemote = remotesFolder:FindFirstChild("WyvernTestCommand")
if not testCommandRemote then
	testCommandRemote = Instance.new("RemoteEvent")
	testCommandRemote.Name = "WyvernTestCommand"
	testCommandRemote.Parent = remotesFolder
end

local wyvern = Workspace:FindFirstChild("wyvernfbx") or Workspace:FindFirstChild("DragonTierraRoblox")
if not wyvern then
	wyvern = Workspace:WaitForChild("wyvernfbx", 5) or Workspace:WaitForChild("DragonTierraRoblox", 5)
end

if not wyvern then
	warn("[WyvernTakeoffController] ERROR: No se encontró wyvernfbx en Workspace.")
	return
end

local dtRoot = wyvern:WaitForChild("DT_Root", 5)
if not dtRoot then
	warn("[WyvernTakeoffController] ERROR: No se encontró DT_Root en wyvernfbx.")
	return
end

-- =====================================================================
-- 1. ACTUADORES FÍSICOS DE DESPEGUE (VECTORFORCE & TORQUE EN CoM)
-- =====================================================================
local takeoffAttachment = dtRoot:FindFirstChild("WyvernTakeoffAttachment")
if not takeoffAttachment then
	takeoffAttachment = Instance.new("Attachment")
	takeoffAttachment.Name = "WyvernTakeoffAttachment"
	takeoffAttachment.Position = WyvernTakeoffConfig.TAKEOFF_ATTACHMENT_OFFSET
	takeoffAttachment.Parent = dtRoot
end

local takeoffForce = dtRoot:FindFirstChild("WyvernTakeoffForce")
if not takeoffForce then
	takeoffForce = Instance.new("VectorForce")
	takeoffForce.Name = "WyvernTakeoffForce"
	takeoffForce.Attachment0 = takeoffAttachment
	takeoffForce.RelativeTo = Enum.ActuatorRelativeTo.World
	takeoffForce.ApplyAtCenterOfMass = true
	takeoffForce.Force = Vector3.zero
	takeoffForce.Enabled = false
	takeoffForce.Parent = dtRoot
end

local takeoffTorque = dtRoot:FindFirstChild("WyvernTakeoffTorque")
if not takeoffTorque then
	takeoffTorque = Instance.new("Torque")
	takeoffTorque.Name = "WyvernTakeoffTorque"
	takeoffTorque.Attachment0 = takeoffAttachment
	takeoffTorque.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
	takeoffTorque.Torque = Vector3.zero
	takeoffTorque.Enabled = false
	takeoffTorque.Parent = dtRoot
end

-- =====================================================================
-- 2. ESTADO INTERNO DEL ACTUADOR
-- =====================================================================
local isTakeoffActive = false
local takeoffElapsed = 0.0

local function startTakeoff()
	if isTakeoffActive then return end
	local currentState = dtRoot:GetAttribute("FlightState") or "GROUNDED"
	if currentState ~= "GROUNDED" and currentState ~= "TAKEOFF" then
		return
	end

	isTakeoffActive = true
	takeoffElapsed = 0.0

	-- Señalizar a la FSM
	if dtRoot:GetAttribute("TakeoffRequested") ~= true then
		dtRoot:SetAttribute("TakeoffRequested", true)
	end

	-- Activar empuje inicial hacia adelante para ganar velocidad aerodinámica (60%)
	dtRoot:SetAttribute("Thrust_Percent", WyvernTakeoffConfig.TAKEOFF_INITIAL_THRUST_PERCENT)
	local maxThrust = 20000.0
	dtRoot:SetAttribute("Thrust_ForceMag", maxThrust * WyvernTakeoffConfig.TAKEOFF_INITIAL_THRUST_PERCENT)

	-- Activar fuerza vertical hacia arriba
	takeoffForce.Force = Vector3.new(0, WyvernTakeoffConfig.TAKEOFF_VERTICAL_FORCE, 0)
	takeoffForce.Enabled = true
	
	-- Activar rotación de morro inicial
	takeoffTorque.Torque = Vector3.new(WyvernTakeoffConfig.TAKEOFF_PITCH_BIAS_TORQUE, 0, 0)
	takeoffTorque.Enabled = true

	print("[WyvernTakeoffController] Despegue Físico Iniciado: F_vert =", WyvernTakeoffConfig.TAKEOFF_VERTICAL_FORCE, "N, Thrust =", WyvernTakeoffConfig.TAKEOFF_INITIAL_THRUST_PERCENT)
end

local function stopTakeoff(reason)
	if not isTakeoffActive then return end

	isTakeoffActive = false
	takeoffElapsed = 0.0

	-- Desactivar inmediatamente fuerzas y torques transitorios de despegue
	takeoffForce.Force = Vector3.zero
	takeoffForce.Enabled = false
	takeoffTorque.Torque = Vector3.zero
	takeoffTorque.Enabled = false
	
	if dtRoot:GetAttribute("TakeoffRequested") == true then
		dtRoot:SetAttribute("TakeoffRequested", false)
	end

	print("[WyvernTakeoffController] Despegue Finalizado (" .. tostring(reason) .. "). Actuador transitorio apagado.")
end

-- Escuchar cambios en el atributo TakeoffRequested
dtRoot:GetAttributeChangedSignal("TakeoffRequested"):Connect(function()
	local req = dtRoot:GetAttribute("TakeoffRequested") == true
	if req and not isTakeoffActive then
		startTakeoff()
	elseif not req and isTakeoffActive then
		stopTakeoff("TakeoffRequested cleared")
	end
end)

-- =====================================================================
-- 3. BUCLE PRINCIPAL DE CONTROL EN HEARTBEAT
-- =====================================================================
RunService.Heartbeat:Connect(function(dt)
	if not isTakeoffActive then return end

	takeoffElapsed = takeoffElapsed + dt
	local currentState = dtRoot:GetAttribute("FlightState") or "GROUNDED"

	-- Desactivar en cuanto la FSM complete la transición a CLIMB o aborte
	if currentState == "CLIMB" then
		stopTakeoff("Transición Exitosa a CLIMB")
	elseif currentState == "TOUCHDOWN" or currentState == "GROUNDED" then
		if takeoffElapsed > 0.30 then
			stopTakeoff("Aborto / Retorno a Tierra")
		end
	elseif takeoffElapsed >= WyvernTakeoffConfig.MAX_TAKEOFF_DURATION then
		stopTakeoff("Timeout de Seguridad")
	else
		-- Mantener fuerza vertical durante TAKEOFF
		takeoffForce.Force = Vector3.new(0, WyvernTakeoffConfig.TAKEOFF_VERTICAL_FORCE, 0)
		takeoffForce.Enabled = true
		
		-- Control proporcional-derivativo de cabeceo suave durante el despegue (objetivo: +8°)
		local rx, _, _ = dtRoot.CFrame:ToOrientation()
		local pitchRate = dtRoot.AssemblyAngularVelocity.X -- rad/s
		local targetPitch = math.rad(8.0)
		local pitchError = targetPitch - rx
		local pitchTorque = math.clamp(pitchError * 3000.0 - pitchRate * 1200.0, -1500.0, WyvernTakeoffConfig.TAKEOFF_PITCH_BIAS_TORQUE)
		
		takeoffTorque.Torque = Vector3.new(pitchTorque, 0, 0)
		takeoffTorque.Enabled = true
	end
end)

-- =====================================================================
-- 4. ESCUCHA DE EVENTOS REMOTOS
-- =====================================================================
testCommandRemote.OnServerEvent:Connect(function(player, command, arg)
	if command == "REQUEST_TAKEOFF" then
		startTakeoff()
	elseif command == "ABORT_TAKEOFF" then
		stopTakeoff("Solicitud de Aborto Manual")
	end
end)

print("[WyvernTakeoffController] Servicio de Despegue Físico Inicializado en Servidor (Fase 5E.3).")
