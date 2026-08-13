local Workspace = game:GetService("Workspace")

local SlingshotFoxAimAssist = {}

local DEFAULTS = {
	Enabled = true,
	MaxWorldDistance = 145,
	MaxAngleDegrees = 6.0,
	BaseAssistRadius = 2.6,
	RadiusPerStud = 0.018,
	MaxAssistRadius = 5.5,
	AimHeightOffset = 0.35,
}

local function mergeConfig(config)
	local result = {}
	for key, value in pairs(DEFAULTS) do
		result[key] = value
	end
	for key, value in pairs(config or {}) do
		result[key] = value
	end
	return result
end

local function isEligibleFox(model)
	if not model or not model:IsA("Model") or not model.Parent then
		return false
	end
	if model:GetAttribute("PredatorType") ~= "Fox" then
		return false
	end
	local state = model:GetAttribute("PredatorState")
	return state ~= "Repelled" and state ~= "Completed"
end

local function getFoxRoot(model)
	if not isEligibleFox(model) then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function getAimPoints(model, root, heightOffset)
	local points = {}
	if root then
		table.insert(points, root.Position + Vector3.new(0, heightOffset, 0))
	end

	local ok, boxCFrame, boxSize = pcall(function()
		local cf, size = model:GetBoundingBox()
		return cf, size
	end)
	if ok and boxCFrame and boxSize then
		local center = boxCFrame.Position
		table.insert(points, center)
		table.insert(points, center + Vector3.new(0, math.min(boxSize.Y * 0.16, 0.75), 0))
	end

	return points
end

local function raycastSeesFox(origin, aimPoint, playerCharacter, foxModel)
	local delta = aimPoint - origin
	if delta.Magnitude <= 0.001 then
		return false
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	params.FilterDescendantsInstances = playerCharacter and { playerCharacter } or {}

	local result = Workspace:Raycast(origin, delta, params)
	if not result or not result.Instance then
		return false
	end

	return result.Instance:FindFirstAncestorOfClass("Model") == foxModel
end

local function angleDegrees(a, b)
	local dot = math.clamp(a:Dot(b), -1, 1)
	return math.deg(math.acos(dot))
end

local function perpendicularMissDistance(origin, shotDirection, point)
	local toPoint = point - origin
	local projection = math.max(toPoint:Dot(shotDirection), 0)
	local closest = origin + shotDirection * projection
	return (point - closest).Magnitude
end

function SlingshotFoxAimAssist.Resolve(player, safeOrigin, requestedDirection, maxRange, requestedAssist, config)
	config = mergeConfig(config)

	if config.Enabled ~= true or requestedAssist ~= true then
		return requestedDirection, nil, nil
	end
	if typeof(safeOrigin) ~= "Vector3" or typeof(requestedDirection) ~= "Vector3" or requestedDirection.Magnitude <= 0.001 then
		return requestedDirection, nil, nil
	end

	local runtime = Workspace:FindFirstChild("PredatorRuntime")
	if not runtime then
		return requestedDirection, nil, nil
	end

	local direction = requestedDirection.Unit
	local character = player and player.Character or nil
	local best = nil

	for _, candidate in ipairs(runtime:GetChildren()) do
		local root = getFoxRoot(candidate)
		if root then
			local worldDistance = (root.Position - safeOrigin).Magnitude
			if worldDistance <= math.min(config.MaxWorldDistance, maxRange or config.MaxWorldDistance) then
				local allowedRadius = math.clamp(
					config.BaseAssistRadius + worldDistance * config.RadiusPerStud,
					config.BaseAssistRadius,
					config.MaxAssistRadius
				)

				for _, aimPoint in ipairs(getAimPoints(candidate, root, config.AimHeightOffset)) do
					local toPoint = aimPoint - safeOrigin
					if toPoint.Magnitude > 0.001 then
						local candidateDirection = toPoint.Unit
						local angle = angleDegrees(direction, candidateDirection)
						local missDistance = perpendicularMissDistance(safeOrigin, direction, aimPoint)

						if angle <= config.MaxAngleDegrees
							and missDistance <= allowedRadius
							and raycastSeesFox(safeOrigin, aimPoint, character, candidate)
						then
							local score = angle * 1.25 + missDistance * 0.85 + worldDistance * 0.002
							if not best or score < best.Score then
								best = {
									Model = candidate,
									AimPoint = aimPoint,
									Direction = candidateDirection,
									Angle = angle,
									MissDistance = missDistance,
									AllowedRadius = allowedRadius,
									Score = score,
								}
							end
						end
					end
				end
			end
		end
	end

	if not best then
		return direction, nil, nil
	end

	return best.Direction, best.Model, {
		AimPoint = best.AimPoint,
		Angle = best.Angle,
		MissDistance = best.MissDistance,
		AllowedRadius = best.AllowedRadius,
	}
end

return SlingshotFoxAimAssist
