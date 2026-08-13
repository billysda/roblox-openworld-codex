# Slingshot Anime Shot v2

## Goal
Keep the existing server-authoritative straight raycast and Fox soft-lock, but stylize the *preview* and *cosmetic projectile* as one exaggerated cubic Bezier arc that ends at the exact straight-ray impact point. Also enable temporary infinite Egg ammo for testing without changing InventoryService.

## Non-negotiable gameplay rule
The curve is cosmetic only. It MUST NOT allow a shot to bend around walls or change the authoritative hit. The endpoint is still the first impact returned by the existing straight preview/server raycast.

## New ModuleScript
Create `StarterPlayer.StarterPlayerScripts.SlingshotAnimeTrajectory` from the exact Source in:
`snapshots/CodexAvanceTest_Current/StarterPlayerScripts/SlingshotAnimeTrajectory.lua`

It exposes:
- `GetCurve(origin, target, cameraCFrame, config)`
- `Evaluate(curve, t)`
- `Tangent(curve, t)`
- `ApplyToBeam(beam, attachment0, attachment1, curve, config)`

Default curve style:
- vertical bend = 22% of shot distance, clamped 5..28 studs;
- lateral bend = 10% of shot distance, clamped 2..14 studs;
- cubic control positions around 26% and 72% forward;
- 28 Beam segments.

## Patch SlingshotAimAssist (current Studio Source)
At top, require sibling module:
```lua
local SlingshotAnimeTrajectory = require(script.Parent:WaitForChild("SlingshotAnimeTrajectory"))
```

When creating the existing preview Beam, preserve current colors/width but add:
```lua
beam.Segments = 28
beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
beam.TextureMode = Enum.TextureMode.Wrap
beam.TextureLength = 2.4
beam.TextureSpeed = -2.8
beam.LightEmission = 0.35
```

After `_updatePreview()` has produced `self.CachedPreviewPosition`, update the Beam curve every preview update using the *visual muzzle* as P0 and `CachedPreviewPosition` as P3:
```lua
local muzzleAttachment = self.MuzzleAttachment
local targetAttachment = self.TargetAttachment
if self.Beam and muzzleAttachment and targetAttachment and self.CachedPreviewPosition then
    local visualOrigin = muzzleAttachment.WorldPosition
    local curve = SlingshotAnimeTrajectory.GetCurve(
        visualOrigin,
        self.CachedPreviewPosition,
        camera.CFrame
    )
    if self.TargetPart then
        self.TargetPart.CFrame = CFrame.new(self.CachedPreviewPosition)
    end
    SlingshotAnimeTrajectory.ApplyToBeam(
        self.Beam,
        muzzleAttachment,
        targetAttachment,
        curve
    )
end
```

Do not change target acquisition, LOS, prediction, lock ranges, camera soft lock or GetFireDirection.

### Charge animation on preview
While LMB is held and RMB AimMode is active, the line may breathe very subtly by varying width no more than +/-15%. Do not add a permanent extra loop; use the controller's existing render/update path.

## Patch SlingshotController (current Studio Source)
Require sibling module:
```lua
local SlingshotAnimeTrajectory = require(script.Parent:WaitForChild("SlingshotAnimeTrajectory"))
```

### Replace cosmetic projectile motion only
Keep creation of the local Egg projectile and all FireResult validation. Replace the current straight interpolation with a cubic Bezier path.

Use the exact server-provided `result.HitPosition` as P3. Visual P0 remains RightGrip/RightHand/Handle as currently resolved.

Use duration:
```lua
local duration = tonumber(result.VisualTravelDuration)
if not duration then
    local distance = (hitPosition - visualOrigin).Magnitude
    duration = math.clamp(distance / 300, 0.16, 0.38)
end
```

Build the curve once:
```lua
local camera = Workspace.CurrentCamera
local curve = SlingshotAnimeTrajectory.GetCurve(
    visualOrigin,
    hitPosition,
    camera and camera.CFrame or nil
)
```

Heartbeat motion:
```lua
local elapsed = os.clock() - startTime
local alpha = math.clamp(elapsed / duration, 0, 1)
local eased = 1 - ((1 - alpha) * (1 - alpha)) -- ease-out, energetic finish
local currentPos = SlingshotAnimeTrajectory.Evaluate(curve, eased)
local tangent = SlingshotAnimeTrajectory.Tangent(curve, eased)
projectile.CFrame = CFrame.lookAt(currentPos, currentPos + tangent) * CFrame.Angles(0, 0, elapsed * 18)
```

At alpha >= 1 destroy as before.

### Cosmetic Trail on Egg
Add one Trail to the local projectile, not one script:
```lua
local trailA = Instance.new("Attachment")
trailA.Position = Vector3.new(-0.12, 0, 0)
trailA.Parent = projectile

local trailB = Instance.new("Attachment")
trailB.Position = Vector3.new(0.12, 0, 0)
trailB.Parent = projectile

local trail = Instance.new("Trail")
trail.Attachment0 = trailA
trail.Attachment1 = trailB
trail.FaceCamera = true
trail.Lifetime = 0.09
trail.MinLength = 0.05
trail.LightEmission = 0.35
trail.Color = ColorSequence.new(Color3.fromRGB(244, 211, 139))
trail.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.18),
    NumberSequenceKeypoint.new(1, 1),
})
trail.Parent = projectile
```

Do NOT give the cosmetic Egg CanQuery/CanTouch/CanCollide.

## Synchronize Fox reaction with visible arrival
Patch the current `SlingshotService:Fire()` minimally.

After authoritative raycast and after computing `hitPosition`, compute:
```lua
local visualTravelDuration = math.clamp((hitPosition - safeOrigin).Magnitude / 300, 0.16, 0.38)
```

Include in FireResult:
```lua
VisualTravelDuration = visualTravelDuration,
```

For a confirmed Fox hit, DO NOT immediately increment `PredatorSlingshotHitSerial`. Instead, capture the validated fox Model and validated shot data, then:
```lua
task.delay(visualTravelDuration, function()
    if not foxModel or not foxModel.Parent then
        return
    end
    foxModel:SetAttribute("PredatorSlingshotHitByUserId", player.UserId)
    foxModel:SetAttribute("PredatorSlingshotHitCharge", charge)
    foxModel:SetAttribute("PredatorSlingshotHitPosition", hitPosition)
    local serial = tonumber(foxModel:GetAttribute("PredatorSlingshotHitSerial")) or 0
    foxModel:SetAttribute("PredatorSlingshotHitSerial", serial + 1)
end)
```

The target is still chosen exclusively by the server raycast before the delay. The delay only synchronizes the already-authorized Fox reaction with the cosmetic Egg arrival.

## Temporary infinite Egg ammo
This is DEVELOPMENT TESTING ONLY.

### HomeCfg
Inside `HomeCfg.Slingshot` add:
```lua
TestInfiniteAmmo = true, -- TEMP: set false before production/public test
```

### SlingshotService
Add helper behavior using current `getCfg()`:
- If `cfg.TestInfiniteAmmo == true`, all normal guards still apply (alive, Tool equipped, CarryingChicken, Storage, sprint/cooldown, valid direction/charge).
- Ammo count must NOT block firing.
- `InventoryService:RemoveItem()` must NOT be called.
- Real inventory Egg count remains untouched.
- Set Player attribute `SlingshotInfiniteAmmo = true` while enabled, false otherwise.
- `FireResult` should include `InfiniteAmmo = cfg.TestInfiniteAmmo == true`.

Pseudo-exact patch around ammo validation:
```lua
local infiniteAmmo = cfg.TestInfiniteAmmo == true
local ammo = self:GetAmmo(player)
if not infiniteAmmo and ammo <= 0 then
    return false, "NoAmmo", 0
end
return true, "Ok", ammo, itemId
```

Around removal:
```lua
local infiniteAmmo = cfg.TestInfiniteAmmo == true
local newAmmo = ammo
if not infiniteAmmo then
    local okRemove
    okRemove, newAmmo = self.InventoryService:RemoveItem(player, itemId, 1)
    -- preserve existing failure path exactly
end
```

Do not change InventoryService or EggService.

### Client ammo UI
In `SlingshotController.updateAmmoUI()`:
```lua
if player:GetAttribute("SlingshotInfiniteAmmo") == true then
    ammoLabel.Text = "🥚 ∞"
    return
end
```
Then preserve current numeric path.

Listen to `SlingshotInfiniteAmmo` attribute changes and call `updateAmmoUI()`.

## Controls remain unchanged
- RMB hold = AimMode + soft lock + curved trajectory preview.
- LMB hold/release = charge/fire.
- Gamepad L2/R2 unchanged.
- Hip fire still works; the fired Egg can still use the anime cosmetic curve to its authoritative endpoint.

## Tests
1. RMB preview bends visibly upward and sideways and remains smooth while camera/fox move.
2. Preview endpoint still equals first straight preview-ray obstacle/target.
3. Fox lock/LOS unchanged.
4. FireResult endpoint is unchanged by curve.
5. Cosmetic Egg follows approximately the same cubic curve as preview and is visible for 0.16..0.38s.
6. Fox reaction occurs when cosmetic Egg visually arrives, not noticeably before.
7. Wall still blocks the real shot; curve never grants wall-bending hit.
8. `TestInfiniteAmmo=true`: can fire with 0 Inventory Egg; Inventory Egg count does not decrease.
9. Ammo UI shows `🥚 ∞`.
10. Setting flag false restores canonical Egg consumption with no further code changes.
11. Fox Rescue v1 still repels/releases sheep.
12. 0 new RemoteEvents.
13. 0 errors red.
