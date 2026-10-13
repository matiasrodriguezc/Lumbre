# Chip
Pill para dominios de una neurona, filtros de la Red y selección múltiple.

- Variantes: `static` (dominio, fondo `surface-alt`), `select` (filtro sin elegir, borde `border-strong`) y `on` (elegido: relleno `accent`, negro, con texto `on-accent`).
- El consumidor provee: label corto (1–2 palabras), ícono opcional, estado.
- Los dominios NO tienen un color cada uno: se distinguen por texto e ícono. Así la pantalla no se llena de colores que compiten con la chispa.
- iOS: capsule button con `.bordered`; Android: `FilterChip` / `AssistChip` de M3.
