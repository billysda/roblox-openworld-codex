local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local DragonModel = Workspace:WaitForChild("DragonModel", 10)
local SheepTemplateTest = Workspace:WaitForChild("SheepTemplateTest", 10)
local SheepModel = SheepTemplateTest

if not DragonModel or not SheepModel then
    warn("DragonSheepThrowTest: Falta DragonModel o SheepTemplateTest.")
    return
end

local socketBoca = DragonModel:FindFirstChild("Socket_Boca")
local sheepThrowTarget = DragonModel:FindFirstChild("SheepThrowTarget")
local sheepHrp = SheepModel:FindFirstChild("HumanoidRootPart")

if not socketBoca or not sheepThrowTarget or not sheepHrp then
    warn("DragonSheepThrowTest: Faltan partes clave (Socket_Boca, SheepThrowTarget o HumanoidRootPart).")
    return
end

local animControllerDragon = DragonModel:FindFirstChild("AnimationController")
if not animControllerDragon then return end
local animatorDragon = animControllerDragon:FindFirstChildOfClass("Animator") or Instance.new("Animator", animControllerDragon)

local dragonAnimation = Instance.new("Animation")
dragonAnimation.AnimationId = "rbxassetid://100881095921375"
local dragonTrack = animatorDragon:LoadAnimation(dragonAnimation)

local connection
local weld

local function detachSheepFromMouth()
    if weld then
        weld:Destroy()
        weld = nil
    end
end

local function startFollowThrowTarget()
    if connection then connection:Disconnect() end
    connection = RunService.Heartbeat:Connect(function()
        SheepModel:PivotTo(sheepThrowTarget.CFrame)
    end)
end

local function stopFollowThrowTarget()
    if connection then
        connection:Disconnect()
        connection = nil
    end
end

dragonTrack:GetMarkerReachedSignal("Grab"):Connect(function()
    print("[Grab] start follow SheepThrowTarget")
    detachSheepFromMouth() -- Por seguridad
    startFollowThrowTarget()
    SheepModel:SetAttribute("CapturedByDragon", true)
end)

dragonTrack:GetMarkerReachedSignal("Throw"):Connect(function()
    print("[Throw] visual throw marker")
    detachSheepFromMouth() -- Por seguridad
end)

dragonTrack:GetMarkerReachedSignal("Catch"):Connect(function()
    print("[Catch] catch marker reached")
    -- La oveja sigue controlada por SheepThrowTarget hasta Release para evitar saltos
end)

dragonTrack:GetMarkerReachedSignal("Release"):Connect(function()
    print("[Release] stop follow and release sheep")
    detachSheepFromMouth()
    stopFollowThrowTarget()
    SheepModel:SetAttribute("CapturedByDragon", false)
end)

local prompt = DragonModel.HumanoidRootPart:FindFirstChild("TestAnimPrompt")
if not prompt then
    prompt = Instance.new("ProximityPrompt")
    prompt.Name = "TestAnimPrompt"
    prompt.ActionText = "Test Animation"
    prompt.ObjectText = "Dragon"
    prompt.HoldDuration = 0
    prompt.RequiresLineOfSight = false
    prompt.MaxActivationDistance = 15
    prompt.Parent = DragonModel.HumanoidRootPart
end

prompt.Triggered:Connect(function(player)
    print("DragonSheepThrowTest: Iniciando animacion solicitada por " .. player.Name)
    -- Detener cualquier secuencia en curso antes de reiniciar
    stopFollowThrowTarget()
    detachSheepFromMouth()
    
    dragonTrack.Priority = Enum.AnimationPriority.Action2
    dragonTrack.Looped = false
    dragonTrack:Play()
end)

print("DragonSheepThrowTest: Listo. Acercate al dragon e interactua (E) para reproducir.")
