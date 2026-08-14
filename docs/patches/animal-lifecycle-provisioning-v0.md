# Animal Lifecycle & Provisioning v0

## Goal
Close the first farm -> dragon-food loop without adding a dragon yet:

`2+ adults -> birth -> juvenile -> adult -> optional provisioning -> DragonMeatRation`

The system must protect 2 breeder adults by default and expose a recovery pair only when a species reaches zero by some external/system loss.

## Performance rules
- One central lifecycle tick at 1 Hz.
- No Script/LocalScript inside animals.
- No new Heartbeat/RenderStepped loops.
- Existing animal AI loops remain unchanged.
- Population hard cap v0: 4 physical animals per species/player.
- Session only. No DataStore in v0.

## New exact files
Transfer exact Source from branch `feature/animal-lifecycle-provisioning-v0`:
- `snapshots/CodexAvanceTest_Current/ReplicatedStorage/FarmLifecycleCatalog.lua`
- `snapshots/CodexAvanceTest_Current/ServerScriptService/Shared/FarmAnimalRegistry.lua`
- `snapshots/CodexAvanceTest_Current/ServerScriptService/FarmLifecycle/Main.server.lua`
- `snapshots/CodexAvanceTest_Current/ServerScriptService/FarmLifecycle/M/FarmLifecycleService.lua`
- `snapshots/CodexAvanceTest_Current/StarterPlayerScripts/FarmLifecycleClient.client.lua`

## Adapter contract
Registered species adapters expose:
- `GetPopulation(player)` -> `{Adults, Juveniles, Total}` or nil
- `SpawnJuvenile(player, adultAt)` -> bool
- `PromoteReady(player, now)` -> integer promoted
- `ProcessAdult(player)` -> bool
- `SpawnAdult(player)` -> bool

The registry is only a server-side table. No RemoteEvent carries an animal Instance.

---

# PATCH A — Pasture Flock.lua

Work on CURRENT Studio Source; preserve terrain alignment, grazing, G/F, Capture/Fox and every existing behavior.

### A1. In `Flock.new`, immediately after `self.Sheep = {}` add:
```lua
self.NextSheepIndex = 1
```

### A2. In the existing initial spawn loop, immediately after cloning/naming the sheep model and before `Sheep.new`, set:
```lua
sheepModel:SetAttribute("FarmSpecies", "Sheep")
sheepModel:SetAttribute("AgeStage", "Adult")
sheepModel:SetAttribute("AdultAt", 0)
sheepModel:SetAttribute("LifecycleManaged", true)
```

After the initial spawn loop and before assigning leader, add:
```lua
self.NextSheepIndex = math.max(self.NextSheepIndex, amount + 1)
```

### A3. Add these exact lifecycle methods before `Flock:Destroy()`:
```lua
function Flock:GetLifecyclePopulation()
	local adults = 0
	local juveniles = 0
	for _, sheep in ipairs(self.Sheep) do
		local model = sheep.Model
		if model and model.Parent then
			if model:GetAttribute("AgeStage") == "Juvenile" then
				juveniles += 1
			else
				adults += 1
			end
		end
	end
	return { Adults = adults, Juveniles = juveniles, Total = adults + juveniles }
end

function Flock:_getLifecycleSpawnCFrame()
	local basePosition = self.Center
	if not basePosition and self.PenCenterPart and self.PenCenterPart.Parent then
		basePosition = self.PenCenterPart.Position
	end
	if not basePosition then
		local folder = self.House and self.House:FindFirstChild(Cfg.Names.SpawnFolder)
		local first = folder and folder:FindFirstChildWhichIsA("BasePart")
		basePosition = first and first.Position or Vector3.zero
	end
	local index = self.NextSheepIndex or (#self.Sheep + 1)
	local angle = math.rad((index * 137) % 360)
	local offset = Vector3.new(math.cos(angle) * 2.2, 0, math.sin(angle) * 2.2)
	return CFrame.new(basePosition + offset + Vector3.new(0, Cfg.SpawnYOffset, 0))
end

function Flock:_spawnLifecycleSheep(stage, adultAt, scale)
	if not self.Template or not self.Folder or not self.Folder.Parent then
		return false
	end
	local index = self.NextSheepIndex or (#self.Sheep + 1)
	self.NextSheepIndex = index + 1

	local model = self.Template:Clone()
	model.Name = "Sheep_" .. self.Player.UserId .. "_" .. index
	model:SetAttribute("FarmSpecies", "Sheep")
	model:SetAttribute("AgeStage", stage)
	model:SetAttribute("AdultAt", adultAt or 0)
	model:SetAttribute("LifecycleManaged", true)

	if stage == "Juvenile" and scale and scale < 1 then
		pcall(function()
			model:ScaleTo(scale)
		end)
	end

	model.Parent = self.Folder
	if not model.PrimaryPart then
		local root = model:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			model.PrimaryPart = root
		else
			model:Destroy()
			return false
		end
	end

	model:PivotTo(self:_getLifecycleSpawnCFrame() * CFrame.Angles(0, math.rad(math.random(0, 359)), 0))
	local sheep = Sheep.new(model, self.Player, self.House, index)
	if not sheep or not sheep.Root then
		model:Destroy()
		return false
	end
	table.insert(self.Sheep, sheep)

	if not self.Leader or not self.Leader.Model or not self.Leader.Model.Parent then
		self.Leader = sheep
		model:SetAttribute("IsLeader", true)
		model.Name = model.Name .. "_Leader"
	end
	return true
end

function Flock:SpawnLifecycleJuvenile(adultAt, scale)
	return self:_spawnLifecycleSheep("Juvenile", adultAt, scale)
end

function Flock:SpawnLifecycleAdult()
	return self:_spawnLifecycleSheep("Adult", 0, 1)
end

function Flock:PromoteLifecycleReady(now)
	local promoted = 0
	for _, sheep in ipairs(self.Sheep) do
		local model = sheep.Model
		if model and model.Parent and model:GetAttribute("AgeStage") == "Juvenile" then
			local adultAt = tonumber(model:GetAttribute("AdultAt")) or math.huge
			if now >= adultAt then
				pcall(function()
					model:ScaleTo(1)
				end)
				model:SetAttribute("AgeStage", "Adult")
				model:SetAttribute("AdultAt", 0)
				promoted += 1
			end
		end
	end
	return promoted
end

function Flock:ProcessLifecycleAdult()
	for i = #self.Sheep, 1, -1 do
		local sheep = self.Sheep[i]
		local model = sheep.Model
		local blocked = model and (
			model:GetAttribute("IsLeader") == true
			or model:GetAttribute("CapturedByThreat") == true
			or model:GetAttribute("CapturedByDragon") == true
		)
		if model and model.Parent and model:GetAttribute("AgeStage") ~= "Juvenile" and not blocked then
			sheep:Destroy()
			table.remove(self.Sheep, i)
			return true
		end
	end
	return false
end
```

Do not change Sheep movement/physics logic in this issue. If ScaleTo causes visible hover offset, report it; do not improvise a physics rewrite.

---

# PATCH B — Pasture Main.lua adapter

Add service:
```lua
local ServerScriptService = game:GetService("ServerScriptService")
```

After current local modules are loaded and after `houseService` exists, require:
```lua
local FarmLifecycleCatalog = require(ReplicatedStorage:WaitForChild("FarmLifecycleCatalog"))
local FarmAnimalRegistry = require(ServerScriptService:WaitForChild("Shared"):WaitForChild("FarmAnimalRegistry"))
```

Register after `houseService` construction:
```lua
FarmAnimalRegistry.Register("Sheep", {
	GetPopulation = function(player)
		local data = houseService.PlayerData[player.UserId]
		local flock = data and data.Flock
		return flock and flock:GetLifecyclePopulation() or nil
	end,
	SpawnJuvenile = function(player, adultAt)
		local data = houseService.PlayerData[player.UserId]
		local flock = data and data.Flock
		local cfg = FarmLifecycleCatalog.Get("Sheep")
		return flock and flock:SpawnLifecycleJuvenile(adultAt, cfg.JuvenileScale) or false
	end,
	PromoteReady = function(player, now)
		local data = houseService.PlayerData[player.UserId]
		local flock = data and data.Flock
		return flock and flock:PromoteLifecycleReady(now) or 0
	end,
	ProcessAdult = function(player)
		local data = houseService.PlayerData[player.UserId]
		local flock = data and data.Flock
		return flock and flock:ProcessLifecycleAdult() or false
	end,
	SpawnAdult = function(player)
		local data = houseService.PlayerData[player.UserId]
		local flock = data and data.Flock
		return flock and flock:SpawnLifecycleAdult() or false
	end,
})
```

---

# PATCH C — Chicken.lua juvenile egg guard

At the very beginning of `Chicken:CanStartEgg()` after function declaration add exactly:
```lua
if self.Model and self.Model:GetAttribute("AgeStage") == "Juvenile" then
	return false
end
```

No other Chicken behavior changes.

---

# PATCH D — AnimalService.lua

Preserve carry, EggService, Chicken/Cuy movement and all current HomeData behavior.

### D1. Ensure each `PlayerAnimals` data table stores current `HomeData`.
Whenever data is created/recreated in `RefreshPlayer`, include:
```lua
HomeData = homeData,
```
And after the house-change block add:
```lua
data.HomeData = homeData
```

### D2. Mark the existing initial Chicken and Cuy as adults before their constructor call:
For chicken clones:
```lua
model:SetAttribute("FarmSpecies", "Chicken")
model:SetAttribute("AgeStage", "Adult")
model:SetAttribute("AdultAt", 0)
model:SetAttribute("LifecycleManaged", true)
```
For Cuy clones use `FarmSpecies = "Cuy"` with the same remaining attributes.

### D3. Add exact helpers before `AnimalService:Step(dt)`:
```lua
local function lifecycleList(data, speciesId)
	if speciesId == "Chicken" then return data and data.Chickens end
	if speciesId == "Cuy" then return data and data.Cuys end
	return nil
end

local function nextAnimalIndex(list)
	local maxIndex = 0
	for _, animal in ipairs(list or {}) do
		maxIndex = math.max(maxIndex, tonumber(animal.Index) or 0)
	end
	return maxIndex + 1
end

function AnimalService:GetLifecyclePopulation(player, speciesId)
	local data = self.PlayerAnimals[player.UserId]
	if not data or not data.HomeData then
		return nil
	end
	local list = lifecycleList(data, speciesId)
	if not list then return nil end
	local adults, juveniles = 0, 0
	for _, animal in ipairs(list) do
		local model = animal.Model
		if model and model.Parent then
			if model:GetAttribute("AgeStage") == "Juvenile" then juveniles += 1 else adults += 1 end
		end
	end
	return { Adults = adults, Juveniles = juveniles, Total = adults + juveniles }
end

function AnimalService:_spawnLifecycleAnimal(player, speciesId, stage, adultAt, scale)
	local data = self.PlayerAnimals[player.UserId]
	local homeData = data and data.HomeData
	if not data or not homeData then return false end
	local list = lifecycleList(data, speciesId)
	if not list then return false end

	local index = nextAnimalIndex(list)
	if speciesId == "Chicken" then
		if not self.ChickenTemplate then return false end
		local spawns = self:GetChickenSpawns(homeData.House)
		if #spawns == 0 then return false end
		local spawn = spawns[((index - 1) % #spawns) + 1]
		local model = self.ChickenTemplate:Clone()
		model.Name = "Chicken_" .. player.UserId .. "_" .. index
		model:SetAttribute("FarmSpecies", "Chicken")
		model:SetAttribute("AgeStage", stage)
		model:SetAttribute("AdultAt", adultAt or 0)
		model:SetAttribute("LifecycleManaged", true)
		if stage == "Juvenile" and scale and scale < 1 then pcall(function() model:ScaleTo(scale) end) end
		local _, chickenFolder = self:GetAnimalRoot(homeData)
		model.Parent = chickenFolder
		local chicken = Chicken.new(model, player, homeData.House, spawn, index, self.EggService, homeData, self)
		table.insert(list, chicken)
		return true
	end

	if speciesId == "Cuy" then
		if not self.CuyTemplate then return false end
		local spawns = self:GetCuySpawns(homeData.House)
		if #spawns == 0 then return false end
		local spawn = spawns[((index - 1) % #spawns) + 1]
		local model = self.CuyTemplate:Clone()
		model.Name = "Cuy_" .. player.UserId .. "_" .. index
		model:SetAttribute("FarmSpecies", "Cuy")
		model:SetAttribute("AgeStage", stage)
		model:SetAttribute("AdultAt", adultAt or 0)
		model:SetAttribute("LifecycleManaged", true)
		if stage == "Juvenile" and scale and scale < 1 then pcall(function() model:ScaleTo(scale) end) end
		local _, _, _, cuyFolder = self:GetAnimalRoot(homeData)
		model.Parent = cuyFolder
		local cuy = Cuy.new(model, player, homeData.House, spawn, index, self)
		table.insert(list, cuy)
		return true
	end
	return false
end

function AnimalService:SpawnLifecycleJuvenile(player, speciesId, adultAt, scale)
	return self:_spawnLifecycleAnimal(player, speciesId, "Juvenile", adultAt, scale)
end

function AnimalService:SpawnLifecycleAdult(player, speciesId)
	return self:_spawnLifecycleAnimal(player, speciesId, "Adult", 0, 1)
end

function AnimalService:PromoteLifecycleReady(player, speciesId, now)
	local data = self.PlayerAnimals[player.UserId]
	local list = lifecycleList(data, speciesId)
	if not list then return 0 end
	local promoted = 0
	for _, animal in ipairs(list) do
		local model = animal.Model
		if model and model.Parent and model:GetAttribute("AgeStage") == "Juvenile" then
			local adultAt = tonumber(model:GetAttribute("AdultAt")) or math.huge
			if now >= adultAt then
				pcall(function() model:ScaleTo(1) end)
				model:SetAttribute("AgeStage", "Adult")
				model:SetAttribute("AdultAt", 0)
				if speciesId == "Chicken" and animal.GetNextEggCooldown then
					animal.NextEggAt = os.clock() + animal:GetNextEggCooldown()
				end
				promoted += 1
			end
		end
	end
	return promoted
end

function AnimalService:ProcessLifecycleAdult(player, speciesId)
	local data = self.PlayerAnimals[player.UserId]
	local list = lifecycleList(data, speciesId)
	if not list then return false end
	for i = #list, 1, -1 do
		local animal = list[i]
		local model = animal.Model
		local blocked = speciesId == "Chicken" and animal.CarriedBy ~= nil
		if model and model.Parent and model:GetAttribute("AgeStage") ~= "Juvenile" and not blocked then
			animal:Destroy()
			table.remove(list, i)
			return true
		end
	end
	return false
end
```

---

# PATCH E — Homestead Main.lua adapters

Add:
```lua
local ServerScriptService = game:GetService("ServerScriptService")
```

After `animalService` exists, require:
```lua
local FarmLifecycleCatalog = require(ReplicatedStorage:WaitForChild("FarmLifecycleCatalog"))
local FarmAnimalRegistry = require(ServerScriptService:WaitForChild("Shared"):WaitForChild("FarmAnimalRegistry"))
```

Register BOTH species:
```lua
for _, speciesId in ipairs({ "Chicken", "Cuy" }) do
	FarmAnimalRegistry.Register(speciesId, {
		GetPopulation = function(player)
			return animalService:GetLifecyclePopulation(player, speciesId)
		end,
		SpawnJuvenile = function(player, adultAt)
			local cfg = FarmLifecycleCatalog.Get(speciesId)
			return animalService:SpawnLifecycleJuvenile(player, speciesId, adultAt, cfg.JuvenileScale)
		end,
		PromoteReady = function(player, now)
			return animalService:PromoteLifecycleReady(player, speciesId, now)
		end,
		ProcessAdult = function(player)
			return animalService:ProcessLifecycleAdult(player, speciesId)
		end,
		SpawnAdult = function(player)
			return animalService:SpawnLifecycleAdult(player, speciesId)
		end,
	})
end
```

---

# StarterGui.FarmLifecycleUI exact hierarchy

Create GUI objects only, 0 scripts inside:

```text
FarmLifecycleUI (ScreenGui, ResetOnSpawn=false, IgnoreGuiInset=false)
├─ OpenButton (TextButton) Text="Animales [N]"
├─ MainPanel (Frame, Visible=false, 430x330, centered)
│  ├─ UICorner radius 6
│  ├─ UIStroke bronze 1.5
│  ├─ Header (Frame)
│  │  ├─ Title (TextLabel) "GRANJA · ANIMALES"
│  │  └─ CloseButton (TextButton) "×"
│  ├─ RationsLabel (TextLabel) "Raciones de carne: 0"
│  ├─ ModeLabel (TextLabel)
│  └─ Rows (Frame)
│     ├─ UIListLayout vertical padding 7
│     ├─ SheepRow (Frame)
│     │  ├─ Name (TextLabel) "Ovejas"
│     │  ├─ Counts (TextLabel)
│     │  ├─ Reserve (TextLabel)
│     │  ├─ ProcessButton (TextButton)
│     │  └─ RecoveryButton (TextButton, Visible=false) "Recuperar pareja"
│     ├─ ChickenRow (same names; Name="Gallinas")
│     └─ CuyRow (same names; Name="Cuyes")
└─ Toast (TextLabel, Visible=false, top-center)
```

Visual style: native GUI only, dark leather brown background `Color3.fromRGB(50,35,24)`, muted bronze stroke `Color3.fromRGB(166,136,90)`, cream text `Color3.fromRGB(236,222,190)`. No raster background. Keep it readable, not decorative-heavy; this is a gameplay test panel.

Suggested placement:
- OpenButton bottom-left, above default hotbar safe area.
- MainPanel centered.
- Each row approx 390x72.

`FarmLifecycleClient` is the ONLY LocalScript/controller.

---

# Required test behavior

`FarmLifecycleCatalog.TestFastMode = true` for this phase.

Starting expected populations after house ownership systems initialize:
- Sheep: 2 adults / 0 juvenile / cap 4.
- Chicken: 3 adults / 0 juvenile / cap 4.
- Cuy: 2 adults / 0 juvenile / cap 4.

Expected fast cycle:
- Cuy birth ~14 s, grows ~10 s later.
- Chicken birth ~18 s, grows ~14 s later.
- Sheep birth ~22 s, grows ~18 s later.

At cap 4 reproduction pauses automatically.

Provisioning examples after surplus adult exists:
- Sheep adult -> +8 `DragonMeatRation` session units.
- Chicken adult -> +4.
- Cuy adult -> +2.

The Process button MUST be disabled whenever Adults <= 2. Juveniles are never processable.

Recovery pair:
- only visible/usable if Total == 0;
- spawns up to 2 adults;
- 60 s session cooldown;
- no coins in v0. This is anti-softlock infrastructure only.

## Protected systems
Do not alter:
- Predator/Fox capture logic;
- Grazing logic;
- Pasture G/F;
- Slingshot;
- Chicken carry semantics;
- EggService / InventoryService;
- Mythic Resources / Codex;
- PastureHUD v5.

## Mandatory validation
1. Claim house and wait for all three animal systems.
2. Open N panel: initial counts correct.
3. Observe physically smaller juvenile Cuy, Chicken and Sheep appearing according to fast test intervals.
4. Juvenile Chicken does NOT lay eggs.
5. Juveniles grow visually to adult and UI counts update.
6. Population never exceeds cap 4 for a species.
7. With 3+ adults, process one surplus animal; no blood/death visual, model simply leaves world and rations increase.
8. UI refuses processing at exactly 2 adults.
9. Sheep leader is never selected for provisioning.
10. Captured Sheep cannot be provisioned.
11. Carried Chicken cannot be provisioned.
12. Fox/Pasture/Slingshot/Mythic systems still work.
13. `scriptsInFarmLifecycleUI = 0`.
14. No new Heartbeat/RenderStepped loops.
15. 0 red errors.

Do not merge main. Do not hard reset or force push. Apply surgical hooks to CURRENT Studio Source.
