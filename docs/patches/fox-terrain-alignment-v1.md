# Fox Terrain Alignment v1

## Objetivo
Aplicar al Fox Predator v0 el mismo principio visual/físico ya validado en las ovejas: el cuerpo debe acompañar suavemente la inclinación del terreno al perseguir, atacar, huir y permanecer detenido, sin añadir raycasts nuevos ni alterar la locomoción horizontal existente.

## Archivo objetivo
`ServerScriptService.Predator.M.FoxController`

La transferencia debe hacerse de forma quirúrgica sobre el Source ACTUAL de Roblox Studio. No reemplazar el archivo completo desde una rama antigua.

## Diagnóstico actual
`FoxController:Move()` fuerza actualmente:

```lua
self.AlignOrientation.CFrame = CFrame.lookAt(Vector3.zero, dir, Vector3.yAxis)
```

Eso obliga al eje UP del Fox a permanecer vertical respecto al mundo. `StepPhysics(dt)` ya ejecuta el raycast de suelo y recibe `result.Normal`, pero actualmente solo usa `result.Distance` para el hover.

## 1. Constantes
Añadir inmediatamente después de `FoxController.__index = FoxController`:

```lua
local FOX_TERRAIN_TILT_MAX_DEGREES = 28
local FOX_TERRAIN_NORMAL_SMOOTHING = 10
local FOX_TERRAIN_NORMAL_MIN_Y = 0.1
```

## 2. Estado por Fox
En `FoxController.new`, después de:

```lua
self.CurrentMoveTrack = nil
```

añadir exactamente:

```lua
self.GroundNormal = Vector3.yAxis
self.FacingDirection = nil
```

Después de validar que `self.Root` existe y antes de `self:SetupModel()`, añadir:

```lua
self.FacingDirection = flatDirection(self.Root.CFrame.LookVector) or Vector3.new(0, 0, -1)
```

## 3. Helpers de terreno
Añadir estos métodos antes de `FoxController:StopTrack()`:

```lua
function FoxController:ClampGroundNormal(normal)
	if typeof(normal) ~= "Vector3" or normal.Magnitude <= 0.001 then
		return Vector3.yAxis
	end

	local unit = normal.Unit
	if unit.Y < 0 then
		unit = -unit
	end

	if unit.Y < FOX_TERRAIN_NORMAL_MIN_Y then
		return Vector3.yAxis
	end

	local maxRadians = math.rad(FOX_TERRAIN_TILT_MAX_DEGREES)
	local angle = math.acos(math.clamp(unit:Dot(Vector3.yAxis), -1, 1))
	if angle <= maxRadians then
		return unit
	end

	local horizontal = Vector3.new(unit.X, 0, unit.Z)
	if horizontal.Magnitude <= 0.001 then
		return Vector3.yAxis
	end

	return (
		Vector3.yAxis * math.cos(maxRadians)
		+ horizontal.Unit * math.sin(maxRadians)
	).Unit
end

function FoxController:UpdateGroundNormal(rawNormal, dt)
	local target = self:ClampGroundNormal(rawNormal)
	local current = self:ClampGroundNormal(self.GroundNormal or Vector3.yAxis)
	local alpha = 1 - math.exp(-FOX_TERRAIN_NORMAL_SMOOTHING * math.max(dt or 0, 0))
	self.GroundNormal = self:ClampGroundNormal(current:Lerp(target, math.clamp(alpha, 0, 1)))
end

function FoxController:UpdateTerrainOrientation()
	if not self.AlignOrientation then
		return
	end

	local up = self:ClampGroundNormal(self.GroundNormal or Vector3.yAxis)
	local facing = flatDirection(self.FacingDirection or self.Root.CFrame.LookVector)
	if not facing then
		return
	end

	local projectedForward = facing - up * facing:Dot(up)
	if projectedForward.Magnitude <= 0.001 then
		local fallback = self.Root.CFrame.LookVector
		projectedForward = fallback - up * fallback:Dot(up)
	end

	if projectedForward.Magnitude <= 0.001 then
		return
	end

	self.AlignOrientation.CFrame = CFrame.lookAt(
		Vector3.zero,
		projectedForward.Unit,
		up
	)
end
```

## 4. Move()
En `FoxController:Move(direction, speed, trackName)`, conservar el cálculo de `dir` y `LinearVelocity` horizontal.

Reemplazar únicamente:

```lua
self.AlignOrientation.CFrame = CFrame.lookAt(Vector3.zero, dir, Vector3.yAxis)
```

por:

```lua
self.FacingDirection = dir
```

No llamar `UpdateTerrainOrientation()` desde `Move()`. La orientación se actualiza desde el ciclo de física para que el suavizado de la normal tenga una cadencia estable.

## 5. StepPhysics(dt)
Dentro del bloque `if result then`, antes o después del cálculo de hover, añadir exactamente:

```lua
self:UpdateGroundNormal(result.Normal, dt)
```

Después del bloque completo `if result then ... else ... end` del hover, añadir:

```lua
self:UpdateTerrainOrientation()
```

Debe quedar conceptualmente:

```lua
if result then
	self:UpdateGroundNormal(result.Normal, dt)
	-- hover existente, sin cambios
else
	self.HoverForce.Force = Vector3.zero
end

self:UpdateTerrainOrientation()
```

No crear un raycast adicional. El único origen de la normal debe ser el `Workspace:Raycast()` ya existente en `StepPhysics(dt)`.

## 6. Estados cubiertos
Este cambio debe afectar automáticamente:

- Chase / Run;
- Pounce mientras `Move()` siga actualizando la dirección hacia el objetivo;
- Carry / Flee;
- Fox detenido sin target, conservando la última dirección frontal mientras la normal del terreno sigue actualizándose.

No modificar animaciones, velocidad, pounce timing, captura ni `SheepCarryAttachment`.

## 7. Restricciones
No modificar:

- `PredatorCfg`;
- `CaptureService`;
- `PredatorService`;
- `Pasture`;
- `Sheep.lua`;
- Flock/Grazing;
- G/F;
- corral;
- Homestead;
- audio;
- FoxTemplate estructural;
- IDs de animación.

## 8. Pruebas obligatorias

1. Plano: Fox estable y horizontal.
2. Persecución cuesta arriba: pitch acompaña la pendiente.
3. Persecución cuesta abajo: pitch acompaña la pendiente.
4. Carrera transversal en ladera: roll coherente.
5. Transición plano -> pendiente -> plano: sin snap importante.
6. Pounce en pendiente: mantiene orientación coherente sin romper AttackFox1.
7. Carry/Flee en pendiente: Fox y oveja transportada siguen funcionando.
8. Fox detenido sobre pendiente: conserva la inclinación.
9. Inclinaciones superiores a 28°: orientación visual limitada a 28°.
10. No se añadieron raycasts.
11. Spawn/chase/pounce/grab/flee del Issue #22 siguen funcionando.
12. 0 errores rojos.

## Resultado esperado
El Fox debe reaccionar al terreno con la misma filosofía visual ya aprobada para las ovejas: normal suavizada, máximo 28°, orientación tangente al suelo y locomoción X/Z sin cambios.
