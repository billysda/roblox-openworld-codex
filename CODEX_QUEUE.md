# CODEX_QUEUE.md

Cola local de trabajo continuo para Codex App + MCP en el place Roblox Studio `CodexAvanceTest`.

## Reglas de uso

- Trabajar una tarea a la vez.
- Antes de implementar, leer `AGENTS.md`, `CODEX_RULES.md`, `STATUS.md` y `ROBLOX_STRUCTURE.md`.
- No modificar Roblox Studio salvo que la tarea lo pida explicitamente.
- No tocar sistemas protegidos sin issue o tarea con autorizacion `[Protected Change]`.
- Mantener `STATUS.md` actualizado despues de cambios importantes.

## Cola

1. [codex-review][analysis] Confirmar en Play si `SlingshotRemote` existe y donde se crea.
   - Estado: requiere Play, asi que queda pendiente de revision/prueba manual.
   - Evidencia en edit mode: `ReplicatedStorage.SlingshotRemote` no existe.
   - Evidencia en codigo: `ServerScriptService.Homestead.Main` crea `SlingshotRemote`, `FireRequest`, `FireResult` y `AmmoChanged` al ejecutarse.
2. [done][analysis] Analizar el flujo actual de `SlingshotEggAmmo` e `InventoryService.Egg` sin modificar codigo.
   - `InventoryService` guarda `Egg` como item de sesion por jugador.
   - `EggService` suma `Egg` al recoger huevo y sincroniza `SlingshotEggAmmo`.
   - `SlingshotService:GetAmmo()` lee `InventoryService:GetItemCount(player, "Egg")`.
   - `SlingshotService:Fire()` descuenta `InventoryService:RemoveItem(player, "Egg", 1)` y actualiza `SlingshotEggAmmo`.
   - `SlingshotController` escucha remotes de `SlingshotRemote` y mantiene el atributo local `SlingshotEggAmmo` cuando recibe cambios.
3. [done][design] Proponer si conviene mantener `SlingshotEggAmmo` o crear `EggAmmo` separado.
   - Recomendacion: mantener `SlingshotEggAmmo` por ahora como nombre operativo del sistema existente.
   - No crear `EggAmmo` separado hasta definir formalmente `EggStorage` vs municion activa.
   - Si se decide renombrar a `EggAmmo`, hacerlo como migracion pequena y explicita, no como sistema paralelo.
4. [blocked][implementation] Implementar consumo de huevo al disparar, bloqueado hasta confirmar tareas 1-3.
   - Nota: el consumo ya parece existir via `InventoryService.Egg`; falta prueba en Play antes de implementar.
5. [blocked][implementation] Conectar Storage con municion, bloqueado hasta confirmar diseno de `EggStorage` vs `SlingshotEggAmmo`.

## Nuevas tareas seguras

6. [done][analysis] Revisar en modo lectura si hay referencias a `EggStorage` o `EggAmmo` en todos los scripts.
   - No se encontraron referencias a `EggStorage`.
   - No se encontraron referencias exactas a `"EggAmmo"`.
   - La busqueda amplia de `EggAmmo` solo encontro coincidencias dentro de `SlingshotEggAmmo`.
7. [done][documentation] Actualizar `ROBLOX_STRUCTURE.md` con el resultado consolidado del analisis de municion.
   - Se agrego la seccion `Analisis consolidado de municion`.
8. [done][risk-review] Crear una lista de riesgos para una futura migracion de `SlingshotEggAmmo` a `EggAmmo`.
   - Riesgos documentados en `ROBLOX_STRUCTURE.md`.

## Siguientes tareas seguras

9. [done][analysis] Revisar en modo lectura donde `HomesteadStorageOpen` bloquea disparo o BattleMode.
   - Cliente: `SlingshotController:canActivate()` bloquea Honda/BattleMode si Storage esta abierto.
   - Cliente: `SlingshotController` escucha `HomesteadStorageOpen` y limpia modo si cambia a `true`.
   - Cliente: `canRequestFire()` bloquea requests de disparo si Storage esta abierto.
   - Servidor: `SlingshotService:CanFire()` bloquea con razon `StorageOpen`.
   - Servidor: `StorageService:OpenStorage()` marca `HomesteadStorageOpen = true`.
   - Servidor: `Homestead.Main` limpia `HomesteadStorageOpen = false` en `CloseStorage` y `CharacterRemoving`.
10. [done][documentation] Comparar `CHECKLIST_TESTING.md` contra el estado real de `SlingshotEggAmmo`.
   - El checklist menciona `EggAmmo`/`EggStorage`, pero el estado real usa `InventoryService.Egg` + `SlingshotEggAmmo`.
   - La separacion Storage vs municion no existe todavia.
   - La mayoria de validaciones requieren Play/manual.
11. [done][risk-review] Revisar riesgos de `WaitForChild` infinito en `SlingshotController` sin entrar en Play.
   - `SlingshotController` espera `SlingshotRemote`, `FireRequest`, `FireResult` y `AmmoChanged` sin timeout.
   - En edit mode `ReplicatedStorage.SlingshotRemote` no existe.
   - `Homestead.Main` parece crearlo al ejecutar; falta prueba en Play para orden de arranque.

## Nuevas tareas seguras 2

12. [done][analysis] Revisar en modo lectura si `StorageService` tiene puntos de extension para una carga futura de municion.
   - Puntos actuales: `GetStorageData`, `OpenStorage`, `SetupHouse`, `StorageData`.
   - No existe metodo de carga de municion desde Storage.
   - Cualquier extension debe usar `InventoryService` en servidor y respetar `HomesteadStorageOpen`.
13. [done][documentation] Proponer ajustes al checklist para reflejar `SlingshotEggAmmo` como estado actual sin cambiar codigo.
   - Documentado en `ROBLOX_STRUCTURE.md`.
   - El checklist actual habla de `EggAmmo`/`EggStorage`; el sistema real usa `InventoryService.Egg` + `SlingshotEggAmmo`.
14. [done][risk-review] Revisar riesgos de multiplayer alrededor de `SessionInventories` e inventario por `UserId`.
   - `InventoryService` indexa por `player.UserId`.
   - `GetInventory()` devuelve copia.
   - `PlayerRemoving` limpia inventario de sesion.
   - Falta prueba manual de varios jugadores.

## Nuevas tareas seguras 3

15. [done][analysis] Revisar en modo lectura como `EggService` marca huevos recolectados y evita duplicacion.
   - `EggService` marca cada huevo con `Collected = false` al crearlo.
   - Al activar el `ProximityPrompt`, valida `OwnerId` contra `player.UserId`.
   - Antes de sumar inventario, corta si `Collected == true`.
   - Si procede, marca `Collected = true`, suma inventario, baja `ActiveEggs` y destruye el modelo.
16. [done][documentation] Documentar el flujo actual de recoleccion de huevo hasta `InventoryService.Egg`.
   - Documentado en `ROBLOX_STRUCTURE.md`.
   - Flujo actual: gallina pone huevo runtime, jugador dueno lo recoge, servidor suma `InventoryService.Egg`, actualiza `SlingshotEggAmmo` y destruye el huevo.
17. [done][risk-review] Revisar riesgos de recoleccion de huevo antes de conectar Storage o municion separada.
   - Recoger huevo hoy va directo a `InventoryService.Egg` y `SlingshotEggAmmo`.
   - No existe paso por `EggStorage`.
   - Falta prueba en Play de doble activacion rapida del prompt, dueño/no dueño, `ActiveEggs` y sincronizacion de municion.

## Nuevas tareas seguras 4

18. [done][analysis] Revisar en modo lectura como `AnimalService` conecta `EggService` con gallinas sin tocar `Chicken`.
   - `Homestead.Main` crea `InventoryService` y lo comparte con `AnimalService`.
   - `AnimalService.new(...)` crea `self.EggService = EggService.new(inventoryService)`.
   - `AnimalService:RefreshPlayer(...)` inyecta `self.EggService` en cada `Chicken.new(...)`.
   - La gallina conserva esa referencia y la usa para `LayEgg(...)` cuando termina el flujo de puesta.
19. [done][documentation] Resumir dependencias entre `EggService`, `AnimalService`, `InventoryService` y `Homestead.Main`.
   - Documentado en `ROBLOX_STRUCTURE.md`.
   - Dependencia principal: `Homestead.Main` comparte `InventoryService`; `AnimalService` crea `EggService`; `EggService` suma `InventoryService.Egg` al recoger.
20. [done][risk-review] Revisar riesgos de `ActiveEggs` y `Collected` al resetear, salir o cambiar de casa.
   - `AnimalService:Release(player)` destruye animales runtime y limpia `PlayerAnimals`.
   - `HomeService:Release(player)` destruye `Workspace.HomeRuntime.Home_<UserId>`.
   - Falta probar en Play salida/reset/cambio de casa con huevos runtime presentes.
   - `CollectedByUser` es contador de sesion del servicio, no storage canonico.

## Nuevas tareas seguras 5

21. [done][analysis] Revisar en modo lectura como `HomeInfo` expone `CollectedEggs`, `Inventory` y `EggCount`.
   - `HomeService:GetHomeInfo()` calcula `EggCount` desde huevos activos en runtime.
   - `Homestead.Main` agrega `CollectedEggs` desde `AnimalService`.
   - `Homestead.Main` agrega `Inventory` desde `InventoryService`.
22. [done][documentation] Documentar diferencias entre conteos de UI: `CollectedEggs`, `Inventory.Egg`, `EggCount` y `SlingshotEggAmmo`.
   - Documentado en `ROBLOX_STRUCTURE.md`.
   - `EggCount`: huevos activos sin recoger.
   - `CollectedEggs`: historial de recoleccion de sesion.
   - `Inventory.Egg`: inventario de sesion y fuente real de municion actual.
   - `SlingshotEggAmmo`: espejo/senal de municion para Honda.
23. [done][risk-review] Revisar riesgos de mostrar conteos distintos de huevos antes de crear `EggStorage`.
   - No usar `CollectedEggs` como municion porque no baja al disparar.
   - No usar `EggCount` como municion porque cuenta huevos en mundo.
   - Falta definir si Storage mostrara `Inventory.Egg`, `EggStorage` futuro o ambos.

## Nuevas tareas seguras 6

24. [done][analysis] Revisar en modo lectura que `CHECKLIST_TESTING.md` cubra los cuatro conteos de huevos actuales.
   - El checklist cubre recoleccion, municion, Storage, UI y multiplayer.
   - No distingue explicitamente `EggCount`, `CollectedEggs`, `Inventory.Egg` y `SlingshotEggAmmo`.
25. [done][documentation] Proponer textos de checklist para diferenciar `EggCount`, `CollectedEggs`, `Inventory.Egg` y `SlingshotEggAmmo` sin editar el checklist todavia.
   - Propuesta documentada en `ROBLOX_STRUCTURE.md`.
   - No se edito `CHECKLIST_TESTING.md`.
26. [done][risk-review] Revisar riesgos de pruebas manuales si se confunden huevos activos, inventario y municion.
   - Riesgos documentados en `ROBLOX_STRUCTURE.md`.
   - Riesgo principal: validar `CollectedEggs` o `EggCount` como municion produciria falsos positivos.

## Nuevas tareas seguras 7

27. [done][analysis] Revisar en modo lectura si `Homestead.Monitor` mezcla conteos globales con conteos por jugador.
   - `Homestead.Monitor` calcula `EggCount` recorriendo todas las carpetas de `Workspace.HomeRuntime`.
   - `InventoryEggsTotal` usa `InventoryService.GetSessionItemTotal("Egg")`.
   - Ambos valores son globales/de sesion, no municion por jugador.
28. [done][documentation] Documentar que valores de monitor son diagnostico global y no fuente canonica de municion.
   - Documentado en `ROBLOX_STRUCTURE.md`.
   - Fuente canonica actual por jugador: `SlingshotService:GetAmmo(player)` -> `InventoryService:GetItemCount(player, "Egg")`.
29. [done][risk-review] Revisar riesgos de usar `GetSessionItemTotal("Egg")` para decisiones de gameplay.
   - Riesgo principal: mezcla inventarios de todos los jugadores.
   - No usar `InventoryEggsTotal` ni `EggCount` del monitor para permitir disparos o cargar ammo.

## Nuevas tareas seguras 8

30. [done][analysis] Revisar en modo lectura si existe alguna UI o texto que muestre `SlingshotEggAmmo` directamente.
   - No se encontro UI prearmada en `StarterGui` para `SlingshotEggAmmo`.
   - `HomesteadClient` muestra `Inventory.Egg` en Storage UI.
   - `SlingshotController` actualiza atributo desde `FireResult` y `AmmoChanged`, pero no se encontro etiqueta visual dedicada.
31. [done][documentation] Documentar donde se podria observar la municion actual sin crear UI nueva.
   - Documentado en `ROBLOX_STRUCTURE.md`.
   - Observar `SlingshotEggAmmo` como atributo del jugador, `Inventory.Egg` en Storage, eventos `AmmoChanged`/`FireResult` y logs de servidor.
32. [done][risk-review] Revisar riesgos de validar municion solo por atributos sin UI visible.
   - Riesgo principal: atributo correcto no prueba que el jugador vea municion.
   - Storage UI correcta no prueba que `AmmoChanged` llegue al flujo de combate.

## Nuevas tareas seguras 9

33. [done][analysis] Revisar en modo lectura que servicios remotos existen en edit mode y cuales solo aparecen por script.
   - En edit mode existen `PastureRemote` y `HomesteadRemote`.
   - En edit mode no existe `ReplicatedStorage.SlingshotRemote`.
   - `Homestead.Main` crea o reutiliza `SlingshotRemote`, `FireRequest`, `FireResult` y `AmmoChanged`.
34. [done][documentation] Documentar diferencia entre remotes presentes en Explorer y remotes creados por `Homestead.Main`.
   - Documentado en `ROBLOX_STRUCTURE.md`.
   - `SlingshotRemote` parece ser runtime/asegurado por script, no instancia persistente visible en edit mode.
35. [done][risk-review] Revisar riesgos de crear remotes manualmente antes de probar Play.
   - Riesgo principal: ocultar un problema real de orden de arranque o crear objetos con clase incorrecta.
   - Falta confirmar en Play que se crean una sola vez y como `RemoteEvent`.

## Nuevas tareas seguras 10

36. [done][analysis] Revisar en modo lectura si hay valores de configuracion de Slingshot en `HomeCfg` relevantes para pruebas.
   - `AmmoItem = "Egg"`.
   - `Cooldown = 0.45`.
   - `MaxRange = 180`.
   - `MaxChargeTime = 0.8`.
   - `MinChargeToFire = 0.05`.
   - `HomeCfg.Debug.Slingshot = true`.
37. [done][documentation] Documentar parametros actuales de Slingshot que afecten pruebas manuales de disparo.
   - Documentado en `ROBLOX_STRUCTURE.md`.
   - La autoridad de ammo/rango/cooldown esta en servidor; el cliente envia `charge`.
38. [done][risk-review] Revisar riesgos de probar disparo sin conocer cooldown, rango, charge o item de municion.
   - Riesgo principal: confundir `Cooldown`, `LowCharge` o `NoHondaEquipped` con fallo de ammo.
   - Las pruebas deben controlar carga, herramienta equipada, intervalo entre disparos y conteos de ammo.

## Nuevas tareas seguras 11

39. [done][analysis] Revisar en modo lectura las razones de rechazo que `SlingshotService` devuelve por `FireResult`.
   - Razones encontradas: `NoPlayer`, `CarryingChicken`, `StorageOpen`, `CharacterInvalid`, `NoHondaEquipped`, `Cooldown`, `NoAmmo`, `InvalidDirection`, `LowCharge`.
   - Exito devuelve `Ok = true` con `Ammo`, `Origin`, `HitPosition`, `HitNormal`, `HitInstance`, `Charge` y `Range`.
40. [done][documentation] Documentar una matriz de resultados esperados para pruebas manuales sin entrar en Play.
   - Documentado en `ROBLOX_STRUCTURE.md`.
   - La matriz separa bloqueos de estado, errores de input, ammo y exito.
41. [done][risk-review] Revisar riesgos de interpretar mal `FireResult.Reason` durante QA.
   - Riesgo principal: confundir `Cooldown`, `LowCharge`, `NoHondaEquipped` o estados protegidos con fallo de ammo.
   - Para QA, registrar `FireResult.Reason` junto con `Inventory.Egg` y `SlingshotEggAmmo`.

## Nuevas tareas seguras 12

42. [done][analysis] Revisar en modo lectura si `SlingshotController` expone o registra `FireResult.Reason`.
   - `SlingshotController` escucha `FireResult`.
   - Actualiza `SlingshotEggAmmo` si `result.Ammo` existe.
   - Solo reproduce visual si `result.Ok == true`.
   - No se encontro uso directo de `result.Reason`.
43. [done][documentation] Documentar que puede observar el tester desde cliente cuando falla un disparo.
   - Documentado en `ROBLOX_STRUCTURE.md`.
   - El tester puede observar atributo ammo, ausencia de proyectil y Storage UI, pero no razon visible del fallo.
44. [done][risk-review] Revisar riesgos de que el cliente oculte razones de fallo de servidor.
   - Riesgo principal: un bloqueo correcto puede parecer bug de input, ammo o remoto.
   - Se recomienda registrar/observar `FireResult.Reason` en pruebas manuales.

## Nuevas tareas seguras 13

45. [done][analysis] Revisar en modo lectura si hay prints/debug existentes que ayuden a QA de `FireResult`.
   - Servidor imprime `NoAmmo` y disparo exitoso con ammo/charge cuando `HomeCfg.Debug.Slingshot` esta activo.
   - Cliente tiene `DEBUG_TOOL_TEST = false`; sus logs son de herramienta/animacion, no de `FireResult.Reason`.
46. [done][documentation] Documentar que logs actuales existen para Slingshot y cuales faltan.
   - Documentado en `ROBLOX_STRUCTURE.md`.
   - Faltan logs visibles para `Cooldown`, `LowCharge`, `StorageOpen`, `CarryingChicken`, `CharacterInvalid`, `NoHondaEquipped` e `InvalidDirection`.
47. [done][risk-review] Revisar riesgos de depender de `HomeCfg.Debug.Slingshot` para pruebas.
   - Riesgo principal: debug actual no cubre todas las razones de rechazo.
   - No sustituye validacion de `Inventory.Egg`, `SlingshotEggAmmo`, `AmmoChanged` y `FireResult`.

## Nuevas tareas seguras 14

48. [codex-ready][analysis] Revisar en modo lectura si `SlingshotController` crea instancias visuales locales que puedan afectar pruebas.
49. [codex-ready][documentation] Documentar visuales locales de proyectil/impacto y su diferencia con autoridad de servidor.
50. [codex-ready][risk-review] Revisar riesgos de confundir visual local con disparo autorizado.

## Falta probar en Play

- Confirmar si `Homestead.Main` crea `ReplicatedStorage.SlingshotRemote`.
- Confirmar si `SlingshotController` encuentra `SlingshotRemote` sin quedarse esperando.
- Confirmar si `AmmoChanged` actualiza `SlingshotEggAmmo` en cliente.
- Confirmar si disparar con `Egg > 0` baja el inventario en 1.
- Confirmar si disparar con `Egg == 0` queda bloqueado por servidor.
- Confirmar si recoger un huevo propio suma exactamente 1 `InventoryService.Egg`, actualiza `SlingshotEggAmmo`, baja `ActiveEggs` y destruye el huevo.
- Confirmar si otro jugador no puede recoger huevos ajenos.
- Confirmar salida/reset/cambio de casa con huevos runtime presentes para detectar huevos huerfanos o `ActiveEggs` incorrecto.
- Confirmar que `Inventory.Egg` y `SlingshotEggAmmo` se mantienen alineados despues de recoger, abrir Storage y disparar.
- Confirmar si el checklist debe describir estado actual (`SlingshotEggAmmo`) o diseno futuro (`EggAmmo`/`EggStorage`) antes de editarlo.
- Confirmar `/hs` en Play solo como diagnostico global; no usar `Inventory Eggs total` para validar municion individual.
- Confirmar si hace falta UI visible de municion o si `SlingshotEggAmmo` como atributo basta para pruebas internas.
- Confirmar en Play que `SlingshotRemote.FireRequest`, `FireResult` y `AmmoChanged` aparecen una sola vez y con clase `RemoteEvent`.
- Controlar `Cooldown`, `MinChargeToFire`, `MaxChargeTime`, `MaxRange` y herramienta equipada al probar disparo.
- Registrar `FireResult.Reason` durante pruebas manuales para distinguir rechazos reales.
- Confirmar si se necesita tarea futura para exponer `FireResult.Reason` al tester.
- No depender solo de `HomeCfg.Debug.Slingshot`; no registra todas las razones de rechazo.

## GitHub Issue #2

51. [done][analysis] Preparar snapshot actual de `CodexAvanceTest` para revision.
   - Issue: #2 `Preparar snapshot actual de CodexAvanceTest para revision`.
   - Se verifico Studio activo como `CodexAvanceTest` en modo Edit.
   - Se exportaron scripts actuales a `snapshots/CodexAvanceTest_Current/`.
   - Se creo `snapshots/CodexAvanceTest_Current/STATUS.md`.
   - Se creo `snapshots/CodexAvanceTest_Current/MANIFEST.md`.
   - No se modifico gameplay, no se creo `src`, no se creo Rojo y no se editaron scripts en Studio.
