-- HomesteadClient v4
-- H = pedir info de cabaÃ±a.
-- G = soltar gallina cargada.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local remoteFolder = ReplicatedStorage:WaitForChild("HomesteadRemote")
local requestHomeInfo = remoteFolder:WaitForChild("RequestHomeInfo")
local homeInfoEvent = remoteFolder:WaitForChild("HomeInfo")
local dropChickenEvent = remoteFolder:WaitForChild("DropChicken")
local storageDataEvent = remoteFolder:WaitForChild("StorageData")
local closeStorageEvent = remoteFolder:WaitForChild("CloseStorage")

local storageGui = nil
local storageLabels = {}

local function createStorageGui()
	if storageGui then
		return storageGui
	end

	local playerGui = localPlayer:WaitForChild("PlayerGui")

	storageGui = Instance.new("ScreenGui")
	storageGui.Name = "HomesteadStorageGui"
	storageGui.ResetOnSpawn = false
	storageGui.Enabled = false
	storageGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Frame"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(320, 250)
	frame.BackgroundColor3 = Color3.fromRGB(36, 32, 27)
	frame.BorderSizePixel = 0
	frame.Parent = storageGui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(16, 12)
	title.Size = UDim2.new(1, -32, 0, 34)
	title.Font = Enum.Font.GothamBold
	title.Text = "AlmacÃ©n"
	title.TextColor3 = Color3.fromRGB(255, 240, 210)
	title.TextScaled = true
	title.Parent = frame

	local function addRow(key, text, y)
		local label = Instance.new("TextLabel")
		label.Name = key .. "Label"
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(24, y)
		label.Size = UDim2.new(1, -48, 0, 28)
		label.Font = Enum.Font.Gotham
		label.Text = text .. ": 0"
		label.TextColor3 = Color3.fromRGB(245, 235, 220)
		label.TextSize = 20
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = frame
		storageLabels[key] = { Label = label, Text = text }
	end

	addRow("Egg", "Huevos", 62)
	addRow("GoldenEgg", "Huevos dorados", 94)
	addRow("ChickenFeed", "Comida gallinas", 126)
	addRow("CuyFeed", "Comida cuys", 158)

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.AnchorPoint = Vector2.new(0.5, 1)
	closeButton.Position = UDim2.new(0.5, 0, 1, -16)
	closeButton.Size = UDim2.fromOffset(150, 36)
	closeButton.BackgroundColor3 = Color3.fromRGB(120, 82, 46)
	closeButton.BorderSizePixel = 0
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Text = "Cerrar"
	closeButton.TextColor3 = Color3.fromRGB(255, 245, 230)
	closeButton.TextSize = 18
	closeButton.Parent = frame
	closeButton.MouseButton1Click:Connect(function()
		storageGui.Enabled = false
		closeStorageEvent:FireServer()
	end)

	return storageGui
end

local function closeStorageGui()
	if storageGui then
		storageGui.Enabled = false
		closeStorageEvent:FireServer()
	end
end

local function showStorage(data)
	local gui = createStorageGui()
	local inventory = data and data.Inventory or {}

	for key, row in pairs(storageLabels) do
		row.Label.Text = row.Text .. ": " .. tostring(inventory[key] or 0)
	end

	gui.Enabled = true
end

local function printHomeInfo(info)
	print("========== [Homestead Info] ==========")
	print("HasHome:", info.HasHome)
	print("Message:", info.Message)

	if info.HasHome then
		print("House:", info.HouseName, "HouseId:", info.HouseId)
		print("Chickens:", info.ChickenCount or 0)
		print("Eggs active:", info.EggCount or 0)
		print("Eggs collected session:", info.CollectedEggs or 0)

		local inventory = info.Inventory or {}
		print("Inventory:")
		print("Egg:", inventory.Egg or 0)
		print("GoldenEgg:", inventory.GoldenEgg or 0)
		print("ChickenFeed:", inventory.ChickenFeed or 0)
		print("CuyFeed:", inventory.CuyFeed or 0)

		if info.Stations then
			for _, station in ipairs(info.Stations) do
				print("Station:", station.Name, "Exists:", station.Exists)
			end
		end
	end

	print("======================================")
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.X then
		if storageGui and storageGui.Enabled then
			closeStorageGui()
			return
		end
	end

	if input.KeyCode == Enum.KeyCode.H then
		requestHomeInfo:FireServer()
	elseif input.KeyCode == Enum.KeyCode.G then
		dropChickenEvent:FireServer()
	end
end)

homeInfoEvent.OnClientEvent:Connect(printHomeInfo)
storageDataEvent.OnClientEvent:Connect(showStorage)

print("[HomesteadClient] H=info, G=soltar gallina.")
