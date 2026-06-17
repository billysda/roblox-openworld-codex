local Chicken = {}
Chicken.__index = Chicken

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")

local HomeCfg = require(script.Parent:WaitForChild("HomeCfg"))

local PathRequestWindowStart = 0
local PathRequestsThisWindow = 0

local function consumePathRequest(now)
	local cfg = HomeCfg.ChickenEscape or {}
	local maxRequests = cfg.MaxPathRequestsPerSecond or 3
	local currentTime = now or os.clock()

	if currentTime - PathRequestWindowStart >= 1 then
		PathRequestWindowStart = currentTime
		PathRequestsThisWindow = 0
	end

	if PathRequestsThisWindow >= maxRequests then
		return false
	end

	PathRequestsThisWindow += 1
	return true
end

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

function Chicken.new(model, ownerPlayer, house, spawnPart, index, eggService, homeData, animalService)
	local self = setmetatable({}, Chicken)

	self.Model = model
	self.Owner = ownerPlayer
	self.House = house
	self.SpawnPart = spawnPart
	self.Index = index
	self.EggService = eggService
	self.HomeData = homeData
	self.Service = animalService

	self.Rng = Random.new((ownerPlayer.UserId + index * 719 + math.floor(os.clock() * 1000)) % 2147483647)

	self.HomePosition = spawnPart.Position
	self.TargetPosition = self.HomePosition
	self.State = "Idle"
	self.NextDecision = os.clock() + self.Rng:NextNumber(0.5, 2.0)
	self.Speed = self.Rng:NextNumber(HomeCfg.Animals.Chicken.SpeedMin, HomeCfg.Animals.Chicken.SpeedMax)

	self.RoamZone = self:GetZone(HomeCfg.Names.ChickenRoamZone)
	self.CoopZone = self:GetZone(HomeCfg.Names.ChickenCoopZone)
	self.IndoorZone = self:GetZone(HomeCfg.Names.ChickenIndoorZone)
	self.EggPoints = self:GetEggPoints()

	self.Personality = {
		Skittishness = self.Rng:NextNumber(0.75, 1.45),
		Energy = self.Rng:NextNumber(0.75, 1.3),
		Laziness = self.Rng:NextNumber(0.8, 1.45),
		Trust = self.Rng:NextNumber(0.65, 1.25),
		EggRate = self.Rng:NextNumber(0.75, 1.35),
	}

	self.NextEggAt = os.clock() + self:GetNextEggCooldown()
	self.NextBurstAt = os.clock() + self:GetNextBurstCooldown()
	self.CurrentEggPoint = nil
	self.NestAccessPoints = {}
	self.NestAccessIndex = 0
	self.NestTargetPart = nil
	self.NestCommitUntil = 0
	self.NestLastProgressAt = os.clock()
	self.NestLastDistance = math.huge
	self.CurrentNestJumpLink = nil
	self.NestJumpStartedAt = 0
	self.NestJumpStartPosition = nil
	self.NestJumpGoalPosition = nil
	self.NestJumpDirection = Vector3.zAxis
	self.OnNestUntil = 0
	self.LayFinishAt = 0
	self.SafeUntil = 0
	self.BurstFinishAt = 0

	self.CarriedBy = nil
	self.CarryPrompt = nil
	self.CarryMotor = nil
	self.CarryDeathConn = nil
	self.CarryAncestryConn = nil

	self.Tracks = {}
	self.PivotToBottom = 0.5
	self.LastMoveDirection = Vector3.zAxis

	self.LastPosition = self.HomePosition
	self.LastProgressCheckAt = os.clock()
	self.LastTargetDistance = math.huge
	self.StuckTime = 0
	self.StuckThreshold = (HomeCfg.ChickenEscape and HomeCfg.ChickenEscape.StuckBeforePathTime) or self.Rng:NextNumber(1.0, 1.5)
	self.ObstacleHits = 0
	self.LastObstacleAt = 0

	self.LastEscapePathAt = -math.huge
	self.EscapePathStartedAt = 0
	self.EscapeWaypoints = nil
	self.EscapeWaypointIndex = 0
	self.EscapeRecoverUntil = 0
	self.StepHopStartedAt = 0
	self.StepHopStart = nil
	self.StepHopGoal = nil
	self.StepHopDirection = Vector3.zAxis
	self.EscapeCommitUntil = 0
	self.EscapeLastProgressAt = 0
	self.EscapeLastDistance = math.huge
	self.EscapeRepathReason = ""
	self.ForcedExitHopStartedAt = 0
	self.ForcedExitHopStart = nil
	self.ForcedExitHopGoal = nil
	self.ForcedExitHopDirection = Vector3.zAxis
	self.ForcedExitHopCooldownUntil = 0

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
	self:SetupCarryPrompt()
	self:SetState("Idle")

	self:SetWorldPosition(self.HomePosition, self.LastMoveDirection, 1)

	return self
end

function Chicken:GetZone(zoneName)
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

function Chicken:GetCurrentPosition()
	if self.Model and self.Model.PrimaryPart then
		return self.Model.PrimaryPart.Position
	end

	return self.HomePosition
end

function Chicken:GetActiveContainmentZone(position)
	local current = position or self:GetCurrentPosition()

	if self.IndoorZone and pointInsidePartXZ(current, self.IndoorZone) then
		return self.IndoorZone, true
	end

	if self.CoopZone and pointInsidePartXZ(current, self.CoopZone) then
		return self.CoopZone, true
	end

	return self.RoamZone, false
end

function Chicken:IsInInteriorZone(position)
	local _, isInterior = self:GetActiveContainmentZone(position)
	return isInterior
end

function Chicken:IsInsideChickenCoopZone(position)
	local current = position or self:GetCurrentPosition()
	return self.CoopZone ~= nil and pointInsidePartXZ(current, self.CoopZone)
end

function Chicken:GetEggPoints()
	local result = {}

	local animalZones = self.House:FindFirstChild(HomeCfg.Names.AnimalZones)
	local folder = animalZones and animalZones:FindFirstChild(HomeCfg.Names.ChickenEggPoints)

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

function Chicken:GetNestAccessPoints()
	local result = {}
	local animalZones = self.House:FindFirstChild(HomeCfg.Names.AnimalZones)
	local folder = animalZones and animalZones:FindFirstChild(HomeCfg.Names.ChickenNestAccessPoints)

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

function Chicken:GetNestJumpLinks()
	local result = {}
	local animalZones = self.House:FindFirstChild(HomeCfg.Names.AnimalZones)
	local folder = animalZones and animalZones:FindFirstChild(HomeCfg.Names.ChickenNestJumpLinks)

	if folder then
		for _, link in ipairs(folder:GetChildren()) do
			local startPart = link:FindFirstChild("Start", true)
			local endPart = link:FindFirstChild("End", true)

			if startPart and startPart:IsA("BasePart") and endPart and endPart:IsA("BasePart") then
				table.insert(result, {
					Name = link.Name,
					Instance = link,
					Start = startPart,
					End = endPart,
				})
			end
		end
	end

	table.sort(result, function(a, b)
		return a.Name < b.Name
	end)

	return result
end

function Chicken:IsNestState()
	return self.State == "GoNestAccess"
		or self.State == "GoNestJumpStart"
		or self.State == "NestJumpUp"
		or self.State == "GoNestEggPoint"
		or self.State == "OnNest"
		or self.State == "NestJumpDown"
end

function Chicken:IsEggPointInNest(point)
	if not point then
		return false
	end

	local position = typeof(point) == "Vector3" and point or point.Position
	return self.CoopZone ~= nil and pointInsidePartXZ(position, self.CoopZone)
end

function Chicken:GetEggPointOutsideCoopZone()
	if not self.CoopZone then
		return nil
	end

	for _, point in ipairs(self.EggPoints) do
		if point and point:IsA("BasePart") and not self:IsEggPointInNest(point) then
			return point
		end
	end

	return nil
end

function Chicken:SetNestDebug(debugState, accessIndex, target, failReason)
	if not self.Model then
		return
	end

	local targetName = ""
	if typeof(target) == "Instance" then
		targetName = target.Name
	elseif typeof(target) == "string" then
		targetName = target
	end

	self.Model:SetAttribute("NestDebug", debugState or "")
	self.Model:SetAttribute("NestAccessIndex", accessIndex or 0)
	self.Model:SetAttribute("NestTarget", targetName)
	self.Model:SetAttribute("NestFailReason", failReason or "")
end

function Chicken:SetNestRouteMode(mode)
	if self.Model then
		self.Model:SetAttribute("NestRouteMode", mode or "")
	end
end

function Chicken:SetNestJumpDebug(debugState, link, reason, target)
	if not self.Model then
		return
	end

	local linkName = ""
	if typeof(link) == "table" then
		linkName = link.Name or ""
	elseif typeof(link) == "Instance" then
		linkName = link.Name
	elseif typeof(link) == "string" then
		linkName = link
	end

	self.Model:SetAttribute("NestJumpDebug", debugState or "")
	self.Model:SetAttribute("NestJumpLink", linkName)
	self.Model:SetAttribute("NestJumpReason", reason or "")
	self.Model:SetAttribute("NestJumpTarget", typeof(target) == "Vector3" and target or Vector3.zero)
end

function Chicken:SetNestLastLog(event)
	if self.Model then
		self.Model:SetAttribute("NestLastLog", event or "")
	end
end

function Chicken:IsChickenNestDebugEnabled()
	return HomeCfg.Debug and HomeCfg.Debug.ChickenNest == true
end

function Chicken:LogNest(event, message, tag)
	self:SetNestLastLog(event or message or "")

	if not self:IsChickenNestDebugEnabled() then
		return
	end

	local chickenName = self.Model and self.Model.Name or ("Chicken" .. tostring(self.Index or ""))
	warn(string.format("%s %s %s", tag or "[ChickenNest]", chickenName, message or event or ""))
end

function Chicken:LogCoopStatus(position)
	local current = position or self:GetCurrentPosition()
	local inside = self:IsInsideChickenCoopZone(current)
	local coopPos = self.CoopZone and tostring(self.CoopZone.Position) or "nil"
	local coopSize = self.CoopZone and tostring(self.CoopZone.Size) or "nil"
	self:LogNest(
		"CoopStatus " .. tostring(inside),
		string.format("IsInsideChickenCoopZone=%s chickenPos=%s coopPos=%s coopSize=%s", tostring(inside), tostring(current), coopPos, coopSize)
	)
	return inside
end

function Chicken:LogEggPointScan()
	self:LogNest("EggPointsFound " .. tostring(#self.EggPoints), "EggPoints found: " .. tostring(#self.EggPoints))
	if #self.EggPoints == 0 then
		self:LogNest("NoChickenEggPointsFound", "No ChickenEggPoints found", "[ChickenNest][FAIL]")
		return
	end

	for _, point in ipairs(self.EggPoints) do
		if point and point:IsA("BasePart") then
			self:LogNest(
				"EggPointCheck " .. point.Name,
				string.format("%s pos=%s insideCoop=%s high=%s", point.Name, tostring(point.Position), tostring(self:IsEggPointInNest(point)), tostring(self:IsHighEggPoint(point)))
			)
		end
	end
end

function Chicken:LogAccessPointScan(points)
	local accessPoints = points or self:GetNestAccessPoints()
	self:LogNest("AccessPointsFound " .. tostring(#accessPoints), "AccessPoints found: " .. tostring(#accessPoints))

	if #accessPoints == 0 and not self:IsInsideChickenCoopZone() then
		self:LogNest("NoAccessPointsOutsideCoop", "No AccessPoints found while chicken is outside coop", "[ChickenNest][FAIL]")
		return accessPoints
	end

	for _, point in ipairs(accessPoints) do
		if point and point:IsA("BasePart") then
			self:LogNest(
				"AccessPointCheck " .. point.Name,
				string.format("%s pos=%s insideCoop=%s", point.Name, tostring(point.Position), tostring(self:IsInsideChickenCoopZone(point.Position)))
			)
		end
	end

	return accessPoints
end

function Chicken:ResetNestProgress(now, targetPosition)
	local current = self:GetCurrentPosition()
	self.NestLastProgressAt = now or os.clock()
	self.NestLastDistance = targetPosition and flat(targetPosition - current).Magnitude or math.huge
end

function Chicken:GetNestGroundedPosition(position)
	self:RefreshRaycastFilter(true)

	local origin = position + Vector3.new(0, 2, 0)
	local result = workspace:Raycast(origin, Vector3.new(0, -5, 0), self.RaycastParams)
	if self:IsValidGroundHit(result) then
		return self:GetGroundedFromHit(position, result)
	end

	return position
end

function Chicken:IsHighEggPoint(point, currentPosition)
	if not point then
		return false
	end

	local current = currentPosition or self:GetCurrentPosition()
	return math.abs(point.Position.Y - current.Y) > 1.5
end

function Chicken:FindBestNestJumpLink(point)
	local cfg = HomeCfg.ChickenNest or {}
	if not cfg.JumpLinksEnabled or not point then
		return nil
	end

	local maxHeightDelta = cfg.NestJumpMaxHeightDelta or 6.0
	local links = self:GetNestJumpLinks()
	local bestLink = nil
	local bestDistance = math.huge

	self:LogNest("NestJumpLinksFound " .. tostring(#links), "NestJumpLinks found: " .. tostring(#links))

	for _, link in ipairs(links) do
		local heightDelta = math.abs(link.End.Position.Y - link.Start.Position.Y)
		local distance = (link.End.Position - point.Position).Magnitude
		self:LogNest(
			"NestJumpLinkCheck " .. link.Name,
			string.format("%s Start=%s End=%s EndDistanceToEgg=%.2f heightDelta=%.2f", link.Name, tostring(link.Start.Position), tostring(link.End.Position), distance, heightDelta)
		)

		if heightDelta <= maxHeightDelta and distance < bestDistance then
			bestDistance = distance
			bestLink = link
		end
	end

	return bestLink
end

function Chicken:SetNestMoveTarget(part, accessIndex, state, now, debugState)
	if not part then
		return false
	end

	local cfg = HomeCfg.Animals.Chicken
	self.NestTargetPart = part
	self.NestAccessIndex = accessIndex or self.NestAccessIndex or 0
	self:SetMoveTarget(part.Position)
	self.NestCommitUntil = now + (cfg.NestAccessCommitTime or 1.2)
	self:ResetNestProgress(now, part.Position)
	self:SetState(state)
	self.NextDecision = now + 30
	self:SetNestDebug(debugState or "UsingAccessPoints", self.NestAccessIndex, part, "")

	local distance = flat(part.Position - self:GetCurrentPosition()).Magnitude
	if state == "GoNestAccess" then
		self:LogNest("MovingToAccessPoint " .. part.Name, string.format("Moving to %s distance=%.2f", part.Name, distance))
	elseif state == "GoNestEggPoint" then
		self:LogNest("GoingToEggPoint " .. part.Name, string.format("Going to EggPoint: %s distance=%.2f", part.Name, distance))
	end

	return true
end

function Chicken:StartNestEggPoint(now, debugState)
	if not self.CurrentEggPoint then
		return self:CancelNestAttempt(now, "NoEggPoint")
	end

	return self:SetNestMoveTarget(self.CurrentEggPoint, self.NestAccessIndex or 0, "GoNestEggPoint", now, debugState or "GoNestEggPoint")
end

function Chicken:StartNestJumpRoute(point, now, reason, nestDebug)
	local link = self:FindBestNestJumpLink(point)
	if not link then
		self:SetNestJumpDebug("Failed", "", "NoJumpLinkForHighEggPoint", point and point.Position or Vector3.zero)
		self:SetNestDebug(nestDebug or "NoAccessPointsFallback", self.NestAccessIndex or 0, point, "NoJumpLinkForHighEggPoint")
		self:LogNest("NoJumpLinkForHighEggPoint", "NoJumpLinkForHighEggPoint", "[ChickenNest][FAIL]")
		return false
	end

	self.CurrentNestJumpLink = link
	self:SetNestRouteMode("InsideCoopGoToJumpStart")
	self:LogNest("RouteMode InsideCoopGoToJumpStart", "RouteMode=InsideCoopGoToJumpStart")
	self:SetNestJumpDebug("GoingToStart", link, reason or "HighEggPoint", link.Start.Position)
	self:LogNest("GoingToNestJumpStart " .. link.Name, "Going to NestJump.Start: " .. link.Name)
	return self:SetNestMoveTarget(link.Start, self.NestAccessIndex or 0, "GoNestJumpStart", now, nestDebug or "UsingAccessPoints")
end

function Chicken:StartNestJumpOrEgg(now, debugState)
	if not self:IsInsideChickenCoopZone() then
		if self.CurrentEggPoint and self:StartNestAccessRoute(self.CurrentEggPoint, now) then
			return true
		end

		self:SetNestRouteMode("EnterCoopViaAccessPoints")
		self:LogNest("RouteMode EnterCoopViaAccessPoints", "RouteMode=EnterCoopViaAccessPoints")
		return self:CancelNestAttempt(now, "OutsideCoopNoAccessPoints")
	end

	if self.CurrentEggPoint and self:IsHighEggPoint(self.CurrentEggPoint) then
		if self:StartNestJumpRoute(self.CurrentEggPoint, now, "HighEggPoint", debugState) then
			return true
		end

		self:SetNestRouteMode("InsideCoopDirectToEggPoint")
		self:LogNest("RouteMode InsideCoopDirectToEggPoint", "RouteMode=InsideCoopDirectToEggPoint")
		local result = self:StartNestEggPoint(now, debugState or "NoAccessPointsFallback")
		self:SetNestDebug(debugState or "NoAccessPointsFallback", self.NestAccessIndex or 0, self.CurrentEggPoint, "NoJumpLinkForHighEggPoint")
		return result
	end

	self:SetNestRouteMode("InsideCoopDirectToEggPoint")
	self:LogNest("RouteMode InsideCoopDirectToEggPoint", "RouteMode=InsideCoopDirectToEggPoint")
	return self:StartNestEggPoint(now, debugState or "GoNestEggPoint")
end

function Chicken:StartNestJumpUp(now)
	local link = self.CurrentNestJumpLink
	if not link then
		return self:CancelNestAttempt(now, "NoJumpLinkForHighEggPoint")
	end

	local cfg = HomeCfg.ChickenNest or {}
	local startPosition = self:GetNestGroundedPosition(link.Start.Position)
	local goalPosition = self:GetNestGroundedPosition(link.End.Position)
	local direction = getFlatDirection(goalPosition - startPosition) or getFlatDirection(self.LastMoveDirection) or Vector3.zAxis

	self.NestJumpStartPosition = startPosition
	self.NestJumpGoalPosition = goalPosition
	self.NestJumpDirection = direction
	self.NestJumpStartedAt = now
	self:SetState("NestJumpUp")
	self.NextDecision = now + (cfg.NestJumpDuration or 0.5)
	self:StopMovementTracks()
	self:SetNestJumpDebug("JumpingUp", link, "HighEggPoint", goalPosition)
	self:LogNest("NestJumpUpStarted " .. link.Name, "NestJumpUp started link=" .. link.Name)
	return true
end

function Chicken:StartOnNest(now)
	local cfg = HomeCfg.ChickenNest or {}
	self:SetState("OnNest")
	self:StopMovementTracks()
	self.OnNestUntil = now + self.Rng:NextNumber(cfg.StayOnNestAfterLayMin or 4, cfg.StayOnNestAfterLayMax or 10)
	self.NextDecision = self.OnNestUntil
	self:SetNestDebug("OnNest", self.NestAccessIndex or 0, "", "")
	self:SetNestJumpDebug("OnNest", self.CurrentNestJumpLink, "LaidEgg", self:GetCurrentPosition())
	return true
end

function Chicken:StartNestJumpDown(now)
	local link = self.CurrentNestJumpLink
	if not link then
		self:SetNestJumpDebug("", "", "", Vector3.zero)
		if self.Rng:NextNumber() < 0.5 then
			self:Idle(now)
		else
			self:PickPeck(now)
		end
		return true
	end

	local cfg = HomeCfg.ChickenNest or {}
	local startPosition = self:GetCurrentPosition()
	local goalPosition = self:GetNestGroundedPosition(link.Start.Position)
	local direction = getFlatDirection(goalPosition - startPosition) or getFlatDirection(self.LastMoveDirection) or Vector3.zAxis

	self.NestJumpStartPosition = startPosition
	self.NestJumpGoalPosition = goalPosition
	self.NestJumpDirection = direction
	self.NestJumpStartedAt = now
	self:SetState("NestJumpDown")
	self.NextDecision = now + (cfg.NestJumpDownDuration or 0.42)
	self:StopMovementTracks()
	self:SetNestJumpDebug("JumpingDown", link, "LeaveNest", goalPosition)
	return true
end

function Chicken:StartNestAccessRoute(point, now)
	self.NestAccessPoints = self:GetNestAccessPoints()
	if #self.NestAccessPoints == 0 then
		return false
	end

	self.CurrentEggPoint = point
	self.NestAccessIndex = 1
	self:LogAccessPointScan(self.NestAccessPoints)
	self:SetNestRouteMode("EnterCoopViaAccessPoints")
	self:LogNest("RouteMode EnterCoopViaAccessPoints", "RouteMode=EnterCoopViaAccessPoints")
	return self:SetNestMoveTarget(self.NestAccessPoints[1], 1, "GoNestAccess", now, "UsingAccessPoints")
end

function Chicken:AdvanceNestAccess(now)
	if self.State ~= "GoNestAccess" then
		local insideCoop = self:IsInsideChickenCoopZone()
		self:LogNest("FinishedAccessPoints " .. tostring(insideCoop), "Finished AccessPoints. Now insideCoop=" .. tostring(insideCoop))
		if not insideCoop then
			self:LogNest("OutsideCoopAfterAccessPoints", "OutsideCoopAfterAccessPoints", "[ChickenNest][FAIL]")
			return self:CancelNestAttempt(now, "OutsideCoopAfterAccessPoints")
		end

		return self:StartNestJumpOrEgg(now, "GoNestEggPoint")
	end

	local reachedPoint = self.NestTargetPart
	if reachedPoint then
		self:LogNest("ReachedAccessPoint " .. reachedPoint.Name, "Reached " .. reachedPoint.Name)
	end

	self.NestAccessIndex += 1
	local nextPoint = self.NestAccessPoints[self.NestAccessIndex]
	if nextPoint then
		self:SetNestRouteMode("EnterCoopViaAccessPoints")
		return self:SetNestMoveTarget(nextPoint, self.NestAccessIndex, "GoNestAccess", now, "UsingAccessPoints")
	end

	local insideCoop = self:IsInsideChickenCoopZone()
	self:LogNest("FinishedAccessPoints " .. tostring(insideCoop), "Finished AccessPoints. Now insideCoop=" .. tostring(insideCoop))
	if not insideCoop then
		self:LogNest("OutsideCoopAfterAccessPoints", "OutsideCoopAfterAccessPoints", "[ChickenNest][FAIL]")
		return self:CancelNestAttempt(now, "OutsideCoopAfterAccessPoints")
	end

	return self:StartNestJumpOrEgg(now, "GoNestEggPoint")
end

function Chicken:CancelNestAttempt(now, reason)
	local cfg = HomeCfg.Animals.Chicken
	local failedLink = self.CurrentNestJumpLink
	local stateBeforeCancel = self.State
	local nestDebug = self.Model and self.Model:GetAttribute("NestDebug") or ""
	local nestFailReason = reason or (self.Model and self.Model:GetAttribute("NestFailReason")) or "Failed"

	self:LogNest(
		"Cancel " .. tostring(reason or "Failed"),
		string.format("reason=%s state=%s NestDebug=%s NestFailReason=%s", tostring(reason or "Failed"), tostring(stateBeforeCancel), tostring(nestDebug), tostring(nestFailReason)),
		"[ChickenNest][CANCEL]"
	)

	self.CurrentEggPoint = nil
	self.NestAccessPoints = {}
	self.NestAccessIndex = 0
	self.NestTargetPart = nil
	self.NestCommitUntil = 0
	self.NestLastDistance = math.huge
	self.NestLastProgressAt = now
	self.CurrentNestJumpLink = nil
	self.NestJumpStartedAt = 0
	self.NestJumpStartPosition = nil
	self.NestJumpGoalPosition = nil
	self.NestJumpDirection = Vector3.zAxis
	self.OnNestUntil = 0
	self.NextEggAt = now + self.Rng:NextNumber(cfg.FailRetryMin or 8, cfg.FailRetryMax or 16)
	self:SetNestDebug("Failed", 0, "", reason or "Failed")
	self:SetNestJumpDebug("Failed", failedLink, reason or "Failed", Vector3.zero)

	if self.Rng:NextNumber() < 0.5 then
		self:Idle(now)
	else
		self:PickPeck(now)
	end

	return true
end

function Chicken:UpdateNestProgress(now, distanceToTarget)
	local cfg = HomeCfg.Animals.Chicken
	if (self.NestLastDistance or math.huge) == math.huge then
		self.NestLastDistance = distanceToTarget
		self.NestLastProgressAt = now
		return false
	end

	if distanceToTarget < (self.NestLastDistance or distanceToTarget) - 0.08 then
		self.NestLastDistance = distanceToTarget
		self.NestLastProgressAt = now
		return false
	end

	return now - (self.NestLastProgressAt or now) >= (cfg.NestFailStuckTime or 2.0)
end

function Chicken:SetupModel()
	self.Model:SetAttribute("OwnerId", self.Owner.UserId)
	self.Model:SetAttribute("OwnerName", self.Owner.Name)
	self.Model:SetAttribute("AnimalType", "Chicken")
	self.Model:SetAttribute("ChickenIndex", self.Index)
	self.Model:SetAttribute("ActiveEggs", self.Model:GetAttribute("ActiveEggs") or 0)

	self.Model:SetAttribute("Skittishness", math.floor(self.Personality.Skittishness * 100) / 100)
	self.Model:SetAttribute("Energy", math.floor(self.Personality.Energy * 100) / 100)
	self.Model:SetAttribute("Laziness", math.floor(self.Personality.Laziness * 100) / 100)
	self.Model:SetAttribute("Trust", math.floor(self.Personality.Trust * 100) / 100)
	self.Model:SetAttribute("EggRate", math.floor(self.Personality.EggRate * 100) / 100)
	self.Model:SetAttribute("ForcedExitHopDebug", "")
	self.Model:SetAttribute("ForcedExitHopReason", "")
	self.Model:SetAttribute("ForcedExitHopGoal", Vector3.zero)
	self.Model:SetAttribute("ForcedExitHopCooldownUntil", 0)
	self.Model:SetAttribute("NestDebug", "")
	self.Model:SetAttribute("NestRouteMode", "")
	self.Model:SetAttribute("NestAccessIndex", 0)
	self.Model:SetAttribute("NestTarget", "")
	self.Model:SetAttribute("NestFailReason", "")
	self.Model:SetAttribute("NestJumpDebug", "")
	self.Model:SetAttribute("NestJumpLink", "")
	self.Model:SetAttribute("NestJumpReason", "")
	self.Model:SetAttribute("NestJumpTarget", Vector3.zero)
	self.Model:SetAttribute("NestLastLog", "")

	local primary = self.Model.PrimaryPart

	if not primary or not primary:IsA("BasePart") then
		primary = self.Model:FindFirstChild("HumanoidRootPart", true)
	end

	if not primary or not primary:IsA("BasePart") then
		primary = self.Model:FindFirstChild("HumanodiRootPart", true)
	end

	if not primary or not primary:IsA("BasePart") then
		primary = self.Model:FindFirstChildWhichIsA("BasePart", true)
	end

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
		self.Model:PivotTo(CFrame.new(self.HomePosition + Vector3.new(0, 5, 0)))

		local pivot = self.Model:GetPivot()
		local boxCFrame, boxSize = self.Model:GetBoundingBox()
		local bottomY = boxCFrame.Position.Y - boxSize.Y * 0.5

		self.PivotToBottom = math.max(pivot.Position.Y - bottomY, 0.05)
	end
end

function Chicken:LoadAnimations()
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
		if typeof(animationId) ~= "string" or not animationId:match("^rbxassetid://%d+$") then
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

	loadTrack("Walk", HomeCfg.Anim.Chicken.Walk)
	loadTrack("Run", HomeCfg.Anim.Chicken.Run)
end

function Chicken:SetupCarryPrompt()
	local primary = self.Model.PrimaryPart
	if not primary then
		return
	end

	local prompt = primary:FindFirstChild("ChickenCarryPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ChickenCarryPrompt"
		prompt.Parent = primary
	end

	prompt.ActionText = "Cargar"
	prompt.ObjectText = "Gallina"
	prompt.MaxActivationDistance = HomeCfg.Animals.Chicken.CarryPromptDistance
	prompt.HoldDuration = HomeCfg.Animals.Chicken.CarryPromptHold
	prompt.RequiresLineOfSight = false
	prompt.Enabled = true

	self.CarryPrompt = prompt

	prompt.Triggered:Connect(function(player)
		if self.Service then
			self.Service:TryCarryChicken(player, self)
		end
	end)
end

function Chicken:SetCarryPromptEnabled(enabled)
	if self.CarryPrompt then
		self.CarryPrompt.Enabled = enabled
	end
end

function Chicken:SetState(state)
	self.State = state

	if self.Model and HomeCfg.Debug.SetAnimalAttributes then
		self.Model:SetAttribute("State", state)
	end
end

function Chicken:RefreshRaycastFilter(ignorePlayers)
	if ignorePlayers == nil then
		ignorePlayers = true
	end

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

	if ignorePlayers then
		for _, player in ipairs(Players:GetPlayers()) do
			if player.Character then
				table.insert(filter, player.Character)
			end
		end
	end

	self.RaycastParams.FilterDescendantsInstances = filter

	if self.ObstacleParams then
		self.ObstacleParams.FilterDescendantsInstances = filter
	end
end

function Chicken:CastObstacle(direction, distance)
	if not self.Model or not self.Model.PrimaryPart then
		return nil
	end

	local flatDirection = getFlatDirection(direction)
	if not flatDirection then
		return nil
	end

	local cfg = HomeCfg.Animals.Chicken
	local castDistance = distance or cfg.ObstacleCheckDistance
	local origin = self.Model.PrimaryPart.Position + Vector3.new(0, cfg.ObstacleCheckHeight, 0)
	local castDirection = flatDirection * castDistance

	self:RefreshRaycastFilter()

	local ok, result = pcall(function()
		return workspace:Spherecast(origin, cfg.ObstacleSphereRadius, castDirection, self.ObstacleParams)
	end)

	if ok then
		return result
	end

	return workspace:Raycast(origin, castDirection, self.ObstacleParams)
end

function Chicken:ResetProgressTracking()
	local position = self.Model and self.Model.PrimaryPart and self.Model.PrimaryPart.Position or self.HomePosition
	self.LastPosition = position
	self.LastProgressCheckAt = os.clock()
	self.LastTargetDistance = self.TargetPosition and flat(self.TargetPosition - position).Magnitude or math.huge
	self.StuckTime = 0
end

function Chicken:SetMoveTarget(position)
	if not position then
		return false
	end

	self.TargetPosition = position
	self:ResetProgressTracking()
	return true
end

function Chicken:HasLineOfSightToTarget(targetPosition)
	if not self.Model or not self.Model.PrimaryPart or not targetPosition then
		return false
	end

	local current = self.Model.PrimaryPart.Position
	local toTarget = targetPosition - current
	local distance = flat(toTarget).Magnitude
	if distance <= 0.5 then
		return true
	end

	local direction = getFlatDirection(toTarget)
	if not direction then
		return true
	end

	local cfg = HomeCfg.Animals.Chicken
	local hit = self:CastObstacle(direction, math.max(distance - 0.15, 0.2))
	return not hit or (hit.Distance or math.huge) >= distance - cfg.ObstacleSphereRadius
end

function Chicken:FindClearAlternativeDirection(direction, distance)
	local flatDirection = getFlatDirection(direction)
	if not flatDirection then
		return nil
	end

	local cfg = HomeCfg.Animals.Chicken
	local checkDistance = distance or cfg.ObstacleCheckDistance
	local angles = {
		math.rad(45),
		math.rad(-45),
		math.rad(90),
		math.rad(-90),
	}

	for _, angle in ipairs(angles) do
		local candidate = rotateFlatDirection(flatDirection, angle)
		if candidate and not self:CastObstacle(candidate, checkDistance) then
			return candidate
		end
	end

	return nil
end

function Chicken:PickShortClearTarget(preferredDirection)
	if not self.Model or not self.Model.PrimaryPart then
		return nil
	end

	local current = self.Model.PrimaryPart.Position
	local zone = self:GetActiveContainmentZone(current)
	local baseDirection = getFlatDirection(preferredDirection) or getFlatDirection(self.LastMoveDirection)
	local cfg = HomeCfg.Animals.Chicken

	for attempt = 1, 8 do
		local direction = nil
		if attempt == 1 and baseDirection then
			direction = self:FindClearAlternativeDirection(baseDirection, cfg.ObstacleCheckDistance) or baseDirection
		else
			direction = rotateFlatDirection(Vector3.zAxis, self.Rng:NextNumber(-math.pi, math.pi))
		end

		if direction and not self:CastObstacle(direction, cfg.ObstacleCheckDistance) then
			local target = current + direction * self.Rng:NextNumber(2.0, 4.5)
			if (not zone or pointInsidePartXZ(target, zone)) and self:HasLineOfSightToTarget(target) then
				return target
			end
		end
	end

	if baseDirection then
		local fallback = current + baseDirection * 1.8
		if zone and not pointInsidePartXZ(fallback, zone) then
			return current
		end

		return fallback
	end

	return current
end

function Chicken:PickReachableRoamTarget(maxAttempts)
	if not self.Model or not self.Model.PrimaryPart then
		return self.HomePosition
	end

	local attempts = maxAttempts or 8
	local current = self.Model.PrimaryPart.Position
	local zone = self:GetActiveContainmentZone(current)

	if zone then
		for _ = 1, attempts do
			local candidate = randomPointInPartXZ(self.Rng, zone)
			if self:HasLineOfSightToTarget(candidate) then
				return candidate
			end
		end
	end

	return self:PickShortClearTarget(self.LastMoveDirection)
end

function Chicken:IsEscapeState()
	return self.State == "EscapePath"
		or self.State == "EscapeStepHop"
		or self.State == "EscapeRecover"
		or self.State == "EscapeToExit"
		or self.State == "EscapeDoorway"
		or self.State == "ForcedExitHop"
end

function Chicken:SetEscapeDebug(reason, target, blockedBy)
	if not self.Model then
		return
	end

	self.Model:SetAttribute("EscapeReason", reason or "")
	self.Model:SetAttribute("EscapeTarget", typeof(target) == "Vector3" and target or (self.TargetPosition or Vector3.zero))
	self.Model:SetAttribute("EscapeWaypointIndex", self.EscapeWaypointIndex or 0)
	self.Model:SetAttribute("EscapeBlockedBy", blockedBy or "")
	self.Model:SetAttribute("EscapeLastRepath", self.LastEscapePathAt or 0)
end

function Chicken:SetForcedExitHopDebug(debugState, reason, goal)
	if not self.Model then
		return
	end

	self.Model:SetAttribute("ForcedExitHopDebug", debugState or "")
	self.Model:SetAttribute("ForcedExitHopReason", reason or "")
	self.Model:SetAttribute("ForcedExitHopGoal", typeof(goal) == "Vector3" and goal or (self.ForcedExitHopGoal or Vector3.zero))
	self.Model:SetAttribute("ForcedExitHopCooldownUntil", self.ForcedExitHopCooldownUntil or 0)
end

function Chicken:IsEscapeBlockingHit(hit, direction)
	if not hit then
		return false
	end

	local flatDirection = getFlatDirection(direction)
	if not flatDirection then
		return true
	end

	local normal = getFlatDirection(hit.Normal)
	if not normal then
		return true
	end

	return flatDirection:Dot(normal) < -0.55
end

function Chicken:UpdateEscapeProgress(now, distanceToWaypoint)
	if (self.EscapeLastDistance or math.huge) == math.huge then
		self.EscapeLastDistance = distanceToWaypoint
		self.EscapeLastProgressAt = now
		return true
	end

	if distanceToWaypoint < (self.EscapeLastDistance or distanceToWaypoint) - 0.1 then
		self.EscapeLastDistance = distanceToWaypoint
		self.EscapeLastProgressAt = now
		return true
	end

	return false
end

function Chicken:FindEscapeDoorwayDirection(direction, distance)
	local flatDirection = getFlatDirection(direction)
	if not flatDirection then
		return nil
	end

	local angles = {
		math.rad(18),
		math.rad(-18),
		math.rad(32),
		math.rad(-32),
		math.rad(50),
		math.rad(-50),
	}

	for _, angle in ipairs(angles) do
		local candidate = rotateFlatDirection(flatDirection, angle)
		if candidate then
			local hit = self:CastObstacle(candidate, distance)
			if not hit or not self:IsEscapeBlockingHit(hit, candidate) then
				return candidate
			end
		end
	end

	return nil
end

function Chicken:IsForcedExitHopCandidateState()
	return self.State == "EscapePath"
		or self.State == "EscapeToExit"
		or self.State == "EscapeDoorway"
		or self.State == "EscapeRecover"
end

function Chicken:GetCurrentEscapeTarget()
	if self.EscapeWaypoints and self.EscapeWaypointIndex and self.EscapeWaypoints[self.EscapeWaypointIndex] then
		return self.EscapeWaypoints[self.EscapeWaypointIndex].Position
	end

	return self.TargetPosition
end

function Chicken:GetForcedExitHopDirection(preferredDirection)
	if not self.Model or not self.Model.PrimaryPart then
		return nil, nil, "NoRoot"
	end

	local cfg = HomeCfg.ChickenEscape or {}
	local current = self.Model.PrimaryPart.Position
	local minDistance = cfg.ForcedExitHopMinDoorDistance or 2.0
	local maxDistance = cfg.ForcedExitHopMaxDoorDistance or 9.0
	local bestTarget = nil
	local bestDistance = math.huge

	for _, target in ipairs(self:GetManualEscapeTargets()) do
		local distance = flat(target - current).Magnitude
		if distance >= minDistance and distance <= maxDistance and distance < bestDistance then
			bestTarget = target
			bestDistance = distance
		end
	end

	if bestTarget then
		return getFlatDirection(bestTarget - current), bestTarget, "ManualExit"
	end

	local escapeTarget = self:GetCurrentEscapeTarget()
	if escapeTarget then
		local distance = flat(escapeTarget - current).Magnitude
		if distance >= minDistance and distance <= maxDistance then
			return getFlatDirection(escapeTarget - current), escapeTarget, "EscapeTarget"
		end
	end

	local direction = getFlatDirection(preferredDirection) or getFlatDirection(self.LastMoveDirection)
	if direction then
		return direction, current + direction * minDistance, "EscapeDirection"
	end

	return nil, nil, "NoDirection"
end

function Chicken:GetForcedExitHopGoal(startPosition, direction)
	local cfg = HomeCfg.ChickenEscape or {}
	local flatDirection = getFlatDirection(direction)
	if not flatDirection then
		return nil
	end

	local rawGoal = startPosition + flatDirection * (cfg.ForcedExitHopDistance or 5.0)
	self:RefreshRaycastFilter(true)

	local origin = rawGoal + Vector3.new(0, 6, 0)
	local result = workspace:Raycast(origin, Vector3.new(0, -16, 0), self.RaycastParams)
	if self:IsValidGroundHit(result) then
		return self:GetGroundedFromHit(rawGoal, result)
	end

	return rawGoal
end

function Chicken:TryStartForcedExitHop(now, preferredDirection, reason)
	local cfg = HomeCfg.ChickenEscape or {}
	if not cfg.ForcedExitHopEnabled then
		self:SetForcedExitHopDebug("Rejected", "Disabled", nil)
		return false
	end

	if not self:CanUseEscape() then
		self:SetForcedExitHopDebug("Rejected", "CannotUseEscape", nil)
		return false
	end

	if not self:IsForcedExitHopCandidateState() then
		self:SetForcedExitHopDebug("Rejected", "WrongState", nil)
		return false
	end

	local current = self:GetCurrentPosition()
	if not self:IsInInteriorZone(current) then
		self:SetForcedExitHopDebug("Rejected", "NotInside", nil)
		return false
	end

	if now < (self.ForcedExitHopCooldownUntil or 0) then
		self:SetForcedExitHopDebug("Rejected", "Cooldown", nil)
		return false
	end

	local stuckFor = now - (self.EscapeLastProgressAt or now)
	if stuckFor < (cfg.ForcedExitHopStuckTime or 0.6) then
		self:SetForcedExitHopDebug("Rejected", "NotStuck", nil)
		return false
	end

	local direction, doorTarget, directionReason = self:GetForcedExitHopDirection(preferredDirection)
	if not direction then
		self:SetForcedExitHopDebug("Rejected", directionReason or "NoDirection", doorTarget)
		return false
	end

	local goal = self:GetForcedExitHopGoal(current, direction)
	if not goal then
		self:SetForcedExitHopDebug("Rejected", "NoGoal", doorTarget)
		return false
	end

	self.ForcedExitHopStart = current
	self.ForcedExitHopGoal = goal
	self.ForcedExitHopDirection = direction
	self.ForcedExitHopStartedAt = now
	self.ForcedExitHopCooldownUntil = now + (cfg.ForcedExitHopCooldown or 1.5)
	self.BurstFinishAt = 0
	self:SetState("ForcedExitHop")
	self.NextDecision = now + (cfg.ForcedExitHopDuration or 0.45)
	self:StopMovementTracks()
	self:SetForcedExitHopDebug("Started", reason or directionReason or "StuckNearDoor", goal)
	self:SetEscapeDebug("ForcedExitHop", goal, "")
	return true
end

function Chicken:CanUseEscape()
	local cfg = HomeCfg.ChickenEscape or {}
	if not cfg.Enabled then
		return false
	end

	return not self.CarriedBy and self.State ~= "Carried" and self.State ~= "LayingEgg"
end

function Chicken:IsEscapeCandidateState()
	return self.State == "AvoidPlayer"
		or self.State == "BurstRun"
		or self.State == "ReturnHome"
		or self.State == "Roam"
end

function Chicken:ShouldUseEscapeFallback(now)
	if not self:CanUseEscape() or not self:IsEscapeCandidateState() then
		return false
	end

	if self.State == "AvoidPlayer" then
		return true
	end

	if self:IsInInteriorZone() then
		return true
	end

	return (self.ObstacleHits or 0) >= 2 or (now - (self.LastObstacleAt or 0)) <= 1.2
end

function Chicken:GetManualEscapeTargets()
	local targets = {}
	local names = { "ChickenExitPoints", "ExitPoints", "ChickenJumpLinks", "JumpLinks" }

	for _, name in ipairs(names) do
		local container = self.House:FindFirstChild(name, true)
		if container then
			if container:IsA("BasePart") then
				table.insert(targets, container.Position)
			else
				for _, obj in ipairs(container:GetDescendants()) do
					if obj:IsA("BasePart") then
						table.insert(targets, obj.Position)
					end
				end
			end
		end
	end

	return targets
end

function Chicken:GetGroundedEscapeTarget(position)
	self:RefreshRaycastFilter(true)

	local origin = Vector3.new(position.X, position.Y + 10, position.Z)
	local result = workspace:Raycast(origin, Vector3.new(0, -60, 0), self.RaycastParams)
	if self:IsValidGroundHit(result) then
		local cfg = HomeCfg.Animals.Chicken
		return Vector3.new(
			position.X,
			result.Position.Y + self.PivotToBottom + cfg.GroundClearance + cfg.ModelYOffset,
			position.Z
		)
	end

	return nil
end

function Chicken:GetEscapeCandidateTargets(preferredDirection)
	local cfg = HomeCfg.ChickenEscape or {}
	local current = self:GetCurrentPosition()
	local candidates = {}

	for _, target in ipairs(self:GetManualEscapeTargets()) do
		table.insert(candidates, target)
	end

	local nearestRoot = self:GetNearestPlayer()
	local toPlayer = nearestRoot and getFlatDirection(nearestRoot.Position - current)
	local preferred = getFlatDirection(preferredDirection)
	local lastMove = getFlatDirection(self.LastMoveDirection)
	local directions = {}

	local function addDirection(direction)
		local flatDirection = getFlatDirection(direction)
		if not flatDirection then
			return
		end

		for _, existing in ipairs(directions) do
			if existing:Dot(flatDirection) > 0.94 then
				return
			end
		end

		table.insert(directions, flatDirection)
	end

	if nearestRoot and self:IsInInteriorZone(current) and toPlayer then
		addDirection(rotateFlatDirection(toPlayer, math.rad(35)))
		addDirection(rotateFlatDirection(toPlayer, math.rad(-35)))
		addDirection(rotateFlatDirection(toPlayer, math.rad(70)))
		addDirection(rotateFlatDirection(toPlayer, math.rad(-70)))
		addDirection(toPlayer)
	end

	addDirection(preferred)
	addDirection(lastMove)
	addDirection(rotateFlatDirection(preferred or lastMove or Vector3.zAxis, math.rad(45)))
	addDirection(rotateFlatDirection(preferred or lastMove or Vector3.zAxis, math.rad(-45)))
	addDirection(Vector3.zAxis)

	local distance = cfg.EscapeTargetDistance or 18
	local attempts = cfg.EscapeTargetAttempts or 8
	for attempt = 1, attempts do
		local direction = directions[attempt]
			or rotateFlatDirection(directions[1] or Vector3.zAxis, self.Rng:NextNumber(-math.pi, math.pi))
			or Vector3.zAxis

		local target = current + direction * self.Rng:NextNumber(distance * 0.7, distance * 1.15)
		local grounded = self:GetGroundedEscapeTarget(target)
		if grounded then
			table.insert(candidates, grounded)
		end
	end

	return candidates
end

function Chicken:StartEscapeRecover(now, reason)
	self.EscapeWaypoints = nil
	self.EscapeWaypointIndex = 0
	self.EscapeCommitUntil = 0
	self.EscapeLastDistance = math.huge
	self.EscapeLastProgressAt = now
	self.EscapeRepathReason = reason or "Recover"
	self.BurstFinishAt = 0
	self:StopMovementTracks()
	self:SetState("EscapeRecover")
	self.EscapeRecoverUntil = now + self.Rng:NextNumber(1.0, 1.6)
	self.NextDecision = self.EscapeRecoverUntil
	self:ResetProgressTracking()
	self:SetEscapeDebug(self.EscapeRepathReason, self.TargetPosition, "")
	return true
end

function Chicken:TryStartStepHop(now, preferredDirection)
	local cfg = HomeCfg.ChickenEscape or {}
	if not cfg.StepHopEnabled or not self:CanUseEscape() or not self.Model or not self.Model.PrimaryPart then
		return false
	end

	local direction = getFlatDirection(preferredDirection) or getFlatDirection(self.LastMoveDirection)
	if not direction then
		return false
	end

	local current = self.Model.PrimaryPart.Position
	local distance = cfg.StepHopDistance or 3
	local maxHeight = cfg.StepHopMaxHeight or 2.5

	self:RefreshRaycastFilter(true)

	local lowOrigin = current + Vector3.new(0, 0.45, 0)
	local lowHit = workspace:Raycast(lowOrigin, direction * distance, self.ObstacleParams)
	if not lowHit then
		return false
	end

	local highOrigin = current + Vector3.new(0, maxHeight + 0.35, 0)
	local highHit = workspace:Raycast(highOrigin, direction * distance, self.ObstacleParams)
	if highHit then
		return false
	end

	local landingXZ = current + direction * distance
	local landingOrigin = landingXZ + Vector3.new(0, maxHeight + 4, 0)
	local groundHit = workspace:Raycast(landingOrigin, Vector3.new(0, -(maxHeight + 8), 0), self.RaycastParams)
	if not self:IsValidGroundHit(groundHit) then
		return false
	end

	local animalCfg = HomeCfg.Animals.Chicken
	self.StepHopStart = current
	self.StepHopGoal = Vector3.new(
		landingXZ.X,
		groundHit.Position.Y + self.PivotToBottom + animalCfg.GroundClearance + animalCfg.ModelYOffset,
		landingXZ.Z
	)
	self.StepHopDirection = direction
	self.StepHopStartedAt = now
	self.EscapeRepathReason = "StepHop"
	self.BurstFinishAt = 0
	self:SetState("EscapeStepHop")
	self.NextDecision = now + (cfg.StepHopDuration or 0.38)
	self:StopMovementTracks()
	self:SetEscapeDebug("StepHop", self.StepHopGoal, "")
	return true
end

function Chicken:StartEscapePath(now, preferredDirection, reason)
	local cfg = HomeCfg.ChickenEscape or {}
	if not self:CanUseEscape() then
		return false
	end

	if now - (self.LastEscapePathAt or -math.huge) < (cfg.EscapePathCooldown or 2.5) then
		return self:StartEscapeRecover(now, "PathCooldown")
	end

	if self:TryStartStepHop(now, preferredDirection) then
		return true
	end

	local current = self:GetCurrentPosition()
	local candidates = self:GetEscapeCandidateTargets(preferredDirection)
	self.LastEscapePathAt = now
	self.EscapeRepathReason = reason or "PathRequest"
	self:SetEscapeDebug(self.EscapeRepathReason, candidates[1], "")

	for _, target in ipairs(candidates) do
		if consumePathRequest(now) then
			local path = PathfindingService:CreatePath({
				AgentRadius = 1.2,
				AgentHeight = 2.5,
				AgentCanJump = false,
				WaypointSpacing = 3,
			})

			local ok = pcall(function()
				path:ComputeAsync(current, target)
			end)

			if ok and path.Status == Enum.PathStatus.Success then
				local waypoints = path:GetWaypoints()
				if #waypoints >= 2 then
					self.EscapeWaypoints = waypoints
					self.EscapeWaypointIndex = 2
					self.EscapePathStartedAt = now
					self.EscapeCommitUntil = now + 1.5
					self.EscapeLastProgressAt = now
					self.EscapeLastDistance = math.huge
					self.BurstFinishAt = 0
					self.Speed = math.max(self.Rng:NextNumber(HomeCfg.Animals.Chicken.AvoidSpeedMin, HomeCfg.Animals.Chicken.AvoidSpeedMax) * self.Personality.Energy, HomeCfg.Animals.Chicken.AvoidSpeedMin)
					self:SetState("EscapePath")
					self.NextDecision = now + (cfg.EscapePathTimeout or 6)
					self:ResetProgressTracking()
					self:SetEscapeDebug(self.EscapeRepathReason, waypoints[self.EscapeWaypointIndex].Position, "")
					return true
				end
			end
		else
			self:SetEscapeDebug("PathThrottle", target, "")
			break
		end
	end

	return self:StartEscapeRecover(now, "PathFailed")
end

function Chicken:StepEscapePath(dt, now)
	local cfg = HomeCfg.ChickenEscape or {}
	if not self.EscapeWaypoints or now - (self.EscapePathStartedAt or now) > (cfg.EscapePathTimeout or 6) then
		return self:StartEscapeRecover(now, "PathTimeout")
	end

	local waypoint = self.EscapeWaypoints[self.EscapeWaypointIndex]
	if not waypoint then
		return self:StartEscapeRecover(now, "PathMissingWaypoint")
	end

	local target = waypoint.Position
	local current = self:GetCurrentPosition()
	local toTarget = target - current
	local dist = flat(toTarget).Magnitude
	local direction = getFlatDirection(toTarget)

	self:SetEscapeDebug(self.EscapeRepathReason ~= "" and self.EscapeRepathReason or "FollowingPath", target, "")

	if not direction or dist <= 0.45 then
		self.EscapeWaypointIndex += 1
		self.EscapeLastDistance = math.huge
		self.EscapeLastProgressAt = now
		if self.EscapeWaypointIndex > #self.EscapeWaypoints then
			return self:StartEscapeRecover(now, "PathComplete")
		end

		self:SetEscapeDebug(self.EscapeRepathReason ~= "" and self.EscapeRepathReason or "FollowingPath", self.EscapeWaypoints[self.EscapeWaypointIndex].Position, "")
		return true
	end

	self:UpdateEscapeProgress(now, dist)
	if self:TryStartForcedExitHop(now, direction, "StuckNearDoor") then
		return true
	end

	local step = math.min(self.Speed * dt, dist)
	local castDistance = math.max(step + HomeCfg.Animals.Chicken.ObstacleSphereRadius, 0.9)
	local blockingHit = self:CastObstacle(direction, castDistance)
	local isBlocking = blockingHit
		and (blockingHit.Distance or 0) <= step + HomeCfg.Animals.Chicken.ObstacleSphereRadius
		and self:IsEscapeBlockingHit(blockingHit, direction)

	if isBlocking then
		local doorwayDirection = self:FindEscapeDoorwayDirection(direction, castDistance)
		if doorwayDirection then
			direction = doorwayDirection
			self:SetEscapeDebug("DoorwaySide", target, "")
		else
			local blockedBy = blockingHit.Instance and blockingHit.Instance:GetFullName() or "Obstacle"
			self:SetEscapeDebug("PathBlocked", target, blockedBy)

			if self:TryStartStepHop(now, direction) then
				return true
			end

			local stuckFor = now - (self.EscapeLastProgressAt or now)
			if now < (self.EscapeCommitUntil or 0) or stuckFor < 2.0 then
				self:StopMovementTracks()
				return true
			end

			if now - (self.LastEscapePathAt or -math.huge) >= (cfg.EscapePathCooldown or 2.5) then
				return self:StartEscapePath(now, direction, "BlockedRepath")
			end

			self:StopMovementTracks()
			return true
		end
	end

	self:SetWorldPosition(current + direction * step, direction, dt)
	self:PlayRun(self.Speed)
	return true
end

function Chicken:StepEscapeStepHop(dt, now)
	local cfg = HomeCfg.ChickenEscape or {}
	local duration = cfg.StepHopDuration or 0.38
	local elapsed = now - (self.StepHopStartedAt or now)
	local alpha = math.clamp(elapsed / duration, 0, 1)
	local startPosition = self.StepHopStart or self:GetCurrentPosition()
	local goalPosition = self.StepHopGoal or startPosition
	local direction = getFlatDirection(self.StepHopDirection) or getFlatDirection(self.LastMoveDirection) or Vector3.zAxis
	local horizontal = startPosition:Lerp(goalPosition, alpha)
	local height = math.sin(alpha * math.pi) * (cfg.StepHopMaxHeight or 2.5)
	local position = horizontal + Vector3.new(0, height, 0)

	self.LastMoveDirection = direction
	self.Model:PivotTo(CFrame.lookAt(position, position + direction, Vector3.yAxis))

	if alpha >= 1 then
		self:SetWorldPosition(goalPosition, direction, dt)
		return self:StartEscapeRecover(now, "StepHopComplete")
	end

	return true
end

function Chicken:StepForcedExitHop(dt, now)
	local cfg = HomeCfg.ChickenEscape or {}
	local duration = cfg.ForcedExitHopDuration or 0.45
	local elapsed = now - (self.ForcedExitHopStartedAt or now)
	local alpha = math.clamp(elapsed / duration, 0, 1)
	local startPosition = self.ForcedExitHopStart or self:GetCurrentPosition()
	local goalPosition = self.ForcedExitHopGoal or startPosition
	local direction = getFlatDirection(self.ForcedExitHopDirection) or getFlatDirection(self.LastMoveDirection) or Vector3.zAxis
	local horizontal = startPosition:Lerp(goalPosition, alpha)
	local arc = math.sin(alpha * math.pi) * (cfg.ForcedExitHopArcHeight or 1.6)
	local position = horizontal + Vector3.new(0, arc, 0)

	self.LastMoveDirection = direction
	self.Model:PivotTo(CFrame.lookAt(position, position + direction, Vector3.yAxis))
	self:PlayRun(self.Speed)

	if alpha >= 1 then
		self:SetWorldPosition(goalPosition, direction, dt)
		self.ForcedExitHopStart = nil
		self.ForcedExitHopGoal = nil

		if self:IsInInteriorZone(self:GetCurrentPosition()) then
			self.EscapeLastProgressAt = now
			self.EscapeLastDistance = math.huge
			self:SetForcedExitHopDebug("Finished", "StillInside", goalPosition)
			return self:StartEscapeRecover(now, "ForcedExitHopStillInside")
		end

		self:SetForcedExitHopDebug("Finished", "Exited", goalPosition)
		return self:StartEscapeRecover(now, "ForcedExitHopComplete")
	end

	return true
end

function Chicken:StepNestJumpUp(dt, now)
	local cfg = HomeCfg.ChickenNest or {}
	local duration = cfg.NestJumpDuration or 0.5
	local elapsed = now - (self.NestJumpStartedAt or now)
	local alpha = math.clamp(elapsed / duration, 0, 1)
	local startPosition = self.NestJumpStartPosition or self:GetCurrentPosition()
	local goalPosition = self.NestJumpGoalPosition or startPosition
	local direction = getFlatDirection(self.NestJumpDirection) or getFlatDirection(goalPosition - startPosition) or Vector3.zAxis
	local horizontal = startPosition:Lerp(goalPosition, alpha)
	local arc = math.sin(alpha * math.pi) * (cfg.NestJumpArcHeight or 2.0)
	local position = horizontal + Vector3.new(0, arc, 0)

	self.LastMoveDirection = direction
	self.Model:PivotTo(CFrame.lookAt(position, position + direction, Vector3.yAxis))
	self:PlayWalk(self.Speed)

	if alpha >= 1 then
		local grounded = self:GetNestGroundedPosition(goalPosition)
		self.LastMoveDirection = direction
		self.Model:PivotTo(CFrame.lookAt(grounded, grounded + direction, Vector3.yAxis))
		self:SetNestJumpDebug("ArrivedUp", self.CurrentNestJumpLink, "HighEggPoint", grounded)
		local distanceToEgg = self.CurrentEggPoint and (self.CurrentEggPoint.Position - grounded).Magnitude or 0
		self:LogNest("NestJumpUpFinished", string.format("NestJumpUp finished. DistanceToEgg=%.2f", distanceToEgg))
		return self:StartNestEggPoint(now, "GoNestEggPoint")
	end

	return true
end

function Chicken:StepOnNest(dt, now)
	self:StopMovementTracks()
	local current = self:GetCurrentPosition()
	local direction = getFlatDirection(self.LastMoveDirection) or Vector3.zAxis
	self.Model:PivotTo(CFrame.lookAt(current, current + direction, Vector3.yAxis))

	if now >= (self.OnNestUntil or 0) then
		return self:StartNestJumpDown(now)
	end

	return true
end

function Chicken:StepNestJumpDown(dt, now)
	local cfg = HomeCfg.ChickenNest or {}
	local duration = cfg.NestJumpDownDuration or 0.42
	local elapsed = now - (self.NestJumpStartedAt or now)
	local alpha = math.clamp(elapsed / duration, 0, 1)
	local startPosition = self.NestJumpStartPosition or self:GetCurrentPosition()
	local goalPosition = self.NestJumpGoalPosition or startPosition
	local direction = getFlatDirection(self.NestJumpDirection) or getFlatDirection(goalPosition - startPosition) or Vector3.zAxis
	local horizontal = startPosition:Lerp(goalPosition, alpha)
	local arc = math.sin(alpha * math.pi) * (cfg.NestJumpArcHeight or 2.0)
	local position = horizontal + Vector3.new(0, arc, 0)

	self.LastMoveDirection = direction
	self.Model:PivotTo(CFrame.lookAt(position, position + direction, Vector3.yAxis))
	self:PlayWalk(self.Speed)

	if alpha >= 1 then
		local grounded = self:GetNestGroundedPosition(goalPosition)
		self.LastMoveDirection = direction
		self.Model:PivotTo(CFrame.lookAt(grounded, grounded + direction, Vector3.yAxis))
		self.NestJumpStartPosition = nil
		self.NestJumpGoalPosition = nil
		self.CurrentNestJumpLink = nil
		self.OnNestUntil = 0
		self:SetNestJumpDebug("FinishedDown", "", "LeaveNest", grounded)
		self:SetNestDebug("", 0, "", "")

		if self.Rng:NextNumber() < 0.5 then
			self:Idle(now)
		else
			self:PickPeck(now)
		end
	end

	return true
end

function Chicken:StepEscapeRecover(dt, now)
	self:StopMovementTracks()
	local current = self:GetCurrentPosition()
	self:SetWorldPosition(current, self.LastMoveDirection, dt)
	self:SetEscapeDebug(self.EscapeRepathReason ~= "" and self.EscapeRepathReason or "Recover", self.TargetPosition, "")

	if self:IsInInteriorZone(current) then
		local nearestRoot, nearestDistance = self:GetNearestPlayer()
		if nearestRoot and nearestDistance <= self:GetAvoidDistance() then
			local escapeDirection = getFlatDirection(nearestRoot.Position - current) or getFlatDirection(self.LastMoveDirection) or Vector3.zAxis
			if self:TryStartForcedExitHop(now, escapeDirection, "RecoverStillInside") then
				return true
			end

			if now >= (self.EscapeRecoverUntil or 0) then
				self.EscapeRecoverUntil = now + 0.35
				self.NextDecision = self.EscapeRecoverUntil
			end

			return true
		end
	end

	if now >= (self.EscapeRecoverUntil or 0) then
		self.EscapeWaypoints = nil
		self.EscapeWaypointIndex = 0
		if self.Rng:NextNumber() < 0.55 then
			self:Idle(now)
		else
			self:PickPeck(now)
		end
	end

	return true
end

function Chicken:UpdateTargetProgress(now, distanceToTarget)
	if self.CarriedBy or self.State == "LayingEgg" or self.State == "SafeInCoop" or self.State == "Carried" then
		self:ResetProgressTracking()
		return false
	end

	if not self.LastProgressCheckAt or now - self.LastProgressCheckAt < 0.35 then
		return false
	end

	local current = self.Model.PrimaryPart.Position
	local elapsed = now - self.LastProgressCheckAt
	local previousDistance = self.LastTargetDistance or distanceToTarget
	local improved = distanceToTarget < previousDistance - 0.12

	if improved then
		self.StuckTime = 0
	else
		self.StuckTime += elapsed
	end

	self.LastPosition = current
	self.LastTargetDistance = distanceToTarget
	self.LastProgressCheckAt = now

	return self.StuckTime >= (self.StuckThreshold or 1.25)
end

function Chicken:ResolveStuck(now, preferredDirection)
	if self.CarriedBy or self.State == "LayingEgg" or self.State == "Carried" then
		return false
	end

	if self:ShouldUseEscapeFallback(now) then
		return self:StartEscapePath(now, preferredDirection, "StuckFallback")
	end

	if self.State == "GoLayEgg" then
		local point = self:PickEggPoint()
		if point then
			self.CurrentEggPoint = point
			self:SetMoveTarget(point.Position)
			self.NextDecision = now + 6
			return true
		end

		self.CurrentEggPoint = nil
		self.NextEggAt = now + self.Rng:NextNumber(8, 16)
		self:Idle(now)
		return true
	end

	if self.State == "AvoidPlayer" then
		local lateralTarget = self:PickShortClearTarget(preferredDirection)
		if lateralTarget and flat(lateralTarget - self:GetCurrentPosition()).Magnitude > 0.25 then
			self:SetMoveTarget(lateralTarget)
			self.NextDecision = now + self.Rng:NextNumber(0.7, 1.4)
			return true
		end

		if self:IsInInteriorZone() then
			return self:StartEscapePath(now, preferredDirection, "InteriorAvoidStuck")
		end
	end

	if self.State == "Roam" or self.State == "ReturnHome" or self.State == "BurstRun" then
		local target = self:PickReachableRoamTarget(8)
		if target then
			self:SetMoveTarget(target)
			if self.State ~= "BurstRun" then
				local cfg = HomeCfg.Animals.Chicken
				self.NextDecision = now + self.Rng:NextNumber(cfg.MoveMin, cfg.MoveMax)
			end
			return true
		end
	end

	return false
end

function Chicken:GetObstacleAvoidanceDirection(direction, now)
	if self.CarriedBy or self.State == "LayingEgg" or self.State == "SafeInCoop" then
		return direction, false
	end

	local flatDirection = getFlatDirection(direction)
	if not flatDirection then
		return nil, false
	end

	local hit = self:CastObstacle(flatDirection)
	if not hit then
		if now and now - (self.LastObstacleAt or 0) > 1.0 then
			self.ObstacleHits = 0
		end
		return flatDirection, false
	end

	self.ObstacleHits = (self.ObstacleHits or 0) + 1
	self.LastObstacleAt = now or os.clock()

	local alternative = self:FindClearAlternativeDirection(flatDirection)
	if alternative then
		return alternative, true
	end

	return nil, true
end

function Chicken:IsValidGroundHit(result)
	return result and result.Normal.Y > 0.45
end

function Chicken:GetGroundedFromHit(position, result)
	local cfg = HomeCfg.Animals.Chicken
	return Vector3.new(
		position.X,
		result.Position.Y + self.PivotToBottom + cfg.GroundClearance + cfg.ModelYOffset,
		position.Z
	)
end

function Chicken:GetGroundedPosition(position)
	local cfg = HomeCfg.Animals.Chicken

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

function Chicken:GetDropGroundedPosition(position)
	local cfg = HomeCfg.Animals.Chicken

	self:RefreshRaycastFilter()

	local origin = Vector3.new(position.X, position.Y + 2, position.Z)
	local result = workspace:Raycast(origin, Vector3.new(0, -8, 0), self.RaycastParams)
	if self:IsValidGroundHit(result) then
		return self:GetGroundedFromHit(position, result)
	end

	return Vector3.new(position.X, position.Y + self.PivotToBottom + cfg.ModelYOffset, position.Z)
end

function Chicken:SetWorldPosition(position, direction, dt)
	if not self.Model or not self.Model.PrimaryPart or self.CarriedBy then
		return
	end

	local grounded = self:GetGroundedPosition(position)

	local targetDirection = direction or self.LastMoveDirection
	if self.State == "LayingEgg" or self.State == "SafeInCoop" then
		targetDirection = self.LastMoveDirection
	end

	targetDirection = getFlatDirection(targetDirection) or getFlatDirection(self.LastMoveDirection) or Vector3.zAxis
	local currentDirection = getFlatDirection(self.LastMoveDirection) or targetDirection

	local cfg = HomeCfg.Animals.Chicken
	local responsiveness = cfg.TurnResponsiveness or 8
	if self.State == "AvoidPlayer" or self.State == "BurstRun" or self.State == "EscapePath" or self.State == "EscapeStepHop" then
		responsiveness = cfg.RunTurnResponsiveness or 12
	end

	local alpha = 1 - math.exp(-responsiveness * (dt or 1))
	local smoothedDirection = currentDirection:Lerp(targetDirection, alpha)
	if smoothedDirection.Magnitude > 0.001 then
		smoothedDirection = smoothedDirection.Unit
	else
		smoothedDirection = targetDirection
	end

	self.LastMoveDirection = smoothedDirection
	self.Model:PivotTo(CFrame.lookAt(grounded, grounded + smoothedDirection, Vector3.yAxis))
end

function Chicken:StopMovementTracks()
	for _, trackName in ipairs({ "Walk", "Run" }) do
		local track = self.Tracks[trackName]
		if track and track.IsPlaying then
			track:Stop(0.12)
		end
	end
end

function Chicken:PlayWalk(speed)
	local runTrack = self.Tracks.Run
	if runTrack and runTrack.IsPlaying then
		runTrack:Stop(0.08)
	end

	local track = self.Tracks.Walk
	if not track then
		return
	end

	if not track.IsPlaying then
		track:Play(0.12)
	end

	local baseSpeed = HomeCfg.Animals.Chicken.WalkAnimBaseSpeed
	local adjusted = math.clamp(speed / baseSpeed, HomeCfg.Animals.Chicken.WalkAnimMin, HomeCfg.Animals.Chicken.WalkAnimMax)

	track:AdjustSpeed(adjusted)
end

function Chicken:PlayRun(speed)
	local walkTrack = self.Tracks.Walk
	if walkTrack and walkTrack.IsPlaying then
		walkTrack:Stop(0.08)
	end

	local track = self.Tracks.Run
	if not track then
		return
	end

	if not track.IsPlaying then
		track:Play(0.08)
	end

	local baseSpeed = HomeCfg.Animals.Chicken.BurstSpeedMin or HomeCfg.Animals.Chicken.AvoidSpeedMin or 6
	local adjusted = math.clamp(speed / baseSpeed, HomeCfg.Animals.Chicken.WalkAnimMin, HomeCfg.Animals.Chicken.WalkAnimMax)

	track:AdjustSpeed(adjusted)
end

function Chicken:GetNearestPlayer()
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

function Chicken:GetAvoidDistance()
	local cfg = HomeCfg.Animals.Chicken
	local base = self.Rng:NextNumber(cfg.AvoidDistanceMin, cfg.AvoidDistanceMax)

	return base * self.Personality.Skittishness / math.max(self.Personality.Trust, 0.1)
end

function Chicken:GetChickenSeparation()
	if not self.Model or not self.Model.PrimaryPart then
		return Vector3.zero
	end

	local parent = self.Model.Parent
	if not parent then
		return Vector3.zero
	end

	local cfg = HomeCfg.Animals.Chicken
	local radius = cfg.SeparationRadius or 2.4
	local weight = cfg.SeparationWeight or 1.25

	local position = self.Model.PrimaryPart.Position
	local separation = Vector3.zero

	for _, other in ipairs(parent:GetChildren()) do
		if other ~= self.Model and other:IsA("Model") and other:GetAttribute("AnimalType") == "Chicken" then
			local otherRoot = other.PrimaryPart or other:FindFirstChild("HumanoidRootPart") or other:FindFirstChildWhichIsA("BasePart", true)

			if otherRoot then
				local away = position - otherRoot.Position
				local dist = flat(away).Magnitude

				if dist > 0.001 and dist < radius then
					local dir = getFlatDirection(away)
					if dir then
						local strength = (radius - dist) / radius
						separation += dir * strength * weight
					end
				end
			end
		end
	end

	return separation
end

function Chicken:GetNextEggCooldown()
	local cfg = HomeCfg.Animals.Chicken
	local base = self.Rng:NextNumber(cfg.LayCooldownMin, cfg.LayCooldownMax)

	return base / math.max(self.Personality.EggRate, 0.1)
end

function Chicken:GetNextBurstCooldown()
	local cfg = HomeCfg.Animals.Chicken
	return self.Rng:NextNumber(cfg.BurstCooldownMin, cfg.BurstCooldownMax)
end

function Chicken:CanStartBurst(now)
	if self.CarriedBy then
		return false
	end

	if self.State ~= "Idle" and self.State ~= "Peck" and self.State ~= "Roam" then
		return false
	end

	if self.State == "GoLayEgg" or self.State == "LayingEgg" or self.State == "SafeInCoop" or self.State == "Carried" then
		return false
	end

	if self:IsInInteriorZone() then
		return false
	end

	if not self.RoamZone then
		return false
	end

	if now < self.NextBurstAt then
		return false
	end

	return self.Rng:NextNumber() <= (HomeCfg.Animals.Chicken.BurstChance or 0)
end

function Chicken:PickBurstRunTarget()
	if self:IsInInteriorZone() then
		return false
	end

	local target = self:PickReachableRoamTarget(8)
	if not target then
		return false
	end

	return self:SetMoveTarget(target)
end

function Chicken:StartBurstRun(now)
	local cfg = HomeCfg.Animals.Chicken

	if not self:PickBurstRunTarget() then
		self.NextBurstAt = now + self:GetNextBurstCooldown()
		return false
	end

	self.Speed = math.max(self.Rng:NextNumber(cfg.BurstSpeedMin, cfg.BurstSpeedMax) * self.Personality.Energy, cfg.BurstSpeedMin)
	self.BurstFinishAt = now + self.Rng:NextNumber(cfg.BurstDurationMin, cfg.BurstDurationMax)
	self.NextBurstAt = now + self:GetNextBurstCooldown()
	self:SetState("BurstRun")
	self.NextDecision = self.BurstFinishAt

	return true
end

function Chicken:FinishBurstRun(now)
	self.BurstFinishAt = 0

	if self.Rng:NextNumber() < 0.55 then
		self:Idle(now)
	else
		self:PickPeck(now)
	end
end

function Chicken:CanStartEgg()
	if self.CarriedBy then
		return false
	end

	if self.State == "SafeInCoop" then
		return false
	end

	if #self.EggPoints == 0 then
		self:LogNest("NoChickenEggPointsFound", "No ChickenEggPoints found", "[ChickenNest][FAIL]")
		return false
	end

	if not self.EggService or not self.EggService:CanLayEgg(self) then
		return false
	end

	return os.clock() >= self.NextEggAt
end

function Chicken:PickEggPoint()
	self:LogEggPointScan()
	if #self.EggPoints == 0 then
		return nil
	end

	local insideCoop = self:IsInsideChickenCoopZone()
	local hasNestAccessPoints = #self:GetNestAccessPoints() > 0
	local startIndex = self.Rng:NextInteger(1, #self.EggPoints)
	for offset = 0, #self.EggPoints - 1 do
		local index = ((startIndex + offset - 1) % #self.EggPoints) + 1
		local point = self.EggPoints[index]
		if point then
			local pointInCoop = self:IsEggPointInNest(point)
			if self.CoopZone then
				if pointInCoop and (insideCoop or hasNestAccessPoints) then
					self:LogNest("SelectedEggPoint " .. point.Name, "Selected EggPoint: " .. point.Name)
					return point
				end
			elseif insideCoop or hasNestAccessPoints or self:HasLineOfSightToTarget(point.Position) then
				self:LogNest("SelectedEggPoint " .. point.Name, "Selected EggPoint: " .. point.Name)
				return point
			end
		end
	end

	local reason = self:GetEggPointOutsideCoopZone() and "EggPointOutsideCoopZone" or "NoValidEggPoint"
	self:LogNest("NoValidEggPoint " .. reason, "No valid EggPoint selected. Reason=" .. reason, "[ChickenNest][FAIL]")
	return nil
end

function Chicken:GoLayEgg(now)
	local cfg = HomeCfg.Animals.Chicken
	local current = self:GetCurrentPosition()
	self:LogNest("GoLayEggStarted", "GoLayEgg started")
	self:LogCoopStatus(current)
	local accessPoints = self:LogAccessPointScan()

	if not self:IsInsideChickenCoopZone(current) and #accessPoints == 0 then
		self.NextEggAt = now + self.Rng:NextNumber(cfg.FailRetryMin or 8, cfg.FailRetryMax or 16)
		self:SetNestRouteMode("EnterCoopViaAccessPoints")
		self:LogNest("RouteMode EnterCoopViaAccessPoints", "RouteMode=EnterCoopViaAccessPoints")
		self:SetNestDebug("Failed", 0, "", "OutsideCoopNoAccessPoints")
		self:SetNestJumpDebug("Failed", "", "OutsideCoopNoAccessPoints", Vector3.zero)
		self:LogNest("OutsideCoopNoAccessPoints", "No AccessPoints found while chicken is outside coop", "[ChickenNest][FAIL]")
		self:Idle(now)
		return
	end

	local point = self:PickEggPoint()
	if not point then
		local outsideEggPoint = self:GetEggPointOutsideCoopZone()
		self.NextEggAt = now + self.Rng:NextNumber(cfg.FailRetryMin or 8, cfg.FailRetryMax or 16)
		if outsideEggPoint then
			self:SetNestRouteMode(self:IsInsideChickenCoopZone(current) and "InsideCoopDirectToEggPoint" or "EnterCoopViaAccessPoints")
			self:SetNestDebug("Failed", 0, outsideEggPoint, "EggPointOutsideCoopZone")
			self:SetNestJumpDebug("Failed", "", "EggPointOutsideCoopZone", outsideEggPoint.Position)
		end
		self:Idle(now)
		return
	end

	self.CurrentEggPoint = point
	self.Speed = self.Rng:NextNumber(cfg.EggWalkSpeedMin, cfg.EggWalkSpeedMax) * self.Personality.Energy
	self.NestAccessPoints = {}
	self.NestAccessIndex = 0

	if not self:IsInsideChickenCoopZone(current) then
		if self:StartNestAccessRoute(point, now) then
			return
		end

		self:SetNestRouteMode("EnterCoopViaAccessPoints")
		self:CancelNestAttempt(now, "OutsideCoopNoAccessPoints")
		return
	end

	self:StartNestJumpOrEgg(now, "AlreadyInside")
end

function Chicken:BeginLayingEgg(now)
	local cfg = HomeCfg.Animals.Chicken

	self:SetNestDebug("LayingEgg", self.NestAccessIndex or 0, self.CurrentEggPoint, "")
	self:LogNest("LayingEggStarted", "LayingEgg started at " .. (self.CurrentEggPoint and self.CurrentEggPoint.Name or "nil"))
	self:SetState("LayingEgg")
	self:StopMovementTracks()

	self.LayFinishAt = now + self.Rng:NextNumber(cfg.LayingTimeMin, cfg.LayingTimeMax) * self.Personality.Laziness
	self.NextDecision = self.LayFinishAt
end

function Chicken:FinishLayingEgg(now)
	if self.EggService and self.CurrentEggPoint and self.HomeData then
		self.EggService:LayEgg(self, self.CurrentEggPoint, self.HomeData)
		self:LogNest("EggCreatedSuccessfully", "Egg created successfully")
	end

	local jumpLink = self.CurrentNestJumpLink
	self.CurrentEggPoint = nil
	self.NestAccessPoints = {}
	self.NestAccessIndex = 0
	self.NestTargetPart = nil
	self.NestCommitUntil = 0
	self.NestLastDistance = math.huge
	self.NextEggAt = now + self:GetNextEggCooldown()

	if jumpLink then
		self:StartOnNest(now)
	else
		self.CurrentNestJumpLink = nil
		self:SetNestDebug("", 0, "", "")
		self:SetNestJumpDebug("", "", "", Vector3.zero)
		self:Idle(now)
	end
end

function Chicken:PickRoamTarget(now)
	local cfg = HomeCfg.Animals.Chicken
	local target = self:PickReachableRoamTarget(8)

	if not target then
		local angle = self.Rng:NextNumber(0, math.pi * 2)
		local radius = self.Rng:NextNumber(1, cfg.RoamRadius)
		target = self.HomePosition + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	end

	self:SetMoveTarget(target)
	self.Speed = self.Rng:NextNumber(cfg.SpeedMin, cfg.SpeedMax) * self.Personality.Energy
	self:SetState("Roam")
	self.NextDecision = now + self.Rng:NextNumber(cfg.MoveMin, cfg.MoveMax)
end

function Chicken:PickPeck(now)
	local cfg = HomeCfg.Animals.Chicken

	self:SetState("Peck")
	self:StopMovementTracks()
	self.NextDecision = now + self.Rng:NextNumber(cfg.PeckMin, cfg.PeckMax) * self.Personality.Laziness
end

function Chicken:Idle(now)
	local cfg = HomeCfg.Animals.Chicken

	self:SetState("Idle")
	self:StopMovementTracks()
	self.NextDecision = now + self.Rng:NextNumber(cfg.IdleMin, cfg.IdleMax) * self.Personality.Laziness
end

function Chicken:AvoidPlayer(now, playerRoot)
	if self.State == "LayingEgg" or self.CarriedBy or self:IsNestState() then
		return
	end

	local cfg = HomeCfg.Animals.Chicken
	local current = self.Model.PrimaryPart.Position
	local away = current - playerRoot.Position
	local direction = getFlatDirection(away)

	if not direction then
		if self:IsInInteriorZone(current) and self:StartEscapePath(now, getFlatDirection(self.LastMoveDirection) or Vector3.zAxis, "PlayerNearInterior") then
			return
		end

		self:Idle(now)
		return
	end

	local target = nil
	if self:IsInInteriorZone(current) then
		local escapeDirection = getFlatDirection(playerRoot.Position - current) or getFlatDirection(self.LastMoveDirection) or direction
		if self:StartEscapePath(now, escapeDirection, "PlayerNearInterior") then
			return
		end

		target = self:PickShortClearTarget(direction)
		if not target or flat(target - current).Magnitude <= 0.25 then
			self:Idle(now)
			return
		end
	else
		target = current + direction * self.Rng:NextNumber(5, 9)
		if not self:HasLineOfSightToTarget(target) then
			target = self:PickShortClearTarget(direction) or target
		end
	end

	self:SetMoveTarget(target)
	self.Speed = math.max(self.Rng:NextNumber(cfg.AvoidSpeedMin, cfg.AvoidSpeedMax) * self.Personality.Energy, cfg.AvoidSpeedMin)
	self:SetState("AvoidPlayer")
	self.NextDecision = now + self.Rng:NextNumber(0.7, 1.8)
end

function Chicken:ReturnHome(now)
	local cfg = HomeCfg.Animals.Chicken
	local target = self:PickReachableRoamTarget(8) or self.HomePosition

	self:SetMoveTarget(target)
	self.Speed = self.Rng:NextNumber(cfg.ReturnSpeedMin, cfg.ReturnSpeedMax) * self.Personality.Energy
	self:SetState("ReturnHome")
	self.NextDecision = now + self.Rng:NextNumber(1.0, 2.4)
end

function Chicken:EnterSafeInCoop(now)
	local cfg = HomeCfg.Animals.Chicken

	self:SetState("SafeInCoop")
	self:StopMovementTracks()
	self.SafeUntil = now + self.Rng:NextNumber(cfg.SafeInCoopMin, cfg.SafeInCoopMax)
	self.NextDecision = self.SafeUntil
end

function Chicken:MakeDecision(now)
	if self.CarriedBy then
		return
	end

	if self.State == "LayingEgg" then
		return
	end

	if self:IsNestState() then
		return
	end

	if self.State == "BurstRun" then
		if now >= self.BurstFinishAt then
			self:FinishBurstRun(now)
		end
		return
	end

	if self.State == "SafeInCoop" then
		if now >= self.SafeUntil then
			self:Idle(now)
		end
		return
	end

	if self:CanStartEgg() then
		self:GoLayEgg(now)
		return
	end

	local nearestRoot, nearestDistance = self:GetNearestPlayer()

	if nearestRoot and nearestDistance <= self:GetAvoidDistance() then
		self:AvoidPlayer(now, nearestRoot)
		return
	end

	if self.RoamZone and not self:IsInInteriorZone(self.Model.PrimaryPart.Position) and not pointInsidePartXZ(self.Model.PrimaryPart.Position, self.RoamZone) then
		self:ReturnHome(now)
		return
	end

	if self:CanStartBurst(now) and self:StartBurstRun(now) then
		return
	end

	local roll = self.Rng:NextNumber()

	if roll < 0.38 then
		self:PickRoamTarget(now)
	elseif roll < 0.72 then
		self:PickPeck(now)
	else
		self:Idle(now)
	end
end

function Chicken:MoveTowards(dt, now)
	local cfg = HomeCfg.Animals.Chicken
	local current = self.Model.PrimaryPart.Position
	local toTarget = self.TargetPosition - current
	local dist = flat(toTarget).Magnitude
	local direction = getFlatDirection(toTarget)
	local isNestState = self:IsNestState()
	local reachDistance = 0.35

	if self.State == "GoNestAccess" then
		reachDistance = cfg.AccessPointReachDistance or 1.0
	elseif self.State == "GoNestJumpStart" then
		reachDistance = (HomeCfg.ChickenNest or {}).NestJumpReachDistance or 1.1
	elseif self.State == "GoNestEggPoint" or self.State == "GoLayEgg" then
		reachDistance = cfg.EggPointReachDistance or 1.0
	end

	if not direction or dist <= reachDistance then
		if self.State == "GoNestAccess" then
			self:AdvanceNestAccess(now)
		elseif self.State == "GoNestJumpStart" then
			self:StartNestJumpUp(now)
		elseif self.State == "GoNestEggPoint" or self.State == "GoLayEgg" then
			self:BeginLayingEgg(now)
		elseif self.State == "BurstRun" then
			if now >= self.BurstFinishAt then
				self:FinishBurstRun(now)
			else
				self:PickBurstRunTarget()
			end
		else
			self:MakeDecision(now)
		end

		return
	end

	if isNestState then
		if self:UpdateNestProgress(now, dist) and now >= (self.NestCommitUntil or 0) then
			self:CancelNestAttempt(now, "Stuck")
			return
		end
	elseif self:UpdateTargetProgress(now, dist) then
		if self:ResolveStuck(now, direction) then
			return
		end
	end

	local separation = self:GetChickenSeparation()
	if separation.Magnitude > 0.001 then
		local separationWeight = isNestState and 0.35 or 1
		local blended = direction + separation * separationWeight
		if blended.Magnitude > 0.001 then
			direction = blended.Unit
		end
	end

	if isNestState then
		local obstacleHit = self:CastObstacle(direction)
		if obstacleHit and self:IsEscapeBlockingHit(obstacleHit, direction) then
			local alternative = self:FindEscapeDoorwayDirection(direction, cfg.ObstacleCheckDistance)
			if alternative then
				local blended = direction * 0.75 + alternative * 0.25
				if blended.Magnitude > 0.001 then
					direction = blended.Unit
				end
			elseif now >= (self.NestCommitUntil or 0) and now - (self.NestLastProgressAt or now) >= (cfg.NestFailStuckTime or 2.0) then
				self:CancelNestAttempt(now, "Blocked")
				return
			else
				self:StopMovementTracks()
				return
			end
		end
	else
		local avoidedDirection, hitObstacle = self:GetObstacleAvoidanceDirection(direction, now)
		if hitObstacle and not avoidedDirection then
			if self:ResolveStuck(now, direction) then
				return
			end
			self:StopMovementTracks()
			return
		end

		direction = avoidedDirection or direction
	end

	local step = math.min(self.Speed * dt, dist)
	local blockingHit = self:CastObstacle(direction, math.max(step + cfg.ObstacleSphereRadius, 0.9))
	local blockingNormal = blockingHit and getFlatDirection(blockingHit.Normal)
	local isBlocking = blockingHit
		and (blockingHit.Distance or 0) <= step + cfg.ObstacleSphereRadius
		and (not blockingNormal or direction:Dot(blockingNormal) < (isNestState and -0.55 or -0.2))

	if isBlocking then
		if isNestState then
			if now >= (self.NestCommitUntil or 0) and now - (self.NestLastProgressAt or now) >= (cfg.NestFailStuckTime or 2.0) then
				self:CancelNestAttempt(now, "Blocked")
				return
			end
		else
			if self:ResolveStuck(now, direction) then
				return
			end
		end

		self:StopMovementTracks()
		return
	end

	local nextPosition = current + direction * step
	local activeZone, isInterior = self:GetActiveContainmentZone(current)
	if not isNestState and isInterior and activeZone and not pointInsidePartXZ(nextPosition, activeZone) then
		if self.State == "GoLayEgg" then
			self:CancelNestAttempt(now, "LeftNestZone")
		elseif self.State == "AvoidPlayer" then
			local escapeDirection = getFlatDirection(self.LastMoveDirection) or direction
			self:StartEscapePath(now, escapeDirection, "InteriorBoundary")
		elseif self.State == "BurstRun" then
			self:FinishBurstRun(now)
		else
			self:Idle(now)
		end

		return
	end

	self:SetWorldPosition(nextPosition, direction, dt)

	if self.State == "AvoidPlayer" or self.State == "BurstRun" then
		self:PlayRun(self.Speed)
	else
		self:PlayWalk(self.Speed)
	end
end

function Chicken:GetCarryPart(character)
	if not character then
		return nil
	end

	return character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("Torso")
		or character:FindFirstChild("HumanoidRootPart")
end

function Chicken:SetCarriedPhysics(isCarried, player)
	if not self.Model then
		return
	end

	for _, desc in ipairs(self.Model:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.CanCollide = false
			desc.CanTouch = false
			desc.CanQuery = false

			if isCarried then
				desc.Anchored = false
				desc.Massless = true
			else
				desc.Anchored = true
				desc.Massless = false
			end
		end
	end

	local primary = self.Model.PrimaryPart

	if primary and isCarried and player then
		pcall(function()
			primary:SetNetworkOwner(player)
		end)
	elseif primary and not isCarried then
		pcall(function()
			primary:SetNetworkOwner(nil)
		end)
	end
end

function Chicken:CreateCarryMotor(player)
	local character = player.Character
	local carryPart = self:GetCarryPart(character)
	local chickenRoot = self.Model and self.Model.PrimaryPart

	if not carryPart or not chickenRoot then
		return nil
	end

	local oldMotor = carryPart:FindFirstChild("ChickenCarryMotor")
	if oldMotor then
		oldMotor:Destroy()
	end

	local motor = Instance.new("Motor6D")
	motor.Name = "ChickenCarryMotor"
	motor.Part0 = carryPart
	motor.Part1 = chickenRoot

	local offset = HomeCfg.Animals.Chicken.CarryOffset or Vector3.new(0, -0.25, -1.05)
	local rotation = HomeCfg.Animals.Chicken.CarryRotation or Vector3.new(0, 180, 0)

	motor.C0 =
		CFrame.new(offset)
		* CFrame.Angles(
			math.rad(rotation.X),
			math.rad(rotation.Y),
			math.rad(rotation.Z)
		)

	motor.C1 = CFrame.identity
	motor.Parent = carryPart

	self.CarryMotor = motor

	return motor
end


function Chicken:DestroyCarryMotor()
	if self.CarryMotor then
		pcall(function()
			self.CarryMotor:Destroy()
		end)
		self.CarryMotor = nil
	end

	local player = self.CarriedBy
	local character = player and player.Character
	local carryPart = self:GetCarryPart(character)

	if carryPart then
		local oldMotor = carryPart:FindFirstChild("ChickenCarryMotor")
		if oldMotor then
			oldMotor:Destroy()
		end
	end
end

function Chicken:DisconnectCarryCleanup()
	if self.CarryDeathConn then
		self.CarryDeathConn:Disconnect()
		self.CarryDeathConn = nil
	end

	if self.CarryAncestryConn then
		self.CarryAncestryConn:Disconnect()
		self.CarryAncestryConn = nil
	end
end

function Chicken:RegisterCarryCleanup(player)
	self:DisconnectCarryCleanup()

	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		self.CarryDeathConn = humanoid.Died:Connect(function()
			if self.Service and self.CarriedBy == player then
				self.Service:ForceDropCarriedChicken(player, "CharacterDied")
			end
		end)
	end

	if character then
		self.CarryAncestryConn = character.AncestryChanged:Connect(function(_, parent)
			if parent == nil and self.Service and self.CarriedBy == player then
				self.Service:ForceDropCarriedChicken(player, "CharacterRemoved")
			end
		end)
	end
end

function Chicken:StartCarry(player)
	if self.CarriedBy then
		return false
	end

	if player.UserId ~= self.Owner.UserId then
		return false
	end

	local character = player.Character
	local carryPart = self:GetCarryPart(character)

	if not carryPart or not self.Model or not self.Model.PrimaryPart then
		return false
	end

	self.CarriedBy = player
	self:RegisterCarryCleanup(player)
	self.CurrentEggPoint = nil
	self.LayFinishAt = 0
	self.NextDecision = math.huge

	self:StopMovementTracks()
	self:SetState("Carried")
	self:SetCarryPromptEnabled(false)

	self:SetCarriedPhysics(true, player)

	local motor = self:CreateCarryMotor(player)

	if not motor then
		self:SetCarriedPhysics(false, nil)
		self:DisconnectCarryCleanup()
		self.CarriedBy = nil
		self:SetCarryPromptEnabled(true)
		self:Idle(os.clock())
		return false
	end

	if self.Model then
		self.Model:SetAttribute("CarriedBy", player.UserId)
		self.Model:SetAttribute("CarryMode", "Motor6D")
	end

	player:SetAttribute("CarryingChicken", true)

	return true
end


function Chicken:Drop(now)
	local player = self.CarriedBy

	if not player then
		return false
	end

	local character = player.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
	local position = self.Model and self.Model.PrimaryPart and self.Model.PrimaryPart.Position
		or (playerRoot and playerRoot.Position)
		or self.HomePosition
	local dropPosition = self:GetDropGroundedPosition(position)

	self:DestroyCarryMotor()
	self:DisconnectCarryCleanup()

	self.CarriedBy = nil

	if self.Model then
		self.Model:SetAttribute("CarriedBy", 0)
		self.Model:SetAttribute("CarryMode", "")
	end

	player:SetAttribute("CarryingChicken", false)

	self:SetCarriedPhysics(false, nil)
	self:SetCarryPromptEnabled(true)

	self:SetWorldPosition(dropPosition, self.LastMoveDirection, 1)

	if self.CoopZone and pointInsidePartXZ(dropPosition, self.CoopZone) then
		self:EnterSafeInCoop(now or os.clock())
	else
		self:Idle(now or os.clock())
	end

	return true
end

function Chicken:ForceDrop(reason)
	local player = self.CarriedBy
	local position = self.Model and self.Model.PrimaryPart and self.Model.PrimaryPart.Position or self.HomePosition
	local dropPosition = self:GetDropGroundedPosition(position or self.HomePosition)

	self:DestroyCarryMotor()
	self:DisconnectCarryCleanup()

	self.CarriedBy = nil

	if player then
		player:SetAttribute("CarryingChicken", false)
	end

	if self.Model then
		self.Model:SetAttribute("CarriedBy", 0)
		self.Model:SetAttribute("CarryMode", "")
	end

	self:SetCarriedPhysics(false, nil)
	self:SetCarryPromptEnabled(true)
	self:StopMovementTracks()

	if self.Model and self.Model.PrimaryPart then
		self:SetWorldPosition(dropPosition, self.LastMoveDirection or Vector3.zAxis, 1)
	end

	self:SetState("Idle")
	self.NextDecision = os.clock() + self.Rng:NextNumber(0.4, 1.2)

	if HomeCfg.Debug.PrintCarry then
		print(string.format("[ChickenCarry] Cleanup complete chicken=%s reason=%s", self.Model and self.Model.Name or "nil", tostring(reason or "ForceDrop")))
	end

	return true
end


function Chicken:StepCarried(dt)
	local player = self.CarriedBy

	if not player then
		return
	end

	local character = player.Character
	local carryPart = self:GetCarryPart(character)

	if not character or not carryPart or not self.CarryMotor or not self.CarryMotor.Parent then
		if self.Service then
			self.Service:ForceDropCarriedChicken(player, "InvalidCarryState")
		else
			self:ForceDrop("InvalidCarryState")
		end
		return
	end

	-- Motor6D mueve la gallina automÃ¡ticamente con el personaje.
	-- No usamos PivotTo por frame.
end


function Chicken:Step(dt, now)
	if not self.Model or not self.Model.Parent or not self.Model.PrimaryPart then
		return false
	end

	if self.CarriedBy then
		self:StepCarried(dt)
		return true
	end

	if self.State == "NestJumpUp" then
		return self:StepNestJumpUp(dt, now)
	end

	if self.State == "OnNest" then
		return self:StepOnNest(dt, now)
	end

	if self.State == "NestJumpDown" then
		return self:StepNestJumpDown(dt, now)
	end

	if self.State == "ForcedExitHop" then
		return self:StepForcedExitHop(dt, now)
	end

	if self.State == "EscapeStepHop" then
		return self:StepEscapeStepHop(dt, now)
	end

	if self.State == "EscapePath" then
		return self:StepEscapePath(dt, now)
	end

	if self.State == "EscapeRecover" then
		return self:StepEscapeRecover(dt, now)
	end

	if self.State == "EscapeToExit" then
		return self:StepEscapePath(dt, now)
	end

	if self.State == "EscapeDoorway" then
		return self:StepEscapePath(dt, now)
	end

	if self.State == "LayingEgg" then
		self:StopMovementTracks()
		if self.CurrentNestJumpLink then
			local current = self.Model.PrimaryPart.Position
			local direction = getFlatDirection(self.LastMoveDirection) or Vector3.zAxis
			self.Model:PivotTo(CFrame.lookAt(current, current + direction, Vector3.yAxis))
		else
			self:SetWorldPosition(self.Model.PrimaryPart.Position, self.LastMoveDirection, dt)
		end

		if now >= self.LayFinishAt then
			self:FinishLayingEgg(now)
		end

		return true
	end

	if self.State == "SafeInCoop" then
		local current = self.Model.PrimaryPart.Position
		local nearestRoot, nearestDistance = self:GetNearestPlayer()
		if nearestRoot and nearestDistance <= self:GetAvoidDistance() and self:IsInInteriorZone(current) then
			local escapeDirection = getFlatDirection(nearestRoot.Position - current) or getFlatDirection(self.LastMoveDirection) or Vector3.zAxis
			return self:StartEscapePath(now, escapeDirection, "SafeInCoopPlayer")
		end

		self:StopMovementTracks()
		self:SetWorldPosition(current, self.LastMoveDirection, dt)

		if now >= self.SafeUntil then
			self:Idle(now)
		end

		return true
	end

	if self.State == "BurstRun" and now >= self.BurstFinishAt then
		self:FinishBurstRun(now)
		return true
	end

	local nearestRoot, nearestDistance = self:GetNearestPlayer()

	if nearestRoot and nearestDistance <= self:GetAvoidDistance() * 0.82 and self.State ~= "AvoidPlayer" and self.State ~= "GoLayEgg" and not self:IsNestState() and not self:IsEscapeState() then
		self:AvoidPlayer(now, nearestRoot)
	end

	if self:IsEscapeState() then
		return true
	end

	if now >= self.NextDecision then
		self:MakeDecision(now)
	end

	if self:IsEscapeState() then
		return true
	end

	if self.State == "Roam" or self.State == "AvoidPlayer" or self.State == "ReturnHome" or self.State == "GoLayEgg" or self.State == "GoNestAccess" or self.State == "GoNestJumpStart" or self.State == "GoNestEggPoint" or self.State == "BurstRun" then
		self:MoveTowards(dt, now)
	else
		self:StopMovementTracks()
		self:SetWorldPosition(self.Model.PrimaryPart.Position, self.LastMoveDirection, dt)
	end

	return true
end

function Chicken:Destroy()
	if self.CarriedBy or self.CarryMotor or self.CarryDeathConn or self.CarryAncestryConn then
		self:ForceDrop("Destroy")
	else
		self:DestroyCarryMotor()
		self:DisconnectCarryCleanup()
	end

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

return Chicken
