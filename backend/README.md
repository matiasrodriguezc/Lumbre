# Backend

Supabase: Postgres 17 + pgvector, RLS, Auth, Edge Functions, pg_cron y pgmq. Todo corre en local con la CLI y Docker; los entornos remotos (dev, staging, prod) se conectan en el paso 41.

## Estructura

| Ruta | Qué es |
|---|---|
| `supabase/config.toml` | Configuración del stack local. Usa los puertos 555xx para convivir con otros proyectos de Supabase. |
| `supabase/migrations/` | El esquema, en orden. Nunca se edita una migración ya aplicada: se agrega una nueva. |
| `supabase/tests/database/` | Tests de pgTAP. Cada archivo crea sus datos en una transacción y la revierte: no dependen del seed. |
| `supabase/tests/concurrency/` | Pruebas que necesitan varias conexiones a la vez (no entran en pgTAP). |
| `supabase/tests/functions/e2e.sh` | Las Edge Functions de punta a punta, como las usa la app. |
| `supabase/functions/` | Edge Functions (Deno). Una carpeta por función; lo compartido en `_shared/`. |
| `supabase/functions/_shared/ai/` | Gateway de IA: proveedores (local y Anthropic), embeddings, precios y prompts versionados. |
| `supabase/functions/_shared/attest/` | App Attest y Play Integrity del lado del servidor (paso 40). |
| `supabase/functions/_tests/` | Tests unitarios de Deno (gateway, links, adjuntos, integridad, contrato OpenAPI). No es una función. |
| `supabase/tests/load/` | Prueba de carga del batch nocturno (paso 63). Resultados en `LOAD-TEST.md`. |
| `eval/` | Set de evaluación de la chispa y su harness (paso 29). |
| `scripts/` | `costos.sh` (tablero de costos) y `generate-clients.sh` (clientes desde el contrato). |
| `SECURITY-REVIEW.md` | Revisión de seguridad del backend (paso 62). |
| `supabase/seed.sql` | Datos de prueba solo para local: usuarios A y B, conceptos y chispas iguales a los de la app de iOS, y los secretos de Vault para los crons locales. |
| `openapi.yaml` | El contrato de las Edge Functions. |

## CI

`.github/workflows/backend.yml` corre en cada PR y en cada push a `main` que toque `backend/`, con tres jobs:

- **unit:** `deno test` de las Edge Functions, el contrato OpenAPI y el set de evaluación (sin base).
- **database:** levanta Postgres con las migraciones desde cero y el seed, pasa el lint, corre los tests de pgTAP y la prueba de concurrencia.
- **auth:** levanta Auth, REST y Mailpit y corre `tests/auth/e2e.sh`.

Si falla, no se mergea.

## Comandos

Levantar el stack (con Docker abierto):

```bash
cd backend && supabase start
```

Volver a crear la base desde cero con las migraciones y el seed:

```bash
cd backend && supabase db reset
```

Crear una migración nueva:

```bash
cd backend && supabase migration new nombre_en_snake_case
```

Correr los tests de la base (pgTAP, en `supabase/tests/database/`):

```bash
cd backend && supabase test db
```

Probar que `consume_credit()` no se pasa del techo con llamadas simultáneas:

```bash
backend/supabase/tests/concurrency/consume_credit.sh
```

Probar Auth de punta a punta (invitado, vinculación de email y email mágico, con los mails de Mailpit):

```bash
backend/supabase/tests/auth/e2e.sh
```

Servir las Edge Functions (en otra terminal; recargan solas al guardar):

```bash
cd backend && supabase functions serve
```

Después de `supabase db reset`, completar embeddings y dominios una vez (el cron lo hace solo cada 5 minutos):

```bash
curl -X POST http://127.0.0.1:55521/functions/v1/process -H "Authorization: Bearer $(supabase status -o env | grep ^SERVICE_ROLE_KEY | cut -d'"' -f2)"
```

Probar las Edge Functions de punta a punta (invitado → captura → Hoy → cuenta → extra → búsqueda → Pro → planificador → export y borrado, más Ana, las internas y el webhook), con `supabase functions serve` corriendo:

```bash
backend/supabase/tests/functions/e2e.sh
```

Tests unitarios de las Edge Functions, el contrato y el set de evaluación (Deno 2; en macOS `brew install deno`; no necesitan el stack):

```bash
cd backend && deno test -A supabase/functions/_tests/ eval/
```

`supabase functions serve` corre las funciones con el Deno que trae su contenedor; el de Homebrew es solo para estos tests y los scripts de `eval/`.

Prueba de carga del batch nocturno (con `supabase functions serve`; ver `LOAD-TEST.md`):

```bash
backend/supabase/tests/load/daily_batch.sh             # 5.000 usuarios × 20 conceptos
USERS=500 backend/supabase/tests/load/daily_batch.sh   # más chica
```

Tablero de costos (local o, con `DB_URL`, el remoto):

```bash
backend/scripts/costos.sh 14
```

Revisar el esquema:

```bash
cd backend && supabase db lint --local
```

Frenar el stack:

```bash
cd backend && supabase stop
```

## Remoto

| Entorno | Proyecto | Región | Estado |
|---|---|---|---|
| dev | `udewtaksxfnnchuhydnr` (organización Lumbre, plan free) | São Paulo (sa-east-1) | Migraciones al día y datos de prueba cargados |
| staging | — | — | Paso 41 |
| prod | — | — | Paso 41 |

- API de dev: https://udewtaksxfnnchuhydnr.supabase.co · Dashboard: https://supabase.com/dashboard/project/udewtaksxfnnchuhydnr
- En dev, los usuarios de prueba (Ana y Beto) **no tienen contraseña**: la API es pública y no se puede entrar con ellos. Los usuarios para iniciar sesión se crean con Auth (paso 20).
- El historial de migraciones remoto usa las mismas versiones que los archivos de `supabase/migrations/`, así que `supabase db push` solo aplica las nuevas.
- Para subir migraciones con la CLI: `supabase login`, `supabase link --project-ref udewtaksxfnnchuhydnr` y `supabase db push`.

## Local

| Servicio | URL |
|---|---|
| API | http://127.0.0.1:55521 |
| Base | postgresql://postgres:postgres@127.0.0.1:55522/postgres |
| Studio | http://127.0.0.1:55523 |
| Mails de prueba | http://127.0.0.1:55524 |

Las claves locales se ven con `supabase status`. No van al repo.

## Reglas de acceso

Supabase da permisos completos sobre las tablas a `anon` y `authenticated`. Por eso todas las tablas tienen RLS activado, y lo que el usuario puede editar se habilita columna por columna:

| Tabla | El usuario puede | Solo el servidor (service role) |
|---|---|---|
| `profiles` | Leer el suyo; editar perfiles creativos, rol propio (`creative_role`, hasta 80 caracteres), hora, zona horaria, idioma, `onboarded_at` y `ai_consent_at` (la fecha la pone un trigger) | Crear, cambiar `plan` y `target_distance` (lo mueve el feedback con un trigger) |
| `categories` | Leer, renombrar y borrar las suyas | Crear (pasa por `capture_concept()`), asignar el dominio |
| `concepts` | Leer, corregir título, tesis, dominio y estado, y borrar los suyos; crear con `capture_concept()`; mover de categoría con `move_concept()` | Escribir el embedding y la destilación |
| `sparks` | Leer las suyas; cambiar `status`, `feedback` y `project_id` | Crear y escribir el contenido, `notified_at` |
| `usage_ledger` | Leer el suyo | Descontar, con `consume_credit()` |
| `domains`, `plan_limits` | Leer (también sin sesión) | Escribir |
| `projects` | Leer, renombrar y borrar los suyos; crear con `create_project()` | — |
| `sparks.project_id` | Guardar la chispa en un proyecto propio (foreign key compuesta) | — |
| `push_tokens` | Leer y borrar los suyos; registrar con `register_push_token()` | Mandar las push |
| `planner_threads`, `planner_messages` | Leer los suyos | Escribir (Edge Function del planificador) |
| `content_reports` | Reportar una chispa o un mensaje propios y leer sus reportes | — |
| `library_concepts` | Leer (con sesión) | Escribir |
| `llm_calls`, `app_config`, `cost_alerts`, `llm_cost_daily` (vista) | Nada | Todo |
| `bridge_topics` (temas puente, paso 92) | Nada (los recibe por `/bridge-topics`) | Todo |
| `spark_jobs`, `subscription_events`, `analytics_outbox` | Nada | Todo |
| `attest_keys`, `rate_limits` | Nada | Todo |
| `waitlist`, `demo_sparks`, `web_rate_limits` (web pública, ver `web/README.md`) | Nada | Todo |

`consume_credit()` solo la puede ejecutar el service role: si la app pudiera llamarla, alguien podría gastar la cuota de otro usuario. Lo mismo el emparejamiento (`pick_spark_pair`, `create_spark`, `spark_runway_days`), `llm_spend_today`, `invoke_edge_function` y los demás helpers del servidor.

`tests/database/01_rls.sql` verifica cada fila de esta tabla. Incluye una guarda que falla si se crea una tabla en `public` sin RLS, y otra que falla si aparece una función `security definer` nueva que la app pueda llamar (la lista cerrada está en el test; todas usan `auth.uid()`). **Toda tabla nueva lleva sus tests de acceso en el mismo cambio.**

## Cuotas

Toda operación que gasta IA pasa primero por `consume_credit(user, kind)`, desde una Edge Function:

- Los límites están en `plan_limits` y se cambian sin publicar versión.
- El plan efectivo sale de `effective_plan()`: `guest` si la sesión es anónima; si no, el `plan` del perfil.
- Los períodos (día y mes) se cuentan en la zona horaria del usuario.
- Si una fila tiene `earned_every`, el cupo se gana: 1 por cada N conceptos guardados en el período, con `max_count` como techo. Es el caso de las chispas extra en free (3 conceptos dan 1, hasta 2 por día).
- **Temas puente** (paso 92, solo Pro): `/bridge-topics` detecta con `bridge_domain_pair()` dos dominios con al menos 5 neuronas propias que casi no se cruzaron en chispas (umbrales en `app_config`), descuenta `bridge_topics` (1 por semana, lunes a lunes en la zona del usuario) y guarda la sugerencia en `bridge_topics`; el resto de la semana devuelve esa misma sin llamar a la IA (`current_bridge_topics()`).
- **Importar notas** (paso 89): `capture_concept()` con `p_import_source` (`markdown`, `apple_notes`) descuenta la captura del día como cualquier otra (`quota_exceeded`: la app la deja en la cola para mañana) y además, si el plan tiene fila `import` (free e invitado: 50 en `total`; Pro no tiene), una de ese cupo (`import_limit`). La neurona guarda `concepts.import_source`. `/capture` destila una nota larga desde `note_text` y devuelve el `import` de los conceptos de más.
- El descuento es atómico: el `update ... where used < techo` bloquea la fila, así que llamadas simultáneas no pasan el límite.
- Si la operación falla después de descontar, la Edge Function llama a `refund_credit(user, kind)`.
- La app muestra lo que le queda con `credit_status()`, que devuelve solo los cupos del usuario de la sesión.

| Plan | Captura | Destilación | Chispas extra | Planificador | Plan profundo | Proyectos | Temas puente |
|---|---|---|---|---|---|---|---|
| guest | 10 por día | — | — | — | — | 1 | — |
| free | 30 por día | 5 por mes | 2 por día, ganadas | — | — | 1 | — |
| pro | 200 por día | 300 por mes | 10 por día | 300 por mes | 60 por mes | 1000 ("ilimitados") | 1 por semana |

Los proyectos son un cupo `total`: no se renueva, se cuentan los que existen. `create_project()` lo respeta y `credit_status()` devuelve `remaining = máximo − proyectos actuales`.

Los de `guest` son provisorios hasta que el prototipo defina qué puede hacer un invitado (paso 14).

## Auth

| Forma de entrar | Estado |
|---|---|
| Invitado (sesión anónima) | Listo. Plan `guest`; se vincula a una cuenta sin perder datos |
| Email mágico (link o código de 6 dígitos) | Listo. El link vuelve a la app por `lumbre://auth-callback` |
| Sign in with Apple | Configurado en `config.toml`, apagado hasta tener las credenciales (H1) |
| Google | Configurado en `config.toml`, apagado hasta tener las credenciales (H1) |

- **Perfil automático:** el trigger `on_auth_user_created` crea el perfil de todo usuario nuevo con la zona horaria y el idioma que manda la app en `data: { timezone, locale }`. Si faltan o no son válidos, usa Buenos Aires y español.
- **Invitado que crea su cuenta:** con `updateUser({ email })` (email) o `linkIdentity()` (Apple o Google) el mismo usuario pasa a `is_anonymous = false`. Conserva sus conceptos y chispas y `effective_plan()` lo pasa a free.
- **Limpieza:** el job `limpiar-invitados` (pg_cron, 03:17 en Argentina) borra a los invitados sin sesión activa en 30 días, con todo lo suyo. Nunca borra cuentas reales.
- **Abuso:** 10 sesiones anónimas por hora por IP. Los invitados no tienen cupo de IA. App Attest y Play Integrity llegan en el paso 40.
- **Contraseñas:** Lumbre no las usa, pero la API de Auth las acepta. Por eso se exigen de 10 caracteres con letras y números, y un alta con contraseña tiene que confirmar el email.
- **Credenciales:** Apple y Google leen sus IDs y secretos de `supabase/.env` (ver `supabase/.env.example`), que no va al repo.

### Ajustes de Auth en el proyecto remoto

No viven en la base, así que las migraciones no los tocan. En dev se configuran desde el dashboard, en Authentication:

1. **Sign In / Providers:** activar *Allow anonymous sign-ins* y *Allow manual linking*.
2. **URL Configuration:** sumar `lumbre://auth-callback` a *Redirect URLs*.
3. **Rate Limits:** *Anonymous sign-ins* en 10 por hora.
4. **Providers → Email:** dejar *Confirm email* activado; contraseña mínima de 10 con letras y números.
5. **Emails:** sin SMTP propio, Supabase manda 2 mails por hora. Para probar con más gente hace falta el proveedor de email de H1.

## Categorías y captura

- Cada usuario arranca **sin categorías**. Se crean al guardar un concepto con `capture_concept(p_thesis, p_category, p_source_type, p_source_url, p_source_title, p_excerpt, p_local_asset_id)`. La app guarda por `/capture` (que la llama con el JWT del usuario y suma embedding, dominio y destilación); la RPC directa sigue andando para textos.
- La función, en una sola transacción: valida (tesis de 1 a 600 caracteres, categoría de 1 a 40, link con URL, URLs solo http(s)), descuenta la cuota de capturas, encuentra la categoría o la crea (hasta 50 por usuario) e inserta el concepto. Si algo falla, no se descuenta nada. Acepta `image` y `pdf` (sin URL obligatoria); el fragmento se corta a 500 caracteres y el título de la fuente a 300.
- Las categorías se comparan normalizadas: sin acentos, en minúscula y con los espacios colapsados. "Economía", " economia " y "ECONOMÍA" son la misma.
- Cada categoría tiene un `domain` opcional de la lista cerrada, que llena el servidor (paso 27). Los conceptos nuevos lo heredan.
- La lista cerrada son 25 dominios (`20260927230000_dominios.sql`). Los slugs no cambian nunca; para renombrar, se cambian `name_es` y `name_en`. La descripción de cada uno nombra mecanismos y vocabulario típico, porque es lo que se embebe para clasificar.
- Un concepto solo puede apuntar a una categoría de su mismo usuario (foreign key compuesta). Borrar una categoría deja sus conceptos sin categoría; no los borra.
- Errores (en el mensaje): `quota_exceeded`, `too_many_categories`, `invalid_thesis`, `invalid_category`, `invalid_source`, `not_authenticated`.

## Qué usa la app

Lo que la app hace **directo con su sesión** (PostgREST y RLS). Todo lo demás va por las Edge Functions (`openapi.yaml`).

| Qué | Cómo |
|---|---|
| Perfil | `profiles`: leer el suyo; editar `creative_profiles`, `spark_hour`, `timezone`, `locale` y `onboarded_at` (fin del onboarding) |
| Consentimiento para la IA | `profiles.ai_consent_at`: al "Acepto", cualquier fecha no nula (el trigger guarda la hora del servidor y conserva la primera si ya había aceptado); al "No acepto" o al revocar, `null`. Sin fecha, `/capture` guarda sin destilar (`distillation: consent_required`), `/spark` y `/planner` responden 403 `ai_consent_required` (antes de cobrar), `/today` no genera la diaria y el batch nocturno la saltea |
| Cupos | `rpc/credit_status`: un registro por cupo (`kind`, `period`, `max_count`, `available`, `used`, `remaining`), incluido `projects` (`period = 'total'`) |
| Bóveda | `concepts` y `categories`: leer (con `category:categories(id,name,domain:domains(slug,name_es,name_en,symbol_ios))`); editar `title`, `thesis`, `status` (confirmar un borrador); borrar. Renombrar y borrar categorías |
| Mover un concepto de categoría | `rpc/move_concept(p_concept, p_category)`: la crea si no existe (límite de 50) y el concepto hereda su dominio |
| Guardar texto sin pasar por la función | `rpc/capture_concept(...)` (sin embedding hasta que corre `/process`; la app usa `/capture`) |
| Chispas | `sparks`: leer; cambiar `status` (`revealed`, `saved`, `discarded`), `feedback` (`obvious`, `irrelevant`, `already_had`) y `project_id`. El feedback mueve la banda del emparejamiento |
| Guardar una chispa | `rpc/save_spark(p_spark, p_project, p_as_neuron)`: la guarda (con su circuito o `null`) y, con `p_as_neuron` (flag `spark_neuron` de la app) y `app_config.spark_neuron_enabled`, la primera vez crea su neurona (`source_type = 'spark'`, `origin_spark_id`, `origin_lo`, `origin_hi`). Devuelve el id de esa neurona o `null`. La neurona no gasta cupo de captura, no suma para la chispa extra y nunca se empareja con sus padres |
| Proyectos | `projects`: leer, renombrar (`name`) y borrar; crear con `rpc/create_project(p_name)` (error `too_many_projects`) |
| Planificador | `planner_messages` y `planner_threads`: leer (los mensajes los escribe `/planner`) |
| Reportes de contenido IA | `content_reports`: insertar `spark_id` o `planner_message_id`, `reason` (`offensive`, `dangerous`, `wrong`, `other`) y `note` (≤ 500). El `user_id` lo pone la base |
| Push | `rpc/register_push_token(p_token, p_platform, p_sandbox)` |
| Cuenta | `rpc/export_my_data()` (JSON con todo, sin embeddings) y `rpc/delete_my_account()` (borra el usuario de auth y todo lo suyo) |
| Biblioteca y dominios | `library_concepts` y `domains`: leer |
| Adjuntos | Storage, bucket privado `capture-temp`: subir a `<user_id>/<uuid>.<ext>` (JPEG, PNG o PDF, hasta 20 MB) y pasar la ruta a `/capture`, que lo borra siempre |

Errores de las RPC (en el mensaje): `not_authenticated`, `invalid_thesis`, `invalid_category`, `invalid_source`, `invalid_request`, `quota_exceeded`, `too_many_categories`, `too_many_projects`, `not_found`.

## Edge Functions

| Función | Quién la llama | Qué hace |
|---|---|---|
| `capture` | App | Guarda (con `capture_concept()` y el JWT del usuario), destila si se pide y hay consentimiento (cupo `distill`, se devuelve si falla), embebe y clasifica la categoría. Lee y borra el adjunto de `capture-temp` |
| `today` | App | Chispa diaria del día local (la genera si falta y hay consentimiento), cupo, extras de hoy, días de pares y cantidad de conceptos |
| `spark` | App | Chispa extra (`spark_extra`) o elegida (`pick`, Pro). Devuelve el crédito si no hay par o falla la IA |
| `search` | App | Embebe la consulta y busca con `match_concepts()` (RLS filtra) |
| `planner` | App | Mensaje al planificador (Pro) con respuesta SSE: `delta`, `done`, `error` |
| `dev-plan` | App, solo local | Cambia el plan (404 salvo `LUMBRE_DEV_TOOLS=true`; un invitado primero crea su cuenta) |
| `revenuecat-webhook` | RevenueCat | Plan pro/free por eventos, idempotente por id (`subscription_events`) |
| `process` | pg_cron | Embeddings pendientes (conceptos, dominios, biblioteca), dominio de las categorías y la bandeja de analytics |
| `daily-sparks` | pg_cron | Chispas diarias de quien ya empezó su día; con Anthropic, por la Batches API (`{collect: true}` levanta resultados) |
| `send-pushes` | pg_cron | Push a quien le llegó la hora (APNs); sin claves, loguea y marca `notified_at` |
| `waitlist` | Web pública | Fila con referidos: `join` (anota y manda el mail de confirmación), `status` (puesto; con el token del mail, confirma) y `leave`. Sin sesión (`verify_jwt = false`), con límites por IP y email (ver `web/README.md`) |
| `demo-spark` | Web pública | Dos ideas → una chispa por el gateway de IA, una por email y por día; el email entra a la fila. No guarda ni loguea las ideas (ver `web/README.md`) |

- Las de la app tienen `verify_jwt = true`; las internas y el webhook validan su propio secreto (clave de servicio o `REVENUECAT_WEBHOOK_SECRET`).
- Variables de entorno: `supabase/.env.example` (bloque de Edge Functions). En local van en `supabase/functions/.env`, que no va al repo; en remoto, `supabase secrets set --env-file supabase/functions/.env`.
- **Invitados:** sin IA de pago. La chispa diaria se les genera igual (es el loop principal) y no consume cupos; con el proveedor local no cuesta nada, con Anthropic cuenta para el tope diario en dólares. `/spark` y `/planner` responden `403 account_required`.
- Eventos de servidor (`docs/analytics.md`, fuente S): `_shared/analytics.ts`. Sin `POSTHOG_API_KEY` se escriben en el log. Los que nacen de escrituras directas de la app (`spark_saved`, `spark_feedback_given`, `concept_deleted`, `project_created`, `data_exported`, `account_deleted`) los deja un trigger en `analytics_outbox` y los manda `/process`. Nunca llevan contenido del usuario.
- Logs: una línea JSON por evento, sin texto de las notas, búsquedas ni mensajes.
- **Límites anti-abuso** (además de los cupos de `plan_limits`): `/search` 120 por hora y `/today` 300 por hora por usuario, con `hit_rate_limit()` (429 `rate_limited`; provisorios, `LUMBRE_SEARCH_PER_HOUR` y `LUMBRE_TODAY_PER_HOUR`).
- **Adjuntos** (paso 34): el bucket `capture-temp` acepta hasta 20 MB. `/capture` no manda al modelo imágenes de más de 5 MB o 8.000 px de lado ni PDFs de más de 20 MB o 30 páginas (`LUMBRE_MAX_PDF_PAGES`): los guarda con la idea de la persona sin gastar destilación. El archivo se borra siempre; lo que se subió sin captura lo borra `/process` a la hora.
- **Consentimiento para la IA** (`profiles.ai_consent_at`, plan.md §10): lo que manda contenido del usuario a un modelo (destilación, chispas extra y elegidas, planificador, la diaria de `/today` y del batch) lo exige. Se pide también con el proveedor local, así dev se comporta como producción. La búsqueda y los embeddings no lo piden: hoy son locales (si se pasa a Voyage, revisar).
- **Destilación:** si no sale nada útil (confianza baja o un archivo que no se pudo leer) se devuelve el cupo `distill`, aunque la persona haya escrito su idea.

### Integridad del dispositivo (paso 40)

`capture`, `today`, `spark`, `search` y `planner` pasan por `requireDeviceIntegrity()` (`_shared/attest/guard.ts`), con el protocolo de headers de la app de iOS (`ios/Packages/LumbreCore/Sources/LumbreCore/AppAttest.swift`): `X-Lumbre-Attest-Key`, `X-Lumbre-Attest-Time` y `X-Lumbre-Attestation` (la primera vez) o `X-Lumbre-Assertion`; el mensaje firmado es `"<función>\n<segundos Unix>\n<cuerpo>"`. Android (paso 70) manda `X-Lumbre-Integrity-Token` con `requestHash` = SHA-256 en hex del mismo mensaje.

| `LUMBRE_ATTESTATION` | Qué hace |
|---|---|
| `off` (default; local y dev) | Nada |
| `report` | Verifica y loguea `{fn: "attest", ok, reason}`; nunca bloquea |
| `enforce` | Sin firma válida: 403 `attestation_failed` (la app descarta la clave y crea otra) |

- **App Attest:** cadena x5c hasta la raíz de Apple (embebida; se puede pisar con `APPLE_APP_ATTEST_ROOT_PEM`), nonce de la extensión `1.2.840.113635.100.8.2`, keyId, App ID (`APP_ATTEST_APP_ID` o `APNS_TEAM_ID.APNS_BUNDLE_ID`), contador y entorno (`APP_ATTEST_ALLOW_DEVELOPMENT`). La clave pública y el contador quedan en `attest_keys`; cada aserción tiene que subir el contador (una repetida no pasa). Tiempo: ±5 minutos.
- **Play Integrity:** `decodeIntegrityToken` con una cuenta de servicio (`PLAY_INTEGRITY_SERVICE_ACCOUNT`, `ANDROID_PACKAGE_NAME`); exige paquete, `requestHash`, menos de 5 minutos, `PLAY_RECOGNIZED` y `MEETS_DEVICE_INTEGRITY` (o básica con `PLAY_INTEGRITY_ALLOW_BASIC=true`).
- Tests en `_tests/attest.test.ts` con una cadena de certificados de prueba (Apple no publica atestaciones de ejemplo) y un test que verifica la autofirma de la raíz real.

## IA

Todo pasa por el gateway (`functions/_shared/ai/gateway.ts`): `complete()`, `stream()`, batches y `embed()`, con reintentos (backoff exponencial con jitter), modelo de respaldo, tope diario en dólares por usuario y global (`app_config`, contra `llm_calls` del día) y registro de **cada** llamada en `llm_calls` (función, modelo, versión de prompt, tokens, costo, latencia, batch). Las fallidas quedan como `<función>:error`.

| Proveedor | Cuándo | Qué hace |
|---|---|---|
| `local` | Sin `ANTHROPIC_API_KEY` (default) o `LUMBRE_AI_PROVIDER=local` | Simula, determinístico. Destilación: título, tesis de la primera oración, principio con plantilla, confianza por largo (baja sin texto: no lee imágenes ni PDFs, así que pide la tesis). Chispa: "A × B" con plantillas elegidas por hash del par. Planificador: plantilla por atajo, en streaming. Costo 0, modelo `local` en `llm_calls` |
| `anthropic` | Con `ANTHROPIC_API_KEY` | SDK oficial (`npm:@anthropic-ai/sdk`, se importa solo si hay clave). JSON estructurado para destilar y chispas, streaming para el planificador, prompt caching del contexto fijo, imágenes y PDFs como bloques nativos, Batches API para la diaria |

| Variable | Default | Para qué |
|---|---|---|
| `LUMBRE_MODEL_FAST` | `claude-haiku-4-5` | Destilación, chispas, planificador rápido |
| `LUMBRE_MODEL_DEEP` | `claude-sonnet-5` | Plan profundo |
| `LUMBRE_MODEL_FALLBACK` | `claude-haiku-5-5` | Si el principal sigue fallando o se niega |

Precios por modelo en `_shared/ai/pricing.ts` (lectura de caché al 10%, escritura al 125%, batch al 50%). Prompts versionados en `_shared/ai/prompts/` (`distill.v1`, `spark.v1`, `planner.v1`): el contenido externo (páginas, archivos, notas) va delimitado y el prompt dice que son datos, no instrucciones.

**Embeddings:** `local` (default) es hashing de palabras sin acentos, raíces y trigramas a 1024 dimensiones con norma 1: textos que comparten palabras quedan cerca, pero no entiende sinónimos ni otros idiomas. Con `VOYAGE_API_KEY` usa `voyage-3.5` (1024). El modelo se guarda con cada vector; si cambia, `/process` re-embebe de a 200. La elección definitiva es el paso 22.

**Moderación:** heurística local barata de entrada y salida (`_shared/moderation.ts`), con la interfaz de un clasificador real. **Lectura de links:** `_shared/links.ts`, con timeout de 8 s, 1,5 MB como máximo, solo hosts públicos (sin localhost ni redes privadas), Open Graph y texto principal.

### Pasar a Anthropic

1. `ANTHROPIC_API_KEY=...` en `supabase/functions/.env` (local) o `supabase secrets set ANTHROPIC_API_KEY=...` (remoto). Opcional: `VOYAGE_API_KEY` para embeddings reales (re-embebe todo solo).
2. Revisar los modelos y `app_config` (`user_daily_usd_cap`, `global_daily_usd_cap`).
3. Correr el set de evaluación (pasos 29 y 30) antes de abrirlo a usuarios.

## Emparejamiento

SQL, sin LLM (`20261009130000_emparejamiento.sql`). `pick_spark_pair(user, exclude_daily)`:

- Candidatos: conceptos `ready` con embedding (los 300 más recientes), de **dominios distintos** (o de categorías distintas si todavía no tienen dominio), con el mismo modelo de embeddings.
- Banda media relativa al usuario: percentil de cada distancia entre las suyas, centro en `profiles.target_distance` (0,6) ± 0,2. El feedback lo corre: obvia +0,03, irrelevante −0,03 (entre 0,35 y 0,85).
- Descanso de 3 días por concepto y pares que nunca se repiten. De los 20 más cerca del centro se sortea uno pesando la novedad.
- Respaldo: un concepto del usuario con uno de `library_concepts` (de sus perfiles, de otro dominio), que se copia a su bóveda con `from_library = true`. Las extra, antes, aceptan conceptos sin descanso (nunca los de la diaria de hoy); la diaria, como último recurso.
- `spark_runway_days(user)`: pares en la banda sin usar; con menos de 7, la app pide capturar más. `create_spark(...)` guarda y marca el uso.

## Crons

| Job | Cuándo | Qué |
|---|---|---|
| `limpiar-invitados` | 06:17 UTC | Borra invitados abandonados |
| `vencer-texto-crudo` | 06:27 UTC | `raw_text` vencido (30 días) a null |
| `limpiar-limites` | 06:37 UTC | Borra las ventanas viejas de `rate_limits` |
| `limpiar-web` | 06:37 UTC | Web pública: ventanas de `web_rate_limits` de más de 2 días, chispas de la demo de más de 30 y emails sin confirmar de más de 30 |
| `alertas-de-costo` | 03:05 UTC | Guarda en `cost_alerts` los usuarios del día anterior por encima de su tope y el global si pasó el 80% |
| `procesar-pendientes` | cada 5 min | `/process` |
| `chispas-diarias` | cada minuto | `/daily-sparks` (200 usuarios por llamada; ver `LOAD-TEST.md`) |
| `chispas-diarias-resultados` | cada 10 min | `/daily-sparks` con `{"collect": true}` |
| `enviar-pushes` | cada 5 min | `/send-pushes` |

Los que llaman a Edge Functions usan pg_net con `invoke_edge_function()`, que lee de Vault la URL y la clave. En local las carga `seed.sql` (`http://kong:8000/functions/v1`, la red de Docker del stack, y la clave de servicio pública de desarrollo). Las respuestas quedan en `net._http_response`. En remoto se cargan una vez por entorno, desde el SQL Editor:

```sql
select vault.create_secret('https://<ref>.supabase.co/functions/v1', 'lumbre_functions_url');
select vault.create_secret('<clave de servicio del proyecto>', 'lumbre_service_key');
```

Sin esos secretos, los jobs no fallan: avisan con un notice y no hacen nada.

## Costos

- `app_config`: topes diarios en dólares (`user_daily_usd_cap` 0,05 y `global_daily_usd_cap` 20). El gateway corta antes de llamar al modelo si se pasaron.
- `llm_cost_daily` (vista): día, función, modelo, llamadas, tokens, costo y latencia promedio.
- `llm_cost_alerts(día)`: usuarios por encima del tope y el total global; el job diario los guarda en `cost_alerts`.
- `llm_cost_dashboard(días)`: por día, total, llamadas, errores, batch, usuarios con IA, costo por usuario y costo promedio por chispa, destilación y mensaje del planificador.
- `llm_cost_month()`: el mes contra el objetivo de costo por usuario activo (`active_user_month_target_usd`, US$ 0,15).
- `llm_cost_signals(día)`: topes superados, chispa más cara que `spark_target_usd` (US$ 0,005, compuerta F2), más de `error_rate_alert` (10%) de llamadas fallidas y modelos de pago sin precio en `pricing.ts`.
- **`scripts/costos.sh [días]`** imprime todo eso, el gasto por función y modelo, los que más gastaron hoy, las alertas guardadas y los topes; sale con 1 si hay señales (sirve para un cron o un CI). Contra el remoto: `DB_URL=<cadena del session pooler> backend/scripts/costos.sh`.
- Todo es solo service role (también se puede consultar desde el SQL Editor o Studio con las mismas funciones).

## Set de evaluación de la chispa (paso 29)

Plan.md §5: 100 pares por perfil, puntuados a mano en "sorprende" y "sirve" (1 a 5); objetivo 3,5 de promedio. Todo en `eval/`:

| Archivo | Qué es |
|---|---|
| `concepts.v1.json` | 24 conceptos por perfil (`software`, `content`, `business`, `design`, `curiosity`), de 10 a 19 dominios cada uno, como los que guardaría alguien de ese perfil |
| `set.v1.json` | Los 500 pares (100 por perfil, siempre de dominios distintos), congelados con el texto de los dos conceptos. Lo arma `build-set.ts` (determinístico) |
| `run.ts` | Genera las chispas con el mismo pedido que producción (`sparkRequest` + `checkSparkJson`) y deja la planilla en `runs/<fecha>_<prompt>_<modelo>.csv` (más un `.meta.json` con tokens, costo y fallas). No toca la base |
| `score.ts` | Lee la planilla puntuada (CSV con coma o punto y coma) y da el promedio por perfil y total, las 10 más flojas y si llega a 3,5 |

```bash
cd backend
ANTHROPIC_API_KEY=… deno run -A eval/run.ts                 # las 500 (menos de US$ 1 con Haiku 4.5)
deno run -A eval/run.ts --profile software --limit 20       # una pasada chica
deno run --allow-read eval/score.ts eval/runs/<corrida>.csv
```

Sin clave usa el proveedor local (sirve para probar el circuito, no para puntuar). Cada cambio de prompt es `spark.vN` y se corre contra el mismo set; si cambian los conceptos, `concepts.v2` y `set.v2`. Puntuar es la tarea H6; iterar el prompt, el paso 30.

## Contrato y clientes (paso 39)

- `openapi.yaml` es el contrato de las Edge Functions de la app. `_tests/contract.test.ts` comprueba que coincide con el código: una función por path, los códigos de error de `_shared/http.ts` (con su status, en `x-error-codes`), que cada error que puede lanzar una función esté documentado, `verify_jwt` contra la seguridad de cada path y los campos que lee cada función del cuerpo.
- `tests/functions/e2e.sh` valida además las respuestas reales contra los schemas (`_tests/validate-response.ts`, con Ajv).
- `scripts/generate-clients.sh [swift|kotlin]` genera los clientes en `backend/build/clients/` (no va al repo): Swift con swift-openapi-generator de Apple y Kotlin con openapi-generator (Retrofit + kotlinx.serialization). El cliente Swift iría como un target `LumbreAPIClient` en `ios/Packages/LumbreCore`; hoy la app usa `EdgeFunctions.swift`, escrito a mano con el mismo contrato.
