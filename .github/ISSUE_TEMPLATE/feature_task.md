---
name: Feature task
about: Definir una tarea pequena para Codex usando GitHub Issues.
title: "[Feature] "
labels: feature
assignees: ""
---

## Objetivo
Describe el cambio solicitado en una oracion corta.

## Alcance permitido
Que puede tocar Codex en este issue.

- Archivos permitidos:
- Sistemas permitidos:

## Fuera de alcance
Que no debe tocar Codex en este issue.

- Archivos prohibidos:
- Sistemas protegidos:

## Labels recomendados
Agrega `codex-ready` solo cuando el issue este listo para que Codex lo trabaje.

Labels de area sugeridos:
- combat
- homestead
- storage
- ui

## Reglas de gameplay relevantes
Incluye cualquier regla que Codex deba respetar.

- Death/Reset tiene prioridad maxima.
- Si `CarryingChicken == true`, el jugador no debe disparar.
- `EggStorage` y `EggAmmo` deben mantenerse separados.
- El servidor debe validar acciones importantes.

## Cambio protegido
Si este issue toca un sistema protegido, el titulo debe empezar con `[Protected Change]` y esta seccion debe estar completa:

- Sistema autorizado:
- Archivos que se pueden tocar:
- Archivos que no se pueden tocar:
- Comportamiento que debe seguir funcionando:
- Como se prueba:

## Criterios de aceptacion
- [ ] El cambio es pequeno y localizado.
- [ ] No toca sistemas protegidos sin autorizacion.
- [ ] No crea RemoteEvents duplicados.
- [ ] No introduce WaitForChild infinito.
- [ ] Actualiza `STATUS.md`.

## Prueba manual en Roblox Studio
- [ ] No requiere prueba manual.
- [ ] Requiere prueba manual y debe quedar en `codex-review`.

