print("[DragonRiderAttachmentFixRuntime] Active v7")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DRAGON_NAME = "DragonModel"
local active = {}

local function getConfig(dragon, name, fallback)
	local folder = dragon and dragon:FindFirstChild("DragonMountConfig")
	local obj = folder and folder:FindFirstChild(name)
	if obj and obj:IsA("ValueBase") then
		return obj.Value
	end
	return fallback
end

local function findBone(dragon, boneName)
	local mesh = dragon and dragon:FindFirstChild("DragonMesh")
	if not mesh then return nil end
	local found = mesh:FindFirstChild(boneName, true)
	if found and found:IsA("Bone") then return found end
	return nil
end

local function getBoneWorld(bone)
	if not bone then return nil end
	local ok, cf = pcall(function() return bone.TransformedWorldCFrame end)
	if ok and typeof(cf) == "CFrame" then return cf end
	local ok2, cf2 = pcall(function() return bone.WorldCFrame end)
	if ok2 and typeof(cf2) == "CFrame" then return cf2 end
	return nil
end

local function cleanupPlayer(player)
	local data = active[player]
	if data then
		if data.constraint then data.constraint:Destroy() end
		if data.attachment then data.attachment:Destroy() end
		if data.debugPart then data.debugPart:Destroy() end
		active[player] = nil
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")	
	local lowerTorso = character and (character:FindFirstChild("LowerTorso") or rootPart)

	if rootPart then
		for _, obj in ipairs(rootPart:GetChildren()) do
			if obj.Name == "DragonRiderRootWeld" then obj:Destroy() end
		end
	end

	if lowerTorso then
		for _, obj in ipairs(lowerTorso:GetChildren()) do
			if obj.Name:match("^DragonRiderMountRigidConstraint") then obj:Destroy() end
		end
	end

	local dragon = Workspace:FindFirstChild(DRAGON_NAME)
	local riderSeat = dragon and dragon:FindFirstChild("DragonRiderSeat")
	local seatWeld = riderSeat and riderSeat:FindFirstChild("SeatWeld")
	if seatWeld then seatWeld:Destroy() end
end

local function setupPlayer(player)
	local dragon = Workspace:FindFirstChild(DRAGON_NAME)
	if not dragon then return end

	local dragonRoot = dragon:FindFirstChild("HumanoidRootPart")
	if not dragonRoot or not dragonRoot:IsA("BasePart") then return end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local characterRoot = character and character:FindFirstChild("HumanoidRootPart")
	local lowerTorso = character and (character:FindFirstChild("LowerTorso") or characterRoot)
	if not character or not humanoid or not characterRoot or not lowerTorso then return end

	local mountBoneName = tostring(getConfig(dragon, "MountBoneName", "Bip01-Spine1_53"))
	local bone = findBone(dragon, mountBoneName)
	if not bone then
		for _, name in ipairs({ "Bip01-Spine1_53", "Bip01-Spine_64", "Bip01-Spine2_52", "Bip01-Pelvis_71", "Root_73" }) do
			bone = findBone(dragon, name)
			if bone then
				mountBoneName = name
				warn("[DragonRiderAttachmentFixRuntime] Bone invÃ¡lido; usando " .. name)
				break
			end
		end
	end
	if not bone then
		warn("[DragonRiderAttachmentFixRuntime] No encontrÃ© bone vÃ¡lido.")
		return
	end

	cleanupPlayer(player)

	local waistAttachment = lowerTorso:FindFirstChild("WaistCenterAttachment")
		or lowerTorso:FindFirstChild("WaistRigAttachment")
		or lowerTorso:FindFirstChild("RootRigAttachment")
		or lowerTorso:FindFirstChild("DragonRiderWaistAttachment")

	if not waistAttachment or not waistAttachment:IsA("Attachment") then
		waistAttachment = Instance.new("Attachment")
		waistAttachment.Name = "DragonRiderWaistAttachment"
		waistAttachment.Parent = lowerTorso
	end

	local mountAttachment = Instance.new("Attachment")
	mountAttachment.Name = "DragonStableMountAttachment_" .. tostring(player.UserId)
	mountAttachment.Parent = dragonRoot

	local constraint = Instance.new("RigidConstraint")
	constraint.Name = "DragonStableMountRigidConstraint_" .. tostring(player.UserId)
	constraint.Attachment0 = mountAttachment
	constraint.Attachment1 = waistAttachment
	constraint.Parent = dragonRoot

	local debugPart = nil
	if getConfig(dragon, "ShowDebugMount", true) == true then
		local folder = dragon:FindFirstChild("MountPoints")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "MountPoints"
			folder.Parent = dragon
		end
		debugPart = Instance.new("Part")
		debugPart.Name = "StableMountDebug_" .. tostring(player.UserId)
		debugPart.Size = Vector3.new(0.55, 0.55, 0.55)
		debugPart.Shape = Enum.PartType.Ball
		debugPart.Material = Enum.Material.Neon
		debugPart.Color = Color3.fromRGB(255, 0, 255)
		debugPart.Transparency = 0.15
		debugPart.Anchored = true
		debugPart.CanCollide = false
		debugPart.CanTouch = false
		debugPart.CanQuery = false
		debugPart.Parent = folder
	end

	active[player] = {
		bone = bone,
		boneName = mountBoneName,
		attachment = mountAttachment,
		constraint = constraint,
		debugPart = debugPart,
		lastWarn = 0,
		lastPrint = 0,
	}

	player:SetAttribute("DragonMountMode", "StableAttachmentRuntime")
	player:SetAttribute("DragonMountBoneName", mountBoneName)
	print("[DragonRiderAttachmentFixRuntime] Stable mount active for", player.Name, "bone=", mountBoneName)
end

local function syncPlayer(player)
	local dragon = Workspace:FindFirstChild(DRAGON_NAME)
	if not dragon then return end

	if player:GetAttribute("DragonMounted") ~= true then
		cleanupPlayer(player)
		return
	end

	local data = active[player]
	if not data then
		setupPlayer(player)
		data = active[player]
		if not data then return end
	end

	local dragonRoot = dragon:FindFirstChild("HumanoidRootPart")
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local characterRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not dragonRoot or not characterRoot or not humanoid then
		cleanupPlayer(player)
		return
	end

	local ox = tonumber(getConfig(dragon, "OffsetX", 0)) or 0
	local oy = tonumber(getConfig(dragon, "OffsetY", 3.8)) or 3.8
	local oz = tonumber(getConfig(dragon, "OffsetZ", 0.35)) or 0.35
	local rx = math.rad(tonumber(getConfig(dragon, "RotX", 0)) or 0)
	local ry = math.rad(tonumber(getConfig(dragon, "RotY", 0)) or 0)
	local rz = math.rad(tonumber(getConfig(dragon, "RotZ", 0)) or 0)

	local boneWorld = getBoneWorld(data.bone)
	if not boneWorld then return end

	local world = boneWorld * CFrame.new(ox, oy, oz) * CFrame.Angles(rx, ry, rz)
	data.attachment.CFrame = dragonRoot.CFrame:ToObjectSpace(world)
	if data.debugPart then data.debugPart.CFrame = world end

	humanoid.AutoRotate = false
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0

	local riderSeat = dragon:FindFirstChild("DragonRiderSeat")
	local seatWeld = riderSeat and riderSeat:FindFirstChild("SeatWeld")
	if seatWeld then seatWeld:Destroy() end

	local rootWeld = characterRoot:FindFirstChild("DragonRiderRootWeld")
	if rootWeld then rootWeld:Destroy() end

	local dist = (characterRoot.Position - world.Position).Magnitude
	if dist > 25 then
		local now = os.clock()
		if now - data.lastWarn > 2 then
			data.lastWarn = now
			warn("[DragonRiderAttachmentFixRuntime] Rider muy lejos del attachment; recentrando.")
		end
		character:PivotTo(world)
		characterRoot.AssemblyLinearVelocity = Vector3.zero
		characterRoot.AssemblyAngularVelocity = Vector3.zero
	end

	if getConfig(dragon, "MountVerboseLogs", false) == true then
		local now = os.clock()
		local interval = tonumber(getConfig(dragon, "DebugPrintInterval", 3)) or 3
		if now - data.lastPrint > interval then
			data.lastPrint = now
			print(("[DragonRiderAttachmentFixRuntime] mounted=%s bone=%s dist=%.2f"):format(player.Name, data.boneName, dist))
		end
	end
end

RunService.Heartbeat:Connect(function()
	for _, player in ipairs(Players:GetPlayers()) do
		syncPlayer(player)
	end
end)
Players.PlayerRemoving:Connect(cleanupPlayer)
