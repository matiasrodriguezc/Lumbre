-- La hora de la próxima chispa y el aviso, coherentes con lo que el usuario ya vio.
--
-- 1. Hoy genera la diaria apenas se abre, aunque todavía no sea la hora elegida. Con la diaria ya hecha,
--    "se recarga" tiene que apuntar a la de mañana: next_spark_at decía "hoy a las 8:00" y a esa hora no llegaba nada.
--    user_clock suma following_spark_at (la hora de la chispa de mañana) y /today la usa cuando ya hay diaria.
-- 2. El aviso solo sale si la chispa sigue por encender: si ya la abrió, "Abrí Lumbre para verla" no tiene sentido.

drop function public.user_clock(uuid);

create function public.user_clock(p_user uuid)
returns table (local_date date, day_started_at timestamptz, spark_due boolean, next_spark_at timestamptz,
               following_spark_at timestamptz, timezone text, plan text)
language sql
stable
security definer
set search_path = ''
as $$
  select d.local_date,
         d.local_date::timestamp at time zone p.timezone as day_started_at,
         (now() at time zone p.timezone)::time >= p.spark_hour as spark_due,
         case when ((d.local_date + p.spark_hour) at time zone p.timezone) > now()
              then (d.local_date + p.spark_hour) at time zone p.timezone
              else ((d.local_date + 1) + p.spark_hour) at time zone p.timezone
         end as next_spark_at,
         ((d.local_date + 1) + p.spark_hour) at time zone p.timezone as following_spark_at,
         p.timezone,
         public.effective_plan(p.id)
  from public.profiles p
  cross join lateral (select (now() at time zone p.timezone)::date as local_date) d
  where p.id = p_user;
$$;
revoke execute on function public.user_clock(uuid) from public, anon, authenticated;
grant execute on function public.user_clock(uuid) to service_role;

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
    and s.status = 'pending'
    and s.notified_at is null
    and s.scheduled_for = (now() at time zone p.timezone)::date
    and (now() at time zone p.timezone)::time >= p.spark_hour
  order by s.created_at
  limit p_limit;
$$;
