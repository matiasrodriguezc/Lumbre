-- Lumbre: esquema base (Postgres + pgvector).
--
-- Principios:
-- - Lo único que se guarda de cada captura es el concepto. Archivos, audios y páginas se borran al procesarse.
-- - Las apps leen con su sesión y RLS. Todo lo que crea contenido o gasta IA pasa por Edge Functions con service role.
-- - Supabase da permisos de tabla completos a anon y authenticated: por eso cada tabla tiene RLS activado
--   y las columnas que el usuario puede editar se habilitan una por una.

create extension if not exists vector with schema extensions;

-- ---------------------------------------------------------------
-- Perfiles
-- ---------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  -- Hasta dos perfiles. Mismos slugs que docs/analytics.md.
  creative_profiles text[] not null default '{}'
    check (cardinality(creative_profiles) <= 2
           and creative_profiles <@ array['software', 'content', 'business', 'design', 'curiosity']),
  spark_hour time not null default '08:00',
  timezone text not null default 'America/Argentina/Buenos_Aires',
  locale text not null default 'es' check (locale in ('es', 'en')),
  -- Lo escribe solo el webhook de RevenueCat (service role).
  plan text not null default 'free' check (plan in ('free', 'pro')),
  -- Distancia objetivo del emparejamiento, calibrada con el feedback. La escribe el servidor.
  target_distance real,
  created_at timestamptz not null default now()
);

comment on table public.profiles is 'Un perfil por usuario de auth. El usuario solo edita perfiles creativos, hora, zona horaria e idioma.';

-- ---------------------------------------------------------------
-- Dominios: lista cerrada (20–25). El embedding de la descripción sirve
-- para clasificar conceptos sin destilar. La lista se carga en el paso 21.
-- ---------------------------------------------------------------
create table public.domains (
  slug text primary key,
  name_es text not null,
  name_en text not null,
  description text not null,
  -- SF Symbol y Material Symbol del dominio.
  symbol_ios text,
  symbol_android text,
  -- La dimensión depende del modelo de embeddings (paso 22). Si cambia, se migra.
  embedding extensions.vector(1024),
  embedding_model text
);

-- ---------------------------------------------------------------
-- Conceptos: lo único que se guarda de cada captura.
-- ---------------------------------------------------------------
create table public.concepts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  domain text not null references public.domains (slug),
  -- El usuario confirmó (o cambió) la categoría sugerida.
  domain_confirmed boolean not null default false,
  title text not null check (char_length(title) between 1 and 120),
  thesis text not null check (char_length(thesis) between 1 and 600),
  -- Null si no se destiló.
  principle text,
  embedding extensions.vector(1024),
  -- Para re-embeber toda la base si se cambia de modelo.
  embedding_model text,
  distilled boolean not null default false,
  confidence text check (confidence in ('high', 'medium', 'low')),
  status text not null default 'ready' check (status in ('draft', 'ready')),
  source_type text not null check (source_type in
    ('text', 'voice', 'selection', 'screenshot', 'scan', 'link', 'image', 'pdf', 'audio', 'video', 'import')),
  source_url text,
  source_title text,
  -- Fragmento subrayado por el usuario.
  excerpt text check (char_length(excerpt) <= 500),
  -- Se borra a los 30 días (job del paso 37).
  raw_text text,
  raw_text_expires_at timestamptz,
  -- Referencia a la foto, que queda en el teléfono.
  local_asset_id text,
  -- Copiado de la biblioteca curada de conceptos invitados (paso 31). No confundir con el usuario invitado.
  from_library boolean not null default false,
  -- Para el descanso de 3 días entre apariciones.
  last_used_at timestamptz,
  created_at timestamptz not null default now(),
  -- Un concepto sin embedding no puede entrar al emparejamiento.
  check ((embedding is null) = (embedding_model is null))
);

create index concepts_user_domain_idx on public.concepts (user_id, domain);
create index concepts_user_created_idx on public.concepts (user_id, created_at desc);
-- Para detectar un link guardado dos veces.
create index concepts_user_url_idx on public.concepts (user_id, source_url) where source_url is not null;

-- ---------------------------------------------------------------
-- Chispas: el par nunca se repite, por eso se guarda ordenado (lo < hi).
-- ---------------------------------------------------------------
create table public.sparks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  concept_lo uuid not null references public.concepts (id) on delete cascade,
  concept_hi uuid not null references public.concepts (id) on delete cascade,
  mode text not null default 'daily' check (mode in ('daily', 'extra', 'pick', 'problem')),
  distance real,
  title text,
  body text,
  status text not null default 'pending' check (status in ('pending', 'revealed', 'saved', 'discarded')),
  feedback text check (feedback in ('obvious', 'irrelevant', 'already_had')),
  -- Día (en la zona del usuario) en que se muestra la chispa diaria.
  scheduled_for date,
  created_at timestamptz not null default now(),
  unique (user_id, concept_lo, concept_hi),
  check (concept_lo < concept_hi)
);

create index sparks_user_scheduled_idx on public.sparks (user_id, scheduled_for desc);

-- ---------------------------------------------------------------
-- Cuotas. Los límites se ajustan sin publicar una versión de la app.
-- ---------------------------------------------------------------
create table public.plan_limits (
  plan text not null,
  kind text not null check (kind in ('capture', 'distill', 'spark_extra', 'planner', 'planner_deep')),
  period text not null check (period in ('day', 'month')),
  max_count int not null check (max_count >= 0),
  primary key (plan, kind, period)
);

insert into public.plan_limits (plan, kind, period, max_count) values
  ('free', 'capture', 'day', 30),
  ('free', 'distill', 'month', 5),
  ('free', 'spark_extra', 'day', 2),
  ('pro', 'capture', 'day', 200),
  ('pro', 'distill', 'month', 300),
  ('pro', 'spark_extra', 'day', 10),
  ('pro', 'planner', 'month', 300),
  ('pro', 'planner_deep', 'month', 60);

create table public.usage_ledger (
  user_id uuid not null references auth.users on delete cascade,
  kind text not null,
  period text not null,
  period_start date not null,
  used int not null default 0 check (used >= 0),
  primary key (user_id, kind, period, period_start)
);

-- Descuenta un crédito de forma atómica y devuelve true si había cupo.
-- - El período se calcula en la zona horaria del usuario.
-- - Si un tipo tiene límite diario y mensual, tienen que alcanzar los dos: si uno falla, se revierten ambos.
-- - Si el plan no tiene fila para ese tipo, no hay cupo.
-- Solo la llaman las Edge Functions (service role): nunca la app directo.
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
  v_ok int;
  v_found boolean := false;
begin
  select plan, timezone into v_plan, v_tz from public.profiles where id = p_user;

  for r in select period, max_count from public.plan_limits where plan = v_plan and kind = p_kind loop
    v_found := true;
    v_start := date_trunc(r.period, now() at time zone v_tz)::date;

    insert into public.usage_ledger (user_id, kind, period, period_start)
    values (p_user, p_kind, r.period, v_start)
    on conflict do nothing;

    v_ok := null;
    update public.usage_ledger
       set used = used + 1
     where user_id = p_user and kind = p_kind and period = r.period
       and period_start = v_start and used < r.max_count
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

revoke execute on function public.consume_credit(uuid, text) from public, anon, authenticated;
grant execute on function public.consume_credit(uuid, text) to service_role;

-- ---------------------------------------------------------------
-- Registro de llamadas a modelos (tablero de costos y alertas). Solo service role.
-- ---------------------------------------------------------------
create table public.llm_calls (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users on delete set null,
  feature text not null,
  model text not null,
  prompt_version text,
  input_tokens int,
  cached_tokens int,
  output_tokens int,
  cost_usd numeric(10, 6),
  latency_ms int,
  batch boolean not null default false,
  created_at timestamptz not null default now()
);

create index llm_calls_created_idx on public.llm_calls (created_at desc);
create index llm_calls_user_created_idx on public.llm_calls (user_id, created_at desc);

-- ---------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.domains enable row level security;
alter table public.concepts enable row level security;
alter table public.sparks enable row level security;
alter table public.plan_limits enable row level security;
alter table public.usage_ledger enable row level security;
alter table public.llm_calls enable row level security;

-- Perfiles: cada uno ve y edita el suyo, pero solo estas columnas.
create policy "profiles: leer el propio" on public.profiles
  for select to authenticated using (id = (select auth.uid()));
create policy "profiles: editar el propio" on public.profiles
  for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
revoke insert, update, delete on public.profiles from anon, authenticated;
grant update (creative_profiles, spark_hour, timezone, locale) on public.profiles to authenticated;

-- Dominios y límites: lectura para cualquiera con sesión, escritura solo service role.
create policy "domains: lectura" on public.domains
  for select to anon, authenticated using (true);
create policy "plan_limits: lectura" on public.plan_limits
  for select to anon, authenticated using (true);
revoke insert, update, delete on public.domains, public.plan_limits from anon, authenticated;

-- Conceptos: se crean solo por el endpoint de captura (límite diario y embedding).
-- El usuario lee, corrige el texto o la categoría, confirma borradores y borra.
create policy "concepts: leer los propios" on public.concepts
  for select to authenticated using (user_id = (select auth.uid()));
create policy "concepts: editar los propios" on public.concepts
  for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "concepts: borrar los propios" on public.concepts
  for delete to authenticated using (user_id = (select auth.uid()));
revoke insert, update on public.concepts from anon, authenticated;
revoke delete on public.concepts from anon;
grant update (title, thesis, domain, domain_confirmed, status) on public.concepts to authenticated;

-- Chispas: las genera el servidor. El usuario las lee y solo cambia estado y motivo.
create policy "sparks: leer las propias" on public.sparks
  for select to authenticated using (user_id = (select auth.uid()));
create policy "sparks: responder las propias" on public.sparks
  for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
revoke insert, update, delete on public.sparks from anon, authenticated;
grant update (status, feedback) on public.sparks to authenticated;

-- Uso: cada uno ve el suyo, para mostrar cuánto le queda.
create policy "usage_ledger: leer el propio" on public.usage_ledger
  for select to authenticated using (user_id = (select auth.uid()));
revoke insert, update, delete on public.usage_ledger from anon, authenticated;

-- llm_calls: sin políticas. Con RLS activado, solo service role la lee y escribe.
revoke all on public.llm_calls from anon, authenticated;

-- Sin sesión no se toca nada de lo del usuario.
revoke all on public.profiles, public.concepts, public.sparks, public.usage_ledger from anon;

-- ---------------------------------------------------------------
-- Candidatos para la chispa (se implementa en el paso 28).
-- $1 = user_id, $2 = distancia objetivo del usuario.
-- ---------------------------------------------------------------
-- select a.id as lo, b.id as hi, (a.embedding <=> b.embedding) as dist
-- from public.concepts a
-- join public.concepts b
--   on b.user_id = a.user_id and a.id < b.id and a.domain <> b.domain
-- where a.user_id = $1
--   and a.status = 'ready' and b.status = 'ready'
--   and a.embedding is not null and b.embedding is not null
--   and coalesce(a.last_used_at, 'epoch') < now() - interval '3 days'
--   and coalesce(b.last_used_at, 'epoch') < now() - interval '3 days'
--   and not exists (
--     select 1 from public.sparks s
--     where s.user_id = $1 and s.concept_lo = a.id and s.concept_hi = b.id)
-- order by abs((a.embedding <=> b.embedding) - $2)
-- limit 20;
