-- Categorías propias de cada usuario (decisión del 27/9/2026, plan.md §4 y §5).
--
-- - Cada usuario arranca sin categorías y las crea al guardar conceptos.
-- - "Economía", " economia " y "ECONOMÍA" son la misma categoría: se comparan normalizadas.
-- - Por debajo, cada categoría se puede asociar a un dominio de la lista cerrada (paso 27, por embedding del nombre).
--   El concepto hereda ese dominio, que es lo que usa el emparejamiento para cruzar mundos distintos.
-- - Guardar un concepto pasa por capture_concept(): descuenta la cuota, encuentra o crea la categoría
--   e inserta el concepto en una sola transacción.

create extension if not exists unaccent with schema extensions;

-- Nombre normalizado para comparar: sin acentos, en minúscula y con los espacios colapsados.
create or replace function public.normalize_category(p_name text)
returns text
language sql
stable
set search_path = ''
as $$
  select lower(extensions.unaccent(regexp_replace(trim(p_name), '\s+', ' ', 'g')));
$$;

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 40),
  normalized text not null,
  -- Dominio de la lista cerrada. Null hasta que se clasifica (paso 27).
  domain text references public.domains (slug),
  created_at timestamptz not null default now(),
  unique (user_id, normalized),
  -- Para que un concepto solo pueda apuntar a una categoría de su mismo usuario.
  unique (id, user_id)
);

create index categories_domain_idx on public.categories (domain);

comment on table public.categories is 'Categorías que crea cada usuario al guardar conceptos. Por debajo se asocian a un dominio.';

create or replace function public.categories_set_normalized()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.name := regexp_replace(trim(new.name), '\s+', ' ', 'g');
  new.normalized := public.normalize_category(new.name);
  return new;
end;
$$;

create trigger categories_normalize
  before insert or update of name on public.categories
  for each row execute function public.categories_set_normalized();

-- Conceptos: la categoría es del usuario; el dominio pasa a ser opcional (se hereda de la categoría).
alter table public.concepts alter column domain drop not null;
alter table public.concepts add column category_id uuid;
alter table public.concepts
  add constraint concepts_category_same_user
  foreign key (category_id, user_id) references public.categories (id, user_id)
  on delete set null (category_id);
create index concepts_category_idx on public.concepts (category_id);

-- Datos que ya existían: una categoría por dominio usado, con el nombre del dominio.
insert into public.categories (user_id, name, domain)
select distinct c.user_id, d.name_es, d.slug
from public.concepts c
join public.domains d on d.slug = c.domain
on conflict (user_id, normalized) do nothing;

update public.concepts c
   set category_id = cat.id
  from public.categories cat
 where cat.user_id = c.user_id and cat.domain = c.domain and c.category_id is null;

-- ---------------------------------------------------------------
-- RLS: cada uno ve, renombra y borra las suyas. Se crean solo con capture_concept().
-- ---------------------------------------------------------------
alter table public.categories enable row level security;

create policy "categories: leer las propias" on public.categories
  for select to authenticated using (user_id = (select auth.uid()));
create policy "categories: renombrar las propias" on public.categories
  for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "categories: borrar las propias" on public.categories
  for delete to authenticated using (user_id = (select auth.uid()));
revoke all on public.categories from anon;
revoke insert, update on public.categories from authenticated;
grant update (name) on public.categories to authenticated;

-- ---------------------------------------------------------------
-- capture_concept: guardar un concepto desde la app
-- ---------------------------------------------------------------
-- Errores (en el mensaje, para que la app los traduzca):
--   not_authenticated · invalid_thesis · invalid_category · invalid_source · quota_exceeded · too_many_categories
create or replace function public.capture_concept(
  p_thesis text,
  p_category text,
  p_source_type text default 'text',
  p_source_url text default null
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
  if p_source_type not in ('text', 'voice', 'selection', 'screenshot', 'scan', 'link')
     or (p_source_type = 'link') <> (p_source_url is not null) then
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

  -- Título: las primeras palabras de la tesis, hasta 60 caracteres. La destilación (paso 25) lo mejora.
  v_title := case
    when char_length(v_thesis) <= 60 then v_thesis
    else coalesce(nullif(substring(left(v_thesis, 60) from '^(.*)\s'), ''), left(v_thesis, 60)) || '…'
  end;

  insert into public.concepts (
    user_id, category_id, domain, domain_confirmed, title, thesis, source_type, source_url,
    raw_text, raw_text_expires_at
  ) values (
    v_user, v_category.id, v_category.domain, false, v_title, v_thesis, p_source_type, p_source_url,
    v_thesis, now() + interval '30 days'
  )
  returning id into v_concept;

  return query select v_concept, v_category.id, v_created;
end;
$$;

revoke execute on function public.capture_concept(text, text, text, text) from public, anon;
grant execute on function public.capture_concept(text, text, text, text) to authenticated, service_role;
