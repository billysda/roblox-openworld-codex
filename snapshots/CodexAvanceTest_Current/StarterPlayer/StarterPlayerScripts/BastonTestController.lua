--[[
	BastonTestController.client.lua  (PROTOTIPO - Etapa 1)
	Apunta con el mouse, calcula una linea perpendicular centrada en el punto
	de mira y la envia al server. Conecta Activated una sola vez por tool.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local CONFIG = {
	LineLength = 14,
}

local remote = ReplicatedStorage:WaitForChild("BastonTestRemote", 10)

local function onActivated()
	if not remote then return end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local mouse = player:GetMouse()
	local camera = workspace.CurrentCamera
	local P

	if camera then
		local ray = camera:ScreenPointToRay(mouse.X, mouse.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
		P = result and result.Position or mouse.Hit.Position
	else
		P = mouse.Hit.Position
	end

	local toP = Vector3.new(P.X - root.Position.X, 0, P.Z - root.Position.Z)
	if toP.Magnitude < 0.001 then return end
	local dir = toP.Unit

	-- linea perpendicular a la direccion de mira, centrada en P
	local perp = Vector3.new(-dir.Z, 0, dir.X).Unit
	local half = CONFIG.LineLength / 2
	local p1 = Vector3.new(P.X, P.Y, P.Z) + perp * half
	local p2 = Vector3.new(P.X, P.Y, P.Z) - perp * half

	remote:FireServer(p1, p2)
end

-- Conectar Activated una sola vez por tool (evita conexiones duplicadas).
local function hookTool(tool)
	if tool:GetAttribute("BastonHooked") then return end
	tool:SetAttribute("BastonHooked", true)
	tool.Activated:Connect(onActivated)
end

local function scan(container)
	if not container then return end
	local existing = container:FindFirstChild("BastonTest")
	if existing and existing:IsA("Tool") then hookTool(existing) end
	container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == "BastonTest" then
			hookTool(child)
		end
	end)
end

-- Buscar la tool tanto en el personaje (equipada) como en la mochila.
player.CharacterAdded:Connect(function(char) scan(char) end)
if player.Character then scan(player.Character) end

scan(player:FindFirstChildOfClass("Backpack"))
player.ChildAdded:Connect(function(child)
	if child:IsA("Backpack") then scan(child) end
end)
