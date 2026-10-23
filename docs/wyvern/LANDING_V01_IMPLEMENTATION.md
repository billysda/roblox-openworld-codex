# Gran Wyvern de Tierra — aterrizaje y locomocion v0.1 (CODIGO, NO PROBADO EN STUDIO)

**Lugar canonico:** `Workspace.wyvernfbx`, Place ID `100008359356261`.
**Rama de entrega:** `feat/wyvern-tierra-landing-v01`.
**Base remota utilizada:** `feat/wyvern-r42-organic-motion` en SHA `0024634e1`.
**ADVERTENCIA:** el informe de Antigravity menciona un commit LOCAL `6331612` de la version validada que no figuraba en la rama remota al crear esta implementacion. **NO sobrescribir el codigo local ni hacer reset / force-push.** Comparar primero fuentes y merges.

## Archivos exactos

| Archivo de entrega | Destino previsto en Roblox Studio |
|---|---|
| `src/WyvernFlightV2/LandingV01/WyvernGroundV01.lua` | `ServerScriptService.WyvernFlightV2.WyvernGroundV01` (ModuleScript) |
| `src/WyvernFlightV2/LandingV01/FlightController.server.lua` | `ServerScriptService.WyvernFlightV2.FlightController` (Script existente; integracion controlada) |
| `src/WyvernFlightV2/LandingV01/FlightAnimation.client.lua` | `StarterPlayer.StarterPlayerScripts.WyvernFlightV2.FlightAnimation` (LocalScript existente; integracion controlada) |

El controlador usa **los mismos LinearVelocity y AlignOrientation** que R4.1/R4.2. El modulo GroundV01 **solo** hace raycasts y aplica sustentacion vertical cuando el modelo esta en tierra. No colocar un segundo script fisico independiente.

## Contrato de estados

- `FLIGHT`: vuelo R4.1/R4.2. Sin cambios de movimiento salvo el atributo de telemetria.
- `APPROACH`: descenso solicitado manteniendo LCtrl, si hay suelo valido dentro de 25 studs del punto de apoyo.
- `LANDING`: proximidad a 3.5 studs y velocidad reducida.
- `GROUNDED_IDLE`: Idle2 con velocidad horizontal tendiendo a cero.
- `GROUNDED_RUN`: Run y avance horizontal controlado por W; A/D giran.
- `Space` o `Shift` en APPROACH/LANDING abortan la aproximacion cuando la altura permite recuperar vuelo.
- **Despegue desde tierra no implementado** en esta primera version; `ResetCommand` original mantiene su retorno al spawn aereo.

El atributo `DT_Root.Wyvern_MotionState` es la referencia de animacion; `Wyvern_GroundClearance`, `Wyvern_GroundProbeCount`, `Wyvern_GroundSpeed` son telemetria.

## Hipotesis/calibraciones a validar, NO tratar como hechos

- `RestRootHeight = 1.798` studs esta derivado de la plataforma Y=40.288 y DT_Root Y=42.086 en el informe del 22 Oct; no es una medicion universal en todas las superficies.
- Raycasts: 5 puntos a 0/±2.5 studs lateral y ±3 longitudinal. No son puntos exactos de huesos. **Se deben contrastar con los pies del rig**.
- Pendiente maxima 30 grados; velocidad Run 16 studs/s; umbrales de frenada y touchdown son parametros iniciales sujetos a Play testing.
- El soporte terrestre es un VectorForce PD vertical. Esto *no* equivale a simulacion IK y puede producir hover/jitter si el colisionador existente interfiere. Probar y ajustar, o cambiar a apoyo puramente por colision si la geometria lo permite.
- `DT_GroundCollider` estaba `CanCollide=false` y bajo el suelo en el informe anterior. Esta version **NO cambia** su ubicacion ni activa su colision. Confirmar si RootPart/otras piezas mantienen contacto real.
- Los hashes temporales de animacion Idle2/Run deben cargar a traves de `wyvernfbx.Animations`. Verificar que sean `Animation` con `AnimationId` legible por Animator. Si no, publicar/registrar secuencias correctamente; **NO inventar IDs**.
- FlightAnimation original reproducia FlightLoop siempre; sustituir exactamente ese LocalScript por el de esta rama, no dejar dos reproductores activos.
- La carga local de animaciones en modelos de Workspace requiere comprobar replicacion al resto de jugadores; v0.1 se prueba primero en Studio. Validacion multijugador pendiente.

## Protocolo Antigravity (operador, no programador principal)

1. Confirma que **abriste** un archivo .rbxl/.rbxlx completo del Place validado, no el AutoSave de otra plantilla; o crea una copia completa nueva mediante Studio File > Save to File.
2. Compara codigo **vivo** del Place con base `docs/studio_snapshot/current/scripts/...`, el commit local `6331612` y el contenido de esta rama. Reconciliar divergencias sin sustituir una version mas reciente a ciegas.
3. Prueba primero en una copia aislada de Place ID `100008359356261`. Inserta `WyvernGroundV01`, actualiza unicamente los dos controladores de destino. Garantiza que no queden 2 Script/LocalScript con iguales funciones.
4. Verifica `DT_Root` alineado con `RootPart`, `DT_NeckSeatWeld` activo; no alteres Welds, meshes, bones, `hoy.blend` ni los assets originales.
5. Pruebas reales Play: vuelo 80 studs/s, boost, giros, intento de aproximacion controlada con LCtrl a plataforma, aterrizaje, idle, W para Run, soltar W, A/D, aborto con Space, asiento estable. Registrar antes/despues, capturas y logs.
6. Inspecciona: visual de patas, penetracion de geometria, distancia al terreno, `DT_GroundCollider`, velocidad Y, temblor del cuerpo, animaciones activas y prioridad. **No declarar superado solo con telemetria**.
7. Repite sobre terreno natural y pendiente moderada. Si la prueba falla, restaura la copia y reporta el estado exacto y la primera condicion que fallo. No modificar el Place de produccion.
8. Devuelve informe y muestras reproducibles. ChatGPT preparara correcciones sobre esta rama.

## Preservacion

- Rama aprobada `feat/wyvern-r42-organic-motion` permanece intacta.
- No borrar backups ni modelos de ServerStorage; no `reset --hard`, `clean -fdx`, ni `force push`.
- El flujo validado `FlightLoop=rbxassetid://96071143174783`, `Idle2=101 frames (338-438)`, `Run=17 frames (1109-1125)` no se vuelve a exportar.
