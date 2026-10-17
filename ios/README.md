# iOS

App de Lumbre en SwiftUI (Swift 6, iOS 17 o más; Liquid Glass en iOS 26). La interfaz habla de neuronas, Red, Circuitos y chispas (`plan.md` §3); en el código siguen los nombres técnicos (`Concept`, `Vault`, `Project`).

## Estructura

| Carpeta | Qué va |
|---|---|
| `Lumbre.xcodeproj` | Proyecto de Xcode con carpetas sincronizadas: los archivos nuevos dentro de `Lumbre/` entran solos (también los recursos, como `PrivacyInfo.xcprivacy`). |
| `Config/` | `Debug-Info.plist` y `Release-Info.plist`: lo que se suma al Info.plist generado (el esquema `lumbre://` y, solo en Debug, http con el Supabase local). |
| `Lumbre/App` | Punto de entrada, estado global (`AppModel`), navegación (TabView flotante + Capturar), push y a qué backend se conecta (`AppEnvironment`). |
| `Lumbre/Features` | Una carpeta por pantalla: Today (Hoy y el reveal), Vault (Red), Projects (Circuitos), Profile, Capture, Concept, Spark (detalle, guardar, tarjeta para compartir), Planner, Paywall, Onboarding, Account (crear cuenta o entrar con email) y Shared. |
| `Lumbre/Resources` | Íconos, String Catalog (`Localizable.xcstrings`, base es), `Lumbre.storekit` y el privacy manifest. |
| `Packages/LumbreDesign` | Tokens generados, tipografía (Fraunces empaquetada), identidad neuronal (neurona, sinapsis, red de fondo, pulso) y componentes. |
| `Packages/LumbreCore` | Modelos, el contrato `LumbreAPI`, `SupabaseLumbreAPI`, `MockLumbreAPI`, la caché (`CachedLumbreAPI`, SwiftData), la cola offline, el cliente de las Edge Functions, App Attest, analytics tipado y feature flags. Su propio String Catalog (`Resources/`, `bundle: .module`) para los errores y el export. |
| `scripts/generate_tokens.py` | Genera los colores y tokens de LumbreDesign desde `design/system/tokens.json`. |

## Comandos

Regenerar los tokens después de cambiar `tokens.json`:

```bash
python3 ios/scripts/generate_tokens.py
```

Compilar para el simulador (el udid sale de `xcrun simctl list devices available`):

```bash
xcodebuild -project ios/Lumbre.xcodeproj -scheme Lumbre -destination 'id=<udid>' -derivedDataPath ios/.build/DerivedData build
```

Correr los tests de LumbreCore (Swift Testing; los de integración se saltean si no está el Supabase local):

```bash
cd ios/Packages/LumbreCore && xcodebuild test -scheme LumbreCore -destination 'id=<udid>' -derivedDataPath ../../.build/DerivedData
```

Llevar a los String Catalogs los textos nuevos del código y cargarles el inglés de `design/copy/copy.json` (Xcode extrae solo al compilar desde el IDE; con `xcodebuild`, después del build). Los cinco catálogos y cuál usa cada target están en `design/copy/README.md`:

```bash
python3 design/copy/copy.py sincronizar-ios && python3 design/copy/copy.py ios && python3 design/copy/copy.py revisar-ios
```

O abrir `ios/Lumbre.xcodeproj` en Xcode y correr el esquema **Lumbre** (arranca en español de Argentina). Para probar en inglés: `-AppleLanguages "(en)"` al lanzar.

## Argumentos de arranque

Esquema → Run → Arguments, o `xcrun simctl launch booted com.matiasrodriguezc.lumbre <arg>`:

| Argumento | Qué hace |
|---|---|
| `-mock` | `MockLumbreAPI`: datos de prueba, sin red, plan free |
| `-mockPro` | Lo mismo, en Pro (planificador, chispas elegidas, conceptualización) |
| `-mockGuest` | Lo mismo, como invitado nuevo: arranca en el onboarding |
| `-remote` | Solo Debug: `lumbre-dev` en vez del Supabase local |
| `-seedUser` | Solo Debug y local: entra como Ana, la usuaria de `backend/supabase/seed.sql` |
| `-resetSession` | Solo Debug: cierra la sesión guardada y prueba el primer login |
| `-flag.<nombre> YES\|NO` | Solo Debug: pisa un feature flag (`-flag.account_email NO`) |
| `-open <pantalla>` | Solo Debug, con `-mock` o `-mockPro`: abre `spark` (detalle), `planner`, `concept`, `draft` (neurona en borrador), `paywall`, `share` (tarjeta para compartir) `consent` o `import` (importar notas); con `-mockGuest`, un paso del onboarding (`profile`, `seeds`, `spark_hour`, `push`) |
| `-revealAt <ms>` | Solo Debug: congela el reveal (flag `reveal_synapse`) en ese instante desde el toque (`-revealAt 450`) |
| `-importPath <ruta>` | Solo Debug: abre la vista previa de importar con una carpeta (como bóveda de Obsidian) o un `.md`, sin pasar por Archivos |
| `-importAutoSubmit YES` | Solo Debug: la vista previa importa sola lo elegido y vuelve a la Red |
| `-checkImportIntent <n>` | Solo Debug: corre `ImportNotesIntent` con n notas de prueba, como si llegaran del atajo de Apple Notes |

Las previews de SwiftUI siempre usan `MockLumbreAPI`. En el mock, el código del email es `123456` y `ana@lumbre.test` es una cuenta que ya existe.

## Backend

En Debug la app usa el Supabase local (`cd backend && supabase start`); con `-remote` o en Release, `lumbre-dev`. Todo pasa por `SupabaseLumbreAPI`, envuelto en `CachedLumbreAPI`:

- **Lecturas y escrituras directas** con la sesión del usuario y RLS (`backend/README.md`, "Qué usa la app"). Lo que genera contenido o gasta IA va por las Edge Functions (`capture`, `today`, `spark`, `search`, `planner`) con `EdgeFunctions`, que también lee el stream del planificador (SSE).
- **Sesión:** la guarda `supabase-swift` en el Keychain y se renueva sola. Sin sesión, entra como invitado (sesión anónima). Las llamadas simultáneas comparten un solo login.
- **Cuenta con email:** `AccountSheet` manda un código de 6 dígitos. Un invitado que crea su cuenta vincula el email al mismo usuario (`updateUser`, verificación `email_change`) y no pierde nada; "Ya tengo cuenta" entra con `signInWithOTP` (si no existe, la crea). El link del mail vuelve por `lumbre://auth-callback` y lo toma `RootView`. Si el servidor responde `account_required` (chispas extra, planificador), la app le ofrece crear la cuenta. En remoto necesita los ajustes de Auth de H14.
- **Caché offline:** `CachedLumbreAPI` guarda en SwiftData la última respuesta de perfil, Hoy, chispas, neuronas, categorías y circuitos, y la devuelve sin red. Se borra al cerrar sesión, al borrar la cuenta y al entrar a otra cuenta. También deja la chispa de hoy en el App Group para el widget.
- **Cola offline:** una captura sin red queda en el teléfono y se manda sola cuando vuelve (`CaptureQueue`).
- **App Attest:** `AppAttestor` firma los pedidos a las funciones de IA con headers `X-Lumbre-Attest-*` (protocolo en `AppAttest.swift`, lo verifica `backend/supabase/functions/_shared/attest/`). Donde no hay App Attest (simulador, o sin el entitlement de Apple Developer) el pedido sale sin firma. Si el servidor responde `attestation_failed`, descarta la clave y reintenta una vez.
- **Consentimiento para IA:** "Tus ideas y la IA" se pide en el onboarding y se cambia en Perfil > Privacidad (`AIConsent`). Sin un "Acepto", la app no conceptualiza, no pide chispas (ni la del día: `/today` la generaría) y el planificador no responde; guardar neuronas sigue andando. La respuesta se copia a la cuenta con `setAIConsent` en `profiles.ai_consent_at` (fecha del "Acepto", null si no aceptó); si la columna todavía no existe, queda en `user_metadata.ai_consent` de Auth y se reintenta en el próximo arranque.

## Privacidad

`Lumbre/Resources/PrivacyInfo.xcprivacy`: sin tracking; API de razón requerida solo UserDefaults (CA92.1); datos vinculados a la cuenta para que la app funcione (email, ideas, fotos y PDFs que se mandan a conceptualizar, id de usuario, compras) y la interacción para analytics. Si se suma un SDK (PostHog, Sentry, RevenueCat) o un dato nuevo, se actualiza junto con las etiquetas de App Store Connect.

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

Provisorio (decisiones conservadoras, a confirmar): desde la Share Extension y Siri no se conceptualiza, siempre se escribe la idea; una imagen compartida queda en la otra app y se guarda solo la idea (como una foto en free); el widget de una chispa sin revelar muestra las dos neuronas pero no el título, para no arruinar el reveal. Con cuenta de Apple Developer (H1) hay que registrar el App Group para los tres bundle IDs.

## Importar notas

Paso 89, flag `import_notes`. Red › Más › Importar notas, o el atajo de Apple Notes. El parser y la tanda viven en `LumbreCore/NoteImport.swift`; la hoja, en `Features/Import/ImportNotesView.swift`; el intent, en `App/ImportNotesIntent.swift`.

- **Markdown:** archivos `.md` sueltos o una carpeta entera (una bóveda de Obsidian, con subcarpetas) desde Archivos. Se saltean lo oculto (`.obsidian`, `.trash`), lo que no es Markdown, los vacíos y los de más de 1 MB. La tesis sale del `title` del front matter, de un título en la primera línea (`# …`), del nombre del archivo (si no es genérico, como "Untitled" o una fecha) o de la primera línea no vacía. Se saca la sintaxis (links, wikilinks, énfasis, callouts, comentarios `%% %%`). La carpeta de primer nivel sugiere la categoría; las sueltas van a "Notas importadas".
- **Vista previa:** elegir y descartar notas (de a una o por grupo), cambiar la categoría de cada grupo y editar la tesis (mantener apretada la nota). Las que ya se importaron en este teléfono arrancan sin elegir (se guardan solo huellas SHA-256, se borran al cerrar sesión).
- **Conceptualización:** las notas de 30 palabras o más se mandan a conceptualizar con la nota entera (`note_text`) si hay "Acepto" y cupo de conceptualización (las primeras, hasta lo que quede del mes; se puede apagar). Si no, o si la IA no saca nada, entran con su tesis.
- **Cupos:** cada nota cuenta como captura del día (30 en free, 200 en Pro). Lo que pasa del tope queda en la cola offline y sigue al día siguiente: la cola deja de reintentar hasta la medianoche del teléfono y la Red lo avisa. En free y como invitado, además, 50 notas importadas en total (`plan_limits` kind `import`; si una nota da varios conceptos, cuenta una).
- **Envío:** todo entra por `CaptureQueue` (`enqueue(contentsOf:)`, una sola escritura) y `/capture` con `import_source`, también sin red.

### Atajo de Apple Notes

iOS no deja que otra app lea Notas en bloque, así que el puente es Atajos:

1. Abrí Atajos y creá un atajo nuevo.
2. Agregá **Buscar notas** (Find Notes). Filtrá por carpeta, fecha o lo que quieras, y poné un límite si son muchas.
3. Agregá **Importar notas a Lumbre** y en **Notas** elegí la variable **Notas** de la acción anterior. Opcional: **Categoría** (por ejemplo, el nombre de la carpeta); si no, entran en "Notas importadas".
4. Corré el atajo. La primera vez Atajos pide permiso para leer Notas. Lumbre se abre con la vista previa.

Atajos pasa cada nota como texto (el título es la primera línea). El intent acepta hasta 1.000 por vez y no manda nada solo: siempre pasa por la vista previa.

Provisorio: en Pro, hasta 500 notas por tanda (tope técnico; tardan unos días en entrar por el tope de 200 capturas por día); las importadas cuentan para la chispa extra como cualquier neurona nueva (el tope de 2 por día no cambia); el invitado tiene el mismo cupo de 50 que free y lo conserva al crear la cuenta.

## Pendientes conocidos

- **Apple y Google** para entrar: esperan sus credenciales (H1, paso 20b). La sheet de cuenta ya avisa que llegan.
- **App Attest en un dispositivo real** necesita el entitlement `com.apple.developer.devicecheck.appattest-environment` (cuenta de Apple Developer, H1). Lo mismo el App Group (`group.com.matiasrodriguezc.lumbre`) y push.
- **RevenueCat** (paso 54): hoy el paywall usa StoreKit 2 directo con `Lumbre.storekit`. Falta el SDK, pasar el id de usuario como `appAccountToken`/app user id y que el plan lo marque el webhook.
- **PostHog y Sentry** (paso 44): los eventos y los flags ya están tipados (`Analytics`, `FeatureFlag`); hoy van al log del sistema y los flags usan sus valores por defecto.
- **Botón Capturar:** usa el lugar que iOS 26 le da a la pestaña de búsqueda, así que es de vidrio neutro y no tintado como en el componente NavBar.
