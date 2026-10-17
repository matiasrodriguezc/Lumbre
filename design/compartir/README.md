# Tarjeta para compartir y widget

Paso 13 de `plan-ejecucion.md` · MAT-228 (tarjeta) y MAT-229 (widget). Especificación para quien implemente en SwiftUI/WidgetKit y Compose/Glance.

- `index.html`: todos los mockups a tamaño real (tarjeta, widgets de iOS, accesorios, StandBy, modos de render, Glance), con selector de tema, idioma (es/en), iPhone (393 / 430 pt) y zonas táctiles.
- `tarjeta.html`: la tarjeta sola a 1080 × 1920 px, para revisar al 100% o sacar el PNG.
- Para verlos con el arte: `python3 -m http.server 8765 --bind 127.0.0.1 --directory design` y abrir `http://127.0.0.1:8765/compartir/`.

Lo marcado **Propuesta** cambia algo que ya existe. Lo marcado **Provisorio** es una decisión que no está en `plan.md`: se tomó la opción más conservadora y hay que confirmarla.

---

## 1. Tarjeta para compartir

Plan §4: "imagen vertical con la chispa y la marca, para historias. Es el loop de crecimiento". Implementada en `ios/Lumbre/Features/Spark/ShareCard.swift`; esto la documenta tal cual y propone mejoras.

### Parámetros de `tarjeta.html`

| Parámetro | Valores |
|---|---|
| `v` | `corto` (Podcast × ruinas), `largo` (título que prueba las 4 líneas), `cuerpo` (prueba las 7 líneas), `nombres` (neuronas largas), `en` |
| `guias` | `medidas`, `ig`, `tiktok`, `wa`, `todas` |
| `formato` | `feed` (1080 × 1350, propuesta) |
| `propuesta` | `1` aplica las mejoras de la sección "Propuestas" |
| `titulo`, `cuerpo`, `a`, `ca`, `b`, `cb`, `lang` | Chispa propia (texto libre; `lang` = `es` o `en`) |
| `limpio` | `1` oculta el panel |
| `zoom` | Achica para revisar (por ejemplo `0.4`); el ajuste se mide siempre a tamaño real |

PNG: abrir sin `zoom`, y en las DevTools del navegador, sobre `#card`, "Capture node screenshot". Sale a 1080 × 1920 si la escala del dispositivo es 1 (en Retina sale a 2×: bajar con la emulación de dispositivo a DPR 1).

### Anatomía (px, escala 1)

| Pieza | Medida |
|---|---|
| Lienzo | 1080 × 1920, fondo `gray` (#E3E3DF), tema gris fijo (`.environment(\.colorScheme, .light)`) |
| Márgenes | 96 a los costados, 250 arriba, 200 abajo. Ancho útil 888 |
| Red de fondo | `NeuralNetworkBackground(.tall)` de 1000 de alto, recortada al centro (`.fill`); máscara opaca hasta 500 y transparente en 1000 |
| Centrado | `Spacer(minLength: 0)` arriba y `Spacer(minLength: 96)` antes de la firma: el bloque de la chispa queda centrado entre el margen de arriba y la firma |
| Neuronas | `HStack` con 48 de separación, dos columnas de 420. Categoría 34 medium, `neuron` al 65%. 12 abajo. Título 48 semibold, `neuron`, hasta 3 líneas. La B alineada a la derecha. 40 abajo |
| Sinapsis | `Synapse(.lit, full: true)`, 880 de ancho (≈ 293 de alto: el lienzo es 240 × 80), centrada. 96 abajo. La estrella `spark` es el único rosa de la chispa |
| Título | Fraunces 104, `spark-hero` (SOFT 100, WONK 1), `neuron`, `lineSpacing(6)`, hasta 4 líneas, `minimumScaleFactor(0.6)` (no baja de 62,4). 48 abajo |
| Cuerpo | Sistema 46 regular, `neuron` al 85%, `lineSpacing(12)`, hasta 7 líneas, `minimumScaleFactor(0.7)` (no baja de 32,2) |
| Firma | `LumbreMark(.long)` de 150 de ancho · 24 · "Lumbre" Fraunces 72 (`title-1`) + punto `spark` de 18 (6 de separación, alineado a la línea de base) · `Spacer` · frase "Donde se encienden las ideas" 32 medium, `neuron` al 65%, alineada a la derecha |
| Accesibilidad | La vista previa en la hoja lleva `accessibilityLabel(spark.accessibilitySummary)`. El PNG no tiene texto alternativo |
| Analytics | `share_card_created` (`mode`) al renderizar; `spark_shared` (`activity_type`) cuando el destino pide la imagen |

Rosa en la tarjeta: la estrella de la sinapsis y el punto del wordmark. El punto es la excepción que permite `design/system/README.md` ("La única excepción es el punto del wordmark"), así que se mantiene.

### Variantes medidas en `tarjeta.html`

| Variante | Resultado |
|---|---|
| Título corto ("Podcast × ruinas") | Título a 104 en 1 línea, cuerpo a 46 en 3 líneas |
| Título largo (83 caracteres) | Título baja a ≈ 98 para entrar en 4 líneas. Como el bloque no entra en el alto, el cuerpo baja a ≈ 33 (×0,72) |
| Cuerpo largo (≈ 420 caracteres) | Cuerpo baja a ≈ 34 (×0,74) para entrar en 7 líneas |
| Neuronas largas | Los títulos de neurona se cortan en 3 líneas con "…"; las categorías largas ("Arquitectura y urbanismo") ocupan una línea entera |
| Inglés | Igual que el corto; frase "Where ideas catch fire" (provisoria) |

En SwiftUI qué texto achica primero cuando el bloque no entra depende de la prioridad de layout. El mockup achica primero el cuerpo y después el título. **Propuesta:** dejarlo explícito con `.layoutPriority(1)` en el título.

### Zonas seguras

Ninguna de las tres apps publica una medida oficial para contenido orgánico. Son referencias de la comunidad: validarlas con capturas reales antes de cerrar.

| App | Arriba | Abajo | Costados | Qué tapa |
|---|---|---|---|---|
| Instagram Historias | 250 | 250 (340 para ir a lo seguro) | — | Nombre, progreso, cerrar / responder, enviar |
| TikTok | 160 | 480 | 120 a la derecha | Pestañas / texto, sonido, barra / botones |
| WhatsApp Estados | ≈ 200 | ≈ 200 | — | Progreso y contacto / responder (estimado) |

Con la tarjeta actual, el título y el cuerpo quedan dentro de todas. La firma (y = 1639 a 1720) cae dentro de la franja de responder de Instagram y de la de abajo de TikTok. Con un cuerpo de 7 líneas, la última línea puede entrar en los 480 de abajo de TikTok, y el final de cada renglón roza la columna de botones de la derecha (24 px).

### Propuestas

1. **Margen de abajo de 340 en vez de 200**, para que la firma quede fuera de la barra de responder de Instagram. El bloque de la chispa se recentra solo. Se ve en `tarjeta.html?propuesta=1&guias=ig`.
2. **Categoría en una línea** (`.lineLimit(1)`): con categorías largas el título de la neurona baja y desalinea las dos columnas.
3. **Frase de la marca en dos líneas parejas** (`.frame(maxWidth: 300)`): hoy queda "Donde se encienden las / ideas", con una palabra sola abajo.
4. **`layoutPriority(1)` en el título** (ver arriba).
5. **Formato feed 1080 × 1350** como segunda opción en la hoja de compartir (no por defecto): márgenes 120 arriba, 112 abajo y 96 a los costados; red de 700; sinapsis de 760; título 88 hasta 4 líneas; cuerpo 40 hasta 5 líneas. Sumar `format` (`story`, `feed`) a `share_card_created`.
6. **Texto que acompaña la imagen** (provisorio): en los destinos que aceptan texto (WhatsApp, Mensajes, X, mail) sumar "Mi chispa de hoy en Lumbre: {title}" y un link a la landing con `utm_source=share_card`. Instagram y TikTok lo ignoran. Espera al dominio definitivo (H3); mientras tanto, solo la imagen. Cuando haya dominio, puede ir también en la firma, en 28 medium al 65%.

---

## 2. Widgets: qué hay y qué muestra

Plan §4: "Widget: chispa del día y captura rápida (WidgetKit y Glance)". El contador (`SparkMeter`) también vive en el widget.

| Widget | iOS | Android |
|---|---|---|
| **Chispa de hoy** | `systemSmall`, `systemMedium`, `systemLarge`, `accessoryCircular`, `accessoryRectangular`, `accessoryInline` | Uno redimensionable con 4 layouts (fila, 2×2, 4×2, 4×3) |
| **Capturar** (provisorio) | `systemSmall` y `accessoryCircular` | 2×1 |
| **Control "Capturar idea"** (propuesta) | `ControlWidgetButton` de iOS 18 para el Centro de control, la pantalla bloqueada y el botón de Acción | — |

### Estados

| Estado | Cuándo | Muestra | Toque principal |
|---|---|---|---|
| Por encender | Hay chispa de hoy (o extra) sin revelar | Las dos neuronas (categoría y título), la sinapsis **sin** estrella y "Encender la chispa" con el punto rosa. Nunca el título ni el cuerpo | `lumbre://spark/{id}` → abre Hoy y arranca el reveal |
| Revelada | La chispa de hoy ya se vio (guardada o no) | Sinapsis encendida, título y la primera línea del cuerpo; en el grande, el contador "Chispa de hoy encendida · La próxima, mañana a las 8:00" | `lumbre://spark/{id}` → detalle |
| Sin chispa | Usada, descartada ("No me sirve") o sin buen par | Sinapsis apagada, "Ya usaste la chispa de hoy", cuándo se recarga y cuántas neuronas faltan para la extra | `lumbre://today` |
| Sin material | Pocas neuronas para combinar (`few_concepts`) | Neurona dormida (o `estado-red-vacia`), "Todavía no hay material para combinar" y "Capturar neuronas" | `lumbre://capture` |
| Sin sesión | Antes del onboarding o después de cerrar sesión | Marca y "Abrí Lumbre para empezar" | `lumbre://today` |
| Invitado sin chispa (provisorio) | Sesión anónima sin chispa diaria (plan §6: invitado sin IA, a definir en el paso 14) | "Creá tu cuenta para recibir tu chispa diaria" y Capturar | `lumbre://account` |
| Cargando | Placeholder de la galería y primera carga | Formas `surface-alt` (`.redacted(reason: .placeholder)` en iOS) | `lumbre://today` |
| Sin datos | Pasó la hora de recarga y la app todavía no escribió la chispa nueva | Sinapsis apagada, "Tu chispa nueva te espera · Abrí Lumbre para traerla" | `lumbre://today` |

Según la propuesta del paso 14 (`design/prototipo/invitado.md`, a confirmar), el invitado **sí** recibe la chispa diaria, así que ve los mismos estados que una cuenta. El estado "Invitado sin chispa" queda solo como respaldo si esa propuesta no se confirma.

### Una sola chispa por pieza

- Por encender: el rosa es el punto del botón. La sinapsis va sin estrella y el contador del grande va sin núcleo rosa.
- Revelada: el rosa es la estrella de la sinapsis. No hay botón con punto.
- Sin chispa, sin material, cargando y sin datos: sin rosa.
- Sin sesión (grande): el punto del wordmark.
- Nunca texto rosa ni relleno rosa sobre gris. En grafito, el botón es hueso con el punto rosa, igual que en la app.

---

## 3. iOS (WidgetKit)

### Medidas

Tabla de Apple, en puntos, para los dos iPhone de referencia:

| Pantalla (pt) | Chico | Mediano | Grande | Circular | Rectangular | Inline |
|---|---|---|---|---|---|---|
| 393 × 852 (también 390 × 844) | 158 × 158 | 338 × 158 | 338 × 354 | 72 × 72 | 160 × 72 | 234 × 26 |
| 430 × 932 (también 428 × 926) | 170 × 170 | 364 × 170 | 364 × 382 | 76 × 76 | 172 × 76 | 257 × 26 |

- Margen interno: el `contentMargins` del sistema (16 pt en la pantalla de inicio; más chico en la bloqueada y StandBy). No usar `.contentMarginsDisabled()`.
- Radio: el del contenedor. Para formas internas, `ContainerRelativeShape`. No fijar el radio a mano (en la maqueta: 22 pt el chico y el mediano, 24 pt el grande).
- Fondo: `.containerBackground(for: .widget) { Palette.bg }`. En el grande, por encender y revelada, la red dormida (`NeuralNetworkBackground(.quiet)`) en una franja de 120 arriba, desvanecida, solo en `.fullColor`.
- Letra mínima 11 pt (HIG).

### Tipografía

Fraunces solo en el título de la chispa y solo a 20 pt o más. Lo demás, fuente del sistema con estilos que escalan.

| Pieza | Chico | Mediano | Grande |
|---|---|---|---|
| Categoría de neurona | — | 11 medium, `ink-muted`, 1 línea | 12 medium, `ink-muted`, 1 línea |
| Título de neurona | 14 semibold, 1 línea | 14 semibold, 1 línea | 15 semibold, hasta 2 líneas (14 en revelada) |
| Título de la chispa | Fraunces 20/23, hasta 3 líneas | Fraunces 22/26 (`title-2`), hasta 2 | Fraunces 28/32 (`title-1`), hasta 2 |
| Cuerpo | 12 regular, `ink-muted`, hasta 2 líneas | 13 regular, hasta 2 | 15 regular, hasta 3 |
| Título de estado | 14–15 semibold | 15 semibold | 17 semibold, o Fraunces 22 en "Tu chispa de hoy está lista" e invitado |
| Detalle | 12 regular | 13 regular | 13 regular |
| Contador | — | — | 15 semibold + 12 regular, neurona de 26 |
| Botones | 14 semibold, alto 30 | 15 semibold, alto 36; Capturar circular de 36 | 15 semibold, alto 40; Capturar de 40 |

Si el título de la chispa no entra en Fraunces 20 en el chico (o 22 en el mediano), usar `ViewThatFits` y pasar a la fuente del sistema 17 semibold: nunca achicar Fraunces por debajo de 20. Fraunces vive en `LumbreDesign`: la extensión del widget tiene que registrarla (igual que la app) o el título sale en la fuente de respaldo.

### Anatomía por tamaño

- **Chico**: por encender = neurona A arriba a la izquierda, sinapsis apagada de 110 al centro, neurona B a la derecha, botón "Encender". Revelada = terminales encendidas (52), título, cuerpo. Una sola zona táctil (`widgetURL`): el botón es visual.
- **Mediano**: por encender = par de neuronas arriba, sinapsis apagada de 150, "Encender la chispa" a la izquierda y Capturar (+) a la derecha. Revelada = terminales + "Tu chispa de hoy" + Capturar arriba, título y cuerpo debajo.
- **Grande**: contador arriba (con línea `border` debajo, como en Hoy). Por encender = "Tu chispa de hoy está lista" en Fraunces 22, la frase "Dos neuronas tuyas…", el par, la sinapsis apagada de 190 y la fila de botones. Revelada = par, sinapsis encendida de 160, título, cuerpo y "Capturar una idea" a lo ancho.
- **Capturar (chico)**: círculo `accent` de 44 con +, "Capturar" 17 semibold y "Una frase, un link o una nota de voz" 12. Todo el widget abre Capturar.

### Zonas táctiles

| Tamaño | Zona | Destino |
|---|---|---|
| Chico | Todo (`widgetURL`) | Según el estado (tabla de estados) |
| Mediano y grande | Fondo (`widgetURL`) | Según el estado |
| Mediano y grande | "Encender la chispa" (`Link`) | `lumbre://spark/{id}?entry=widget&size=…` |
| Mediano y grande | Capturar (`Link`) | `lumbre://capture?entry=widget&size=…` |
| Circular | Todo | Chispa: `spark/{id}` o `today`. Capturar: `capture` |
| Rectangular e inline | Todo | Igual que el circular |

Cada `Link` ocupa al menos 44 × 44 pt: si el dibujo es más chico (el + de 36), agrandar el área con `contentShape` y padding.

### Modos de render

| Modo | Dónde | Qué cambia |
|---|---|---|
| `.fullColor` | Pantalla de inicio en claro u oscuro | Tal cual: gris (`light`) o grafito (`dark`), según el sistema. El widget no sigue el ajuste de tema de la app |
| `.accented` | Tintado (iOS 18) y transparente (Liquid Glass, iOS 26) | El sistema saca el fondo y pinta todo de un color. Sin rosa. La estrella y el botón van con `.widgetAccentable()`. El botón relleno pasa a contorno de 1,5 con el símbolo `sparkle` en lugar del punto (un relleno se tiñe y tapa el texto). Sin red de fondo. Las formas de neurona quedan en el grupo primario |
| `.vibrant` | Pantalla bloqueada y StandBy con poca luz | Monocromo. Ver accesorios |
| StandBy | iPhone cargando de costado | El chico aparece agrandado, sin fondo (`showsWidgetContainerBackground == false`), sobre negro. La estrella rosa queda sobre negro: se mantiene. Con poca luz el sistema lo pinta en rojo: no hay que hacer nada |

Leer `@Environment(\.widgetRenderingMode)` y `\.showsWidgetContainerBackground` para decidir el botón y la red.

### Pantalla bloqueada

- Circular: fondo `AccessoryWidgetBackground()`. Por encender = la neurona compacta; revelada = la estrella (`sparkle`); sin chispa = neurona chica + "8:00"; Capturar = "+".
- Rectangular: 15 semibold + 13 regular (hasta 2 líneas). Por encender = "✦ Tu chispa está lista" + "{a} y {b}"; revelada = título + cuerpo; sin chispa = "Próxima chispa" + "Mañana a las 8:00".
- Inline: símbolo + texto, una línea: "Tu chispa está lista", el título, "Próxima chispa: mañana 8:00" o "Capturar una idea".
- Sin Fraunces (todo queda por debajo de 20 pt) y sin rosa.
- Privacidad (provisorio): `.privacySensitive()` en títulos de neurona, título y cuerpo de la chispa, en todos los tamaños. Así el sistema los oculta con el teléfono bloqueado cuando la persona apagó el acceso con bloqueo.
- Always-On: el sistema baja el brillo; con `ink`/`ink-muted` alcanza el contraste.

### Captura rápida y App Intents

- En el widget, `Link(destination: lumbre://capture?entry=widget)` alcanza y funciona desde iOS 17.
- `CaptureIdeaIntent: AppIntent` con `openAppWhenRun = true` (o `supportedModes = .foreground` en iOS 26) para Atajos, Siri, el botón de Acción y el Control de iOS 18. Desde ahí `capture_opened` lleva `entry = app_intent` (ya existe en `docs/analytics.md`).

---

## 4. Android (Jetpack Glance)

### Medidas

Tabla de Android para una grilla típica de 5 × 4 (Pixel 4), en dp, en vertical: ancho 73n − 16, alto 118m − 16.

| Celdas | Tamaño (dp) | Layout |
|---|---|---|
| 2×1 | 130 × 102 | Fila compacta (sin Capturar ni descripción). También el widget Capturar |
| 4×1 | 276 × 102 | Fila |
| 2×2 | 130 × 220 | Chico (una sola acción, como en iOS) |
| 4×2 | 276 × 220 | Mediano (por defecto) |
| 4×3 | 276 × 337 | Grande |

```kotlin
override val sizeMode = SizeMode.Responsive(setOf(
    DpSize(120.dp, 80.dp),   // fila: 2×1, 3×1, 4×1 y apaisado
    DpSize(120.dp, 180.dp),  // chico: 2×2, 3×2, 2×3
    DpSize(250.dp, 180.dp),  // mediano: 4×2
    DpSize(250.dp, 300.dp),  // grande: 4×3 y más
))
```

`appwidget-provider`: `targetCellWidth="4" targetCellHeight="2"`, `minWidth="250dp" minHeight="180dp"`, `minResizeWidth="120dp" minResizeHeight="80dp"`, `maxResizeWidth="530dp" maxResizeHeight="450dp"`, `resizeMode="horizontal|vertical"`, `widgetCategory="home_screen"`, `description="@string/widget_spark_description"`, `previewLayout` y `previewImage`. Capturar: `targetCellWidth="2" targetCellHeight="1"`. Cada launcher tiene su grilla: los layouts se eligen por tamaño, no por cantidad de celdas. En apaisado las alturas bajan (66m − 15) y casi todo cae en la fila.

### Forma, color y letra

- Radio: `android.R.dimen.system_app_widget_background_radius` en Android 12 o más (nunca pasa de 28 dp; en la maqueta, 24), con 16 dp de respaldo. Elementos internos: `system_app_widget_inner_radius`. `GlanceModifier.appWidgetBackground()` no pone el radio solo: hay que ponerlo.
- Margen interno 16 dp (12 en el 2×2).
- Color: `GlanceTheme` con un `ColorProviders` propio generado de los tokens: día = gris, noche = grafito (`ColorProvider(day, night)`). **Dynamic color apagado** (la marca es la noche). Provisorio: aunque la persona prenda el dynamic color en la app, el widget sigue con los colores de la marca en la v1, porque con fondos de color el rosa deja de ir sobre negro.
- Letra (provisorio): Glance solo acepta familias del sistema, así que **no hay Fraunces** en Android: el título de la chispa va en la fuente del sistema 600 (19 sp en el 2×2, 22 en el 4×2, 28 en el 4×3). Renderizarlo como imagen se descartó: no escala con la letra del sistema y pesa. Todo en `sp`.
- Rosa: el punto del botón y la estrella, como drawables vectoriales tintados con `spark`. Mismas reglas que iOS.
- Áreas táctiles de 48 dp como mínimo (botones de 40 con margen).

### Toques

`actionStartActivity(Intent(Intent.ACTION_VIEW, Uri.parse("lumbre://…")))` con el mismo esquema que iOS y un `intent-filter` para `lumbre` en la actividad principal. El 2×2 y las filas tienen una sola acción (todo el widget); el 4×2 y el 4×3 tienen fondo + "Encender la chispa" + Capturar, como el mediano y el grande de iOS.

### Vista previa en el selector

- Android 15 o más: vistas previas generadas (`AppWidgetManager.setWidgetPreview`, limitado a unas dos llamadas por hora; en Glance, `providePreview` + `GlanceAppWidgetManager.setWidgetPreviews` desde Glance 1.2, verificar la versión). Se llama al primer inicio y después de iniciar sesión.
- Android 12 a 14: `previewLayout` con el mismo layout y datos de ejemplo.
- Android 11 o menos y respaldo: `previewImage` (PNG del 4×2 revelado en gris).
- Contenido de la vista previa: siempre la chispa de ejemplo "Podcast × ruinas" revelada, nunca datos de la persona. En iOS lo mismo con `placeholder(in:)` y `getSnapshot` cuando `context.isPreview`.

### Actualización

La app llama a `updateAll()` cuando cambia algo (igual que iOS, ver abajo) y agenda un `OneTimeWorkRequest` para la hora de recarga, que pasa el widget a "Sin datos" hasta que la app traiga la chispa nueva.

---

## 5. Datos, links y analytics

### Lo que el widget necesita (provisorio)

Hoy la app guarda `LumbreShared.TodaySnapshot` (id, título, cuerpo, las dos neuronas, estado y fecha). Le faltan el contador y el estado de la sesión. Propuesta, en el mismo App Group (`today.json` → `widget.json`):

```swift
struct WidgetState: Codable {
    enum Session: String, Codable { case signedOut, guest, account }
    enum Empty: String, Codable { case fewConcepts, noCandidates, usedToday }
    var session: Session
    var today: TodaySnapshot?        // nil si no hay chispa hoy
    var isExtra: Bool                // "Tu chispa extra está lista"
    var available: Int, total: Int   // contador
    var refillsAt: Date              // "Se recarga mañana a las 8:00"
    var conceptsUntilExtra: Int?     // "Guardá 3 neuronas para ganar 1 extra"
    var empty: Empty?
    var updatedAt: Date
}
```

- La app lo escribe al cargar Hoy, después del reveal, al guardar o descartar la chispa, al capturar, al pedir una extra y al iniciar o cerrar sesión, y llama a `WidgetCenter.shared.reloadAllTimelines()`.
- Línea de tiempo: una entrada ahora y otra en `refillsAt`, que pasa a "Sin datos". El widget no llama al backend en la v1 (decisión conservadora: sin red ni sesión en la extensión).
- Archivo con `completeFileProtectionUntilFirstUserAuthentication` (como hoy) para que se lea con el teléfono bloqueado después del primer desbloqueo.
- Logs sin contenido de las notas (ya es así en `LumbreShared`).
- Por encender: el snapshot trae título y cuerpo, pero el widget no los muestra hasta que el estado sea revelada.

### Deep links (provisorio)

El esquema `lumbre://` ya existe (`lumbre://auth-callback`, `Account.swift`) y `AppRoute` ya tiene `.today`, `.spark(id)` y `.capture(entry:)`. Falta el parser de URL.

| Link | Ruta | Efecto |
|---|---|---|
| `lumbre://spark/{sparkID}?entry=widget&size={size}` | `.spark(id)` | Por encender: Hoy y arranca el reveal (`spark_revealed` con `entry = widget`). Revelada: detalle |
| `lumbre://today?entry=widget&size={size}` | `.today` | Hoy |
| `lumbre://capture?entry=widget&size={size}` | `.capture(entry: "widget")` | Sheet de Capturar (`capture_opened` con `entry = widget`) |
| `lumbre://account?entry=widget&size={size}` | nueva | Crear cuenta desde invitado (provisorio, depende del paso 14) |

`size`: `small`, `medium`, `large`, `circular`, `rectangular`, `inline`, `row`, `2x2`, `4x2`, `4x3`, `capture`.

### Analytics

- `widget_tapped` (`action`, `size`) lo manda la app al abrir el link. `action` hoy acepta `open_spark` y `capture`. Provisorio: sumar `open_app` para `today` y `account` (requiere tocar `docs/analytics.md`).
- `spark_revealed` con `entry = widget`, `capture_opened` con `entry = widget`: ya existen.
- `has_widget` (propiedad de persona): `WidgetCenter.getCurrentConfigurations` en iOS y `GlanceAppWidgetManager.getGlanceIds` en Android, al abrir la app.

### Feature flags (provisorio)

- `widget`: la extensión no puede consultar PostHog. La app escribe el valor del flag en el App Group; apagado, el widget muestra "Abrí Lumbre para empezar" sin contenido. El widget existe en el binario igual (no se puede sacar de la galería en caliente).
- `share_card_feed` y `share_card_text`: para el formato feed y el texto que acompaña la imagen.

---

## 6. Accesibilidad

- **VoiceOver / TalkBack:** el área de la chispa es un solo elemento con la etiqueta de `widget.a11y.pending` o `widget.a11y.revealed` (la segunda es la misma que `accessibilitySummary`). Los botones van aparte: "Encender la chispa" y "Capturar una idea". Ilustraciones, sinapsis, red y neuronas chicas: ocultas (`accessibilityHidden` / sin `contentDescription`). En Glance, `GlanceModifier.semantics { contentDescription = … }`.
- **Por encender no adelanta la chispa** tampoco para el lector de pantalla: la etiqueta nombra las neuronas, no el título.
- **Texto grande (iOS: de Large a AX5 en widgets; Android: escala de fuente hasta 200%):**
  - Chico: desde `.accessibility1`, sin sinapsis; por encender queda "Tu chispa está lista" + "Encender"; revelada, solo el título (en la fuente del sistema si Fraunces no entra).
  - Mediano: sin categorías y sin cuerpo; el título hasta 3 líneas.
  - Grande: sin contador y sin par de neuronas.
  - Accesorios: el sistema limita el tamaño; usar `ViewThatFits` en el rectangular.
  - Android: mismas reducciones con `LocalSize` + `fontScale` > 1,3.
- **Contraste:** todo el texto en `ink` o `ink-muted` (≥ 4,4:1 en gris y grafito). En la tarjeta, el 65% de `neuron` sobre `gray` da ≈ 5,5:1.
- **Estados nunca solo por color:** neurona dormida + texto en todos los vacíos.
- **Movimiento:** el widget no anima nada propio; las transiciones de contenido son las del sistema.

---

## 7. Copy es/en

La fuente del copy es `design/copy/copy.json`: los textos nuevos de esta tabla están ahí en la pantalla `widget` (ids `widget.*`, con `%@` en lugar de `{a}`, `{time}`), y los que ya existen se reusan con su clave de siempre. Esta tabla es la referencia de dónde va cada uno.

Los marcados "ya existe" se reusan tal cual del código actual. La hora sale con el formato del sistema (`8:00` / `8:00 AM`).

| Id | es | en | Dónde |
|---|---|---|---|
| `widget.spark.name` | Chispa de hoy | Today's spark | Galería de widgets |
| `widget.spark.description` | Tu chispa del día y un atajo para capturar. | Your daily spark and a shortcut to capture. | Galería de widgets |
| `widget.capture.name` | Capturar | Capture | Galería de widgets · ya existe |
| `widget.capture.description` | Abrí Capturar directo desde la pantalla de inicio. | Open Capture straight from your Home Screen. | Galería de widgets |
| `widget.pending.title` | Tu chispa de hoy está lista | Your spark for today is ready | Por encender (grande, mediano) · ya existe |
| `widget.pending.extra.title` | Tu chispa extra está lista | Your extra spark is ready | Por encender, chispa extra · ya existe |
| `widget.pending.body` | Dos neuronas tuyas de mundos distintos están por conectarse. | Two of your neurons from different worlds are about to connect. | Por encender (grande) · ya existe |
| `widget.pending.cta` | Encender la chispa | Light the spark | Botón principal (mediano, grande) · ya existe |
| `widget.pending.cta.short` | Encender | Light it | Botón del chico y del 2×2 |
| `widget.pending.lock` | Tu chispa está lista | Your spark is ready | Accesorios rectangular e inline |
| `widget.pending.pair` | {a} y {b} | {a} and {b} | Rectangular y fila 4×1 |
| `widget.revealed.label` | Tu chispa de hoy | Today's spark | Revelada (mediano) · ya existe |
| `widget.meter.available` | 1 chispa para encender | 1 spark to light | Contador (grande) · ya existe |
| `widget.meter.lit` | Chispa de hoy encendida | Today's spark is lit | Contador (grande) · ya existe |
| `widget.meter.used` | Usaste las chispas de hoy | You've used today's sparks | Contador (grande) · ya existe |
| `widget.refill.tomorrow` | Se recarga mañana a las {time} | Refills tomorrow at {time} | Contador · ya existe |
| `widget.next.tomorrow` | La próxima, mañana a las {time} | Next one tomorrow at {time} | Revelada y sin chispa · ya existe |
| `widget.next.lock` | Próxima chispa: mañana {time} | Next spark: tomorrow {time} | Inline |
| `widget.next.lock.title` | Próxima chispa | Next spark | Rectangular, sin chispa |
| `widget.next.lock.when` | Mañana a las {time} | Tomorrow at {time} | Rectangular, sin chispa |
| `widget.used.title` | Ya usaste la chispa de hoy | You've used today's spark | Sin chispa · ya existe |
| `widget.used.earn` | Guardá {n} neuronas para ganar 1 extra | Save {n} neurons to earn 1 extra | Sin chispa (grande, mediano) · ya existe |
| `widget.noMaterial.title` | Todavía no hay material para combinar | Nothing to connect yet | Sin material · ya existe |
| `widget.noMaterial.body` | Guardá neuronas de temas distintos. | Save neurons from different topics. | Sin material (mediano) |
| `widget.noMaterial.body.long` | Guardá algunas neuronas de temas distintos: una frase, un link o una nota de voz. Con eso Lumbre enciende tu primera chispa. | Save a few neurons from different topics: a quote, a link or a voice note. That gives Lumbre what it needs to light your first spark. | Sin material (grande) · ya existe |
| `widget.capture.cta` | Capturar | Capture | Botón de captura · ya existe |
| `widget.capture.cta.long` | Capturar una idea | Capture an idea | Botón de captura (grande) · ya existe |
| `widget.capture.cta.neurons` | Capturar neuronas | Capture neurons | Sin material, sin chispa · ya existe |
| `widget.capture.hint` | Una frase, un link o una nota de voz | A quote, a link or a voice note | Widget Capturar |
| `widget.signedOut.title` | Abrí Lumbre para empezar | Open Lumbre to get started | Sin sesión |
| `widget.signedOut.body` | Guardá lo que te inspira. Cada mañana, dos de tus neuronas se conectan y salta una chispa. | Save what inspires you. Every morning, two of your neurons connect and a spark flies. | Sin sesión (mediano, grande) · ya existe |
| `widget.guest.title` | Creá tu cuenta para recibir tu chispa diaria | Create your account to get your daily spark | Invitado sin chispa (provisorio) |
| `widget.guest.body` | Mientras tanto, podés capturar neuronas como invitado. | Meanwhile, you can capture neurons as a guest. | Invitado sin chispa (provisorio) |
| `widget.noData.title` | Tu chispa nueva te espera | Your new spark is waiting | Sin datos (después de la recarga) |
| `widget.noData.body` | Abrí Lumbre para traerla. | Open Lumbre to load it. | Sin datos |
| `widget.open` | Abrir | Open | Sin datos |
| `widget.a11y.pending` | Chispa por encender: {a}, de {catA}, con {b}, de {catB}. Tocá para encenderla. | Spark to light: {a}, from {catA}, with {b}, from {catB}. Tap to light it. | VoiceOver y TalkBack |
| `widget.a11y.revealed` | Chispa: {title}. {body} Combina {a}, de {catA}, con {b}, de {catB}. | Spark: {title}. {body} Combines {a}, from {catA}, with {b}, from {catB}. | VoiceOver y TalkBack · ya existe |
| `widget.a11y.capture` | Capturar una idea | Capture an idea | Botón de captura · ya existe |
| `control.capture.title` | Capturar idea | Capture idea | Control de iOS 18 (propuesta) |
| `share.tagline` | Donde se encienden las ideas | Where ideas catch fire | Firma de la tarjeta · ya existe |
| `share.text` | Mi chispa de hoy en Lumbre: {title} | Today's spark from Lumbre: {title} | Texto que acompaña la imagen (provisorio) |
| `share.button` | Compartir imagen | Share image | Hoja de la tarjeta · ya existe |
| `share.sheet.title` | Tarjeta para compartir | Share card | Hoja de la tarjeta · ya existe |
| `share.format.story` | Para historias | For stories | Selector de formato (propuesta) |
| `share.format.feed` | Para publicaciones | For posts | Selector de formato (propuesta) |

---

## Fuentes

- Apple, Human Interface Guidelines, Widgets: tabla de tamaños por dispositivo, márgenes (16 pt, 11 pt ajustado), letra mínima 11 pt, Dynamic Type de Large a AX5, modos full color / accented / vibrant, StandBy, Always-On y placeholders. <https://developer.apple.com/design/human-interface-guidelines/widgets>
- Android, Provide flexible widget layouts: tabla de tamaños por celdas y fórmula 73n − 16 × 118m − 16. <https://developer.android.com/develop/ui/views/appwidgets/layouts>
- Android, Glance, Build UI: `SizeMode.Responsive`. <https://developer.android.com/develop/ui/compose/glance/build-ui>
- Android, Add previews to your widget picker: `setWidgetPreview` (Android 15), `previewLayout` (12+), `previewImage`. <https://developer.android.com/develop/ui/views/appwidgets/previews>
- Android 12, Widgets: esquinas (`system_app_widget_background_radius`, máximo 28 dp) y dynamic color. <https://developer.android.com/about/versions/12/features/widgets>
- Zonas seguras: no hay medidas oficiales para contenido orgánico. Instagram 250/250 y 340 abajo para ir a lo seguro: <https://www.moonb.io/blog/instagram-story-specs>, <https://argil.ai/blog/instagram-story-dimensions>. TikTok 160/480/120: <https://www.houseofmarketers.com/guide-to-safe-zones-tiktok-facebook-instagram-stories>, <https://blog.adnabu.com/tiktok/tiktok-ad-specs/>. WhatsApp: estimado.
