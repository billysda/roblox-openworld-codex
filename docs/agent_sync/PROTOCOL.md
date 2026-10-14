# OpenWorld Codex — protocolo de sincronización de 3 agentes (v1)

**Alcance exclusivo:** `billysda/roblox-openworld-codex` y el Place identificado mediante Studio MCP como `CodexAvanceTest` / `Lugar de Cazador32262: 06202026_3`, PlaceId observado `100008359356261` al 2026-10-13. **Nunca aplicar cambios a Dark Fantasy World.**

## Fuente de verdad y responsabilidades

- **GitHub:** fuente versionada de *código revisado* y de resultados de captura. Las ramas y los commits identifican exactamente cada versión. Una carpeta local o una importación de Gemini Web no sustituyen al remoto.
- **Roblox Studio:** fuente de la configuración viva del DataModel y del comportamiento en Play; un inventario de Edit no incluye objetos generados en runtime.
- **GPT-6:** programador A con acceso a GitHub. Lee Source completo y diffs reales, trabaja en su rama y publica PR/commits con SHA.
- **Gemini Argon 4 Web:** programador B, desde una importación de solo lectura. Puede entregar código completo o parche con `base_commit` a Antigravity; **no afirmar sincronización en tiempo real** hasta que reimporte la rama exacta. Antigravity publica el cambio como PR; no sustituye código a mano sin comparar SHA.
- **Antigravity:** operador de integración y agente observador de Studio. Lee **todos los cambios desde el último SHA confirmado** con `git fetch`, inspecciona diffs y código completo, informa preguntas con evidencia MCP, sincroniza sólo versiones autorizadas, prueba y publica los resultados.

## Regla de actualización obligatoria antes de CADA tarea

1. Obtener estado remoto fresco (`git fetch origin --prune`; consultar las PR abiertas y su `head_sha`). Ejecutar `python tools/agent_sync/watch_repo.py --once` en Antigravity.
2. Verificar rama, `HEAD`, `origin/main`, PR objetivo, estado local y `git status --porcelain`; comparar contra el último SHA revisado. Las ramas experimentales son independientes.
3. Leer **código completo de todos los archivos afectados**, el diff completo del conjunto de commits y dependencias relevantes. No sustituir este paso por un resumen en lenguaje natural.
4. Si existe divergencia de Studio ↔ GitHub, crear respaldo y reportar SHA-256 de `Source` antes de modificar; **detener cualquier escritura destructiva**.
5. Después de revisar, registrar explícitamente el SHA leído mediante `python tools/agent_sync/watch_repo.py --ack`. `--ack` sólo certifica lectura/revisión, **no** implementación o Play PASS.
6. Si una tarea comienza con un commit diferente al observado, actualizar el contexto, descartar parches obsoletos y recalcular la estrategia.

**No hay una conexión push automática al chat de GPT ni a Gemini Web.** ChatGPT lee GitHub fresco al comenzar su siguiente tarea; Argon Web debe reimportar la rama/código correspondiente; Antigravity puede ejecutar el watcher periódicamente sólo cuando se haya configurado en el PC local.

## Comparaciones A/B de versiones competidoras

1. Elegir mismo `base_sha` estable y prueba reproducible.
2. Abrir `experiment/<sistema>-gpt6` y `experiment/<sistema>-argon4` desde **ese mismo commit**. Cada agente edita exclusivamente su rama.
3. Antigravity conserva una copia del Place y un manifiesto de archivos/atributos modificables. Antes de ensayar cada variante, restaurar el mismo estado base y verificar hashes iniciales.
4. Ejecutar la variante A, registrar commit + hash de cada Source y propiedades de Studio; ejecutar pruebas, guardar logs/capturas y evaluación del usuario.
5. Restaurar el estado base antes de probar B. Nunca mezclar archivos A y B, remotes, constraints o propiedades del DataModel.
6. Elegir con el usuario; integrar ganadora a `main` mediante PR verificada. Conservar rama y PR perdedoras para comparaciones futuras.
7. Cualquier modificación durante Play/Studio debe exportarse de vuelta a rama de GitHub antes de considerar terminado el turno.

## Entrega técnica obligatoria

Cada entrega de un programador incluye como mínimo:

```json
{
  "project": "OpenWorld Codex",
  "placeId": 100008359356261,
  "agent": "gpt6-or-argon4",
  "base_commit": "<40-char-git-sha>",
  "branch": "experiment/<task>-<agent>",
  "head_commit": "<40-char-git-sha-or-null-until-published>",
  "changed_paths": ["ruta/relativa/de/archivo.lua"],
  "studio_paths": ["ServerScriptService.WyvernFlightV2.FlightController"],
  "studio_before_sha256": {"ruta.DataModel": "<sha256-obtenido-por-MCP>"},
  "requires_datamodel_changes": false,
  "manual_playtest_required": true
}
```

Para cada archivo modificado, entregar Source **completo accesible en la rama** y diff contra `base_commit`. Los hashes de `git` no sustituyen al SHA-256 de Source observado en Studio. Distinguir siempre `not tested`, `automated test` y `user-confirmed Play`.

## Handoff de Antigravity

- Comprobar la identidad del Place en MCP por nombre + PlaceId, y `git status` limpio o cambios locales preservados.
- Traer los commits/PR nuevos, inspeccionar `git diff <old>..<new> -- <paths>` y abrir el contenido completo de las dependencias afectadas.
- Hacer backup de Source y propiedades por instancia; aplicar únicamente rutas expresamente autorizadas.
- Verificar SHA de Source tras la inyección, Output, errores y diferencia del estado del DataModel; registrar en comentario de PR o issue el `head_commit` integrado, `placeId`, `Studio ID`, `Studio Source SHA`, la prueba ejecutada y sus resultados.
- Exportar las correcciones locales a **otra rama o nuevo commit**, jamás dejarlas sólo en Studio.
- Si se modificaron propiedades, modelos, constraints, RemoteEvents o jerarquía, regenerar inventario y publicar diff del snapshot en GitHub.
- Si falla cualquier validación, revertir desde el backup y publicar bloqueo **sin afirmar que todo pasó**.

## Inventario y código canónico

`docs/studio_snapshot/current/` contiene el **snapshot archivado en Edit al 2026-10-13** de 4.064 instancias más fuentes de 84 scripts. Es evidencia de Studio en esa fecha, no un mecanismo de despliegue ni garantía de contenido de Play. Se omitió `RBX_ANIMSAVES` masivo y no se guardó el voxel Terrain/geometry binaria.

**No inyectar directamente todos los archivos de `docs/studio_snapshot/current/scripts/` en Studio**. Antes de decidir el árbol de `src/` o el mapeo de fuentes, reconciliar cada ruta real de Studio con las fuentes versionadas y con `scripts/` y `snapshots/` históricos. No reemplazar Homestead/Pasture/Flight por versiones anteriores por accidente.

## Comunicación verificable

- Una PR identifica código completo, autores, SHA base, SHA cabeza, archivos cambiados y estado de pruebas.
- Para tareas de integración/observación, abrir un GitHub Issue y enlazar la PR. Los comentarios son canal **asíncrono**; un comentario no despierta automáticamente a otro agente.
- Antigravity debe revisar cambios en `origin/main` y en las ramas experimentales activas al iniciar turno; puede automatizar una revisión horaria/minutaria local con el watcher, previa configuración en el PC del usuario.
- GPT-6 comprueba el remoto en cada nueva tarea; Argon Web debe reimportar y señalar commit importado. Nunca asumir que el chat de otro agente recibió un aviso.
