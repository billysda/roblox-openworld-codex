-- Homestead Monitor v1.0
-- Comandos de chat:
-- /hs
-- /homestead stats

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local function safeRequireHomeCfg()
	local homestead = ServerScriptService:FindFirstChild("Homestead")
	local m = homestead and homestead:FindFirstChild("M")
	local cfgModule = m and m:FindFirstChild("HomeCfg")

	if cfgModule and cfgModule:IsA("ModuleScript") then
		local ok, cfg = pcall(require, cfgModule)
		if ok then
			return cfg
		end
	end

	return nil
end

local function safeRequireInventoryService()
	local homestead = ServerScriptService:FindFirstChild("Homestead")
	local m = homestead and homestead:FindFirstChild("M")
	local inventoryModule = m and m:FindFirstChild("InventoryService")

	if inventoryModule and inventoryModule:IsA("ModuleScript") then
		local ok, inventoryService = pcall(require, inventoryModule)
		if ok then
			return inventoryService
		end
	end

	return nil
end

local function getAnimalFolder(homeFolder, name)
	local animals = homeFolder and homeFolder:FindFirstChild("Animals")
	return animals and animals:FindFirstChild(name) or nil
end

local function countEggs(eggFolder)
	local count = 0
	if not eggFolder then
		return count
	end

	for _, obj in ipairs(eggFolder:GetChildren()) do
		if obj:IsA("Model") or obj:IsA("BasePart") then
			count += 1
		end
	end

	return count
end

local function collectStats()
	local cfg = safeRequireHomeCfg()
	local runtimeName = cfg and cfg.Names and cfg.Names.HomeRuntime or "HomeRuntime"
	local runtime = workspace:FindFirstChild(runtimeName)
	local inventoryService = safeRequireInventoryService()

	local stats = {
		PlayerCount = #Players:GetPlayers(),
		ActiveHomes = 0,
		ChickenCount = 0,
		CuyCount = 0,
		EggCount = 0,
		CarriedChickens = 0,
		LayingEggChickens = 0,
		GoNestAccessChickens = 0,
		NestJumpUpChickens = 0,
		OnNestChickens = 0,
		HiddenCuys = 0,
		AvoidPlayerCuys = 0,
		EstimatedChickenUpdatesPerSecond = 0,
		EstimatedCuyUpdatesPerSecond = 0,
		EstimatedHomesteadRaycastsPerSecond = 0,
		InventoryEggsTotal = inventoryService and inventoryService.GetSessionItemTotal("Egg") or 0,
		RuntimeFound = runtime ~= nil,
	}

	if runtime then
		for _, homeFolder in ipairs(runtime:GetChildren()) do
			if homeFolder:IsA("Folder") then
				stats.ActiveHomes += 1

				local chickenFolder = getAnimalFolder(homeFolder, "Chickens")
				if chickenFolder then
					for _, chicken in ipairs(chickenFolder:GetChildren()) do
						if chicken:IsA("Model") then
							stats.ChickenCount += 1

							local state = chicken:GetAttribute("State") or "None"
							if state == "Carried" then
								stats.CarriedChickens += 1
							elseif state == "LayingEgg" then
								stats.LayingEggChickens += 1
							elseif state == "GoNestAccess" then
								stats.GoNestAccessChickens += 1
							elseif state == "NestJumpUp" then
								stats.NestJumpUpChickens += 1
							elseif state == "OnNest" then
								stats.OnNestChickens += 1
							end
						end
					end
				end

				local cuyFolder = getAnimalFolder(homeFolder, "Cuys")
				if cuyFolder then
					for _, cuy in ipairs(cuyFolder:GetChildren()) do
						if cuy:IsA("Model") then
							stats.CuyCount += 1

							local state = cuy:GetAttribute("State") or "None"
							if state == "Hidden" then
								stats.HiddenCuys += 1
							elseif state == "AvoidPlayer" then
								stats.AvoidPlayerCuys += 1
							end
						end
					end
				end

				stats.EggCount += countEggs(getAnimalFolder(homeFolder, "Eggs"))
			end
		end
	end

	local chickenInterval = cfg and cfg.Animals and cfg.Animals.Chicken and cfg.Animals.Chicken.UpdateRate or (1 / 30)
	local cuyInterval = cfg and cfg.Animals and cfg.Animals.Cuy and cfg.Animals.Cuy.UpdateRate or (1 / 30)
	local chickenHz = 1 / math.max(chickenInterval, 1 / 120)
	local cuyHz = 1 / math.max(cuyInterval, 1 / 120)

	stats.EstimatedChickenUpdatesPerSecond = math.floor(stats.ChickenCount * chickenHz + 0.5)
	stats.EstimatedCuyUpdatesPerSecond = math.floor(stats.CuyCount * cuyHz + 0.5)
	stats.EstimatedHomesteadRaycastsPerSecond = math.floor(stats.EstimatedChickenUpdatesPerSecond + stats.EstimatedCuyUpdatesPerSecond + 0.5)

	return stats
end

local function buildStatsText()
	local s = collectStats()
	local lines = {}

	table.insert(lines, "========== [Homestead Stats] ==========")
	table.insert(lines, "Players: " .. s.PlayerCount)
	table.insert(lines, "Homes activos: " .. s.ActiveHomes)
	table.insert(lines, "Gallinas activas: " .. s.ChickenCount)
	table.insert(lines, "Cuys activos: " .. s.CuyCount)
	table.insert(lines, "Huevos activos: " .. s.EggCount)
	table.insert(lines, "Inventory Eggs total: " .. s.InventoryEggsTotal)
	table.insert(lines, "Gallinas cargadas: " .. s.CarriedChickens)
	table.insert(lines, "Gallinas en LayingEgg: " .. s.LayingEggChickens)
	table.insert(lines, "Gallinas en GoNestAccess: " .. s.GoNestAccessChickens)
	table.insert(lines, "Gallinas en NestJumpUp: " .. s.NestJumpUpChickens)
	table.insert(lines, "Gallinas en OnNest: " .. s.OnNestChickens)
	table.insert(lines, "Cuys en Hidden: " .. s.HiddenCuys)
	table.insert(lines, "Cuys en AvoidPlayer: " .. s.AvoidPlayerCuys)
	table.insert(lines, "Estimated Chicken updates/s: " .. s.EstimatedChickenUpdatesPerSecond)
	table.insert(lines, "Estimated Cuy updates/s: " .. s.EstimatedCuyUpdatesPerSecond)
	table.insert(lines, "Estimated Homestead raycasts/s aproximados: " .. s.EstimatedHomesteadRaycastsPerSecond .. " baseline")
	table.insert(lines, "Runtime found: " .. tostring(s.RuntimeFound))
	table.insert(lines, "=======================================")

	return table.concat(lines, "\n")
end

local function printStats()
	print(buildStatsText())
end

local function hookPlayer(player)
	player.Chatted:Connect(function(message)
		message = string.lower(message)

		if message == "/hs" or message == "/homestead stats" then
			printStats()
		end
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	hookPlayer(player)
end

Players.PlayerAdded:Connect(hookPlayer)

print("[HomesteadMonitor] Listo. Usa /hs o /homestead stats.")