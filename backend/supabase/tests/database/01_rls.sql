-- RLS: el usuario A no ve ni toca los datos de B, y nadie cambia lo que solo escribe el servidor.
-- Crea sus propios datos dentro de la transacción y la revierte al final: no depende del seed.
begin;
create extension if not exists pgtap with schema extensions;
select plan(35);

-- ---------------------------------------------------------------
-- Datos: X y Y, cada uno con su perfil, dos conceptos, una chispa y uso.
-- ---------------------------------------------------------------
insert into auth.users (id, email, aud, role) values
  ('aaaaaaaa-0000-4000-8000-000000000001', 'x@rls.test', 'authenticated', 'authenticated'),
  ('bbbbbbbb-0000-4000-8000-000000000002', 'y@rls.test', 'authenticated', 'authenticated');

insert into public.profiles (id, spark_hour) values
  ('aaaaaaaa-0000-4000-8000-000000000001', '08:00'),
  ('bbbbbbbb-0000-4000-8000-000000000002', '09:00');

insert into public.domains (slug, name_es, name_en, description)
values ('rls_test', 'Prueba', 'Test', 'Dominio de los tests de RLS.');

insert into public.concepts (id, user_id, domain, title, thesis, source_type) values
  ('aaaaaaaa-0000-4000-8000-0000000000c1', 'aaaaaaaa-0000-4000-8000-000000000001', 'rls_test', 'X uno', 'Tesis de X uno.', 'text'),
  ('aaaaaaaa-0000-4000-8000-0000000000c2', 'aaaaaaaa-0000-4000-8000-000000000001', 'rls_test', 'X dos', 'Tesis de X dos.', 'text'),
  ('bbbbbbbb-0000-4000-8000-0000000000c1', 'bbbbbbbb-0000-4000-8000-000000000002', 'rls_test', 'Y uno', 'Tesis de Y uno.', 'text'),
  ('bbbbbbbb-0000-4000-8000-0000000000c2', 'bbbbbbbb-0000-4000-8000-000000000002', 'rls_test', 'Y dos', 'Tesis de Y dos.', 'text');

insert into public.sparks (user_id, concept_lo, concept_hi, title, body, status) values
  ('aaaaaaaa-0000-4000-8000-000000000001', 'aaaaaaaa-0000-4000-8000-0000000000c1', 'aaaaaaaa-0000-4000-8000-0000000000c2', 'X × X', 'Chispa de X.', 'revealed'),
  ('bbbbbbbb-0000-4000-8000-000000000002', 'bbbbbbbb-0000-4000-8000-0000000000c1', 'bbbbbbbb-0000-4000-8000-0000000000c2', 'Y × Y', 'Chispa de Y.', 'revealed');

insert into public.usage_ledger (user_id, kind, period, period_start, used) values
  ('aaaaaaaa-0000-4000-8000-000000000001', 'capture', 'day', current_date, 3),
  ('bbbbbbbb-0000-4000-8000-000000000002', 'capture', 'day', current_date, 5);

insert into public.llm_calls (user_id, feature, model) values
  ('bbbbbbbb-0000-4000-8000-000000000002', 'spark', 'claude-haiku-4-5');

-- ---------------------------------------------------------------
-- Guarda para tablas futuras
-- ---------------------------------------------------------------
select is(
  (select array_agg(tablename::text) from pg_tables where schemaname = 'public' and not rowsecurity),
  null,
  'todas las tablas de public tienen RLS activado'
);

-- ---------------------------------------------------------------
-- Con la sesión de X
-- ---------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', '{"sub": "aaaaaaaa-0000-4000-8000-000000000001", "role": "authenticated"}', true);

-- Lectura: solo lo propio
select is((select array_agg(id) from public.profiles), array['aaaaaaaa-0000-4000-8000-000000000001'::uuid],
  'profiles: X ve solo su perfil');
select is((select array_agg(id order by id) from public.concepts),
  array['aaaaaaaa-0000-4000-8000-0000000000c1', 'aaaaaaaa-0000-4000-8000-0000000000c2']::uuid[],
  'concepts: X ve solo sus conceptos');
select is((select array_agg(title) from public.sparks), array['X × X'],
  'sparks: X ve solo su chispa');
select is((select array_agg(used) from public.usage_ledger), array[3],
  'usage_ledger: X ve solo su uso');
select ok((select count(*) from public.domains) >= 1, 'domains: X puede leer los dominios');
select ok((select count(*) from public.plan_limits) >= 1, 'plan_limits: X puede leer los límites');
select throws_ok($$ select * from public.llm_calls $$, '42501', null, 'llm_calls: X no puede leer los costos');

-- Perfil: solo las columnas propias del usuario
select lives_ok($$ update public.profiles set spark_hour = '07:30' where id = auth.uid() $$,
  'profiles: X cambia su hora de la chispa');
select throws_ok($$ update public.profiles set plan = 'pro' where id = auth.uid() $$, '42501', null,
  'profiles: X no puede pasarse a Pro');
select throws_ok($$ update public.profiles set target_distance = 0.1 where id = auth.uid() $$, '42501', null,
  'profiles: X no puede tocar la distancia del emparejamiento');
select throws_ok($$ insert into public.profiles (id) values (gen_random_uuid()) $$, '42501', null,
  'profiles: X no puede crear perfiles');

-- Conceptos: corregir sí; crear, cambiar de dueño o escribir el embedding, no
select lives_ok($$ update public.concepts set title = 'X uno corregido' where id = 'aaaaaaaa-0000-4000-8000-0000000000c1' $$,
  'concepts: X corrige el título de su concepto');
select throws_ok($$ insert into public.concepts (user_id, domain, title, thesis, source_type)
                    values (auth.uid(), 'rls_test', 'a', 'b', 'text') $$, '42501', null,
  'concepts: X no puede crear conceptos sin pasar por el endpoint de captura');
select throws_ok($$ update public.concepts set user_id = 'bbbbbbbb-0000-4000-8000-000000000002' where user_id = auth.uid() $$, '42501', null,
  'concepts: X no puede pasarle un concepto a otro usuario');
select throws_ok($$ update public.concepts set embedding_model = 'otro' where user_id = auth.uid() $$, '42501', null,
  'concepts: X no puede escribir el embedding');

-- Chispas: responder sí; crear o reescribir, no
select lives_ok($$ update public.sparks set status = 'saved', feedback = null where user_id = auth.uid() $$,
  'sparks: X guarda su chispa');
select throws_ok($$ update public.sparks set title = 'reescrita' where user_id = auth.uid() $$, '42501', null,
  'sparks: X no puede reescribir el contenido de su chispa');
select throws_ok($$ insert into public.sparks (user_id, concept_lo, concept_hi)
                    values (auth.uid(), 'aaaaaaaa-0000-4000-8000-0000000000c1', 'aaaaaaaa-0000-4000-8000-0000000000c2') $$, '42501', null,
  'sparks: X no puede crear chispas');

-- Cuotas y configuración: solo el servidor
select throws_ok($$ update public.usage_ledger set used = 0 $$, '42501', null,
  'usage_ledger: X no puede resetear su uso');
select throws_ok($$ select public.consume_credit('bbbbbbbb-0000-4000-8000-000000000002', 'capture') $$, '42501', null,
  'consume_credit: X no puede llamarla (ni gastar la cuota de otro)');
select throws_ok($$ insert into public.domains (slug, name_es, name_en, description) values ('x', 'x', 'x', 'x') $$, '42501', null,
  'domains: X no puede crear dominios');
select throws_ok($$ update public.plan_limits set max_count = 9999 $$, '42501', null,
  'plan_limits: X no puede cambiar los límites');

-- Los datos de Y: los intentos no fallan, pero no afectan ninguna fila
select lives_ok($$ update public.concepts set title = 'hackeado' where user_id = 'bbbbbbbb-0000-4000-8000-000000000002' $$,
  'concepts: editar los de Y no da error (RLS filtra las filas)');
select lives_ok($$ delete from public.concepts where user_id = 'bbbbbbbb-0000-4000-8000-000000000002' $$,
  'concepts: borrar los de Y no da error (RLS filtra las filas)');
select lives_ok($$ update public.sparks set status = 'discarded' where user_id = 'bbbbbbbb-0000-4000-8000-000000000002' $$,
  'sparks: responder las de Y no da error (RLS filtra las filas)');
select lives_ok($$ update public.profiles set spark_hour = '03:00' where id = 'bbbbbbbb-0000-4000-8000-000000000002' $$,
  'profiles: editar el de Y no da error (RLS filtra las filas)');

-- ---------------------------------------------------------------
-- De vuelta como servidor: comprobar qué cambió de verdad
-- ---------------------------------------------------------------
reset role;

select is((select array_agg(title order by title) from public.concepts where user_id = 'bbbbbbbb-0000-4000-8000-000000000002'),
  array['Y dos', 'Y uno'], 'concepts: los de Y siguen intactos');
select is((select status from public.sparks where user_id = 'bbbbbbbb-0000-4000-8000-000000000002'), 'revealed',
  'sparks: la de Y sigue intacta');
select is((select spark_hour from public.profiles where id = 'bbbbbbbb-0000-4000-8000-000000000002'), '09:00'::time,
  'profiles: el de Y sigue intacto');
select is((select spark_hour from public.profiles where id = 'aaaaaaaa-0000-4000-8000-000000000001'), '07:30'::time,
  'profiles: el cambio permitido de X sí se guardó');

-- ---------------------------------------------------------------
-- Sin sesión
-- ---------------------------------------------------------------
set local role anon;
select set_config('request.jwt.claims', '', true);

select throws_ok($$ select * from public.concepts $$, '42501', null, 'concepts: sin sesión no se leen');
select throws_ok($$ select * from public.profiles $$, '42501', null, 'profiles: sin sesión no se leen');
select throws_ok($$ select * from public.sparks $$, '42501', null, 'sparks: sin sesión no se leen');
select ok((select count(*) from public.domains) >= 1, 'domains: sin sesión se pueden leer');

reset role;
select * from finish();
rollback;
