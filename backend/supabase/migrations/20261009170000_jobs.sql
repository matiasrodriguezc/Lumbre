-- Trabajos del servidor: batch nocturno de chispas, push, webhook de RevenueCat y crons hacia las Edge Functions.

-- ---------------------------------------------------------------
-- Batch nocturno (paso 32)
-- ---------------------------------------------------------------
-- Con Anthropic, la chispa diaria se pide por la Batches API (50% menos) y se levanta después.
-- El par ya está elegido y reservado (last_used_at) cuando se manda el batch.
create table public.spark_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  scheduled_for date not null,
  concept_lo uuid not null references public.concepts (id) on delete cascade,
  concept_hi uuid not null references public.concepts (id) on delete cascade,
  distance real,
  distance_percentile smallint,
  uses_library boolean not null default false,
  -- Id del batch de Anthropic. Null mientras no se mandó.
  batch_id text,
  status text not null default 'pending' check (status in ('pending', 'submitted', 'done', 'failed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, scheduled_for)
);

create index spark_jobs_status_idx on public.spark_jobs (status, batch_id);
create index spark_jobs_lo_idx on public.spark_jobs (concept_lo);
create index spark_jobs_hi_idx on public.spark_jobs (concept_hi);

alter table public.spark_jobs enable row level security;
revoke all on public.spark_jobs from anon, authenticated;

-- Usuarios cuyo día local ya empezó y todavía no tienen chispa diaria (ni un batch en curso),
-- con al menos un concepto listo para emparejar.
create or replace function public.users_needing_daily_spark(p_limit int default 200)
returns table (user_id uuid, local_date date)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, d.local_date
  from public.profiles p
  cross join lateral (select (now() at time zone p.timezone)::date as local_date) d
  where not exists (select 1 from public.sparks s
                     where s.user_id = p.id and s.mode = 'daily' and s.scheduled_for = d.local_date)
    and not exists (select 1 from public.spark_jobs j
                     where j.user_id = p.id and j.scheduled_for = d.local_date and j.status in ('pending', 'submitted'))
    and exists (select 1 from public.concepts c
                 where c.user_id = p.id and c.status = 'ready' and c.embedding is not null)
  order by p.id
  limit p_limit;
$$;

revoke execute on function public.users_needing_daily_spark(int) from public, anon, authenticated;
grant execute on function public.users_needing_daily_spark(int) to service_role;

-- ---------------------------------------------------------------
-- Push de la chispa diaria
-- ---------------------------------------------------------------
-- Chispas diarias de hoy cuya hora local ya llegó y que todavía no se avisaron.
create or replace function public.due_spark_pushes(p_limit int default 500)
returns table (spark_id uuid, user_id uuid, spark_hour time, locale text)
language sql
stable
security definer
set search_path = ''
as $$
  select s.id, s.user_id, p.spark_hour, p.locale
  from public.sparks s
  join public.profiles p on p.id = s.user_id
  where s.mode = 'daily'
    and s.notified_at is null
    and s.scheduled_for = (now() at time zone p.timezone)::date
    and (now() at time zone p.timezone)::time >= p.spark_hour
  order by s.created_at
  limit p_limit;
$$;

revoke execute on function public.due_spark_pushes(int) from public, anon, authenticated;
grant execute on function public.due_spark_pushes(int) to service_role;

create index sparks_unnotified_idx on public.sparks (scheduled_for) where mode = 'daily' and notified_at is null;

-- ---------------------------------------------------------------
-- Webhook de RevenueCat (paso 36)
-- ---------------------------------------------------------------
-- Cada evento se procesa una sola vez por su id. No se guarda el cuerpo completo: solo lo necesario.
create table public.subscription_events (
  id text primary key,
  type text not null,
  app_user_id text,
  -- Plan que quedó después del evento (null si no cambió nada).
  plan_after text check (plan_after in ('free', 'pro')),
  received_at timestamptz not null default now()
);

alter table public.subscription_events enable row level security;
revoke all on public.subscription_events from anon, authenticated;

-- ---------------------------------------------------------------
-- Crons hacia las Edge Functions (pg_net + Vault)
-- ---------------------------------------------------------------
-- La URL de las funciones y la clave de servicio viven en Vault, no en el código:
--   lumbre_functions_url   https://<ref>.supabase.co/functions/v1   (en local la carga seed.sql)
--   lumbre_service_key     la clave de servicio del proyecto
-- Sin secretos cargados, invoke_edge_function() no hace nada (y lo avisa con un notice).
create extension if not exists pg_net with schema extensions;

create or replace function public.invoke_edge_function(p_path text, p_body jsonb default '{}')
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text;
  v_key text;
begin
  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'lumbre_functions_url';
  select decrypted_secret into v_key from vault.decrypted_secrets where name = 'lumbre_service_key';
  if v_url is null or v_key is null then
    raise notice 'invoke_edge_function: faltan lumbre_functions_url o lumbre_service_key en Vault';
    return null;
  end if;

  return net.http_post(
    url := rtrim(v_url, '/') || p_path,
    body := coalesce(p_body, '{}'),
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_key),
    timeout_milliseconds := 60000
  );
end;
$$;

revoke execute on function public.invoke_edge_function(text, jsonb) from public, anon, authenticated;
grant execute on function public.invoke_edge_function(text, jsonb) to service_role;

-- Embeddings y dominios pendientes, y la bandeja de eventos.
select cron.schedule('procesar-pendientes', '*/5 * * * *', $$ select public.invoke_edge_function('/process') $$);
-- Chispas diarias de los usuarios cuyo día local ya empezó.
select cron.schedule('chispas-diarias', '*/15 * * * *', $$ select public.invoke_edge_function('/daily-sparks') $$);
-- Resultados de los batches de Anthropic.
select cron.schedule('chispas-diarias-resultados', '*/10 * * * *',
  $$ select public.invoke_edge_function('/daily-sparks', '{"collect": true}') $$);
-- Push a quien le llegó la hora de su chispa.
select cron.schedule('enviar-pushes', '*/5 * * * *', $$ select public.invoke_edge_function('/send-pushes') $$);
