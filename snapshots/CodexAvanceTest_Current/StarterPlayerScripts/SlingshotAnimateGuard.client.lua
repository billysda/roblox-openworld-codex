-- SlingshotAnimateGuard
-- Evita que Character.Animate y las animaciones default de Roblox se mezclen con Honda BattleMode.
-- No toca Homestead/Pasture. Solo actua localmente cuando SlingshotBattleMode=true.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local DEBUG = false
local STOP_INTERVAL = 0.10

-- IDs propias de Honda. Se usan para NO detener tus animaciones.
-- Si luego agregas BattleIdle/AimWalk, coloca aqui sus IDs tambien.
local SLINGSHOT_ALLOWED_IDS = {
	["115221880901221"] = true, -- ForwardWalk
	["118947770582006"] = true, -- WalkBack
	["95882892791676"] = true,  -- LeftWalk
	["83682374587056"] = true,  -- RightWalk
	["75300022487459"] = true,  -- Run

	["119503398871932"] = true, -- Jump
	["117156129208587"] = true, -- Falling
	["78066032414207"] = true,  -- Landing

	["95523738131385"] = true,  -- Slide

	["122989211293201"] = true, -- ForwardRoll
	["96477627111389"] = true,  -- BackRoll
	["107353867818444"] = true, -- LeftRoll
	["113337713022215"] = true, -- RightRoll

	["117985293791796"] = true, -- AimIdle
	["84371476515785"] = true,  -- CarryChicken
}

local character = nil
local humanoid = nil
local animator = nil
local animateScript = nil
local savedAnimateDisabled = nil
local active = false
local accum = 0
local printedActive = false
local printedRestore = false
local stoppedOnce = {}

local function getDigits(animationId)
	if typeof(animationId) ~= "string" then
		return ""
	end
	return animationId:match("(%d+)$") or animationId:match("id=(%d+)") or ""
end

local function resolve()
	character = player.Character
	if not character then
		humanoid = nil
		animator = nil
		animateScript = nil
		return false
	end

	humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		animator = humanoid:FindFirstChildOfClass("Animator")
	else
		animator = nil
	end

	animateScript = character:FindFirstChild("Animate")
	return character ~= nil and humanoid ~= nil
end

local function isBattleMode()
	return player:GetAttribute("SlingshotBattleMode") == true
		and player:GetAttribute("CarryingChicken") ~= true
end

local function getTrackInfo(track)
	local name = tostring(track.Name or "")
	local animName = ""
	local animId = ""

	pcall(function()
		if track.Animation then
			animName = tostring(track.Animation.Name or "")
			animId = tostring(track.Animation.AnimationId or "")
		end
	end)

	return name, animName, animId, getDigits(animId)
end

local function isSlingshotTrack(track)
	local _, _, _, digits = getTrackInfo(track)
	return digits ~= "" and SLINGSHOT_ALLOWED_IDS[digits] == true
end

local function stopNonSlingshotTracks(reason)
	if not animator then
		return
	end

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if not isSlingshotTrack(track) then
			local trackName, animName, animId, digits = getTrackInfo(track)

			pcall(function()
				track:Stop(0.05)
			end)

			if DEBUG then
				local key = trackName .. "|" .. animId
				if not stoppedOnce[key] then
					stoppedOnce[key] = true
					print(string.format(
						"[SlingshotAnimateGuard] Stopped foreign/default track reason=%s track=%s anim=%s id=%s digits=%s priority=%s",
						tostring(reason),
						tostring(trackName),
						tostring(animName),
						tostring(animId),
						tostring(digits),
						tostring(track.Priority)
					))
				end
			end
		end
	end
end

local function activateGuard()
	if active then
		return
	end

	resolve()
	active = true
	printedRestore = false

	if animateScript then
		if savedAnimateDisabled == nil then
			savedAnimateDisabled = animateScript.Disabled
		end
		animateScript.Disabled = true
	end

	if DEBUG and not printedActive then
		printedActive = true
		print("[SlingshotAnimateGuard] Character.Animate disabled while Honda BattleMode is active.")
	end

	stopNonSlingshotTracks("activate")
end

local function deactivateGuard()
	if not active then
		return
	end

	active = false
	printedActive = false
	stoppedOnce = {}

	resolve()

	if animateScript and savedAnimateDisabled ~= nil then
		animateScript.Disabled = savedAnimateDisabled
	end

	savedAnimateDisabled = nil

	if DEBUG and not printedRestore then
		printedRestore = true
		print("[SlingshotAnimateGuard] Character.Animate restored after Honda BattleMode.")
	end
end

local function refreshState()
	if isBattleMode() then
		activateGuard()
	else
		deactivateGuard()
	end
end

player:GetAttributeChangedSignal("SlingshotBattleMode"):Connect(refreshState)
player:GetAttributeChangedSignal("SlingshotEquipped"):Connect(refreshState)
player:GetAttributeChangedSignal("CarryingChicken"):Connect(function()
	if player:GetAttribute("CarryingChicken") == true then
		deactivateGuard()
	else
		refreshState()
	end
end)

player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoid = nil
	animator = nil
	animateScript = nil
	savedAnimateDisabled = nil
	active = false
	accum = 0
	printedActive = false
	printedRestore = false
	stoppedOnce = {}

	task.defer(function()
		resolve()
		refreshState()
	end)
end)

player.CharacterRemoving:Connect(function()
	deactivateGuard()
	character = nil
	humanoid = nil
	animator = nil
	animateScript = nil
	savedAnimateDisabled = nil
end)

RunService.Heartbeat:Connect(function(dt)
	if not isBattleMode() then
		if active then
			deactivateGuard()
		end
		return
	end

	if not active then
		activateGuard()
	end

	accum += dt
	if accum >= STOP_INTERVAL then
		accum = 0
		resolve()

		if animateScript then
			animateScript.Disabled = true
		end

		stopNonSlingshotTracks("heartbeat")
	end
end)

task.defer(function()
	resolve()
	refreshState()
end)

if DEBUG then
	print("[SlingshotAnimateGuard] Ready. Stops default Animate tracks only during Honda BattleMode.")
end
