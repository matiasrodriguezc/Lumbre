-- Integridad del dispositivo (paso 40), límites anti-abuso (paso 62) y limpieza de adjuntos temporales (paso 34).
-- Todo es solo del servidor: la app no ve estas tablas ni estas funciones.

-- ---------------------------------------------------------------
-- App Attest: claves atestiguadas
-- ---------------------------------------------------------------
-- Una fila por clave del Secure Enclave (una por instalación de la app). La escribe la guarda de las Edge Functions
-- (_shared/attest/guard.ts) al verificar la atestación; cada aserción sube sign_count (una repetida no pasa).
-- user_id es el último usuario que la usó: una clave no queda atada a una cuenta (se puede cerrar sesión y entrar con otra).
create table public.attest_keys (
  key_id text primary key check (char_length(key_id) between 1 and 200),
  platform text not null default 'ios' check (platform in ('ios')),
  user_id uuid references auth.users on delete set null,
  -- Clave pública de la hoja (SPKI, base64).
  public_key text not null,
  sign_count bigint not null default 0 check (sign_count >= 0),
  environment text not null check (environment in ('production', 'development')),
  -- Recibo de Apple (base64), para pedir la métrica de fraude más adelante.
  receipt text,
  created_at timestamptz not null default now(),
  last_used_at timestamptz not null default now()
);

create index attest_keys_user_idx on public.attest_keys (user_id);

comment on table public.attest_keys is 'Claves de App Attest verificadas (paso 40). Solo service role.';

alter table public.attest_keys enable row level security;
revoke all on public.attest_keys from anon, authenticated;

-- ---------------------------------------------------------------
-- Límites de frecuencia (ventana fija)
-- ---------------------------------------------------------------
-- Para lo que no gasta un cupo de plan_limits pero igual cuesta (la búsqueda embebe cada consulta).
-- hit_rate_limit('search:<user>', 120, 3600) = hasta 120 por hora. Atómico: el upsert bloquea la fila.
create table public.rate_limits (
  key text not null,
  window_start timestamptz not null,
  hits int not null default 0,
  primary key (key, window_start)
);

alter table public.rate_limits enable row level security;
revoke all on public.rate_limits from anon, authenticated;

create or replace function public.hit_rate_limit(p_key text, p_max int, p_window_seconds int)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_start timestamptz := to_timestamp(floor(extract(epoch from now()) / p_window_seconds) * p_window_seconds);
  v_hits int;
begin
  insert into public.rate_limits as r (key, window_start, hits)
  values (p_key, v_start, 1)
  on conflict (key, window_start) do update set hits = r.hits + 1
  returning hits into v_hits;
  return v_hits <= p_max;
end;
$$;

revoke execute on function public.hit_rate_limit(text, int, int) from public, anon, authenticated;
grant execute on function public.hit_rate_limit(text, int, int) to service_role;

-- Ventanas viejas: se borran todos los días.
create or replace function public.purge_rate_limits()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count int;
begin
  delete from public.rate_limits where window_start < now() - interval '2 days';
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke execute on function public.purge_rate_limits() from public, anon, authenticated;
grant execute on function public.purge_rate_limits() to service_role;

select cron.schedule('limpiar-limites', '37 6 * * *', $$ select public.purge_rate_limits() $$);

-- ---------------------------------------------------------------
-- Adjuntos temporales que quedaron sin procesar
-- ---------------------------------------------------------------
-- /capture borra el adjunto siempre. Si la app lo subió y nunca llamó a /capture (se cerró, se quedó sin red),
-- /process lo encuentra acá y lo borra con la API de Storage (la base no deja borrar storage.objects directo).
create or replace function public.stale_capture_uploads(p_older_than interval default interval '1 hour', p_limit int default 500)
returns setof text
language sql
stable
security definer
set search_path = ''
as $$
  select o.name
  from storage.objects o
  where o.bucket_id = 'capture-temp'
    and o.created_at < now() - p_older_than
  order by o.created_at
  limit p_limit;
$$;

revoke execute on function public.stale_capture_uploads(interval, int) from public, anon, authenticated;
grant execute on function public.stale_capture_uploads(interval, int) to service_role;

-- El bucket temporal acepta hasta 20 MB (antes 50): es el máximo que se le manda al modelo (un PDF; una imagen,
-- 5 MB). Lo que pasa de eso no se destila, así que no tiene sentido subirlo. Provisorio: revisar con la app de iOS.
update storage.buckets set file_size_limit = 20971520 where id = 'capture-temp';
