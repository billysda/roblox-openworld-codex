# Revisión de PR #41 — línea base OpenWorld Codex (2026-10-13)

- PR #41 fusionada en `main` mediante commit `a4881d5d71b4e77106204ba10923287c1f142a56`.
- La PR añadió 104 archivos y ~30.916 líneas, mayoritariamente documentación, inventario y copias Source leídas de Roblox Studio. **No actualizó directamente el DataModel/Place.**
- Snapshot Edit observado: PlaceId `100008359356261`, 4.064 instancias representadas (2.480 de Workspace), 789 objetos con indexación espacial y Source de 84 scripts.
- Excluidos: >1 millón de nodos en `ServerStorage.RBX_ANIMSAVES`; voxel Terrain y recursos binarios Mesh/CSG; instancias generadas sólo en Play. El inventario no representa absolutamente todos los descendientes ni todos los servicios posibles.
- Revisión selectiva de los scripts activos `WyvernFlightV2` y fuentes auxiliares: las seis fuentes del sistema V2 existen con los hashes indicados en `SCRIPT_INDEX.md`. Las pruebas de comportamiento siguen necesitando Play real.
- Los 84 enlaces relativos en `SCRIPT_INDEX.md` fueron reparados en una PR de seguimiento.
- **Precaución crítica:** `DIFF_FROM_PREVIOUS.md` es un diagnóstico histórico, NO una reconciliación aplicable automáticamente. Nombres/rutas alternos (por ejemplo `StarterPlayerScripts/...` vs `StarterPlayer/StarterPlayerScripts/...`) pueden producir falsos `REPO_ONLY` o `STUDIO_ONLY`. Antes de sincronizar: comparar el `GetFullName()`, ClassName, Source exacto y SHA-256 leído en Studio.
- La presencia de fuentes dentro de `docs/studio_snapshot/current/scripts` no autoriza desplegarlas todas ni elimina la necesidad de establecer un árbol de código canónico para edición.
- El watcher de `tools/agent_sync/watch_repo.py` detecta cambios remotos y requiere configuración/ejecución local por Antigravity. No existe entrega automática de nuevos commits al chat de Gemini Web ni ChatGPT.

## Siguiente auditoría obligatoria

Antigravity debe identificar el mapeo real para cada fuente activa entre **Studio ↔ snapshot archivado ↔ árbol de código en desarrollo**, y probar un ciclo pequeño de modificación reversible antes de permitir reemplazos grandes de código.
