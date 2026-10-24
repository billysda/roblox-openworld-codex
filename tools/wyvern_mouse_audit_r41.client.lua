-- WyvernMouseAudit.client.lua
-- DIAGNOSTICO READ-ONLY del control R4.1/R4.2. No escribe AimState, CFrame, velocidad ni controles.
-- Colocar temporalmente en StarterPlayerScripts en una COPIA AISLADA.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local folder = ReplicatedStorage:WaitForChild("WyvernFlightV2", 10)
local wyv = Workspace:WaitForChild("wyvernfbx", 15)
local root = wyv and wyv:WaitForChild("DT_Root", 10)
if not (folder and root) then
    warn("[WYV-AIM-AUDIT][CLIENT] No se encontró WyvernFlightV2 o DT_Root.")
    return
end

local function tryRequire(module)
    if not module or not module:IsA("ModuleScript") then return nil, "MISSING" end
    local ok, result = pcall(require, module)
    if not ok then return nil, tostring(result) end
    return result, nil
end

local canonical = folder:FindFirstChild("FlightAimState")
local nestedParent = folder:FindFirstChild("Aim")
local nested = nestedParent and nestedParent:FindFirstChild("FlightAimState")
local rootAim, rootErr = tryRequire(canonical)
local nestedAim, nestedErr = tryRequire(nested)
local oneAim = rootAim and nestedAim and rawequal(rootAim, nestedAim)
print(string.format("[WYV-AIM-AUDIT][CLIENT] rootAim=%s nestedAim=%s SAME_TABLE=%s errors=%s | %s",
    tostring(canonical and canonical:GetFullName()), tostring(nested and nested:GetFullName()),
    tostring(oneAim), tostring(rootErr), tostring(nestedErr)))

local scripts = player:FindFirstChild("PlayerScripts")
local wyvScripts = scripts and scripts:FindFirstChild("WyvernFlightV2")
if wyvScripts then
    for _, s in ipairs(wyvScripts:GetDescendants()) do
        if s:IsA("LocalScript") then
            print("[WYV-AIM-AUDIT][SCRIPT]", s:GetFullName(), "Disabled=", s.Disabled)
        end
    end
end

local lastRawMouseEvent = -100
local rawX, rawY, rawCount = 0, 0, 0
UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        rawX += input.Delta.X
        rawY += input.Delta.Y
        rawCount += 1
        lastRawMouseEvent = os.clock()
    end
end)

local function deg(v)
    return type(v) == "number" and math.deg(v) or -999
end
local function fmt(v)
    return type(v) == "number" and string.format("%.3f", v) or tostring(v)
end
local function yaw(cf)
    local f = cf.LookVector
    return math.deg(math.atan2(-f.X, -f.Z))
end
local timer = 0
RunService.RenderStepped:Connect(function(dt)
    timer += dt
    if timer < 0.20 then return end
    timer = 0
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local mode = tostring(root:GetAttribute("Wyvern_MotionState"))
    local userAim = rootAim
    local nestedA = nestedAim
    local elapsed = os.clock() - lastRawMouseEvent
    local s = string.format(
      "[WYV-AIM-AUDIT][CLIENT] mode=%s mouseBehavior=%s rawEvents=%d rawDelta=(%.1f,%.1f) recent=%.2fs " ..
      "rootAimYaw=%.1f nestedAimYaw=%.1f rootIntent=%s nestedIntent=%s " ..
      "cameraYaw=%.1f bodyYaw=%.1f aimServer=%s finalTurn=%s yawRate=%s cameraType=%s",
      mode, tostring(UserInputService.MouseBehavior), rawCount, rawX, rawY, elapsed,
      userAim and deg(userAim.playerAimYaw) or -999,
      nestedA and deg(nestedA.playerAimYaw) or -999,
      userAim and fmt(userAim.aimTurnIntent) or "nil",
      nestedA and fmt(nestedA.aimTurnIntent) or "nil",
      yaw(camera.CFrame), yaw(root.CFrame),
      tostring(root:GetAttribute("Flight_AimTurnIntent")),
      tostring(root:GetAttribute("Flight_FinalTurnIntent")),
      tostring(root:GetAttribute("Flight_YawRate")), tostring(camera.CameraType))
    print(s)
    rawX, rawY, rawCount = 0, 0, 0
end)
