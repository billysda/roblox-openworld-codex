# Diagnóstico de Idle 2 / Run tras publicar v0.2.2

Fuente de verdad: scripts vivos de Roblox Studio, no snapshot histórico del 13 de octubre.
**NO modificar Input/FlightCamera/FlightAimState corregidos localmente por Antigravity.**

## Hallazgos firmes

- Los hashes `8c1794a653432e52f4a4cef328ee29ff` (Idle2) y
`eb17dbbd7c553982094c6755fd75e20c` (Run) proceden de
`KeyframeSequenceProvider:RegisterKeyframeSequence()`; no son IDs permanentes.
- `src/WyvernFlightV2/LandingV022/FlightAnimationServerV022.server.lua`
requiere `rbxassetid://NUMERO` y fue reportado DESHABILITADO por Antigravity.
- `src/WyvernFlightV2/LandingV01/FlightAnimation.client.lua` inicia
`LoadAnimation()` en pcall, pero no confirma que `track.Length > 0` y
que avanza `TimePosition` después de Play.
- El documento de restauración de giro R4.1 declara los archivos Idle2/Run
intactos, pero NO aporta medición de reproducción de AnimationTracks.

## Herramientas de solo lectura

- `tools/wyvern_animation_audit.client.lua` -> LocalScript temporal bajo StarterPlayerScripts
- `tools/wyvern_animation_audit.server.lua` -> Script temporal bajo ServerScriptService

Instalar en una COPIA del Place. Estos monitores no crean ni detienen pistas,
no cambian prioridades ni modifican Camera, Input, FlightController o welds.

1. Aterrizar con Ctrl -> `Wyvern_MotionState = GROUNDED_IDLE`.
2. Mantener W -> `Wyvern_MotionState = GROUNDED_RUN`.
3. Cliente: para cada estado registrar `Animator:GetPlayingAnimationTracks()`,
   nombres, `AnimationId`, `Length`, `TimePosition`, `WeightCurrent`
   y errores `Failed to load animation` en Output CLIENTE.
4. Servidor: comparar lista de pistas y estado Enabled del script server.
5. Localizar el Source EXACTO del reproductor `FlightAnimation` vivo. Comparar SHA-256
   y `desiredTrackName()` contra v0.1 en GitHub. **No asumir** que es ese script.
6. Si estado cambia a Grounded, pero solo FlightLoop reproduce, encontrar
   quién lo reproduce continuamente y si Idle2/Run tienen IDs validos.
7. Si `track.Length = 0` o `TimePosition` no avanza, reportar asset ID/permisos/
   errores de carga, no declarar éxito porque `Play()` devolvió.
8. Si ambos tracks están activos, medir prioridad y peso; desactivar reproductor
   competidor SOLO al migrar hacia el servidor y en la copia aislada.

## Reparación después del diagnóstico

- Publicar ambas **KeyframeSequence** ORIGINALES de
  `ServerStorage.RBX_ANIMSAVES.wyvernfbx` con cuenta/grupo que posee el Place,
  sin reexportar de Blender y sin alterar keyframes.
- Copiar IDs NUMÉRICOS emitidos por Roblox y asignarlos como
  `wyvernfbx.Animations.Idle2.AnimationId = "rbxassetid://..."`
  y `wyvernfbx.Animations.Run.AnimationId = "rbxassetid://..."`.
- Confirmar carga de cada pista individual desde el Animator ya existente,
  `Length > 0`, `TimePosition` creciente, misma postura/cinemática de pies.
- Sólo entonces habilitar `FlightAnimationServerV022` y deshabilitar el
  reproductor cliente antiguo, como UNA migración coordinada.
- Probar en Play Studio y servidor publicado con DOS clientes.
- Exportar Sources modificados (incluido Input corregido) a GitHub antes de
  etiquetar la versión como validada.

## Evitar regresiones

No reescribir el controlador de vuelo ni crear un segundo Animator.
No sustituir el Input recién corregido por el snapshot del repo.
No hacer reset --hard, force-push ni borrar backups.
