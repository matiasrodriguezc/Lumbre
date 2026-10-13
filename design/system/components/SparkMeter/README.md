# SparkMeter
Contador de chispas disponibles hoy y cuándo se recarga.

- El consumidor provee: disponibles / total, texto de estado y hora de recarga (local del usuario).
- Es una línea, no una tarjeta: una neurona chica (negra con el núcleo `spark` si hay chispa para encender, dormida en `border` si no), el estado en `headline` y la recarga en `ink-muted`, con un separador `border` abajo.
- Free: a la derecha, tres neuronitas que se llenan con las neuronas guardadas hoy hacia la próxima extra. Sin chispas, el texto explica cómo ganar una ("Guardá 2 neuronas para ganar 1 extra").
- Vive arriba en la pestaña Hoy y en el widget. En Pro muestra el uso justo diario, no un infinito.
