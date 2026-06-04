# CODEX_QUEUE.md

Cola local de trabajo continuo para Codex App + MCP en el place Roblox Studio `CodexAvanceTest`.

## Reglas de uso

- Trabajar una tarea a la vez.
- Antes de implementar, leer `AGENTS.md`, `CODEX_RULES.md`, `STATUS.md` y `ROBLOX_STRUCTURE.md`.
- No modificar Roblox Studio salvo que la tarea lo pida explicitamente.
- No tocar sistemas protegidos sin issue o tarea con autorizacion `[Protected Change]`.
- Mantener `STATUS.md` actualizado despues de cambios importantes.

## Cola inicial

1. [codex-ready][analysis] Confirmar en Play si `SlingshotRemote` existe y donde se crea.
2. [codex-ready][analysis] Analizar el flujo actual de `SlingshotEggAmmo` e `InventoryService.Egg` sin modificar codigo.
3. [codex-ready][design] Proponer si conviene mantener `SlingshotEggAmmo` o crear `EggAmmo` separado.
4. [blocked][implementation] Implementar consumo de huevo al disparar, bloqueado hasta confirmar tareas 1-3.
5. [blocked][implementation] Conectar Storage con municion, bloqueado hasta confirmar diseno de `EggStorage` vs `SlingshotEggAmmo`.

