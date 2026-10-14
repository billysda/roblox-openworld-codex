local Impact = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local SAMPLE_INTERVAL = 1 / 25
local DOWN_RAY_DISTANCE = 38
local MIN_IMPACT_APPROACH = 10
local MIN_GROUND_IMPACT_APPROACH = 28
local SOFT_GROUND_APPROACH = 8
local FORWARD_RAY_DISTANCE = 42
local VELOCITY_LOOKAHEAD_TIME = 0.28
local NOSE_PROBE_OFFSET = Vector3.new(0, 3.5, -18)
local CHEST_PROBE_OFFSET = Vector3.new(0, 1.5, -8)
local NOSE_PROBE_LENGTH = 8
local LANDING_CONTACT_DISTANCE = 5

local FLIGHT_STATES = {
	Takeoff = true,
	Fly = true,
	Glide = true,
	Dive = true,
	Landing = true,
}

local stateByDragon = setmetatable({}, { __mode = "k" })
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true

local function getState(dragon)
	local state = stateByDragon[dragon]
	if not state then
		state = {
			accumulated = 0,
			exclude = {},
		}
		stateByDragon[dragon] = state
	end
	return state
end

local function refreshExclude(dragon, state)
	table.clear(state.exclude)
	table.insert(state.exclude, dragon)

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(state.exclude, player.Character)
		end
	end

	params.FilterDescendantsInstances = state.exclude
	return params
end

local function classifyKind(normalY)
	if normalY < -0.25 then
		return "Ceiling"
	end
	if normalY >= 0.45 then
		return "Ground"
	end
	return "Wall"
end

local function classifySeverity(kind, state, speed, approachSpeed)
	if approachSpeed >= 65 or speed >= 95 or state == "Dive" then
		return "Hard"
	end
	if approachSpeed >= 28 or speed >= 55 then
		return "Medium"
	end
	return "Soft"
end

local function classifyLandingSeverity(state, speed, approachSpeed, normalY)
	if approachSpeed >= 65 or speed >= 95 or state == "Dive" then
		return "Hard"
	end
	if speed >= 55 or approachSpeed >= 32 then
		return "Medium"
	end
	if speed < 55 and approachSpeed < 32 and normalY >= 0.55 then
		return "Soft"
	end
	return "Medium"
end

local function buildImpact(hit, distance, velocity, state)
	local speed = velocity.Magnitude
	local approachSpeed = -velocity:Dot(hit.Normal)
	local normalY = hit.Normal.Y
	local kind = classifyKind(normalY)

	if kind == "Ground" and approachSpeed < MIN_GROUND_IMPACT_APPROACH then
		return nil
	end

	if approachSpeed < MIN_IMPACT_APPROACH then
		if kind ~= "Ground" or approachSpeed < SOFT_GROUND_APPROACH then
			return nil
		end
	end

	return {
		kind = kind,
		severity = classifySeverity(kind, state, speed, approachSpeed),
		hit = hit,
		distance = distance,
		speed = speed,
		approachSpeed = approachSpeed,
		normalY = normalY,
	}
end

local function buildLandingContact(hit, origin, source, velocity, state)
	local normalY = hit.Normal.Y
	if normalY < 0.45 then
		return nil
	end

	local speed = velocity.Magnitude
	local approachSpeed = -velocity:Dot(hit.Normal)
	local distance = (origin - hit.Position).Magnitude
	if distance > LANDING_CONTACT_DISTANCE then
		return nil
	end

	return {
		kind = "LandingContact",
		severity = classifyLandingSeverity(state, speed, approachSpeed, normalY),
		hit = hit,
		distance = distance,
		speed = speed,
		approachSpeed = approachSpeed,
		normalY = normalY,
		source = source,
	}
end

local function chooseImpact(current, candidate)
	if not candidate then
		return current
	end
	if not current then
		return candidate
	end
	if candidate.severity == "Hard" and current.severity ~= "Hard" then
		return candidate
	end
	if candidate.distance < current.distance then
		return candidate
	end
	return current
end

function Impact.sample(dragon, root, velocity, state, dt)
	if not FLIGHT_STATES[state] then
		return nil
	end
	if not dragon or not root or not root:IsA("BasePart") then
		return nil
	end
	if typeof(velocity) ~= "Vector3" then
		return nil
	end

	local sampleState = getState(dragon)
	sampleState.accumulated += dt
	if sampleState.accumulated < SAMPLE_INTERVAL then
		return nil
	end
	sampleState.accumulated = 0

	local raycastParams = refreshExclude(dragon, sampleState)
	local origin = root.Position
	local speed = velocity.Magnitude
	local groundHit = Workspace:Raycast(origin, Vector3.new(0, -DOWN_RAY_DISTANCE, 0), raycastParams)
	local groundDistance = groundHit and (origin - groundHit.Position).Magnitude or nil
	local impact = nil
	local rootCf = root.CFrame
	local velocityDir = speed > 1 and velocity.Unit or rootCf.LookVector
	local noseOrigin = rootCf:PointToWorldSpace(NOSE_PROBE_OFFSET)
	local chestOrigin = rootCf:PointToWorldSpace(CHEST_PROBE_OFFSET)
	local noseDirection = velocityDir * NOSE_PROBE_LENGTH
	local noseHit = Workspace:Raycast(noseOrigin, noseDirection, raycastParams)
	if noseHit then
		impact = chooseImpact(impact, buildLandingContact(noseHit, noseOrigin, "Nose", velocity, state))
	end

	local chestHit = Workspace:Raycast(chestOrigin, noseDirection, raycastParams)
	if chestHit then
		impact = chooseImpact(impact, buildLandingContact(chestHit, chestOrigin, "Chest", velocity, state))
	end

	if state == "Landing" and impact and impact.kind == "LandingContact" then
		impact.groundHit = groundHit
		impact.groundDistance = groundDistance
		return impact
	end

	if speed > 6 then
		local direction = velocity.Unit
		local distance = math.clamp(speed * VELOCITY_LOOKAHEAD_TIME + 6, 12, 72)
		local hit = Workspace:Raycast(origin, direction * distance, raycastParams)
		if hit then
			impact = chooseImpact(impact, buildImpact(hit, (origin - hit.Position).Magnitude, velocity, state))
		end
	end

	if speed < 18 or not impact then
		local look = root.CFrame.LookVector
		if look.Magnitude > 0.01 then
			local hit = Workspace:Raycast(origin, look.Unit * FORWARD_RAY_DISTANCE, raycastParams)
			if hit then
				impact = chooseImpact(impact, buildImpact(hit, (origin - hit.Position).Magnitude, velocity, state))
			end
		end
	end

	if impact then
		impact.groundHit = groundHit
		impact.groundDistance = groundDistance
	end

	return impact
end

return Impact
