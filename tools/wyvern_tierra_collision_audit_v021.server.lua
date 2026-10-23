--!strict
-- WYVERN TIERRA v0.2.1 - COLLISION AUDIT / ISOLATION - SOLO COPIA DEL PLACE.
-- Agregar temporalmente a ServerScriptService en una copia verificable de Studio.
-- Modo: atributo string del Script "CollisionTestMode" (OBSERVE por defecto).
-- OBSERVE: no cambia fisica. ISOLATE_ROOT: desactiva CanCollide RootPart.
-- ISOLATE_MESHES: solo mallas. ISOLATE_VISUAL: mallas + RootPart.
-- Todos los cambios son temporales en Play. NO instalar en produccion.
local RunService = game:GetService("RunService")
local model = workspace:WaitForChild("wyvernfbx", 15)
assert(model and model:IsA("Model"), "Falta Workspace.wyvernfbx")
local root = model:WaitForChild("DT_Root", 10)
assert(root and root:IsA("BasePart"), "Falta wyvernfbx.DT_Root")
local body = model:FindFirstChild("RootPart")
local groundCollider = model:FindFirstChild("DT_GroundCollider")
local seat = model:FindFirstChild("DT_NeckSeat")

local ALLOWED = { OBSERVE=true, ISOLATE_ROOT=true, ISOLATE_MESHES=true, ISOLATE_VISUAL=true }
local mode = tostring(script:GetAttribute("CollisionTestMode") or "OBSERVE"):upper()
assert(ALLOWED[mode], "CollisionTestMode desconocido: " .. mode)

local allParts = {}
local original = {}
local recentTouches = {}
local touchCooldown = {}
for _, desc in ipairs(model:GetDescendants()) do
    if desc:IsA("BasePart") then
        table.insert(allParts, desc)
        original[desc] = {
            canCollide = desc.CanCollide,
            canTouch = desc.CanTouch,
            massless = desc.Massless,
            collisionGroup = desc.CollisionGroup,
        }
    end
end

local function v(v3)
    return string.format("(%.2f,%.2f,%.2f)", v3.X, v3.Y, v3.Z)
end

local function printPart(part)
    local localPos = root.CFrame:PointToObjectSpace(part.Position)
    local mass = part:GetMass()
    local extra = ""
    if part:IsA("MeshPart") then
        extra = " Fidelity=" .. tostring(part.CollisionFidelity)
    end
    local props = part.CustomPhysicalProperties
    local density = props and props.Density or -1
    print(string.format(
        "[WYV-COL][PART] %s %s CanCollide=%s CanTouch=%s CanQuery=%s Anchored=%s Massless=%s Mass=%.2f Density=%.2f RootPriority=%d Group=%s Size=%s LocalPos=%s%s",
        part:GetFullName(), part.ClassName, tostring(part.CanCollide),
        tostring(part.CanTouch), tostring(part.CanQuery), tostring(part.Anchored),
        tostring(part.Massless), mass, density, part.RootPriority,
        part.CollisionGroup, v(part.Size), v(localPos), extra
    ))
end

print(string.format("[WYV-COL][START] mode=%s PartCount=%d ModelScale=%.8f", mode,#allParts,model:GetScale()))
print("[WYV-COL][KEY] dtRoot="..root:GetFullName()
    .." rootpart="..tostring(body and body:GetFullName())
    .." groundCollider="..tostring(groundCollider and groundCollider:GetFullName())
    .." seat="..tostring(seat and seat:GetFullName()))
for _, part in ipairs(allParts) do
    printPart(part)
end

for _, part in ipairs(allParts) do
    local isBody = part == body
    local isMesh = part:IsA("MeshPart")
    if (mode == "ISOLATE_ROOT" and isBody)
        or (mode == "ISOLATE_MESHES" and isMesh)
        or (mode == "ISOLATE_VISUAL" and (isBody or isMesh)) then
        if part.CanCollide then
            part.CanCollide = false
            print("[WYV-COL][A/B ISOLATED] "..part:GetFullName())
        end
    end
end

local function trackTouch(part, other)
    if not other or not other:IsA("BasePart") or other:IsDescendantOf(model) then return end
    -- Solo contactos potencialmente SOLIDOS que se ven en esta prueba.
    if not (part.CanCollide and other.CanCollide) then return end
    local stamp = os.clock()
    local token = part:GetFullName() .. "|" .. other:GetFullName()
    if (stamp-(touchCooldown[token] or -999))<0.25 then return end
    touchCooldown[token]=stamp
    local event = string.format("time=%.3f %s -> %s vel=%s omega=%s",
        stamp,part:GetFullName(),other:GetFullName(),
        v(root.AssemblyLinearVelocity),v(root.AssemblyAngularVelocity))
    table.insert(recentTouches,event)
    if #recentTouches>20 then table.remove(recentTouches,1) end
    print("[WYV-COL][TOUCH] "..event)
end

local connections = {}
for _, part in ipairs(allParts) do
    if part.CanCollide then
        table.insert(connections,part.Touched:Connect(function(other) trackTouch(part,other) end))
    end
end

local sum = 0
local previousTilt = 0
local previousOmega = 0
local previousState = tostring(root:GetAttribute("Wyvern_MotionState") or "unknown")
RunService.Heartbeat:Connect(function(dt)
    sum+=dt
    if sum<0.10 then return end
    local measuredDt = sum
    sum=0
    local state = tostring(root:GetAttribute("Wyvern_MotionState") or "unknown")
    local dot = math.clamp(root.CFrame.UpVector:Dot(Vector3.yAxis),-1,1)
    local tilt=math.deg(math.acos(dot))
    local omega=root.AssemblyAngularVelocity.Magnitude
    local speed=root.AssemblyLinearVelocity.Magnitude
    local sudden = (omega>1.25 and previousOmega<=1.25) or (tilt>30 and previousTilt<=30)
    local contactCount=0
    for _,part in ipairs(allParts) do if part.CanCollide then contactCount+=1 end end
    local base=string.format(
        "[WYV-COL][TELEMETRY] state=%s speed=%.2f tilt=%.1f omega=%.3f angularDelta=%.1f vy=%.2f activeSolidParts=%d support=%s probes=%s clearance=%s COM=%s",
        state,speed,tilt,omega,(tilt-previousTilt)/measuredDt,
        root.AssemblyLinearVelocity.Y,contactCount,
        tostring(root:FindFirstChild("WyvernGroundSupportV01") and root.WyvernGroundSupportV01.Enabled),
        tostring(root:GetAttribute("Wyvern_GroundProbeCount")),
        tostring(root:GetAttribute("Wyvern_GroundClearance")),
        v(root.AssemblyCenterOfMass)
    )
    if state ~= previousState then
        warn("[WYV-COL][STATE_TRANSITION] from="..previousState.." to="..state
            .." "..base)
        for _,touch in ipairs(recentTouches) do
            warn("[WYV-COL][TRANSITION CONTACT] "..touch)
        end
        previousState=state
    end
    if sudden then
        warn("[WYV-COL][TILT_SPIKE] "..base)
        for _,touch in ipairs(recentTouches) do warn("[WYV-COL][PREVIOUS TOUCH] "..touch) end
    elseif state=="GROUNDED_RUN" and (math.floor(os.clock()*2)~=math.floor((os.clock()-measuredDt)*2)) then
        print(base)
    end
    previousTilt=tilt
    previousOmega=omega
end)

script.Destroying:Connect(function()
    for _,c in ipairs(connections) do c:Disconnect() end
    -- Solo reestablecer las partes que siguen en el mismo modelo.
    for part,properties in pairs(original) do
        if part.Parent and part:IsDescendantOf(model) then
            part.CanCollide=properties.canCollide
        end
    end
end)
