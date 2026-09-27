-- Cuotas: cupos ganados, plan de invitado, devolución y estado para la app.

-- ---------------------------------------------------------------
-- Cupos que se ganan
-- ---------------------------------------------------------------
-- "Guardar 3 conceptos nuevos da 1 chispa extra, hasta 2 extra por día" (plan.md §4).
-- Si earned_every no es null, el cupo del período es 1 por cada earned_every conceptos
-- guardados en ese período (sin contar los de la biblioteca), con max_count como techo.
alter table public.plan_limits
  add column earned_every int check (earned_every > 0);

comment on column public.plan_limits.earned_every is
  'Si no es null, el cupo se gana: 1 por cada N conceptos guardados en el período, hasta max_count.';

update public.plan_limits set earned_every = 3 where plan = 'free' and kind = 'spark_extra';

-- ---------------------------------------------------------------
-- Plan de invitado
-- ---------------------------------------------------------------
-- El plan efectivo de un usuario con sesión anónima es 'guest', sin importar profiles.plan.
-- Así, cuando el invitado crea su cuenta, pasa a free solo, sin sincronizar nada.
-- Límites provisorios y bajos: las sesiones anónimas se crean gratis y se prestan al abuso.
-- Se ajustan cuando el prototipo defina qué puede hacer un invitado (paso 14).
alter table public.plan_limits
  add constraint plan_limits_plan_check check (plan in ('guest', 'free', 'pro'));

insert into public.plan_limits (plan, kind, period, max_count) values
  ('guest', 'capture', 'day', 10);

create or replace function public.effective_plan(p_user uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case when u.is_anonymous then 'guest' else coalesce(p.plan, 'free') end
  from auth.users u
  left join public.profiles p on p.id = u.id
  where u.id = p_user;
$$;

revoke execute on function public.effective_plan(uuid) from public, anon, authenticated;
grant execute on function public.effective_plan(uuid) to service_role;

-- Inicio del período en la zona horaria del usuario, como fecha local y como instante.
create or replace function public.period_start(p_period text, p_timezone text)
returns date
language sql
stable
set search_path = ''
as $$
  select date_trunc(p_period, now() at time zone p_timezone)::date;
$$;

-- Conceptos guardados por el usuario desde el inicio del período (sin los de la biblioteca).
create or replace function public.concepts_saved_since(p_user uuid, p_start date, p_timezone text)
returns int
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::int
  from public.concepts
  where user_id = p_user
    and not from_library
    and created_at >= (p_start::timestamp at time zone p_timezone);
$$;

revoke execute on function public.concepts_saved_since(uuid, date, text) from public, anon, authenticated;
grant execute on function public.concepts_saved_since(uuid, date, text) to service_role;

-- ---------------------------------------------------------------
-- consume_credit: ahora con plan efectivo y cupos ganados
-- ---------------------------------------------------------------
create or replace function public.consume_credit(p_user uuid, p_kind text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_plan text;
  v_tz text;
  r record;
  v_start date;
  v_cap int;
  v_ok int;
  v_found boolean := false;
begin
  v_plan := public.effective_plan(p_user);
  select timezone into v_tz from public.profiles where id = p_user;
  if v_plan is null or v_tz is null then
    -- Usuario inexistente o sin perfil: no hay cupo.
    return false;
  end if;

  for r in
    select period, max_count, earned_every
    from public.plan_limits
    where plan = v_plan and kind = p_kind
  loop
    v_found := true;
    v_start := public.period_start(r.period, v_tz);
    v_cap := r.max_count;
    if r.earned_every is not null then
      v_cap := least(v_cap, public.concepts_saved_since(p_user, v_start, v_tz) / r.earned_every);
    end if;

    insert into public.usage_ledger (user_id, kind, period, period_start)
    values (p_user, p_kind, r.period, v_start)
    on conflict do nothing;

    -- El update toma el lock de la fila: dos llamadas simultáneas no pueden pasar el techo.
    v_ok := null;
    update public.usage_ledger
       set used = used + 1
     where user_id = p_user and kind = p_kind and period = r.period
       and period_start = v_start and used < v_cap
    returning 1 into v_ok;

    if v_ok is null then
      raise exception 'quota_exceeded';
    end if;
  end loop;

  return v_found;
exception when raise_exception then
  -- El bloque con excepción revierte los descuentos hechos en este llamado.
  return false;
end;
$$;

-- ---------------------------------------------------------------
-- refund_credit: devuelve un crédito si la operación falló después de descontarlo
-- ---------------------------------------------------------------
create or replace function public.refund_credit(p_user uuid, p_kind text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tz text;
  v_count int;
begin
  select timezone into v_tz from public.profiles where id = p_user;
  if v_tz is null then
    return false;
  end if;

  update public.usage_ledger l
     set used = used - 1
   where l.user_id = p_user and l.kind = p_kind and l.used > 0
     and l.period_start = public.period_start(l.period, v_tz);
  get diagnostics v_count = row_count;
  return v_count > 0;
end;
$$;

revoke execute on function public.refund_credit(uuid, text) from public, anon, authenticated;
grant execute on function public.refund_credit(uuid, text) to service_role;

-- ---------------------------------------------------------------
-- credit_status: cuánto le queda al usuario de la sesión, para mostrarlo en la app
-- ---------------------------------------------------------------
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
  )
  select c.kind, c.period, c.max_count, c.cap as available,
         coalesce(u.used, 0) as used,
         greatest(c.cap - coalesce(u.used, 0), 0) as remaining
  from caps c
  left join public.usage_ledger u
    on u.user_id = c.user_id and u.kind = c.kind and u.period = c.period and u.period_start = c.start
  order by c.kind, c.period;
$$;

revoke execute on function public.credit_status() from public, anon;
grant execute on function public.credit_status() to authenticated, service_role;
