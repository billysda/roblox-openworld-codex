---
name: Bug report
about: Reportar un bug pequeno, verificable y listo para triage.
title: "[Bug] "
labels: bug
assignees: ""
---

## Resumen
Describe el bug en una oracion corta.

## Sistema afectado
Marca los sistemas relacionados:

- [ ] combat
- [ ] homestead
- [ ] storage
- [ ] ui
- [ ] Pasture
- [ ] CarryChicken
- [ ] Death/Reset
- [ ] Otro:

## Pasos para reproducir
1.
2.
3.

## Resultado actual
Que ocurre ahora.

## Resultado esperado
Que deberia ocurrir.

## Archivos o scripts relacionados
Lista rutas si las conoces.

## Cambio protegido
Si este bug requiere tocar un sistema protegido, el titulo del issue debe empezar con `[Protected Change]` y debe explicar:

- Sistema autorizado.
- Archivos que se pueden tocar.
- Archivos que no se pueden tocar.
- Comportamiento que debe seguir funcionando.
- Como se prueba.

## Validacion requerida
- [ ] Revisar errores obvios de Lua.
- [ ] Evitar RemoteEvents duplicados.
- [ ] Evitar WaitForChild infinito.
- [ ] Verificar autoridad importante en servidor.
- [ ] Requiere prueba manual en Roblox Studio.

