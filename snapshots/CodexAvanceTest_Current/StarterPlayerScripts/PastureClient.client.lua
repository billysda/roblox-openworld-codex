local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local remoteFolder = ReplicatedStorage:WaitForChild("PastureRemote")
local whistleEvent = remoteFolder:WaitForChild("Whistle")
local commandTargetEvent = remoteFolder:WaitForChild("CommandTarget", 10)

if not commandTargetEvent then
	warn("[PastureClient] CommandTarget remote no encontrado; F sigue disponible.")
end

local marker = nil

local function getMouseGroundPosition()
	local mouse = player:GetMouse()
	local ray = mouse.UnitRay
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true

	if player.Character then
		params.FilterDescendantsInstances = { player.Character }
	end

	local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	if result then
		return result.Position
	end

	return nil
end

local function showMarker(position)
	if marker then
		marker:Destroy()
	end

	marker = Instance.new("Part")
	marker.Name = "PastureCommandTargetMarker"
	marker.Shape = Enum.PartType.Cylinder
	marker.Size = Vector3.new(0.15, 4, 4)
	marker.CFrame = CFrame.new(position + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.Material = Enum.Material.Neon
	marker.Color = Color3.fromRGB(80, 220, 120)
	marker.Transparency = 0.25
	marker.Parent = Workspace

	Debris:AddItem(marker, 2)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.F then
		whistleEvent:FireServer()
	elseif input.KeyCode == Enum.KeyCode.G and commandTargetEvent then
		local position = getMouseGroundPosition()
		if position then
			showMarker(position)
			commandTargetEvent:FireServer(position)
		end
	end
end)
