-- Límites de frecuencia y adjuntos huérfanos (pasos 34 y 62), tablero de costos (paso 38) y biblioteca (paso 31).
begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

-- ---------------------------------------------------------------
-- hit_rate_limit
-- ---------------------------------------------------------------
select is(public.hit_rate_limit('test:a', 2, 3600), true, 'hit_rate_limit: el primero entra');
select is(public.hit_rate_limit('test:a', 2, 3600), true, 'hit_rate_limit: el segundo entra');
select is(public.hit_rate_limit('test:a', 2, 3600), false, 'hit_rate_limit: el tercero se pasa del tope');
select is(public.hit_rate_limit('test:b', 2, 3600), true, 'hit_rate_limit: cada clave cuenta por separado');
insert into public.rate_limits (key, window_start, hits) values ('test:viejo', now() - interval '3 days', 5);
select ok(public.purge_rate_limits() >= 1, 'purge_rate_limits: borra ventanas de hace más de 2 días');

-- ---------------------------------------------------------------
-- Adjuntos que quedaron en capture-temp
-- ---------------------------------------------------------------
insert into storage.objects (bucket_id, name, created_at) values
  ('capture-temp', '10000000-0000-4000-8000-000000000001/viejo.jpg', now() - interval '2 hours'),
  ('capture-temp', '10000000-0000-4000-8000-000000000001/nuevo.jpg', now() - interval '5 minutes');
select is((select array_agg(n) from public.stale_capture_uploads() n where n like '10000000-%'),
  array['10000000-0000-4000-8000-000000000001/viejo.jpg'],
  'stale_capture_uploads: solo los de más de una hora');

-- ---------------------------------------------------------------
-- Tablero de costos
-- ---------------------------------------------------------------
-- Se arranca de cero para que los números sean exactos.
delete from public.llm_calls;
insert into auth.users (id, email, aud, role) values
  ('10000000-0000-4000-8000-0000000000a1', 'a@costos.test', 'authenticated', 'authenticated'),
  ('10000000-0000-4000-8000-0000000000a2', 'b@costos.test', 'authenticated', 'authenticated');
insert into public.llm_calls (user_id, feature, model, input_tokens, output_tokens, cost_usd, batch) values
  ('10000000-0000-4000-8000-0000000000a1', 'spark', 'claude-haiku-4-5', 500, 100, 0.002, true),
  ('10000000-0000-4000-8000-0000000000a2', 'spark', 'claude-haiku-4-5', 500, 100, 0.004, false),
  ('10000000-0000-4000-8000-0000000000a2', 'spark:error', 'claude-haiku-4-5', 0, 0, 0, false),
  ('10000000-0000-4000-8000-0000000000a2', 'distill', 'claude-haiku-4-5', 2000, 300, 0.006, false),
  ('10000000-0000-4000-8000-0000000000a2', 'planner', 'claude-sonnet-5', 1000, 1000, 0.012, false),
  ('10000000-0000-4000-8000-0000000000a2', 'planner_summary', 'claude-haiku-4-5', 1000, 100, 0.002, false),
  ('10000000-0000-4000-8000-0000000000a2', 'embed', 'lumbre-local-hash-v1', 10, 0, 0, false);

select results_eq(
  $$ select cost_usd, calls, error_calls, batch_calls, users, sparks, usd_per_spark, distills, usd_per_distill,
            planner_messages, usd_per_planner_message
       from public.llm_cost_dashboard(7) where day = (now() at time zone 'UTC')::date $$,
  $$ values (0.026::numeric, 7, 1, 1, 2, 2, 0.003::numeric, 1, 0.006::numeric, 1, 0.014::numeric) $$,
  'llm_cost_dashboard: total, errores, batch, usuarios y costo por chispa, destilación y mensaje');
select is((select count(*)::int from public.llm_cost_dashboard(7)), 7, 'llm_cost_dashboard: una fila por día, también sin llamadas');
select results_eq(
  $$ select users, usd_per_user, over_target from public.llm_cost_month() $$,
  $$ values (2, 0.013::numeric, false) $$,
  'llm_cost_month: costo por usuario activo del mes contra el objetivo');
select is((select count(*)::int from public.llm_cost_signals()), 0, 'llm_cost_signals: un día normal no tiene señales');

-- Una chispa cara y un modelo sin precio.
insert into public.llm_calls (user_id, feature, model, input_tokens, output_tokens, cost_usd) values
  ('10000000-0000-4000-8000-0000000000a1', 'spark', 'claude-haiku-4-5', 5000, 2000, 0.03),
  ('10000000-0000-4000-8000-0000000000a1', 'spark', 'modelo-nuevo', 500, 100, 0);
select is((select array_agg(signal order by signal) from public.llm_cost_signals()),
  array['spark_cost', 'unpriced_model'], 'llm_cost_signals: avisa la chispa cara y el modelo sin precio');
-- Y un usuario que pasó su tope.
insert into public.llm_calls (user_id, feature, model, cost_usd) values ('10000000-0000-4000-8000-0000000000a1', 'planner', 'claude-sonnet-5', 0.05);
select ok(exists (select 1 from public.llm_cost_signals() where signal = 'user_cap' and detail = '10000000-0000-4000-8000-0000000000a1'),
  'llm_cost_signals: incluye a quien pasó su tope diario');
-- Muchos errores.
insert into public.llm_calls (user_id, feature, model, cost_usd)
select null, 'distill:error', 'claude-haiku-4-5', 0 from generate_series(1, 20);
select ok(exists (select 1 from public.llm_cost_signals() where signal = 'error_rate'), 'llm_cost_signals: avisa una tasa de errores alta');

-- ---------------------------------------------------------------
-- Biblioteca de conceptos invitados (paso 31)
-- ---------------------------------------------------------------
select is((select count(*)::int from (select profile from public.library_concepts group by profile having count(*) >= 30) p), 5,
  'biblioteca: los cinco perfiles tienen al menos 30 conceptos');
select is((select min(n)::int from (select count(distinct domain) n from public.library_concepts group by profile) d) >= 14, true,
  'biblioteca: cada perfil cruza al menos 14 dominios');
select is((select count(*)::int from public.library_concepts
            where (profile = 'software' and domain = 'tecnologia')
               or (profile = 'business' and domain in ('negocios', 'economia'))
               or (profile = 'design' and domain = 'diseno')
               or (profile = 'content' and domain in ('literatura', 'marketing'))), 0,
  'biblioteca: ningún perfil tiene conceptos de su propio mundo (lo que sirve es el cruce)');
select is((select count(*)::int from public.library_concepts where char_length(thesis) > 200 or char_length(principle) > 160), 0,
  'biblioteca: tesis y principios cortos, como los de una destilación');

select * from finish();
rollback;
