--[[
	BastonTestService.lua  (PROTOTIPO - Etapa 1)
	"Baston de pastor": prueba de una linea ROJA que el jugador apunta, dura 3s
	y empuja a SUS ovejas hacia el lado contrario.

	ADITIVO: NO modifica Pasture/Flock/Sheep. Solo lee Cfg (nombres) y escribe
	temporalmente en el constraint LinearVelocity que la oveja YA usa para que el
	empuje sea VISIBLE. (Setear AssemblyLinearVelocity no sirve: el constraint
	LinearVelocity con MaxAxesForce 100000 en XZ lo sobrescribe.)

	Etapa 2 (futuro, con autorizacion): integrar como fuente de amenaza dentro
	de Flock.lua para un arreo suave por steering.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPack = game:GetService("StarterPack")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Pasture = ServerScriptService:WaitForChild("Pasture")
local M = Pasture:WaitForChild("M")
local Cfg = require(M:WaitForChild("Cfg"))

local CONFIG = {
	LineLength  = 14,   -- largo de la linea (studs)
	Band        = 10,   -- ancho de influencia a cada lado de la linea
	PushSpeed   = 12,   -- velocidad horizontal del empuje
	Duration    = 3,    -- segundos que vive la linea y el empuje
	Cooldown    = 0.5,  -- anti-spam por jugador
	MaxAimRange = 80,   -- distancia max. desde el jugador (anti-exploit)
}

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- ---------------------------------------------------------------------------
-- 1) Tool generada + RemoteEvent
-- ---------------------------------------------------------------------------
local function ensureToolTemplate()
	local existing = StarterPack:FindFirstChild("BastonTest")
	if existing then return existing end

	local tool = Instance.new("Tool")
	tool.Name = "BastonTest"
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool:SetAttribute("SetupGenerated", true)
	tool.Parent = StarterPack
	return tool
end

local toolTemplate = ensureToolTemplate()

-- Dar la tool a jugadores ya presentes que no la tengan (evita duplicados).
local function giveToolIfMissing(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local char = player.Character
	local hasIt = (backpack and backpack:FindFirstChild("BastonTest"))
		or (char and char:FindFirstChild("BastonTest"))
	if backpack and not hasIt then
		toolTemplate:Clone().Parent = backpack
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	giveToolIfMissing(player)
end
-- A los que entran luego, StarterPack entrega la tool automaticamente.

local remote = ReplicatedStorage:FindFirstChild("BastonTestRemote")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "BastonTestRemote"
	remote.Parent = ReplicatedStorage
end

-- ---------------------------------------------------------------------------
-- 2) Amenazas activas + UN solo loop Heartbeat
-- ---------------------------------------------------------------------------
local cooldowns = {}     -- [player] = lastFireTime
local activeThreats = {} -- { { a, b, expires, ownerId } }

local function getOwnerFlock(ownerId)
	local runtime = workspace:FindFirstChild(Cfg.Names.Runtime)
	if not runtime then return nil end
	return runtime:FindFirstChild("Flock_" .. ownerId)
end

local function pushSheepAwayFromSegment(threat)
	local flock = getOwnerFlock(threat.ownerId)
	if not flock then return end

	local a, b = threat.a, threat.b
	local ab = b - a
	local abLenSq = ab:Dot(ab)
	if abLenSq < 0.0001 then return end

	for _, sheep in ipairs(flock:GetChildren()) do
		local root = sheep:FindFirstChild("HumanoidRootPart")
		if root then
			local p = flat(root.Position)
			local t = math.clamp((p - a):Dot(ab) / abLenSq, 0, 1)
			local closest = a + ab * t
			local offset = p - closest
			local dist = offset.Magnitude

			if dist <= CONFIG.Band then
				local dir
				if dist > 0.001 then
					dir = offset.Unit
				else
					-- justo sobre la linea: empuja por la normal
					dir = Vector3.new(-ab.Z, 0, ab.X).Unit
				end

				-- Escribir en el MISMO constraint que usa la oveja (Y=0; el hover
				-- controla la altura). Fallback a AssemblyLinearVelocity.
				local lv = root:FindFirstChild("LinearVelocity")
				if lv and lv:IsA("LinearVelocity") then
					lv.VectorVelocity = Vector3.new(dir.X * CONFIG.PushSpeed, 0, dir.Z * CONFIG.PushSpeed)
				else
					local cur = root.AssemblyLinearVelocity
					root.AssemblyLinearVelocity = Vector3.new(dir.X * CONFIG.PushSpeed, cur.Y, dir.Z * CONFIG.PushSpeed)
				end
			end
		end
	end
end

RunService.Heartbeat:Connect(function()
	if #activeThreats == 0 then return end
	local now = os.clock()
	for i = #activeThreats, 1, -1 do
		local threat = activeThreats[i]
		if now >= threat.expires then
			table.remove(activeThreats, i)
		else
			pushSheepAwayFromSegment(threat)
		end
	end
end)

-- ---------------------------------------------------------------------------
-- 3) Recepcion del disparo del baston
-- ---------------------------------------------------------------------------
remote.OnServerEvent:Connect(function(player, p1, p2)
	if typeof(p1) ~= "Vector3" or typeof(p2) ~= "Vector3" then return end

	local now = os.clock()
	if cooldowns[player] and now - cooldowns[player] < CONFIG.Cooldown then
		return
	end

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- Anti-exploit: la linea no puede estar absurdamente lejos del jugador.
	if (flat((p1 + p2) / 2) - flat(root.Position)).Magnitude > CONFIG.MaxAimRange then
		return
	end

	local a, b = flat(p1), flat(p2)
	local length = (b - a).Magnitude
	if length < 0.5 then return end

	cooldowns[player] = now

	-- Linea ROJA visible
	local center = (p1 + p2) / 2 + Vector3.new(0, 0.2, 0)
	local line = Instance.new("Part")
	line.Name = "BastonLine"
	line.Anchored = true
	line.CanCollide = false
	line.CanQuery = false
	line.CanTouch = false
	line.Material = Enum.Material.Neon
	line.Color = Color3.fromRGB(255, 0, 0)
	line.Size = Vector3.new(0.4, 0.4, length)
	line.CFrame = CFrame.lookAt(center, Vector3.new(p2.X, center.Y, p2.Z))
	line.Parent = workspace
	Debris:AddItem(line, CONFIG.Duration)

	table.insert(activeThreats, {
		a = a,
		b = b,
		expires = now + CONFIG.Duration,
		ownerId = player.UserId,
	})
end)

Players.PlayerRemoving:Connect(function(player)
	cooldowns[player] = nil
	for i = #activeThreats, 1, -1 do
		if activeThreats[i].ownerId == player.UserId then
			table.remove(activeThreats, i)
		end
	end
end)
