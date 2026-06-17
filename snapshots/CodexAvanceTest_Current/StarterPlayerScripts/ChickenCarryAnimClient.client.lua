-- ChickenCarryAnimClient v5
-- Reproduce la animacion de cargar gallina desde atributos replicados.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remoteFolder = ReplicatedStorage:WaitForChild("HomesteadRemote")
local ANIM_ATTRIBUTE = "CarryChickenAnimationId"

local currentTrack = nil
local currentAnimator = nil
local currentAnimationId = nil
local warnedMissingAnimation = false
local humanoidDiedConn = nil
local stopCarryAnim = nil

local function getAnimator()
	local character = player.Character
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	return animator
end

local function getCarryAnimationId()
	local animationId = remoteFolder:GetAttribute(ANIM_ATTRIBUTE)

	if typeof(animationId) == "string" and animationId:match("^rbxassetid://%d+$") then
		return animationId
	end

	return nil
end

local function isCarryingChicken()
	return player:GetAttribute("CarryingChicken") == true
end

local function playCarryAnim()
	local animationId = getCarryAnimationId()
	if not animationId then
		if not warnedMissingAnimation then
			warn("[ChickenCarryAnimClient] Falta atributo", ANIM_ATTRIBUTE, "en HomesteadRemote.")
			warnedMissingAnimation = true
		end
		if stopCarryAnim then
			stopCarryAnim()
		end
		return
	end

	local animator = getAnimator()
	if not animator then
		if stopCarryAnim then
			stopCarryAnim()
		end
		return
	end

	if currentTrack and currentTrack.IsPlaying and currentAnimator == animator and currentAnimationId == animationId then
		return
	end

	if currentTrack then
		pcall(function()
			currentTrack:Stop(0.15)
			currentTrack:Destroy()
		end)
		currentTrack = nil
		currentAnimationId = nil
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = animationId

	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)

	if not ok or not track then
		warn("[ChickenCarryAnimClient] No pude cargar animacion:", animationId)
		return
	end

	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	track:Play(0.15)

	currentTrack = track
	currentAnimator = animator
	currentAnimationId = animationId
end

function stopCarryAnim()
	if currentTrack then
		pcall(function()
			currentTrack:Stop(0.15)
			currentTrack:Destroy()
		end)

		currentTrack = nil
		currentAnimator = nil
		currentAnimationId = nil
	end
end

local function disconnectHumanoidDied()
	if humanoidDiedConn then
		humanoidDiedConn:Disconnect()
		humanoidDiedConn = nil
	end
end

local function bindHumanoidDeath(character)
	disconnectHumanoidDied()

	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoidDiedConn = humanoid.Died:Connect(function()
			stopCarryAnim()
		end)
	end
end

local function refresh()
	if isCarryingChicken() then
		playCarryAnim()
	else
		stopCarryAnim()
	end
end

player.CharacterAdded:Connect(function(character)
	stopCarryAnim()
	bindHumanoidDeath(character)
	task.wait(0.5)
	refresh()
end)

player.CharacterRemoving:Connect(function()
	stopCarryAnim()
	disconnectHumanoidDied()
end)

player:GetAttributeChangedSignal("CarryingChicken"):Connect(refresh)
remoteFolder:GetAttributeChangedSignal(ANIM_ATTRIBUTE):Connect(function()
	if isCarryingChicken() then
		refresh()
	end
end)

bindHumanoidDeath(player.Character)
refresh()

print("[ChickenCarryAnimClient] Listo. Animacion por atributo:", ANIM_ATTRIBUTE)
