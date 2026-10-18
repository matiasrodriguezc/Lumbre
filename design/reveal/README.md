# Coreografía del reveal

Paso 12 de `plan-ejecucion.md` · MAT-225. Tiempos, curvas, hápticos y accesibilidad del reveal de la chispa, para quien lo implemente en SwiftUI y en Compose.

- `index.html`: el documento visual con el prototipo animado (Hoy desenfocado + modal, dentro de un teléfono), con el swipe del §12. Tiene velocidad 1× / 0,5× / 0,25×, Reducir movimiento (arranca según `prefers-reduced-motion`), tema gris o grafito, iOS o Android, una línea de tiempo dibujada con cursor, un deslizador para congelar cualquier instante y un registro de eventos (háptico, anuncio, `spark_revealed`). Para verlo: `python3 -m http.server -d design` y abrir `/reveal/`. Un instante se puede enlazar con `?t=650&tema=dark&rm=1&plataforma=android`.
- Este README: la especificación en texto. Manda `design/system/README.md` ("Movimiento y háptica"); lo que acá se agrega y no está ahí va marcado como **provisorio, a confirmar**.

## 1. Idea

El único momento coreografiado de la app, contado como una sinapsis: las dos neuronas entran desde los costados, cada una estira su terminal hacia el centro, un impulso cruza cada terminal y salta la chispa (la estrella), con un háptico. Después sube el título. Todo pasa en un modal a pantalla completa: el resto de la app, barra incluida, queda desenfocado detrás de un velo `neuron` al 22 %, y la chispa está en un panel `surface` con `radius-lg` y `glow-spark`.

## 2. Línea de tiempo recomendada

El reloj arranca con el toque en "Encender la chispa" (t = 0). El modal se funde **en paralelo** con la entrada de las neuronas, no antes: el toque ya es la decisión y cualquier espera previa se siente como carga. A los 200 ms el panel ya es opaco; las neuronas llegan a los 250. Todo termina a los **900 ms** (hoy la app tarda ~1.200).

El panel nace con su **tamaño final**: título, cuerpo y acciones ya ocupan su lugar con opacidad 0 (y ocultos a accesibilidad) hasta su momento. Así nada se reacomoda ni se vuelve a centrar.

| Pista | Inicio (ms) | Dura (ms) | Qué se anima | Curva |
|---|---|---|---|---|
| Velo y desenfoque | 0 | 200 | Opacidad 0→1 del velo `neuron` al 22 % y del material desenfocado, juntos | fundido |
| Panel | 0 | 200 | Opacidad 0→1. Sin escala ni desplazamiento | fundido |
| Etiqueta "Tu chispa de hoy" | 0 | 200 | Va con el panel | fundido |
| Neurona A y su nombre | 0 | 250 | Neurona: x −22 → 0 (unidades del lienzo de 240 × 80) y opacidad 0→1. Nombre: x −16 pt → 0 y opacidad 0→1 | entrada |
| Neurona B y su nombre | 0 | 250 | Igual desde la derecha (+22 u / +16 pt) | entrada |
| Terminales | 150 | 400 | Cada terminal crece desde el soma hacia el centro: máscara del 43 % al 100 % del ancho de su neurona | alcance |
| Impulsos | 450 | 200 | Un punto `info-text` por terminal viaja del soma al hueco (x 46 → 106 en la izquierda, 194 → 134 en la derecha). Aparece en los primeros 40 ms y se apaga en los últimos 40 | impulso |
| Estrella | 650 | 300 | Escala 0,1 → 1 (pasa un 7 % y vuelve); opacidad 0→1 en 70 ms lineal | encendido (resorte) |
| `glow-spark` del panel | 650 | 250 | Opacidad 0→1 de la sombra, en una capa propia detrás del panel | fundido |
| Háptico | 650 | — | `.success` (iOS) / `CONFIRM` (Android), mismo cuadro que la estrella | — |
| Título | 650 | 250 | y +12 pt → 0 y opacidad 0→1 | entrada |
| Cuerpo | 700 | 200 | y +8 pt → 0 y opacidad 0→1 | entrada |
| Acciones | 750 | 150 | Solo opacidad 0→1 | fundido |
| Cruz y tocar afuera | 900 | 100 | La cruz aparece; se habilitan cruz, toque afuera, escape de VoiceOver y back de Android | fundido |
| Anuncio y foco | 900 | — | Anuncio de `spark.accessibilitySummary`, foco al título. `spark_revealed` y `api.revealSpark` | — |

Los desplazamientos son fijos en pt (no dependen del tamaño de letra ni del alto del contenedor). Las unidades "u" son del lienzo de la sinapsis completa (`NeuralArt.synapseFull*`, 240 × 80): la neurona izquierda ocupa x 2–114, la derecha x 126–238, la estrella va centrada en x 120 y el axón corre a y ≈ 37,6.

## 3. Curvas

| Nombre | Uso | CSS | SwiftUI | Compose |
|---|---|---|---|---|
| fundido | velo, panel, glow, acciones, cruz, cierre | `cubic-bezier(0, 0, 0.2, 1)` | `.timingCurve(0, 0, 0.2, 1, duration: d)` | `tween(d, easing = LinearOutSlowInEasing)` |
| entrada | neuronas, nombres, título, cuerpo | `cubic-bezier(0.2, 0.8, 0.2, 1)` | `.timingCurve(0.2, 0.8, 0.2, 1, duration: d)` | `tween(d, easing = CubicBezierEasing(0.2f, 0.8f, 0.2f, 1f))` |
| alcance | terminales | `cubic-bezier(0.3, 0.7, 0.2, 1)` | `.timingCurve(0.3, 0.7, 0.2, 1, duration: 0.4)` | `tween(400, easing = CubicBezierEasing(0.3f, 0.7f, 0.2f, 1f))` |
| impulso | impulsos | `cubic-bezier(0.4, 0, 1, 1)` | `.timingCurve(0.4, 0, 1, 1, duration: 0.2)` | `tween(200, easing = FastOutLinearInEasing)` |
| encendido | estrella | keyframes muestreados del resorte | `.spring(duration: 0.3, bounce: 0.35)` | `spring(dampingRatio = 0.65f, stiffness = 440f)` |
| fundido sereno | Reducir movimiento | `cubic-bezier(0.4, 0, 0.2, 1)` | `.timingCurve(0.4, 0, 0.2, 1, duration: 0.2)` | `tween(200, easing = FastOutSlowInEasing)` |

Equivalencia del resorte: `.spring(duration: d, bounce: b)` de SwiftUI es, con masa 1, rigidez (2π / d)² y amortiguación 1 − b. Con d = 0,3 y b = 0,35: rigidez 439 y amortiguación 0,65. Llega a 1 a los ~210 ms, pasa un 7 % y queda quieto antes de los 950. El código actual usa `bounce: 0.4` (amortiguación 0,6, pasa un 9 %); se baja un poco para que el rebote sea de la estrella sola y no se sienta gelatinoso.

## 4. Háptica

Un solo háptico en todo el reveal, en el cuadro en que se enciende la estrella.

**iOS**
- `.success`. El código ya usa `.sensoryFeedback(.success, trigger: collisions)`: alcanza con que el disparador cambie a los 650 ms, en el mismo cuadro que la estrella.
- Preparar: con `.sensoryFeedback` lo maneja SwiftUI. Si en dispositivo se nota retraso, pasar a `UINotificationFeedbackGenerator`: `prepare()` en el toque (t = 0, 650 ms antes) y `notificationOccurred(.success)` a los 650.
- Hápticos del sistema apagados (Ajustes › Sonidos y hápticos): no vibra y no hay que hacer nada. Nada visual depende del háptico.

**Android**
- API 30 o más: `view.performHapticFeedback(HapticFeedbackConstants.CONFIRM)` con `LocalView.current`.
- API 28–29 (minSdk 28): `HapticFeedbackConstants.VIRTUAL_KEY`, un clic corto. **Provisorio, a confirmar.** Sin `Vibrator` ni permiso `VIBRATE`: `performHapticFeedback` ya respeta el ajuste del sistema.
- "Respuesta táctil" apagada: no vibra. Nunca usar `FLAG_IGNORE_GLOBAL_SETTING`.
- No hace falta preparar. Si se evalúa `HapticFeedbackType.Confirm` de Compose, revisar a qué cae en API 28–29 antes de adoptarlo.

## 5. Reducir movimiento

- iOS: `@Environment(\.accessibilityReduceMotion)`.
- Android: "Quitar animaciones" deja `Settings.Global.ANIMATOR_DURATION_SCALE` en 0. Leerlo con `ValueAnimator.areAnimatorsEnabled()` (devuelve `false` en ese caso).

Qué se ve:
- El modal entero (velo, desenfoque y panel) se funde en 200 ms con el fundido sereno, sin espera previa. Adentro todo está en su estado final: neuronas en su lugar, terminales tocándose, estrella encendida, `glow-spark` puesto, título, cuerpo, acciones y cruz.
- Sin escala, sin rebote, sin desplazamiento y sin impulsos.

Cuándo pasa cada cosa:
- 0 ms: toque, empieza el fundido.
- 200 ms: háptico; cruz, toque afuera, escape y back habilitados; anuncio y foco al título; `spark_revealed` con `reduce_motion = true`. **El háptico al final del fundido es provisorio, a confirmar** (hoy la app lo dispara al principio).
- En Android con escala 0, Compose termina las animaciones al instante (el fundido no se ve, y está bien). Lo importante es saltear los `delay()` de la coreografía para que el háptico y el anuncio no esperen 650 / 900 ms.

## 6. Accesibilidad

- El panel es modal: `.accessibilityAddTraits(.isModal)` en iOS (ya está), `paneTitle` en Compose. Mientras dura la coreografía, lo que todavía no se ve va con `.accessibilityHidden(true)` / `invisibleToUser()`; solo se expone "Tu chispa de hoy".
- A los 900 ms (200 con Reducir movimiento): anuncio de `spark.accessibilitySummary` y foco al título, que es encabezado. En iOS, el anuncio con prioridad alta (`accessibilitySpeechAnnouncementPriority = .high`) para que el cambio de foco no lo corte; en Android, el mismo texto en una región `liveRegion = LiveRegionMode.Polite`.
- La sinapsis es decorativa y está oculta; el par de neuronas se lee como texto.
- Cierre: cruz con área de 44 × 44 pt / 48 × 48 dp (hoy mide 32 × 32), toque afuera, `.accessibilityAction(.escape)` en iOS y back en Android. Todo recién a los 900 ms.
- Nada depende del movimiento ni del háptico: el estado final tiene toda la información (nombres de las dos neuronas, título, cuerpo, acciones).
- Con texto grande el panel scrollea, como hoy.

## 7. Casos

| Caso | Qué pasa |
|---|---|
| Chispa diaria o extra | Misma coreografía. Solo cambia la etiqueta: "Tu chispa de hoy" / "Tu chispa extra" (en Hoy: "Tu chispa de hoy está lista" / "Tu chispa extra está lista"). |
| Entrada desde push o widget | No se reproduce sola. La app abre Hoy con la chispa por encender arriba (`consumeRoute` ya hace eso) y la coreografía arranca con el toque en "Encender la chispa". Si la chispa ya se reveló (por ejemplo, en otro dispositivo), llega revelada, sin animación. `spark_revealed.entry` tiene que ser `push` o `widget` (hoy `TodayView` no lo pasa y siempre manda `app`). |
| Tema gris (default) | La estrella es el único rosa, apoyada entre las dos terminales negras. `glow-spark` es una sombra negra suave (`0 8 24` al 16 %): el panel "se levanta" cuando salta la chispa. |
| Tema grafito | Neuronas hueso. `glow-spark` es un halo rosa de 28 px al 30 % alrededor del panel; es el único momento de la app con ese halo. |
| Toques durante la animación | "Encender la chispa" queda deshabilitado desde el primer toque (el doble toque no relanza; el `guard phase == .idle` ya lo cubre). Hasta los 900 ms se ignoran la cruz, el toque afuera, el escape y el back. No se puede saltear: dura menos de un segundo. Las acciones se pueden tocar desde que son visibles (750 ms). **Back y escape ignorados hasta los 900: provisorio, a confirmar.** |
| La app pasa a segundo plano a mitad | Al volver se muestra el estado final, sin repetir. Si se cerró antes de los 900 ms, `revealSpark` no llegó: la chispa sigue por encender y se puede revelar de nuevo. |
| Android sin desenfoque | `Modifier.blur` y el desenfoque entre ventanas existen desde API 31 (y se apagan con ahorro de batería). Sin desenfoque, el velo pasa a `scrim` (`neuron` al 50 %) para que Hoy no compita con el panel. **Provisorio, a confirmar.** |
| Cierre | Fundido de 200 ms (curva fundido), sin deslizar, igual que la apertura. Al cerrar, la chispa queda en Hoy (SparkCard abierta) y el contador pasa a "Usaste las chispas de hoy" si era la última. **El fundido de cierre es provisorio, a confirmar.** |

## 8. Especificación, código actual y recomendación

Código leído el 2026-10-13: `ios/Lumbre/Features/Today/SparkReveal.swift` (`SparkHero.ignite()`, `SparkRevealModal`), `LumbreDesign/Components/Neural.swift` (`Synapse`), `SparkCard.swift`, `SparkActions.swift`. Tiempos del código contados desde el toque.

| Tema | Especificación | Código actual | Recomendación |
|---|---|---|---|
| Arranque | No dice dónde cae el modal en el tiempo | Presenta el `fullScreenCover` sin animación y espera 300 ms (50 con Reducir movimiento) antes de la primera fase | Sin espera: modal y sinapsis arrancan en t = 0; el fundido del modal corre en paralelo |
| Duración total | 900 ms | ~1.200 ms hasta el anuncio (300 + 340 + 220 + 340) | 900 ms |
| Fundido del modal | Fundido, sin deslizar | Velo y panel con `.opacity` 250 ms `easeOut`. El `.ultraThinMaterial` de `presentationBackground` queda fuera de esa opacidad y aparece de golpe (verificar en dispositivo) | 200 ms, curva fundido, con el material adentro del mismo fundido |
| Entrada de las neuronas | Desde los costados, 0–250 | No entran: el panel aparece con nombres y sinapsis `apart` (neuronas corridas 10 u hacia afuera) ya en su lugar | x ±22 u y opacidad, 0–250, entrada; los nombres las acompañan ±16 pt |
| Terminales | Cada una estira su terminal, 150–550 | `approaching`, 340 ms `easeIn`: las neuronas enteras se corren 10 u hacia el centro; nada se estira | La terminal crece desde el soma (máscara), 150–550, alcance |
| Impulsos | Cruzan cada terminal, 450–650, `info-text` | Aparecen quietos en x = 40 durante `approaching`; en `collided` viajan al centro mientras se apagan con el resorte | Viajan de x 46 a 106 en 450–650, impulso. Con borde `surface` (1,8 u, radio 4 u): `info-text` sobre la terminal `ink` queda por debajo de 2:1 y no se ve. **Provisorio** |
| Estrella | Se enciende a los 650 | ~640 (300 + 340), `spring(duration: 0.3, bounce: 0.4)` de 0,1 a 1 | 650, `.spring(duration: 0.3, bounce: 0.35)` |
| Escala de la sinapsis | No hay | Toda la sinapsis escala a 1,1 en `collided` y vuelve a 1 en `revealed` | Sacarla: el rebote es solo de la estrella |
| `glow-spark` | "Se enciende la estrella con `glow-spark`" | El panel tiene `glow-spark` fijo desde que aparece | El `glow-spark` es del panel y se enciende 650–900; la estrella no lleva sombra (en gris el token es una sombra negra que la ensuciaría). **Provisorio** |
| Háptico | `.success` / `CONFIRM` a los 650 | Al pasar a `collided` (~640). Coincide | Igual, en el mismo cuadro que la estrella |
| Título y cuerpo | El título sube hasta los 900 | Entran juntos en `revealed` (860–1.200) con `.move(edge: .bottom)`: el recorrido depende del alto del contenedor | Título 650–900 desde +12 pt; cuerpo 700–900 desde +8 pt; acciones 750–900 solo opacidad |
| Tamaño del panel | — | Título, cuerpo y acciones se insertan al final: el panel crece de golpe y se vuelve a centrar | Tamaño final desde el principio |
| Cruz | Cierra solo ya revelada | Oculta y deshabilitada hasta `revealed`; mide 32 × 32 pt | Aparece a los 900 en 100 ms; área de 44 × 44 pt |
| Cierre | Solo dice que se abre sin deslizar | `isShowingReveal = false` con la animación por defecto del `fullScreenCover`: desliza hacia abajo | Fundido de 200 ms, sin deslizar. **Provisorio** |
| Reducir movimiento | Fundido de 200 ms sin escala ni rebote | Espera 50 ms, háptico al principio, `revealed` con `easeInOut(0.2)` | Sin espera; fundido sereno; háptico y anuncio a los 200. **Provisorio el momento del háptico** |
| Anuncio | — | Al final (~1.200) con `accessibilitySummary` | A los 900 (200 con Reducir movimiento), con foco al título |
| Origen | `spark_revealed.entry`: `app`, `push`, `widget` | `TodayView` no le pasa `entry` a `SparkHero`: siempre `app` | Pasar el origen de `AppRoute.spark` hasta el reveal |

Nota: la variante sin identidad neuronal (`stage` + `collision`, con las dos tarjetas que chocan) queda como está; esta coreografía es la del modal (`neuralIdentity` encendido).

## 9. Qué cambiar en `SparkReveal.swift`

No se tocó el código en este paso. Para la sesión de implementación:

1. Sacar la espera de 300 ms. El cover se presenta sin animación (como ahora) y la coreografía arranca en el mismo toque; el fundido del modal es una pista más.
2. Reemplazar las tres fases con `Task.sleep` por pistas con su propio retraso. Un solo `Task` queda para lo que no es animación: háptico a los 650; a los 900, habilitar el cierre, anuncio, `spark_revealed` y `revealSpark`.
3. `Synapse` con progreso continuo (entrada, terminal, impulso, estrella) en lugar de `apart / reaching / lit`. Los tres estados quedan como atajos para Hoy y compartir. La terminal se puede enmascarar con un `Rectangle` cuyo ancho anima (`.mask`), o separarse en su propia capa en `identidad/generar.py`. **La técnica es provisoria, a confirmar.**
4. Panel con su tamaño final desde el principio y sin `.scaleEffect(1.1)` en la sinapsis.
5. `glow-spark` en una capa propia detrás del panel, con opacidad animada.
6. `.presentationBackground(.clear)` y dibujar el material y el velo dentro del modal, adentro del mismo fundido.
7. Cierre con fundido propio de 200 ms antes de `isShowingReveal = false` (con `disablesAnimations` también al cerrar). Cruz de 44 × 44. `.accessibilityAction(.escape)` solo revelada. Ocultar a VoiceOver lo que todavía no se ve.
8. Pasar `entry` desde la ruta de push o widget.

Esqueleto en SwiftUI (iOS 17+), un `KeyframeAnimator` para la sinapsis y animaciones con retraso para el texto:

```swift
struct RevealValues {
    var enter = 0.0      // 0 → 1: neuronas y nombres
    var reach = 0.0      // 0 → 1: terminales
    var impulse = 0.0    // 0 → 1: posición del impulso
    var impulseOpacity = 0.0
    var star = 0.1       // escala
    var starOpacity = 0.0
}

KeyframeAnimator(initialValue: RevealValues(), trigger: igniteCount) { v in
    Synapse(progress: v)   // nueva API de LumbreDesign
} keyframes: { _ in
    KeyframeTrack(\.enter) { CubicKeyframe(1, duration: 0.25) }          // aproximar "entrada" o usar .timingCurve en un withAnimation
    KeyframeTrack(\.reach) { LinearKeyframe(0, duration: 0.15); CubicKeyframe(1, duration: 0.4) }
    KeyframeTrack(\.impulse) { LinearKeyframe(0, duration: 0.45); CubicKeyframe(1, duration: 0.2) }
    KeyframeTrack(\.impulseOpacity) {
        LinearKeyframe(0, duration: 0.45); LinearKeyframe(1, duration: 0.04)
        LinearKeyframe(1, duration: 0.12); LinearKeyframe(0, duration: 0.04)
    }
    KeyframeTrack(\.star) { LinearKeyframe(0.1, duration: 0.65); SpringKeyframe(1, duration: 0.3, spring: .init(duration: 0.3, bounce: 0.35)) }
    KeyframeTrack(\.starOpacity) { LinearKeyframe(0, duration: 0.65); LinearKeyframe(1, duration: 0.07) }
}

// Texto y capas del panel, todo disparado en el toque:
withAnimation(.timingCurve(0, 0, 0.2, 1, duration: 0.2)) { modalVisible = true }
withAnimation(.timingCurve(0, 0, 0.2, 1, duration: 0.25).delay(0.65)) { glowVisible = true }
withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.25).delay(0.65)) { titleVisible = true }
withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.2).delay(0.7)) { bodyVisible = true }
withAnimation(.timingCurve(0, 0, 0.2, 1, duration: 0.15).delay(0.75)) { actionsVisible = true }
Task { @MainActor in
    try? await Task.sleep(for: .milliseconds(650)); collisions += 1          // háptico
    try? await Task.sleep(for: .milliseconds(250)); finishReveal()           // cierre, anuncio, analytics, API
}
```

`CubicKeyframe` interpola con Catmull-Rom, no con una bezier: si se quiere la curva exacta, las pistas de entrada y alcance van mejor con `withAnimation(.timingCurve(...).delay(...))` sobre valores sueltos, y el `KeyframeAnimator` queda para el impulso y la estrella.

Esqueleto en Compose:

```kotlin
val Fade = LinearOutSlowInEasing
val Enter = CubicBezierEasing(0.2f, 0.8f, 0.2f, 1f)
val Reach = CubicBezierEasing(0.3f, 0.7f, 0.2f, 1f)
val Impulse = FastOutLinearInEasing

val reduced = !ValueAnimator.areAnimatorsEnabled()
val enter = remember { Animatable(0f) }
val reach = remember { Animatable(0f) }
val impulse = remember { Animatable(0f) }
val star = remember { Animatable(0.1f) }
val view = LocalView.current

LaunchedEffect(igniteCount) {
    if (reduced) {
        /* todo en estado final; fundido de 200 con FastOutSlowInEasing */
        delay(200); haptic(view); finishReveal(); return@LaunchedEffect
    }
    launch { enter.animateTo(1f, tween(250, easing = Enter)) }
    launch { reach.animateTo(1f, tween(400, delayMillis = 150, easing = Reach)) }
    launch { impulse.animateTo(1f, tween(200, delayMillis = 450, easing = Impulse)) }
    launch { delay(650); star.animateTo(1f, spring(dampingRatio = 0.65f, stiffness = 440f)) }
    delay(650); haptic(view)
    delay(250); finishReveal()
}

fun haptic(view: View) {
    view.performHapticFeedback(
        if (Build.VERSION.SDK_INT >= 30) HapticFeedbackConstants.CONFIRM
        else HapticFeedbackConstants.VIRTUAL_KEY   // provisorio
    )
}
```

## 10. Decisiones provisorias (a confirmar)

No están en `plan.md` ni en `design/system/README.md`:

1. `glow-spark` en el panel, no en la estrella, encendido de 650 a 900.
2. Impulso con borde `surface` (1,8 u, radio 4 u) para que se lea sobre la terminal `ink`.
3. Con Reducir movimiento, el háptico al final del fundido (200 ms).
4. Cierre con fundido de 200 ms, sin deslizar.
5. Respaldo háptico en Android 28–29: `VIRTUAL_KEY`.
6. Velo `scrim` sin desenfoque en Android 28–30 o con el desenfoque apagado.
7. Back de Android y escape de VoiceOver ignorados hasta los 900 ms; no se puede saltear.
8. La terminal crece con una máscara desde el soma (o se separa en capa propia en `generar.py`).

## 11. Copy

No hay copy nuevo de interfaz. El prototipo usa el que ya está en el código: "Encender la chispa", "Tu chispa de hoy está lista", "Dos neuronas tuyas de mundos distintos están por conectarse.", "Tu chispa de hoy" / "Tu chispa extra", "Guardar idea", "Planificar", "No me sirve", "Compartir", "Más acciones", "Cerrar", "1 chispa para encender", "Usaste las chispas de hoy", y el resumen de `accessibilitySummary`.

## 12. Swipe en el reveal (flag `reveal_swipe`)

Paso 93 de `plan-ejecucion.md` (`plan.md` §4, versión 1.1). En el modal, con la chispa ya revelada, deslizar la tarjeta a la derecha la guarda y a la izquierda abre "No me sirve". Es un atajo: los botones siguen en su lugar y hacen lo mismo. En el prototipo (`index.html`, sección "Swipe") se prueba con el mouse o el dedo sobre el panel. Lo que no está en `plan.md` va marcado como **provisorio, a confirmar**.

### Cuándo se puede

- Desde que la chispa queda revelada: 900 ms desde el toque (200 con Reducir movimiento), el mismo momento en que se habilitan la cruz y el toque afuera. Antes, el panel no se mueve.
- Solo en el modal de la sinapsis (flag `reveal_synapse`). El reveal anterior y la chispa en Hoy no tienen gesto.
- Con el flag apagado no hay gesto ni acciones de VoiceOver: quedan solo los botones.
- Mientras corre una acción que salió del gesto (la hoja de circuitos, el diálogo del motivo o el guardado), el panel no se puede volver a deslizar.

### Qué hace cada lado

| Lado | Acción | Igual que |
|---|---|---|
| Derecha | Guarda. Con `projects`, abre la hoja "Dónde la guardás"; sin `projects`, guarda directo sin circuito | "Guardar idea" |
| Izquierda | Abre "¿Por qué no te sirve?" con los tres motivos | "No me sirve" |

Si el lado no aplica (la chispa ya está guardada, por ejemplo porque se tocó "Guardar idea" antes, o ya se descartó), el panel se resiste: se mueve un cuarto de lo que se mueve el dedo, hasta 32 pt, sin indicador ni háptico, y vuelve.

### Reconocimiento y convivencia con el scroll

- El gesto es del panel, no del fondo. Arranca a los 10 pt de movimiento y se decide una sola vez, en ese momento: si el desplazamiento está a menos de 30° de la horizontal (|y| ≤ 0,58 · |x|), es un swipe; si no, es scroll y el panel no se mueve en todo ese gesto.
- Una vez decidido como swipe, el scroll del modal se apaga hasta soltar: con texto grande el panel scrollea (§6) y un swipe un poco diagonal no lo puede mover.
- Empezar sobre un botón vale: el botón se cancela al moverse el dedo, como en cualquier lista de iOS.

### La tarjeta sigue al dedo

- x = desplazamiento del dedo, 1:1; y = 0. Rotación de x / ancho del panel × 4°, con tope de ±4°, sobre el centro. **La rotación es provisoria, a confirmar**; con Reducir movimiento no hay rotación.
- Detrás del panel, sobre el velo, aparece el indicador del lado que el panel deja al descubierto (como las acciones de una fila de iOS): "Guardar idea" con el ícono de marcador a la izquierda al deslizar a la derecha, y "No me sirve" a la derecha al deslizar a la izquierda. Va centrado en el alto de la pantalla (no del panel), a 16 pt del borde.
- El indicador es una pastilla `radius-full`. Antes del umbral, `surface` con borde `border` y texto `ink`, con opacidad proporcional al recorrido (0 → 1 hasta el umbral). Al cruzarlo, se llena de `accent` con texto `on-accent`, como el botón principal (negro en gris, hueso en grafito), sin animación de escala. No lleva rosa: el único rosa del modal sigue siendo la estrella. **Provisorio, a confirmar.**

### Umbral y háptico

- Umbral: 30 % del ancho del panel, con un mínimo de 96 pt (122 pt en un iPhone de 440 pt de ancho, con el panel de 408).
- Al cruzarlo hacia afuera, el indicador se llena y suena `.impact(weight: .medium)` (iOS) / `GESTURE_THRESHOLD_ACTIVATE` (Android, API 34+). Al volver hacia adentro sin soltar, se vacía y suena `.impact(weight: .light)` / `GESTURE_THRESHOLD_DEACTIVATE`. En Android 28–33, `CLOCK_TICK` para los dos. **Los hápticos son provisorios, a confirmar.** No es el háptico del reveal: aquel es uno solo y de la coreografía; este responde a la mano.
- También se acepta un tirón: si se suelta antes del umbral pero con más de 48 pt de recorrido y más de 700 pt/s hacia el mismo lado, cuenta como cruzado.

### Al soltar

| Caso | Con movimiento | Con Reducir movimiento |
|---|---|---|
| Antes del umbral (o hacia un lado que no aplica) | Vuelve al centro con `.spring(duration: 0.3, bounce: 0.2)`; la rotación vuelve con él | Vuelve al centro en 200 ms con el fundido sereno, sin rebote |
| Pasado el umbral | Sale por ese lado: x hasta el borde de la pantalla más 40 pt y opacidad 0, en 220 ms con la curva fundido (el impulso del dedo se nota porque arranca rápido) | Sin salida: el panel se funde en su lugar en 200 ms (fundido sereno) |
| Después de salir | Se abre la acción: la hoja de circuitos o el diálogo del motivo; sin `projects`, se guarda directo | Igual |
| Termina bien (eligió circuito o motivo, o se guardó) | El modal se cierra con su fundido de 200 ms (§7, "Cierre"). La chispa queda en Hoy con su estado nuevo | Igual |
| Se cancela (cerró la hoja, canceló el diálogo) o falla | El panel vuelve desde el lado por el que salió: x a 0 y opacidad 1 en 300 ms con la curva entrada. Si falló, el aviso de error de las acciones queda a la vista | Aparece en el centro con un fundido sereno de 200 ms |

Que el gesto cierre el modal y el botón no es a propósito: deslizar es sacar la tarjeta de encima; tocar el botón deja ver "Idea guardada" y seguir con Planificar o Compartir. **Provisorio, a confirmar.**

### Accesibilidad

- VoiceOver no usa el gesto. El título y el cuerpo, que son los elementos que toman el foco (a los 900 ms el foco va al título), tienen dos acciones personalizadas con `accessibilityAction(named:)`: "Guardar idea" y "No me sirve". Hacen lo mismo que el swipe, sin mover el panel: abren la hoja o el diálogo, y al terminar bien se cierra el modal. Solo aparecen con el flag, ya revelada, y la de cada lado solo si aplica.
- En Android, `CustomAccessibilityAction` con los mismos nombres en `semantics { customActions = … }`.
- Los botones siguen siendo el camino principal: el gesto no se anuncia ni tiene hint, y nada depende de él.
- Control por botón y Control por voz usan los botones.

### Analytics

`spark_swiped` (app) cuando se suelta pasado el umbral o se usa la acción de VoiceOver, antes de abrir la acción: `mode`, `direction` (`save`, `dismiss`) e `input` (`gesture`, `accessibility_action`). El resultado se sigue midiendo con `spark_saved` y `spark_feedback_given` (servidor), como con los botones.

### SwiftUI

- Un `DragGesture` dentro del `ScrollView` del modal le gana al scroll en iOS 18 o más, aunque vaya como `.simultaneousGesture`: con texto grande el panel deja de scrollear. Por eso el swipe es un `UIPanGestureRecognizer` que se instala en el `UIScrollView` que contiene al panel (`ScrollSwipeRecognizer`, una vista vacía detrás del panel que lo busca al entrar en la ventana). Solo empieza si el toque cae sobre el panel y el desplazamiento está a menos de 30° de la horizontal; `panGestureRecognizer.require(toFail:)` hace que el scroll espere a que falle. Mientras dura el swipe, `.scrollDisabled(true)`.
- `offset(x:)` y `rotationEffect` del panel desde un `@State` de arrastre; el indicador vive en el fondo del modal, detrás del `ScrollView`.
- `.sensoryFeedback(trigger: isArmed) { _, armed in armed ? .impact(weight: .medium) : .impact(weight: .light) }`.
- El gesto le pide la acción a `SparkActions` (`SparkActionRequest`: la misma hoja, el mismo diálogo y el mismo guardado de los botones) y `SparkActions` avisa si terminó bien o se canceló.
- En iOS 26 el diálogo del motivo es un popover anclado al botón "No me sirve": con la tarjeta afuera, la flecha apunta al lugar vacío donde estaba. Se lee bien, pero es **provisorio, a confirmar**.

### Decisiones provisorias (a confirmar)

1. El swipe exitoso cierra el modal; el botón no.
2. Rotación de hasta ±4° y salida por el borde en 220 ms.
3. Indicador detrás del panel, en `surface` antes del umbral y en `accent` después, sin rosa.
4. Umbral del 30 % del ancho (mínimo 96 pt), tirón desde 48 pt a 700 pt/s, ángulo de 30°.
5. Hápticos `.impact` medio y liviano (iOS) y `GESTURE_THRESHOLD_*` / `CLOCK_TICK` (Android).
6. Con Reducir movimiento: la tarjeta sigue al dedo (es movimiento que hace la persona) pero sin rotación, sin rebote y sin salida.
7. El popover del motivo (iOS 26) queda anclado al lugar del botón cuando la tarjeta ya salió.

## 13. Conos de crecimiento (flag `growth_cones`, 2026-10-17)

Referencia: microscopía de dos neuronas a punto de conectarse ("Dos NEURONAS a punto de CONECTARSE", La Hiperactina). En la punta de cada axón hay un **cono de crecimiento**: un cuerpo chico con filopodios que se estiran y se retraen todo el tiempo, tanteando. Los dos conos avanzan despacio, se tocan primero con las puntas y después se entrelazan, como un apretón de manos.

En Lumbre la neurona estática (soma y dendritas, del arte de `generar.py`) queda igual hasta x = 56 del lienzo de 240 × 80; de ahí sale un axón vivo que se afina hasta el cono. Componente: `GrowthConeSynapse` (LumbreDesign, `GrowthCones.swift`).

| Momento | Qué pasa |
|---|---|
| **Antes** (Hoy, chispa sin encender) | Los conos están separados (x 80 y 160). Los 8 filopodios de cada uno se estiran y se retraen a destiempo (fases propias, 0,7 a 1,4 rad/s), el axón ondula y el cono deriva un poco en vertical. En bucle, sin fin |
| **0 – 250 ms** | Entran las neuronas desde los costados (como antes) |
| **150 – 600 ms** | Los conos avanzan hasta quedar a 16 u del centro; el abanico de filopodios se cierra un 30 % hacia el otro |
| **600 – 650 ms** | Se tocan las puntas |
| **650 ms** | Salta la estrella con su resorte, el háptico y el glow (sin cambios) |
| **600 – 900 ms** | Ya conectados: los conos terminan de juntarse debajo de la estrella (x 114 y 126) y los filopodios se retraen y se apagan. Queda la unión limpia, tapada por la estrella |
| **Después** (tarjeta, compartir) | La misma pose, quieta: los dos axones unidos debajo de la estrella, sin filopodios |

- Ya no cruza el impulso: en el video no hay nada parecido y competía con el contacto.
- Con Reducir movimiento los filopodios quedan quietos (el reveal ya es un fundido de 200 ms).
- Sin el flag, vuelven las terminales fijas de §2.
- El prototipo `index.html` todavía muestra la versión de §2.

## 14. Botones de abajo (flag `reveal_buttons`, 2026-10-17)

La tarjeta del reveal queda limpia: las dos neuronas, la sinapsis, el título y la idea. Las acciones salen de la tarjeta y van abajo, como botones redondos de las apps de swipe:

| Botón | Qué hace |
|---|---|
| Izquierda, ✕ (64 pt, contorno) | "No me sirve": la tarjeta sale por la izquierda, igual que el swipe, y pide el motivo |
| Medio, compartir (52 pt, contorno) | La tarjeta para compartir; al volver, la tarjeta sigue en su lugar |
| Derecha, guardar (64 pt, negro, tick rosa) | La tarjeta sale por la derecha y se elige el circuito, igual que el swipe. El tick va en `spark`: es el único botón negro y el rosa siempre va apoyado en negro (compartir queda neutro: rosa sobre gris no se puede) |

- Aparecen con las acciones (750 → 900 ms) y se encogen un 8 % al tocarlos (sin escala con Reducir movimiento).
- Planificar sale del reveal: sigue en la chispa de Hoy y en el detalle.
- Reportar (obligatorio en Play para contenido de IA) queda con un toque largo sobre la tarjeta y como acción de VoiceOver.
- La estrella de la sinapsis mide 46 u de alto y tapa el punto donde se juntan los conos.
