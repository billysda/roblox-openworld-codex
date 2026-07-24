# Grazing v1: zona semialeatoria, asistencia suave y anillo adaptado al terreno

Implementación preparada en la rama:

`feature/grazing-v1-assisted-terrain`

Commits principales:

- `85225fad191ee11e20b0c58d5cdf5d25d110b0d2` — configuración.
- `9d8dabc914ded8ac8b78064999bc50b8843f5c15` — lógica y visual de la zona.

## Objetivo

Mejorar la zona de pastoreo sin convertirla en un imán global:

- radio lógico de 23 studs;
- el jugador lleva el rebaño hasta la zona;
- cuando al menos una oveja entra, las restantes que estén como máximo 10 studs fuera del borde reciben una guía suave;
- la ayuda nunca reemplaza una orden G/F activa;
- para 2 ovejas siguen siendo necesarias las 2; en rebaños mayores se requiere aproximadamente el 75%;
- una salida breve no pausa inmediatamente el consumo: gracia de 1.75 segundos;
- el disco sólido se reemplaza visualmente por un anillo de segmentos ajustados individualmente al terreno;
- la posición se elige primero desde puntos validados opcionales y, si no existen, mediante muestreo procedural con rechazo de pendientes/desniveles excesivos.

## Configuración implementada

`Cfg.Grazing` incluye valores equivalentes a:

```lua
ZoneRadius = 23,
RequireAllSheep = false,
RequiredFraction = 0.75,
MinSheepInside = 2,
ExitGraceSeconds = 1.75,

AssistEnabled = true,
AssistDistance = 10,
AssistSpeed = 6.5,
AssistInnerPadding = 5,
AssistRefreshDuration = 0.65,

PointsFolder = "PastureGrazingPoints",
CandidateAttempts = 16,
TerrainSampleCount = 8,
MaxTerrainHeightSpread = 6,
MinGroundNormalY = 0.78,

RingSegments = 32,
RingThickness = 0.85,
RingHeight = 0.12,
RingYOffset = 0.12,
```

También se conservan en `Cfg.Pen` los valores de la ruta del issue #15:

```lua
CommandEntranceDistance = 7,
CommandCenterDistance = 6,
```

## Conteo requerido

El número requerido se calcula por fracción, limitado por el tamaño real del rebaño activo:

- 1 activa -> 1 requerida;
- 2 activas -> 2 requeridas;
- 4 activas -> 3 requeridas;
- 8 activas -> 6 requeridas.

Una oveja capturada ya no hace imposible completar la actividad: el requisito se ajusta al número de ovejas activas.

## Gracia de salida

Cada zona mantiene `QualifiedUntil`.

Cuando se alcanza el número requerido, se renueva una ventana de 1.75 segundos. Si una oveja pisa fuera brevemente, el consumo continúa durante esa ventana. Si permanece fuera más tiempo, el progreso se pausa, pero no se reinicia.

El jugador recibe el atributo de diagnóstico:

```text
PastureGraceActive
```

## Asistencia suave

La asistencia se implementa exclusivamente desde `GrazingService`, reutilizando el movimiento tranquilo ya existente de cada objeto `Sheep`.

No fue necesario modificar `Sheep.lua`.

Condiciones:

- al menos una oveja ya está dentro;
- todavía falta alguna para alcanzar el requisito;
- la oveja asistida está fuera del círculo pero a no más de 10 studs del borde;
- no existe G, F ni otro movimiento activo del rebaño;
- la oveja no está capturada ni marcada como `JustReleased`.

Cada oveja recibe un destino interior distinto calculado con ángulo dorado. Durante la ayuda se usan:

```text
GrazingAssistActive
GrazingAssistTarget
CalmMoveState = GrazingAssist
```

Cuando las condiciones dejan de cumplirse, `GrazingService` limpia únicamente el movimiento tranquilo que él mismo había creado.

## Visual adaptado al terreno

`GrazingZone` continúa existiendo como Part lógica invisible (`Transparency = 1`) para no romper la lectura existente de `Flock`.

El visual real es un folder `TerrainRing` con 32 segmentos:

1. cada segmento calcula su punto de la circunferencia;
2. hace su propio raycast vertical;
3. se coloca sobre el suelo;
4. se orienta usando la normal del terreno;
5. conserva el material Neon y los estados de transparencia activos/pulsantes.

Ya no se muestra un disco relleno atravesando lomas o caminos.

## Elección semialeatoria segura

Primero se buscan BaseParts bajo:

`Workspace.PastureGrazingPoints`

Un punto puede usar `HouseId`; nil o 0 significa global. Se evita repetir inmediatamente el último punto del jugador.

Cuando la carpeta no existe o no ofrece un punto válido, se prueban hasta 16 posiciones procedurales entre `ZoneDistanceMin` y `ZoneDistanceMax`.

Cada candidato se comprueba en el centro y alrededor del perímetro. Se rechaza cuando:

- falta suelo en alguna muestra;
- la pendiente supera `MinGroundNormalY`;
- la diferencia de alturas supera `MaxTerrainHeightSpread`.

Si ningún candidato pasa por completo, se usa el mejor encontrado y se imprime una advertencia de diagnóstico.

## Archivos modificados por ChatGPT

- `snapshots/CodexAvanceTest_Current/ServerScriptService/Pasture/M/Cfg.lua`
- `snapshots/CodexAvanceTest_Current/ServerScriptService/Pasture/M/GrazingService.lua`
- este documento.

No se modificaron:

- `Sheep.lua`;
- `Flock.lua`;
- corral o `PenEntrance`;
- puertas;
- Bastón;
- Homestead;
- Workspace.

Antigravity debe copiar exactamente `Cfg.lua` y `GrazingService.lua` desde esta rama al DataModel actual, sin reemplazar el `Flock.lua` del issue #15.

## Pruebas

1. 0/2 dentro: ninguna oveja es atraída.
2. 1/2 dentro y la segunda a <=10 studs fuera del borde: recibe guía suave.
3. Segunda más lejos: no recibe ayuda.
4. G/F activa: la asistencia no reemplaza la orden.
5. 2/2 dentro: comienza el consumo.
6. Una oveja sale brevemente: la actividad continúa hasta 1.75 s.
7. Sale más tiempo: el progreso se pausa, pero no se reinicia.
8. El anillo sigue la pendiente y no aparece un disco atravesando terreno.
9. La zona evita pendientes/desniveles excesivos cuando encuentra alternativas.
10. Corral y ruta PenEntrance continúan funcionando sin cambios.
