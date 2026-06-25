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

RunService.Heartbeat:Connect(function()
local sheepFolder = workspace:FindFirstChild(SHEEP_FOLDER_NAME)
if not sheepFolder then return end

local now = os.clock()

for player, isActive in pairs(activeShepherds) do
    if isActive and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local rootPart = player.Character.HumanoidRootPart
        local origin = rootPart.Position
        local lookDir = rootPart.CFrame.LookVector
        lookDir = Vector3.new(lookDir.X, 0, lookDir.Z).Unit

        local function applyBaston(sheepModel)
            if sheepModel:IsA("Model") then
                local root = sheepModel:FindFirstChild("HumanoidRootPart")
                if root then
                    local sheepPos = root.Position
                    local vecToSheep = sheepPos - origin
                    local flatVec = Vector3.new(vecToSheep.X, 0, vecToSheep.Z)
                    local distance = flatVec.Magnitude

                    if distance > 0 and distance <= BASTON_RANGE then
                        local dirToSheep = flatVec.Unit
                        local dotProduct = lookDir:Dot(dirToSheep)
                        local angleDeg = math.deg(math.acos(math.clamp(dotProduct, -1, 1)))

                        if angleDeg <= (BASTON_ANGLE_DEG / 2) then
                            local currentSpook = sheepModel:GetAttribute("BastonSpookTime") or 0
                            
                            if now >= currentSpook then
                                sheepModel:SetAttribute("BastonFleeDir", dirToSheep)
                            end
                            
                            sheepModel:SetAttribute("BastonSpookTime", now + 4.5)
                        end
                    end
                end
            end
        end

        for _, child in ipairs(sheepFolder:GetChildren()) do
            if child:IsA("Folder") then
                for _, s in ipairs(child:GetChildren()) do applyBaston(s) end
            else
                applyBaston(child)
            end
        end
    end
end
end)
