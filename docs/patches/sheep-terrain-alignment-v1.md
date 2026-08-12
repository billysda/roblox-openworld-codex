# Sheep Terrain Alignment v1

Objetivo: corregir la orientación horizontal rígida de las ovejas en pendientes sin añadir raycasts nuevos ni modificar flocking, velocidades, Grazing, G/F, corral o animaciones.

## Diagnóstico confirmado

`Sheep.lua` ya hace un raycast vertical en `StepPhysics(dt)` para mantener la altura, pero descarta `result.Normal`. Además, `MoveInDirection()` y `StopMovementAndIdle()` escriben `AlignOrientation.CFrame` con `Vector3.yAxis`, por lo que el cuerpo permanece horizontal aunque el terreno esté inclinado.

Esta corrección reutiliza el mismo raycast existente y usa su normal para construir el `CFrame` de orientación.

## Valores v1

Añadir cerca de las constantes superiores de `Sheep.lua`:

```lua
local TERRAIN_TILT_MAX_DEGREES = 28
local TERRAIN_NORMAL_SMOOTHING = 10
local TERRAIN_NORMAL_MIN_Y = 0.1
```

No añadir estos valores a `Cfg.lua` todavía. Primero validar visualmente.

## Estado por oveja

En `Sheep.new`, después de inicializar `self.HeightFiltered`, añadir:

```lua
self.GroundNormal = Vector3.yAxis
self.FacingDirection = getFlatDirection(self.Root.CFrame.LookVector) or Vector3.new(0, 0, -1)
```

## Helpers nuevos

Añadir antes de `Sheep:MoveInDirection`:

```lua
function Sheep:ClampGroundNormal(normal)
	if typeof(normal) ~= "Vector3" or normal.Magnitude < 0.001 then
		return Vector3.yAxis
	end

	local target = normal.Unit
	if target.Y < 0 then
		target = -target
	end

	local worldUp = Vector3.yAxis
	local maxAngle = math.rad(TERRAIN_TILT_MAX_DEGREES)
	local angle = math.acos(math.clamp(worldUp:Dot(target), -1, 1))

	if angle <= maxAngle then
		return target
	end

	local axis = worldUp:Cross(target)
	if axis.Magnitude < 0.001 then
		return worldUp
	end

	return CFrame.fromAxisAngle(axis.Unit, maxAngle):VectorToWorldSpace(worldUp).Unit
end

function Sheep:UpdateGroundNormal(rawNormal, dt)
	if typeof(rawNormal) ~= "Vector3" or rawNormal.Magnitude < 0.001 then
		return
	end

	if rawNormal.Y < TERRAIN_NORMAL_MIN_Y then
		return
	end

	local target = self:ClampGroundNormal(rawNormal)
	local current = self.GroundNormal or Vector3.yAxis
	local alpha = 1 - math.exp(-TERRAIN_NORMAL_SMOOTHING * math.max(dt or 0, 0))
	local blended = current:Lerp(target, math.clamp(alpha, 0, 1))

	if blended.Magnitude > 0.001 then
		self.GroundNormal = blended.Unit
	else
		self.GroundNormal = target
	end
end

function Sheep:UpdateTerrainOrientation()
	if not self.AlignOrientation or not self.Root then
		return
	end

	local facing = getFlatDirection(self.FacingDirection or self.Root.CFrame.LookVector)
	if not facing then
		return
	end

	local up = self.GroundNormal or Vector3.yAxis
	local projectedForward = facing - up * facing:Dot(up)

	if projectedForward.Magnitude < 0.001 then
		projectedForward = facing
	end

	self.AlignOrientation.CFrame = CFrame.lookAt(
		Vector3.zero,
		projectedForward.Unit,
		up
	)
end
```

## Cambio en MoveInDirection

Encontrar la escritura actual equivalente a:

```lua
self.AlignOrientation.CFrame = CFrame.lookAt(Vector3.zero, finalDirection, Vector3.yAxis)
```

Reemplazarla únicamente por:

```lua
self.FacingDirection = finalDirection
```

No cambiar `LinearVelocity.VectorVelocity` ni el resto de la función.

## Cambio en StopMovementAndIdle

Encontrar:

```lua
local lookDirection = getFlatDirection(self.Root.CFrame.LookVector)

if lookDirection then
	self.AlignOrientation.CFrame = CFrame.lookAt(Vector3.zero, lookDirection, Vector3.yAxis)
end
```

Reemplazar por:

```lua
local lookDirection = getFlatDirection(self.Root.CFrame.LookVector)

if lookDirection then
	self.FacingDirection = lookDirection
end
```

## Cambio en StepPhysics

Dentro de:

```lua
if result then
```

antes de calcular o aplicar la fuerza de hover, añadir:

```lua
self:UpdateGroundNormal(result.Normal, dt)
```

Después del bloque completo `if result then ... else ... end`, ejecutar siempre:

```lua
self:UpdateTerrainOrientation()
```

El raycast actual sigue siendo el único raycast de suelo usado por este sistema.

## Comportamiento esperado

- terreno plano: oveja casi horizontal;
- subida: pitch hacia arriba siguiendo la pendiente;
- bajada: pitch hacia abajo;
- pendiente lateral: roll suave;
- cambios de normal: suavizados, sin snap;
- inclinaciones extremas: limitadas a 28 grados;
- si el raycast no encuentra suelo durante un instante: conservar la última normal válida, evitando oscilación hacia horizontal;
- movimiento permanece horizontal en X/Z y el sistema Hover actual sigue controlando Y.

## Restricciones

No modificar:

- Flock.lua
- GrazingService.lua
- Cfg.lua
- Pasture.Main
- Predator/Fox
- Homestead
- corral/PenEntrance
- G/F
- animaciones
- audio

No añadir raycasts secundarios ni loops nuevos.

## Validación requerida

1. Plano: sin inclinación visible incorrecta.
2. Pendiente de 10–15°: cuerpo acompaña suavemente.
3. Pendiente de 20–30°: cuerpo acompaña sin jitter fuerte.
4. Cambio plano -> pendiente -> plano: transición suave.
5. Subir y bajar la misma pendiente: pitch cambia de signo correctamente.
6. Caminar transversalmente por una ladera: roll coherente.
7. Idle sobre pendiente: mantiene orientación del terreno.
8. Run/PanicMove: sigue inclinación también al correr.
9. G, F, Grazing y corral conservan comportamiento.
10. Fox Predator v0 no cambia.
11. 0 errores rojos.
