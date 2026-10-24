# Gran Wyvern de Tierra — v0.2.3, CONTACTO FÍSICO PERMANENTE Y TERRENO

**Rama:** `fix/wyvern-tierra-physics-v023`
**Base:** `audit/wyvern-r41-mouse-control-regression`
**Modelo:** `Workspace.wyvernfbx`; **Place ID:** `100008359356261`
**ESTADO:** Implementado en 3 scripts físicos GitHub, **NO probado en Play Mode**; no publicar, ni hacer merge todavía.

## Por qué existe la versión

El usuario comprobó flotación aparente en Idle2/Run, cambios no deseados a FLIGHT en crestas, hundimiento al perder suelo y falta de estabilidad en mundo abierto. La captura compartida tenía estado CRUISE, no demuestra el apoyo de patas en tierra; hay que medir huesos animados y contacto real en Play Mode.

En la v0.2.2:
- `DT_TorsoCollisionV022`: esfera de diámetro 3 studs, offset local Y=+0.35; **CanCollide=false** en vuelo, aproximación, aterrizaje y despegue; **true** solo en estados terrestres.
- `GroundV01` imponía apoyo vertical por `VectorForce` PD calculado a `RestRootHeight=1.798`; altura nominal de cara inferior de esfera ≈0.65 studs por encima de plataforma, permitiendo flotar sin tocar.
- `sensor.valid` exigía centro+apoyo delantero+trasero+plano, por lo que podía ser falso en crestas aunque hubiese terreno cercano. Tras 0.4s se cambiaba a `GROUND_RECOVERY` y tras +1s saltaba a `FLIGHT`.

## Cambios exactos v0.2.3

1. `src/WyvernFlightV2/LandingV022/GroundCollisionV022.lua`
   - `DT_TorsoCollisionV022` **CanCollide=true permanentemente en todos los estados, incluso FLIGHT**. `SetActive(...)` es compatibilidad y ya no lo desactiva.
   - Esfera 3×3×3 studs, offset local (0,-0.27,0), altura de contacto objetivo en llano `1.77` studs sobre suelo. Despeje nominal respecto a base anterior ≈0.028 studs.
   - Propiedades físicas `Friction=0.85, Elasticity=0`; Massless y soldadura al `DT_Root`; resto de mallas, RootPart y DT_GroundCollider originales sin colisión.
   - Solo se rehace el weld **del proxy existente** para corregir su desplazamiento al principio del Play aislado. **No tocar `DT_RootWeld`, `DT_NeckSeatWeld` ni Motor6D**.
   - PELIGRO/limitación: esfera sola no abarca pies, alas y cola; mantenerla sólida en vuelo puede introducir contactos nuevos. Probar aproximación a terreno, paredes y despegue y rechazar la versión si rompe el vuelo.

2. `src/WyvernFlightV2/LandingV01/WyvernGroundV01.lua`
   - `RestRootHeight=1.77` para concordar con el cuerpo físico. `VectorForce` siempre inactivo, sin sustentación artificial; gravedad+suelo deben sostener el dragón.
   - Raycasts conservan condición estricta `valid` para identificar superficie **aterrizable**.
   - Expone `nearGround`, `nearHitCount`, `nearestClearance`, `nearNormal` aunque el suelo NO sea válido para aterrizar. Se admite contacto próximo aislado sobre crestas, sin exigir siempre apoyo delantero y trasero.
   - `Spherecast` anticipatorio ajusta centro/radio al proxy real (local Y=-0.27, radio 1.5).

3. `src/WyvernFlightV2/LandingV01/FlightController.server.lua`
   - Límite horizontal de fuerza `min(250000, max(350, AssemblyMass*90))`, por eje X/Z en estado terrestre, fuerza vertical cero; no modificar fuerzas aéreas existentes.
   - `GROUND_RECOVERY` NO transiciona automáticamente a `FLIGHT` por temporizador. Respeta gravedad durante ausencia de suelo; intenta recuperar estado de tierra cuando existe superficie cercana y velocidad vertical moderada. **Space** inicia TAKEOFF deliberado.
   - Gracia aumentada a `0.65s` basada en suelo *cercano*, no en condición de aterrizaje estricta.
   - Orientación del cuerpo sigue la normal de terreno promediada con interpolación, limitada inicialmente a **12°** de inclinación corporal para prevenir vuelcos. La inclinación limitada NO garantiza que todas las garras apoyen en pendientes fuertes: evaluar IK posteriormente.
   - Durante `LANDING`, al llegar a `clearance<=0.75`, cede la componente vertical a gravedad/colisión para no presionar el collider hacia el piso. No se cambia la salida original TAKEOFF/FLIGHT.
   - Telemetría añadida a DT_Root: `Wyvern_NearGround`, `Wyvern_NearHitCount`, `Wyvern_NearestGroundClearance`, `Wyvern_AlwaysCollidable`, `Wyvern_PhysicalSupportOnly`, `Wyvern_GroundRecoveryTime`.
   - En `GROUND_RECOVERY` prolongado no hay despegue automático; el dragón puede caer al vacío indefinidamente hasta pulsar Space o recontactar terreno. Es una decisión temporal para quitar el bug de vuelo involuntario; probar gameplay real.

## CRÍTICO: RECONCILIAR CON EL STUDIO VIVO, NO SOBREESCRIBIRLO

Antigravity reparó recientemente por separado:
- `StarterPlayerScripts.WyvernFlightV2.Input`: cálculo de yaw/pitch canónico R4.1 validado; repositorio puede contener un snapshot antiguo.
- `FlightCamera` y el singleton `ReplicatedStorage.WyvernFlightV2.FlightAimState`: cámara y giro recuperados.
- `ServerScriptService.WyvernFlightV2.FlightAnimationServerV022`: Idle2/Run restauradas temporalmente con KeyframeSequence, publicables solo al tener IDs numéricos.

**Prohibido** sustituir o modificar estos 4 sistemas al integrar v0.2.3. Los cambios locales aún pueden no estar publicados en rama remota. Exportar Source/hashes de TODOS los scripts vivos ANTES de integrar. El FlightController puede contener mejoras locales: combinar las diferencias de física, no reemplazar completo si difiere. Todo trabajo en copia del Place, luego revertir/proteger copia original.

### Archivos a instalar (SOLO TRES)

| Código GitHub | Instancia existente en Studio |
|---|---|
| `src/WyvernFlightV2/LandingV022/GroundCollisionV022.lua` | `ServerScriptService.WyvernFlightV2.GroundCollisionV022` |
| `src/WyvernFlightV2/LandingV01/WyvernGroundV01.lua` | `ServerScriptService.WyvernFlightV2.WyvernGroundV01` |
| `src/WyvernFlightV2/LandingV01/FlightController.server.lua` | `ServerScriptService.WyvernFlightV2.FlightController` |

Solo para medición en la copia: `tools/wyvern_terrain_validation_v023.server.lua` -> Script temporal `ServerScriptService.WyvernTerrainValidationV023`. No lo dejar en producción.

## Test A/B reproducible

- A: Place v0.2.2, misma plataforma/pendiente/desnivel, W 30, Shift+W 39, Idle2; capturar `Wyvern_MotionState`, cámara, huesos, velocidades, inclinación.
- B: Copia del mismo Place con SOLO el parche de los 3 módulos físicos de v0.2.3. Comparar ruta/cámara, NUNCA basarse solo en logs.
- Calibrar Y de patas reales de Idle2 y Run con `Bone.TransformedWorldCFrame.Position`. El monitor informa todos los huesos con 'Pata' y en modo terrestre sus gaps verticales respecto al suelo cercano. No asumir que la posicion del hueso sea la punta de la garra; contrastar con superficie de la malla.
- Probar: suelo plano, dos pies al suelo, carrera 30/39, frenar en seco; rampas 10°, 20°, 30°; transición rampa→cima, cresta, bache, fosa corta; escalón 2 studs; roca, muro y acantilado.
- Esfera SIEMPRE CanCollide=true durante FLIGHT, APPROACH, LANDING, GROUNDED_IDLE, GROUNDED_RUN, GROUND_RECOVERY y TAKEOFF; raíces y mallas CanCollide=false.
- Mensurable: inclinación max <15° en los obstáculos bajos de la prueba v0.2.2; sin hundimiento por suelo; <0.15 studs gap visual de garras objetivo **en plano de referencia** (si el hueso está en la posición correcta); no rebotes impulsivos; ausencia de cambio a FLIGHT sin pulsar Space; soporte VectorForce.Enabled=false.
- Vuelo aprobado R4.1/R4.2: rumbo frontal, respuesta de mouse, giro A/D, Boost, ascenso, cámara orbital; montura de cuello. Verificar especialmente el vuelo bajo contra Terrain debido a collider siempre activo.
- Reanudar vuelo por Space desde terreno y GROUND_RECOVERY; asegurarse que no colisione violentamente al despegar.
- Publicación de Idle2/Run IDs **pendiente**; no volver a cambiar sistema animación. En experiencia publicada pueden seguir sin funcionar fuera de Studio mientras usen hashes locales.

## Condiciones de STOP / ROLLBACK

Si la esfera provoca choque en vuelo, se engancha en roca o rompe aterrizajes; si el dragón se hunde/flota por error >0.15 studs; si no contacta pared; si aparecen vuelcos o se pierde animación/cámara: DETENER, registrar primer estado/medida y restaurar la COPIA, no producción. No aumentar fuerzas o MaxTorque a ciegas. No activar vieja DT_GroundCollider enterrada. No reconfigurar rig, añadir Humanoid ni usar PivotTo cada Heartbeat. No borrar backups; no reset --hard ni force-push.

## Mejora posterior si no supera

La esfera central es un proxy mínimo. Para asentamiento biológico creíble en laderas fuertes se necesitará collider torso calibrado y/o IK de patas independiente del rig visual. No cambiar a `ControllerManager` en esta iteración: implicaría reemplazar completamente autoridad de movimiento y arriesgar vuelo aprobado.
