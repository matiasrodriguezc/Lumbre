# Backend

Supabase: Postgres 17 + pgvector, RLS, Auth, Edge Functions, pg_cron y pgmq. Todo corre en local con la CLI y Docker; los entornos remotos (dev, staging, prod) se conectan en el paso 41.

## Estructura

| Ruta | Qué es |
|---|---|
| `supabase/config.toml` | Configuración del stack local. Usa los puertos 555xx para convivir con otros proyectos de Supabase. |
| `supabase/migrations/` | El esquema, en orden. Nunca se edita una migración ya aplicada: se agrega una nueva. |
| `supabase/tests/database/` | Tests de pgTAP. Cada archivo crea sus datos en una transacción y la revierte: no dependen del seed. |
| `supabase/seed.sql` | Datos de prueba solo para local: usuarios A y B, dominios provisorios, conceptos y chispas iguales a los de la app de iOS. |

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

Revisar el esquema:

```bash
cd backend && supabase db lint --local
```

Frenar el stack:

```bash
cd backend && supabase stop
```

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
