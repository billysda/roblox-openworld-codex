-- Pasture Monitor v1.1
-- Comandos de chat:
-- /ps               -> stats rápidas
-- /pasture stats    -> stats rápidas
-- /pv               -> validación
-- /pasture validate -> validación
--
-- También puedes seleccionar este Script y activar:
-- AutoPrint = true
-- PrintInterval = 15

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local scriptObj = script
if scriptObj:GetAttribute("AutoPrint") == nil then
	scriptObj:SetAttribute("AutoPrint", false)
end

if scriptObj:GetAttribute("PrintInterval") == nil then
	scriptObj:SetAttribute("PrintInterval", 15)
end

local remoteFolder = ReplicatedStorage:FindFirstChild("PastureRemote")
local requestStats = remoteFolder and remoteFolder:FindFirstChild("RequestStats")
local statsResponse = remoteFolder and remoteFolder:FindFirstChild("StatsResponse")

local function safeRequireCfg()
	local pasture = ServerScriptService:FindFirstChild("Pasture")
	local m = pasture and pasture:FindFirstChild("M")
	local cfgModule = m and m:FindFirstChild("Cfg")

	if cfgModule and cfgModule:IsA("ModuleScript") then
		local ok, cfg = pcall(require, cfgModule)
		if ok then
			return cfg
		end
	end

	return nil
end

local function countChildrenOfClass(parent, className)
	local count = 0
	if not parent then
		return count
	end

	for _, obj in ipairs(parent:GetChildren()) do
		if obj:IsA(className) then
			count += 1
		end
	end

	return count
end

local function collectStats()
	local cfg = safeRequireCfg()

	local runtimeName = cfg and cfg.Names and cfg.Names.Runtime or "SheepRuntime"
	local housesName = cfg and cfg.Names and cfg.Names.Houses or "Houses"

	local runtime = workspace:FindFirstChild(runtimeName)
	local housesFolder = workspace:FindFirstChild(housesName)

	local stats = {
		PlayerCount = #Players:GetPlayers(),
		HouseTotal = 0,
		HouseTaken = 0,
		HouseFree = 0,
		FlockCount = 0,
		SheepCount = 0,
		LeaderCount = 0,
		SheepBaseParts = 0,
		InvalidRoots = 0,
		States = {},
		Sequences = {},
		RuntimeFound = runtime ~= nil,
		HousesFound = housesFolder ~= nil,
		EstimatedHoverRaycastsPerSecond = 0,
		EstimatedAIUpdatesPerSecond = 0,
		LuaMemoryMB = nil,
	}

	if housesFolder then
		for _, house in ipairs(housesFolder:GetChildren()) do
			if house:IsA("Model") or house:IsA("Folder") then
				stats.HouseTotal += 1

				if house:GetAttribute("Taken") == true then
					stats.HouseTaken += 1
				else
					stats.HouseFree += 1
				end
			end
		end
	end

	if runtime then
		for _, flockFolder in ipairs(runtime:GetChildren()) do
			if flockFolder:IsA("Folder") then
				stats.FlockCount += 1

				for _, sheep in ipairs(flockFolder:GetChildren()) do
					if sheep:IsA("Model") then
						stats.SheepCount += 1

						if sheep:GetAttribute("IsLeader") == true then
							stats.LeaderCount += 1
						end

						local root = sheep:FindFirstChild("HumanoidRootPart")
						if not root or not root:IsA("BasePart") then
							stats.InvalidRoots += 1
						end

						for _, desc in ipairs(sheep:GetDescendants()) do
							if desc:IsA("BasePart") then
								stats.SheepBaseParts += 1
							end
						end

						local state = sheep:GetAttribute("State") or "None"
						stats.States[state] = (stats.States[state] or 0) + 1

						local sequence = sheep:GetAttribute("Sequence")
						if sequence and sequence ~= "" then
							stats.Sequences[sequence] = (stats.Sequences[sequence] or 0) + 1
						end
					end
				end
			end
		end
	end

	local aiRate = cfg and cfg.Update and cfg.Update.AI or 0.1
	if aiRate <= 0 then
		aiRate = 0.1
	end

	local physicsInterval = cfg and cfg.Update and cfg.Update.Physics or (1 / 30)
	local physicsHz = 1 / math.max(physicsInterval, 1 / 120)
	stats.EstimatedHoverRaycastsPerSecond = math.floor(stats.SheepCount * physicsHz)
	stats.EstimatedAIUpdatesPerSecond = math.floor(stats.SheepCount / aiRate)

	local ok, mem = pcall(function()
		return collectgarbage("count")
	end)

	if ok and mem then
		stats.LuaMemoryMB = mem / 1024
	end

	return stats
end

local function formatMap(map)
	local parts = {}

	for name, count in pairs(map) do
		table.insert(parts, tostring(name) .. "=" .. tostring(count))
	end

	table.sort(parts)

	if #parts == 0 then
		return "none"
	end

	return table.concat(parts, ", ")
end

local function buildStatsText()
	local s = collectStats()
	local lines = {}

	table.insert(lines, "========== [Pasture Stats] ==========")
	table.insert(lines, "Players: " .. s.PlayerCount)
	table.insert(lines, "Houses: total=" .. s.HouseTotal .. " taken=" .. s.HouseTaken .. " free=" .. s.HouseFree)
	table.insert(lines, "Flocks: " .. s.FlockCount)
	table.insert(lines, "Sheep: " .. s.SheepCount .. " leaders=" .. s.LeaderCount .. " invalidRoots=" .. s.InvalidRoots)
	table.insert(lines, "Sheep BaseParts: " .. s.SheepBaseParts)
	table.insert(lines, "States: " .. formatMap(s.States))
	table.insert(lines, "Sequences: " .. formatMap(s.Sequences))
	table.insert(lines, "Estimated Hover Raycasts/s: " .. s.EstimatedHoverRaycastsPerSecond)
	table.insert(lines, "Estimated AI Updates/s: " .. s.EstimatedAIUpdatesPerSecond)

	if s.LuaMemoryMB then
		table.insert(lines, string.format("Lua Memory: %.2f MB", s.LuaMemoryMB))
	end

	table.insert(lines, "Runtime found: " .. tostring(s.RuntimeFound))
	table.insert(lines, "Houses found: " .. tostring(s.HousesFound))
	table.insert(lines, "=====================================")

	return table.concat(lines, "\n")
end

local function validateSystem()
	local cfg = safeRequireCfg()
	local lines = {}

	local function add(ok, message)
		table.insert(lines, (ok and "[OK] " or "[WARN] ") .. message)
	end

	local runtimeName = cfg and cfg.Names and cfg.Names.Runtime or "SheepRuntime"
	local housesName = cfg and cfg.Names and cfg.Names.Houses or "Houses"
	local spawnFolderName = cfg and cfg.Names and cfg.Names.SpawnFolder or "SheepSpawns"
	local promptPartName = cfg and cfg.Names and cfg.Names.HousePromptPart or "ClaimPromptPart"
	local promptName = cfg and cfg.Names and cfg.Names.HousePrompt or "ProximityPrompt"
	local corralName = cfg and cfg.Names and cfg.Names.CorralCenter or "CorralCenter"
	local sheepPerFlock = cfg and cfg.SheepPerFlock or 10

	local runtime = workspace:FindFirstChild(runtimeName)
	local housesFolder = workspace:FindFirstChild(housesName)

	table.insert(lines, "========== [Pasture Validate] ==========")

	add(runtime ~= nil, "Workspace." .. runtimeName)
	add(housesFolder ~= nil, "Workspace." .. housesName)

	local assets = ServerStorage:FindFirstChild("Assets")
	local sheepFolder = assets and assets:FindFirstChild("Sheep")
	local template = sheepFolder and sheepFolder:FindFirstChild("SheepTemplate")

	add(assets ~= nil, "ServerStorage.Assets")
	add(sheepFolder ~= nil, "ServerStorage.Assets.Sheep")
	add(template ~= nil and template:IsA("Model"), "ServerStorage.Assets.Sheep.SheepTemplate Model")

	if template and template:IsA("Model") then
		add(template.PrimaryPart ~= nil or template:FindFirstChild("HumanoidRootPart") ~= nil, "SheepTemplate PrimaryPart/HumanoidRootPart")
		add(template:FindFirstChild("AnimationController") ~= nil, "SheepTemplate AnimationController")
	end

	local seenHouseIds = {}

	if housesFolder then
		for _, house in ipairs(housesFolder:GetChildren()) do
			if house:IsA("Model") or house:IsA("Folder") then
				local id = house:GetAttribute("HouseId")
				add(id ~= nil, house.Name .. " HouseId")

				if id ~= nil then
					if seenHouseIds[id] then
						add(false, "HouseId duplicado: " .. tostring(id) .. " en " .. house.Name .. " y " .. seenHouseIds[id])
					else
						seenHouseIds[id] = house.Name
					end
				end

				local promptPart = house:FindFirstChild(promptPartName)
				add(promptPart ~= nil, house.Name .. "." .. promptPartName)

				local prompt = promptPart and promptPart:FindFirstChild(promptName)
				add(prompt ~= nil and prompt:IsA("ProximityPrompt"), house.Name .. "." .. promptPartName .. "." .. promptName)

				local corral = house:FindFirstChild(corralName)
				add(corral ~= nil and corral:IsA("BasePart"), house.Name .. "." .. corralName)

				local spawns = house:FindFirstChild(spawnFolderName)
				add(spawns ~= nil, house.Name .. "." .. spawnFolderName)

				if spawns then
					local count = countChildrenOfClass(spawns, "BasePart")
					add(count >= sheepPerFlock, house.Name .. " spawns=" .. count .. "/" .. sheepPerFlock)
				end
			end
		end
	end

	add(remoteFolder ~= nil, "ReplicatedStorage.PastureRemote")
	add(remoteFolder and remoteFolder:FindFirstChild("Whistle") ~= nil, "Remote Whistle")
	add(requestStats ~= nil, "Remote RequestStats")
	add(statsResponse ~= nil, "Remote StatsResponse")

	table.insert(lines, "========================================")

	return table.concat(lines, "\n")
end

local function printStats(player)
	local text = buildStatsText()
	print(text)

	if player and statsResponse then
		statsResponse:FireClient(player, text)
	end
end

local function printValidate(player)
	local text = validateSystem()
	print(text)

	if player and statsResponse then
		statsResponse:FireClient(player, text)
	end
end

local function hookPlayer(player)
	player.Chatted:Connect(function(message)
		message = string.lower(message)

		if message == "/ps" or message == "/pasture stats" then
			printStats(player)
		elseif message == "/pv" or message == "/pasture validate" then
			printValidate(player)
		end
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	hookPlayer(player)
end

Players.PlayerAdded:Connect(hookPlayer)

if requestStats then
	requestStats.OnServerEvent:Connect(function(player, mode)
		mode = tostring(mode or "stats")

		if mode == "validate" then
			printValidate(player)
		else
			printStats(player)
		end
	end)
end

task.spawn(function()
	while script.Parent do
		local interval = scriptObj:GetAttribute("PrintInterval") or 15

		if scriptObj:GetAttribute("AutoPrint") == true then
			printStats(nil)
		end

		task.wait(math.max(interval, 5))
	end
end)

print("[PastureMonitor] Listo. Usa /ps, /pv o presiona P desde cliente.")
