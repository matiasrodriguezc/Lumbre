-- Lumbre: esquema base (Supabase / Postgres + pgvector)
-- Referencia de diseño, no migración final. Revisar tipos, índices y políticas antes de producción.

create extension if not exists vector;

-- ---------------------------------------------------------------
-- Perfiles
-- ---------------------------------------------------------------
create table profiles (
  id uuid primary key references auth.users on delete cascade,
  creative_profiles text[] not null default '{}',   -- hasta 2: software, contenido, negocios, diseño, curiosidad
  spark_hour time not null default '08:00',
  timezone text not null default 'America/Argentina/Buenos_Aires',
  locale text not null default 'es',
  plan text not null default 'free',                 -- lo actualiza solo el webhook de RevenueCat
  target_distance real,                              -- distancia objetivo del usuario, calibrada con feedback
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- Dominios: lista cerrada (20–25). El embedding de la descripción
-- sirve para clasificar conceptos sin destilar.
-- ---------------------------------------------------------------
create table domains (
  slug text primary key,                 -- 'tecnologia', 'biologia', 'fisica', ...
  name_es text not null,
  name_en text not null,
  description text not null,
  embedding vector(1024),                -- mismo modelo que los conceptos
  embedding_model text
);

-- ---------------------------------------------------------------
-- Conceptos: lo único que se guarda de cada captura.
-- Nunca archivos: audios, PDFs, videos y páginas se borran tras procesar.
-- ---------------------------------------------------------------
create table concepts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  domain text not null references domains(slug),
  domain_confirmed boolean not null default false,  -- el usuario confirmó la sugerencia
  title text not null,
  thesis text not null,
  principle text,                                   -- null si no se destiló
  embedding vector(1024),                           -- la dimensión depende del modelo elegido
  embedding_model text not null,                    -- para re-embeber si se cambia de modelo
  distilled boolean not null default false,
  confidence text check (confidence in ('high','medium','low')),
  status text not null default 'ready' check (status in ('draft','ready')),
  source_type text not null check (source_type in ('text','voice','selection','screenshot','scan','link','image','pdf','audio','video','import')),
  source_url text,
  source_title text,
  excerpt text check (char_length(excerpt) <= 500), -- fragmento subrayado por el usuario
  raw_text text,                                    -- se borra a los 30 días (job de pg_cron)
  raw_text_expires_at timestamptz,
  local_asset_id text,                              -- referencia a la foto en el teléfono
  is_guest boolean not null default false,          -- concepto invitado de la biblioteca curada
  last_used_at timestamptz,                         -- para el descanso de 3 días
  created_at timestamptz not null default now()
);
create index concepts_user_idx on concepts (user_id, domain);
create index concepts_url_idx on concepts (user_id, source_url) where source_url is not null; -- duplicados

-- ---------------------------------------------------------------
-- Chispas: el par nunca se repite (ordenado lo < hi).
-- ---------------------------------------------------------------
create table sparks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  concept_lo uuid not null references concepts(id) on delete cascade,
  concept_hi uuid not null references concepts(id) on delete cascade,
  mode text not null default 'daily' check (mode in ('daily','extra','pick','problem')),
  distance real,
  title text,
  body text,
  status text not null default 'pending' check (status in ('pending','revealed','saved','discarded')),
  feedback text check (feedback in ('obvious','irrelevant','already_had')),
  scheduled_for date,
  created_at timestamptz not null default now(),
  unique (user_id, concept_lo, concept_hi),
  check (concept_lo < concept_hi)
);

-- ---------------------------------------------------------------
-- Cuotas
-- ---------------------------------------------------------------
create table plan_limits (
  plan text not null,                    -- 'free' | 'pro'
  kind text not null,                    -- 'capture' | 'distill' | 'spark_extra' | 'planner' | 'planner_deep'
  period text not null check (period in ('day','month')),
  max_count int not null,
  primary key (plan, kind, period)
);

insert into plan_limits values
  ('free','capture','day',30),
  ('free','distill','month',5),
  ('free','spark_extra','day',2),
  ('pro','capture','day',200),
  ('pro','distill','month',300),
  ('pro','spark_extra','day',10),
  ('pro','planner','month',300),
  ('pro','planner_deep','month',60);

create table usage_ledger (
  user_id uuid not null references auth.users on delete cascade,
  kind text not null,
  period text not null,
  period_start date not null,
  used int not null default 0,
  primary key (user_id, kind, period, period_start)
);

-- Descuenta un crédito de forma atómica. Devuelve true si había cupo.
-- El período se calcula en la zona horaria del usuario.
-- Si un tipo no tiene fila en plan_limits para ese plan, no hay cupo.
create or replace function consume_credit(p_user uuid, p_kind text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plan text;
  v_tz text;
  r record;
  v_start date;
  v_ok int;
  v_found boolean := false;
begin
  select plan, timezone into v_plan, v_tz from profiles where id = p_user;

  for r in select period, max_count from plan_limits where plan = v_plan and kind = p_kind loop
    v_found := true;
    v_start := date_trunc(r.period, now() at time zone v_tz)::date;

    insert into usage_ledger (user_id, kind, period, period_start)
    values (p_user, p_kind, r.period, v_start)
    on conflict do nothing;

    v_ok := null;
    update usage_ledger
       set used = used + 1
     where user_id = p_user and kind = p_kind and period = r.period
       and period_start = v_start and used < r.max_count
    returning 1 into v_ok;

    if v_ok is null then
      raise exception 'quota_exceeded';  -- revierte los descuentos previos de este llamado
    end if;
  end loop;

  return v_found;
exception when raise_exception then
  return false;
end;
$$;

-- ---------------------------------------------------------------
-- Registro de llamadas a modelos (tablero de costos y alertas)
-- ---------------------------------------------------------------
create table llm_calls (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users on delete set null,
  feature text not null,                 -- 'distill' | 'spark' | 'planner' | ...
  model text not null,
  input_tokens int, cached_tokens int, output_tokens int,
  cost_usd numeric(10,6),
  latency_ms int,
  batch boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- Row Level Security: cada usuario ve solo lo suyo
-- ---------------------------------------------------------------
alter table profiles enable row level security;
alter table concepts enable row level security;
alter table sparks enable row level security;
alter table usage_ledger enable row level security;

create policy "own profile read" on profiles for select using (id = auth.uid());
create policy "own profile update" on profiles for update using (id = auth.uid()) with check (id = auth.uid());
revoke update (plan) on profiles from authenticated;  -- plan solo lo escribe el webhook (service role)
create policy "own concepts" on concepts for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own sparks" on sparks for select using (user_id = auth.uid());
create policy "own sparks feedback" on sparks for update using (user_id = auth.uid());
create policy "own usage" on usage_ledger for select using (user_id = auth.uid());
-- plan_limits y domains: lectura pública. llm_calls: solo service role.

-- ---------------------------------------------------------------
-- Candidatos para la chispa de mañana (lo corre el batch nocturno)
-- $1 = user_id, $2 = distancia objetivo del usuario
-- ---------------------------------------------------------------
-- select a.id as lo, b.id as hi, (a.embedding <=> b.embedding) as dist
-- from concepts a
-- join concepts b
--   on b.user_id = a.user_id and a.id < b.id and a.domain <> b.domain
-- where a.user_id = $1
--   and a.status = 'ready' and b.status = 'ready'
--   and coalesce(a.last_used_at, 'epoch') < now() - interval '3 days'
--   and coalesce(b.last_used_at, 'epoch') < now() - interval '3 days'
--   and not exists (
--     select 1 from sparks s
--     where s.user_id = $1 and s.concept_lo = a.id and s.concept_hi = b.id)
-- order by abs((a.embedding <=> b.embedding) - $2)
-- limit 20;
--
-- Nota: los conceptos invitados viven en una biblioteca aparte y se copian
-- al usuario (is_guest = true) solo cuando se usan, para que el par quede registrado.
