local Cfg = {}

-- =========================================================================
-- PASTURE SYSTEM v1.0 PROFESSIONAL
-- Una sola fuente de configuración del sistema de ovejas.
-- =========================================================================

Cfg.Names = {
	Runtime = "SheepRuntime",

	Houses = "Houses",
	HousePromptPart = "ClaimPromptPart",
	HousePrompt = "ProximityPrompt",
	CorralCenter = "CorralCenter",
	PenCenter = "CorralCenter",
	PenEntrance = "PenEntrance",
	SpawnFolder = "SheepSpawns",

	Assets = "Assets",
	SheepFolder = "Sheep",
	SheepTemplate = "SheepTemplate",

	RemoteFolder = "PastureRemote",
	WhistleRemote = "Whistle",
}

Cfg.Debug = {
	PrintInvalidActions = false,
	SetDebugAttributes = true,
	PrintLifecycle = true,
}

Cfg.Collision = {
	Enabled = true,
	SheepGroup = "PastureSheep",
	PlayerGroup = "PasturePlayer",
	SheepCollideWithSheep = false,
	SheepCollideWithPlayers = false,
}

Cfg.SheepPerFlock = 2
Cfg.SpawnYOffset = 3

Cfg.Radius = 15
Cfg.PlayerMoveSpeed = 1.2

Cfg.Hover = {
	TargetHeight = 3.2,
	RayLength = 11.2,
	Spring = 1400,
	Damping = 220,
	HeightSmoothing = 12,
	MaxCorrectionRatio = 0.75,
}

Cfg.Update = {
	-- Hover/altura física. 30 Hz reduce raycasts sin perder estabilidad.
	Physics = 1 / 30,

	-- IA de comportamiento. 10 Hz es suficiente para rebaños.
	AI = 0.1,

	-- Evita acumulación excesiva si el servidor tiene un pico.
	MaxPhysicsCatchUp = 2,
}

Cfg.IdleTime = {
	Min = 4,
	Max = 12,
}

Cfg.Flock = {
	PressureRadius = 28,
	MinMoveTime = 1.2,

	RecallDuration = 10,
	RecallStopDistance = 12,
	WhistleCooldown = 1.5,

	MoveSpeed = 10,
	LeaderSpeed = 11,
	RegroupSpeed = 7,

	FollowLeaderDistance = 7,
	CohesionRadius = 10,
	MaxGroupDistance = 20,
	SeparationRadius = 4,

	DirectionSmoothing = 0.22,

	WeightMove = 1.0,
	WeightLeader = 0.85,
	WeightCenter = 0.7,
	WeightSeparate = 1.35,
	WeightPlayerFlee = 1.15,
	WeightNatural = 0.12,
}

Cfg.CommandTarget = {
	RemoteName = "CommandTarget",

	MaxDistanceFromPlayer = 220,
	Duration = 30,
	StopDistance = 6,

	SoftFleeRadius = 6,
	EmergencyPanicDistance = 3,
	PlayerFleeWeight = 0.25,

	ForceImmediateResponse = true,
}

Cfg.Pen = {
	DefaultRadius = 12,
	DefaultApproachRadius = 16,
	DefaultEntryRadius = 4,
	AssistEnabled = true,

	-- Ruta G: entrada -> centro del corral.
	CommandEntranceDistance = 7,
	CommandCenterDistance = 6,
}

-- Movimiento de grupo por "zona de flujo", no siguiendo rígidamente a la líder.
Cfg.Flow = {
	TargetAhead = 13,
	SlotSpacing = 5,
	RowSpacing = 5,
	SlotPull = 1.05,
	ForwardWeight = 0.95,
	CenterWeight = 0.22,
	SeparationWeight = 1.2,
	PlayerFleeWeight = 1.1,
	NaturalWeight = 0.1,
	AheadSoftLimit = 7,
	SlotMaxPullDistance = 18,
	Columns = 5,
}

-- Recuperación cuando una oveja se queda demasiado lejos del rebaño.
Cfg.Lost = {
	LeaderDistance = 26,
	CenterDistance = 32,
	CriticalDistance = 45,

	RegroupSpeedMin = 9,
	RegroupSpeedMax = 13,

	CriticalSpeedMin = 13,
	CriticalSpeedMax = 17,

	WeightLeader = 1.35,
	WeightCenter = 0.85,
	WeightSeparate = 0.55,
}

-- Movimiento tranquilo cuando no hay presión del jugador.
Cfg.Calm = {
	MinWait = 1.2,
	MaxWait = 4.5,

	MoveDurationMin = 1.3,
	MoveDurationMax = 4.2,

	WanderChance = 0.8,

	WanderSpeed = 3.2,
	LeaderWanderSpeed = 2.4,

	WanderSpeedMin = 2.2,
	WanderSpeedMax = 4.8,

	BurstChance = 0.16,
	BurstSpeedMin = 6.5,
	BurstSpeedMax = 10.5,

	SoftReturnDistance = 12,
	MaxCalmDistanceFromCenter = 20,

	WeightCenter = 0.55,
	WeightSeparate = 1.15,
	WeightRandom = 0.85,
}

Cfg.MoveAnim = {
	TrotSpeedThreshold = 5.5,
	RunSpeedThreshold = 13,

	PanicDistance = 7,
	PanicSpeed = 16,

	WalkBaseSpeed = 3.2,
	TrotBaseSpeed = 10,
	RunBaseSpeed = 16,

	AdjustMin = 0.75,
	AdjustMax = 1.45,
}

-- Diferencias individuales: algunas reaccionan tarde, otras corren, otras trotan.
Cfg.Response = {
	LeaderDelayMin = 0.05,
	LeaderDelayMax = 0.25,

	FreeDelayMin = 0.05,
	FreeDelayMax = 1.4,

	BusyDelayMin = 0.8,
	BusyDelayMax = 3.2,

	EatDelayMin = 1.5,
	EatDelayMax = 5.5,

	LieDelayMin = 2.5,
	LieDelayMax = 7.5,

	SleepDelayMin = 4.5,
	SleepDelayMax = 11,

	MoveModeDurationMin = 1.6,
	MoveModeDurationMax = 3.8,

	WalkChance = 0.18,
	TrotChance = 0.62,
	RunChance = 0.20,

	PanicWalkChance = 0.08,
	PanicTrotChance = 0.24,
	PanicRunChance = 0.68,

	WalkSpeedMin = 3.2,
	WalkSpeedMax = 5.2,

	TrotSpeedMin = 7.5,
	TrotSpeedMax = 11.5,

	RunSpeedMin = 13.5,
	RunSpeedMax = 17,
}

-- IDs actuales de animación.
-- Es buena práctica tenerlas aquí, NO dentro de la lógica de Sheep.
Cfg.Anim = {
	Walk = "rbxassetid://98801271365263",
	Trot = "rbxassetid://140710027312622",
	Run = "rbxassetid://77179937004940",

	Idle = "rbxassetid://121773693589116",

	LieStart = "rbxassetid://80336580004356",
	LieLoop1 = "rbxassetid://134401810460343",
	LieLoop2 = "rbxassetid://126790719773233",
	LieEnd = "rbxassetid://134697800065907",

	SleepStart = "rbxassetid://103165630829880",
	SleepLoop = "rbxassetid://111279793169124",

	-- Provisional hasta que publiques SleepEnd real.
	SleepEnd = "rbxassetid://134697800065907",

	EatStart = "rbxassetid://91017364750780",
	EatLoop1 = "rbxassetid://104614822864669",
	EatLoop2 = "rbxassetid://93086399005574",
	EatEnd = "rbxassetid://132441957725496",
}

Cfg.ActionLoop = {}

Cfg.IdleActions = {
	{ Name = "Eat", Weight = 55 },
	{ Name = "LieLook", Weight = 30 },
	{ Name = "Sleep", Weight = 15 },
}

Cfg.Sequences = {
	Eat = {
		Start = "EatStart",
		Loops = { "EatLoop1", "EatLoop2" },
		End = "EatEnd",

		MinTime = 18,
		MaxTime = 55,

		LoopSwitchMin = 7,
		LoopSwitchMax = 16,

		ExitBeforeMove = true,
	},

	LieLook = {
		Start = "LieStart",
		Loops = { "LieLoop1", "LieLoop2" },
		End = "LieEnd",

		MinTime = 25,
		MaxTime = 75,

		LoopSwitchMin = 8,
		LoopSwitchMax = 18,

		ExitBeforeMove = true,
	},

	Sleep = {
		Start = "SleepStart",
		Loops = { "SleepLoop" },
		End = "SleepEnd",
		FallbackEnd = "LieEnd",

		MinTime = 50,
		MaxTime = 140,

		LoopSwitchMin = 12,
		LoopSwitchMax = 25,

		ExitBeforeMove = true,
	},

	StartFade = 0.25,
	LoopFade = 0.25,
	EndFade = 0.25,
}

Cfg.Grazing = {
	Enabled = true,

	RuntimeFolder = "PastureGrazingRuntime",
	PointsFolder = "PastureGrazingPoints",

	-- Área lógica invisible. Los wisps son solo una guía aproximada.
	ZoneRadius = 23,
	ZoneHeight = 0.15,
	ZoneDistanceMin = 55,
	ZoneDistanceMax = 90,

	GrassGoal = 100,
	GrassPerSecond = 8,

	-- Para 2 ovejas siguen siendo necesarias las 2; en rebaños mayores ~75%.
	RequireAllSheep = false,
	RequiredFraction = 0.75,
	MinSheepInside = 2,
	ExitGraceSeconds = 1.75,

	-- La ayuda solo aparece cuando ya hay una oveja dentro y otra está cerca.
	AssistEnabled = true,
	AssistDistance = 10,
	AssistSpeed = 6.5,
	AssistInnerPadding = 5,
	AssistRefreshDuration = 0.65,

	CheckInterval = 0.25,
	MarkerUpdateInterval = 0.5,

	XPPerZone = 25,
	XPToNextLevel = 100,

	ZoneYOffset = 0.08,
	LabelHeight = 8,

	-- Elección segura de posición.
	CandidateAttempts = 16,
	TerrainSampleCount = 8,
	MaxTerrainHeightSpread = 6,
	MinGroundNormalY = 0.78,
	GroundRayHeight = 70,
	GroundRayDepth = 160,

	-- Visual orgánico: una sola Part invisible con Attachments y partículas.
	WispCount = 12,
	WispRadiusScale = 0.92,
	WispRadiusJitter = 1.8,
	WispYOffset = 0.08,
	WispTexture = "rbxasset://textures/particles/smoke_main.dds",
	WispRateIdle = 0.55,
	WispRateActive = 0.95,
	WispRateQualified = 1.45,
	WispLifetimeMin = 0.85,
	WispLifetimeMax = 1.35,
	WispSpeedIdleMin = 1.0,
	WispSpeedIdleMax = 1.8,
	WispSpeedActiveMin = 1.35,
	WispSpeedActiveMax = 2.35,
	WispSpeedQualifiedMin = 1.7,
	WispSpeedQualifiedMax = 2.9,
	WispSpreadAngle = 12,
	WispSize = 1.45,

	Debug = true,
}

return Cfg
