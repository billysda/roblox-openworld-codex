local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local remoteFolder = RS:WaitForChild("BastonRemotes", 10)
local actionRemote = remoteFolder and remoteFolder:WaitForChild("Action", 10)

player.CharacterAdded:Connect(function(char)
char.ChildAdded:Connect(function(child)
if child:IsA("Tool") and (child.Name == "Baston" or child.Name == "Staff") then
child.Activated:Connect(function()
print("[🪄 CLIENTE] Clic detectado. Enviando señal al servidor...")
if actionRemote then actionRemote:FireServer(true) end
end)
end
end)
end)
