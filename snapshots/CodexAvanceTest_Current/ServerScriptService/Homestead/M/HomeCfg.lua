local HomeCfg = {}

HomeCfg.Names = {
	Houses = "Houses",
	HomeRuntime = "HomeRuntime",

	Stations = "Stations",

	StationKitchen = "Kitchen",
	StationStorage = "Storage",
	StationIncubator = "Incubator",
	StationAnimalCare = "AnimalCare",
	StationBed = "Bed",

	AnimalSpawns = "AnimalSpawns",
	ChickenSpawns = "ChickenSpawns",
	CuySpawns = "CuySpawns",

	AnimalZones = "AnimalZones",
	ChickenRoamZone = "ChickenRoamZone",
	ChickenCoopZone = "ChickenCoopZone",
	ChickenEggPoints = "ChickenEggPoints",
	ChickenNestAccessPoints = "ChickenNestAccessPoints",
	ChickenNestJumpLinks = "ChickenNestJumpLinks",
	ChickenIndoorZone = "ChickenIndoorZone",
	CuyRoamZone = "CuyRoamZone",
	CuyIndoorZone = "CuyIndoorZone",
	CuyHidePoints = "CuyHidePoints",

	Remotes = "HomesteadRemote",
	RequestHomeInfo = "RequestHomeInfo",
	HomeInfo = "HomeInfo",
	DropChicken = "DropChicken",
	RequestStorage = "RequestStorage",
	StorageData = "StorageData",
	CloseStorage = "CloseStorage",
}

HomeCfg.DefaultStations = {
	"Kitchen",
	"Storage",
	"Incubator",
	"AnimalCare",
	"Bed",
}

HomeCfg.Anim = {
	Chicken = {
		Walk = "rbxassetid://90131139149240",
		Run = "rbxassetid://118651681311536",
	},

	Cuy = {
		Idle = "",
		Walk = "",
		Run = "",
	},

	Player = {
		CarryChicken = "rbxassetid://84371476515785",
	},
}

HomeCfg.Animals = {
	Chicken = {
		Count = 3,

		TemplateNames = {
			"ChickenTemplate",
			"Gallina",
		},

		UpdateRate = 1 / 30,

		RoamRadius = 9,
		HomeReturnRadius = 15,

		IdleMin = 1.8,
		IdleMax = 6.5,

		PeckMin = 1.2,
		PeckMax = 4.2,

		MoveMin = 1.0,
		MoveMax = 3.2,

		SpeedMin = 1.5,
		SpeedMax = 3.0,

		AvoidDistanceMin = 5.5,
		AvoidDistanceMax = 9.5,

		AvoidSpeedMin = 7.0,
		AvoidSpeedMax = 10.0,

		ReturnSpeedMin = 2.8,
		ReturnSpeedMax = 4.8,

		BurstChance = 0.12,
		BurstCooldownMin = 12,
		BurstCooldownMax = 28,
		BurstDurationMin = 1.2,
		BurstDurationMax = 3.0,
		BurstSpeedMin = 7.5,
		BurstSpeedMax = 11.0,

		EggWalkSpeedMin = 1.6,
		EggWalkSpeedMax = 2.8,
		AccessPointReachDistance = 1.0,
		EggPointReachDistance = 1.0,
		NestAccessCommitTime = 1.2,
		NestFailStuckTime = 2.0,
		FailRetryMin = 8,
		FailRetryMax = 16,

		WalkAnimBaseSpeed = 3.0,
		WalkAnimMin = 0.7,
		WalkAnimMax = 1.9,

		GroundRayHeight = 18,
		GroundRayLength = 80,
		GroundClearance = 0.03,
		ModelYOffset = 0,
		TurnResponsiveness = 8,
		RunTurnResponsiveness = 12,

		ObstacleCheckDistance = 3.5,
		ObstacleCheckHeight = 1.0,
		ObstacleSphereRadius = 0.7,
		ObstacleTurnWeight = 1.5,

		SeparationRadius = 2.4,
		SeparationWeight = 1.25,

		LayCooldownMin = 35,
		LayCooldownMax = 85,

		LayingTimeMin = 7,
		LayingTimeMax = 15,

		MaxActiveEggsPerChicken = 4,

		CarryPromptDistance = 7,
		CarryPromptHold = 0.25,

		CarryOffset = Vector3.new(-0.5, -0.25, -1.05),
		CarryRotation = Vector3.new(0, -20, 0),
		CarryTurnResponsiveness = 20,

		SafeInCoopMin = 18,
		SafeInCoopMax = 35,
	},

	Cuy = {
		Count = 2,

		TemplateNames = {
			"CuyTemplate",
			"Cuy",
		},

		UpdateRate = 1 / 30,

		RoamSpeedMin = 0.8,
		RoamSpeedMax = 1.7,

		RunSpeedMin = 5.0,
		RunSpeedMax = 7.2,

		AvoidDistanceMin = 7,
		AvoidDistanceMax = 12,
		CalmDistanceBonus = 3,

		IdleMin = 4,
		IdleMax = 11,

		LookMin = 1.5,
		LookMax = 4,

		NibbleMin = 3,
		NibbleMax = 8,

		RoamDurationMin = 1.0,
		RoamDurationMax = 2.2,
		RoamStepMin = 2,
		RoamStepMax = 6,

		HiddenMin = 10,
		HiddenMax = 22,

		PeekOutMin = 2,
		PeekOutMax = 5,

		TurnResponsiveness = 7,
		RunTurnResponsiveness = 12,
		PositionResponsiveness = 18,
		MaxWalkStep = 0.18,
		MaxRunStep = 0.35,

		GroundRayHeight = 12,
		GroundRayLength = 50,
		GroundClearance = 0.02,
		ModelYOffset = 0,

		ObstacleCheckDistance = 2.5,
		ObstacleSphereRadius = 0.45,
	},
}

HomeCfg.ChickenEscape = {
	Enabled = true,

	StuckBeforePathTime = 1.2,
	EscapePathCooldown = 2.5,
	EscapePathTimeout = 6,

	MaxPathRequestsPerSecond = 3,

	EscapeTargetDistance = 18,
	EscapeTargetAttempts = 8,

	IgnorePlayerAsObstacle = true,

	StepHopEnabled = true,
	StepHopMaxHeight = 2.5,
	StepHopDistance = 3,
	StepHopDuration = 0.38,

	ForcedExitHopEnabled = true,
	ForcedExitHopStuckTime = 0.6,
	ForcedExitHopDistance = 5.0,
	ForcedExitHopDuration = 0.45,
	ForcedExitHopArcHeight = 1.6,
	ForcedExitHopCooldown = 1.5,
	ForcedExitHopMinDoorDistance = 2.0,
	ForcedExitHopMaxDoorDistance = 9.0,
}

HomeCfg.ChickenNest = {
	JumpLinksEnabled = true,
	NestJumpReachDistance = 1.1,
	NestJumpDuration = 0.5,
	NestJumpArcHeight = 2.0,
	NestJumpMaxHeightDelta = 6.0,
	NestJumpDownDuration = 0.42,
	StayOnNestAfterLayMin = 4,
	StayOnNestAfterLayMax = 10,
}

HomeCfg.Eggs = {
	TemplateNames = {
		"EggTemplate",
		"HuevoTemplate",
		"Huevo",
	},

	CollectDistance = 8,
	PromptActionText = "Recoger",
	PromptObjectText = "Huevo",
}

HomeCfg.Slingshot = {
	AmmoItem = "Egg",
	Cooldown = 0.45,
	MaxRange = 180,
	MaxChargeTime = 0.8,
	MinChargeToFire = 0.05,
}

HomeCfg.Debug = {
	PrintStartup = true,
	PrintAnimalSpawn = false,
	PrintEggs = false,
	PrintCarry = false,
	SetAnimalAttributes = true,
	ChickenNest = false,
	Inventory = true,
	Storage = true,
	Slingshot = true,
}

return HomeCfg
