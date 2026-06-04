# ROBLOX_STRUCTURE.md

Informe de inspeccion de Roblox Studio para preparar cambios seguros en el sistema de disparo con huevos.

## Inspeccion

- Fecha: 2026-06-04 02:41 -05:00
- Target MCP activo: `CodexAvanceTest`
- Studio id: `202e33d8-ccb8-4fce-9451-bb9f0515f664`
- DataModel accesible: si
- Nombre interno del DataModel: `Place1`
- PlaceId: `84364645709785`
- Modo: solo lectura. No se modifico Roblox Studio.

Servicios verificados:

- `Workspace`: accesible, 24 hijos directos.
- `ServerScriptService`: accesible, 2 hijos directos.
- `ReplicatedStorage`: accesible, 2 hijos directos.
- `StarterPlayer`: accesible, 2 hijos directos.
- `StarterGui`: accesible, 1 hijo directo.

## Workspace

Estructura relevante encontrada:

- `Workspace.Houses`
  - Carpeta principal de Homestead.
  - Contiene 10 casas: `House01`, `House02`, `House03`, `House04`, `House05`, `House06`, `House07`, `House08`, `House09`, `House010`.
  - Cada casa parece seguir el patron de `House01`.
- `Workspace.Houses.House01`
  - `AnimalZones`
    - `ChickenEggPoints`
      - `EggPoint01`
      - `EggPoint02`
      - `EggPoint03`
    - `ChickenNestAccessPoints`
      - `AccessPoint01`
      - `AccessPoint02`
      - `AccessPoint03`
    - `ChickenNestJumpLinks`
      - `NestJump01.Start`
      - `NestJump01.End`
    - `ChickenRoamZone`
    - `ChickenCoopZone`
    - `CuyRoamZone`
    - `CuyHidePoints`
  - `AnimalSpawns`
    - `ChickenSpawns`
      - `Spawn01`
      - `Spawn02`
      - `Spawn03`
    - `CuySpawns`
  - `SheepSpawns`
  - `Stations`
    - `Kitchen`
    - `Storage`
      - `StoragePart`
    - `Incubator`
    - `AnimalCare`
    - `Bed`
  - `ClaimPromptPart.ProximityPrompt`
  - `CorralCenter`
- `Workspace.HomeRuntime`
  - Existe como `Folder`.
  - No tenia hijos visibles durante la inspeccion.
- `Workspace.SheepRuntime`
  - Existe como `Folder`.
  - No tenia hijos visibles durante la inspeccion.
- `Workspace.WorkspaceGallinaReference`
  - Modelo de referencia de gallina.
  - Hijos inmediatos: `AnimSaves`, `HumanodiRootPart`, `MeshGallina`, `AnimationController`, `InitialPoses`.
- Otros elementos visibles: `Baseplate`, `SpawnLocation`, `Realistic Campfire`, `Rig`, `StarterCharacter`, `SheepTemplateTest`, `Cabaña1`, `Sketchfab_Scene`, varios `Part`.

## ServerScriptService

Estructura relevante encontrada:

- `ServerScriptService.Pasture`
  - `Main` (`Script`)
  - `Monitor` (`Script`)
  - `M`
    - `Cfg` (`ModuleScript`)
    - `Rand` (`ModuleScript`)
    - `House` (`ModuleScript`)
    - `Flock` (`ModuleScript`)
    - `Sheep` (`ModuleScript`)
- `ServerScriptService.Homestead`
  - `Main` (`Script`)
  - `Monitor` (`Script`)
  - `M`
    - `HomeCfg` (`ModuleScript`)
    - `StationService` (`ModuleScript`)
    - `HomeService` (`ModuleScript`)
    - `Chicken` (`ModuleScript`)
    - `AnimalService` (`ModuleScript`)
    - `EggService` (`ModuleScript`)
    - `Cuy` (`ModuleScript`)
    - `InventoryService` (`ModuleScript`)
    - `StorageService` (`ModuleScript`)
    - `SlingshotService` (`ModuleScript`)

Notas de scripts relevantes:

- `Homestead.Main` inicializa `HomeService`, `InventoryService`, `StorageService`, `SlingshotService` y `AnimalService`.
- `Homestead.Main` define remotes de Homestead y tambien define un folder `SlingshotRemote` con `FireRequest`, `FireResult` y `AmmoChanged`, pero `ReplicatedStorage.SlingshotRemote` no existe en edit mode durante esta inspeccion.
- `SlingshotService` ya usa el item `Egg` como municion mediante `InventoryService`.
- `SlingshotService` ya sincroniza el atributo de jugador `SlingshotEggAmmo`.
- `SlingshotService` ya bloquea disparo si:
  - `CarryingChicken == true`
  - `HomesteadStorageOpen == true`
  - personaje invalido o muerto
  - no hay herramienta `Honda` o `Slingshot` equipada
  - cooldown activo
  - inventario sin `Egg`
- `InventoryService` guarda inventario de sesion por jugador con items `Egg`, `GoldenEgg`, `ChickenFeed`, `CuyFeed`.
- `StorageService` muestra el inventario actual, pero no separa `EggStorage` de municion activa.
- `EggService` recoge huevos y suma `Egg` al inventario; tambien actualiza `SlingshotEggAmmo`.

## ReplicatedStorage

Estructura actual encontrada en edit mode:

- `ReplicatedStorage.PastureRemote`
  - `Whistle` (`RemoteEvent`)
  - `RequestStats` (`RemoteEvent`)
  - `StatsResponse` (`RemoteEvent`)
- `ReplicatedStorage.HomesteadRemote`
  - Atributo: `CarryChickenAnimationId = rbxassetid://84371476515785`
  - `RequestHomeInfo` (`RemoteEvent`)
  - `HomeInfo` (`RemoteEvent`)
  - `DropChicken` (`RemoteEvent`)
  - `RequestStorage` (`RemoteEvent`)
  - `StorageData` (`RemoteEvent`)
  - `CloseStorage` (`RemoteEvent`)

Remotes definidos por script pero no presentes en edit mode:

- `ReplicatedStorage.SlingshotRemote`
  - `FireRequest`
  - `FireResult`
  - `AmmoChanged`

Riesgo: no crear manualmente remotes duplicados sin confirmar el comportamiento al iniciar Play/servidor.

## StarterPlayer

Estructura relevante encontrada:

- `StarterPlayer.StarterPlayerScripts`
  - `PastureClient` (`LocalScript`)
  - `PastureStatsClient` (`LocalScript`)
  - `HomesteadClient` (`LocalScript`)
  - `PasturePromptClient` (`LocalScript`)
  - `ChickenCarryAnimClient` (`LocalScript`)
  - `SlingshotController` (`LocalScript`)
  - `RunOnlyAnimationTest` (`LocalScript`)
  - `HondaToolIsolationTest` (`LocalScript`)
  - `SlingshotAnimateGuard` (`LocalScript`)
- `StarterPlayer.StarterCharacterScripts`
  - Sin hijos relevantes visibles en la inspeccion.

Notas de cliente:

- `HomesteadClient` crea en runtime `HomesteadStorageGui` en `PlayerGui`; no existe como ScreenGui prearmado en `StarterGui`.
- `HomesteadClient` consume `StorageData` y muestra `Egg`, `GoldenEgg`, `ChickenFeed`, `CuyFeed`.
- `SlingshotController` solicita disparo con `fireRequestEvent:FireServer(origin, direction, charge)`.
- `SlingshotController` crea visuales locales `SlingshotEggProjectile` y `SlingshotEggImpact`.
- `SlingshotController` bloquea entrada si `CarryingChicken` o `HomesteadStorageOpen` estan activos.
- `SlingshotAnimateGuard` protege animaciones de Honda BattleMode y respeta `CarryingChicken`.

## StarterGui

Estructura encontrada:

- `StarterGui.Cfgf` (`ModuleScript`)

No se encontro UI preexistente de storage en `StarterGui`. La UI de storage se crea desde `StarterPlayer.StarterPlayerScripts.HomesteadClient`.

## StarterPack

Aunque no estaba en la lista minima solicitada, es relevante para combate:

- `StarterPack.Honda` (`Tool`)
  - `Handle`
  - `Fork`
- `StarterPack.Script` (`Script`)
- `StarterPack.RBX_ANIMSAVES` con muchas animaciones.

`SlingshotService` acepta herramientas llamadas `Honda` o `Slingshot`.

## ServerStorage

Estructura relevante para plantillas:

- `ServerStorage.Assets.HomesteadAnimals`
  - `EggTemplate` (`Model`)
    - `Egg` (`Part`)
  - `Gallina` (`Model`)
    - `InitialPoses`
    - `AnimationController`
    - `AnimSaves`
    - `MeshGallina`
    - `HumanodiRootPart`
  - `CuyTemplate`
  - `DevReferences`
- `ServerStorage.Assets.Sheep.SheepTemplate`
- `ServerStorage.RBX_ANIMSAVES`
  - Contiene animaciones/guardados de gallina, oveja, rig y otros modelos.

## Ubicaciones clave

- Homestead:
  - Mundo: `Workspace.Houses`
  - Runtime: `Workspace.HomeRuntime`
  - Servidor: `ServerScriptService.Homestead`
  - Remotes: `ReplicatedStorage.HomesteadRemote`
- Chicken / Gallina:
  - Template principal: `ServerStorage.Assets.HomesteadAnimals.Gallina`
  - Referencia en Workspace: `Workspace.WorkspaceGallinaReference`
  - Logica servidor: `ServerScriptService.Homestead.M.Chicken`
  - Orquestacion animales: `ServerScriptService.Homestead.M.AnimalService`
  - Cliente animacion carry: `StarterPlayer.StarterPlayerScripts.ChickenCarryAnimClient`
- EggTemplate:
  - `ServerStorage.Assets.HomesteadAnimals.EggTemplate`
- Storage:
  - Fisico por casa: `Workspace.Houses.<House>.Stations.Storage.StoragePart`
  - Servidor: `ServerScriptService.Homestead.M.StorageService`
  - Cliente/UI runtime: `StarterPlayer.StarterPlayerScripts.HomesteadClient`
  - Remotes: `ReplicatedStorage.HomesteadRemote.RequestStorage`, `StorageData`, `CloseStorage`
- Slingshot / Honda:
  - Tool: `StarterPack.Honda`
  - Servidor: `ServerScriptService.Homestead.M.SlingshotService`
  - Cliente: `StarterPlayer.StarterPlayerScripts.SlingshotController`
  - Anim guard: `StarterPlayer.StarterPlayerScripts.SlingshotAnimateGuard`
  - Remotes previstos por script: `ReplicatedStorage.SlingshotRemote.FireRequest`, `FireResult`, `AmmoChanged`

## Remotes existentes relacionados

Presentes en `ReplicatedStorage`:

- Homestead:
  - `ReplicatedStorage.HomesteadRemote.RequestHomeInfo`
  - `ReplicatedStorage.HomesteadRemote.HomeInfo`
  - `ReplicatedStorage.HomesteadRemote.DropChicken`
- Storage/UI:
  - `ReplicatedStorage.HomesteadRemote.RequestStorage`
  - `ReplicatedStorage.HomesteadRemote.StorageData`
  - `ReplicatedStorage.HomesteadRemote.CloseStorage`
- Pasture:
  - `ReplicatedStorage.PastureRemote.Whistle`
  - `ReplicatedStorage.PastureRemote.RequestStats`
  - `ReplicatedStorage.PastureRemote.StatsResponse`

Definidos en `Homestead.Main` pero no presentes en edit mode:

- Combat/Slingshot:
  - `ReplicatedStorage.SlingshotRemote.FireRequest`
  - `ReplicatedStorage.SlingshotRemote.FireResult`
  - `ReplicatedStorage.SlingshotRemote.AmmoChanged`

## Scripts sensibles

No tocar sin autorizacion o issue especifico:

- `ServerScriptService.Pasture`
- `ServerScriptService.Homestead.M.Chicken`
- `StarterPlayer.StarterPlayerScripts.ChickenCarryAnimClient`
- `ServerScriptService.Homestead.M.StorageService`
- `StarterPlayer.StarterPlayerScripts.HomesteadClient`
- `StarterPlayer.StarterPlayerScripts.SlingshotController`
- `StarterPlayer.StarterPlayerScripts.SlingshotAnimateGuard`
- `ServerScriptService.Homestead.M.SlingshotService`
- `ServerScriptService.Homestead.M.EggService`
- `ServerStorage.Assets.HomesteadAnimals.Gallina`
- `ServerStorage.Assets.HomesteadAnimals.EggTemplate`
- `StarterPack.Honda`

## Sistemas que no deben tocarse sin autorizacion

Por reglas del proyecto, no tocar sin issue con `[Protected Change]`:

- `ServerScriptService.Pasture`
- `CarryChicken`
- `ChickenCarryAnimClient`
- `Storage/UI`
- `Honda BattleMode`
- `Death/Reset`
- Templates principales de Gallina y `EggTemplate`

## Recomendacion para EggAmmo

El primer issue de EggAmmo no deberia crear un sistema nuevo desde cero. Ya existe una base:

- Municion actual: atributo `SlingshotEggAmmo`.
- Fuente actual: `InventoryService` item `Egg`.
- Consumo actual: `SlingshotService:Fire()` descuenta `Egg` con `InventoryService:RemoveItem(player, "Egg", 1)`.
- UI actual: `HomesteadClient` muestra inventario `Egg`, no separa storage/ammo.

Recomendacion segura:

1. Preparar un issue de analisis/ajuste pequeno para decidir si `SlingshotEggAmmo` se conserva como nombre o se migra a `EggAmmo`.
2. No duplicar remotes; verificar primero en Play si `SlingshotRemote` aparece al ejecutar `Homestead.Main`.
3. Si se implementa separacion real `EggStorage` vs `EggAmmo`, el cambio debe tocar con cuidado:
   - `InventoryService`
   - `StorageService`
   - `SlingshotService`
   - `HomesteadClient`
   - posiblemente `EggService`
4. Como Storage/UI y Honda BattleMode son sensibles, el issue debe ser muy acotado o marcarse como `[Protected Change]` si va a tocar esos flujos.

## Falta confirmar antes del disparo con huevos

- Probar en Play si `ReplicatedStorage.SlingshotRemote` se crea correctamente y no queda bloqueado por `WaitForChild` en cliente.
- Confirmar si el juego quiere conservar `SlingshotEggAmmo` o crear `EggAmmo` como atributo canonico.
- Confirmar diseno: `EggStorage` separado de `EggAmmo`, o inventario `Egg` actual como municion activa.
- Confirmar comportamiento esperado al recoger huevo: directo a municion, directo a storage, o ambos con accion de carga.
- Confirmar si `HomesteadStorageOpen` cubre todas las UI criticas o solo Storage.
- Confirmar pruebas manuales en Roblox Studio para muerte/reset, carry chicken, storage abierto, disparo sin municion y disparo con municion.

## Riesgos detectados

- Ya existe municion funcional bajo `SlingshotEggAmmo`; crear `EggAmmo` sin migracion clara puede duplicar estado.
- `EggStorage` no existe; mezclarlo con `InventoryService.Egg` podria romper storage o municion.
- `SlingshotRemote` esta definido por script pero no existe en edit mode; crear otro remoto manualmente podria duplicar o cambiar el flujo.
- Storage/UI y Honda BattleMode son sensibles y ya estan conectados al bloqueo de disparo.
- `EggService` destruye huevos al recoger y actualiza municion; cambiarlo sin prueba puede duplicar o perder huevos.
- Las plantillas `Gallina` y `EggTemplate` existen en `ServerStorage` y son protegidas.

