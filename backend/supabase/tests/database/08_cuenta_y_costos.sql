-- Cuenta y datos (exportar, borrar, texto crudo vencido), búsqueda, costos y crons.
begin;
create extension if not exists pgtap with schema extensions;
select plan(20);

create function pg_temp.vec(theta float8) returns extensions.vector language sql immutable as $$
  select (array[cos(theta), sin(theta)] || array_fill(0::float8, array[1022]))::extensions.vector(1024);
$$;

insert into auth.users (id, email, aud, role, created_at) values
  ('80000000-0000-4000-8000-000000000001', 'x@cuenta.test', 'authenticated', 'authenticated', now() - interval '10 days'),
  ('80000000-0000-4000-8000-000000000002', 'y@cuenta.test', 'authenticated', 'authenticated', now());

insert into public.concepts (id, user_id, domain, title, thesis, source_type, embedding, embedding_model, raw_text, raw_text_expires_at) values
  ('80000000-0000-4000-8000-0000000000a1', '80000000-0000-4000-8000-000000000001', 'cocina', 'X cerca', 'Tesis.', 'text',
   pg_temp.vec(0.1), 'test', 'texto viejo', now() - interval '1 day'),
  ('80000000-0000-4000-8000-0000000000a2', '80000000-0000-4000-8000-000000000001', 'fisica', 'X lejos', 'Tesis.', 'text',
   pg_temp.vec(2.0), 'test', 'texto nuevo', now() + interval '29 days'),
  ('80000000-0000-4000-8000-0000000000b1', '80000000-0000-4000-8000-000000000002', 'cocina', 'Y igual', 'Tesis.', 'text',
   pg_temp.vec(0.0), 'test', null, null);
insert into public.sparks (id, user_id, concept_lo, concept_hi, title, body) values
  ('80000000-0000-4000-8000-0000000005a1', '80000000-0000-4000-8000-000000000001',
   '80000000-0000-4000-8000-0000000000a1', '80000000-0000-4000-8000-0000000000a2', 'X × X', 'Chispa.');
insert into public.planner_threads (id, user_id, spark_id) values
  ('80000000-0000-4000-8000-0000000007a1', '80000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-0000000005a1');
insert into public.planner_messages (thread_id, user_id, role, content) values
  ('80000000-0000-4000-8000-0000000007a1', '80000000-0000-4000-8000-000000000001', 'user', 'Hola'),
  ('80000000-0000-4000-8000-0000000007a1', '80000000-0000-4000-8000-000000000001', 'assistant', 'Plan.');
insert into public.projects (user_id, name) values ('80000000-0000-4000-8000-000000000001', 'Proyecto X');

-- ---------------------------------------------------------------
-- Texto crudo vencido
-- ---------------------------------------------------------------
select is(public.purge_expired_raw_text() >= 1, true, 'purge_expired_raw_text: limpia el texto crudo vencido');
select results_eq(
  $$ select title, raw_text from public.concepts where user_id = '80000000-0000-4000-8000-000000000001' order by title $$,
  $$ values ('X cerca', null::text), ('X lejos', 'texto nuevo') $$,
  'el texto crudo vencido queda en null y el vigente se conserva');

-- ---------------------------------------------------------------
-- Costos
-- ---------------------------------------------------------------
insert into public.llm_calls (user_id, feature, model, cost_usd, created_at) values
  ('80000000-0000-4000-8000-000000000001', 'spark', 'claude-haiku-4-5', 0.04, now()),
  ('80000000-0000-4000-8000-000000000001', 'planner', 'claude-sonnet-5', 0.03, now()),
  ('80000000-0000-4000-8000-000000000002', 'spark', 'claude-haiku-4-5', 0.01, now());
select results_eq(
  $$ select user_usd, user_cap from public.llm_spend_today('80000000-0000-4000-8000-000000000001') $$,
  $$ values (0.07::numeric, 0.05::numeric) $$,
  'llm_spend_today: gasto del día del usuario y su tope');
select ok((select calls >= 2 from public.llm_cost_daily
            where day = (now() at time zone 'UTC')::date and feature = 'spark' and model = 'claude-haiku-4-5'),
  'llm_cost_daily: agrupa por día, función y modelo');
select results_eq(
  $$ select scope, user_id from public.llm_cost_alerts() where scope = 'user'
      and user_id in ('80000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000002') $$,
  $$ values ('user', '80000000-0000-4000-8000-000000000001'::uuid) $$,
  'llm_cost_alerts: marca al usuario que pasó su tope diario');
select ok(public.record_cost_alerts((now() at time zone 'UTC')::date) >= 1, 'record_cost_alerts: guarda las alertas del día');
select ok(public.record_cost_alerts((now() at time zone 'UTC')::date) >= 1, 'record_cost_alerts: se puede correr dos veces (idempotente)');

-- ---------------------------------------------------------------
-- Crons
-- ---------------------------------------------------------------
select results_eq(
  $$ select jobname, schedule from cron.job
      where jobname in ('procesar-pendientes', 'chispas-diarias', 'chispas-diarias-resultados', 'enviar-pushes',
                        'vencer-texto-crudo', 'alertas-de-costo')
      order by jobname $$,
  $$ values ('alertas-de-costo', '5 3 * * *'), ('chispas-diarias', '*/15 * * * *'), ('chispas-diarias-resultados', '*/10 * * * *'),
            ('enviar-pushes', '*/5 * * * *'), ('procesar-pendientes', '*/5 * * * *'), ('vencer-texto-crudo', '27 6 * * *') $$,
  'los crons del servidor están programados');

-- ---------------------------------------------------------------
-- Con la sesión de X
-- ---------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', '{"sub": "80000000-0000-4000-8000-000000000001", "role": "authenticated"}', true);

-- Búsqueda semántica: RLS deja solo lo propio, ordenado por cercanía.
select is((select array_agg(title) from public.match_concepts(pg_temp.vec(0.0), 10)), array['X cerca', 'X lejos'],
  'match_concepts: devuelve solo los conceptos propios, del más cercano al más lejano');
select is((select count(*)::int from public.match_concepts(pg_temp.vec(0.0), 1)), 1, 'match_concepts: respeta la cantidad pedida');

create temp table export as select public.export_my_data() as data;
select is((select jsonb_array_length(data -> 'concepts') from export), 2, 'export_my_data: trae sus conceptos');
select ok((select not (data -> 'concepts' -> 0 ? 'embedding') from export), 'export_my_data: sin el embedding');
select is((select jsonb_array_length(data -> 'planner' -> 0 -> 'messages') from export), 2,
  'export_my_data: trae los mensajes del planificador');
select is((select data #>> '{projects,0,name}' from export), 'Proyecto X', 'export_my_data: trae sus proyectos');
select is((select data #>> '{profile,id}' from export), '80000000-0000-4000-8000-000000000001', 'export_my_data: trae su perfil');
select throws_ok($$ select public.llm_spend_today(auth.uid()) $$, '42501', null, 'llm_spend_today: la app no puede llamarla');
select throws_ok($$ select public.invoke_edge_function('/process') $$, '42501', null, 'invoke_edge_function: la app no puede llamarla');

select lives_ok($$ select public.delete_my_account() $$, 'delete_my_account: X borra su cuenta');

reset role;
select ok(not exists (select 1 from auth.users where id = '80000000-0000-4000-8000-000000000001')
          and not exists (select 1 from public.concepts where user_id = '80000000-0000-4000-8000-000000000001')
          and not exists (select 1 from public.planner_messages where user_id = '80000000-0000-4000-8000-000000000001'),
  'delete_my_account: con el usuario se va todo lo suyo');
select ok(exists (select 1 from public.concepts where user_id = '80000000-0000-4000-8000-000000000002')
          and exists (select 1 from public.analytics_outbox
                       where distinct_id = '80000000-0000-4000-8000-000000000001' and event = 'account_deleted'),
  'delete_my_account: no toca a otros usuarios y deja el evento account_deleted');

select * from finish();
rollback;
