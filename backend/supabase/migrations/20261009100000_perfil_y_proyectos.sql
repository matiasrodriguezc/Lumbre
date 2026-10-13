-- Perfil (onboarding y banda del emparejamiento), proyectos, push y lo que la app escribe directo en las chispas.

-- ---------------------------------------------------------------
-- Perfil
-- ---------------------------------------------------------------
-- La app marca el fin del onboarding.
alter table public.profiles add column onboarded_at timestamptz;
grant update (onboarded_at) on public.profiles to authenticated;

-- target_distance pasa a ser el centro de la banda de percentiles del emparejamiento (plan.md §5):
-- 0,6 = percentil 60 de las distancias del propio usuario, con ±0,2 de banda (40–80).
update public.profiles set target_distance = 0.6 where target_distance is null;
alter table public.profiles
  alter column target_distance set default 0.6,
  alter column target_distance set not null,
  add constraint profiles_target_distance_range check (target_distance between 0.35::real and 0.85::real);

comment on column public.profiles.target_distance is
  'Centro de la banda de percentiles del emparejamiento (0,6 = percentil 60, banda ±0,2). Lo mueve el feedback de las chispas.';

-- ---------------------------------------------------------------
-- Chispas: datos para analytics y push
-- ---------------------------------------------------------------
alter table public.sparks
  -- Percentil de la distancia del par entre las del usuario (0–100), para calibrar la banda.
  add column distance_percentile smallint check (distance_percentile between 0 and 100),
  -- Uno de los dos conceptos vino de la biblioteca de conceptos invitados.
  add column uses_library boolean not null default false,
  -- Cuándo salió la push de la chispa diaria. Null: todavía no se avisó.
  add column notified_at timestamptz;

-- Una sola chispa diaria por usuario y día: el batch nocturno y Hoy pueden intentar crearla a la vez.
create unique index sparks_one_daily_idx on public.sparks (user_id, scheduled_for) where mode = 'daily';

-- ---------------------------------------------------------------
-- El feedback mueve la banda
-- ---------------------------------------------------------------
-- "Obvia" pide pares más lejanos; "irrelevante", más cercanos; "ya la tuve" no dice nada de la distancia.
-- Si el usuario cambia de motivo, se deshace el anterior. El centro queda entre 0,35 y 0,85.
create or replace function public.feedback_delta(p_feedback text)
returns real
language sql
immutable
set search_path = ''
as $$
  select case p_feedback when 'obvious' then 0.03 when 'irrelevant' then -0.03 else 0 end::real;
$$;

create or replace function public.sparks_feedback_moves_band()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_delta real := public.feedback_delta(new.feedback) - public.feedback_delta(old.feedback);
begin
  if v_delta <> 0 then
    update public.profiles
       set target_distance = least(0.85::real, greatest(0.35::real, target_distance + v_delta))
     where id = new.user_id;
  end if;
  return new;
end;
$$;

revoke execute on function public.sparks_feedback_moves_band() from public, anon, authenticated;

create trigger sparks_feedback_band
  after update of feedback on public.sparks
  for each row when (new.feedback is distinct from old.feedback)
  execute function public.sparks_feedback_moves_band();

-- ---------------------------------------------------------------
-- Proyectos (1.0: una lista simple; el tablero llega en 1.1)
-- ---------------------------------------------------------------
create table public.projects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 60),
  created_at timestamptz not null default now(),
  -- Para que una chispa solo pueda ir a un proyecto de su mismo usuario.
  unique (id, user_id)
);

create index projects_user_idx on public.projects (user_id, created_at desc);

comment on table public.projects is 'Proyectos del usuario. Se crean con create_project(), que respeta el límite del plan.';

alter table public.sparks add column project_id uuid;
alter table public.sparks
  add constraint sparks_project_same_user
  foreign key (project_id, user_id) references public.projects (id, user_id)
  on delete set null (project_id);
create index sparks_project_idx on public.sparks (project_id);

alter table public.projects enable row level security;

create policy "projects: leer los propios" on public.projects
  for select to authenticated using (user_id = (select auth.uid()));
create policy "projects: renombrar los propios" on public.projects
  for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "projects: borrar los propios" on public.projects
  for delete to authenticated using (user_id = (select auth.uid()));
revoke all on public.projects from anon;
revoke insert, update on public.projects from authenticated;
grant update (name) on public.projects to authenticated;

-- La chispa guardada puede ir a un proyecto propio (la foreign key compuesta impide usar uno ajeno).
grant update (project_id) on public.sparks to authenticated;

-- ---------------------------------------------------------------
-- Límite de proyectos en plan_limits
-- ---------------------------------------------------------------
-- Un cupo 'total' no se renueva: se cuenta lo que existe. Pro tiene 1000 como techo de abuso ("ilimitados").
alter table public.plan_limits drop constraint plan_limits_kind_check;
alter table public.plan_limits
  add constraint plan_limits_kind_check
  check (kind in ('capture', 'distill', 'spark_extra', 'planner', 'planner_deep', 'projects'));
alter table public.plan_limits drop constraint plan_limits_period_check;
alter table public.plan_limits
  add constraint plan_limits_period_check check (period in ('day', 'month', 'total'));

insert into public.plan_limits (plan, kind, period, max_count) values
  ('guest', 'projects', 'total', 1),
  ('free', 'projects', 'total', 1),
  ('pro', 'projects', 'total', 1000);

-- Un período 'total' arranca en el origen. Así consume_credit() y refund_credit() no fallan con él,
-- aunque los proyectos no pasan por ellas: se cuentan las filas.
create or replace function public.period_start(p_period text, p_timezone text)
returns date
language sql
stable
set search_path = ''
as $$
  select case when p_period = 'total' then date '1970-01-01'
              else date_trunc(p_period, now() at time zone p_timezone)::date end;
$$;

-- Crear un proyecto. Errores: not_authenticated · invalid_request · too_many_projects
create or replace function public.create_project(p_name text)
returns public.projects
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_name text := regexp_replace(trim(coalesce(p_name, '')), '\s+', ' ', 'g');
  v_max int;
  v_project public.projects;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if char_length(v_name) not between 1 and 60 then
    raise exception 'invalid_request' using errcode = '22023';
  end if;

  -- El lock del perfil serializa dos altas simultáneas del mismo usuario.
  perform 1 from public.profiles where id = v_user for update;
  select max_count into v_max from public.plan_limits
   where plan = public.effective_plan(v_user) and kind = 'projects' and period = 'total';
  if coalesce(v_max, 0) <= (select count(*) from public.projects where user_id = v_user) then
    raise exception 'too_many_projects' using errcode = 'P0001';
  end if;

  insert into public.projects (user_id, name) values (v_user, v_name) returning * into v_project;
  return v_project;
end;
$$;

revoke execute on function public.create_project(text) from public, anon;
grant execute on function public.create_project(text) to authenticated;

-- credit_status: suma el cupo de proyectos (remaining = máximo − proyectos actuales).
create or replace function public.credit_status()
returns table (kind text, period text, max_count int, available int, used int, remaining int)
language sql
stable
security definer
set search_path = ''
as $$
  with me as (
    select u.id, public.effective_plan(u.id) as plan, p.timezone
    from auth.users u
    join public.profiles p on p.id = u.id
    where u.id = (select auth.uid())
  ),
  limits as (
    select l.kind, l.period, l.max_count, l.earned_every,
           public.period_start(l.period, me.timezone) as start, me.id as user_id, me.timezone
    from public.plan_limits l
    join me on me.plan = l.plan
  ),
  caps as (
    select limits.*,
           case when earned_every is null then max_count
                else least(max_count, public.concepts_saved_since(user_id, start, timezone) / earned_every)
           end as cap
    from limits
  ),
  usage as (
    select c.*,
           case when c.kind = 'projects'
                then (select count(*)::int from public.projects p where p.user_id = c.user_id)
                else coalesce((select u.used from public.usage_ledger u
                                where u.user_id = c.user_id and u.kind = c.kind
                                  and u.period = c.period and u.period_start = c.start), 0)
           end as used
    from caps c
  )
  select kind, period, max_count, cap as available, used, greatest(cap - used, 0) as remaining
  from usage
  order by kind, period;
$$;

-- ---------------------------------------------------------------
-- Tokens de push
-- ---------------------------------------------------------------
-- El token identifica al dispositivo: si otro usuario entra en el mismo teléfono, el token pasa a él.
create table public.push_tokens (
  token text primary key check (char_length(token) between 1 and 512),
  user_id uuid not null references auth.users on delete cascade,
  platform text not null check (platform in ('ios', 'android')),
  -- APNs de desarrollo (builds de Xcode) o de producción (TestFlight y App Store).
  sandbox boolean not null default false,
  updated_at timestamptz not null default now()
);

create index push_tokens_user_idx on public.push_tokens (user_id);

alter table public.push_tokens enable row level security;
create policy "push_tokens: leer los propios" on public.push_tokens
  for select to authenticated using (user_id = (select auth.uid()));
create policy "push_tokens: borrar los propios" on public.push_tokens
  for delete to authenticated using (user_id = (select auth.uid()));
revoke all on public.push_tokens from anon;
revoke insert, update on public.push_tokens from authenticated;

-- Errores: not_authenticated · invalid_request
create or replace function public.register_push_token(p_token text, p_platform text, p_sandbox boolean default false)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if char_length(coalesce(trim(p_token), '')) not between 1 and 512 or p_platform not in ('ios', 'android') then
    raise exception 'invalid_request' using errcode = '22023';
  end if;

  insert into public.push_tokens (token, user_id, platform, sandbox, updated_at)
  values (trim(p_token), v_user, p_platform, coalesce(p_sandbox, false), now())
  on conflict (token) do update
    set user_id = excluded.user_id, platform = excluded.platform,
        sandbox = excluded.sandbox, updated_at = now();
end;
$$;

revoke execute on function public.register_push_token(text, text, boolean) from public, anon;
grant execute on function public.register_push_token(text, text, boolean) to authenticated;

-- ---------------------------------------------------------------
-- Mover un concepto a otra categoría (la crea si no existe)
-- ---------------------------------------------------------------
-- La app no puede escribir category_id directo: la categoría nueva cuenta para el límite de 50
-- y el concepto hereda su dominio. Errores: not_authenticated · not_found · invalid_category · too_many_categories
create or replace function public.move_concept(p_concept uuid, p_category text)
returns table (category_id uuid, category_created boolean)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_user uuid := auth.uid();
  v_name text := regexp_replace(trim(coalesce(p_category, '')), '\s+', ' ', 'g');
  v_category public.categories;
  v_created boolean := false;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if not exists (select 1 from public.concepts c where c.id = p_concept and c.user_id = v_user) then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  if char_length(v_name) not between 1 and 40 then
    raise exception 'invalid_category' using errcode = '22023';
  end if;

  select * into v_category from public.categories c
   where c.user_id = v_user and c.normalized = public.normalize_category(v_name);
  if not found then
    if (select count(*) from public.categories c where c.user_id = v_user) >= 50 then
      raise exception 'too_many_categories' using errcode = 'P0001';
    end if;
    insert into public.categories (user_id, name) values (v_user, v_name) returning * into v_category;
    v_created := true;
  end if;

  update public.concepts c
     set category_id = v_category.id, domain = v_category.domain, domain_confirmed = true
   where c.id = p_concept;

  return query select v_category.id, v_created;
end;
$$;

revoke execute on function public.move_concept(uuid, text) from public, anon;
grant execute on function public.move_concept(uuid, text) to authenticated;
