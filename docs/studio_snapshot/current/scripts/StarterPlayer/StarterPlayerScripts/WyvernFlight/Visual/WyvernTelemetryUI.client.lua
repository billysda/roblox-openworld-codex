-- WyvernTelemetryUI.client.lua
-- HUD de Telemetría Completa y Control Rotacional Físico (Fase 3A)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = playerGui:FindFirstChild("WyvernAeroTelemetryUI")
if screenGui then screenGui:Destroy() end

screenGui = Instance.new("ScreenGui")
screenGui.Name = "WyvernAeroTelemetryUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Marco Principal
local frame = Instance.new("Frame")
frame.Name = "TelemetryPanel"
frame.Size = UDim2.new(0, 360, 0, 460)
frame.Position = UDim2.new(0, 20, 0, 30)
frame.BackgroundColor3 = Color3.fromRGB(12, 16, 24)
frame.BackgroundTransparency = 0.12
frame.BorderSizePixel = 0
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(0, 210, 255)
stroke.Thickness = 1.5
stroke.Parent = frame

-- Título
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -20, 0, 24)
title.Position = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1
title.Text = "WYVERN ROTATIONAL & AERO HUD [FASE 3A]"
title.TextColor3 = Color3.fromRGB(0, 230, 255)
title.TextSize = 12
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

-- Badge de Estado de Stall
local stallBadge = Instance.new("TextLabel")
stallBadge.Name = "StallBadge"
stallBadge.Size = UDim2.new(0, 100, 0, 20)
stallBadge.Position = UDim2.new(1, -110, 0, 8)
stallBadge.BackgroundColor3 = Color3.fromRGB(30, 180, 80)
stallBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
stallBadge.TextSize = 10
stallBadge.Font = Enum.Font.GothamBold
stallBadge.Text = "NORMAL"
stallBadge.Parent = frame

local badgeCorner = Instance.new("UICorner")
badgeCorner.CornerRadius = UDim.new(0, 4)
badgeCorner.Parent = stallBadge

-- Lista de Labels
local metricNames = {
	"Stage", "Airspeed", "AoA", "Lift", "Drag", "LWRatio",
	"Torques", "Attitude", "GlobalAngVel", "LocalAngVel", "Velocity3D"
}

local labels = {}
for i, name in ipairs(metricNames) do
	local lbl = Instance.new("TextLabel")
	lbl.Name = name
	lbl.Size = UDim2.new(1, -20, 0, 19)
	lbl.Position = UDim2.new(0, 10, 0, 34 + (i - 1) * 22)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = Color3.fromRGB(220, 230, 245)
	lbl.TextSize = 11
	lbl.Font = Enum.Font.RobotoMono
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = name .. ": --"
	lbl.Parent = frame
	labels[name] = lbl
end

-- Panel de Ayuda de Teclas
local helpFrame = Instance.new("Frame")
helpFrame.Name = "HelpPanel"
helpFrame.Size = UDim2.new(1, -16, 0, 95)
helpFrame.Position = UDim2.new(0, 8, 1, -102)
helpFrame.BackgroundColor3 = Color3.fromRGB(18, 24, 36)
helpFrame.BackgroundTransparency = 0.3
helpFrame.BorderSizePixel = 0
helpFrame.Parent = frame

local helpCorner = Instance.new("UICorner")
helpCorner.CornerRadius = UDim.new(0, 6)
helpCorner.Parent = helpFrame

local helpText = Instance.new("TextLabel")
helpText.Size = UDim2.new(1, -12, 1, -8)
helpText.Position = UDim2.new(0, 6, 0, 4)
helpText.BackgroundTransparency = 1
helpText.TextColor3 = Color3.fromRGB(180, 205, 230)
helpText.TextSize = 10
helpText.Font = Enum.Font.GothamMedium
helpText.TextXAlignment = Enum.TextXAlignment.Left
helpText.TextYAlignment = Enum.TextYAlignment.Top
helpText.Text = "CONTROL ROTACIONAL FÍSICO (TORQUE PURO):\n[I / K] = Pitch Up (Nariz Arriba) / Pitch Down (Abajo)\n[J / L] = Roll Left (Alabeo Izq) / Roll Right (Der)\n[U / O] = Yaw Left (Guiñada Izq) / Yaw Right (Der)\n[G] = Lanzar Planeo (80 st/s)  |  [R] = Reset  |  [C] = Cámara"
helpText.Parent = helpFrame

-- Bucle de actualización en RenderStepped
local wyvern = Workspace:FindFirstChild("wyvernfbx") or Workspace:FindFirstChild("DragonTierraRoblox")
local dtRoot = wyvern and wyvern:FindFirstChild("DT_Root")

RunService.RenderStepped:Connect(function()
	if not wyvern or not dtRoot or not dtRoot.Parent then
		wyvern = Workspace:FindFirstChild("wyvernfbx") or Workspace:FindFirstChild("DragonTierraRoblox")
		dtRoot = wyvern and wyvern:FindFirstChild("DT_Root")
		return
	end

	local stage = dtRoot:GetAttribute("Aero_Stage") or "STANDBY"
	local speed = dtRoot:GetAttribute("Aero_Speed") or 0
	local aoa = dtRoot:GetAttribute("Aero_AoA") or 0
	local lift = dtRoot:GetAttribute("Aero_Lift") or 0
	local drag = dtRoot:GetAttribute("Aero_Drag") or 0
	local lw = dtRoot:GetAttribute("Aero_LWRatio") or 0

	local pTorque = dtRoot:GetAttribute("Aero_PitchTorque") or 0
	local rTorque = dtRoot:GetAttribute("Aero_RollTorque") or 0
	local yTorque = dtRoot:GetAttribute("Aero_YawTorque") or 0

	local rootCF = dtRoot.CFrame
	local rx, ry, rz = rootCF:ToOrientation()
	local pitchDeg = math.deg(rx)
	local yawDeg = math.deg(ry)
	local rollDeg = math.deg(rz)

	local globAngVel = dtRoot.AssemblyAngularVelocity
	local locAngVel = rootCF:VectorToObjectSpace(globAngVel)
	local linVel = dtRoot.AssemblyLinearVelocity

	if aoa >= 16.0 then
		stallBadge.Text = "STALL"
		stallBadge.BackgroundColor3 = Color3.fromRGB(220, 40, 40)
	elseif aoa >= 12.0 then
		stallBadge.Text = "NEAR STALL"
		stallBadge.BackgroundColor3 = Color3.fromRGB(240, 180, 30)
	else
		stallBadge.Text = "NORMAL"
		stallBadge.BackgroundColor3 = Color3.fromRGB(30, 180, 80)
	end

	labels["Stage"].Text = string.format("MODO: %s", stage)
	labels["Airspeed"].Text = string.format("AIRSPEED: %.1f st/s", speed)
	labels["AoA"].Text = string.format("ANGLE OF ATTACK: %.1f°", aoa)
	labels["Lift"].Text = string.format("LIFT: %.1f N", lift)
	labels["Drag"].Text = string.format("DRAG: %.1f N", drag)
	labels["LWRatio"].Text = string.format("LIFT/WEIGHT RATIO: %.2f (Peso=26369N)", lw)
	labels["Torques"].Text = string.format("TORQUE: P:%.0f | R:%.0f | Y:%.0f N*st", pTorque, rTorque, yTorque)
	labels["Attitude"].Text = string.format("ATTITUDE: P:%.1f° | R:%.1f° | Y:%.1f°", pitchDeg, rollDeg, yawDeg)
	labels["GlobalAngVel"].Text = string.format("GLOBAL ω: (%.2f, %.2f, %.2f) rad/s", globAngVel.X, globAngVel.Y, globAngVel.Z)
	labels["LocalAngVel"].Text = string.format("LOCAL ω:  (%.2f, %.2f, %.2f) rad/s", locAngVel.X, locAngVel.Y, locAngVel.Z)
	labels["Velocity3D"].Text = string.format("VELOCIDAD: (Vx:%.1f, Vy:%.1f, Vz:%.1f)", linVel.X, linVel.Y, linVel.Z)
end)
