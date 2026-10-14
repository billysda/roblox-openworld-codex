-- DragonJitterTrap.client.lua
-- Diagnostics script to capture jitter events and print detailed ring buffer logs.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local DRAGON_NAME = "DragonModel"

local buffer = {}
local maxFrames = 120
local insertIndex = 1

local stateChanges = {} -- list of { time = number, state = string }
local lastTimeMet = {
	rootYJump = 0,
	targetYJump = 0,
	pitchJump = 0,
	angularSpike = 0,
	ikSpike = 0,
	lostFeet = 0,
	stateChangedFast = 0
}

local lastTriggerTime = 0

local function getDragon()
	return Workspace:FindFirstChild(DRAGON_NAME)
end

local function getRoot(dragon)
	return dragon and dragon:FindFirstChild("HumanoidRootPart")
end

local function getOccupant(dragon)
	local seat = dragon:FindFirstChild("DragonRiderSea")
	if seat and seat:IsA("Seat") and seat.Occupant and seat.Occupant.Parent then
		return seat.Occupant.Parent.Name
	end
	local seat1 = dragon:FindFirstChild("DragonRiderSeat")
	if seat1 and seat1:IsA("Seat") and seat1.Occupant and seat1.Occupant.Parent then
		return seat1.Occupant.Parent.Name
	end
	return "none"
end

local function addToBuffer(frameData)
	buffer[insertIndex] = frameData
	insertIndex = insertIndex + 1
	if insertIndex > maxFrames then
		insertIndex = 1
	end
end

local function getLastNFrames(n)
	local result = {}
	local total = #buffer
	if total == 0 then return result end
	local count = math.min(n, total)
	
	for i = 1, count do
		local idx = insertIndex - count + i - 1
		while idx < 1 do
			idx = idx + total
		end
		while idx > total do
			idx = idx - total
		end
		table.insert(result, buffer[idx])
	end
	return result
end

local function dumpBuffer(isManual)
	if isManual then
		print("[DragonJitterTrap] MANUAL DUMP")
	else
		print("[DragonJitterTrap] TRIGGER AUTOMATIC")
	end
	
	local last30 = getLastNFrames(30)
	for idx, frame in ipairs(last30) do
		print(string.format("[DragonJitterTrap] t=%.3f state=%s rootY=%.2f targetY=%s pitch=%s drop=%s alignEnabled=%s linearEnabled=%s anchored=%s yawResetReason=%s yawResetTime=%s groundYaw=%s ikDelta=%s lostFeet=%s angVel=%s mouseYaw=%s mousePitch=%s occupant=%s pos=%s look=%s up=%s linVel=%s pivotY=%.2f parkedLocked=%s dt=%.4f",
			frame.time,
			tostring(frame.state),
			frame.pos.Y,
			frame.bodyTargetY and string.format("%.2f", frame.bodyTargetY) or "nil",
			frame.bodyPitchDeg and string.format("%.1f", frame.bodyPitchDeg) or "nil",
			tostring(frame.dropActive),
			tostring(frame.alignEnabled),
			tostring(frame.linearEnabled),
			tostring(frame.rootAnchored),
			tostring(frame.yawResetReason),
			frame.yawResetTime and string.format("%.2f", frame.yawResetTime) or "nil",
			frame.groundYawDeg and string.format("%.1f", frame.groundYawDeg) or "nil",
			frame.ikMaxDelta and string.format("%.2f", frame.ikMaxDelta) or "nil",
			tostring(frame.ikLostHits),
			string.format("%.2f", frame.angVel.Magnitude),
			frame.mouseAimYaw and string.format("%.1f", frame.mouseAimYaw) or "nil",
			frame.mouseAimPitch and string.format("%.1f", frame.mouseAimPitch) or "nil",
			tostring(frame.occupant),
			tostring(frame.pos),
			tostring(frame.look),
			tostring(frame.up),
			tostring(frame.linVel),
			frame.pivot.Position.Y,
			tostring(frame.ikParkedLocked),
			frame.dt
		))
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.J then
		dumpBuffer(true)
	end
end)

RunService.Heartbeat:Connect(function(dt)
	local ok, err = pcall(function()
		local dragon = getDragon()
		local root = getRoot(dragon)
		if not dragon or not root then return end
		
		local now = os.clock()
		local previousFrames = getLastNFrames(1)
		local previousFrame = previousFrames[1]
		
		local state = dragon:GetAttribute("DragonFlightState") or "none"
		
		-- Track state changes in the last 1.0 second
		if previousFrame and state ~= previousFrame.state then
			table.insert(stateChanges, { time = now, state = state })
		end
		
		-- Clean up old state changes
		while #stateChanges > 0 and now - stateChanges[1].time > 1.0 do
			table.remove(stateChanges, 1)
		end
		
		local frameData = {
			time = now,
			dt = dt,
			state = state,
			pos = root.Position,
			look = root.CFrame.LookVector,
			up = root.CFrame.UpVector,
			angVel = root.AssemblyAngularVelocity,
			linVel = root.AssemblyLinearVelocity,
			pivot = dragon:GetPivot(),
			occupant = getOccupant(dragon),
			
			-- debug attributes
			bodyTargetY = dragon:GetAttribute("DragonBodyTargetY"),
			bodyPitchDeg = dragon:GetAttribute("DragonBodyPitchDeg"),
			dropActive = dragon:GetAttribute("DragonDropActive"),
			mouseAimYaw = dragon:GetAttribute("DragonMouseAimYaw"),
			mouseAimPitch = dragon:GetAttribute("DragonMouseAimPitch"),
			ikMaxDelta = dragon:GetAttribute("DragonIKMaxDelta"),
			ikLostHits = dragon:GetAttribute("DragonIKLostHits"),
			ikParkedLocked = dragon:GetAttribute("DragonIKParkedLocked"),

			-- new attributes for LandingYawAuthorityReset_v1
			alignEnabled = dragon:GetAttribute("DragonAlignEnabled"),
			linearEnabled = dragon:GetAttribute("DragonLinearEnabled"),
			yawResetReason = dragon:GetAttribute("DragonYawResetReason"),
			yawResetTime = dragon:GetAttribute("DragonYawResetTime"),
			groundYawDeg = dragon:GetAttribute("DragonGroundYawDeg"),
			rootAnchored = root.Anchored,
			dragonRootAnchored = dragon:GetAttribute("DragonRootAnchored"),
		}
		
		addToBuffer(frameData)
		
		if previousFrame then
			local currentRootY = frameData.pos.Y
			local previousRootY = previousFrame.pos.Y
			local rootYJump = math.abs(currentRootY - previousRootY) > 0.35
			
			local currentTargetY = frameData.bodyTargetY or currentRootY
			local previousTargetY = previousFrame.bodyTargetY or previousRootY
			local targetYJump = math.abs(currentTargetY - previousTargetY) > 0.75
			
			local currentPitch = frameData.bodyPitchDeg or 0
			local previousPitch = previousFrame.bodyPitchDeg or 0
			local pitchJump = math.abs(currentPitch - previousPitch) > 6
			
			local angularSpike = frameData.angVel.Magnitude > 6
			local ikSpike = frameData.ikMaxDelta and frameData.ikMaxDelta > 3
			local lostFeet = frameData.ikLostHits and frameData.ikLostHits >= 2
			local stateChangedFast = #stateChanges >= 3
			
			-- Update condition met timestamps
			if rootYJump then lastTimeMet.rootYJump = now end
			if targetYJump then lastTimeMet.targetYJump = now end
			if pitchJump then lastTimeMet.pitchJump = now end
			if angularSpike then lastTimeMet.angularSpike = now end
			if ikSpike then lastTimeMet.ikSpike = now end
			if lostFeet then lastTimeMet.lostFeet = now end
			if stateChangedFast then lastTimeMet.stateChangedFast = now end
			
			-- Count how many conditions are met in a 0.25s window
			local activeCount = 0
			local reasons = {}
			for cond, lastTime in pairs(lastTimeMet) do
				if now - lastTime <= 0.25 then
					activeCount = activeCount + 1
					table.insert(reasons, cond)
				end
			end
			
			-- Trigger automatic dump if 2 or more conditions are met and we are not in cooldown
			if activeCount >= 2 and now - lastTriggerTime > 3.0 then
				lastTriggerTime = now
				print("[DragonJitterTrap] TRIGGER reason=" .. table.concat(reasons, ", "))
				dumpBuffer(false)
			end
		end
	end)
	if not ok then
		warn("[DragonJitterTrap][ERROR] " .. tostring(err))
	end
end)
