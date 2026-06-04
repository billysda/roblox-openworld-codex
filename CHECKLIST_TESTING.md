# CHECKLIST_TESTING.md

## Pruebas para sistema de huevos / disparo

### Recolección
- [ ] El jugador puede recoger huevo.
- [ ] EggAmmo o EggStorage sube correctamente.
- [ ] No se duplica el huevo.
- [ ] El huevo desaparece o queda marcado como recolectado.

### Munición
- [ ] Si EggAmmo > 0, el jugador puede disparar.
- [ ] Al disparar, EggAmmo baja en 1.
- [ ] Si EggAmmo == 0, el jugador no puede disparar.
- [ ] El servidor bloquea el disparo, no solo el cliente.

### Storage
- [ ] EggStorage y EggAmmo son valores separados.
- [ ] Cargar munición desde Storage baja EggStorage.
- [ ] Cargar munición sube EggAmmo.
- [ ] No hay duplicación al abrir/cerrar Storage.

### CarryChicken
- [ ] Si CarryingChicken == true, no puede disparar.
- [ ] Al soltar gallina, puede disparar si tiene EggAmmo.
- [ ] No se rompe animación de cargar gallina.

### Death / Reset
- [ ] Al morir, no puede disparar.
- [ ] Al resetear, no queda disparo bloqueado permanentemente.
- [ ] No hay errores rojos en Output.

### UI
- [ ] La UI muestra EggAmmo correcto.
- [ ] La UI no inventa valores localmente.
- [ ] La UI escucha el valor real del servidor.

### Multiplayer
- [ ] Un jugador no consume munición de otro.
- [ ] No hay daño friendly fire si hay equipos.
- [ ] El disparo se replica correctamente.
