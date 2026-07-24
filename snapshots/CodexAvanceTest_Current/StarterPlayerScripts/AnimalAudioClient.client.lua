local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Cfg = require(script.Parent:WaitForChild("AnimalAudioCfg"))
local random = Random.new()

if not Cfg.Enabled then
	return
end

local tracked = {} -- Model -> state
local activeSoundCount = 0
local lastScan = 0

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = false

local function debugPrint(...)
	if Cfg.Debug then
		print("[AnimalAudio]", ...)
	end
end

local function normalizeAssetId(value)
	if typeof(value) == "number" and value > 0 then
		return "rbxassetid://" .. tostring(math.floor(value))
	end
	if typeof(value) == "string" then
		local digits = string.match(value, "%d+")
		if digits and tonumber(digits) and tonumber(digits) > 0 then
			return "rbxassetid://" .. digits
		end
	end
	return nil
end

local function getPlayerRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getAnimalRoot(model)
	if not model or not model.Parent then
		return nil
	end

	local primary = model.PrimaryPart
	if primary and primary:IsA("BasePart") then
		return primary
	end

	local namedRoot = model:FindFirstChild("HumanoidRootPart", true)
	if namedRoot and namedRoot:IsA("BasePart") then
		return namedRoot
	end

	local genericRoot = model:FindFirstChildWhichIsA("BasePart", true)
	return genericRoot
end

local function resolveProfileName(model)
	local explicit = model:GetAttribute("AnimalType") or model:GetAttribute("AudioProfile")
	if typeof(explicit) == "string" and Cfg.Profiles[explicit] then
		return explicit
	end

	local lowerName = string.lower(model.Name)
	for profileName, profile in pairs(Cfg.Profiles) do
		for _, hint in ipairs(profile.NameHints or {}) do
			if string.find(lowerName, string.lower(hint), 1, true) then
				return profileName
			end
		end
	end

	return nil
end

local function isAnimalModel(instance)
	if not instance:IsA("Model") then
		return false
	end
	return resolveProfileName(instance) ~= nil and getAnimalRoot(instance) ~= nil
end

local function chooseAsset(list)
	if type(list) ~= "table" or #list == 0 then
		return nil
	end

	local startIndex = random:NextInteger(1, #list)
	for offset = 0, #list - 1 do
		local index = ((startIndex + offset - 2) % #list) + 1
		local assetId = normalizeAssetId(list[index])
		if assetId then
			return assetId
		end
	end
	return nil
end

local function playSpatialSound(root, assetList, settings)
	if activeSoundCount >= (Cfg.MaxConcurrentSounds or 10) then
		return false
	end

	local playerRoot = getPlayerRoot()
	if not playerRoot or not root or not root.Parent then
		return false
	end

	local distance = (playerRoot.Position - root.Position).Magnitude
	if distance > (Cfg.MaxAudibleDistance or 65) then
		return false
	end

	local assetId = chooseAsset(assetList)
	if not assetId then
		return false
	end

	local sound = Instance.new("Sound")
	sound.Name = "AnimalAudioOneShot"
	sound.SoundId = assetId
	sound.Volume = settings.Volume or 0.4
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = settings.RollOffMinDistance or 5
	sound.RollOffMaxDistance = settings.RollOffMaxDistance or 50
	sound.PlaybackSpeed = random:NextNumber(
		settings.PlaybackSpeedMin or 0.96,
		settings.PlaybackSpeedMax or 1.04
	)
	sound.Parent = root

	activeSoundCount += 1
	local released = false
	local function release()
		if released then
			return
		end
		released = true
		activeSoundCount = math.max(0, activeSoundCount - 1)
	end

	sound.Ended:Connect(release)
	sound.Destroying:Connect(release)
	sound:Play()
	Debris:AddItem(sound, 8)
	return true
end

local function nextVoiceTime(profile, now)
	local voice = profile.Voice or {}
	local minimum = voice.MinDelay or 15
	local maximum = math.max(minimum, voice.MaxDelay or 35)
	return now + random:NextNumber(minimum, maximum)
end

local function registerAnimal(model)
	if tracked[model] or not isAnimalModel(model) then
		return
	end

	local profileName = resolveProfileName(model)
	local profile = profileName and Cfg.Profiles[profileName]
	if not profile then
		return
	end

	local now = os.clock()
	tracked[model] = {
		ProfileName = profileName,
		Profile = profile,
		Root = getAnimalRoot(model),
		NextFootstep = now + random:NextNumber(0.05, 0.3),
		NextVoice = nextVoiceTime(profile, now),
		LastAlertState = false,
	}

	debugPrint("registrado", model:GetFullName(), profileName)
end

local function unregisterInvalidAnimals()
	for model, state in pairs(tracked) do
		if not model.Parent then
			tracked[model] = nil
		else
			state.Root = getAnimalRoot(model)
			if not state.Root then
				tracked[model] = nil
			end
		end
	end
end

local function scanRuntimeFolders()
	for _, folderName in ipairs(Cfg.RuntimeFolders or {}) do
		local folder = Workspace:FindFirstChild(folderName)
		if folder then
			for _, descendant in ipairs(folder:GetDescendants()) do
				if descendant:IsA("Model") then
					registerAnimal(descendant)
				end
			end
		end
	end
	unregisterInvalidAnimals()
end

local function getHorizontalSpeed(root)
	local velocity = root.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
end

local function getStepInterval(speed)
	local footsteps = Cfg.Footsteps
	if speed >= (footsteps.RunSpeed or 12.5) then
		return footsteps.RunInterval or 0.23
	elseif speed >= (footsteps.TrotSpeed or 5.5) then
		return footsteps.TrotInterval or 0.34
	end
	return footsteps.WalkInterval or 0.48
end

local function getSurfaceGroup(model, root)
	rayParams.FilterDescendantsInstances = { model, player.Character }
	local result = Workspace:Raycast(
		root.Position + Vector3.new(0, 1, 0),
		Vector3.new(0, -(Cfg.GroundRayLength or 8), 0),
		rayParams
	)

	if not result then
		return "Default"
	end

	local override = result.Instance and result.Instance:GetAttribute("FootstepSurface")
	if typeof(override) == "string" and override ~= "" then
		return override
	end

	return Cfg.MaterialGroups[result.Material] or "Default"
end

local function updateFootsteps(model, state, now, playerRoot)
	if not Cfg.Footsteps.Enabled or now < state.NextFootstep then
		return
	end

	local root = state.Root
	if not root or not root.Parent then
		return
	end

	local distance = (playerRoot.Position - root.Position).Magnitude
	if distance > (Cfg.Footsteps.RollOffMaxDistance or 45) + 8 then
		state.NextFootstep = now + 0.4
		return
	end

	local speed = getHorizontalSpeed(root)
	if speed < (Cfg.Footsteps.MinimumHorizontalSpeed or 1.35) then
		state.NextFootstep = now + 0.12
		return
	end

	local profileSteps = state.Profile.Footsteps or {}
	local group = getSurfaceGroup(model, root)
	local assets = profileSteps[group]
	if not assets or #assets == 0 then
		assets = profileSteps.Default
	end

	playSpatialSound(root, assets, Cfg.Footsteps)
	state.NextFootstep = now + getStepInterval(speed) * random:NextNumber(0.92, 1.08)
end

local function getAlertState(model)
	return model:GetAttribute("CapturedByDragon") == true
		or model:GetAttribute("IsPanicking") == true
		or model:GetAttribute("Panicking") == true
		or model:GetAttribute("JustReleased") == true
end

local function updateVoice(model, state, now, playerRoot)
	if not Cfg.Voices.Enabled then
		return
	end

	local root = state.Root
	if not root or not root.Parent then
		return
	end

	local alertState = getAlertState(model)
	if alertState and not state.LastAlertState then
		playSpatialSound(root, state.Profile.Voice and state.Profile.Voice.Alert, Cfg.Voices)
		state.NextVoice = nextVoiceTime(state.Profile, now)
	end
	state.LastAlertState = alertState

	if now < state.NextVoice then
		return
	end

	state.NextVoice = nextVoiceTime(state.Profile, now)
	local distance = (playerRoot.Position - root.Position).Magnitude
	if distance > (Cfg.Voices.RollOffMaxDistance or 58) + 8 then
		return
	end

	local voice = state.Profile.Voice or {}
	if random:NextNumber() <= (voice.Chance or 0.35) then
		playSpatialSound(root, voice.Idle, Cfg.Voices)
	end
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastScan >= (Cfg.ScanInterval or 0.5) then
		lastScan = now
		scanRuntimeFolders()
	end

	local playerRoot = getPlayerRoot()
	if not playerRoot then
		return
	end

	for model, state in pairs(tracked) do
		updateFootsteps(model, state, now, playerRoot)
		updateVoice(model, state, now, playerRoot)
	end
end)

scanRuntimeFolders()
debugPrint("cliente iniciado")
