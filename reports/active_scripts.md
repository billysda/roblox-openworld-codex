# Active Scripts

## Active scripts

- `ServerScriptService.DragonCollisionRuntime.server.lua` (Script, lines=151)
- `ServerScriptService.DragonFlightService.server.lua` (Script, lines=2174)
- `ServerScriptService.DragonRiderAttachmentFixRuntime.server.lua` (Script, lines=236)
- `ServerScriptService.Pasture.M.Sheep` (ModuleScript, lines=1546)
- `StarterPlayer.StarterPlayerScripts.DragonBodyCurl.client.lua` (LocalScript, lines=371)
- `StarterPlayer.StarterPlayerScripts.DragonFlightClient.client.lua` (LocalScript, lines=1151)
- `StarterPlayer.StarterPlayerScripts.DragonMouseAim.client.lua` (LocalScript, lines=848)
- `StarterPlayer.StarterPlayerScripts.DragonSerpentTurn.client.lua` (LocalScript, lines=301)
- `StarterPlayer.StarterPlayerScripts.DragonSpineAim.client.lua` (LocalScript, lines=438)
- `StarterPlayer.StarterPlayerScripts.DragonTorsoTwist.client.lua` (LocalScript, lines=705)

## Disabled scripts

- `ServerScriptService.DragonPivotDirectTest.server.lua` (Script, lines=47)
- `ServerScriptService.DragonSheepGrabWalkTest.server.lua` (Script, lines=257)
- `ServerScriptService.DragonSheepThrowTest.server.lua` (Script, lines=102)

## Test/debug scripts

- `ServerScriptService.DragonPivotDirectTest.server.lua` (Script, disabled=True, lines=47)
- `ServerScriptService.DragonSheepGrabWalkTest.server.lua` (Script, disabled=True, lines=257)
- `ServerScriptService.DragonSheepThrowTest.server.lua` (Script, disabled=True, lines=102)

## Possibly obsolete patch scripts

- `ServerScriptService.DragonPivotDirectTest.server.lua` - review before stacking another patch.
- `ServerScriptService.DragonRiderAttachmentFixRuntime.server.lua` - review before stacking another patch.
- `ServerScriptService.DragonSheepGrabWalkTest.server.lua` - review before stacking another patch.
- `ServerScriptService.DragonSheepThrowTest.server.lua` - review before stacking another patch.

## Scripts that may conflict

- `ServerScriptService.DragonFlightService.server.lua` concentrates flight and mount logic and may overlap with `ServerScriptService.DragonRiderAttachmentFixRuntime.server.lua`.
- `DragonBodyCurl`, `DragonMouseAim`, `DragonSerpentTurn`, `DragonSpineAim`, and `DragonTorsoTwist` all influence orientation or bones and should be reviewed together before pose runtime changes.
- `DragonCollisionRuntime` and `DragonGroundCollider` are the likely collision runtime axis; avoid duplicating collision logic inside flight.
