# Grazing v1: asistencia suave y wisps adaptados al suelo

Implementación preparada en:

`feature/grazing-wisps-visual`

Base conservada:

`feature/grazing-v1-assisted-terrain`

## Resultado

La lógica de pastoreo permanece igual:

- radio lógico invisible de 23 studs;
- 0/2 dentro: no hay atracción;
- 1/2 dentro: la oveja restante recibe ayuda solo si está como máximo 10 studs fuera del borde;
- G, F y el movimiento normal del rebaño tienen prioridad;
- 2 ovejas requieren 2; rebaños mayores requieren aproximadamente 75%;
- gracia de salida de 1.75 segundos;
- progreso pausado, no reiniciado, cuando deja de cumplirse el requisito.

Solo se reemplaza la representación visual.

## Visual anterior retirado

Se elimina `TerrainRing`:

- 32 Parts rectangulares;
- borde geométrico visible y partido;
- riesgo de segmentos flotantes;
- Tweens individuales por segmento;
- apariencia de círculo matemático sobre terreno natural.

## Visual nuevo

Cada zona crea:

- una Part lógica invisible llamada `GrazingZone`;
- una sola Part invisible llamada `GrazingWispAnchor`;
- 12 Attachments distribuidos de forma orgánica cerca del borde;
- un ParticleEmitter de baja tasa por Attachment;
- la etiqueta de progreso existente.

Los 12 puntos hacen raycast individual al crearse y quedan colocados sobre el suelo. El radio de cada punto tiene una variación determinista, por lo que el área visible no intenta formar una circunferencia perfecta.

Las partículas usan una textura incorporada de Roblox:

`rbxasset://textures/particles/smoke_main.dds`

No se necesitan modelos, paquetes externos, PointLights ni assets subidos por el usuario.

## Estados visuales

`idle`:

- emisión baja;
- verde suave;
- movimiento vertical lento.

`active`:

- una o más ovejas dentro;
- emisión ligeramente mayor;
- verde más vivo.

`qualified`:

- requisito alcanzado o dentro de la gracia;
- emisión más visible;
- mezcla verde/amarilla.

Los cambios de estado modifican directamente `Rate`, `Speed` y `Color`. No se crean Tweens.

## Coste aproximado por zona

Visual nuevo:

- 1 Part de anclaje;
- 12 Attachments;
- 12 ParticleEmitters;
- tasas entre 0.55 y 1.45 partículas por segundo por emisor;
- aproximadamente 8 partículas vivas en reposo y cerca de 20–24 al completar.

Esto reemplaza 32 Parts visibles y 32 Tweens por pulso.

## Configuración

Los valores principales están en `Cfg.Grazing`:

```lua
WispCount = 12,
WispRadiusScale = 0.92,
WispRadiusJitter = 1.8,
WispYOffset = 0.08,
WispRateIdle = 0.55,
WispRateActive = 0.95,
WispRateQualified = 1.45,
WispLifetimeMin = 0.85,
WispLifetimeMax = 1.35,
WispSize = 1.45,
```

## Archivos modificados

- `snapshots/CodexAvanceTest_Current/ServerScriptService/Pasture/M/Cfg.lua`
- `snapshots/CodexAvanceTest_Current/ServerScriptService/Pasture/M/GrazingService.lua`
- `docs/grazing-v1-design.md`

No se modificaron:

- `Flock.lua`;
- `Sheep.lua`;
- `Main.lua`;
- corral, puerta o `PenEntrance`;
- casas;
- Bastón;
- Homestead;
- Workspace persistente.

## Pruebas obligatorias en Studio

1. Confirmar que no existe `TerrainRing` en la zona runtime.
2. Confirmar que existe `GrazingWispAnchor` con 12 Attachments.
3. Revisar que los puntos nacen desde el suelo en terreno irregular.
4. Confirmar que la apariencia es orgánica y no un círculo perfecto.
5. Confirmar que no hay PointLights.
6. Confirmar que no se crean Tweens repetitivos.
7. Probar 0/2, 1/2 y 2/2.
8. Probar prioridad de G y F.
9. Probar la gracia de 1.75 segundos.
10. Confirmar que la ruta del corral por `PenEntrance` continúa intacta.
11. Confirmar ausencia de errores rojos en Output.
