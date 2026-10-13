-- Emparejamiento (paso 28, plan.md §5): SQL, sin LLM y sin costo de tokens.
--
-- - Pares de dominios distintos. Si un concepto todavía no tiene dominio, cuenta su categoría:
--   coalesce(domain, 'cat:' || category_id). Así, antes de clasificar, se cruzan categorías distintas.
-- - Banda media relativa a cada usuario: percentiles de sus propias distancias, con centro en
--   profiles.target_distance (0,6 por defecto) ± 0,2. El feedback mueve el centro.
-- - El par nunca se repite (sparks guarda lo < hi con unique) y cada concepto descansa 3 días.
-- - De los 20 pares más cerca del centro se elige uno al azar, pesando la novedad: conceptos nuevos y poco usados.
-- - Respaldo: un concepto del usuario con uno de la biblioteca de conceptos invitados (paso 31).
-- - Solo se miran los 300 conceptos más recientes, para acotar los n² pares.
-- Todo esto lo llaman las Edge Functions con service role: la app no ve estas funciones.

-- ---------------------------------------------------------------
-- Todos los pares posibles del usuario, con su distancia y su percentil
-- ---------------------------------------------------------------
create or replace function public.spark_pairs(p_user uuid)
returns table (lo uuid, hi uuid, distance real, percentile real, rested boolean, used boolean, novelty real)
language sql
stable
security definer
set search_path = ''
as $$
  with mine as (
    select c.id, c.embedding, c.embedding_model,
           coalesce(c.domain, 'cat:' || c.category_id::text) as dom,
           coalesce(c.last_used_at, '-infinity'::timestamptz) < now() - interval '3 days' as rested,
           extract(epoch from now() - c.created_at) / 86400.0 as age_days,
           (select count(*) from public.sparks s
             where s.user_id = c.user_id and (s.concept_lo = c.id or s.concept_hi = c.id)) as uses
    from public.concepts c
    where c.user_id = p_user
      and c.status = 'ready'
      and c.embedding is not null
      and (c.domain is not null or c.category_id is not null)
    order by c.created_at desc
    limit 300
  ),
  pairs as (
    select a.id as lo, b.id as hi,
           (a.embedding operator(extensions.<=>) b.embedding)::real as distance,
           a.rested and b.rested as rested,
           exists (select 1 from public.sparks s
                    where s.user_id = p_user and s.concept_lo = a.id and s.concept_hi = b.id) as used,
           -- Novedad: 1 sin usos y bajando con cada aparición; los conceptos de la última semana pesan hasta el doble.
           ((2.0 / (2 + a.uses + b.uses))
             * (1 + 0.5 * (exp(-a.age_days / 7.0) + exp(-b.age_days / 7.0))))::real as novelty
    from mine a
    join mine b on a.id < b.id and a.dom <> b.dom and a.embedding_model = b.embedding_model
  )
  select lo, hi, distance, (percent_rank() over (order by distance))::real as percentile, rested, used, novelty
  from pairs;
$$;

revoke execute on function public.spark_pairs(uuid) from public, anon, authenticated;
grant execute on function public.spark_pairs(uuid) to service_role;

-- ---------------------------------------------------------------
-- Copia un concepto de la biblioteca a la bóveda del usuario
-- ---------------------------------------------------------------
-- Va a la categoría del usuario con el nombre del dominio en español (la crea si no existe y hay lugar).
create or replace function public.copy_library_concept(p_user uuid, p_library uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lib public.library_concepts;
  v_name text;
  v_category uuid;
  v_concept uuid;
begin
  select * into v_lib from public.library_concepts where id = p_library;
  if not found then
    return null;
  end if;
  select name_es into v_name from public.domains where slug = v_lib.domain;

  select id into v_category from public.categories
   where user_id = p_user and normalized = public.normalize_category(v_name);
  if v_category is null and (select count(*) from public.categories where user_id = p_user) < 50 then
    insert into public.categories (user_id, name, domain) values (p_user, v_name, v_lib.domain)
    returning id into v_category;
  end if;

  insert into public.concepts (
    user_id, category_id, domain, domain_confirmed, title, thesis, principle, embedding, embedding_model,
    distilled, confidence, status, source_type, from_library, library_id
  ) values (
    p_user, v_category, v_lib.domain, true, v_lib.title, v_lib.thesis, v_lib.principle, v_lib.embedding,
    v_lib.embedding_model, true, 'high', 'ready', 'text', true, v_lib.id
  )
  returning id into v_concept;
  return v_concept;
end;
$$;

revoke execute on function public.copy_library_concept(uuid, uuid) from public, anon, authenticated;
grant execute on function public.copy_library_concept(uuid, uuid) to service_role;

-- ---------------------------------------------------------------
-- Elegir el par de la próxima chispa
-- ---------------------------------------------------------------
-- p_exclude_daily = true para las chispas extra: si no hay pares descansados, acepta conceptos sin descanso,
-- pero nunca los de la chispa diaria de hoy (que puede estar sin abrir).
-- Orden de intentos:
--   1. pares descansados y sin usar
--   2. (solo extra) pares sin usar, sin exigir descanso
--   3. un concepto del usuario con uno de la biblioteca (lo copia a su bóveda)
--   4. (solo diaria) pares sin usar, sin exigir descanso: Hoy no queda vacía
-- Sin ningún concepto con embedding no devuelve filas.
create or replace function public.pick_spark_pair(p_user uuid, p_exclude_daily boolean default false)
returns table (concept_lo uuid, concept_hi uuid, distance real, distance_percentile int, uses_library boolean, candidates_count int)
language plpgsql
volatile
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_center real;
  v_profiles text[];
  v_tz text;
  v_daily uuid[] := '{}';
  v_attempt int;
  v_relaxed boolean;
  v_mine record;
  v_lib record;
  v_copy uuid;
  r record;
begin
  select target_distance, creative_profiles, timezone into v_center, v_profiles, v_tz
    from public.profiles where id = p_user;
  if not found then
    return;
  end if;

  if p_exclude_daily then
    select array[s.concept_lo, s.concept_hi] into v_daily
      from public.sparks s
     where s.user_id = p_user and s.mode = 'daily' and s.scheduled_for = (now() at time zone v_tz)::date;
    v_daily := coalesce(v_daily, '{}');
  end if;

  foreach v_attempt in array case when p_exclude_daily then array[1, 2, 3] else array[1, 3, 4] end loop
    if v_attempt in (1, 2, 4) then
      v_relaxed := v_attempt <> 1;
      select * into r from (
        with eligible as (
          select p.*, abs(p.percentile - v_center) as gap
          from public.spark_pairs(p_user) p
          where not p.used
            and (p.rested or (v_relaxed and not (p.lo = any(v_daily) or p.hi = any(v_daily))))
        ),
        summary as (
          select count(*)::int as n, coalesce(bool_or(gap <= 0.2), false) as any_in_band from eligible
        ),
        top20 as (
          -- Si hay pares en la banda, solo esos; si no, los más cercanos a ella.
          select e.* from eligible e, summary s
          where not s.any_in_band or e.gap <= 0.2
          order by e.gap
          limit 20
        )
        select t.lo, t.hi, t.distance, round(t.percentile * 100)::int as pct, (select n from summary) as n
        from top20 t
        -- Sorteo ponderado: la clave exponencial con peso = novedad.
        order by -ln(1 - random()) / greatest(t.novelty, 0.01)
        limit 1
      ) picked;
      if r.lo is not null then
        return query select r.lo, r.hi, r.distance, r.pct, false, r.n;
        return;
      end if;
    else
      -- Respaldo con la biblioteca: el concepto del usuario menos usado (descansado primero).
      select c.id, c.embedding, c.embedding_model, c.domain into v_mine
        from public.concepts c
       where c.user_id = p_user and c.status = 'ready' and c.embedding is not null and not c.from_library
         and not (c.id = any(v_daily))
       order by coalesce(c.last_used_at, '-infinity'::timestamptz) < now() - interval '3 days' desc,
                (select count(*) from public.sparks s
                  where s.user_id = p_user and (s.concept_lo = c.id or s.concept_hi = c.id)),
                c.created_at desc
       limit 1;
      if v_mine.id is null then
        -- Sin conceptos con embedding no hay chispa posible.
        return;
      end if;

      -- Un concepto invitado de otro dominio, de sus perfiles si hay (si no, de cualquiera),
      -- que no haya copiado antes, con la distancia más cerca del centro de su banda.
      select l.id, l.dist, l.pct into v_lib from (
        select l.id,
               (l.embedding operator(extensions.<=>) v_mine.embedding)::real as dist,
               percent_rank() over (partition by l.in_profile order by l.embedding operator(extensions.<=>) v_mine.embedding) as pct,
               l.in_profile
        from (
          select lc.*, (cardinality(v_profiles) = 0 or lc.profile = any(v_profiles)) as in_profile
          from public.library_concepts lc
          where lc.embedding is not null
            and lc.embedding_model = v_mine.embedding_model
            and lc.domain is distinct from v_mine.domain
            and not exists (select 1 from public.concepts c where c.user_id = p_user and c.library_id = lc.id)
        ) l
      ) l
      order by l.in_profile desc, abs(l.pct - v_center), random()
      limit 1;

      if v_lib.id is not null then
        v_copy := public.copy_library_concept(p_user, v_lib.id);
        return query select least(v_mine.id, v_copy), greatest(v_mine.id, v_copy), v_lib.dist,
                            round(v_lib.pct * 100)::int, true, 0;
        return;
      end if;
    end if;
  end loop;
end;
$$;

revoke execute on function public.pick_spark_pair(uuid, boolean) from public, anon, authenticated;
grant execute on function public.pick_spark_pair(uuid, boolean) to service_role;

-- Días aproximados de pares buenos que le quedan: pares en la banda sin usar (uno por día).
-- Con menos de 7, la app pide capturar más.
create or replace function public.spark_runway_days(p_user uuid)
returns int
language sql
stable
security definer
set search_path = ''
as $$
  select least(count(*), 365)::int
  from public.spark_pairs(p_user) p
  where not p.used
    and abs(p.percentile - (select target_distance from public.profiles where id = p_user)) <= 0.2;
$$;

revoke execute on function public.spark_runway_days(uuid) from public, anon, authenticated;
grant execute on function public.spark_runway_days(uuid) to service_role;

-- ---------------------------------------------------------------
-- Guardar la chispa
-- ---------------------------------------------------------------
-- Ordena el par, inserta y marca el uso de los dos conceptos (para el descanso).
-- Si el par ya existe o ya hay chispa diaria para ese día, no inserta y devuelve null.
create or replace function public.create_spark(
  p_user uuid,
  p_concept_a uuid,
  p_concept_b uuid,
  p_mode text,
  p_title text,
  p_body text,
  p_distance real default null,
  p_distance_percentile int default null,
  p_uses_library boolean default false,
  p_scheduled_for date default null,
  p_status text default 'pending'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if p_concept_a = p_concept_b
     or (select count(*) from public.concepts where id in (p_concept_a, p_concept_b) and user_id = p_user) <> 2 then
    raise exception 'invalid_request' using errcode = '22023';
  end if;

  insert into public.sparks (
    user_id, concept_lo, concept_hi, mode, title, body, distance, distance_percentile, uses_library,
    scheduled_for, status
  ) values (
    p_user, least(p_concept_a, p_concept_b), greatest(p_concept_a, p_concept_b), p_mode, p_title, p_body,
    p_distance, p_distance_percentile, coalesce(p_uses_library, false), p_scheduled_for, p_status
  )
  on conflict do nothing
  returning id into v_id;

  if v_id is not null then
    update public.concepts set last_used_at = now() where id in (p_concept_a, p_concept_b);
  end if;
  return v_id;
end;
$$;

revoke execute on function public.create_spark(uuid, uuid, uuid, text, text, text, real, int, boolean, date, text)
  from public, anon, authenticated;
grant execute on function public.create_spark(uuid, uuid, uuid, text, text, text, real, int, boolean, date, text)
  to service_role;

-- ---------------------------------------------------------------
-- El reloj del usuario: día local, hora de la chispa y próxima recarga
-- ---------------------------------------------------------------
create or replace function public.user_clock(p_user uuid)
returns table (local_date date, day_started_at timestamptz, spark_due boolean, next_spark_at timestamptz, timezone text, plan text)
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
         p.timezone,
         public.effective_plan(p.id)
  from public.profiles p
  cross join lateral (select (now() at time zone p.timezone)::date as local_date) d
  where p.id = p_user;
$$;

revoke execute on function public.user_clock(uuid) from public, anon, authenticated;
grant execute on function public.user_clock(uuid) to service_role;
