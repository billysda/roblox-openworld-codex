# Mythic Resources v0 + Codex v0

## Alcance
Primer vertical slice jugable de recursos míticos. Solo 3 recursos: `Mandrake`, `EmberBloom`, `MoonDewLotus`.

Objetivo observable:
1. ver la planta en el mundo;
2. acercarse y mantener `E`;
3. el nodo desaparece;
4. inventario de sesión +1;
5. primera recolección desbloquea la entrada en el Códice;
6. aparece toast de descubrimiento;
7. el nodo reaparece después de 15 s en esta fase de prueba.

No implementar todavía consumo por dragones, buffs PvP, recetas, investigación de nivel 2 ni DataStore.

## Arquitectura de rendimiento
No scripts dentro de plantas ni spawns. No loops por nodo. No Heartbeat/RenderStepped para recursos.

El servidor usa un solo `ProximityPromptService.PromptTriggered` global. Cada nodo es una copia anclada y sin colisión. El respawn usa `task.delay` solo después de recoger. El runtime inicial recomendado es 9-15 nodos para la prueba.

## Código escrito por ChatGPT
Rama: `feature/mythic-resources-codex-v0`

Archivos exactos:
- `snapshots/CodexAvanceTest_Current/ReplicatedStorage/MythicResourceCatalog.lua`
- `snapshots/CodexAvanceTest_Current/ServerScriptService/MythicResources/Main.server.lua`
- `snapshots/CodexAvanceTest_Current/ServerScriptService/MythicResources/M/MythicInventoryService.lua`
- `snapshots/CodexAvanceTest_Current/ServerScriptService/MythicResources/M/CodexService.lua`
- `snapshots/CodexAvanceTest_Current/ServerScriptService/MythicResources/M/MythicResourceService.lua`
- `snapshots/CodexAvanceTest_Current/StarterPlayerScripts/CodexClient.client.lua`

Transferir Sources exactos. No reescribir la lógica.

## Templates que debe aportar el usuario
Crear exactamente:

```text
ServerStorage
└─ Assets
   └─ MythicResources
      ├─ Mandrake
      ├─ EmberBloom
      └─ MoonDewLotus
```

Cada template puede ser `Model` o `MeshPart`. Recomendado: 1 Model + 1 MeshPart principal. Sin Scripts, sin Humanoid, sin constraints físicos. El servicio fuerza `Anchored=true`, `CanCollide=false`, `CanTouch=false` en los clones runtime.

Para Model, colocar el Pivot cerca de la base de la planta para que el marker represente el punto donde toca el suelo.

## Spawns
Crear:

```text
Workspace
└─ MythicResourceSpawns
```

Cada spawn es un `Part` marcador. El servicio lo vuelve invisible/no-colisionable automáticamente.

Atributos obligatorios por Part:
- `MythicResourceId` (string): `Mandrake`, `EmberBloom` o `MoonDewLotus`.

Atributos opcionales:
- `MythicSpawnId` (string): identificador único. Si falta usa `Part.Name`.
- `RespawnSeconds` (number): override del default 15.
- `Enabled` (boolean): false impide spawn.

Nombres recomendados:
- `Spawn_Mandrake_01` ...
- `Spawn_EmberBloom_01` ...
- `Spawn_MoonDewLotus_01` ...

Para prueba inicial crear 3 markers por recurso (9 nodos). No poblar el mapa completo todavía.

## Runtime
El servidor crea automáticamente:

```text
Workspace
└─ MythicResourceRuntime
```

Cada clone runtime recibe:
- `MythicRuntime = true`
- `MythicResourceId = <id>`
- `MythicSpawnId = <spawn id>`

El `ProximityPrompt` se llama `MythicCollectPrompt` y recibe los mismos ids.

## Player attributes
Solo uno en v0:
- `CodexKnownMythics` (number 0..3)

No replicar una Attribute por cada item. Los conteos individuales viajan por snapshot/delta remotos para que el sistema escale cuando existan decenas de recursos.

## Remotes
`Main.server.lua` crea automáticamente:

```text
ReplicatedStorage
└─ MythicResourceRemote
   ├─ RequestSnapshot (RemoteFunction)
   └─ StateChanged (RemoteEvent)
```

`RequestSnapshot` devuelve inventario de sesión + descubrimientos. `StateChanged` solo envía deltas de recolección al jugador correspondiente.

## StarterGui.CodexUI
Crear GuiObjects reales en `StarterGui`; `scriptsInGui = 0`.

Jerarquía exacta requerida por `CodexClient.client.lua`:

```text
CodexUI (ScreenGui)
├─ OpenButton (TextButton)
├─ MainPanel (Frame, Visible=false)
│  ├─ UICorner
│  ├─ UIStroke
│  ├─ Header (Frame)
│  │  ├─ Title (TextLabel)
│  │  └─ CloseButton (TextButton)
│  ├─ Tabs (Frame)
│  │  ├─ FloraTab (TextButton)
│  │  └─ DragonsTab (TextButton)
│  ├─ Body (Frame)
│  │  ├─ EntryList (ScrollingFrame)
│  │  │  ├─ UIListLayout
│  │  │  └─ EntryTemplate (TextButton, Visible=false)
│  │  └─ DetailPanel (Frame)
│  │     ├─ NameLabel
│  │     ├─ StatusLabel
│  │     ├─ RarityLabel
│  │     ├─ CountLabel
│  │     ├─ AffinityLabel
│  │     ├─ UsesLabel
│  │     ├─ DescriptionLabel
│  │     └─ HintLabel
│  └─ FooterHint (TextLabel)
└─ Toast (Frame, Visible=false)
   └─ TextLabel
```

### Estilo visual
Mantener lenguaje del Pasture HUD v5 sin fondos grandes raster:
- cuero oscuro base `Color3.fromRGB(50,35,24)`;
- pergamino/crema para texto principal `Color3.fromRGB(236,222,190)`;
- bronce envejecido `Color3.fromRGB(166,136,90)`;
- UICorner 5-6 px, no pastillas modernas;
- UIStroke 1-1.5 px;
- reutilizar opcionalmente `rbxassetid://86154667392432` en cuatro esquinas y `rbxassetid://89957211027855` como divider. No generar fondos raster nuevos.

### Layout recomendado
- `CodexUI.ResetOnSpawn=false`, `DisplayOrder=25`.
- `OpenButton`: AnchorPoint `(1,0.5)`, Position `UDim2.new(1,-18,0.5,0)`, Size `UDim2.fromOffset(122,42)`, Text `CÓDICE  [K]`.
- `MainPanel`: AnchorPoint `(0.5,0.5)`, Position `(0.5,0.5)`, Size `UDim2.new(0.72,0,0.72,0)` + `UISizeConstraint` min `620x420`, max `900x600`.
- Header altura 52.
- Tabs altura 38 debajo del Header.
- Body ocupa resto dejando Footer de 28.
- `EntryList`: aproximadamente 34% del ancho Body.
- `DetailPanel`: resto del ancho con padding 18.
- `EntryTemplate`: altura 42, texto alineado izquierda.
- `Toast`: top-center, Size `360x46`, Position `UDim2.new(0.5,0,0,72)`.

`DragonsTab` funciona en v0 como placeholder visible: el controlador muestra que la sección está reservada, pero no crea datos de dragones todavía.

## Controles
- `K`: abrir/cerrar Códice en PC.
- `OpenButton`: abrir/cerrar para PC/Touch.
- `CloseButton`: cerrar.

## Datos v0
### Mandrágora Ancestral
- Afinidad: Naturaleza x1.50, Tierra x1.25.
- Uso previsto: alimento de crecimiento, vitalidad.

### Flor de Brasa
- Afinidad: Fuego x1.50.
- Uso previsto: alimento elemental, dominio ofensivo.

### Loto de Rocío Lunar
- Afinidad: Agua x1.40, Hielo x1.40.
- Uso previsto: recuperación, resistencia.

Estos multiplicadores son metadata de diseño; v0 NO consume la planta ni modifica estadísticas de dragón.

## Estado de descubrimiento
Solo 2 estados en v0:
- desconocido: lista muestra `?????`; detalle oculta nombre/rareza/afinidades;
- descubierto: se revela ficha completa y conteo en bolsa.

Primera recolección: toast `NUEVO DESCUBRIMIENTO · <nombre>`.
Recolecciones siguientes: toast `+1 <nombre>`.

## Persistencia
V0 es deliberadamente SESSION-ONLY. No DataStore en esta fase. Al salir del servidor se limpian inventario y descubrimientos. Esto permite validar UX y rendimiento sin mezclar todavía migraciones de datos.

## Pruebas obligatorias
1. 9 markers / 9 runtime plants, 3 por tipo.
2. Ninguna planta contiene Script/LocalScript/ModuleScript.
3. Acercarse a Mandrake -> prompt `Recolectar / Mandrágora Ancestral`.
4. Recoger -> runtime clone desaparece, toast nuevo descubrimiento, `CodexKnownMythics=1`.
5. Abrir K -> Mandrake visible; otras 2 `?????`; count Mandrake=1.
6. Recoger segunda Mandrake -> count=2; no duplica descubrimiento.
7. A los ~15s, nodo reaparece.
8. Repetir EmberBloom y MoonDewLotus -> 3/3.
9. DragonsTab muestra placeholder y no genera errores.
10. Touch: OpenButton abre Códice.
11. `scriptsInCodexUI=0`.
12. No se tocó InventoryService/Homestead/Pasture/Predator/Slingshot/HUD v5.
13. No loops nuevos de Heartbeat/RenderStepped para recursos.
14. 0 errores rojos.

## Fuera de alcance
- DataStore/persistencia.
- alimentar dragones.
- buffs/debuffs.
- crafting/alquimia.
- investigación Codex nivel 2.
- VFX permanente en cada planta.
- poblar el mapa completo.
