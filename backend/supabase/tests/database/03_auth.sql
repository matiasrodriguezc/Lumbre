-- Auth: perfil automático al registrarse, vinculación de invitados y limpieza de invitados abandonados.
begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

select has_trigger('auth', 'users', 'on_auth_user_created', 'auth.users tiene el trigger que crea el perfil');

-- ---------------------------------------------------------------
-- Perfil al registrarse
-- ---------------------------------------------------------------
insert into auth.users (id, email, aud, role, raw_user_meta_data) values
  ('e0000000-0000-4000-8000-000000000001', 'sin-datos@auth.test', 'authenticated', 'authenticated', '{}'),
  ('e0000000-0000-4000-8000-000000000002', 'con-datos@auth.test', 'authenticated', 'authenticated',
   '{"timezone": "America/Mexico_City", "locale": "en-US"}'),
  ('e0000000-0000-4000-8000-000000000003', 'datos-malos@auth.test', 'authenticated', 'authenticated',
   '{"timezone": "Marte/Olympus", "locale": "fr"}');

select results_eq(
  $$ select timezone, locale, plan from public.profiles where id = 'e0000000-0000-4000-8000-000000000001' $$,
  $$ values ('America/Argentina/Buenos_Aires', 'es', 'free') $$,
  'sin metadatos: perfil con los valores por defecto');
select results_eq(
  $$ select timezone, locale from public.profiles where id = 'e0000000-0000-4000-8000-000000000002' $$,
  $$ values ('America/Mexico_City', 'en') $$,
  'con metadatos: usa la zona horaria y el idioma del teléfono');
select results_eq(
  $$ select timezone, locale from public.profiles where id = 'e0000000-0000-4000-8000-000000000003' $$,
  $$ values ('America/Argentina/Buenos_Aires', 'es') $$,
  'con metadatos inválidos: cae a los valores por defecto');

-- ---------------------------------------------------------------
-- Invitado que después crea su cuenta
-- ---------------------------------------------------------------
insert into auth.users (id, aud, role, is_anonymous)
values ('e0000000-0000-4000-8000-000000000010', 'authenticated', 'authenticated', true);
insert into public.domains (slug, name_es, name_en, description)
values ('auth_test', 'Prueba', 'Test', 'Dominio de los tests de auth.');
insert into public.concepts (user_id, domain, title, thesis, source_type)
values ('e0000000-0000-4000-8000-000000000010', 'auth_test', 'Idea de invitado', 'La guardó antes de crear la cuenta.', 'text');

select ok(exists (select 1 from public.profiles where id = 'e0000000-0000-4000-8000-000000000010'),
  'invitado: también tiene perfil');
select is(public.effective_plan('e0000000-0000-4000-8000-000000000010'), 'guest', 'invitado: plan guest');

-- Vincular una identidad deja el mismo usuario con is_anonymous = false.
update auth.users set is_anonymous = false, email = 'ya-no-invitado@auth.test'
 where id = 'e0000000-0000-4000-8000-000000000010';

select is(public.effective_plan('e0000000-0000-4000-8000-000000000010'), 'free', 'al crear la cuenta pasa a free');
select is((select count(*)::int from public.concepts where user_id = 'e0000000-0000-4000-8000-000000000010'), 1,
  'al crear la cuenta conserva lo que guardó como invitado');

-- ---------------------------------------------------------------
-- Limpieza de invitados abandonados
-- ---------------------------------------------------------------
insert into auth.users (id, aud, role, is_anonymous, created_at) values
  ('e0000000-0000-4000-8000-000000000020', 'authenticated', 'authenticated', true, now() - interval '40 days'),
  ('e0000000-0000-4000-8000-000000000021', 'authenticated', 'authenticated', true, now() - interval '40 days'),
  ('e0000000-0000-4000-8000-000000000022', 'authenticated', 'authenticated', true, now() - interval '5 days'),
  ('e0000000-0000-4000-8000-000000000023', 'authenticated', 'authenticated', false, now() - interval '90 days');
-- El 21 es viejo pero volvió hace 2 días.
insert into auth.sessions (id, user_id, created_at, updated_at, refreshed_at)
values (gen_random_uuid(), 'e0000000-0000-4000-8000-000000000021',
        now() - interval '40 days', now() - interval '2 days', (now() - interval '2 days')::timestamp);
insert into public.concepts (user_id, domain, title, thesis, source_type)
values ('e0000000-0000-4000-8000-000000000020', 'auth_test', 'Abandonado', 'Nadie volvió por esto.', 'text');

select public.cleanup_abandoned_guests();

select ok(not exists (select 1 from auth.users where id = 'e0000000-0000-4000-8000-000000000020'),
  'limpieza: borra al invitado sin actividad en 30 días');
select ok(not exists (select 1 from public.concepts where user_id = 'e0000000-0000-4000-8000-000000000020'),
  'limpieza: con el usuario se van sus conceptos');
select ok(exists (select 1 from auth.users where id = 'e0000000-0000-4000-8000-000000000021'),
  'limpieza: no borra a un invitado viejo que volvió hace poco');
select ok(exists (select 1 from auth.users where id = 'e0000000-0000-4000-8000-000000000022'),
  'limpieza: no borra a un invitado nuevo');
select ok(exists (select 1 from auth.users where id = 'e0000000-0000-4000-8000-000000000023'),
  'limpieza: nunca borra una cuenta real por inactividad');

select is((select schedule from cron.job where jobname = 'limpiar-invitados'), '17 6 * * *',
  'la limpieza está programada todos los días');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub": "e0000000-0000-4000-8000-000000000001", "role": "authenticated"}', true);
select throws_ok($$ select public.cleanup_abandoned_guests() $$, '42501', null,
  'cleanup_abandoned_guests: la app no puede llamarla');
reset role;

select * from finish();
rollback;
