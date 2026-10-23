# Gran Wyvern de Tierra — v0.2.2, mundo abierto y animaciones publicadas

**Modelo:** `Workspace.wyvernfbx`; **Place ID:** `100008359356261`.  
**Rama:** `fix/wyvern-tierra-openworld-v022`.  
**Origen:** `fix/wyvern-tierra-ground-collision-v021` (contiene el fix de recepción de Shift).
**ESTADO:** archivos Luau escritos y revisados en GitHub; **sin Play Mode**. NO aprobado ni publicado.  
Conservar `hoy.blend`, FlightLoop aprobado, 82 huesos y todas las uniones de las piezas.

## 1. Diagnóstico comprobado por Antigravity el 23 de octubre

- `RootPart` 0.10 × 0.10 × 0.05 studs era la **única** parte física sólida. Impactando un escalón de 2 studs a 30 studs/s produjo una inclinación máxima de **38.56°** y una velocidad angular **5.36 rad/s**.
- Al desactivar `RootPart.CanCollide` en prueba A/B la inclinación bajó a **7.97°** y la velocidad angular a **1.47 rad/s**.
- El antiguo `DT_GroundCollider` sobresale **0.587 studs** bajo el plano de apoyo calibrado. **NO activar `CanCollide` en su posición actual**.
- Tras perder sensor durante 0.4s, el sistema saltaba directamente a FLIGHT y recuperaba velocidad de crucero/boost, amplificando el vuelco. Son **dos fallos encadenados**.

## 2. Scripts y ruta de instalación en UNA COPIA AISLADA

| GitHub | Destino Roblox Studio |
|---|---|
| `src/WyvernFlightV2/LandingV01/FlightController.server.lua` (v0.2.2) | `ServerScriptService.WyvernFlightV2.FlightController` (Script existente) |
| `src/WyvernFlightV2/LandingV01/WyvernGroundV01.lua` (v0.2.2) | `ServerScriptService.WyvernFlightV2.WyvernGroundV01` (ModuleScript existente) |
| `src/WyvernFlightV2/LandingV022/GroundCollisionV022.lua` (NUEVO) | `ServerScriptService.WyvernFlightV2.GroundCollisionV022` (ModuleScript nuevo) |
| `src/WyvernFlightV2/LandingV022/FlightAnimationServerV022.server.lua` (NUEVO) | `ServerScriptService.WyvernFlightV2.FlightAnimationServerV022` (Script nuevo; **disabled hasta tener IDs publicados**) |
| `src/WyvernFlightV2/LandingV02/FlightCamera.client.lua` (actualizado) | `StarterPlayer.StarterPlayerScripts.WyvernFlightV2.FlightCamera` |
| `src/WyvernFlightV2/LandingV02/Input.client.lua` (actualizado) | `StarterPlayer.StarterPlayerScripts.WyvernFlightV2.Input` |

Comparar antes con los archivos VIVOS de Studio; fusionar si contienen cambios posteriores. No machacar configuraciones aprobadas ni crear dos controladores de movimiento. `GroundCollisionV022` se requiere por `script.Parent`, así que debe estar junto a FlightController.

## 3. Solución física v0.2.2

- `RootPart.CanCollide=false`; las cinco `MeshParts` mantienen `CanCollide=false`.
- `DT_Root` conserva control de COM y `RootPriority=127`. El `DT_GroundCollider` original sigue no sólido.
- Solo cuando esté en estado terrestre aparece sólido un volumen esférico pequeño `DT_TorsoCollisionV022`, de 3×3×3 studs, centro en `DT_Root.CFrame * CFrame.new(0,0.35,0)`, sujeto con un `WeldConstraint`. Sus medidas son iniciales (0.65 studs de despeje inferior aprox. en el suelo plano calibrado). **Obligatorio probar contra pared/roca/pendiente**: no prometer que previene todo clipping.
- `WyvernGroundV01:ProbeObstacle(speed)` lanza un `Workspace:Spherecast` de radio 1.35 hacia delante hasta la distancia de frenado; reduce la velocidad antes de un obstáculo frontal sólido. Los barridos pueden no detectar overlaps presentes al iniciar el cast; documentar esas limitaciones.
- Los 5 sensores de apoyo aceptan una pendiente regular hasta 30° usando la desviación de cada contacto respecto al plano local central (máximo inicial 1.25 studs), y **no** el desnivel absoluto entre garras. Validar la detección en terreno voxel irregular.
- `GROUND_RECOVERY` reemplaza el paso instantáneo `GROUNDED_RUN -> FLIGHT`: durante ~1s preserva la velocidad real horizontal y permite caída gravitatoria; si recupera apoyo vuelve a tierra; si el desnivel persiste, cede a FLIGHT con velocidad inicial 15–40 studs/s y acelera según R4.2. El movimiento de ratón sigue sin girar el dragón durante esa fase.
- El proxy es **una primera aproximación**. No pretende sustituir una configuración exhaustiva de colisiones contra todos los terrenos. No incrementar torque ni activar la colisión de la malla visual como arreglo rápido.

## 4. Idle2 y Run en experiencia publicada: tarea OBLIGATORIA previa al cambio de animador

**No son IDs persistentes:**
- `Idle2 = 8c1794a653432e52f4a4cef328ee29ff`
- `Run = eb17dbbd7c553982094c6755fd75e20c`

Son hashes locales de `KeyframeSequenceProvider:RegisterKeyframeSequence()`, no activos publicables. No inventar IDs ni anteponer `rbxassetid://` a hashes.

Procedimiento:
1. En Studio, localizar `ServerStorage.RBX_ANIMSAVES.wyvernfbx.wyvern_idle2_from_hoy_Scene` y `...wyvern_run_from_hoy_Scene` (KeyframeSequence originales completos).
2. Publicar ambas como **Animation assets** propiedad de la cuenta/grupo dueño del Place. No sustituir `hoy.blend`, ni sobrescribir FlightLoop. Anotar IDs numéricos reales `Idle2` y `Run` junto con propietario y permisos.
3. Establecer `Workspace.wyvernfbx.Animations.Idle2.AnimationId = "rbxassetid://NUMERO_REAL_IDLE2"` y analogamente Run. Comprobar desde Studio y PUBLICADO con permission de load; no confundir con Animations guardadas en disco.
4. En la copia aislada, habilitar `FlightAnimationServerV022`, **deshabilitar el anterior** `StarterPlayer.StarterPlayerScripts.WyvernFlightV2.FlightAnimation` en el mismo experimento; no duplicar reproductores.
5. La implementacion servidor valida que FlightLoop, Idle2 y Run tengan IDs numericos publicados; de lo contrario **no reproduce nada** (solo WARNING) y debes mantener sin migrar la version anterior. No declarar experiencia lista hasta tener esos IDs.
6. El servidor replica los `AnimationTrack` del rig ajeno al avatar. Publica atributos `Wyvern_RunPhaseBase`, `Wyvern_RunPhaseRate` y `Wyvern_RunPhaseStamp`; FlightCamera reconstruye fase en cliente para sacudidas ritmicas. Probar 2 clientes separados.

## 5. Matriz de pruebas obligatorias en Studio

1. Línea base (versión actual) mismo obstáculo de 2 studs a 30 y 39 studs/s: error de vuelco reproducible.
2. V0.2.2 mismo obstáculo, mismas velocidades: registrar `RootPart.CanCollide`, proxy `CanCollide`, velocidad angular máxima, pitch/roll, distancia de frenado y `Wyvern_MotionState`. **No aceptar pasar atravesando el obstáculo**.
3. Carrera sobre plano, bordes, suelo desnivelado, rampas <=30°, rocas, paredes y suelo Terrain real. Comprobar no penetración o enganche, no vuelco, no hover excesivo, frenada/reanudacion intencional.
4. Caída desde acantilado: registrar sucesión de estados `GROUNDED_RUN -> GROUND_RECOVERY -> FLIGHT`, mantener rumbo/velocidad, evitar el pico a 80–130 al primer frame.
5. Bache corto: `GROUNDED_RUN -> GROUND_RECOVERY -> GROUNDED_RUN` sin desplegar alas innecesariamente; si no se recupera sin problemas, capturar el error para v0.2.3.
6. Vuelo completo R4.1/R4.2, boost, camara y montura, aterrizaje, Idle2, Run 30/39, Space despegue sin teletransporte. `DT_RootWeld` y `DT_NeckSeatWeld` intactos.
7. Animaciones publicadas: probar Idle2 y Run en sesión **real publicada** desde DOS clientes; que ambas se vean de forma sincronizada y con los impactos de cámara solo en el cliente jinete.
8. Verificar Output sin errores/Warnings no atendidos. Registrar props finales y commit probado.

## 6. Condiciones de parada

Si los barridos no anticipan la roca, el proxy crea un nuevo vuelco, el dragon flota/hunde o se pierden el vuelo/animaciones, restaurar copia de trabajo (sin afectar producción) y reportar logs del primer fallo. No transformar un fallo de fisica en un `PivotTo()` cada Heartbeat, ni subir MaxTorque sin mediciones. No limpiar respaldos aprobados ni hacer reset/destructive git. Solo merge/despliegue tras video + aprobacion del usuario.
