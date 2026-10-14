-- WyvernPropulsion.server.lua
-- Motor de Propulsión Física Aislada (Fase 5A / 5B Core)
-- Empuje longitudinal puro aplicado en el Centro de Masa (r x F = 0)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local wyvernFlightFolder = ReplicatedStorage:WaitForChild("WyvernFlight")
local WyvernPropulsionConfig = require(wyvernFlightFolder:WaitForChild("Config"):WaitForChild("WyvernPropulsionConfig"))
local remotesFolder = wyvernFlightFolder:WaitForChild("Remotes")

local testCommandRemote = remotesFolder:FindFirstChild("WyvernTestCommand")
if not testCommandRemote then
	testCommandRemote = Instance.new("RemoteEvent")
	testCommandRemote.Name = "WyvernTestCommand"
	testCommandRemote.Parent = remotesFolder
end

local wyvern = Workspace:WaitForChild("wyvernfbx", 10) or Workspace:WaitForChild("DragonTierraRoblox", 10)
if not wyvern then
	warn("[WyvernPropulsion] ERROR: No se encontró wyvernfbx en Workspace.")
	return
end

local dtRoot = wyvern:WaitForChild("DT_Root", 10)
if not dtRoot then
	warn("[WyvernPropulsion] ERROR: No se encontró DT_Root en wyvernfbx.")
	return
end

-- =====================================================================
-- 1. ACTUADOR FÍSICO DE PROPULSIÓN (VECTORFORCE EN CoM)
-- =====================================================================
local thrustAttachment = dtRoot:FindFirstChild("WyvernThrustAttachment")
if not thrustAttachment then
	thrustAttachment = Instance.new("Attachment")
	thrustAttachment.Name = "WyvernThrustAttachment"
	thrustAttachment.Position = WyvernPropulsionConfig.THRUST_ATTACHMENT_OFFSET
	thrustAttachment.Parent = dtRoot
end

local thrustForce = dtRoot:FindFirstChild("WyvernThrustForce")
if not thrustForce then
	thrustForce = Instance.new("VectorForce")
	thrustForce.Name = "WyvernThrustForce"
	thrustForce.Attachment0 = thrustAttachment
	thrustForce.RelativeTo = Enum.ActuatorRelativeTo.World
	thrustForce.ApplyAtCenterOfMass = true -- Estricto: r x F = 0
	thrustForce.Force = Vector3.zero
	thrustForce.Parent = dtRoot
end

local currentThrustPercent = 0.0

local function updateThrust()
	if dtRoot.Anchored or currentThrustPercent <= 0.0001 then
		thrustForce.Force = Vector3.zero
		dtRoot:SetAttribute("Thrust_ForceMag", 0)
		dtRoot:SetAttribute("Thrust_Percent", 0)
		return
	end

	-- El thrust sigue estrictamente el eje longitudinal local (LookVector)
	local lookDir = dtRoot.CFrame.LookVector
	local forceMagnitude = WyvernPropulsionConfig.MAX_THRUST * math.clamp(currentThrustPercent, 0, 1)
	local appliedForceVector = lookDir * forceMagnitude

	thrustForce.Force = appliedForceVector
	dtRoot:SetAttribute("Thrust_ForceMag", forceMagnitude)
	dtRoot:SetAttribute("Thrust_Percent", currentThrustPercent)
end

RunService.Heartbeat:Connect(updateThrust)

-- Sincronizar cambios directos de atributo Thrust_Percent
dtRoot:GetAttributeChangedSignal("Thrust_Percent"):Connect(function()
	local attrPct = dtRoot:GetAttribute("Thrust_Percent")
	if attrPct and math.abs(attrPct - currentThrustPercent) > 0.001 then
		currentThrustPercent = math.clamp(attrPct, 0, 1)
		updateThrust()
	end
end)

-- =====================================================================
-- 2. COMANDOS REMOTOS DE PRUEBA
-- =====================================================================
testCommandRemote.OnServerEvent:Connect(function(player, command, arg)
	if command == "SET_THRUST_PERCENT" then
		currentThrustPercent = math.clamp(tonumber(arg) or 0, 0, 1)
		updateThrust()
	elseif command == "INCREMENT_THRUST" then
		currentThrustPercent = math.clamp(currentThrustPercent + WyvernPropulsionConfig.THRUST_STEP, 0, 1)
		updateThrust()
	elseif command == "DECREMENT_THRUST" then
		currentThrustPercent = math.clamp(currentThrustPercent - WyvernPropulsionConfig.THRUST_STEP, 0, 1)
		updateThrust()
	elseif command == "ZERO_THRUST" then
		currentThrustPercent = 0.0
		updateThrust()
	elseif command == "REQUEST_TAKEOFF" then
		currentThrustPercent = 0.60
		updateThrust()
	end
end)
