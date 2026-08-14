# AnimalService ForceDrop closure fix v1

## Root cause
Issue #36 inserted the lifecycle helpers immediately after the internal `if chicken.ForceDrop then ... else ... end` block inside `AnimalService:ForceDropCarriedChicken`, but failed to restore the original function tail:

```lua
return ok
end
```

As a result, every lifecycle helper beginning at `local function lifecycleList(...)` became syntactically nested inside `ForceDropCarriedChicken`, and the module reached EOF while the function from line ~297 was still open. `Homestead.Main` therefore failed at `require(AnimalService)` and the Homestead runtime never initialized.

## Exact Studio patch
Work on the CURRENT Studio source only.

In `ServerScriptService.Homestead.M.AnimalService`, find this exact block:

```lua
	if chicken.ForceDrop then
		ok = pcall(function()
			chicken:ForceDrop(reason)
		end)
	else
		ok = pcall(function()
			chicken:Drop(os.clock())
		end)
	end

local function lifecycleList(data, speciesId)
```

Replace only that boundary with:

```lua
	if chicken.ForceDrop then
		ok = pcall(function()
			chicken:ForceDrop(reason)
		end)
	else
		ok = pcall(function()
			chicken:Drop(os.clock())
		end)
	end

	return ok
end

local function lifecycleList(data, speciesId)
```

No other code changes are part of this fix.

## Required validation
1. `AnimalService.lua` compiles with 0 syntax errors.
2. `Homestead.Main` starts successfully.
3. Claim a house and confirm `Taken=true` and `OwnerId=<player.UserId>`.
4. Confirm `Workspace.HomeRuntime.Home_<UserId>` exists.
5. Confirm initial Chickens and Cuys appear physically again.
6. Confirm Sheep/Pasture still work.
7. Confirm lifecycle panel N still opens.
8. Wait for Chicken/Cuy juvenile births and verify lifecycle still functions.
9. 0 red errors.

Do not rename template roots, change PrimaryPart, move spawns, apply Issue #37, reset hard, force-push, or merge main as part of this fix.
