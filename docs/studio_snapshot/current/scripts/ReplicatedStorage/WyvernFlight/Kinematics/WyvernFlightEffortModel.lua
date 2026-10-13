-- WyvernFlightEffortModel.lua
-- Modelo Continuo de Esfuerzo de Vuelo (Fase 5D.2)
-- Calcula y suaviza la variable continua FlightEffort [0.0, 1.0] a partir de telemetría física.
-- 100% libre de state machines discretas y 100% independiente del framerate.

local WyvernFlightEffortModel = {}
WyvernFlightEffortModel.__index = WyvernFlightEffortModel

-- Pesos y Constantes del Modelo
local WEIGHT_LW    = 0.45 -- Prioridad principal: déficit/exceso de sustentación
local WEIGHT_SPEED = 0.25 -- Modulador secundario por velocidad
local WEIGHT_THRUST= 0.20 -- Demanda de acelerador
local WEIGHT_CLIMB = 0.15 -- Esfuerzo en trepada
local WEIGHT_SINK  = 0.15 -- Caída por pérdida de sustentación

local K_RISE = 4.0 -- Tasa de subida (1/s)
local K_FALL = 1.5 -- Tasa de relajación (1/s)

function WyvernFlightEffortModel.new()
	local self = setmetatable({}, WyvernFlightEffortModel)
	self.currentEffort = 0.0
	self.targetEffort = 0.0
	return self
end

function WyvernFlightEffortModel:computeTarget(flightState)
	local speed = math.max(flightState.airspeed or 0, 0)
	local lwRatio = math.max(flightState.lwRatio or 0, 0)
	local thrust = math.clamp(flightState.thrustPercent or 0, 0, 1)
	local vy = flightState.verticalSpeed or 0
	local pitchDeg = flightState.pitchDeg or 0
	-- NOTA DE DISEÑO (Fase 5D.2B): Aero_AoA NO es una entrada activa de la fórmula de FlightEffort;
	-- se mantiene disponible en telemetría como señal diagnóstica / futura.

	-- 1. Componente de Sustentación vs Peso (L/W)
	local eLW = 0.0
	if lwRatio <= 1.0 then
		eLW = 1.0 - lwRatio -- 1.0 a cero sustentación, 0.0 en trim equilibrado
	else
		eLW = -0.5 * math.clamp(lwRatio - 1.0, 0.0, 1.0) -- Margen de alivio
	end

	-- 2. Componente de Velocidad (Airspeed)
	local uV = math.clamp((speed - 40.0) / (90.0 - 40.0), 0.0, 1.0)
	local smoothV = uV * uV * (3.0 - 2.0 * uV)
	local eSpeed = 1.0 - 0.85 * smoothV -- 1.0 a baja velocidad (<40), 0.15 a velocidad de planeo (>=90)

	-- 3. Componente de Acelerador (Thrust)
	local eThrust = thrust

	-- 4. Componente de Trepada (Climb)
	local eClimb = 0.0
	if vy > 0 and pitchDeg > 0 then
		local normVy = math.clamp(vy / 30.0, 0.0, 1.0)
		local normPitch = math.clamp(pitchDeg / 25.0, 0.0, 1.0)
		eClimb = normVy * normPitch
	end

	-- 5. Componente de Hundimiento con Déficit (Sink Deficit)
	local eSink = 0.0
	if vy < -15.0 and lwRatio < 0.90 then
		local normSink = math.clamp((-vy - 15.0) / 35.0, 0.0, 1.0)
		local normDeficit = math.clamp((0.90 - lwRatio) / 0.90, 0.0, 1.0)
		eSink = normSink * normDeficit
	end

	-- 6. Combinación Ponderada y Clamping Estricto [0, 1]
	local rawTarget = (WEIGHT_LW * eLW) + (WEIGHT_SPEED * eSpeed) + (WEIGHT_THRUST * eThrust) + (WEIGHT_CLIMB * eClimb) + (WEIGHT_SINK * eSink)
	self.targetEffort = math.clamp(rawTarget, 0.0, 1.0)

	return self.targetEffort, {
		eLW = eLW,
		eSpeed = eSpeed,
		eThrust = eThrust,
		eClimb = eClimb,
		eSink = eSink
	}
end

function WyvernFlightEffortModel:update(dt, flightState)
	local target, components = self:computeTarget(flightState)

	-- Filtrado temporal asimétrico independiente de framerate (exponential decay)
	local k = (target >= self.currentEffort) and K_RISE or K_FALL
	local alpha = 1.0 - math.exp(-k * math.max(dt, 0.001))

	self.currentEffort = self.currentEffort + (target - self.currentEffort) * alpha
	self.currentEffort = math.clamp(self.currentEffort, 0.0, 1.0)

	return self.currentEffort, self.targetEffort, components
end

return WyvernFlightEffortModel
