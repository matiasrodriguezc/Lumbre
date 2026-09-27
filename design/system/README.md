Lumbre es una app de creatividad por recombinación: absorbés ideas, la IA las destila en conceptos atómicos y todos los días hace chocar dos de ellos para que salte una chispa. La app se llama Lumbre; lo que genera cada día es una chispa. El sistema existe para que ese choque sea lo único que brilla. Todo lo demás es noche tranquila.

## Principios

- **Una sola chispa por pantalla.** `spark` (#FF3EA5) aparece en un único elemento protagonista: la chispa del día, el CTA principal o el contador. Si hay dos cosas magenta, una sobra.
- **Noche primero.** El tema `dark` es el default y el de marca. El tema `light` es la misma interfaz a la luz del día, no otra marca.
- **Nativo antes que idéntico.** iOS y Android comparten tokens, copy, ilustraciones y la tarjeta de la chispa. La navegación, los controles del sistema, la tipografía de texto, los gestos y los sheets son los de cada plataforma.
- **El concepto es el átomo.** La unidad visual es la tarjeta de concepto (título, tesis, dominio, fuente). Todo lo que el usuario guarda se muestra así, nunca como texto crudo.

## Voz y contenido

- Rioplatense neutro con voseo: "Elegí tu perfil", "Guardá esta idea", "Te queda 1 chispa hoy". En otros idiomas, tono equivalente: directo y cálido.
- Sentence case siempre. Nada de MAYÚSCULAS en labels ni botones.
- Los botones dicen exactamente qué pasa y mantienen el nombre en todo el flujo: "Guardar concepto" → toast "Concepto guardado".
- La chispa se escribe como un choque: "Podcast × ruinas", "Ciclones × aspiradoras". Usá el signo × entre los dos conceptos, con espacios.
- Vacíos y errores dan dirección, no disculpas: "Todavía no hay conceptos. Guardá una frase, un link o una nota de voz para tener material que combinar."
- Sin emoji decorativos en UI. Los perfiles se identifican con íconos del sistema (SF Symbols / Material Symbols), no con emoji.
- La palabra "IA" se usa poco: el usuario "destila" un concepto y "enciende" una chispa.

## Color

- Fondo: `bg`. Tarjetas y barras: `surface`. Inputs y elementos anidados: `surface-alt`.
- Texto: `ink` para todo lo principal, `ink-muted` para metadatos. Ambos pasan 6:1 o más en los dos temas.
- Acción principal: relleno `accent` con texto `on-accent` (azul noche sobre magenta, 5.52:1). Nunca texto blanco sobre magenta.
- Magenta como texto o ícono chico: `accent-text` (más claro en oscuro, más profundo en claro).
- Selección: `accent-soft` de fondo + `accent-text` o `ink` encima.
- Pro: `pro` (violeta) con `on-pro`. El violeta significa "esto es Pro" y nada más.
- `signal-blue` e `info-text` para información neutra y links que no son la acción principal.
- Estados `success`, `warning`, `danger`: siempre con ícono y palabra; no se distinguen solo por color.
- Bordes: `border` es decorativo; `border-strong` para cualquier control (≥3:1).
- Foco: anillo de 2px en `focus-ring`, separado 2px del control.

## Tipografía

- Dos familias con roles fijos. `display` = Fraunces (serif variable, OFL, se empaqueta en ambas apps) para la marca: el wordmark, `spark-hero`, `counter`, `title-1`, `title-2`. `text` = la fuente del sistema (SF Pro en iOS, Roboto Flex/Roboto en Android) para todo lo demás: `headline`, `body`, `callout`, `caption`.
- El contraste es intencional: una serif cálida de fuego de hogar y una sans nativa y precisa conviven y dan algo nuevo, igual que los dos conceptos que chocan.
- Fraunces solo a 20pt o más. Nunca en botones, chips, listas, tabs, campos ni texto corrido.
- Usá el archivo variable con `opsz` automático, peso 600 y el eje `SOFT` en 100 (curvas blandas). El eje `WONK` en 1 queda reservado al wordmark y al título de la chispa.
- Números en Fraunces siempre con `lining-nums tabular-nums`.
- La fuente del sistema garantiza Dynamic Type y la escala de fuente de Android sin trabajo extra. Los estilos display también escalan: en iOS con `relativeTo:` y en Android en `sp`.
- Máximo un `spark-hero` por pantalla.

## Espaciado, forma y elevación

- Grilla de 4pt: `space-1` a `space-10`. Margen lateral de pantalla `space-4` (iOS usa los márgenes de layout del sistema cuando existen).
- Radios con jerarquía: `radius-sm` inputs, `radius-md` tarjetas y botones, `radius-lg` la chispa del día y sheets, `radius-full` pills. La chispa del día es lo más redondo de la pantalla.
- En oscuro la elevación se da con superficies más claras (`surface` → `surface-alt`), no con sombras. En claro, `elev-card` suave.
- `glow-spark` es exclusivo del momento chispa y del CTA principal. Nunca en tarjetas comunes.

## Movimiento y háptica

- Un solo momento coreografiado: el reveal de la chispa. Las dos tarjetas de concepto se acercan, chocan, aparece la estrella con `glow-spark` y un háptico `.success` (iOS) / `CONFIRM` (Android). Unos 900ms en total.
- Resto de transiciones: las del sistema (push, sheet, predictive back). No inventes transiciones propias para navegación.
- Con Reducir movimiento activado, el reveal es un fundido de 200ms sin escala ni rebote.

## Iconografía

- iOS: SF Symbols. Android: Material Symbols Rounded (peso 400, relleno 0; relleno 1 en el tab activo).
- Equivalencias base: Hoy `sparkles` / `auto_awesome`; Bóveda `square.stack.3d.up` / `stacks`; Capturar `plus` / `add`; Proyectos `square.grid.2x2` / `dashboard`; Perfil `person.crop.circle` / `account_circle`.
- La estrella de cuatro puntas representa la chispa del día y solo se usa para eso. El símbolo de las dos llamas es de marca y no aparece como ícono de interfaz.

## Logo

- El símbolo es un filamento de foco simplificado: una varilla vertical `signal-blue` y una espiral de tres vueltas que la envuelve. Los tramos de la espiral que pasan por detrás son `nebula-violet` y los de adelante, `spark`. Dos conceptos que se entrelazan; donde se tocan, se enciende la idea.
- La profundidad sale solo del cambio de color entre tramos de atrás y de adelante: sin degradés, brillos ni sombras.
- Ícono de app: el símbolo al 66% de alto sobre `night`, en cuadrado a sangre (cada sistema aplica su máscara).
- Wordmark: "Lumbre" en Fraunces 600 con SOFT 100, en `ink`, seguido de un punto `spark`. El punto es parte de la marca.
- El símbolo de marca va en ícono, splash y wordmark. Dentro de la app, la chispa (feature) se representa con la estrella de cuatro puntas.
- Cuidado con la lectura suelta: una forma que envuelve una vara puede recordar al símbolo de medicina o a un "$". Validar el ícono solo, sin wordmark, con personas sin contexto.

## Plataformas

- Navegación: barra flotante con los cuatro destinos y, separado a su derecha, un botón + flotante para Capturar. Ver el componente NavBar.
- iOS (SwiftUI): `TabView` flotante con Liquid Glass y botón + de vidrio tintado en `accent`, `NavigationStack` con large titles, sheets con detents, `.buttonStyle(.borderedProminent)` tintado con `accent`, materiales y controles del sistema (incluido el material de iOS 26). Tokens como Color Assets con variantes Any/Dark.
- Android (Jetpack Compose, Material 3): barra de navegación flotante tipo floating toolbar de M3 Expressive, `FloatingActionButton` separado para Capturar, `TopAppBar`, `ModalBottomSheet`, predictive back. `ColorScheme` propio generado desde estos tokens; dynamic color apagado por defecto (la marca es la noche), opcional en ajustes.
- Los tokens se exportan a Swift y Kotlin desde `tokens.json` (Style Dictionary u otro script) para que ninguna app tenga valores escritos a mano.
