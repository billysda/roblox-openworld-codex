# CURRENT_SYNC_AUDIT

- Fecha y hora: 2026-07-21 16:04:04 -05:00
- Branch: `main`
- HEAD local: `b3acfbd0d8840b4e017e6381b09aa03fd3803d6f`
- HEAD origin/main: `b3acfbd0d8840b4e017e6381b09aa03fd3803d6f`
- HEAD observado al crear el issue: `b3acfbd0d8840b4e017e6381b09aa03fd3803d6f`
- Estado del HEAD actual: igual al HEAD observado al crear el issue.
- Target MCP: `CodexAvanceTest`
- DataModel: `Place1`
- PlaceId: `84364645709785`
- Scripts Studio auditados: 42
- Scripts repo auditados (`scripts/` + `snapshots/CodexAvanceTest_Current/`): 42

## Conteos

- `MATCH`: 19
- `DIFFERENT`: 9
- `STUDIO_ONLY`: 13
- `REPO_ONLY`: 12
- `DUPLICATE_REPO_VERSION`: 1

## Comparacion completa

| Studio path | Clase | Lineas Studio | SHA-256 Studio | Repo path(s) | SHA-256 repo | Clasificacion | Notas |
|---|---|---:|---|---|---|---|---|
| ServerScriptService.BastonTestService | Script | 72 | `e2186f81041ba353e917ba5d774b7f034d16c75920d6a30ea82b5616ff2a266b` | snapshots/CodexAvanceTest_Current/ServerScriptService/BastonTestService.lua | e2186f81041ba353e917ba5d774b7f034d16c75920d6a30ea82b5616ff2a266b | `MATCH` |  |
| ServerScriptService.DragonCollisionRuntime |  |  | `` | scripts/ServerScriptService/DragonCollisionRuntime.server.lua | c028a83cb2a88c91fcb2a6eb4391e39db2d5230da586bae3611fdeadfeaef6e3 | `REPO_ONLY` | Existe en el repo, pero no en el place activo. |
| ServerScriptService.DragonFlightService |  |  | `` | scripts/ServerScriptService/DragonFlightService.server.lua | 8660224e02b0daf54bc9e045d2d0d7f0483ad361e0869462bf0f475c19bb2b22 | `REPO_ONLY` | Existe en el repo, pero no en el place activo. |
| ServerScriptService.DragonPivotDirectTest |  |  | `` | scripts/ServerScriptService/DragonPivotDirectTest.server.lua | 73f3d0418999d4c24c4f959077babd953ddafd24479f3cff2407e4b431cd1172 | `REPO_ONLY` | Existe en el repo, pero no en el place activo. |
| ServerScriptService.DragonRaidAutoTest | Script | 9 | `02b018c0017477ede4eae0849b5a7245735a324017574a0278fdc519a8e7c1eb` | snapshots/CodexAvanceTest_Current/ServerScriptService/DragonRaidAutoTest.server.lua | 02b018c0017477ede4eae0849b5a7245735a324017574a0278fdc519a8e7c1eb | `MATCH` |  |
| ServerScriptService.DragonRiderAttachmentFixRuntime |  |  | `` | scripts/ServerScriptService/DragonRiderAttachmentFixRuntime.server.lua | 59decf948c7655c4b7c1bf4784874e0f91c5030fd8b976b8c7578abc4cf4f3ae | `REPO_ONLY` | Existe en el repo, pero no en el place activo. |
| ServerScriptService.DragonSheepGrabWalkTest |  |  | `` | scripts/ServerScriptService/DragonSheepGrabWalkTest.server.lua | 7ec61bd9211c14cf266c6a79ee0af355069e6d8a580228af5ec1085eb418af20 | `REPO_ONLY` | Existe en el repo, pero no en el place activo. |
| ServerScriptService.DragonSheepThrowTest |  |  | `` | scripts/ServerScriptService/DragonSheepThrowTest.server.lua | 261089b3f4af61272552d6d84610863b204d676bd719ff44df7cc13f73c7c5b3 | `REPO_ONLY` | Existe en el repo, pero no en el place activo. |
| ServerScriptService.Homestead.M.AnimalService | ModuleScript | 390 | `5c8e6c72e5d5ec05983b567a4a65bd1a19321611f8e9b6974b52ed1d0e38936b` | snapshots/CodexAvanceTest_Current/ServerScriptService/Homestead/M/AnimalService.lua | a7c05ed8bcf893899551d8ad44ffa790d3a42a027bcfcefa851b3dd71f698dbb | `DIFFERENT` | Existe ruta equivalente en el repo, pero el hash difiere. |
| ServerScriptService.Homestead.M.Chicken | ModuleScript | 3069 | `36c294440727896ed83eb1f4b7f108b07d3069dcd08e09ebaca5ae5c371f0296` | snapshots/CodexAvanceTest_Current/ServerScriptService/Homestead/M/Chicken.lua | 51511813eadbdff9304d449879f7a32148ef78ed7c0c4a45aefb3fc8e7d1926c | `DIFFERENT` | Existe ruta equivalente en el repo, pero el hash difiere. |
| ServerScriptService.Homestead.M.Cuy | ModuleScript | 1054 | `439429831a9ba20300425075cfa95b2546482f1c5af7d9acfff7442cfffe7bb0` | snapshots/CodexAvanceTest_Current/ServerScriptService/Homestead/M/Cuy.lua | 439429831a9ba20300425075cfa95b2546482f1c5af7d9acfff7442cfffe7bb0 | `MATCH` |  |
| ServerScriptService.Homestead.M.DragonRaidService | ModuleScript | 426 | `a03f848f74ed99df868a1ec670f27cb056d3479d37884e42735c5b1708b87ce4` | snapshots/CodexAvanceTest_Current/ServerScriptService/Homestead/M/DragonRaidService.lua | 481a13d3d82424ec19b8efee10d4185b1efb2e9bf3828ca2c55a39bdcd25c951 | `DIFFERENT` | Existe ruta equivalente en el repo, pero el hash difiere. |
| ServerScriptService.Homestead.M.EggService | ModuleScript | 221 | `47bc4a92cdd49b763e155cb6899d659774453ccdc5ec26b87baecebc3efee433` | snapshots/CodexAvanceTest_Current/ServerScriptService/Homestead/M/EggService.lua | aa2c1b1fe4d88c9dd40790e9a341c7904a61520ebdfcfee159b2439a8e384b78 | `DIFFERENT` | Existe ruta equivalente en el repo, pero el hash difiere. |
| ServerScriptService.Homestead.M.HomeCfg | ModuleScript | 283 | `74499cc0677ebb2186d334d4bc94ce0f687ad8f1480935d746d2af9eb77476f2` | snapshots/CodexAvanceTest_Current/ServerScriptService/Homestead/M/HomeCfg.lua | 74499cc0677ebb2186d334d4bc94ce0f687ad8f1480935d746d2af9eb77476f2 | `MATCH` |  |
| ServerScriptService.Homestead.M.HomeService | ModuleScript | 437 | `a6f6fbb79cc91f217dfe8224b85ba67a86974f195fe061a2b8547585e73f3814` | snapshots/CodexAvanceTest_Current/ServerScriptService/Homestead/M/HomeService.lua | 6f6bbb2070babd9ba61b5d5dd70160a06c46d3d60b435262d5c6847aee9d634a | `DIFFERENT` | Existe ruta equivalente en el repo, pero el hash difiere. |
| ServerScriptService.Homestead.M.InventoryService | ModuleScript | 143 | `ade0567e3f732fa9ba50e82b6f5bfde3dc259ee5b8a188b4c2f4967eb32cbd72` | snapshots/CodexAvanceTest_Current/ServerScriptService/Homestead/M/InventoryService.lua | ade0567e3f732fa9ba50e82b6f5bfde3dc259ee5b8a188b4c2f4967eb32cbd72 | `MATCH` |  |
| ServerScriptService.Homestead.M.SlingshotService | ModuleScript | 278 | `373186f7e43fd4215fbc406af2f76259407ed8632c2fe88b64ab6c559a1ab743` | snapshots/CodexAvanceTest_Current/ServerScriptService/Homestead/M/SlingshotService.lua | 373186f7e43fd4215fbc406af2f76259407ed8632c2fe88b64ab6c559a1ab743 | `MATCH` |  |
| ServerScriptService.Homestead.M.StationService | ModuleScript | 27 | `9cbf3e1784387029b5a4ef4f6f5a8edc37577f3a81e2f367b8bba389c1d52acd` | snapshots/CodexAvanceTest_Current/ServerScriptService/Homestead/M/StationService.lua | 9cbf3e1784387029b5a4ef4f6f5a8edc37577f3a81e2f367b8bba389c1d52acd | `MATCH` |  |
| ServerScriptService.Homestead.M.StorageService | ModuleScript | 195 | `464197d98ddf4d1b5013ad1a6fb85186f12330d8101880e796cabedc38bab7a6` | snapshots/CodexAvanceTest_Current/ServerScriptService/Homestead/M/StorageService.lua | 442e03136e82fc4aa817204a0687636664684b11992b87cdb097a2fcb2e68395 | `DIFFERENT` | Existe ruta equivalente en el repo, pero el hash difiere. |
| ServerScriptService.Homestead.Main | Script | 151 | `a45f8e4c3a74a07f70424aba607dfceddeaf0e990265abf2379b169031b6e0d2` | snapshots/CodexAvanceTest_Current/ServerScriptService/Homestead/Main.lua | a45f8e4c3a74a07f70424aba607dfceddeaf0e990265abf2379b169031b6e0d2 | `MATCH` |  |
| ServerScriptService.Homestead.Monitor | Script | 192 | `321a3a012697f55e0d6c54b25486a8db5d38dd87178f3476847d7720bd55cab5` | snapshots/CodexAvanceTest_Current/ServerScriptService/Homestead/Monitor.lua | 321a3a012697f55e0d6c54b25486a8db5d38dd87178f3476847d7720bd55cab5 | `MATCH` |  |
| ServerScriptService.Pasture.M.Cfg | ModuleScript | 332 | `ecbc78ea9e6ff34b6a88b5dabf8935377e3dcd2e5bcb3b1c9f0f5671319a1e0a` | snapshots/CodexAvanceTest_Current/ServerScriptService/Pasture/M/Cfg.lua | ecbc78ea9e6ff34b6a88b5dabf8935377e3dcd2e5bcb3b1c9f0f5671319a1e0a | `MATCH` |  |
| ServerScriptService.Pasture.M.Flock | ModuleScript | 412 | `5d48fb213a1781adeccd3dbe1f5eb81c2b8329e5a0bf2f3a5c6c70c635594b92` | snapshots/CodexAvanceTest_Current/ServerScriptService/Pasture/M/Flock.lua | 5d48fb213a1781adeccd3dbe1f5eb81c2b8329e5a0bf2f3a5c6c70c635594b92 | `MATCH` |  |
| ServerScriptService.Pasture.M.GrazingService | ModuleScript | 290 | `4deb5528112a85e76aa334d84486abba0be745478560f8b7c52d785ba33ccbe7` | snapshots/CodexAvanceTest_Current/ServerScriptService/Pasture/M/GrazingService.lua | 4deb5528112a85e76aa334d84486abba0be745478560f8b7c52d785ba33ccbe7 | `MATCH` |  |
| ServerScriptService.Pasture.M.House | ModuleScript | 164 | `17929a9a3b09e8155ecc1288547ac856e4b0329e3394d541e55dde05e58562d3` | snapshots/CodexAvanceTest_Current/ServerScriptService/Pasture/M/House.lua | 17929a9a3b09e8155ecc1288547ac856e4b0329e3394d541e55dde05e58562d3 | `MATCH` |  |
| ServerScriptService.Pasture.M.Rand | ModuleScript | 29 | `fcd87e0a2e3eae0e137535e3ea625edefb5f71de3e681ef66b2c3ded37566cc3` | snapshots/CodexAvanceTest_Current/ServerScriptService/Pasture/M/Rand.lua | fcd87e0a2e3eae0e137535e3ea625edefb5f71de3e681ef66b2c3ded37566cc3 | `MATCH` |  |
| ServerScriptService.Pasture.M.Sheep | ModuleScript | 1883 | `318ea3736eeac096acd41e034b87edcb730e15d5650a64de222e0dc751f4bfe8` | scripts/ServerScriptService/Pasture/M/Sheep.lua<br>snapshots/CodexAvanceTest_Current/ServerScriptService/Pasture/M/Sheep.lua | 1d96055b9c2ef4b81bc11cfa9e1573efc451ccc3b2352bce2a0b865e7877a111<br>318ea3736eeac096acd41e034b87edcb730e15d5650a64de222e0dc751f4bfe8 | `DUPLICATE_REPO_VERSION` | Una copia del repo coincide con Studio, pero hay otras copias conflictivas. |
| ServerScriptService.Pasture.Main | Script | 159 | `6e6172100f502ddaf21637dc3e30f1bb9dd86ae0deb8643f257809aec96209bc` | snapshots/CodexAvanceTest_Current/ServerScriptService/Pasture/Main.lua | 6e6172100f502ddaf21637dc3e30f1bb9dd86ae0deb8643f257809aec96209bc | `MATCH` |  |
| ServerScriptService.Pasture.Monitor | Script | 346 | `01f02d1de22815146d1fdcc3e3660c5140031c66ba1755ae1d042b369cc9c228` | snapshots/CodexAvanceTest_Current/ServerScriptService/Pasture/Monitor.lua | 01f02d1de22815146d1fdcc3e3660c5140031c66ba1755ae1d042b369cc9c228 | `MATCH` |  |
| SoundService.Copiadeseguridad.Cfg | ModuleScript | 66 | `b04861647c4b933565856f718802690a86b25e000a1adff3e78c398190104df1` |  |  | `STUDIO_ONLY` | No existe version mapeada en scripts/ ni snapshots/CodexAvanceTest_Current/. |
| SoundService.Copiadeseguridad.Flock | ModuleScript | 114 | `095248ba685893c7f3c48e134e41fe095e58b96da3e61c70aec4b78b0921012d` |  |  | `STUDIO_ONLY` | No existe version mapeada en scripts/ ni snapshots/CodexAvanceTest_Current/. |
| SoundService.Copiadeseguridad.Sheep | ModuleScript | 388 | `972399fdcf378690bc47f372c1de250a9c0a00dac54e3dd2179ff4494690a6ce` |  |  | `STUDIO_ONLY` | No existe version mapeada en scripts/ ni snapshots/CodexAvanceTest_Current/. |
| StarterPack.Script | Script | 211 | `fc13785bdefb112f19cf16af2f7b27e552e920e6135b2f01c99cb8e259e409ce` |  |  | `STUDIO_ONLY` | No existe version mapeada en scripts/ ni snapshots/CodexAvanceTest_Current/. |
| StarterPlayer.StarterPlayerScripts.BastonTestController | LocalScript | 18 | `52bae0ad8a74cb36aa56fdb124a64d8cce266d8aa5d416971b9837ad58adad2c` | snapshots/CodexAvanceTest_Current/StarterPlayer/StarterPlayerScripts/BastonTestController.lua | 52bae0ad8a74cb36aa56fdb124a64d8cce266d8aa5d416971b9837ad58adad2c | `MATCH` |  |
| StarterPlayer.StarterPlayerScripts.ChickenCarryAnimClient | LocalScript | 169 | `01f5c2530a74639234bc39bdd4feb6ea9b9b5f2d45488ef805806199b64dc8ef` | snapshots/CodexAvanceTest_Current/StarterPlayerScripts/ChickenCarryAnimClient.client.lua | 01f5c2530a74639234bc39bdd4feb6ea9b9b5f2d45488ef805806199b64dc8ef | `MATCH` |  |
| StarterPlayer.StarterPlayerScripts.DragonBodyCurl |  |  | `` | scripts/StarterPlayerScripts/DragonBodyCurl.client.lua | 539820b8a680d2d0fd7dfcde344eaa4e41414e15af7970c22e49519f5ddd67a1 | `REPO_ONLY` | Existe en el repo, pero no en el place activo. |
| StarterPlayer.StarterPlayerScripts.DragonFlightClient |  |  | `` | scripts/StarterPlayerScripts/DragonFlightClient.client.lua | 0f43eca62e8ecd5c21e9c342f3aca1acd5256df62f1797b072149649b70ace47 | `REPO_ONLY` | Existe en el repo, pero no en el place activo. |
| StarterPlayer.StarterPlayerScripts.DragonMouseAim |  |  | `` | scripts/StarterPlayerScripts/DragonMouseAim.client.lua | 756b32d630a5a26f74bc4cf7ed7822a321d858d1ca36d0cbafd26ba99abccb87 | `REPO_ONLY` | Existe en el repo, pero no en el place activo. |
| StarterPlayer.StarterPlayerScripts.DragonSerpentTurn |  |  | `` | scripts/StarterPlayerScripts/DragonSerpentTurn.client.lua | e98b4e336fc882b229c3d89765a4adc7173173294261da1c99d6df55e14b3364 | `REPO_ONLY` | Existe en el repo, pero no en el place activo. |
| StarterPlayer.StarterPlayerScripts.DragonSpineAim |  |  | `` | scripts/StarterPlayerScripts/DragonSpineAim.client.lua | 01cbae020dffa415b343484c750b301336b0f135de39508dce5f6e342867b49f | `REPO_ONLY` | Existe en el repo, pero no en el place activo. |
| StarterPlayer.StarterPlayerScripts.DragonTorsoTwist |  |  | `` | scripts/StarterPlayerScripts/DragonTorsoTwist.client.lua | 250adbdffa52ece8905e7b5c8b482f6801b119639c992b3de9b79f3fcaeb1da8 | `REPO_ONLY` | Existe en el repo, pero no en el place activo. |
| StarterPlayer.StarterPlayerScripts.HomesteadClient | LocalScript | 162 | `44bf5cf9837e8adcf21d17066816bbe5aec7dd27d0ab456b70a6dfa5d04ccc23` | snapshots/CodexAvanceTest_Current/StarterPlayerScripts/HomesteadClient.client.lua | 3c1a8d4581d1d77d8cbfb9eb1033382bf18c09fa9e1f9bee2c226863b0e24c1d | `DIFFERENT` | Existe ruta equivalente en el repo, pero el hash difiere. |
| StarterPlayer.StarterPlayerScripts.HondaToolIsolationTest | LocalScript | 256 | `c2429618c174b214510407874d08b3f45787328851c402df12011f0fa5892e0c` |  |  | `STUDIO_ONLY` | No existe version mapeada en scripts/ ni snapshots/CodexAvanceTest_Current/. |
| StarterPlayer.StarterPlayerScripts.PastureClient | LocalScript | 16 | `a6b91295ed5b6607a9cbf223d47be01559230c990203873107fbae129b881da3` |  |  | `STUDIO_ONLY` | No existe version mapeada en scripts/ ni snapshots/CodexAvanceTest_Current/. |
| StarterPlayer.StarterPlayerScripts.PasturePromptClient | LocalScript | 180 | `09c2b83d916c0c49fe4c48b0d5eaf26756c16be853d6520ef2802a278bff61e5` | snapshots/CodexAvanceTest_Current/StarterPlayerScripts/PasturePromptClient.client.lua | 5f6cd56995d4efde24340b107a70ff4808156e9d3238c55e4718ad5cf6ede18f | `DIFFERENT` | Existe ruta equivalente en el repo, pero el hash difiere. |
| StarterPlayer.StarterPlayerScripts.PastureStatsClient | LocalScript | 31 | `5063c318eb5d1fe9fa655be4a71aba6cd3042f29bf0a289c18b475a6572dbfa9` |  |  | `STUDIO_ONLY` | No existe version mapeada en scripts/ ni snapshots/CodexAvanceTest_Current/. |
| StarterPlayer.StarterPlayerScripts.RunOnlyAnimationTest | LocalScript | 160 | `55bfd8b8c0f58233f0fc1288140c19c878af0d9e6cccc6b36c0ac96313bc9178` |  |  | `STUDIO_ONLY` | No existe version mapeada en scripts/ ni snapshots/CodexAvanceTest_Current/. |
| StarterPlayer.StarterPlayerScripts.SlingshotAnimateGuard | LocalScript | 257 | `b381936e7b88c33095b55b2e16f77bb20bec83435b2c2072b1a1751c08f62dfd` | snapshots/CodexAvanceTest_Current/StarterPlayerScripts/SlingshotAnimateGuard.client.lua | b381936e7b88c33095b55b2e16f77bb20bec83435b2c2072b1a1751c08f62dfd | `MATCH` |  |
| StarterPlayer.StarterPlayerScripts.SlingshotController | LocalScript | 1941 | `caf9cd77e8c80a0397de96982ab96973208f9905e3ee26d02ecd6274a8754050` | snapshots/CodexAvanceTest_Current/StarterPlayerScripts/SlingshotController.client.lua | dbde956a50b5141d03dff757ba7d53933ccd1278d7df9c3548150a9a9c5ac5d2 | `DIFFERENT` | Existe ruta equivalente en el repo, pero el hash difiere. |
| Workspace.Realistic Campfire.Fire.Light.FX | Script | 19 | `68312e87bc4b0b68956529d779f719f8b18019aab74cc17a1b7f13fdd69f31aa` |  |  | `STUDIO_ONLY` | No existe version mapeada en scripts/ ni snapshots/CodexAvanceTest_Current/. |
| Workspace.Realistic Campfire.READ ME | Script | 33 | `2ba933d41c47a3b38354b7ef6657cf0bf01daf7610f55c97849e07556cd3caca` |  |  | `STUDIO_ONLY` | No existe version mapeada en scripts/ ni snapshots/CodexAvanceTest_Current/. |
| Workspace.Rig.Animate | LocalScript | 898 | `c6a4fd950adac4f5f67ec72f4fe94bedc34aab40e66f432266115bc4a99b1d11` |  |  | `STUDIO_ONLY` | No existe version mapeada en scripts/ ni snapshots/CodexAvanceTest_Current/. |
| Workspace.SheepPens.SheepPenGate.Script | Script | 14 | `39a11451cf55e1db152adcc4661e1267b51720e8c2ebbf3387bec41e99e09f38` |  |  | `STUDIO_ONLY` | No existe version mapeada en scripts/ ni snapshots/CodexAvanceTest_Current/. |
| Workspace.StarterCharacter.Animate | LocalScript | 898 | `c6a4fd950adac4f5f67ec72f4fe94bedc34aab40e66f432266115bc4a99b1d11` |  |  | `STUDIO_ONLY` | No existe version mapeada en scripts/ ni snapshots/CodexAvanceTest_Current/. |

## Archivos que deben exportarse para poner GitHub al dia

- `ServerScriptService.Homestead.M.AnimalService`
- `ServerScriptService.Homestead.M.Chicken`
- `ServerScriptService.Homestead.M.DragonRaidService`
- `ServerScriptService.Homestead.M.EggService`
- `ServerScriptService.Homestead.M.HomeService`
- `ServerScriptService.Homestead.M.StorageService`
- `SoundService.Copiadeseguridad.Cfg`
- `SoundService.Copiadeseguridad.Flock`
- `SoundService.Copiadeseguridad.Sheep`
- `StarterPack.Script`
- `StarterPlayer.StarterPlayerScripts.HomesteadClient`
- `StarterPlayer.StarterPlayerScripts.HondaToolIsolationTest`
- `StarterPlayer.StarterPlayerScripts.PastureClient`
- `StarterPlayer.StarterPlayerScripts.PasturePromptClient`
- `StarterPlayer.StarterPlayerScripts.PastureStatsClient`
- `StarterPlayer.StarterPlayerScripts.RunOnlyAnimationTest`
- `StarterPlayer.StarterPlayerScripts.SlingshotController`
- `Workspace.Realistic Campfire.Fire.Light.FX`
- `Workspace.Realistic Campfire.READ ME`
- `Workspace.Rig.Animate`
- `Workspace.SheepPens.SheepPenGate.Script`
- `Workspace.StarterCharacter.Animate`

## Conclusion

NO SINCRONIZADO
