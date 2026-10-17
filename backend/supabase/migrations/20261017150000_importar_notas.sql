-- Importar notas (paso 89, flag import_notes): archivos Markdown, carpetas de Obsidian y Apple Notes (vía Atajos).
-- Cada nota entra por /capture como cualquier captura, pero gasta su propio cupo ('import') en vez del tope de
-- capturas por día (decidido el 2026-10-17): importar 50 notas no deja al usuario sin poder capturar ese día.
--
-- free e invitado: 50 en total, no se renueva (plan.md §4). Pro: ilimitado, con 1.000 por día como techo técnico
-- contra el abuso (provisorio: ver ios/README.md). El invitado conserva lo que usó al crear la cuenta (mismo usuario).
-- Las importadas cuentan para la chispa extra igual que cualquier neurona nueva (el tope de 2 por día no cambia).

-- ---------------------------------------------------------------
-- Cupo 'import'
-- ---------------------------------------------------------------
alter table public.plan_limits drop constraint plan_limits_kind_check;
alter table public.plan_limits
  add constraint plan_limits_kind_check
  check (kind in ('capture', 'distill', 'spark_extra', 'planner', 'planner_deep', 'projects', 'import'));

insert into public.plan_limits (plan, kind, period, max_count) values
  ('guest', 'import', 'total', 50),
  ('free', 'import', 'total', 50),
  ('pro', 'import', 'day', 1000);

-- ---------------------------------------------------------------
-- De dónde vino una neurona importada
-- ---------------------------------------------------------------
alter table public.concepts
  add column import_source text check (import_source in ('markdown', 'apple_notes'));

comment on column public.concepts.import_source is
  'Si la neurona vino de importar notas: markdown (archivos o carpeta de Obsidian) o apple_notes (atajo). Null si se capturó.';

-- ---------------------------------------------------------------
-- capture_concept: con p_import_source
-- ---------------------------------------------------------------
-- Igual que antes; el parámetro nuevo va al final con default null, así las llamadas por nombre siguen andando.
-- Con p_import_source descuenta 'import' (y avisa import_limit) en vez de 'capture' (quota_exceeded).
-- Se borra la versión de 7 parámetros: con las dos, PostgREST no sabría a cuál llamar.
drop function public.capture_concept(text, text, text, text, text, text, text);

-- Errores (en el mensaje): not_authenticated · invalid_thesis · invalid_category · invalid_source
--   · quota_exceeded · import_limit · too_many_categories
create or replace function public.capture_concept(
  p_thesis text,
  p_category text,
  p_source_type text default 'text',
  p_source_url text default null,
  p_source_title text default null,
  p_excerpt text default null,
  p_local_asset_id text default null,
  p_import_source text default null
)
returns table (concept_id uuid, category_id uuid, category_created boolean)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_user uuid := auth.uid();
  v_thesis text := regexp_replace(trim(coalesce(p_thesis, '')), '\s+', ' ', 'g');
  v_category_name text := regexp_replace(trim(coalesce(p_category, '')), '\s+', ' ', 'g');
  v_url text := nullif(trim(coalesce(p_source_url, '')), '');
  v_source_title text := left(nullif(regexp_replace(trim(coalesce(p_source_title, '')), '\s+', ' ', 'g'), ''), 300);
  -- El fragmento se corta a 500 caracteres (la app ya lo corta; esto es la red de seguridad).
  v_excerpt text := left(nullif(trim(coalesce(p_excerpt, '')), ''), 500);
  v_asset text := left(nullif(trim(coalesce(p_local_asset_id, '')), ''), 200);
  v_import text := nullif(trim(coalesce(p_import_source, '')), '');
  v_category public.categories;
  v_created boolean := false;
  v_title text;
  v_concept uuid;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if char_length(v_thesis) not between 1 and 600 then
    raise exception 'invalid_thesis' using errcode = '22023';
  end if;
  if char_length(v_category_name) not between 1 and 40 then
    raise exception 'invalid_category' using errcode = '22023';
  end if;
  -- Un link necesita su URL. Los demás tipos pueden traer la de origen (una selección de Safari, un PDF bajado).
  if p_source_type is null
     or p_source_type not in ('text', 'voice', 'selection', 'screenshot', 'scan', 'link', 'image', 'pdf')
     or (p_source_type = 'link' and v_url is null)
     or (v_url is not null and (v_url !~* '^https?://[^\s]+$' or char_length(v_url) > 2048)) then
    raise exception 'invalid_source' using errcode = '22023';
  end if;
  -- Una nota importada es texto.
  if v_import is not null and (v_import not in ('markdown', 'apple_notes') or p_source_type <> 'text') then
    raise exception 'invalid_source' using errcode = '22023';
  end if;

  if v_import is null then
    if not public.consume_credit(v_user, 'capture') then
      raise exception 'quota_exceeded' using errcode = 'P0001';
    end if;
  elsif not public.consume_credit(v_user, 'import') then
    raise exception 'import_limit' using errcode = 'P0001';
  end if;

  select * into v_category from public.categories c
   where c.user_id = v_user and c.normalized = public.normalize_category(v_category_name);
  if not found then
    if (select count(*) from public.categories c where c.user_id = v_user) >= 50 then
      raise exception 'too_many_categories' using errcode = 'P0001';
    end if;
    insert into public.categories (user_id, name) values (v_user, v_category_name)
    returning * into v_category;
    v_created := true;
  end if;

  -- Título: las primeras palabras de la tesis, hasta 60 caracteres. La destilación lo mejora.
  v_title := case
    when char_length(v_thesis) <= 60 then v_thesis
    else coalesce(nullif(substring(left(v_thesis, 60) from '^(.*)\s'), ''), left(v_thesis, 60)) || '…'
  end;

  insert into public.concepts (
    user_id, category_id, domain, domain_confirmed, title, thesis, source_type, source_url,
    source_title, excerpt, local_asset_id, raw_text, raw_text_expires_at, import_source
  ) values (
    v_user, v_category.id, v_category.domain, false, v_title, v_thesis, p_source_type, v_url,
    v_source_title, v_excerpt, v_asset, v_thesis, now() + interval '30 days', v_import
  )
  returning id into v_concept;

  return query select v_concept, v_category.id, v_created;
end;
$$;

revoke execute on function public.capture_concept(text, text, text, text, text, text, text, text) from public, anon;
grant execute on function public.capture_concept(text, text, text, text, text, text, text, text) to authenticated, service_role;
