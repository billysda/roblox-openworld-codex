local Catalog = {}

Catalog.Order = {
	"Mandrake",
	"EmberBloom",
	"MoonDewLotus",
}

Catalog.Resources = {
	Mandrake = {
		Id = "Mandrake",
		DisplayName = "Mandrágora Ancestral",
		Category = "MythicPlant",
		Rarity = "Poco común",
		ModelName = "Mandrake",
		RespawnSeconds = 15,
		PromptHoldDuration = 0.55,
		PromptDistance = 9,
		Affinity = {
			Nature = 1.50,
			Earth = 1.25,
		},
		RecommendedElements = { "Naturaleza", "Tierra" },
		Uses = { "Alimento de crecimiento", "Vitalidad" },
		Description = "Una raíz antigua cargada de energía vital. Los dragones ligados a la naturaleza y la tierra responden especialmente bien a su esencia.",
		RegionHint = "Bosques húmedos, raíces antiguas y zonas de tierra fértil.",
	},
	EmberBloom = {
		Id = "EmberBloom",
		DisplayName = "Flor de Brasa",
		Category = "MythicPlant",
		Rarity = "Poco común",
		ModelName = "EmberBloom",
		RespawnSeconds = 15,
		PromptHoldDuration = 0.45,
		PromptDistance = 9,
		Affinity = {
			Fire = 1.50,
		},
		RecommendedElements = { "Fuego" },
		Uses = { "Alimento elemental", "Dominio ofensivo" },
		Description = "Una flor que conserva calor en su núcleo incluso lejos del fuego. Su esencia favorece a dragones de afinidad ígnea.",
		RegionHint = "Roca caliente, ruinas quemadas y regiones volcánicas.",
	},
	MoonDewLotus = {
		Id = "MoonDewLotus",
		DisplayName = "Loto de Rocío Lunar",
		Category = "MythicPlant",
		Rarity = "Poco común",
		ModelName = "MoonDewLotus",
		RespawnSeconds = 15,
		PromptHoldDuration = 0.50,
		PromptDistance = 9,
		Affinity = {
			Water = 1.40,
			Ice = 1.40,
		},
		RecommendedElements = { "Agua", "Hielo" },
		Uses = { "Recuperación", "Resistencia" },
		Description = "Un loto frío y húmedo que concentra energía lunar. Su savia se asocia con recuperación, calma y resistencia elemental.",
		RegionHint = "Humedales, lagunas tranquilas y cavernas húmedas.",
	},
}

function Catalog.Get(resourceId)
	return Catalog.Resources[resourceId]
end

function Catalog.IsValid(resourceId)
	return Catalog.Resources[resourceId] ~= nil
end

return Catalog
