local SlingshotAnimeTrajectory = {}

local DEFAULTS = {
	UpFraction = 0.22,
	SideFraction = 0.10,
	MinUp = 5,
	MaxUp = 28,
	MinSide = 2,
	MaxSide = 14,
	P1ForwardFraction = 0.26,
	P2ForwardFraction = 0.72,
	P2OffsetScale = 0.72,
	BeamSegments = 28,
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

function SlingshotAnimeTrajectory.GetCurve(origin, target, cameraCFrame, config)
	config = mergeConfig(config)
	local delta = target - origin
	local distance = delta.Magnitude
	if distance <= 0.001 then
		return {
			P0 = origin,
			P1 = origin,
			P2 = target,
			P3 = target,
			Distance = 0,
		}
	end

	local direction = delta.Unit
	local cameraRight = cameraCFrame and cameraCFrame.RightVector or Vector3.xAxis
	local side = perpendicularSide(direction, cameraRight)

	local upAmount = math.clamp(distance * config.UpFraction, config.MinUp, config.MaxUp)
	local sideAmount = math.clamp(distance * config.SideFraction, config.MinSide, config.MaxSide)

	-- Curva anime: gran elevación y un barrido lateral moderado.
	-- El punto final SIEMPRE sigue siendo el punto de impacto del raycast real.
	local offset = Vector3.yAxis * upAmount + side * sideAmount
	local p0 = origin
	local p1 = origin + direction * (distance * config.P1ForwardFraction) + offset
	local p2 = origin + direction * (distance * config.P2ForwardFraction) + offset * config.P2OffsetScale
	local p3 = target

	return {
		P0 = p0,
		P1 = p1,
		P2 = p2,
		P3 = p3,
		Distance = distance,
		UpAmount = upAmount,
		SideAmount = sideAmount,
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