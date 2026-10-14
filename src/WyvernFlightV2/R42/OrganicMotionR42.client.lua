-- OrganicMotionR42.client.lua
-- OpenWorld Codex | WyvernFlightV2 R4.2 (solo efectos visuales)
-- R4.1 permanece intacta: NO modificar FlightController, FlightCamera,
-- FlightAnimation, Input, DT_Root, velocidad, fisica ni remotes.
--
-- Destino: StarterPlayer.StarterPlayerScripts.WyvernFlightV2.OrganicMotionR42
-- Para comparar A/B: atributo OrganicMotionEnabled=false ANTES de Play
-- o deshabilitar este LocalScript (sin cambiar los scripts de R4.1).
--
-- Etapas de frame en Roblox:
-- PreAnimation -> Animator actualiza Bone.Transform -> PreSimulation.
-- Aplicamos offset ADITIVO en PreSimulation, despues de la animacion.
-- Si una Bone no recibe keyframes, retiramos nuestro offset anterior
-- antes de volver a escribir para que no se acumule indefinidamente.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local v2 = ReplicatedStorage:WaitForChild("WyvernFlightV2", 12)
if not v2 then
    warn("[Wyvern R4.2] Falta ReplicatedStorage.WyvernFlightV2. No se activa.")
    return
end

local configFolder = v2:WaitForChild("Config", 12)
local flightConfigModule = configFolder and configFolder:WaitForChild("WyvernFlightConfig", 12)
local organicConfigModule = v2:WaitForChild("OrganicMotionConfigR42", 12)
if not flightConfigModule or not organicConfigModule then
    warn("[Wyvern R4.2] Faltan modulos de configuracion; R4.1 sigue intacta.")
    return
end

local FlightConfig = require(flightConfigModule)
local MotionConfig = require(organicConfigModule)

local wyvern = Workspace:FindFirstChild("wyvernfbx")
    or Workspace:WaitForChild("wyvernfbx", 10)
    or Workspace:FindFirstChild("DragonTierraRoblox")

if not wyvern then
    warn("[Wyvern R4.2] No se encontro el modelo wyvernfbx; addon inactivo.")
    return
end

local dtRoot = wyvern:FindFirstChild("DT_Root")
local skeletonRoot = wyvern:FindFirstChild("RootPart")
local animationController = wyvern:FindFirstChildOfClass("AnimationController")
local animator = animationController and animationController:FindFirstChildOfClass("Animator")

if not dtRoot or not skeletonRoot or not animator then
    warn("[Wyvern R4.2] DT_Root, RootPart o Animator faltante. Addon inactivo.")
    return
end

local tail = MotionConfig.Tail
local neck = MotionConfig.Neck
local head = MotionConfig.Head
local allRecords = {}
local tailRecords = {}
local neckRecords = {}
local headRecord = nil

-- Cada record guarda el ultimo offset aplicado a su Bone.
-- Esto conserva el resultado original del Animator y permite rollback.
local function makeRecord(name, yawAxis, pitchAxis)
    local instance = skeletonRoot:FindFirstChild(name, true)
    if not instance or not instance:IsA("Bone") then
        warn("[Wyvern R4.2] Bone ausente en RootPart: " .. name)
        return nil
    end
    local record = {
        bone = instance,
        yawAxis = yawAxis.Unit,
        pitchAxis = pitchAxis and pitchAxis.Unit or nil,
        yaw = 0,
        pitch = 0,
        lastOffset = CFrame.identity,
        lastWritten = nil,
    }
    table.insert(allRecords, record)
    return record
end

for _, name in ipairs(tail.Names) do
    table.insert(tailRecords, makeRecord(name, tail.LocalYawAxis, nil) or false)
end
for _, name in ipairs(neck.Names) do
    table.insert(neckRecords, makeRecord(name, neck.LocalYawAxis, nil) or false)
end
headRecord = makeRecord(head.Name, head.LocalYawAxis, head.LocalPitchAxis)

local expectedBones = #tail.Names + #neck.Names + 1
local poseEnabled = #allRecords == expectedBones

if not poseEnabled then
    warn(("[Wyvern R4.2] Rig parcial (%d/%d huesos). " ..
        "Solo cambia la velocidad de animacion; las poses secundarias quedan desactivadas.")
        :format(#allRecords, expectedBones))
end

local activeTrack = nil
local currentSpeedMultiplier = FlightConfig.AnimationSpeed or 1
local trackSearchElapsed = MotionConfig.Animation.TrackSearchSeconds
local lastReportAt = 0
local poseActive = false

local function getNumberAttribute(name, fallback)
    local value = dtRoot:GetAttribute(name)
    return (type(value) == "number" and value == value) and value or fallback
end

local function seekFlightTrack()
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        local animation = track.Animation
        if track.IsPlaying and animation and animation.AnimationId == FlightConfig.AnimationId then
            return track
        end
    end
    return nil
end

local function restoreBoneOffsets()
    for _, record in ipairs(allRecords) do
        local bone = record.bone
        -- Nunca sobrescribir una nueva pose producida por el Animator u otro script.
        if bone.Parent and record.lastWritten and bone.Transform == record.lastWritten then
            bone.Transform = bone.Transform * record.lastOffset:Inverse()
        end
        record.lastOffset = CFrame.identity
        record.lastWritten = nil
        record.yaw = 0
        record.pitch = 0
    end
    poseActive = false
end

local function restoreAnimationSpeed()
    if activeTrack and activeTrack.IsPlaying then
        activeTrack:AdjustSpeed(FlightConfig.AnimationSpeed or 1)
    end
    currentSpeedMultiplier = FlightConfig.AnimationSpeed or 1
end

local function restoreR41()
    restoreAnimationSpeed()
    restoreBoneOffsets()
    script:SetAttribute("R42_AnimationMultiplier", FlightConfig.AnimationSpeed or 1)
end

local function enabled()
    return script:GetAttribute("OrganicMotionEnabled") ~= false
end

-- Control reversible sin cambiar otras instancias. Por defecto activo.
script:GetAttributeChangedSignal("OrganicMotionEnabled"):Connect(function()
    if not enabled() then
        restoreR41()
    else
        -- buscar de nuevo la pista si se ha cambiado durante A/B
        trackSearchElapsed = MotionConfig.Animation.TrackSearchSeconds
    end
end)

local function targetAnimationMultiplier()
    local speed = getNumberAttribute("Flight_Speed", FlightConfig.CruiseSpeed)
    local cruise = FlightConfig.CruiseSpeed
    local slow = FlightConfig.MinSpeed
    local fast = FlightConfig.MaxSpeed
    local settings = MotionConfig.Animation

    if dtRoot:GetAttribute("Flight_IsBoosting") == true then
        return settings.BoostMultiplier
    end
    if speed <= cruise then
        local t = math.clamp((speed - slow) / math.max(cruise - slow, 1), 0, 1)
        return settings.SlowMultiplier
            + (settings.CruiseMultiplier - settings.SlowMultiplier) * t
    end
    local t = math.clamp((speed - cruise) / math.max(fast - cruise, 1), 0, 1)
    return settings.CruiseMultiplier
        + (settings.FastMultiplier - settings.CruiseMultiplier) * t
end

-- PreAnimation permite cambiar la velocidad ANTES de que Animator avance la pista.
RunService.PreAnimation:Connect(function(dt)
    if not enabled() or not animator.Parent or not dtRoot.Parent then
        return
    end

    dt = math.clamp(dt, 0, 0.1)
    trackSearchElapsed += dt

    if not activeTrack or not activeTrack.IsPlaying then
        if trackSearchElapsed >= MotionConfig.Animation.TrackSearchSeconds then
            activeTrack = seekFlightTrack()
            trackSearchElapsed = 0
        end
    end

    if not activeTrack or not activeTrack.IsPlaying then
        return
    end

    local wanted = targetAnimationMultiplier()
    local tau = math.max(MotionConfig.Animation.ResponseSeconds, 0.01)
    local alpha = 1 - math.exp(-dt / tau)
    currentSpeedMultiplier += (wanted - currentSpeedMultiplier) * alpha

    if math.abs(activeTrack.Speed - currentSpeedMultiplier) > 0.005 then
        activeTrack:AdjustSpeed(currentSpeedMultiplier)
    end

    if os.clock() - lastReportAt >= 0.25 then
        lastReportAt = os.clock()
        script:SetAttribute("R42_AnimationMultiplier", math.floor(currentSpeedMultiplier * 1000 + 0.5) / 1000)
    end
end)

local function updateBone(record, wantedYawDeg, wantedPitchDeg, responseSeconds, dt)
    local alpha = 1 - math.exp(-dt / math.max(responseSeconds, 0.01))
    record.yaw += (wantedYawDeg - record.yaw) * alpha
    record.pitch += (wantedPitchDeg - record.pitch) * alpha

    local newOffset = CFrame.fromAxisAngle(record.yawAxis, math.rad(record.yaw))
    if record.pitchAxis then
        newOffset *= CFrame.fromAxisAngle(record.pitchAxis, math.rad(record.pitch))
    end

    local bone = record.bone
    if not bone.Parent then
        return
    end

    local animatedBase = bone.Transform
    -- La igualdad exacta indica que el Animator NO modifico este Transform
    -- desde la escritura anterior. Retirar el offset previo en ese caso.
    if record.lastWritten and animatedBase == record.lastWritten then
        animatedBase *= record.lastOffset:Inverse()
    end
    bone.Transform = animatedBase * newOffset
    record.lastOffset = newOffset
    record.lastWritten = bone.Transform
end

-- PreSimulation ocurre despues del paso de animacion. Solo visual local.
RunService.PreSimulation:Connect(function(dt)
    if not enabled() or not poseEnabled or not dtRoot.Parent or not skeletonRoot.Parent then
        return
    end
    if not activeTrack or not activeTrack.IsPlaying then
        if poseActive then
            restoreBoneOffsets()
        end
        return
    end

    dt = math.clamp(dt, 0.001, 0.1)
    poseActive = true

    local intent = math.clamp(getNumberAttribute("Flight_FinalTurnIntent", 0), -1, 1)
    local pitchIntent = math.clamp(getNumberAttribute("Flight_FinalPitchIntent", 0), -1, 1)
    local yawRate = getNumberAttribute("Flight_HeadingDeltaPerSecond", 0)
    local measuredTurn = math.clamp(
        yawRate / MotionConfig.MaxMeasuredTurnRateDegPerSecond, -1, 1
    )
    local timeNow = os.clock()

    -- Cola: responde al giro angular real; cada eslabon se retrasa algo mas.
    for i, record in ipairs(tailRecords) do
        local follow = tail.FollowSeconds[i]
        local baseYaw = measuredTurn * tail.DirectionSign * tail.TotalYawDegrees * tail.Weights[i]
        local sway = math.sin(
            timeNow * math.pi * 2 * tail.SwayFrequencyHz - i * tail.SwayPhaseRadiansPerJoint
        ) * tail.SwayDegreesPerJoint * (i / #tailRecords)
        updateBone(record, baseYaw + sway, 0, follow, dt)
    end

    -- Cuello/cabeza: reaccionan a la intencion de la entrada antes de que
    -- el cuerpo termine de girar. Rangos tan bajos que no sustituyen la animacion.
    for i, record in ipairs(neckRecords) do
        local yaw = intent * neck.DirectionSign * neck.TotalYawDegrees * neck.Weights[i]
        updateBone(record, yaw, 0, neck.ResponseSeconds[i], dt)
    end
    updateBone(
        headRecord,
        intent * head.YawSign * head.MaxYawDegrees,
        pitchIntent * head.PitchSign * head.MaxPitchDegrees,
        head.ResponseSeconds,
        dt
    )
end)

print(("[Wyvern R4.2] Organic Motion conectado. Rig=%d/%d huesos, " ..
    "animacion=%s, fase=PreAnimation/PreSimulation.")
    :format(#allRecords, expectedBones, tostring(FlightConfig.AnimationId)))
