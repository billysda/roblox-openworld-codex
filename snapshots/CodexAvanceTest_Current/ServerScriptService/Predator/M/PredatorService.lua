local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FoxController = require(script.Parent:WaitForChild("FoxController"))

local PredatorService = {}
PredatorService.__index = PredatorService

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

local function getSheepRoot(model)
	if not model then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

function PredatorService.new(cfg, captureService)
	local self = setmetatable({}, PredatorService)
	self.Cfg = cfg
	self.CaptureService = captureService
	self.Runtime = ensureFolder(Workspace, cfg.RuntimeFolder)
	self.Active = {}
	self.Connection = nil
	self.PhysicsTimer = 0
	self.AITimer = 0
	self.NextSpawnAt = os.clock() + (cfg.Spawn.InitialDelay or 5)
	self.Rng = Random.new()
	return self
end

function PredatorService:GetFoxTemplate()
	local current = ServerStorage
	for _, name in ipairs(self.Cfg.TemplateFolder) do
		current = current and current:FindFirstChild(name)
	end

	local template = current and current:FindFirstChild(self.Cfg.FoxTemplateName)
	if template and template:IsA("Model") then
		return template
	end
	return nil
end

function PredatorService:GetSpawnGroundParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true

	local filter = { self.Runtime }
	local sheepRuntime = Workspace:FindFirstChild("SheepRuntime")
	if sheepRuntime then
		table.insert(filter, sheepRuntime)
	end
	params.FilterDescendantsInstances = filter
	return params
end

function PredatorService:ChooseSpawnCFrame(target)
	local root = getSheepRoot(target)
	if not root then
		return nil
	end

	local spawnCfg = self.Cfg.Spawn
	local foxCfg = self.Cfg.Fox
	local params = self:GetSpawnGroundParams()

	for _ = 1, spawnCfg.Attempts do
		local angle = self.Rng:NextNumber(0, math.pi * 2)
		local distance = self.Rng:NextNumber(spawnCfg.DistanceMin, spawnCfg.DistanceMax)
		local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local sample = root.Position + offset
		local origin = sample + Vector3.new(0, spawnCfg.GroundRayHeight, 0)
		local result = Workspace:Raycast(
			origin,
			Vector3.new(0, -spawnCfg.GroundRayDepth, 0),
			params
		)

		if result and result.Normal.Y >= 0.65 then
			local position = result.Position + Vector3.new(0, foxCfg.GroundTargetHeight, 0)
			local look = root.Position - position
			look = Vector3.new(look.X, 0, look.Z)
			if look.Magnitude > 0.001 then
				return CFrame.lookAt(position, position + look.Unit, Vector3.yAxis)
			end
			return CFrame.new(position)
		end
	end

	return nil
end

function PredatorService:PickSpawnTarget()
	local candidates = FoxController.GetValidSheepModels(self.CaptureService, self.Cfg)
	if #candidates == 0 then
		return nil
	end
	return candidates[self.Rng:NextInteger(1, #candidates)]
end

function PredatorService:SpawnFox(now)
	if #self.Active >= self.Cfg.Spawn.MaxActive then
		return false
	end

	local template = self:GetFoxTemplate()
	if not template then
		warn("[PredatorService] Falta ServerStorage.Assets.Predators.FoxTemplate")
		self.NextSpawnAt = now + 10
		return false
	end

	local target = self:PickSpawnTarget()
	if not target then
		self.NextSpawnAt = now + 5
		return false
	end

	local spawnCFrame = self:ChooseSpawnCFrame(target)
	if not spawnCFrame then
		self.NextSpawnAt = now + 5
		return false
	end

	local fox = template:Clone()
	fox.Name = "Fox_" .. tostring(math.floor(now * 1000))
	fox.Parent = self.Runtime

	local root = fox:FindFirstChild("HumanoidRootPart") or fox.PrimaryPart
	if not root or not root:IsA("BasePart") then
		warn("[PredatorService] FoxTemplate sin HumanoidRootPart válido")
		fox:Destroy()
		self.NextSpawnAt = now + 10
		return false
	end

	fox.PrimaryPart = root
	fox:PivotTo(spawnCFrame)

	local controller = FoxController.new(fox, self.CaptureService, self.Cfg, target)
	if controller.Finished then
		controller:Destroy()
		self.NextSpawnAt = now + 10
		return false
	end

	table.insert(self.Active, controller)
	self.NextSpawnAt = math.huge

	if self.Cfg.Fox.DebugPrints then
		print("[PredatorService] Fox creado contra", target.Name)
	end
	return true
end

function PredatorService:CleanupFinished(now)
	for index = #self.Active, 1, -1 do
		local controller = self.Active[index]
		if controller.Finished or not controller.Model or not controller.Model.Parent then
			controller:Destroy()
			table.remove(self.Active, index)
			self.NextSpawnAt = now + self.Cfg.Spawn.RespawnCooldown
		end
	end
end

function PredatorService:StepPhysics(dt)
	for _, controller in ipairs(self.Active) do
		controller:StepPhysics(dt)
	end
end

function PredatorService:StepAI(now)
	for _, controller in ipairs(self.Active) do
		controller:StepAI(now)
	end

	self:CleanupFinished(now)

	if self.Cfg.Spawn.Enabled and #self.Active < self.Cfg.Spawn.MaxActive and now >= self.NextSpawnAt then
		self:SpawnFox(now)
	end
end

function PredatorService:Start()
	if self.Connection or not self.Cfg.Enabled then
		return
	end

	local physicsInterval = self.Cfg.Update.Physics
	local aiInterval = self.Cfg.Update.AI
	local maxCatchUp = self.Cfg.Update.MaxPhysicsCatchUp or 2

	self.Connection = RunService.Heartbeat:Connect(function(dt)
		self.PhysicsTimer += dt
		local physicsSteps = 0

		while self.PhysicsTimer >= physicsInterval and physicsSteps < maxCatchUp do
			self.PhysicsTimer -= physicsInterval
			physicsSteps += 1
			self:StepPhysics(physicsInterval)
		end

		if physicsSteps >= maxCatchUp then
			self.PhysicsTimer = 0
		end

		self.AITimer += dt
		if self.AITimer >= aiInterval then
			self.AITimer = 0
			self:StepAI(os.clock())
		end
	end)
end

function PredatorService:Stop()
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end

	for _, controller in ipairs(self.Active) do
		controller:Destroy()
	end
	self.Active = {}
end

return PredatorService
