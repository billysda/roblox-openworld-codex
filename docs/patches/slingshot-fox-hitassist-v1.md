# Slingshot Fox Hit Assist v1

## Problema confirmado
El Aim Assist actual es principalmente client-side: mueve suavemente la cámara y `GetFireDirection()` apunta a un punto del Fox con una predicción corta (`PredictionTime = 0.07`, `PredictionMax = 1.5`). El hit real sigue siendo un único raycast muy fino en el servidor.

Eso permite fallos aunque la retícula parezca bloqueada, sobre todo con un Fox pequeño y en movimiento, porque:
- el cliente calcula dirección sobre una posición ligeramente anterior;
- existe latencia cliente -> servidor;
- el Fox puede desplazarse fuera del rayo fino;
- la predicción de 0.07 s es limitada y no constituye hit forgiveness.

## Objetivo
Mantener el soft-lock visual existente pero añadir una segunda capa server-authoritative de aim forgiveness SOLO cuando el jugador está usando RMB/L2 AimMode.

No es un aimbot duro: el disparo original debe pasar cerca del Fox y debe existir LOS real. El cliente NO envía ningún target.

## Nuevo ModuleScript escrito por ChatGPT
Crear exactamente:
`ServerScriptService.Homestead.M.SlingshotFoxAimAssist`

Source de referencia:
`snapshots/CodexAvanceTest_Current/ServerScriptService/Homestead/M/SlingshotFoxAimAssist.lua`

El módulo busca únicamente Models en `Workspace.PredatorRuntime` con:
`PredatorType == "Fox"`
y estado distinto de `Repelled` / `Completed`.

### Ventana de asistencia
Defaults:
- MaxWorldDistance = 145 studs
- MaxAngleDegrees = 6.0°
- BaseAssistRadius = 2.6 studs
- RadiusPerStud = 0.018
- MaxAssistRadius = 5.5 studs

El disparo solo se corrige si el vector original ya pasa suficientemente cerca del Fox.

### LOS obligatorio
Antes de corregir la dirección, el módulo hace raycast server-side desde `safeOrigin` al punto candidato. Solo acepta si la primera geometría golpeada pertenece al mismo Fox.

Una pared, roca, árbol u otra cobertura cancela la asistencia.

## Patch SlingshotController ACTUAL
No reemplazar el archivo completo.

En el lugar donde actualmente se envía:
```lua
fireRequestEvent:FireServer(origin, direction, charge)
```
reemplazar únicamente por:
```lua
fireRequestEvent:FireServer(origin, direction, charge, isAiming == true)
```

Nada más cambia en el protocolo del cliente. NO enviar `LockedModel`, Instance, nombre de Fox ni posición de target.

## Patch SlingshotService ACTUAL
Require sibling:
```lua
local SlingshotFoxAimAssist = require(script.Parent:WaitForChild("SlingshotFoxAimAssist"))
```

Cambiar firma:
```lua
function SlingshotService:Fire(player, origin, direction, charge, aimAssistRequested)
```

Después de:
```lua
local safeOrigin = self:GetSafeOrigin(player, origin)
local unitDirection = direction.Unit
```
y ANTES de calcular/raycast final, insertar:
```lua
local assistedFox = nil
local assistDebug = nil

if aimAssistRequested == true then
    local resolvedDirection, foxModel, debugInfo = SlingshotFoxAimAssist.Resolve(
        player,
        safeOrigin,
        unitDirection,
        maxRange,
        true
    )

    if typeof(resolvedDirection) == "Vector3" and resolvedDirection.Magnitude > 0.001 then
        unitDirection = resolvedDirection.Unit
    end
    assistedFox = foxModel
    assistDebug = debugInfo
end
```

Luego preservar EXACTAMENTE el raycast real existente:
```lua
local hit = Workspace:Raycast(safeOrigin, unitDirection * range, params)
```

El módulo NO decide el hit final. Solo corrige ligeramente la dirección. `Workspace:Raycast` sigue siendo la autoridad definitiva.

En `result` añadir solo para diagnóstico cliente:
```lua
AimAssistApplied = assistedFox ~= nil,
AimAssistTarget = assistedFox and assistedFox.Name or "",
```

Opcionalmente, solo con Debug.Slingshot activo, imprimir angle/missDistance de `assistDebug`.

## Setup Remote
Cambiar únicamente:
```lua
self.Remotes.FireRequest.OnServerEvent:Connect(function(player, origin, direction, charge)
    self:Fire(player, origin, direction, charge)
end)
```
a:
```lua
self.Remotes.FireRequest.OnServerEvent:Connect(function(player, origin, direction, charge, aimAssistRequested)
    self:Fire(player, origin, direction, charge, aimAssistRequested == true)
end)
```

## No cambiar
- Anime trajectory v3
- SlingshotImpactFX
- VisualTravelDuration
- Fox delayed reaction
- Infinite ammo test
- InventoryService / EggService
- FoxController / PredatorService
- target acquisition client actual
- LOS client actual
- camera soft-lock
- HUD

## Resultado esperado
### RMB/L2 + Fox cerca de la retícula
Cliente soft-lock -> envía dirección + boolean `true` -> servidor encuentra Fox dentro de una pequeña ventana -> valida LOS -> corrige algunos grados -> raycast final golpea realmente al Fox.

### Hip fire
LMB sin AimMode -> boolean false -> cero magnetismo server-side -> comportamiento actual.

### Cobertura
Si hay pared entre jugador y Fox -> módulo no corrige -> raycast normal golpea pared.

## Pruebas
1. Fox quieto + RMB: hit consistente.
2. Fox corriendo lateralmente + RMB: hit mucho más consistente que v3.
3. Apuntar claramente lejos del Fox: NO debe magnetizar.
4. Fox detrás de pared: NO debe magnetizar.
5. Hip-fire sin RMB: sin server assist.
6. ImpactFX y trayectoria anime siguen iguales.
7. Fox Rescue sigue reaccionando al arribo visual del huevo.
8. 0 RemoteEvents nuevos.
9. 0 errores rojos.
