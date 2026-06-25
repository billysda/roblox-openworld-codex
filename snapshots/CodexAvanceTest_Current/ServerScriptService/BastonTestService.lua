local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local BASTON_RANGE = 35 -- Alcance del viento en studs
local BASTON_ANGLE_DEG = 60 -- Amplitud del cono de presión (grados)
local SHEEP_FOLDER_NAME = "SheepRuntime" -- Carpeta oficial de ovejas del proyecto

local activeShepherds = {} -- Diccionario de jugadores usando el bastón

-- 1. Crear comunicación segura cliente-servidor
local RS = game:GetService("ReplicatedStorage")
local remoteFolder = RS:FindFirstChild("BastonRemotes")
if not remoteFolder then
	remoteFolder = Instance.new("Folder")
	remoteFolder.Name = "BastonRemotes"
	remoteFolder.Parent = RS
end

local actionRemote = remoteFolder:FindFirstChild("Action")
if not actionRemote then
	actionRemote = Instance.new("RemoteEvent")
	actionRemote.Name = "Action"
	actionRemote.Parent = remoteFolder
end

-- 2. Escuchar cuando el jugador levanta/baja el bastón
actionRemote.OnServerEvent:Connect(function(player, isActive)
	if typeof(isActive) == "boolean" then
		activeShepherds[player] = isActive
	end
end)

Players.PlayerRemoving:Connect(function(player)
	activeShepherds[player] = nil
end)

-- 3. Loop principal: Cono de Presión (Se ejecuta suavemente sin físicas rígidas)
RunService.Heartbeat:Connect(function()
	local sheepFolder = workspace:FindFirstChild(SHEEP_FOLDER_NAME)
	if not sheepFolder then return end

	for player, isActive in pairs(activeShepherds) do
		if isActive and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local rootPart = player.Character.HumanoidRootPart
			local origin = rootPart.Position
			
			-- Dirección hacia donde mira el pastor, ignorando el eje Y (para no empujar al cielo)
			local lookDir = rootPart.CFrame.LookVector
			lookDir = Vector3.new(lookDir.X, 0, lookDir.Z).Unit 

			-- Buscar qué ovejas están dentro de la ráfaga de aire
			for _, sheepModel in ipairs(sheepFolder:GetChildren()) do
				if sheepModel.PrimaryPart and sheepModel:FindFirstChild("Humanoid") then
					local humanoid = sheepModel.Humanoid
					local sheepPos = sheepModel.PrimaryPart.Position
					
					local vecToSheep = sheepPos - origin
					local flatVec = Vector3.new(vecToSheep.X, 0, vecToSheep.Z)
					local distance = flatVec.Magnitude

					if distance > 0 and distance <= BASTON_RANGE then
						local dirToSheep = flatVec.Unit
						local dotProduct = lookDir:Dot(dirToSheep)
						local angleDeg = math.deg(math.acos(math.clamp(dotProduct, -1, 1)))

						-- Si está dentro del abanico frontal (Cono)
						if angleDeg <= (BASTON_ANGLE_DEG / 2) then
							-- PLAN C: Calcular ruta de escape (alejarse del pastor)
							local fleeDirection = dirToSheep
							local targetPos = sheepPos + (fleeDirection * 12) -- Distancia de escape
							
							-- Forzar el movimiento natural de Roblox (sobrescribe la IA base temporalmente)
							humanoid:MoveTo(targetPos)
						end
					end
				end
			end
		end
	end
end)
