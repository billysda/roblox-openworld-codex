Place: CodexAvanceTest
DataModel: Place1
Fecha: 2026-07-21
Snapshot: CodexAvanceTest_Current

Issue trabajado: #13 [Protected Change] Migrar corral global a configuracion por casa
Archivos tocados: MANIFEST.md, STATUS.md, ServerScriptService/Pasture/M/Cfg.lua, ServerScriptService/Pasture/M/Flock.lua, ServerScriptService/Pasture/M/Sheep.lua
Que cambio: Se agregaron nombres/defaults de Pen en Cfg, Flock cachea referencias de corral por casa y solo usa fallback legacy global si la casa no tiene configuracion valida, y Sheep usa asistencia de entrada en dos etapas PenEntrance -> PenCenter. En Workspace se crearon PenEntrance en las 10 casas, marcados NeedsManualPlacement=true y con PenAssistEnabled=false porque no hay entrada por casa inequivoca.
Que falta probar: Colocar manualmente cada PenEntrance en la abertura real del corral, activar PenAssistEnabled por casa cuando corresponda, conectar PenOpen a una puerta por casa, y validar en Play que G/F/corral/baston siguen funcionando.
Riesgos conocidos: Mientras PenEntrance siga con NeedsManualPlacement=true y PenAssistEnabled=false, los rebanos usan fallback legacy global; no se modifico SheepPenGate.Script porque la unica puerta detectada sigue siendo global.

Issue trabajado: #12 [Protected Change] Retirar proteccion de acantilados y restaurar comportamiento previo
Archivos tocados: MANIFEST.md, STATUS.md, ServerScriptService/Pasture/M/Cfg.lua, ServerScriptService/Pasture/M/Sheep.lua
Que cambio: Se retiro unicamente la proteccion de bordes del issue #11 por falsos positivos en pequenos desniveles. Se elimino Cfg.Ledge, Sheep:HasSafeGroundAhead(direction) y el bloqueo de MoveInDirection que detenia o desviaba ovejas por deteccion de borde.
Que falta probar: Play manual para confirmar que G conserva rango 220, duracion 30s, parada 6 studs, respuesta inmediata y reduccion de miedo del dueno; confirmar F/corral/baston sin cambios.
Riesgos conocidos: Sin proteccion de acantilados, las ovejas vuelven al comportamiento previo del issue #10 y pueden avanzar sobre desniveles peligrosos si el terreno lo permite.

Issue trabajado: #10 [Protected Change] Aplicar v1 del destino marcado y revisar hover de seleccion
Archivos tocados: MANIFEST.md, STATUS.md, ServerScriptService/Pasture/Main.lua, ServerScriptService/Pasture/M/Cfg.lua, ServerScriptService/Pasture/M/Flock.lua, ServerScriptService/Pasture/M/Sheep.lua, StarterPlayerScripts/PastureClient.client.lua
Que cambio: Se aplico la mejora exacta indicada para la orden G: distancia maxima 220, duracion 30s, parada 6 studs, validacion local antes de marcador, CommandActive/CommandTarget en flockData y menor miedo del dueno mientras CommandTarget esta activo. Main conserva validacion de servidor usando Cfg.CommandTarget.MaxDistanceFromPlayer, con fallback 220.
Que falta probar: Play manual en Roblox Studio para confirmar que G responde desde mayor distancia, ambas ovejas obedecen, F cancela el destino y corral/baston mantienen prioridad.
Riesgos conocidos: v1 sigue sin Pathfinding; puntos no navegables pueden fallar. La busqueda de hover/seleccion no encontro SelectionBox, Highlight, Handles, SelectionService ni Mouse.Target en scripts del juego; solo GetMouse() en PastureClient para el raycast, por lo que el hover visual parece comportamiento de Roblox Studio durante Play/Run.

Issue trabajado: #8 [Protected Change] Actualizar snapshot principal desde Roblox Studio
Archivos tocados: MANIFEST.md, AnimalService.lua, Chicken.lua, EggService.lua, HomeService.lua, StorageService.lua, HomesteadClient.client.lua, PasturePromptClient.client.lua, SlingshotController.client.lua
Que cambio: Se actualizaron unicamente los 8 scripts autorizados del snapshot desde el Source real de Roblox Studio y se registraron sus hashes normalizados en MANIFEST.md.
Que falta probar: Revision manual del snapshot y validacion humana final antes de marcar el issue como cerrado.
Riesgos conocidos: DragonRaidService y los 13 scripts STUDIO_ONLY quedaron intactos por exclusion explicita del issue.

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

Issue trabajado: Fix de Prioridad en la huida EXCLUSIVA del Bastón y reducción de tiempo a 3s.
Archivos tocados: BastonTestService.lua, Sheep.lua.
Qué cambió: Se movió la inyección del bastón en Sheep.lua por encima de HandleSequence para interrumpir animaciones. Esta interrupción está condicionada estrictamente a la variable BastonSpookTime, garantizando que si el jugador se acerca sin usar la herramienta, la oveja mantenga su lógica de escape y prioridades originales intactas. Se redujo el tiempo a 3.0s.

Issue trabajado: Mejora de UX en pastoreo (Atracción Magnética).
Archivos tocados: Flock.lua, Sheep.lua.
Qué cambió: Se modificó Flock:UpdateBrain para localizar y enviar la posición de la zona de pastoreo al flockData. En Sheep.lua, se añadió una lógica justo antes de StepCalm que detecta si la oveja está en un radio de atracción (ZoneRadius + 25 studs). Si lo está, la oveja camina automáticamente hacia el centro de la zona de pastoreo para facilitar la jugabilidad, a menos que el jugador la esté arreando activamente.

Issue trabajado: Fix del bug "Pared invisible" al entrar a la zona de pastoreo.
Archivos tocados: Sheep.lua.
Qué cambió: Se rediseñó la atracción magnética. Cada oveja ahora calcula un punto estático personal dentro de la zona basado en su índice para evitar amontonamiento. Se eliminó la condición de detención abrupta y se añadió una proyección vectorial que refleja la dirección de deambular (CalmDirection) hacia el centro si la oveja intenta salir de la zona, logrando que entren fluidamente y se mantengan dentro del círculo de forma autónoma.

Issue trabajado: Fix del conflicto entre Recall (F) y Atracción de GrazingZone (Stutter y Loop IsLost).
Archivos tocados: Sheep.lua.
Qué cambió: Se rediseñó la lógica de atracción en Sheep.lua. Ahora la atracción magnética solo se activa si el centro del rebaño (Flock.Center) está a menos de 15 studs del borde de la zona. Esto evita que la zona secuestre a las ovejas cuando el jugador las llama desde lejos (resolviendo el efecto de barrera invisible). Además, se eliminó la restricción rígida de "personalTarget" para que una vez dentro de la zona puedan deambular libremente sin tartamudear.

Issue trabajado: Sistema dinámico de Corral (Pen Zone) mediante Part física.
Archivos tocados: Flock.lua, Sheep.lua.
Qué cambió: Se integró la lectura de la pieza "SheepPenZone". Cuando el atributo IsOpen es false, el Flock desconecta su centro del jugador, anclándolo al corral, y las ovejas rebotan internamente. Al cambiar IsOpen a true, se calcula un PenExitTarget usando el LookVector de la pieza, atrayendo a las ovejas hacia la salida automáticamente (Olor a Libertad) hasta cruzar el umbral.

Issue trabajado: Simplificación de la lógica del Corral (Pen Zone).
Archivos tocados: Flock.lua, Sheep.lua y generación en Workspace.
Qué cambió: Se eliminó la lógica de la puerta y la dirección de salida. El corral ahora es una pieza plana (cilindro acostado). Si IsOpen es false, las ovejas rebotan hacia el centro del tapete. Si IsOpen es true, la restricción desaparece por completo y las ovejas simplemente retoman su IA natural para deambular libres o seguir al jugador.

Issue trabajado: Fix de pánico del jugador dentro del corral (SheepPenZone).
Archivos tocados: Flock.lua, Sheep.lua.
Qué cambió: En Flock.lua, si el corral está cerrado (IsOpen = false), se establece ownerRoot = nil para que las ovejas no consideren al jugador una amenaza y no huyan al acercarse. En Sheep.lua, la restricción de radio del corral se movió a la primera línea de StepAI, actuando como un muro absoluto de máxima prioridad que cancela cualquier estado (incluso pánico por bastón) si intentan salir del tapete cerrado.

Issue trabajado: Fix de orden de ejecución en Flock.lua (Supresión de pánico).
Archivos tocados: Flock.lua.
Qué cambió: Se movió el bloque de detección del corral (SheepPenZone) al principio de la función UpdateBrain. Al anular ownerRoot = nil antes del cálculo de presión (PressureRadius), se garantiza que IsMoving permanezca en false, erradicando por completo el instinto de huida de las ovejas mientras el corral está cerrado.

Issue trabajado: Fix de jerarquía del Corral y adición de Logs de depuración.
Archivos tocados: Flock.lua, Sheep.lua.
Qué cambió: Se corrigió la ruta de búsqueda en Flock.lua para que busque "SheepPenZone" dentro de la carpeta "SheepPens". Se añadieron prints de colores (RichText) con cooldowns de 2 y 5 segundos en Flock y Sheep para rastrear el estado del corral (Encontrado/Error/Muro) sin generar lag en la consola.

Issue trabajado: Creación de puerta funcional y área de succión automatizada.
Archivos tocados: Flock.lua, Sheep.lua, Estructura en Workspace.
Qué cambió: Se programó un script procedimental que genera una puerta con ProximityPrompt y un área de aproximación (SheepPenApproachZone) dentro de la carpeta SheepPens. Se modificó Flock.lua y Sheep.lua para que, si las ovejas están dentro del área de aproximación y la puerta está abierta, caminen solas hacia el centro del corral.

Issue trabajado: Filtrado fiel de detección en SheepPenApproachZone (Bucle de succión).
Archivos tocados: Sheep.lua.
Qué cambió: Se rediseñó el bloque de control del corral en Sheep:StepAI. Se introdujo el atributo dinámico JustReleased. Al abrir la puerta, las ovejas internas adquieren inmunidad temporal para poder salir de la alfombra sin ser succionadas. Al alejarse al campo, el flag se extingue, permitiendo que la succión funcione de manera fiel únicamente cuando regresan de pastar.

Issue trabajado: Fix de conflicto de imanes (GrazingZone vs PenApproach).
Archivos tocados: Sheep.lua.
Qué cambió: Se eliminó la succión omnidireccional del bloque GrazingZone en Sheep.lua, conservando únicamente su rebote interno. Además, se le añadió la condición JustReleased para que las ovejas no queden atrapadas en la zona verde cuando la puerta del corral se abre y se les ordena salir. La alfombra de aproximación ahora es el único imán de entrada válido en todo el juego.

Issue trabajado: Fix de glitch en ovejas externas al cerrar corral.
Archivos tocados: Flock.lua, Sheep.lua.
Qué cambió: Se eliminó la mutación global en Flock.lua que forzaba ownerRoot=nil al cerrar la puerta. En Sheep.lua se purgó el código sobrante; ahora, si la valla se cierra y la oveja está afuera, el motor del corral se ignora por completo. La oveja mantiene su lógica de seguimiento intacta y ya no se bugea.
