# Slingshot Anime Impact v3

## Goal
Build on Issue #31 without changing authoritative gameplay:

1. every confirmed surface hit gets a visible local impact at the exact server `HitPosition`;
2. anime trajectories vary from shot to shot instead of reusing one silhouette;
3. the cosmetic Egg remains visible longer and uses smooth in/out timing instead of rushing through the first half of the curve;
4. Fox Rescue, LOS, soft lock, infinite test ammo and the straight server raycast remain unchanged.

## Reference code written by ChatGPT
Branch: `feature/slingshot-anime-impact-v3`

Exact modules:
- `snapshots/CodexAvanceTest_Current/StarterPlayerScripts/SlingshotAnimeTrajectory.lua`
- `snapshots/CodexAvanceTest_Current/StarterPlayerScripts/SlingshotImpactFX.lua`

Do not reconstruct these modules manually. Transfer their exact Source into current Studio.

---

## 1. Random trajectory styles

`SlingshotAnimeTrajectory` now exposes:

```lua
CreateRandomStyle()
CopyStyle(style)
GetVisualTravelDuration(origin, target, config)
GetCurve(origin, target, cameraCFrame, config, style)
```

The module contains six base silhouettes plus small bounded jitter:
- right arc;
- left arc;
- soft S;
- reverse S;
- tall centered arc;
- low/wide arc.

The endpoint `P3` is NEVER randomized. It remains the authoritative/preview ray endpoint.

### SlingshotAimAssist surgical patch

In constructor add:

```lua
self.CurveStyle = SlingshotAnimeTrajectory.CreateRandomStyle()
```

In `SetAiming(enabled)`, only when transitioning false -> true:

```lua
if enabled == true and self.Aiming ~= true then
    self.CurveStyle = SlingshotAnimeTrajectory.CreateRandomStyle()
end
```

Then preserve the rest of current SetAiming logic.

Add:

```lua
function SlingshotAimAssist:GetCurveStyle()
    return SlingshotAnimeTrajectory.CopyStyle(self.CurveStyle)
end

function SlingshotAimAssist:RandomizeCurveStyle()
    self.CurveStyle = SlingshotAnimeTrajectory.CreateRandomStyle()
end
```

Where current Issue #31 preview calls `GetCurve`, pass the stable style:

```lua
local curve = SlingshotAnimeTrajectory.GetCurve(
    visualOrigin,
    self.CachedPreviewPosition,
    camera.CFrame,
    nil,
    self.CurveStyle
)
```

IMPORTANT: do not call `CreateRandomStyle()` inside Update/render. The curve must stay stable while aiming. Randomize only when AimMode starts and immediately after a shot is requested, so the next shot gets a different silhouette without jitter.

---

## 2. Preserve exact curve used for each fired Egg

In current `SlingshotController`, create near other state:

```lua
local pendingProjectileStyles = {}
```

Immediately before the existing `FireServer(origin, direction, charge)` call:

```lua
local shotStyle
if aimAssist and aimAssist.GetCurveStyle then
    shotStyle = aimAssist:GetCurveStyle()
else
    shotStyle = SlingshotAnimeTrajectory.CreateRandomStyle()
end

table.insert(pendingProjectileStyles, shotStyle)

if aimAssist and aimAssist.RandomizeCurveStyle then
    aimAssist:RandomizeCurveStyle()
end
```

Do not send this style to the server. It is cosmetic only.

When `FireResult` arrives, pop one style for that request:

```lua
local shotStyle = table.remove(pendingProjectileStyles, 1)
```

If `result.Ok == true`, call:

```lua
playProjectileVisual(result, shotStyle)
```

If result failed, the popped style is simply discarded.

Change signature:

```lua
function playProjectileVisual(result, shotStyle)
```

Build the curve with the captured style:

```lua
local curve = SlingshotAnimeTrajectory.GetCurve(
    visualOrigin,
    hitPosition,
    camera and camera.CFrame or nil,
    nil,
    shotStyle
)
```

This guarantees the fired Egg uses the same style that was visible immediately before firing, while the next preview can already switch to a new random style.

---

## 3. Slower, easier-to-read Egg flight

The v2 duration `0.16..0.38` is too fast visually.

New canonical cosmetic duration:

```lua
distance / 220
clamped to 0.24 .. 0.50 seconds
```

In client fallback use:

```lua
local duration = tonumber(result.VisualTravelDuration)
if not duration then
    duration = SlingshotAnimeTrajectory.GetVisualTravelDuration(visualOrigin, hitPosition)
end
```

Replace the v2 quadratic ease-out:

```lua
1 - ((1 - alpha) * (1 - alpha))
```

with smoothstep:

```lua
local eased = alpha * alpha * (3 - 2 * alpha)
```

Reason: v2 rushes through the beginning of the trajectory. Smoothstep makes the Egg readable at launch, through the apex and at impact.

Keep the existing Trail, but increase readability slightly:

```lua
trail.Lifetime = 0.13
trail.MinLength = 0.04
```

Optional safe visual adjustment to the local cosmetic projectile only:

```lua
projectile.Size = Vector3.new(0.40, 0.40, 0.40)
```

Do not change any physical/collision properties; it remains local, anchored, CanQuery/CanTouch/CanCollide false.

---

## 4. Exact impact FX on every real surface hit

Create current Studio ModuleScript:

`StarterPlayer.StarterPlayerScripts.SlingshotImpactFX`

with the exact Source from this branch.

At top of `SlingshotController` require it:

```lua
local SlingshotImpactFX = require(script.Parent:WaitForChild("SlingshotImpactFX"))
```

Inside `playProjectileVisual`, when visual `alpha >= 1`, BEFORE destroying the projectile, execute exactly once:

```lua
local hasRealHit = typeof(result.HitInstance) == "string" and result.HitInstance ~= ""
if hasRealHit then
    SlingshotImpactFX.Play(hitPosition, result.HitNormal)
end
```

Then destroy projectile as current code does.

The impact module is entirely cosmetic/client-local. It creates at the exact world position:
- short cream/gold spark burst;
- soft egg-colored puff;
- tiny Neon flash;
- expanding anime ring;
- automatic cleanup under 1 second.

This works for:
- Fox;
- Terrain;
- walls;
- house parts;
- trees/props;
- any other Instance returned by the authoritative raycast.

If the ray reaches max range without a hit (`HitInstance == ""`), do NOT create a fake impact in mid-air.

Do not raycast again to decide the impact. Use the server FireResult `HitPosition` and `HitNormal`.

---

## 5. Server visual timing parity

In current `SlingshotService:Fire()`, keep the authoritative raycast exactly as-is.

Change only the existing Issue #31 visual travel duration from:

```lua
math.clamp(distance / 300, 0.16, 0.38)
```

to:

```lua
math.clamp(distance / 220, 0.24, 0.50)
```

Continue returning:

```lua
VisualTravelDuration = visualTravelDuration
```

Continue using that SAME duration for the already-validated Fox `PredatorSlingshotHitSerial` delay. Do not change which target was hit and do not defer the authoritative raycast itself.

This keeps Fox reaction synchronized with the slower visible Egg.

---

## 6. Infinite test ammo remains unchanged

Keep:

```lua
HomeCfg.Slingshot.TestInfiniteAmmo = true
```

No changes to InventoryService or EggService.

---

## 7. Protected behavior

Do NOT change:
- target acquisition values;
- Fox-only aim assist;
- LOS;
- camera responsiveness;
- RMB/LMB and gamepad mapping;
- server FireRequest payload (`origin, direction, charge` only);
- server authoritative raycast;
- Fox Rescue / Release behavior;
- Chicken carry / Storage guards;
- Pasture HUD v5;
- Sheep/Flock/Grazing.

No RemoteEvents.

---

## Tests

1. Begin RMB AimMode: trajectory is stable, not jittering frame-to-frame.
2. Fire once: Egg uses the visible curve; next preview changes to another random style.
3. Fire repeatedly: observe left/right/high/S variants while all endpoints remain correct.
4. Egg is noticeably easier to track than v2, especially at 30-80 studs.
5. Egg follows smoothstep through the whole curve rather than instantly racing away.
6. Hit Terrain: impact FX appears exactly on Terrain hit point.
7. Hit wall/prop: impact FX appears on that exact object point.
8. Hit Fox: same impact FX appears at hit point and Fox reacts when Egg visually arrives.
9. Miss into max range: no fake impact FX in empty air.
10. Walls still block real hit; visual curve never changes the authoritative target.
11. Infinite test ammo still works and real inventory stays untouched.
12. Soft-lock/LOS/Fox Rescue remain functional.
13. 0 new RemoteEvents.
14. 0 red errors.
