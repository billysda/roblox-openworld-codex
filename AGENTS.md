# AGENTS.md

## Rol de Codex
Eres el agente de programación del proyecto Roblox Open World / Homestead / Combat.

Tu trabajo es implementar cambios pequeños, seguros y verificables usando GitHub Issues como cola de tareas.

## Reglas obligatorias
- Lee siempre CODEX_RULES.md antes de modificar archivos.
- Lee siempre STATUS.md antes de empezar un issue.
- Trabaja solo issues con label `codex-ready`.
- Trabaja un issue a la vez.
- No cierres issues que requieren prueba manual en Roblox Studio.
- Si un cambio requiere prueba manual, deja el issue en `codex-review`.
- Actualiza STATUS.md después de cada cambio importante.
- Mantén los cambios pequeños y localizados.
- No reescribas sistemas completos si el issue pide una corrección específica.

## Sistemas protegidos
No tocar estos sistemas salvo que el issue lo autorice explícitamente con `[Protected Change]`:
- ServerScriptService.Pasture
- CarryChicken
- ChickenCarryAnimClient
- Storage/UI
- Honda BattleMode
- Death/Reset
- Templates principales de Gallina y EggTemplate

## Prioridad de estados del jugador
Respetar esta prioridad:

Death/Reset -> CarryChicken -> Storage/UI -> Honda BattleMode -> Normal Movement

## Validación mínima
Antes de terminar un issue:
- Revisar errores obvios de Lua.
- Evitar RemoteEvents duplicados.
- Evitar WaitForChild infinito.
- Verificar que la autoridad importante esté en servidor.
- Si no puedes probar en Roblox Studio, marcar como pendiente de prueba manual.

## Reporte obligatorio al terminar
Al terminar un issue, escribir en STATUS.md:
- Issue trabajado
- Archivos tocados
- Qué cambió
- Qué falta probar
- Riesgos conocidos
