local Rand = {}

function Rand.pickWeighted(list, rng)
	local totalWeight = 0

	for _, item in ipairs(list) do
		totalWeight += item.Weight
	end

	if totalWeight <= 0 then
		return nil
	end

	local roll = rng:NextNumber(0, totalWeight)
	local current = 0

	for _, item in ipairs(list) do
		current += item.Weight

		if roll <= current then
			return item
		end
	end

	return list[#list]
end

return Rand
