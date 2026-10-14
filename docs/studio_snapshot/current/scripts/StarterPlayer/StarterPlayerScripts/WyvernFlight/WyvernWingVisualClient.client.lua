-- WyvernWingVisualClient.client.lua
-- Controlador cliente de animación procedural de alas (Fase 5C.1)
-- Vinculado a RenderStepped para suavidad visual de 60+ FPS sin costo en servidor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local wyvernFlightFolder = ReplicatedStorage:WaitForChild("WyvernFlight", 10)
if not wyvernFlightFolder then return end

local kinematicsFolder = wyvernFlightFolder:WaitForChild("Kinematics", 10)
if not kinematicsFolder then return end

local WyvernWingKinematics = require(kinematicsFolder:WaitForChild("WyvernWingKinematics"))

local wyvern = Workspace:WaitForChild("wyvernfbx", 10) or Workspace:WaitForChild("DragonTierraRoblox", 10)
if not wyvern then return end

local wingKinematics = WyvernWingKinematics.new(wyvern)

RunService.RenderStepped:Connect(function(dt)
	wingKinematics:update(dt)
end)
