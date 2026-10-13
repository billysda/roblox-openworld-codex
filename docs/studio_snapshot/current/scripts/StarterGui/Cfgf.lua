local Cfg = {}

Cfg.Names = {
	Runtime = "SheepRuntime",

	Houses = "Houses",
	HousePromptPart = "ClaimPromptPart",
	HousePrompt = "ProximityPrompt",
	CorralCenter = "CorralCenter",
	SpawnFolder = "SheepSpawns",

	Assets = "Assets",
	SheepFolder = "Sheep",
	SheepTemplate = "SheepTemplate",
}

Cfg.SheepPerFlock = 10
Cfg.SpawnYOffset = 3

Cfg.Radius = 15
Cfg.FleeSpeed = 12
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
	AI = 0.1,
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

-- Movimiento suave cuando el rebaño está tranquilo
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
	-- Si la oveja camina lento, usa Walk.
	-- Si supera esta velocidad, usa Trot.
	TrotSpeedThreshold = 5.5,

	-- Si supera esta velocidad, usa Run.
	RunSpeedThreshold = 13,

	-- Si el jugador está demasiado cerca, la oveja entra en pánico corto.
	PanicDistance = 7,
	PanicSpeed = 16,

	-- Velocidades base para sincronizar la animación
	WalkBaseSpeed = 3.2,
	TrotBaseSpeed = 10,
	RunBaseSpeed = 16,

	AdjustMin = 0.75,
	AdjustMax = 1.45,
}

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

	-- Provisional hasta que publiques SleepEnd real
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

Cfg.Debug = {
	PrintInvalidActions = true,
	SetDebugAttributes = true,
}

Cfg.Response = {
	-- Tiempo de reacción cuando el rebaño empieza a moverse
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

	-- Cada cuánto cambia su estilo de movimiento durante huida/rebaño
	MoveModeDurationMin = 1.6,
	MoveModeDurationMax = 3.8,

	-- Reacción normal del rebaño
	WalkChance = 0.18,
	TrotChance = 0.62,
	RunChance = 0.20,

	-- Si el jugador está demasiado cerca
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

Cfg.Lost = {
	-- Si una oveja está más lejos que esto de la líder, entra en recuperación.
	LeaderDistance = 26,

	-- Si está muy lejos del centro general del rebaño, también vuelve.
	CenterDistance = 32,

	-- Si está extremadamente lejos, corre más fuerte.
	CriticalDistance = 45,

	-- Velocidades para volver al grupo.
	RegroupSpeedMin = 9,
	RegroupSpeedMax = 13,

	CriticalSpeedMin = 13,
	CriticalSpeedMax = 17,

	-- Separación durante regreso, para que no se monten encima.
	WeightLeader = 1.35,
	WeightCenter = 0.85,
	WeightSeparate = 0.55,
}

Cfg.Flow = {
	-- La zona hacia donde se mueve el rebaño estará delante del centro.
	TargetAhead = 13,

	-- Separación lateral entre posiciones imaginarias.
	SlotSpacing = 5,

	-- Distancia entre filas del rebaño.
	RowSpacing = 5,

	-- Cuánto le importa a cada oveja ir hacia su zona.
	SlotPull = 1.05,

	-- Cuánto empuja la dirección general del rebaño.
	ForwardWeight = 0.95,

	-- Cohesión ligera al centro, no demasiado fuerte.
	CenterWeight = 0.22,

	-- Separación entre ovejas.
	SeparationWeight = 1.2,

	-- Huida del jugador cuando está muy cerca.
	PlayerFleeWeight = 1.1,

	-- Movimiento imperfecto/natural.
	NaturalWeight = 0.1,

	-- Si una oveja se adelanta, no la jalamos fuerte hacia atrás.
	AheadSoftLimit = 7,

	-- Máxima fuerza de atracción hacia su zona.
	SlotMaxPullDistance = 18,

	-- Cantidad de columnas imaginarias.
	Columns = 5,
}

return Cfg