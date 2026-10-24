-- WyvernGroundABHarness.server.lua
-- Gran Wyvern de Tierra: controlled A/B between original-style XZ drive and
-- Roblox ControllerManager/GroundController. NEVER deploy in production.
-- Requires script attribute ABTestEnabled=true AND Studio Play environment.
-- Clones Workspace.wyvernfbx; DOES NOT modify its flight/rig/animator/controller.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

if not RunService:IsStudio() or script:GetAttribute("ABTestEnabled") ~= true then
    warn("[WYV-AB] Inactive. Only run in Studio with ABTestEnabled=true on this Script.")
    return
end

local driveMode = tostring(script:GetAttribute("DriveMode") or "GroundController")
assert(driveMode == "GroundController" or driveMode == "LegacyXZ",
    "DriveMode must be GroundController or LegacyXZ")

local MAIN = Workspace:WaitForChild("wyvernfbx", 20)
local MAIN_ROOT = MAIN:WaitForChild("DT_Root", 10)
assert(MAIN_ROOT, "[WYV-AB] Missing canonical DT_Root")
assert(not Workspace:FindFirstChild("WyvernGroundAB_TestClone"),
    "[WYV-AB] Test clone already exists; stop and restart Play")

local X = 2000 -- far away from the real wyvern and approved world
local TOP = 40
local testWorld = Instance.new("Model")
testWorld.Name = "WyvernGroundAB_Track"
testWorld.Parent = Workspace

local function makePart(name, size, cf, material)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.CFrame = cf
    part.Anchored = true
    part.CanCollide = true
    part.Material = material or Enum.Material.Concrete
    part.Color = Color3.fromRGB(110, 118, 124)
    part.Parent = testWorld
    return part
end

-- Start exactly 70 studs of flat, ending at Z=-30.
makePart("A_Flat_70studs", Vector3.new(52,2,70),
    CFrame.new(X, TOP-1, 5), Enum.Material.Grass)

local cursorZ = -30
local cursorY = TOP

local function ramp(name, degrees, length, material)
    local rotation = CFrame.Angles(math.rad(degrees), 0, 0)
    local topRearLocal = Vector3.new(0, 1, length/2)
    local rearWorld = Vector3.new(X,cursorY,cursorZ)
    local pos = rearWorld - rotation:VectorToWorldSpace(topRearLocal)
    makePart(name,Vector3.new(52,2,length), CFrame.new(pos)*rotation,material)
    local topFrontLocal = Vector3.new(0,1,-length/2)
    local front = pos + rotation:VectorToWorldSpace(topFrontLocal)
    cursorY=front.Y
    cursorZ=front.Z
end

local function plateau(name,length)
    makePart(name, Vector3.new(52,2,length),
        CFrame.new(X,cursorY-1,cursorZ-length/2),Enum.Material.Concrete)
    cursorZ -= length
end

ramp("B_10deg",10,55,Enum.Material.Slate)
plateau("C_10deg_Plateau",22)
ramp("D_20deg",20,50,Enum.Material.Rock)
plateau("E_20deg_Plateau",22)
ramp("F_30deg",30,45,Enum.Material.Slate)
plateau("G_Crest",40)
ramp("H_Downhill_20deg",-20,48,Enum.Material.Grass)
plateau("I_Exit",80)

-- Clone the user's EXACT visual/physical rig. Its existing server controller
-- selects only Workspace.wyvernfbx, never WyvernGroundAB_TestClone.
local oldArchivable=MAIN.Archivable
MAIN.Archivable=true
local clone=MAIN:Clone()
MAIN.Archivable=oldArchivable
assert(clone,"Failed to clone wyvernfbx")
clone.Name="WyvernGroundAB_TestClone"
clone.Parent=Workspace
local root=clone:FindFirstChild("DT_Root")
assert(root and root:IsA("BasePart"),"Missing DT_Root on clone")

-- Disable ALL cloned scripts: no competing motion, camera or animation.
for _,item in ipairs(clone:GetDescendants()) do
    if item:IsA("Script") or item:IsA("LocalScript") then
        item.Disabled=true
    elseif item:IsA("BasePart") then
        item.Anchored=false
        if item:IsA("MeshPart") or item.Name=="RootPart"
            or item.Name=="DT_GroundCollider" or item.Name=="DT_Root" then
            item.CanCollide=false
        end
    end
end

local baseCF=CFrame.lookAt(Vector3.new(X,TOP+2.2,20),
    Vector3.new(X,TOP+2.2,19))
local relative=clone:GetPivot():ToObjectSpace(root.CFrame)
clone:PivotTo(baseCF * relative:Inverse())
root.AssemblyLinearVelocity=Vector3.zero
root.AssemblyAngularVelocity=Vector3.zero

-- Make one smooth, calibrated, welded physical contact primitive. Keep exact
-- values constant in both A/B variants, so only the locomotion driver changes.
local proxy=clone:FindFirstChild("DT_TorsoCollisionV022")
if proxy and not proxy:IsA("Part") then
    error("[WYV-AB] unexpected existing collider class")
end
if not proxy then
    proxy=Instance.new("Part")
    proxy.Name="DT_TorsoCollisionV022"
    proxy.Parent=clone
end
local previousWeld=proxy:FindFirstChild("DT_TorsoCollisionWeldV022")
if previousWeld then previousWeld:Destroy() end
proxy.CanCollide=false
proxy.Anchored=false
proxy.Massless=true
proxy.Shape=Enum.PartType.Ball
proxy.Size=Vector3.new(3,3,3)
proxy.CFrame=root.CFrame*CFrame.new(0,-0.27,0)
proxy.Transparency=1
proxy.CastShadow=false
proxy.CanQuery=false
proxy.CustomPhysicalProperties=PhysicalProperties.new(0.7,0.65,0,100,100)
local weld=Instance.new("WeldConstraint")
weld.Name="DT_TorsoCollisionWeldV022"
weld.Part0=root
weld.Part1=proxy
weld.Parent=proxy
proxy.CanCollide=true

-- Explicitly disable copied runtime actuators in both variants.
for _,part in ipairs(clone:GetDescendants()) do
    if part:IsA("LinearVelocity") or part:IsA("AlignOrientation")
        or part:IsA("VectorForce") or part:IsA("Torque") then
        part.Enabled=false
    end
end

pcall(function()root:SetNetworkOwner(nil)end)

local inputRemote=ReplicatedStorage:FindFirstChild("WyvernGroundABInput")
if not inputRemote then
    inputRemote=Instance.new("RemoteEvent")
    inputRemote.Name="WyvernGroundABInput"
    inputRemote.Parent=ReplicatedStorage
end
local playerPilot=nil
local desiredW=false
local desiredBoost=false
local turn=0
inputRemote.OnServerEvent:Connect(function(player,p)
    if type(p)~="table" then return end
    if playerPilot and playerPilot~=player then return end
    playerPilot=player
    desiredW=p.w==true
    desiredBoost=p.shift==true
    turn=math.clamp(tonumber(p.turn) or 0,-1,1)
end)

local manager,ground,sensor,lv,ao
local facingYaw=math.atan2(-root.CFrame.LookVector.X,-root.CFrame.LookVector.Z)
local attachment=root:FindFirstChild("WyvernAB_Attachment")
if not attachment then
    attachment=Instance.new("Attachment")
    attachment.Name="WyvernAB_Attachment"
    attachment.Parent=root
end

if driveMode=="GroundController" then
    manager=Instance.new("ControllerManager")
    manager.Name="WyvernAB_ControllerManager"
    manager.RootPart=root
    manager.BaseMoveSpeed=30
    manager.BaseTurnSpeed=math.rad(60)
    manager.UpDirection=Vector3.yAxis
    manager.Parent=clone

    sensor=Instance.new("ControllerPartSensor")
    sensor.Name="WyvernAB_GroundSensor"
    sensor.SensorMode=Enum.SensorMode.Floor
    sensor.SearchDistance=8.0 -- MUST be greater than GroundOffset=1.77
    sensor.Parent=root
    manager.GroundSensor=sensor

    ground=Instance.new("GroundController")
    ground.Name="WyvernAB_GroundController"
    ground.GroundOffset=1.77
    ground.AccelerationTime=0.35
    ground.DecelerationTime=0.20
    ground.Friction=0.65
    ground.FrictionWeight=100
    ground.BalanceMaxTorque=100000 -- Sept 2026 physics bug: avoid zero torque
    ground.BalanceSpeed=10
    ground.TurnSpeedFactor=1
    ground.Parent=manager
    manager.ActiveController=ground
else
    lv=Instance.new("LinearVelocity")
    lv.Name="WyvernAB_LegacyLinearVelocity"
    lv.Attachment0=attachment
    lv.RelativeTo=Enum.ActuatorRelativeTo.World
    lv.VelocityConstraintMode=Enum.VelocityConstraintMode.Vector
    lv.ForceLimitsEnabled=true
    lv.ForceLimitMode=Enum.ForceLimitMode.PerAxis
    local force=math.clamp(root.AssemblyMass*450,350,250000)
    lv.MaxAxesForce=Vector3.new(force,0,force)
    lv.VectorVelocity=Vector3.zero
    lv.Parent=root
    ao=Instance.new("AlignOrientation")
    ao.Name="WyvernAB_LegacyAlignOrientation"
    ao.Attachment0=attachment
    ao.Mode=Enum.OrientationAlignmentMode.OneAttachment
    ao.MaxTorque=1e6
    ao.Responsiveness=12
    ao.RigidityEnabled=false
    ao.Parent=root
end

-- Optional Studio-only animation playback on the clone. The original
-- wyvern's FlightAnimationServerV022 remains untouched and targets wyvernfbx.
local animator=clone:FindFirstChild("AnimationController")
animator=animator and animator:FindFirstChildOfClass("Animator")
local testTracks={}
if animator then
    local ServerStorage=game:GetService("ServerStorage")
    local KeyframeSequenceProvider=game:GetService("KeyframeSequenceProvider")
    local originalSequences=ServerStorage:FindFirstChild("RBX_ANIMSAVES")
    originalSequences=originalSequences and originalSequences:FindFirstChild("wyvernfbx")
    local animations=clone:FindFirstChild("Animations")
    local function tryLoad(name,sequenceName,priority)
        local id=nil
        local obj=animations and animations:FindFirstChild(name)
        if obj and obj:IsA("Animation") and obj.AnimationId:match("^rbxassetid://%d+$") then
            id=obj.AnimationId
        end
        if not id then
            local seq=originalSequences and originalSequences:FindFirstChild(sequenceName)
            if seq and seq:IsA("KeyframeSequence") then
                local ok, result=pcall(function()
                    return KeyframeSequenceProvider:RegisterKeyframeSequence(seq)
                end)
                if ok then id="rbxassetid://"..result end
            end
        end
        if not id then
            warn("[WYV-AB] No "..name.." asset on clone; physics still testable")
            return
        end
        local a=Instance.new("Animation")
        a.AnimationId=id
        a.Name="AB_"..name
        local ok,track=pcall(function()return animator:LoadAnimation(a)end)
        if ok then
            track.Looped=true
            track.Priority=priority
            testTracks[name]=track
        else
            warn("[WYV-AB] Could not load "..name..": "..tostring(track))
        end
    end
    tryLoad("Idle2","wyvern_idle2_from_hoy_Scene",Enum.AnimationPriority.Idle)
    tryLoad("Run","wyvern_run_from_hoy_Scene",Enum.AnimationPriority.Movement)
end
local currentTrack=nil
local function updateAnimation(walking,speed)
    local target=walking and "Run" or "Idle2"
    if target~=currentTrack then
        if currentTrack and testTracks[currentTrack] then
            testTracks[currentTrack]:Stop(0.20)
        end
        local track=testTracks[target]
        if track then track:Play(0.2) end
        currentTrack=target
    end
    if target=="Run" and testTracks.Run then
        testTracks.Run:AdjustSpeed(math.clamp(speed/30,0.25,1.3))
    end
end

local nextMessage=0
root:SetAttribute("WyvernAB_Mode",driveMode)
print("[WYV-AB][READY] mode=",driveMode,"assemblyMass=",root.AssemblyMass,
    "GroundOffset=1.77; collider=3x3x3; output clone only")
RunService.Heartbeat:Connect(function(dt)
    dt=math.clamp(dt,1/240,0.08)
    facingYaw=(facingYaw-turn*math.rad(60)*dt)%(2*math.pi)
    local forward=CFrame.fromEulerAnglesYXZ(0,facingYaw,0).LookVector
    local goalSpeed=desiredW and (desiredBoost and 39 or 30) or 0
    updateAnimation(desiredW,goalSpeed)
    if manager then
        manager.BaseMoveSpeed=goalSpeed
        manager.FacingDirection=forward
        manager.MovingDirection=desiredW and forward or Vector3.zero
    else
        lv.VectorVelocity=forward*goalSpeed
        ao.CFrame=CFrame.fromEulerAnglesYXZ(0,facingYaw,0)
    end

    if os.clock()>=nextMessage then
        nextMessage=os.clock()+0.5
        local v=root.AssemblyLinearVelocity
        local planar=Vector3.new(v.X,0,v.Z).Magnitude
        local raycastParams=RaycastParams.new()
        raycastParams.FilterType=Enum.RaycastFilterType.Exclude
        raycastParams.FilterDescendantsInstances={clone,MAIN}
        raycastParams.RespectCanCollide=true
        local floor=Workspace:Raycast(root.Position+Vector3.yAxis*5,
            Vector3.new(0,-55,0),raycastParams)
        local gap=floor and root.Position.Y-floor.Position.Y or -999
        local normal=floor and floor.Normal or Vector3.yAxis
        local slope=math.deg(math.acos(math.clamp(normal.Y,-1,1)))
        local sensed=sensor and sensor.SensedPart
        local actual=root.CFrame.LookVector
        local tilt=math.deg(math.acos(math.clamp(
            root.CFrame.UpVector:Dot(Vector3.yAxis),-1,1)))
        print(string.format("[WYV-AB][SAMPLE] mode=%s x=%.2f y=%.2f z=%.2f "..
           "targetSpeed=%.1f speedXZ=%.2f vy=%.2f slope=%.1f rootGap=%.2f "..
           "tilt=%.2f yaw=%.1f sensedFloor=%s",
           driveMode,root.Position.X,root.Position.Y,root.Position.Z,
           goalSpeed,planar,v.Y,slope,gap,tilt,
           math.deg(math.atan2(-actual.X,-actual.Z)),
           tostring(sensed and sensed.Name or "NONE")))
    end
end)
