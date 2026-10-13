-- Captura con adjuntos (imagen y PDF), fuente completa, almacenamiento temporal y búsqueda semántica.

-- ---------------------------------------------------------------
-- capture_concept: ahora con imagen, PDF, título de la fuente, fragmento y foto local
-- ---------------------------------------------------------------
-- Mismos nombres y defaults que antes; los parámetros nuevos van al final con default null,
-- así las llamadas por nombre de la versión anterior siguen andando.
-- Se borra la versión de 4 parámetros: con las dos, PostgREST no sabría a cuál llamar.
drop function public.capture_concept(text, text, text, text);

-- Errores (en el mensaje): not_authenticated · invalid_thesis · invalid_category · invalid_source
--   · quota_exceeded · too_many_categories
create or replace function public.capture_concept(
  p_thesis text,
  p_category text,
  p_source_type text default 'text',
  p_source_url text default null,
  p_source_title text default null,
  p_excerpt text default null,
  p_local_asset_id text default null
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

  if not public.consume_credit(v_user, 'capture') then
    raise exception 'quota_exceeded' using errcode = 'P0001';
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
    source_title, excerpt, local_asset_id, raw_text, raw_text_expires_at
  ) values (
    v_user, v_category.id, v_category.domain, false, v_title, v_thesis, p_source_type, v_url,
    v_source_title, v_excerpt, v_asset, v_thesis, now() + interval '30 days'
  )
  returning id into v_concept;

  return query select v_concept, v_category.id, v_created;
end;
$$;

revoke execute on function public.capture_concept(text, text, text, text, text, text, text) from public, anon;
grant execute on function public.capture_concept(text, text, text, text, text, text, text) to authenticated, service_role;

-- ---------------------------------------------------------------
-- Almacenamiento temporal de adjuntos
-- ---------------------------------------------------------------
-- La app sube la imagen o el PDF a <su user_id>/<uuid>.<ext>; la Edge Function de captura lo lee
-- con service role y lo borra siempre, también si falla. Nada queda guardado (plan.md §6).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('capture-temp', 'capture-temp', false, 52428800, array['image/jpeg', 'image/png', 'application/pdf'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "capture-temp: subir a la carpeta propia" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'capture-temp' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "capture-temp: leer la carpeta propia" on storage.objects
  for select to authenticated
  using (bucket_id = 'capture-temp' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "capture-temp: borrar de la carpeta propia" on storage.objects
  for delete to authenticated
  using (bucket_id = 'capture-temp' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- ---------------------------------------------------------------
-- Búsqueda semántica
-- ---------------------------------------------------------------
-- security invoker: corre con la sesión del usuario, así RLS deja solo sus conceptos.
-- El embedding de la consulta lo calcula la Edge Function de búsqueda con el mismo modelo que los conceptos.
create or replace function public.match_concepts(p_query_embedding extensions.vector(1024), p_match_count int default 30)
returns setof public.concepts
language sql
stable
security invoker
set search_path = ''
as $$
  select c.*
  from public.concepts c
  where c.embedding is not null
  order by c.embedding operator(extensions.<=>) p_query_embedding
  limit least(greatest(coalesce(p_match_count, 30), 1), 50);
$$;

revoke execute on function public.match_concepts(extensions.vector, int) from public, anon;
grant execute on function public.match_concepts(extensions.vector, int) to authenticated, service_role;
