local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local FarmLifecycleService = {}
FarmLifecycleService.__index = FarmLifecycleService

local function nowSeconds()
	return Workspace:GetServerTimeNow()
end

local function clampCount(value)
	return math.max(0, math.floor(tonumber(value) or 0))
end

function FarmLifecycleService.new(catalog, registry, stateChangedRemote)
	local self = setmetatable({}, FarmLifecycleService)
	self.Catalog = catalog
	self.Registry = registry
	self.StateChangedRemote = stateChangedRemote
	self.PlayerState = {}
	return self
end

function FarmLifecycleService:_getPlayerState(player)
	local userId = player.UserId
	local state = self.PlayerState[userId]
	if not state then
		state = {
			Rations = 0,
			Species = {},
			RecoveryCooldownUntil = {},
		}
		self.PlayerState[userId] = state
	end
	return state
end

function FarmLifecycleService:_getSpeciesState(player, speciesId)
	local playerState = self:_getPlayerState(player)
	local state = playerState.Species[speciesId]
	if not state then
		state = { NextBirthAt = nil }
		playerState.Species[speciesId] = state
	end
	return state
end

function FarmLifecycleService:_fire(player, payload)
	if self.StateChangedRemote then
		self.StateChangedRemote:FireClient(player, payload)
	end
end

function FarmLifecycleService:GetRations(player)
	return self:_getPlayerState(player).Rations
end

function FarmLifecycleService:GetSpeciesSnapshot(player, speciesId)
	local cfg = self.Catalog.Get(speciesId)
	local adapter = self.Registry.Get(speciesId)
	if not cfg or not adapter or not adapter.GetPopulation then
		return {
			SpeciesId = speciesId,
			Available = false,
			Adults = 0,
			Juveniles = 0,
			Total = 0,
			Capacity = cfg and cfg.Capacity or 0,
			ReserveAdults = cfg and cfg.ReserveAdults or 0,
			RationYield = cfg and cfg.RationYield or 0,
			CanProcess = false,
			CanRecover = false,
			NextBirthAt = nil,
		}
	end

	local population = adapter.GetPopulation(player)
	if not population then
		return {
			SpeciesId = speciesId,
			Available = false,
			Adults = 0,
			Juveniles = 0,
			Total = 0,
			Capacity = cfg.Capacity,
			ReserveAdults = cfg.ReserveAdults,
			RationYield = cfg.RationYield,
			CanProcess = false,
			CanRecover = false,
			NextBirthAt = nil,
		}
	end

	local adults = clampCount(population.Adults)
	local juveniles = clampCount(population.Juveniles)
	local total = clampCount(population.Total or (adults + juveniles))
	local speciesState = self:_getSpeciesState(player, speciesId)
	local playerState = self:_getPlayerState(player)
	local cooldownUntil = playerState.RecoveryCooldownUntil[speciesId] or 0

	return {
		SpeciesId = speciesId,
		DisplayName = cfg.DisplayName,
		PluralName = cfg.PluralName,
		Available = true,
		Adults = adults,
		Juveniles = juveniles,
		Total = total,
		Capacity = cfg.Capacity,
		ReserveAdults = cfg.ReserveAdults,
		RationYield = cfg.RationYield,
		CanProcess = adults > cfg.ReserveAdults,
		CanRecover = total == 0 and nowSeconds() >= cooldownUntil,
		RecoveryCooldownUntil = cooldownUntil,
		NextBirthAt = speciesState.NextBirthAt,
	}
end

function FarmLifecycleService:GetSnapshot(player)
	local result = {
		Rations = self:GetRations(player),
		TestFastMode = self.Catalog.TestFastMode == true,
		Species = {},
	}

	for _, speciesId in ipairs(self.Catalog.SpeciesOrder) do
		result.Species[speciesId] = self:GetSpeciesSnapshot(player, speciesId)
	end

	return result
end

function FarmLifecycleService:ProcessOne(player, speciesId)
	local cfg = self.Catalog.Get(speciesId)
	local adapter = self.Registry.Get(speciesId)
	if not cfg or not adapter or not adapter.ProcessAdult then
		return false, "Unavailable"
	end

	local snapshot = self:GetSpeciesSnapshot(player, speciesId)
	if not snapshot.Available then
		return false, "NoHome"
	end
	if snapshot.Adults <= cfg.ReserveAdults then
		return false, "BreederReserve"
	end

	local ok = adapter.ProcessAdult(player)
	if not ok then
		return false, "ProcessFailed"
	end

	local playerState = self:_getPlayerState(player)
	playerState.Rations += cfg.RationYield

	self:_fire(player, {
		Type = "Processed",
		SpeciesId = speciesId,
		RationsAdded = cfg.RationYield,
		Rations = playerState.Rations,
		Snapshot = self:GetSnapshot(player),
	})
	return true, "Ok"
end

function FarmLifecycleService:RequestRecoveryPair(player, speciesId)
	local cfg = self.Catalog.Get(speciesId)
	local adapter = self.Registry.Get(speciesId)
	if not cfg or not adapter or not adapter.SpawnAdult then
		return false, "Unavailable"
	end

	local snapshot = self:GetSpeciesSnapshot(player, speciesId)
	if not snapshot.Available then
		return false, "NoHome"
	end
	if snapshot.Total ~= 0 then
		return false, "PopulationExists"
	end

	local state = self:_getPlayerState(player)
	local now = nowSeconds()
	local cooldownUntil = state.RecoveryCooldownUntil[speciesId] or 0
	if now < cooldownUntil then
		return false, "Cooldown"
	end

	local spawned = 0
	for _ = 1, math.min(2, cfg.Capacity) do
		if adapter.SpawnAdult(player) then
			spawned += 1
		end
	end
	if spawned == 0 then
		return false, "SpawnFailed"
	end

	state.RecoveryCooldownUntil[speciesId] = now + (self.Catalog.RecoveryCooldown or 60)
	self:_fire(player, {
		Type = "RecoveryPair",
		SpeciesId = speciesId,
		Spawned = spawned,
		Snapshot = self:GetSnapshot(player),
	})
	return true, "Ok"
end

function FarmLifecycleService:_stepSpecies(player, speciesId, now)
	local cfg = self.Catalog.Get(speciesId)
	local adapter = self.Registry.Get(speciesId)
	if not cfg or not adapter then
		return
	end

	if adapter.PromoteReady then
		local promoted = adapter.PromoteReady(player, now) or 0
		if promoted > 0 then
			self:_fire(player, {
				Type = "GrewUp",
				SpeciesId = speciesId,
				Count = promoted,
				Snapshot = self:GetSnapshot(player),
			})
		end
	end

	if not adapter.GetPopulation or not adapter.SpawnJuvenile then
		return
	end

	local population = adapter.GetPopulation(player)
	if not population then
		self:_getSpeciesState(player, speciesId).NextBirthAt = nil
		return
	end

	local adults = clampCount(population.Adults)
	local juveniles = clampCount(population.Juveniles)
	local total = clampCount(population.Total or (adults + juveniles))
	local speciesState = self:_getSpeciesState(player, speciesId)

	if adults < 2 or total >= cfg.Capacity then
		speciesState.NextBirthAt = nil
		return
	end

	local interval = self.Catalog.GetBirthInterval(speciesId)
	if not speciesState.NextBirthAt then
		speciesState.NextBirthAt = now + interval
		return
	end

	if now < speciesState.NextBirthAt then
		return
	end

	local adultAt = now + self.Catalog.GetJuvenileDuration(speciesId)
	local ok = adapter.SpawnJuvenile(player, adultAt)
	if ok then
		speciesState.NextBirthAt = now + interval
		self:_fire(player, {
			Type = "Birth",
			SpeciesId = speciesId,
			AdultAt = adultAt,
			Snapshot = self:GetSnapshot(player),
		})
	else
		speciesState.NextBirthAt = now + math.min(interval, 5)
	end
end

function FarmLifecycleService:Step()
	local now = nowSeconds()
	for _, player in ipairs(Players:GetPlayers()) do
		for _, speciesId in ipairs(self.Catalog.SpeciesOrder) do
			self:_stepSpecies(player, speciesId, now)
		end
	end
end

function FarmLifecycleService:ClearPlayer(player)
	self.PlayerState[player.UserId] = nil
end

return FarmLifecycleService
