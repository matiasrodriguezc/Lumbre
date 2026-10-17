# Tokens en Figma

Paso 9 de `plan-ejecucion.md` (prep de MAT-221). `design/system/tokens.json` exportado como variables de Figma, con el tema gris como modo por defecto y el grafito como segundo modo. Todo sale de un script: nunca edites a mano lo de `variables/` ni lo de `plugin/`.

```sh
python3 design/figma/generar_variables.py          # regenera variables/ y plugin/
python3 design/figma/generar_variables.py --check  # falla si quedó algo desactualizado respecto de tokens.json
```

## Qué se crea

| Colección | Modos | Variables |
|---|---|---|
| **Color** | Gris (default), Grafito | 25 colores en grupos: `marca/` (neuron, gray, graphite, bone, spark), `superficie/` (bg, surface, surface-alt, scrim), `texto/` (ink, ink-muted, info-text, accent-text, pro-text), `borde/` (border, border-strong, focus-ring), `accion/` (accent, on-accent, accent-soft, pro, on-pro), `estado/` (success, warning, danger). `accent` y `pro` son alias de `texto/ink`, como en tokens.json |
| **Espaciado** | Valor | `espacio/space-1` a `space-10` y `radio/radius-sm` a `radius-full` |
| **Tipografía** | iOS, Android | `familia/display` (Fraunces) y `familia/text` (SF Pro Text en iOS, Roboto Flex en Android); tamaño e interlineado de cada estilo (`texto/body/tamano`…). En Android, body es 16/24 (bodyLarge), como dice tokens.json |

Además, el plugin crea:

- **16 estilos de texto:** `iOS/spark-hero`, `iOS/counter`, `iOS/title-1`, `iOS/title-2`, `iOS/headline`, `iOS/body`, `iOS/callout`, `iOS/caption` y los mismos en `Android/…`. Los display usan Fraunces SemiBold; el resto, la fuente del sistema de cada plataforma.
- **3 estilos de efecto:** `glow-spark/Gris` (sombra negra suave), `glow-spark/Grafito` (halo rosa) y `elev-card/Gris`. En grafito la tarjeta no lleva sombra: la elevación es `surface` → `surface-alt`.

Cada variable trae su descripción (el uso de tokens.json), la sintaxis de código para Web (`var(--bg)`) e iOS (`Palette.bg`, `Space.s4`, `Radius.md`) y un **alcance** que bloquea los usos que prohíbe el sistema:

- `marca/spark` solo aparece para rellenos de forma y efectos. No se ofrece como color de texto ni como relleno de marco: el rosa va apoyado en negro (núcleo, punto del botón, estrella), nunca como texto ni relleno grande sobre gris.
- Los fondos (`bg`, `surface`…) solo como relleno; las tintas (`ink`, `ink-muted`…) como texto, forma y trazo; los bordes como trazo.

## Cómo importarlo

### Opción A, recomendada: el plugin "Lumbre tokens"

No depende de la versión del importador de Figma, crea los estilos y se puede volver a correr cuando cambian los tokens: actualiza lo que existe por nombre y no duplica.

1. Abrí el archivo de diseño de Lumbre en la app de escritorio de Figma.
2. Menú **Plugins → Development → Import plugin from manifest…** y elegí `design/figma/plugin/manifest.json`.
3. Corré **Plugins → Development → Lumbre tokens**. Al terminar avisa cuántas variables creó o actualizó, y si faltó alguna fuente.
4. Fuentes: Fraunces y Roboto Flex están en Google Fonts dentro de Figma. SF Pro Text tiene que estar instalada en la Mac (developer.apple.com/fonts); si no está, el plugin prueba con SF Pro y, si tampoco, usa Inter y lo avisa. Instalala y volvé a correr el plugin para corregir los estilos.
5. Fraunces: el plugin no puede fijar los ejes variables. En los estilos display, poné a mano **SOFT 100** (y **WONK 1** solo en `spark-hero` y el wordmark) desde el panel de tipografía → Variable font axes.

### Opción B: importación nativa de variables (JSON)

Los archivos de `variables/` siguen el formato de Design Tokens (DTCG) con las extensiones de Figma (`com.figma.scopes`, `com.figma.codeSyntax`). Un archivo por colección y modo:

| Archivo | Colección | Modo |
|---|---|---|
| `Color.Gris.tokens.json` | Color | Gris (importalo primero: es el default) |
| `Color.Grafito.tokens.json` | Color | Grafito |
| `Espaciado.Valor.tokens.json` | Espaciado | Valor |
| `Tipografia.iOS.tokens.json` | Tipografía | iOS |
| `Tipografia.Android.tokens.json` | Tipografía | Android |

1. Panel **Local variables** (sin nada seleccionado, en el panel derecho) → menú de colecciones → **Import variables** y elegí `Color.Gris.tokens.json`. Renombrá la colección a "Color" y el modo a "Gris" si Figma les puso otro nombre.
2. En la colección Color, **Import mode** (o importá el segundo archivo sobre la misma colección) con `Color.Grafito.tokens.json`, y llamá al modo "Grafito".
3. Repetí con Espaciado y con Tipografía (iOS primero).
4. Este camino no crea estilos de texto ni de efecto: para eso corré igual el plugin (opción A), que respeta las variables que ya existan con el mismo nombre.

La importación nativa de Figma es reciente y su formato puede variar entre versiones. Si algún archivo no entra, usá el plugin.

## Cómo usarlo en el archivo

- Poné el modo en el frame de cada pantalla: **Color → Gris** (default) o **Grafito**; **Tipografía → iOS** o **Android**. Así una misma pantalla se ve en los dos temas cambiando un solo control.
- Para los colores, usá siempre las variables semánticas (`superficie/bg`, `texto/ink`, `accion/accent`…). Las de `marca/` son para el ícono, la tarjeta para compartir (que siempre va en gris) y las ilustraciones.
- Las ilustraciones de la identidad (`design/system/identidad/*.svg`) pintan cada parte por rol: dormida `superficie/surface-alt`, conexión `borde/border`, encendida `texto/ink`, impulso `texto/info-text`, sinapsis `marca/spark`. Al pegarlas en Figma, ataná cada capa a esa variable para que sigan el tema.
