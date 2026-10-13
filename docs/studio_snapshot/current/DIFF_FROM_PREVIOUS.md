# Comparación: Studio Actual vs. Snapshots en GitHub

Comparación de SHA-256 entre el estado actual de Roblox Studio (`docs/studio_snapshot/current/scripts/`) y el snapshot previo en el repositorio (`snapshots/CodexAvanceTest_Current/`).

## Resumen de Divergencias

| Script Studio | Hash Studio Actual | Hash GitHub Repo | Estado |
|---|---|---|---|
| `Workspace.LensFlare.README` | `0a72b091dc595a37...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `Workspace.LensFlare.Configuration` | `c1a330c793b363ef...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `Workspace.LensFlare.Modules.LensFlare` | `9594c9b2f6133c7d...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `Workspace.LensFlare.Client.InitLensFlare` | `287d5b7d1467c2aa...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `Workspace.Rig.Animate` | `c6a4fd950adac4f5...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `Workspace.StarterCharacter.Animate` | `c6a4fd950adac4f5...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `Workspace.Cabaña1.Realistic Campfire.READ ME` | `717b6d3410a5fbe0...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `Workspace.Cabaña1.Realistic Campfire.Fire.Light.FX` | `717b6d3410a5fbe0...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ReplicatedStorage.WyvernFlight.Shared.WyvernGroundDetector` | `cec1740a7ccbf7ca...` | `cec1740a7ccbf7ca...` | MATCH (Idéntico) |
| `ReplicatedStorage.WyvernFlight.Config.WyvernPhysicsConfig` | `b46db36d19b80dcc...` | `b46db36d19b80dcc...` | MATCH (Idéntico) |
| `ReplicatedStorage.WyvernFlight.Config.WyvernAerodynamicsConfig` | `42e380975f0102da...` | `42e380975f0102da...` | MATCH (Idéntico) |
| `ReplicatedStorage.WyvernFlight.Config.WyvernAeroSurfaceConfig` | `a5433ec279c37a0f...` | `a5433ec279c37a0f...` | MATCH (Idéntico) |
| `ReplicatedStorage.WyvernFlight.Config.WyvernPropulsionConfig` | `f75cf834f6f96dc2...` | `f75cf834f6f96dc2...` | MATCH (Idéntico) |
| `ReplicatedStorage.WyvernFlight.Config.WyvernFlappingConfig` | `0514abff01aab8a5...` | `0514abff01aab8a5...` | MATCH (Idéntico) |
| `ReplicatedStorage.WyvernFlight.Config.WyvernTakeoffConfig` | `ff6623dc617c34bf...` | `ff6623dc617c34bf...` | MATCH (Idéntico) |
| `ReplicatedStorage.WyvernFlight.Kinematics.WyvernWingKinematics` | `bf8a747ceb2ff336...` | `bf8a747ceb2ff336...` | MATCH (Idéntico) |
| `ReplicatedStorage.WyvernFlight.Kinematics.WyvernFlightEffortModel` | `f3727a637386f45b...` | `f3727a637386f45b...` | MATCH (Idéntico) |
| `ReplicatedStorage.WyvernFlightV2.FlightAimState` | `af3efed8ce139913...` | `105c08d68ae3a19e...` | **DIFFERENT (Modificado en Studio)** |
| `ReplicatedStorage.WyvernFlightV2.Config.WyvernFlightConfig` | `f8351d59bf637069...` | `f8351d59bf637069...` | MATCH (Idéntico) |
| `ServerScriptService.Pasture.Main` | `875f4c4505cb8d99...` | `f34cff7d7389f6d5...` | **DIFFERENT (Modificado en Studio)** |
| `ServerScriptService.Pasture.Monitor` | `01f02d1de2281514...` | `01f02d1de2281514...` | MATCH (Idéntico) |
| `ServerScriptService.Pasture.M.Cfg` | `cddb9f82df688a5f...` | `f79d98f9b9f38026...` | **DIFFERENT (Modificado en Studio)** |
| `ServerScriptService.Pasture.M.Rand` | `fcd87e0a2e3eae0e...` | `fcd87e0a2e3eae0e...` | MATCH (Idéntico) |
| `ServerScriptService.Pasture.M.House` | `4a0e05dfdc16e54a...` | `f5cd852964976436...` | **DIFFERENT (Modificado en Studio)** |
| `ServerScriptService.Pasture.M.Flock` | `d12e70bb7558237f...` | `08d487bda05fe3ac...` | **DIFFERENT (Modificado en Studio)** |
| `ServerScriptService.Pasture.M.Sheep` | `4baaa7a49c952cf0...` | `db279e93e18de690...` | **DIFFERENT (Modificado en Studio)** |
| `ServerScriptService.Homestead.Main` | `af0e735d053b5fea...` | `6b64e5713696318e...` | **DIFFERENT (Modificado en Studio)** |
| `ServerScriptService.Homestead.M.HomeCfg` | `93145cf41f4c34ee...` | `e77645efaedf50a7...` | **DIFFERENT (Modificado en Studio)** |
| `ServerScriptService.Homestead.M.StationService` | `9cbf3e1784387029...` | `9cbf3e1784387029...` | MATCH (Idéntico) |
| `ServerScriptService.Homestead.M.HomeService` | `a6f6fbb79cc91f21...` | `a6f6fbb79cc91f21...` | MATCH (Idéntico) |
| `ServerScriptService.Homestead.M.Chicken` | `4974b4c9083f7b27...` | `bdbfc7799b396011...` | **DIFFERENT (Modificado en Studio)** |
| `ServerScriptService.Homestead.M.AnimalService` | `d30bd4a8e77b6058...` | `44074318354c4093...` | **DIFFERENT (Modificado en Studio)** |
| `ServerScriptService.Homestead.M.EggService` | `47bc4a92cdd49b76...` | `47bc4a92cdd49b76...` | MATCH (Idéntico) |
| `ServerScriptService.WyvernFlight.Services.WyvernFlightStateManager` | `895edaf1392a400d...` | `895edaf1392a400d...` | MATCH (Idéntico) |
| `ServerScriptService.WyvernFlight.Physics.WyvernPhysicsBaseline` | `62ec753dde240341...` | `62ec753dde240341...` | MATCH (Idéntico) |
| `ServerScriptService.WyvernFlight.Physics.WyvernAerodynamics` | `9d61fb9149873db4...` | `9d61fb9149873db4...` | MATCH (Idéntico) |
| `ServerScriptService.WyvernFlight.Physics.WyvernPropulsion` | `0a277bc16b7e35fb...` | `0a277bc16b7e35fb...` | MATCH (Idéntico) |
| `ServerScriptService.WyvernFlight.Physics.WyvernFlapping` | `1385f3ba33715b5a...` | `1385f3ba33715b5a...` | MATCH (Idéntico) |
| `ServerScriptService.WyvernFlight.Physics.WyvernTakeoffController` | `c9165e724b6a43a3...` | `c9165e724b6a43a3...` | MATCH (Idéntico) |
| `ServerScriptService.WyvernFlightV2.FlightController` | `80f43a9dabb28175...` | `80f43a9dabb28175...` | MATCH (Idéntico) |
| `ServerStorage._Reference_DragonClassic.ServerScripts.DragonFlightService.server.lua` | `e3b0c44298fc1c14...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.ServerScripts.DragonCollisionRuntime.server.lua` | `e3b0c44298fc1c14...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.ServerScripts.DragonRiderRealCharacterParkingStabilizer.server.lua` | `e3b0c44298fc1c14...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.ServerScripts.DragonPhase4MountService.server.lua` | `e3b0c44298fc1c14...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.ServerScripts.DragonFlightService_DUPLICATE_DISABLED_DO_NOT_RUN` | `c841e6e213b5c333...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.ServerScripts.DragonCollisionRuntime_DUPLICATE_DISABLED_DO_NOT_RUN` | `b70ddc89eaf3811e...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.ServerScripts.DragonGroundKinematic` | `163f153d06e8e53b...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.ServerScripts.DragonGroundKinematic.module.lua` | `e3b0c44298fc1c14...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.ServerScripts.DragonFlightImpact` | `991810a68d0ee612...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.ServerScripts.DragonFlightImpact.module.lua` | `e3b0c44298fc1c14...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.ServerScripts.DragonSheepThrowTest.server.lua` | `e3b0c44298fc1c14...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.ServerScripts.DragonSheepGrabWalkTest.server.lua` | `e3b0c44298fc1c14...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.ServerScripts.DragonPivotDirectTest.server.lua` | `e3b0c44298fc1c14...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.ServerScripts.HumanoidPhysicsPinTest` | `de92cad8880714de...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.ServerScripts.SystemFlightTravelTestRunner` | `02e64b559257015a...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.ServerScripts.SystemFlightTravelTestRunner` | `02e64b559257015a...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.ClientScripts.DragonFlightClient.client.lua` | `e3b0c44298fc1c14...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.ClientScripts.DragonMouseAim.client.lua` | `e3b0c44298fc1c14...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.ClientScripts.DragonBodyCurl.client.lua` | `e3b0c44298fc1c14...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.ClientScripts.DragonSpineAim.client.lua` | `e3b0c44298fc1c14...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.ClientScripts.DragonSerpentTurn.client.lua` | `e3b0c44298fc1c14...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.ClientScripts.DragonTorsoTwist` | `4a6a7b44ebda1da1...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.ClientScripts.DragonRiderVisual.client.lua` | `e3b0c44298fc1c14...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.ClientScripts.DragonRiderCameraProxyStabilizer.client.lua` | `e3b0c44298fc1c14...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.ClientScripts.LocalScript` | `e87c69df05b2154a...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.ClientScripts.DragonMountPhase4LateWeld.client.lua` | `e3b0c44298fc1c14...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.ClientScripts.DragonRearFootIK` | `257e47b58b29bc4f...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.ClientScripts.DragonTerrainAdaptationDebug` | `a870106d54b86ceb...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.ClientScripts.DragonRootSlopeDebug` | `c4543a1c711efc75...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.ClientScripts.DragonJitterTrap` | `f48df012512d8eba...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `ServerStorage._Reference_DragonClassic.StarterGui.DragonSheepTestGui.MainFrame.DragonSheepTestClient` | `a7e011eb78040101...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `StarterPlayer.StarterPlayerScripts.PastureClient` | `c216cefd7b843d7a...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `StarterPlayer.StarterPlayerScripts.PastureStatsClient` | `5063c318eb5d1fe9...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `StarterPlayer.StarterPlayerScripts.HomesteadClient` | `44bf5cf9837e8adc...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `StarterPlayer.StarterPlayerScripts.PasturePromptClient` | `09c2b83d916c0c49...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `StarterPlayer.StarterPlayerScripts.ChickenCarryAnimClient` | `01f5c2530a746392...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `StarterPlayer.StarterPlayerScripts.WyvernFlight.WyvernWingVisualClient` | `733a80dcfeb5593c...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `StarterPlayer.StarterPlayerScripts.WyvernFlight.Client.WyvernManualTestController` | `0299b930fcb60e1c...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `StarterPlayer.StarterPlayerScripts.WyvernFlight.Visual.WyvernTelemetryUI` | `919d7ca70caf30a4...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `StarterPlayer.StarterPlayerScripts.WyvernFlightV2.Input` | `edbef32bb2e2109b...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `StarterPlayer.StarterPlayerScripts.WyvernFlightV2.FlightCamera` | `f7aea132226df600...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `StarterPlayer.StarterPlayerScripts.WyvernFlightV2.FlightAnimation` | `130d9cc6ded83234...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `StarterGui.Cfgf` | `902d8c0154a746e1...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |
| `StarterPack.Script` | `fc13785bdefb112f...` | `N/A` | *STUDIO_ONLY (Nuevo / Sin tracking)* |

## Archivos en GitHub Repo ausentes en Studio (REPO_ONLY)

| Archivo en GitHub | SHA-256 | Estado |
|---|---|---|
| `ServerScriptService/BastonTestService.lua` | `e2186f81041ba353...` | REPO_ONLY |
| `ServerScriptService/DragonRaidAutoTest.server.lua` | `02b018c0017477ed...` | REPO_ONLY |
| `ServerScriptService/Homestead/M/Cuy.lua` | `439429831a9ba203...` | REPO_ONLY |
| `ServerScriptService/Homestead/M/DragonRaidService.lua` | `481a13d3d82424ec...` | REPO_ONLY |
| `ServerScriptService/Homestead/M/InventoryService.lua` | `ade0567e3f732fa9...` | REPO_ONLY |
| `ServerScriptService/Homestead/M/SlingshotService.lua` | `1efda2bb202304d4...` | REPO_ONLY |
| `ServerScriptService/Homestead/M/StorageService.lua` | `464197d98ddf4d1b...` | REPO_ONLY |
| `ServerScriptService/Homestead/Monitor.lua` | `321a3a012697f55e...` | REPO_ONLY |
| `ServerScriptService/Pasture/M/GrazingService.lua` | `7de683e0247333cd...` | REPO_ONLY |
| `ServerScriptService/WyvernFlight/Diagnostics/WyvernTakeoffDiagnostic5E3B.server.lua` | `6b88d811cf89406c...` | REPO_ONLY |
| `ServerScriptService/WyvernFlight/Diagnostics/WyvernTakeoffDiagnostic5E3C.server.lua` | `f1c0e98dd3c8bc92...` | REPO_ONLY |
| `ServerScriptService/WyvernFlight/Diagnostics/WyvernTakeoffPhysXValidation.server.lua` | `66bb0e349c3187e1...` | REPO_ONLY |
| `StarterPlayer/StarterPlayerScripts/BastonTestController.lua` | `52bae0ad8a74cb36...` | REPO_ONLY |
| `StarterPlayerScripts/ChickenCarryAnimClient.client.lua` | `01f5c2530a746392...` | REPO_ONLY |
| `StarterPlayerScripts/HomesteadClient.client.lua` | `44bf5cf9837e8adc...` | REPO_ONLY |
| `StarterPlayerScripts/PasturePromptClient.client.lua` | `09c2b83d916c0c49...` | REPO_ONLY |
| `StarterPlayerScripts/SlingshotAnimateGuard.client.lua` | `b381936e7b88c330...` | REPO_ONLY |
| `StarterPlayerScripts/SlingshotController.client.lua` | `29107281f9ee3d29...` | REPO_ONLY |
| `StarterPlayerScripts/WyvernFlight/Client/WyvernManualTestController.client.lua` | `0299b930fcb60e1c...` | REPO_ONLY |
| `StarterPlayerScripts/WyvernFlight/Visual/WyvernTelemetryUI.client.lua` | `919d7ca70caf30a4...` | REPO_ONLY |
| `StarterPlayerScripts/WyvernFlight/WyvernWingVisualClient.client.lua` | `733a80dcfeb5593c...` | REPO_ONLY |
| `StarterPlayerScripts/WyvernFlightV2/FlightAnimation.client.lua` | `130d9cc6ded83234...` | REPO_ONLY |
| `StarterPlayerScripts/WyvernFlightV2/FlightCamera.client.lua` | `f7aea132226df600...` | REPO_ONLY |
| `StarterPlayerScripts/WyvernFlightV2/Input.client.lua` | `edbef32bb2e2109b...` | REPO_ONLY |
