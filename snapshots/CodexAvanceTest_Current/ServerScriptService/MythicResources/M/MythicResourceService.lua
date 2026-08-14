local ProximityPromptService = game:GetService("ProximityPromptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local MythicResourceService = {}
MythicResourceService.__index = MythicResourceService

local TEST_CLUSTER_LAYOUT = {
	{ ResourceId = "Mandrake", Offset = Vector3.new(-8, 0, -9) },
	{ ResourceId = "EmberBloom", Offset = Vector3.new(0, 0, -10) },
	{ ResourceId = "MoonDewLotus", Offset = Vector3.new(8, 0, -9) },
	{ ResourceId = "Mandrake", Offset = Vector3.new(-10, 0, -14) },
	{ ResourceId = "EmberBloom", Offset = Vector3.new(0, 0, -15) },
	{ ResourceId = "MoonDewLotus", Offset = Vector3.new(10, 0, -14) },
	{ ResourceId = "Mandrake", Offset = Vector3.new(-12, 0, -19) },
	{ ResourceId = "EmberBloom", Offset = Vector3.new(0, 0, -20) },
	{ ResourceId = "MoonDewLotus", Offset = Vector3.new(12, 0, -19) },
}

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		return folder
	end
	if folder then
		error(string.format("[MythicResources] %s existe pero no es Folder", folder:GetFullName()))
	end
	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function getTemplateFolder()
	local assets = ServerStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("MythicResources")
end

local function getInteractionPart(instance)
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Model") then
		if instance.PrimaryPart then
			return instance.PrimaryPart
		end
		return instance:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function prepareWorldInstance(instance)
	if instance:IsA("BasePart") then
		instance.Anchored = true
		instance.CanCollide = false
		instance.CanTouch = false
		instance.CanQuery = false
		return
	end
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
end

function MythicResourceService.new(catalog, inventoryService, codexService, stateChangedRemote)
	local self = setmetatable({}, MythicResourceService)
	self.Catalog = catalog
	self.Inventory = inventoryService
	self.Codex = codexService
	self.StateChangedRemote = stateChangedRemote
	self.SpawnFolder = ensureFolder(Workspace, "MythicResourceSpawns")
	self.Runtime = ensureFolder(Workspace, "MythicResourceRuntime")
	self.NodesBySpawnId = {}
	self.PromptConnection = nil
	self.ChildAddedConnection = nil
	return self
end

function MythicResourceService:_positionClone(clone, marker)
	if clone:IsA("Model") then
		clone:PivotTo(marker.CFrame)
	elseif clone:IsA("BasePart") then
		clone.CFrame = marker.CFrame
	end
end

function MythicResourceService:_spawnMarker(marker)
	if not marker:IsA("BasePart") then
		return false
	end

	local resourceId = marker:GetAttribute("MythicResourceId")
	local definition = self.Catalog.Get(resourceId)
	if not definition then
		warn("[MythicResources] Spawn sin MythicResourceId válido:", marker:GetFullName())
		return false
	end
	if marker:GetAttribute("Enabled") == false then
		return false
	end

	marker.Transparency = 1
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false

	local spawnId = tostring(marker:GetAttribute("MythicSpawnId") or marker.Name)
	local existing = self.NodesBySpawnId[spawnId]
	if existing and existing.Model and existing.Model.Parent then
		return true
	end

	local templateFolder = getTemplateFolder()
	local template = templateFolder and templateFolder:FindFirstChild(definition.ModelName)
	if not template or (not template:IsA("Model") and not template:IsA("BasePart")) then
		warn(string.format("[MythicResources] Falta template ServerStorage.Assets.MythicResources.%s", definition.ModelName))
		return false
	end

	local clone = template:Clone()
	clone.Name = string.format("%s_%s", resourceId, spawnId)
	clone:SetAttribute("MythicRuntime", true)
	clone:SetAttribute("MythicResourceId", resourceId)
	clone:SetAttribute("MythicSpawnId", spawnId)
	prepareWorldInstance(clone)
	clone.Parent = self.Runtime
	self:_positionClone(clone, marker)

	local interactionPart = getInteractionPart(clone)
	if not interactionPart then
		warn("[MythicResources] Template sin BasePart interactuable:", clone.Name)
		clone:Destroy()
		return false
	end

	local prompt = interactionPart:FindFirstChild("MythicCollectPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "MythicCollectPrompt"
		prompt.Parent = interactionPart
	end
	prompt.ActionText = "Recolectar"
	prompt.ObjectText = definition.DisplayName
	prompt.HoldDuration = definition.PromptHoldDuration or 0.5
	prompt.MaxActivationDistance = definition.PromptDistance or 9
	prompt.RequiresLineOfSight = true
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("MythicResourceId", resourceId)
	prompt:SetAttribute("MythicSpawnId", spawnId)

	self.NodesBySpawnId[spawnId] = {
		Marker = marker,
		Model = clone,
		Prompt = prompt,
		Busy = false,
		ResourceId = resourceId,
	}
	return true
end

function MythicResourceService:_removeMarkerNode(marker)
	if not marker or not marker:IsA("BasePart") then
		return
	end
	local spawnId = tostring(marker:GetAttribute("MythicSpawnId") or marker.Name)
	local node = self.NodesBySpawnId[spawnId]
	if node then
		if node.Model and node.Model.Parent then
			node.Model:Destroy()
		end
		self.NodesBySpawnId[spawnId] = nil
	end
end

function MythicResourceService:_groundTestPosition(player, desiredPosition, fallbackY)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local exclude = { self.SpawnFolder, self.Runtime }
	if player.Character then
		table.insert(exclude, player.Character)
	end
	params.FilterDescendantsInstances = exclude

	local origin = desiredPosition + Vector3.new(0, 40, 0)
	local result = Workspace:Raycast(origin, Vector3.new(0, -100, 0), params)
	if result then
		return result.Position + Vector3.new(0, 0.03, 0)
	end
	return Vector3.new(desiredPosition.X, fallbackY, desiredPosition.Z)
end

function MythicResourceService:ClearTestSpawnsForPlayer(player)
	local userId = player and player.UserId
	if not userId then
		return
	end

	for _, marker in ipairs(self.SpawnFolder:GetChildren()) do
		if marker:IsA("BasePart") and marker:GetAttribute("MythicTestOwnerUserId") == userId then
			self:_removeMarkerNode(marker)
			marker:Destroy()
		end
	end
end

function MythicResourceService:SpawnTestClusterForPlayer(player, rootCFrame)
	if not player or typeof(rootCFrame) ~= "CFrame" then
		return 0
	end

	self:ClearTestSpawnsForPlayer(player)

	local fallbackY = rootCFrame.Position.Y - 3
	local created = 0
	for index, spec in ipairs(TEST_CLUSTER_LAYOUT) do
		if self.Catalog.IsValid(spec.ResourceId) then
			local desired = rootCFrame:PointToWorldSpace(spec.Offset)
			local groundPosition = self:_groundTestPosition(player, desired, fallbackY)
			local spawnId = string.format("Test_%d_%02d_%s", player.UserId, index, spec.ResourceId)

			local marker = Instance.new("Part")
			marker.Name = spawnId
			marker.Size = Vector3.new(0.4, 0.4, 0.4)
			marker.Transparency = 1
			marker.Anchored = true
			marker.CanCollide = false
			marker.CanTouch = false
			marker.CanQuery = false
			marker.CFrame = CFrame.new(groundPosition) * CFrame.Angles(0, math.rad((index * 47) % 360), 0)
			marker:SetAttribute("MythicResourceId", spec.ResourceId)
			marker:SetAttribute("MythicSpawnId", spawnId)
			marker:SetAttribute("MythicTestOwnerUserId", player.UserId)
			marker:SetAttribute("MythicTestSpawn", true)
			marker:SetAttribute("RespawnSeconds", 8)
			marker.Parent = self.SpawnFolder

			self:_spawnMarker(marker)
			created += 1
		end
	end

	return created
end

function MythicResourceService:_collect(prompt, player)
	local spawnId = prompt:GetAttribute("MythicSpawnId")
	local resourceId = prompt:GetAttribute("MythicResourceId")
	if typeof(spawnId) ~= "string" or not self.Catalog.IsValid(resourceId) then
		return
	end

	local node = self.NodesBySpawnId[spawnId]
	if not node or node.Busy or node.Prompt ~= prompt or not node.Model or not node.Model.Parent then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local promptPart = prompt.Parent
	if not root or not promptPart or not promptPart:IsA("BasePart") then
		return
	end
	if (root.Position - promptPart.Position).Magnitude > (prompt.MaxActivationDistance + 3) then
		return
	end

	node.Busy = true
	prompt.Enabled = false

	local ok, newCount = self.Inventory:Add(player, resourceId, 1)
	if not ok then
		node.Busy = false
		prompt.Enabled = true
		return
	end

	local firstDiscovery = self.Codex:Discover(player, resourceId)
	if self.StateChangedRemote then
		self.StateChangedRemote:FireClient(player, {
			Type = "Collected",
			ResourceId = resourceId,
			Count = newCount,
			FirstDiscovery = firstDiscovery,
			KnownCount = self.Codex:GetKnownCount(player),
		})
	end

	local model = node.Model
	node.Model = nil
	node.Prompt = nil
	if model and model.Parent then
		model:Destroy()
	end

	local definition = self.Catalog.Get(resourceId)
	local respawnSeconds = tonumber(node.Marker:GetAttribute("RespawnSeconds"))
		or definition.RespawnSeconds
		or 15

	task.delay(respawnSeconds, function()
		local current = self.NodesBySpawnId[spawnId]
		if current ~= node or not node.Marker or not node.Marker.Parent then
			return
		end
		node.Busy = false
		self:_spawnMarker(node.Marker)
	end)
end

function MythicResourceService:Start()
	for _, marker in ipairs(self.SpawnFolder:GetChildren()) do
		self:_spawnMarker(marker)
	end

	self.ChildAddedConnection = self.SpawnFolder.ChildAdded:Connect(function(marker)
		task.defer(function()
			self:_spawnMarker(marker)
		end)
	end)

	self.PromptConnection = ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name == "MythicCollectPrompt" then
			self:_collect(prompt, player)
		end
	end)
end

function MythicResourceService:Destroy()
	if self.PromptConnection then
		self.PromptConnection:Disconnect()
		self.PromptConnection = nil
	end
	if self.ChildAddedConnection then
		self.ChildAddedConnection:Disconnect()
		self.ChildAddedConnection = nil
	end
end

return MythicResourceService
