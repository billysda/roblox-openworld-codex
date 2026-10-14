-- WyvernFlightStateManager.server.lua
-- Gestor Autoritativo de Estados de Vuelo (Fase 5E.2-D)
-- Observador de Estado Puro: NO escribe fuerzas, torques, impulsos, masa, posiciones ni huesos.
-- Fase 5E.2-D: Consume IsTouchdownContact explícito para gobernar LANDING -> TOUCHDOWN.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local wyvernFlightFolder = ReplicatedStorage:WaitForChild("WyvernFlight", 10)
if not wyvernFlightFolder then return end

local sharedFolder = wyvernFlightFolder:WaitForChild("Shared", 10)
local WyvernGroundDetector = require(sharedFolder:WaitForChild("WyvernGroundDetector"))

local wyvern = Workspace:WaitForChild("wyvernfbx", 10) or Workspace:WaitForChild("DragonTierraRoblox", 10)
if not wyvern then
	warn("[WyvernFlightStateManager] ERROR: No se encontró wyvernfbx en Workspace.")
	return
end

local dtRoot = wyvern:WaitForChild("DT_Root", 10)
if not dtRoot then
	warn("[WyvernFlightStateManager] ERROR: No se encontró DT_Root en wyvernfbx.")
	return
end

-- =====================================================================
-- CONSTANTES Y TIEMPOS MÍNIMOS DE ESTADO (MINIMUM STATE TIME)
-- =====================================================================
local MIN_STATE_TIME = {
	GROUNDED  = 0.40,
	TAKEOFF   = 0.30,
	LANDING   = 0.25,
	TOUCHDOWN = 0.00, -- Preemption instantánea
	CLIMB     = 0.25,
	CRUISE    = 0.20,
	GLIDE     = 0.25,
	DIVE      = 0.30,
	STALL     = 0.00, -- Preemption instantánea
	RECOVERY  = 0.30
}

local DOMAIN_MAP = {
	GROUNDED  = "GROUND",
	TAKEOFF   = "GROUND",
	LANDING   = "GROUND",
	TOUCHDOWN = "GROUND",
	CLIMB     = "AIR",
	CRUISE    = "AIR",
	GLIDE     = "AIR",
	DIVE      = "AIR",
	STALL     = "AIR",
	RECOVERY  = "AIR"
}

-- =====================================================================
-- INSTANCIACIÓN DE SENSORES Y ESTADO INTERNO
-- =====================================================================
local groundSensor = WyvernGroundDetector.new(wyvern)

local currentState = "GROUNDED"
local previousState = "GROUNDED"
local stateTime = 0.0

local smoothedSpeedTrend = 0.0
local lastSpeed = 0.0
local TREND_TAU = 0.30 -- Filtro exponencial de 300 ms

local groundLossTimer = 0.0

-- Inicializar atributos autoritativos en DT_Root
dtRoot:SetAttribute("FlightState", currentState)
dtRoot:SetAttribute("FlightDomain", DOMAIN_MAP[currentState])
dtRoot:SetAttribute("TakeoffRequested", false)

-- =====================================================================
-- EVALUADOR DE CONDICIONES ATÓMICAS
-- =====================================================================
local function evaluateFlightSignals(dt, groundData)
	local linVel = dtRoot.AssemblyLinearVelocity
	local speed = linVel.Magnitude
	local vy = linVel.Y

	local rx, _, _ = dtRoot.CFrame:ToOrientation()
	local pitchDeg = math.deg(rx)

	local aoaDeg = dtRoot:GetAttribute("Aero_AoA") or 0.0
	local lwRatio = dtRoot:GetAttribute("Aero_LWRatio") or 1.0
	local thrust = dtRoot:GetAttribute("Thrust_Percent") or 0.0
	local takeoffReq = (dtRoot:GetAttribute("TakeoffRequested") == true)

	-- Filtro temporal de tendencia de aceleración (a_trend)
	if dt > 0 then
		local instantAcc = (speed - lastSpeed) / dt
		smoothedSpeedTrend = smoothedSpeedTrend + (dt / TREND_TAU) * (instantAcc - smoothedSpeedTrend)
		lastSpeed = speed
	end

	return {
		speed = speed,
		vy = vy,
		pitchDeg = pitchDeg,
		aoaDeg = aoaDeg,
		lwRatio = lwRatio,
		thrust = thrust,
		takeoffRequested = takeoffReq,
		aTrend = smoothedSpeedTrend,
		groundDist = groundData.GroundDistance,
		isContact = groundData.GroundContact,
		isTouchdownContact = groundData.IsTouchdownContact or false,
		isGrounded = groundData.IsGrounded,
		isGroundable = groundData.IsGroundableSurface,
		touchdownCount = groundData.TouchdownSampleCount or 0
	}
end

-- =====================================================================
-- GRAFO DE ADYACENCIA ESTRICTO (FSM)
-- =====================================================================
local function getNextStateFromGraph(state, s, timeInState)
	local canTransitionNormal = (timeInState >= (MIN_STATE_TIME[state] or 0.20))

	-- -----------------------------------------------------------------
	-- 1. ESTADO: GROUNDED
	-- Aristas válidas: -> TAKEOFF, -> GLIDE
	-- -----------------------------------------------------------------
	if state == "GROUNDED" then
		if s.takeoffRequested then
			return "TAKEOFF"
		end

		-- Preemption por pérdida real de suelo (caída de acantilado >= 0.15s)
		if not s.isContact then
			groundLossTimer = groundLossTimer + (timeInState > 0 and 0.0166 or 0)
			if groundLossTimer >= 0.15 then
				groundLossTimer = 0.0
				return "GLIDE"
			end
		else
			groundLossTimer = 0.0
		end

		return "GROUNDED"

	-- -----------------------------------------------------------------
	-- 2. ESTADO: TAKEOFF
	-- Aristas válidas: -> CLIMB, -> TOUCHDOWN
	-- -----------------------------------------------------------------
	elseif state == "TAKEOFF" then
		-- Despeje completo del suelo -> CLIMB
		if s.groundDist >= 12.0 then
			return "CLIMB"
		end

		-- Aborto / contacto inmediato con el suelo
		if s.isTouchdownContact and s.vy <= 0 then
			return "TOUCHDOWN"
		end

		return "TAKEOFF"

	-- -----------------------------------------------------------------
	-- 3. ESTADO: CLIMB
	-- Aristas válidas: -> STALL, -> LANDING, -> CRUISE, -> DIVE, -> GLIDE
	-- -----------------------------------------------------------------
	elseif state == "CLIMB" then
		-- Preemption instantánea por Stall
		if s.aoaDeg >= 16.0 or (s.speed < 30.0 and s.lwRatio < 0.30) then
			return "STALL"
		end

		-- Preemption por proximidad a tierra aterrizables
		if s.groundDist <= 30.0 and s.vy <= -2.0 and s.isGroundable then
			return "LANDING"
		end

		if canTransitionNormal then
			-- Picado directo desde climb (pushover agresivo)
			if s.pitchDeg <= -15.0 and s.vy <= -18.0 then
				return "DIVE"
			end
			-- Planeo si corta gas
			if s.thrust <= 0.02 and s.vy < 2.0 then
				return "GLIDE"
			end
			-- Nivelación a Cruise
			if s.vy < 2.0 and s.pitchDeg <= 4.0 then
				return "CRUISE"
			end
		end

		return "CLIMB"

	-- -----------------------------------------------------------------
	-- 4. ESTADO: CRUISE
	-- Aristas válidas: -> STALL, -> LANDING, -> CLIMB, -> DIVE, -> GLIDE
	-- -----------------------------------------------------------------
	elseif state == "CRUISE" then
		if s.aoaDeg >= 16.0 or (s.speed < 30.0 and s.lwRatio < 0.30) then
			return "STALL"
		end

		if s.groundDist <= 30.0 and s.vy <= -2.0 and s.isGroundable then
			return "LANDING"
		end

		if canTransitionNormal then
			if s.pitchDeg <= -15.0 and s.vy <= -18.0 then
				return "DIVE"
			end
			if s.pitchDeg >= 8.0 and s.vy >= 5.0 then
				return "CLIMB"
			end
			if s.thrust <= 0.02 and s.groundDist >= 15.0 then
				return "GLIDE"
			end
		end

		return "CRUISE"

	-- -----------------------------------------------------------------
	-- 5. ESTADO: GLIDE
	-- Aristas válidas: -> STALL, -> LANDING, -> CRUISE, -> CLIMB, -> DIVE
	-- -----------------------------------------------------------------
	elseif state == "GLIDE" then
		if s.aoaDeg >= 16.0 or (s.speed < 30.0 and s.lwRatio < 0.30) then
			return "STALL"
		end

		if s.groundDist <= 30.0 and s.vy <= -2.0 and s.isGroundable then
			return "LANDING"
		end

		if canTransitionNormal then
			if s.pitchDeg <= -15.0 and s.vy <= -18.0 then
				return "DIVE"
			end
			if s.vy >= 5.0 and s.pitchDeg >= 8.0 then
				return "CLIMB"
			end
			if s.thrust >= 0.08 then
				return "CRUISE"
			end
		end

		return "GLIDE"

	-- -----------------------------------------------------------------
	-- 6. ESTADO: DIVE
	-- Aristas válidas: -> STALL, -> LANDING, -> CRUISE, -> CLIMB, -> GLIDE
	-- -----------------------------------------------------------------
	elseif state == "DIVE" then
		if s.aoaDeg >= 16.0 then
			return "STALL"
		end

		if s.groundDist <= 30.0 and s.vy <= -2.0 and s.isGroundable then
			return "LANDING"
		end

		if canTransitionNormal then
			-- Salida a Climb si la recogida continúa en trepada
			if s.vy >= 5.0 and s.pitchDeg >= 8.0 then
				return "CLIMB"
			end
			-- Salida de Dive con Conjunción Estricta
			if s.pitchDeg > -8.0 and s.vy > -10.0 then
				if s.thrust <= 0.02 then
					return "GLIDE"
				else
					return "CRUISE"
				end
			end
		end

		return "DIVE"

	-- -----------------------------------------------------------------
	-- 7. ESTADO: STALL
	-- Aristas válidas: -> RECOVERY ÚNICAMENTE
	-- -----------------------------------------------------------------
	elseif state == "STALL" then
		-- Salida forzosa únicamente hacia Recovery
		if s.pitchDeg <= -5.0 and s.aTrend > 5.0 then
			return "RECOVERY"
		end

		return "STALL"

	-- -----------------------------------------------------------------
	-- 8. ESTADO: RECOVERY
	-- Aristas válidas: -> DIVE, -> CLIMB, -> GLIDE, -> CRUISE (Sin forzar Cruise)
	-- -----------------------------------------------------------------
	elseif state == "RECOVERY" then
		local isRecoveryComplete = (s.aoaDeg <= 11.0) and (s.lwRatio >= 0.85) and (s.speed >= 55.0)

		if isRecoveryComplete and canTransitionNormal then
			-- Despacho directo según el régimen físico instantáneo
			if s.pitchDeg <= -15.0 and s.vy <= -18.0 then
				return "DIVE"
			elseif s.pitchDeg >= 8.0 and s.vy >= 5.0 then
				return "CLIMB"
			elseif s.thrust <= 0.02 then
				return "GLIDE"
			else
				return "CRUISE"
			end
		end

		return "RECOVERY"

	-- -----------------------------------------------------------------
	-- 9. ESTADO: LANDING
	-- Aristas válidas: -> TOUCHDOWN, -> CLIMB (Go-Around)
	-- -----------------------------------------------------------------
	elseif state == "LANDING" then
		-- Preemption instantánea por Go-Around
		if s.thrust >= 0.85 and s.pitchDeg >= 10.0 then
			return "CLIMB"
		end

		-- Preemption instantánea por Touchdown al confirmar contacto multi-probe
		if s.isTouchdownContact and s.touchdownCount >= 3 then
			return "TOUCHDOWN"
		end

		return "LANDING"

	-- -----------------------------------------------------------------
	-- 10. ESTADO: TOUCHDOWN
	-- Aristas válidas: -> GROUNDED, -> TAKEOFF
	-- -----------------------------------------------------------------
	elseif state == "TOUCHDOWN" then
		-- Disipación y parada completa -> GROUNDED
		if s.speed <= 12.0 and s.isGrounded then
			return "GROUNDED"
		end

		-- Rebote elástico / aceleración violenta hacia arriba
		if not s.isContact and s.vy > 5.0 then
			return "TAKEOFF"
		end

		return "TOUCHDOWN"
	end

	return currentState
end

-- =====================================================================
-- BUCLE PRINCIPAL EN HEARTBEAT (OBSERVADOR AUTORITATIVO)
-- =====================================================================
RunService.Heartbeat:Connect(function(dt)
	local groundData = groundSensor:update(dt)
	local signals = evaluateFlightSignals(dt, groundData)

	local nextState = getNextStateFromGraph(currentState, signals, stateTime)

	if nextState ~= currentState then
		previousState = currentState
		currentState = nextState
		stateTime = 0.0

		dtRoot:SetAttribute("FlightState", currentState)
		dtRoot:SetAttribute("FlightDomain", DOMAIN_MAP[currentState])
	else
		stateTime = stateTime + dt
	end

	-- Publicar telemetría diagnóstica de suelo
	dtRoot:SetAttribute("GroundDistance", groundData.GroundDistance)
	dtRoot:SetAttribute("GroundContact", groundData.GroundContact)
	dtRoot:SetAttribute("IsTouchdownContact", groundData.IsTouchdownContact)
	dtRoot:SetAttribute("IsGrounded", groundData.IsGrounded)
	dtRoot:SetAttribute("IsGroundableSurface", groundData.IsGroundableSurface)
end)

print("[WyvernFlightStateManager] Servicio Autoritativo de Estados Inicializado en Servidor (Fase 5E.2-D).")
