-- WyvernTakeoffConfig.lua
-- Configuración del Actuador Físico de Despegue (Fase 5E.3)
-- Sistema Server-Authoritative: Fuerza vertical y empuje inicial transitorios.

local WyvernTakeoffConfig = {
	-- Magnitud de asistencia vertical transitoria (en Newtons)
	-- Masa = 134.4 kg, Peso = 26,369.28 N
	-- 32,000 N -> Fuerza neta hacia arriba = +5,630.72 N (a_y inicial neta ≈ +41.9 studs/s^2)
	TAKEOFF_VERTICAL_FORCE = 32000.0,
	
	-- Empuje longitudinal inicial aplicado durante el despegue (60% = 12,000 N)
	TAKEOFF_INITIAL_THRUST_PERCENT = 0.60,
	
	-- Duración máxima de seguridad del actuador de despegue (segundos)
	MAX_TAKEOFF_DURATION = 2.0,
	
	-- Altura de despeje para transición a CLIMB (studs)
	CLIMB_TRANSITION_CLEARANCE = 12.0,
	
	-- Suave torque de cabeceo positivo para rotación de morro (N*m)
	-- Aplicado transitoriamente durante la rotación inicial
	TAKEOFF_PITCH_BIAS_TORQUE = 2500.0,
	
	-- Punto de aplicación: estrictamente en el Centro de Masa
	TAKEOFF_ATTACHMENT_OFFSET = Vector3.new(0, 0, 0)
}

return WyvernTakeoffConfig
