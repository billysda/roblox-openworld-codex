local PredatorCfg = {}

PredatorCfg.Enabled = true
PredatorCfg.RuntimeFolder = "PredatorRuntime"
PredatorCfg.TemplateFolder = { "Assets", "Predators" }
PredatorCfg.FoxTemplateName = "FoxTemplate"

PredatorCfg.Update = {
	Physics = 1 / 30,
	AI = 0.1,
	MaxPhysicsCatchUp = 2,
}

PredatorCfg.Spawn = {
	Enabled = true,
	InitialDelay = 5,
	RespawnCooldown = 30,
	MaxActive = 1,
	DistanceMin = 36,
	DistanceMax = 52,
	Attempts = 12,
	GroundRayHeight = 45,
	GroundRayDepth = 100,
}

PredatorCfg.Fox = {
	DetectionRadius = 70,
	ChaseSpeed = 16,
	PounceSpeed = 12,
	FleeSpeed = 17,

	AttackStartDistance = 5.8,
	AttackHitRadius = 4.2,
	AttackHitTime = 0.45,
	AttackDuration = 0.75,
	AttackCooldown = 1.15,

	CarryDuration = 6,
	FleeDistance = 55,

	GroundTargetHeight = 2.0,
	GroundRayLength = 12,
	HoverSpring = 1300,
	HoverDamping = 210,
	HoverMaxCorrectionRatio = 0.8,
	TurnResponsiveness = 16,
	MoveForce = 80000,
	TurnTorque = 120000,

	SearchTimeout = 10,
	SafePenFallbackRadius = 12,

	DebugAttributes = true,
	DebugPrints = true,
}

return PredatorCfg
