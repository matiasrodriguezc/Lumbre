-- Waitlist de la landing con referidos (paso 5) y demo web de la chispa (paso 6).
--
-- - Solo se guarda el email (más el código de referido, quién lo refirió y las UTM de la campaña).
-- - Cada persona tiene dos tokens, de los que acá se guarda solo el sha256:
--   el de su página de la fila ("estás en el puesto N"), que vuelve al navegador al anotarse, y el de confirmación,
--   que viaja solo por email. Confirmar exige el segundo: así nadie confirma un email ajeno.
--   Los dos sirven para ver la fila y para salir de ella.
-- - La fila se ordena por orden de llegada; cada referido confirmado sube `waitlist_referral_boost` puestos.
-- - La demo no guarda las ideas que pega la persona ni la chispa: solo que ese email ya usó la de hoy.
-- - Límites anti-abuso por IP y por email en `web_rate_limits` (la IP llega hasheada con sal desde la función).
-- Todo es solo service role: la web habla con las Edge Functions `waitlist` y `demo-spark`, nunca con la base.

-- ---------------------------------------------------------------
-- Configuración (se cambia sin publicar versión)
-- ---------------------------------------------------------------
insert into public.app_config (key, value, description) values
  ('web_waitlist_enabled', 'true', 'Flag de la waitlist de la landing. En false, /waitlist responde disabled.'),
  ('web_demo_enabled', 'true', 'Flag de la demo web de la chispa. En false, /demo-spark responde disabled.'),
  ('web_demo_daily_max', '500', 'Chispas de la demo web por día (Buenos Aires) para todo Lumbre.'),
  ('waitlist_referral_boost', '10', 'Puestos que sube en la fila cada referido confirmado.')
on conflict (key) do nothing;

create or replace function public.app_config_value(p_key text, p_default jsonb)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select value from public.app_config where key = p_key), p_default);
$$;

revoke execute on function public.app_config_value(text, jsonb) from public, anon, authenticated;
grant execute on function public.app_config_value(text, jsonb) to service_role;

-- ---------------------------------------------------------------
-- Waitlist
-- ---------------------------------------------------------------
create table public.waitlist (
  id uuid primary key default gen_random_uuid(),
  -- Orden de llegada: es la base de la posición en la fila.
  seq bigint generated always as identity unique,
  email text not null unique
    check (email = lower(btrim(email)) and length(email) between 6 and 254 and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  referral_code text not null unique check (referral_code ~ '^[a-z2-9]{7}$'),
  -- sha256 (hex) del token de la página de la fila (lo tiene el navegador).
  token_hash text not null unique check (token_hash ~ '^[0-9a-f]{64}$'),
  -- sha256 (hex) del token de confirmación (solo viaja por email).
  confirm_hash text not null unique check (confirm_hash ~ '^[0-9a-f]{64}$'),
  referred_by uuid references public.waitlist (id) on delete set null,
  -- Referidos que confirmaron su email. Solo esos suben puestos.
  referrals_count int not null default 0 check (referrals_count >= 0),
  locale text not null default 'es' check (locale in ('es', 'en')),
  source text not null default 'landing' check (source in ('landing', 'demo')),
  utm_source text check (length(utm_source) <= 100),
  utm_medium text check (length(utm_medium) <= 100),
  utm_campaign text check (length(utm_campaign) <= 100),
  confirmed_at timestamptz,
  created_at timestamptz not null default now()
);

create index waitlist_referred_by_idx on public.waitlist (referred_by);
create index waitlist_unconfirmed_idx on public.waitlist (created_at) where confirmed_at is null;

alter table public.waitlist enable row level security;
revoke all on public.waitlist from anon, authenticated;

-- Código de referido: 7 caracteres sin los que se confunden (0/o, 1/l/i).
create or replace function public.waitlist_new_code()
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  alphabet constant text := 'abcdefghjkmnpqrstuvwxyz23456789';
  bytes bytea;
  code text;
begin
  loop
    bytes := extensions.gen_random_bytes(7);
    code := '';
    for i in 0..6 loop
      code := code || substr(alphabet, 1 + (get_byte(bytes, i) % length(alphabet)), 1);
    end loop;
    exit when not exists (select 1 from public.waitlist where referral_code = code);
  end loop;
  return code;
end;
$$;

revoke execute on function public.waitlist_new_code() from public, anon, authenticated;
grant execute on function public.waitlist_new_code() to service_role;

-- Puesto en la fila: 1 + cuántos van antes. Va antes quien tiene menor (seq − referidos × boost), y a igualdad, quien llegó antes.
create or replace function public.waitlist_position(p_id uuid)
returns int
language sql
stable
security definer
set search_path = ''
as $$
  with b as (select (public.app_config_value('waitlist_referral_boost', '10') #>> '{}')::int as boost),
  me as (select w.seq, w.seq - w.referrals_count * b.boost as score from public.waitlist w, b where w.id = p_id)
  select case when (select count(*) from me) = 0 then null else
    1 + (select count(*)::int from public.waitlist w, b, me
          where (w.seq - w.referrals_count * b.boost, w.seq) < (me.score, me.seq))
  end;
$$;

revoke execute on function public.waitlist_position(uuid) from public, anon, authenticated;
grant execute on function public.waitlist_position(uuid) to service_role;

-- Lo que ve la persona en su página de la fila. Nunca el email completo.
create type public.waitlist_entry as (
  id uuid,
  created boolean,
  referral_code text,
  "position" int,
  total int,
  referrals int,
  confirmed boolean
);

create or replace function public.waitlist_entry_of(p_id uuid, p_created boolean)
returns public.waitlist_entry
language sql
stable
security definer
set search_path = ''
as $$
  select row(w.id, p_created, w.referral_code, public.waitlist_position(w.id),
             (select count(*)::int from public.waitlist), w.referrals_count, w.confirmed_at is not null)::public.waitlist_entry
  from public.waitlist w where w.id = p_id;
$$;

revoke execute on function public.waitlist_entry_of(uuid, boolean) from public, anon, authenticated;
grant execute on function public.waitlist_entry_of(uuid, boolean) to service_role;

-- Anotarse. Si el email ya estaba, devuelve su fila con created = false y no cambia nada
-- (la función decide si le reenvía el link con waitlist_rotate_confirm).
create or replace function public.waitlist_join(
  p_email text,
  p_token_hash text,
  p_confirm_hash text,
  p_referral_code text default null,
  p_locale text default 'es',
  p_source text default 'landing',
  p_utm_source text default null,
  p_utm_medium text default null,
  p_utm_campaign text default null
)
returns public.waitlist_entry
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_email text := lower(btrim(p_email));
  v_id uuid;
  v_referrer uuid;
begin
  select id into v_id from public.waitlist where email = v_email;
  if v_id is not null then
    return public.waitlist_entry_of(v_id, false);
  end if;

  if p_referral_code is not null then
    select id into v_referrer from public.waitlist where referral_code = lower(btrim(p_referral_code));
  end if;

  insert into public.waitlist (email, referral_code, token_hash, confirm_hash, referred_by, locale, source, utm_source, utm_medium, utm_campaign)
  values (v_email, public.waitlist_new_code(), p_token_hash, p_confirm_hash, v_referrer,
          case when p_locale = 'en' then 'en' else 'es' end,
          case when p_source = 'demo' then 'demo' else 'landing' end,
          left(p_utm_source, 100), left(p_utm_medium, 100), left(p_utm_campaign, 100))
  on conflict (email) do nothing
  returning id into v_id;

  -- Dos altas simultáneas del mismo email: gana una, la otra ve la fila existente.
  if v_id is null then
    select id into v_id from public.waitlist where email = v_email;
    return public.waitlist_entry_of(v_id, false);
  end if;
  return public.waitlist_entry_of(v_id, true);
end;
$$;

revoke execute on function public.waitlist_join(text, text, text, text, text, text, text, text, text) from public, anon, authenticated;
grant execute on function public.waitlist_join(text, text, text, text, text, text, text, text, text) to service_role;

-- Link de email nuevo para alguien que ya estaba: cambia solo el token de confirmación
-- (el anterior deja de andar; la página de la fila abierta en su navegador sigue andando).
create or replace function public.waitlist_rotate_confirm(p_id uuid, p_confirm_hash text)
returns boolean
language sql
volatile
security definer
set search_path = ''
as $$
  update public.waitlist set confirm_hash = p_confirm_hash where id = p_id returning true;
$$;

revoke execute on function public.waitlist_rotate_confirm(uuid, text) from public, anon, authenticated;
grant execute on function public.waitlist_rotate_confirm(uuid, text) to service_role;

-- Estado por cualquiera de los dos tokens. Con p_confirm y el token del email, confirma (una sola vez)
-- y le suma el referido a quien lo invitó. Devuelve null si el token no existe.
create or replace function public.waitlist_status(p_token_hash text, p_confirm boolean default false)
returns public.waitlist_entry
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_referrer uuid;
begin
  if p_confirm then
    update public.waitlist set confirmed_at = now()
     where confirm_hash = p_token_hash and confirmed_at is null
    returning id, referred_by into v_id, v_referrer;
    if v_referrer is not null then
      update public.waitlist set referrals_count = referrals_count + 1 where id = v_referrer;
    end if;
  end if;
  if v_id is null then
    select id into v_id from public.waitlist where token_hash = p_token_hash or confirm_hash = p_token_hash;
  end if;
  if v_id is null then
    return null;
  end if;
  return public.waitlist_entry_of(v_id, false);
end;
$$;

revoke execute on function public.waitlist_status(text, boolean) from public, anon, authenticated;
grant execute on function public.waitlist_status(text, boolean) to service_role;

-- Salir de la fila: borra el email y todo lo suyo. Los puestos que ya regaló por referidos quedan.
create or replace function public.waitlist_leave(p_token_hash text)
returns boolean
language sql
volatile
security definer
set search_path = ''
as $$
  with gone as (delete from public.waitlist where token_hash = p_token_hash or confirm_hash = p_token_hash returning 1)
  select exists (select 1 from gone);
$$;

revoke execute on function public.waitlist_leave(text) from public, anon, authenticated;
grant execute on function public.waitlist_leave(text) to service_role;

-- ---------------------------------------------------------------
-- Límites anti-abuso de la web
-- ---------------------------------------------------------------
-- Ventana fija: una fila por (bucket, sujeto, inicio de la ventana). El sujeto es un hash (IP o email con sal).
create table public.web_rate_limits (
  bucket text not null,
  subject text not null,
  window_start timestamptz not null,
  hits int not null default 0,
  primary key (bucket, subject, window_start)
);

create index web_rate_limits_window_idx on public.web_rate_limits (window_start);

alter table public.web_rate_limits enable row level security;
revoke all on public.web_rate_limits from anon, authenticated;

-- Suma un intento y dice si entra en el límite. Atómico: el upsert bloquea la fila.
create or replace function public.web_rate_hit(p_bucket text, p_subject text, p_window_seconds int, p_max int)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_start timestamptz := to_timestamp(floor(extract(epoch from now()) / p_window_seconds) * p_window_seconds);
  v_hits int;
begin
  insert into public.web_rate_limits as r (bucket, subject, window_start, hits)
  values (p_bucket, p_subject, v_start, 1)
  on conflict (bucket, subject, window_start) do update set hits = r.hits + 1
  returning hits into v_hits;
  return v_hits <= p_max;
end;
$$;

revoke execute on function public.web_rate_hit(text, text, int, int) from public, anon, authenticated;
grant execute on function public.web_rate_hit(text, text, int, int) to service_role;

-- ---------------------------------------------------------------
-- Demo web de la chispa
-- ---------------------------------------------------------------
-- Una por email y por día (Buenos Aires). No guarda las ideas ni la chispa.
create table public.demo_sparks (
  waitlist_id uuid not null references public.waitlist (id) on delete cascade,
  day date not null,
  created_at timestamptz not null default now(),
  primary key (waitlist_id, day)
);

create index demo_sparks_day_idx on public.demo_sparks (day);

alter table public.demo_sparks enable row level security;
revoke all on public.demo_sparks from anon, authenticated;

create or replace function public.demo_today()
returns date
language sql
stable
set search_path = ''
as $$
  select (now() at time zone 'America/Argentina/Buenos_Aires')::date;
$$;

-- Reserva la chispa de hoy para ese email: 'ok', 'used' (ya la usó hoy) o 'full' (se llegó al máximo del día).
create or replace function public.demo_spark_claim(p_waitlist_id uuid)
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_day date := public.demo_today();
  v_max int := (public.app_config_value('web_demo_daily_max', '500') #>> '{}')::int;
  v_inserted int;
begin
  -- Serializa las reservas del día para que el máximo global no se pase con pedidos simultáneos.
  perform pg_advisory_xact_lock(hashtext('demo_spark_claim'), (v_day - date '2000-01-01'));
  if (select count(*) from public.demo_sparks where day = v_day) >= v_max then
    return 'full';
  end if;
  insert into public.demo_sparks (waitlist_id, day) values (p_waitlist_id, v_day)
  on conflict do nothing;
  get diagnostics v_inserted = row_count;
  return case when v_inserted = 1 then 'ok' else 'used' end;
end;
$$;

revoke execute on function public.demo_spark_claim(uuid) from public, anon, authenticated;
grant execute on function public.demo_spark_claim(uuid) to service_role;

-- Si la IA falla después de reservar, se devuelve la chispa del día.
create or replace function public.demo_spark_release(p_waitlist_id uuid)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  delete from public.demo_sparks where waitlist_id = p_waitlist_id and day = public.demo_today();
$$;

revoke execute on function public.demo_spark_release(uuid) from public, anon, authenticated;
grant execute on function public.demo_spark_release(uuid) to service_role;

-- ---------------------------------------------------------------
-- Limpieza diaria
-- ---------------------------------------------------------------
-- Ventanas de límites vencidas, chispas de la demo de hace más de 30 días y emails que nunca se confirmaron
-- en 30 días (pudo anotarlos otra persona: no se guardan sin confirmar).
create or replace function public.cleanup_web()
returns int
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_total int := 0;
  v_n int;
begin
  delete from public.web_rate_limits where window_start < now() - interval '2 days';
  get diagnostics v_n = row_count; v_total := v_total + v_n;
  delete from public.demo_sparks where day < public.demo_today() - 30;
  get diagnostics v_n = row_count; v_total := v_total + v_n;
  delete from public.waitlist where confirmed_at is null and created_at < now() - interval '30 days';
  get diagnostics v_n = row_count; v_total := v_total + v_n;
  return v_total;
end;
$$;

revoke execute on function public.cleanup_web() from public, anon, authenticated;
grant execute on function public.cleanup_web() to service_role;

select cron.schedule('limpiar-web', '37 6 * * *', $$ select public.cleanup_web() $$);
