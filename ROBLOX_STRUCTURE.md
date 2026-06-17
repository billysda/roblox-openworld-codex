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

## Analisis consolidado de municion

Actualizado: 2026-06-04 03:12 -05:00.

Hallazgos de solo lectura:

- `ReplicatedStorage.SlingshotRemote` no existe en edit mode.
- `ServerScriptService.Homestead.Main` crea `SlingshotRemote`, `FireRequest`, `FireResult` y `AmmoChanged` cuando se ejecuta.
- `StarterPlayer.StarterPlayerScripts.SlingshotController` espera `ReplicatedStorage.SlingshotRemote` con `WaitForChild`.
- `InventoryService.Egg` es la fuente real actual de municion.
- `SlingshotService:GetAmmo()` lee `InventoryService:GetItemCount(player, "Egg")`.
- `SlingshotService:Fire()` descuenta `InventoryService:RemoveItem(player, "Egg", 1)`.
- `SlingshotEggAmmo` funciona como atributo sincronizado/espejo del conteo de `Egg`.
- `EggService` suma `Egg` al recoger huevo y actualiza `SlingshotEggAmmo`.
- No se encontraron referencias exactas a `EggStorage`.
- No se encontraron referencias exactas a un atributo o variable independiente `"EggAmmo"`.

Conclusion de diseno:

- Mantener `SlingshotEggAmmo` por ahora es la opcion mas segura porque ya esta conectado al sistema existente.
- Crear `EggAmmo` separado solo conviene despues de definir formalmente `EggStorage` vs municion activa.
- Implementar `EggAmmo` en paralelo sin migracion puede duplicar estado y romper la UI o el consumo de huevos.

Riesgos de migracion futura a `EggAmmo`:

- Cliente y servidor podrian leer nombres distintos (`EggAmmo` vs `SlingshotEggAmmo`).
- `InventoryService.Egg` podria seguir bajando aunque la UI muestre otro contador.
- `EggService` podria sumar huevos al inventario equivocado.
- `StorageService` podria mostrar huevos almacenados como si fueran municion activa.
- Los remotes de `SlingshotRemote` deben validarse en Play antes de renombrar o crear atributos nuevos.

## Analisis de bloqueos por Storage

Actualizado: 2026-06-04 03:14 -05:00.

Hallazgos de solo lectura:

- `StorageService:OpenStorage()` marca `player:SetAttribute("HomesteadStorageOpen", true)` despues de validar casa/owner y antes de enviar `StorageData`.
- `Homestead.Main` marca `HomesteadStorageOpen = false` cuando recibe `CloseStorage`.
- `Homestead.Main` tambien limpia `HomesteadStorageOpen = false` en `CharacterRemoving`.
- `SlingshotController:canActivate()` bloquea Honda/BattleMode si `HomesteadStorageOpen == true`, limpia modo local y fuerza unequip local.
- `SlingshotController` escucha `HomesteadStorageOpen`; si cambia a `true`, ejecuta `cleanupMode("StorageOpen")`, limpia atributos debug y fuerza unequip local.
- `SlingshotController:canRequestFire()` bloquea request de disparo si `HomesteadStorageOpen == true`.
- `SlingshotService:CanFire()` bloquea en servidor con razon `"StorageOpen"` si `HomesteadStorageOpen == true`.

Conclusion:

- El bloqueo por Storage existe en cliente y servidor.
- Storage/UI sigue siendo sistema sensible; cualquier conexion con municion debe respetar `HomesteadStorageOpen`.
- Falta confirmar en Play que abrir/cerrar Storage sincroniza el atributo correctamente en cliente y servidor.

## Comparacion con CHECKLIST_TESTING

Estado actual segun inspeccion de lectura:

- Recoleccion: `EggService` suma `InventoryService.Egg` y marca/destruye el huevo, pero requiere prueba manual.
- Municion: el servidor descuenta `InventoryService.Egg` al disparar y sincroniza `SlingshotEggAmmo`, pero falta prueba en Play.
- Storage: no existe separacion real `EggStorage` vs `EggAmmo`; el Storage muestra `InventoryService.Egg`.
- CarryChicken: el disparo se bloquea por `CarryingChicken` en cliente y servidor, pero falta prueba manual.
- Death/Reset: `SlingshotService` revisa humanoid muerto/invalido y `SlingshotController` limpia en `HumanoidDead`/`CharacterRemoving`, pero falta prueba manual.
- UI: `HomesteadClient` muestra inventario `Egg`; no hay UI especifica de `EggAmmo` confirmada.
- Multiplayer: `InventoryService` usa inventario por `UserId`; falta prueba manual de varios jugadores.

## Riesgo de WaitForChild en SlingshotController

- `SlingshotController` espera `ReplicatedStorage.SlingshotRemote` con `WaitForChild` sin timeout.
- Tambien espera `FireRequest`, `FireResult` y `AmmoChanged` sin timeout.
- En edit mode `ReplicatedStorage.SlingshotRemote` no existe.
- `Homestead.Main` parece crearlo al ejecutarse, asi que el riesgo depende del orden de arranque en Play.
- Falta probar en Play que `Homestead.Main` corre antes de que el cliente quede esperando indefinidamente.

## Puntos de extension de Storage

Actualizado: 2026-06-04 03:15 -05:00.

Hallazgos de solo lectura:

- `StorageService:GetStorageData(player)` es el punto actual que arma datos para UI.
- `StorageService:OpenStorage(player, house)` valida casa/owner, fuerza unequip, marca `HomesteadStorageOpen = true` y envia `StorageData`.
- `StorageService:SetupHouse(house)` encuentra `Stations.Storage` y conecta el `ProximityPrompt`.
- `InventoryService` ya expone `AddItem`, `RemoveItem`, `GetItemCount` y `GetInventory`.
- `HomesteadClient` crea filas de UI para `Egg`, `GoldenEgg`, `ChickenFeed` y `CuyFeed`.

Conclusion:

- No hay metodo actual para cargar municion desde Storage.
- Un futuro flujo de carga deberia usar `InventoryService` en servidor y no confiar en valores locales de UI.
- Cualquier extension debe respetar que Storage/UI es sistema sensible y que `HomesteadStorageOpen` bloquea Honda/BattleMode.

## Ajustes sugeridos al checklist

Sin modificar `CHECKLIST_TESTING.md`, estas diferencias deben considerarse antes de actualizarlo:

- Donde dice `EggAmmo`, el sistema actual verificable por lectura es `SlingshotEggAmmo`.
- Donde dice `EggStorage`, el sistema actual no tiene entidad separada.
- Las pruebas de municion deben comprobar `InventoryService.Egg` y el atributo `SlingshotEggAmmo`.
- Las pruebas de Storage deben distinguir entre inventario actual (`Egg`) y un futuro storage separado.
- Las pruebas de UI deben separar `HomesteadStorageGui` de una futura UI de municion.

## Riesgos multiplayer de inventario

Hallazgos de solo lectura:

- `InventoryService` guarda inventarios en `SessionInventories`.
- Cada inventario se indexa por `player.UserId`.
- `GetInventory()` devuelve copia, no la tabla interna.
- `AddItem()` y `RemoveItem()` validan `itemId` contra `DEFAULT_ITEMS`.
- `Homestead.Main` llama `inventoryService:ClearPlayer(player)` en `PlayerRemoving`.

Riesgos:

- El inventario es de sesion; no hay persistencia documentada.
- Falta prueba manual de dos jugadores para confirmar que el consumo de `Egg` no cruza usuarios.
- `GetSessionItemTotal()` suma todos los inventarios; no usarlo para municion individual.
- Un futuro `EggStorage` debe mantener aislamiento por `UserId` igual que `InventoryService`.

## Analisis de recoleccion de huevos

Actualizado: 2026-06-04 03:19 -05:00.

Hallazgos de solo lectura:

- `AnimalService.new(homeService, inventoryService)` crea `EggService.new(inventoryService)`, asi que la recoleccion de huevos ya queda conectada al inventario del servidor.
- `EggService:FindEggTemplate()` busca la plantilla principalmente en `ServerStorage.Assets.HomesteadAnimals.EggTemplate`.
- `EggService:GetEggFolder(homeData)` usa `homeData.RuntimeFolder.Animals.Eggs` como carpeta runtime para los huevos de una casa.
- `EggService:CanLayEgg(chicken)` limita huevos activos por gallina usando `HomeCfg.Animals.Chicken.MaxActiveEggsPerChicken`, actualmente con fallback de 4.
- `EggService:LayEgg(chicken, eggPoint, homeData)` clona el template, lo nombra como `Egg_<ownerId>_<chickenIndex>_<serial>`, lo mueve al `EggPoint` y marca atributos:
  - `OwnerId`
  - `OwnerName`
  - `ChickenIndex`
  - `Collected = false`
- Al poner un huevo, `EggService` incrementa `chicken.Model.ActiveEggs`.
- Si el huevo tiene `PrimaryPart`, se crea o reutiliza un `ProximityPrompt` y se conecta `prompt.Triggered`.
- En recoleccion, el servidor valida que `player.UserId == OwnerId`; jugadores que no son duenos no suman el huevo.
- Antes de sumar inventario, `EggService` revisa `eggModel:GetAttribute("Collected") == true`; si ya esta recogido, corta el flujo.
- Cuando la recoleccion procede, marca `Collected = true`, suma `InventoryService:AddItem(player, "Egg", 1)`, actualiza `player.SlingshotEggAmmo`, decrementa `ActiveEggs` y destruye `eggModel`.
- `AnimalService:GetCollectedEggCount(player)` expone `EggService:GetCollectedCount(player)` para `Homestead.Main`, y `Homestead.Main` lo incluye en `HomeInfo`.

Riesgos antes de conectar Storage o municion separada:

- Hoy recoger un huevo lo convierte directamente en `InventoryService.Egg` y tambien actualiza `SlingshotEggAmmo`; no pasa por `EggStorage`.
- Si luego se agrega `EggStorage`, hay que decidir si recoger huevo va directo a storage, directo a municion, o a inventario general.
- `Collected` y `Destroy()` reducen riesgo de doble recoleccion, pero falta prueba en Play de doble activacion rapida del `ProximityPrompt`.
- `ActiveEggs` baja despues de sumar inventario; si ocurre error entre esos pasos, podria quedar conteo desincronizado hasta el siguiente flujo de gallina.
- El conteo `CollectedByUser` es de sesion y no reemplaza inventario persistente ni storage.
- No tocar `EggTemplate`, `Gallina`, `Chicken`, `Storage/UI` ni `SlingshotService` sin un issue acotado o `[Protected Change]` cuando corresponda.

## Dependencias AnimalService / EggService

Actualizado: 2026-06-04 03:24 -05:00.

Hallazgos de solo lectura:

- `Homestead.Main` crea una unica instancia compartida de `InventoryService`.
- `Homestead.Main` pasa ese `inventoryService` a `AnimalService.new(homeService, inventoryService)`, `StorageService.new(...)` y `SlingshotService.new(...)`.
- `AnimalService.new(...)` guarda `self.InventoryService = inventoryService` y crea `self.EggService = EggService.new(inventoryService)`.
- `AnimalService:RefreshPlayer(player, homeData)` crea las gallinas runtime del jugador cuando existe `homeData` y no hay gallinas previas.
- Cada gallina se crea con `Chicken.new(model, player, homeData.House, spawn, index, self.EggService, homeData, self)`.
- `Chicken.new(...)` conserva la referencia recibida como `self.EggService` y `self.HomeData`.
- Cuando la gallina termina el flujo de puesta, llama `self.EggService:LayEgg(self, self.CurrentEggPoint, self.HomeData)`.
- `EggService:LayEgg(...)` usa el `InventoryService` inyectado solo al recoger el huevo, no al ponerlo.
- `AnimalService:GetCollectedEggCount(player)` consulta `self.EggService:GetCollectedCount(player)`.
- `Homestead.Main` incluye `CollectedEggs` e `Inventory` en la respuesta de `HomeInfo`.
- `Homestead.Main` ejecuta `animalService:Release(player)`, `inventoryService:ClearPlayer(player)` y `homeService:Release(player)` en `PlayerRemoving`.

Dependencias actuales:

- Fuente de inventario: `InventoryService`.
- Productor de huevos runtime: `Chicken` mediante `EggService`.
- Orquestador por jugador/casa: `AnimalService`.
- Exposicion a cliente de conteos: `Homestead.Main` via `HomeInfo`.
- Municion actual al recoger: `InventoryService.Egg` + atributo `SlingshotEggAmmo`.

Riesgos de `ActiveEggs` y `Collected` al resetear, salir o cambiar de casa:

- `AnimalService:Release(player)` destruye gallinas/cuyes y borra `PlayerAnimals[player.UserId]`.
- `HomeService:Release(player)` destruye `Workspace.HomeRuntime.Home_<UserId>` si existe; ahi tambien viven los huevos runtime bajo `Animals.Eggs`.
- Si un jugador sale entre poner huevo y recogerlo, falta confirmar en Play que no queda un huevo runtime huerfano ni `ActiveEggs` desincronizado.
- Si el jugador cambia de casa, `AnimalService:RefreshPlayer(...)` llama `Release(player)` cuando detecta otra casa, pero falta probar que la carpeta vieja de huevos desaparece en el orden esperado.
- `CollectedByUser` vive dentro de `EggService` y no se limpia por jugador en el fragmento inspeccionado; queda como contador de sesion del servicio, no como inventario canonico.
- `InventoryService:ClearPlayer(player)` limpia inventario al salir, asi que cualquier futuro `EggStorage` persistente no debe depender solo de `InventoryService.Egg`.
- La validacion de doble recoleccion depende de `Collected` en el modelo del huevo; si la carpeta runtime se destruye durante un trigger, falta prueba manual de que no aparecen errores rojos.

## Conteos de huevos expuestos

Actualizado: 2026-06-04 03:25 -05:00.

Hallazgos de solo lectura:

- `HomeService:GetHomeInfo(player)` calcula `EggCount` contando hijos de `homeData.RuntimeFolder.Animals.Eggs`.
- `EggCount` representa huevos activos en mundo/runtime, no huevos en inventario ni municion.
- `Homestead.Main` agrega `CollectedEggs = animalService:GetCollectedEggCount(player)` al `HomeInfo`.
- `CollectedEggs` representa huevos recogidos durante la sesion del `EggService`, no necesariamente huevos disponibles.
- `Homestead.Main` agrega `Inventory = inventoryService:GetInventory(player)` al `HomeInfo`.
- `Inventory.Egg` es el conteo de item `Egg` del inventario de sesion; hoy es la fuente real que usa `SlingshotService:GetAmmo()`.
- `HomesteadClient` imprime `EggCount`, `CollectedEggs` e `Inventory.Egg` en consola al recibir `HomeInfo`.
- `HomesteadClient` muestra Storage desde `data.Inventory`, por lo que la fila `Egg` de Storage refleja `Inventory.Egg`.
- `SlingshotService:SyncAmmo()` setea `SlingshotEggAmmo` desde `GetAmmo(player)`, que lee `InventoryService:GetItemCount(player, "Egg")`.
- `SlingshotService:Fire()` descuenta `InventoryService.RemoveItem(player, "Egg", 1)` y despues actualiza `SlingshotEggAmmo` y `AmmoChanged`.
- `SlingshotEggAmmo` es un espejo/senal de municion para combate, no un storage separado.

Interpretacion segura:

- `EggCount`: huevos fisicos activos sin recoger.
- `CollectedEggs`: historial de recoleccion de sesion.
- `Inventory.Egg`: huevos disponibles en inventario actual y fuente de municion.
- `SlingshotEggAmmo`: espejo del conteo de municion basado en `Inventory.Egg`.

Riesgos de UI antes de crear `EggStorage`:

- Mostrar `CollectedEggs` como municion seria incorrecto porque no baja al disparar.
- Mostrar `EggCount` como municion seria incorrecto porque cuenta huevos aun no recogidos.
- Mostrar `Inventory.Egg` como storage definitivo puede confundir si luego se separan `EggStorage` y `EggAmmo`.
- `SlingshotEggAmmo` depende de sincronizacion por atributo/remotes; falta probar en Play que siempre coincide con `Inventory.Egg`.
- Una UI futura debe etiquetar cada conteo con su significado o elegir un unico valor canonico por pantalla.

## Brecha actual del checklist de huevos

Actualizado: 2026-06-04 03:26 -05:00.

Hallazgos de solo lectura sobre `CHECKLIST_TESTING.md`:

- El checklist cubre recoleccion, municion, Storage, CarryChicken, Death/Reset, UI y multiplayer.
- En recoleccion, usa la frase `EggAmmo o EggStorage sube correctamente`; el sistema real aun no tiene `EggStorage` y la municion actual se refleja como `SlingshotEggAmmo`.
- En municion, el checklist usa `EggAmmo`, pero el sistema real comprobable por lectura usa `Inventory.Egg` como fuente y `SlingshotEggAmmo` como espejo.
- En Storage, el checklist espera `EggStorage` separado de `EggAmmo`; esa separacion todavia no existe.
- En UI, el checklist pide que la UI muestre `EggAmmo`, pero el cliente actual conocido muestra Storage desde `Inventory.Egg` y no una UI confirmada de ammo separada.
- El checklist no distingue explicitamente:
  - `EggCount`: huevos activos en mundo.
  - `CollectedEggs`: contador de recoleccion de sesion.
  - `Inventory.Egg`: inventario de sesion y fuente real de municion actual.
  - `SlingshotEggAmmo`: atributo/remoto espejo de municion.

Propuesta para actualizar el checklist mas adelante:

- En recoleccion, probar que recoger huevo propio suma `Inventory.Egg` y actualiza `SlingshotEggAmmo`.
- En recoleccion, probar que `EggCount` baja o que el modelo desaparece al recoger.
- En recoleccion, probar que `CollectedEggs` sube como contador de sesion, sin usarlo como municion.
- En municion, probar que `Inventory.Egg` baja en 1 al disparar y que `SlingshotEggAmmo` queda alineado.
- En Storage, marcar como pendiente la separacion real `EggStorage` vs municion hasta que exista diseno aprobado.
- En UI, separar pruebas de Storage UI (`Inventory.Egg`) y futura UI de municion (`SlingshotEggAmmo` o `EggAmmo` canonico).

Riesgos de prueba manual si se confunden conteos:

- Validar `CollectedEggs` como ammo daria un falso positivo porque no baja al disparar.
- Validar `EggCount` como ammo daria un falso positivo/negativo porque son huevos sin recoger.
- Validar solo `SlingshotEggAmmo` puede ocultar una desincronizacion con `Inventory.Egg`.
- Validar solo `Inventory.Egg` puede ocultar que el cliente no recibio `AmmoChanged`.
- Probar `EggStorage` antes de implementarlo mezclaria expectativa futura con comportamiento actual.

## Analisis de Homestead.Monitor

Actualizado: 2026-06-04 03:29 -05:00.

Hallazgos de solo lectura:

- `ServerScriptService.Homestead.Monitor` es un script de diagnostico activado por chat con `/hs` o `/homestead stats`.
- `collectStats()` arma un resumen global, no por jugador.
- El monitor busca `Workspace.HomeRuntime` usando `HomeCfg.Names.HomeRuntime` con fallback `"HomeRuntime"`.
- `ActiveHomes` cuenta carpetas dentro de `Workspace.HomeRuntime`.
- `ChickenCount`, `CuyCount` y `EggCount` se suman recorriendo todas las carpetas runtime de casas.
- `EggCount` del monitor representa huevos activos totales en mundo/runtime, no huevos disponibles para un jugador especifico.
- `InventoryEggsTotal` usa `InventoryService.GetSessionItemTotal("Egg")`.
- `InventoryService.GetSessionItemTotal(itemId)` recorre `SessionInventories` y suma el item para todos los inventarios de sesion.
- El monitor imprime `Inventory Eggs total` como total global de sesion, no como municion individual.
- En edit mode `Workspace.HomeRuntime` existe pero no tenia hijos durante esta inspeccion, asi que los conteos runtime requieren Play para observar datos reales.

Interpretacion segura:

- `Homestead.Monitor` sirve para diagnostico global de Homestead.
- `InventoryEggsTotal` puede ayudar a detectar si hay huevos de inventario acumulados en la sesion, pero no debe alimentar reglas de disparo.
- La fuente canonica actual de municion por jugador sigue siendo `InventoryService:GetItemCount(player, "Egg")` leida por `SlingshotService:GetAmmo(player)`.

Riesgos si se usa el monitor para gameplay:

- `GetSessionItemTotal("Egg")` mezcla jugadores; usarlo para disparo permitiria que un jugador dependa de huevos de otro.
- `EggCount` mezcla huevos activos de todas las casas; usarlo como ammo confundiria huevos sin recoger con municion.
- Los conteos globales pueden verse correctos mientras un jugador individual esta desincronizado.
- El monitor requiere runtime poblado; en edit mode puede mostrar cero aunque el flujo funcione al entrar en Play.
- Si se implementa `EggStorage`, el monitor deberia etiquetar claramente si muestra inventario total, storage total, ammo total o huevos activos.

## Observabilidad de municion actual

Actualizado: 2026-06-04 03:30 -05:00.

Hallazgos de solo lectura:

- No se encontro una UI prearmada en `StarterGui` para mostrar `SlingshotEggAmmo`.
- `StarterGui` solo contiene `Cfgf` durante la inspeccion.
- `HomesteadClient` crea `HomesteadStorageGui` en runtime y muestra filas de inventario, incluida `Egg`, desde `Inventory`.
- Esa fila `Egg` de Storage muestra `Inventory.Egg`, no una municion visual separada.
- `SlingshotController` recibe `FireResult` con campo `Ammo` y llama `setAmmoAttribute(result.Ammo)`.
- `SlingshotController` recibe `AmmoChanged`; si `itemId == "Egg"`, actualiza `SlingshotEggAmmo`.
- `SlingshotController` no parece crear una etiqueta visual de ammo segun las busquedas de `TextLabel`, `AmmoChanged` y `SlingshotEggAmmo`.
- `SlingshotService` actualiza `SlingshotEggAmmo` en servidor al sincronizar, fallar por ammo, disparar y limpiar jugador.
- `EggService` tambien actualiza `SlingshotEggAmmo` al recoger un huevo.
- `HomeCfg` define el ammo item como `Egg`.

Donde observar sin crear UI nueva:

- Atributo del jugador `SlingshotEggAmmo` en Player durante Play.
- `Inventory.Egg` en Storage UI, sabiendo que es inventario actual y no UI de municion dedicada.
- Eventos `SlingshotRemote.AmmoChanged` y `FireResult` en Play si se inspecciona Output/cliente.
- Logs de servidor de `SlingshotService` cuando debug de Slingshot esta activo.
- `Homestead.Monitor` solo como diagnostico global, no como valor individual de ammo.

Riesgos de validar solo por atributo:

- Un atributo correcto no prueba que exista una UI clara para el jugador.
- Una UI de Storage correcta no prueba que `AmmoChanged` llegue al cliente de combate.
- Un `SlingshotEggAmmo` correcto en cliente podria desincronizarse si `Inventory.Egg` cambia sin `AmmoChanged`.
- Ver solo prints de servidor no prueba que el cliente vea el conteo.
- Crear una UI nueva de ammo sin definir `EggAmmo` vs `SlingshotEggAmmo` podria fijar un nombre que luego haya que migrar.

## Remotes en Explorer vs runtime

Actualizado: 2026-06-04 03:31 -05:00.

Hallazgos de solo lectura:

- En edit mode, `ReplicatedStorage` tiene dos folders directos: `PastureRemote` y `HomesteadRemote`.
- `PastureRemote` contiene `Whistle`, `RequestStats` y `StatsResponse`.
- `HomesteadRemote` contiene `RequestHomeInfo`, `HomeInfo`, `DropChicken`, `RequestStorage`, `StorageData` y `CloseStorage`.
- En edit mode no existe `ReplicatedStorage.SlingshotRemote`.
- `Homestead.Main` define `ensureFolder(parent, name)` y `ensureRemote(parent, name)`.
- `Homestead.Main` usa `ensureFolder(ReplicatedStorage, "SlingshotRemote")`.
- `Homestead.Main` crea o reutiliza `FireRequest`, `FireResult` y `AmmoChanged` dentro de `SlingshotRemote`.
- `SlingshotController` espera `ReplicatedStorage.SlingshotRemote`, `FireRequest`, `FireResult` y `AmmoChanged` con `WaitForChild`.
- Por lo tanto, `SlingshotRemote` parece ser un remoto runtime creado por `Homestead.Main`, no una instancia persistente visible en edit mode.

Riesgos de crear remotes manualmente antes de Play:

- Se puede crear una estructura duplicada o con clase incorrecta si `Homestead.Main` tambien intenta asegurarla.
- Si se crea un objeto con nombre correcto pero clase incorrecta, `ensureFolder`/`ensureRemote` puede hacer `error(...)`.
- Crear `SlingshotRemote` en edit mode podria ocultar un problema real de orden de arranque entre servidor y cliente.
- Si se agregan remotes hijos con nombres distintos, `SlingshotController` seguira esperando los nombres actuales.
- La prueba correcta pendiente es Play: confirmar que `Homestead.Main` crea remotes antes de que el cliente quede esperando.

## Configuracion actual de Slingshot

Actualizado: 2026-06-04 03:34 -05:00.

Hallazgos de solo lectura:

- `HomeCfg.Slingshot.AmmoItem = "Egg"`.
- `HomeCfg.Slingshot.Cooldown = 0.45`.
- `HomeCfg.Slingshot.MaxRange = 180`.
- `HomeCfg.Slingshot.MaxChargeTime = 0.8`.
- `HomeCfg.Slingshot.MinChargeToFire = 0.05`.
- `HomeCfg.Debug.Slingshot = true`.
- `SlingshotService:GetAmmo(player)` lee `cfg.AmmoItem` y usa `InventoryService:GetItemCount(player, itemId)`.
- `SlingshotService:CanFire(player)` bloquea si no hay player, si `CarryingChicken`, si `HomesteadStorageOpen`, si personaje invalido, si no hay `Honda`/`Slingshot` equipado, si cooldown esta activo o si ammo <= 0.
- `SlingshotService:Fire(...)` vuelve a leer `AmmoItem`, `Cooldown`, `MaxRange` y `MinChargeToFire`.
- El servidor clamp de `charge` a `0..1` y rechaza si `charge < MinChargeToFire` con `Reason = "LowCharge"`.
- Si dispara correctamente, el servidor descuenta 1 `InventoryService.Egg`, actualiza `SlingshotEggAmmo`, envia `AmmoChanged` y calcula `Range = MaxRange * clamp(0.55 + charge * 0.45, 0.55, 1)`.
- Con `MaxRange = 180`, el rango efectivo va de aproximadamente `99` studs con carga minima visual del servidor a `180` studs con `charge = 1`.
- `SlingshotController` tambien tiene constantes locales `MaxChargeTime = 0.8` y `MinChargeToFire = 0.05`, y envia `charge` al servidor; la autoridad final sigue estando en servidor.

Parametros que afectan pruebas manuales:

- Para probar consumo de municion, esperar al menos `0.45` segundos entre disparos o se puede recibir `Cooldown`.
- Un click/carga demasiado corto puede producir `LowCharge` y no consumir huevo.
- La herramienta equipada debe llamarse `Honda` o `Slingshot`.
- La prueba de rango debe distinguir carga baja, carga media y carga completa.
- La prueba de municion debe verificar `Inventory.Egg`, `SlingshotEggAmmo`, `AmmoChanged` y `FireResult.Ammo`.

Riesgos de probar sin conocer estos parametros:

- Confundir `Cooldown` con fallo de ammo.
- Confundir `LowCharge` con bloqueo de servidor.
- Probar sin Honda equipada y recibir `NoHondaEquipped`.
- Medir rango sin controlar `charge` y obtener resultados variables.
- Asumir que `MaxChargeTime` del cliente es autoridad; el servidor solo recibe y valida `charge`.
- Como `HomeCfg.Debug.Slingshot = true`, Output puede tener logs utiles, pero los logs no reemplazan validacion de atributos/remotes.

## Matriz de FireResult

Actualizado: 2026-06-04 03:35 -05:00.

Hallazgos de solo lectura:

- `SlingshotService:CanFire(player)` devuelve razones antes de validar direccion/carga:
  - `NoPlayer`
  - `CarryingChicken`
  - `StorageOpen`
  - `CharacterInvalid`
  - `NoHondaEquipped`
  - `Cooldown`
  - `NoAmmo`
  - `Ok`
- `SlingshotService:Fire(...)` envia `FireResult` con `Ok = false`, `Reason = reason` y `Ammo = ammo` cuando `CanFire` falla.
- Despues de `CanFire`, el servidor puede devolver:
  - `InvalidDirection` si `direction` no es `Vector3` valido o tiene magnitud casi cero.
  - `LowCharge` si `charge < MinChargeToFire`.
  - `NoAmmo` si `InventoryService:RemoveItem(player, "Egg", 1)` falla aunque `CanFire` haya pasado.
- En exito, `FireResult` incluye `Ok = true`, `Ammo = newAmmo`, `Origin`, `HitPosition`, `HitNormal`, `HitInstance`, `Charge` y `Range`.

Matriz esperada para QA manual:

- Sin player valido: `NoPlayer`, no aplica a prueba normal de usuario.
- Cargando gallina: `CarryingChicken`, no debe consumir huevo.
- Storage abierto: `StorageOpen`, no debe consumir huevo.
- Personaje muerto/invalido/sin root: `CharacterInvalid`, no debe consumir huevo.
- Sin `Honda` o `Slingshot` equipado: `NoHondaEquipped`, no debe consumir huevo.
- Disparo repetido antes de `0.45s`: `Cooldown`, no debe consumir huevo.
- Inventario `Egg <= 0`: `NoAmmo`, no debe disparar ni bajar contador.
- Direccion invalida: `InvalidDirection`, no debe consumir huevo.
- Carga menor a `0.05`: `LowCharge`, no debe consumir huevo.
- Exito: `Ok = true`, debe bajar `Inventory.Egg` en 1 y actualizar `SlingshotEggAmmo`.

Riesgos de interpretar mal `FireResult.Reason`:

- `NoAmmo` puede venir de `CanFire` o de `RemoveItem`; ambos apuntan a inventario insuficiente, pero el segundo detecta una carrera/desincronizacion.
- `Cooldown` puede parecer que el arma no dispara si se prueba demasiado rapido.
- `LowCharge` puede parecer fallo de input si el click es muy corto.
- `NoHondaEquipped` puede confundirse con bug de ammo si la herramienta no esta equipada o se desequipa por Storage/Carry.
- `CharacterInvalid` puede aparecer en muerte/reset y no debe tratarse como problema de SlingshotRemote.
- Si el cliente no muestra `Reason`, la prueba debe revisar Output/atributos/remotes para no adivinar.

## Observabilidad cliente de FireResult

Actualizado: 2026-06-04 03:36 -05:00.

Hallazgos de solo lectura:

- `SlingshotController` escucha `fireResultEvent.OnClientEvent`.
- Si `result` no es tabla, el cliente ignora el evento.
- Si `result.Ammo ~= nil`, el cliente llama `setAmmoAttribute(result.Ammo)`.
- `setAmmoAttribute(count)` normaliza el numero y setea `player:SetAttribute("SlingshotEggAmmo", count)`.
- Si `result.Ok == true`, el cliente llama `playProjectileVisual(result)`.
- No se encontro lectura directa de `result.Reason` en `SlingshotController`.
- No se encontro `warn`/`print` de `FireResult.Reason` en el cliente.
- `ammoChangedEvent.OnClientEvent` tambien actualiza `SlingshotEggAmmo` si `itemId == "Egg"`.
- En fallos de servidor con `Ok = false`, el cliente actualiza ammo si viene `Ammo`, pero no parece mostrar ni registrar la razon de fallo.

Que puede observar el tester desde cliente sin UI nueva:

- Cambio del atributo `SlingshotEggAmmo`.
- Aparicion o ausencia de visual local `SlingshotEggProjectile`/impacto.
- Ausencia de proyectil cuando `Ok ~= true`.
- Estado de `Inventory.Egg` si abre Storage UI.
- No hay señal visual confirmada para `Reason` especifico del fallo.

Riesgos si el cliente oculta razones de fallo:

- El tester puede ver que no sale proyectil, pero no saber si fue `Cooldown`, `LowCharge`, `NoAmmo`, `StorageOpen` u otro bloqueo.
- Un fallo correcto de servidor puede parecer bug de input.
- Si `Ammo` se actualiza aunque `Ok = false`, el contador puede cambiar/confirmarse sin explicar el motivo.
- Para QA manual, conviene observar `FireResult.Reason` desde Output/herramientas de depuracion o agregar una tarea futura de UI/logging si se autoriza.

## Logs/debug existentes de Slingshot

Actualizado: 2026-06-04 03:38 -05:00.

Hallazgos de solo lectura:

- `HomeCfg.Debug.Slingshot = true`.
- En servidor, `SlingshotService` imprime `[Slingshot] NoAmmo` cuando `CanFire` falla por `NoAmmo`.
- En servidor, `SlingshotService` imprime `[Slingshot] NoAmmo` si `InventoryService:RemoveItem(...)` falla despues de pasar `CanFire`.
- En servidor, `SlingshotService` imprime `[Slingshot] <player> fired Egg. Ammo=<newAmmo> charge=<charge>` en disparo exitoso.
- No se encontraron prints especificos para `Cooldown`, `LowCharge`, `StorageOpen`, `CarryingChicken`, `CharacterInvalid`, `NoHondaEquipped` o `InvalidDirection`.
- En cliente, `SlingshotController` tiene `DEBUG_TOOL_TEST = false`.
- Los logs de `SlingshotDebug` del cliente existen, pero estan orientados a diagnostico de herramienta, animaciones y RightGrip; no a `FireResult.Reason`.
- El mensaje de cliente `[SlingshotController] Ready...` solo aparece si `DEBUG_TOOL_TEST` esta activo.

Logs actuales utiles para QA:

- Exito de disparo en servidor: confirma jugador, nuevo ammo y charge.
- `NoAmmo` en servidor: confirma inventario insuficiente o falla de `RemoveItem`.
- `SlingshotDebug` de cliente: util para herramienta/animacion si se activa debug, no para razon de rechazo de disparo.

Logs que faltan para QA completa:

- No hay log visible por cada `FireResult.Reason`.
- No hay log local confirmado cuando el cliente recibe `Ok = false`.
- No hay UI visible de razon de fallo.

Riesgos de depender de `HomeCfg.Debug.Slingshot`:

- Debug actual cubre exito y `NoAmmo`, pero no todos los rechazos.
- Si QA solo mira Output, puede pasar por alto `Cooldown` o `LowCharge`.
- Activar logs de cliente requeriria tocar `DEBUG_TOOL_TEST`, lo cual no corresponde sin issue especifico.
- Los logs no sustituyen validacion de `Inventory.Egg`, `SlingshotEggAmmo`, `AmmoChanged` y `FireResult`.

## Falta confirmar antes del disparo con huevos

- Probar en Play si `ReplicatedStorage.SlingshotRemote` se crea correctamente y no queda bloqueado por `WaitForChild` en cliente.
- Confirmar si el juego quiere conservar `SlingshotEggAmmo` o crear `EggAmmo` como atributo canonico.
- Confirmar diseno: `EggStorage` separado de `EggAmmo`, o inventario `Egg` actual como municion activa.
- Confirmar comportamiento esperado al recoger huevo: directo a municion, directo a storage, o ambos con accion de carga.
- Probar en Play que recoger un huevo propio suma exactamente 1 `InventoryService.Egg`, actualiza `SlingshotEggAmmo`, baja `ActiveEggs` y destruye el modelo.
- Probar en Play que otro jugador no puede recoger huevos ajenos.
- Probar en Play salida/reset/cambio de casa con huevos runtime presentes, para confirmar que no quedan huevos huerfanos ni contadores `ActiveEggs` incorrectos.
- Probar en Play que `Inventory.Egg` y `SlingshotEggAmmo` se mantienen alineados despues de recoger, abrir Storage y disparar.
- Actualizar `CHECKLIST_TESTING.md` solo cuando se apruebe si el checklist debe describir estado actual (`SlingshotEggAmmo`) o diseno futuro (`EggAmmo`/`EggStorage`).
- Probar `/hs` en Play solo como diagnostico global; no usar `Inventory Eggs total` para validar municion individual.
- Confirmar en Play si el jugador necesita una UI visible de municion o si basta con Storage/atributo para pruebas internas.
- Confirmar en Play que `SlingshotRemote.FireRequest`, `FireResult` y `AmmoChanged` aparecen una sola vez y con clase `RemoteEvent`.
- Al probar disparo en Play, controlar `Cooldown = 0.45`, `MinChargeToFire = 0.05`, `MaxChargeTime = 0.8`, `MaxRange = 180` y herramienta equipada `Honda`/`Slingshot`.
- Registrar `FireResult.Reason` en Play para distinguir `NoAmmo`, `Cooldown`, `LowCharge`, `NoHondaEquipped`, `StorageOpen`, `CarryingChicken` y `CharacterInvalid`.
- Confirmar si se necesita una tarea futura para exponer `FireResult.Reason` al tester en UI/log local.
- No depender solo de `HomeCfg.Debug.Slingshot`; actualmente no registra todas las razones de rechazo.
- Confirmar si `HomesteadStorageOpen` cubre todas las UI criticas o solo Storage.
- Confirmar pruebas manuales en Roblox Studio para muerte/reset, carry chicken, storage abierto, disparo sin municion y disparo con municion.

## Riesgos detectados

- Ya existe municion funcional bajo `SlingshotEggAmmo`; crear `EggAmmo` sin migracion clara puede duplicar estado.
- `EggStorage` no existe; mezclarlo con `InventoryService.Egg` podria romper storage o municion.
- `SlingshotRemote` esta definido por script pero no existe en edit mode; crear otro remoto manualmente podria duplicar o cambiar el flujo.
- Storage/UI y Honda BattleMode son sensibles y ya estan conectados al bloqueo de disparo.
- `EggService` destruye huevos al recoger y actualiza municion; cambiarlo sin prueba puede duplicar o perder huevos.
- Las plantillas `Gallina` y `EggTemplate` existen en `ServerStorage` y son protegidas.

## Snapshot exportado para revision

Actualizado: 2026-06-16 21:17 -05:00.

Snapshot local:

- `snapshots/CodexAvanceTest_Current/`

Origen:

- Place: `CodexAvanceTest`.
- DataModel: `Place1`.
- Modo Studio: Edit.
- Exportacion por MCP de Roblox Studio, solo lectura.

Sistemas exportados:

- `ServerScriptService.Homestead.Main`
- `ServerScriptService.Homestead.Monitor`
- `ServerScriptService.Homestead.M.HomeCfg`
- `ServerScriptService.Homestead.M.HomeService`
- `ServerScriptService.Homestead.M.AnimalService`
- `ServerScriptService.Homestead.M.Chicken`
- `ServerScriptService.Homestead.M.Cuy`
- `ServerScriptService.Homestead.M.EggService`
- `ServerScriptService.Homestead.M.InventoryService`
- `ServerScriptService.Homestead.M.StorageService`
- `ServerScriptService.Homestead.M.StationService`
- `ServerScriptService.Homestead.M.SlingshotService`
- `ServerScriptService.Homestead.M.DragonRaidService`
- `StarterPlayer.StarterPlayerScripts.HomesteadClient`
- `StarterPlayer.StarterPlayerScripts.ChickenCarryAnimClient`
- `StarterPlayer.StarterPlayerScripts.SlingshotController`
- `StarterPlayer.StarterPlayerScripts.SlingshotAnimateGuard`
- `StarterPlayer.StarterPlayerScripts.PasturePromptClient`
- `ServerScriptService.DragonRaidAutoTest`

Confirmaciones de estructura:

- `SlingshotService` existe en `ServerScriptService.Homestead.M.SlingshotService`.
- `SlingshotController` existe y fue exportado desde `StarterPlayer.StarterPlayerScripts.SlingshotController`.
- `SlingshotAnimateGuard` existe y fue exportado desde `StarterPlayer.StarterPlayerScripts.SlingshotAnimateGuard`.
- `DragonRaidService` existe en `ServerScriptService.Homestead.M.DragonRaidService`.
- `DragonRaidAutoTest` existe en `ServerScriptService.DragonRaidAutoTest`.
- El manifiesto completo esta en `snapshots/CodexAvanceTest_Current/MANIFEST.md`.

Estado relevante para huevos como municion:

- El sistema actual ya contiene Fire v0 con `Egg` como municion.
- La fuente actual de municion documentada sigue siendo `InventoryService.Egg` con espejo/atributo `SlingshotEggAmmo`.
- No se creo `EggAmmo`, `EggStorage`, `src` ni Rojo.
- No se modifico gameplay ni scripts dentro de Studio.

## Actualizacion 2026-06-16
Se agrego Pasture.M.GrazingService para el sistema de pastoreo v0, usando atributos de Player.
