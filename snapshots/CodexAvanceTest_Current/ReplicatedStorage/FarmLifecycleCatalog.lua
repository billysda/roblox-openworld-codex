local FarmLifecycleCatalog = {}

FarmLifecycleCatalog.TestFastMode = true
FarmLifecycleCatalog.TickInterval = 1.0
FarmLifecycleCatalog.RecoveryCooldown = 60
FarmLifecycleCatalog.RationItemId = "DragonMeatRation"

FarmLifecycleCatalog.SpeciesOrder = {
	"Sheep",
	"Chicken",
	"Cuy",
}

FarmLifecycleCatalog.Species = {
	Sheep = {
		DisplayName = "Oveja",
		PluralName = "Ovejas",
		Capacity = 4,
		ReserveAdults = 2,
		RationYield = 8,
		JuvenileScale = 0.62,
		TestBirthInterval = 22,
		TestJuvenileDuration = 18,
		ProductionBirthInterval = 12 * 60,
		ProductionJuvenileDuration = 18 * 60,
	},

	Chicken = {
		DisplayName = "Gallina",
		PluralName = "Gallinas",
		Capacity = 4,
		ReserveAdults = 2,
		RationYield = 4,
		JuvenileScale = 0.68,
		TestBirthInterval = 18,
		TestJuvenileDuration = 14,
		ProductionBirthInterval = 8 * 60,
		ProductionJuvenileDuration = 12 * 60,
	},

	Cuy = {
		DisplayName = "Cuy",
		PluralName = "Cuyes",
		Capacity = 4,
		ReserveAdults = 2,
		RationYield = 2,
		JuvenileScale = 0.65,
		TestBirthInterval = 14,
		TestJuvenileDuration = 10,
		ProductionBirthInterval = 6 * 60,
		ProductionJuvenileDuration = 9 * 60,
	},
}

function FarmLifecycleCatalog.Get(speciesId)
	return FarmLifecycleCatalog.Species[speciesId]
end

function FarmLifecycleCatalog.GetBirthInterval(speciesId)
	local cfg = FarmLifecycleCatalog.Get(speciesId)
	if not cfg then
		return nil
	end
	if FarmLifecycleCatalog.TestFastMode then
		return cfg.TestBirthInterval
	end
	return cfg.ProductionBirthInterval
end

function FarmLifecycleCatalog.GetJuvenileDuration(speciesId)
	local cfg = FarmLifecycleCatalog.Get(speciesId)
	if not cfg then
		return nil
	end
	if FarmLifecycleCatalog.TestFastMode then
		return cfg.TestJuvenileDuration
	end
	return cfg.ProductionJuvenileDuration
end

return FarmLifecycleCatalog
