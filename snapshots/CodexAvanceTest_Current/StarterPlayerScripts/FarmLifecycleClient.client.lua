local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("FarmLifecycleUI")

local openButton = gui:WaitForChild("OpenButton")
local panel = gui:WaitForChild("MainPanel")
local closeButton = panel:WaitForChild("Header"):WaitForChild("CloseButton")
local rationsLabel = panel:WaitForChild("RationsLabel")
local modeLabel = panel:WaitForChild("ModeLabel")
local rows = panel:WaitForChild("Rows")
local toast = gui:WaitForChild("Toast")

local remotes = ReplicatedStorage:WaitForChild("FarmLifecycleRemote")
local requestSnapshot = remotes:WaitForChild("RequestSnapshot")
local processAnimal = remotes:WaitForChild("ProcessAnimal")
local requestRecoveryPair = remotes:WaitForChild("RequestRecoveryPair")
local stateChanged = remotes:WaitForChild("StateChanged")

local rowBySpecies = {
	Sheep = rows:WaitForChild("SheepRow"),
	Chicken = rows:WaitForChild("ChickenRow"),
	Cuy = rows:WaitForChild("CuyRow"),
}

local snapshot = nil
local toastToken = 0

local function showToast(text)
	toastToken += 1
	local token = toastToken
	toast.Text = text
	toast.Visible = true
	task.delay(2.2, function()
		if toastToken == token then
			toast.Visible = false
		end
	end)
end

local function setButtonState(button, enabled)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundTransparency = enabled and 0.08 or 0.48
	button.TextTransparency = enabled and 0 or 0.42
end

local function updateRow(speciesId, data)
	local row = rowBySpecies[speciesId]
	if not row then
		return
	end

	local counts = row:WaitForChild("Counts")
	local reserve = row:WaitForChild("Reserve")
	local processButton = row:WaitForChild("ProcessButton")
	local recoveryButton = row:WaitForChild("RecoveryButton")

	if not data or not data.Available then
		counts.Text = "Sin propiedad activa"
		reserve.Text = ""
		setButtonState(processButton, false)
		recoveryButton.Visible = false
		return
	end

	counts.Text = string.format("Adultos %d  ·  Crías %d  ·  %d/%d", data.Adults or 0, data.Juveniles or 0, data.Total or 0, data.Capacity or 0)
	reserve.Text = string.format("Reserva reproductora: %d · Provisiones: +%d raciones", data.ReserveAdults or 2, data.RationYield or 0)
	setButtonState(processButton, data.CanProcess == true)
	processButton.Text = data.CanProcess and "Preparar provisiones" or "2 reproductores protegidos"
	recoveryButton.Visible = data.Total == 0
	setButtonState(recoveryButton, data.CanRecover == true)
end

local function render(newSnapshot)
	snapshot = newSnapshot or snapshot
	if not snapshot then
		return
	end

	rationsLabel.Text = string.format("Raciones de carne: %d", snapshot.Rations or 0)
	modeLabel.Text = snapshot.TestFastMode and "PRUEBA RÁPIDA · nacimientos y crecimiento acelerados" or "Ciclo normal"

	for speciesId, row in pairs(rowBySpecies) do
		local data = snapshot.Species and snapshot.Species[speciesId]
		updateRow(speciesId, data)
	end
end

local function refresh()
	local ok, result = pcall(function()
		return requestSnapshot:InvokeServer()
	end)
	if ok and typeof(result) == "table" then
		render(result)
	end
end

local function setOpen(open)
	panel.Visible = open
	if open then
		refresh()
	end
end

openButton.Activated:Connect(function()
	setOpen(not panel.Visible)
end)

closeButton.Activated:Connect(function()
	setOpen(false)
end)

for speciesId, row in pairs(rowBySpecies) do
	row:WaitForChild("ProcessButton").Activated:Connect(function()
		local data = snapshot and snapshot.Species and snapshot.Species[speciesId]
		if data and data.CanProcess then
			processAnimal:FireServer(speciesId)
		end
	end)

	row:WaitForChild("RecoveryButton").Activated:Connect(function()
		local data = snapshot and snapshot.Species and snapshot.Species[speciesId]
		if data and data.CanRecover then
			requestRecoveryPair:FireServer(speciesId)
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.N then
		setOpen(not panel.Visible)
	end
end)

stateChanged.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	if payload.Snapshot then
		render(payload.Snapshot)
	else
		refresh()
	end

	local speciesId = payload.SpeciesId
	local data = speciesId and snapshot and snapshot.Species and snapshot.Species[speciesId]
	local name = data and (data.DisplayName or speciesId) or tostring(speciesId or "animal")

	if payload.Type == "Birth" then
		showToast("NACIÓ UNA CRÍA · " .. name)
	elseif payload.Type == "GrewUp" then
		showToast(string.upper(name) .. " CRECIÓ")
	elseif payload.Type == "Processed" then
		showToast(string.format("+%d RACIONES · %s", payload.RationsAdded or 0, name))
	elseif payload.Type == "RecoveryPair" then
		showToast("PAREJA DE RECUPERACIÓN · " .. name)
	end
end)

panel.Visible = false
toast.Visible = false
refresh()
