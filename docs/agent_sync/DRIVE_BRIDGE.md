# Puente GitHub → Google Drive → Gemini Argon 4

**Propósito:** proporcionar a Gemini Web una copia verificable del **código real completo** de una revisión de GitHub, sin depender del watcher de cinco minutos ni de resúmenes. No ofrece acceso directo de Gemini Web a GitHub, ni funciones de escritura en Google Drive, ni sincronización automática hacia Roblox Studio.

## Paso 0: prueba de acceso real a Drive (obligatoria)

Antigravity debe confirmar en Windows si **Google Drive para escritorio** está instalado y autenticado con la **misma cuenta** que Gemini Web usa para consultar Drive. Determinar una carpeta local realmente sincronizada (no asumir una letra de unidad). No copiar un checkout Git ni `.git` a Drive.

Crear la carpeta `OpenWorld_AgentBridge` allí. Copiar **sólo** `STATUS.md` como prueba y verificar que Drive indica sincronización terminada. En Gemini Web, pedir a Argon que busque y **abra** ese archivo; debe citar una frase real y confirmar la ruta. Si no lo encuentra, STOP: no asumir que el puente funciona.

## Paso 1: exportación bajo demanda (NO esperar cinco minutos)

En el checkout local seguro `E:\Games\clone\roblox-openworld-codex`, con cambios locales preservados:

```powershell
git fetch origin --prune
python tools/agent_sync/export_drive_context.py --ref origin/main --out "<CARPETA_LOCAL_SINCRONIZADA>\OpenWorld_AgentBridge"
```

Sustituir el valor entre comillas por la **ruta real verificada**, sin conservar los caracteres `<>`. Para ramas A/B, indicar `--ref origin/experiment/... ` y registrar también la base común.

La herramienta lee exclusivamente **blobs Git ya confirmados** en el SHA indicado (no archivos sin commit del working tree), crea:

```text
OpenWorld_AgentBridge/
├── CURRENT_SYNC_STATE.md
└── revisions/<SHA-GIT-40-HEX>/
    ├── CODE_PART_0001.md
    ├── CODE_PART_0002.md
    ├── ...
    ├── MANIFEST.json
    └── READY.json
```

Cada parte contiene **código íntegro** con la ruta y SHA-256 del Source de cada archivo; el manifiesto enumera todos los archivos y SHA individuales. Se incluyen .lua/.luau Git-tracked y documentos maestros; agregar `--inventory` para sumar los archivos JSONL del mapa DataModel. Es posible que algunas partes grandes requieran lecturas separadas dentro de Gemini.

La exportación **no comprueba la subida real a la nube**. No iniciar tarea a Argon hasta que se compruebe que **todas** las partes y los marcadores son accesibles desde su cuenta de Google Drive. Si faltan partes, STOP. El script bloquea la exportación si encuentra patrones de credenciales conocidos, pero no reemplaza auditoría de privacidad. El repo es propiedad del usuario; evitar compartir carpetas públicamente.

## Paso 2: confirmación de SHA por Gemini

La orden previa a cada turno de Argon 4 es:

> Busca `OpenWorld_AgentBridge/CURRENT_SYNC_STATE.md` en Drive y abre la revisión `revisions/<SHA>/`. Verifica que puedes leer `READY.json`, `MANIFEST.json` y las partes de código relevantes. Responde con `commitSha`, número de partes, archivos que has leído y nombre de la rama. **No programes** si el SHA de la revisión no coincide con el SHA base de tu tarea.

Un fichero `READY.json` generado localmente no certifica que Drive haya sincronizado: **la confirmación la realiza Gemini leyendo los archivos**. Si Drive indexa algunos archivos tarde, repetir lectura, nunca adivinar.

## Paso 3: publicar cambios de Argon

Gemini Web suele limitarse a lectura de Drive. Para escribir, Argon entrega `unified diff` o Source completo con `base_commit` **en su chat**; Antigravity (o GPT-6 si el usuario le proporciona la entrega) publica exactamente esos archivos en una rama GitHub aislada y PR. Si se quiere **cero copia manual**, se requiere una herramienta que sí escriba (IDE con agente Gemini, Gemini CLI o canal de entrega de archivos probado). El puente de lectura **no resuelve la escritura** por sí solo.

## Regla de no desincronización

No depender de tiempo transcurrido. Antes de cada tarea:

1. Antigravity ejecuta `git fetch origin` manual y exporta el `ref`/SHA apropiado.
2. Drive sincroniza las partes completas; Argon confirma que **leyó** el SHA correcto.
3. La tarea fija `base_commit` y `branch`. Si cambian las ramas principales durante el desarrollo, la entrega se mantiene aislada; antes de fusionar, integrar/revisar diferencias, ejecutar pruebas y documentar conflictos.
4. Antigravity no toca Studio sin comparar Source y registrar copia de seguridad; el watcher de 5 min sólo detecta cambios y sigue sirviendo de respaldo.

**No asumir conocimiento instantáneo en Gemini Web**: siempre hay un paso de consulta de Drive. No existe una latencia garantizada de Google Drive. 
