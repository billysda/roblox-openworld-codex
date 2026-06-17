local GrazingService = {}
GrazingService.__index = GrazingService

local Cfg = require(script.Parent.Cfg)

function GrazingService.new(houseService)
	local self = setmetatable({}, GrazingService)
	self.HouseService = houseService
	
	self.RuntimeFolder = workspace:FindFirstChild(Cfg.Grazing.RuntimeFolder)
	if not self.RuntimeFolder then
		self.RuntimeFolder = Instance.new("Folder")
		self.RuntimeFolder.Name = Cfg.Grazing.RuntimeFolder
		self.RuntimeFolder.Parent = workspace
	end
	
	self.ActiveZones = {} -- userId -> data
	self.LastCheckTime = 0
	self.LastMarkerTime = 0
	
	return self
end

function GrazingService:_debug(msg)
	if Cfg.Grazing.Debug then
		print("[Grazing] " .. msg)
	end
end

function GrazingService:Step(clockTime)
	if not Cfg.Grazing.Enabled then return end
	
	local dtCheck = clockTime - self.LastCheckTime
	if dtCheck >= Cfg.Grazing.CheckInterval then
		self.LastCheckTime = clockTime
		self:_updateZones(dtCheck)
		self:_cleanupLostPlayers()
	end
	
	local dtMarker = clockTime - self.LastMarkerTime
	if dtMarker >= Cfg.Grazing.MarkerUpdateInterval then
		self.LastMarkerTime = clockTime
		self:_updateMarkers()
	end
end

function GrazingService:_cleanupLostPlayers()
	for userId, zoneData in pairs(self.ActiveZones) do
		local player = game.Players:GetPlayerByUserId(userId)
		local data = self.HouseService.PlayerData[userId]
		
		if not player or not data or not data.House or not data.Flock then
			if zoneData.Folder then
				zoneData.Folder:Destroy()
			end
			self.ActiveZones[userId] = nil
		end
	end
end

function GrazingService:_updateZones(dt)
	for userId, data in pairs(self.HouseService.PlayerData) do
		local player = game.Players:GetPlayerByUserId(userId)
		if player and data.House and data.Flock then
			self:_ensurePlayerAttributes(player)
			self:_handlePlayerZone(player, data.House, data.Flock, dt)
		end
	end
end

function GrazingService:_ensurePlayerAttributes(player)
	if player:GetAttribute("PastureFlockLevel") == nil then
		player:SetAttribute("PastureFlockLevel", 1)
		player:SetAttribute("PastureFlockXP", 0)
		player:SetAttribute("PastureGrassEaten", 0)
		player:SetAttribute("PastureGrassGoal", Cfg.Grazing.GrassGoal)
		player:SetAttribute("PastureSheepInside", 0)
		player:SetAttribute("PastureSheepRequired", Cfg.Grazing.MinSheepInside)
		player:SetAttribute("PastureZoneIndex", 1)
	end
end

function GrazingService:_handlePlayerZone(player, house, flock, dt)
	local userId = player.UserId
	local zoneData = self.ActiveZones[userId]
	
	if not zoneData then
		zoneData = self:_createZoneForPlayer(player, house, flock)
		if not zoneData then return end
		self.ActiveZones[userId] = zoneData
	end
	
	-- Count sheep inside
	local insideCount = 0
	local activeSheepCount = 0
	
	if flock.Sheep then
		for _, sheep in pairs(flock.Sheep) do
			if sheep.Model and not sheep.Model:GetAttribute("CapturedByDragon") and sheep.Root then
				activeSheepCount = activeSheepCount + 1
				-- Solo distancia horizontal
				local hDist = Vector3.new(sheep.Root.Position.X, 0, sheep.Root.Position.Z) - Vector3.new(zoneData.Position.X, 0, zoneData.Position.Z)
				if hDist.Magnitude <= Cfg.Grazing.ZoneRadius then
					insideCount = insideCount + 1
				end
			end
		end
	end
	
	local requiredCount = Cfg.Grazing.MinSheepInside
	if Cfg.Grazing.RequireAllSheep then
		requiredCount = math.max(Cfg.Grazing.MinSheepInside, activeSheepCount)
	end
	
	player:SetAttribute("PastureSheepInside", insideCount)
	player:SetAttribute("PastureSheepRequired", requiredCount)
	
	if insideCount >= requiredCount then
		local progress = player:GetAttribute("PastureGrassEaten") or 0
		progress = progress + (Cfg.Grazing.GrassPerSecond * dt)
		
		local goal = player:GetAttribute("PastureGrassGoal") or Cfg.Grazing.GrassGoal
		
		if progress >= goal then
			progress = 0
			local zoneIndex = (player:GetAttribute("PastureZoneIndex") or 1) + 1
			player:SetAttribute("PastureZoneIndex", zoneIndex)
			
			local xp = (player:GetAttribute("PastureFlockXP") or 0) + Cfg.Grazing.XPPerZone
			local level = player:GetAttribute("PastureFlockLevel") or 1
			
			self:_debug(string.format("Zona completada %s XP=%d Level=%d", player.Name, Cfg.Grazing.XPPerZone, level))
			
			if xp >= Cfg.Grazing.XPToNextLevel then
				xp = xp - Cfg.Grazing.XPToNextLevel
				level = level + 1
				player:SetAttribute("PastureFlockLevel", level)
				self:_debug(string.format("Rebaño subió de nivel %s Level=%d", player.Name, level))
			end
			player:SetAttribute("PastureFlockXP", xp)
			
			-- Remove old zone
			if zoneData.Folder then
				zoneData.Folder:Destroy()
			end
			self.ActiveZones[userId] = nil
		end
		
		player:SetAttribute("PastureGrassEaten", progress)
	end
end

function GrazingService:_createZoneForPlayer(player, house, flock)
	local basePos = nil
	if house.CorralCenter then
		basePos = house.CorralCenter.Position
	elseif flock.Center then
		basePos = flock.Center
	end
	
	if not basePos then return nil end
	
	local angle = math.random() * math.pi * 2
	local dist = Cfg.Grazing.ZoneDistanceMin + math.random() * (Cfg.Grazing.ZoneDistanceMax - Cfg.Grazing.ZoneDistanceMin)
	local offset = Vector3.new(math.cos(angle) * dist, 50, math.sin(angle) * dist)
	
	local rayStart = basePos + offset
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	
	-- No es necesario filtrar si solo queremos el suelo, pero si hay problemas
	-- con colisiones se podría usar FilterDescendantsInstances
	
	local raycastResult = workspace:Raycast(rayStart, Vector3.new(0, -100, 0))
	local zonePos = basePos + Vector3.new(offset.X, 0, offset.Z) + Vector3.new(0, Cfg.Grazing.ZoneYOffset, 0)
	
	if raycastResult then
		zonePos = raycastResult.Position + Vector3.new(0, Cfg.Grazing.ZoneYOffset, 0)
	end
	
	local folder = Instance.new("Folder")
	folder.Name = "Grazing_" .. player.UserId
	folder.Parent = self.RuntimeFolder
	
	local zonePart = Instance.new("Part")
	zonePart.Name = "GrazingZone"
	zonePart.Anchored = true
	zonePart.CanCollide = false
	zonePart.CanTouch = false
	zonePart.CanQuery = false
	zonePart.Shape = Enum.PartType.Cylinder
	zonePart.Size = Vector3.new(Cfg.Grazing.ZoneHeight, Cfg.Grazing.ZoneRadius * 2, Cfg.Grazing.ZoneRadius * 2)
	zonePart.CFrame = CFrame.new(zonePos) * CFrame.Angles(0, 0, math.pi/2)
	zonePart.Transparency = 0.55
	zonePart.Material = Enum.Material.Neon
	zonePart.Color = Color3.fromRGB(150, 255, 150)
	zonePart.Parent = folder
	
	local anchor = Instance.new("Part")
	anchor.Name = "FlockLabelAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1,1,1)
	anchor.Position = zonePos + Vector3.new(0, Cfg.Grazing.LabelHeight, 0)
	anchor.Parent = folder
	
	local bgui = Instance.new("BillboardGui")
	bgui.Name = "ProgressGui"
	bgui.Size = UDim2.new(0, 200, 0, 80)
	bgui.StudsOffset = Vector3.new(0, 0, 0)
	bgui.AlwaysOnTop = true
	
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.TextScaled = true
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextStrokeTransparency = 0
	textLabel.Parent = bgui
	
	bgui.Parent = anchor
	
	local zoneIndex = player:GetAttribute("PastureZoneIndex") or 1
	self:_debug(string.format("Zona creada %s #%d", player.Name, zoneIndex))
	
	return {
		Folder = folder,
		Position = zonePos,
		Anchor = anchor,
		TextLabel = textLabel
	}
end

function GrazingService:_updateMarkers()
	for userId, zoneData in pairs(self.ActiveZones) do
		local player = game.Players:GetPlayerByUserId(userId)
		local data = self.HouseService.PlayerData[userId]
		
		if player and data and data.Flock then
			if data.Flock.Center then
				zoneData.Anchor.Position = data.Flock.Center + Vector3.new(0, Cfg.Grazing.LabelHeight, 0)
			else
				zoneData.Anchor.Position = zoneData.Position + Vector3.new(0, Cfg.Grazing.LabelHeight, 0)
			end
			
			local eaten = math.floor(player:GetAttribute("PastureGrassEaten") or 0)
			local goal = player:GetAttribute("PastureGrassGoal") or Cfg.Grazing.GrassGoal
			local inside = player:GetAttribute("PastureSheepInside") or 0
			local req = player:GetAttribute("PastureSheepRequired") or 2
			local lvl = player:GetAttribute("PastureFlockLevel") or 1
			local xp = player:GetAttribute("PastureFlockXP") or 0
			
			zoneData.TextLabel.Text = string.format("Pasto consumido: %d/%d\nOvejas: %d/%d\nRebaño Nv.%d  XP %d/%d", 
				eaten, goal, inside, req, lvl, xp, Cfg.Grazing.XPToNextLevel)
		end
	end
end

return GrazingService
