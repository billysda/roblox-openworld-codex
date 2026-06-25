Place: CodexAvanceTest
DataModel: Place1
Fecha: 2026-06-16 21:17:34 -05:00
Snapshot: CodexAvanceTest_Current

Sistemas activos:
- Pasture v1.2 (Scripts exportados a snapshot, SheepPerFlock ajustado a 2)
- Pasture GrazingService v0
- InventoryService
- EggService
- StorageService
- SlingshotService
- SlingshotController
- SlingshotAnimateGuard
- Slingshot Fire v0 con Egg como municion
- DragonRaidService existe
- DragonRaidAutoTest existe pero queda Disabled=true

Ultimo comportamiento confirmado:
- recoger Egg suma InventoryService.Egg
- Storage muestra Egg
- Honda dispara usando Egg
- SlingshotService consume Egg
- CarryChicken bloquea Honda
- Storage bloquea Honda

Riesgos:
- DragonRaidService se conserva, pero no se ejecuta automaticamente
- Fire v0 no tiene dano todavia
- Honda sigue siendo Tool normal con Handle/RightGrip
- El repo todavia es snapshot, no fuente Rojo

Issue trabajado: [Protected Change] Refactorización del Bastón (Plan C - Cono de Presión)
Archivos tocados: BastonTestService.lua, BastonTestController.client.lua
Qué cambió: Se eliminó el uso problemático de LinearVelocity aportado por Claude. Se implementó un algoritmo matemático de "Cono de Presión" desde el servidor que detecta ovejas en un ángulo de 60° y las aleja usando Humanoid:MoveTo(), respetando la gravedad y animaciones nativas.
Qué falta probar: Confirmar en Roblox Studio (Play) que al activar la herramienta "Baston" frente a las ovejas, estas caminen en dirección contraria sin flotar ni temblar.
Riesgos conocidos: Si el script de la oveja (Pasture.M.Sheep) fuerza su propio MoveTo muy agresivamente en cada frame, podría pelear con este script. De ser así, se requerirá un flag de "override" en Sheep.lua en la próxima iteración.

Issue trabajado: Refactorización del Bastón de pastoreo (Plan C - Cono AI).
Archivos tocados: BastonTestService.lua, Pasture/M/Sheep.lua, STATUS.md.
Qué cambió: Se eliminó el empuje de físicas directas. El servidor del bastón ahora proyecta un vector de dirección (BastonFleeDir) como atributo. En Sheep.lua, la oveja lee esto y reacciona usando su propia IA con el estado "PanicMove" y la velocidad "Cfg.MoveAnim.PanicSpeed", replicando exactamente el comportamiento natural de cuando huye del jugador.
Qué falta probar: Confirmar si la velocidad de huida es la adecuada al uso continuo del bastón.

Issue trabajado: Corrección final del Bastón (Eliminación de empuje artificial).
Archivos tocados: BastonTestService.lua, Sheep.lua.
Qué cambió: Se eliminó la actualización constante del vector de huida para evitar el efecto de "viento/volante". Las ovejas ahora eligen una dirección recta y huyen solas por 4.5 segundos a velocidad natural (15, Run) sin frenar en seco cuando el jugador suelta el clic, logrando un comportamiento orgánico de rebaño.

Issue trabajado: Fix definitivo del Bastón con lógica Event-Driven y Checkpoints a color.
Archivos tocados: BastonTestService.lua, Sheep.lua, BastonTestController.client.lua
Qué cambió: Se eliminó el Heartbeat del servidor. Ahora la detección se calcula en un solo frame ('one-shot') al recibir el evento de clic, ampliando el rango a 50 studs y 90 grados. Se agregaron prints con RichText (colores) para debug intuitivo.