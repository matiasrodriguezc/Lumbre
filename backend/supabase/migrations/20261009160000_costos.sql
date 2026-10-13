-- Costos de IA (paso 38): topes diarios en dólares, tablero y alertas. Todo solo service role.

-- ---------------------------------------------------------------
-- Configuración del servidor
-- ---------------------------------------------------------------
-- Valores que se cambian sin publicar versión. La lee el gateway de IA de las Edge Functions.
create table public.app_config (
  key text primary key,
  value jsonb not null,
  description text,
  updated_at timestamptz not null default now()
);

alter table public.app_config enable row level security;
revoke all on public.app_config from anon, authenticated;

insert into public.app_config (key, value, description) values
  ('user_daily_usd_cap', '0.05', 'Tope de gasto de IA por usuario y por día (UTC), en dólares.'),
  ('global_daily_usd_cap', '20', 'Tope de gasto de IA de todo Lumbre por día (UTC), en dólares.');

-- ---------------------------------------------------------------
-- Gasto del día, para que el gateway corte antes de pasarse
-- ---------------------------------------------------------------
create index llm_calls_user_day_idx on public.llm_calls (user_id, created_at);

create or replace function public.llm_spend_today(p_user uuid)
returns table (user_usd numeric, global_usd numeric, user_cap numeric, global_cap numeric)
language sql
stable
security definer
set search_path = ''
as $$
  select
    coalesce((select sum(cost_usd) from public.llm_calls
               where user_id = p_user and created_at >= date_trunc('day', now())), 0),
    coalesce((select sum(cost_usd) from public.llm_calls where created_at >= date_trunc('day', now())), 0),
    (select (value #>> '{}')::numeric from public.app_config where key = 'user_daily_usd_cap'),
    (select (value #>> '{}')::numeric from public.app_config where key = 'global_daily_usd_cap');
$$;

revoke execute on function public.llm_spend_today(uuid) from public, anon, authenticated;
grant execute on function public.llm_spend_today(uuid) to service_role;

-- ---------------------------------------------------------------
-- Tablero: costo por día, función y modelo
-- ---------------------------------------------------------------
create view public.llm_cost_daily with (security_invoker = true) as
select
  (created_at at time zone 'UTC')::date as day,
  feature,
  model,
  count(*)::int as calls,
  count(*) filter (where batch)::int as batch_calls,
  coalesce(sum(input_tokens), 0)::bigint as input_tokens,
  coalesce(sum(cached_tokens), 0)::bigint as cached_tokens,
  coalesce(sum(output_tokens), 0)::bigint as output_tokens,
  coalesce(sum(cost_usd), 0)::numeric(12, 6) as cost_usd,
  round(avg(latency_ms))::int as avg_latency_ms
from public.llm_calls
group by 1, 2, 3;

revoke all on public.llm_cost_daily from anon, authenticated;

-- ---------------------------------------------------------------
-- Alertas: usuarios del día por encima de su tope y el total global
-- ---------------------------------------------------------------
create or replace function public.llm_cost_alerts(p_day date default (now() at time zone 'UTC')::date)
returns table (day date, scope text, user_id uuid, cost_usd numeric, cap_usd numeric)
language sql
stable
security definer
set search_path = ''
as $$
  with caps as (
    select (select (value #>> '{}')::numeric from public.app_config where key = 'user_daily_usd_cap') as user_cap,
           (select (value #>> '{}')::numeric from public.app_config where key = 'global_daily_usd_cap') as global_cap
  ),
  calls as (
    select * from public.llm_calls
    where created_at >= (p_day::timestamp at time zone 'UTC')
      and created_at < ((p_day + 1)::timestamp at time zone 'UTC')
  )
  select p_day, 'user', c.user_id, sum(c.cost_usd), caps.user_cap
  from calls c, caps
  where c.user_id is not null
  group by c.user_id, caps.user_cap
  having sum(c.cost_usd) > caps.user_cap
  union all
  select p_day, 'global', null, coalesce(sum(c.cost_usd), 0), caps.global_cap
  from calls c, caps
  group by caps.global_cap
  having coalesce(sum(c.cost_usd), 0) > caps.global_cap * 0.8;
$$;

comment on function public.llm_cost_alerts(date) is
  'Usuarios por encima de su tope diario y el total global si pasó el 80% del suyo, para un día (UTC).';

revoke execute on function public.llm_cost_alerts(date) from public, anon, authenticated;
grant execute on function public.llm_cost_alerts(date) to service_role;

create table public.cost_alerts (
  id bigint generated always as identity primary key,
  day date not null,
  scope text not null check (scope in ('user', 'global')),
  user_id uuid references auth.users on delete set null,
  cost_usd numeric(12, 6) not null,
  cap_usd numeric(12, 6),
  created_at timestamptz not null default now(),
  unique nulls not distinct (day, scope, user_id)
);

create index cost_alerts_user_idx on public.cost_alerts (user_id);

alter table public.cost_alerts enable row level security;
revoke all on public.cost_alerts from anon, authenticated;

create or replace function public.record_cost_alerts(p_day date default (now() at time zone 'UTC')::date - 1)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count int;
begin
  insert into public.cost_alerts (day, scope, user_id, cost_usd, cap_usd)
  select a.day, a.scope, a.user_id, a.cost_usd, a.cap_usd from public.llm_cost_alerts(p_day) a
  on conflict (day, scope, user_id) do update set cost_usd = excluded.cost_usd, cap_usd = excluded.cap_usd;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke execute on function public.record_cost_alerts(date) from public, anon, authenticated;
grant execute on function public.record_cost_alerts(date) to service_role;

-- Todos los días a las 03:05 UTC, con el día anterior cerrado.
select cron.schedule('alertas-de-costo', '5 3 * * *', $$ select public.record_cost_alerts() $$);
