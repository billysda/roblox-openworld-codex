-- WyvernGroundDetector.lua
-- Módulo de Detección de Suelo y Superficies de Aterrizaje (Fase 5E.2-F)
-- Observador puramente sensorial: NO modifica física, fuerzas, torques, masa, posición ni huesos.
-- Fase 5E.2-F: Calibración Anatómica Final de Offsets Estáticos basada en los centroides reales de garras y cola.

local Workspace = game:GetService("Workspace")

local WyvernGroundDetector = {}
WyvernGroundDetector.__index = WyvernGroundDetector

-- =====================================================================
-- CONFIGURACIÓN DEL SENSOR
-- =====================================================================
WyvernGroundDetector.CONFIG = {
	-- Umbral de proximidad para contacto físico de patas/base
	CONTACT_DISTANCE_THRESHOLD = 1.20, -- studs
	
	-- Umbral de persistencia temporal para IsGrounded (segundos)
	GROUNDED_PERSISTENCE_TIME = 0.15,
	
	-- Muestras consecutivas mínimas requeridas para confirmar TOUCHDOWN
	TOUCHDOWN_MIN_SAMPLES = 3,
	
	-- Parámetros de barrido dinámico de rayos
	BASE_RAY_LENGTH = 15.0,    -- studs
	MAX_RAY_LENGTH  = 45.0,    -- studs (límite máximo de seguridad)
	VELOCITY_LOOKAHEAD_FACTOR = 2.0, -- escala dinámica según -Vy * dt
	
	-- Criterio de superficie aterrizable: inclinación <= 45.0° (cos(45°) = 0.707)
	MIN_GROUNDABLE_NORMAL_Y = 0.707,
	
	-- OFFSETS ESTÁTICOS CALIBRADOS ANATÓMICAMENTE RESPECTO A DT_Root
	-- Medidos empíricamente sobre los centroides de los conjuntos de huesos en reposo:
	-- Center:   DT_GroundCollider Base (0.00, -2.49, 0.00)
	-- LeftLeg:  Centroide Dedo_Izq_* + Pata_Izq_015 (+2.85, -2.49, +5.90)
	-- RightLeg: Centroide Dedo_Der_* + Pata_Der_05 (-2.75, -2.49, +5.90)
	-- Tail:     Patín Intermedio Cola_4_079 (0.00, -2.49, +13.60)
	PROBE_OFFSETS = {
		Center   = Vector3.new(0.00, -2.49, 0.00),   -- Base Central Ventral
		LeftLeg  = Vector3.new(2.85, -2.49, 5.90),   -- Pie Izquierdo Real
		RightLeg = Vector3.new(-2.75, -2.49, 5.90),  -- Pie Derecho Real
		Tail     = Vector3.new(0.00, -2.49, 13.60)   -- Región Caudal Intermedia Cola_4
	}
}

function WyvernGroundDetector.new(wyvernModel)
	local self = setmetatable({}, WyvernGroundDetector)
	self.model = wyvernModel
	self.rootPart = wyvernModel:FindFirstChild("DT_Root") or wyvernModel.PrimaryPart
	self.groundCollider = wyvernModel:FindFirstChild("DT_GroundCollider", true)
	
	-- Configurar RaycastParams con exclusión estricta de todo el modelo wyvern
	self.rayParams = RaycastParams.new()
	self.rayParams.FilterType = Enum.RaycastFilterType.Exclude
	self.rayParams.FilterDescendantsInstances = { wyvernModel }
	self.rayParams.RespectCanCollide = true
	self.rayParams.IgnoreWater = false
	
	-- Estado interno del sensor
	self.lastGroundDistance = 999.0
	self.lastGroundNormal = Vector3.yAxis
	self.lastGroundContact = false
	self.isGrounded = false
	self.isGroundableSurface = false
	self.isTouchdownContact = false
	
	self.contactDuration = 0.0
	self.lossDuration = 0.0
	self.touchdownSampleCount = 0
	
	return self
end

-- =====================================================================
-- EVALUACIÓN DEL SENSOR (UPDATE)
-- =====================================================================
function WyvernGroundDetector:update(dt)
	if not self.rootPart then
		return {
			GroundDistance = 999.0,
			GroundNormal = Vector3.yAxis,
			GroundContact = false,
			IsTouchdownContact = false,
			IsGrounded = false,
			IsGroundableSurface = false,
			TouchdownSampleCount = 0,
			Probes = {},
			ProbeDistances = { Center = 999, LeftLeg = 999, RightLeg = 999, Tail = 999 },
			ProbeContacts = { Center = false, LeftLeg = false, RightLeg = false, Tail = false },
			ProbeGroundables = { Center = false, LeftLeg = false, RightLeg = false, Tail = false },
			ValidProbeCount = 0,
			GroundableProbeCount = 0
		}
	end

	local rootCF = self.rootPart.CFrame
	local linVel = self.rootPart.AssemblyLinearVelocity
	local vy = linVel.Y

	-- 1. Calcular longitud dinámica del rayo (Swept Lookahead)
	local lookaheadDist = (vy < 0) and (-vy * dt * self.CONFIG.VELOCITY_LOOKAHEAD_FACTOR) or 0
	local dynamicRayLength = math.clamp(self.CONFIG.BASE_RAY_LENGTH + lookaheadDist, self.CONFIG.BASE_RAY_LENGTH, self.CONFIG.MAX_RAY_LENGTH)
	local rayDirection = -Vector3.yAxis * dynamicRayLength

	-- 2. Ejecutar los 4 Probes Estáticos de Forma Individual
	local minDistance = 999.0
	local weightedNormal = Vector3.zero
	local validHits = 0
	local groundableHits = 0

	local probeResults = {}
	local probeDistances = {}
	local probeContacts = {}
	local probeGroundables = {}

	for probeKey, localOffset in pairs(self.CONFIG.PROBE_OFFSETS) do
		local originWorld = rootCF:PointToWorldSpace(localOffset)
		local hit = Workspace:Raycast(originWorld, rayDirection, self.rayParams)

		local pDist = 999.0
		local pNorm = Vector3.yAxis
		local pGroundable = false
		local pContact = false
		local pHitInst = nil

		if hit and hit.Instance and hit.Instance.CanCollide then
			pDist = hit.Distance
			pNorm = hit.Normal
			pHitInst = hit.Instance
			validHits = validHits + 1
			weightedNormal = weightedNormal + pNorm

			if pNorm:Dot(Vector3.yAxis) >= self.CONFIG.MIN_GROUNDABLE_NORMAL_Y then
				pGroundable = true
				groundableHits = groundableHits + 1
			end

			if pDist <= self.CONFIG.CONTACT_DISTANCE_THRESHOLD and pGroundable then
				pContact = true
			end

			if pDist < minDistance then
				minDistance = pDist
			end
		end

		probeResults[probeKey] = {
			LocalOffset = localOffset,
			OriginWorld = originWorld,
			Hit = (hit ~= nil),
			Distance = pDist,
			Normal = pNorm,
			HitInstance = pHitInst,
			IsGroundable = pGroundable,
			IsContact = pContact
		}

		probeDistances[probeKey] = pDist
		probeContacts[probeKey] = pContact
		probeGroundables[probeKey] = pGroundable
	end

	-- 3. Consolidar Normal y Superficie Aterrizable
	local finalNormal = Vector3.yAxis
	if validHits > 0 then
		finalNormal = (weightedNormal / validHits).Unit
	end

	local isGroundable = (validHits > 0) and ((groundableHits / validHits) >= 0.50) and (finalNormal:Dot(Vector3.yAxis) >= self.CONFIG.MIN_GROUNDABLE_NORMAL_Y)
	local isProximityContact = (minDistance <= self.CONFIG.CONTACT_DISTANCE_THRESHOLD) and isGroundable

	-- 4. CONTRATO MULTI-PROBE DE TOUCHDOWN (Fase 5E.2-D/F)
	-- Requiere (Center y una pata) O (ambas patas). El probe caudal solo o una pata sola NO pueden disparar Touchdown.
	local centerContact = probeContacts.Center == true
	local leftLegContact = probeContacts.LeftLeg == true
	local rightLegContact = probeContacts.RightLeg == true
	local isTouchdownContact = ((centerContact and (leftLegContact or rightLegContact)) or (leftLegContact and rightLegContact)) and isGroundable

	-- 5. Contador de Muestras Consecutivas para Touchdown
	if isTouchdownContact then
		self.touchdownSampleCount = self.touchdownSampleCount + 1
	else
		self.touchdownSampleCount = 0
	end

	-- 6. Persistencia y Debounce para IsGrounded (Entrada 0.15s, Salida 0.15s)
	-- Depende estrictamente de apoyo biomecánico válido (validGroundSupport = isTouchdownContact)
	local validGroundSupport = isTouchdownContact

	if validGroundSupport then
		self.contactDuration = self.contactDuration + dt
		self.lossDuration = 0.0

		if self.contactDuration >= self.CONFIG.GROUNDED_PERSISTENCE_TIME then
			self.isGrounded = true
		end
	else
		self.lossDuration = self.lossDuration + dt
		self.contactDuration = 0.0

		if self.lossDuration >= self.CONFIG.GROUNDED_PERSISTENCE_TIME then
			self.isGrounded = false
		end
	end

	self.lastGroundDistance = minDistance
	self.lastGroundNormal = finalNormal
	self.lastGroundContact = isProximityContact
	self.isTouchdownContact = isTouchdownContact
	self.isGroundableSurface = isGroundable

	return {
		GroundDistance = minDistance,       -- Proximidad / Aproximación / Landing Candidate
		GroundNormal = finalNormal,
		GroundContact = isProximityContact, -- Proximidad física global
		IsTouchdownContact = isTouchdownContact, -- Señal estricta multi-probe para Touchdown y Apoyo
		IsGrounded = self.isGrounded,       -- Estado confirmado de descanso terrestre (requiere apoyo válido >= 0.15s)
		IsGroundableSurface = isGroundable,
		TouchdownSampleCount = self.touchdownSampleCount,
		DynamicRayLength = dynamicRayLength,
		
		-- Desglose Individual Completo por Probe
		Probes = probeResults,
		ProbeDistances = probeDistances,
		ProbeContacts = probeContacts,
		ProbeGroundables = probeGroundables,
		ValidProbeCount = validHits,
		GroundableProbeCount = groundableHits
	}
end

return WyvernGroundDetector
