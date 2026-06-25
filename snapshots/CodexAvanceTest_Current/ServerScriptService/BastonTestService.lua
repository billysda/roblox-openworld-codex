local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local BASTON_RANGE = 35
local BASTON_ANGLE_DEG = 60
local SHEEP_FOLDER_NAME = "SheepRuntime"

local activeShepherds = {}

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

actionRemote.OnServerEvent:Connect(function(player, isActive)
	if typeof(isActive) == "boolean" then
		activeShepherds[player] = isActive
	end
end)

Players.PlayerRemoving:Connect(function(player)
	activeShepherds[player] = nil
end)

local function applyHerding(sheepModel, origin, lookDir)
	-- FIX: Se eliminó la dependencia de Humanoid. Se busca el HumanoidRootPart y sus físicas.
	if sheepModel:IsA("Model") then
		local root = sheepModel:FindFirstChild("HumanoidRootPart")
		if root then
			local linVel = root:FindFirstChild("LinearVelocity")
			local alignOri = root:FindFirstChild("AlignOrientation")
			
			if linVel and alignOri then
				local sheepPos = root.Position
				local vecToSheep = sheepPos - origin
				local flatVec = Vector3.new(vecToSheep.X, 0, vecToSheep.Z)
				local distance = flatVec.Magnitude

				if distance > 0 and distance <= BASTON_RANGE then
					local dirToSheep = flatVec.Unit
					local dotProduct = lookDir:Dot(dirToSheep)
					local angleDeg = math.deg(math.acos(math.clamp(dotProduct, -1, 1)))

					if angleDeg <= (BASTON_ANGLE_DEG / 2) then
						local fleeDirection = dirToSheep
						
						-- Sobrescribimos la física de la oveja de forma segura
						linVel.VectorVelocity = fleeDirection * 22 -- Velocidad de escape
						alignOri.CFrame = CFrame.lookAt(Vector3.zero, fleeDirection, Vector3.yAxis)
					end
				end
			end
		end
	end
end

-- Usamos Stepped para ejecutar después de la IA de la oveja pero antes de que rendericen las físicas
RunService.Stepped:Connect(function()
	local sheepFolder = workspace:FindFirstChild(SHEEP_FOLDER_NAME)
	if not sheepFolder then return end

	for player, isActive in pairs(activeShepherds) do
		if isActive and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local rootPart = player.Character.HumanoidRootPart
			local origin = rootPart.Position
			
			local lookDir = rootPart.CFrame.LookVector
			lookDir = Vector3.new(lookDir.X, 0, lookDir.Z).Unit 

			-- FIX: Iteración correcta de carpetas de rebaños (Flocks)
			for _, child in ipairs(sheepFolder:GetChildren()) do
				if child:IsA("Folder") then
					for _, sheepModel in ipairs(child:GetChildren()) do
						applyHerding(sheepModel, origin, lookDir)
					end
				else
					applyHerding(child, origin, lookDir)
				end
			end
		end
	end
end)
