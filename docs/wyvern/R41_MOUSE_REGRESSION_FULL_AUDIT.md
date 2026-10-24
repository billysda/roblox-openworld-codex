# AUDITORÍA INTEGRAL (WyvernFlightV2) — regresión de giro con ratón, 23/10/2026

**Estado:** diagnóstico instrumentado; NO es parche funcional y NO modifica fuente activa.  
**Rama:** `audit/wyvern-r41-mouse-control-regression`, derivada de `fix/wyvern-tierra-openworld-v022`.  
**Place:** `100008359356261`; **modelo:** `Workspace.wyvernfbx`.

## 1. Fuente de verdad y error del proceso

- `docs/studio_snapshot/current/scripts/` representa Studio capturado **13/10**, no la copia viva de R4.1/R4.2 validada el 22/10.
- La cámara e Input entregados para v0.2 se copiaron desde ese snapshot, luego se ampliaron. **Ese procedimiento fue un error de integración: no se comparó contra Source de Studio, incumpliendo `docs/agent_sync/PROTOCOL.md`.**
- Antigravity reporta que en Studio instaló una cámara preliminar R1 con una referencia inexistente `WyvernFlightConfig.CameraOffset`, provocando error de tipo y dejando `CameraType=Scriptable` sin actualización.
- Antigravity cambió **localmente** `FlightCamera`, `Input`, el módulo raíz `FlightAimState` y creó `ReplicatedStorage.WyvernFlightV2.Aim.FlightAimState` como proxy. Esas fuentes exactas no figuran subidas en la rama GitHub v0.2.2; **NO sustituirlas por archivos históricos**.
- La documentación de aprobación `docs/wyvern/vuelo_orientacion_asiento_aprobado_20261022.md` se declaró en commit local `6331612`, pero devuelve 404 en la rama remota auditada. Confirmar el estado local antes de hacer `git pull`, merge o publicar.
- Que la cámara siga al dragón por 10 s **no valida el giro por ratón**. La prueba que faltó fue mouseDelta -> aimYaw -> aimTurn packet -> server finalTurn -> yawRate -> dirección física.

## 2. Dependencias: inventario completo de gameplay del Gran Wyvern de Tierra

### Física/cuerpo
- `Workspace.wyvernfbx.DT_Root`: ensamblaje y controlador de movimiento, rootPriority 127.
- `DT_RootWeld` -> `RootPart` -> 5 MeshParts por `Motor6D`.
- `DT_NeckSeatWeld` -> `DT_NeckSeat`.
- `DT_GroundColliderWeld` -> `DT_GroundCollider`.
- `ServerScriptService.WyvernFlightV2.FlightController`: ÚNICA autoridad de velocidad/orientación, escribe `Flight_FinalTurnIntent`, `Flight_YawRate`, `Flight_Heading`, `Wyvern_MotionState`.
- `WyvernGroundV01`: raycast/spherecast suelo y obstáculos.
- `GroundCollisionV022`: geometría suave física terrestre.
- `FlightAnimationServerV022`: permanece deshabilitado hasta asignar IDs permanentes Idle2/Run.

### Apuntado y cámara del jugador
- `ReplicatedStorage.WyvernFlightV2.Config.WyvernFlightConfig`: parámetros constantes R4.1/R4.2, incluyendo deadzone, sensitivity, yaw response.
- `ReplicatedStorage.WyvernFlightV2.FlightAimState`: estado de aim; API histórica `ApplyMouseDelta`, `ResetAim`, `GetAimDirection`, `SoftAlignWithDragon`.
- `ReplicatedStorage.WyvernFlightV2.Aim.FlightAimState`: **SOLO visto por informe de Studio**, no versionado en GitHub auditado. Si existe, debe ser un proxy EXACTAMENTE hacia el módulo raíz, no una tabla de aim independiente.
- `StarterPlayer.StarterPlayerScripts.WyvernFlightV2.FlightCamera`: captura mouse, rota cámara y DEBE actualizar `FlightAimState` del mismo VM/tabla que Input.
- `StarterPlayer.StarterPlayerScripts.WyvernFlightV2.Input`: calcula yaw/pitch error y envía `aimTurn/aimPitch/turn/vertical` por `FlightInput` a ~30 Hz.
- `ReplicatedStorage.WyvernFlightV2.Remotes.FlightInput`: un único RemoteEvent. Comprobar no duplicación.
- `FlightAnimation`: reproduce animación temporal; no debe controlar yaw ni escribir aim.
- `OrganicMotionR42`: posprocesa huesos visuales; **no** debe escribir aim o Root CFrame (comprobar estado Enabled y ejecución).
- `ServerScriptService.WyvernFlight` LEGACY y `StarterPlayerScripts.WyvernFlight` LEGACY: aparecen Disabled en snapshot. Confirmar en Studio; no reactivar.

## 3. Diferencias verificadas en archivos remotos (no Studio vivo)

Comparación `docs/studio_snapshot/current/scripts` ↔ `src/WyvernFlightV2` en rama v0.2.2:
- FlightCamera: **346 → 474 líneas** por cámara terrestre, soporte de Run y estados. Las llamadas aéreas a `ApplyMouseDelta/GetAimDirection` siguen en el código GitHub.
- Input: **349 → 388 líneas**; el packet remoto cambió de `aimTurn=currentAimTurnIntent` a `aimTurn=onGround and 0 or currentAimTurnIntent`, igual para `aimPitch`. Confirmar `onGround=false` durante crucero real; si es falso, el script no debería suprimir aim.
- FlightController: **414 → 680 líneas**; conserva la fórmula central de giro R4.1; se añadió FSM terrestre y lógica de recuperación. Si recibe aimTurn válido en `FLIGHT` debería girar. El problema puede estar ANTES del servidor o en la sincronización Studio↔GitHub.

**Ninguna de estas observaciones demuestra aún qué línea de Studio anuló el mouse steering.**

## 4. Instrumentación NO INTRUSIVA

Archivos en esta rama:
- `tools/wyvern_mouse_audit_r41.client.lua`: instalar TEMPORAL en `StarterPlayerScripts` (LocalScript) de una COPIA DEL PLACE. Imprime estado de cámara/mouse, deltas, identidad de ambos módulos aim, intención de giro, atributos de yaw y ejecución de cliente.
- `tools/wyvern_mouse_audit_r41.server.lua`: instalar TEMPORAL en `ServerScriptService` (Script) de la COPIA. Registra paquetes `FlightInput` realmente recibidos, `Flight_AimTurnIntent`, `Flight_FinalTurnIntent`, `Flight_YawRate`, `Flight_Heading`.

NO establecen `CameraType`, NO modifican `FlightAimState`, NO generan fuerzas, NO cambian `DT_Root`. Desinstalar ambos scripts tras la prueba.

## 5. Experimento usuario/Antigravity con ratón REAL, no inyección artificial

1. Verificar copia .rbxl real y `git status` limpio, sin reset ni force-push. Archivar las fuentes de cámara/Input/AimState/servidor **vivas** antes de tocar nada. Subir a rama de auditoría bajo `reports/wyvern/live_sources_20261023/` sin modificar el Place.
2. Añadir ambos monitores temporales. Iniciar Play con ratón capturado (`MouseBehavior.LockCenter`) y `Wyvern_MotionState=FLIGHT`.
3. En vuelo recto, mover ratón a DERECHA durante 1 segundo sin A/D, repetir IZQUIERDA, luego ARRIBA/ABAJO (3–5 s). Capturar cliente y servidor. Apuntar los valores en orden.
4. **Resultado esperado:** `rawDelta.X != 0` -> `rootAimYaw` cambia -> `rootIntent` cambia -> `packetAimTurn` no es cero -> `server finalTurn` no es cero -> `yawRate` no es cero -> cambia dirección de `DT_Root.LookVector`. No afirmar éxito solo porque cámara orbitó.
5. Si `SAME_TABLE=false`, comparar `FlightCamera` e `Input` y restaurar una sola tabla canonica compartida. Si es `true` pero packetAimTurn=0, revisar `Input` y `onGround`. Si packet llega no cero pero finalTurn es cero, revisar FSM/remoto/controlador. Si finalTurn no cero pero heading no cambia, revisar fuerzas, alignOrientation y otra autoridad.
6. Validar A/D manual por separado para excluir problemas de torque o servidor: si A/D gira pero mouse no, es casi seguro el canal de aim.
7. A/B usando solo la copia aislada: comparar primero la versión viva actual con fuentes exactas del último R4.1 aprobado (si están disponibles en backup verificado). No mezclar scripts de ramas diferentes a ojo.
8. Una vez corregida la primera causa demostrada, integrar SOLO el diff mínimo. Reproducir pruebas de tierra, aterrizaje, despegue, giro libre de cámara terrestre y vuelo R4.1/R4.2.

## 6. Definición de SUPERADO

En vuelo, el mouse captura delta real y manda giro de forma continua en ambos ejes. Cámara acompaña dirección sin congelarse ni desajustarse. Se conserva A/D, W/S, Space/Ctrl, boost, colisiones v0.2.2, Idle2/Run y shakes terrestres. En tierra, mover mouse órbita cámara sin girar el cuerpo. Reportar porcentajes de respuesta (pixel → yaw aim → yaw body), errores y los hashes **antes/después** de Source.

**Prohibición:** no parchear ciegamente `FlightController`, no restaurar cámara R1 ni cambiar `DT_Root`, welds, mallas o propiedades de colisión para tratar de corregir apuntado.
