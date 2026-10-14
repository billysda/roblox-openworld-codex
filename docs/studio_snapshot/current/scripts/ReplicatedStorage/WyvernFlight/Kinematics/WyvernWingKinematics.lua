-- WyvernWingKinematics.lua
-- Driver Visual y Cinemático Procedural Unificado de Alas, Torso, Cola y Estabilización Cervical Vestibular
-- Proyecto: Wyvern Flight Rebuild (Fase 5C Completa Aprobada)
--
-- Arquitectura Desacoplada en Capas (100% Visual en Cliente):
-- 1. Flight Neutral Pose (Base Anatómica Desplegada en Alas - Fase 5C.1)
-- 2. Organic Wingbeat Waveform (Downstroke 42% / Upstroke 58% - Fase 5C.2)
-- 3. Propagación de Phase Lag en Alas (Hombro -> Brazo -> Antebrazo -> Muñeca -> Dedos)
-- 4. Reacción Corporal Biomecánica en Torso (Pecho 1 -> Pecho 2 -> Pecho 3 - Fase 5C.3)
-- 5. Follow-Through Inercial Calibrado en Cola (Cola 1 -> Cola 6 - Fase 5C.4-D)
-- 6. Estabilización Cervical Vestibular Causal (Cuello 2 -> Cuello 3 -> Cabeza - Fase 5C.7B)
-- 7. 100% Desacoplado de la Física y Aerodinámica

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local wyvernFlightFolder = ReplicatedStorage:WaitForChild("WyvernFlight", 10)
local WyvernFlightEffortModel = nil
pcall(function()
	if script and script.Parent and script.Parent:FindFirstChild("WyvernFlightEffortModel") then
		WyvernFlightEffortModel = require(script.Parent.WyvernFlightEffortModel)
	elseif wyvernFlightFolder then
		local kinFolder = wyvernFlightFolder:FindFirstChild("Kinematics")
		if kinFolder and kinFolder:FindFirstChild("WyvernFlightEffortModel") then
			WyvernFlightEffortModel = require(kinFolder.WyvernFlightEffortModel)
		end
	end
end)

-- =====================================================================
-- RANGOS EXPERIMENTALES DE AMPLITUD DE ALA (FASE 5D.3)
-- =====================================================================
local MIN_WING_AMPLITUDE = 5.0  -- Grados base a FlightEffort = 0.0 (Planeo / Dive)
local MAX_WING_AMPLITUDE = 14.0 -- Grados base a FlightEffort = 1.0 (Máximo esfuerzo)

local WyvernWingKinematics = {}
WyvernWingKinematics.__index = WyvernWingKinematics

-- =====================================================================
-- 1. CONFIGURACIÓN DE CADENAS DE ALAS (FLIGHT NEUTRAL + PROPAGACIÓN)
-- =====================================================================
local WING_CHAINS = {
	Left = {
		Root = {
			name = "Hombro_Izq_055",
			baseTransform = CFrame.Angles(math.rad(5), math.rad(-15), math.rad(10)),
			flapAxis = Vector3.new(-0.560, 0.732, 0.389).Unit,
			ampFactor = 0.20,
			phaseLag = 0.00
		},
		UpperArm = {
			name = "Brazo_Izq_056",
			baseTransform = CFrame.Angles(math.rad(10), math.rad(5), math.rad(-15)),
			flapAxis = Vector3.new(-0.366, 0.708, -0.603).Unit,
			ampFactor = 0.40,
			phaseLag = 0.08
		},
		Forearm = {
			name = "Antebrazo_Izq_057",
			baseTransform = CFrame.Angles(math.rad(-5), math.rad(-20), math.rad(15)),
			flapAxis = Vector3.new(-0.982, 0.187, 0.018).Unit,
			ampFactor = 0.65,
			phaseLag = 0.16
		},
		Wrist = {
			name = "Ala_Izq_058",
			baseTransform = CFrame.Angles(math.rad(5), math.rad(-10), math.rad(5)),
			flapAxis = Vector3.new(0.157, -0.785, 0.599).Unit,
			ampFactor = 0.85,
			phaseLag = 0.25
		},
		InnerMembrane = {
			{ name = "Ala_Izq_4_1_073", baseTransform = CFrame.Angles(0, math.rad(-10), math.rad(5)), flapAxis = Vector3.new(-0.982, 0.187, 0.018).Unit, ampFactor = 0.40, phaseLag = 0.10 },
			{ name = "Ala_Izq_4_2_074", baseTransform = CFrame.Angles(0, math.rad(-10), math.rad(5)), flapAxis = Vector3.new(-0.982, 0.187, 0.018).Unit, ampFactor = 0.50, phaseLag = 0.15 },
			{ name = "Ala_Izq_4_3_075", baseTransform = CFrame.Angles(0, math.rad(-5), 0), flapAxis = Vector3.new(-0.982, 0.187, 0.018).Unit, ampFactor = 0.60, phaseLag = 0.20 },
		},
		Digits = {
			-- Dedo 1 (Inferior)
			{ { name = "Ala_Izq_1_1_061", baseTransform = CFrame.Angles(math.rad(5), math.rad(5), 0), flapAxis = Vector3.new(-0.931, -0.342, 0.123).Unit, ampFactor = 0.25, phaseLag = 0.28 },
			  { name = "Ala_Izq_1_2_062", baseTransform = CFrame.identity, flapAxis = Vector3.new(-0.990, -0.096, 0.099).Unit, ampFactor = 0.25, phaseLag = 0.32 },
			  { name = "Ala_Izq_1_3_063", baseTransform = CFrame.identity, flapAxis = Vector3.new(-0.998, 0, 0.068).Unit, ampFactor = 0.25, phaseLag = 0.35 },
			  { name = "Ala_Izq_1_4_064", baseTransform = CFrame.identity, flapAxis = Vector3.new(0, 1, 0).Unit, ampFactor = 0.00, phaseLag = 0.38 } },
			-- Dedo 2 (Medio)
			{ { name = "Ala_Izq_2_1_065", baseTransform = CFrame.Angles(math.rad(5), 0, 0), flapAxis = Vector3.new(-0.931, -0.342, 0.123).Unit, ampFactor = 0.25, phaseLag = 0.28 },
			  { name = "Ala_Izq_2_2_066", baseTransform = CFrame.identity, flapAxis = Vector3.new(-0.990, -0.096, 0.099).Unit, ampFactor = 0.25, phaseLag = 0.32 },
			  { name = "Ala_Izq_2_3_067", baseTransform = CFrame.identity, flapAxis = Vector3.new(-0.998, 0, 0.068).Unit, ampFactor = 0.25, phaseLag = 0.35 },
			  { name = "Ala_Izq_3_3_068", baseTransform = CFrame.identity, flapAxis = Vector3.new(0, 1, 0).Unit, ampFactor = 0.00, phaseLag = 0.38 } },
			-- Dedo 3 (Punta Principal / Borde de Ataque)
			{ { name = "Ala_Izq_3_1_069", baseTransform = CFrame.Angles(math.rad(5), math.rad(-5), 0), flapAxis = Vector3.new(-0.931, -0.342, 0.123).Unit, ampFactor = 0.25, phaseLag = 0.28 },
			  { name = "Ala_Izq_3_2_070", baseTransform = CFrame.Angles(0, math.rad(-5), 0), flapAxis = Vector3.new(-0.990, -0.096, 0.099).Unit, ampFactor = 0.25, phaseLag = 0.32 },
			  { name = "Ala_Izq_3_3_071", baseTransform = CFrame.Angles(0, math.rad(-5), 0), flapAxis = Vector3.new(-0.998, 0, 0.068).Unit, ampFactor = 0.25, phaseLag = 0.35 },
			  { name = "Ala_Izq_3_4_072", baseTransform = CFrame.identity, flapAxis = Vector3.new(0, 1, 0).Unit, ampFactor = 0.00, phaseLag = 0.38 } }
		}
	},
	Right = {
		Root = {
			name = "Hombro_Der_035",
			baseTransform = CFrame.Angles(math.rad(5), math.rad(15), math.rad(-10)),
			flapAxis = Vector3.new(-0.645, -0.656, -0.391).Unit,
			ampFactor = 0.20,
			phaseLag = 0.00
		},
		UpperArm = {
			name = "Brazo_Der_036",
			baseTransform = CFrame.Angles(math.rad(10), math.rad(-5), math.rad(15)),
			flapAxis = Vector3.new(-0.237, -0.783, 0.575).Unit,
			ampFactor = 0.40,
			phaseLag = 0.08
		},
		Forearm = {
			name = "Antebrazo_Der_037",
			baseTransform = CFrame.Angles(math.rad(-5), math.rad(20), math.rad(-15)),
			flapAxis = Vector3.new(-0.981, -0.191, -0.033).Unit,
			ampFactor = 0.65,
			phaseLag = 0.16
		},
		Wrist = {
			name = "Ala_Der_038",
			baseTransform = CFrame.Angles(math.rad(5), math.rad(10), math.rad(-5)),
			flapAxis = Vector3.new(0.065, 0.839, -0.541).Unit,
			ampFactor = 0.85,
			phaseLag = 0.25
		},
		InnerMembrane = {
			{ name = "Ala_Der_1_1_052", baseTransform = CFrame.Angles(0, math.rad(10), math.rad(-5)), flapAxis = Vector3.new(-0.981, -0.191, -0.033).Unit, ampFactor = 0.40, phaseLag = 0.10 },
			{ name = "Ala_Der_1_2_053", baseTransform = CFrame.Angles(0, math.rad(10), math.rad(-5)), flapAxis = Vector3.new(-0.981, -0.191, -0.033).Unit, ampFactor = 0.50, phaseLag = 0.15 },
			{ name = "Ala_Der_1_3_054", baseTransform = CFrame.Angles(0, math.rad(5), 0), flapAxis = Vector3.new(-0.981, -0.191, -0.033).Unit, ampFactor = 0.60, phaseLag = 0.20 },
		},
		Digits = {
			-- Dedo 2 (Inferior)
			{ { name = "Ala_Der_2_1_00",  baseTransform = CFrame.Angles(math.rad(5), math.rad(-5), 0), flapAxis = Vector3.new(-0.911, 0.343, -0.231).Unit, ampFactor = 0.25, phaseLag = 0.28 },
			  { name = "Ala_Der_2_2_041", baseTransform = CFrame.identity, flapAxis = Vector3.new(-0.971, 0.086, -0.222).Unit, ampFactor = 0.25, phaseLag = 0.32 },
			  { name = "Ala_Der_2_3_042", baseTransform = CFrame.identity, flapAxis = Vector3.new(-0.970, 0, -0.243).Unit, ampFactor = 0.25, phaseLag = 0.35 },
			  { name = "Ala_Der_2_4_043", baseTransform = CFrame.identity, flapAxis = Vector3.new(0, 1, 0).Unit, ampFactor = 0.00, phaseLag = 0.38 } },
			-- Dedo 3 (Medio)
			{ { name = "Ala_Der_3_1_044", baseTransform = CFrame.Angles(math.rad(5), 0, 0), flapAxis = Vector3.new(-0.911, 0.343, -0.231).Unit, ampFactor = 0.25, phaseLag = 0.28 },
			  { name = "Ala_Der_3_2_045", baseTransform = CFrame.identity, flapAxis = Vector3.new(-0.971, 0.086, -0.222).Unit, ampFactor = 0.25, phaseLag = 0.32 },
			  { name = "Ala_Der_3_3_046", baseTransform = CFrame.identity, flapAxis = Vector3.new(-0.970, 0, -0.243).Unit, ampFactor = 0.25, phaseLag = 0.35 },
			  { name = "Ala_Der_3_4_047", baseTransform = CFrame.identity, flapAxis = Vector3.new(0, 1, 0).Unit, ampFactor = 0.00, phaseLag = 0.38 } },
			-- Dedo 4 (Punta Principal / Borde de Ataque)
			{ { name = "Ala_Der_4_1_048", baseTransform = CFrame.Angles(math.rad(5), math.rad(5), 0), flapAxis = Vector3.new(-0.911, 0.343, -0.231).Unit, ampFactor = 0.25, phaseLag = 0.28 },
			  { name = "Ala_Der_4_2_049", baseTransform = CFrame.Angles(0, math.rad(5), 0), flapAxis = Vector3.new(-0.971, 0.086, -0.222).Unit, ampFactor = 0.25, phaseLag = 0.32 },
			  { name = "Ala_Der_4_3_050", baseTransform = CFrame.Angles(0, math.rad(5), 0), flapAxis = Vector3.new(-0.970, 0, -0.243).Unit, ampFactor = 0.25, phaseLag = 0.35 },
			  { name = "Ala_Der_4_4_051", baseTransform = CFrame.identity, flapAxis = Vector3.new(0, 1, 0).Unit, ampFactor = 0.00, phaseLag = 0.38 } }
		}
	}
}

-- =====================================================================
-- 2. CONFIGURACIÓN DE REACCIÓN CORPORAL (PECHO / TORSO - FASE 5C.3)
-- =====================================================================
local CHEST_CHAIN = {
	{
		name = "Pecho_1_022",
		baseTransform = CFrame.identity,
		pitchAxis = Vector3.new(1, 0, 0),
		maxPitchDeg = 0.60,
		phaseLag = 0.05
	},
	{
		name = "Pecho_2_023",
		baseTransform = CFrame.identity,
		pitchAxis = Vector3.new(1, 0, 0),
		maxPitchDeg = 1.00,
		phaseLag = 0.08
	},
	{
		name = "Pecho_3_024",
		baseTransform = CFrame.identity,
		pitchAxis = Vector3.new(1, 0, 0),
		maxPitchDeg = 1.30,
		phaseLag = 0.12
	}
}

-- =====================================================================
-- 3. CONFIGURACIÓN DE FOLLOW-THROUGH EN COLA (FASE 5C.4-D APROBADA)
-- =====================================================================
local TAIL_CHAIN = {
	{ name = "Cola_1_076", baseTransform = CFrame.identity, pitchAxis = Vector3.new(1, 0, 0), maxPitchDeg = 0.30, phaseLag = 0.35 },
	{ name = "Cola_2_077", baseTransform = CFrame.identity, pitchAxis = Vector3.new(1, 0, 0), maxPitchDeg = 0.40, phaseLag = 0.45 },
	{ name = "Cola_3_078", baseTransform = CFrame.identity, pitchAxis = Vector3.new(1, 0, 0), maxPitchDeg = 0.55, phaseLag = 0.55 },
	{ name = "Cola_4_079", baseTransform = CFrame.identity, pitchAxis = Vector3.new(1, 0, 0), maxPitchDeg = 0.75, phaseLag = 0.65 },
	{ name = "Cola_5_080", baseTransform = CFrame.identity, pitchAxis = Vector3.new(1, 0, 0), maxPitchDeg = 1.00, phaseLag = 0.80 },
	{ name = "Cola_6_081", baseTransform = CFrame.identity, pitchAxis = Vector3.new(1, 0, 0), maxPitchDeg = 1.25, phaseLag = 0.95 },
	{ name = "Cola_7_082", baseTransform = CFrame.identity, pitchAxis = Vector3.new(1, 0, 0), maxPitchDeg = 0.00, phaseLag = 0.00 }
}

-- =====================================================================
-- 4. CONFIGURACIÓN DE ESTABILIZACIÓN CERVICAL VESTIBULAR (FASE 5C.7B FINAL)
-- =====================================================================
-- Cuello_1_025 no recibe compensación local (0.0°); acompaña la raíz torácica.
-- Cuello_2, Cuello_3 y Cabeza aplican contra-rotación sagital en Local X.
local CERVICAL_CHAIN = {
	{
		name = "Cuello_2_026",
		baseTransform = CFrame.identity,
		pitchAxis = Vector3.new(1, 0, 0),
		maxPitchDeg = 0.25,
		phaseLag = 0.12
	},
	{
		name = "Cuello_3_027",
		baseTransform = CFrame.identity,
		pitchAxis = Vector3.new(1, 0, 0),
		maxPitchDeg = 0.40,
		phaseLag = 0.16
	},
	{
		name = "Cabeza_028",
		baseTransform = CFrame.identity,
		pitchAxis = Vector3.new(1, 0, 0),
		maxPitchDeg = 0.60,
		phaseLag = 0.20
	}
}

-- =====================================================================
-- 5. FUNCIÓN DE FORMA ORGÁNICA DE ALETEO (ORGANIC WINGBEAT SHAPE)
-- =====================================================================
local DOWNSTROKE_RATIO = 0.42
local TWO_PI = 2 * math.pi

local function calculateOrganicShape(phaseWithLag)
	local normalizedPhase = (phaseWithLag % TWO_PI) / TWO_PI
	if normalizedPhase < 0 then normalizedPhase = normalizedPhase + 1 end

	if normalizedPhase < DOWNSTROKE_RATIO then
		local u = normalizedPhase / DOWNSTROKE_RATIO
		local u_warped = u ^ 1.15
		return math.cos(math.pi * u_warped)
	else
		local u = (normalizedPhase - DOWNSTROKE_RATIO) / (1.0 - DOWNSTROKE_RATIO)
		local smooth_u = u * u * (3.0 - 2.0 * u)
		return -1.0 + 2.0 * smooth_u
	end
end

function WyvernWingKinematics.new(wyvernModel)
	local self = setmetatable({}, WyvernWingKinematics)
	self.model = wyvernModel
	self.rootPart = wyvernModel:FindFirstChild("DT_Root") or wyvernModel:FindFirstChild("RootPart") or wyvernModel.PrimaryPart
	self.boneCache = {}
	self.chestCache = {}
	self.tailCache = {}
	self.cervicalCache = {}

	if not WyvernFlightEffortModel then
		pcall(function()
			local rsKin = ReplicatedStorage:FindFirstChild("WyvernFlight") and ReplicatedStorage.WyvernFlight:FindFirstChild("Kinematics")
			if rsKin and rsKin:FindFirstChild("WyvernFlightEffortModel") then
				WyvernFlightEffortModel = require(rsKin.WyvernFlightEffortModel)
			end
		end)
	end

	if WyvernFlightEffortModel then
		self.effortModel = WyvernFlightEffortModel.new()
	end

	self:cacheBones()
	return self
end

function WyvernWingKinematics:cacheBones()
	-- 1. Cachear Alas
	for side, chainData in pairs(WING_CHAINS) do
		self.boneCache[side] = {
			Root = { bone = self.model:FindFirstChild(chainData.Root.name, true), def = chainData.Root },
			UpperArm = { bone = self.model:FindFirstChild(chainData.UpperArm.name, true), def = chainData.UpperArm },
			Forearm = { bone = self.model:FindFirstChild(chainData.Forearm.name, true), def = chainData.Forearm },
			Wrist = { bone = self.model:FindFirstChild(chainData.Wrist.name, true), def = chainData.Wrist },
			InnerMembrane = {},
			Digits = {}
		}

		for _, memDef in ipairs(chainData.InnerMembrane) do
			local b = self.model:FindFirstChild(memDef.name, true)
			if b then
				table.insert(self.boneCache[side].InnerMembrane, { bone = b, def = memDef })
			end
		end

		for _, digitChain in ipairs(chainData.Digits) do
			local digitBones = {}
			for _, dDef in ipairs(digitChain) do
				local b = self.model:FindFirstChild(dDef.name, true)
				if b then
					table.insert(digitBones, { bone = b, def = dDef })
				end
			end
			table.insert(self.boneCache[side].Digits, digitBones)
		end
	end

	-- 2. Cachear Pecho / Torso
	self.chestCache = {}
	for _, chestDef in ipairs(CHEST_CHAIN) do
		local b = self.model:FindFirstChild(chestDef.name, true)
		if b then
			table.insert(self.chestCache, { bone = b, def = chestDef })
		end
	end

	-- 3. Cachear Cola
	self.tailCache = {}
	for _, tailDef in ipairs(TAIL_CHAIN) do
		local b = self.model:FindFirstChild(tailDef.name, true)
		if b then
			table.insert(self.tailCache, { bone = b, def = tailDef })
		end
	end

	-- 4. Cachear Cadena Cervical (Cuello 2, Cuello 3, Cabeza)
	self.cervicalCache = {}
	for _, cervDef in ipairs(CERVICAL_CHAIN) do
		local b = self.model:FindFirstChild(cervDef.name, true)
		if b then
			table.insert(self.cervicalCache, { bone = b, def = cervDef })
		end
	end
end

-- =====================================================================
-- 6. APLICACIÓN DE TRANSFORMACIONES DESACOPLADAS EN CAPAS
-- =====================================================================
local function applyOrganicBoneTransform(boneEntry, globalPhase, baseAmpDeg)
	if not boneEntry or not boneEntry.bone then return end
	local baseCF = boneEntry.def.baseTransform or CFrame.identity

	if baseAmpDeg and baseAmpDeg > 0 and boneEntry.def.ampFactor and boneEntry.def.ampFactor > 0 then
		local delayedPhase = globalPhase - (boneEntry.def.phaseLag or 0)
		local shapeValue = calculateOrganicShape(delayedPhase)

		local boneAngleRad = math.rad(baseAmpDeg * boneEntry.def.ampFactor * shapeValue)
		local offsetRot = CFrame.fromAxisAngle(boneEntry.def.flapAxis, boneAngleRad)
		boneEntry.bone.Transform = baseCF * offsetRot
	else
		boneEntry.bone.Transform = baseCF
	end
end

local function applyChestReactionTransform(chestEntry, globalPhase, isFlapEnabled)
	if not chestEntry or not chestEntry.bone then return end
	local baseCF = chestEntry.def.baseTransform or CFrame.identity

	if isFlapEnabled and chestEntry.def.maxPitchDeg and chestEntry.def.maxPitchDeg > 0 then
		local delayedPhase = globalPhase - (chestEntry.def.phaseLag or 0)
		local shapeValue = calculateOrganicShape(delayedPhase)

		local pitchAngleRad = math.rad(chestEntry.def.maxPitchDeg * (-shapeValue))
		local reactionRot = CFrame.fromAxisAngle(chestEntry.def.pitchAxis, pitchAngleRad)
		chestEntry.bone.Transform = baseCF * reactionRot
	else
		chestEntry.bone.Transform = baseCF
	end
end

local function applyTailFollowThroughTransform(tailEntry, globalPhase, isFlapEnabled)
	if not tailEntry or not tailEntry.bone then return end
	local baseCF = tailEntry.def.baseTransform or CFrame.identity

	if isFlapEnabled and tailEntry.def.maxPitchDeg and tailEntry.def.maxPitchDeg > 0 then
		local delayedPhase = globalPhase - (tailEntry.def.phaseLag or 0)
		local shapeValue = calculateOrganicShape(delayedPhase)

		local pitchAngleRad = math.rad(tailEntry.def.maxPitchDeg * (-shapeValue))
		local tailRot = CFrame.fromAxisAngle(tailEntry.def.pitchAxis, pitchAngleRad)
		tailEntry.bone.Transform = baseCF * tailRot
	else
		tailEntry.bone.Transform = baseCF
	end
end

local function applyCervicalStabilizationTransform(cervEntry, globalPhase, isFlapEnabled)
	if not cervEntry or not cervEntry.bone then return end
	local baseCF = cervEntry.def.baseTransform or CFrame.identity

	if isFlapEnabled and cervEntry.def.maxPitchDeg and cervEntry.def.maxPitchDeg > 0 then
		local delayedPhase = globalPhase - (cervEntry.def.phaseLag or 0)
		local shapeValue = calculateOrganicShape(delayedPhase)

		-- Contra-rotación vestibular opuesta a la flexión del esternón (+shapeValue)
		local pitchAngleRad = math.rad(cervEntry.def.maxPitchDeg * shapeValue)
		local stabRot = CFrame.fromAxisAngle(cervEntry.def.pitchAxis, pitchAngleRad)
		cervEntry.bone.Transform = baseCF * stabRot
	else
		cervEntry.bone.Transform = baseCF
	end
end

function WyvernWingKinematics:update(dt)
	if not self.rootPart then return end

	local isFlapEnabled = (self.rootPart:GetAttribute("Flap_Enabled") == true)
	local flapPhase = self.rootPart:GetAttribute("Flap_Phase") or 0.0
	local flapAmplitude = 10.0

	if isFlapEnabled then
		if self.effortModel then
			local linVel = self.rootPart.AssemblyLinearVelocity
			local lwRatio = self.rootPart:GetAttribute("Aero_LWRatio") or 1.0
			local thrust = self.rootPart:GetAttribute("Thrust_Percent") or 0.0
			local rx, _, _ = self.rootPart.CFrame:ToOrientation()

			local flightState = {
				airspeed = linVel.Magnitude,
				lwRatio = lwRatio,
				thrustPercent = thrust,
				verticalSpeed = linVel.Y,
				pitchDeg = math.deg(rx)
			}

			local currentEffort, targetEffort = self.effortModel:update(dt, flightState)
			local u = math.pow(math.clamp(currentEffort, 0.0, 1.0), 0.75)
			local smoothE = u * u * (3.0 - 2.0 * u)
			flapAmplitude = MIN_WING_AMPLITUDE + (MAX_WING_AMPLITUDE - MIN_WING_AMPLITUDE) * smoothE

			self.rootPart:SetAttribute("Visual_FlightEffort", currentEffort)
			self.rootPart:SetAttribute("Visual_TargetFlightEffort", targetEffort)
			self.rootPart:SetAttribute("Visual_WingAmplitude", flapAmplitude)
		else
			flapAmplitude = self.rootPart:GetAttribute("Flap_Amplitude") or 10.0
		end
	else
		flapAmplitude = 0.0
	end

	-- 1. Capa Torácica: Reacción Corporal (Pecho 1 -> Pecho 3)
	for _, chestEntry in ipairs(self.chestCache) do
		applyChestReactionTransform(chestEntry, flapPhase, isFlapEnabled)
	end

	-- 2. Capa Caudal: Follow-Through Inercial en Cola (Cola 1 -> Cola 6)
	for _, tailEntry in ipairs(self.tailCache) do
		applyTailFollowThroughTransform(tailEntry, flapPhase, isFlapEnabled)
	end

	-- 3. Capa Cervical: Estabilización Vestibular (Cuello 2 -> Cuello 3 -> Cabeza)
	for _, cervEntry in ipairs(self.cervicalCache) do
		applyCervicalStabilizationTransform(cervEntry, flapPhase, isFlapEnabled)
	end

	-- 4. Capa Alar Izquierda: Flight Neutral + Wingbeat Orgánico
	local lData = self.boneCache.Left
	if lData then
		applyOrganicBoneTransform(lData.Root, flapPhase, flapAmplitude)
		applyOrganicBoneTransform(lData.UpperArm, flapPhase, flapAmplitude)
		applyOrganicBoneTransform(lData.Forearm, flapPhase, flapAmplitude)
		applyOrganicBoneTransform(lData.Wrist, flapPhase, flapAmplitude)
		for _, m in ipairs(lData.InnerMembrane) do applyOrganicBoneTransform(m, flapPhase, flapAmplitude) end
		for _, dChain in ipairs(lData.Digits) do
			for _, d in ipairs(dChain) do applyOrganicBoneTransform(d, flapPhase, flapAmplitude) end
		end
	end

	-- 5. Capa Alar Derecha: Flight Neutral + Wingbeat Orgánico
	local rData = self.boneCache.Right
	if rData then
		applyOrganicBoneTransform(rData.Root, flapPhase, flapAmplitude)
		applyOrganicBoneTransform(rData.UpperArm, flapPhase, flapAmplitude)
		applyOrganicBoneTransform(rData.Forearm, flapPhase, flapAmplitude)
		applyOrganicBoneTransform(rData.Wrist, flapPhase, flapAmplitude)
		for _, m in ipairs(rData.InnerMembrane) do applyOrganicBoneTransform(m, flapPhase, flapAmplitude) end
		for _, dChain in ipairs(rData.Digits) do
			for _, d in ipairs(dChain) do applyOrganicBoneTransform(d, flapPhase, flapAmplitude) end
		end
	end
end

return WyvernWingKinematics
