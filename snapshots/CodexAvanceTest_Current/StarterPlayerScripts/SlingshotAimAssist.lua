local Workspace = game:GetService("Workspace")

local SlingshotAimAssist = {}
SlingshotAimAssist.__index = SlingshotAimAssist

local DEFAULTS = {
	MaxRange = 180,
	AcquireWorldDistance = 145,
	BreakWorldDistance = 165,
	AcquireScreenRadius = 190,
	BreakScreenRadius = 320,
	AcquireInterval = 0.08,
	PreviewRayInterval = 1 / 30,
	CameraResponsiveness = 8,
	PredictionTime = 0.07,
	PredictionMax = 1.5,
	BeamWidth = 0.032,
	BeamTransparency = 0.22,
}

local function mergeConfig(config)
	local result = {}
	for key, value in pairs(DEFAULTS) do
		result[key] = value
	end
	for key, value in pairs(config or {}) do
		result[key] = value
	end
	return result
end

local function isFoxModel(model)
	return model
		and model:IsA("Model")
		and model:GetAttribute("PredatorType") == "Fox"
		and model:GetAttribute("PredatorState") ~= "Repelled"
		and model:GetAttribute("PredatorState") ~= "Completed"
end

local function getFoxRoot(model)
	if not isFoxModel(model) or not model.Parent then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	return root and root:IsA("BasePart") and root or nil
end

local function getMuzzlePart(tool, character)
	if tool then
		local handle = tool:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			return handle
		end
	end
	if character then
		local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
		if hand and hand:IsA("BasePart") then
			return hand
		end
	end
	return nil
end

function SlingshotAimAssist.new(player, config)
	local self = setmetatable({}, SlingshotAimAssist)
	self.Player = player
	self.Config = mergeConfig(config)
	self.Aiming = false
	self.LockedModel = nil
	self.LockedRoot = nil
	self.LastAcquireAt = 0
	self.LastPreviewAt = 0
	self.CachedPreviewPosition = nil
	self.Character = nil
	self.Tool = nil
	self.MuzzlePart = nil
	self.MuzzleAttachment = nil
	self.TargetPart = nil
	self.TargetAttachment = nil
	self.Beam = nil
	self.ScreenGui = nil
	self.Reticle = nil
	self.ReticleParts = {}
	self:_ensureVisuals()
	return self
end

function SlingshotAimAssist:_ensureVisuals()
	if not self.TargetPart then
		local part = Instance.new("Part")
		part.Name = "SlingshotAimPreviewTarget"
		part.Size = Vector3.new(0.05, 0.05, 0.05)
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Parent = Workspace
		self.TargetPart = part

		local attachment = Instance.new("Attachment")
		attachment.Name = "SlingshotAimTargetAttachment"
		attachment.Parent = part
		self.TargetAttachment = attachment
	end

	if not self.ScreenGui then
		local playerGui = self.Player:WaitForChild("PlayerGui", 5)
		if playerGui then
			local gui = Instance.new("ScreenGui")
			gui.Name = "SlingshotAimUI"
			gui.ResetOnSpawn = false
			gui.IgnoreGuiInset = false
			gui.Enabled = false
			gui.Parent = playerGui
			self.ScreenGui = gui

			local reticle = Instance.new("Frame")
			reticle.Name = "Reticle"
			reticle.AnchorPoint = Vector2.new(0.5, 0.5)
			reticle.Position = UDim2.fromScale(0.5, 0.5)
			reticle.Size = UDim2.fromOffset(28, 28)
			reticle.BackgroundTransparency = 1
			reticle.Parent = gui
			self.Reticle = reticle

			local specs = {
				{ "Top", UDim2.fromOffset(2, 8), UDim2.new(0.5, -1, 0, 0) },
				{ "Bottom", UDim2.fromOffset(2, 8), UDim2.new(0.5, -1, 1, -8) },
				{ "Left", UDim2.fromOffset(8, 2), UDim2.new(0, 0, 0.5, -1) },
				{ "Right", UDim2.fromOffset(8, 2), UDim2.new(1, -8, 0.5, -1) },
			}
			for _, spec in ipairs(specs) do
				local line = Instance.new("Frame")
				line.Name = spec[1]
				line.Size = spec[2]
				line.Position = spec[3]
				line.BorderSizePixel = 0
				line.BackgroundColor3 = Color3.fromRGB(244, 232, 199)
				line.Parent = reticle
				table.insert(self.ReticleParts, line)
			end
		end
	end
end

function SlingshotAimAssist:_setReticleLocked(locked)
	local color = locked and Color3.fromRGB(225, 167, 92) or Color3.fromRGB(244, 232, 199)
	for _, line in ipairs(self.ReticleParts) do
		if line and line.Parent then
			line.BackgroundColor3 = color
		end
	end
end

function SlingshotAimAssist:_setMuzzle(tool, character)
	local part = getMuzzlePart(tool, character)
	if part == self.MuzzlePart and self.MuzzleAttachment and self.MuzzleAttachment.Parent then
		return
	end

	if self.MuzzleAttachment then
		self.MuzzleAttachment:Destroy()
		self.MuzzleAttachment = nil
	end
	if self.Beam then
		self.Beam:Destroy()
		self.Beam = nil
	end

	self.MuzzlePart = part
	if not part or not self.TargetAttachment then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "SlingshotAimMuzzleAttachment"
	attachment.Parent = part
	self.MuzzleAttachment = attachment

	local beam = Instance.new("Beam")
	beam.Name = "SlingshotTrajectoryPreview"
	beam.Attachment0 = attachment
	beam.Attachment1 = self.TargetAttachment
	beam.FaceCamera = true
	beam.Width0 = self.Config.BeamWidth
	beam.Width1 = self.Config.BeamWidth * 0.75
	beam.LightEmission = 0.15
	beam.Transparency = NumberSequence.new(self.Config.BeamTransparency)
	beam.Color = ColorSequence.new(Color3.fromRGB(238, 221, 177))
	beam.Enabled = self.Aiming
	beam.Parent = part
	self.Beam = beam
end

function SlingshotAimAssist:SetContext(character, tool)
	self.Character = character
	self.Tool = tool
	self:_setMuzzle(tool, character)
end

function SlingshotAimAssist:SetAiming(enabled)
	self.Aiming = enabled == true
	if not self.Aiming then
		self.LockedModel = nil
		self.LockedRoot = nil
		self.CachedPreviewPosition = nil
	end
	if self.ScreenGui then
		self.ScreenGui.Enabled = self.Aiming
	end
	if self.Beam then
		self.Beam.Enabled = self.Aiming
	end
	self:_setReticleLocked(self.LockedRoot ~= nil)
end

function SlingshotAimAssist:_getAimPoint(root)
	if not root then
		return nil
	end
	local velocity = root.AssemblyLinearVelocity
	local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local lead = flatVelocity * self.Config.PredictionTime
	if lead.Magnitude > self.Config.PredictionMax then
		lead = lead.Unit * self.Config.PredictionMax
	end
	return root.Position + lead
end

function SlingshotAimAssist:_isLineOfSight(cameraPosition, model, aimPoint)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	params.FilterDescendantsInstances = self.Character and { self.Character } or {}

	local delta = aimPoint - cameraPosition
	local result = Workspace:Raycast(cameraPosition, delta, params)
	if not result then
		return true
	end
	return result.Instance and result.Instance:FindFirstAncestorOfClass("Model") == model
end

function SlingshotAimAssist:_screenDistance(camera, worldPosition)
	local viewportPoint, onScreen = camera:WorldToViewportPoint(worldPosition)
	if not onScreen or viewportPoint.Z <= 0 then
		return math.huge
	end
	local viewport = camera.ViewportSize
	local center = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
	return (Vector2.new(viewportPoint.X, viewportPoint.Y) - center).Magnitude
end

function SlingshotAimAssist:_isLockValid(camera)
	local model = self.LockedModel
	local root = getFoxRoot(model)
	if not root then
		return false
	end
	local distance = (root.Position - camera.CFrame.Position).Magnitude
	if distance > self.Config.BreakWorldDistance then
		return false
	end
	local aimPoint = self:_getAimPoint(root)
	if self:_screenDistance(camera, aimPoint) > self.Config.BreakScreenRadius then
		return false
	end
	if not self:_isLineOfSight(camera.CFrame.Position, model, aimPoint) then
		return false
	end
	self.LockedRoot = root
	return true
end

function SlingshotAimAssist:_acquire(camera)
	local runtime = Workspace:FindFirstChild("PredatorRuntime")
	if not runtime then
		return
	end

	local bestModel, bestRoot, bestScore = nil, nil, math.huge
	local cameraPosition = camera.CFrame.Position
	for _, candidate in ipairs(runtime:GetChildren()) do
		local root = getFoxRoot(candidate)
		if root then
			local distance = (root.Position - cameraPosition).Magnitude
			if distance <= self.Config.AcquireWorldDistance then
				local aimPoint = self:_getAimPoint(root)
				local screenDistance = self:_screenDistance(camera, aimPoint)
				if screenDistance <= self.Config.AcquireScreenRadius and self:_isLineOfSight(cameraPosition, candidate, aimPoint) then
					local score = screenDistance + distance * 0.12
					if score < bestScore then
						bestModel, bestRoot, bestScore = candidate, root, score
					end
				end
			end
		end
	end

	self.LockedModel = bestModel
	self.LockedRoot = bestRoot
end

function SlingshotAimAssist:GetFireDirection(origin, fallbackDirection)
	if self.Aiming and self.LockedRoot and self.LockedRoot.Parent then
		local aimPoint = self:_getAimPoint(self.LockedRoot)
		local delta = aimPoint and (aimPoint - origin) or nil
		if delta and delta.Magnitude > 0.001 then
			return delta.Unit
		end
	end
	return fallbackDirection
end

function SlingshotAimAssist:_updatePreview(camera, now)
	if now - self.LastPreviewAt < self.Config.PreviewRayInterval then
		return
	end
	self.LastPreviewAt = now

	local origin = camera.CFrame.Position
	local direction = self:GetFireDirection(origin, camera.CFrame.LookVector)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	params.FilterDescendantsInstances = self.Character and { self.Character } or {}

	local result = Workspace:Raycast(origin, direction * self.Config.MaxRange, params)
	self.CachedPreviewPosition = result and result.Position or (origin + direction * self.Config.MaxRange)
end

function SlingshotAimAssist:Update(dt, camera, character, tool)
	if not self.Aiming or not camera then
		return
	end
	self:SetContext(character, tool)

	local now = os.clock()
	if not self:_isLockValid(camera) and now - self.LastAcquireAt >= self.Config.AcquireInterval then
		self.LastAcquireAt = now
		self.LockedModel = nil
		self.LockedRoot = nil
		self:_acquire(camera)
	end

	self:_setReticleLocked(self.LockedRoot ~= nil)

	if self.LockedRoot then
		local aimPoint = self:_getAimPoint(self.LockedRoot)
		local targetDirection = aimPoint and (aimPoint - camera.CFrame.Position).Unit or nil
		if targetDirection then
			local currentDirection = camera.CFrame.LookVector
			local alpha = 1 - math.exp(-self.Config.CameraResponsiveness * dt)
			local blended = currentDirection:Lerp(targetDirection, alpha)
			if blended.Magnitude > 0.001 then
				camera.CFrame = CFrame.lookAt(camera.CFrame.Position, camera.CFrame.Position + blended.Unit, Vector3.yAxis)
			end
		end
	end

	self:_updatePreview(camera, now)
	if self.TargetPart and self.CachedPreviewPosition then
		self.TargetPart.CFrame = CFrame.new(self.CachedPreviewPosition)
	end
	if self.Beam then
		self.Beam.Enabled = true
		self.Beam.Color = ColorSequence.new(self.LockedRoot and Color3.fromRGB(225, 167, 92) or Color3.fromRGB(238, 221, 177))
	end
end

function SlingshotAimAssist:Destroy()
	if self.MuzzleAttachment then self.MuzzleAttachment:Destroy() end
	if self.Beam then self.Beam:Destroy() end
	if self.TargetPart then self.TargetPart:Destroy() end
	if self.ScreenGui then self.ScreenGui:Destroy() end
	self.MuzzleAttachment = nil
	self.Beam = nil
	self.TargetPart = nil
	self.ScreenGui = nil
end

return SlingshotAimAssist
