local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remoteFolder = ReplicatedStorage:WaitForChild("PastureRemote")
local whistleEvent = remoteFolder:WaitForChild("Whistle")
local commandTargetEvent = remoteFolder:WaitForChild("CommandTarget", 10)

local MAX_COMMAND_DISTANCE = 220
local PASTURE_STAFF_ATTRIBUTE = "PastureStaff"

if not commandTargetEvent then
	warn("[PastureClient] CommandTarget remote no encontrado; F/silbido sigue disponible.")
end

local marker = nil
local characterChildAddedConnection = nil
local characterChildRemovedConnection = nil

local playerGui = player:WaitForChild("PlayerGui")
local pastureGui = playerGui:WaitForChild("PastureHUD", 10)
local mobileActions = pastureGui and pastureGui:FindFirstChild("MobileActions") or nil
local whistleButton = mobileActions and mobileActions:FindFirstChild("WhistleButton") or nil
local commandButton = mobileActions and mobileActions:FindFirstChild("CommandButton") or nil
local commandReticle = pastureGui and pastureGui:FindFirstChild("CommandReticle") or nil

local grazingPanel = pastureGui and pastureGui:FindFirstChild("GrazingPanel") or nil
local foxWarningCenter = pastureGui and pastureGui:FindFirstChild("FoxWarningCenter") or nil

local warningTween = nil

if not pastureGui then
	warn("[PastureClient] PastureHUD no encontrado; los controles PC siguen disponibles.")
end

local function getPlayerRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getEquippedPastureStaff()
	local character = player.Character
	if not character then
		return nil
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute(PASTURE_STAFF_ATTRIBUTE) == true then
			return child
		end
	end

	return nil
end

local function flatDistance(a, b)
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

local function getRaycastParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true

	if player.Character then
		params.FilterDescendantsInstances = { player.Character }
	end

	return params
end

local function raycastGround(origin, direction)
	local result = Workspace:Raycast(origin, direction, getRaycastParams())
	return result and result.Position or nil
end

local function getMouseGroundPosition()
	local mouse = player:GetMouse()
	local ray = mouse.UnitRay
	return raycastGround(ray.Origin, ray.Direction * 500)
end

local function getCenterScreenGroundPosition()
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	local viewportSize = camera.ViewportSize
	local ray = camera:ViewportPointToRay(viewportSize.X * 0.5, viewportSize.Y * 0.5)
	return raycastGround(ray.Origin, ray.Direction * 500)
end

local function showMarker(position)
	if marker then
		marker:Destroy()
	end

	marker = Instance.new("Part")
	marker.Name = "PastureCommandTargetMarker"
	marker.Shape = Enum.PartType.Cylinder
	marker.Size = Vector3.new(0.15, 4, 4)
	marker.CFrame = CFrame.new(position + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.Material = Enum.Material.Neon
	marker.Color = Color3.fromRGB(80, 220, 120)
	marker.Transparency = 0.25
	marker.Parent = Workspace

	Debris:AddItem(marker, 2)
end

local function requestWhistle()
	whistleEvent:FireServer()
end

local function requestCommandTarget(positionProvider)
	if not commandTargetEvent then
		return
	end

	if not getEquippedPastureStaff() then
		return
	end

	local position = positionProvider and positionProvider() or nil
	if not position then
		return
	end

	local root = getPlayerRoot()
	if not root then
		return
	end

	if flatDistance(position, root.Position) > MAX_COMMAND_DISTANCE then
		warn("[PastureClient] Destino demasiado lejos para el rebaño.")
		return
	end

	showMarker(position)
	commandTargetEvent:FireServer(position)
end

local function syncButtonFallback(button)
	if not button then
		return
	end

	local icon = button:FindFirstChild("Icon")
	local fallback = button:FindFirstChild("Fallback")
	if not fallback or not fallback:IsA("GuiObject") then
		return
	end

	local function refresh()
		local hasImage = icon and icon:IsA("ImageLabel") and icon.Image ~= ""
		fallback.Visible = not hasImage
	end

	refresh()

	if icon and icon:IsA("ImageLabel") then
		icon:GetPropertyChangedSignal("Image"):Connect(refresh)
	end
end

local function refreshTouchUi()
	local usingTouch = UserInputService.PreferredInput == Enum.PreferredInput.Touch
	local hasStaff = getEquippedPastureStaff() ~= nil

	if mobileActions then
		mobileActions.Visible = usingTouch
	end

	if whistleButton then
		whistleButton.Visible = usingTouch
	end

	if commandButton then
		commandButton.Visible = usingTouch and hasStaff and commandTargetEvent ~= nil
	end

	if commandReticle then
		commandReticle.Visible = usingTouch and hasStaff and commandTargetEvent ~= nil
	end
end

-- Pasture HUD v5 Data Synchronization
local function refreshGrazingHud()
	if not grazingPanel then
		return
	end

	local eaten = math.floor(player:GetAttribute("PastureGrassEaten") or 0)
	local goal = player:GetAttribute("PastureGrassGoal") or 100
	local inside = player:GetAttribute("PastureSheepInside") or 0
	local required = player:GetAttribute("PastureSheepRequired") or 2
	local level = player:GetAttribute("PastureFlockLevel") or 1
	local xp = player:GetAttribute("PastureFlockXP") or 0
	local xpGoal = 100

	local grassStat = grazingPanel:FindFirstChild("GrassStat")
	if grassStat and grassStat:FindFirstChild("Value") then
		grassStat.Value.Text = string.format("%d / %d", eaten, goal)
	end

	local sheepStat = grazingPanel:FindFirstChild("SheepStat")
	if sheepStat and sheepStat:FindFirstChild("Value") then
		sheepStat.Value.Text = string.format("%d / %d", inside, required)
	end

	local levelLabel = grazingPanel:FindFirstChild("LevelLabel")
	if levelLabel then
		levelLabel.Text = string.format("Rebaño Nv.%d", level)
	end

	local xpLabel = grazingPanel:FindFirstChild("XPLabel")
	if xpLabel then
		xpLabel.Text = string.format("XP %d / %d", xp, xpGoal)
	end

	grazingPanel.Visible = (eaten > 0 or inside > 0)
end

local function refreshFoxWarning()
	if not foxWarningCenter then
		return
	end

	local active = player:GetAttribute("PastureFoxWarning") == true
	local customText = player:GetAttribute("PastureFoxWarningText")
	local label = foxWarningCenter:FindFirstChild("Label")

	if label and typeof(customText) == "string" and customText ~= "" then
		label.Text = customText
	elseif label then
		label.Text = "ZORRO CERCA"
	end

	if warningTween then
		warningTween:Cancel()
		warningTween = nil
	end

	local targetSize = UDim2.fromOffset(220, 46)
	local popSize = UDim2.fromOffset(211, 44) -- 0.96 scale pop

	if active then
		foxWarningCenter.Visible = true
		foxWarningCenter.Size = popSize
		foxWarningCenter.BackgroundTransparency = 1
		local stroke = foxWarningCenter:FindFirstChildOfClass("UIStroke")
		if stroke then stroke.Transparency = 1 end

		local tweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		warningTween = TweenService:Create(foxWarningCenter, tweenInfo, {
			Size = targetSize,
			BackgroundTransparency = 0.08
		})
		warningTween:Play()
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.18), { Transparency = 0.15 }):Play()
		end
	else
		local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		warningTween = TweenService:Create(foxWarningCenter, tweenInfo, {
			Size = popSize,
			BackgroundTransparency = 1
		})
		local stroke = foxWarningCenter:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, tweenInfo, { Transparency = 1 }):Play()
		end
		warningTween.Completed:Connect(function()
			if player:GetAttribute("PastureFoxWarning") ~= true then
				foxWarningCenter.Visible = false
				foxWarningCenter.Size = targetSize
			end
		end)
		warningTween:Play()
	end
end

local function bindCharacter(character)
	if characterChildAddedConnection then
		characterChildAddedConnection:Disconnect()
		characterChildAddedConnection = nil
	end

	if characterChildRemovedConnection then
		characterChildRemovedConnection:Disconnect()
		characterChildRemovedConnection = nil
	end

	if character then
		characterChildAddedConnection = character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				refreshTouchUi()
			end
		end)

		characterChildRemovedConnection = character.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				refreshTouchUi()
			end
		end)
	end

	task.defer(refreshTouchUi)
end

syncButtonFallback(whistleButton)
syncButtonFallback(commandButton)
refreshTouchUi()

player.AttributeChanged:Connect(function(attr)
	if string.sub(attr, 1, 7) == "Pasture" then
		refreshGrazingHud()
		if attr == "PastureFoxWarning" or attr == "PastureFoxWarningText" then
			refreshFoxWarning()
		end
	end
end)

refreshGrazingHud()
refreshFoxWarning()

UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(refreshTouchUi)
player.CharacterAdded:Connect(bindCharacter)

if player.Character then
	bindCharacter(player.Character)
end

if whistleButton and whistleButton:IsA("GuiButton") then
	whistleButton.Activated:Connect(function()
		requestWhistle()
	end)
end

if commandButton and commandButton:IsA("GuiButton") then
	commandButton.Activated:Connect(function()
		requestCommandTarget(getCenterScreenGroundPosition)
	end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.F then
		requestWhistle()
	elseif input.KeyCode == Enum.KeyCode.G then
		requestCommandTarget(getMouseGroundPosition)
	end
end)
