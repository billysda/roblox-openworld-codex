# WyvernFlightV2 R4.2 — perfil MAX (intensidad extrema)

**Fecha:** 2026-10-14. **Issue:** #52. **PR:** #53. **Estado:** GitHub actualizado; pendiente aplicar a Studio y validar en Play. El usuario indicó que casi no percibe el efecto anterior y pidió subir la intensidad **al máximo**.

## Cambio exacto
Se editó **únicamente** `src/WyvernFlightV2/R42/OrganicMotionConfigR42.lua`, sin cambios de lógica cliente ni scripts R4.1. El perfil actual es deliberadamente teatral, con valores acotados: `Tail.TotalYawDegrees=90` (repartidos entre 7 huesos), `MaxMeasuredTurnRateDegPerSecond=8` (se satura antes; a ~6.1°/s la cola busca ~69° acumulados más sway), `SwayDegreesPerJoint=3`, `Neck.TotalYawDegrees=25`, `Head.MaxYawDegrees=12`, `Head.MaxPitchDegrees=6`, playback `0.65/1.00/1.45/1.80x` (freno/crucero/aceleración/boost). Es **un preset de prueba**, NO una afirmación de que el rig tolere cualquier postura sin clipping.

| Parámetro | R4.2 original | MAX |
| --- | ---: | ---: |
| Animación con freno | 0.85x | 0.65x |
| Animación crucero | 1.00x | 1.00x |
| Animación aceleración máxima | 1.10x | 1.45x |
| Animación boost | 1.20x | 1.80x |
| `Animation.ResponseSeconds` | 0.32s | 0.20s |
| `Tail.TotalYawDegrees` | 16° | 90° (suma articulada) |
| `Tail.SwayDegreesPerJoint` | 0.42° | 3.0° |
| `Tail.SwayFrequencyHz` | 0.48 Hz | 0.62 Hz |
| `Neck.TotalYawDegrees` | 4° | 25° (suma articulada) |
| `Head.MaxYawDegrees` | 1.6° | 12° |
| `Head.MaxPitchDegrees` | 0.7° | 6° |
| `MaxMeasuredTurnRateDegPerSecond` | 50°/s | 8°/s |

**Nota:** amplitudes de cola, cuello y cabeza son offsets locales relativos al Animator, NO ángulos de giro de `DT_Root`. No modificar dirección, velocidad real ni `FlightController`. El aumento de velocidad de animación acelera toda la pista original, no sólo las alas; revisar si se ve natural.

## Antigravity: actualizar solo una instancia en Studio
1. Inspeccionar último SHA remoto de PR #53 con `git fetch origin`, leer esta guía y el **Source completo** `src/WyvernFlightV2/R42/OrganicMotionConfigR42.lua`. Confirmar Studio `PlaceId=100008359356261`, estado actual y SHA del módulo instalado. No ejecutar watcher periódico.
2. **Respaldar el Source real existente del ModuleScript** `ReplicatedStorage.WyvernFlightV2.OrganicMotionConfigR42` (y SHA-256), además de conservar el respaldo R4.1 `backup/wyvern-r41-studio-pre-r42`. Si Studio contiene cambios manuales no registrados, parar y comparar.
3. En **Edit**, actualizar exclusivamente `ReplicatedStorage.WyvernFlightV2.OrganicMotionConfigR42.Source` con el Source exacto de la rama de PR #53, registrando sha256 antes/después. No alterar el LocalScript `OrganicMotionR42`, su estado de habilitación, ni la animación importada.
4. Play: observar cola y cuello lateralmente y desde la cámara real en giros ambos sentidos, vuelo recto 2 min (sin deriva acumulada), pitch ascenso/descenso, boost con aleteo hasta ~1.8x. Medir track.Speed y al menos tres `Bone.Transform` representativos. Comprobar que la cola no atraviesa el cuerpo, alas/membranas no se desgarran ni tiemblan y cabeza/cuello no rompen la silueta.
5. **Si clipping/deformación seria:** detener Play, restaurar inmediatamente el ModuleScript anterior o reducir los **valores de este mismo config** hasta el máximo visual estable; no tocar huesos/modelos ni scripts R4.1. Publicar el valor ajustado en la rama de PR #53 y pruebas que lo justifican.
6. Comparar MAX con R4.2 original y R4.1; verificar que `OrganicMotionEnabled=false` aún revierte a R4.1 y no hay duplicación de tracks. No asumir que tener un valor en GitHub modifica Studio automáticamente.
7. Publicar comentario a Issue #52 y/o PR #53 con SHA base/cabeza, SHA-256 Source Studio antes/después, Output Play, prueba visual (captura/vídeo si posible) y estado persistente en Edit. **No fusionar PR sin aprobación del usuario.**

### Rollback
- **Para volver a R4.2 anterior:** restaurar **sólo el config** de `dae39775ad26dad9a10bfdad7c0863b9b316f63a:src/WyvernFlightV2/R42/OrganicMotionConfigR42.lua` o el backup de Source Studio tomado en paso 2. No hacer `reset --hard`.
- **Para volver a comportamiento R4.1 en Play:** establecer `OrganicMotionEnabled=false` en `StarterPlayer.StarterPlayerScripts.WyvernFlightV2.OrganicMotionR42` antes de Play o deshabilitar el LocalScript. El addon actual intenta restaurar velocidad de pista y offsets propios.
