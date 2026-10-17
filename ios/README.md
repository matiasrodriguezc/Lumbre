# iOS

App de Lumbre en SwiftUI (Swift 6, iOS 17 o más; Liquid Glass en iOS 26).

## Estructura

| Carpeta | Qué va |
|---|---|
| `Lumbre.xcodeproj` | Proyecto de Xcode con carpetas sincronizadas: los archivos nuevos dentro de `Lumbre/` entran solos. |
| `Lumbre/App` | Punto de entrada y navegación (TabView flotante + Capturar). |
| `Lumbre/Features` | Una carpeta por pantalla: Hoy, Bóveda, Proyectos, Perfil, Capturar. |
| `Packages/LumbreDesign` | Tokens generados, tipografía y componentes (botones, chips, SparkCard, SparkMeter, ConceptCard). |
| `Packages/LumbreCore` | Modelos, el contrato `LumbreAPI` y `MockLumbreAPI` con datos de prueba. |
| `scripts/generate_tokens.py` | Genera los colores y tokens de LumbreDesign desde `design/system/tokens.json`. |

## Comandos

Regenerar los tokens después de cambiar `tokens.json`:

```bash
python3 ios/scripts/generate_tokens.py
```

Compilar para el simulador:

```bash
xcodebuild -project ios/Lumbre.xcodeproj -scheme Lumbre -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath ios/.build/DerivedData build
```

Correr los tests de LumbreCore:

```bash
cd ios/Packages/LumbreCore && xcodebuild test -scheme LumbreCore -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

O abrir `ios/Lumbre.xcodeproj` en Xcode y correr el esquema **Lumbre** (arranca en español de Argentina).

## Backend

La app se conecta a `lumbre-dev` en Supabase (`App/AppEnvironment.swift`) con `SupabaseLumbreAPI` (paquete LumbreCore, sobre `supabase-swift`):

- **Lectura:** con la sesión del usuario y RLS. Hoy, Bóveda y el contador de chispas leen del remoto; guardar una chispa y "No me sirve" escriben ahí.
- **Sesión:** la guarda `supabase-swift` en el Keychain y se renueva sola. Las llamadas simultáneas comparten un solo login.
- **Login de desarrollo (solo Debug):** si existe `Lumbre/Resources/DevCredentials.plist` (fuera del repo, con `email` y `password`), la app entra como Ana, la usuaria de prueba de dev. Sin el archivo, entra como invitado, lo que requiere los ajustes de H14 en el dashboard.
- **Capturar** guarda textos y links con `capture_concept()`. La categoría se elige entre las del usuario o se escribe una nueva, y la sheet avisa cuando se va a crear. Voz y foto llegan con los pasos 48 y 50. Al guardar, Hoy y la Bóveda vuelven a cargar.

Argumentos de arranque (esquema → Run → Arguments, o `xcrun simctl launch … <arg>`):

| Argumento | Qué hace |
|---|---|
| `-mock` | Usa `MockLumbreAPI`, con los datos de prueba y sin red |
| `-mockPro` | Lo mismo, con el perfil de prueba en Pro (para probar el planificador y lo Pro) |
| `-resetSession` | Solo Debug: cierra la sesión guardada y prueba el primer login |

Las previews de SwiftUI siempre usan `MockLumbreAPI`.

## Extensiones: Share Extension, widget y App Intents

| Carpeta | Target | Qué hace |
|---|---|---|
| `LumbreShare` | Share Extension (`…lumbre.share`) | Compartir texto, links, texto seleccionado en Safari (con URL y título, vía `GetPageInfo.js`), una imagen o un PDF hacia la Red. Pide "¿Qué idea te deja esto?" y la categoría (sugiere las del usuario). |
| `LumbreWidgets` | Widget (`…lumbre.widgets`) | "Chispa de hoy" (chico, mediano, grande, rectangular e inline de pantalla bloqueada), "Guardar una idea" (chico y circular) y, en iOS 18, el control de captura. |
| `Shared` | App y widget | App Intents (`SaveIdeaIntent`, `OpenTodaySparkIntent`, `OpenCaptureIntent`), las vistas del widget y la tabla de textos `Extensions.xcstrings` (es-AR base, en). |

Cómo se conectan (todo por el App Group `group.com.matiasrodriguezc.lumbre`, en los tres `.entitlements` de `Config/`):

- **Snapshot del widget:** `CachedLumbreAPI` escribe la chispa de hoy y la próxima hora al cargar Hoy, y los nombres de las categorías al cargarlas (`LumbreShared`). El widget no habla con el servidor. Con `-mock` también se escribe.
- **Capturas desde afuera** (`ExternalCapture`): si la app dejó backend y sesión vigente, la extensión manda directo con la sesión **prestada** (la lee del Keychain, que usa el App Group como access group, y nunca la renueva: la app es la única dueña del refresh token). Si no hay sesión, falta red o el servidor falla, queda en la cola offline compartida y la manda la app al volver a primer plano. La cola relee el disco y escribe con `NSFileCoordinator`, así dos procesos no se pisan.
- **Links profundos:** `lumbre://today`, `lumbre://spark/<id>` y `lumbre://capture?entry=widget`. Los abre `ExtensionsBridge` (único enganche en `LumbreApp`), que también recibe los App Intents que abren la app y copia el tema al widget.
- **Flags:** `share_extension`, `widgets` y `app_intents`. Las extensiones leen los últimos valores remotos que la app guarda en el App Group.

Probar en el simulador:

```bash
# Renderiza todos los widgets a PNG en <App Group>/WidgetSnapshots/
xcrun simctl launch booted com.matiasrodriguezc.lumbre -mock -renderWidgetSnapshots
xcrun simctl get_app_container booted com.matiasrodriguezc.lumbre groups
# Link profundo
xcrun simctl openurl booted "lumbre://capture?entry=widget"
# Con el backend local: guarda una neurona de prueba por el camino de la extensión y anota el resultado en el log
xcrun simctl launch booted com.matiasrodriguezc.lumbre -checkExternalCapture
```

Provisorio (decisiones conservadoras, a confirmar): desde la Share Extension y Siri no se destila, siempre se escribe la idea; una imagen compartida queda en la otra app y se guarda solo la idea (como una foto en free); el widget de una chispa sin revelar muestra las dos neuronas pero no el título, para no arruinar el reveal. Con cuenta de Apple Developer (H1) hay que registrar el App Group para los tres bundle IDs.

## Pendientes conocidos

- **Fraunces:** el archivo de la fuente no está en el repo todavía. Mientras tanto los estilos display usan New York, la serif del sistema. Para activarla, copiar el variable font como `Packages/LumbreDesign/Sources/LumbreDesign/Resources/Fraunces.ttf`: el código la detecta sola.
- **Botón Capturar:** usa el lugar que iOS 26 le da a la pestaña de búsqueda, así que es de vidrio neutro y no magenta como en el componente NavBar. Un botón propio tintado no se puede fundir con la barra del sistema.
- **Ícono de app:** llega con el paso 8.
