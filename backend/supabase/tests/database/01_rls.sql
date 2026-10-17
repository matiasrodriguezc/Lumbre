-- RLS: el usuario A no ve ni toca los datos de B, y nadie cambia lo que solo escribe el servidor.
-- Crea sus propios datos dentro de la transacción y la revierte al final: no depende del seed.
begin;
create extension if not exists pgtap with schema extensions;
select plan(45);

-- ---------------------------------------------------------------
-- Datos: X y Y, cada uno con su perfil, dos conceptos, una chispa y uso.
-- ---------------------------------------------------------------
insert into auth.users (id, email, aud, role) values
  ('aaaaaaaa-0000-4000-8000-000000000001', 'x@rls.test', 'authenticated', 'authenticated'),
  ('bbbbbbbb-0000-4000-8000-000000000002', 'y@rls.test', 'authenticated', 'authenticated');

-- El trigger ya creó los perfiles; se fija la hora para poder comprobar cambios.
insert into public.profiles (id, spark_hour) values
  ('aaaaaaaa-0000-4000-8000-000000000001', '08:00'),
  ('bbbbbbbb-0000-4000-8000-000000000002', '09:00')
on conflict (id) do update set spark_hour = excluded.spark_hour;

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

-- Guarda para funciones futuras (paso 62): una función security definer salta RLS, así que las que puede llamar
-- la app son una lista cerrada, y todas usan auth.uid() en vez de recibir el usuario por parámetro.
-- Si agregás una, revisá que no acepte un user id ajeno y sumala acá.
select is(
  (select array_agg(p.proname::text order by p.proname)
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosecdef
      and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'))),
  array['capture_concept', 'create_project', 'credit_status', 'delete_my_account', 'export_my_data', 'move_concept',
        'register_push_token', 'save_spark'],
  'solo estas funciones security definer las puede llamar la app'
);
select is(
  (select array_agg(p.proname::text order by p.proname)
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosecdef
      and has_function_privilege('anon', p.oid, 'execute')),
  null,
  'ninguna función security definer se puede llamar sin sesión'
);
select is(
  (select array_agg(p.proname::text) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosecdef
      and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')),
  null,
  'toda función security definer fija su search_path'
);

insert into public.attest_keys (key_id, user_id, public_key, environment)
values ('clave-de-x', 'aaaaaaaa-0000-4000-8000-000000000001', 'MFkw', 'development');
insert into public.rate_limits (key, window_start, hits) values ('search:aaaaaaaa-0000-4000-8000-000000000001', now(), 1);

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
select throws_ok($$ select * from public.bridge_topics $$, '42501', null, 'bridge_topics: X no puede leer las sugerencias (solo el servidor)');
select throws_ok($$ select * from public.bridge_domain_pair(auth.uid()) $$, '42501', null, 'bridge_domain_pair: la app no puede llamarla');

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
select throws_ok($$ select * from public.attest_keys $$, '42501', null, 'attest_keys: X no lee las claves de App Attest');
select throws_ok($$ update public.attest_keys set sign_count = 0 $$, '42501', null, 'attest_keys: X no puede resetear el contador');
select throws_ok($$ select * from public.rate_limits $$, '42501', null, 'rate_limits: X no lee los límites de frecuencia');
select throws_ok($$ select public.hit_rate_limit('search:otro', 1000, 60) $$, '42501', null, 'hit_rate_limit: X no puede llamarla');
select throws_ok($$ select * from public.llm_cost_dashboard(7) $$, '42501', null, 'llm_cost_dashboard: X no ve el tablero de costos');

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
