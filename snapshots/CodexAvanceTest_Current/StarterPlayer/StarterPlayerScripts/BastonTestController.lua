local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local CONFIG = {
	LineLength = 14
}

local function getRemote()
	return ReplicatedStorage:WaitForChild("BastonTestRemote", 5)
end

local function onActivated()
	local character = player.Character
	if not character then return end
	
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	
	local mouse = player:GetMouse()
	local ray = workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {character}
	
	local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
	local P
	if result then
		P = result.Position
	else
		P = mouse.Hit.Position
	end
	
	local toP = P - root.Position
	local dir = Vector3.new(toP.X, 0, toP.Z)
	if dir.Magnitude < 0.001 then return end
	dir = dir.Unit
	
	local perp = Vector3.new(-dir.Z, 0, dir.X).Unit
	local halfLen = CONFIG.LineLength / 2
	local p1 = P + perp * halfLen
	local p2 = P - perp * halfLen
	
	local remote = getRemote()
	if remote then
		remote:FireServer(p1, p2)
	end
end

local function setupCharacter(char)
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == "BastonTest" then
			child.Activated:Connect(onActivated)
		end
	end)
end

player.CharacterAdded:Connect(setupCharacter)

if player.Character then
	setupCharacter(player.Character)
	local tool = player.Character:FindFirstChild("BastonTest")
	if tool then
		tool.Activated:Connect(onActivated)
	end
end
