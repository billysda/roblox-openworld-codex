-- WyvernPhysicsConfig.lua
-- Constantes de calibración exclusivas para el Baseline Test de Física (Fase 1B)

local WyvernPhysicsConfig = {
	-- Tiempos de las etapas del test (segundos)
	INITIAL_IDLE_TIME = 0.5,
	GRAVITY_TEST_TIME = 1.0,
	FORWARD_FORCE_TIME = 1.5,
	FORWARD_INERTIA_TIME = 1.0,
	TORQUE_TEST_TIME = 1.5,
	TORQUE_INERTIA_TIME = 1.0,

	-- Magnitudes físicas de prueba calibradas para la masa de la Assembly (134.4 kg)
	BASELINE_FORWARD_FORCE = 8000, -- Fuerza hacia adelante (~60 N/kg de aceleración)
	BASELINE_TORQUE = 2500,       -- Torque en eje Y (Yaw) para rotación física

	-- Intervalo de muestreo de telemetría (segundos)
	TELEMETRY_INTERVAL = 0.25,
}

return WyvernPhysicsConfig
