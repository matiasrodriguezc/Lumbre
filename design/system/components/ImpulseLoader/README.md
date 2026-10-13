# ImpulseLoader
El pulso: un impulso `info-text` recorre un axón dormido en 1,2 s. Indicador de carga propio para destilar y encender.

- Solo para "Destilando…" y para encender una chispa. Cualquier otra carga usa el spinner del sistema (`ProgressView`, `CircularProgressIndicator`).
- El consumidor provee el texto debajo ("Destilando…") y el rol de estado para lectores de pantalla.
- Con Reducir movimiento, el impulso queda quieto en el medio del axón.
- iOS: `ImpulseLoader()` en LumbreDesign.
