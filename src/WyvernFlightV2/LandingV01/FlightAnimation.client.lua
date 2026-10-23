-- FlightAnimation.client.lua -- Gran Wyvern de Tierra, transiciones v0.1
-- Sustituye al reproductor que iniciaba FlightLoop para siempre.
-- UN solo Animator, una sola pista dominante. No reescribe los huesos.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local flightFolder = ReplicatedStorage:WaitForChild("WyvernFlightV2")
local config = require(flightFolder:WaitForChild("Config"):WaitForChild("WyvernFlightConfig"))
local wyvern = Workspace:WaitForChild("wyvernfbx", 15)
if not wyvern then
    warn("[Wyvern Anim v0.1] Falta Workspace.wyvernfbx")
    return
end

local dtRoot = wyvern:WaitForChild("DT_Root", 10)
local controller = wyvern:WaitForChild("AnimationController", 10)
local animator = controller and controller:WaitForChild("Animator", 10)
if not dtRoot or not animator then
    warn("[Wyvern Anim v0.1] Falta DT_Root o Animator")
    return
end

local animFolder = wyvern:FindFirstChild("Animations")
local tracks = {}
local currentName = nil

local function loadTrack(animation, priority)
    if not animation or not animation:IsA("Animation") then return nil end
    if animation.AnimationId == "" then return nil end
    local ok, track = pcall(function()
        return animator:LoadAnimation(animation)
    end)
    if not ok or not track then
        warn("[Wyvern Anim v0.1] No se pudo cargar " .. animation.Name .. ": " .. tostring(track))
        return nil
    end
    track.Looped = true
    track.Priority = priority
    return track
end

local flightAnim = Instance.new("Animation")
flightAnim.Name = "WyvernFlightLoopAnim_V2"
flightAnim.AnimationId = config.AnimationId
tracks.FlightLoop = loadTrack(flightAnim, Enum.AnimationPriority.Movement)

if animFolder then
    tracks.Idle2 = loadTrack(animFolder:FindFirstChild("Idle2"), Enum.AnimationPriority.Idle)
    tracks.Run = loadTrack(animFolder:FindFirstChild("Run"), Enum.AnimationPriority.Movement)
end

if not tracks.FlightLoop then
    warn("[Wyvern Anim v0.1] No se pudo cargar FlightLoop; se cancela controlador de pistas.")
    return
end

local function desiredTrackName()
    local mode = dtRoot:GetAttribute("Wyvern_MotionState")
    if mode == "GROUNDED_IDLE" then return "Idle2" end
    if mode == "GROUNDED_RUN" then return "Run" end
    return "FlightLoop"
end

local function transition()
    local wanted = desiredTrackName()
    -- Nunca detener el vuelo si la animacion terrestre no esta cargada.
    if wanted ~= "FlightLoop" and not tracks[wanted] then
        warn("[Wyvern Anim v0.1] Falta animacion " .. wanted .. ". Se mantiene FlightLoop.")
        wanted = "FlightLoop"
    end
    if wanted == currentName then return end
    local fade = wanted == "FlightLoop" and 0.3 or 0.25

    -- Solo detener las pistas que controla este script, no las del editor
    -- ni las de otros sistemas de prueba.
    if currentName and tracks[currentName] then
        tracks[currentName]:Stop(fade)
    end
    local incoming = tracks[wanted]
    if not incoming.IsPlaying then
        incoming:Play(fade, 1, 1)
    else
        incoming:AdjustWeight(1, fade)
    end
    currentName = wanted
end

dtRoot:GetAttributeChangedSignal("Wyvern_MotionState"):Connect(transition)
dtRoot:GetAttributeChangedSignal("Wyvern_GroundSpeed"):Connect(function()
    if currentName == "Run" and tracks.Run then
        local speed = dtRoot:GetAttribute("Wyvern_GroundSpeed") or 16
        tracks.Run:AdjustSpeed(math.clamp(speed / 16, 0.5, 1.5))
    end
end)

transition()
print("[Wyvern Anim v0.1] FlightLoop/Idle2/Run listos; estado=", desiredTrackName())
