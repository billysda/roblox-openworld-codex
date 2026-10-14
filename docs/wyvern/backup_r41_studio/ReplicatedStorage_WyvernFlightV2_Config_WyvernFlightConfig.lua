-- WyvernFlightConfig.lua
-- Configuración Central del Sistema de Vuelo y Cámara DragonWorld (Fase R2)
-- Basado directamente en las especificaciones de ZoomCam.cs, CameraEffectsManager.cs y Cameras.cs.

local WyvernFlightConfig = {
	-- =========================================================================
	-- 1. VELOCIDADES Y DINÁMICA DE VUELO (Fase R1 Intacta)
	-- =========================================================================
	CruiseSpeed = 80.0,             -- studs/s: velocidad base de crucero
	MaxSpeed = 130.0,               -- studs/s: velocidad máxima al mantener aceleración (W)
	MinSpeed = 30.0,                -- studs/s: velocidad mínima al frenar (S)
	
	Acceleration = 35.0,            -- studs/s^2: aceleración progresiva con peso
	Deceleration = 20.0,            -- studs/s^2: retorno suave a velocidad de crucero
	BrakeDeceleration = 45.0,       -- studs/s^2: frenado activo al pulsar S

	-- =========================================================================
	-- 2. DIRECCIÓN REAL Y GIRO COORDINADO (Fase R3: Wyvern Steering)
	-- =========================================================================
	MaxTurnRoll = 35.0,             -- deg: alabeo objetivo máximo al girar
	BaseYawRate = 22.0,             -- deg/s: tasa base de cambio de rumbo
	TurnYawBonus = 26.0,            -- deg/s: bono de guiñada al alcanzar alabeo pleno (Total máx: 48 deg/s)
	
	TurnResponse = 5.0,             -- factor de interpolación suave para entradas A/D
	RollAcceleration = 5.5,         -- tasa de entrada hacia el alabeo de giro
	RollReturn = 4.0,               -- tasa de recuperación a nivel horizontal al soltar A/D
	YawSmoothing = 6.0,             -- aceleración y suavizado angular de guiñada
	FlightDirectionResponse = 5.5,  -- factor de curvatura suave de la trayectoria de velocidad

	SpeedTurnMin = 0.40,            -- autoridad mínima de giro a muy baja velocidad
	SpeedTurnMax = 1.15,            -- autoridad máxima acotada durante BOOST

	PitchSpeed = 40.0,              -- deg/s: velocidad de cabeceo
	MaxPitchUp = 45.0,              -- deg: límite de subida
	MaxPitchDown = 60.0,            -- deg: límite de picada
	PitchSmooth = 5.0,              -- factor de convergencia suave

	VerticalSpeed = 35.0,           -- studs/s: tasa de ascenso (Space) o descenso (LCtrl)
	VerticalSmooth = 6.0,

	-- =========================================================================
	-- 2.1 MOUSE AIM STEERING (Fase R4: DragonWorld Aim / Mouse Steering)
	-- =========================================================================
	AimTurnDeadzone = 3.5,          -- deg: zona muerta angular horizontal (sin jitter en vuelo recto)
	AimTurnResponse = 5.0,          -- factor de suavizado de intención de giro por aim
	AimMaxYawError = 75.0,          -- deg: error angular de guiñada donde se alcanza el 100% de intención de giro
	AimTurnStrength = 1.0,          -- multiplicador de fuerza de giro por aim

	AimPitchDeadzone = 3.0,         -- deg: zona muerta angular vertical
	AimMaxPitchError = 45.0,        -- deg: error angular de cabeceo donde se alcanza el 100% de elevación
	AimPitchStrength = 1.0,         -- multiplicador de fuerza de cabeceo por aim

	MouseSensitivity = 0.18,        -- deg/pixel: sensibilidad de rotación de cámara por movimiento de ratón

	-- =========================================================================
	-- 3. BOOST FÍSICO Y CICLO DE ESTADOS (DragonWorld DragonFlyingState / FlyFlap)
	-- =========================================================================
	BoostMaxSpeed = 175.0,          -- studs/s: velocidad pico durante el impulso
	BoostAcceleration = 130.0,      -- studs/s^2: incremento violento de velocidad
	BoostDuration = 2.4,            -- segundos totales del impulso activo
	BoostStartDuration = 0.25,      -- segundos: fase START / IMPULSE inicial
	BoostSustainDuration = 1.65,    -- segundos: fase SUSTAIN a máxima velocidad
	BoostReleaseDuration = 0.50,    -- segundos: fase RELEASE post-impulso
	BoostCooldown = 4.0,            -- segundos: recarga antes de poder volver a impulsarse
	BoostReturnSmooth = 2.5,        -- desaceleración suave post-boost hacia crucero

	-- =========================================================================
	-- 4. CÁMARA ESTILO FREELOOK Y ÓRBITAS (DragonWorld ZoomCam.cs / Cameras.cs)
	-- =========================================================================
	VisualCenterOffset = Vector3.new(0, 1.5, 2.0), -- punto focal del torso/cuerpo estable

	-- 3 Órbitas de FreeLook (Altura y Radio según elevación de pitch)
	OrbitTopHeight = 14.0,          -- studs sobre el centroide en ascenso
	OrbitTopRadius = 38.0,          -- radio en ascenso
	OrbitMidHeight = 6.0,           -- studs sobre el centroide en vuelo nivelado
	OrbitMidRadius = 44.0,          -- radio en crucero
	OrbitBotHeight = -4.0,          -- studs bajo el centroide en picada
	OrbitBotRadius = 34.0,          -- radio en picada

	-- Curva no lineal de zoom (pow(zAxis, zoomCurvePower))
	ZoomCurvePower = 3.0,
	MinZoom = 0.5,
	MaxZoom = 1.0,
	DefaultZAxis = 0.0,             -- 0.0 = maxZoom / mayor amplitud visual

	-- Retrasos y Amortiguamientos Separados (Camera Lag con peso)
	PositionSmooth = 8.5,           -- seguimiento de posición con inercia (no pegado)
	RotationSmooth = 7.0,           -- retraso rotacional al girar (abre la curva)
	TargetSmooth = 16.0,            -- seguimiento amortiguado del look target
	LookAheadFactor = 0.22,         -- lookTarget = center + velocity * factor
	CameraBankFactor = 0.35,        -- fracción del roll que acompaña la cámara (35%)

	-- =========================================================================
	-- 5. PIPELINE DE FOV (DragonWorld ZoomCam.cs)
	-- =========================================================================
	MinFOV = 45.0,                  -- FOV a zoom máximo
	MaxFOV = 70.0,                  -- FOV base en vuelo normal (zAxis = 0)
	BoostSustainedFOV = 20.0,       -- +20° de apertura progresiva sostenida en BOOST
	BoostImpulseFOV = 8.0,          -- +8° de oscilación por batido / pulso en BOOST
	BoostTransitionSpeed = 1.5,     -- segundos para transición MoveTowards(smoothBoost)
	BoostCameraPullback = 10.0,     -- studs que la cámara se aleja hacia atrás en BOOST
	FOVSmooth = 6.0,                -- suavizado de FOV

	-- =========================================================================
	-- 6. CAMERA SHAKE PROCEDURAL CONTROLADO (DragonWorld CameraEffectsManager.cs)
	-- =========================================================================
	BaseShakeAmpMult = 0.25,        -- multiplicador de amplitud en crucero tranquilo
	BaseShakeFreqMult = 0.30,       -- multiplicador de frecuencia en crucero tranquilo
	BoostShakeAmpMult = 1.50,       -- multiplicador de amplitud en BOOST (1.5x original)
	BoostShakeFreqMult = 1.50,      -- multiplicador de frecuencia en BOOST (1.5x original)
	ShakeSmoothTime = 0.20,         -- tiempo de transición entre multiplicadores de shake
	ImpulseShakeAmp = 1.50,         -- impulso inicial en BOOST START
	ImpulseShakeFreq = 1.50,
	ImpulseShakeDuration = 0.35,    -- segundos de duración del impulso cuadrático inicial

	-- =========================================================================
	-- 7. ANIMACIÓN IMPORTADA INTACTA
	-- =========================================================================
	AnimationId = "rbxassetid://96071143174783",
	AnimationSpeed = 1.0,

	-- =========================================================================
	-- 8. CONDICIÓN DE SPAWN Y RESET
	-- =========================================================================
	SpawnPosition = Vector3.new(0, 300.0, 0),
	SpawnHeading = Vector3.new(0, 0, -1)
}

return WyvernFlightConfig
