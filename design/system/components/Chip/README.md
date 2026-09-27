# Chip
Pill para dominios de un concepto, filtros de la bóveda y selección múltiple.

- Variantes: `static` (dominio, fondo `surface-alt`), `select` (filtro sin elegir, borde `border-strong`) y `on` (elegido: `accent-soft` + `accent-text` + borde `accent`).
- El consumidor provee: label corto (1–2 palabras), ícono opcional, estado.
- Los dominios NO tienen un color cada uno: se distinguen por texto e ícono. Así la pantalla no se llena de colores que compiten con la chispa.
- iOS: capsule button con `.bordered`; Android: `FilterChip` / `AssistChip` de M3.
