local Sheep = {}
Sheep.__index = Sheep

local Players = game:GetService("Players")

local Cfg = require(script.Parent:WaitForChild("Cfg"))
local Rand = require(script.Parent:WaitForChild("Rand"))

local OBSTACLE_CHECK_DISTANCE = 4.5
local OBSTACLE_CHECK_HEIGHT = 0.8
local OBSTACLE_SPHERE_RADIUS = 1.1
local OBSTACLE_TURN_WEIGHT = 1.35

local function isValidAnimId(id)
	return typeof(id) == "string" and id:match("^rbxassetid://%d+$") ~= nil
end

-- Pasture Sheep AntiStack v1
local function applySheepNoQuery(model)
	if not model then
		return
	end

	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.CanQuery = false
		end
	end
end

local function flatVector(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function getFlatDirection(vector)
	local flat = flatVector(vector)

	if flat.Magnitude > 0.001 then
		return flat.Unit
	end

	return nil
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

local function flatDistance(a, b)
	return flatVector(a - b).Magnitude
end

function Sheep.new(model, ownerPlayer, houseModel, index)
	local self = setmetatable({}, Sheep)

	self.Model = model
	self.Owner = ownerPlayer
	self.House = houseModel
	self.Index = index

	self.Root = model:FindFirstChild("HumanoidRootPart")
	self.AnimationController = model:FindFirstChild("AnimationController")

	if not self.Root or not self.Root:IsA("BasePart") then
		warn("[Sheep] Falta HumanoidRootPart en", model.Name)
		return self
	end

	if not self.AnimationController then
		warn("[Sheep] Falta AnimationController en", model.Name)
	end

	self.Animator = nil

	if self.AnimationController then
		self.Animator = self.AnimationController:FindFirstChildOfClass("Animator")
	end

	if not self.Animator and self.AnimationController then
		self.Animator = Instance.new("Animator")
		self.Animator.Parent = self.AnimationController
	end

	self.Rng = Random.new((ownerPlayer.UserId + index * 1009 + math.floor(os.clock() * 1000)) % 2147483647)

	self.State = "Idle"
	self.CurrentIdleAction = nil
	self.NextIdleChange = os.clock() + self.Rng:NextNumber(1, Cfg.IdleTime.Max)

	self.HeightFiltered = Cfg.Hover.TargetHeight
	self.WalkSpeedScale = self.Rng:NextNumber(0.9, 1.15)

	self.NaturalDirection = self:GetRandomFlatDirection()
	self.NextNaturalChange = os.clock() + self.Rng:NextNumber(1.2, 3.2)

	self.NextCalmMove = os.clock() + self.Rng:NextNumber(Cfg.Calm.MinWait, Cfg.Calm.MaxWait)
	self.CalmMoveUntil = 0
	self.CalmDirection = nil
	self.CalmChosenSpeed = nil
	self.CalmMoveState = "CalmWalk"

	self.ReactAt = 0
	self.SpeedModeUntil = 0
	self.SpeedMode = nil

	self.LastMovePosition = self.Root.Position
	self.LastMoveCheckAt = os.clock()
	self.MoveStuckTime = 0
	self.ObstacleAvoidDirection = nil
	self.ObstacleAvoidUntil = 0
	self.LastObstacleAt = 0
	self.LastObstacleNormal = nil

	self.Personality = {
		Energy = self.Rng:NextNumber(0.85, 1.25),
		Bravery = self.Rng:NextNumber(0.75, 1.25),
		Laziness = self.Rng:NextNumber(0.75, 1.35),
	}

	self.Tracks = {}
	self.InvalidActionWarnings = {}

	self.SequenceActive = false
	self.SequenceName = nil
	self.SequenceEnding = false
	self.SequenceToken = 0
	self.SequenceEndAt = 0
	self.SequenceLoopName = nil
	self.SequenceNextLoopSwap = 0

	model:SetAttribute("OwnerId", ownerPlayer.UserId)
	model:SetAttribute("OwnerName", ownerPlayer.Name)
	model:SetAttribute("SheepIndex", index)
	model:SetAttribute("HouseId", houseModel:GetAttribute("HouseId") or 0)
	model:SetAttribute("State", self.State)
	model:SetAttribute("IsLeader", false)

	applySheepNoQuery(self.Model)
	self:SetupPhysics()
	self:LoadAnimations()
	self:PlayIdleBase(0)

	return self
end

function Sheep:SetState(state)
	self.State = state

	if self.Model then
		self.Model:SetAttribute("State", state)
	end
end

function Sheep:GetRandomFlatDirection()
	local angle = self.Rng:NextNumber(0, math.pi * 2)
	return Vector3.new(math.cos(angle), 0, math.sin(angle))
end

function Sheep:GetNaturalDirection(now)
	if now >= self.NextNaturalChange then
		self.NaturalDirection = self:GetRandomFlatDirection()
		self.NextNaturalChange = now + self.Rng:NextNumber(1.2, 3.2)
	end

	return self.NaturalDirection
end

function Sheep:ScheduleNextCalmMove(now)
	self.NextCalmMove = now + self.Rng:NextNumber(Cfg.Calm.MinWait, Cfg.Calm.MaxWait)
end

function Sheep:ApplyCollisionGroup()
	if not Cfg.Collision or not Cfg.Collision.Enabled then
		return
	end

	for _, obj in ipairs(self.Model:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.CollisionGroup = Cfg.Collision.SheepGroup
		end
	end
end

function Sheep:SetupPhysics()
	self.Root.Anchored = false

	pcall(function()
		self.Root:SetNetworkOwner(nil)
	end)

	self:ApplyCollisionGroup()

	self.Attachment = self.Root:FindFirstChildWhichIsA("Attachment")

	if not self.Attachment then
		self.Attachment = Instance.new("Attachment")
		self.Attachment.Name = "Attachment"
		self.Attachment.Parent = self.Root
	end

	self.LinearVelocity = self.Root:FindFirstChild("LinearVelocity")

	if not self.LinearVelocity then
		self.LinearVelocity = Instance.new("LinearVelocity")
		self.LinearVelocity.Name = "LinearVelocity"
		self.LinearVelocity.Parent = self.Root
	end

	self.LinearVelocity.Attachment0 = self.Attachment
	self.LinearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	self.LinearVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	self.LinearVelocity.MaxAxesForce = Vector3.new(100000, 0, 100000)
	self.LinearVelocity.VectorVelocity = Vector3.zero

	self.AlignOrientation = self.Root:FindFirstChild("AlignOrientation")

	if not self.AlignOrientation then
		self.AlignOrientation = Instance.new("AlignOrientation")
		self.AlignOrientation.Name = "AlignOrientation"
		self.AlignOrientation.Parent = self.Root
	end

	self.AlignOrientation.Attachment0 = self.Attachment
	self.AlignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	self.AlignOrientation.Responsiveness = 12
	self.AlignOrientation.MaxTorque = 100000
	self.AlignOrientation.RigidityEnabled = false

	self.HoverForce = self.Root:FindFirstChild("HoverForce")

	if not self.HoverForce then
		self.HoverForce = Instance.new("VectorForce")
		self.HoverForce.Name = "HoverForce"
		self.HoverForce.Parent = self.Root
	end

	self.HoverForce.Attachment0 = self.Attachment
	self.HoverForce.RelativeTo = Enum.ActuatorRelativeTo.World
	self.HoverForce.ApplyAtCenterOfMass = true
	self.HoverForce.Force = Vector3.zero

	self.RaycastParams = RaycastParams.new()
	self.RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local runtimeFolder = workspace:FindFirstChild((Cfg.Names and Cfg.Names.Runtime) or "SheepRuntime")

	if runtimeFolder then
		self.RaycastParams.FilterDescendantsInstances = { self.Model, runtimeFolder }
	else
		self.RaycastParams.FilterDescendantsInstances = { self.Model }
	end
	self.RaycastParams.IgnoreWater = true

	self.ObstacleParams = RaycastParams.new()
	self.ObstacleParams.FilterType = Enum.RaycastFilterType.Exclude
	self.ObstacleParams.FilterDescendantsInstances = { self.Model }
	self.ObstacleParams.IgnoreWater = true
end

function Sheep:LoadTrack(name, animId, priority, looped)
	if not self.Animator then
		return nil
	end

	if not isValidAnimId(animId) then
		return nil
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = animId

	local ok, track = pcall(function()
		return self.Animator:LoadAnimation(anim)
	end)

	if not ok or not track then
		warn("[Sheep] No se pudo cargar animación:", name, animId)
		return nil
	end

	track.Priority = priority
	track.Looped = looped

	self.Tracks[name] = track

	return track
end

function Sheep:LoadAnimations()
	self:LoadTrack("Walk", Cfg.Anim.Walk, Enum.AnimationPriority.Movement, true)
	self:LoadTrack("Trot", Cfg.Anim.Trot, Enum.AnimationPriority.Movement, true)
	self:LoadTrack("Run", Cfg.Anim.Run, Enum.AnimationPriority.Movement, true)

	self:LoadTrack("Idle", Cfg.Anim.Idle, Enum.AnimationPriority.Idle, true)

	self:LoadTrack("LieStart", Cfg.Anim.LieStart, Enum.AnimationPriority.Action, false)
	self:LoadTrack("LieLoop1", Cfg.Anim.LieLoop1, Enum.AnimationPriority.Action, true)
	self:LoadTrack("LieLoop2", Cfg.Anim.LieLoop2, Enum.AnimationPriority.Action, true)
	self:LoadTrack("LieEnd", Cfg.Anim.LieEnd, Enum.AnimationPriority.Action, false)

	self:LoadTrack("SleepStart", Cfg.Anim.SleepStart, Enum.AnimationPriority.Action, false)
	self:LoadTrack("SleepLoop", Cfg.Anim.SleepLoop, Enum.AnimationPriority.Action, true)
	self:LoadTrack("SleepEnd", Cfg.Anim.SleepEnd, Enum.AnimationPriority.Action, false)

	self:LoadTrack("EatStart", Cfg.Anim.EatStart, Enum.AnimationPriority.Action, false)
	self:LoadTrack("EatLoop1", Cfg.Anim.EatLoop1, Enum.AnimationPriority.Action, true)
	self:LoadTrack("EatLoop2", Cfg.Anim.EatLoop2, Enum.AnimationPriority.Action, true)
	self:LoadTrack("EatEnd", Cfg.Anim.EatEnd, Enum.AnimationPriority.Action, false)
end

function Sheep:StopTrack(name, fade)
	local track = self.Tracks[name]

	if track and track.IsPlaying then
		track:Stop(fade or 0.2)
	end
end

function Sheep:StopMoveTracks(exceptName, fade)
	local moveTracks = { "Walk", "Trot", "Run" }

	for _, name in ipairs(moveTracks) do
		if name ~= exceptName then
			self:StopTrack(name, fade or 0.2)
		end
	end
end

-- =========================================================================
-- SEQUENCES: Start -> Loop -> End
-- =========================================================================

function Sheep:IsSequenceAction(actionName)
	return Cfg.Sequences and Cfg.Sequences[actionName] ~= nil
end

function Sheep:GetTrackLength(track, fallback)
	if track and track.Length and track.Length > 0 then
		return track.Length
	end

	return fallback or 1
end

function Sheep:AfterTrackStops(track, token, fallback, callback)
	if not track then
		task.delay(fallback or 1, function()
			if token == self.SequenceToken then
				callback()
			end
		end)

		return
	end

	local finished = false
	local connection = nil

	connection = track.Stopped:Connect(function()
		if finished then
			return
		end

		finished = true

		if connection then
			connection:Disconnect()
		end

		if token == self.SequenceToken then
			callback()
		end
	end)

	local delayTime = self:GetTrackLength(track, fallback or 1)

	task.delay(delayTime + 0.15, function()
		if finished then
			return
		end

		finished = true

		if connection then
			connection:Disconnect()
		end

		if token == self.SequenceToken then
			callback()
		end
	end)
end

function Sheep:GetValidSequenceLoops(sequenceData)
	local valid = {}

	if not sequenceData or not sequenceData.Loops then
		return valid
	end

	for _, loopName in ipairs(sequenceData.Loops) do
		if self.Tracks[loopName] then
			table.insert(valid, loopName)
		end
	end

	return valid
end

function Sheep:ForEachSequenceTrackName(callback)
	for _, sequenceData in pairs(Cfg.Sequences or {}) do
		if typeof(sequenceData) == "table" then
			if sequenceData.Start then
				callback(sequenceData.Start)
			end

			if sequenceData.End then
				callback(sequenceData.End)
			end

			if sequenceData.FallbackEnd then
				callback(sequenceData.FallbackEnd)
			end

			if sequenceData.Loops then
				for _, loopName in ipairs(sequenceData.Loops) do
					callback(loopName)
				end
			end
		end
	end
end

function Sheep:StopSequenceImmediate(fade)
	if not self.SequenceActive and not self.SequenceName and not self.SequenceEnding then
		return
	end

	self.SequenceToken += 1
	self.SequenceActive = false
	self.SequenceName = nil
	self.SequenceEnding = false
	self.SequenceEndAt = 0
	self.SequenceLoopName = nil
	self.SequenceNextLoopSwap = 0

	self:ForEachSequenceTrackName(function(trackName)
		self:StopTrack(trackName, fade or 0.15)
	end)

	if self.Model and Cfg.Debug.SetDebugAttributes then
		self.Model:SetAttribute("Sequence", "")
	end
end

function Sheep:PickSequenceLoop(sequenceData)
	local validLoops = self:GetValidSequenceLoops(sequenceData)

	if #validLoops == 0 then
		return nil
	end

	if #validLoops == 1 then
		return validLoops[1]
	end

	local picked = validLoops[self.Rng:NextInteger(1, #validLoops)]

	if picked == self.SequenceLoopName then
		for _, loopName in ipairs(validLoops) do
			if loopName ~= self.SequenceLoopName then
				return loopName
			end
		end
	end

	return picked
end

function Sheep:PlaySequenceLoop(sequenceName, token)
	if token ~= self.SequenceToken then
		return
	end

	if not self.SequenceActive or self.SequenceName ~= sequenceName then
		return
	end

	local sequenceData = Cfg.Sequences[sequenceName]
	if not sequenceData then
		return
	end

	local loopName = self:PickSequenceLoop(sequenceData)

	if not loopName then
		warn("[Sheep] No hay loops válidos para secuencia:", sequenceName)
		return
	end

	local loopTrack = self.Tracks[loopName]

	if not loopTrack then
		return
	end

	self.SequenceLoopName = loopName

	self:ForEachSequenceTrackName(function(trackName)
		if trackName ~= loopName then
			self:StopTrack(trackName, Cfg.Sequences.LoopFade or 0.2)
		end
	end)

	loopTrack.Looped = true

	if not loopTrack.IsPlaying then
		loopTrack:Play(Cfg.Sequences.LoopFade or 0.2)
	end

	loopTrack:AdjustSpeed(self.Rng:NextNumber(0.92, 1.08))

	local minSwap = sequenceData.LoopSwitchMin or 8
	local maxSwap = sequenceData.LoopSwitchMax or 18

	self.SequenceNextLoopSwap = os.clock() + self.Rng:NextNumber(minSwap, maxSwap)
end

function Sheep:PlaySequenceAction(sequenceName)
	local sequenceData = Cfg.Sequences[sequenceName]

	if not sequenceData then
		return false
	end

	local validLoops = self:GetValidSequenceLoops(sequenceData)

	if #validLoops == 0 then
		warn("[Sheep] No se puede iniciar secuencia sin loop válido:", sequenceName)
		self:PlayIdleBase(0.25)
		return false
	end

	self:StopMoveTracks(nil, 0.2)
	self:StopTrack("Idle", 0.2)

	for name, _ in pairs(Cfg.ActionLoop) do
		self:StopTrack(name, 0.2)
	end

	self:StopSequenceImmediate(0.15)

	self.SequenceToken += 1
	local token = self.SequenceToken

	self.SequenceActive = true
	self.SequenceName = sequenceName
	self.SequenceEnding = false
	self.SequenceLoopName = nil
	self.SequenceNextLoopSwap = 0
	self.CurrentIdleAction = sequenceName

	self:SetState(sequenceName)
	self.LinearVelocity.VectorVelocity = Vector3.zero

	if self.Model and Cfg.Debug.SetDebugAttributes then
		self.Model:SetAttribute("Sequence", sequenceName)
	end

	local duration = self.Rng:NextNumber(sequenceData.MinTime or 20, sequenceData.MaxTime or 60)
	self.SequenceEndAt = os.clock() + duration

	local startTrack = self.Tracks[sequenceData.Start]

	if startTrack then
		startTrack.Looped = false
		startTrack:Play(Cfg.Sequences.StartFade or 0.25)
		startTrack:AdjustSpeed(self.Rng:NextNumber(0.95, 1.05))

		self:AfterTrackStops(startTrack, token, 1.2, function()
			self:PlaySequenceLoop(sequenceName, token)
		end)
	else
		self:PlaySequenceLoop(sequenceName, token)
	end

	return true
end

function Sheep:EndSequenceAction(now)
	if not self.SequenceActive or self.SequenceEnding then
		return false
	end

	local sequenceName = self.SequenceName
	local sequenceData = Cfg.Sequences[sequenceName]

	if not sequenceData then
		self:StopSequenceImmediate(0.2)
		self.CurrentIdleAction = nil
		return false
	end

	self.SequenceEnding = true
	self.SequenceToken += 1

	local token = self.SequenceToken

	local endTrackName = sequenceData.End
	local endTrack = self.Tracks[endTrackName]

	if not endTrack and sequenceData.FallbackEnd then
		endTrackName = sequenceData.FallbackEnd
		endTrack = self.Tracks[endTrackName]
	end

	if not endTrack then
		endTrackName = "LieEnd"
		endTrack = self.Tracks.LieEnd
	end

	self:ForEachSequenceTrackName(function(trackName)
		if trackName ~= endTrackName then
			self:StopTrack(trackName, Cfg.Sequences.EndFade or 0.25)
		end
	end)

	self:SetState(sequenceName .. "_End")
	self.LinearVelocity.VectorVelocity = Vector3.zero

	if endTrack then
		endTrack.Looped = false
		endTrack:Play(Cfg.Sequences.EndFade or 0.25)
		endTrack:AdjustSpeed(self.Rng:NextNumber(0.95, 1.05))

		self:AfterTrackStops(endTrack, token, 1.2, function()
			self.SequenceActive = false
			self.SequenceName = nil
			self.SequenceEnding = false
			self.SequenceEndAt = 0
			self.SequenceLoopName = nil
			self.SequenceNextLoopSwap = 0
			self.CurrentIdleAction = nil

			if self.Model and Cfg.Debug.SetDebugAttributes then
				self.Model:SetAttribute("Sequence", "")
			end

			self:PlayIdleBase(0.25)
			self.NextIdleChange = os.clock() + self.Rng:NextNumber(Cfg.IdleTime.Min, Cfg.IdleTime.Max)
			self:ScheduleNextCalmMove(os.clock())
		end)
	else
		self:ForEachSequenceTrackName(function(trackName)
			self:StopTrack(trackName, 0.2)
		end)

		self.SequenceActive = false
		self.SequenceName = nil
		self.SequenceEnding = false
		self.SequenceEndAt = 0
		self.SequenceLoopName = nil
		self.SequenceNextLoopSwap = 0
		self.CurrentIdleAction = nil

		if self.Model and Cfg.Debug.SetDebugAttributes then
			self.Model:SetAttribute("Sequence", "")
		end

		self:PlayIdleBase(0.25)
	end

	return true
end

function Sheep:HandleSequence(now, movementRequested)
	if not self.SequenceActive and not self.SequenceEnding then
		return false
	end

	self.LinearVelocity.VectorVelocity = Vector3.zero
	self.CalmMoveUntil = 0
	self.CalmDirection = nil
	self.CalmChosenSpeed = nil
	self.CalmMoveState = "CalmWalk"

	if self.SequenceEnding then
		return true
	end

	local sequenceData = Cfg.Sequences[self.SequenceName]

	if movementRequested and sequenceData and sequenceData.ExitBeforeMove ~= false then
		self:EndSequenceAction(now)
		return true
	end

	if now >= self.SequenceEndAt then
		self:EndSequenceAction(now)
		return true
	end

	if sequenceData and now >= self.SequenceNextLoopSwap then
		self:PlaySequenceLoop(self.SequenceName, self.SequenceToken)
	end

	return true
end

-- =========================================================================
-- Animación base
-- =========================================================================

function Sheep:StopIdleActions(fade)
	self:StopSequenceImmediate(fade or 0.2)

	for name, _ in pairs(Cfg.ActionLoop) do
		self:StopTrack(name, fade or 0.2)
	end

	self.CurrentIdleAction = nil
end

function Sheep:PlayIdleBase(fade)
	self:StopMoveTracks(nil, fade or 0.2)
	self:StopIdleActions(fade or 0.2)

	local idle = self.Tracks.Idle

	if idle and not idle.IsPlaying then
		idle:Play(fade or 0.2)
		idle:AdjustSpeed(self.Rng:NextNumber(0.9, 1.1))
	end
end

function Sheep:GetMoveTrackName(state, speed)
	if state == "PanicMove" and self.Tracks.Run then
		return "Run"
	end

	if speed >= Cfg.MoveAnim.RunSpeedThreshold and self.Tracks.Run then
		return "Run"
	end

	if speed >= Cfg.MoveAnim.TrotSpeedThreshold and self.Tracks.Trot then
		return "Trot"
	end

	if self.Tracks.Walk then
		return "Walk"
	end

	return nil
end

function Sheep:PlayMoveAnim(state, speed)
	self:StopTrack("Idle", 0.18)
	self:StopIdleActions(0.18)

	local trackName = self:GetMoveTrackName(state, speed)

	if not trackName then
		return
	end

	self:StopMoveTracks(trackName, 0.18)

	local track = self.Tracks[trackName]

	if track and not track.IsPlaying then
		track:Play(0.18)
	end

	if track then
		local baseSpeed = Cfg.MoveAnim.WalkBaseSpeed

		if trackName == "Trot" then
			baseSpeed = Cfg.MoveAnim.TrotBaseSpeed
		elseif trackName == "Run" then
			baseSpeed = Cfg.MoveAnim.RunBaseSpeed
		end

		local adjusted = speed / baseSpeed
		adjusted *= self.WalkSpeedScale
		adjusted = math.clamp(adjusted, Cfg.MoveAnim.AdjustMin, Cfg.MoveAnim.AdjustMax)

		track:AdjustSpeed(adjusted)
	end
end

function Sheep:WarnInvalidActionOnce(actionName, reason)
	if not Cfg.Debug or not Cfg.Debug.PrintInvalidActions then
		return
	end

	if self.InvalidActionWarnings[actionName] then
		return
	end

	self.InvalidActionWarnings[actionName] = true

	warn("[Sheep] Acción inválida ignorada:", actionName, "-", reason or "sin razón", "en", self.Model and self.Model.Name or "oveja")
end

function Sheep:IsSequencePlayable(sequenceName)
	local sequenceData = Cfg.Sequences and Cfg.Sequences[sequenceName]

	if not sequenceData then
		return false, "no existe en Cfg.Sequences"
	end

	local validLoops = self:GetValidSequenceLoops(sequenceData)

	if #validLoops == 0 then
		return false, "no tiene loops válidos"
	end

	if sequenceData.Start and not self.Tracks[sequenceData.Start] then
		return false, "falta Start: " .. tostring(sequenceData.Start)
	end

	local hasEnd = false

	if sequenceData.End and self.Tracks[sequenceData.End] then
		hasEnd = true
	end

	if sequenceData.FallbackEnd and self.Tracks[sequenceData.FallbackEnd] then
		hasEnd = true
	end

	if sequenceData.ExitBeforeMove ~= false and not hasEnd then
		return false, "falta End o FallbackEnd válido"
	end

	return true
end

function Sheep:IsIdleActionPlayable(actionName)
	if self:IsSequenceAction(actionName) then
		return self:IsSequencePlayable(actionName)
	end

	if self.Tracks[actionName] then
		return true
	end

	return false, "no existe track cargado"
end

function Sheep:GetPlayableIdleActions()
	local playable = {}

	for _, item in ipairs(Cfg.IdleActions) do
		local actionName = item.Name
		local ok, reason = self:IsIdleActionPlayable(actionName)

		if ok then
			table.insert(playable, item)
		else
			self:WarnInvalidActionOnce(actionName, reason)
		end
	end

	return playable
end

function Sheep:PlayIdleAction(actionName)
	if self:IsSequenceAction(actionName) then
		self:PlaySequenceAction(actionName)
		return
	end

	local track = self.Tracks[actionName]

	if not track then
		self:PlayIdleBase(0.3)
		return
	end

	self:StopMoveTracks(nil, 0.2)
	self:StopTrack("Idle", 0.2)
	self:StopIdleActions(0.25)

	self.CurrentIdleAction = actionName

	track:Play(0.3)
	track:AdjustSpeed(self.Rng:NextNumber(0.9, 1.1))
end

function Sheep:ChooseIdleAction(now)
	local playableActions = self:GetPlayableIdleActions()

	if #playableActions == 0 then
		if self.Model and Cfg.Debug.SetDebugAttributes then
			self.Model:SetAttribute("IdleAction", "None")
		end

		self:PlayIdleBase(0.3)
		self.NextIdleChange = now + self.Rng:NextNumber(Cfg.IdleTime.Min, Cfg.IdleTime.Max)
		return
	end

	local item = Rand.pickWeighted(playableActions, self.Rng)

	if item then
		if self.Model and Cfg.Debug.SetDebugAttributes then
			self.Model:SetAttribute("IdleAction", item.Name)
		end

		self:PlayIdleAction(item.Name)
	else
		if self.Model and Cfg.Debug.SetDebugAttributes then
			self.Model:SetAttribute("IdleAction", "Idle")
		end

		self:PlayIdleBase(0.3)
	end

	self.NextIdleChange = now + self.Rng:NextNumber(Cfg.IdleTime.Min, Cfg.IdleTime.Max)
end

-- =========================================================================
-- Movimiento auxiliar
-- =========================================================================

function Sheep:CalculateSeparation(positions)
	local separation = Vector3.zero

	if not positions then
		return separation
	end

	for _, item in ipairs(positions) do
		if item.Sheep ~= self then
			local otherPosition = item.Position
			local away = self.Root.Position - otherPosition
			local dist = flatVector(away).Magnitude

			if dist > 0.001 and dist < Cfg.Flock.SeparationRadius then
				local strength = (Cfg.Flock.SeparationRadius - dist) / Cfg.Flock.SeparationRadius
				local awayDir = getFlatDirection(away)

				if awayDir then
					separation += awayDir * strength
				end
			end
		end
	end

	return separation
end

function Sheep:RefreshObstacleFilter()
	local filter = { self.Model }

	local sheepRuntime = workspace:FindFirstChild((Cfg.Names and Cfg.Names.Runtime) or "SheepRuntime")
	if sheepRuntime then
		table.insert(filter, sheepRuntime)
	end

	local homeRuntime = workspace:FindFirstChild("HomeRuntime")
	if homeRuntime then
		table.insert(filter, homeRuntime)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(filter, player.Character)
		end
	end

	if self.ObstacleParams then
		self.ObstacleParams.FilterDescendantsInstances = filter
	end
end

function Sheep:CastObstacle(direction, distance)
	if not self.Root or not self.Root.Parent then
		return nil
	end

	local flatDirection = getFlatDirection(direction)
	if not flatDirection then
		return nil
	end

	self:RefreshObstacleFilter()

	local origin = self.Root.Position + Vector3.new(0, OBSTACLE_CHECK_HEIGHT, 0)
	local castDirection = flatDirection * (distance or OBSTACLE_CHECK_DISTANCE)

	local ok, result = pcall(function()
		return workspace:Spherecast(origin, OBSTACLE_SPHERE_RADIUS, castDirection, self.ObstacleParams)
	end)

	if ok then
		return result
	end

	return workspace:Raycast(origin, castDirection, self.ObstacleParams)
end

function Sheep:FindClearAlternativeDirection(direction, normal)
	local flatDirection = getFlatDirection(direction)
	if not flatDirection then
		return nil
	end

	local candidates = {}
	local flatNormal = normal and getFlatDirection(normal) or nil
	if flatNormal then
		local tangent = Vector3.new(-flatNormal.Z, 0, flatNormal.X)
		if tangent:Dot(flatDirection) < 0 then
			tangent = -tangent
		end

		table.insert(candidates, tangent)
		table.insert(candidates, -tangent)
	end

	for _, angle in ipairs({ math.rad(45), math.rad(-45), math.rad(90), math.rad(-90) }) do
		local candidate = rotateFlatDirection(flatDirection, angle)
		if candidate then
			table.insert(candidates, candidate)
		end
	end

	for _, candidate in ipairs(candidates) do
		if candidate and not self:CastObstacle(candidate, math.max(OBSTACLE_CHECK_DISTANCE * 0.7, 1.5)) then
			return candidate
		end
	end

	return nil
end

function Sheep:GetObstacleAvoidanceDirection(direction)
	local now = os.clock()
	local finalDirection = getFlatDirection(direction)
	if not finalDirection then
		return nil, false
	end

	if self.ObstacleAvoidDirection and now < (self.ObstacleAvoidUntil or 0) then
		finalDirection = getFlatDirection(finalDirection * 0.2 + self.ObstacleAvoidDirection * 1.2) or self.ObstacleAvoidDirection
	end

	local hit = self:CastObstacle(finalDirection)
	if not hit then
		return finalDirection, false
	end

	self.LastObstacleAt = now
	self.LastObstacleNormal = hit.Normal

	local normal = getFlatDirection(hit.Normal) or -finalDirection
	local slide = finalDirection - normal * finalDirection:Dot(normal)
	slide = getFlatDirection(slide)

	local alternative = self:FindClearAlternativeDirection(finalDirection, normal)
	if alternative then
		self.ObstacleAvoidDirection = alternative
		self.ObstacleAvoidUntil = now + 0.75
		return getFlatDirection(finalDirection * 0.08 + alternative * 1.35 + normal * 0.3) or alternative, true
	end

	local side = Vector3.new(-finalDirection.Z, 0, finalDirection.X)
	if side:Dot(normal) < 0 then
		side = -side
	end

	local adjusted = getFlatDirection(finalDirection * 0.05 + (slide or side) * 1.25 + normal * OBSTACLE_TURN_WEIGHT)
	if not adjusted then
		return nil, true
	end

	local stillBlocked = self:CastObstacle(adjusted, math.max(OBSTACLE_CHECK_DISTANCE * 0.55, 1.4))
	if stillBlocked and (stillBlocked.Distance or 0) <= OBSTACLE_SPHERE_RADIUS + 0.25 then
		return nil, true
	end

	self.ObstacleAvoidDirection = adjusted
	self.ObstacleAvoidUntil = now + 0.55
	return adjusted, true
end

function Sheep:UpdateStuckRecovery(direction, hitObstacle, now)
	if not self.Root or not self.Root.Parent then
		return nil
	end

	if self.ObstacleAvoidDirection and now < (self.ObstacleAvoidUntil or 0) then
		return self.ObstacleAvoidDirection
	end

	if not self.LastMoveCheckAt or now - self.LastMoveCheckAt < 0.35 then
		return nil
	end

	local moved = flatDistance(self.Root.Position, self.LastMovePosition or self.Root.Position)
	local elapsed = now - self.LastMoveCheckAt

	if moved < 0.14 then
		self.MoveStuckTime += elapsed
	elseif not hitObstacle then
		self.MoveStuckTime = 0
	end

	self.LastMovePosition = self.Root.Position
	self.LastMoveCheckAt = now

	if self.MoveStuckTime < 1.5 then
		return nil
	end

	local recovery = self:FindClearAlternativeDirection(direction, self.LastObstacleNormal)
	if recovery then
		self.MoveStuckTime = 0
		self.ObstacleAvoidDirection = recovery
		self.ObstacleAvoidUntil = now + 1.0
		return recovery
	end

	return nil
end

function Sheep:MoveInDirection(direction, speed, state)
	local now = os.clock()
	local finalDirection = getFlatDirection(direction)

	if not finalDirection then
		self.LinearVelocity.VectorVelocity = Vector3.zero
		return
	end

	local avoidedDirection, hitObstacle = self:GetObstacleAvoidanceDirection(finalDirection)
	if hitObstacle and not avoidedDirection then
		avoidedDirection = self:UpdateStuckRecovery(finalDirection, true, now)
		if not avoidedDirection then
			self.LinearVelocity.VectorVelocity = Vector3.zero
			return
		end
	end

	finalDirection = avoidedDirection or finalDirection

	local recoveryDirection = self:UpdateStuckRecovery(finalDirection, hitObstacle, now)
	if recoveryDirection then
		finalDirection = getFlatDirection(finalDirection * 0.2 + recoveryDirection * 1.25) or recoveryDirection
	end

	local stepDistance = math.max((speed or 0) * (Cfg.Update.AI or 0.1), 1.2)
	local blockingHit = self:CastObstacle(finalDirection, stepDistance + OBSTACLE_SPHERE_RADIUS)
	local blockingNormal = blockingHit and getFlatDirection(blockingHit.Normal)
	if blockingHit and (blockingHit.Distance or 0) <= stepDistance + OBSTACLE_SPHERE_RADIUS and (not blockingNormal or finalDirection:Dot(blockingNormal) < -0.2) then
		local alternative = self:FindClearAlternativeDirection(finalDirection, blockingNormal)
		if alternative and not self:CastObstacle(alternative, stepDistance + OBSTACLE_SPHERE_RADIUS) then
			self.ObstacleAvoidDirection = alternative
			self.ObstacleAvoidUntil = now + 1.0
			finalDirection = getFlatDirection(finalDirection * 0.1 + alternative * 1.3) or alternative
		else
			self.LinearVelocity.VectorVelocity = Vector3.zero
			return
		end
	end

	self:SetState(state)

	self.LinearVelocity.VectorVelocity = finalDirection * speed
	self.AlignOrientation.CFrame = CFrame.lookAt(Vector3.zero, finalDirection, Vector3.yAxis)

	self:PlayMoveAnim(state, speed)
end

function Sheep:StopMovementAndIdle(now)
	if self:HandleSequence(now, false) then
		return
	end

	self:SetState("Idle")
	self.LinearVelocity.VectorVelocity = Vector3.zero
	self.CalmMoveUntil = 0
	self.CalmDirection = nil
	self.MoveStuckTime = 0
	self.ObstacleAvoidDirection = nil
	self.ObstacleAvoidUntil = 0
	self.LastMovePosition = self.Root.Position
	self.LastMoveCheckAt = now

	local lookDirection = getFlatDirection(self.Root.CFrame.LookVector)

	if lookDirection then
		self.AlignOrientation.CFrame = CFrame.lookAt(Vector3.zero, lookDirection, Vector3.yAxis)
	end

	self:StopMoveTracks(nil, 0.25)

	local currentAction = self.CurrentIdleAction and self.Tracks[self.CurrentIdleAction]

	if currentAction and not currentAction.Looped and not currentAction.IsPlaying then
		self.CurrentIdleAction = nil
		self:PlayIdleBase(0.25)
	end

	if now >= self.NextIdleChange then
		self:ChooseIdleAction(now)
	elseif not self.CurrentIdleAction then
		local idle = self.Tracks.Idle
		if idle and not idle.IsPlaying then
			idle:Play(0.25)
		end
	end
end

-- =========================================================================
-- Física
-- =========================================================================

function Sheep:StepPhysics(dt)
	if not self.Root or not self.Root.Parent then
		return
	end

	local origin = self.Root.Position + Vector3.new(0, 0.25, 0)
	local direction = Vector3.new(0, -Cfg.Hover.RayLength, 0)

	local result = workspace:Raycast(origin, direction, self.RaycastParams)

	if result then
		local alturaActual = result.Distance

		local alpha = math.clamp(dt * Cfg.Hover.HeightSmoothing, 0, 1)
		self.HeightFiltered = self.HeightFiltered + (alturaActual - self.HeightFiltered) * alpha

		local errorAltura = Cfg.Hover.TargetHeight - self.HeightFiltered
		local velocidadVertical = self.Root.AssemblyLinearVelocity.Y

		local peso = self.Root.AssemblyMass * workspace.Gravity
		local correccion = (errorAltura * Cfg.Hover.Spring) - (velocidadVertical * Cfg.Hover.Damping)

		local limite = peso * Cfg.Hover.MaxCorrectionRatio
		correccion = math.clamp(correccion, -limite, limite)

		local fuerzaFinal = peso + correccion

		self.HoverForce.Force = Vector3.new(0, fuerzaFinal, 0)
	else
		self.HoverForce.Force = Vector3.zero
	end
end

-- =========================================================================
-- IA: reacción, calma, flow y pérdida
-- =========================================================================

function Sheep:GetReactionDelay(isLeader)
	if isLeader then
		return self.Rng:NextNumber(Cfg.Response.LeaderDelayMin, Cfg.Response.LeaderDelayMax)
	end

	local sequenceName = self.SequenceName

	if sequenceName == "Sleep" then
		return self.Rng:NextNumber(Cfg.Response.SleepDelayMin, Cfg.Response.SleepDelayMax) * self.Personality.Laziness
	end

	if sequenceName == "LieLook" then
		return self.Rng:NextNumber(Cfg.Response.LieDelayMin, Cfg.Response.LieDelayMax) * self.Personality.Laziness
	end

	if sequenceName == "Eat" then
		return self.Rng:NextNumber(Cfg.Response.EatDelayMin, Cfg.Response.EatDelayMax) * self.Personality.Laziness
	end

	if self.CurrentIdleAction then
		return self.Rng:NextNumber(Cfg.Response.BusyDelayMin, Cfg.Response.BusyDelayMax)
	end

	return self.Rng:NextNumber(Cfg.Response.FreeDelayMin, Cfg.Response.FreeDelayMax)
end

function Sheep:CanRespondToMovement(now, movementRequested, isLeader)
	if not movementRequested then
		self.ReactAt = 0
		return false
	end

	if self.ReactAt <= 0 then
		self.ReactAt = now + self:GetReactionDelay(isLeader)
	end

	return now >= self.ReactAt
end

function Sheep:ResetMovementReaction()
	self.ReactAt = 0
	self.SpeedModeUntil = 0
	self.SpeedMode = nil
end

function Sheep:PickMoveMode(now, panic)
	if now < self.SpeedModeUntil and self.SpeedMode then
		return self.SpeedMode
	end

	local roll = self.Rng:NextNumber()
	local mode = "Trot"

	if panic then
		if roll <= Cfg.Response.PanicRunChance then
			mode = "Run"
		elseif roll <= Cfg.Response.PanicRunChance + Cfg.Response.PanicTrotChance then
			mode = "Trot"
		else
			mode = "Walk"
		end
	else
		if roll <= Cfg.Response.RunChance then
			mode = "Run"
		elseif roll <= Cfg.Response.RunChance + Cfg.Response.TrotChance then
			mode = "Trot"
		else
			mode = "Walk"
		end
	end

	self.SpeedMode = mode
	self.SpeedModeUntil = now + self.Rng:NextNumber(
		Cfg.Response.MoveModeDurationMin,
		Cfg.Response.MoveModeDurationMax
	)

	return mode
end

function Sheep:GetVariedMoveSpeed(now, baseSpeed, moveState, panic, isLeader)
	local mode = self:PickMoveMode(now, panic)

	local energy = 1
	if self.Personality and self.Personality.Energy then
		energy = self.Personality.Energy
	end

	if isLeader and mode == "Walk" then
		mode = "Trot"
	end

	if mode == "Walk" then
		return self.Rng:NextNumber(Cfg.Response.WalkSpeedMin, Cfg.Response.WalkSpeedMax), isLeader and "GuideWalk" or "FlockWalk"
	end

	if mode == "Run" then
		return self.Rng:NextNumber(Cfg.Response.RunSpeedMin, Cfg.Response.RunSpeedMax) * energy, isLeader and "GuideRun" or "PanicMove"
	end

	return self.Rng:NextNumber(Cfg.Response.TrotSpeedMin, Cfg.Response.TrotSpeedMax) * energy, isLeader and "GuideTrot" or moveState
end

function Sheep:GetCalmMoveSpeed(isLeader)
	local energy = 1
	if self.Personality and self.Personality.Energy then
		energy = self.Personality.Energy
	end

	if isLeader then
		return self.Rng:NextNumber(1.8, Cfg.Calm.LeaderWanderSpeed)
	end

	local roll = self.Rng:NextNumber()

	if roll <= Cfg.Calm.BurstChance then
		return self.Rng:NextNumber(Cfg.Calm.BurstSpeedMin, Cfg.Calm.BurstSpeedMax) * energy
	end

	return self.Rng:NextNumber(Cfg.Calm.WanderSpeedMin, Cfg.Calm.WanderSpeedMax) * energy
end

function Sheep:IsLostFromFlock(flockData, isLeader)
	if isLeader then
		return false
	end

	if not self.Root or not self.Root.Parent then
		return false
	end

	local leaderPosition = flockData.LeaderPosition
	local center = flockData.Center

	local lost = false
	local maxDistance = 0

	if leaderPosition then
		local distToLeader = flatDistance(self.Root.Position, leaderPosition)
		maxDistance = math.max(maxDistance, distToLeader)

		if distToLeader > Cfg.Lost.LeaderDistance then
			lost = true
		end
	end

	if center then
		local distToCenter = flatDistance(self.Root.Position, center)
		maxDistance = math.max(maxDistance, distToCenter)

		if distToCenter > Cfg.Lost.CenterDistance then
			lost = true
		end
	end

	return lost, maxDistance
end

function Sheep:MoveBackToFlock(now, flockData, lostDistance)
	local direction = Vector3.zero

	local leaderPosition = flockData.LeaderPosition
	local center = flockData.Center
	local positions = flockData.Positions

	if leaderPosition then
		local toLeader = getFlatDirection(leaderPosition - self.Root.Position)

		if toLeader then
			direction += toLeader * Cfg.Lost.WeightLeader
		end
	end

	if center then
		local toCenter = getFlatDirection(center - self.Root.Position)

		if toCenter then
			direction += toCenter * Cfg.Lost.WeightCenter
		end
	end

	local separation = self:CalculateSeparation(positions)
	direction += separation * Cfg.Lost.WeightSeparate

	self.CalmDirection = nil
	self.CalmMoveUntil = 0
	self.CalmChosenSpeed = nil
	self.CalmMoveState = "CalmWalk"

	self:ResetMovementReaction()

	local energy = 1

	if self.Personality and self.Personality.Energy then
		energy = self.Personality.Energy
	end

	local speed
	local state

	if lostDistance >= Cfg.Lost.CriticalDistance then
		speed = self.Rng:NextNumber(Cfg.Lost.CriticalSpeedMin, Cfg.Lost.CriticalSpeedMax) * energy
		state = "LostRun"
	else
		speed = self.Rng:NextNumber(Cfg.Lost.RegroupSpeedMin, Cfg.Lost.RegroupSpeedMax) * energy
		state = "Regroup"
	end

	self:MoveInDirection(direction, speed, state)
end

function Sheep:GetFlowMoveDirection(flockData)
	local moveDirection = flockData.MoveDirection
	local flow = flockData.Flow

	local direction = Vector3.zero

	if moveDirection then
		direction += moveDirection * Cfg.Flow.ForwardWeight
	end

	if flow and flow.Slots then
		local slotPosition = flow.Slots[self]

		if slotPosition then
			local toSlotVector = slotPosition - self.Root.Position
			local toSlot = getFlatDirection(toSlotVector)

			if toSlot then
				local distToSlot = flatVector(toSlotVector).Magnitude
				local pull = math.clamp(distToSlot / Cfg.Flow.SlotMaxPullDistance, 0.15, 1)

				if moveDirection then
					local aheadAmount = flatVector(self.Root.Position - slotPosition):Dot(moveDirection)

					if aheadAmount > Cfg.Flow.AheadSoftLimit then
						pull *= 0.15
					end
				end

				direction += toSlot * Cfg.Flow.SlotPull * pull
			end
		end
	end

	if flockData.Center then
		local distToCenter = flatDistance(self.Root.Position, flockData.Center)

		if distToCenter > Cfg.Flock.CohesionRadius then
			local toCenter = getFlatDirection(flockData.Center - self.Root.Position)

			if toCenter then
				direction += toCenter * Cfg.Flow.CenterWeight
			end
		end
	end

	return direction
end

function Sheep:StepCalm(now, flockData)
	local center = flockData.Center
	local positions = flockData.Positions

	if self.CalmDirection and now < self.CalmMoveUntil then
		local direction = self.CalmDirection

		local separation = self:CalculateSeparation(positions)
		direction += separation * Cfg.Calm.WeightSeparate

		if center then
			local distToCenter = flatDistance(self.Root.Position, center)

			if distToCenter > Cfg.Calm.SoftReturnDistance then
				local toCenter = getFlatDirection(center - self.Root.Position)

				if toCenter then
					local strength = math.clamp(distToCenter / Cfg.Calm.MaxCalmDistanceFromCenter, 0.2, 1)
					direction += toCenter * Cfg.Calm.WeightCenter * strength
				end
			end
		end

		local speed = self.CalmChosenSpeed or Cfg.Calm.WanderSpeed
		local state = self.CalmMoveState or "CalmWalk"

		self:MoveInDirection(direction, speed, state)
		return true
	end

	if self.CalmDirection and now >= self.CalmMoveUntil then
		self.CalmDirection = nil
		self.CalmMoveUntil = 0
		self.CalmChosenSpeed = nil
		self.CalmMoveState = "CalmWalk"
		self:ScheduleNextCalmMove(now)
		return false
	end

	if self.CurrentIdleAction then
		return false
	end

	if now < self.NextCalmMove then
		return false
	end

	self:ScheduleNextCalmMove(now)

	if self.Rng:NextNumber() > Cfg.Calm.WanderChance then
		return false
	end

	local direction = Vector3.zero

	local randomDirection = self:GetRandomFlatDirection()
	direction += randomDirection * Cfg.Calm.WeightRandom

	local separation = self:CalculateSeparation(positions)
	direction += separation * Cfg.Calm.WeightSeparate

	if center then
		local distToCenter = flatDistance(self.Root.Position, center)

		if distToCenter > Cfg.Calm.SoftReturnDistance then
			local toCenter = getFlatDirection(center - self.Root.Position)

			if toCenter then
				local strength = math.clamp(distToCenter / Cfg.Calm.MaxCalmDistanceFromCenter, 0.25, 1.25)
				direction += toCenter * Cfg.Calm.WeightCenter * strength
			end
		end
	end

	local finalDirection = getFlatDirection(direction)
	if not finalDirection then
		return false
	end

	self.CalmDirection = finalDirection
	self.CalmMoveUntil = now + self.Rng:NextNumber(Cfg.Calm.MoveDurationMin, Cfg.Calm.MoveDurationMax)

	local isLeader = flockData.Leader == self
	local speed = self:GetCalmMoveSpeed(isLeader)

	self.CalmChosenSpeed = speed

	if speed >= Cfg.MoveAnim.TrotSpeedThreshold then
		self.CalmMoveState = "CalmTrot"
	else
		self.CalmMoveState = "CalmWalk"
	end

	self:MoveInDirection(finalDirection, speed, self.CalmMoveState)
	return true
end

function Sheep:StepAI(now, flockData)
	if not self.Root or not self.Root.Parent then
		return
	end

	flockData = flockData or {}
	local myFlockData = {}
	for k, v in pairs(flockData) do myFlockData[k] = v end
	flockData = myFlockData

	if flockData.PenCenter then
		local distToPen = flatDistance(self.Root.Position, flockData.PenCenter)
		local isInsidePen = distToPen <= (flockData.PenRadius + 1.5)

		if not flockData.PenIsOpen then
			self.Model:SetAttribute("JustReleased", false)
			if isInsidePen then
				flockData.OwnerRoot = nil
				flockData.Center = flockData.PenCenter
				flockData.LeaderPosition = nil
				flockData.IsMoving = false
				flockData.MoveDirection = nil

				if distToPen > (flockData.PenRadius - 2.5) then
					local toCenter = getFlatDirection(flockData.PenCenter - self.Root.Position)
					if toCenter then
						self.State = "Walk"
						self.CurrentSequence = nil
						self:ResetMovementReaction()
						self:MoveInDirection(toCenter, 8, "Walk")
						return
					end
				end
			end
		else
			if isInsidePen then
				self.Model:SetAttribute("JustReleased", true)
			end

			local maxRange = flockData.PenRadius + (flockData.PenApproachRadius or 12)
			if self.Model:GetAttribute("JustReleased") and distToPen > maxRange then
				self.Model:SetAttribute("JustReleased", false)
			end

			local movReq = flockData.IsMoving and flockData.MoveDirection
			if flockData.PenApproachCenter and not movReq and not self.Model:GetAttribute("JustReleased") then
				local distToApp = flatDistance(self.Root.Position, flockData.PenApproachCenter)
				if distToApp <= flockData.PenApproachRadius and distToPen > 3 then
					local toPen = getFlatDirection(flockData.PenCenter - self.Root.Position)
					if toPen then
						self.CalmDirection = nil
						self.CalmMoveUntil = 0
						self:ResetMovementReaction()
						self:MoveInDirection(toPen, 11, "Trot")
						return
					end
				end
			end
		end
	end

	local isLeader = flockData.Leader == self
	local center = flockData.Center
	local leaderPosition = flockData.LeaderPosition
	local ownerRoot = flockData.OwnerRoot
	local positions = flockData.Positions
	local movementRequested = flockData.IsMoving and flockData.MoveDirection
	local isLost, lostDistance = self:IsLostFromFlock(flockData, isLeader)

	local canRespondToMovement = self:CanRespondToMovement(now, movementRequested, isLeader)
	local shouldExitSequence = isLost or canRespondToMovement

	-- LÓGICA EXCLUSIVA DEL BASTÓN: Solo se activa si recibió el clic (spookTime > now)
	local spookTime = self.Model:GetAttribute("BastonSpookTime") or 0
	if now < spookTime then
		local bastonFlee = self.Model:GetAttribute("BastonFleeDir")
		if bastonFlee then
			-- Interrupción absoluta SOLO por uso de la herramienta
			if self.State ~= "PanicMove" then
				warn("<font color='rgb(255, 50, 50)'>[⚠️ BASTÓN] Oveja interrumpida de su estado actual por la ráfaga de viento.</font>")
				self.State = "PanicMove"
				self.CurrentSequence = nil
				self:ResetMovementReaction()
			end
			
			if not self.Model:GetAttribute("BastonLogCooldown") or now > self.Model:GetAttribute("BastonLogCooldown") then
				print("<font color='rgb(255, 100, 255)'>[🐑 IA OVEJA] Huida por BASTÓN! Faltan: " .. string.format("%.1f", spookTime - now) .. "s</font>")
				self.Model:SetAttribute("BastonLogCooldown", now + 1)
			end
			
			self:MoveInDirection(bastonFlee, 18, "Run")
			return
		end
	end

	if self:HandleSequence(now, shouldExitSequence) then
		return
	end
	if isLost then
		self:MoveBackToFlock(now, flockData, lostDistance)
		return
	end

	if movementRequested and not canRespondToMovement then
		self.LinearVelocity.VectorVelocity = Vector3.zero

		if not self.SequenceActive and not self.SequenceEnding then
			self:SetState("DelayedReact")
		end

		return
	end

	if not movementRequested then
		self:ResetMovementReaction()
	end

	if flockData.IsMoving and flockData.MoveDirection then
		self.CalmDirection = nil
		self.CalmMoveUntil = 0
		self.CalmChosenSpeed = nil
		self.CalmMoveState = "CalmWalk"

		local direction = self:GetFlowMoveDirection(flockData)

		if direction.Magnitude < 0.001 then
			direction = flockData.MoveDirection
		end

		local panic = false

		if ownerRoot then
			local distToPlayer = flatDistance(self.Root.Position, ownerRoot.Position)

			if distToPlayer <= Cfg.Radius then
				local awayFromPlayer = getFlatDirection(self.Root.Position - ownerRoot.Position)

				if awayFromPlayer then
					local strength = math.clamp((Cfg.Radius - distToPlayer) / Cfg.Radius, 0.25, 1)
					direction += awayFromPlayer * Cfg.Flow.PlayerFleeWeight * strength
				end

				if distToPlayer <= Cfg.MoveAnim.PanicDistance then
					panic = true
				end
			end
		end

		local separation = self:CalculateSeparation(positions)
		direction += separation * Cfg.Flow.SeparationWeight

		local natural = self:GetNaturalDirection(now)
		direction += natural * Cfg.Flow.NaturalWeight

		local speed = isLeader and Cfg.Flock.LeaderSpeed or Cfg.Flock.MoveSpeed
		local moveState = isLeader and "GuideTrot" or "FlockMove"

		if center then
			local distToCenter = flatDistance(self.Root.Position, center)

			if distToCenter > Cfg.Flock.MaxGroupDistance then
				speed += 2
			end
		end

		if panic then
			speed = Cfg.MoveAnim.PanicSpeed
			moveState = "PanicMove"
		end

		speed, moveState = self:GetVariedMoveSpeed(now, speed, moveState, panic, isLeader)

		self:MoveInDirection(direction, speed, moveState)
		return
	end

	if not isLeader and leaderPosition then
		local distToLeader = flatDistance(self.Root.Position, leaderPosition)

		if distToLeader > Cfg.Flock.MaxGroupDistance then
			self.CalmDirection = nil
			self.CalmMoveUntil = 0
			self.CalmChosenSpeed = nil
			self.CalmMoveState = "CalmWalk"

			local direction = Vector3.zero

			local toLeader = getFlatDirection(leaderPosition - self.Root.Position)
			if toLeader then
				direction += toLeader * 1.2
			end

			if center then
				local toCenter = getFlatDirection(center - self.Root.Position)
				if toCenter then
					direction += toCenter * 0.7
				end
			end

			local separation = self:CalculateSeparation(positions)
			direction += separation * 0.8

			self:MoveInDirection(direction, Cfg.Flock.RegroupSpeed, "Regroup")
			return
		end
	end

	if flockData.GrazingZone and not movementRequested and not self.Model:GetAttribute("JustReleased") then
		local zoneRadius = (Cfg.Grazing and Cfg.Grazing.ZoneRadius) or 15
		local distToZoneCenter = flatDistance(self.Root.Position, flockData.GrazingZone)

		if distToZoneCenter <= (zoneRadius - 2) then
			if self.CalmDirection then
				local projectedDist = flatDistance(self.Root.Position + (self.CalmDirection * 4), flockData.GrazingZone)
				if projectedDist > zoneRadius - 1.5 then
					self.CalmDirection = getFlatDirection(flockData.GrazingZone - self.Root.Position)
				end
			end
		end
	end



	if self:StepCalm(now, flockData) then
		return
	end

	self:StopMovementAndIdle(now)
end

function Sheep:Destroy()
	self.SequenceToken += 1

	for _, track in pairs(self.Tracks) do
		if track then
			pcall(function()
				track:Stop(0)
				track:Destroy()
			end)
		end
	end

	table.clear(self.Tracks)

	if self.Model then
		self.Model:Destroy()
	end

	self.Model = nil
	self.Owner = nil
	self.House = nil
	self.Root = nil
	self.Animator = nil
	self.LinearVelocity = nil
	self.AlignOrientation = nil
	self.HoverForce = nil
end

return Sheep
