-- Temas puente (paso 92, plan.md §4 versión 1.1, flag bridge_topics).
--
-- Si la Red tiene mucho de dos dominios que casi no se cruzaron, Lumbre sugiere 2 o 3 temas para leer que los unan
-- ("bioarte" entre biología y arte). Solo temas: nunca artículos, autores ni links (la IA los inventaría).
--
-- - La detección es SQL, sin LLM: bridge_domain_pair() elige los dos dominios con más neuronas propias
--   (sin borradores, ni las de la biblioteca, ni las que nacieron de una chispa) que casi no aparecieron juntos
--   en una chispa.
-- - Los umbrales viven en app_config y se cambian sin publicar versión (provisorios: 5 neuronas por dominio
--   y como mucho 1 chispa entre los dos).
-- - Solo Pro (decidido el 2026-10-17) y una llamada a la IA por semana como mucho: cupo `bridge_topics` de 1 por
--   semana en plan_limits, así pasa por consume_credit() como toda llamada de IA y dos pedidos simultáneos no pasan
--   el techo. Free e invitado no tienen fila: no tienen cupo.
-- - Va después de 20261017150000_importar_notas.sql, que también redefine plan_limits_kind_check: la lista de acá
--   tiene que incluir la de esa ('import').
-- - La sugerencia de la semana queda en bridge_topics y se devuelve sin volver a llamar a la IA.
-- Todo esto lo usa la Edge Function bridge-topics con service role: la app no ve la tabla ni las funciones.

-- ---------------------------------------------------------------
-- Cupo semanal
-- ---------------------------------------------------------------
alter table public.plan_limits drop constraint plan_limits_kind_check;
alter table public.plan_limits
  add constraint plan_limits_kind_check
  check (kind in ('capture', 'distill', 'spark_extra', 'planner', 'planner_deep', 'projects', 'import', 'bridge_topics'));
alter table public.plan_limits drop constraint plan_limits_period_check;
alter table public.plan_limits
  add constraint plan_limits_period_check check (period in ('day', 'week', 'month', 'total'));

-- La semana arranca el lunes en la zona del usuario (date_trunc('week'), igual que period_start()).
insert into public.plan_limits (plan, kind, period, max_count) values
  ('pro', 'bridge_topics', 'week', 1);

insert into public.app_config (key, value, description) values
  ('bridge_topics_min_concepts', '5', 'Temas puente: neuronas propias que necesita cada uno de los dos dominios.'),
  ('bridge_topics_max_crossings', '1', 'Temas puente: chispas entre los dos dominios a partir de las cuales ya "se cruzaron".')
on conflict (key) do nothing;

-- ---------------------------------------------------------------
-- Sugerencias
-- ---------------------------------------------------------------
create table public.bridge_topics (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  domain_a text not null references public.domains (slug),
  domain_b text not null references public.domains (slug),
  -- [{ "title": "Bioarte", "why": "…" }], de 2 a 3. Validado en la Edge Function: sin links ni obras.
  topics jsonb not null check (jsonb_typeof(topics) = 'array' and jsonb_array_length(topics) between 2 and 3),
  locale text not null check (locale in ('es', 'en')),
  prompt_version text not null,
  model text not null,
  created_at timestamptz not null default now(),
  check (domain_a < domain_b)
);

create index bridge_topics_user_created_idx on public.bridge_topics (user_id, created_at desc);

comment on table public.bridge_topics is
  'Temas para leer que unen dos dominios fuertes y poco cruzados de la Red. Una por semana como mucho. Solo service role.';

alter table public.bridge_topics enable row level security;
revoke all on public.bridge_topics from anon, authenticated;

-- ---------------------------------------------------------------
-- Detección: los dos dominios
-- ---------------------------------------------------------------
-- Entre los 6 dominios con más neuronas (cada uno con al menos bridge_topics_min_concepts), el par con menos de
-- bridge_topics_max_crossings + 1 chispas entre ellos, primero el más parejo y más grande. Sin par, no devuelve filas.
create or replace function public.bridge_domain_pair(p_user uuid)
returns table (domain_a text, domain_b text, concepts_a int, concepts_b int, crossings int)
language sql
stable
security definer
set search_path = ''
as $$
  with settings as (
    select coalesce(public.app_config_number('bridge_topics_min_concepts'), 5)::int as min_concepts,
           coalesce(public.app_config_number('bridge_topics_max_crossings'), 1)::int as max_crossings
  ),
  strong as (
    select c.domain, count(*)::int as n
    from public.concepts c
    where c.user_id = p_user and c.status = 'ready' and not c.from_library and c.source_type <> 'spark'
      and c.domain is not null
    group by c.domain
    having count(*) >= (select min_concepts from settings)
    order by count(*) desc, c.domain
    limit 6
  ),
  crossed as (
    select least(ca.domain, cb.domain) as a, greatest(ca.domain, cb.domain) as b, count(*)::int as n
    from public.sparks s
    join public.concepts ca on ca.id = s.concept_lo
    join public.concepts cb on cb.id = s.concept_hi
    where s.user_id = p_user and ca.domain <> cb.domain
    group by 1, 2
  )
  select a.domain, b.domain, a.n, b.n, coalesce(x.n, 0)
  from strong a
  join strong b on a.domain < b.domain
  left join crossed x on x.a = a.domain and x.b = b.domain
  where coalesce(x.n, 0) <= (select max_crossings from settings)
  order by least(a.n, b.n) desc, a.n + b.n desc, coalesce(x.n, 0), a.domain, b.domain
  limit 1;
$$;

revoke execute on function public.bridge_domain_pair(uuid) from public, anon, authenticated;
grant execute on function public.bridge_domain_pair(uuid) to service_role;

-- ---------------------------------------------------------------
-- La sugerencia de esta semana (en la zona del usuario), si ya la hay
-- ---------------------------------------------------------------
create or replace function public.current_bridge_topics(p_user uuid)
returns setof public.bridge_topics
language sql
stable
security definer
set search_path = ''
as $$
  select t.*
  from public.bridge_topics t
  join public.profiles p on p.id = t.user_id
  where t.user_id = p_user
    and t.created_at >= (public.period_start('week', p.timezone)::timestamp at time zone p.timezone)
  order by t.created_at desc
  limit 1;
$$;

revoke execute on function public.current_bridge_topics(uuid) from public, anon, authenticated;
grant execute on function public.current_bridge_topics(uuid) to service_role;
