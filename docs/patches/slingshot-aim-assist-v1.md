# Slingshot Aim Assist v1

## Goal
Replace the current left-click-only aim/charge behavior with separate aim and fire controls, add soft lock-on to Fox targets, show a live straight trajectory preview that matches the server hitscan, and replace the exaggerated fake parabolic projectile visual.

## Existing controller assumptions
Target file: `StarterPlayerScripts/SlingshotController.client.lua`.

The current controller already has `isAiming`, `chargeStart`, `getFireOriginDirection()`, `beginAimCharge()`, `finishAimCharge()`, `renderUpdate()`, `playProjectileVisual()`, and mouse/gamepad input handlers.

The new ModuleScript written by ChatGPT is:
`StarterPlayerScripts/SlingshotAimAssist.lua`.

## 1. Require module
Near the service/local declarations add:

```lua
local SlingshotAimAssist = require(script.Parent:WaitForChild("SlingshotAimAssist"))
```

After local state variables add:

```lua
local aimAssist = SlingshotAimAssist.new(player, {
    MaxRange = 180,
    AcquireWorldDistance = 145,
    BreakWorldDistance = 165,
    AcquireScreenRadius = 190,
    BreakScreenRadius = 320,
    CameraResponsiveness = 8,
    PredictionTime = 0.07,
})
```

Do not create remotes.

## 2. Split aim from charge/fire
Replace `beginAimCharge()` / `finishAimCharge()` semantics with four functions:

```lua
local function beginAimMode()
    if not active or not isBattleMode or activeAction then
        return
    end
    if player:GetAttribute("CarryingChicken") == true or player:GetAttribute("HomesteadStorageOpen") == true then
        return
    end

    isAiming = true
    aimAssist:SetContext(character, activeTool)
    aimAssist:SetAiming(true)
    setDebugAttributes(true, isBattleMode, true, chooseLocomotionState(GetRawMoveInput()))
    playLocomotion(chooseLocomotionState(GetRawMoveInput()))
end

local function endAimMode()
    if chargeStart then
        chargeStart = nil
    end
    if isAiming then
        isAiming = false
        aimAssist:SetAiming(false)
        setDebugAttributes(true, isBattleMode, false, chooseLocomotionState(GetRawMoveInput()))
        playLocomotion(chooseLocomotionState(GetRawMoveInput()))
    end
end

local function beginFireCharge()
    if not canRequestFire() then
        return
    end
    if chargeStart then
        return
    end
    chargeStart = os.clock()
end

local function finishFireCharge()
    local startedAt = chargeStart
    chargeStart = nil
    if not startedAt or not canRequestFire() then
        return
    end

    local charge = math.clamp((os.clock() - startedAt) / SLINGSHOT_FIRE.MaxChargeTime, 0, 1)
    if charge < SLINGSHOT_FIRE.MinChargeToFire then
        return
    end

    local ammoAttr = player:GetAttribute("SlingshotEggAmmo") or 0
    if ammoAttr <= 0 then
        showFeedback("No tienes huevos")
        return
    end

    local origin, fallbackDirection = getFireOriginDirection()
    if origin and fallbackDirection then
        local direction = aimAssist:GetFireDirection(origin, fallbackDirection)
        fireRequestEvent:FireServer(origin, direction, charge)
    end
end
```

Aim mode is now held independently by RMB/L2. Fire charge is LMB/R2.

## 3. Render update
After the existing `updateCamera(dt, raw, moveState)` call in `renderUpdate(dt)`, add:

```lua
if isAiming then
    aimAssist:Update(dt, Workspace.CurrentCamera, character, activeTool)
end
```

This order is intentional: the existing battle camera updates first, then aim assist applies the soft target correction.

## 4. Cleanup and activation
In cleanup/deactivate paths, before restoring camera, ensure:

```lua
aimAssist:SetAiming(false)
chargeStart = nil
```

On activate, after the tool/character is established:

```lua
aimAssist:SetContext(character, tool)
```

Do not destroy the module on every unequip; it is reused. `SetAiming(false)` hides visuals and clears lock.

## 5. Input mapping
Replace the old input mapping where MouseButton1/ButtonR2 directly calls `beginAimCharge()`.

InputBegan behavior:

```lua
if input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.ButtonL2 then
    beginAimMode()
    return
end

if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
    beginFireCharge()
    return
end
```

InputEnded behavior:

```lua
if input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.ButtonL2 then
    endAimMode()
    return
end

if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
    finishFireCharge()
    return
end
```

PC controls become:
- Hold RMB: AimMode + soft Fox lock + trajectory preview.
- Hold/release LMB: charge/fire.

Gamepad controls become:
- Hold L2: aim.
- Hold/release R2: charge/fire.

Hip-fire with LMB/R2 remains allowed, but has no auto-lock unless AimMode is active.

## 6. Projectile visual fix
Replace the current exaggerated parabola in `playProjectileVisual(result)`.

Keep the existing creation of the cosmetic egg Part and visual origin selection, but replace the `VISUAL_SPEED = 55`, gravity, ballistic `v0`, and gravity position formula with a straight fast cosmetic flight matching the server raycast:

```lua
local distance = (hitPosition - visualOrigin).Magnitude
local duration = math.clamp(
    distance / SLINGSHOT_FIRE.ProjectileSpeed,
    SLINGSHOT_FIRE.ProjectileMinDuration,
    SLINGSHOT_FIRE.ProjectileMaxDuration
)

local rotSpeed = Vector3.new(
    math.random(-12, 12),
    math.random(-12, 12),
    math.random(-12, 12)
)

local startTime = os.clock()
local connection
local finished = false

local function finish()
    if finished then return end
    finished = true
    if connection then
        connection:Disconnect()
        connection = nil
    end
    if projectile then
        projectile:Destroy()
    end
end

connection = RunService.Heartbeat:Connect(function()
    if not projectile or not projectile.Parent then
        finish()
        return
    end

    local t = os.clock() - startTime
    local alpha = math.clamp(t / duration, 0, 1)
    if alpha >= 1 then
        finish()
        return
    end

    local currentPos = visualOrigin:Lerp(hitPosition, alpha)
    projectile.CFrame = CFrame.new(currentPos)
        * CFrame.Angles(rotSpeed.X * t, rotSpeed.Y * t, rotSpeed.Z * t)
end)

Debris:AddItem(projectile, duration + 0.2)
```

Reason: the real server shot is a straight raycast. The previous slow high parabola was only cosmetic and visually contradicted the real hit path.

## 7. Target behavior
`SlingshotAimAssist.lua` already implements:
- client-only target search inside `Workspace.PredatorRuntime`;
- only models with `PredatorType == "Fox"`;
- ignores Repelled/Completed;
- acquires within ~190 screen pixels and 145 studs;
- retains lock up to ~320 screen pixels / 165 studs;
- requires line of sight;
- applies tiny movement prediction (0.07 sec, max 1.5 studs);
- softly rotates camera while RMB/L2 is held;
- uses one Beam as trajectory preview;
- preview raycast updates at 30 Hz, not every render frame;
- native reticle changes from cream to amber while a Fox is locked;
- no RemoteEvents and no server target trust.

## 8. Server authority
Do not modify the core server hit decision for this feature. `SlingshotService` still owns the real raycast and Fox repel signal. The client only chooses a direction.

## 9. Tests
1. Equip Honda: existing BattleMode works.
2. RMB with no Fox near center: reticle/trajectory appear, no hard snap.
3. RMB with Fox near center: locks and follows softly.
4. Moving Fox remains tracked while RMB is held.
5. Releasing RMB breaks the lock immediately.
6. LMB while RMB held charges and fires toward assisted direction.
7. LMB without RMB still hip-fires straight camera direction.
8. Trajectory Beam endpoint matches the straight raycast direction.
9. Cosmetic egg no longer flies in an exaggerated high arc.
10. One valid hit still triggers Fox Repelled from Issue #29.
11. LOS obstruction prevents lock / server raycast hits obstruction.
12. No extra RemoteEvents.
13. Chicken carry / Storage / movement restrictions unchanged.
14. 0 red errors.
