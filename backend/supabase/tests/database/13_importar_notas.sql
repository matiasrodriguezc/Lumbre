-- Importar notas (paso 89): capture_concept() con p_import_source cuenta como captura del día y, en free y como
-- invitado, gasta además el cupo 'import' de 50 notas en total. Pro no tiene ese cupo.
begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

insert into auth.users (id, email, aud, role) values
  ('12000000-0000-4000-8000-000000000001', 'free@importar.test', 'authenticated', 'authenticated'),
  ('12000000-0000-4000-8000-000000000002', 'pro@importar.test', 'authenticated', 'authenticated');
update public.profiles set plan = 'pro' where id = '12000000-0000-4000-8000-000000000002';

create function pg_temp.login(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
$$;
grant execute on function pg_temp.login(uuid) to authenticated;

create function pg_temp.used(p_user uuid, p_kind text) returns int language sql as $$
  select coalesce(sum(used), 0)::int from public.usage_ledger where user_id = p_user and kind = p_kind;
$$;

select results_eq(
  $$ select plan, period, max_count from public.plan_limits where kind = 'import' order by plan $$,
  $$ values ('free'::text, 'total'::text, 50), ('guest', 'total', 50) $$,
  'import: 50 en total en free y como invitado; Pro no tiene tope'
);

-- ---------------------------------------------------------------
-- Free
-- ---------------------------------------------------------------
set local role authenticated;
select pg_temp.login('12000000-0000-4000-8000-000000000001');

select lives_ok($$ select public.capture_concept('Separación ciclónica', 'Ingeniería', 'text', null, null, 'Un flujo en espiral.', null, 'markdown') $$,
  'free: importa una nota de Markdown');
select throws_ok($$ select public.capture_concept('Un link', 'Ingeniería', 'link', 'https://ejemplo.com', p_import_source => 'markdown') $$,
  '22023', 'invalid_source', 'una nota importada es texto');
select throws_ok($$ select public.capture_concept('Otra', 'Ingeniería', p_import_source => 'notion') $$,
  '22023', 'invalid_source', 'solo markdown y apple_notes');
reset role;

select is((select import_source from public.concepts where thesis = 'Separación ciclónica'), 'markdown',
  'la neurona guarda de dónde vino');
select is((select excerpt from public.concepts where thesis = 'Separación ciclónica'), 'Un flujo en espiral.',
  'y su fragmento');
select is(pg_temp.used('12000000-0000-4000-8000-000000000001', 'capture'), 1, 'importar cuenta como captura del día');
select is(pg_temp.used('12000000-0000-4000-8000-000000000001', 'import'), 1, 'y gasta el cupo de importación');

-- Le queda 1 del cupo de importación.
update public.usage_ledger set used = 49
 where user_id = '12000000-0000-4000-8000-000000000001' and kind = 'import';
set local role authenticated;
select pg_temp.login('12000000-0000-4000-8000-000000000001');
select lives_ok($$ select public.capture_concept('La nota 50', 'Notas', p_import_source => 'apple_notes') $$,
  'free: la nota 50 entra');
select throws_ok($$ select public.capture_concept('La nota 51', 'Notas', p_import_source => 'apple_notes') $$,
  'P0001', 'import_limit', 'free: la 51 se rechaza con import_limit');
reset role;
select is(pg_temp.used('12000000-0000-4000-8000-000000000001', 'capture'), 2,
  'la importación rechazada no gasta la captura del día');

-- Sin capturas hoy, tampoco entra una importada: queda para mañana (quota_exceeded).
update public.usage_ledger set used = 30
 where user_id = '12000000-0000-4000-8000-000000000001' and kind = 'capture';
update public.usage_ledger set used = 0
 where user_id = '12000000-0000-4000-8000-000000000001' and kind = 'import';
set local role authenticated;
select pg_temp.login('12000000-0000-4000-8000-000000000001');
select throws_ok($$ select public.capture_concept('Mañana', 'Notas', p_import_source => 'markdown') $$,
  'P0001', 'quota_exceeded', 'con el tope del día lleno, la importada espera a mañana');
reset role;

-- ---------------------------------------------------------------
-- Pro: sin cupo de importación
-- ---------------------------------------------------------------
set local role authenticated;
select pg_temp.login('12000000-0000-4000-8000-000000000002');
select is((select count(*)::int from (select public.capture_concept('Nota Pro ' || g, 'Notas', p_import_source => 'apple_notes')
                                        from generate_series(1, 3) g) x), 3, 'pro: importa sin cupo de importación');
reset role;
select is(pg_temp.used('12000000-0000-4000-8000-000000000002', 'import'), 0, 'pro: no descuenta import');
select is(pg_temp.used('12000000-0000-4000-8000-000000000002', 'capture'), 3, 'pro: sí cuenta las capturas del día');
select * from finish();
rollback;
