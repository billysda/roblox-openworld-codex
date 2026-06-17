-- PasturePromptClient v2
-- Control visual local de prompts de casas.
-- Regla:
-- - Si NO tengo casa: veo solo casas libres.
-- - Si YA tengo casa: no veo ningÃºn prompt de reclamar casa.
-- - Si una casa estÃ¡ tomada por cualquiera: no veo su prompt.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local HOUSES_FOLDER_NAME = "Houses"
local CLAIM_PART_NAME = "ClaimPromptPart"
local PROMPT_NAME = "ProximityPrompt"

local housesFolder = Workspace:WaitForChild(HOUSES_FOLDER_NAME)

local houseConnections = {}
local promptConnections = {}

local function isHouseObject(obj)
	return obj:IsA("Model") or obj:IsA("Folder")
end

local function getPrompt(house)
	local claimPart = house:FindFirstChild(CLAIM_PART_NAME)
	if not claimPart then
		return nil
	end

	local prompt = claimPart:FindFirstChild(PROMPT_NAME)
	if prompt and prompt:IsA("ProximityPrompt") then
		return prompt
	end

	return nil
end

local function playerOwnsAnyHouse()
	for _, house in ipairs(housesFolder:GetChildren()) do
		if isHouseObject(house) then
			if house:GetAttribute("Taken") == true and house:GetAttribute("OwnerId") == player.UserId then
				return true
			end
		end
	end

	return false
end

local function shouldShowPrompt(house, ownsAnyHouse)
	if ownsAnyHouse then
		return false
	end

	if house:GetAttribute("Taken") == true then
		return false
	end

	local ownerId = house:GetAttribute("OwnerId")
	if typeof(ownerId) == "number" and ownerId ~= 0 then
		return false
	end

	return true
end

local refreshing = false

local function refreshPrompts()
	if refreshing then
		return
	end

	refreshing = true

	local ownsAnyHouse = playerOwnsAnyHouse()

	for _, house in ipairs(housesFolder:GetChildren()) do
		if isHouseObject(house) then
			local prompt = getPrompt(house)

			if prompt then
				local show = shouldShowPrompt(house, ownsAnyHouse)

				if prompt.Enabled ~= show then
					prompt.Enabled = show
				end
			end
		end
	end

	refreshing = false
end

local function disconnectHouse(house)
	if houseConnections[house] then
		for _, c in ipairs(houseConnections[house]) do
			c:Disconnect()
		end

		houseConnections[house] = nil
	end

	if promptConnections[house] then
		for _, c in ipairs(promptConnections[house]) do
			c:Disconnect()
		end

		promptConnections[house] = nil
	end
end

local function watchPrompt(house)
	if promptConnections[house] then
		for _, c in ipairs(promptConnections[house]) do
			c:Disconnect()
		end
	end

	promptConnections[house] = {}

	local prompt = getPrompt(house)
	if prompt then
		table.insert(promptConnections[house], prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
			task.defer(refreshPrompts)
		end))
	end
end

local function watchHouse(house)
	if not isHouseObject(house) then
		return
	end

	disconnectHouse(house)

	houseConnections[house] = {
		house:GetAttributeChangedSignal("Taken"):Connect(refreshPrompts),
		house:GetAttributeChangedSignal("OwnerId"):Connect(refreshPrompts),
		house.ChildAdded:Connect(function()
			task.wait(0.05)
			watchPrompt(house)
			refreshPrompts()
		end),
		house.ChildRemoved:Connect(function()
			task.defer(refreshPrompts)
		end),
	}

	watchPrompt(house)
	refreshPrompts()
end

for _, house in ipairs(housesFolder:GetChildren()) do
	watchHouse(house)
end

housesFolder.ChildAdded:Connect(function(child)
	task.wait(0.1)
	watchHouse(child)
end)

housesFolder.ChildRemoved:Connect(function(child)
	disconnectHouse(child)
	task.defer(refreshPrompts)
end)

-- Respaldo: esto evita que por replicaciÃ³n tardÃ­a o scripts del servidor el prompt quede visible.
task.spawn(function()
	while task.wait(0.25) do
		refreshPrompts()
	end
end)

refreshPrompts()

print("[PasturePromptClient v2] Listo. Prompts invÃ¡lidos ocultos localmente.")
