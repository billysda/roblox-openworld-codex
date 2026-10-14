-- Pasture Stats Client v1.1
-- P = pedir stats al servidor
-- Shift + P = pedir validación al servidor

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remoteFolder = ReplicatedStorage:WaitForChild("PastureRemote")
local requestStats = remoteFolder:WaitForChild("RequestStats")
local statsResponse = remoteFolder:WaitForChild("StatsResponse")

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.P then
		local shiftDown = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)

		if shiftDown then
			requestStats:FireServer("validate")
		else
			requestStats:FireServer("stats")
		end
	end
end)

statsResponse.OnClientEvent:Connect(function(text)
	print(text)
end)
