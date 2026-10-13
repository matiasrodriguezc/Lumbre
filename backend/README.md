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
| `supabase/seed.sql` | Datos de prueba solo para local: usuarios A y B, conceptos y chispas iguales a los de la app de iOS, y los secretos de Vault para los crons locales. |
| `openapi.yaml` | El contrato de las Edge Functions. |

## CI

`.github/workflows/backend.yml` corre en cada PR y en cada push a `main` que toque `backend/`, con dos jobs:

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
| `profiles` | Leer el suyo; editar perfiles creativos, hora, zona horaria, idioma y `onboarded_at` | Crear, cambiar `plan` y `target_distance` (lo mueve el feedback con un trigger) |
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
| `spark_jobs`, `subscription_events`, `analytics_outbox` | Nada | Todo |

`consume_credit()` solo la puede ejecutar el service role: si la app pudiera llamarla, alguien podría gastar la cuota de otro usuario. Lo mismo el emparejamiento (`pick_spark_pair`, `create_spark`, `spark_runway_days`), `llm_spend_today`, `invoke_edge_function` y los demás helpers del servidor.

`tests/database/01_rls.sql` verifica cada fila de esta tabla. Incluye una guarda que falla si se crea una tabla en `public` sin RLS. **Toda tabla nueva lleva sus tests de acceso en el mismo cambio.**

## Cuotas

Toda operación que gasta IA pasa primero por `consume_credit(user, kind)`, desde una Edge Function:

- Los límites están en `plan_limits` y se cambian sin publicar versión.
- El plan efectivo sale de `effective_plan()`: `guest` si la sesión es anónima; si no, el `plan` del perfil.
- Los períodos (día y mes) se cuentan en la zona horaria del usuario.
- Si una fila tiene `earned_every`, el cupo se gana: 1 por cada N conceptos guardados en el período, con `max_count` como techo. Es el caso de las chispas extra en free (3 conceptos dan 1, hasta 2 por día).
- El descuento es atómico: el `update ... where used < techo` bloquea la fila, así que llamadas simultáneas no pasan el límite.
- Si la operación falla después de descontar, la Edge Function llama a `refund_credit(user, kind)`.
- La app muestra lo que le queda con `credit_status()`, que devuelve solo los cupos del usuario de la sesión.

| Plan | Captura | Destilación | Chispas extra | Planificador | Plan profundo | Proyectos |
|---|---|---|---|---|---|---|
| guest | 10 por día | — | — | — | — | 1 |
| free | 30 por día | 5 por mes | 2 por día, ganadas | — | — | 1 |
| pro | 200 por día | 300 por mes | 10 por día | 300 por mes | 60 por mes | 1000 ("ilimitados") |

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
| Cupos | `rpc/credit_status`: un registro por cupo (`kind`, `period`, `max_count`, `available`, `used`, `remaining`), incluido `projects` (`period = 'total'`) |
| Bóveda | `concepts` y `categories`: leer (con `category:categories(id,name,domain:domains(slug,name_es,name_en,symbol_ios))`); editar `title`, `thesis`, `status` (confirmar un borrador); borrar. Renombrar y borrar categorías |
| Mover un concepto de categoría | `rpc/move_concept(p_concept, p_category)`: la crea si no existe (límite de 50) y el concepto hereda su dominio |
| Guardar texto sin pasar por la función | `rpc/capture_concept(...)` (sin embedding hasta que corre `/process`; la app usa `/capture`) |
| Chispas | `sparks`: leer; cambiar `status` (`revealed`, `saved`, `discarded`), `feedback` (`obvious`, `irrelevant`, `already_had`) y `project_id`. El feedback mueve la banda del emparejamiento |
| Proyectos | `projects`: leer, renombrar (`name`) y borrar; crear con `rpc/create_project(p_name)` (error `too_many_projects`) |
| Planificador | `planner_messages` y `planner_threads`: leer (los mensajes los escribe `/planner`) |
| Reportes de contenido IA | `content_reports`: insertar `spark_id` o `planner_message_id`, `reason` (`offensive`, `dangerous`, `wrong`, `other`) y `note` (≤ 500). El `user_id` lo pone la base |
| Push | `rpc/register_push_token(p_token, p_platform, p_sandbox)` |
| Cuenta | `rpc/export_my_data()` (JSON con todo, sin embeddings) y `rpc/delete_my_account()` (borra el usuario de auth y todo lo suyo) |
| Biblioteca y dominios | `library_concepts` y `domains`: leer |
| Adjuntos | Storage, bucket privado `capture-temp`: subir a `<user_id>/<uuid>.<ext>` (JPEG, PNG o PDF, hasta 50 MB) y pasar la ruta a `/capture`, que lo borra siempre |

Errores de las RPC (en el mensaje): `not_authenticated`, `invalid_thesis`, `invalid_category`, `invalid_source`, `invalid_request`, `quota_exceeded`, `too_many_categories`, `too_many_projects`, `not_found`.

## Edge Functions

| Función | Quién la llama | Qué hace |
|---|---|---|
| `capture` | App | Guarda (con `capture_concept()` y el JWT del usuario), destila si se pide (cupo `distill`, se devuelve si falla), embebe y clasifica la categoría. Lee y borra el adjunto de `capture-temp` |
| `today` | App | Chispa diaria del día local (la genera si falta), cupo, extras de hoy, días de pares y cantidad de conceptos |
| `spark` | App | Chispa extra (`spark_extra`) o elegida (`pick`, Pro). Devuelve el crédito si no hay par o falla la IA |
| `search` | App | Embebe la consulta y busca con `match_concepts()` (RLS filtra) |
| `planner` | App | Mensaje al planificador (Pro) con respuesta SSE: `delta`, `done`, `error` |
| `dev-plan` | App, solo local | Cambia el plan (404 salvo `LUMBRE_DEV_TOOLS=true`; un invitado primero crea su cuenta) |
| `revenuecat-webhook` | RevenueCat | Plan pro/free por eventos, idempotente por id (`subscription_events`) |
| `process` | pg_cron | Embeddings pendientes (conceptos, dominios, biblioteca), dominio de las categorías y la bandeja de analytics |
| `daily-sparks` | pg_cron | Chispas diarias de quien ya empezó su día; con Anthropic, por la Batches API (`{collect: true}` levanta resultados) |
| `send-pushes` | pg_cron | Push a quien le llegó la hora (APNs); sin claves, loguea y marca `notified_at` |

- Las de la app tienen `verify_jwt = true`; las internas y el webhook validan su propio secreto (clave de servicio o `REVENUECAT_WEBHOOK_SECRET`).
- Variables de entorno: `supabase/.env.example` (bloque de Edge Functions). En local van en `supabase/functions/.env`, que no va al repo; en remoto, `supabase secrets set --env-file supabase/functions/.env`.
- **Invitados:** sin IA de pago. La chispa diaria se les genera igual (es el loop principal) y no consume cupos; con el proveedor local no cuesta nada, con Anthropic cuenta para el tope diario en dólares. `/spark` y `/planner` responden `403 account_required`.
- Eventos de servidor (`docs/analytics.md`, fuente S): `_shared/analytics.ts`. Sin `POSTHOG_API_KEY` se escriben en el log. Los que nacen de escrituras directas de la app (`spark_saved`, `spark_feedback_given`, `concept_deleted`, `project_created`, `data_exported`, `account_deleted`) los deja un trigger en `analytics_outbox` y los manda `/process`. Nunca llevan contenido del usuario.
- Logs: una línea JSON por evento, sin texto de las notas, búsquedas ni mensajes.

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
| `alertas-de-costo` | 03:05 UTC | Guarda en `cost_alerts` los usuarios del día anterior por encima de su tope y el global si pasó el 80% |
| `procesar-pendientes` | cada 5 min | `/process` |
| `chispas-diarias` | cada 15 min | `/daily-sparks` |
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
- Todo es solo service role (para el tablero: SQL Editor o Studio).
