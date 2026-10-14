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

## Colaboración GPT-6 / Gemini Argon 4 / Antigravity

**Leer siempre** `docs/agent_sync/PROTOCOL.md` antes de comenzar tareas o sincronizar Studio.

- Dos programadores pueden crear versiones competidoras A/B en ramas separadas **desde el mismo base_sha**. Nunca mezclar las dos variantes antes de elegir una ganadora.
- GPT-6 escribe en GitHub mediante commits/PR; Gemini Argon 4 Web entrega parches basados en SHA a Antigravity; Antigravity publica en GitHub y sincroniza el Place local.
- Antigravity debe obtener cambios GitHub frescos e inspeccionar código y diffs completos: `python tools/agent_sync/watch_repo.py --once`; si falta el estado revisado, no inyectar nada. Puede activar `--watch` localmente cuando lo configure el usuario.
- Antes de empezar cualquier tarea: verificación del último SHA remoto de `main` y de la rama/PR relevante; no fiarse de resúmenes, memorias, importaciones web o snapshots antiguos.
- No sobreescribir Studio desde `main` sin comparar rutas/Source SHA y realizar backup. Todas las correcciones realizadas en Studio deben volver a una rama de GitHub.
- La carpeta `docs/studio_snapshot/current/scripts` es evidencia archivada del estado de Studio en Edit (2026-10-13): **NO** es automáticamente árbol canónico de despliegue.
- Los scripts V1 legacy WyvernFlight deshabilitados se mantienen deshabilitados; no mezclar Dark Fantasy World.
- Para cada integración: publicar SHA de commit fuente, rutas exactas, SHA-256 de Source Studio, resultado de pruebas y cambios del DataModel en la PR o issue. No declarar Play PASS sin la prueba correspondiente.
