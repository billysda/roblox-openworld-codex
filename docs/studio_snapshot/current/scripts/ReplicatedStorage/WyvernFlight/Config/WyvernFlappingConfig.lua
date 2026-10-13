-- WyvernFlappingConfig.lua
-- Configuración y Cinemática Rigurosa del Flapping Físico (Fase 5B.2)
-- Definición formal de ciclo armónico, tasas angulares y velocidades inducidas

local WyvernFlappingConfig = {
	-- Interruptor maestro
	ENABLED = false,

	-- Parámetros cinemáticos nominales
	DEFAULT_FREQUENCY_HZ = 1.5,      -- Frecuencia en Hz
	DEFAULT_AMPLITUDE_DEG = 10.0,    -- Amplitud de deflexión alar en grados
	DOWNSTROKE_RATIO = 0.50,         -- [AUDITORÍA: Marcador para asimetría futura, actualmente simétrico 0.50]
	PHASE_OFFSET = 0.0,              -- Desfase inicial global en radianes

	-- Fases individuales por ala
	LEFT_PHASE = 0.0,
	RIGHT_PHASE = 0.0,

	-- Brazo de palanca aerodinámico medio por sección alar (en studs)
	WING_SPAN_DISTANCE = {
		LeftWingOuter = 16.0,
		LeftWingInner = 6.5,
		RightWingInner = 6.5,
		RightWingOuter = 16.0
	},

	-- Factor de centro de presión transversal del segmento alar (0.5 = centro geométrico)
	SPAN_AERO_CENTER_FACTOR = 0.5,

	-- Superficies afectadas por el batido
	AFFECTED_SURFACES = {
		LeftWingOuter = true,
		LeftWingInner = true,
		RightWingInner = true,
		RightWingOuter = true,
		Tail = false,
		VerticalFin = false,
		Body = false
	}
}

-- Cinemática armónica diferenciable con unidades normalizadas
function WyvernFlappingConfig.computeFlapState(t, freqHz, ampDeg, phaseOffset)
	local f = freqHz or WyvernFlappingConfig.DEFAULT_FREQUENCY_HZ
	local A_deg = ampDeg or WyvernFlappingConfig.DEFAULT_AMPLITUDE_DEG
	local offset = phaseOffset or 0.0

	local omega = 2.0 * math.pi * f
	local phase = (t * omega + offset) % (2.0 * math.pi)

	-- 1. Deflexión angular (grados y radianes)
	local angleDeg = A_deg * math.sin(phase)
	local angleRad = math.rad(angleDeg)

	-- 2. Tasa de cambio angular dδ/dt (grados/s y rad/s)
	-- d/dt [A * sin(omega*t)] = A * omega * cos(omega*t)
	local rateDegPerSec = A_deg * omega * math.cos(phase)
	local rateRadPerSec = math.rad(rateDegPerSec) -- Riguroso: radianes por segundo

	return {
		phase = phase,
		angleDeg = angleDeg,
		angleRad = angleRad,
		rateDegPerSec = rateDegPerSec,
		rateRadPerSec = rateRadPerSec,
		omega = omega,
		freqHz = f,
		ampDeg = A_deg
	}
end

return WyvernFlappingConfig
