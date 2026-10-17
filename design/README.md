# Design

Todo lo visual y el copy de Lumbre. Las reglas (color, tipografía, voz, mundo neuronal) están en `system/README.md`; si algo de esta carpeta las contradice, manda el sistema, y por encima `plan.md`.

## Índice

| Carpeta | Qué hay | Paso |
|---|---|---|
| `system/` | Design system: `tokens.json` (fuente única), `tokens.css`, componentes, logo, identidad neuronal (`identidad.html`, `identidad/generar.py`) | 1, 8 |
| `figma/` | Tokens como variables de Figma (modos Gris y Grafito; Tipografía iOS y Android): plugin "Lumbre tokens" y JSON para la importación nativa. Instrucciones en `figma/README.md` | 9 · MAT-221 |
| `copy/` | Copy es/en de todas las pantallas (`copy.json`) y `copy.py`, que lo vuelca al String Catalog de iOS y a `strings.xml` de Android y lo compara con el código. Ver `copy/README.md` | 10 · MAT-226 |
| `estados/` | Estados vacíos, de error, sin conexión y de contenido inaccesible: especificación (`README.md`), copy y mockups (`index.html`) | 11 · MAT-227 |
| `reveal/` | Coreografía del reveal de la chispa: línea de tiempo, curvas, hápticos, Reducir movimiento y diferencias con `SparkReveal.swift` (`README.md`), y prototipo animado (`index.html`) | 12 · MAT-225 |
| `compartir/` | Tarjeta para compartir (1080×1920, `tarjeta.html` a tamaño real) y widgets de iOS y Android (`index.html`, especificación en `README.md`) | 13 · MAT-228, MAT-229 |
| `prototipo/` | Prototipo navegable del loop con selector iOS/Android (`index.html`) y la propuesta de qué puede hacer el invitado (`invitado.md`, a confirmar) | 14 · MAT-223 |
| `test/` | Kit del test con 5 personas: guion (`guion.md`), el ícono solo (`icono.html`) y la planilla (`resultados.csv`) | 15 · MAT-224, MAT-210 |
| `shared/` | Base de los mockups: `maqueta.css` (teléfono, barras, sheets, piezas), `maqueta.js` (tema, plataforma, neuronas chicas), `arte.js` (los SVG de la identidad, generado por `arte.py`) y `plantilla.html` | — |
| `propuestas/` | Propuestas de diseño anteriores | — |

## Cómo ver los mockups

Los HTML cargan los SVG y el JS de `shared/`, así que conviene servirlos (con `file://` algunos navegadores bloquean partes):

```sh
python3 -m http.server 8765 -d design
# http://127.0.0.1:8765/prototipo/  ·  /reveal/  ·  /estados/  ·  /compartir/  ·  /test/icono.html
```

Todos tienen selector de tema (Gris, el default, y Grafito) y, donde aplica, de plataforma (iOS y Android).

## Generadores

| Script | Genera | Cuándo correrlo |
|---|---|---|
| `system/identidad/generar.py` | Logo, ilustraciones, exportes del ícono, `identidad.html` (requiere shapely) | Al cambiar una forma |
| `shared/arte.py` | `shared/arte.js` | Después de `generar.py` |
| `figma/generar_variables.py` | `figma/variables/` y `figma/plugin/` (`--check` para verificar) | Al cambiar `tokens.json` |
| `copy/copy.py` | Catálogo de iOS, `strings.xml` y CSV en `copy/build/` (`revisar-ios` compara con el código) | Al cambiar `copy.json` o el copy del código |
