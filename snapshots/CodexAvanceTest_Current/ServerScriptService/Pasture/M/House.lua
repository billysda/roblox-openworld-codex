local House = {}
House.__index = House

local Cfg = require(script.Parent:WaitForChild("Cfg"))
local Flock = require(script.Parent:WaitForChild("Flock"))

function House.new(housesFolder, runtimeFolder, sheepTemplate)
	local self = setmetatable({}, House)

	self.HousesFolder = housesFolder
	self.Runtime = runtimeFolder
	self.Template = sheepTemplate

	self.Houses = {}
	self.PlayerData = {}

	self:LoadHouses()

	return self
end

function House:LoadHouses()
	for _, houseModel in ipairs(self.HousesFolder:GetChildren()) do
		if houseModel:IsA("Model") or houseModel:IsA("Folder") then
			self:RegisterHouse(houseModel)
		else
			warn("[House]", houseModel.Name, "debe ser Model o Folder. Ahora es:", houseModel.ClassName)
		end
	end

	print("[House] Casas listas:", #self.Houses)
end

function House:RegisterHouse(houseModel)
	if houseModel:GetAttribute("HouseId") == nil then
		houseModel:SetAttribute("HouseId", #self.Houses + 1)
	end

	houseModel:SetAttribute("OwnerId", 0)
	houseModel:SetAttribute("Taken", false)

	local promptPart = houseModel:FindFirstChild(Cfg.Names.HousePromptPart)

	if not promptPart then
		warn("[House] Falta ClaimPromptPart en", houseModel.Name)
		return
	end

	local prompt = promptPart:FindFirstChild(Cfg.Names.HousePrompt)

	if not prompt or not prompt:IsA("ProximityPrompt") then
		warn("[House] Falta ProximityPrompt dentro de", promptPart.Name)
		return
	end

	prompt.ActionText = "Reclamar"
	prompt.ObjectText = "Casa"
	prompt.Enabled = true

	prompt.Triggered:Connect(function(player)
		self:Claim(player, houseModel)
	end)

	table.insert(self.Houses, houseModel)
end

function House:Claim(player, houseModel)
	local userId = player.UserId

	if self.PlayerData[userId] then
		warn("[House]", player.Name, "ya tiene una casa.")
		return
	end

	if houseModel:GetAttribute("Taken") == true then
		warn("[House]", houseModel.Name, "ya está ocupada.")
		return
	end

	houseModel:SetAttribute("Taken", true)
	houseModel:SetAttribute("OwnerId", userId)

	local promptPart = houseModel:FindFirstChild(Cfg.Names.HousePromptPart)
	local prompt = promptPart and promptPart:FindFirstChild(Cfg.Names.HousePrompt)

	if prompt then
		prompt.Enabled = false
	end

	local flock = Flock.new(player, houseModel, self.Runtime, self.Template)

	self.PlayerData[userId] = {
		House = houseModel,
		Flock = flock,
	}

	if Cfg.Debug.PrintLifecycle then
		print("[House]", player.Name, "reclamó", houseModel.Name)
	end
end

function House:Release(player)
	local userId = player.UserId
	local data = self.PlayerData[userId]

	if not data then
		return
	end

	if data.Flock then
		data.Flock:Destroy()
	end

	if data.House then
		data.House:SetAttribute("Taken", false)
		data.House:SetAttribute("OwnerId", 0)

		local promptPart = data.House:FindFirstChild(Cfg.Names.HousePromptPart)
		local prompt = promptPart and promptPart:FindFirstChild(Cfg.Names.HousePrompt)

		if prompt then
			prompt.Enabled = true
		end
	end

	self.PlayerData[userId] = nil

	if Cfg.Debug.PrintLifecycle then
		print("[House] Casa liberada:", player.Name)
	end
end

function House:Whistle(player)
	local userId = player.UserId
	local data = self.PlayerData[userId]

	if not data then
		warn("[House]", player.Name, "intentó silbar, pero no tiene casa.")
		return
	end

	if data.Flock and data.Flock.Whistle then
		data.Flock:Whistle()
	end
end

function House:StepPhysics(dt)
	for _, data in pairs(self.PlayerData) do
		if data.Flock then
			data.Flock:StepPhysics(dt)
		end
	end
end

function House:StepAI(now)
	for _, data in pairs(self.PlayerData) do
		if data.Flock then
			data.Flock:StepAI(now)
		end
	end
end

return House
