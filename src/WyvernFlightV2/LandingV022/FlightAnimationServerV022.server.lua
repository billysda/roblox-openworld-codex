-- FlightAnimationServerV022.server.lua
-- Animaciones replicadas para modelo NO jugador: Workspace.wyvernfbx.
-- ACTIVA SOLO DESPUES de publicar Idle2 y Run como rbxassetid://NUMERO.
-- Deshabilitar StarterPlayerScripts.WyvernFlightV2.FlightAnimation para
-- que no compita con este servidor; no dejar dos controladores simultaneos.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local wyvern = Workspace:WaitForChild("wyvernfbx", 15)
if not wyvern then error("Falta el Gran Wyvern de Tierra") end
local root = wyvern:WaitForChild("DT_Root", 10)
local animCtrl = wyvern:WaitForChild("AnimationController", 10)
local animator = animCtrl and animCtrl:WaitForChild("Animator", 10)
local folder = wyvern:WaitForChild("Animations", 10)
local cfg = require(ReplicatedStorage:WaitForChild("WyvernFlightV2")
    :WaitForChild("Config"):WaitForChild("WyvernFlightConfig"))

assert(root and animator and folder, "Falta Root, Animator o carpeta Animations")

local function publishedId(value)
    if type(value) ~= "string" then return nil end
    local digits = value:match("^rbxassetid://(%d+)$") or value:match("^(%d+)$")
    if digits and tonumber(digits) and tonumber(digits) > 0 then
        return "rbxassetid://" .. digits
    end
    return nil
end

local idle = folder:FindFirstChild("Idle2")
local run = folder:FindFirstChild("Run")
local flightId = publishedId(cfg.AnimationId)
local idleId = idle and idle:IsA("Animation") and publishedId(idle.AnimationId)
local runId = run and run:IsA("Animation") and publishedId(run.AnimationId)

-- Bloqueo explícito: un hash temporal de Studio NO funciona en la experiencia.
if not (flightId and idleId and runId) then
    warn("[WYV-ANIM-PUBLISH] Falta un ID permanente. Publicar Idle2 y Run"
      .." como Animation assets del propietario del Place, asignar"
      .." rbxassetid://NUMERO en wyvernfbx.Animations; NO desactivar"
      .." FlightAnimation cliente hasta terminar esa migracion.")
    return
end

local function load(id, name, priority)
    local a = Instance.new("Animation")
    a.Name = "WyvernV022_" .. name
    a.AnimationId = id
    local track = animator:LoadAnimation(a)
    track.Looped = true
    track.Priority = priority
    return track
end

local tracks = {
    FlightLoop = load(flightId, "FlightLoop", Enum.AnimationPriority.Movement),
    Idle2 = load(idleId, "Idle2", Enum.AnimationPriority.Idle),
    Run = load(runId, "Run", Enum.AnimationPriority.Movement),
}
local current = nil
local function desired()
    local state = root:GetAttribute("Wyvern_MotionState")
    if state == "GROUNDED_IDLE" then return "Idle2" end
    if state == "GROUNDED_RUN" then return "Run" end
    if state == "GROUND_RECOVERY" then return "Run" end
    return "FlightLoop"
end
local function change()
    local target = desired()
    if target == current then return end
    if current then tracks[current]:Stop(0.22) end
    local nextTrack = tracks[target]
    if not nextTrack.IsPlaying then nextTrack:Play(0.22,1,1) end
    current = target
    root:SetAttribute("Wyvern_ServerAnimation", target)
end

root:GetAttributeChangedSignal("Wyvern_MotionState"):Connect(change)
change()

local timer = 0
RunService.Heartbeat:Connect(function(dt)
    timer += dt
    if timer < 0.08 then return end
    timer = 0

    if current == "Run" then
        local nominal = root:GetAttribute("Wyvern_RunNominalSpeed") or 30
        local v = root.AssemblyLinearVelocity
        local actual = Vector3.new(v.X, 0, v.Z).Magnitude
        local rate = math.clamp(actual / nominal, 0.25, 1.3)
        tracks.Run:AdjustSpeed(rate)
        if tracks.Run.Length > 0 then
            root:SetAttribute("Wyvern_RunPhaseBase",
                (tracks.Run.TimePosition / tracks.Run.Length) % 1)
            root:SetAttribute("Wyvern_RunPhaseRate", rate / tracks.Run.Length)
            root:SetAttribute("Wyvern_RunPhaseStamp", Workspace:GetServerTimeNow())
            return
        end
    end
    root:SetAttribute("Wyvern_RunPhaseRate", 0)
    root:SetAttribute("Wyvern_RunPhaseBase", -1)
    root:SetAttribute("Wyvern_RunPhaseStamp", Workspace:GetServerTimeNow())
end)

print("[WYV-ANIM-PUBLISH] FlightLoop, Idle2, Run cargadas por SERVIDOR")
