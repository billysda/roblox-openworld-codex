local Flock = {}
Flock.__index = Flock

local Cfg = require(script.Parent:WaitForChild("Cfg"))
local Sheep = require(script.Parent:WaitForChild("Sheep"))

local function sortByName(a, b)
	return a.Name < b.Name
end

local function flatVector(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function flatDirection(vector)
	local flat = flatVector(vector)

	if flat.Magnitude > 0.001 then
		return flat.Unit
	end

	return nil
end

local function smoothDirection(current, desired, alpha)
	if not desired then
		return current
	end

	if not current then
		return desired
	end

	local blended = current:Lerp(desired, alpha)
	return flatDirection(blended) or desired
end

local function getRightVector(direction)
	if not direction then
		return Vector3.xAxis
	end

	local right = Vector3.new(direction.Z, 0, -direction.X)

	if right.Magnitude > 0.001 then
		return right.Unit
	end

	return Vector3.xAxis
end

local function readNumberAttribute(instance, name, fallback)
	local value = instance and instance:GetAttribute(name)
	if typeof(value) == "number" then
		return value
	end

	return fallback
end

local function readBooleanAttribute(instance, name, fallback)
	local value = instance and instance:GetAttribute(name)
	if typeof(value) == "boolean" then
		return value
	end

	return fallback
end

function Flock.new(player, houseModel, runtimeFolder, sheepTemplate)
	local self = setmetatable({}, Flock)

	self.Player = player
	self.House = houseModel
	self.Runtime = runtimeFolder
	self.Template = sheepTemplate
	self.Sheep = {}

	self.Leader = nil
	self.Center = nil
	self.MoveDirection = nil
	self.IsMoving = false
	self.LastPressureTime = 0
	self.RecallUntil = 0
	self.CommandTarget = nil
	self.CommandTargetUntil = 0
	self.LegacyPenWarningPrinted = false

	self.PenCenterPart = nil
	self.PenEntrancePart = nil
	self.PenRadius = Cfg.Pen.DefaultRadius
	self.PenApproachRadius = Cfg.Pen.DefaultApproachRadius
	self.PenEntryRadius = Cfg.Pen.DefaultEntryRadius
	self.PenAssistEnabled = Cfg.Pen.AssistEnabled ~= false
	self.LegacyPenPart = nil
	self.LegacyApproachPart = nil

	self:ResolvePenConfig()

	self.Folder = Instance.new("Folder")
	self.Folder.Name = "Flock_" .. player.UserId
	self.Folder.Parent = runtimeFolder

	self:SpawnSheep()

	return self
end

function Flock:ResolvePenConfig()
	local houseModel = self.House
	local penCenterName = Cfg.Names.PenCenter or Cfg.Names.CorralCenter or "CorralCenter"
	local penEntranceName = Cfg.Names.PenEntrance or "PenEntrance"

	local centerPart = houseModel and houseModel:FindFirstChild(penCenterName, true)
	local entrancePart = houseModel and houseModel:FindFirstChild(penEntranceName, true)

	if centerPart and centerPart:IsA("BasePart") then
		self.PenCenterPart = centerPart
	end

	if entrancePart and entrancePart:IsA("BasePart") and not entrancePart:GetAttribute("NeedsManualPlacement") then
		self.PenEntrancePart = entrancePart
	end

	self.PenRadius = readNumberAttribute(houseModel, "PenRadius", Cfg.Pen.DefaultRadius)
	self.PenApproachRadius = readNumberAttribute(houseModel, "PenApproachRadius", Cfg.Pen.DefaultApproachRadius)
	self.PenEntryRadius = readNumberAttribute(houseModel, "PenEntryRadius", Cfg.Pen.DefaultEntryRadius)
	self.PenAssistEnabled = readBooleanAttribute(houseModel, "PenAssistEnabled", Cfg.Pen.AssistEnabled ~= false)

	if not (self.PenCenterPart and self.PenEntrancePart and self.PenAssistEnabled) then
		local pensFolder = workspace:FindFirstChild("SheepPens")
		if pensFolder then
			self.LegacyPenPart = pensFolder:FindFirstChild("SheepPenZone")
			self.LegacyApproachPart = pensFolder:FindFirstChild("SheepPenApproachZone")
		end
	end
end

function Flock:SpawnSheep()
	local spawnFolder = self.House:FindFirstChild(Cfg.Names.SpawnFolder)

	if not spawnFolder then
		warn("[Flock] Falta SheepSpawns en", self.House.Name)
		return
	end

	local spawns = {}

	for _, obj in ipairs(spawnFolder:GetChildren()) do
		if obj:IsA("BasePart") then
			table.insert(spawns, obj)
		end
	end

	table.sort(spawns, sortByName)

	if #spawns < Cfg.SheepPerFlock then
		warn("[Flock]", self.House.Name, "tiene solo", #spawns, "spawns. Necesita", Cfg.SheepPerFlock)
	end

	local amount = math.min(Cfg.SheepPerFlock, #spawns)

	for i = 1, amount do
		local spawnPart = spawns[i]
		local sheepModel = self.Template:Clone()

		sheepModel.Name = "Sheep_" .. self.Player.UserId .. "_" .. i
		sheepModel.Parent = self.Folder

		if not sheepModel.PrimaryPart then
			local root = sheepModel:FindFirstChild("HumanoidRootPart")

			if root and root:IsA("BasePart") then
				sheepModel.PrimaryPart = root
			else
				warn("[Flock] La oveja no tiene HumanoidRootPart:", sheepModel.Name)
				sheepModel:Destroy()
				continue
			end
		end

		local randomYaw = math.rad(math.random(0, 359))
		local spawnCFrame = spawnPart.CFrame + Vector3.new(0, Cfg.SpawnYOffset, 0)

		sheepModel:PivotTo(spawnCFrame * CFrame.Angles(0, randomYaw, 0))

		local sheep = Sheep.new(sheepModel, self.Player, self.House, i)
		table.insert(self.Sheep, sheep)
	end

	self.Leader = self.Sheep[1]

	if self.Leader and self.Leader.Model then
		self.Leader.Model:SetAttribute("IsLeader", true)
		self.Leader.Model.Name = self.Leader.Model.Name .. "_Leader"
	end

	if Cfg.Debug.PrintLifecycle then
		print("[Flock] Rebaño creado:", self.Player.Name, "# ovejas:", #self.Sheep)

		if self.Leader then
			print("[Flock] Líder asignada:", self.Leader.Model.Name)
		end
	end
end

function Flock:SetCommandTarget(targetPosition, now)
	self.CommandTarget = targetPosition
	self.CommandTargetUntil = (now or os.clock()) + (Cfg.CommandTarget.Duration or 15)
	self.RecallUntil = 0

	if Cfg.Debug.PrintLifecycle and self.Player then
		print("[Flock] Destino marcado:", self.Player.Name, targetPosition)
	end
end

function Flock:ClearCommandTarget()
	self.CommandTarget = nil
	self.CommandTargetUntil = 0
end

function Flock:GetOwnerRoot()
	if not self.Player then
		return nil
	end

	local character = self.Player.Character
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

function Flock:IsPlayerMoving(ownerRoot)
	if not ownerRoot then
		return false
	end

	local velocity = ownerRoot.AssemblyLinearVelocity
	local flatSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

	return flatSpeed > Cfg.PlayerMoveSpeed
end

function Flock:CalculateCenter()
	local total = Vector3.zero
	local count = 0

	for _, sheep in ipairs(self.Sheep) do
		if sheep.Root and sheep.Root.Parent then
			if sheep.Model and sheep.Model:GetAttribute("CapturedByDragon") then continue end
			total += sheep.Root.Position
			count += 1
		end
	end

	if count == 0 then
		return nil
	end

	return total / count
end

function Flock:GetPositions()
	local positions = {}

	for _, sheep in ipairs(self.Sheep) do
		if sheep.Root and sheep.Root.Parent then
			if sheep.Model and sheep.Model:GetAttribute("CapturedByDragon") then continue end
			table.insert(positions, {
				Sheep = sheep,
				Position = sheep.Root.Position,
			})
		end
	end

	return positions
end

function Flock:BuildFlowData(moveDirection)
	if not self.Center or not moveDirection then
		return nil
	end

	local columns = Cfg.Flow.Columns or 5
	local half = (columns - 1) / 2

	local right = getRightVector(moveDirection)
	local target = self.Center + moveDirection * Cfg.Flow.TargetAhead

	local slots = {}

	for i, sheep in ipairs(self.Sheep) do
		if sheep.Root and sheep.Root.Parent then
			if sheep.Model and sheep.Model:GetAttribute("CapturedByDragon") then continue end
			local col = ((i - 1) % columns) - half
			local row = math.floor((i - 1) / columns)

			local sideOffset = col * Cfg.Flow.SlotSpacing
			local backOffset = row * Cfg.Flow.RowSpacing

			local slotPosition = target + right * sideOffset - moveDirection * backOffset

			slots[sheep] = slotPosition
		end
	end

	return {
		Target = target,
		Right = right,
		Slots = slots,
	}
end

function Flock:UpdateBrain(now)
	local ownerRoot = self:GetOwnerRoot()
	local center = self:CalculateCenter()
	self.Center = center

	local penCenter, penEntrance, penRadius, penIsOpen = nil, nil, nil, false
	local penApproachRadius, penEntryRadius, penAssistEnabled = nil, nil, false

	if self.PenCenterPart and self.PenCenterPart.Parent and self.PenEntrancePart and self.PenEntrancePart.Parent and self.PenAssistEnabled then
		penCenter = self.PenCenterPart.Position
		penEntrance = self.PenEntrancePart.Position
		penRadius = self.PenRadius
		penApproachRadius = self.PenApproachRadius
		penEntryRadius = self.PenEntryRadius
		penAssistEnabled = true
		penIsOpen = self.House and self.House:GetAttribute("PenOpen") == true
	elseif self.LegacyPenPart and self.LegacyPenPart:IsA("BasePart") then
		if not self.LegacyPenWarningPrinted then
			self.LegacyPenWarningPrinted = true
			warn("[Flock] Usando corral legacy global para", self.House and self.House.Name or "house desconocida")
		end

		penCenter = self.LegacyPenPart.Position
		penRadius = math.min(self.LegacyPenPart.Size.Y, self.LegacyPenPart.Size.Z) / 2
		penIsOpen = self.LegacyPenPart:GetAttribute("IsOpen") or false

		if self.LegacyApproachPart and self.LegacyApproachPart:IsA("BasePart") then
			penEntrance = self.LegacyApproachPart.Position
			penApproachRadius = math.min(self.LegacyApproachPart.Size.Y, self.LegacyApproachPart.Size.Z) / 2
			penEntryRadius = Cfg.Pen.DefaultEntryRadius
			penAssistEnabled = true
		end
	end

	local shouldMove = false
	local desiredDirection = nil
	local mode = "Idle"

	if ownerRoot and center then
		local toCenter = center - ownerRoot.Position
		local distanceToCenter = flatVector(toCenter).Magnitude
		local playerMoving = self:IsPlayerMoving(ownerRoot)

		if self.CommandTarget and now > self.CommandTargetUntil then
			self:ClearCommandTarget()
		end

		local commandActive = self.CommandTarget ~= nil and now <= self.CommandTargetUntil
		local recallActive = now <= self.RecallUntil

		if commandActive then
			local toTarget = self.CommandTarget - center
			local distanceToTarget = flatVector(toTarget).Magnitude

			if distanceToTarget > (Cfg.CommandTarget.StopDistance or 8) then
				shouldMove = true
				desiredDirection = flatDirection(toTarget)
				mode = "CommandTarget"
			else
				self:ClearCommandTarget()
				mode = "Idle"
			end

		elseif distanceToCenter <= Cfg.Flock.PressureRadius and playerMoving then
			shouldMove = true
			desiredDirection = flatDirection(toCenter)
			self.LastPressureTime = now
			mode = "Pressure"

		elseif recallActive then
			local toPlayer = ownerRoot.Position - center
			local distanceToPlayer = flatVector(toPlayer).Magnitude

			if distanceToPlayer > Cfg.Flock.RecallStopDistance then
				shouldMove = true
				desiredDirection = flatDirection(toPlayer)
				mode = "Recall"
			else
				self.RecallUntil = 0
				mode = "Idle"
			end

		elseif self.MoveDirection and now - self.LastPressureTime <= Cfg.Flock.MinMoveTime then
			shouldMove = true
			desiredDirection = self.MoveDirection
			mode = "Coast"
		end
	end

	if shouldMove and desiredDirection then
		self.MoveDirection = smoothDirection(
			self.MoveDirection,
			desiredDirection,
			Cfg.Flock.DirectionSmoothing
		)

		self.IsMoving = true
	else
		self.IsMoving = false
	end

	local leaderPosition = nil

	if self.Leader and self.Leader.Root and self.Leader.Root.Parent then
		if not (self.Leader.Model and self.Leader.Model:GetAttribute("CapturedByDragon")) then
			leaderPosition = self.Leader.Root.Position
		end
	end

	local flow = nil

	if self.IsMoving and self.MoveDirection then
		flow = self:BuildFlowData(self.MoveDirection)
	end

	local grazingZonePos = nil
	if Cfg.Grazing and Cfg.Grazing.RuntimeFolder then
		local runtime = workspace:FindFirstChild(Cfg.Grazing.RuntimeFolder)
		if runtime then
			local playerFolder = runtime:FindFirstChild("Grazing_" .. self.Player.UserId)
			if playerFolder then
				local zonePart = playerFolder:FindFirstChild("GrazingZone")
				if zonePart then
					grazingZonePos = zonePart.Position
				end
			end
		end
	end


	return {
		OwnerRoot = ownerRoot,
		Center = self.Center,
		Leader = self.Leader,
		LeaderPosition = leaderPosition,
		MoveDirection = self.MoveDirection,
		IsMoving = self.IsMoving,
		Mode = mode,
		CommandActive = self.CommandTarget ~= nil and now <= self.CommandTargetUntil,
		CommandTarget = self.CommandTarget,
		Flow = flow,
		Positions = self:GetPositions(),
		GrazingZone = grazingZonePos,
		PenCenter = penCenter,
		PenEntrance = penEntrance,
		PenRadius = penRadius,
		PenApproachRadius = penApproachRadius,
		PenEntryRadius = penEntryRadius,
		PenIsOpen = penIsOpen,
		PenAssistEnabled = penAssistEnabled,
	}
end

function Flock:Whistle()
	self.RecallUntil = os.clock() + Cfg.Flock.RecallDuration
	self:ClearCommandTarget()

	if Cfg.Debug.PrintLifecycle and self.Player then
		print("[Flock] Silbido recibido:", self.Player.Name)
	end
end

function Flock:StepPhysics(dt)
	for _, sheep in ipairs(self.Sheep) do
		sheep:StepPhysics(dt)
	end
end

function Flock:StepAI(now)
	local flockData = self:UpdateBrain(now)

	for _, sheep in ipairs(self.Sheep) do
		sheep:StepAI(now, flockData)
	end
end

function Flock:Destroy()
	for _, sheep in ipairs(self.Sheep) do
		sheep:Destroy()
	end

	table.clear(self.Sheep)

	if self.Folder then
		self.Folder:Destroy()
	end

	self.Player = nil
	self.House = nil
	self.Runtime = nil
	self.Template = nil
	self.Folder = nil
	self.Leader = nil
	self.Center = nil
	self.MoveDirection = nil
	self.CommandTarget = nil
	self.CommandTargetUntil = 0
	self.PenCenterPart = nil
	self.PenEntrancePart = nil
	self.LegacyPenPart = nil
	self.LegacyApproachPart = nil
end

return Flock
