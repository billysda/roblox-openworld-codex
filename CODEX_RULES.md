# CODEX_RULES.md

## Proyecto
Juego Roblox de mundo abierto con Homestead, gallinas, huevos, storage, combate y sistemas futuros de economía/dragones.

## Estado importante del proyecto
- Pasture funciona y NO debe tocarse salvo autorización explícita.
- CarryChicken funciona y debe mantenerse estable.
- Storage/UI es sensible porque se conectará con huevos y munición.
- Honda BattleMode funciona, pero es sensible en transiciones.
- Death/Reset tiene prioridad máxima.
- Homestead puede tocarse solo cuando el issue lo indique.

## Animaciones confirmadas
- CarryChicken: rbxassetid://84371476515785
- Chicken Run: rbxassetid://118651681311536

## CarryChicken
- Usa atributo del jugador `CarryingChicken`.
- Si `CarryingChicken == true`, el jugador NO debe disparar.
- No modificar ChickenCarryAnimClient salvo issue protegido.

## Storage
- Separar huevos guardados de munición activa:
  - EggStorage = huevos guardados en cofre/storage.
  - EggAmmo = huevos cargados para disparar.
- No mezclar storage con munición sin validación de servidor.

## Combate con huevos
- El cliente puede pedir disparar.
- El servidor decide si puede disparar.
- El servidor descuenta EggAmmo.
- Si EggAmmo <= 0, no debe disparar.
- Si el jugador murió, reseteó, está cargando gallina o está en UI crítica, no debe disparar.

## Sistemas protegidos
Un issue normal NO puede tocar:
- ServerScriptService.Pasture
- CarryChicken
- ChickenCarryAnimClient
- Honda BattleMode
- Death/Reset
- Templates principales de Gallina y EggTemplate

Para tocar un sistema protegido, el issue debe empezar con:
[Protected Change]

Y debe incluir:
- Qué sistema se autoriza tocar.
- Qué archivos puede tocar.
- Qué archivos no puede tocar.
- Qué comportamiento debe seguir funcionando.
- Cómo se prueba.
