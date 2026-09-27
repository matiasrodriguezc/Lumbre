-- Auth: perfil automático al registrarse y limpieza de invitados abandonados.

-- ---------------------------------------------------------------
-- Perfil al registrarse
-- ---------------------------------------------------------------
-- Se crea para todo usuario nuevo, incluidos los invitados (sesión anónima).
-- La app manda la zona horaria y el idioma del teléfono en los metadatos del alta:
--   signInAnonymously / signInWithOtp / signInWithIdToken con data: { timezone, locale }.
-- Si faltan o no son válidos, quedan los defaults del perfil.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_timezone text := new.raw_user_meta_data ->> 'timezone';
  v_locale text := lower(left(new.raw_user_meta_data ->> 'locale', 2));
begin
  if v_timezone is null or not exists (select 1 from pg_catalog.pg_timezone_names where name = v_timezone) then
    v_timezone := 'America/Argentina/Buenos_Aires';
  end if;
  if v_locale is null or v_locale not in ('es', 'en') then
    v_locale := 'es';
  end if;

  insert into public.profiles (id, timezone, locale)
  values (new.id, v_timezone, v_locale)
  on conflict (id) do nothing;
  return new;
end;
$$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Vincular una cuenta (email, Apple o Google) a un invitado no crea un usuario nuevo:
-- el mismo auth.users pasa a is_anonymous = false y conserva su perfil, conceptos y chispas.
-- effective_plan() lo pasa de guest a free sin tocar nada más.

-- ---------------------------------------------------------------
-- Limpieza de invitados abandonados
-- ---------------------------------------------------------------
-- Un invitado sin sesión activa en 30 días se borra con todo lo suyo (cascade).
-- Solo invitados: una cuenta real nunca se borra por inactividad.
create or replace function public.cleanup_abandoned_guests(p_inactive interval default interval '30 days')
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_deleted int;
begin
  delete from auth.users u
   where u.is_anonymous
     and u.created_at < now() - p_inactive
     and not exists (
       select 1 from auth.sessions s
        where s.user_id = u.id
          and coalesce(s.refreshed_at::timestamptz, s.updated_at, s.created_at) > now() - p_inactive
     );
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

revoke execute on function public.cleanup_abandoned_guests(interval) from public, anon, authenticated;
grant execute on function public.cleanup_abandoned_guests(interval) to service_role;

create extension if not exists pg_cron with schema pg_catalog;

-- Todos los días a las 06:17 UTC (03:17 en Argentina), fuera del horario de las chispas.
select cron.schedule('limpiar-invitados', '17 6 * * *', $$ select public.cleanup_abandoned_guests() $$);
