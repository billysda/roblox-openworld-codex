# Orden para Antigravity: primera captura real de OpenWorld Codex

**Propósito**: entregar a ChatGPT un mapa consultable del contenido ACTUAL de Roblox Studio. No programar ni modificar gameplay durante esta tarea.

## Identidad del proyecto

- Repo único: `billysda/roblox-openworld-codex`
- Objetivo: Place de **OpenWorld Codex / CodexAvanceTest**, identificar por nombre + PlaceId actual.
- Excluir explícitamente **Dark Fantasy World**.
- Si hay ambigüedad de ventanas, detener y preguntar; no operar sobre la primera ventana arbitraria.
- Antes de exportar, comparar nombres, PlaceId, estado Edit/Play y último guardado. No asumir que código en GitHub es la última versión de Studio.

## Operación

1. Comprobar Studio MCP, localizar Place, crear backup local del Place (`.rbxl`/`.rbxlx` si viable) y no subir binarios privados automáticamente.
2. Abrir y seguir `docs/studio_snapshot/README.md` de GitHub.
3. Leer `tools/studio_snapshot/export_inventory.lua`. Usar código de ese archivo mediante `execute_luau` en **Edit**, por separado para `Workspace`, `ReplicatedStorage`, `ServerScriptService`, `ServerStorage`, `StarterPlayer`, `StarterGui`, `Lighting` y `SoundService`. Añadir los demás servicios que contengan objetos del juego.
4. Para cada servicio, empezar con `START_INDEX=1`, `PAGE_LIMIT=80`. Registrar la respuesta JSON completa como archivo individual; repetir `START_INDEX += PAGE_LIMIT` hasta `hasMore=false`. No recortar el resultado. Reducir PAGE_LIMIT y recapturar todo ese servicio si MCP trunca respuestas.
5. Validar que el recuento `totalNodes`, `placeId`, `gameId` y la secuencia de páginas sea coherente. No editar el DataModel entre páginas.
6. Guardar las páginas temporalmente en una carpeta fuera del mapa publicado, p. ej. `captures/edit`. Ejecutar:

```powershell
python tools/studio_snapshot/build_map.py --pages captures/edit --out docs/studio_snapshot/current --place-name CodexAvanceTest --studio-id ID_REAL --mode Edit --git-revision SHA_REAL
```

7. Si el script falla, corregir la **captura**, no falsificar filas para aprobar. Inspeccionar archivos generados: `INDEX.md`, `WORKSPACE_TREE.md`, `SPATIAL_INDEX.md`, `instances/workspace.jsonl`, `spatial_index.jsonl`, `metadata.json`.
8. Inspeccionar contenido potencialmente sensible antes de publicar. El repositorio es público. Filtrar datos de usuario, secretos, credenciales o cualquier otra información privada incluso si aparece en nombres/atributos; registrar exclusiones.
9. Capturar además, **por un método autorizado de Studio MCP**, todos los `Source` de scripts del proyecto necesarios para compilar/sincronizar, conservando ruta exacta y hashes SHA-256. No copiar secretos al repositorio público. Documentar exclusiones/permisos insuficientes.
10. Registrar dependencias: relaciones entre constraints/joints/attachments, RemoteEvents, scripts y ModuleScript require; evidenciar si una relación es una referencia real o fue inferida del código.
11. Si es viable, repetir captura separada en Play para instancias runtime, y guardarla en `docs/studio_snapshot/runtime`; no mezclar Edit y Play.
12. Crear commit (preferiblemente rama o PR para revisión) con mapa, scripts autorizados, estadísticas, limitaciones, diferencias entre GitHub y Studio y URL/SHA. **No sincronizar código viejo desde GitHub por encima del Studio actual.**

## Preguntas de ChatGPT que Antigravity debe responder con evidencia

- ¿Cuál es el nombre y PlaceId efectivo?
- ¿Dónde está exactamente `Workspace.wyvernfbx` y su `DT_Root`?
- ¿Cuál es el Source actual de `WyvernFlightV2` y qué hash tiene cada archivo?
- ¿Qué scripts funcionan en Edit y cuáles sólo aparecen en Play?
- ¿Hay duplicados de FlightCamera, Input o FlightController habilitados?
- ¿GitHub representa el mismo Source de Studio, o hay divergencias?
- ¿Hay errores en Output al iniciar Play?
- ¿Qué mecanismo MCP de sincronización es fiable y reversible?

Responder con paths, valores, logs/capturas concretas y fecha. No declarar `PASS` cuando una prueba sólo simuló inputs; gameplay real se valida por el usuario.

## Después del primer snapshot

ChatGPT programará mediante cambios versionados de GitHub. Antigravity, al recibir commit/PR y rutas exactas, comparará SHA de Studio y repo, inyectará únicamente lo autorizado, probará Edit/Play, enviará informe y recapturará las partes afectadas del mapa. Si hay conflictos, detener y consultar.

**Entrega terminada sólo cuando el snapshot real y verificable esté en GitHub.** Sin resultados de Studio la estructura es `UNKNOWN`.
