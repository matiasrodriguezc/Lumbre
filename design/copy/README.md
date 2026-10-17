# Copy es/en

Paso 10 de `plan-ejecucion.md` (MAT-226). Todos los textos de la app en español (fuente) e inglés, ordenados por pantalla, en un solo archivo que alimenta el String Catalog de iOS y los `strings.xml` de Android.

| Archivo | Qué es |
|---|---|
| `copy.json` | La fuente. Un texto por línea, agrupado por pantalla |
| `copy.py` | Valida el archivo, carga los catálogos de iOS, genera los recursos de Android y lo compara con el código |
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

# iOS, después de compilar con -derivedDataPath ios/.build/DerivedData (ios/README.md):
python3 design/copy/copy.py sincronizar-ios   # claves del código a los catálogos, saca las que ya no están
python3 design/copy/copy.py ios               # el inglés de copy.json a los cinco catálogos

# Android (cuando lo adopte):
python3 design/copy/copy.py android --out android/app/src/main/res
```

`ios` **mezcla**: en cada catálogo traduce solo las claves que ya tiene (las que extrajo el compilador o, en Extensions y AppShortcuts, las que se agregaron a mano), así un mismo `copy.json` alimenta los cinco sin meter en uno lo de los otros. Las claves sin palabras (`×`, `%@ · %@`) quedan con `shouldTranslate: false`. `xcstrings --out <catálogo>` hace lo mismo con uno solo. Android genera los dos archivos completos.

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

Pantallas: comunes, navegación, onboarding, perfiles creativos, cuenta e invitado, Hoy, reveal, chispa, planificador, Capturar, Red, neurona, Circuitos, Perfil, paywall, errores, estados (vacíos, error, offline, contenido inaccesible), widget, Siri y App Intents, Share Extension, export a Markdown.

## Voz en los dos idiomas

- Español rioplatense con voseo, sentence case, sin emoji. En inglés, el mismo tono: directo y cálido, frases cortas, sentence case.
- Vocabulario neuronal fijo: neurona / *neuron*, Red / *Network* ("tu red" / *your network*), Circuitos / *Circuits*, chispa / *spark*. Encender una chispa / *light a spark* ("Encender la chispa" → *Light the spark*, "Encendiendo…" → *Lighting…*). Conceptualizar / *conceptualize*. Capturar / *Capture*. Invitado / *guest*. "Sinapsis", "axón" y "dendrita" no van en la interfaz en ningún idioma.
- La chispa se escribe "A × B" en los dos idiomas.
- Rutas del sistema: iOS dice **Ajustes**, Android **Configuración** (en inglés, *Settings* en los dos). La tienda: cuenta de Apple en iOS, Google Play en Android. Esos textos llevan su reemplazo en `android`.

## Notas para quien implemente

- **iOS: cinco catálogos**, todos con el inglés de `copy.json`. Después de cambiar textos: compilar, `sincronizar-ios`, `ios` y `revisar-ios`, que compara el código de la app, las extensiones y los paquetes con `copy.json` y lista las claves sin inglés de cada catálogo.

  | Catálogo | Qué textos | Claves |
  |---|---|---|
  | `ios/Lumbre/Resources/Localizable.xcstrings` | La app y `LumbreDesign` (sus `Text("…")` se buscan en el bundle principal) | `sincronizar-ios` |
  | `ios/Packages/LumbreCore/Sources/LumbreCore/Resources/Localizable.xcstrings` | Errores de `LumbreAPIError` y el export, con `bundle: .module`: el bundle del paquete viaja en la app y en cada extensión, así se traducen igual corra donde corra (widget, App Intents, Share Extension) | `sincronizar-ios` |
  | `ios/LumbreShare/Localizable.xcstrings` | Share Extension | `sincronizar-ios` |
  | `ios/Shared/Extensions.xcstrings` | Widget y App Intents (`extensionsText(…)` o `table: "Extensions"`) | a mano: el compilador extrae `extensionsText(…)` a la tabla de la app |
  | `ios/Lumbre/App/AppShortcuts.xcstrings` | Frases de Siri (`${applicationName}`) | a mano |
- Los plurales de iOS van con `plural` en `copy.json`: la clave es la forma `other` (`Guardá %lld neuronas para ganar 1 extra`) y el catálogo lleva las variaciones `one`/`other` en es y en. No usar `^[…](inflect: true)`: en español no concuerda. O dos claves (`1 captura…` / `%lld capturas…`). En Android esos casos van como `<plurals>`.
- **Android:** el idioma por defecto (`values/`) es el español, porque el foco inicial es hispano (plan.md §2 y §12). `values-en/` para inglés. Los nombres son `pantalla_elemento`.
- Cuando cambie un texto en el código, cambialo acá primero y corré `revisar-ios`: lista lo que falta y lo que quedó viejo.
