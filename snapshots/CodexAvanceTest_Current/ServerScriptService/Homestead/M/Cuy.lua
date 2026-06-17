local Cuy = {}
Cuy.__index = Cuy

local Players = game:GetService("Players")

local HomeCfg = require(script.Parent:WaitForChild("HomeCfg"))

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function getFlatDirection(vector)
	local f = flat(vector)
	if f.Magnitude > 0.001 then
		return f.Unit
	end
	return nil
end

local function pointInsidePartXZ(point, part)
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local half = part.Size * 0.5

	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Z) <= half.Z
end

local function randomPointInPartXZ(rng, part)
	local half = part.Size * 0.5
	local x = rng:NextNumber(-half.X, half.X)
	local z = rng:NextNumber(-half.Z, half.Z)
	local world = part.CFrame:PointToWorldSpace(Vector3.new(x, 0, z))

	return Vector3.new(world.X, part.Position.Y, world.Z)
end

local function rotateFlatDirection(direction, radians)
	local flatDirection = getFlatDirection(direction)
	if not flatDirection then
		return nil
	end

	local cos = math.cos(radians)
	local sin = math.sin(radians)
	return getFlatDirection(Vector3.new(
		flatDirection.X * cos - flatDirection.Z * sin,
		0,
		flatDirection.X * sin + flatDirection.Z * cos
	))
end

local function isValidAnimId(id)
	return typeof(id) == "string" and id:match("^rbxassetid://%d+$") ~= nil
end

local function getRootPart(model)
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end

	for _, name in ipairs({ "HumanoidRootPart", "CuyRoot", "MeshCuy" }) do
		local part = model:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			return part
		end
	end

	return model:FindFirstChildWhichIsA("BasePart", true)
end

function Cuy.new(model, ownerPlayer, house, spawnPart, index, animalService)
	local self = setmetatable({}, Cuy)

	self.Model = model
	self.Owner = ownerPlayer
	self.House = house
	self.SpawnPart = spawnPart
	self.Index = index
	self.Service = animalService

	self.Rng = Random.new((ownerPlayer.UserId + index * 1223 + math.floor(os.clock() * 1000)) % 2147483647)

	self.HomePosition = spawnPart.Position
	self.TargetPosition = self.HomePosition
	self.State = "Idle"
	self.NextDecision = os.clock() + self.Rng:NextNumber(0.4, 1.6)
	self.Speed = self.Rng:NextNumber(HomeCfg.Animals.Cuy.RoamSpeedMin, HomeCfg.Animals.Cuy.RoamSpeedMax)

	self.RoamZone = self:GetZone(HomeCfg.Names.CuyRoamZone)
	self.IndoorZone = self:GetZone(HomeCfg.Names.CuyIndoorZone)
	self.HidePoints = self:GetHidePoints()
	self.CurrentHidePoint = nil
	self.HiddenUntil = 0

	self.Personality = {
		Skittishness = self.Rng:NextNumber(0.8, 1.55),
		Energy = self.Rng:NextNumber(0.8, 1.25),
		Laziness = self.Rng:NextNumber(0.85, 1.5),
		Trust = self.Rng:NextNumber(0.65, 1.2),
		HidePreference = self.Rng:NextNumber(0.7, 1.4),
		Curiosity = self.Rng:NextNumber(0.65, 1.4),
	}

	local cfg = HomeCfg.Animals.Cuy
	local baseAvoid = self.Rng:NextNumber(cfg.AvoidDistanceMin, cfg.AvoidDistanceMax)
	self.AvoidDistance = baseAvoid * self.Personality.Skittishness / math.max(self.Personality.Trust, 0.1)
	self.CalmDistance = self.AvoidDistance + (cfg.CalmDistanceBonus or 3)
	self.IsAfraid = false

	self.Tracks = {}
	self.PivotToBottom = 0.25
	self.LastMoveDirection = Vector3.zAxis
	self.LookDirection = Vector3.zAxis
	self.StepAccumulator = 0
	self.LastPosition = self.HomePosition
	self.LastProgressCheckAt = os.clock()
	self.LastTargetDistance = math.huge
	self.StuckTime = 0
	self.StuckThreshold = self.Rng:NextNumber(1.0, 1.5)
	self.LastRetargetAt = 0

	self.RaycastParams = RaycastParams.new()
	self.RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	self.RaycastParams.FilterDescendantsInstances = { self.Model }
	self.RaycastParams.IgnoreWater = true

	self.ObstacleParams = RaycastParams.new()
	self.ObstacleParams.FilterType = Enum.RaycastFilterType.Exclude
	self.ObstacleParams.FilterDescendantsInstances = { self.Model }
	self.ObstacleParams.IgnoreWater = true

	self:SetupModel()
	self:LoadAnimations()
	self:SetState("Idle")
	self:SetWorldPosition(self.HomePosition, self.LastMoveDirection, 1)

	return self
end

function Cuy:GetZone(zoneName)
	if not zoneName then
		return nil
	end

	local animalZones = self.House:FindFirstChild(HomeCfg.Names.AnimalZones)
	local zone = animalZones and animalZones:FindFirstChild(zoneName)

	if zone and zone:IsA("BasePart") then
		return zone
	end

	return nil
end

function Cuy:GetCurrentPosition()
	if self.Model and self.Model.PrimaryPart then
		return self.Model.PrimaryPart.Position
	end

	return self.HomePosition
end

function Cuy:GetActiveRoamZone(position)
	local current = position or self:GetCurrentPosition()

	if self.IndoorZone and pointInsidePartXZ(current, self.IndoorZone) then
		return self.IndoorZone, true
	end

	if self.RoamZone and pointInsidePartXZ(current, self.RoamZone) then
		return self.RoamZone, false
	end

	return self.RoamZone, false
end

function Cuy:GetHidePoints()
	local result = {}
	local animalZones = self.House:FindFirstChild(HomeCfg.Names.AnimalZones)
	local folder = animalZones and animalZones:FindFirstChild(HomeCfg.Names.CuyHidePoints)

	if folder then
		for _, obj in ipairs(folder:GetChildren()) do
			if obj:IsA("BasePart") then
				table.insert(result, obj)
			end
		end
	end

	table.sort(result, function(a, b)
		return a.Name < b.Name
	end)

	return result
end

function Cuy:SetupModel()
	self.Model:SetAttribute("OwnerId", self.Owner.UserId)
	self.Model:SetAttribute("OwnerName", self.Owner.Name)
	self.Model:SetAttribute("AnimalType", "Cuy")
	self.Model:SetAttribute("CuyIndex", self.Index)

	self.Model:SetAttribute("Skittishness", math.floor(self.Personality.Skittishness * 100) / 100)
	self.Model:SetAttribute("Energy", math.floor(self.Personality.Energy * 100) / 100)
	self.Model:SetAttribute("Laziness", math.floor(self.Personality.Laziness * 100) / 100)
	self.Model:SetAttribute("Trust", math.floor(self.Personality.Trust * 100) / 100)
	self.Model:SetAttribute("HidePreference", math.floor(self.Personality.HidePreference * 100) / 100)
	self.Model:SetAttribute("Curiosity", math.floor(self.Personality.Curiosity * 100) / 100)
	self.Model:SetAttribute("AvoidDistance", math.floor((self.AvoidDistance or 0) * 100) / 100)
	self.Model:SetAttribute("CalmDistance", math.floor((self.CalmDistance or 0) * 100) / 100)

	local primary = getRootPart(self.Model)
	if primary then
		self.Model.PrimaryPart = primary
	end

	for _, desc in ipairs(self.Model:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Anchored = true
			desc.CanCollide = false
			desc.CanTouch = false
			desc.CanQuery = false
		end
	end

	if primary then
		self.Model:PivotTo(CFrame.new(self.HomePosition + Vector3.new(0, 3, 0)))

		local pivot = self.Model:GetPivot()
		local boxCFrame, boxSize = self.Model:GetBoundingBox()
		local bottomY = boxCFrame.Position.Y - boxSize.Y * 0.5

		self.PivotToBottom = math.max(pivot.Position.Y - bottomY, 0.03)
	else
		warn("[Cuy] Falta root BasePart en", self.Model.Name)
	end
end

function Cuy:LoadAnimations()
	local animCfg = HomeCfg.Anim.Cuy or {}
	if not (isValidAnimId(animCfg.Idle) or isValidAnimId(animCfg.Walk) or isValidAnimId(animCfg.Run)) then
		return
	end

	local controller = self.Model:FindFirstChildOfClass("AnimationController") or self.Model:FindFirstChild("AnimationController")
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Name = "AnimationController"
		controller.Parent = self.Model
	end

	local animator = controller:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end

	local function loadTrack(trackName, animationId)
		if not isValidAnimId(animationId) then
			return
		end

		local anim = Instance.new("Animation")
		anim.AnimationId = animationId

		local ok, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)

		if ok and track then
			track.Looped = true
			self.Tracks[trackName] = track
		end
	end

	loadTrack("Idle", animCfg.Idle)
	loadTrack("Walk", animCfg.Walk)
	loadTrack("Run", animCfg.Run)
end

function Cuy:SetState(state)
	self.State = state

	if self.Model and HomeCfg.Debug.SetAnimalAttributes then
		self.Model:SetAttribute("State", state)
	end
end

function Cuy:StopMovementTracks()
	for _, name in ipairs({ "Walk", "Run" }) do
		local track = self.Tracks[name]
		if track and track.IsPlaying then
			track:Stop(0.12)
		end
	end
end

function Cuy:PlayTrack(name, speed)
	local track = self.Tracks[name]
	if not track then
		return
	end

	for _, otherName in ipairs({ "Idle", "Walk", "Run" }) do
		local other = self.Tracks[otherName]
		if otherName ~= name and other and other.IsPlaying then
			other:Stop(0.1)
		end
	end

	if not track.IsPlaying then
		track:Play(0.12)
	end

	if speed then
		track:AdjustSpeed(math.clamp(speed / 2.5, 0.7, 1.8))
	end
end

function Cuy:PlayIdle()
	self:PlayTrack("Idle")
end

function Cuy:PlayWalk(speed)
	self:PlayTrack("Walk", speed)
end

function Cuy:PlayRun(speed)
	self:PlayTrack("Run", speed)
end

function Cuy:RefreshRaycastFilter()
	local filter = {}

	if self.Model then
		table.insert(filter, self.Model)
	end

	local homeRuntime = workspace:FindFirstChild("HomeRuntime")
	if homeRuntime then
		table.insert(filter, homeRuntime)
	end

	local sheepRuntime = workspace:FindFirstChild("SheepRuntime")
	if sheepRuntime then
		table.insert(filter, sheepRuntime)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(filter, player.Character)
		end
	end

	self.RaycastParams.FilterDescendantsInstances = filter
	self.ObstacleParams.FilterDescendantsInstances = filter
end

function Cuy:CastObstacle(direction, distance)
	if not self.Model or not self.Model.PrimaryPart then
		return nil
	end

	local flatDirection = getFlatDirection(direction)
	if not flatDirection then
		return nil
	end

	local cfg = HomeCfg.Animals.Cuy
	local origin = self.Model.PrimaryPart.Position + Vector3.new(0, 0.5, 0)
	local castDirection = flatDirection * (distance or cfg.ObstacleCheckDistance)

	self:RefreshRaycastFilter()

	local ok, result = pcall(function()
		return workspace:Spherecast(origin, cfg.ObstacleSphereRadius, castDirection, self.ObstacleParams)
	end)

	if ok then
		return result
	end

	return workspace:Raycast(origin, castDirection, self.ObstacleParams)
end

function Cuy:IsValidGroundHit(result)
	return result and result.Normal.Y > 0.45
end

function Cuy:GetGroundedFromHit(position, result)
	local cfg = HomeCfg.Animals.Cuy
	return Vector3.new(
		position.X,
		result.Position.Y + self.PivotToBottom + cfg.GroundClearance + cfg.ModelYOffset,
		position.Z
	)
end

function Cuy:GetGroundedPosition(position)
	local cfg = HomeCfg.Animals.Cuy

	self:RefreshRaycastFilter()

	local shortOrigin = Vector3.new(position.X, position.Y + 2, position.Z)
	local shortResult = workspace:Raycast(shortOrigin, Vector3.new(0, -8, 0), self.RaycastParams)
	if self:IsValidGroundHit(shortResult) then
		return self:GetGroundedFromHit(position, shortResult)
	end

	local origin = Vector3.new(position.X, position.Y + cfg.GroundRayHeight, position.Z)
	local direction = Vector3.new(0, -cfg.GroundRayLength, 0)
	local result = workspace:Raycast(origin, direction, self.RaycastParams)
	if self:IsValidGroundHit(result) then
		return self:GetGroundedFromHit(position, result)
	end

	return Vector3.new(position.X, position.Y + self.PivotToBottom + cfg.ModelYOffset, position.Z)
end

function Cuy:SetWorldPosition(position, direction, dt)
	if not self.Model or not self.Model.PrimaryPart then
		return
	end

	local cfg = HomeCfg.Animals.Cuy
	local safeDt = math.max(dt or cfg.UpdateRate or (1 / 30), 0.001)
	local grounded = self:GetGroundedPosition(position)
	local currentPosition = self.Model.PrimaryPart.Position
	local positionAlpha = 1 - math.exp(-(cfg.PositionResponsiveness or 18) * safeDt)
	local smoothedPosition = currentPosition:Lerp(grounded, positionAlpha)

	if flat(grounded - currentPosition).Magnitude > 3 then
		smoothedPosition = grounded
	end

	local targetDirection = direction or self.LastMoveDirection
	if self.State == "Hidden" or self.State == "Nibble" or self.State == "PeekOut" then
		targetDirection = self.LastMoveDirection
	elseif self.State == "LookAround" and self.LookDirection then
		targetDirection = self.LookDirection
	end

	targetDirection = getFlatDirection(targetDirection) or getFlatDirection(self.LastMoveDirection) or Vector3.zAxis
	local currentDirection = getFlatDirection(self.LastMoveDirection) or targetDirection

	local responsiveness = cfg.TurnResponsiveness or 7
	if self.State == "AvoidPlayer" or self.State == "GoHide" then
		responsiveness = cfg.RunTurnResponsiveness or 12
	end

	local alpha = 1 - math.exp(-responsiveness * safeDt)
	local smoothed = currentDirection:Lerp(targetDirection, alpha)
	if smoothed.Magnitude > 0.001 then
		smoothed = smoothed.Unit
	else
		smoothed = targetDirection
	end

	self.LastMoveDirection = smoothed
	self.Model:PivotTo(CFrame.lookAt(smoothedPosition, smoothedPosition + smoothed, Vector3.yAxis))
end

function Cuy:HasLineOfSightToTarget(targetPosition)
	if not self.Model or not self.Model.PrimaryPart or not targetPosition then
		return false
	end

	local current = self.Model.PrimaryPart.Position
	local toTarget = targetPosition - current
	local distance = flat(toTarget).Magnitude
	if distance <= 0.4 then
		return true
	end

	local direction = getFlatDirection(toTarget)
	if not direction then
		return true
	end

	local hit = self:CastObstacle(direction, math.max(distance - 0.1, 0.2))
	return not hit or (hit.Distance or math.huge) >= distance - HomeCfg.Animals.Cuy.ObstacleSphereRadius
end

function Cuy:FindClearAlternativeDirection(direction)
	local flatDirection = getFlatDirection(direction)
	if not flatDirection then
		return nil
	end

	for _, angle in ipairs({ math.rad(45), math.rad(-45), math.rad(90), math.rad(-90) }) do
		local candidate = rotateFlatDirection(flatDirection, angle)
		if candidate and not self:CastObstacle(candidate) then
			return candidate
		end
	end

	return nil
end

function Cuy:PickReachableRoamTarget(maxAttempts)
	if not self.Model or not self.Model.PrimaryPart then
		return self.HomePosition
	end

	local cfg = HomeCfg.Animals.Cuy
	local current = self.Model.PrimaryPart.Position
	local zone = self:GetActiveRoamZone(current)
	local attempts = maxAttempts or 8
	local baseDirection = getFlatDirection(self.LastMoveDirection) or Vector3.zAxis

	for attempt = 1, attempts do
		local direction
		if attempt == 1 then
			direction = self:FindClearAlternativeDirection(baseDirection) or baseDirection
		else
			direction = rotateFlatDirection(Vector3.zAxis, self.Rng:NextNumber(-math.pi, math.pi))
		end

		if direction then
			local target = current + direction * self.Rng:NextNumber(cfg.RoamStepMin or 2, cfg.RoamStepMax or 6)
			if (not zone or pointInsidePartXZ(target, zone)) and self:HasLineOfSightToTarget(target) then
				return target
			end
		end
	end

	if zone then
		for _ = 1, math.max(2, math.floor(attempts / 2)) do
			local target = randomPointInPartXZ(self.Rng, zone)
			if flat(target - current).Magnitude <= (cfg.RoamStepMax or 6) and self:HasLineOfSightToTarget(target) then
				return target
			end
		end
	end

	return current
end

function Cuy:PickHidePoint()
	if #self.HidePoints == 0 then
		return nil
	end

	local activeZone = self:GetActiveRoamZone()
	local startIndex = self.Rng:NextInteger(1, #self.HidePoints)
	for offset = 0, #self.HidePoints - 1 do
		local index = ((startIndex + offset - 1) % #self.HidePoints) + 1
		local point = self.HidePoints[index]
		if point then
			local allowedByZone = not activeZone or pointInsidePartXZ(point.Position, activeZone)
			if allowedByZone and self:HasLineOfSightToTarget(point.Position) then
				return point
			end
		end
	end

	return nil
end

function Cuy:PickShortEscapeTarget(preferredDirection)
	if not self.Model or not self.Model.PrimaryPart then
		return nil
	end

	local current = self.Model.PrimaryPart.Position
	local zone = self:GetActiveRoamZone(current)
	local direction = self:FindClearAlternativeDirection(preferredDirection) or getFlatDirection(preferredDirection) or getFlatDirection(self.LastMoveDirection)
	if not direction then
		return nil
	end

	for _ = 1, 6 do
		local target = current + direction * self.Rng:NextNumber(2.0, 4.0)
		if (not zone or pointInsidePartXZ(target, zone)) and self:HasLineOfSightToTarget(target) then
			return target
		end
		direction = rotateFlatDirection(direction, self.Rng:NextNumber(-math.pi, math.pi)) or direction
	end

	local fallback = current + direction * 2
	if zone and not pointInsidePartXZ(fallback, zone) then
		return current
	end

	return fallback
end

function Cuy:ResetProgressTracking()
	local position = self:GetCurrentPosition()
	self.LastPosition = position
	self.LastProgressCheckAt = os.clock()
	self.LastTargetDistance = self.TargetPosition and flat(self.TargetPosition - position).Magnitude or math.huge
	self.StuckTime = 0
end

function Cuy:SetMoveTarget(position)
	if not position then
		return false
	end

	self.TargetPosition = position
	self:ResetProgressTracking()
	return true
end

function Cuy:UpdateTargetProgress(now, distanceToTarget)
	if self.State == "Hidden" then
		self:ResetProgressTracking()
		return false
	end

	if not self.LastProgressCheckAt or now - self.LastProgressCheckAt < 0.4 then
		return false
	end

	local elapsed = now - self.LastProgressCheckAt
	local previousDistance = self.LastTargetDistance or distanceToTarget
	local improved = distanceToTarget < previousDistance - 0.08

	if improved then
		self.StuckTime = 0
	else
		self.StuckTime += elapsed
	end

	self.LastPosition = self:GetCurrentPosition()
	self.LastTargetDistance = distanceToTarget
	self.LastProgressCheckAt = now

	return self.StuckTime >= (self.StuckThreshold or 1.25)
end

function Cuy:ResolveStuck(now, preferredDirection)
	if now - (self.LastRetargetAt or 0) < 0.45 then
		self:StopMovementTracks()
		self:PlayIdle()
		return true
	end

	self.LastRetargetAt = now

	if self.State == "AvoidPlayer" or self.State == "GoHide" then
		local point = self:PickHidePoint()
		if point then
			self.CurrentHidePoint = point
			self:SetMoveTarget(point.Position)
			self.NextDecision = now + self.Rng:NextNumber(2.0, 4.0)
			return true
		end

		local shortTarget = self:PickShortEscapeTarget(preferredDirection)
		if shortTarget and flat(shortTarget - self:GetCurrentPosition()).Magnitude > 0.2 then
			self.CurrentHidePoint = nil
			self:SetMoveTarget(shortTarget)
			self.NextDecision = now + self.Rng:NextNumber(0.6, 1.2)
			return true
		end

		self.CurrentHidePoint = nil
		self:EnterHidden(now)
		return true
	end

	if self.State == "Roam" then
		local target = self:PickReachableRoamTarget(8)
		if target and flat(target - self:GetCurrentPosition()).Magnitude > 0.2 then
			self:SetMoveTarget(target)
			self.NextDecision = now + self.Rng:NextNumber(0.8, 1.6)
		else
			self:LookAround(now)
		end
		return true
	end

	return false
end

function Cuy:GetNearestPlayer()
	local nearestRoot = nil
	local nearestDistance = math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")

		if root and self.Model and self.Model.PrimaryPart then
			local dist = flat(self.Model.PrimaryPart.Position - root.Position).Magnitude
			if dist < nearestDistance then
				nearestDistance = dist
				nearestRoot = root
			end
		end
	end

	return nearestRoot, nearestDistance
end

function Cuy:GetAvoidDistance()
	return self.AvoidDistance or HomeCfg.Animals.Cuy.AvoidDistanceMin or 7
end

function Cuy:GetCalmDistance()
	return self.CalmDistance or (self:GetAvoidDistance() + (HomeCfg.Animals.Cuy.CalmDistanceBonus or 3))
end

function Cuy:Idle(now)
	local cfg = HomeCfg.Animals.Cuy
	self:SetState("Idle")
	self:StopMovementTracks()
	self:PlayIdle()
	self.NextDecision = now + self.Rng:NextNumber(cfg.IdleMin, cfg.IdleMax) * self.Personality.Laziness
end

function Cuy:LookAround(now)
	local cfg = HomeCfg.Animals.Cuy
	self:SetState("LookAround")
	self:StopMovementTracks()
	self:PlayIdle()

	local baseDirection = getFlatDirection(self.LastMoveDirection) or Vector3.zAxis
	self.LookDirection = rotateFlatDirection(baseDirection, self.Rng:NextNumber(-math.pi * 0.75, math.pi * 0.75)) or baseDirection
	self.NextDecision = now + self.Rng:NextNumber(cfg.LookMin, cfg.LookMax) * math.max(self.Personality.Curiosity, 0.4)
end

function Cuy:Nibble(now)
	local cfg = HomeCfg.Animals.Cuy
	self:SetState("Nibble")
	self:StopMovementTracks()
	self:PlayIdle()
	self.NextDecision = now + self.Rng:NextNumber(cfg.NibbleMin, cfg.NibbleMax) * self.Personality.Laziness
end

function Cuy:Roam(now)
	local cfg = HomeCfg.Animals.Cuy
	local target = self:PickReachableRoamTarget(8)
	if not target or flat(target - self:GetCurrentPosition()).Magnitude <= 0.25 then
		self:LookAround(now)
		return
	end

	self:SetMoveTarget(target)
	self.Speed = self.Rng:NextNumber(cfg.RoamSpeedMin, cfg.RoamSpeedMax) * self.Personality.Energy
	self:SetState("Roam")
	self.NextDecision = now + self.Rng:NextNumber(cfg.RoamDurationMin, cfg.RoamDurationMax) * self.Personality.Laziness
end

function Cuy:GoHide(now, run)
	local cfg = HomeCfg.Animals.Cuy
	local point = self:PickHidePoint()
	self.CurrentHidePoint = point

	if not point then
		self.CurrentHidePoint = nil
		if run then
			self:EnterHidden(now)
		else
			self:LookAround(now)
		end
		return false
	end

	self:SetMoveTarget(point.Position)

	if run then
		self.IsAfraid = true
		self.Speed = math.max(self.Rng:NextNumber(cfg.RunSpeedMin, cfg.RunSpeedMax) * self.Personality.Energy, cfg.RunSpeedMin)
	else
		self.Speed = self.Rng:NextNumber(cfg.RoamSpeedMin, cfg.RoamSpeedMax) * self.Personality.Energy
	end

	self:SetState("GoHide")
	self.NextDecision = now + self.Rng:NextNumber(2.8, 5.2)
	return true
end

function Cuy:AvoidPlayer(now, playerRoot)
	local cfg = HomeCfg.Animals.Cuy
	local current = self.Model.PrimaryPart.Position
	local away = getFlatDirection(current - playerRoot.Position) or getFlatDirection(self.LastMoveDirection) or Vector3.zAxis
	local point = self:PickHidePoint()

	self.IsAfraid = true

	if point then
		self.CurrentHidePoint = point
		self:SetMoveTarget(point.Position)
	else
		self.CurrentHidePoint = nil
		local shortTarget = self:PickShortEscapeTarget(away)
		if shortTarget and flat(shortTarget - current).Magnitude > 0.2 then
			self:SetMoveTarget(shortTarget)
		else
			self:EnterHidden(now)
			return
		end
	end

	self.Speed = math.max(self.Rng:NextNumber(cfg.RunSpeedMin, cfg.RunSpeedMax) * self.Personality.Energy, cfg.RunSpeedMin)
	self:SetState("AvoidPlayer")
	self.NextDecision = now + 0.45
end

function Cuy:EnterHidden(now)
	local cfg = HomeCfg.Animals.Cuy
	self:SetState("Hidden")
	self.IsAfraid = true
	self:StopMovementTracks()
	self:PlayIdle()

	local duration = self.Rng:NextNumber(cfg.HiddenMin, cfg.HiddenMax)
	duration = duration * self.Personality.HidePreference / math.max(self.Personality.Curiosity, 0.45)
	self.HiddenUntil = now + duration
	self.NextDecision = self.HiddenUntil
end

function Cuy:PeekOut(now)
	local cfg = HomeCfg.Animals.Cuy
	self:SetState("PeekOut")
	self:StopMovementTracks()
	self:PlayIdle()
	self.LookDirection = rotateFlatDirection(self.LastMoveDirection, self.Rng:NextNumber(-math.pi * 0.4, math.pi * 0.4)) or self.LastMoveDirection
	self.NextDecision = now + self.Rng:NextNumber(cfg.PeekOutMin, cfg.PeekOutMax) / math.max(self.Personality.Curiosity, 0.45)
end

function Cuy:MakeDecision(now)
	local nearestRoot, nearestDistance = self:GetNearestPlayer()
	if nearestRoot and nearestDistance <= self:GetAvoidDistance() then
		self:AvoidPlayer(now, nearestRoot)
		return
	end

	if self.IsAfraid and (not nearestRoot or nearestDistance >= self:GetCalmDistance()) then
		self.IsAfraid = false
	end

	if self.State == "Hidden" then
		if now >= self.HiddenUntil then
			self.CurrentHidePoint = nil
			self:PeekOut(now)
		end
		return
	end

	if self.State == "AvoidPlayer" then
		if nearestRoot and nearestDistance <= self:GetCalmDistance() then
			self:GoHide(now, true)
		else
			self:PeekOut(now)
		end
		return
	end

	if self.State == "GoHide" then
		return
	end

	if self.State == "PeekOut" then
		if self.IsAfraid then
			self:HiddenOrIdle(now)
		elseif self.Rng:NextNumber() < math.clamp(0.35 * self.Personality.Curiosity, 0.18, 0.55) then
			self:LookAround(now)
		else
			self:Idle(now)
		end
		return
	end

	local hideChance = math.clamp(0.035 * self.Personality.HidePreference * self.Personality.Skittishness, 0.015, 0.09)
	local roamChance = math.clamp(0.16 * self.Personality.Energy / math.max(self.Personality.Laziness, 0.5), 0.08, 0.26)
	local lookChance = math.clamp(0.24 * self.Personality.Curiosity, 0.14, 0.36)
	local nibbleChance = math.clamp(0.32 * self.Personality.Laziness, 0.2, 0.44)
	local roll = self.Rng:NextNumber()

	if roll < hideChance then
		self:GoHide(now, false)
	elseif roll < hideChance + roamChance then
		self:Roam(now)
	elseif roll < hideChance + roamChance + lookChance then
		self:LookAround(now)
	elseif roll < hideChance + roamChance + lookChance + nibbleChance then
		self:Nibble(now)
	else
		self:Idle(now)
	end
end

function Cuy:HiddenOrIdle(now)
	if self.IsAfraid then
		self:EnterHidden(now)
	else
		self:Idle(now)
	end
end

function Cuy:MoveTowards(dt, now)
	local current = self.Model.PrimaryPart.Position
	local toTarget = self.TargetPosition - current
	local dist = flat(toTarget).Magnitude
	local direction = getFlatDirection(toTarget)

	if not direction or dist <= 0.25 then
		if self.State == "AvoidPlayer" or self.State == "GoHide" then
			self:EnterHidden(now)
		else
			self:MakeDecision(now)
		end
		return
	end

	if self:UpdateTargetProgress(now, dist) then
		if self:ResolveStuck(now, direction) then
			return
		end
	end

	local hit = self:CastObstacle(direction)
	if hit then
		local alternative = self:FindClearAlternativeDirection(direction)
		if alternative then
			direction = alternative
		else
			if self.State == "AvoidPlayer" or self.State == "GoHide" then
				self:ResolveStuck(now, direction)
			else
				self:LookAround(now)
			end
			return
		end
	end

	local cfg = HomeCfg.Animals.Cuy
	local maxStep = cfg.MaxWalkStep or 0.18
	if self.State == "AvoidPlayer" or self.State == "GoHide" then
		maxStep = cfg.MaxRunStep or 0.35
	end

	local step = math.min(self.Speed * dt, dist, maxStep)
	local blockingHit = self:CastObstacle(direction, math.max(step + cfg.ObstacleSphereRadius, 0.5))
	if blockingHit and (blockingHit.Distance or 0) <= step + cfg.ObstacleSphereRadius then
		local alternative = self:FindClearAlternativeDirection(direction)
		if alternative then
			direction = alternative
		else
			if self.State == "AvoidPlayer" or self.State == "GoHide" then
				self:ResolveStuck(now, direction)
			else
				self:LookAround(now)
			end
			return
		end
	end

	local nextPosition = current + direction * step
	local activeZone = self:GetActiveRoamZone(current)
	if activeZone and not pointInsidePartXZ(nextPosition, activeZone) then
		if self.State == "AvoidPlayer" or self.State == "GoHide" then
			self:EnterHidden(now)
		else
			self:LookAround(now)
		end
		return
	end

	self:SetWorldPosition(nextPosition, direction, dt)

	if self.State == "AvoidPlayer" or self.State == "GoHide" then
		self:PlayRun(self.Speed)
	else
		self:PlayWalk(self.Speed)
	end
end

function Cuy:Step(dt, now)
	if not self.Model or not self.Model.Parent or not self.Model.PrimaryPart then
		return false
	end

	local interval = HomeCfg.Animals.Cuy.UpdateRate or (1 / 30)
	self.StepAccumulator += dt
	if self.StepAccumulator < interval then
		return true
	end

	local stepDt = math.min(self.StepAccumulator, interval * 2)
	self.StepAccumulator = 0

	if self.State == "Hidden" then
		self:StopMovementTracks()
		self:PlayIdle()
		self:SetWorldPosition(self.Model.PrimaryPart.Position, self.LastMoveDirection, stepDt)

		local nearestRoot, nearestDistance = self:GetNearestPlayer()
		if nearestRoot and nearestDistance <= self:GetCalmDistance() then
			self.IsAfraid = true
			self.HiddenUntil = math.max(self.HiddenUntil, now + 2)
		elseif not nearestRoot or nearestDistance >= self:GetCalmDistance() then
			self.IsAfraid = false
		end

		if now >= self.HiddenUntil then
			self.CurrentHidePoint = nil
			self:PeekOut(now)
		end

		return true
	end

	local nearestRoot, nearestDistance = self:GetNearestPlayer()
	if nearestRoot and nearestDistance <= self:GetAvoidDistance() and self.State ~= "AvoidPlayer" and self.State ~= "GoHide" then
		self:AvoidPlayer(now, nearestRoot)
	elseif self.IsAfraid and (not nearestRoot or nearestDistance >= self:GetCalmDistance()) then
		self.IsAfraid = false
	end

	if now >= self.NextDecision then
		self:MakeDecision(now)
	end

	if self.State == "Roam" or self.State == "AvoidPlayer" or self.State == "GoHide" then
		self:MoveTowards(stepDt, now)
	else
		self:StopMovementTracks()
		self:PlayIdle()
		local stationaryDirection = self.LastMoveDirection
		if self.State == "LookAround" then
			stationaryDirection = self.LookDirection or stationaryDirection
		end
		self:SetWorldPosition(self.Model.PrimaryPart.Position, stationaryDirection, stepDt)
	end

	return true
end

function Cuy:Destroy()
	for _, track in pairs(self.Tracks) do
		if track then
			pcall(function()
				track:Stop(0)
				track:Destroy()
			end)
		end
	end

	if self.Model then
		self.Model:Destroy()
	end

	self.Model = nil
	self.Owner = nil
	self.House = nil
	self.SpawnPart = nil
end

return Cuy
