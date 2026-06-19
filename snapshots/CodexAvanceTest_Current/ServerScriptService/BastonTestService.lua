local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPack = game:GetService("StarterPack")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Pasture = ServerScriptService:WaitForChild("Pasture")
local M = Pasture:WaitForChild("M")
local Cfg = require(M:WaitForChild("Cfg"))

local CONFIG = {
	LineLength = 14,
	Band = 10,
	PushSpeed = 12,
	Duration = 3,
	Cooldown = 0.5
}

-- 1) Generar Tool
local tool = Instance.new("Tool")
tool.Name = "BastonTest"
tool.RequiresHandle = false
tool.CanBeDropped = false
tool:SetAttribute("SetupGenerated", true)
tool.Parent = StarterPack

for _, player in ipairs(game.Players:GetPlayers()) do
	local clone = tool:Clone()
	clone.Parent = player:FindFirstChild("Backpack")
end

local remote = Instance.new("RemoteEvent")
remote.Name = "BastonTestRemote"
remote.Parent = ReplicatedStorage

local cooldowns = {}

remote.OnServerEvent:Connect(function(player, p1, p2)
	local now = os.clock()
	if cooldowns[player] and now - cooldowns[player] < CONFIG.Cooldown then
		return
	end
	cooldowns[player] = now

	-- Dibujar linea roja
	local line = Instance.new("Part")
	line.Name = "BastonLine"
	line.Color = Color3.fromRGB(255, 0, 0)
	line.Material = Enum.Material.Neon
	line.Anchored = true
	line.CanCollide = false
	line.Size = Vector3.new(0.3, 0.3, CONFIG.LineLength)
	
	local center = (p1 + p2) / 2
	line.CFrame = CFrame.lookAt(center, p2) + Vector3.new(0, 0.2, 0)
	line.Parent = workspace

	Debris:AddItem(line, CONFIG.Duration)
	
	-- Loop activo de 3 segundos
	local startTime = os.clock()
	local connection
	
	connection = RunService.Heartbeat:Connect(function(dt)
		if os.clock() - startTime >= CONFIG.Duration then
			connection:Disconnect()
			return
		end
		
		local runtime = workspace:FindFirstChild(Cfg.Names.Runtime)
		if not runtime then return end
		
		for _, folder in ipairs(runtime:GetChildren()) do
			if string.find(folder.Name, "Flock_") then
				for _, sheep in ipairs(folder:GetChildren()) do
					local root = sheep:FindFirstChild("HumanoidRootPart")
					if root then
						local a = Vector3.new(p1.X, 0, p1.Z)
						local b = Vector3.new(p2.X, 0, p2.Z)
						local p = Vector3.new(root.Position.X, 0, root.Position.Z)
						
						local ab = b - a
						local ap = p - a
						
						local t = ap:Dot(ab) / ab:Dot(ab)
						t = math.clamp(t, 0, 1)
						
						local closest = a + t * ab
						local dist = (p - closest).Magnitude
						
						if dist <= CONFIG.Band then
							local dir = (p - closest)
							if dir.Magnitude > 0.001 then
								dir = dir.Unit
							else
								dir = Vector3.new(-ab.Z, 0, ab.X).Unit
							end
							
							local currentVel = root.AssemblyLinearVelocity
							root.AssemblyLinearVelocity = Vector3.new(dir.X * CONFIG.PushSpeed, currentVel.Y, dir.Z * CONFIG.PushSpeed)
						end
					end
				end
			end
		end
	end)
end)
