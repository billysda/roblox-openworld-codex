local SlingshotAnimeTrajectory = {}

local RNG = Random.new()

local DEFAULTS = {
	UpFraction = 0.22,
	SideFraction = 0.10,
	MinUp = 5,
	MaxUp = 28,
	MinSide = 2,
	MaxSide = 14,
	P1ForwardFraction = 0.26,
	P2ForwardFraction = 0.72,
	BeamSegments = 32,
	VisualSpeed = 220,
	VisualMinDuration = 0.24,
	VisualMaxDuration = 0.50,
}

local STYLE_PRESETS = {
	-- Arco clásico hacia la derecha.
	{ Up1 = 1.08, Up2 = 0.76, Side1 = 1.05, Side2 = 0.72, P1 = 0.24, P2 = 0.73 },
	-- Arco clásico hacia la izquierda.
	{ Up1 = 1.10, Up2 = 0.78, Side1 = -1.10, Side2 = -0.70, P1 = 0.25, P2 = 0.72 },
	-- S suave: sale a la derecha y vuelve por la izquierda.
	{ Up1 = 0.92, Up2 = 0.68, Side1 = 1.35, Side2 = -0.48, P1 = 0.22, P2 = 0.70 },
	-- S inversa.
	{ Up1 = 0.95, Up2 = 0.70, Side1 = -1.30, Side2 = 0.52, P1 = 0.23, P2 = 0.71 },
	-- Arco alto casi centrado con pequeña desviación.
	{ Up1 = 1.30, Up2 = 0.98, Side1 = 0.42, Side2 = 0.18, P1 = 0.27, P2 = 0.75 },
	-- Arco bajo y ancho para variar la silueta.
	{ Up1 = 0.72, Up2 = 0.48, Side1 = 1.42, Side2 = 0.88, P1 = 0.20, P2 = 0.69 },
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

local function safeUnit(vector, fallback)
	if typeof(vector) == "Vector3" and vector.Magnitude > 0.001 then
		return vector.Unit
	end
	return fallback or Vector3.zAxis
end

local function perpendicularSide(direction, cameraRight)
	local right = cameraRight or Vector3.xAxis
	local projected = right - direction * right:Dot(direction)
	if projected.Magnitude <= 0.001 then
		projected = Vector3.yAxis:Cross(direction)
	end
	if projected.Magnitude <= 0.001 then
		projected = Vector3.xAxis
	end
	return projected.Unit
end

local function worldFrameWithRight(position, desiredRight)
	local right = safeUnit(desiredRight, Vector3.xAxis)
	local referenceUp = math.abs(right:Dot(Vector3.yAxis)) > 0.96 and Vector3.zAxis or Vector3.yAxis
	local back = right:Cross(referenceUp)
	if back.Magnitude <= 0.001 then
		back = Vector3.zAxis
	else
		back = back.Unit
	end
	local up = back:Cross(right).Unit
	return CFrame.fromMatrix(position, right, up, back)
end

local function setAttachmentWorldFrame(attachment, worldFrame)
	if not attachment or not attachment.Parent then
		return
	end
	local parent = attachment.Parent
	if parent:IsA("BasePart") then
		attachment.CFrame = parent.CFrame:ToObjectSpace(worldFrame)
	else
		attachment.CFrame = worldFrame
	end
end

local function jitter(value, amount)
	return value * RNG:NextNumber(1 - amount, 1 + amount)
end

function SlingshotAnimeTrajectory.CreateRandomStyle()
	local preset = STYLE_PRESETS[RNG:NextInteger(1, #STYLE_PRESETS)]
	return {
		Up1 = jitter(preset.Up1, 0.10),
		Up2 = jitter(preset.Up2, 0.10),
		Side1 = jitter(preset.Side1, 0.12),
		Side2 = jitter(preset.Side2, 0.12),
		P1 = math.clamp(preset.P1 + RNG:NextNumber(-0.025, 0.025), 0.16, 0.34),
		P2 = math.clamp(preset.P2 + RNG:NextNumber(-0.025, 0.025), 0.62, 0.82),
	}
end

function SlingshotAnimeTrajectory.CopyStyle(style)
	if typeof(style) ~= "table" then
		return SlingshotAnimeTrajectory.CreateRandomStyle()
	end
	return {
		Up1 = tonumber(style.Up1) or 1,
		Up2 = tonumber(style.Up2) or 0.72,
		Side1 = tonumber(style.Side1) or 1,
		Side2 = tonumber(style.Side2) or 0.72,
		P1 = tonumber(style.P1) or DEFAULTS.P1ForwardFraction,
		P2 = tonumber(style.P2) or DEFAULTS.P2ForwardFraction,
	}
end

function SlingshotAnimeTrajectory.GetVisualTravelDuration(origin, target, config)
	config = mergeConfig(config)
	local distance = (target - origin).Magnitude
	return math.clamp(
		distance / config.VisualSpeed,
		config.VisualMinDuration,
		config.VisualMaxDuration
	)
end

function SlingshotAnimeTrajectory.GetCurve(origin, target, cameraCFrame, config, style)
	config = mergeConfig(config)
	style = SlingshotAnimeTrajectory.CopyStyle(style)

	local delta = target - origin
	local distance = delta.Magnitude
	if distance <= 0.001 then
		return {
			P0 = origin,
			P1 = origin,
			P2 = target,
			P3 = target,
			Distance = 0,
			Style = style,
		}
	end

	local direction = delta.Unit
	local cameraRight = cameraCFrame and cameraCFrame.RightVector or Vector3.xAxis
	local side = perpendicularSide(direction, cameraRight)

	local upAmount = math.clamp(distance * config.UpFraction, config.MinUp, config.MaxUp)
	local sideAmount = math.clamp(distance * config.SideFraction, config.MinSide, config.MaxSide)

	local p0 = origin
	local p1Offset = Vector3.yAxis * (upAmount * style.Up1) + side * (sideAmount * style.Side1)
	local p2Offset = Vector3.yAxis * (upAmount * style.Up2) + side * (sideAmount * style.Side2)
	local p1 = origin + direction * (distance * style.P1) + p1Offset
	local p2 = origin + direction * (distance * style.P2) + p2Offset
	local p3 = target

	return {
		P0 = p0,
		P1 = p1,
		P2 = p2,
		P3 = p3,
		Distance = distance,
		UpAmount = upAmount,
		SideAmount = sideAmount,
		Style = style,
	}
end

function SlingshotAnimeTrajectory.Evaluate(curve, t)
	t = math.clamp(tonumber(t) or 0, 0, 1)
	local inv = 1 - t
	return curve.P0 * (inv * inv * inv)
		+ curve.P1 * (3 * inv * inv * t)
		+ curve.P2 * (3 * inv * t * t)
		+ curve.P3 * (t * t * t)
end

function SlingshotAnimeTrajectory.Tangent(curve, t)
	t = math.clamp(tonumber(t) or 0, 0, 1)
	local inv = 1 - t
	local tangent = (curve.P1 - curve.P0) * (3 * inv * inv)
		+ (curve.P2 - curve.P1) * (6 * inv * t)
		+ (curve.P3 - curve.P2) * (3 * t * t)
	return safeUnit(tangent, safeUnit(curve.P3 - curve.P0, Vector3.zAxis))
end

function SlingshotAnimeTrajectory.ApplyToBeam(beam, attachment0, attachment1, curve, config)
	if not beam or not attachment0 or not attachment1 or not curve then
		return
	end
	config = mergeConfig(config)

	local startVector = curve.P1 - curve.P0
	local endVector = curve.P3 - curve.P2
	local startLength = startVector.Magnitude
	local endLength = endVector.Magnitude

	setAttachmentWorldFrame(attachment0, worldFrameWithRight(curve.P0, safeUnit(startVector, Vector3.xAxis)))
	setAttachmentWorldFrame(attachment1, worldFrameWithRight(curve.P3, safeUnit(endVector, Vector3.xAxis)))

	beam.CurveSize0 = startLength
	beam.CurveSize1 = endLength
	beam.Segments = config.BeamSegments
end

return SlingshotAnimeTrajectory
