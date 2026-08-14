local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Catalog = require(ReplicatedStorage:WaitForChild("MythicResourceCatalog"))
local remotes = ReplicatedStorage:WaitForChild("MythicResourceRemote")
local requestSnapshot = remotes:WaitForChild("RequestSnapshot")
local stateChanged = remotes:WaitForChild("StateChanged")

local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("CodexUI")
local openButton = gui:WaitForChild("OpenButton")
local mainPanel = gui:WaitForChild("MainPanel")
local closeButton = mainPanel:WaitForChild("Header"):WaitForChild("CloseButton")
local floraTab = mainPanel:WaitForChild("Tabs"):WaitForChild("FloraTab")
local dragonsTab = mainPanel.Tabs:WaitForChild("DragonsTab")
local body = mainPanel:WaitForChild("Body")
local entryList = body:WaitForChild("EntryList")
local entryTemplate = entryList:WaitForChild("EntryTemplate")
local detail = body:WaitForChild("DetailPanel")
local nameLabel = detail:WaitForChild("NameLabel")
local statusLabel = detail:WaitForChild("StatusLabel")
local rarityLabel = detail:WaitForChild("RarityLabel")
local countLabel = detail:WaitForChild("CountLabel")
local affinityLabel = detail:WaitForChild("AffinityLabel")
local usesLabel = detail:WaitForChild("UsesLabel")
local descriptionLabel = detail:WaitForChild("DescriptionLabel")
local hintLabel = detail:WaitForChild("HintLabel")
local footerHint = mainPanel:WaitForChild("FooterHint")
local toast = gui:WaitForChild("Toast")
local toastText = toast:WaitForChild("TextLabel")

local snapshot = {
	Inventory = {},
	Discovered = {},
	KnownCount = 0,
}
local selectedResourceId = Catalog.Order[1]
local currentTab = "Flora"
local entryButtons = {}
local toastToken = 0

local ELEMENT_NAMES = {
	Nature = "Naturaleza",
	Earth = "Tierra",
	Fire = "Fuego",
	Water = "Agua",
	Ice = "Hielo",
	Lightning = "Rayo",
}

local function safeRequestSnapshot()
	local ok, data = pcall(function()
		return requestSnapshot:InvokeServer()
	end)
	if ok and typeof(data) == "table" then
		snapshot.Inventory = typeof(data.Inventory) == "table" and data.Inventory or {}
		snapshot.Discovered = typeof(data.Discovered) == "table" and data.Discovered or {}
		snapshot.KnownCount = tonumber(data.KnownCount) or 0
	end
end

local function listText(values)
	if typeof(values) ~= "table" or #values == 0 then
		return "—"
	end
	return table.concat(values, " · ")
end

local function affinityText(definition)
	local lines = {}
	for element, multiplier in pairs(definition.Affinity or {}) do
		local displayName = ELEMENT_NAMES[element] or element
		table.insert(lines, string.format("%s  ×%.2g", displayName, multiplier))
	end
	table.sort(lines)
	return #lines > 0 and table.concat(lines, "   ") or "—"
end

local function setDetailVisible(visible)
	rarityLabel.Visible = visible
	countLabel.Visible = visible
	affinityLabel.Visible = visible
	usesLabel.Visible = visible
	descriptionLabel.Visible = visible
	hintLabel.Visible = visible
end

local function renderDetail(resourceId)
	selectedResourceId = resourceId or selectedResourceId

	if currentTab == "Dragons" then
		nameLabel.Text = "Dragones"
		statusLabel.Text = "Esta sección ya está reservada para el futuro registro de especies, afinidades y habilidades."
		setDetailVisible(false)
		footerHint.Text = "CÓDICE v0 · Flora mítica activa · Dragones reservado"
		return
	end

	local definition = Catalog.Get(selectedResourceId)
	if not definition then
		return
	end

	local discovered = snapshot.Discovered[selectedResourceId] == true
	if not discovered then
		nameLabel.Text = "????????????"
		statusLabel.Text = "Entrada desconocida"
		setDetailVisible(false)
		descriptionLabel.Visible = true
		descriptionLabel.Text = "Encuentra y recolecta este recurso en el mundo para registrarlo en el Códice."
		footerHint.Text = string.format("Flora mítica descubierta: %d / %d", snapshot.KnownCount or 0, #Catalog.Order)
		return
	end

	setDetailVisible(true)
	nameLabel.Text = definition.DisplayName
	statusLabel.Text = "DESCUBIERTO"
	rarityLabel.Text = "Rareza  ·  " .. definition.Rarity
	countLabel.Text = "En la bolsa  ·  " .. tostring(snapshot.Inventory[selectedResourceId] or 0)
	affinityLabel.Text = "Afinidad  ·  " .. affinityText(definition)
	usesLabel.Text = "Usos previstos  ·  " .. listText(definition.Uses)
	descriptionLabel.Text = definition.Description
	hintLabel.Text = "Dónde buscar  ·  " .. definition.RegionHint
	footerHint.Text = string.format("Flora mítica descubierta: %d / %d", snapshot.KnownCount or 0, #Catalog.Order)
end

local function refreshEntryButtons()
	for _, resourceId in ipairs(Catalog.Order) do
		local button = entryButtons[resourceId]
		if button then
			local discovered = snapshot.Discovered[resourceId] == true
			local definition = Catalog.Get(resourceId)
			button.Text = discovered and definition.DisplayName or "?????"
			button:SetAttribute("Discovered", discovered)
		end
	end
end

local function createEntries()
	entryTemplate.Visible = false
	for _, resourceId in ipairs(Catalog.Order) do
		local definition = Catalog.Get(resourceId)
		local button = entryTemplate:Clone()
		button.Name = "Entry_" .. resourceId
		button.Visible = true
		button.LayoutOrder = table.find(Catalog.Order, resourceId) or 1
		button.Text = snapshot.Discovered[resourceId] and definition.DisplayName or "?????"
		button.Parent = entryList
		button.Activated:Connect(function()
			currentTab = "Flora"
			entryList.Visible = true
			renderDetail(resourceId)
		end)
		entryButtons[resourceId] = button
	end
end

local function setTab(tabName)
	currentTab = tabName
	if tabName == "Flora" then
		entryList.Visible = true
		floraTab:SetAttribute("Selected", true)
		dragonsTab:SetAttribute("Selected", false)
		refreshEntryButtons()
		renderDetail(selectedResourceId)
	else
		entryList.Visible = false
		floraTab:SetAttribute("Selected", false)
		dragonsTab:SetAttribute("Selected", true)
		renderDetail(selectedResourceId)
	end
end

local function setOpen(open)
	mainPanel.Visible = open
	if open then
		safeRequestSnapshot()
		refreshEntryButtons()
		renderDetail(selectedResourceId)
	end
end

local function showToast(message, firstDiscovery)
	toastToken += 1
	local token = toastToken
	toastText.Text = message
	toast.Visible = true
	toast.BackgroundTransparency = 1
	toastText.TextTransparency = 1

	TweenService:Create(toast, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = firstDiscovery and 0.08 or 0.18,
	}):Play()
	TweenService:Create(toastText, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 0,
	}):Play()

	task.delay(firstDiscovery and 2.6 or 1.7, function()
		if token ~= toastToken then
			return
		end
		local a = TweenService:Create(toast, TweenInfo.new(0.24), { BackgroundTransparency = 1 })
		local b = TweenService:Create(toastText, TweenInfo.new(0.24), { TextTransparency = 1 })
		a:Play()
		b:Play()
		b.Completed:Once(function()
			if token == toastToken then
				toast.Visible = false
			end
		end)
	end)
end

safeRequestSnapshot()
createEntries()
setTab("Flora")
mainPanel.Visible = false
toast.Visible = false

openButton.Activated:Connect(function()
	setOpen(not mainPanel.Visible)
end)
closeButton.Activated:Connect(function()
	setOpen(false)
end)
floraTab.Activated:Connect(function()
	setTab("Flora")
end)
dragonsTab.Activated:Connect(function()
	setTab("Dragons")
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.K then
		setOpen(not mainPanel.Visible)
	end
end)

stateChanged.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or payload.Type ~= "Collected" then
		return
	end
	local resourceId = payload.ResourceId
	local definition = Catalog.Get(resourceId)
	if not definition then
		return
	end

	snapshot.Inventory[resourceId] = tonumber(payload.Count) or (snapshot.Inventory[resourceId] or 0)
	if payload.FirstDiscovery == true then
		snapshot.Discovered[resourceId] = true
		snapshot.KnownCount = tonumber(payload.KnownCount) or snapshot.KnownCount
		showToast("NUEVO DESCUBRIMIENTO · " .. definition.DisplayName, true)
	else
		showToast("+1  " .. definition.DisplayName, false)
	end

	refreshEntryButtons()
	if selectedResourceId == resourceId and currentTab == "Flora" then
		renderDetail(resourceId)
	end
end)
