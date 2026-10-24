-- WyvernMouseAudit.server.lua
-- DIAGNOSTICO READ-ONLY para comprobar que los paquetes del mouse llegan al servidor.
-- Instalar SOLO temporalmente junto al controlador, en copia aislada.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local wyv = Workspace:WaitForChild("wyvernfbx", 15)
local root = wyv and wyv:WaitForChild("DT_Root", 10)
local folder = ReplicatedStorage:WaitForChild("WyvernFlightV2", 10)
local remotes = folder and folder:WaitForChild("Remotes", 10)
local flightInput = remotes and remotes:WaitForChild("FlightInput", 10)
if not(root and flightInput) then
    warn("[WYV-AIM-AUDIT][SERVER] No se encontró DT_Root o FlightInput.")
    return
end

local latest
local lastStamp = 0
flightInput.OnServerEvent:Connect(function(player, packet)
    if type(packet) ~= "table" then return end
    latest = {name=player.Name, turn=packet.turn, aimTurn=packet.aimTurn,
        aimPitch=packet.aimPitch, yawError=packet.aimYawError, pitchError=packet.aimPitchError}
    lastStamp = os.clock()
end)

local acc = 0
RunService.Heartbeat:Connect(function(dt)
    acc += dt
    if acc < 0.20 then return end
    acc = 0
    if not latest then return end
    print(string.format(
        "[WYV-AIM-AUDIT][SERVER] player=%s age=%.2fs mode=%s "..
        "packetTurn=%s packetAimTurn=%s packetAimPitch=%s yawError=%s pitchError=%s "..
        "serverIntent=%s finalTurn=%s yawRate=%s heading=%s",
        latest.name, os.clock()-lastStamp,
        tostring(root:GetAttribute("Wyvern_MotionState")),
        tostring(latest.turn),tostring(latest.aimTurn), tostring(latest.aimPitch),
        tostring(latest.yawError), tostring(latest.pitchError),
        tostring(root:GetAttribute("Flight_AimTurnIntent")),
        tostring(root:GetAttribute("Flight_FinalTurnIntent")),
        tostring(root:GetAttribute("Flight_YawRate")),
        tostring(root:GetAttribute("Flight_Heading"))))
end)
