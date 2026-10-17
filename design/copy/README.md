# Copy es/en

Paso 10 de `plan-ejecucion.md` (MAT-226). Todos los textos de la app en español (fuente) e inglés, ordenados por pantalla, en un solo archivo que alimenta el String Catalog de iOS y los `strings.xml` de Android.

| Archivo | Qué es |
|---|---|
| `copy.json` | La fuente. Un texto por línea, agrupado por pantalla |
| `copy.py` | Valida el archivo, genera el catálogo de iOS y los recursos de Android, y lo compara con el código |
| `build/ios/Localizable.xcstrings` | String Catalog generado (no se usa directo: ver abajo) |
| `build/android/values/strings.xml` | Android, español (idioma por defecto) |
| `build/android/values-en/strings.xml` | Android, inglés |
| `build/copy.csv` | Todo en una planilla, para revisar o pasarle a quien traduzca |

Lo de `build/` se genera: no lo edites a mano.

## Comandos

```sh
python3 design/copy/copy.py validar        # claves únicas y mismos placeholders en es y en
python3 design/copy/copy.py todo           # validar + catálogo + Android + CSV en build/
python3 design/copy/copy.py revisar-ios    # textos del código que faltan en copy.json, y al revés
python3 design/copy/copy.py formatear      # reordena copy.json con un texto por línea

# Volcar a las apps (cuando cada app lo adopte):
python3 design/copy/copy.py xcstrings --out ios/Lumbre/Resources/Localizable.xcstrings
python3 design/copy/copy.py android --out android/app/src/main/res
```

`xcstrings --out` **mezcla**: conserva las claves y traducciones que ya tenga el catálogo y solo agrega o pisa las de `copy.json` (las `nuevo` entran recién cuando el compilador las extrae del código). Las claves sin palabras (`×`, `%@ · %@`) quedan con `shouldTranslate: false`. Android genera los dos archivos completos.

## Cómo está armado `copy.json`

Cada texto:

```json
{"id": "hoy.extra.many_left", "es": "Te quedan %lld chispas extra hoy.", "en": "You have %lld extra sparks left today."}
```

- **`id`**: `pantalla.elemento`, estable. En Android es el nombre del recurso (`hoy_extra_many_left`).
- **`es`**: el texto fuente. **En iOS también es la clave**: SwiftUI usa el literal (`Text("Te quedan \(n) chispas extra hoy.")`) como clave del catálogo, así que tiene que coincidir con el código. Las interpolaciones se escriben como las escribe Xcode: `%lld` para enteros, `%@` para textos y fechas formateadas, `%%` para un % literal.
- **`en`**: la traducción, con los mismos placeholders. Si cambia el orden, posicionales: `%1$@`, `%2$@`.
- Opcionales: `note` (contexto; va como comentario en el catálogo), `platform` (`ios` o `android` si existe en una sola), `android` (reemplazo de es/en solo para Android: rutas de Configuración, Google Play, galería), `plural` (formas `one`/`other` con `%d` y `%s`: `<plurals>` en Android y variaciones de plural del catálogo en iOS, en los dos idiomas), `status` (`nuevo` = definido en diseño y todavía no en el código).
- Como en iOS la clave es el texto, **un mismo texto va una sola vez**. Lo que se repite entre pantallas vive en `comun`. `validar` falla si hay dos iguales.

Pantallas: comunes, navegación, onboarding, perfiles creativos, cuenta e invitado, Hoy, reveal, chispa, planificador, Capturar, Red, neurona, Circuitos, Perfil, paywall, errores, estados (vacíos, error, offline, contenido inaccesible), widget, export a Markdown.

## Voz en los dos idiomas

- Español rioplatense con voseo, sentence case, sin emoji. En inglés, el mismo tono: directo y cálido, frases cortas, sentence case.
- Vocabulario neuronal fijo: neurona / *neuron*, Red / *Network* ("tu red" / *your network*), Circuitos / *Circuits*, chispa / *spark*. Encender una chispa / *light a spark* ("Encender la chispa" → *Light the spark*, "Encendiendo…" → *Lighting…*). Conceptualizar / *conceptualize*. Capturar / *Capture*. Invitado / *guest*. "Sinapsis", "axón" y "dendrita" no van en la interfaz en ningún idioma.
- La chispa se escribe "A × B" en los dos idiomas.
- Rutas del sistema: iOS dice **Ajustes**, Android **Configuración** (en inglés, *Settings* en los dos). La tienda: cuenta de Apple en iOS, Google Play en Android. Esos textos llevan su reemplazo en `android`.

## Notas para quien implemente

- **iOS, app:** `ios/Lumbre/Resources/Localizable.xcstrings` tiene `en` para todo lo de la app. Después de cambiar textos: compilar, sincronizar el catálogo (`ios/README.md`), `copy.py xcstrings --out …` y `revisar-ios`, que también lista las claves sin inglés de los cuatro catálogos.
- Los textos de los paquetes (`LumbreDesign`, `LumbreCore`: `Text("…")` y `String(localized:)` sin `bundle:`) se buscan en el bundle principal, o sea en el catálogo de la app. En la Share Extension el bundle principal es el de la extensión: por eso `LumbreShare/Localizable.xcstrings` también lleva los errores de `LumbreAPIError`.
- **Extensiones:** el widget y los App Intents usan la tabla `Extensions` (`ios/Shared/Extensions.xcstrings`, con `extensionsText(…)` o `table: "Extensions"`), la Share Extension su propio `Localizable.xcstrings` y las frases de Siri `ios/Lumbre/App/AppShortcuts.xcstrings`. Esos tres catálogos se mantienen a mano, con su inglés; no salen de `copy.json`. El compilador igual extrae los `extensionsText(…)` a la tabla de la app: ahí quedan con `shouldTranslate: false`.
- Los plurales de iOS van con `plural` en `copy.json`: la clave es la forma `other` (`Guardá %lld neuronas para ganar 1 extra`) y el catálogo lleva las variaciones `one`/`other` en es y en. No usar `^[…](inflect: true)`: en español no concuerda. O dos claves (`1 captura…` / `%lld capturas…`). En Android esos casos van como `<plurals>`.
- **Android:** el idioma por defecto (`values/`) es el español, porque el foco inicial es hispano (plan.md §2 y §12). `values-en/` para inglés. Los nombres son `pantalla_elemento`.
- Cuando cambie un texto en el código, cambialo acá primero y corré `revisar-ios`: lista lo que falta y lo que quedó viejo.
