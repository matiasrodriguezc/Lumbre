-- Consentimiento para la IA de terceros (profiles.ai_consent_at): lo edita solo la persona, la fecha la pone el
-- servidor y sin él el batch nocturno no le genera la chispa diaria.
begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (id, email, aud, role) values
  ('11000000-0000-4000-8000-000000000001', 'a@consentimiento.test', 'authenticated', 'authenticated'),
  ('11000000-0000-4000-8000-000000000002', 'b@consentimiento.test', 'authenticated', 'authenticated');

-- Los dos con un concepto listo y con vector: lo único que los separa para el batch es el consentimiento.
insert into public.concepts (user_id, domain, title, thesis, source_type, status, embedding, embedding_model)
select id, 'cocina', 'C', 'Tesis.', 'text', 'ready',
       (array[1::float8] || array_fill(0::float8, array[1023]))::extensions.vector(1024), 'test'
from auth.users where email like '%@consentimiento.test';

create function pg_temp.login(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
$$;
grant execute on function pg_temp.login(uuid) to authenticated;

select is((select ai_consent_at from public.profiles where id = '11000000-0000-4000-8000-000000000001'), null,
  'perfil nuevo: sin consentimiento');
select ok(not exists (select 1 from public.users_needing_daily_spark(100000) where user_id = '11000000-0000-4000-8000-000000000001'),
  'batch nocturno: sin consentimiento no recibe la diaria');

-- ---------------------------------------------------------------
-- Como A
-- ---------------------------------------------------------------
set local role authenticated;
select pg_temp.login('11000000-0000-4000-8000-000000000001');

select lives_ok($$ update public.profiles set ai_consent_at = '2001-01-01T00:00:00Z' where id = auth.uid() $$,
  'A acepta desde la app');
select ok((select ai_consent_at from public.profiles where id = auth.uid()) > now() - interval '1 minute',
  'la fecha es la del servidor, no la que mandó el teléfono');

-- Volver a mandar el "Acepto" no cambia la fecha.
select set_config('test.first_consent', (select ai_consent_at::text from public.profiles where id = auth.uid()), true);
update public.profiles set ai_consent_at = now() + interval '1 day' where id = auth.uid();
select is((select ai_consent_at from public.profiles where id = auth.uid()), current_setting('test.first_consent')::timestamptz,
  'aceptar otra vez conserva la primera fecha');

-- A no toca el de B.
update public.profiles set ai_consent_at = now() where id = '11000000-0000-4000-8000-000000000002';
reset role;
select is((select ai_consent_at from public.profiles where id = '11000000-0000-4000-8000-000000000002'), null,
  'A no puede aceptar por B (RLS)');
select ok(exists (select 1 from public.users_needing_daily_spark(100000) where user_id = '11000000-0000-4000-8000-000000000001'),
  'batch nocturno: con consentimiento recibe la diaria');
select ok(not exists (select 1 from public.users_needing_daily_spark(100000) where user_id = '11000000-0000-4000-8000-000000000002'),
  'batch nocturno: B sigue afuera');

-- Revocar.
set local role authenticated;
select pg_temp.login('11000000-0000-4000-8000-000000000001');
select lives_ok($$ update public.profiles set ai_consent_at = null where id = auth.uid() $$, 'A revoca desde la app');
reset role;
select is((select ai_consent_at from public.profiles where id = '11000000-0000-4000-8000-000000000001'), null,
  'revocar deja la columna en null');
select ok(not exists (select 1 from public.users_needing_daily_spark(100000) where user_id = '11000000-0000-4000-8000-000000000001'),
  'batch nocturno: después de revocar no recibe la diaria');

-- Sin sesión no se toca.
set local role anon;
select throws_ok($$ update public.profiles set ai_consent_at = now() $$, '42501', null,
  'anon no puede editar el consentimiento');
reset role;

select * from finish();
rollback;
