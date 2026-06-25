local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local BASTON_RANGE = 50
local BASTON_ANGLE_DEG = 90
local SHEEP_FOLDER_NAME = "SheepRuntime"

local remoteFolder = RS:FindFirstChild("BastonRemotes") or Instance.new("Folder")
remoteFolder.Name = "BastonRemotes"
remoteFolder.Parent = RS

local actionRemote = remoteFolder:FindFirstChild("Action") or Instance.new("RemoteEvent")
actionRemote.Name = "Action"
actionRemote.Parent = remoteFolder

actionRemote.OnServerEvent:Connect(function(player, isActive)
if not isActive then return end

print("<font color='rgb(0, 255, 255)'>[🪄 SERVIDOR] " .. player.Name .. " usó el bastón. Calculando área...</font>")

local character = player.Character
if not character then return end
local rootPart = character:FindFirstChild("HumanoidRootPart")
if not rootPart then return end

local sheepFolder = workspace:FindFirstChild(SHEEP_FOLDER_NAME)
if not sheepFolder then
    warn("<font color='rgb(255, 0, 0)'>[🔴 ERROR] Carpeta SheepRuntime no encontrada.</font>")
    return
end

local origin = rootPart.Position
local lookDir = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z).Unit
local now = os.clock()
local afectadas = 0

local function applyBaston(sheepModel)
    if sheepModel:IsA("Model") and sheepModel:FindFirstChild("HumanoidRootPart") then
        local sRoot = sheepModel.HumanoidRootPart
        local vecToSheep = sRoot.Position - origin
        local flatVec = Vector3.new(vecToSheep.X, 0, vecToSheep.Z)
        local distance = flatVec.Magnitude

        if distance > 0 and distance <= BASTON_RANGE then
            local dirToSheep = flatVec.Unit
            local dotProduct = lookDir:Dot(dirToSheep)
            local angleDeg = math.deg(math.acos(math.clamp(dotProduct, -1, 1)))

            if angleDeg <= (BASTON_ANGLE_DEG / 2) then
                sheepModel:SetAttribute("BastonFleeDir", dirToSheep)
                sheepModel:SetAttribute("BastonSpookTime", now + 3.0)
                afectadas = afectadas + 1
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

if afectadas > 0 then
    print("<font color='rgb(0, 255, 0)'>[🟢 ÉXITO] Ovejas espantadas: " .. tostring(afectadas) .. "</font>")
else
    print("<font color='rgb(255, 128, 0)'>[🟠 AVISO] Ninguna oveja en el rango de 50 studs y 90 grados.</font>")
end
end)
