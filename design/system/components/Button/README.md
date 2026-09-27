# Button
Botón de acción en cuatro variantes: `primary` (magenta, una por pantalla), `secondary` (contorno), `ghost` (texto magenta) y `pro` (violeta, solo para compras y funciones Pro).

- El consumidor provee: label (verbo + objeto, sentence case), ícono opcional a la izquierda, acción y estado `disabled`.
- `primary`: fondo `accent`, texto `on-accent`. Alto mínimo 48pt/dp. `glow-spark` solo en el CTA del reveal de la chispa.
- En iOS se implementa con `.borderedProminent` + `.tint(accent)` + `.controlSize(.large)`; en Android con `Button` de M3 y `ButtonDefaults.buttonColors(containerColor = accent, contentColor = onAccent)`.
- No uses dos `primary` en la misma pantalla. No uses `pro` para acciones gratuitas.
