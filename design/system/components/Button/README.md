# Button
Botón de acción en cuatro variantes: `primary` (negro, una por pantalla), `secondary` (contorno), `ghost` (gris subrayado) y `pro` (negro con la palabra Pro, solo para compras y funciones Pro).

- El consumidor provee: label (verbo + objeto, sentence case), ícono opcional a la izquierda, acción y estado `disabled`.
- `primary`: fondo `accent` (negro en gris, hueso en grafito), texto `on-accent`. Si la acción enciende algo ("Encender la chispa"), lleva adelante un punto `spark` de 10pt: el rosa siempre sobre negro. Alto mínimo 48pt/dp.
- En iOS se implementa con `.borderedProminent` + `.tint(accent)` + `.controlSize(.large)`; en Android con `Button` de M3 y `ButtonDefaults.buttonColors(containerColor = accent, contentColor = onAccent)`.
- No uses dos `primary` en la misma pantalla. No uses `pro` para acciones gratuitas.
