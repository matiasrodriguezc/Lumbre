Lumbre es una app de creatividad por recombinación: absorbés ideas, la IA las destila en neuronas (ideas atómicas) y todos los días conecta dos de ellas para que salte una chispa. La app se llama Lumbre; lo que genera cada día es una chispa. El sistema existe para que ese choque sea lo único que brilla. Todo lo demás es noche tranquila.

## Principios

- **Una sola chispa por pantalla.** `spark` (#FF3EA5) es el único color de la marca y aparece apoyado en negro: el núcleo de la neurona, el punto del botón que enciende, la chispa en la sinapsis. Si el rosa compite consigo mismo, algo sobra.
- **Gris primero.** El tema gris (`light`) es el default y el de marca. El grafito (`dark`) es la misma interfaz invertida: neurona hueso sobre fondo grafito.
- **Nativo antes que idéntico.** iOS y Android comparten tokens, copy, ilustraciones y la tarjeta de la chispa. La navegación, los controles del sistema, la tipografía de texto, los gestos y los sheets son los de cada plataforma.
- **La neurona es el átomo.** La unidad visual es la tarjeta de neurona (componente ConceptCard: título, tesis, dominio, fuente). Todo lo que el usuario guarda se muestra así, nunca como texto crudo.

## Voz y contenido

- Rioplatense neutro con voseo: "Elegí tu perfil", "Guardá esta idea", "Te queda 1 chispa hoy". En otros idiomas, tono equivalente: directo y cálido.
- Sentence case siempre. Nada de MAYÚSCULAS en labels ni botones.
- Los botones dicen exactamente qué pasa y mantienen el nombre en todo el flujo: "Guardar neurona" → toast "Neurona guardada".
- La chispa se escribe como un choque: "Podcast × ruinas", "Ciclones × aspiradoras". Usá el signo × entre las dos neuronas, con espacios.
- Vacíos y errores dan dirección, no disculpas: "Todavía no hay neuronas. Guardá una frase, un link o una nota de voz para tener material que conectar."
- Sin emoji decorativos en UI. Los perfiles se identifican con íconos del sistema (SF Symbols / Material Symbols), no con emoji.
- La palabra "IA" se usa poco: el usuario "destila" una neurona y "enciende" una chispa.
- Vocabulario neuronal: **neurona** (la idea guardada, femenino: "la neurona", "Neurona guardada"), **Red** (todas sus neuronas; antes Bóveda), **Circuitos** (antes Proyectos), **chispa** (la sinapsis que se enciende). Dos neuronas "se conectan"; no se usan "axón", "dendrita" ni vocabulario médico en la interfaz.

## Color

Paleta "Gris neurona": casi monocroma, con un solo color. Sale del logo: una neurona negra sobre gris con un punto rosa encima.

- **Marca:** `gray` #E3E3DF (fondo), `neuron` #0E0E10 (la neurona y la tinta), `spark` #FF3EA5 (el único color). Para el modo oscuro, `graphite` #2A2A2C de fondo y `bone` #EDEDE8 de tinta.
- **El rosa va siempre apoyado en negro** (o en la neurona): el núcleo, el punto del botón principal, la chispa de la sinapsis. Sobre gris solo llega a 2,5:1 y se pierde; sobre negro, 6:1. La única excepción es el punto del wordmark.
- Fondo: `bg`. Superficies apenas elevadas (sheets, barras): `surface`. Inputs, búsqueda y neuronas dormidas: `surface-alt`.
- Texto: `ink` para todo lo principal, `ink-muted` para metadatos (≥4.4:1 en todas las superficies).
- Acción principal: relleno `accent` (negro en gris, hueso en grafito) con `on-accent`, y un punto `spark` adentro cuando la acción enciende algo ("Encender la chispa"). Una por pantalla.
- Secundaria: contorno `border-strong`. Terciaria (`ghost`): `ink-muted` subrayado. Nada de texto rosa sobre gris; `accent-text` queda solo para casos puntuales.
- Selección: el elegido va en `accent` (negro) con `on-accent`; `accent-soft` es un gris para fondos de selección suaves.
- Pro: `pro` es negro con la palabra Pro. Información: `info-text` (gris oscuro) y links subrayados. Ya no hay violeta ni azul.
- Estados `success`, `warning`, `danger`: siempre con ícono y palabra; no se distinguen solo por color.
- Bordes: `border` es decorativo (separadores, el eje de las listas, la red de fondo); `border-strong` para cualquier control (≥3:1).
- Foco: anillo de 2px en `focus-ring` (negro / hueso), separado 2px del control.

## Tipografía

- Dos familias con roles fijos. `display` = Fraunces (serif variable, OFL, se empaqueta en ambas apps) para la marca: el wordmark, `spark-hero`, `counter`, `title-1`, `title-2`. `text` = la fuente del sistema (SF Pro en iOS, Roboto Flex/Roboto en Android) para todo lo demás: `headline`, `body`, `callout`, `caption`.
- El contraste es intencional: una serif cálida de fuego de hogar y una sans nativa y precisa conviven y dan algo nuevo, igual que las dos neuronas que se conectan.
- Fraunces solo a 20pt o más. Nunca en botones, chips, listas, tabs, campos ni texto corrido.
- Usá el archivo variable con `opsz` automático, peso 600 y el eje `SOFT` en 100 (curvas blandas). El eje `WONK` en 1 queda reservado al wordmark y al título de la chispa.
- Números en Fraunces siempre con `lining-nums tabular-nums`.
- La fuente del sistema garantiza Dynamic Type y la escala de fuente de Android sin trabajo extra. Los estilos display también escalan: en iOS con `relativeTo:` y en Android en `sp`.
- Máximo un `spark-hero` por pantalla.

## Espaciado, forma y elevación

- Grilla de 4pt: `space-1` a `space-10`. Margen lateral de pantalla `space-4` (iOS usa los márgenes de layout del sistema cuando existen).
- Radios con jerarquía: `radius-sm` inputs, `radius-md` tarjetas y botones, `radius-lg` sheets, `radius-full` pills y el botón principal.
- **Menos tarjetas.** Lo neuronal se dibuja directo sobre el fondo: la chispa del día no va en una tarjeta, el contador es una línea y las listas de neuronas y chispas cuelgan de un axón (una línea `border` con un nodo por fila).
- En grafito la elevación se da con superficies más claras (`surface` → `surface-alt`), no con sombras. En gris, `elev-card` suave.
- `glow-spark` es exclusivo del momento chispa y del CTA principal. Nunca en tarjetas comunes.

## Movimiento y háptica

- Un solo momento coreografiado: el reveal de la chispa, contado como una sinapsis. Las dos neuronas entran desde los costados (0–250ms), cada uno estira su terminal hacia el centro (150–550ms), un impulso `info-text` cruza cada terminal (450–650ms) y a los 650ms se enciende la estrella con `glow-spark` y un háptico `.success` (iOS) / `CONFIRM` (Android). El título sube hasta los 900ms.
- El pulso: indicador de carga propio solo para destilar y encender. Un impulso recorre un axón en 1,2s. Para cualquier otra carga, el spinner del sistema.
- Resto de transiciones: las del sistema (push, sheet, predictive back). No inventes transiciones propias para navegación. La red de fondo nunca se anima.
- Con Reducir movimiento activado, el reveal es un fundido de 200ms sin escala ni rebote, y el pulso queda quieto.

## Iconografía

- iOS: SF Symbols. Android: Material Symbols Rounded (peso 400, relleno 0; relleno 1 en el tab activo).
- Pestañas con íconos propios en el facetado de la marca (generados en `identidad/generar.py`, imagesets de plantilla en la app): Hoy `tab-hoy` (una neurona), Red `tab-red` (neuronas conectadas), Circuitos `tab-circuitos` (un circuito cerrado). Perfil `brain.head.profile` / `psychology`; Capturar `plus` / `add`. En Android, los tres primeros como vector drawables desde los mismos SVG.
- La estrella de cuatro puntas representa la chispa del día y solo se usa para eso. La neurona es de marca y no aparece como ícono de interfaz.

## Logo

- El símbolo es una neurona plana: soma, cinco dendritas y un axón largo que termina en tres botones. Cada idea guardada es una neurona; la chispa es lo que pasa cuando dos se conectan.
- Dos versiones. **Largo** (`lumbre-mark.svg`): horizontal, con el axón hacia el wordmark; para wordmark, splash y web; mínimo 64px de ancho. **Compacto** (`lumbre-mark-compacto.svg`): el axón se curva hacia abajo para llenar un cuadrado; para ícono, avatares, favicon y notificaciones; mínimo 24px.
- Ícono de app: el compacto en `neuron` (negro) sobre `gray`, en cuadrado a sangre (cada sistema aplica su máscara), con el núcleo en `spark`. `lumbre-app-icon-mono.svg` es la base para tinted (iOS) y monochrome (Android).
- Wordmark: "Lumbre" en Fraunces 600 con SOFT 100, en `ink`, seguido de un punto `spark`. El punto es parte de la marca. La neurona va en `ink`, sin núcleo rosa, para que el punto sea el único.
- El símbolo de marca va en ícono, splash y wordmark. Dentro de la app, la chispa (feature) se representa con la estrella de cuatro puntas y, en el momento chispa, con la sinapsis.
- Validar el ícono solo, sin wordmark, con personas sin contexto: que se lea como neurona (y no como estrella de mar o insecto) a 29px.

## Mundo neuronal

La identidad sale de una sola metáfora: idea guardada = neurona, Red = todas tus neuronas, chispa = sinapsis que se enciende, destilar = un impulso que recorre un axón, Circuito = proyecto. La guía visual completa, con ejemplos en los dos temas, está en `identidad.html`.

- **La metáfora se ve y se dice.** Neurona, Red y Circuitos son los nombres de la interfaz (ver Voz y contenido). "Chispa" se mantiene; "sinapsis", "axón" y "dendrita" quedan para el sistema gráfico, no para el copy.
- **Facetado orgánico.** Todo lo gráfico se dibuja como el símbolo: ramas que nacen gruesas y se afinan o terminan en un botón redondo, uniones blandas y un contorno hecho de tramos rectos cortos. Solo rellenos planos: sin degradés, brillos ni contornos.
- **Color por rol, sin colores nuevos.** Neurona dormida `surface-alt`; conexión `border`; neurona encendida `ink`; impulso `info-text`; sinapsis encendida `spark` (una por pantalla). Así la ilustración funciona igual en los dos temas.
- **La sinapsis** (`identidad/sinapsis.svg`): dos terminales enfrentadas con la estrella en el hueco. Es la ilustración del momento chispa: va entre las dos neuronas de la SparkCard (56–64pt de ancho), en el reveal y en la tarjeta para compartir. Sin estrella, es el estado de espera hasta la próxima chispa.
- **La red** (`identidad/red-*.svg`): neuronas dormidas unidas a sus vecinas. Es el fondo de todas las pantallas: una franja arriba, detrás del título grande, que se desvanece hacia el contenido (iOS: `.neuralBackground()` en lugar de `.background(Palette.bg)`). A pantalla completa solo en el splash y la tarjeta para compartir. Nunca animada, nunca a pleno detrás de listas o texto corrido, y con un solo par encendido por pantalla como máximo.
- **Estados vacíos** (`identidad/estado-*.svg`): red vacía (una neurona sola), antes de la chispa (dos que se buscan), sin circuitos (una conexión abierta) y sin conexión (un axón cortado).
- Todo se genera con `identidad/generar.py` (requiere shapely). Para cambiar una forma, editá el script y regenerá; no edites los SVG a mano.
- Los SVG de `identidad/` no tienen fondo y pintan cada parte por su clase de rol (`n-dormant`, `n-link`, `n-active`, `n-impulse`, `n-spark`), que toma los tokens del tema. Sueltos usan los valores del tema oscuro, así que sobre blanco la neurona crema casi no se ve.

## Plataformas

- Navegación: barra flotante con los cuatro destinos y, separado a su derecha, un botón + flotante para Capturar. Ver el componente NavBar.
- iOS (SwiftUI): `TabView` flotante con Liquid Glass y botón + de vidrio tintado en `accent`, `NavigationStack` con large titles, sheets con detents, `.buttonStyle(.borderedProminent)` tintado con `accent`, materiales y controles del sistema (incluido el material de iOS 26). Tokens como Color Assets con variantes Any/Dark.
- Android (Jetpack Compose, Material 3): barra de navegación flotante tipo floating toolbar de M3 Expressive, `FloatingActionButton` separado para Capturar, `TopAppBar`, `ModalBottomSheet`, predictive back. `ColorScheme` propio generado desde estos tokens; dynamic color apagado por defecto (la marca es la noche), opcional en ajustes.
- Los tokens se exportan a Swift y Kotlin desde `tokens.json` (Style Dictionary u otro script) para que ninguna app tenga valores escritos a mano.
