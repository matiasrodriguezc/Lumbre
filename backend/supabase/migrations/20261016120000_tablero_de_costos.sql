-- Tablero de costos y alertas (paso 38, plan.md §7 y §13). Amplía 20261009160000_costos.sql.
--
-- - llm_cost_dashboard(días): una fila por día con el total, las llamadas, los errores, los usuarios con IA,
--   el costo por usuario y el costo promedio por chispa, destilación y mensaje del planificador.
-- - llm_cost_month(): el mes en curso contra el objetivo de costo por usuario activo (≤ US$ 0,15).
-- - llm_cost_signals(día): las señales que hay que mirar ese día (topes, chispa cara, muchos errores, modelo sin precio).
-- - backend/scripts/costos.sh imprime todo esto contra la base local o la remota.
-- Los umbrales viven en app_config y se cambian sin publicar versión. Todo es solo service role.

insert into public.app_config (key, value, description) values
  ('spark_target_usd', '0.005', 'Costo objetivo por chispa (compuerta F2). Más que esto en promedio del día es una señal.'),
  ('active_user_month_target_usd', '0.15', 'Costo de IA objetivo por usuario activo mensual (plan.md §13).'),
  ('error_rate_alert', '0.1', 'Proporción de llamadas fallidas del día que dispara una señal.')
on conflict (key) do nothing;

create or replace function public.app_config_number(p_key text)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select (value #>> '{}')::numeric from public.app_config where key = p_key;
$$;

revoke execute on function public.app_config_number(text) from public, anon, authenticated;
grant execute on function public.app_config_number(text) to service_role;

-- ---------------------------------------------------------------
-- Tablero por día
-- ---------------------------------------------------------------
create or replace function public.llm_cost_dashboard(p_days int default 14)
returns table (
  day date,
  cost_usd numeric,
  calls int,
  error_calls int,
  batch_calls int,
  users int,
  usd_per_user numeric,
  sparks int,
  usd_per_spark numeric,
  distills int,
  usd_per_distill numeric,
  planner_messages int,
  usd_per_planner_message numeric,
  embed_usd numeric
)
language sql
stable
security definer
set search_path = ''
as $$
  with days as (
    select generate_series((now() at time zone 'UTC')::date - (greatest(p_days, 1) - 1), (now() at time zone 'UTC')::date, interval '1 day')::date as day
  ),
  calls as (
    select (c.created_at at time zone 'UTC')::date as day, c.*,
           c.feature like '%:error' as failed,
           split_part(c.feature, ':', 1) as base
    from public.llm_calls c
    where c.created_at >= ((now() at time zone 'UTC')::date - (greatest(p_days, 1) - 1))::timestamp at time zone 'UTC'
  )
  select d.day,
         coalesce(sum(c.cost_usd), 0)::numeric(12, 6),
         count(c.id)::int,
         count(c.id) filter (where c.failed)::int,
         count(c.id) filter (where c.batch)::int,
         count(distinct c.user_id)::int,
         round(coalesce(sum(c.cost_usd), 0) / nullif(count(distinct c.user_id), 0), 6),
         count(c.id) filter (where c.base = 'spark' and not c.failed)::int,
         round(sum(c.cost_usd) filter (where c.base = 'spark') / nullif(count(c.id) filter (where c.base = 'spark' and not c.failed), 0), 6),
         count(c.id) filter (where c.base = 'distill' and not c.failed)::int,
         round(sum(c.cost_usd) filter (where c.base = 'distill') / nullif(count(c.id) filter (where c.base = 'distill' and not c.failed), 0), 6),
         count(c.id) filter (where c.base = 'planner' and not c.failed)::int,
         round(sum(c.cost_usd) filter (where c.base in ('planner', 'planner_summary'))
               / nullif(count(c.id) filter (where c.base = 'planner' and not c.failed), 0), 6),
         coalesce(sum(c.cost_usd) filter (where c.base in ('embed', 'search', 'classify')), 0)::numeric(12, 6)
  from days d
  left join calls c on c.day = d.day
  group by d.day
  order by d.day desc;
$$;

comment on function public.llm_cost_dashboard(int) is
  'Tablero de costos de IA por día (UTC): total, llamadas, errores, usuarios y costo por chispa, destilación y mensaje.';

revoke execute on function public.llm_cost_dashboard(int) from public, anon, authenticated;
grant execute on function public.llm_cost_dashboard(int) to service_role;

-- ---------------------------------------------------------------
-- Mes en curso contra el objetivo por usuario activo
-- ---------------------------------------------------------------
-- "Usuario activo" acá es quien generó al menos una llamada de IA en el mes (la chispa diaria cuenta). Es una cota
-- del MAU real de PostHog (que también cuenta a quien solo mira): si da bien acá, da bien allá.
create or replace function public.llm_cost_month()
returns table (month date, cost_usd numeric, users int, usd_per_user numeric, target_usd numeric, over_target boolean)
language sql
stable
security definer
set search_path = ''
as $$
  with m as (
    select coalesce(sum(cost_usd), 0)::numeric(12, 6) as cost, count(distinct user_id)::int as users
    from public.llm_calls
    where created_at >= date_trunc('month', now() at time zone 'UTC') at time zone 'UTC'
  )
  select date_trunc('month', now() at time zone 'UTC')::date, m.cost, m.users,
         round(m.cost / nullif(m.users, 0), 6),
         public.app_config_number('active_user_month_target_usd'),
         coalesce(m.cost / nullif(m.users, 0) > public.app_config_number('active_user_month_target_usd'), false)
  from m;
$$;

revoke execute on function public.llm_cost_month() from public, anon, authenticated;
grant execute on function public.llm_cost_month() to service_role;

-- ---------------------------------------------------------------
-- Señales del día
-- ---------------------------------------------------------------
create or replace function public.llm_cost_signals(p_day date default (now() at time zone 'UTC')::date)
returns table (signal text, detail text, value numeric, threshold numeric)
language sql
stable
security definer
set search_path = ''
as $$
  with calls as (
    select * from public.llm_calls
    where created_at >= (p_day::timestamp at time zone 'UTC') and created_at < ((p_day + 1)::timestamp at time zone 'UTC')
  ),
  agg as (
    select count(*) as n,
           count(*) filter (where feature like '%:error') as failed,
           sum(cost_usd) filter (where split_part(feature, ':', 1) = 'spark') as spark_cost,
           count(*) filter (where feature = 'spark') as sparks
    from calls
  )
  -- Topes en dólares (las mismas filas que guarda el job alertas-de-costo).
  select case a.scope when 'user' then 'user_cap' else 'global_cap' end,
         coalesce(a.user_id::text, 'global'), a.cost_usd, a.cap_usd
  from public.llm_cost_alerts(p_day) a
  union all
  -- Chispa más cara que el objetivo (compuerta F2).
  select 'spark_cost', 'promedio por chispa', round(agg.spark_cost / agg.sparks, 6), public.app_config_number('spark_target_usd')
  from agg
  where agg.sparks > 0 and agg.spark_cost / agg.sparks > public.app_config_number('spark_target_usd')
  union all
  -- Muchas llamadas fallidas: el proveedor anda mal o el modelo de respaldo está trabajando de más.
  select 'error_rate', 'llamadas fallidas', round(agg.failed::numeric / agg.n, 4), public.app_config_number('error_rate_alert')
  from agg
  where agg.n >= 20 and agg.failed::numeric / agg.n > public.app_config_number('error_rate_alert')
  union all
  -- Un modelo de pago con costo 0: falta su precio en _shared/ai/pricing.ts.
  select 'unpriced_model', c.model, count(*)::numeric, 0
  from calls c
  where c.cost_usd = 0 and c.model not like 'local%' and c.model not like 'lumbre-local%'
    and (c.input_tokens > 0 or c.output_tokens > 0)
  group by c.model;
$$;

comment on function public.llm_cost_signals(date) is
  'Señales de costo de un día: topes superados, chispa más cara que el objetivo, tasa de errores y modelos sin precio.';

revoke execute on function public.llm_cost_signals(date) from public, anon, authenticated;
grant execute on function public.llm_cost_signals(date) to service_role;
