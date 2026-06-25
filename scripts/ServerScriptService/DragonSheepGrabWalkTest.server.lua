print("=== DragonSheepGrabWalkTest SCRIPT STARTED ===")

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[CleanCheck] Socket_Boca references: 0")
print("[CleanCheck] ThrowAnimBase references: 0")
print("[CleanCheck] SheepThrowTarget references: 0")
print("[CleanCheck] Using bite bone: tongue_bone03_0")
print("[CleanCheck] Using Bite Animation: rbxassetid://108627489079626")

local dragon = Workspace:WaitForChild("DragonModel", 10)
if not dragon then warn("[Init] DragonModel no encontrado"); return end

local sheep = Workspace:WaitForChild("SheepTemplateTest", 10)
if not sheep then warn("[Init] SheepTemplateTest no encontrado"); return end

local sheepRoot = sheep:WaitForChild("HumanoidRootPart", 5)
if not sheepRoot then warn("[Init] HumanoidRootPart de oveja no encontrado"); return end

local biteBone = dragon:FindFirstChild("tongue_bone03_0", true)
if not biteBone or not biteBone:IsA("Bone") then
    warn("[Init] tongue_bone03_0 no encontrado"); return 
end

local dragonController = dragon:FindFirstChildOfClass("AnimationController")
local animator = dragonController and dragonController:FindFirstChildOfClass("Animator")
if not animator and dragonController then
    animator = Instance.new("Animator")
    animator.Parent = dragonController
end

local MOVE_SPEED = 5
local PRE_BITE_DISTANCE = 5
local MAX_ATTACH_DISTANCE = 3
local DRAGON_FORWARD_YAW_OFFSET_DEGREES = 0
local EXTRA_HEIGHT_OFFSET = 0
local BITE_CARRY_OFFSET = CFrame.new(0, -0.8, 0)

local walkAnim = Instance.new("Animation"); walkAnim.AnimationId = "rbxassetid://81299004723585"
local biteAnim = Instance.new("Animation"); biteAnim.AnimationId = "rbxassetid://108627489079626"

local walkTrack = animator:LoadAnimation(walkAnim)
local biteTrack = animator:LoadAnimation(biteAnim)

local initialDragonPivot = dragon:GetPivot()
local initialSheepPivot = sheep:GetPivot()

local currentRunId = 0
local movementConnection = nil
local calibrateConnection = nil
local carryingConnection = nil
local attached = false
local isBitePhase = false
local savedSheepCC = sheepRoot.CanCollide

local function getBiteCFrame()
    if biteBone and biteBone:IsA("Bone") then
        return biteBone.TransformedWorldCFrame
    end
    return nil
end

local function disconnectAll()
    if carryingConnection then carryingConnection:Disconnect(); carryingConnection = nil end
    if movementConnection then movementConnection:Disconnect(); movementConnection = nil end
    if calibrateConnection then calibrateConnection:Disconnect(); calibrateConnection = nil end
end

local function resetTest()
    print("[Reset] resetTest called")
    disconnectAll()
    walkTrack:Stop()
    biteTrack:Stop()
    biteTrack:AdjustSpeed(1)
    
    attached = false
    isBitePhase = false
    sheepRoot.CanCollide = savedSheepCC
    sheep:SetAttribute("CapturedByDragon", false)
    
    dragon:PivotTo(initialDragonPivot)
    sheep:PivotTo(initialSheepPivot)
end

local function attachSheepToBiteBone()
    if attached then return end
    
    local targetCFrame = getBiteCFrame() * BITE_CARRY_OFFSET
    local snapDistance = (targetCFrame.Position - sheepRoot.Position).Magnitude
    
    if snapDistance > 3 then
        warn("[BiteAttach] Snap too large:", snapDistance)
        return
    end
    
    attached = true
    sheepRoot.CanCollide = false
    sheep:SetAttribute("CapturedByDragon", true)
    
    sheep:PivotTo(targetCFrame)
    
    carryingConnection = RunService.Heartbeat:Connect(function()
        local cf = getBiteCFrame()
        if cf then sheep:PivotTo(cf * BITE_CARRY_OFFSET) end
    end)
    
    print("[BiteAttach] Attached by real bone distance")
    biteTrack:AdjustSpeed(0)
    print("[Debug] Pose frozen. Press Reset.")
end

local function startBiteCalibration(runId)
    local minDistance = math.huge
    local lastLog = 0
    
    if calibrateConnection then calibrateConnection:Disconnect() end
    calibrateConnection = RunService.Heartbeat:Connect(function()
        if runId ~= currentRunId then 
            if calibrateConnection then calibrateConnection:Disconnect(); calibrateConnection = nil end
            return
        end
        
        if not attached and biteTrack.IsPlaying then
            local biteCF = getBiteCFrame()
            if biteCF then
                local dist = (biteCF.Position - sheepRoot.Position).Magnitude
                if dist < minDistance then minDistance = dist end
                
                if os.clock() - lastLog > 0.2 then
                    print(string.format("[BiteLive] t=%.3f dist=%.2f", biteTrack.TimePosition, dist))
                    lastLog = os.clock()
                end
                
                if dist <= MAX_ATTACH_DISTANCE then attachSheepToBiteBone() end
            end
        end
        
        if not biteTrack.IsPlaying and not attached then
            print("\n[BiteAnalysis] minDistance=", minDistance)
            warn("[BiteAnalysis] Bone never got close enough")
            if calibrateConnection then calibrateConnection:Disconnect(); calibrateConnection = nil end
        end
    end)
end

local function startBiteTest()
    print("[Start] startBiteTest called")
    resetTest()
    currentRunId += 1
    local runId = currentRunId
    
    walkTrack.Priority = Enum.AnimationPriority.Movement
    walkTrack.Looped = true
    walkTrack:Play(0.2)
    walkTrack:AdjustSpeed(1)
    
    local lastMoveLog = 0
    print("[MoveLoop] connected")
    
    movementConnection = RunService.Heartbeat:Connect(function(dt)
        if runId ~= currentRunId then 
            if movementConnection then movementConnection:Disconnect(); movementConnection = nil end
            return 
        end
        
        if isBitePhase then return end
        
        local dragonPivot = dragon:GetPivot()
        local dragonPos = dragonPivot.Position
        local sheepPos = sheepRoot.Position
        local flatDelta = Vector3.new(sheepPos.X - dragonPos.X, 0, sheepPos.Z - dragonPos.Z)
        
        local biteCF = getBiteCFrame()
        local biteDistance = biteCF and (biteCF.Position - sheepPos).Magnitude or math.huge
        
        if os.clock() - lastMoveLog > 0.25 then
            print(string.format("[MoveLoop] dragonPos=%.1f,%.1f,%.1f sheepPos=%.1f,%.1f,%.1f biteDistance=%.2f", 
                dragonPos.X, dragonPos.Y, dragonPos.Z, sheepPos.X, sheepPos.Y, sheepPos.Z, biteDistance))
            lastMoveLog = os.clock()
        end
        
        if biteDistance <= PRE_BITE_DISTANCE then
            isBitePhase = true
            print("[MoveLoop] Heartbeat movement disconnected (Reached target)")
            if movementConnection then movementConnection:Disconnect(); movementConnection = nil end
            
            print("[Bite] Starting bite animation")
            biteTrack.Priority = Enum.AnimationPriority.Action
            biteTrack.Looped = false
            biteTrack:Play(0.12)
            biteTrack:AdjustSpeed(1)
            startBiteCalibration(runId)
            return
        end
        
        if flatDelta.Magnitude > 0.1 then
            local dir = flatDelta.Unit
            local step = math.min(MOVE_SPEED * dt, flatDelta.Magnitude)
            local newPos = dragonPos + dir * step
            newPos = Vector3.new(newPos.X, dragonPos.Y + EXTRA_HEIGHT_OFFSET, newPos.Z)

            local targetLook = Vector3.new(sheepPos.X, newPos.Y, sheepPos.Z)
            local cf = CFrame.lookAt(newPos, targetLook)
                     * CFrame.Angles(0, math.rad(DRAGON_FORWARD_YAW_OFFSET_DEGREES), 0)

            dragon:PivotTo(cf)
        end
    end)
end

local function previewWalkOnly()
    print("[Preview] previewWalkOnly called")
    resetTest()
    currentRunId += 1
    walkTrack.Priority = Enum.AnimationPriority.Movement
    walkTrack.Looped = true
    walkTrack:Play(0.2)
end

local function previewBiteOnly()
    print("[Preview] previewBiteOnly called")
    resetTest()
    currentRunId += 1
    local runId = currentRunId
    print("[Bite] Starting bite animation")
    biteTrack.Priority = Enum.AnimationPriority.Action
    biteTrack.Looped = false
    biteTrack:Play(0.12)
    biteTrack:AdjustSpeed(1)
    startBiteCalibration(runId)
end

local remotes = ReplicatedStorage:WaitForChild("DragonSheepTestRemotes")
print("[UI] Remotes ready")

remotes.StartBiteTest.OnServerEvent:Connect(function(player)
    print("[UI] StartBiteTest requested by:", player.Name)
    startBiteTest()
end)

remotes.ResetBiteTest.OnServerEvent:Connect(function(player)
    print("[UI] ResetBiteTest requested by:", player.Name)
    resetTest()
end)

remotes.PreviewWalkOnly.OnServerEvent:Connect(function(player)
    print("[UI] PreviewWalkOnly requested by:", player.Name)
    previewWalkOnly()
end)

remotes.PreviewBiteOnly.OnServerEvent:Connect(function(player)
    print("[UI] PreviewBiteOnly requested by:", player.Name)
    previewBiteOnly()
end)
