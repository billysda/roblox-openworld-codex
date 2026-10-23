# Gran Wyvern de Tierra — jugabilidad terrestre v0.2 (PENDIENTE PLAY MODE)

Rama: `feat/wyvern-tierra-gameplay-v02`  
Base: `feat/wyvern-tierra-landing-v01`  
Place: `100008359356261`  
Modelo unico: `Workspace.wyvernfbx`

> Estado: codigo subido a GitHub, **sin ejecutar aun en Roblox Studio**. No fusionar con el vuelo aprobado antes de superar pruebas.

## Referencia audiovisual

Video del usuario `20261023-0307-00.9155591(1).mp4` (~11.9 s, 1236x800, 30 fps): muestra el Gran Wyvern de Tierra en carrera, patas alternadas y una camara que recorre vistas lateral/frontal/trasera. La configuracion elegida prioriza seguimiento y peso; los impactos exactos de camara son una **interpretacion** que debe ajustarse durante la prueba visual. No se afirma haber medido desplazamiento de pixeles de cada pisada.

## Cambios implementados

1. **Giro terrestre exclusivamente por A/D:** el calculo yaw aereo ya no actualiza `currentYaw` en `GROUNDED_IDLE / GROUNDED_RUN`. `Input` transmite mouse aim = 0 mientras este en tierra. Mover el mouse no debe virar el dragón.
2. **Cámara terrestre libre:** sin reemplazar la camara de vuelo fuera de tierra. Orbitas mouse capturado/RMB, scroll para zoom 23-65 studs, target suavizado, FOV 73-78, raycast de obstruccion. Retorna suavemente a sistema de aim de vuelo tras despegue.
3. **Impactos reales sincronizados:** `FlightAnimation` publica `DT_Root.Wyvern_RunPhaseLocal` localmente desde el `AnimationTrack.TimePosition/Length`. La camara usa pulsos en fases 0.43 y 0.83, con intensidad proporcional a velocidad fisica horizontal. Amplitud inicial `GROUND_SHAKE_STRENGTH=0.85` en `FlightCamera.client.lua`, editable sin volver a Blender. En Idle el impacto es cero.
4. **Correr, no caminar:** W ordena `30 studs/s` (v0.1: 16), Shift+W ordena `39 studs/s` en tierra; la pista Run acelera su playback segun velocidad medida. Verificar ratio de deslizamiento de patas antes de subir mas la velocidad.
5. **Despegue sin reset:** Space en tierra activa `TAKEOFF` con ventana de 0.55s, componente vertical 38 studs/s y recuperacion posterior del control R4.1/R4.2. Se usa el mismo LinearVelocity/AlignOrientation, sin un segundo controlador.
6. **Aterrizaje:** cinco rayos calibrados cerca de garra frontal izquierda/derecha, pie trasero izquierdo/derecho y centro; se requiere centro + un soporte frontal + un soporte trasero, y desnivel maximo de 2.5 studs. Corrige trote inicial sin pulsar W.
7. **HUD reutilizado:** la caja existente indica `MANTENER CTRL PARA ATERRIZAR` con superficie valida, controles de tierra al llegar y `Space` para despegar.

## Archivos entregados en la rama

| Archivo GitHub | Destino de integracion en Studio |
|---|---|
| `src/WyvernFlightV2/LandingV01/FlightController.server.lua` (ACTUALIZADO v0.2) | `ServerScriptService.WyvernFlightV2.FlightController` |
| `src/WyvernFlightV2/LandingV01/WyvernGroundV01.lua` (ACTUALIZADO v0.2) | `ServerScriptService.WyvernFlightV2.WyvernGroundV01` |
| `src/WyvernFlightV2/LandingV01/FlightAnimation.client.lua` (ACTUALIZADO v0.2) | `StarterPlayer.StarterPlayerScripts.WyvernFlightV2.FlightAnimation` |
| `src/WyvernFlightV2/LandingV02/FlightCamera.client.lua` (NUEVO parche completo basado en snapshot) | `StarterPlayer.StarterPlayerScripts.WyvernFlightV2.FlightCamera` |
| `src/WyvernFlightV2/LandingV02/Input.client.lua` (NUEVO parche completo basado en snapshot) | `StarterPlayer.StarterPlayerScripts.WyvernFlightV2.Input` |

**ATENCION — riesgo de sobrescritura:** la camara y Input v0.2 se derivaron del snapshot archivado de 13 oct 2026, mientras el Place vivo puede contener nuevas correcciones R4.2. Antigravity DEBE realizar comparacion y fusion puntual de cambios contra scripts vivos, NO pegar el archivo completo si difiere. Mantener las funciones modernas del vuelo aprobado. El FlightController v0.2 deriva del archivo v0.1 que Antigravity valido. Verificar tambien divergence local del commit `6331612`.

No instanciar segundos controladores, segundas camaras, segundo Animator ni un nuevo dragón.

## Controles v0.2

| Tecla | Vuelo | Tierra |
|---|---|---|
| Mouse capturado | Aim vuelo original | Orbitar camara libremente, sin girar dragón |
| Scroll | Como antes | Acercar o alejar camara |
| W | Acelerar | Run ~30 studs/s |
| Shift + W | Boost aereo | Run rapido ~39 studs/s |
| A / D | Viraje vuelo | Girar dragón en tierra |
| Ctrl | Descender / solicitar aterrizaje | — |
| Space | Subir o cancelar aproximacion | Despegue |
| R | Reiniciar en aire | Reiniciar en aire |
| M | Capturar/liberar mouse | Capturar/liberar mouse |

## Pruebas Play Mode obligatorias

1. Abre COPIA real del Place, .rbxl comprobado (contiene wyvern y scripts), sin editar produccion.
2. Mide vuelo R4.1/R4.2 con mouse aim, giros A/D, ascenso/descenso, Boost, FOV/shake aereo; nada debe cambiar.
3. Aterriza con Ctrl sobre superficie valida; verifica contactos reales de garras y patas con geometria y que no haya trote sin W. Comprobar 5 probes y rechazo en borde/acantilado.
4. **Giro de camara en suelo**: mueve mouse 360° con el dragon en Idle 2. `DT_Root.Orientation` deberia quedar constante (sin A/D). `Camera.CFrame` debe cambiar; en Run el cuerpo conserva rumbo si solo se mueve mouse.
5. Pulsa W: medir `AssemblyLinearVelocity` real 30 studs/s objetivo, deslizamiento de cada pata y ciclo Run (17 keyframes). Verificar que playback `Speed`≈1.0 a 30 studs/s. Si se desliza corregir velocidad nominal segun zancada.
6. Shift+W: 39 studs/s objetivo, playback≈1.3; confirmar contacto real y no perder superficie en terreno.
7. **Efectos de camara**: grabar video lateral/trasero, comprobar dos golpes por ciclo Run a TimePosition≈0.43 y≈0.83, intensidad proporcional al avance; Idle2 estable sin shake. Evaluar comodidad en uso sostenido. Ajustar `GROUND_SHAKE_STRENGTH` si molesta.
8. Suelta W: vuelve a Idle2, no trota al aterrizar sin input.
9. Space desde IDLE y desde RUN: despega, cambia a FlightLoop, retoma camara y mouse aim de vuelo, sin inmovilizacion ni salto brusco.
10. Aerofreno/despegue alternado 5 veces, terreno de la isla, borde y pendiente leve; jinete permanece fijo al DT_NeckSeat.
11. Telemetria, Output sin errores, sin duplicados de Scripts ni Animators; validar en cliente y servidor.
12. Multijugador: comprobar que Idle2/Run se ven en otro cliente (el reproductor actual es LocalScript y podria necesitar autoridad en servidor). NO declarar replicacion superada sin prueba 2 jugadores.

## Alertas y limites de v0.2

- **No es produccion** hasta Play Mode y evaluacion humana de cámara/velocidad.
- El vuelo aprobado sigue protegido en rama base y respaldo Place.
- No modificar Blender ni las animaciones de 101/17 cuadros ni asset de vuelo.
- La camera shake es solo local/visual, sin fuerzas extra sobre el dragón.
- El video de referencia es un ejemplo de sensación, no una curva de movimiento extracta.
- No se implementa caminar (solo Run), ni IK de suelo, ni animacion nueva de takeoff.
- Se requiere calibrar aceleracion, velocidad nominal, huella de contacto y maxima pendiente despues de observar video en Studio.

## Protocolo de entrega por Antigravity

Reportar codigo integrado (hashs/commit), diff frente a scripts vivos, capturas/videos de Run con camara, velocidad comando/real, TimePosition y playback, yaw del cuerpo antes/despues de orbitar mouse, tests despegue, regresiones en vuelo y estado de asiento. Ante errores, capturar primeras lineas Output. No arreglar a ciegas ni aplicar cambios destructivos; ChatGPT revisara y versionara los fixes.
