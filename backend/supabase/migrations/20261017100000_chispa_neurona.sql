-- La chispa guardada se vuelve neurona (paso 88, plan.md §4 versión 1.1). Flag `spark_neuron`.
--
-- - Al guardar una chispa con save_spark() se crea una neurona con su título y su cuerpo y la referencia a la
--   chispa y a sus dos neuronas de origen. Entra sin embedding: /process la embebe (título + cuerpo) como a
--   cualquier otra, y al tener vector toma el dominio más cercano (no tiene categoría hasta que el usuario la mueva).
-- - El emparejamiento nunca la cruza con sus padres: ni spark_pairs() (y con ella pick_spark_pair() y
--   spark_runway_days()) ni create_spark().
-- - No pasa por capture_concept(), así que no gasta cupo de captura, y concepts_saved_since() no la cuenta:
--   si no, guardar chispas daría chispas extra.
-- - Se apaga en dos lados: la app manda p_as_neuron con su flag `spark_neuron` (PostHog) y el servidor
--   lo ignora si app_config.spark_neuron_enabled es false.

-- ---------------------------------------------------------------
-- Configuración
-- ---------------------------------------------------------------
insert into public.app_config (key, value, description) values
  ('spark_neuron_enabled', 'true',
   'Flag spark_neuron del lado del servidor. En false, guardar una chispa no crea su neurona aunque la app lo pida.')
on conflict (key) do nothing;

-- ---------------------------------------------------------------
-- Neuronas que nacen de una chispa
-- ---------------------------------------------------------------
alter table public.concepts drop constraint concepts_source_type_check;
alter table public.concepts add constraint concepts_source_type_check check (source_type in
  ('text', 'voice', 'selection', 'screenshot', 'scan', 'link', 'image', 'pdf', 'audio', 'video', 'import', 'spark'));

-- La chispa y los dos padres. Si se borra un padre, se borra la chispa (cascade) y quedan en null:
-- la neurona sigue siendo del usuario, y source_type = 'spark' sigue diciendo de dónde vino.
alter table public.concepts
  add column origin_spark_id uuid references public.sparks (id) on delete set null,
  add column origin_lo uuid references public.concepts (id) on delete set null,
  add column origin_hi uuid references public.concepts (id) on delete set null;

comment on column public.concepts.origin_spark_id is 'La chispa guardada de la que nació esta neurona (source_type = spark).';
comment on column public.concepts.origin_lo is 'Neurona de origen de la chispa (la de id menor). Nunca se empareja con esta.';
comment on column public.concepts.origin_hi is 'Neurona de origen de la chispa (la de id mayor). Nunca se empareja con esta.';

-- Una neurona por chispa.
create unique index concepts_origin_spark_idx on public.concepts (origin_spark_id) where origin_spark_id is not null;
create index concepts_origin_lo_idx on public.concepts (origin_lo) where origin_lo is not null;
create index concepts_origin_hi_idx on public.concepts (origin_hi) where origin_hi is not null;

-- Dominio por cercanía: una neurona de chispa sin categoría toma el dominio más cercano a su vector
-- (plan.md §5: "sin conceptualización, el dominio se asigna por cercanía a los vectores de cada dominio").
create or replace function public.concepts_spark_domain()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  select d.slug into new.domain
    from public.domains d
   where d.embedding is not null and d.embedding_model = new.embedding_model
   order by d.embedding operator(extensions.<=>) new.embedding
   limit 1;
  return new;
end;
$$;

revoke execute on function public.concepts_spark_domain() from public, anon, authenticated;

create trigger concepts_spark_domain
  before insert or update of embedding on public.concepts
  for each row
  when (new.source_type = 'spark' and new.domain is null and new.category_id is null and new.embedding is not null)
  execute function public.concepts_spark_domain();

-- Crea la neurona de una chispa (o devuelve la que ya tiene). Null si el flag del servidor está apagado.
-- Solo la llaman save_spark() y las Edge Functions.
create or replace function public.create_spark_neuron(p_spark uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_spark public.sparks;
  v_title text;
  v_thesis text;
  v_id uuid;
begin
  if not coalesce((public.app_config_value('spark_neuron_enabled', 'true') #>> '{}')::boolean, false) then
    return null;
  end if;

  select * into v_spark from public.sparks where id = p_spark;
  if not found then
    return null;
  end if;

  select id into v_id from public.concepts where origin_spark_id = p_spark;
  if v_id is not null then
    return v_id;
  end if;

  -- Sin título (no debería pasar), el de las dos neuronas; sin cuerpo, el título.
  v_title := nullif(regexp_replace(trim(coalesce(v_spark.title, '')), '\s+', ' ', 'g'), '');
  if v_title is null then
    select a.title || ' × ' || b.title into v_title
      from public.concepts a, public.concepts b
     where a.id = v_spark.concept_lo and b.id = v_spark.concept_hi;
  end if;
  v_title := left(v_title, 120);
  v_thesis := left(coalesce(nullif(regexp_replace(trim(coalesce(v_spark.body, '')), '\s+', ' ', 'g'), ''), v_title), 600);

  insert into public.concepts (
    user_id, title, thesis, status, source_type, origin_spark_id, origin_lo, origin_hi
  ) values (
    v_spark.user_id, v_title, v_thesis, 'ready', 'spark', v_spark.id, v_spark.concept_lo, v_spark.concept_hi
  )
  on conflict (origin_spark_id) where origin_spark_id is not null do nothing
  returning id into v_id;

  if v_id is null then
    -- Otra llamada la creó en el mismo instante.
    select id into v_id from public.concepts where origin_spark_id = p_spark;
    return v_id;
  end if;

  perform public.track_event(v_spark.user_id, 'spark_neuron_created', jsonb_build_object(
    'mode', v_spark.mode,
    'parent_is_spark_neuron', exists (select 1 from public.concepts c
                                       where c.id in (v_spark.concept_lo, v_spark.concept_hi) and c.source_type = 'spark')));
  return v_id;
end;
$$;

revoke execute on function public.create_spark_neuron(uuid) from public, anon, authenticated;
grant execute on function public.create_spark_neuron(uuid) to service_role;

-- ---------------------------------------------------------------
-- Guardar una chispa desde la app
-- ---------------------------------------------------------------
-- Reemplaza el update directo de status y project_id (que sigue andando, sin neurona).
-- Con p_as_neuron (el flag `spark_neuron` de la app), la primera vez que se guarda crea su neurona.
-- Mover la chispa a otro circuito no crea otra. Devuelve el id de la neurona que nació de la chispa, o null.
-- Errores: not_authenticated · not_found (la chispa o el circuito no son del usuario)
create or replace function public.save_spark(p_spark uuid, p_project uuid default null, p_as_neuron boolean default false)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_status text;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  select status into v_status from public.sparks where id = p_spark and user_id = v_user for update;
  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  if p_project is not null and not exists (select 1 from public.projects where id = p_project and user_id = v_user) then
    raise exception 'not_found' using errcode = 'P0002';
  end if;

  update public.sparks set status = 'saved', project_id = p_project where id = p_spark;

  if coalesce(p_as_neuron, false) and v_status <> 'saved' then
    perform public.create_spark_neuron(p_spark);
  end if;
  return (select id from public.concepts where origin_spark_id = p_spark);
end;
$$;

revoke execute on function public.save_spark(uuid, uuid, boolean) from public, anon;
grant execute on function public.save_spark(uuid, uuid, boolean) to authenticated, service_role;

-- ---------------------------------------------------------------
-- Las neuronas de chispa no suman para la chispa extra
-- ---------------------------------------------------------------
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
    and source_type <> 'spark'
    and created_at >= (p_start::timestamp at time zone p_timezone);
$$;

-- ---------------------------------------------------------------
-- Emparejamiento: nunca una neurona con sus padres
-- ---------------------------------------------------------------
-- Igual que en 20261009130000_emparejamiento.sql, más la exclusión de padres en el join.
create or replace function public.spark_pairs(p_user uuid)
returns table (lo uuid, hi uuid, distance real, percentile real, rested boolean, used boolean, novelty real)
language sql
stable
security definer
set search_path = ''
as $$
  with mine as (
    select c.id, c.embedding, c.embedding_model, c.origin_lo, c.origin_hi,
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
      -- Una neurona que nació de una chispa nunca se cruza con sus dos padres.
      and a.id is distinct from b.origin_lo and a.id is distinct from b.origin_hi
      and b.id is distinct from a.origin_lo and b.id is distinct from a.origin_hi
  )
  select lo, hi, distance, (percent_rank() over (order by distance))::real as percentile, rested, used, novelty
  from pairs;
$$;

-- True si una de las dos neuronas nació de una chispa de la otra.
create or replace function public.is_spark_parent(p_a uuid, p_b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.concepts c
     where (c.id = p_a and p_b in (c.origin_lo, c.origin_hi))
        or (c.id = p_b and p_a in (c.origin_lo, c.origin_hi)));
$$;

revoke execute on function public.is_spark_parent(uuid, uuid) from public, anon, authenticated;
grant execute on function public.is_spark_parent(uuid, uuid) to service_role;

-- create_spark: además, rechaza un par de neurona y padre (por ejemplo, un pick armado a mano).
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
     or (select count(*) from public.concepts where id in (p_concept_a, p_concept_b) and user_id = p_user) <> 2
     or public.is_spark_parent(p_concept_a, p_concept_b) then
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
