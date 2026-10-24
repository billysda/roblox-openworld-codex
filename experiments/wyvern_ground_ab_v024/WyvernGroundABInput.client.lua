-- WyvernGroundABInput.client.lua
-- Studio-only pilot and follow camera for the ISOLATED wyvern clone.
-- Does not require or replace FlightAimState, R4.2 FlightCamera or production Input.
-- In the disposable test Place, disable the original FlightCamera and Input
-- temporarily to avoid competing CameraType and user controls.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")
local ReplicatedStorage=game:GetService("ReplicatedStorage")

if not RunService:IsStudio() then return end
local player=Players.LocalPlayer
local clone=Workspace:WaitForChild("WyvernGroundAB_TestClone",10)
local remote=ReplicatedStorage:WaitForChild("WyvernGroundABInput",10)
if not(clone and remote) then
    warn("[WYV-AB][CLIENT] Harness not enabled. No pilot camera attached.")
    return
end
local root=clone:WaitForChild("DT_Root",10)
if not root then return end

local gui=Instance.new("ScreenGui")
gui.Name="WyvernGroundAB_HUD"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.Parent=player:WaitForChild("PlayerGui")
local box=Instance.new("TextLabel")
box.BackgroundColor3=Color3.fromRGB(10,19,29)
box.BackgroundTransparency=0.22
box.TextColor3=Color3.fromRGB(237,241,246)
box.TextSize=15
box.Font=Enum.Font.Code
box.TextXAlignment=Enum.TextXAlignment.Left
box.TextYAlignment=Enum.TextYAlignment.Top
box.Position=UDim2.fromOffset(14,70)
box.Size=UDim2.fromOffset(560,100)
box.Parent=gui

local camera=Workspace.CurrentCamera
local oldCameraType=camera.CameraType
local oldCameraSubject=camera.CameraSubject
camera.CameraType=Enum.CameraType.Scriptable
UIS.MouseBehavior=Enum.MouseBehavior.Default

local cameraPos=root.Position+Vector3.new(0,15,40)
local sendElapsed=0
local currentMode=clone:WaitForChild("DT_Root"):GetAttribute("WyvernAB_Mode")
local active=true
script.Destroying:Connect(function()
    active=false
    if camera then
        camera.CameraType=oldCameraType
        camera.CameraSubject=oldCameraSubject
    end
    gui:Destroy()
end)

RunService:BindToRenderStep("WyvernAB_Follow",Enum.RenderPriority.Camera.Value+10,function(dt)
    if not active or not root.Parent then return end
    local w=UIS:IsKeyDown(Enum.KeyCode.W)
    local shift=UIS:IsKeyDown(Enum.KeyCode.LeftShift)
        or UIS:IsKeyDown(Enum.KeyCode.RightShift)
    local turn=(UIS:IsKeyDown(Enum.KeyCode.D) and 1 or 0)-
        (UIS:IsKeyDown(Enum.KeyCode.A) and 1 or 0)

    sendElapsed+=dt
    if sendElapsed >= 1/20 then
        sendElapsed=0
        remote:FireServer({w=w,shift=shift,turn=turn})
    end

    local speed=root.AssemblyLinearVelocity
    local horizontal=Vector3.new(speed.X,0,speed.Z).Magnitude
    local f=root.CFrame.LookVector
    local flat=Vector3.new(f.X,0,f.Z)
    if flat.Magnitude<0.01 then flat=Vector3.new(0,0,-1) end
    flat=flat.Unit

    local target=root.Position+Vector3.new(0,4,0)
    local desired=target-flat*35+Vector3.new(0,13,0)
    local smoothing=1-math.exp(-5*math.clamp(dt,0,0.1))
    cameraPos=cameraPos:Lerp(desired,smoothing)
    camera.CFrame=CFrame.lookAt(cameraPos,target)
    camera.FieldOfView=76

    box.Text=string.format(
        "GRAN WYVERN — TEST A/B (COPIA DE STUDIO)\n"..
        "MODO: %s  |  W correr  |  Shift+W sprint  |  A/D girar\n"..
        "Objetivo: subir 10 / 20 / 30 grados y cruzar la cresta.\n"..
        "Pos Z: %.1f    Altura Y: %.1f    Velocidad horizontal: %.1f studs/s",
        tostring(currentMode),root.Position.Z,root.Position.Y,horizontal)
end)
