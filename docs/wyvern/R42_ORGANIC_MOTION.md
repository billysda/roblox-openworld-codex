# WyvernFlightV2 R4.2 — Organic Motion (prueba aislada)

**Estado:** código publicado, **sin instalar en Roblox Studio ni probar en Play**. R4.1 debe seguir intacta. El usuario aprobó las mejoras de aleteo variable y movimientos orgánicos de cola/cuello/cabeza; **audio queda descartado**.

## Versiones y modelo
- Proyecto: `billysda/roblox-openworld-codex`; PlaceId que deberá confirmar MCP: `100008359356261`.
- Rama: `feat/wyvern-r42-organic-motion`; PR e Issue asociados, sin merge hasta Play y aprobación.
- Base Git de desarrollo: `75cfb7a2737ad682a35a4d3f4cd1f09e4e143109` (no implica que Studio esté igual).
- Modelo observado en snapshot Edit 2026-10-13: `Workspace.wyvernfbx.RootPart.Cadera_01`; `DT_Root` publica atributos de vuelo; `AnimationController.Animator` reproduce `rbxassetid://96071143174783`.
- Snapshot: `docs/studio_snapshot/current/WORKSPACE_TREE.md`, líneas ~1602–1685. **No desplegar los scripts del snapshot como si fueran actuales.**

## Archivos NUEVOS del PR y destino Studio

| Source GitHub | Tipo Studio | Destino (crear, sin sustituir existentes) |
| --- | --- | --- |
| `src/WyvernFlightV2/R42/OrganicMotionConfigR42.lua` | ModuleScript | `ReplicatedStorage.WyvernFlightV2.OrganicMotionConfigR42` |
| `src/WyvernFlightV2/R42/OrganicMotionR42.client.lua` | LocalScript | `StarterPlayer.StarterPlayerScripts.WyvernFlightV2.OrganicMotionR42` |

**No se debe reemplazar** `FlightAnimation` (reproduce el loop a velocidad base 1x), `Input`, `FlightCamera`, `FlightController`, `FlightAimState`, `WyvernFlightConfig` ni huesos/modelos. Los efectos son exclusivamente **locales**. Ningún `RemoteEvent` nuevo.

## Diseño

1. **Aleteo:** localizar el `AnimationTrack` que ya usa `WyvernFlightConfig.AnimationId` en el Animator del wyvern. Interpolar `Speed` por `Flight_Speed` y `Flight_IsBoosting`, llamar `:AdjustSpeed()`. `0.85x` con freno fuerte → `1.00x` crucero → `1.10x` aceleración → `1.20x` boost. Cambia la *reproducción de toda la animación*, no solamente las alas; validar visualmente que patas/cuerpo no aceleran de manera extraña. No cargar una segunda animación.
2. **Cola:** 7 huesos en cadena desde `Cola_1_076` hasta `Cola_7_082`. El parámetro `Flight_HeadingDeltaPerSecond` controla una desviación total máxima de ~16° distribuida por pesos entre los siete huesos; el retraso aumenta progresivamente hacia la punta. Una oscilación mínima ayuda a evitar rigidez.
3. **Cuello/cabeza:** huesos `Cuello_1_025`, `Cuello_2_026`, `Cuello_3_027`, `Cabeza_028`; reaccionan sutilmente al `Flight_FinalTurnIntent` y `Flight_FinalPitchIntent`. El máximo previsto del cuello es ~4° distribuidos, cabeza ~1.6° yaw y ~0.7° pitch.
4. **Animador:** `PreAnimation` ajusta velocidad antes del paso del Animator; `PreSimulation` aplica el offset `Bone.Transform` **después** del paso de animaciones. Se evita la acumulación de offsets si el Animator no refresca un hueso. Los ejes/signos `LocalYawAxis`, `LocalPitchAxis`, `DirectionSign`, `YawSign` y `PitchSign` son **suposiciones iniciales a calibrar** con las orientaciones reales del rig.
5. **Rollback:** deshabilitar `OrganicMotionR42` **ANTES DE PLAY** o establecer su atributo `OrganicMotionEnabled=false` en Studio (modo Edit) y repetir Play. Con el atributo se permite además activar/desactivar en Play; el código intenta restaurar `AnimationTrack.Speed` y los offsets que aún le pertenezcan. Si otro script escribió un `Bone.Transform` diferente, deliberadamente no lo sobrescribe.

## Plan seguro para Antigravity (MCP)

**FASE 0 — preservar R4.1 sin sobrescritura:** confirmar PlaceId + scripts V2 activos en Studio y verificar `git status`. Leer Source completo, propiedades y SHA-256 exacto de los seis componentes V2 originales; guardar copia íntegra de la versión **actual de Studio** y registro de la animación/huesos/atributos en una rama de respaldo identificada por SHA. No confiar en captura Edit histórica como código vigente. No tocar el resto de sistemas.

**FASE 1 — inspección de rig:** consultar nombres, clases, parent y `Bone.CFrame` (sólo lectura) para cola, cuello, cabeza; comprobar que el `AnimationTrack` es realmente localizable por `Animation.AnimationId`. Si faltan piezas o R4.1 difiere de forma incompatible, informar bloqueo antes de instalar.

**FASE 2 — integración:** en Edit crear sólo el `ModuleScript` y `LocalScript` nuevos en las rutas arriba. Inspeccionar SHA-256 de Source GitHub y Source Studio, registrar resultados. No tocar la animación importada ni otros scripts.

**FASE 3 — Play y calibración:**
- Comprobar automontura, cámara, mouse aim, giro izquierdo/derecho, W/S, Space/LCtrl, Shift y R (regresión R4.1).
- Leer `AnimationTrack.Speed` / atributo local `R42_AnimationMultiplier`: probar ralentización ~0.85, crucero ~1.00, aceleración ~1.10 y boost ~1.20; una transición suavizada debe evitar reinicios de animación. Aceptar que no todos los valores exactos aparecen sin forzar sus condiciones reales de velocidad.
- Girar izquierda/derecha y comprobar cola curva progresiva **sin torsión**, cuello/cabeza sutiles con sentido correcto. Si ejes o signos están mal, editar *solo* `OrganicMotionConfigR42.lua` y registrar nuevos SHA en rama del PR.
- Mantener marcha recta y probar 2 minutos: sin desviación creciente, jitter o deformaciones acumuladas; verificar que los offsets no estropean huesos no animados.
- Toggle A/B `OrganicMotionEnabled=false` o deshabilitar addon antes de Play y reiniciar: R4.1 debe conservarse idéntico. Rehabilitar para comparar.
- Revisar Output y, cuando sea posible, rendimiento básico del addon con un solo dragón y un jugador.

**FASE 4 — reportar:** dejar en Issue/PR resultados `PlaceId`, SHA de Source R4.1 respaldados, HEAD exacto del PR, SHA-256 del addon en Git/Studio, pruebas que realmente se ejecutaron, capturas o vídeo si son útiles y correcciones (si hubiera). No afirmar Play PASS antes de prueba real. No mergear sin aprobación del usuario.

## Riesgos abiertos (a validar)
- Una animación importada puede contener keys de cola/cuello que interactúen con `Bone.Transform`. `PreSimulation` es el orden previsto por Roblox, pero debe comprobarse en Play con el rig concreto.
- Orientación local de cada Bone: ejes Y/X pueden no corresponder visualmente a yaw/pitch. Calibrar config antes de subir amplitudes; empezar con desplazamientos sutiles.
- Si un hueso no recibe keys cada cuadro, `Bone.Transform` puede retener el valor anterior; por eso el addon intenta retirar su offset anterior cuando detecta que el Animator no lo modificó.
- `GetPlayingAnimationTracks()` no garantiza localizar el track si éste todavía no ha arrancado; se reintenta cada 0.4 s. Si no existe, la modificación de playback espera y la pose secundaria no se inicia.
- El efecto no cambia sustentación ni se replica como física autoritativa de servidor. Es un embellecimiento local para **un wyvern de pruebas**; adaptar a muchos jugadores/dragones requeriría ownership y replicación de animaciones revisadas por separado.

**No activar** el antiguo watcher programado de 5 minutos ni el flujo Gemini/Drive.
