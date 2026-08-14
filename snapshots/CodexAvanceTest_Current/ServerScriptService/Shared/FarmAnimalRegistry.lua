local FarmAnimalRegistry = {}

local adapters = {}

function FarmAnimalRegistry.Register(speciesId, adapter)
	assert(typeof(speciesId) == "string" and speciesId ~= "", "speciesId invalido")
	assert(typeof(adapter) == "table", "adapter invalido")
	adapters[speciesId] = adapter
end

function FarmAnimalRegistry.Unregister(speciesId, adapter)
	if adapters[speciesId] == adapter or adapter == nil then
		adapters[speciesId] = nil
	end
end

function FarmAnimalRegistry.Get(speciesId)
	return adapters[speciesId]
end

function FarmAnimalRegistry.GetRegisteredSpecies()
	local result = {}
	for speciesId in pairs(adapters) do
		table.insert(result, speciesId)
	end
	table.sort(result)
	return result
end

return FarmAnimalRegistry
