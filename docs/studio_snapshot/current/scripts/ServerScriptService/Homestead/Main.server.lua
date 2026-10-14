local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Root = script.Parent
local M = Root:WaitForChild("M")

local HomeCfg = require(M:WaitForChild("HomeCfg"))
local HomeService = require(M:WaitForChild("HomeService"))
local AnimalService = require(M:WaitForChild("AnimalService"))

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)

	if folder then
		if folder:IsA("Folder") then
			return folder
		end

		error("[Homestead] " .. name .. " existe pero no es Folder.")
	end

	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent

	return folder
end

local function ensureRemote(parent, name)
	local remote = parent:FindFirstChild(name)

	if remote then
		if remote:IsA("RemoteEvent") then
			return remote
		end

		error("[Homestead] " .. name .. " existe pero no es RemoteEvent.")
	end

	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = parent

	return remote
end

local remoteFolder = ensureFolder(ReplicatedStorage, HomeCfg.Names.Remotes)
remoteFolder:SetAttribute("CarryChickenAnimationId", HomeCfg.Anim.Player.CarryChicken)

local requestHomeInfo = ensureRemote(remoteFolder, HomeCfg.Names.RequestHomeInfo)
local homeInfoEvent = ensureRemote(remoteFolder, HomeCfg.Names.HomeInfo)
local dropChickenEvent = ensureRemote(remoteFolder, HomeCfg.Names.DropChicken)

local homeService = HomeService.new()
local animalService = AnimalService.new(homeService)

requestHomeInfo.OnServerEvent:Connect(function(player)
	local info = homeService:GetHomeInfo(player)
	info.CollectedEggs = animalService:GetCollectedEggCount(player)
	homeInfoEvent:FireClient(player, info)
end)

dropChickenEvent.OnServerEvent:Connect(function(player)
	animalService:DropCarriedChicken(player)
end)

Players.PlayerRemoving:Connect(function(player)
	animalService:Release(player)
	homeService:Release(player)
end)

task.spawn(function()
	while script.Parent do
		for _, player in ipairs(Players:GetPlayers()) do
			local homeData = homeService:RefreshPlayerHome(player)
			animalService:RefreshPlayer(player, homeData)
		end

		task.wait(2)
	end
end)

local animalTimer = 0
local animalInterval = HomeCfg.Animals.Chicken.UpdateRate or (1 / 30)
local maxCatchUp = 2

RunService.Heartbeat:Connect(function(dt)
	animalTimer += dt

	local steps = 0

	while animalTimer >= animalInterval and steps < maxCatchUp do
		animalTimer -= animalInterval
		steps += 1

		animalService:Step(animalInterval)
	end

	if steps >= maxCatchUp then
		animalTimer = 0
	end
end)

print("[Homestead] Sistema iniciado correctamente. v4 ChickenCarry")
