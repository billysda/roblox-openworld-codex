# Gran Wyvern de Tierra — prueba A/B ControllerManager vs Legacy XZ (v0.2.4 EXPERIMENTAL)

**Place:** 100008359356261. **Rig canónico:** `Workspace.wyvernfbx`.
**Rama:** `experiment/wyvern-groundcontroller-ab-v024` (basada en `fix/wyvern-tierra-physics-v023`).
**Estado:** prototipo de comparación programado; **NO ejecutado en Studio, NO aprobado**.
**Objetivo:** demostrar con el MISMO rig si Roblox GroundController asciende 10°, 20°, 30° y la cresta mejor que el movimiento horizontal XZ de la v0.2.3.

## Revisión de hechos / discrepancia de versiones

El informe Antigravity del 23/10 dice que cambió `GROUND_FORCE_PER_MASS=90` a `450` localmente en Studio, pero `fix/wyvern-tierra-physics-v023` remoto todavía contiene **90** a fecha 23/10. **No reescribir la fuente de Studio ni publicar el cambio de 450 a ciegas.** Este experimento usa **450 en su variante LegacyXZ** para reproducir la calibración LOCAL informada; es una equivalencia de su propulsión XZ, no un clon del FSM completo.

Antigravity declaró PASS con rampas pero el usuario observó fallo en su Play. Se requieren recorrido continuo, inputs reales, pendiente y posición de cada muestra. No declarar PASS por permanecer 32 frames en GROUNDED_RUN.

## Fuentes oficiales que justifican el ensayo

- `ControllerManager` gestiona un `RootPart`, `MovingDirection`, `FacingDirection`, `GroundSensor` y `ActiveController`: https://create.roblox.com/docs/reference/engine/classes/ControllerManager
- `GroundController` regula fuerza de locomoción, aceleración, frenado, orientación y `GroundOffset`: https://create.roblox.com/docs/reference/engine/classes/GroundController
- `ControllerPartSensor` ofrece `SensorMode=Floor`, `SearchDistance`, `HitFrame` y `HitNormal`: https://create.roblox.com/docs/reference/engine/classes/ControllerPartSensor
- Sep/Oct 2026: un bug reciente de controladores físicos mostró que `BalanceMaxTorque=0` podía impedir movimiento; evitar cero y NO asumir que se solucionó toda fricción: https://devforum.roblox.com/t/controllermanagergroundsensor-no-longer-works-properly/4890240
- Controladores estándar también pueden fallar en desniveles; este A/B no prejuzga victoria.

## Archivos del experimento (NO pertenecen a scripts del Place aprobado)

- `experiments/wyvern_ground_ab_v024/WyvernGroundABHarness.server.lua`
- `experiments/wyvern_ground_ab_v024/WyvernGroundABInput.client.lua`

El servidor corre **solo** cuando está en Studio y tiene el atributo Boolean `ABTestEnabled=true`. No modifica la instancia original: crea `Workspace.WyvernGroundAB_TestClone` y `Workspace.WyvernGroundAB_Track` lejos del mundo actual (X≈2000). Si la cámara Input y FlightCamera originales siguen Enabled, el experimento ABORTA para prevenir doble controlador de cámara.

El experimento crea una pista dedicada:
- Plano inicial de 70 studs
- Rampas continuas 10°, 20°, 30°, con descansos entre ellas
- Cresta, descenso de 20° y salida

Clona el rig exacto incluyendo huesos y mallas, crea proxy esférico 3×3×3 idéntico a v0.2.3, con Y=-0.27 y contacto permanente. Ambos modos tienen proxy, terreno, masa y entrada iguales.

### Modo A: LegacyXZ

Crea **un solo** `LinearVelocity` para XZ con eje Y sin fuerza y una `AlignOrientation`. Límite por eje `AssemblyMass*450`, dentro de 250000; sin soporte PD. Esto replica el mecanismo de avance del parche local descrito por Antigravity (no todo el sistema de vuelo ni su FSM).

### Modo B: GroundController

Crea:
- `ControllerManager.RootPart = clone.DT_Root`
- `ControllerPartSensor` en RootPart; `SensorMode=Floor`, `SearchDistance=8`
- `GroundController.GroundOffset=1.77`, `AccelerationTime=0.35`, `DecelerationTime=0.20`, `Friction=0.65`, `BalanceMaxTorque=100000` (no 0)
- `ActiveController = GroundController`; `MovingDirection` / `FacingDirection` desde W/A/D

Los `LinearVelocity`, `AlignOrientation` y `VectorForce` heredados en la COPIA del rig se deshabilitan. No hay dos autoridades sobre el ensamble experimental. La velocidad objetivo es W=30, Shift+W=39 en ambos modos.

Para Idle2/Run, la copia intenta usar los assets numéricos existentes; si no existen, usa secuencias originales `ServerStorage.RBX_ANIMSAVES.wyvernfbx` registradas TEMPORALMENTE solo en Studio. Esto no publica animaciones ni altera el reproductor principal.

## Cómo debe ejecutarlo Antigravity

1. **Guardar y abrir copia completa de Place**. Verificar que contiene `Workspace.wyvernfbx`, rigs, `DT_RootWeld`, asiento, scripts aprobados. No tocar el Place original ni hacer publish.
2. Inspeccionar y exportar hashes SHA-256 del Source vivo del vuelo y de las animaciones recientes (FlightCamera, Input, FlightAimState, FlightController, FlightAnimationServerV022). No reemplazarlos con archivos viejos de GitHub.
3. En la COPIA: **deshabilitar temporalmente SOLO** `StarterPlayer.StarterPlayerScripts.WyvernFlightV2.FlightCamera` y `...Input` para que la cámara de prueba tenga autoridad única. No alterar las fuentes ni borrarlas. El controlador de vuelo original del dragón canónico puede permanecer, porque el experimento mueve solo el CLON.
4. Crear `ServerScriptService.WyvernGroundABHarness` Script con contenido del archivo server. Añadir atributos: `ABTestEnabled` **Boolean true** y `DriveMode` **String GroundController**.
5. Crear `StarterPlayer.StarterPlayerScripts.WyvernGroundABInput` LocalScript con contenido del archivo cliente.
6. Iniciar Play (cliente real) y verificar los mensajes `[WYV-AB][READY]`, clon a X≈2000, pista y HUD. **Si no aparecen, diagnosticar primero; no cambiar variables arbitrarias**.
7. Mover con W y Shift+W, orientar con A/D (no usa mouse aim de R4.1). Ejecutar 3 recorridos idénticos de plano→10°→20°→30°→cresta. Capturar una grabación continua del dragón y Output.
8. Detener Play. Restaurar la MISMA copia del Place desde el mismo punto inicial (el runtime original no persiste los clones).
9. Cambiar solo `DriveMode` a String `LegacyXZ` y repetir 3 recorridos con mismos inputs/tiempo; si es más cómodo invertir orden A/B, pero nunca poner ambos drivers simultáneamente.
10. Reportar para cada pendiente y modo: tiempo para terminar, posición Z y Y real, `speedXZ`, `vy`, inclinación corporal, `sensor.SensedPart` (o nil), contactos, bloqueos, caídas, hundimiento de garras y video. Evaluar no solo velocidad objetivo sino ascenso Y efectivo.
11. Si el Manager no detecta `GroundSensor`, `GroundOffset` causa bouncing, `BalanceMaxTorque` es insuficiente, o el proxy se engancha, conservar el PRIMER error. No declarar que la alternativa oficial gana sin completarlo.
12. Terminado el experimento, eliminar los dos Scripts de prueba de la copia o cerrar sin guardar; **restaurar los originales FlightCamera e Input a Enabled en la copia**, confirmar en el Place principal que nunca fueron modificados.

## Criterios de aprobación

- El clon cruza al menos las 3 rampas y una cresta sin teletransporte, sin cambio a vuelo, sin quedar atascado, y con ascenso Y medible.
- No vuelcos >15° ni penetraciones fuertes, respetando que el torso visual puede inclinarse por animación.
- En Idle2 se detiene, Run acompaña avance físico. Validar por video; prioridad física primero.
- Sin spam de errores en Output y sin conflictos con FlightController original; sin scripts instalados en Place principal.
- Mejora significativa frente a LegacyXZ **en las mismas condiciones**. Si ControllerManager no supera, no migrar producción: alternativa próxima será velocidad tangente por superficie + sensor y colliders calibrados.

## Restricciones

- NADA de merge a `main` ni publicación.
- NO editar `hoy.blend`, huesos, Welds aprobadas, cámara R4.2, Input corregido, animaciones, ni Place principal.
- No borrar backups/datos ambiguos, no `git reset --hard`, no force push, no `clean -fdx`.
- Exportar informe con estado real de Studio y fuentes/hashes del experimento. El cambio de fuerza local de 450 debe documentarse aparte si aún no fue llevado al remoto.
