local DragonRaidService = {}

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- Constantes configurables
local CONFIG = {
	SHOW_CARRY_POINT_DEBUG = true,
	DRAGON_YAW_OFFSET_DEGREES = -90, -- Ajustable
	CARRY_OFFSET_LOCAL = Vector3.new(0, -8, -5), -- Ajustable para que caiga en patas
	CIRCLE_RADIUS = 80,
	CIRCLE_HEIGHT = 90,
	CIRCLE_DURATION = 7.0,
	DIVE_DURATION = 2.5,
	ASCEND_DURATION = 4.0,
	LOWER_DURATION = 2.0,
	FLEE_DURATION = 4.0,
	TURN_SMOOTHNESS = 6.0,
}

local isRaidActive = false
local raidConnection = nil
local dragonClone = nil
local capturedSheep = nil
local originalSheepStates = {}

local function cleanupRaid()
	if raidConnection then
		raidConnection:Disconnect()
		raidConnection = nil
	end
	if capturedSheep then
		DragonRaidService:CleanupCapturedSheepAsStolen()
	end
	if dragonClone then
		dragonClone:Destroy()
		dragonClone = nil
	end
	isRaidActive = false
	
	local raidFolder = Workspace:FindFirstChild("DragonRaidRuntime")
	if raidFolder and #raidFolder:GetChildren() == 0 then
		raidFolder:Destroy()
	end
end

local function getBezierPoint(t, p0, p1, p2)
	local u = 1 - t
	return (u * u * p0) + (2 * u * t * p1) + (t * t * p2)
end

function DragonRaidService:CleanupCapturedSheepAsStolen()
	if not capturedSheep then return end
	
	local sheep = capturedSheep
	capturedSheep = nil
	
	-- No reactivamos la fÃ­sica ni le quitamos el atributo. Simplemente la robamos (destruimos su modelo visual).
	if sheep and sheep.Parent then
		sheep:Destroy()
	end
	
	originalSheepStates = {}
end

function DragonRaidService:PrepareTestSceneForFirstPlayer()
	local player = game.Players:GetPlayers()[1]
	if not player then return false end

	local houseModule = require(game.ServerScriptService.Pasture.M.House)
	local sheepRuntime = Workspace:FindFirstChild("SheepRuntime") or Workspace:FindFirstChild("PastureRuntime")
	
	-- Reclamar la primera casa disponible si no hay ovejas
	if not sheepRuntime or #sheepRuntime:GetChildren() < 10 then
		local housesFolder = Workspace:FindFirstChild("Houses")
		if housesFolder then
			for _, house in ipairs(housesFolder:GetChildren()) do
				if house:GetAttribute("OwnerId") == nil or house:GetAttribute("OwnerId") == 0 then
					houseModule:Claim(player, house)
					print("[DragonRaidService] Se reclamÃ³ la casa " .. house.Name .. " para testear.")
					break
				end
			end
		end
	end

	-- Esperar instanciaciÃ³n de ovejas
	local flockWait = 0
	while flockWait < 50 do
		local sr = Workspace:FindFirstChild("SheepRuntime") or Workspace:FindFirstChild("PastureRuntime")
		if sr and #sr:GetChildren() >= 10 then
			print("[DragonRaidService] Ovejas detectadas:", #sr:GetChildren())
			return true
		end
		task.wait(0.1)
		flockWait = flockWait + 1
	end
	return false
end

function DragonRaidService:FindValidSheepTarget()
	local sheepRuntime = Workspace:FindFirstChild("SheepRuntime") or Workspace:FindFirstChild("PastureRuntime")
	if not sheepRuntime then
		print("[DragonRaidService] No se encontrÃ³ carpeta SheepRuntime o PastureRuntime.")
		return nil
	end

	local validSheepList = {}
	local rejectedList = {}
	
	for _, child in ipairs(sheepRuntime:GetDescendants()) do
		if child:IsA("Model") then
			local root = child.PrimaryPart or child:FindFirstChild("HumanoidRootPart")
			if not root then
				table.insert(rejectedList, child.Name .. " (Sin root)")
			elseif string.match(child.Name, "Template") then
				table.insert(rejectedList, child.Name .. " (Es template)")
			elseif child:GetAttribute("CapturedByDragon") == true then
				table.insert(rejectedList, child.Name .. " (Ya capturada)")
			elseif child:GetAttribute("Dead") == true then
				table.insert(rejectedList, child.Name .. " (Muerta)")
			elseif not string.match(child.Name, "Sheep") and not string.match(child.Name, "Oveja") then
				table.insert(validSheepList, child)
			else
				table.insert(validSheepList, child)
			end
		end
	end

	if #validSheepList > 0 then
		local bestList = {}
		for _, s in ipairs(validSheepList) do
			if not string.match(s.Name, "Leader") then
				table.insert(bestList, s)
			end
		end
		if #bestList > 0 then
			return bestList[math.random(1, #bestList)]
		else
			return validSheepList[math.random(1, #validSheepList)]
		end
	end
	
	print("[DragonRaidService] No se encontraron ovejas. Rechazadas:", #rejectedList)
	for i, r in ipairs(rejectedList) do print("  - " .. r) end
	return nil
end

function DragonRaidService:GrabSheep(sheep)
	if not dragonClone or not sheep then return end
	capturedSheep = sheep
	sheep:SetAttribute("CapturedByDragon", true)

	local root = sheep:FindFirstChild("HumanoidRootPart") or sheep.PrimaryPart
	local carryPoint = dragonClone:FindFirstChild("DragonCarryPoint") or dragonClone:FindFirstChild("DragonCarryAttachment")
	
	if root and carryPoint then
		for _, desc in ipairs(sheep:GetDescendants()) do
			if desc:IsA("LinearVelocity") or desc:IsA("AlignOrientation") or desc:IsA("AlignPosition") or desc:IsA("VectorForce") then
				originalSheepStates[desc] = { Enabled = desc.Enabled }
				desc.Enabled = false
			elseif desc:IsA("BasePart") then
				if desc.Anchored then
					originalSheepStates[desc] = { Anchored = true }
					desc.Anchored = false
				end
				pcall(function() desc:SetNetworkOwner(nil) end)
			end
		end
		
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		
		-- Snap y Weld temporal
		-- Mantener oveja derecha usando CFrame local o simplemente lookAt plano
		local horizontalDir = carryPoint.CFrame.LookVector * Vector3.new(1, 0, 1)
		if horizontalDir.Magnitude < 0.001 then horizontalDir = Vector3.new(0, 0, -1) end
		
		root.CFrame = CFrame.lookAt(carryPoint.Position, carryPoint.Position + horizontalDir.Unit)
		
		local tempWeld = Instance.new("WeldConstraint")
		tempWeld.Name = "DragonGrabWeld"
		tempWeld.Part0 = carryPoint
		tempWeld.Part1 = root
		tempWeld.Parent = root
	end
end

function DragonRaidService:ReleaseSheep()
	if not capturedSheep then return end
	
	local sheep = capturedSheep
	capturedSheep = nil
	
	local root = sheep:FindFirstChild("HumanoidRootPart") or sheep.PrimaryPart
	if root then
		local weld = root:FindFirstChild("DragonGrabWeld")
		if weld then weld:Destroy() end
		
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	
	for obj, state in pairs(originalSheepStates) do
		if typeof(obj) == "Instance" then
			if obj:IsA("BasePart") and state.Anchored ~= nil then
				obj.Anchored = state.Anchored
			elseif (obj:IsA("LinearVelocity") or obj:IsA("AlignOrientation") or obj:IsA("AlignPosition") or obj:IsA("VectorForce")) and state.Enabled ~= nil then
				obj.Enabled = state.Enabled
			end
		end
	end
	originalSheepStates = {}
	
	sheep:SetAttribute("CapturedByDragon", false)
end

function DragonRaidService:StartDragonRaid()
	if isRaidActive then return end
	isRaidActive = true
	
	local raidFolder = Workspace:FindFirstChild("DragonRaidRuntime")
	if not raidFolder then
		raidFolder = Instance.new("Folder")
		raidFolder.Name = "DragonRaidRuntime"
		raidFolder.Parent = Workspace
	end

	local targetSheep = self:FindValidSheepTarget()
	if not targetSheep then
		warn("[DragonRaidService] No hay ovejas vÃ¡lidas. Abortando.")
		cleanupRaid()
		return
	end
	local sheepTargetPos = targetSheep.PrimaryPart and targetSheep.PrimaryPart.Position or targetSheep:FindFirstChild("HumanoidRootPart").Position

	local sourceDragon = Workspace:FindFirstChild("DragonModel") or game:GetService("ServerStorage"):FindFirstChild("DragonModel", true)
	if not sourceDragon then
		warn("[DragonRaidService] DragonModel no encontrado.")
		cleanupRaid()
		return
	end

	dragonClone = sourceDragon:Clone()
	dragonClone.Parent = raidFolder
	local rootPart = dragonClone.PrimaryPart or dragonClone:FindFirstChild("HumanoidRootPart")
	if not dragonClone.PrimaryPart then dragonClone.PrimaryPart = rootPart end

	for _, desc in ipairs(dragonClone:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Anchored = true
			desc.CanCollide = false
		end
	end

	local carryPoint = dragonClone:FindFirstChild("DragonCarryPoint") or dragonClone:FindFirstChild("DragonCarryAttachment")
	if not carryPoint then
		carryPoint = Instance.new("Part")
		carryPoint.Name = "DragonCarryPoint"
		carryPoint.Size = Vector3.new(0.4, 0.4, 0.4)
		carryPoint.CanCollide = false
		carryPoint.Anchored = false
		carryPoint.Massless = true
		carryPoint.CFrame = rootPart.CFrame * CFrame.new(CONFIG.CARRY_OFFSET_LOCAL)
		carryPoint.Parent = dragonClone

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = rootPart
		weld.Part1 = carryPoint
		weld.Parent = carryPoint

		local dragAtt = Instance.new("Attachment")
		dragAtt.Name = "GrabAttachment"
		dragAtt.Parent = carryPoint
	end
	
	if carryPoint:IsA("BasePart") then
		carryPoint.Transparency = CONFIG.SHOW_CARRY_POINT_DEBUG and 0.5 or 1
	end

	local spawnOffset = Vector3.new(400, 200, 0)
	local startPos = sheepTargetPos + spawnOffset
	local initialDirection = (sheepTargetPos - startPos).Unit
	local startRot = CFrame.lookAt(Vector3.zero, initialDirection) * CFrame.Angles(0, math.rad(CONFIG.DRAGON_YAW_OFFSET_DEGREES), 0)
	dragonClone:PivotTo(CFrame.new(startPos) * startRot)

	local startTime = os.clock()

	local T_APPROACH = 4.0
	local T_CIRCLE = CONFIG.CIRCLE_DURATION
	local T_COMMIT = 1.0
	local T_DIVE = CONFIG.DIVE_DURATION
	local T_ASCEND = CONFIG.ASCEND_DURATION
	local T_LOWER = CONFIG.LOWER_DURATION
	local T_FLEE = CONFIG.FLEE_DURATION
	
	local timeApproach = T_APPROACH
	local timeCircle = timeApproach + T_CIRCLE
	local timeCommit = timeCircle + T_COMMIT
	local timeDive = timeCommit + T_DIVE
	local timeAscend = timeDive + T_ASCEND
	local timeLower = timeAscend + T_LOWER
	local timeFlee = timeLower + T_FLEE

	local circleRadius = CONFIG.CIRCLE_RADIUS
	local circleHeight = CONFIG.CIRCLE_HEIGHT
	
	local grabbed = false
	local released = false
	
	local p_circleExit = Vector3.zero
	local p_diveControl = Vector3.zero
	local p_diveTarget = Vector3.zero
	local p_diveEnd = Vector3.zero
	local p_ascendControl = Vector3.zero
	local p_ascendEnd = Vector3.zero
	local p_dropStart = Vector3.zero

	local currentRotation = startRot
	local lastPos = startPos
	
	raidConnection = RunService.Heartbeat:Connect(function(dt)
		local t = os.clock() - startTime
		
		if targetSheep and not targetSheep.Parent then
			targetSheep = nil
			if not released then
				self:ReleaseSheep()
				released = true
			end
		end

		if targetSheep and targetSheep.PrimaryPart then
			sheepTargetPos = targetSheep.PrimaryPart.Position
		end
		local circleCenter = sheepTargetPos + Vector3.new(0, circleHeight, 0)
		local targetPos = lastPos

		if t < timeApproach then
			local alpha = t / T_APPROACH
			local angle = 0
			local circleEntryPos = circleCenter + Vector3.new(math.cos(angle) * circleRadius, 0, math.sin(angle) * circleRadius)
			targetPos = startPos:Lerp(circleEntryPos, alpha)
			
		elseif t < timeCircle then
			local localT = t - timeApproach
			local alpha = localT / T_CIRCLE
			local angle = alpha * math.pi * 4
			targetPos = circleCenter + Vector3.new(math.cos(angle) * circleRadius, 0, math.sin(angle) * circleRadius)
			p_circleExit = targetPos
			p_diveControl = p_circleExit + Vector3.new(0, 50, -50)
			
		elseif t < timeCommit then
			local localT = t - timeCircle
			local alpha = localT / T_COMMIT
			local easeAlpha = alpha * alpha
			local diveStartTarget = p_circleExit:Lerp(p_circleExit + Vector3.new(0, 20, 0), easeAlpha)
			targetPos = diveStartTarget
			
			p_diveTarget = sheepTargetPos + Vector3.new(0, 4, 0)
			p_diveControl = targetPos + (targetPos - circleCenter).Unit * 50 + Vector3.new(0, 30, 0)
			p_diveEnd = targetPos
			
		elseif t < timeDive then
			local localT = t - timeCommit
			local alpha = math.clamp(localT / T_DIVE, 0, 1)
			local easeAlpha = 1 - (1 - alpha) * (1 - alpha) 
			
			targetPos = getBezierPoint(easeAlpha, p_diveEnd, p_diveControl, p_diveTarget)
			p_ascendControl = targetPos + (targetPos - p_diveControl).Unit * 50 + Vector3.new(0, 40, 0)

		elseif t < timeAscend then
			if not grabbed and targetSheep then
				grabbed = true
				self:GrabSheep(targetSheep)
			end
			local localT = t - timeDive
			local alpha = math.clamp(localT / T_ASCEND, 0, 1)
			local easeAlpha = math.sin(alpha * math.pi / 2)
			
			p_ascendEnd = sheepTargetPos + Vector3.new(200, 150, 200)
			targetPos = getBezierPoint(easeAlpha, p_diveTarget, p_ascendControl, p_ascendEnd)
			p_dropStart = targetPos

		elseif t < timeLower then
			local localT = t - timeAscend
			local alpha = math.clamp(localT / T_LOWER, 0, 1)
			
			local rayOrigin = p_dropStart
			local params = RaycastParams.new()
			params.FilterDescendantsInstances = {dragonClone, targetSheep}
			params.FilterType = Enum.RaycastFilterType.Exclude
			local hit = Workspace:Raycast(rayOrigin, Vector3.new(0, -200, 0), params)
			
			local dropPos = hit and (hit.Position + Vector3.new(0, 10, 0)) or (p_dropStart - Vector3.new(0, 40, 0))
			targetPos = p_dropStart:Lerp(dropPos, alpha)

		elseif t < timeFlee then
			local localT = t - timeLower
			local alpha = localT / T_FLEE
			local fleeTarget = targetPos + Vector3.new(0, 100, -300)
			targetPos = targetPos:Lerp(fleeTarget, alpha)
		else
			cleanupRaid()
			return
		end

		local diff = targetPos - lastPos
		if diff.Magnitude > 0.1 then
			local direction = diff.Unit
			local rawRot = CFrame.lookAt(Vector3.zero, direction)
			local desiredRot = rawRot * CFrame.Angles(0, math.rad(CONFIG.DRAGON_YAW_OFFSET_DEGREES), 0)
			
			currentRotation = currentRotation:Lerp(desiredRot, math.min(dt * CONFIG.TURN_SMOOTHNESS, 1))
		end

		dragonClone:PivotTo(CFrame.new(targetPos) * currentRotation)
		lastPos = targetPos
	end)
end

function DragonRaidService:EndRaid()
	cleanupRaid()
end

return DragonRaidService