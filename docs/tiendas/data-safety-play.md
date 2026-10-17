# Data safety de Google Play

Paso 65, parte docs (MAT-296). Respuestas del formulario de Play Console › App content › Data safety, coherentes con `docs/legal/privacidad.es.md`, con el inventario de `docs/legal/README.md` y con `privacidad-app-store.md`. Se completa cuando exista la app de Android (bloque H); se revisa contra el build real antes de mandarlo.

## Sección 1: Recolección y seguridad

| Pregunta | Respuesta | Nota |
|---|---|---|
| Does your app collect or share any of the required user data types? | **Yes** | |
| Is all of the user data collected by your app encrypted in transit? | **Yes** | HTTPS en todo (Supabase, Edge Functions, PostHog, Sentry, RevenueCat) |
| Which of the following methods of account creation does your app support? | **Username/password or other authentication** (email con link mágico) y **OAuth** (Google; Apple en iOS) | También "sin cuenta" (invitado) |
| Do you provide a way for users to request that their data is deleted? | **Yes** | En la app y por web |
| Delete account URL | `https://[DOMINIO]/borrar-cuenta` | **Falta crear esta página** (Play la exige aunque se pueda borrar desde la app). Tiene que explicar cómo pedir el borrado sin tener la app instalada |
| Can users request that some data be deleted without deleting their account? | **Yes** | Cada neurona, chispa y circuito se borra desde la app |

## Sección 2: Tipos de dato

"Compartido" en Play excluye a los proveedores que procesan por cuenta nuestra (Supabase, Anthropic, PostHog, Sentry, RevenueCat). Por eso **nada se marca como compartido**.

Para cada tipo recolectado: **Collected** = Yes · **Shared** = No · **Processed ephemerally** = No (salvo donde se indica) · **Required or optional** según la tabla.

| Categoría de Play | Tipo | ¿Recolecta? | Obligatorio | Propósitos |
|---|---|---|---|---|
| Personal info | **Email address** | Sí | Opcional (se puede usar como invitado) | App functionality, Account management |
| Personal info | **Name** | Sí | Opcional | Account management (lo manda Google al entrar; no se usa) |
| Personal info | **User IDs** | Sí | Obligatorio | App functionality, Analytics, Account management |
| Personal info | Address, Phone, Race, Political, Sexual orientation, Other | No | | |
| Financial info | **Purchase history** | Sí | Opcional (solo Pro) | App functionality |
| Financial info | Payment info, Credit score, Other | No | | Lo procesa Google Play |
| Health and fitness | — | No | | |
| Messages | — | No | | |
| Photos and videos | **Photos** | Sí | Opcional | App functionality. Las imágenes que se destilan se suben y se borran enseguida; se declara igual porque pasan por un tercero (Anthropic) y el resultado se guarda |
| Audio | Voice or sound recordings | No (provisorio) | | El dictado se transcribe en el teléfono. Pasa a Sí si se suben audios para destilar |
| Audio | Music files, Other audio | No | | |
| Files and docs | **Files and docs** | Sí | Opcional | App functionality (PDFs a destilar; se borran enseguida) |
| Calendar | — | No | | |
| Contacts | — | No | | |
| App activity | **App interactions** | Sí | Obligatorio | Analytics |
| App activity | In-app search history | No | | La búsqueda se procesa en el momento y no se guarda (procesamiento efímero) |
| App activity | Installed apps | No | | |
| App activity | **Other user-generated content** | Sí | Obligatorio | App functionality (neuronas, links, chispas, circuitos, planificador, reportes) |
| App activity | Other actions | No | | |
| Web browsing | Web browsing history | No | | Los links guardados son contenido del usuario |
| App info and performance | **Crash logs** | Sí | Obligatorio | Analytics, App functionality |
| App info and performance | **Diagnostics** | Sí | Obligatorio | Analytics, App functionality |
| App info and performance | Other app performance data | No | | |
| Device or other IDs | **Device or other IDs** | Sí | Obligatorio | Analytics, App functionality (id de instalación de PostHog y Sentry, token de FCM; no el AAID) |
| Location | Approximate / Precise | No | | Solo la zona horaria del teléfono |

**Fraud prevention, security, and compliance:** marcarlo también en User IDs y Device or other IDs si Play Integrity y los límites anti-abuso usan esos datos (paso 40).

## Sección 3: Lo que muestra la ficha

- No se comparten datos con terceros.
- Se recolectan: información personal, información financiera, fotos, archivos y documentos, actividad en la app, información y rendimiento de la app, identificadores del dispositivo.
- Los datos están cifrados en tránsito.
- Podés pedir que se borren tus datos.

## Otros formularios de App content relacionados

| Formulario | Respuesta |
|---|---|
| Privacy policy | `https://[DOMINIO]/privacidad` |
| Ads | No contiene anuncios |
| App access | Todo se puede usar como invitado; Pro necesita una cuenta de prueba (instrucciones como en `docs/lanzamiento/revision-app-store.md`) |
| Target audience | 18+ y 16–17 [según la edad mínima que confirme el abogado]; no dirigida a niños |
| Generative AI | Sí: la app genera contenido con IA y permite reportarlo desde la app (menú de acciones de cada chispa y de cada respuesta del planificador › Reportar; tabla `content_reports`) |
| Financial features | Ninguna |
| Health | Ninguna |
| Government apps | No |
| Data deletion | Ver sección 1 |
