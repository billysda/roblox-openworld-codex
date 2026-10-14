-- WyvernAerodynamicsConfig.lua
-- Configuración Aerodinámica y de Control Rotacional Físico (Fase 3A)
-- Mantiene intacto el modelo aerodinámico de la Fase 2D y añade torque físico para Pitch/Roll/Yaw.

local WyvernAerodynamicsConfig = {
	-- Parámetros físicos base
	BASE_MASS = 134.4,                  -- kg (Masa real de DT_Root / Assembly)
	DEFAULT_GRAVITY = 196.2,            -- studs/s^2 (workspace.Gravity)
	WEIGHT = 134.4 * 196.2,             -- 26,369.28 N

	-- Velocidades
	MIN_AIRSPEED = 6.0,                 -- studs/s
	CRUISING_SPEED = 80.0,              -- studs/s

	-- Sustentación (Lift) - Intacto de Fase 2D
	MAX_LIFT_COEFFICIENT = 4.12,        -- Cl máximo
	NEUTRAL_LIFT_FACTOR = 0.40,         -- Cl en AoA = 0°
	POST_STALL_LIFT_FACTOR = 0.25,      -- Cl residual en pérdida profunda

	-- Ángulos de Ataque - Intacto de Fase 2D
	OPTIMAL_AOA_DEG = 12.0,             -- AoA óptimo
	STALL_AOA_DEG = 16.0,               -- Inicio del desprendimiento de flujo
	MAX_AOA_DEG = 45.0,                 -- Límite angular

	-- Resistencia (Drag) - Intacto de Fase 2D
	BASE_DRAG_COEFFICIENT = 0.025,      -- Cd0
	INDUCED_DRAG_COEFF = 0.0025,        -- K inducido
	STALL_DRAG_MULTIPLIER = 2.2,        -- Multiplicador en stall
	MAX_DRAG_FORCE = 12000.0,           -- Límite de seguridad (N)

	-- Punto de aplicación en Center of Mass (X=0, Y=0, Z=0)
	LIFT_ATTACHMENT_OFFSET = Vector3.new(0, 0, 0),

	-- Torques Físicos Máximos (N*studs) para control rotacional
	-- Calibrados para el momento de inercia de la Assembly (~900 kg*stud^2)
	MAX_PITCH_TORQUE = 3500.0,          -- Eje local X (Nose-Up / Nose-Down)
	MAX_ROLL_TORQUE  = 2800.0,          -- Eje local Z (Bancar / Roll)
	MAX_YAW_TORQUE   = 3000.0,          -- Eje local Y (Guiñada / Yaw)

	-- Zona de spawn aérea
	TEST_SPAWN_POSITION = Vector3.new(-130.3, 180.0, 0.0),
	MIN_SAFE_ALTITUDE = 12.0,
}

return WyvernAerodynamicsConfig
