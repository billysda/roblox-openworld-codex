-- SlingshotController v3
-- Local Honda/Slingshot battle controller. It does not replace global movement.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local RENDER_STEP_NAME = "SlingshotBattleCamera"

local slingshotRemoteFolder = ReplicatedStorage:WaitForChild("SlingshotRemote")
local fireRequestEvent = slingshotRemoteFolder:WaitForChild("FireRequest")
local fireResultEvent = slingshotRemoteFolder:WaitForChild("FireResult")
local ammoChangedEvent = slingshotRemoteFolder:WaitForChild("AmmoChanged")

local DEBUG_TOOL_TEST = false
local DEBUG_SUPPRESS_DEFAULT_TOOL_ANIMS = true
local DEBUG_DISABLE_TOOL_HANDLE_VISUAL = false
local DEBUG_DISABLE_BODY_LEAN = true
local DEBUG_DISABLE_CAMERA_KICK = true
local DEBUG_DISABLE_ROLL_CAMERA = true
local USE_VISUAL_SLINGSHOT_MODEL = false

local ARM_TEST_MODE = "Normal"
-- Allowed values:
-- "Normal"
-- "HideHandleOnly"
-- "NoRightGrip"
-- "AnimationOnlyNoTool"
-- "NoDefaultAnimate"
local ARM_TEST_RUN_PRIORITY = "Action2"
-- Allowed values: "Action", "Action2"

local TOOL_NAMES = {
	Honda = true,
	Slingshot = true,
}

local EXPECTED_ANIMATIONS = {
	"BattleIdle",
	"ForwardWalk",
	"WalkBack",
	"LeftWalk",
	"RightWalk",
	"Run",
	"Jump",
	"Falling",
	"Landing",
	"Slide",
	"ForwardRoll",
	"BackRoll",
	"LeftRoll",
	"RightRoll",
	"AimIdle",
	"AimWalk",
}

local SLINGSHOT_ANIM_IDS = {
	BattleIdle = "",

	ForwardWalk = "rbxassetid://115221880901221",
	WalkBack = "rbxassetid://118947770582006",
	LeftWalk = "rbxassetid://95882892791676",
	RightWalk = "rbxassetid://83682374587056",
	Run = "rbxassetid://75300022487459",

	Jump = "rbxassetid://119503398871932",
	Falling = "rbxassetid://117156129208587",
	Landing = "rbxassetid://78066032414207",

	Slide = "rbxassetid://95523738131385",

	ForwardRoll = "rbxassetid://122989211293201",
	BackRoll = "rbxassetid://96477627111389",
	LeftRoll = "rbxassetid://107353867818444",
	RightRoll = "rbxassetid://113337713022215",

	AimIdle = "rbxassetid://117985293791796",
	AimWalk = "",
}

local SLINGSHOT_CAMERA = {
	BattleOffset = Vector3.new(2.35, 1.35, 0),
	AimOffset = Vector3.new(2.85, 1.15, 0),

	BattleFOV = 74,
	AimFOV = 60,

	Responsiveness = 14,

	BobEnabled = true,
	WalkBobY = 0.18,
	WalkBobX = 0.09,
	RunBobY = 0.32,
	RunBobX = 0.16,
	BobWalkSpeed = 8,
	BobRunSpeed = 13,

	SwayEnabled = true,
	SwayFromMouse = 0.05,
	SwayFromMove = 0.12,

	RollTiltWalk = 2.5,
	RollTiltRun = 4.5,
	AimRollTilt = 1.2,

	LandingKick = 0.22,
	SlideTilt = 5.0,
	RollCameraKick = 0.25,
}

local BATTLE_WALK_SPEED = 14
local BATTLE_RUN_SPEED = 19
local AIM_WALK_SPEED = 9
local TURN_RESPONSIVENESS = 14
local ROLL_COOLDOWN = 1.2
local ROLL_DURATION = 0.45
local ROLL_DISTANCE = 9.0
local SLIDE_COOLDOWN = 1.4
local SLIDE_DURATION = 0.55
local SLIDE_DISTANCE = 11.0

local SLINGSHOT_FIRE = {
	MaxChargeTime = 0.8,
	MinChargeToFire = 0.05,
	ProjectileMinDuration = 0.12,
	ProjectileMaxDuration = 0.25,
	ProjectileSpeed = 650,
}

local LOCOMOTION_STATES = {
	BattleIdle = true,
	ForwardWalk = true,
	WalkBack = true,
	LeftWalk = true,
	RightWalk = true,
	Run = true,
	AimIdle = true,
	AimWalk = true,
}

local ACTION_STATES = {
	Jump = true,
	Falling = true,
	Landing = true,
	Slide = true,
	ForwardRoll = true,
	BackRoll = true,
	LeftRoll = true,
	RightRoll = true,
}

local HIGH_PRIORITY = Enum.AnimationPriority.Action
pcall(function()
	if Enum.AnimationPriority.Action2 then
		HIGH_PRIORITY = Enum.AnimationPriority.Action2
	end
end)

local active = false
local activeTool = nil
local character = nil
local humanoid = nil
local rootPart = nil
local animator = nil
local stateConn = nil
local diedConn = nil
local renderBound = false
local currentLocomotion = nil
local currentMoveState = "BattleIdle"
local currentActionState = ""
local previousState = nil
local tracks = {}
local trackAnimations = {}
local ownedTracks = {}
local wiredTools = {}
local warnedMissingIds = {}
local warnedInvalidIds = {}
local keysDown = {}
local isBattleMode = false
local isAiming = false
local isRolling = false
local isSliding = false
local isJumping = false
local isFalling = false
local isLanding = false
local nextRollAt = 0
local nextSlideAt = 0
local activeAction = nil
local actionToken = 0
local chargeStart = nil
local bobTime = 0
local smoothedCameraOffset = Vector3.zero
local cameraRoll = 0
local cameraPitchKick = 0
local mouseSway = 0
local jointData = {}
local debugPrintedRunAnimations = false
local stoppedDefaultToolTracks = {}
local defaultToolAnimationIds = {
	["rbxassetid://507768375"] = true,
	["http://www.roblox.com/asset/?id=507768375"] = true,
	["rbxassetid://182393478"] = true,
	["http://www.roblox.com/asset/?id=182393478"] = true,
}
local armTestPrintedRunTracks = false
local rightGripBackup = nil
local animateBackup = nil
local runOnlyTrack = nil
local runOnlyAnimation = nil
local playProjectileVisual = nil

local ammoUI = nil
local ammoLabel = nil
local feedbackLabel = nil
local feedbackTween = nil

local function getOrCreateUI()
	local playerGui = player:WaitForChild("PlayerGui", 5)
	if not playerGui then return nil end

	if playerGui:FindFirstChild("SlingshotUI") then
		ammoUI = playerGui.SlingshotUI
		ammoLabel = ammoUI:FindFirstChild("AmmoLabel", true)
		feedbackLabel = ammoUI:FindFirstChild("FeedbackLabel", true)
		return ammoUI
	end

	ammoUI = Instance.new("ScreenGui")
	ammoUI.Name = "SlingshotUI"
	ammoUI.ResetOnSpawn = false
	ammoUI.Enabled = false

	ammoLabel = Instance.new("TextLabel")
	ammoLabel.Name = "AmmoLabel"
	ammoLabel.Size = UDim2.new(0, 100, 0, 40)
	ammoLabel.Position = UDim2.new(0.5, 0, 1, -120)
	ammoLabel.AnchorPoint = Vector2.new(0.5, 1)
	ammoLabel.BackgroundTransparency = 0.5
	ammoLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	ammoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	ammoLabel.TextScaled = true
	ammoLabel.Font = Enum.Font.GothamBold
	ammoLabel.Text = "ðŸ¥š x 0"
	ammoLabel.Parent = ammoUI
	
	local stroke = Instance.new("UIStroke")
	stroke.Parent = ammoLabel
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = ammoLabel

	feedbackLabel = Instance.new("TextLabel")
	feedbackLabel.Name = "FeedbackLabel"
	feedbackLabel.Size = UDim2.new(0, 200, 0, 40)
	feedbackLabel.Position = UDim2.new(0.5, 0, 1, -170)
	feedbackLabel.AnchorPoint = Vector2.new(0.5, 1)
	feedbackLabel.BackgroundTransparency = 1
	feedbackLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	feedbackLabel.TextScaled = true
	feedbackLabel.Font = Enum.Font.GothamBold
	feedbackLabel.Text = "No tienes huevos"
	feedbackLabel.TextTransparency = 1
	feedbackLabel.Parent = ammoUI

	local stroke2 = Instance.new("UIStroke")
	stroke2.Parent = feedbackLabel

	ammoUI.Parent = playerGui
	return ammoUI
end

local function updateAmmoUI()
	if not ammoLabel then return end
	local ammo = player:GetAttribute("SlingshotEggAmmo") or 0
	ammoLabel.Text = "ðŸ¥š x " .. tostring(ammo)
end

local function showFeedback(msg)
	if not feedbackLabel then return end
	feedbackLabel.Text = msg
	feedbackLabel.TextTransparency = 0
	if feedbackTween then feedbackTween:Cancel() end
	
	local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.5)
	feedbackTween = TweenService:Create(feedbackLabel, tweenInfo, {TextTransparency = 1})
	feedbackTween:Play()
end

local function writeAction(actionName)
	currentActionState = actionName or ""
	player:SetAttribute("SlingshotAction", currentActionState)
	if character then
		character:SetAttribute("SlingshotAction", currentActionState)
	end
end

local function setDebugAttributes(equipped, battleMode, aiming, moveState)
	currentMoveState = moveState or "Idle"
	player:SetAttribute("SlingshotEquipped", equipped)
	player:SetAttribute("SlingshotBattleMode", battleMode)
	player:SetAttribute("SlingshotAiming", aiming)
	player:SetAttribute("SlingshotMoveState", currentMoveState)

	if character then
		character:SetAttribute("SlingshotEquipped", equipped)
		character:SetAttribute("SlingshotBattleMode", battleMode)
		character:SetAttribute("SlingshotAiming", aiming)
		character:SetAttribute("SlingshotMoveState", currentMoveState)
	end
end

local function resetDebugAttributes()
	setDebugAttributes(false, false, false, "Idle")
	writeAction("")
end

local function forceLocalUnequipTools()
	task.defer(function()
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:UnequipTools()
		end
	end)
end

local function setTemporaryAction(actionName, duration)
	actionToken += 1
	local token = actionToken
	writeAction(actionName)

	task.delay(duration or 0.35, function()
		if active and token == actionToken then
			writeAction("")
		end
	end)
end

local function clearAction()
	actionToken += 1
	writeAction("")
end

local function normalizeAnimationId(animId)
	if typeof(animId) ~= "string" then
		return nil
	end

	local trimmed = animId:match("^%s*(.-)%s*$")
	if trimmed == "" then
		return nil
	end

	if trimmed:match("^rbxassetid://%d+$") then
		return trimmed
	end

	if trimmed:match("^%d+$") then
		return "rbxassetid://" .. trimmed
	end

	return false
end

local function getFullNameSafe(inst)
	if not inst then
		return "nil"
	end

	local ok, fullName = pcall(function()
		return inst:GetFullName()
	end)

	return ok and fullName or tostring(inst)
end

local function getAnimationIdSafe(track)
	local okAnimation, animation = pcall(function()
		return track.Animation
	end)

	if okAnimation and animation then
		return animation.AnimationId or ""
	end

	return ""
end

local function getAnimationNameSafe(track)
	local okAnimation, animation = pcall(function()
		return track.Animation
	end)

	if okAnimation and animation then
		return animation.Name or ""
	end

	return ""
end

local function findRightGrip()
	if not character then
		return nil
	end

	local rightHand = character:FindFirstChild("RightHand")
	local rightArm = character:FindFirstChild("Right Arm")
	local rightGrip = (rightHand and rightHand:FindFirstChild("RightGrip")) or (rightArm and rightArm:FindFirstChild("RightGrip"))
	if rightGrip then
		return rightGrip
	end

	for _, desc in ipairs(character:GetDescendants()) do
		if desc.Name == "RightGrip" and (desc:IsA("Weld") or desc:IsA("Motor6D") or desc:IsA("WeldConstraint")) then
			return desc
		end
	end

	return nil
end

local function printToolDiagnostics(tool)
	if not DEBUG_TOOL_TEST then
		return
	end

	local handle = tool and tool:FindFirstChild("Handle")
	local rightGrip = findRightGrip()
	print(string.format("[SlingshotDebug] RightGrip found: %s path=%s", tostring(rightGrip ~= nil), getFullNameSafe(rightGrip)))
	print(string.format("[SlingshotDebug] Tool Handle found: %s", tostring(handle ~= nil)))
	print(string.format("[SlingshotDebug] Tool RequiresHandle=%s", tostring(tool and tool.RequiresHandle)))
	print(string.format("[SlingshotDebug] Tool Grip=%s", tostring(tool and tool.Grip)))

	if rightGrip then
		local part0 = rightGrip:IsA("WeldConstraint") and rightGrip.Part0 or rightGrip.Part0
		local part1 = rightGrip:IsA("WeldConstraint") and rightGrip.Part1 or rightGrip.Part1
		print(string.format("[SlingshotDebug] RightGrip Part0=%s Part1=%s", part0 and part0.Name or "nil", part1 and part1.Name or "nil"))
	end
end

local function getTrackWeightSafe(track, propertyName)
	local ok, value = pcall(function()
		return track[propertyName]
	end)
	if ok then
		return tostring(value)
	end
	return "?"
end

local function printActiveAnimationTracks(reason)
	if not DEBUG_TOOL_TEST or not animator then
		return
	end

	print("[SlingshotDebug] Active Animator tracks " .. tostring(reason or ""))
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		local trackName = track.Name or ""
		local animationName = getAnimationNameSafe(track)
		local animationId = getAnimationIdSafe(track)
		print(string.format("[SlingshotDebug] Track name=%s animation=%s id=%s priority=%s weight=%s target=%s", tostring(trackName), tostring(animationName), tostring(animationId), tostring(track.Priority), getTrackWeightSafe(track, "WeightCurrent"), getTrackWeightSafe(track, "WeightTarget")))
	end
end

local function printArmTestRunTracks()
	if not animator then
		return
	end

	print("[ArmTest] Active tracks during Run:")
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		local trackName = track.Name or ""
		local animationName = getAnimationNameSafe(track)
		local animationId = getAnimationIdSafe(track)
		print(string.format("[ArmTest] name=%s anim=%s id=%s priority=%s weight=%s target=%s", tostring(trackName), tostring(animationName), tostring(animationId), tostring(track.Priority), getTrackWeightSafe(track, "WeightCurrent"), getTrackWeightSafe(track, "WeightTarget")))
	end
end

local function setToolHandleVisual(tool, hidden)
	if not tool then
		return
	end

	local shouldHideAll = DEBUG_DISABLE_TOOL_HANDLE_VISUAL
	if not shouldHideAll and ARM_TEST_MODE ~= "HideHandleOnly" then
		return
	end

	for _, desc in ipairs(tool:GetDescendants()) do
		if desc:IsA("BasePart") and (shouldHideAll or desc.Name == "Handle") then
			desc.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

local function disableAnimateForArmTest()
	if ARM_TEST_MODE ~= "NoDefaultAnimate" or not character then
		return
	end

	local animate = character:FindFirstChild("Animate")
	local disabled = false
	if animate and animate:IsA("LocalScript") then
		animateBackup = animateBackup or { Script = animate, Disabled = animate.Disabled }
		animate.Disabled = true
		disabled = true
	end

	print(string.format("[ArmTest] Mode=NoDefaultAnimate AnimateDisabled=%s", tostring(disabled)))
end

local function restoreAnimateForArmTest()
	if animateBackup and animateBackup.Script then
		pcall(function()
			animateBackup.Script.Disabled = animateBackup.Disabled
		end)
	end
	animateBackup = nil
end

local function removeRightGripForArmTest()
	if ARM_TEST_MODE ~= "NoRightGrip" then
		return
	end

	local rightGrip = findRightGrip()
	local removed = false
	if rightGrip then
		local c0 = nil
		local c1 = nil
		pcall(function()
			c0 = rightGrip.C0
			c1 = rightGrip.C1
		end)
		rightGripBackup = {
			ClassName = rightGrip.ClassName,
			Name = rightGrip.Name,
			Parent = rightGrip.Parent,
			Part0 = rightGrip.Part0,
			Part1 = rightGrip.Part1,
			C0 = c0,
			C1 = c1,
		}
		rightGrip:Destroy()
		removed = true
	end

	print(string.format("[ArmTest] Mode=NoRightGrip RightGripRemoved=%s", tostring(removed)))
end

local function restoreRightGripForArmTest()
	if not rightGripBackup then
		return
	end

	local backup = rightGripBackup
	rightGripBackup = nil
	if not backup.Parent or backup.Parent:FindFirstChild(backup.Name) then
		return
	end

	local ok, joint = pcall(function()
		return Instance.new(backup.ClassName)
	end)
	if not ok or not joint then
		return
	end

	joint.Name = backup.Name
	pcall(function()
		joint.Part0 = backup.Part0
		joint.Part1 = backup.Part1
	end)
	pcall(function()
		if backup.C0 then
			joint.C0 = backup.C0
		end
		if backup.C1 then
			joint.C1 = backup.C1
		end
	end)
	joint.Parent = backup.Parent
end

local function applyArmTestMode(tool)
	if not DEBUG_TOOL_TEST or ARM_TEST_MODE == "Normal" then
		return
	end

	print("[ArmTest] Mode=" .. tostring(ARM_TEST_MODE))
	if ARM_TEST_MODE == "HideHandleOnly" then
		setToolHandleVisual(tool, true)
		print(string.format("[ArmTest] Mode=HideHandleOnly HandleHidden=true RightGripStillExists=%s", tostring(findRightGrip() ~= nil)))
	elseif ARM_TEST_MODE == "NoRightGrip" then
		removeRightGripForArmTest()
	elseif ARM_TEST_MODE == "NoDefaultAnimate" then
		disableAnimateForArmTest()
	elseif ARM_TEST_MODE == "AnimationOnlyNoTool" then
		print("[ArmTest] Mode=AnimationOnlyNoTool Use F8 with Honda unequipped to play Run only")
	end
end

local function resolveCharacter()
	character = player.Character
	if not character then
		return false
	end

	humanoid = character:FindFirstChildOfClass("Humanoid")
	rootPart = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not rootPart or humanoid.Health <= 0 then
		return false
	end

	animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	return true
end

local function stopTrack(track, fadeTime)
	if track then
		pcall(function()
			track:Stop(fadeTime or 0.12)
			track:Destroy()
		end)
	end
end

local function stopAllAnimations()
	for name, track in pairs(tracks) do
		ownedTracks[track] = nil
		stopTrack(track, 0.12)
		tracks[name] = nil
	end

	for name, animation in pairs(trackAnimations) do
		animation:Destroy()
		trackAnimations[name] = nil
	end

	currentLocomotion = nil
end

local function loadAnimations()
	stopAllAnimations()

	if not animator then
		return
	end

	for _, name in ipairs(EXPECTED_ANIMATIONS) do
		local normalizedId = normalizeAnimationId(SLINGSHOT_ANIM_IDS[name])
		if normalizedId == nil then
			if DEBUG_TOOL_TEST and not warnedMissingIds[name] then
				warn("[SlingshotController] Missing ID for " .. name)
				warnedMissingIds[name] = true
			end
		elseif normalizedId == false then
			if not warnedInvalidIds[name] then
				warn("[SlingshotController] Invalid AnimationId for " .. name .. ": " .. tostring(SLINGSHOT_ANIM_IDS[name]))
				warnedInvalidIds[name] = true
			end
		else
			local animation = Instance.new("Animation")
			animation.Name = name
			animation.AnimationId = normalizedId
			trackAnimations[name] = animation

			local ok, track = pcall(function()
				return animator:LoadAnimation(animation)
			end)

			if ok and track then
				if name == "Run" and ARM_TEST_RUN_PRIORITY == "Action" then
					track.Priority = Enum.AnimationPriority.Action
				elseif LOCOMOTION_STATES[name] or ACTION_STATES[name] then
					track.Priority = HIGH_PRIORITY
				end

				if DEBUG_TOOL_TEST and name == "Run" then
					print(string.format("[ArmTest] Run priority=%s", tostring(track.Priority)))
				end

				track.Looped = LOCOMOTION_STATES[name] == true or name == "Falling"
				tracks[name] = track
				ownedTracks[track] = true
			else
				warn("[SlingshotController] Failed to load animation: " .. name)
			end
		end
	end
end

local function stopRunOnlyArmTest()
	if runOnlyTrack then
		pcall(function()
			runOnlyTrack:Stop(0.12)
			runOnlyTrack:Destroy()
		end)
		runOnlyTrack = nil
	end

	if runOnlyAnimation then
		runOnlyAnimation:Destroy()
		runOnlyAnimation = nil
	end
end

local function startRunOnlyArmTest()
	if not DEBUG_TOOL_TEST then
		return
	end

	if ARM_TEST_MODE ~= "AnimationOnlyNoTool" then
		print("[ArmTest] F8 ignored. Set ARM_TEST_MODE = \"AnimationOnlyNoTool\" first.")
		return
	end

	if active then
		print("[ArmTest] AnimationOnlyNoTool blocked because Honda BattleMode is active. Unequip Honda first.")
		return
	end

	if runOnlyTrack then
		stopRunOnlyArmTest()
		print("[ArmTest] Mode=AnimationOnlyNoTool RunOnlyStopped")
		return
	end

	if not resolveCharacter() then
		warn("[ArmTest] AnimationOnlyNoTool could not start: character not ready")
		return
	end

	local runId = normalizeAnimationId(SLINGSHOT_ANIM_IDS.Run)
	if not runId or runId == false then
		warn("[ArmTest] AnimationOnlyNoTool could not start: Run ID missing or invalid")
		return
	end

	runOnlyAnimation = Instance.new("Animation")
	runOnlyAnimation.Name = "ArmTestRunOnly"
	runOnlyAnimation.AnimationId = runId

	local ok, track = pcall(function()
		return animator:LoadAnimation(runOnlyAnimation)
	end)
	if not ok or not track then
		warn("[ArmTest] AnimationOnlyNoTool could not load Run")
		return
	end

	runOnlyTrack = track
	if ARM_TEST_RUN_PRIORITY == "Action" then
		runOnlyTrack.Priority = Enum.AnimationPriority.Action
	else
		runOnlyTrack.Priority = HIGH_PRIORITY
	end
	runOnlyTrack.Looped = true
	runOnlyTrack:Play(0.12)
	print("[ArmTest] Mode=AnimationOnlyNoTool RunOnlyStarted")
	printArmTestRunTracks()
end

local function stopLocomotion()
	if currentLocomotion and tracks[currentLocomotion] then
		pcall(function()
			tracks[currentLocomotion]:Stop(0.12)
		end)
	end
	currentLocomotion = nil
end

local function playLocomotion(stateName)
	if currentLocomotion == stateName then
		return
	end

	stopLocomotion()

	local track = tracks[stateName]
	if track then
		pcall(function()
			track:Play(0.12)
		end)
		currentLocomotion = stateName
	end
end

local function playAction(stateName)
	local track = tracks[stateName]
	if not track then
		return false
	end

	pcall(function()
		track:Stop(0.03)
		track:Play(0.06)
	end)

	return true
end

local function stopActionTrack(stateName)
	local track = tracks[stateName]
	if track then
		pcall(function()
			track:Stop(0.08)
		end)
	end
end

local function isKeyDown(keyCode)
	return keysDown[keyCode] == true or UserInputService:IsKeyDown(keyCode)
end

local function GetRawMoveInput()
	local wDown = isKeyDown(Enum.KeyCode.W)
	local aDown = isKeyDown(Enum.KeyCode.A)
	local sDown = isKeyDown(Enum.KeyCode.S)
	local dDown = isKeyDown(Enum.KeyCode.D)
	local shiftDown = isKeyDown(Enum.KeyCode.LeftShift) or isKeyDown(Enum.KeyCode.RightShift)
	local forward = 0
	local side = 0

	if wDown then
		forward += 1
	end
	if sDown then
		forward -= 1
	end
	if dDown then
		side += 1
	end
	if aDown then
		side -= 1
	end

	return {
		W = wDown,
		A = aDown,
		S = sDown,
		D = dDown,
		Shift = shiftDown,
		forward = math.clamp(forward, -1, 1),
		side = math.clamp(side, -1, 1),
	}
end

local function rawHasMovement(raw)
	return raw.W or raw.A or raw.S or raw.D
end

local function getBattleMoveState(raw)
	if raw.Shift and raw.W then
		return "Run"
	end
	if raw.W then
		return "ForwardWalk"
	end
	if raw.S then
		return "WalkBack"
	end
	if raw.A then
		return "LeftWalk"
	end
	if raw.D then
		return "RightWalk"
	end
	return "BattleIdle"
end

local function chooseLocomotionState(raw)
	if isFalling then
		return "Falling"
	end

	if isAiming then
		if rawHasMovement(raw) then
			if tracks.AimWalk then
				return "AimWalk"
			end
			return getBattleMoveState(raw)
		end
		return "AimIdle"
	end

	return getBattleMoveState(raw)
end

local function getFlatVector(vector)
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude <= 0.001 then
		return nil
	end
	return flat.Unit
end

local function getCameraBasis()
	local camera = Workspace.CurrentCamera
	local forward = camera and getFlatVector(camera.CFrame.LookVector) or nil
	local right = camera and getFlatVector(camera.CFrame.RightVector) or nil

	if not forward and rootPart then
		forward = getFlatVector(rootPart.CFrame.LookVector)
	end
	if not right and rootPart then
		right = getFlatVector(rootPart.CFrame.RightVector)
	end

	return forward or Vector3.zAxis, right or Vector3.xAxis
end

local function getDirectionFromRaw(raw, fallbackForward)
	local forward, right = getCameraBasis()
	local direction = (forward * raw.forward) + (right * raw.side)

	if direction.Magnitude <= 0.001 then
		return fallbackForward or forward
	end

	return direction.Unit
end

local function getRollActionName(raw)
	if raw.S then
		return "BackRoll"
	end
	if raw.A then
		return "LeftRoll"
	end
	if raw.D then
		return "RightRoll"
	end
	return "ForwardRoll"
end

local function getRollDirection(raw)
	local forward, right = getCameraBasis()
	if raw.S then
		return -forward
	end
	if raw.A then
		return -right
	end
	if raw.D then
		return right
	end
	return forward
end

local function trackLooksLikeDefaultTool(track)
	if ownedTracks[track] then
		return false
	end

	local trackName = track.Name or ""
	local animationName = getAnimationNameSafe(track)
	local animationId = getAnimationIdSafe(track)
	local lowerTrackName = string.lower(trackName)
	local lowerAnimationName = string.lower(animationName)
	local lowerAnimationId = string.lower(animationId)

	if lowerTrackName:find("tool") or lowerAnimationName:find("tool") then
		return true
	end

	if defaultToolAnimationIds[animationId] or defaultToolAnimationIds[lowerAnimationId] or lowerAnimationId:find("507768375") or lowerAnimationId:find("182393478") then
		return true
	end

	if track.Priority == Enum.AnimationPriority.Action or track.Priority == HIGH_PRIORITY then
		return true
	end

	return false
end

local function suppressDefaultToolPose(forcePrint)
	if not DEBUG_SUPPRESS_DEFAULT_TOOL_ANIMS or not animator then
		return
	end

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if trackLooksLikeDefaultTool(track) then
			local trackName = track.Name or ""
			local animationId = getAnimationIdSafe(track)
			local key = trackName .. "|" .. animationId
			pcall(function()
				track:Stop(0.05)
			end)
			if DEBUG_TOOL_TEST and (forcePrint or not stoppedDefaultToolTracks[key]) then
				stoppedDefaultToolTracks[key] = true
				print(string.format("[SlingshotDebug] Stopped possible default tool animation: %s %s", tostring(trackName), tostring(animationId)))
			end
		end
	end
end

local function findMotorByName(parent, name)
	if not parent then
		return nil
	end

	local direct = parent:FindFirstChild(name)
	if direct and direct:IsA("Motor6D") then
		return direct
	end

	for _, desc in ipairs(parent:GetDescendants()) do
		if desc:IsA("Motor6D") and desc.Name == name then
			return desc
		end
	end

	return nil
end

local function captureJoints()
	jointData = {}
	if not character then
		return
	end

	local lowerTorso = character:FindFirstChild("LowerTorso")
	local upperTorso = character:FindFirstChild("UpperTorso")
	local head = character:FindFirstChild("Head")
	local rightUpperLeg = character:FindFirstChild("RightUpperLeg")
	local leftUpperLeg = character:FindFirstChild("LeftUpperLeg")

	local joints = {
		Root = lowerTorso and findMotorByName(lowerTorso, "Root") or findMotorByName(character, "Root"),
		Waist = upperTorso and findMotorByName(upperTorso, "Waist") or findMotorByName(character, "Waist"),
		Neck = (head and findMotorByName(head, "Neck")) or (upperTorso and findMotorByName(upperTorso, "Neck")) or findMotorByName(character, "Neck"),
		RightHip = rightUpperLeg and findMotorByName(rightUpperLeg, "RightHip") or findMotorByName(character, "RightHip"),
		LeftHip = leftUpperLeg and findMotorByName(leftUpperLeg, "LeftHip") or findMotorByName(character, "LeftHip"),
	}

	for label, motor in pairs(joints) do
		if motor then
			jointData[label] = {
				Motor = motor,
				BaseC0 = motor.C0,
				CurrentC0 = motor.C0,
			}
		end
	end
end

local function restoreJoints()
	for _, data in pairs(jointData) do
		if data.Motor then
			pcall(function()
				data.Motor.C0 = data.BaseC0
			end)
		end
	end
	jointData = {}
end

local function lerpJoint(label, transform, alpha)
	local data = jointData[label]
	if not data or not data.Motor then
		return
	end

	local target = data.BaseC0 * transform
	data.CurrentC0 = data.CurrentC0:Lerp(target, alpha)
	data.Motor.C0 = data.CurrentC0
end

local function updateBodyLean(dt, raw)
	if DEBUG_DISABLE_BODY_LEAN or not active then
		return
	end

	local alpha = 1 - math.exp(-12 * dt)
	local side = raw.side
	local forward = raw.forward
	local runBoost = raw.Shift and raw.W and 1.35 or 1
	local backFactor = raw.S and -0.55 or 1

	local sideRoll = math.rad(-side * 6 * runBoost)
	local sideYaw = math.rad(side * 4 * backFactor)
	local forwardPitch = math.rad(-math.max(forward, 0) * 3 * runBoost)
	local backPitch = math.rad(math.max(-forward, 0) * 2)

	lerpJoint("Root", CFrame.Angles(forwardPitch + backPitch, sideYaw * 0.4, sideRoll * 0.35), alpha)
	lerpJoint("Waist", CFrame.Angles(forwardPitch * 0.55, sideYaw, sideRoll), alpha)
	lerpJoint("Neck", CFrame.Angles(-forwardPitch * 0.25, -sideYaw * 0.55, -sideRoll * 0.45), alpha)
	lerpJoint("RightHip", CFrame.Angles(0, 0, math.rad(side * 2.2)), alpha)
	lerpJoint("LeftHip", CFrame.Angles(0, 0, math.rad(side * 2.2)), alpha)
end

local function restorePreviousState()
	if humanoid then
		if previousState and previousState.AutoRotate ~= nil then
			humanoid.AutoRotate = previousState.AutoRotate
		else
			humanoid.AutoRotate = true
		end

		if previousState and previousState.WalkSpeed then
			humanoid.WalkSpeed = previousState.WalkSpeed
		end

		if previousState and previousState.CameraOffset then
			humanoid.CameraOffset = previousState.CameraOffset
		else
			humanoid.CameraOffset = Vector3.zero
		end
	end

	local camera = Workspace.CurrentCamera
	if camera and previousState and previousState.FieldOfView then
		camera.FieldOfView = previousState.FieldOfView
	end

	if previousState then
		UserInputService.MouseBehavior = previousState.MouseBehavior or Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = previousState.MouseIconEnabled
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
end

local function resetCameraState()
	bobTime = 0
	smoothedCameraOffset = previousState and previousState.CameraOffset or Vector3.zero
	cameraRoll = 0
	cameraPitchKick = 0
	mouseSway = 0
end

local function cleanupMode(reason)
	local hadState = active or activeTool ~= nil
	local oldTool = activeTool

	active = false
	activeTool = nil
	isBattleMode = false
	isAiming = false
	isRolling = false
	isSliding = false
	isJumping = false
	isFalling = false
	isLanding = false
	activeAction = nil
	chargeStart = nil

	if renderBound then
		RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
		renderBound = false
	end

	if stateConn then
		stateConn:Disconnect()
		stateConn = nil
	end
	if diedConn then
		diedConn:Disconnect()
		diedConn = nil
	end

	if ammoUI then
		ammoUI.Enabled = false
	end

	setToolHandleVisual(oldTool, false)
	restoreRightGripForArmTest()
	restoreAnimateForArmTest()
	stopAllAnimations()
	restoreJoints()
	restorePreviousState()
	previousState = nil
	resetCameraState()
	clearAction()
	resetDebugAttributes()

	if hadState and reason then
		print("[SlingshotController] Deactivated:", reason)
	end
end

local function safeMoveRoot(direction, distance)
	if not rootPart or not character or distance <= 0 then
		return
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true

	local origin = rootPart.Position + Vector3.new(0, 1.5, 0)
	local castDistance = math.max(distance + 0.35, 0.35)
	local hit = Workspace:Raycast(origin, direction * castDistance, params)
	if hit then
		return
	end

	rootPart.CFrame = rootPart.CFrame + (direction * distance)
end

local function startAction(kind, actionName, direction, duration, distance)
	if activeAction then
		return
	end

	isRolling = kind == "Roll"
	isSliding = kind == "Slide"
	activeAction = {
		Kind = kind,
		Name = actionName,
		Direction = direction.Unit,
		StartedAt = os.clock(),
		Duration = duration,
		Distance = distance,
		Moved = 0,
	}

	stopLocomotion()
	playAction(actionName)
	writeAction(actionName)

	if not DEBUG_DISABLE_CAMERA_KICK then
		if kind == "Roll" and not DEBUG_DISABLE_ROLL_CAMERA then
			cameraPitchKick += SLINGSHOT_CAMERA.RollCameraKick
		elseif kind == "Slide" then
			cameraPitchKick += SLINGSHOT_CAMERA.RollCameraKick * 0.5
		end
	end
end

local function finishAction()
	if activeAction then
		stopActionTrack(activeAction.Name)
	end

	activeAction = nil
	isRolling = false
	isSliding = false
	writeAction("")
end

local function updateActionMotion(dt)
	if not activeAction then
		return
	end

	local now = os.clock()
	local elapsed = now - activeAction.StartedAt
	local alpha = math.clamp(elapsed / activeAction.Duration, 0, 1)

	if alpha >= 1 then
		finishAction()
		return
	end

	local desiredMoved = activeAction.Distance * math.sin(alpha * math.pi * 0.5)
	local deltaMove = math.max(desiredMoved - activeAction.Moved, 0)
	activeAction.Moved = desiredMoved
	safeMoveRoot(activeAction.Direction, deltaMove)
end

local function updateMovementSpeed(raw)
	if not humanoid then
		return
	end

	if isAiming then
		humanoid.WalkSpeed = AIM_WALK_SPEED
	elseif raw.Shift and raw.W then
		humanoid.WalkSpeed = BATTLE_RUN_SPEED
	else
		humanoid.WalkSpeed = BATTLE_WALK_SPEED
	end
end

local function updateRootFacing(dt)
	local camera = Workspace.CurrentCamera
	local cameraLook = camera and getFlatVector(camera.CFrame.LookVector)
	if not cameraLook or not rootPart then
		return
	end

	local currentLook = getFlatVector(rootPart.CFrame.LookVector) or cameraLook
	local alpha = 1 - math.exp(-TURN_RESPONSIVENESS * dt)
	local smoothedLook = currentLook:Lerp(cameraLook, alpha)
	if smoothedLook.Magnitude > 0.001 then
		rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + smoothedLook.Unit, Vector3.yAxis)
	end
end

local function updateCamera(dt, raw, moveState)
	local camera = Workspace.CurrentCamera
	if not camera or not humanoid then
		return
	end

	local responsiveness = SLINGSHOT_CAMERA.Responsiveness or 14
	local alpha = 1 - math.exp(-responsiveness * dt)
	local moving = rawHasMovement(raw)
	local running = moveState == "Run"

	local baseOffset = isAiming and SLINGSHOT_CAMERA.AimOffset or SLINGSHOT_CAMERA.BattleOffset
	local bob = Vector3.zero
	if SLINGSHOT_CAMERA.BobEnabled and moving and not activeAction then
		local bobSpeed = running and SLINGSHOT_CAMERA.BobRunSpeed or SLINGSHOT_CAMERA.BobWalkSpeed
		local bobY = running and SLINGSHOT_CAMERA.RunBobY or SLINGSHOT_CAMERA.WalkBobY
		local bobX = running and SLINGSHOT_CAMERA.RunBobX or SLINGSHOT_CAMERA.WalkBobX
		bobTime += dt * bobSpeed
		bob = Vector3.new(math.cos(bobTime) * bobX, math.abs(math.sin(bobTime)) * bobY, 0)
	else
		bobTime = bobTime + dt * 3
	end

	local moveSway = Vector3.zero
	if SLINGSHOT_CAMERA.SwayEnabled then
		local mouseDelta = UserInputService:GetMouseDelta()
		mouseSway = mouseSway + (-mouseDelta.X * SLINGSHOT_CAMERA.SwayFromMouse * 0.01)
		mouseSway = mouseSway * math.exp(-8 * dt)
		moveSway = Vector3.new(raw.side * SLINGSHOT_CAMERA.SwayFromMove, 0, 0)
	end

	local targetOffset = baseOffset + bob + moveSway
	smoothedCameraOffset = smoothedCameraOffset:Lerp(targetOffset, alpha)
	humanoid.CameraOffset = smoothedCameraOffset

	local targetFov = isAiming and SLINGSHOT_CAMERA.AimFOV or SLINGSHOT_CAMERA.BattleFOV
	camera.FieldOfView = camera.FieldOfView + (targetFov - camera.FieldOfView) * alpha

	local targetRoll = 0
	if activeAction and activeAction.Kind == "Slide" and not DEBUG_DISABLE_ROLL_CAMERA then
		targetRoll = SLINGSHOT_CAMERA.SlideTilt * 0.6
	elseif activeAction and activeAction.Kind == "Roll" and not DEBUG_DISABLE_ROLL_CAMERA then
		targetRoll = raw.side * SLINGSHOT_CAMERA.RollTiltRun
	elseif isAiming then
		targetRoll = -raw.side * SLINGSHOT_CAMERA.AimRollTilt
	elseif running then
		targetRoll = -raw.side * SLINGSHOT_CAMERA.RollTiltRun
	elseif moving then
		targetRoll = -raw.side * SLINGSHOT_CAMERA.RollTiltWalk
	end

	targetRoll += mouseSway
	cameraRoll = cameraRoll + (targetRoll - cameraRoll) * alpha
	if DEBUG_DISABLE_CAMERA_KICK then
		cameraPitchKick = 0
	else
		cameraPitchKick = cameraPitchKick * math.exp(-10 * dt)
	end

	camera.CFrame = camera.CFrame * CFrame.Angles(cameraPitchKick, 0, math.rad(cameraRoll))
end

local function updateLocomotion(raw, moveState)
	if activeAction then
		return
	end

	if LOCOMOTION_STATES[moveState] then
		playLocomotion(moveState)
	elseif moveState == "Falling" then
		stopLocomotion()
		playAction("Falling")
	end
end

local function renderUpdate(dt)
	if not active then
		return
	end

	if not resolveCharacter() then
		cleanupMode("CharacterInvalid")
		return
	end

	if player:GetAttribute("CarryingChicken") == true then
		cleanupMode("CarryingChicken")
		return
	end

	local raw = GetRawMoveInput()
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	humanoid.AutoRotate = false
	suppressDefaultToolPose()
	updateMovementSpeed(raw)
	updateRootFacing(dt)
	updateBodyLean(dt, raw)
	updateActionMotion(dt)

	local moveState = chooseLocomotionState(raw)
	setDebugAttributes(true, isBattleMode, isAiming, moveState)
	updateLocomotion(raw, moveState)
	if DEBUG_TOOL_TEST and moveState == "Run" and not debugPrintedRunAnimations then
		debugPrintedRunAnimations = true
		printActiveAnimationTracks("Run")
		printArmTestRunTracks()
		suppressDefaultToolPose(true)
	end
	updateCamera(dt, raw, moveState)
end

local function canActivate()
	if player:GetAttribute("CarryingChicken") == true then
		warn("[SlingshotController] Honda mode blocked while carrying chicken.")
		cleanupMode("BlockedByCarryChicken")
		resetDebugAttributes()
		forceLocalUnequipTools()
		return false
	end

	if player:GetAttribute("HomesteadStorageOpen") == true then
		cleanupMode("BlockedByStorageOpen")
		resetDebugAttributes()
		forceLocalUnequipTools()
		return false
	end

	if not resolveCharacter() then
		warn("[SlingshotController] Honda mode blocked because character is not ready or is dead.")
		return false
	end

	return true
end

local function bindRender()
	if renderBound then
		RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
	end

	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, renderUpdate)
	renderBound = true
end

local function activate(tool)
	if activeTool == tool and active then
		return
	end

	cleanupMode(nil)

	if not canActivate() then
		resetDebugAttributes()
		return
	end

	local camera = Workspace.CurrentCamera
	previousState = {
		AutoRotate = humanoid.AutoRotate,
		WalkSpeed = humanoid.WalkSpeed,
		CameraOffset = humanoid.CameraOffset,
		FieldOfView = camera and camera.FieldOfView or SLINGSHOT_CAMERA.BattleFOV,
		MouseBehavior = UserInputService.MouseBehavior,
		MouseIconEnabled = UserInputService.MouseIconEnabled,
	}

	active = true
	activeTool = tool
	isBattleMode = true
	isAiming = false
	isRolling = false
	isSliding = false
	isJumping = false
	isFalling = false
	isLanding = false
	activeAction = nil
	nextRollAt = 0
	nextSlideAt = 0
	debugPrintedRunAnimations = false
	armTestPrintedRunTracks = false
	clearAction()
	resetCameraState()

	humanoid.AutoRotate = false
	humanoid.WalkSpeed = BATTLE_WALK_SPEED
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

	if not DEBUG_DISABLE_BODY_LEAN then
		captureJoints()
	end
	loadAnimations()
	setToolHandleVisual(tool, true)
	suppressDefaultToolPose(true)
	setDebugAttributes(true, true, false, "BattleIdle")
	playLocomotion("BattleIdle")
	task.delay(0.15, function()
		if active and activeTool == tool then
			printToolDiagnostics(tool)
			applyArmTestMode(tool)
			printActiveAnimationTracks("Equip")
			suppressDefaultToolPose(true)
		end
	end)

	stateConn = humanoid.StateChanged:Connect(function(_, newState)
		if not active then
			return
		end

		if newState == Enum.HumanoidStateType.Jumping then
			isJumping = true
			isFalling = false
			isLanding = false
			stopLocomotion()
			setDebugAttributes(true, isBattleMode, isAiming, "Jump")
			setTemporaryAction("Jump", 0.25)
			playAction("Jump")
		elseif newState == Enum.HumanoidStateType.Freefall then
			isJumping = false
			isFalling = true
			isLanding = false
			stopLocomotion()
			setDebugAttributes(true, isBattleMode, isAiming, "Falling")
			writeAction("Falling")
			playAction("Falling")
		elseif isFalling and (newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Running or newState == Enum.HumanoidStateType.RunningNoPhysics) then
			isJumping = false
			isFalling = false
			isLanding = true
			stopActionTrack("Falling")
			setDebugAttributes(true, isBattleMode, isAiming, "Landing")
			setTemporaryAction("Landing", 0.35)
			if not DEBUG_DISABLE_CAMERA_KICK then
				cameraPitchKick += SLINGSHOT_CAMERA.LandingKick
			end
			playAction("Landing")
			task.delay(0.35, function()
				if active then
					isLanding = false
				end
			end)
		elseif newState == Enum.HumanoidStateType.Dead then
			cleanupMode("HumanoidDead")
		end
	end)

	diedConn = humanoid.Died:Connect(function()
		cleanupMode("HumanoidDied")
	end)

	bindRender()
	
	getOrCreateUI()
	updateAmmoUI()
	if ammoUI then
		ammoUI.Enabled = true
	end

	if DEBUG_TOOL_TEST then
		print("[SlingshotController] BattleMode activated with", tool.Name)
	end
end

local function startRoll()
	if not active or not isBattleMode or isAiming or activeAction then
		return
	end
	if player:GetAttribute("CarryingChicken") == true or not resolveCharacter() then
		return
	end

	local now = os.clock()
	if now < nextRollAt then
		return
	end

	local raw = GetRawMoveInput()
	local actionName = getRollActionName(raw)
	local direction = getRollDirection(raw)
	nextRollAt = now + ROLL_COOLDOWN
	startAction("Roll", actionName, direction, ROLL_DURATION, ROLL_DISTANCE)
end

local function startSlide()
	if not active or not isBattleMode or isAiming or activeAction then
		return
	end
	if player:GetAttribute("CarryingChicken") == true or not resolveCharacter() then
		return
	end

	local raw = GetRawMoveInput()
	if getBattleMoveState(raw) ~= "Run" then
		return
	end

	local now = os.clock()
	if now < nextSlideAt then
		return
	end

	local forward = getCameraBasis()
	nextSlideAt = now + SLIDE_COOLDOWN
	startAction("Slide", "Slide", forward, SLIDE_DURATION, SLIDE_DISTANCE)
end

local function setAmmoAttribute(count)
	count = math.max(math.floor(tonumber(count) or 0), 0)
	player:SetAttribute("SlingshotEggAmmo", count)
	updateAmmoUI()
end

local function getFireOriginDirection()
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil, nil
	end

	return camera.CFrame.Position, camera.CFrame.LookVector
end

local function canRequestFire()
	if not active or not isBattleMode or activeAction then
		return false
	end

	if player:GetAttribute("CarryingChicken") == true or player:GetAttribute("HomesteadStorageOpen") == true then
		return false
	end

	if not resolveCharacter() or not humanoid or humanoid.Health <= 0 then
		return false
	end

	local raw = GetRawMoveInput()
	if raw.Shift and raw.W then
		showFeedback("No puedes disparar corriendo")
		return false
	end

	return true
end

local function beginAimCharge()
	if not canRequestFire() then
		return
	end

	isAiming = true
	chargeStart = os.clock()
	setDebugAttributes(true, isBattleMode, true, chooseLocomotionState(GetRawMoveInput()))
	playLocomotion(chooseLocomotionState(GetRawMoveInput()))
end

local function finishAimCharge()
	local startedAt = chargeStart
	chargeStart = nil

	if isAiming then
		isAiming = false
		setDebugAttributes(true, isBattleMode, false, chooseLocomotionState(GetRawMoveInput()))
		playLocomotion(chooseLocomotionState(GetRawMoveInput()))
	end

	if not startedAt or not canRequestFire() then
		return
	end

	local charge = math.clamp((os.clock() - startedAt) / SLINGSHOT_FIRE.MaxChargeTime, 0, 1)
	if charge < SLINGSHOT_FIRE.MinChargeToFire then
		return
	end

	local ammoAttr = player:GetAttribute("SlingshotEggAmmo") or 0
	if ammoAttr <= 0 then
		showFeedback("No tienes huevos")
		return
	end

	local origin, direction = getFireOriginDirection()
	if origin and direction then
		fireRequestEvent:FireServer(origin, direction, charge)
	end
end

function playProjectileVisual(result)
	if typeof(result) ~= "table" or result.Ok ~= true then
		return
	end

	local origin = result.Origin
	local hitPosition = result.HitPosition
	if typeof(origin) ~= "Vector3" or typeof(hitPosition) ~= "Vector3" then
		return
	end

	local visualOrigin = origin
	if character then
		local rightGrip = findRightGrip()
		if rightGrip and rightGrip.Part1 then
			visualOrigin = rightGrip.Part1.Position
		elseif character:FindFirstChild("RightHand") then
			visualOrigin = character.RightHand.Position
		elseif activeTool and activeTool:FindFirstChild("Handle") then
			visualOrigin = activeTool.Handle.Position
		end
	end

	-- Constantes de trayectoria parabÃ³lica (tipo catapulta)
	local VISUAL_SPEED = 55 -- velocidad lenta, arco alto
	local GRAVITY_SCALE = 2.0 -- gravedad exagerada
	local MIN_DURATION = 0.18
	local MAX_DURATION = 1.4

	local projectile = Instance.new("Part")
	projectile.Name = "SlingshotEggProjectile"
	projectile.Shape = Enum.PartType.Ball
	projectile.Size = Vector3.new(0.34, 0.34, 0.34)
	projectile.Material = Enum.Material.SmoothPlastic
	projectile.Color = Color3.fromRGB(255, 246, 218)
	projectile.Anchored = true
	projectile.CanCollide = false
	projectile.CanTouch = false
	projectile.CanQuery = false
	projectile.CFrame = CFrame.new(visualOrigin)
	projectile.Parent = Workspace

	local distance = (hitPosition - visualOrigin).Magnitude
	local duration = math.clamp(distance / VISUAL_SPEED, MIN_DURATION, MAX_DURATION)
	
	local g = Vector3.new(0, -Workspace.Gravity * GRAVITY_SCALE, 0)
	local v0 = (hitPosition - visualOrigin) / duration - 0.5 * g * duration
	
	local rotSpeed = Vector3.new(
		math.random(-12, 12),
		math.random(-12, 12),
		math.random(-12, 12)
	)

	local startTime = os.clock()
	local connection
	local finished = false

	local function finish()
		if finished then return end
		finished = true
		if connection then
			connection:Disconnect()
			connection = nil
		end
		if projectile then
			projectile:Destroy()
		end
	end

	connection = RunService.Heartbeat:Connect(function()
		if not projectile or not projectile.Parent then
			finish()
			return
		end

		local t = os.clock() - startTime
		if t >= duration then
			finish()
		else
			local currentPos = visualOrigin + v0 * t + 0.5 * g * t * t
			projectile.CFrame = CFrame.new(currentPos) * CFrame.Angles(rotSpeed.X * t, rotSpeed.Y * t, rotSpeed.Z * t)
		end
	end)

	Debris:AddItem(projectile, duration + 0.2)
end

local function isSlingshotTool(inst)
	return inst and inst:IsA("Tool") and TOOL_NAMES[inst.Name] == true
end

local function wireTool(tool)
	if not isSlingshotTool(tool) or wiredTools[tool] then
		return
	end

	wiredTools[tool] = true

	tool.Equipped:Connect(function()
		activate(tool)
	end)

	tool.Unequipped:Connect(function()
		if activeTool == tool then
			cleanupMode("ToolUnequipped")
		end
	end)

	tool.AncestryChanged:Connect(function(_, parent)
		if not parent and activeTool == tool then
			cleanupMode("ToolRemoved")
		end
	end)
end

local function scanTools(container)
	if not container then
		return
	end

	for _, child in ipairs(container:GetChildren()) do
		wireTool(child)
	end
end

local function connectCharacter(newCharacter)
	stopRunOnlyArmTest()
	cleanupMode("CharacterAdded")
	character = newCharacter
	resetDebugAttributes()
	scanTools(character)

	character.ChildAdded:Connect(function(child)
		wireTool(child)
	end)
end

local backpack = player:WaitForChild("Backpack")
backpack.ChildAdded:Connect(function(child)
	wireTool(child)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode ~= Enum.KeyCode.Unknown then
		keysDown[input.KeyCode] = true
	end

	if input.KeyCode == Enum.KeyCode.F8 then
		startRunOnlyArmTest()
		return
	end

	if gameProcessed or not active then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
		beginAimCharge()
		return
	end

	if input.KeyCode == Enum.KeyCode.Q then
		startRoll()
		return
	end

	if input.KeyCode == Enum.KeyCode.LeftControl then
		startSlide()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode ~= Enum.KeyCode.Unknown then
		keysDown[input.KeyCode] = nil
	end

	if not active then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
		finishAimCharge()
	end
end)

fireResultEvent.OnClientEvent:Connect(function(result)
	if typeof(result) ~= "table" then
		return
	end

	if result.Ammo ~= nil then
		setAmmoAttribute(result.Ammo)
	end

	if result.Ok == true then
		playProjectileVisual(result)
	else
		if result.Reason == "NoAmmo" then
			showFeedback("No tienes huevos")
		elseif result.Reason == "Sprinting" then
			showFeedback("No puedes disparar corriendo")
		end
	end
end)

ammoChangedEvent.OnClientEvent:Connect(function(itemId, count)
	if itemId == "Egg" then
		setAmmoAttribute(count)
	end
end)

player:GetAttributeChangedSignal("SlingshotEggAmmo"):Connect(function()
	updateAmmoUI()
end)

player:GetAttributeChangedSignal("CarryingChicken"):Connect(function()
	if player:GetAttribute("CarryingChicken") == true then
		cleanupMode("CarryingChicken")
		resetDebugAttributes()
		forceLocalUnequipTools()
	end
end)

player:GetAttributeChangedSignal("HomesteadStorageOpen"):Connect(function()
	if player:GetAttribute("HomesteadStorageOpen") == true then
		cleanupMode("StorageOpen")
		resetDebugAttributes()
		forceLocalUnequipTools()
	end
end)

player.CharacterRemoving:Connect(function()
	stopRunOnlyArmTest()
	cleanupMode("CharacterRemoving")
end)

player.CharacterAdded:Connect(connectCharacter)

if player.Character then
	connectCharacter(player.Character)
else
	resetDebugAttributes()
end

scanTools(backpack)
if DEBUG_TOOL_TEST then
	print("[SlingshotController] Ready. Equip Honda/Slingshot for BattleMode. Hold left click for AimMode.")
end
