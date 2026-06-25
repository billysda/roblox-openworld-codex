# Mount System Diagnosis

## Observed state

- Active mount system: not tested in Play. In Edit, `DragonRiderSeat`, `HumanoidRootPart`, `DragonMountConfig`, and mount attributes on `DragonModel` exist.
- Seat/WeldConstraint/RigidConstraint/Attachment: `DragonRiderSeat` exists. Runtime details still need Play verification.
- DragonRiderBoneConstraint: exists=False
- DragonRiderRootWeld: exists=False
- DragonCollisionRuntime: exists=False
- DragonGroundCollider: exists=True
- DragonMesh.CanCollide: True

## Scripts that look like old patches

- `ServerScriptService.DragonPivotDirectTest.server.lua`
- `ServerScriptService.DragonRiderAttachmentFixRuntime.server.lua`
- `ServerScriptService.DragonSheepGrabWalkTest.server.lua`
- `ServerScriptService.DragonSheepThrowTest.server.lua`

## Main visible risk

- `DragonFlightService.server.lua` has 2174 lines. Before adding new logic, separate mount, collision, and runtime diagnosis into smaller services.
