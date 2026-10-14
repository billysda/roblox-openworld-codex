-- WyvernAeroSurfaceConfig.lua
-- Configuración de Vuelo Completo con Superficies Aerodinámicas Distribuidas (Fase 4D)

local WyvernAeroSurfaceConfig = {
	-- Switch de selección de modelo
	-- true  = Superficies Distribuidas Autónomas (Fase 4D)
	-- false = Fallback Global CoM Baseline
	USE_EXPERIMENTAL_AERO_SURFACES = true,

	-- Límites de deflexión aerodinámica de control (en grados)
	MAX_PITCH_DEFLECTION_DEG = 12.0,    -- Elevones y timón de profundidad (±12°)
	MAX_ROLL_DEFLECTION_DEG  = 12.0,    -- Alerones diferenciales (±12°)
	MAX_YAW_DEFLECTION_DEG   = 10.0,    -- Timón vertical de dirección (±10°)

	-- Definición geométrica de las 7 superficies distribuidas
	SURFACES = {
		LeftWingOuter = {
			Name = "LeftWingOuter",
			LocalOffset = Vector3.new(16.0, 0.8, -2.0),
			AreaFraction = 0.24,
			LocalChord = Vector3.new(0, 0, -1),
			LocalNormal = Vector3.new(0, 1, 0),
			LocalSpan = Vector3.new(1, 0, 0),
			PitchControlWeight = 0.5,
			RollControlWeight  = 1.0,
			YawControlWeight   = 0.0
		},
		LeftWingInner = {
			Name = "LeftWingInner",
			LocalOffset = Vector3.new(6.5, 0.4, -1.0),
			AreaFraction = 0.26,
			LocalChord = Vector3.new(0, 0, -1),
			LocalNormal = Vector3.new(0, 1, 0),
			LocalSpan = Vector3.new(1, 0, 0),
			PitchControlWeight = 0.8,
			RollControlWeight  = 0.4,
			YawControlWeight   = 0.0
		},
		RightWingInner = {
			Name = "RightWingInner",
			LocalOffset = Vector3.new(-6.5, 0.4, -1.0),
			AreaFraction = 0.26,
			LocalChord = Vector3.new(0, 0, -1),
			LocalNormal = Vector3.new(0, 1, 0),
			LocalSpan = Vector3.new(-1, 0, 0),
			PitchControlWeight = 0.8,
			RollControlWeight  = -0.4,
			YawControlWeight   = 0.0
		},
		RightWingOuter = {
			Name = "RightWingOuter",
			LocalOffset = Vector3.new(-16.0, 0.8, -2.0),
			AreaFraction = 0.24,
			LocalChord = Vector3.new(0, 0, -1),
			LocalNormal = Vector3.new(0, 1, 0),
			LocalSpan = Vector3.new(-1, 0, 0),
			PitchControlWeight = 0.5,
			RollControlWeight  = -1.0,
			YawControlWeight   = 0.0
		},
		Tail = {
			Name = "Tail",
			LocalOffset = Vector3.new(0.0, 1.2, 10.5), -- Estabilizador horizontal posterior
			AreaFraction = 0.16,
			LocalChord = Vector3.new(0, 0, -1),
			LocalNormal = Vector3.new(0, 1, 0),
			LocalSpan = Vector3.new(1, 0, 0),
			PitchControlWeight = -1.0,
			RollControlWeight  = 0.0,
			YawControlWeight   = 0.0
		},
		VerticalFin = {
			Name = "VerticalFin",
			LocalOffset = Vector3.new(0.0, 1.8, 9.5),  -- Aleta vertical dorsal de guiñada
			AreaFraction = 0.12,
			LocalChord = Vector3.new(0, 0, -1),
			LocalNormal = Vector3.new(1, 0, 0),        -- Normal transversal lateral (+X)
			LocalSpan = Vector3.new(0, 1, 0),
			PitchControlWeight = 0.0,
			RollControlWeight  = 0.0,
			YawControlWeight   = 1.0
		},
		Body = {
			Name = "Body",
			LocalOffset = Vector3.new(0.0, 0.0, 0.0),
			AreaFraction = 0.10,
			LocalChord = Vector3.new(0, 0, -1),
			LocalNormal = Vector3.new(0, 1, 0),
			LocalSpan = Vector3.new(1, 0, 0),
			PitchControlWeight = 0.0,
			RollControlWeight  = 0.0,
			YawControlWeight   = 0.0
		}
	}
}

return WyvernAeroSurfaceConfig
