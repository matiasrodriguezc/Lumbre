# Capturas de tienda (paso 66)

Guion, títulos y orden en `docs/tiendas/capturas.md`. Formato App Store 6,9" (1320×2868): Apple escala al resto.

| Ruta | Qué es |
|---|---|
| `crudas/<idioma>/` | Las pantallas tal cual salen del simulador (iPhone 17 Pro Max, `-mock`, barra de estado 9:41) |
| `plantilla.html` | Compone una captura: fondo `gray`, la red de neuronas arriba, el título en Fraunces 600 y la pantalla |
| `componer.sh` | Genera las 7 con Chrome sin ventana: `design/tiendas/componer.sh es` |
| `capturas/<idioma>/` | Las finales, listas para subir |

## Cómo se sacan las crudas

1. Barra de estado limpia: `xcrun simctl status_bar booted override --time 9:41 --batteryState discharging --batteryLevel 100`.
2. Consentimiento para IA aceptado: `xcrun simctl spawn booted defaults write com.matiasrodriguezc.lumbre aiConsent -bool YES`.
3. La app con `-mock` (o `-mockPro` para el planificador) y `-AppleLanguages "(es)" -AppleLocale es_AR`, y `-open concept|vault|planner|share` para ir directo a cada pantalla. Para el set en inglés: `-AppleLanguages "(en)" -AppleLocale en_US -mockLanguage en`, que pasa también los datos de prueba (`MockData`) al inglés.
4. El reveal (1) y Hoy (2) se sacan tocando "Encender la chispa"; Capturar (3), con el + y el texto pegado desde el portapapeles (`xcrun simctl pbcopy`, en UTF-8).

`-open revealed` no sirve para la captura 2: deja el contador gastado y la tarjeta sin encender. Es solo del atajo de depuración; el recorrido real anda bien.

