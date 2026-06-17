# STATUS.md

## Estado actual
ConfiguraciÃ³n inicial de flujo Codex + GitHub Issues.

## Ãšltimo issue trabajado
CODEX_QUEUE tareas 1-47.

## Cambios recientes
- 2026-06-16 21:50 -05:00: Se ajusto Cfg.SheepPerFlock a 2 en Pasture.
- 2026-06-04 03:38 -05:00: Se completaron tareas seguras 45-47 de `CODEX_QUEUE.md`. Se documento que `HomeCfg.Debug.Slingshot` ayuda con `NoAmmo` y disparos exitosos, pero no registra todas las razones de rechazo de `FireResult`; no sustituye validaciones de ammo/remotes. No se modifico Roblox Studio ni scripts.
- 2026-06-04 03:36 -05:00: Se completaron tareas seguras 42-44 de `CODEX_QUEUE.md`. Se documento que `SlingshotController` actualiza `SlingshotEggAmmo` y proyectil local desde `FireResult`, pero no expone ni registra `FireResult.Reason`; esto puede dificultar QA sin observacion adicional. No se modifico Roblox Studio ni scripts.
- 2026-06-04 03:35 -05:00: Se completaron tareas seguras 39-41 de `CODEX_QUEUE.md`. Se documento la matriz de `FireResult.Reason` para `SlingshotService`, separando estados protegidos, cooldown, carga baja, falta de ammo, direccion invalida y exito. No se modifico Roblox Studio ni scripts.
- 2026-06-04 03:34 -05:00: Se completaron tareas seguras 36-38 de `CODEX_QUEUE.md`. Se documento `HomeCfg.Slingshot`: `AmmoItem = "Egg"`, `Cooldown = 0.45`, `MaxRange = 180`, `MaxChargeTime = 0.8`, `MinChargeToFire = 0.05`, y riesgos de confundir cooldown/carga/herramienta con fallos de ammo. No se modifico Roblox Studio ni scripts.
- 2026-06-04 03:31 -05:00: Se completaron tareas seguras 33-35 de `CODEX_QUEUE.md`. Se verifico que `SlingshotRemote` no existe en edit mode y que `Homestead.Main` lo crea o reutiliza junto con `FireRequest`, `FireResult` y `AmmoChanged`; se documento no crear remotes manualmente antes de Play. No se modifico Roblox Studio ni scripts.
- 2026-06-04 03:30 -05:00: Se completaron tareas seguras 30-32 de `CODEX_QUEUE.md`. Se documento que no hay UI visible dedicada a `SlingshotEggAmmo`; la municion actual se observa por atributo, `AmmoChanged`/`FireResult`, Storage muestra `Inventory.Egg` y los logs sirven solo como diagnostico. No se modifico Roblox Studio ni scripts.
- 2026-06-04 03:29 -05:00: Se completaron tareas seguras 27-29 de `CODEX_QUEUE.md`. Se documento que `Homestead.Monitor` reporta conteos globales (`EggCount`, `InventoryEggsTotal`) para diagnostico y no debe usarse como fuente canonica de municion por jugador. No se modifico Roblox Studio ni scripts.
- 2026-06-04 03:26 -05:00: Se completaron tareas seguras 24-26 de `CODEX_QUEUE.md`. Se reviso `CHECKLIST_TESTING.md` sin editarlo y se documento que el checklist todavia no distingue `EggCount`, `CollectedEggs`, `Inventory.Egg` y `SlingshotEggAmmo`. No se modifico Roblox Studio ni scripts.
- 2026-06-04 03:25 -05:00: Se completaron tareas seguras 21-23 de `CODEX_QUEUE.md`. Se documento la diferencia entre `EggCount`, `CollectedEggs`, `Inventory.Egg` y `SlingshotEggAmmo`, y los riesgos de UI/checklist antes de crear `EggStorage`. No se modifico Roblox Studio ni scripts.
- 2026-06-04 03:24 -05:00: Se completaron tareas seguras 18-20 de `CODEX_QUEUE.md`. Se documento como `AnimalService` crea `EggService` con el `InventoryService` compartido, como inyecta ese `EggService` en gallinas runtime, y que salida/reset/cambio de casa con huevos presentes requiere prueba en Play. No se modifico Roblox Studio ni scripts.
- 2026-06-04 03:19 -05:00: Se completaron tareas seguras 15-17 de `CODEX_QUEUE.md`. Se documento el flujo de recoleccion de huevos: `EggService` valida dueno, usa `Collected`, suma `InventoryService.Egg`, sincroniza `SlingshotEggAmmo`, baja `ActiveEggs` y destruye el huevo. No se modifico Roblox Studio ni scripts.
- 2026-06-04 03:15 -05:00: Se completaron tareas seguras 12-14 de `CODEX_QUEUE.md`. Se documentaron puntos de extension de Storage, ajustes sugeridos para `CHECKLIST_TESTING.md` segun el estado real `SlingshotEggAmmo`, y riesgos multiplayer de `SessionInventories` por `UserId`.
- 2026-06-04 03:14 -05:00: Se completaron tareas seguras 9-11 de `CODEX_QUEUE.md`. Se documento que `HomesteadStorageOpen` bloquea disparo/BattleMode en cliente y servidor, que el checklist todavia habla de `EggAmmo`/`EggStorage` mientras el sistema real usa `SlingshotEggAmmo`, y que `SlingshotController` tiene `WaitForChild` sin timeout para `SlingshotRemote`.
- 2026-06-04 03:12 -05:00: Se completaron tareas seguras 6-8 de `CODEX_QUEUE.md`. No se encontraron referencias exactas a `EggStorage` ni a `"EggAmmo"` independiente; se documento el analisis consolidado y riesgos de migracion en `ROBLOX_STRUCTURE.md`.
- 2026-06-04 03:10 -05:00: Se avanzo el flujo continuo usando `CODEX_QUEUE.md`. La tarea 1 quedo en `codex-review` porque requiere Play. Se completaron las tareas 2 y 3 con analisis de solo lectura sobre `SlingshotRemote`, `SlingshotEggAmmo` e `InventoryService.Egg`; no se modifico Roblox Studio.
- Se creo `CODEX_QUEUE.md` como cola local de trabajo continuo para Codex App + MCP en `CodexAvanceTest`.
- 2026-06-04 02:41 -05:00: Se inspecciono Roblox Studio usando MCP sobre el target `CodexAvanceTest`. El DataModel fue accesible. Se encontraron Homestead, Pasture, Storage, Gallina, EggTemplate, Honda/Slingshot y remotes principales; se actualizo `ROBLOX_STRUCTURE.md`.
- 2026-06-04 02:32 -05:00: Se intento inspeccionar Roblox Studio usando MCP. La instancia fue detectada, pero el DataModel no estuvo accesible; se creo `ROBLOX_STRUCTURE.md` con el bloqueo y pendientes de confirmacion.
- Se agregaron templates de GitHub Issues, Pull Request y documentacion de labels para el flujo Codex.
- Se creÃ³ estructura de reglas para Codex.
- Se definieron sistemas protegidos.
- Se definiÃ³ prioridad de estados del jugador.

## Sistemas sensibles
- Pasture: NO TOCAR sin autorizaciÃ³n explÃ­cita.
- CarryChicken: estable, sensible.
- Storage/UI: pendiente de conectar con huevos y municiÃ³n.
- Honda BattleMode: estable, sensible en transiciones.
- Death/Reset: prioridad mÃ¡xima.
- Homestead: permitido si el issue corresponde.

## Pendientes de prueba manual
- Pendiente probar en Play si `ReplicatedStorage.SlingshotRemote` se crea por `Homestead.Main` y si `SlingshotController` no queda esperando remotes.
- Pendiente confirmar diseno final: conservar `SlingshotEggAmmo` o migrar a `EggAmmo`; separar `EggStorage` de municion activa.
- Pendiente probar en Play si `AmmoChanged` sincroniza cliente y si disparar consume exactamente 1 `InventoryService.Egg`.
- Pendiente probar en Play si recoger un huevo propio suma exactamente 1 `InventoryService.Egg`, actualiza `SlingshotEggAmmo`, baja `ActiveEggs` y destruye el huevo.
- Pendiente probar en Play si otro jugador no puede recoger huevos ajenos.
- Pendiente probar en Play salida/reset/cambio de casa con huevos runtime presentes para confirmar que no quedan huevos huerfanos ni `ActiveEggs` desincronizado.
- Pendiente probar en Play que `Inventory.Egg` y `SlingshotEggAmmo` se mantienen alineados despues de recoger, abrir Storage y disparar.
- Pendiente decidir si `CHECKLIST_TESTING.md` debe describir estado actual (`SlingshotEggAmmo`) o diseno futuro (`EggAmmo`/`EggStorage`) antes de editarlo.
- Pendiente probar `/hs` en Play solo como diagnostico global; no usar `Inventory Eggs total` para validar municion individual.
- Pendiente confirmar si hace falta UI visible de municion o si `SlingshotEggAmmo` como atributo basta para pruebas internas.
- Pendiente confirmar en Play que `SlingshotRemote.FireRequest`, `FireResult` y `AmmoChanged` aparecen una sola vez y con clase `RemoteEvent`.
- Pendiente controlar `Cooldown = 0.45`, `MinChargeToFire = 0.05`, `MaxChargeTime = 0.8`, `MaxRange = 180` y herramienta equipada al probar disparo.
- Pendiente registrar `FireResult.Reason` durante pruebas manuales para distinguir `NoAmmo`, `Cooldown`, `LowCharge`, `NoHondaEquipped`, `StorageOpen`, `CarryingChicken` y `CharacterInvalid`.
- Pendiente confirmar si hace falta tarea futura para exponer `FireResult.Reason` al tester en UI o log local.
- Pendiente no depender solo de `HomeCfg.Debug.Slingshot`; actualmente no registra todas las razones de rechazo.

## Riesgos conocidos
- Codex puede romper sistemas existentes si un issue estÃ¡ mal escrito.
- Roblox Studio debe usarse para probar animaciones, UI, disparo y estados del jugador.
- En `CodexAvanceTest` ya existe municion `SlingshotEggAmmo` y disparo con huevos ligado a `InventoryService.Egg`; crear `EggAmmo` sin migracion clara puede duplicar estado.
- `EggStorage` no existe todavia como entidad separada; Storage/UI y Honda BattleMode son sensibles.
- En edit mode no existe `ReplicatedStorage.SlingshotRemote`; parece crearse por `Homestead.Main`, pero falta comprobarlo en Play.
- `SlingshotController` usa `WaitForChild` sin timeout para `SlingshotRemote` y sus remotes hijos; si `Homestead.Main` no corre a tiempo, el cliente puede quedar esperando.
- El inventario actual es de sesion por `UserId`; falta prueba multiplayer para confirmar aislamiento y consumo individual.
- La recoleccion de huevos actual entra directo a `InventoryService.Egg` y `SlingshotEggAmmo`; conectar `EggStorage` sin diseno puede duplicar o perder huevos.
- `EggService` usa `Collected` y `Destroy()` para evitar duplicados, pero falta probar doble activacion rapida del `ProximityPrompt` en Play.
- `CollectedEggs`, `Inventory.Egg`, `EggCount` y `SlingshotEggAmmo` pueden representar conteos distintos; antes de UI o Storage hay que definir cual es canonico para cada pantalla.
- `AnimalService:Release` y `HomeService:Release` destruyen runtime al salir/cambiar casa; falta confirmar el orden con huevos presentes.
- El checklist actual usa `EggAmmo`/`EggStorage` como nombres objetivo, pero el estado real todavia usa `Inventory.Egg` y `SlingshotEggAmmo`; una prueba manual mal nombrada puede validar el contador equivocado.
- `Homestead.Monitor` aparece como posible siguiente punto de revision porque reporta conteos globales; no usar valores globales como fuente canonica por jugador sin analisis.
- `InventoryService.GetSessionItemTotal("Egg")` suma huevos de todos los inventarios de sesion; usarlo para gameplay mezclaria municion entre jugadores.
- `Homestead.Monitor.EggCount` suma huevos activos de todas las casas; no representa municion disponible.
- No hay UI visible dedicada a municion; validar solo atributos o logs puede ocultar problemas de experiencia de jugador.
- Crear `SlingshotRemote` manualmente antes de Play puede ocultar un problema real de arranque o provocar conflicto de clases con `ensureFolder`/`ensureRemote`.
- Probar disparo sin controlar carga/cooldown/herramienta puede generar falsos diagnosticos de ammo.
- Si QA no observa `FireResult.Reason`, puede interpretar un bloqueo correcto como fallo de municion o de remoto.
- `SlingshotController` no parece mostrar la razon de fallo al jugador/tester; la ausencia de proyectil por si sola es evidencia debil.
- `HomeCfg.Debug.Slingshot` registra exito y `NoAmmo`, pero no cubre `Cooldown`, `LowCharge`, `StorageOpen`, `CarryingChicken`, `CharacterInvalid`, `NoHondaEquipped` ni `InvalidDirection`.

## Siguiente objetivo
Crear sistema de disparo usando huevos como municiÃ³n.
eports/explorer_snapshot.md, 
eports/dragon_bones.md, 
eports/active_scripts.md, 
eports/output_last_test.md, 
eports/mount_system_diagnosis.md, scripts/ServerScriptService/*, scripts/StarterPlayerScripts/*, patches/. Qu? cambi?: se exportaron scripts relacionados con Dragon/Flight/Mount/Collision/Sheep y reportes t?cnicos de DataModel/bones/mount. Qu? falta probar: Play manual para montar, caminar, despegar, volar y desmontar. Riesgos conocidos: no modificar Pasture/Homestead ni a?adir m?s l?gica a DragonFlightService.server.lua sin issue espec?fico.
- 2026-06-10: Snapshot tecnico del sistema Dragon exportado desde Roblox Studio MCP. Issue trabajado: solicitud directa del usuario, sin GitHub issue codex-ready. Archivos tocados: README.md, reports/*, scripts/ServerScriptService/*, scripts/StarterPlayerScripts/*, patches/. Que cambio: se exportaron scripts relacionados con Dragon, Flight, Mount, Collision y Sheep, mas reportes tecnicos de DataModel, bones y mount. Que falta probar: Play manual para montar, caminar, despegar, volar y desmontar. Riesgos conocidos: no modificar Pasture/Homestead ni anadir mas logica a DragonFlightService.server.lua sin issue especifico.

## Issue #2 - Snapshot CodexAvanceTest_Current

- 2026-06-16 21:17 -05:00: Se trabajo la Issue #2 `Preparar snapshot actual de CodexAvanceTest para revision`.
- Place inspeccionado: `CodexAvanceTest / Place1`, Studio en modo Edit, usando MCP de Roblox Studio.
- Archivos tocados: `STATUS.md`, `ROBLOX_STRUCTURE.md`, `CODEX_QUEUE.md`, `snapshots/CodexAvanceTest_Current/*`.
- Que cambio: se exportaron scripts actuales de `ServerScriptService.Homestead`, `StarterPlayer.StarterPlayerScripts` y `ServerScriptService.DragonRaidAutoTest` al snapshot local.
- Estado real documentado: el disparo con huevos ya existe como Fire v0 usando `InventoryService.Egg`, `SlingshotService`, `SlingshotController`, `SlingshotAnimateGuard` y atributo `SlingshotEggAmmo`.
- Sistemas encontrados: Pasture v1.2, Homestead v4 ChickenCarry, InventoryService, EggService, StorageService, SlingshotService, SlingshotController, SlingshotAnimateGuard, DragonRaidService y DragonRaidAutoTest.
- Que falta probar: no se hizo Play en esta tarea; falta prueba manual de recoger Egg, Storage, disparo Honda, consumo de Egg, bloqueos por CarryChicken/Storage y efectos de reset/death.
- Riesgos conocidos: DragonRaidAutoTest existe pero queda Disabled=true; DragonRaidService se conserva, pero no se ejecuta automaticamente; Fire v0 no tiene dano todavia; Honda sigue siendo Tool normal con Handle/RightGrip; el repo es snapshot, no fuente Rojo.
