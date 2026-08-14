# Mythic Resources v0.1 - Test cluster near player

## Goal
Make the existing Mythic Resources v0 visually testable on a very large map by temporarily spawning the same 3 mythic resources close to each player's current character on spawn/respawn.

This is a development/testing convenience only. It must not replace the future regional spawn design.

## Source references written by ChatGPT
Branch: `feature/mythic-test-spawn-near-player`

Updated exact sources:
- `snapshots/CodexAvanceTest_Current/ServerScriptService/MythicResources/Main.server.lua`
- `snapshots/CodexAvanceTest_Current/ServerScriptService/MythicResources/M/MythicResourceService.lua`

Reference commits:
- ResourceService test cluster + ground projection: `fdd4428e8c78fffff113ae08527799ea84304296`
- Main hook on CharacterAdded/respawn: `0bcf551d2b6a259c06cda1fe1c8bb02d91044622`

## IMPORTANT: current Studio first
Studio currently contains Issue #34 local commit `1c9ef3b`.
Do not replace unrelated MythicResource/Codex scripts from an older snapshot.
Use the two exact updated sources as the intended delta, or apply their new methods/hooks surgically to the current Studio sources.

Do not touch CodexClient, CodexUI, Catalog, MythicInventoryService or CodexService unless only syncing their unchanged snapshots.

## Temporary behavior
`Main.server.lua` contains:
```lua
local TEST_SPAWN_NEAR_PLAYER = true
local TEST_SPAWN_DELAY = 0.8
```

When a character spawns:
1. wait about 0.8s;
2. resolve HumanoidRootPart;
3. call `resourceService:SpawnTestClusterForPlayer(player, rootPart.CFrame)`;
4. the service deletes only prior temporary markers owned by that player;
5. creates 9 invisible markers in a 3x3 fan near/in front of the character;
6. projects each marker down to the nearest ground/floor with one setup raycast;
7. spawns the existing templates through the existing `_spawnMarker()` path.

Layout is deliberately close to the player, roughly 9..23 studs away:
- row 1: Mandrake / EmberBloom / MoonDewLotus
- row 2: Mandrake / EmberBloom / MoonDewLotus
- row 3: Mandrake / EmberBloom / MoonDewLotus

Every temporary marker has:
- `MythicResourceId`
- `MythicSpawnId`
- `MythicTestOwnerUserId`
- `MythicTestSpawn = true`
- `RespawnSeconds = 8`

This means the user can immediately see and collect all 3 models without crossing the map.

## Cleanup
`ClearTestSpawnsForPlayer(player)` removes only temporary markers for that user and destroys their matching runtime clones.
It runs before rebuilding the cluster and on PlayerRemoving.
Existing static markers from Issue #34 remain untouched.

The existing delayed respawn is safe: if a temporary marker has been removed, its delayed callback sees the marker no longer has a parent and exits.

## Performance rules
- still 0 scripts per plant;
- still one global ProximityPromptService listener;
- no Heartbeat/RenderStepped loops added;
- only 9 setup ground raycasts when a character spawns/respawns;
- no repeated polling;
- runtime BaseParts now also set `CanQuery=false` in addition to Anchored/CanCollide=false/CanTouch=false;
- test cluster is temporary and controlled by a single flag.

For a 10-player production server this flag must be disabled before release, otherwise it would intentionally create up to 90 temporary test nodes. Setting `TEST_SPAWN_NEAR_PLAYER = false` restores the normal static/regional spawn behavior without deleting the underlying system.

## Required Studio verification
1. Start Play Solo at any location on the large map.
2. Within ~1 second, 9 mythic resources are visible near/in front of the character.
3. There are exactly 3 Mandrake, 3 EmberBloom, 3 MoonDewLotus temporary nodes for that player.
4. Prompts still say `Recolectar` and correct DisplayName.
5. Collect one of each and verify Codex reaches 3/3.
6. Verify collected temporary node respawns in ~8 seconds.
7. Reset character and verify old temporary cluster is removed/replaced near the new spawn; it must not duplicate indefinitely.
8. Static 9 markers from Issue #34 are unchanged.
9. `scriptsInCodexUI = 0`, 0 scripts in plant nodes.
10. 0 red errors.

## Do not touch
- Homestead / InventoryService canonical
- Pasture / Sheep / Flock / Grazing
- Predator / Fox
- Slingshot
- PastureHUD v5
- main branch

No reset --hard, no force push, no merge main.
