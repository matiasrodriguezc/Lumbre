# ProfileOption
Opción seleccionable del onboarding para elegir perfil creativo (multi-selección, máximo 2).

- El consumidor provee: ícono del sistema, título (`headline`), descripción de una línea (`callout` en `ink-muted`), estado seleccionado.
- Seleccionado: fondo `surface-alt`, borde de 2px `accent` (negro), ícono sobre `accent`.
- Perfiles iniciales: Software y apps, Contenido y escritura, Negocios, Diseño, y "Curiosidad libre".
- Semántica: en iOS es un toggle (`.isSelected` trait); en Android un `Modifier.toggleable` con rol Checkbox.
