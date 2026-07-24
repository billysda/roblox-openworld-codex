# Grazing v1: zona semialeatoria, asistencia suave y anillo adaptado al terreno

Diseño aprobado para implementar sobre `feature/pasture-command-target-v0`.

## Objetivo

Mejorar la zona de pastoreo sin convertirla en un imán global:

- radio lógico de 23 studs;
- el jugador lleva el rebaño hasta la zona;
- cuando al menos una oveja entra, las ovejas restantes que estén como máximo 10 studs fuera del borde reciben una guía suave hacia puntos interiores distintos;
- la ayuda nunca reemplaza una orden G/F activa;
- para 2 ovejas siguen siendo necesarias las 2; en rebaños mayores se requiere aproximadamente el 75%;
- una salida breve no pausa inmediatamente el consumo: gracia de 1.75 segundos;
- el disco sólido se reemplaza visualmente por un anillo de segmentos ajustados individualmente al terreno;
- la posición se elige primero desde puntos validados opcionales y, si no existen, mediante muestreo procedural con rechazo de pendientes/desniveles excesivos.

## Configuración esperada

Extender `Cfg.Grazing` con valores equivalentes a:

```lua
ZoneRadius = 23,
RequireAllSheep = false,
RequiredFraction = 0.75,
MinSheepInside = 2,

AssistEnabled = true,
AssistDistance = 10,
AssistSpeed = 6.5,
AssistInnerPadding = 5,
ExitGraceSeconds = 1.75,

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

## Conteo requerido

Reemplazar el cálculo actual por:

```lua
local fraction = Cfg.Grazing.RequiredFraction or 0.75
local fractionalRequired = math.ceil(activeSheepCount * fraction)
local requestedMinimum = Cfg.Grazing.MinSheepInside or 1
local requiredCount = math.max(requestedMinimum, fractionalRequired)
requiredCount = math.clamp(requiredCount, 1, math.max(activeSheepCount, 1))
```

Resultados:

- 1 activa -> 1 requerida;
- 2 activas -> 2 requeridas;
- 4 activas -> 3 requeridas;
- 8 activas -> 6 requeridas.

## Gracia de salida

Cada `zoneData` debe incluir `QualifiedUntil = 0`.

Cuando `insideCount >= requiredCount`:

```lua
zoneData.QualifiedUntil = os.clock() + (Cfg.Grazing.ExitGraceSeconds or 1.75)
```

La zona cuenta como apta mientras:

```lua
local qualified = insideCount >= requiredCount
	or os.clock() <= (zoneData.QualifiedUntil or 0)
```

Durante la gracia el pasto sigue avanzando. Añadir atributo de jugador `PastureGraceActive` para diagnóstico.

## Asistencia suave por oveja

`GrazingService` debe limpiar y escribir estos atributos en cada modelo de oveja:

```text
GrazingAssistActive: boolean
GrazingAssistTarget: Vector3
```

La asistencia solo se activa cuando:

- `Cfg.Grazing.AssistEnabled` es true;
- al menos una oveja ya está dentro;
- todavía no se alcanza el número requerido;
- la oveja asistida está fuera del radio;
- su distancia al centro es menor o igual a `ZoneRadius + AssistDistance`.

Cada oveja debe recibir un punto interior distinto y estable calculado desde `sheep.Index`, no todas el centro. Usar un ángulo dorado o equivalente y limitar el destino a `ZoneRadius - AssistInnerPadding`.

Al completar/destruir la zona, liberar jugador, capturar una oveja o dejar de cumplir las condiciones, establecer `GrazingAssistActive=false` y eliminar `GrazingAssistTarget`.

## Sheep.lua

En el bloque de GrazingZone, antes del rebote interno, leer los atributos. Solo obedecer la asistencia cuando:

```lua
not movementRequested
and not commandActive
and not self.Model:GetAttribute("JustReleased")
```

Si `GrazingAssistActive == true` y `GrazingAssistTarget` es Vector3:

```lua
local toTarget = getFlatDirection(assistTarget - self.Root.Position)
if toTarget then
	self.CalmDirection = nil
	self.CalmMoveUntil = 0
	self.CalmChosenSpeed = nil
	self:ResetMovementReaction()
	self:MoveInDirection(toTarget, Cfg.Grazing.AssistSpeed or 6.5, "GrazingAssist")
	return
end
```

Conservar el rebote interno existente para ovejas que ya están dentro.

## Visual adaptado al terreno

`GrazingZone` permanece como Part lógica invisible (`Transparency=1`) porque el conteo usa distancia horizontal.

Crear un folder `TerrainRing` con 32 segmentos no colisionables. Para cada segmento:

1. calcular su punto sobre la circunferencia;
2. lanzar un raycast vertical individual;
3. colocar el segmento sobre el resultado + `RingYOffset`;
4. orientarlo tangente al anillo;
5. usar Material Neon y el verde actual.

El pulso y estado activo deben cambiar la transparencia de los segmentos, no del disco lógico. No crear un disco relleno visible.

## Elección semialeatoria segura

Primero buscar BaseParts bajo `Workspace.PastureGrazingPoints`. Un punto puede tener atributo `HouseId`; nil/0 significa global. Elegir uno compatible y evitar repetir inmediatamente el último punto del jugador.

Cuando la carpeta no exista o no tenga puntos compatibles, probar hasta `CandidateAttempts` posiciones procedurales entre `ZoneDistanceMin` y `ZoneDistanceMax`.

Para aceptar una posición:

- raycast en el centro y en `TerrainSampleCount` puntos del perímetro;
- todos deben encontrar suelo;
- ningún `Normal.Y` puede ser menor que `MinGroundNormalY`;
- la diferencia entre altura máxima y mínima no puede superar `MaxTerrainHeightSpread`.

Si ningún intento pasa, usar el mejor candidato encontrado y emitir un warning de diagnóstico, sin bloquear la creación de la zona.

## Archivos autorizados

- `ServerScriptService.Pasture.M.Cfg`
- `ServerScriptService.Pasture.M.GrazingService`
- `ServerScriptService.Pasture.M.Sheep`
- copias correspondientes en snapshot
- `MANIFEST.md`
- `STATUS.md`

No modificar Flock, corral, PenEntrance, puertas, Bastón, Homestead ni Workspace en esta fase.

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
