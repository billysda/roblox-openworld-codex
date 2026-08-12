local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local FoxController = {}
FoxController.__index = FoxController

local function flatVector(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function flatDirection(v)
	local flat = flatVector(v)
	if flat.Magnitude > 0.001 then
		return flat.Unit
	end
	return nil
end

local function flatDistance(a, b)
	return flatVector(a - b).Magnitude
end

local function getSheepRoot(model)
	if not model or not model.Parent then
		return nil
	end

	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function findHouseById(houseId)
	if typeof(houseId) ~= "number" then
		return nil
	end

	local houses = Workspace:FindFirstChild("Houses")
	if not houses then
		return nil
	end

	for _, house in ipairs(houses:GetChildren()) do
		if house:GetAttribute("HouseId") == houseId then
			return house
		end
	end

	return nil
end

local function isInsideSafePen(sheepModel, fallbackRadius)
	local root = getSheepRoot(sheepModel)
	if not root then
		return false
	end

	local house = findHouseById(sheepModel:GetAttribute("HouseId"))
	if not house then
		return false
	end

	local center = house:FindFirstChild("CorralCenter", true)
	if not center or not center:IsA("BasePart") then
		return false
	end

	local radius = house:GetAttribute("PenRadius")
	if typeof(radius) ~= "number" then
		radius = fallbackRadius or 12
	end

	return flatDistance(root.Position, center.Position) <= radius
end

function FoxController.GetValidSheepModels(captureService, cfg)
	local runtime = Workspace:FindFirstChild("SheepRuntime")
	if not runtime then
		return {}
	end

	local valid = {}
	local fallbackRadius = cfg.Fox.SafePenFallbackRadius or 12

	for _, child in ipairs(runtime:GetDescendants()) do
		if child:IsA("Model") then
			local root = getSheepRoot(child)
			if root
				and child:GetAttribute("Dead") ~= true
				and child:GetAttribute("CapturedByThreat") ~= true
				and child:GetAttribute("CapturedByDragon") ~= true
				and not captureService:IsCaptured(child)
				and not isInsideSafePen(child, fallbackRadius)
			then
				table.insert(valid, child)
			end
		end
	end

	return valid
end

function FoxController.GetClosestValidSheep(position, captureService, cfg, maxDistance)
	local best = nil
	local bestDistance = maxDistance or math.huge

	for _, sheep in ipairs(FoxController.GetValidSheepModels(captureService, cfg)) do
		local root = getSheepRoot(sheep)
		if root then
			local distance = flatDistance(position, root.Position)
			if distance <= bestDistance then
				best = sheep
				bestDistance = distance
			end
		end
	end

	return best, bestDistance
end

function FoxController.new(model, captureService, cfg, initialTarget)
	local self = setmetatable({}, FoxController)
	self.Model = model
	self.CaptureService = captureService
	self.Cfg = cfg
	self.FoxCfg = cfg.Fox
	self.Root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	self.Target = initialTarget
	self.CapturedSheep = nil
	self.State = "Seeking"
	self.StateStartedAt = os.clock()
	self.CreatedAt = os.clock()
	self.NextAttackAt = 0
	self.AttackHitChecked = false
	self.FleeTarget = nil
	self.Finished = false
	self.Tracks = {}
	self.CurrentMoveTrack = nil

	if not self.Root or not self.Root:IsA("BasePart") then
		warn("[FoxController] Fox sin HumanoidRootPart/PrimaryPart válido")
		self.Finished = true
		return self
	end

	self:SetupModel()
	self:SetupAnimation()
	self:SetupPhysics()
	self:SetState("Seeking")
	self:SetTarget(initialTarget)

	return self
end

function FoxController:DebugPrint(...)
	if self.FoxCfg.DebugPrints then
		print("[FoxController]", ...)
	end
end

function FoxController:SetState(state)
	self.State = state
	self.StateStartedAt = os.clock()
	if self.Model and self.Model.Parent then
		self.Model:SetAttribute("PredatorState", state)
	end
end

function FoxController:SetTarget(target)
	self.Target = target
	if self.Model and self.Model.Parent and self.FoxCfg.DebugAttributes then
		self.Model:SetAttribute("PredatorTargetSheep", target and target.Name or "")
	end
end

function FoxController:SetupModel()
	self.Model.PrimaryPart = self.Root
	self.Model:SetAttribute("PredatorType", "Fox")
	self.Model:SetAttribute("IsCarryingSheep", false)

	for _, desc in ipairs(self.Model:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Anchored = false
			desc.CanCollide = false
			desc.CanTouch = false
			pcall(function()
				desc:SetNetworkOwner(nil)
			end)
		end
	end
end

function FoxController:SetupAnimation()
	local controller = self.Model:FindFirstChildOfClass("AnimationController")
	local animator = controller and controller:FindFirstChildOfClass("Animator")
	if not animator then
		warn("[FoxController] Animator no encontrado en", self.Model:GetFullName())
		return
	end

	local folder = self.Model:FindFirstChild("PredatorAnimations")
	if not folder then
		warn("[FoxController] PredatorAnimations no encontrado")
		return
	end

	local function load(name, priority, looped)
		local animation = folder:FindFirstChild(name)
		if not animation or not animation:IsA("Animation") or animation.AnimationId == "" then
			return
		end

		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if not ok or not track then
			warn("[FoxController] No se pudo cargar", name)
			return
		end

		track.Priority = priority
		track.Looped = looped
		self.Tracks[name] = track
	end

	load("Run", Enum.AnimationPriority.Movement, true)
	load("CarryRun", Enum.AnimationPriority.Movement, true)
	load("Pounce", Enum.AnimationPriority.Action, false)
end

function FoxController:SetupPhysics()
	local root = self.Root
	local attachment = root:FindFirstChild("PredatorAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "PredatorAttachment"
		attachment.Parent = root
	end
	self.Attachment = attachment

	local velocity = root:FindFirstChild("PredatorLinearVelocity")
	if not velocity then
		velocity = Instance.new("LinearVelocity")
		velocity.Name = "PredatorLinearVelocity"
		velocity.Parent = root
	end
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	velocity.MaxAxesForce = Vector3.new(self.FoxCfg.MoveForce, 0, self.FoxCfg.MoveForce)
	velocity.VectorVelocity = Vector3.zero
	self.LinearVelocity = velocity

	local align = root:FindFirstChild("PredatorAlignOrientation")
	if not align then
		align = Instance.new("AlignOrientation")
		align.Name = "PredatorAlignOrientation"
		align.Parent = root
	end
	align.Attachment0 = attachment
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Responsiveness = self.FoxCfg.TurnResponsiveness
	align.MaxTorque = self.FoxCfg.TurnTorque
	align.RigidityEnabled = false
	self.AlignOrientation = align

	local hover = root:FindFirstChild("PredatorHoverForce")
	if not hover then
		hover = Instance.new("VectorForce")
		hover.Name = "PredatorHoverForce"
		hover.Parent = root
	end
	hover.Attachment0 = attachment
	hover.RelativeTo = Enum.ActuatorRelativeTo.World
	hover.ApplyAtCenterOfMass = true
	hover.Force = Vector3.zero
	self.HoverForce = hover

	self.GroundParams = RaycastParams.new()
	self.GroundParams.FilterType = Enum.RaycastFilterType.Exclude
	self.GroundParams.IgnoreWater = true
	self:RefreshGroundFilter()
end

function FoxController:RefreshGroundFilter()
	local filter = { self.Model }
	local sheepRuntime = Workspace:FindFirstChild("SheepRuntime")
	local predatorRuntime = Workspace:FindFirstChild(self.Cfg.RuntimeFolder)
	if sheepRuntime then
		table.insert(filter, sheepRuntime)
	end
	if predatorRuntime then
		table.insert(filter, predatorRuntime)
	end
	self.GroundParams.FilterDescendantsInstances = filter
end

function FoxController:StopTrack(name, fade)
	local track = self.Tracks[name]
	if track and track.IsPlaying then
		track:Stop(fade or 0.1)
	end
end

function FoxController:PlayMoveTrack(name)
	if self.CurrentMoveTrack == name then
		local current = self.Tracks[name]
		if current and current.IsPlaying then
			return
		end
	end

	for _, trackName in ipairs({ "Run", "CarryRun" }) do
		if trackName ~= name then
			self:StopTrack(trackName, 0.12)
		end
	end

	local track = self.Tracks[name]
	if track and not track.IsPlaying then
		track:Play(0.12)
	end
	self.CurrentMoveTrack = name
end

function FoxController:PlayPounce()
	self:StopTrack("Run", 0.08)
	self:StopTrack("CarryRun", 0.08)
	self.CurrentMoveTrack = nil
	local track = self.Tracks.Pounce
	if track then
		track:Play(0.05)
	end
end

function FoxController:StopMovement()
	if self.LinearVelocity then
		self.LinearVelocity.VectorVelocity = Vector3.zero
	end
end

function FoxController:Move(direction, speed, trackName)
	local dir = flatDirection(direction)
	if not dir then
		self:StopMovement()
		return
	end

	self.LinearVelocity.VectorVelocity = dir * speed
	self.AlignOrientation.CFrame = CFrame.lookAt(Vector3.zero, dir, Vector3.yAxis)
	if trackName then
		self:PlayMoveTrack(trackName)
	end
end

function FoxController:IsTargetValid(target)
	if not target or not target.Parent then
		return false
	end
	if target:GetAttribute("Dead") == true
		or target:GetAttribute("CapturedByThreat") == true
		or target:GetAttribute("CapturedByDragon") == true
	then
		return false
	end
	if isInsideSafePen(target, self.FoxCfg.SafePenFallbackRadius) then
		return false
	end
	return getSheepRoot(target) ~= nil
end

function FoxController:AcquireTarget()
	local target = FoxController.GetClosestValidSheep(
		self.Root.Position,
		self.CaptureService,
		self.Cfg,
		self.FoxCfg.DetectionRadius
	)
	self:SetTarget(target)
	return target
end

function FoxController:BeginPounce(now)
	self:SetState("Pounce")
	self.StateStartedAt = now
	self.AttackHitChecked = false
	self:PlayPounce()
end

function FoxController:GetMouthDistanceToTarget(target)
	local root = getSheepRoot(target)
	local carryWorld = self.CaptureService:GetCarryWorldCFrame(self.Model)
	if not root or not carryWorld then
		return math.huge
	end
	return (carryWorld.Position - root.Position).Magnitude
end

function FoxController:ChooseFleeTarget(sheepModel)
	local origin = nil
	local house = findHouseById(sheepModel and sheepModel:GetAttribute("HouseId"))
	if house then
		local penCenter = house:FindFirstChild("CorralCenter", true)
		if penCenter and penCenter:IsA("BasePart") then
			origin = penCenter.Position
		end
	end

	if not origin and sheepModel then
		local ownerId = sheepModel:GetAttribute("OwnerId")
		if typeof(ownerId) == "number" then
			local player = Players:GetPlayerByUserId(ownerId)
			local character = player and player.Character
			local ownerRoot = character and character:FindFirstChild("HumanoidRootPart")
			if ownerRoot then
				origin = ownerRoot.Position
			end
		end
	end

	local away = origin and flatDirection(self.Root.Position - origin) or flatDirection(self.Root.CFrame.LookVector)
	if not away then
		away = Vector3.new(1, 0, 0)
	end
	return self.Root.Position + away * self.FoxCfg.FleeDistance
end

function FoxController:OnSuccessfulGrab(now)
	self.CapturedSheep = self.Target
	self.FleeTarget = self:ChooseFleeTarget(self.CapturedSheep)
	self:SetState("Carry")
	self.StateStartedAt = now
	self:PlayMoveTrack("CarryRun")
	self:DebugPrint("oveja capturada", self.CapturedSheep and self.CapturedSheep.Name or "?")
end

function FoxController:FinishCarry(reason)
	if self.CapturedSheep then
		self.CaptureService:Release(self.Model, self.CapturedSheep)
	end
	self.CapturedSheep = nil
	self:StopMovement()
	self:StopTrack("CarryRun", 0.12)
	self:SetState("Completed")
	self.Model:SetAttribute("PredatorResult", reason or "carry-complete")
	self.Finished = true
end

function FoxController:StepPhysics(dt)
	if self.Finished or not self.Root or not self.Root.Parent then
		return
	end

	self:RefreshGroundFilter()
	local result = Workspace:Raycast(
		self.Root.Position,
		Vector3.new(0, -self.FoxCfg.GroundRayLength, 0),
		self.GroundParams
	)

	if result then
		local currentHeight = result.Distance
		local errorHeight = self.FoxCfg.GroundTargetHeight - currentHeight
		local verticalSpeed = self.Root.AssemblyLinearVelocity.Y
		local weight = self.Root.AssemblyMass * Workspace.Gravity
		local correction = (errorHeight * self.FoxCfg.HoverSpring) - (verticalSpeed * self.FoxCfg.HoverDamping)
		local limit = weight * self.FoxCfg.HoverMaxCorrectionRatio
		correction = math.clamp(correction, -limit, limit)
		self.HoverForce.Force = Vector3.new(0, weight + correction, 0)
	else
		self.HoverForce.Force = Vector3.zero
	end

	if self.CapturedSheep then
		if not self.CaptureService:UpdateCarry(self.Model, self.CapturedSheep) then
			self:FinishCarry("carry-lost")
		end
	end
end

function FoxController:StepAI(now)
	if self.Finished or not self.Root or not self.Root.Parent then
		return
	end

	if self.State == "Carry" then
		if not self.CapturedSheep or not self.CapturedSheep.Parent then
			self:FinishCarry("sheep-missing")
			return
		end

		local elapsed = now - self.StateStartedAt
		local toFlee = self.FleeTarget and (self.FleeTarget - self.Root.Position) or nil
		if elapsed >= self.FoxCfg.CarryDuration or not toFlee or flatVector(toFlee).Magnitude <= 4 then
			self:FinishCarry("test-escape-complete")
			return
		end

		self:Move(toFlee, self.FoxCfg.FleeSpeed, "CarryRun")
		return
	end

	if self.Target and not self:IsTargetValid(self.Target) then
		self:SetTarget(nil)
	end

	if not self.Target then
		self:AcquireTarget()
	end

	if not self.Target then
		self:StopMovement()
		if now - self.CreatedAt >= self.FoxCfg.SearchTimeout then
			self:SetState("NoTarget")
			self.Finished = true
		end
		return
	end

	local targetRoot = getSheepRoot(self.Target)
	if not targetRoot then
		self:SetTarget(nil)
		return
	end

	if self.State == "Pounce" then
		local elapsed = now - self.StateStartedAt
		local toTarget = targetRoot.Position - self.Root.Position

		if elapsed <= self.FoxCfg.AttackHitTime + 0.08 then
			self:Move(toTarget, self.FoxCfg.PounceSpeed, nil)
		else
			self:StopMovement()
		end

		if not self.AttackHitChecked and elapsed >= self.FoxCfg.AttackHitTime then
			self.AttackHitChecked = true
			local mouthDistance = self:GetMouthDistanceToTarget(self.Target)
			if mouthDistance <= self.FoxCfg.AttackHitRadius then
				local grabbed = self.CaptureService:Grab(self.Model, self.Target)
				if grabbed then
					self:OnSuccessfulGrab(now)
					return
				end
			end
		end

		if elapsed >= self.FoxCfg.AttackDuration then
			self.NextAttackAt = now + self.FoxCfg.AttackCooldown
			self:SetState("Chase")
		end
		return
	end

	local toTarget = targetRoot.Position - self.Root.Position
	local distance = flatVector(toTarget).Magnitude

	if distance <= self.FoxCfg.AttackStartDistance and now >= self.NextAttackAt then
		self:BeginPounce(now)
		return
	end

	self:SetState("Chase")
	self:Move(toTarget, self.FoxCfg.ChaseSpeed, "Run")
end

function FoxController:Destroy()
	if self.CapturedSheep then
		self.CaptureService:Release(self.Model, self.CapturedSheep)
	end
	self.CaptureService:ReleaseAllForFox(self.Model)
	if self.Model and self.Model.Parent then
		self.Model:Destroy()
	end
	self.Finished = true
end

return FoxController
