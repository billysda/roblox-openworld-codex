-- WyvernPhysicsBaseline.server.lua
-- Ejecuta la secuencia automatizada del Baseline Test de Física (Fase 1B)
-- Controlado 100% por físicas reales de Roblox: Gravedad + VectorForce + Torque

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WyvernPhysicsConfig = require(ReplicatedStorage:WaitForChild("WyvernFlight"):WaitForChild("Config"):WaitForChild("WyvernPhysicsConfig"))

local wyvern = Workspace:WaitForChild("wyvernfbx", 10) or Workspace:WaitForChild("DragonTierraRoblox", 10)
if not wyvern then
	warn("[WyvernBaseline] ERROR: No se encontró wyvernfbx en Workspace.")
	return
end

local dtRoot = wyvern:WaitForChild("DT_Root", 10)
if not dtRoot then
	warn("[WyvernBaseline] ERROR: No se encontró DT_Root en wyvernfbx.")
	return
end

-- Función para desanclar/anclar limpiamente toda la Assembly
local function setAssemblyAnchored(anchored)
	for _, desc in ipairs(wyvern:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Anchored = anchored
		end
	end
end

-- Función segura para consultar NetworkOwner (Solo válida en unanchored)
local function getSafeNetworkOwner(part)
	local ok, owner = pcall(function()
		return part:GetNetworkOwner()
	end)
	if ok then
		return owner and owner.Name or "Server (nil / Auto)"
	else
		return "Anchored (No Applicable)"
	end
end

-- 1. Crear componentes físicos dentro de DT_Root
local physicsAttachment = dtRoot:FindFirstChild("WyvernPhysicsAttachment")
if not physicsAttachment then
	physicsAttachment = Instance.new("Attachment")
	physicsAttachment.Name = "WyvernPhysicsAttachment"
	physicsAttachment.Parent = dtRoot
end

local baselineForce = dtRoot:FindFirstChild("WyvernBaselineForce")
if not baselineForce then
	baselineForce = Instance.new("VectorForce")
	baselineForce.Name = "WyvernBaselineForce"
	baselineForce.Attachment0 = physicsAttachment
	baselineForce.RelativeTo = Enum.ActuatorRelativeTo.World
	baselineForce.ApplyAtCenterOfMass = true
	baselineForce.Force = Vector3.zero
	baselineForce.Parent = dtRoot
end

local baselineTorque = dtRoot:FindFirstChild("WyvernBaselineTorque")
if not baselineTorque then
	baselineTorque = Instance.new("Torque")
	baselineTorque.Name = "WyvernBaselineTorque"
	baselineTorque.Attachment0 = physicsAttachment
	baselineTorque.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
	baselineTorque.Torque = Vector3.zero
	baselineTorque.Parent = dtRoot
end

-- Función de muestreo de telemetría
local function logTelemetry(stage, elapsed)
	local pos = dtRoot.Position
	local linVel = dtRoot.AssemblyLinearVelocity
	local angVel = dtRoot.AssemblyAngularVelocity
	local com = dtRoot.AssemblyCenterOfMass
	local mass = dtRoot.AssemblyMass

	print(string.format("[TELEMETRY] Stage=%s | t=%.2fs | Pos=(%.2f, %.2f, %.2f) | LinVel=(%.2f, %.2f, %.2f) [|v|=%.2f] | AngVel=(%.2f, %.2f, %.2f) | Mass=%.1f",
		stage, elapsed, pos.X, pos.Y, pos.Z, linVel.X, linVel.Y, linVel.Z, linVel.Magnitude, angVel.X, angVel.Y, angVel.Z, mass))
end

-- 2. Iniciar secuencia de prueba automatizada
task.spawn(function()
	print("\n=======================================================")
	print("[WyvernBaseline] INICIANDO FASE 1B: PHYSICS CORE TEST")
	print("=======================================================")

	-- ESTADO 1: IDLE (Dragón anclado)
	print(string.format("[WyvernBaseline] NetworkOwner Inicial: %s", getSafeNetworkOwner(dtRoot)))
	print("\n--- ESTADO 1: IDLE (Anclado) ---")
	setAssemblyAnchored(true)
	task.wait(WyvernPhysicsConfig.INITIAL_IDLE_TIME)
	logTelemetry("IDLE", 0)

	-- ESTADO 2: RELEASE (Gravedad natural)
	print("\n--- ESTADO 2: RELEASE (Gravedad natural activada) ---")
	setAssemblyAnchored(false)
	
	-- Fijar network owner al servidor explícitamente para control físico determinista
	pcall(function()
		dtRoot:SetNetworkOwner(nil)
	end)
	print(string.format("[WyvernBaseline] NetworkOwner Durante Simulación: %s", getSafeNetworkOwner(dtRoot)))

	local startTime = os.clock()
	local duration = WyvernPhysicsConfig.GRAVITY_TEST_TIME
	while (os.clock() - startTime) < duration do
		logTelemetry("GRAVITY_DROP", os.clock() - startTime)
		task.wait(WyvernPhysicsConfig.TELEMETRY_INTERVAL)
	end

	-- ESTADO 3: FORWARD FORCE (Aceleración lineal con VectorForce)
	print("\n--- ESTADO 3: FORWARD FORCE (Aplicando fuerza vectorial en LookVector) ---")
	local forwardDir = dtRoot.CFrame.LookVector
	local appliedForceVector = forwardDir * WyvernPhysicsConfig.BASELINE_FORWARD_FORCE
	baselineForce.Force = appliedForceVector
	print(string.format("[WyvernBaseline] Fuerza aplicada: Vector3(%.1f, %.1f, %.1f) [Magnitud=%.1f N]", 
		appliedForceVector.X, appliedForceVector.Y, appliedForceVector.Z, appliedForceVector.Magnitude))

	startTime = os.clock()
	duration = WyvernPhysicsConfig.FORWARD_FORCE_TIME
	while (os.clock() - startTime) < duration do
		logTelemetry("FORWARD_FORCE", os.clock() - startTime)
		task.wait(WyvernPhysicsConfig.TELEMETRY_INTERVAL)
	end

	-- ESTADO 3b: INERCIA LINEAL (Fuerza = 0, observando conservación de movimiento)
	print("\n--- ESTADO 3b: FORWARD INERTIA (Fuerza cortada a 0, observando inercia) ---")
	baselineForce.Force = Vector3.zero
	startTime = os.clock()
	duration = WyvernPhysicsConfig.FORWARD_INERTIA_TIME
	while (os.clock() - startTime) < duration do
		logTelemetry("FORWARD_INERTIA", os.clock() - startTime)
		task.wait(WyvernPhysicsConfig.TELEMETRY_INTERVAL)
	end

	-- ESTADO 4: TORQUE TEST (Rotación física con Torque)
	print("\n--- ESTADO 4: TORQUE TEST (Aplicando Torque físico en Yaw) ---")
	local appliedTorqueVector = Vector3.new(0, WyvernPhysicsConfig.BASELINE_TORQUE, 0)
	baselineTorque.Torque = appliedTorqueVector
	print(string.format("[WyvernBaseline] Torque aplicado: Vector3(%.1f, %.1f, %.1f) N*m", 
		appliedTorqueVector.X, appliedTorqueVector.Y, appliedTorqueVector.Z))

	startTime = os.clock()
	duration = WyvernPhysicsConfig.TORQUE_TEST_TIME
	while (os.clock() - startTime) < duration do
		logTelemetry("TORQUE_APPLIED", os.clock() - startTime)
		task.wait(WyvernPhysicsConfig.TELEMETRY_INTERVAL)
	end

	-- ESTADO 4b: INERCIA ANGULAR (Torque = 0, observando conservación angular)
	print("\n--- ESTADO 4b: ANGULAR INERTIA (Torque cortado a 0, observando inercia angular) ---")
	baselineTorque.Torque = Vector3.zero
	startTime = os.clock()
	duration = WyvernPhysicsConfig.TORQUE_INERTIA_TIME
	while (os.clock() - startTime) < duration do
		logTelemetry("ANGULAR_INERTIA", os.clock() - startTime)
		task.wait(WyvernPhysicsConfig.TELEMETRY_INTERVAL)
	end

	-- ESTADO 5: STOP (Registro final de estabilidad)
	print("\n--- ESTADO 5: FINAL EVALUATION ---")
	logTelemetry("FINAL_REST", 0)

	-- Auditoría de integridad de huesos y MeshParts
	local totalBones = 0
	for _, desc in ipairs(wyvern:GetDescendants()) do
		if desc:IsA("Bone") then
			totalBones = totalBones + 1
		end
	end

	print(string.format("[WyvernBaseline] Conteo final de huesos: %d / 82", totalBones))
	print(string.format("[WyvernBaseline] AssemblyRootPart final: %s", dtRoot.AssemblyRootPart and dtRoot.AssemblyRootPart.Name or "nil"))
	print("[WyvernBaseline] TEST FASE 1B COMPLETADO EXITOSAMENTE.\n")
end)
