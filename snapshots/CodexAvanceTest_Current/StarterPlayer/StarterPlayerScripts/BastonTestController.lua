local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

-- Buscar los remotos con límite de tiempo para no colgar el cliente
local remoteFolder = RS:WaitForChild("BastonRemotes", 10)
local actionRemote = remoteFolder and remoteFolder:WaitForChild("Action", 10)

local isHerding = false

local function updateHerdingState(state)
	if isHerding ~= state then
		isHerding = state
		if actionRemote then
			actionRemote:FireServer(isHerding)
		end
	end
end

-- Detectar cuando se usa una herramienta llamada "Baston"
player.CharacterAdded:Connect(function(char)
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and (child.Name == "Baston" or child.Name == "Staff") then
			child.Activated:Connect(function()
				updateHerdingState(true) -- Inicia la ráfaga de aire
			end)
			child.Deactivated:Connect(function()
				updateHerdingState(false) -- Detiene la ráfaga
			end)
		end
	end)
	
	char.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and (child.Name == "Baston" or child.Name == "Staff") then
			updateHerdingState(false) -- Por si se desequipa o guarda en Storage
		end
	end)
end)
