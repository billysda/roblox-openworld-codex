-- wyvern_terrain_validation_v023.server.lua
-- READ ONLY / isolated Play Place: no edits, velocities, welds or forces.
-- Samples real physical root, always-on sphere, and ANIMATED bone transforms.
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local model=Workspace:WaitForChild("wyvernfbx",15)
local root=model and model:WaitForChild("DT_Root",10)
if not root then warn("[WYV-TERRAIN-023] Missing root");return end
local proxy=model:WaitForChild("DT_TorsoCollisionV022",10)
if not proxy then warn("[WYV-TERRAIN-023] Missing physical proxy");return end
local footBones={}
for _,d in ipairs(model:GetDescendants()) do
    if d:IsA("Bone") and d.Name:lower():find("pata") then
        table.insert(footBones,d)
    end
end
print("[WYV-TERRAIN-023] ANIMATED FOOT BONE CANDIDATES=",#footBones)
for _,bone in ipairs(footBones) do
    print("[WYV-TERRAIN-023][BONE]",bone:GetFullName())
end

local params=RaycastParams.new()
params.FilterType=Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances={model}
params.RespectCanCollide=true
params.IgnoreWater=true
local overlap=OverlapParams.new()
overlap.FilterType=Enum.RaycastFilterType.Exclude
overlap.FilterDescendantsInstances={model}
overlap.RespectCanCollide=true
overlap.MaxParts=8

local elapsed=0
local lastState=nil
local function scan()
    local state=tostring(root:GetAttribute("Wyvern_MotionState"))
    local below=Workspace:Raycast(root.Position+Vector3.yAxis*5,
        Vector3.new(0,-70,0),params)
    local groundY=below and below.Position.Y or -999
    local lowest=proxy.Position.Y-proxy.Size.Y*0.5
    local contactLike={}
    local near=Workspace:GetPartsInPart(proxy,overlap)
    for i=1,math.min(3,#near) do
        contactLike[#contactLike+1]=near[i]:GetFullName()
    end
    local tilt=math.deg(math.acos(math.clamp(
        root.CFrame.UpVector:Dot(Vector3.yAxis),-1,1)))
    local vel=root.AssemblyLinearVelocity
    print(string.format("[WYV-TERRAIN-023][ROOT] state=%s rootY=%.3f groundY=%.3f "..
        "proxyBottomY=%.3f proxyCanCollide=%s overlapCount=%d tilt=%.2f "..
        "vy=%.3f speedXZ=%.2f sensorNear=%s nearHits=%s "..
        "clearance=%s recovery=%.2f forceOn=%s rootPart=%s",
        state, root.Position.Y,groundY,lowest,
        tostring(proxy.CanCollide),#near,tilt,vel.Y,
        Vector3.new(vel.X,0,vel.Z).Magnitude,
        tostring(root:GetAttribute("Wyvern_NearGround")),
        tostring(root:GetAttribute("Wyvern_NearHitCount")),
        tostring(root:GetAttribute("Wyvern_NearestGroundClearance")),
        tonumber(root:GetAttribute("Wyvern_GroundRecoveryTime")) or 0,
        tostring(root:FindFirstChild("WyvernGroundSupportV01")
            and root.WyvernGroundSupportV01.Enabled),
        root.AssemblyRootPart and root.AssemblyRootPart.Name or "nil"))
    if #contactLike>0 then
        print("[WYV-TERRAIN-023][OVERLAP]",table.concat(contactLike,";"))
    end
    if state=="GROUNDED_IDLE" or state=="GROUNDED_RUN" then
        for index,bone in ipairs(footBones) do
            if index>10 then break end
            local worldPos=bone.TransformedWorldCFrame.Position
            local floor=Workspace:Raycast(worldPos+Vector3.yAxis*5,
                Vector3.new(0,-15,0),params)
            local gap=floor and (worldPos.Y-floor.Position.Y) or math.huge
            print(string.format("[WYV-TERRAIN-023][FOOT] %s gap=%.3f y=%.3f",
                bone.Name,gap,worldPos.Y))
        end
    end
end
RunService.Heartbeat:Connect(function(dt)
    elapsed+=dt
    local state=root:GetAttribute("Wyvern_MotionState")
    if state ~= lastState then
        lastState=state
        print("[WYV-TERRAIN-023][STATE]",tostring(state))
        scan()
    elseif elapsed>=0.5 then
        elapsed=0
        scan()
    end
end)
