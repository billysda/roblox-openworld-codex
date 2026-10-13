# OpenWorld Codex — Inventario del Place (Roblox Studio)

**Estado: PENDIENTE DE CAPTURA REAL.** Este directorio no es un mapa completo del Place hasta que Antigravity exporte el DataModel mediante Studio MCP. Nunca reconstruir ni inventar objetos desde recuerdos o capturas antiguas.

## Contrato de colaboración

- **ChatGPT:** programador del código versionado en GitHub; prepara cambios pequeños, revisa dependencias y entrega commit/PR.
- **Antigravity:** operador local de Roblox Studio; responde preguntas de observación, exporta el estado real del Place, sincroniza únicamente los cambios aprobados, ejecuta pruebas Edit/Play y publica evidencias.
- **Usuario:** valida sensaciones visuales y gameplay. Sin confirmación de Play, el resultado queda `pendiente de validación`.
- **Alcance:** exclusivamente OpenWorld Codex / CodexAvanceTest y el wyvern correspondiente. NO confundir con Dark Fantasy World.

**Regla previa a cualquier push o inyección:** comparar primero Studio (fuente del estado jugable), checkout local y GitHub por rutas + hashes. Si divergen, conservar ambos, exportar snapshot, registrar diferencias y detener cambios destructivos.

## Representación versionada solicitada

Después de la primera exportación exitosa, Antigravity debe crear o actualizar en esta carpeta:

- `metadata.json`: nombre exacto de la ventana/Place, PlaceId/UniverseId cuando sean accesibles, Studio ID, fecha UTC, estado Edit o Play, versión de Studio, hash del snapshot y rama/commit GitHub de referencia.
- `instances/workspace.jsonl`: **todos** los descendientes de Workspace (sin truncamiento); un registro por instancia con ruta estable, clase, padre, índice entre hermanos, atributos, tags y propiedades relevantes (pivote/CFrame, tamaño, visibilidad, colisiones, mesh/texture/asset IDs, etc.).
- `instances/services/*.jsonl`: el resto de servicios relevantes (`ReplicatedStorage`, `ServerScriptService`, `ServerStorage`, `StarterGui`, `StarterPlayer`, `Lighting`, etc.), separados por servicio.
- `WORKSPACE_TREE.md`: árbol de carpetas, modelos, scripts, Parts, bones y demás objetos, generado desde los JSONL, con índice navegable de grandes subárboles.
- `SPATIAL_INDEX.md`: lista de modelos y BaseParts con posiciones mundiales, pivotes, bounding boxes y grupos espaciales; **no es un mapa 3D renderizado**.
- `SCRIPT_INDEX.md`: ruta exacta, clase, ubicación, enabled/disabled cuando corresponda, hash SHA-256 de Source y ruta del código exportado; fuente de scripts aparte bajo `scripts/` si se puede exportar legalmente.
- `CONNECTIONS.md`: remotes, referencias de `Attachment0/1`, `Part0/1`, joints, constraints, ModuleScript requires y otras relaciones verificables. Distinguir referencias extraídas de instancias frente a análisis estático de Source.
- `DIFF_FROM_PREVIOUS.md`: añadidos, borrados y modificaciones por ruta/propiedad/hash desde la exportación anterior.
- `CAPTURE_LIMITATIONS.md`: aquello que no puede inferirse fielmente del inventario; errores y bloques omitidos.

**No guardar mapas falsos ni completar huecos con imaginación.** Hasta contar con un archivo exportado, el elemento se marca `UNKNOWN`.

## Procedimiento de captura

1. Antigravity enumera las ventanas Studio MCP y selecciona por nombre **y PlaceId**, no por índice de lista. Se recomienda `CodexAvanceTest`, sujeto a verificación actual.
2. Hace snapshot local/backup del proyecto antes de escribir. Opera en modo lectura para la captura.
3. Ejecuta `tools/studio_snapshot/export_inventory.lua` por servicios y por páginas (START/LIMIT). Recoge **todas** las páginas hasta `hasMore=false`, comprueba que no faltan índices y concatena los registros en JSONL ordenado. Exporta primero en Edit; genera por separado un snapshot de Play para objetos runtime (no mezclarlos).
4. Completa la exportación de Source de scripts mediante capacidades autorizadas de Studio MCP, con hashes y sin inventar Source cuando el acceso sea denegado.
5. Genera los índices de árbol, espacial, scripts y relaciones a partir de los datos obtenidos; compara captura con snapshot anterior y documenta cambios.
6. Verifica recuento de instancias por servicio, números de página, duplicados de rutas, referencias huérfanas y casos con errores de lectura; publica el snapshot con commit separado y comunica URL/SHA.
7. ChatGPT revisa el snapshot antes de programar; Antigravity vuelve a sincronizar/recapturar luego de cada lote importante de cambios.

### Seguridad y fidelidad

- No exportar tokens, claves, datos personales, chat, DataStore ni valores privados de cuentas. Revisar scripts por secretos antes de publicarlos: **este repositorio es público**.
- Nunca utilizar un snapshot Edit como prueba de que un objeto runtime existe en Play, ni viceversa.
- El inventario es una representación **estructural y espacial**, no un `.rbxl` ni una reconstrucción fiel de MeshPart/CSG/Terrain. Para geometría exacta se necesitan modelos/assets/voxels y copias del Place adecuadas.
- Los Assets pueden cambiar externamente sin que cambie el MeshId: conservar AssetIds y, cuando sea legal y viable, comprobación de versión externa.
- Considerar carpetas/modelos muy grandes: paginar, no cortar silenciosamente.

## Preguntas al agente local

Cuando ChatGPT no pueda observar Studio, abrir una pregunta concreta a Antigravity (por GitHub Issue o prompt) con:
`place`, `paths`, `observation`, `edit/play`, `evidence_required`.
Antigravity debe responder con ruta exacta, valor real, timestamp, herramienta, diferencias con GitHub y, si corresponde, logs/captura. El agente local no debe modificar nada cuando sólo se le pide observar.

## Próximo paso

**Antigravity debe efectuar la primera exportación completa.** Mientras no exista, el estado es `PENDIENTE` y ChatGPT no debe afirmar conocer el interior actual del Workspace.
