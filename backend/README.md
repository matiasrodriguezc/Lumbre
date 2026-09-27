# Backend

Supabase: Postgres 17 + pgvector, RLS, Auth, Edge Functions, pg_cron y pgmq. Todo corre en local con la CLI y Docker; los entornos remotos (dev, staging, prod) se conectan en el paso 41.

## Estructura

| Ruta | Qué es |
|---|---|
| `supabase/config.toml` | Configuración del stack local. Usa los puertos 555xx para convivir con otros proyectos de Supabase. |
| `supabase/migrations/` | El esquema, en orden. Nunca se edita una migración ya aplicada: se agrega una nueva. |
| `supabase/tests/database/` | Tests de pgTAP. Cada archivo crea sus datos en una transacción y la revierte: no dependen del seed. |
| `supabase/tests/concurrency/` | Pruebas que necesitan varias conexiones a la vez (no entran en pgTAP). |
| `supabase/seed.sql` | Datos de prueba solo para local: usuarios A y B, dominios provisorios, conceptos y chispas iguales a los de la app de iOS. |

## CI

`.github/workflows/backend.yml` corre en cada PR y en cada push a `main` que toque `backend/`: levanta Postgres con las migraciones desde cero y el seed, pasa el lint, corre los tests de pgTAP y la prueba de concurrencia. Si falla, no se mergea.

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
| `profiles` | Leer el suyo; editar perfiles creativos, hora, zona horaria e idioma | Crear, cambiar `plan` y `target_distance` |
| `concepts` | Leer, corregir título, tesis, dominio y estado, y borrar los suyos | Crear (pasa por el endpoint de captura, con límite y embedding) |
| `sparks` | Leer las suyas; cambiar `status` y `feedback` | Crear y escribir el contenido |
| `usage_ledger` | Leer el suyo | Descontar, con `consume_credit()` |
| `domains`, `plan_limits` | Leer (también sin sesión) | Escribir |
| `llm_calls` | Nada | Todo |

`consume_credit()` solo la puede ejecutar el service role: si la app pudiera llamarla, alguien podría gastar la cuota de otro usuario.

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

| Plan | Captura | Destilación | Chispas extra | Planificador | Plan profundo |
|---|---|---|---|---|---|
| guest | 10 por día | — | — | — | — |
| free | 30 por día | 5 por mes | 2 por día, ganadas | — | — |
| pro | 200 por día | 300 por mes | 10 por día | 300 por mes | 60 por mes |

Los de `guest` son provisorios hasta que el prototipo defina qué puede hacer un invitado (paso 14).
