local CaptureService = {}
CaptureService.__index = CaptureService

local ACTUATOR_CLASSES = {
	LinearVelocity = true,
	AlignOrientation = true,
	AlignPosition = true,
	VectorForce = true,
}

local function getSheepRoot(sheepModel)
	if not sheepModel or not sheepModel.Parent then
		return nil
	end

	local root = sheepModel:FindFirstChild("HumanoidRootPart") or sheepModel.PrimaryPart
	if root and root:IsA("BasePart") then
		return root
	end

	return nil
end

local function getCarryAttachment(foxModel)
	if not foxModel then
		return nil
	end

	local attachment = foxModel:FindFirstChild("SheepCarryAttachment", true)
	if attachment and attachment:IsA("Attachment") then
		return attachment
	end

	return nil
end

local function getAttachmentWorldCFrame(attachment)
	if not attachment then
		return nil
	end

	local parent = attachment.Parent
	if parent and parent:IsA("Bone") then
		return parent.TransformedWorldCFrame * attachment.CFrame
	end

	return attachment.WorldCFrame
end

function CaptureService.new()
	return setmetatable({
		Active = {},
	}, CaptureService)
end

function CaptureService:GetCarryWorldCFrame(foxModel)
	return getAttachmentWorldCFrame(getCarryAttachment(foxModel))
end

function CaptureService:IsCaptured(sheepModel)
	return self.Active[sheepModel] ~= nil
		or (sheepModel and sheepModel:GetAttribute("CapturedByThreat") == true)
		or (sheepModel and sheepModel:GetAttribute("CapturedByDragon") == true)
end

function CaptureService:Grab(foxModel, sheepModel)
	if not foxModel or not foxModel.Parent or not sheepModel or not sheepModel.Parent then
		return false, "missing-model"
	end

	if self:IsCaptured(sheepModel) then
		return false, "already-captured"
	end

	local sheepRoot = getSheepRoot(sheepModel)
	local carryWorld = self:GetCarryWorldCFrame(foxModel)
	if not sheepRoot or not carryWorld then
		return false, "missing-root-or-carry-point"
	end

	local state = {
		Fox = foxModel,
		Sheep = sheepModel,
		Root = sheepRoot,
		CarryOffset = carryWorld:ToObjectSpace(sheepRoot.CFrame),
		Actuators = {},
	}

	for _, desc in ipairs(sheepModel:GetDescendants()) do
		if ACTUATOR_CLASSES[desc.ClassName] then
			table.insert(state.Actuators, {
				Object = desc,
				Enabled = desc.Enabled,
			})
			desc.Enabled = false
		end
	end

	local animationController = sheepModel:FindFirstChildOfClass("AnimationController")
	local animator = animationController and animationController:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			track:Stop(0.1)
		end
	end

	sheepRoot.AssemblyLinearVelocity = Vector3.zero
	sheepRoot.AssemblyAngularVelocity = Vector3.zero
	pcall(function()
		sheepRoot:SetNetworkOwner(nil)
	end)

	-- CapturedByDragon se mantiene temporalmente como flag de compatibilidad
	-- porque Flock.lua ya excluye esas ovejas de centro/flow. El estado canónico
	-- nuevo para depredadores es CapturedByThreat/CapturedByType.
	sheepModel:SetAttribute("CapturedByThreat", true)
	sheepModel:SetAttribute("CapturedByType", "Fox")
	sheepModel:SetAttribute("CapturedByDragon", true)
	foxModel:SetAttribute("IsCarryingSheep", true)

	self.Active[sheepModel] = state
	return true
end

function CaptureService:UpdateCarry(foxModel, sheepModel)
	local state = self.Active[sheepModel]
	if not state or state.Fox ~= foxModel then
		return false
	end

	if not foxModel.Parent or not sheepModel.Parent or not state.Root or not state.Root.Parent then
		return false
	end

	local carryWorld = self:GetCarryWorldCFrame(foxModel)
	if not carryWorld then
		return false
	end

	local targetRootCFrame = carryWorld * state.CarryOffset
	state.Root.AssemblyLinearVelocity = Vector3.zero
	state.Root.AssemblyAngularVelocity = Vector3.zero

	if sheepModel.PrimaryPart then
		sheepModel:PivotTo(targetRootCFrame)
	else
		state.Root.CFrame = targetRootCFrame
	end

	return true
end

function CaptureService:Release(foxModel, sheepModel)
	local state = sheepModel and self.Active[sheepModel]
	if not state then
		if foxModel and foxModel.Parent then
			foxModel:SetAttribute("IsCarryingSheep", false)
		end
		return false
	end

	self.Active[sheepModel] = nil

	for _, saved in ipairs(state.Actuators) do
		local obj = saved.Object
		if obj and obj.Parent then
			obj.Enabled = saved.Enabled
		end
	end

	if state.Root and state.Root.Parent then
		state.Root.AssemblyLinearVelocity = Vector3.zero
		state.Root.AssemblyAngularVelocity = Vector3.zero
	end

	if sheepModel and sheepModel.Parent then
		sheepModel:SetAttribute("CapturedByThreat", false)
		sheepModel:SetAttribute("CapturedByType", nil)
		sheepModel:SetAttribute("CapturedByDragon", false)
		sheepModel:SetAttribute("JustReleased", true)

		task.delay(1.25, function()
			if sheepModel and sheepModel.Parent then
				sheepModel:SetAttribute("JustReleased", false)
			end
		end)
	end

	if foxModel and foxModel.Parent then
		foxModel:SetAttribute("IsCarryingSheep", false)
	end

	return true
end

function CaptureService:ReleaseAllForFox(foxModel)
	for sheepModel, state in pairs(self.Active) do
		if state.Fox == foxModel then
			self:Release(foxModel, sheepModel)
		end
	end
end

return CaptureService
