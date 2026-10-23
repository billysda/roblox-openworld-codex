# Gran Wyvern de Tierra — incidente v0.2: vuelco ante obstáculo y pérdida de apoyo

**Rama:** `fix/wyvern-tierra-ground-collision-v021`  
**Estado:** DIAGNÓSTICO INSTRUMENTADO, no corrección física aprobada.  
**Modelo único:** `Workspace.wyvernfbx` (Place `100008359356261`).  
**Referencia:** vídeo de usuario `20261023-0407-05.0835087(1).mp4` (30.8 s, 1240x776).

## Hallazgos sustentados

- ~5.8s: dragon en carrera cerca de plataformas y bordes; el panel de controles muestra **CONTROLES TERRESTRES**.
- ~6.4s: el dragon sube bruscamente, cabeza y cola se desalinean; el panel ya muestra **CONTROLES DE VUELO**.
- ~7.8s: cola levantada casi verticalmente, severa rotación de todo el cuerpo. En el HUD de vuelo visible hay velocidad de vuelo alta, aunque no mide velocidad horizontal terrestre.
- No se puede distinguir visualmente, sin instrumentación, si el primer detonante fue `RootPart`, un `MeshPart`, `DT_GroundCollider`, un contacto externo (plataforma/cornisa) o la recuperación de la lógica aérea. No afirmar causa específica hasta Play instrumentado.
- El snapshot histórico del dragón daba `DT_Root.CanCollide=false`, `RootPart.CanCollide=true`. Son datos históricos, no lectura actual.
- Código v0.2: `Ground:Sense()` hace raycasts para detectar suelo, pero NO tiene swept test frontal de obstáculos. En `GROUNDED_RUN`, si `sensor.valid=false` o `clearance>3` durante 0.4s, el controlador cambia directo a `FLIGHT`. El controlador aéreo seguía actualizando `currentSpeed` por su crucero/boost, separado de `groundMoveSpeed`. Eso permite una recuperación aérea muy rápida y sin transición temporal al salir de un borde, *potencial amplificador del vuelco*.
- `DT_RootWeld` suelda `DT_Root` a `RootPart`, el cuerpo visual está unido mediante varios `Motor6D` a `RootPart`; los contactos de las piezas físicas pueden transmitir torque a todo el ensamble.
- `AlignOrientation` tiene `MaxTorque=1e6`, `Responsiveness=12`, `RigidityEnabled=false` en la referencia GitHub; no se ha medido si torque es suficiente para cancelar un impacto a 30–39 studs/s. No subir este torque a ciegas.

## 1. Ejecutar auditoría reproducible ANTES de modificar colisiones

Archivo: `tools/wyvern_tierra_collision_audit_v021.server.lua`.

1. Abrir copia COMPLETA del Place, verificando el dragón y los scripts v0.2. No ejecutar en producción.
2. Crear Script temporal en `ServerScriptService` pegando ese archivo. Atributo String `CollisionTestMode = OBSERVE` (por defecto).
3. Reproducir una sola carrera con W/Shift hacia la misma placa que genera el vuelco. Registrar vídeo, Output filtrado por `[WYV-COL]`.
4. El script imprime **TODAS** las BaseParts del wyvern con `CanCollide`, `CanQuery`, `CanTouch`, `Massless`, `RootPriority`, `Size`, posición local, CollisionGroup, fidelidad de colisión de MeshParts y otras propiedades; además loguea contactos sólidos candidatos, cambios de estado, velocidad angular, inclinación, COM, activación del soporte y nivel de los sensores.
5. Si reproduce el problema, copiar la secuencia `[TOUCH]`, `[STATE_TRANSITION]` y `[TILT_SPIKE]`, incluyendo **el orden temporal**. La señal `Touched` es una pista, no prueba inequívoca de la fuerza que causó el vuelco.

## 2. A/B aislado de piezas (solo en copias diferentes del Place)

- A / `OBSERVE`: sin alterar fisica — referencia obligatoria.
- B / `ISOLATE_ROOT`: desactivar temporalmente `RootPart.CanCollide`, todo lo demás igual.
- C / `ISOLATE_MESHES`: desactivar solo `MeshPart.CanCollide`, dejar `RootPart` como estaba.
- D / `ISOLATE_VISUAL`: desactivar `RootPart` + todas las `MeshPart` colisiones.

**Importante:** que desaparezca un vuelco al desactivar colisiones no demuestra que el juego ya esté listo: el dragón podría atravesar paredes. Estas variantes SOLO determinan qué piezas deben excluirse del cuerpo visual.

Registrar para cada modo: 3 intentos idénticos, roll/pitch máximo, `AssemblyAngularVelocity` máxima, estado de control al primer vuelco, `CanCollide=true` restantes, `VectorForce`, `AlignOrientation` y velocidad; indicar si atraviesa o no obstáculos.

## 3. Arquitectura de arreglo prevista tras A/B (NO IMPLEMENTADA AÚN)

1. **Cuerpo visual no colisionante**: si se confirma que las mallas o RootPart se traban, desactivar sus colisiones físicas y conservar rig, animación y render. No tocar `CanQuery`/`CanTouch` sin justificar.
2. **Colisión física simplificada específica del wyvern**: diseñar 1 o más proxies convexos lisos, con `WeldConstraint` al mismo ensamble de `DT_Root`, tamaños y offsets MEDIDOS en Studio (no inventados). El collider no debe interceptar el suelo en reposo ni crear un eje de rotación sobre un saliente. Verificar `DT_GroundCollider` histórico: cara inferior estaba por debajo del piso (no habilitarlo a ciegas).
3. **Predicción de obstáculos**: barridos frontales y de apoyo próximos al área que abarcan las patas: ajustar carrera y frenado antes de escalones demasiado altos. En terrenos con pequeñas pendientes, amortiguar altura de apoyo en vez de frenar de golpe.
4. **Handoff seguro de Ground→Flight**: detectar diferencia entre borde, bache y salto; no pasar directamente de 30 studs/s de carrera al `currentSpeed` antiguo de vuelo tras 0.4s sin apoyo. Conservar heading/velocidad y un estado breve de transición; asegurar que la cámara no rote violentamente.
5. **Torque y COM**: con medidas de masa y contactos, ajustar `AlignOrientation`, límite angular y distribución de masa, evitando `CFrame` rígidos o Anchored en cada frame.
6. Prueba en terreno real: escalón pequeño, escalón alto, roca, pendiente, cornisa, pared y recuperación del vuelo. Probar a 30 y 39 studs/s.

## Cambios efectivamente versionados en esta rama

- **Se añadió** auditoría reversible read-only/A-B en el archivo anterior.
- **Se sincronizó** una corrección ya validada localmente por Antigravity: `playerInputs.boost = (inputPacket.boost == true)` en `src/WyvernFlightV2/LandingV01/FlightController.server.lua`.
- **NO** se han cambiado colisiones de producción, meshes, welds, sensores, locomoción, cámaras ni física aprobada.

## Entrega esperada

Un reporte de Antigravity con tabla de TODAS las piezas del dragón y su colisión real; qué evento ocurre primero (contacto, pérdida de sensor o transición a vuelo), reproducción A/B y evidencia en vídeo del mismo obstáculo. Con esos datos ChatGPT crea el arreglo de física v0.2.2 con mínima intervención en el ensamblaje correcto.
