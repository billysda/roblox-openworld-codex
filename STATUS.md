# STATUS.md

## Estado actual
Configuración inicial de flujo Codex + GitHub Issues.

## Último issue trabajado
Ninguno.

## Cambios recientes
- Se creo `CODEX_QUEUE.md` como cola local de trabajo continuo para Codex App + MCP en `CodexAvanceTest`.
- 2026-06-04 02:41 -05:00: Se inspecciono Roblox Studio usando MCP sobre el target `CodexAvanceTest`. El DataModel fue accesible. Se encontraron Homestead, Pasture, Storage, Gallina, EggTemplate, Honda/Slingshot y remotes principales; se actualizo `ROBLOX_STRUCTURE.md`.
- 2026-06-04 02:32 -05:00: Se intento inspeccionar Roblox Studio usando MCP. La instancia fue detectada, pero el DataModel no estuvo accesible; se creo `ROBLOX_STRUCTURE.md` con el bloqueo y pendientes de confirmacion.
- Se agregaron templates de GitHub Issues, Pull Request y documentacion de labels para el flujo Codex.
- Se creó estructura de reglas para Codex.
- Se definieron sistemas protegidos.
- Se definió prioridad de estados del jugador.

## Sistemas sensibles
- Pasture: NO TOCAR sin autorización explícita.
- CarryChicken: estable, sensible.
- Storage/UI: pendiente de conectar con huevos y munición.
- Honda BattleMode: estable, sensible en transiciones.
- Death/Reset: prioridad máxima.
- Homestead: permitido si el issue corresponde.

## Pendientes de prueba manual
- Ninguno todavía.
- Pendiente probar en Play si `ReplicatedStorage.SlingshotRemote` se crea por `Homestead.Main` y si `SlingshotController` no queda esperando remotes.
- Pendiente confirmar diseno final: conservar `SlingshotEggAmmo` o migrar a `EggAmmo`; separar `EggStorage` de municion activa.

## Riesgos conocidos
- Codex puede romper sistemas existentes si un issue está mal escrito.
- Roblox Studio debe usarse para probar animaciones, UI, disparo y estados del jugador.
- En `CodexAvanceTest` ya existe municion `SlingshotEggAmmo` y disparo con huevos ligado a `InventoryService.Egg`; crear `EggAmmo` sin migracion clara puede duplicar estado.
- `EggStorage` no existe todavia como entidad separada; Storage/UI y Honda BattleMode son sensibles.

## Siguiente objetivo
Crear sistema de disparo usando huevos como munición.
