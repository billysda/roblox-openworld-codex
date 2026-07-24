local GrazingService = {}
GrazingService.__index = GrazingService

local Players = game:GetService("Players")

local Cfg = require(script.Parent.Cfg)

local GOLDEN_ANGLE = math.pi * (3 - math.sqrt(5))

local WISP_COLORS = {
	idle = ColorSequence.new(
		Color3.fromRGB(132, 220, 118),
		Color3.fromRGB(205, 255, 166)
	),
	active = ColorSequence.new(
		Color3.fromRGB(116, 238, 105),
		Color3.fromRGB(224, 255, 158)
	),
	qualified = ColorSequence.new(
		Color3.fromRGB(178, 255, 112),
		Color3.fromRGB(255, 244, 150)
	),
}

local function flatVector(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function flatDistance(a, b)
	return flatVector(a - b).Magnitude
end

local function flatDirection(vector)
	local flat = flatVector(vector)
	if flat.Magnitude > 0.001 then
		return flat.Unit
	end
	return nil
end

local function makeWispSizeSequence(scale)
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, scale * 0.18),
		NumberSequenceKeypoint.new(0.28, scale),
		NumberSequenceKeypoint.new(0.72, scale * 0.72),
		NumberSequenceKeypoint.new(1, scale * 0.22),
	})
end

local WISP_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.16, 0.28),
	NumberSequenceKeypoint.new(0.72, 0.52),
	NumberSequenceKeypoint.new(1, 1),
})

function GrazingService.new(houseService)
	local self = setmetatable({}, GrazingService)
	self.HouseService = houseService

	self.RuntimeFolder = workspace:FindFirstChild(Cfg.Grazing.RuntimeFolder)
	if not self.RuntimeFolder then
		self.RuntimeFolder = Instance.new("Folder")
		self.RuntimeFolder.Name = Cfg.Grazing.RuntimeFolder
		self.RuntimeFolder.Parent = workspace
	end

	self.ActiveZones = {} -- userId -> zoneData
	self.LastZonePosition = {} -- userId -> Vector3
	self.LastCheckTime = 0
	self.LastMarkerTime = 0
	self.Random = Random.new()

	self.GroundRayParams = RaycastParams.new()
	self.GroundRayParams.FilterType = Enum.RaycastFilterType.Exclude
	self.GroundRayParams.IgnoreWater = true

	local exclusions = { self.RuntimeFolder }
	local housesFolder = workspace:FindFirstChild((Cfg.Names and Cfg.Names.Houses) or "Houses")
	if housesFolder then
		table.insert(exclusions, housesFolder)
	end
	self.GroundRayParams.FilterDescendantsInstances = exclusions

	return self
end

function GrazingService:_debug(message)
	if Cfg.Grazing.Debug then
		print("[Grazing] " .. message)
	end
end

function GrazingService:Step(clockTime)
	if not Cfg.Grazing.Enabled then
		return
	end

	local dtCheck = clockTime - self.LastCheckTime
	if dtCheck >= Cfg.Grazing.CheckInterval then
		self.LastCheckTime = clockTime
		self:_updateZones(clockTime, dtCheck)
		self:_cleanupLostPlayers(clockTime)
	end

	local dtMarker = clockTime - self.LastMarkerTime
	if dtMarker >= Cfg.Grazing.MarkerUpdateInterval then
		self.LastMarkerTime = clockTime
		self:_updateMarkers()
	end
end

function GrazingService:_ensurePlayerAttributes(player)
	local defaults = {
		PastureFlockLevel = 1,
		PastureFlockXP = 0,
		PastureGrassEaten = 0,
		PastureGrassGoal = Cfg.Grazing.GrassGoal,
		PastureSheepInside = 0,
		PastureSheepRequired = Cfg.Grazing.MinSheepInside,
		PastureZoneIndex = 1,
		PastureGraceActive = false,
	}

	for name, value in pairs(defaults) do
		if player:GetAttribute(name) == nil then
			player:SetAttribute(name, value)
		end
	end
end

function GrazingService:_cleanupLostPlayers(now)
	for userId, zoneData in pairs(self.ActiveZones) do
		local player = Players:GetPlayerByUserId(userId)
		local data = self.HouseService.PlayerData[userId]

		if not player or not data or not data.House or not data.Flock then
			self:_clearFlockAssist(zoneData.Flock, now)
			if zoneData.Folder then
				zoneData.Folder:Destroy()
			end
			if player then
				player:SetAttribute("PastureGraceActive", false)
			end
			self.ActiveZones[userId] = nil
			self.LastZonePosition[userId] = nil
		end
	end
end

function GrazingService:_updateZones(now, dt)
	for userId, data in pairs(self.HouseService.PlayerData) do
		local player = Players:GetPlayerByUserId(userId)
		if player and data.House and data.Flock then
			self:_ensurePlayerAttributes(player)
			self:_handlePlayerZone(player, data.House, data.Flock, now, dt)
		end
	end
end

function GrazingService:_getRequiredCount(activeSheepCount)
	if activeSheepCount <= 0 then
		return 0
	end

	if Cfg.Grazing.RequireAllSheep then
		return activeSheepCount
	end

	local fraction = Cfg.Grazing.RequiredFraction or 0.75
	local fractionalRequired = math.ceil(activeSheepCount * fraction)
	local requestedMinimum = Cfg.Grazing.MinSheepInside or 1
	local minimumForCurrentFlock = math.min(requestedMinimum, activeSheepCount)

	return math.clamp(
		math.max(minimumForCurrentFlock, fractionalRequired),
		1,
		activeSheepCount
	)
end

function GrazingService:_isFlockBusy(flock, now)
	if not flock then
		return false
	end

	if flock.IsMoving then
		return true
	end

	if flock.CommandTarget and now <= (flock.CommandTargetUntil or 0) then
		return true
	end

	if now <= (flock.RecallUntil or 0) then
		return true
	end

	return false
end

function GrazingService:_clearSheepAssist(sheep, now)
	if not sheep then
		return
	end

	if sheep.Model then
		sheep.Model:SetAttribute("GrazingAssistActive", false)
		sheep.Model:SetAttribute("GrazingAssistTarget", nil)
	end

	if sheep.CalmMoveState == "GrazingAssist" then
		sheep.CalmDirection = nil
		sheep.CalmMoveUntil = 0
		sheep.CalmChosenSpeed = nil
		sheep.CalmMoveState = "CalmWalk"

		if sheep.ScheduleNextCalmMove then
			sheep:ScheduleNextCalmMove(now)
		end
	end
end

function GrazingService:_clearFlockAssist(flock, now)
	if not flock or not flock.Sheep then
		return
	end

	for _, sheep in pairs(flock.Sheep) do
		self:_clearSheepAssist(sheep, now)
	end
end

function GrazingService:_getAssistTarget(zonePosition, sheepIndex)
	local radius = Cfg.Grazing.ZoneRadius or 23
	local padding = Cfg.Grazing.AssistInnerPadding or 5
	local innerRadius = math.max(2, radius - padding)
	local index = math.max(1, tonumber(sheepIndex) or 1)
	local angle = index * GOLDEN_ANGLE
	local personalRadius = math.min(innerRadius, 4 + (((index - 1) % 4) * 3))

	return zonePosition + Vector3.new(
		math.cos(angle) * personalRadius,
		0,
		math.sin(angle) * personalRadius
	)
end

function GrazingService:_setSheepAssist(sheep, target, now)
	if not sheep or not sheep.Root or not sheep.Root.Parent then
		return
	end

	local direction = flatDirection(target - sheep.Root.Position)
	if not direction then
		self:_clearSheepAssist(sheep, now)
		return
	end

	if sheep.Model then
		sheep.Model:SetAttribute("GrazingAssistActive", true)
		sheep.Model:SetAttribute("GrazingAssistTarget", target)
	end

	-- Se reutiliza el movimiento tranquilo de Sheep. Las órdenes G/F y el
	-- movimiento del rebaño tienen prioridad porque StepAI las procesa antes.
	sheep.CalmDirection = direction
	sheep.CalmMoveUntil = now + (Cfg.Grazing.AssistRefreshDuration or 0.65)
	sheep.CalmChosenSpeed = Cfg.Grazing.AssistSpeed or 6.5
	sheep.CalmMoveState = "GrazingAssist"

	if sheep.ResetMovementReaction then
		sheep:ResetMovementReaction()
	end
end

function GrazingService:_updateAssistance(flock, zoneData, insideCount, requiredCount, now)
	if not flock or not flock.Sheep then
		return
	end

	local assistAllowed = Cfg.Grazing.AssistEnabled == true
		and insideCount > 0
		and requiredCount > 0
		and insideCount < requiredCount
		and not self:_isFlockBusy(flock, now)

	local zoneRadius = Cfg.Grazing.ZoneRadius or 23
	local assistDistance = Cfg.Grazing.AssistDistance or 10

	for _, sheep in pairs(flock.Sheep) do
		local valid = sheep
			and sheep.Model
			and sheep.Root
			and sheep.Root.Parent
			and not sheep.Model:GetAttribute("CapturedByDragon")

		if not valid then
			self:_clearSheepAssist(sheep, now)
			continue
		end

		local distance = flatDistance(sheep.Root.Position, zoneData.Position)
		local shouldAssist = assistAllowed
			and distance > zoneRadius
			and distance <= zoneRadius + assistDistance
			and not sheep.Model:GetAttribute("JustReleased")

		if shouldAssist then
			local target = self:_getAssistTarget(zoneData.Position, sheep.Index)
			self:_setSheepAssist(sheep, target, now)
		else
			self:_clearSheepAssist(sheep, now)
		end
	end

	zoneData.ZonePart:SetAttribute("AssistActive", assistAllowed)
end

function GrazingService:_getWispStateProperties(state)
	if state == "qualified" then
		return
			Cfg.Grazing.WispRateQualified or 1.45,
			Cfg.Grazing.WispSpeedQualifiedMin or 1.7,
			Cfg.Grazing.WispSpeedQualifiedMax or 2.9,
			WISP_COLORS.qualified
	end

	if state == "active" then
		return
			Cfg.Grazing.WispRateActive or 0.95,
			Cfg.Grazing.WispSpeedActiveMin or 1.35,
			Cfg.Grazing.WispSpeedActiveMax or 2.35,
			WISP_COLORS.active
	end

	return
		Cfg.Grazing.WispRateIdle or 0.55,
		Cfg.Grazing.WispSpeedIdleMin or 1.0,
		Cfg.Grazing.WispSpeedIdleMax or 1.8,
		WISP_COLORS.idle
end

function GrazingService:_setWispState(zoneData, state)
	if zoneData.VisualState == state then
		return
	end

	local rate, minSpeed, maxSpeed, color = self:_getWispStateProperties(state)

	for _, emitter in ipairs(zoneData.WispEmitters or {}) do
		if emitter and emitter.Parent then
			emitter.Rate = rate
			emitter.Speed = NumberRange.new(minSpeed, maxSpeed)
			emitter.Color = color
		end
	end

	zoneData.VisualState = state
	zoneData.ZonePart:SetAttribute("VisualState", state)
end

function GrazingService:_updateZoneVisual(zoneData, insideCount, qualified)
	if qualified then
		self:_setWispState(zoneData, "qualified")
	elseif insideCount > 0 then
		self:_setWispState(zoneData, "active")
	else
		self:_setWispState(zoneData, "idle")
	end
end

function GrazingService:_completeZone(player, flock, zoneData, now)
	local userId = player.UserId
	local progress = 0
	local zoneIndex = (player:GetAttribute("PastureZoneIndex") or 1) + 1
	player:SetAttribute("PastureZoneIndex", zoneIndex)

	local xp = (player:GetAttribute("PastureFlockXP") or 0) + Cfg.Grazing.XPPerZone
	local level = player:GetAttribute("PastureFlockLevel") or 1

	while xp >= Cfg.Grazing.XPToNextLevel do
		xp -= Cfg.Grazing.XPToNextLevel
		level += 1
	end

	player:SetAttribute("PastureFlockXP", xp)
	player:SetAttribute("PastureFlockLevel", level)
	player:SetAttribute("PastureGrassEaten", progress)
	player:SetAttribute("PastureGraceActive", false)

	self:_debug(string.format(
		"Zona completada %s. Nivel=%d XP=%d",
		player.Name,
		level,
		xp
	))

	self:_clearFlockAssist(flock, now)
	self.LastZonePosition[userId] = zoneData.Position

	if zoneData.Folder then
		zoneData.Folder:Destroy()
	end
	self.ActiveZones[userId] = nil
end

function GrazingService:_handlePlayerZone(player, house, flock, now, dt)
	local userId = player.UserId
	local zoneData = self.ActiveZones[userId]

	if not zoneData then
		zoneData = self:_createZoneForPlayer(player, house, flock)
		if not zoneData then
			return
		end
		self.ActiveZones[userId] = zoneData
	end

	zoneData.Flock = flock

	local insideCount = 0
	local activeSheepCount = 0
	local zoneRadius = Cfg.Grazing.ZoneRadius or 23

	if flock.Sheep then
		for _, sheep in pairs(flock.Sheep) do
			if sheep.Model
				and not sheep.Model:GetAttribute("CapturedByDragon")
				and sheep.Root
				and sheep.Root.Parent
			then
				activeSheepCount += 1
				if flatDistance(sheep.Root.Position, zoneData.Position) <= zoneRadius then
					insideCount += 1
				end
			end
		end
	end

	local requiredCount = self:_getRequiredCount(activeSheepCount)
	player:SetAttribute("PastureSheepInside", insideCount)
	player:SetAttribute("PastureSheepRequired", requiredCount)

	zoneData.InsideCount = insideCount
	zoneData.RequiredCount = requiredCount
	zoneData.ZonePart:SetAttribute("InsideCount", insideCount)
	zoneData.ZonePart:SetAttribute("RequiredCount", requiredCount)

	self:_updateAssistance(flock, zoneData, insideCount, requiredCount, now)

	if requiredCount > 0 and insideCount >= requiredCount then
		zoneData.QualifiedUntil = now + (Cfg.Grazing.ExitGraceSeconds or 1.75)
	end

	local qualified = requiredCount > 0
		and (insideCount >= requiredCount or now <= (zoneData.QualifiedUntil or 0))
	local graceActive = qualified and insideCount < requiredCount

	player:SetAttribute("PastureGraceActive", graceActive)
	zoneData.ZonePart:SetAttribute("GraceActive", graceActive)
	zoneData.ZonePart:SetAttribute("QualifiedUntil", zoneData.QualifiedUntil or 0)

	if qualified then
		local progress = player:GetAttribute("PastureGrassEaten") or 0
		progress += Cfg.Grazing.GrassPerSecond * dt

		local goal = player:GetAttribute("PastureGrassGoal") or Cfg.Grazing.GrassGoal
		if progress >= goal then
			self:_completeZone(player, flock, zoneData, now)
			return
		end

		player:SetAttribute("PastureGrassEaten", progress)
	end

	self:_updateZoneVisual(zoneData, insideCount, qualified)
end

function GrazingService:_getBasePosition(house, flock)
	local centerName = (Cfg.Names and (Cfg.Names.PenCenter or Cfg.Names.CorralCenter)) or "CorralCenter"
	local centerPart = house and house:FindFirstChild(centerName, true)

	if centerPart and centerPart:IsA("BasePart") then
		return centerPart.Position
	end

	if flock and flock.Center then
		return flock.Center
	end

	return nil
end

function GrazingService:_raycastGround(position)
	local rayHeight = Cfg.Grazing.GroundRayHeight or 70
	local rayDepth = Cfg.Grazing.GroundRayDepth or 160
	local origin = position + Vector3.new(0, rayHeight, 0)
	local direction = Vector3.new(0, -rayDepth, 0)
	return workspace:Raycast(origin, direction, self.GroundRayParams)
end

function GrazingService:_evaluateCandidate(candidatePosition)
	local sampleCount = math.max(4, Cfg.Grazing.TerrainSampleCount or 8)
	local sampleRadius = (Cfg.Grazing.ZoneRadius or 23) * 0.88
	local minHeight = math.huge
	local maxHeight = -math.huge
	local minNormalY = 1
	local centerResult = nil

	for index = 0, sampleCount do
		local samplePosition = candidatePosition
		if index > 0 then
			local angle = ((index - 1) / sampleCount) * math.pi * 2
			samplePosition += Vector3.new(
				math.cos(angle) * sampleRadius,
				0,
				math.sin(angle) * sampleRadius
			)
		end

		local result = self:_raycastGround(samplePosition)
		if not result then
			return false, nil, math.huge
		end

		if index == 0 then
			centerResult = result
		end

		minHeight = math.min(minHeight, result.Position.Y)
		maxHeight = math.max(maxHeight, result.Position.Y)
		minNormalY = math.min(minNormalY, result.Normal.Y)
	end

	if not centerResult then
		return false, nil, math.huge
	end

	local heightSpread = maxHeight - minHeight
	local accepted = heightSpread <= (Cfg.Grazing.MaxTerrainHeightSpread or 6)
		and minNormalY >= (Cfg.Grazing.MinGroundNormalY or 0.78)
	local score = heightSpread + ((1 - minNormalY) * 20)
	local position = centerResult.Position + Vector3.new(0, Cfg.Grazing.ZoneYOffset or 0.08, 0)

	return accepted, position, score
end

function GrazingService:_getPresetPoints(house, lastPosition)
	local folderName = Cfg.Grazing.PointsFolder or "PastureGrazingPoints"
	local pointsFolder = workspace:FindFirstChild(folderName)
	if not pointsFolder then
		return {}
	end

	local houseId = house and house:GetAttribute("HouseId") or 0
	local candidates = {}

	for _, descendant in ipairs(pointsFolder:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute("Enabled") ~= false then
			local pointHouseId = descendant:GetAttribute("HouseId")
			if pointHouseId == nil or pointHouseId == 0 or pointHouseId == houseId then
				table.insert(candidates, descendant)
			end
		end
	end

	if #candidates > 1 and lastPosition then
		local filtered = {}
		for _, point in ipairs(candidates) do
			if flatDistance(point.Position, lastPosition) > 4 then
				table.insert(filtered, point)
			end
		end
		if #filtered > 0 then
			candidates = filtered
		end
	end

	-- Fisher-Yates para no favorecer el orden del Explorer.
	for index = #candidates, 2, -1 do
		local swapIndex = self.Random:NextInteger(1, index)
		candidates[index], candidates[swapIndex] = candidates[swapIndex], candidates[index]
	end

	return candidates
end

function GrazingService:_chooseZonePosition(player, house, flock)
	local basePosition = self:_getBasePosition(house, flock)
	if not basePosition then
		return nil
	end

	local lastPosition = self.LastZonePosition[player.UserId]

	for _, point in ipairs(self:_getPresetPoints(house, lastPosition)) do
		local accepted, position = self:_evaluateCandidate(point.Position)
		if accepted and position then
			return position, "preset:" .. point.Name
		end
	end

	local attempts = math.max(1, Cfg.Grazing.CandidateAttempts or 16)
	local minimumDistance = Cfg.Grazing.ZoneDistanceMin or 55
	local maximumDistance = Cfg.Grazing.ZoneDistanceMax or 90
	local bestPosition = nil
	local bestScore = math.huge

	for _ = 1, attempts do
		local angle = self.Random:NextNumber(0, math.pi * 2)
		local distance = self.Random:NextNumber(minimumDistance, maximumDistance)
		local candidate = basePosition + Vector3.new(
			math.cos(angle) * distance,
			0,
			math.sin(angle) * distance
		)

		if not lastPosition or flatDistance(candidate, lastPosition) > (Cfg.Grazing.ZoneRadius or 23) then
			local accepted, position, score = self:_evaluateCandidate(candidate)
			if position and score < bestScore then
				bestPosition = position
				bestScore = score
			end
			if accepted and position then
				return position, "procedural"
			end
		end
	end

	if bestPosition then
		warn("[Grazing] No se encontró una zona completamente plana; usando el mejor candidato disponible")
		return bestPosition, "procedural-fallback"
	end

	local fallbackCandidate = basePosition + Vector3.new(minimumDistance, 0, 0)
	local result = self:_raycastGround(fallbackCandidate)
	if result then
		warn("[Grazing] Usando posición de emergencia sin validación perimetral")
		return result.Position + Vector3.new(0, Cfg.Grazing.ZoneYOffset or 0.08, 0), "emergency"
	end

	return nil
end

function GrazingService:_createGroundWisps(parent, zonePosition)
	local anchor = Instance.new("Part")
	anchor.Name = "GrazingWispAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(zonePosition)
	anchor.Parent = parent

	local emitters = {}
	local count = math.max(6, Cfg.Grazing.WispCount or 12)
	local zoneRadius = Cfg.Grazing.ZoneRadius or 23
	local radius = zoneRadius * (Cfg.Grazing.WispRadiusScale or 0.92)
	local radiusJitter = Cfg.Grazing.WispRadiusJitter or 1.8
	local yOffset = Cfg.Grazing.WispYOffset or 0.08
	local spread = Cfg.Grazing.WispSpreadAngle or 12
	local sizeScale = Cfg.Grazing.WispSize or 1.45

	for index = 1, count do
		-- La variación determinista evita una circunferencia mecánica sin cambiar
		-- de forma cada vez que se actualiza el servidor.
		local baseAngle = ((index - 1) / count) * math.pi * 2
		local angle = baseAngle + math.sin(index * 2.17) * 0.055
		local jitter = math.sin(index * 4.123 + 0.7) * radiusJitter
		local pointRadius = math.max(2, radius + jitter)
		local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local samplePosition = zonePosition + radial * pointRadius
		local result = self:_raycastGround(samplePosition)

		local worldPosition
		if result then
			local normal = result.Normal.Magnitude > 0.001 and result.Normal.Unit or Vector3.yAxis
			worldPosition = result.Position + normal * yOffset
		else
			worldPosition = Vector3.new(samplePosition.X, zonePosition.Y + yOffset, samplePosition.Z)
		end

		local attachment = Instance.new("Attachment")
		attachment.Name = string.format("WispPoint%02d", index)
		attachment.Position = anchor.CFrame:PointToObjectSpace(worldPosition)
		attachment.Parent = anchor

		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "GroundWisp"
		emitter.Texture = Cfg.Grazing.WispTexture or "rbxasset://textures/particles/smoke_main.dds"
		emitter.Enabled = true
		emitter.Rate = Cfg.Grazing.WispRateIdle or 0.55
		emitter.Lifetime = NumberRange.new(
			Cfg.Grazing.WispLifetimeMin or 0.85,
			Cfg.Grazing.WispLifetimeMax or 1.35
		)
		emitter.Speed = NumberRange.new(
			Cfg.Grazing.WispSpeedIdleMin or 1.0,
			Cfg.Grazing.WispSpeedIdleMax or 1.8
		)
		emitter.SpreadAngle = Vector2.new(spread, spread)
		emitter.Acceleration = Vector3.new(0, 0.65, 0)
		emitter.Drag = 1.15
		emitter.VelocityInheritance = 0
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-18, 18)
		emitter.LightEmission = 0.7
		emitter.LightInfluence = 0
		emitter.ZOffset = 0.15
		emitter.Color = WISP_COLORS.idle
		emitter.Size = makeWispSizeSequence(sizeScale)
		emitter.Transparency = WISP_TRANSPARENCY
		emitter.Parent = attachment

		table.insert(emitters, emitter)
	end

	return anchor, emitters
end

function GrazingService:_createZoneForPlayer(player, house, flock)
	local zonePosition, source = self:_chooseZonePosition(player, house, flock)
	if not zonePosition then
		warn("[Grazing] No se pudo encontrar suelo para crear la zona de", player.Name)
		return nil
	end

	local folder = Instance.new("Folder")
	folder.Name = "Grazing_" .. player.UserId
	folder.Parent = self.RuntimeFolder

	-- Parte lógica invisible. Flock sigue encontrándola por nombre para exponer
	-- la posición a Sheep; el conteo real usa distancia horizontal.
	local zonePart = Instance.new("Part")
	zonePart.Name = "GrazingZone"
	zonePart.Anchored = true
	zonePart.CanCollide = false
	zonePart.CanTouch = false
	zonePart.CanQuery = false
	zonePart.CastShadow = false
	zonePart.Shape = Enum.PartType.Cylinder
	zonePart.Size = Vector3.new(
		Cfg.Grazing.ZoneHeight,
		Cfg.Grazing.ZoneRadius * 2,
		Cfg.Grazing.ZoneRadius * 2
	)
	zonePart.CFrame = CFrame.new(zonePosition) * CFrame.Angles(0, 0, math.pi / 2)
	zonePart.Transparency = 1
	zonePart:SetAttribute("ZoneRadius", Cfg.Grazing.ZoneRadius)
	zonePart:SetAttribute("Source", source or "unknown")
	zonePart.Parent = folder

	local wispAnchor, wispEmitters = self:_createGroundWisps(folder, zonePosition)

	local anchor = Instance.new("Part")
	anchor.Name = "FlockLabelAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = zonePosition + Vector3.new(0, Cfg.Grazing.LabelHeight, 0)
	anchor.Parent = folder

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ProgressGui"
	billboard.Size = UDim2.new(0, 200, 0, 80)
	billboard.StudsOffset = Vector3.zero
	billboard.AlwaysOnTop = true
	billboard.Parent = anchor

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.TextScaled = true
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextStrokeTransparency = 0
	textLabel.Parent = billboard

	local zoneIndex = player:GetAttribute("PastureZoneIndex") or 1
	self:_debug(string.format("Zona creada %s #%d (%s)", player.Name, zoneIndex, source or "unknown"))

	local zoneData = {
		Folder = folder,
		Position = zonePosition,
		ZonePart = zonePart,
		WispAnchor = wispAnchor,
		WispEmitters = wispEmitters,
		VisualState = nil,
		Anchor = anchor,
		TextLabel = textLabel,
		BGui = billboard,
		QualifiedUntil = 0,
		Flock = flock,
	}

	self:_setWispState(zoneData, "idle")
	return zoneData
end

function GrazingService:_updateMarkers()
	for userId, zoneData in pairs(self.ActiveZones) do
		local player = Players:GetPlayerByUserId(userId)
		local data = self.HouseService.PlayerData[userId]

		if player and data and data.Flock then
			if data.Flock.Center then
				zoneData.Anchor.Position = data.Flock.Center + Vector3.new(0, Cfg.Grazing.LabelHeight, 0)
			else
				zoneData.Anchor.Position = zoneData.Position + Vector3.new(0, Cfg.Grazing.LabelHeight, 0)
			end

			local eaten = math.floor(player:GetAttribute("PastureGrassEaten") or 0)
			local goal = player:GetAttribute("PastureGrassGoal") or Cfg.Grazing.GrassGoal
			local inside = player:GetAttribute("PastureSheepInside") or 0
			local required = player:GetAttribute("PastureSheepRequired") or 2
			local level = player:GetAttribute("PastureFlockLevel") or 1
			local xp = player:GetAttribute("PastureFlockXP") or 0
			local graceActive = player:GetAttribute("PastureGraceActive") == true
			local graceText = graceActive and " (margen)" or ""

			zoneData.TextLabel.Text = string.format(
				"Pasto consumido: %d/%d%s\nOvejas alimentándose: %d/%d\nRebaño Nv.%d  XP %d/%d",
				eaten,
				goal,
				graceText,
				inside,
				required,
				level,
				xp,
				Cfg.Grazing.XPToNextLevel
			)

			local character = player.Character
			local root = character and (character.PrimaryPart or character:FindFirstChild("HumanoidRootPart"))
			local distanceToZone = root and (root.Position - zoneData.Position).Magnitude or math.huge
			zoneData.BGui.Enabled = distanceToZone <= 80 or inside > 0 or eaten > 0
		end
	end
end

return GrazingService
