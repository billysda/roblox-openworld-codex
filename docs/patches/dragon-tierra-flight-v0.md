# DragonTierraRoblox — Independent Flight System v0

## Scope
Implement only the basic flight system for `Workspace.DragonTierraRoblox`.

This system is independent from the legacy dragon system. Do not modify, require, copy, or integrate directly with:
- `Workspace.DragonModel`
- `ServerScriptService.DragonFlightService.server.lua`
- `ServerScriptService.DragonGroundKinematic.module.lua`
- `ServerScriptService.DragonFlightImpact.module.lua`
- `ServerScriptService.DragonCollisionRuntime.server.lua`
- `StarterPlayer.StarterPlayerScripts.DragonFlightClient.client.lua`
- the legacy procedural dragon LocalScripts.

## Prepared rig assumptions
The #40 preparation has already produced:
- `DragonTierraRoblox.PrimaryPart = HumanoidRootPart`
- `HumanoidRootPart` approximately `8,4,16`, transparent, non-collidable
- `HumanoidRootPart.FlightAttachment`
- `FlightAttachment.LinearVelocity` disabled initially
- `FlightAttachment.AlignOrientation` disabled initially
- `HumanoidRootPart.SaddleAttachment`
- `DragonRiderSeat` + `DragonMountPrompt`
- `DragonGroundCollider` in CollisionGroup `DragonTierraBody`
- `AnimationController.Animator`
- original `RootPart` and 83 bones preserved
- existing Walk and Flight animations

## New architecture
Create separate folders and scripts; do not build a monolith.

```text
ServerScriptService
└── DragonTierra
    ├── Server
    │   ├── DragonTierraService.server.lua
    │   └── Flight
    │       ├── DragonTierraFlightService.lua
    │       ├── DragonTierraFlightController.lua
    │       ├── DragonTierraFlightPhysics.lua
    │       └── DragonTierraFlightConfig.lua
    └── Shared
        └── DragonTierraTypes.lua

StarterPlayer
└── StarterPlayerScripts
    └── DragonTierra
        └── Client
            ├── DragonTierraController.client.lua
            └── Flight
                ├── DragonTierraFlightInput.lua
                ├── DragonTierraFlightCamera.lua
                └── DragonTierraFlightState.lua

ReplicatedStorage
└── DragonTierra
    └── Remotes
        ├── FlightInput
        ├── FlightToggle
        └── FlightState
```

## States
Use a minimal state machine:
- `Grounded`
- `Takeoff`
- `Flying`
- `Landing`

Do not port legacy states such as Ascending/Cruising/Gliding/Diving/LandingApproach/Flare/Touchdown.

## Controls
Mounted player only:
- `W`: forward
- `S`: reverse
- `A`: turn left
- `D`: turn right
- `E`: ascend
- `Q`: descend
- `Space`: takeoff from Grounded / request Landing from Flying
- `Shift`: boost

Use the camera's horizontal LookVector for forward direction.

## Server authority
Client sends intent only: movement axes, vertical intent, boost, camera direction, and flight toggle request. Server owns:
- flight state
- velocity
- position/physics
- state transitions
- takeoff/landing validation

Never accept final CFrame/position/velocity from client.

## Physics
Use only modern constraints already prepared on the rig:
- `LinearVelocity` for flight motion
- `AlignOrientation` for orientation

Do not use BodyVelocity/BodyGyro.

Start disabled while Grounded.

Suggested initial config:
```lua
TakeoffSpeed = 22
FlightSpeed = 55
ReverseSpeed = 28
BoostSpeed = 80
VerticalSpeed = 30
Acceleration = 45
Deceleration = 55
TurnResponsiveness = 5
OrientationResponsiveness = 8
MaxRollDegrees = 18
TakeoffDuration = 0.95
LandingSpeed = 26
CameraDistance = 28
CameraHeight = 8
CameraSmoothness = 6
```

All values must live in `DragonTierraFlightConfig.lua`, not as magic numbers in controllers.

## Flight motion
Horizontal target velocity is built from:
- camera horizontal direction
- forward/reverse input
- turn input

Vertical component comes only from E/Q in v0.
No input on E/Q means approximately zero vertical velocity target, preserving altitude.

Apply acceleration/deceleration toward target velocity.

## Orientation / banking
Use `AlignOrientation` to face the horizontal movement direction with smoothing.
Add a modest roll of up to 18 degrees from A/D input.
No procedural bone animation.

## Takeoff
Grounded + valid toggle request:
1. enter `Takeoff`
2. enable LinearVelocity + AlignOrientation
3. lift smoothly for about 0.95s
4. switch to `Flying`
5. play existing Flight animation

No teleport-like jump.

## Landing
Flying + Space request:
1. enter `Landing`
2. reduce horizontal speed
3. raycast downward from HumanoidRootPart, excluding DragonTierraRoblox and its collider
4. descend smoothly
5. detect valid ground
6. place root safely above ground
7. disable LinearVelocity + AlignOrientation
8. return to `Grounded`

Do not use legacy DragonFlightImpact or DragonGroundKinematic.

## Animation
Use existing `AnimationController.Animator`.
Use the existing Flight animation for `Takeoff`, `Flying`, and `Landing`.
Do not create new animation assets.
Walk animation remains reserved for the future ground controller.

## Camera
While mounted and Flying:
- third-person follow
- smooth target behind dragon
- configurable distance/height
- no legacy camera code
- restore normal camera behavior when not mounted/flying

## Mount integration
Use the prepared `DragonRiderSeat` / `SaddleAttachment`.
Only the current seat occupant can control flight.
Do not reuse legacy mount service.

## Performance
- no per-bone loops
- no RenderStepped for physics
- no per-dragon permanent polling beyond a central server update loop appropriate to the active flight state
- client input/event handling may use UserInputService and one controlled render/update connection for camera only
- clean all connections when no longer needed

## Safety / isolation
Do not modify any legacy dragon files or behavior. Do not rename existing DragonTierra bones. Do not alter visual MeshParts or SurfaceAppearances.

## Validation
Required Play tests:
1. mount DragonTierraRoblox
2. Grounded -> Takeoff -> Flying
3. W/A/S/D movement
4. E/Q altitude control
5. Shift boost
6. smooth orientation/banking
7. flight animation visible
8. Space -> Landing -> Grounded
9. ground raycast avoids self-collision
10. legacy DragonModel remains unchanged and functional
11. zero red errors

## Deliverable
Update `MANIFEST.md` / `STATUS.md` and create a commit using:
`feat: implement independent DragonTierra flight system`
