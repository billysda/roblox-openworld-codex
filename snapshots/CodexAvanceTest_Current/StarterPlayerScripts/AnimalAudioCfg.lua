local Cfg = {}

Cfg.Enabled = true
Cfg.Debug = false

Cfg.RuntimeFolders = {
	"SheepRuntime",
	"HomeRuntime",
}

Cfg.MaxAudibleDistance = 65
Cfg.MaxConcurrentSounds = 10
Cfg.ScanInterval = 0.5
Cfg.GroundRayLength = 8

Cfg.Footsteps = {
	Enabled = true,
	MinimumHorizontalSpeed = 1.35,
	WalkInterval = 0.48,
	TrotInterval = 0.34,
	RunInterval = 0.23,
	TrotSpeed = 5.5,
	RunSpeed = 12.5,
	Volume = 0.28,
	RollOffMinDistance = 5,
	RollOffMaxDistance = 45,
	PlaybackSpeedMin = 0.94,
	PlaybackSpeedMax = 1.07,
}

Cfg.Voices = {
	Enabled = true,
	Volume = 0.55,
	RollOffMinDistance = 7,
	RollOffMaxDistance = 58,
	PlaybackSpeedMin = 0.94,
	PlaybackSpeedMax = 1.06,
}

-- Añade IDs publicados por tu experiencia. Deja una lista vacía para desactivar
-- temporalmente una categoría sin cambiar el código.
Cfg.Profiles = {
	Sheep = {
		NameHints = { "sheep", "oveja", "lamb" },
		Voice = {
			Idle = {},
			Alert = {},
			MinDelay = 14,
			MaxDelay = 34,
			Chance = 0.42,
		},
		Footsteps = {
			Grass = {},
			Dirt = {},
			Sand = {},
			Stone = {},
			Wood = {},
			Snow = {},
			Default = {},
		},
	},

	Chicken = {
		NameHints = { "chicken", "gallina", "rooster" },
		Voice = {
			Idle = {},
			Alert = {},
			MinDelay = 10,
			MaxDelay = 26,
			Chance = 0.36,
		},
		Footsteps = {
			Grass = {},
			Dirt = {},
			Stone = {},
			Wood = {},
			Default = {},
		},
	},

	Cuy = {
		NameHints = { "cuy", "guinea" },
		Voice = {
			Idle = {},
			Alert = {},
			MinDelay = 16,
			MaxDelay = 38,
			Chance = 0.28,
		},
		Footsteps = {
			Grass = {},
			Dirt = {},
			Stone = {},
			Wood = {},
			Default = {},
		},
	},
}

Cfg.MaterialGroups = {
	[Enum.Material.Grass] = "Grass",
	[Enum.Material.LeafyGrass] = "Grass",
	[Enum.Material.Ground] = "Dirt",
	[Enum.Material.Mud] = "Dirt",
	[Enum.Material.Salt] = "Dirt",
	[Enum.Material.Sand] = "Sand",
	[Enum.Material.Sandstone] = "Sand",
	[Enum.Material.Rock] = "Stone",
	[Enum.Material.Slate] = "Stone",
	[Enum.Material.Concrete] = "Stone",
	[Enum.Material.Cobblestone] = "Stone",
	[Enum.Material.Brick] = "Stone",
	[Enum.Material.Marble] = "Stone",
	[Enum.Material.Granite] = "Stone",
	[Enum.Material.Wood] = "Wood",
	[Enum.Material.WoodPlanks] = "Wood",
	[Enum.Material.Snow] = "Snow",
	[Enum.Material.Glacier] = "Snow",
	[Enum.Material.Ice] = "Snow",
}

return Cfg
