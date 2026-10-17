# Build in public (paso 7)

Kit para H12 (prep MAT-219). Arranca cuando estén la landing (`web/`) y los handles.

| Archivo | Qué es |
|---|---|
| `calendario.md` | 4 semanas, red por red, con lo que se mide cada viernes |
| `chispas-del-dia.md` | Las 20 chispas de la serie diaria |
| `plantillas.md` | Plantillas de post para X y LinkedIn, y guiones de TikTok/Reels |
| `plantilla-visual.html` | La imagen de cada chispa en tres formatos (X 1600×900, feed 1080×1350, historia 1080×1920) y dos temas, con botón para bajar el PNG. Usa `design/system/tokens.css` y el arte de `design/shared/arte.js` |
| `plantilla-visual.src.html`, `generar.py` | Fuente de la plantilla. Si cambiás las chispas o el diseño: `python3 docs/build-in-public/generar.py` |

La plantilla hay que abrirla desde un servidor local para que carguen los tokens y el arte (por ejemplo, `python3 -m http.server` en la raíz del repo y `http://localhost:8000/docs/build-in-public/plantilla-visual.html`). Parámetros: `?n=1..20&formato=x|feed|historia&tema=gris|grafito&limpio=1`.
