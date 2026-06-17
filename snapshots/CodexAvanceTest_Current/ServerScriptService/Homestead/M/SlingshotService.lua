local SlingshotService = {}
SlingshotService.__index = SlingshotService

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local HomeCfg = require(script.Parent:WaitForChild("HomeCfg"))

local TOOL_NAMES = {
	Honda = true,
	Slingshot = true,
}

local function getCfg()
	return HomeCfg.Slingshot or {}
end

local function isFiniteNumber(value)
	return typeof(value) == "number" and value == value and math.abs(value) < 1e6
end

local function isFiniteVector3(value)
	return typeof(value) == "Vector3"
		and isFiniteNumber(value.X)
		and isFiniteNumber(value.Y)
		and isFiniteNumber(value.Z)
end

local function findEquippedSlingshot(character)
	if not character then
		return nil
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and TOOL_NAMES[child.Name] then
			return child
		end
	end

	return nil
end

function SlingshotService.new(inventoryService, remotes)
	local self = setmetatable({}, SlingshotService)

	self.InventoryService = inventoryService
	self.Remotes = remotes or {}
	self.NextFireAt = {}

	return self
end

function SlingshotService:GetAmmo(player)
	local cfg = getCfg()
	local itemId = cfg.AmmoItem or "Egg"

	if not self.InventoryService then
		return 0
	end

	return self.InventoryService:GetItemCount(player, itemId)
end

function SlingshotService:SyncAmmo(player)
	if not player then
		return 0
	end

	local cfg = getCfg()
	local itemId = cfg.AmmoItem or "Egg"
	local ammo = self:GetAmmo(player)

	player:SetAttribute("SlingshotEggAmmo", ammo)

	if self.Remotes.AmmoChanged then
		self.Remotes.AmmoChanged:FireClient(player, itemId, ammo)
	end

	return ammo
end

function SlingshotService:CanFire(player)
	local cfg = getCfg()
	local itemId = cfg.AmmoItem or "Egg"

	if not player or not player:IsA("Player") then
		return false, "NoPlayer", 0
	end

	if player:GetAttribute("CarryingChicken") == true then
		return false, "CarryingChicken", self:GetAmmo(player)
	end

	if player:GetAttribute("HomesteadStorageOpen") == true then
		return false, "StorageOpen", self:GetAmmo(player)
	end

	if player:GetAttribute("SlingshotMoveState") == "Run" then
		return false, "Sprinting", self:GetAmmo(player)
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if not character or not humanoid or humanoid.Health <= 0 or not root then
		return false, "CharacterInvalid", self:GetAmmo(player)
	end

	local flatVel = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	if flatVel.Magnitude > 16.5 then
		return false, "Sprinting", self:GetAmmo(player)
	end

	if not findEquippedSlingshot(character) then
		return false, "NoHondaEquipped", self:GetAmmo(player)
	end

	local now = os.clock()
	local nextFireAt = self.NextFireAt[player.UserId] or 0
	if now < nextFireAt then
		return false, "Cooldown", self:GetAmmo(player)
	end

	local ammo = self:GetAmmo(player)
	if ammo <= 0 then
		return false, "NoAmmo", 0
	end

	return true, "Ok", ammo, itemId
end

function SlingshotService:GetSafeOrigin(player, requestedOrigin)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local head = character and character:FindFirstChild("Head")
	local fallback = (head and head.Position) or (root and root.Position + Vector3.new(0, 1.5, 0)) or Vector3.zero

	if isFiniteVector3(requestedOrigin) and root and (requestedOrigin - root.Position).Magnitude <= 18 then
		return requestedOrigin
	end

	return fallback
end

function SlingshotService:Fire(player, origin, direction, charge)
	local cfg = getCfg()
	local itemId = cfg.AmmoItem or "Egg"
	local cooldown = cfg.Cooldown or 0.45
	local maxRange = cfg.MaxRange or 180
	local minCharge = cfg.MinChargeToFire or 0.05

	local canFire, reason, ammo = self:CanFire(player)
	if not canFire then
		if reason == "NoAmmo" and HomeCfg.Debug and HomeCfg.Debug.Slingshot then
			print("[Slingshot] NoAmmo", player and player.Name or "Unknown")
		end

		if self.Remotes.FireResult and player then
			self.Remotes.FireResult:FireClient(player, {
				Ok = false,
				Reason = reason,
				Ammo = ammo or 0,
			})
		end
		if player then
			player:SetAttribute("SlingshotEggAmmo", ammo or 0)
		end
		return false
	end

	if not isFiniteVector3(direction) or direction.Magnitude <= 0.001 then
		self.Remotes.FireResult:FireClient(player, {
			Ok = false,
			Reason = "InvalidDirection",
			Ammo = ammo,
		})
		return false
	end

	charge = math.clamp(tonumber(charge) or 0, 0, 1)
	if charge < minCharge then
		self.Remotes.FireResult:FireClient(player, {
			Ok = false,
			Reason = "LowCharge",
			Ammo = ammo,
		})
		return false
	end

	local okRemove, newAmmo = self.InventoryService:RemoveItem(player, itemId, 1)
	if not okRemove then
		newAmmo = newAmmo or self:GetAmmo(player)
		player:SetAttribute("SlingshotEggAmmo", newAmmo)
		self.Remotes.FireResult:FireClient(player, {
			Ok = false,
			Reason = "NoAmmo",
			Ammo = newAmmo,
		})
		if HomeCfg.Debug and HomeCfg.Debug.Slingshot then
			print("[Slingshot] NoAmmo", player.Name)
		end
		return false
	end

	self.NextFireAt[player.UserId] = os.clock() + cooldown
	player:SetAttribute("SlingshotEggAmmo", newAmmo)

	if self.Remotes.AmmoChanged then
		self.Remotes.AmmoChanged:FireClient(player, itemId, newAmmo)
	end

	local safeOrigin = self:GetSafeOrigin(player, origin)
	local unitDirection = direction.Unit
	local range = maxRange * math.clamp(0.55 + charge * 0.45, 0.55, 1)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	params.IgnoreWater = true

	local hit = Workspace:Raycast(safeOrigin, unitDirection * range, params)
	local hitPosition = safeOrigin + unitDirection * range
	local hitNormal = Vector3.yAxis
	local hitInstanceName = ""

	if hit then
		hitPosition = hit.Position
		hitNormal = hit.Normal
		hitInstanceName = hit.Instance and hit.Instance.Name or ""
	end

	local result = {
		Ok = true,
		Ammo = newAmmo,
		Origin = safeOrigin,
		HitPosition = hitPosition,
		HitNormal = hitNormal,
		HitInstance = hitInstanceName,
		Charge = charge,
		Range = range,
	}

	if self.Remotes.FireResult then
		self.Remotes.FireResult:FireClient(player, result)
	end

	if HomeCfg.Debug and HomeCfg.Debug.Slingshot then
		print(string.format("[Slingshot] %s fired Egg. Ammo=%d charge=%.2f", player.Name, newAmmo, charge))
	end

	return true, result
end

function SlingshotService:Setup()
	if not self.Remotes.FireRequest then
		warn("[Slingshot] FireRequest remote missing.")
		return
	end

	self.Remotes.FireRequest.OnServerEvent:Connect(function(player, origin, direction, charge)
		self:Fire(player, origin, direction, charge)
	end)

	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("SlingshotEggAmmo", self:GetAmmo(player))
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.NextFireAt[player.UserId] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		player:SetAttribute("SlingshotEggAmmo", self:GetAmmo(player))
	end
end

return SlingshotService