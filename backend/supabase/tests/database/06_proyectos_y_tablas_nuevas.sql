-- Perfil, proyectos, push, captura con adjuntos, reportes, planificador, biblioteca y tablas solo del servidor.
-- Acceso de cada tabla nueva: A no ve ni toca lo de B, y lo que escribe el servidor no lo escribe la app.
begin;
create extension if not exists pgtap with schema extensions;
select plan(52);

insert into auth.users (id, email, aud, role) values
  ('d0000000-0000-4000-8000-000000000001', 'a@nuevas.test', 'authenticated', 'authenticated'),
  ('d0000000-0000-4000-8000-000000000002', 'b@nuevas.test', 'authenticated', 'authenticated'),
  ('d0000000-0000-4000-8000-000000000003', 'p@nuevas.test', 'authenticated', 'authenticated');
insert into auth.users (id, aud, role, is_anonymous) values
  ('d0000000-0000-4000-8000-000000000004', 'authenticated', 'authenticated', true);
update public.profiles set plan = 'pro' where id = 'd0000000-0000-4000-8000-000000000003';

-- Una chispa de A y una de B, con sus conceptos.
insert into public.concepts (id, user_id, domain, title, thesis, source_type) values
  ('d0000000-0000-4000-8000-0000000000a1', 'd0000000-0000-4000-8000-000000000001', 'cocina', 'A uno', 'Tesis A uno.', 'text'),
  ('d0000000-0000-4000-8000-0000000000a2', 'd0000000-0000-4000-8000-000000000001', 'fisica', 'A dos', 'Tesis A dos.', 'text'),
  ('d0000000-0000-4000-8000-0000000000b1', 'd0000000-0000-4000-8000-000000000002', 'cocina', 'B uno', 'Tesis B uno.', 'text'),
  ('d0000000-0000-4000-8000-0000000000b2', 'd0000000-0000-4000-8000-000000000002', 'fisica', 'B dos', 'Tesis B dos.', 'text');
insert into public.sparks (id, user_id, concept_lo, concept_hi, title, body, status) values
  ('d0000000-0000-4000-8000-0000000005a1', 'd0000000-0000-4000-8000-000000000001',
   'd0000000-0000-4000-8000-0000000000a1', 'd0000000-0000-4000-8000-0000000000a2', 'A × A', 'Chispa de A.', 'revealed'),
  ('d0000000-0000-4000-8000-0000000005b1', 'd0000000-0000-4000-8000-000000000002',
   'd0000000-0000-4000-8000-0000000000b1', 'd0000000-0000-4000-8000-0000000000b2', 'B × B', 'Chispa de B.', 'revealed');
insert into public.planner_threads (id, user_id, spark_id) values
  ('d0000000-0000-4000-8000-0000000007a1', 'd0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-0000000005a1'),
  ('d0000000-0000-4000-8000-0000000007b1', 'd0000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8000-0000000005b1');
insert into public.planner_messages (thread_id, user_id, role, content) values
  ('d0000000-0000-4000-8000-0000000007a1', 'd0000000-0000-4000-8000-000000000001', 'assistant', 'Plan de A.'),
  ('d0000000-0000-4000-8000-0000000007b1', 'd0000000-0000-4000-8000-000000000002', 'assistant', 'Plan de B.');
insert into public.projects (id, user_id, name) values
  ('d0000000-0000-4000-8000-0000000006b1', 'd0000000-0000-4000-8000-000000000002', 'Proyecto de B');
insert into public.push_tokens (token, user_id, platform) values ('token-de-b', 'd0000000-0000-4000-8000-000000000002', 'ios');

create function pg_temp.login(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
$$;
grant execute on function pg_temp.login(uuid) to authenticated;

select is((select round(target_distance::numeric, 2) from public.profiles where id = 'd0000000-0000-4000-8000-000000000001'), 0.6,
  'perfil: la banda del emparejamiento arranca centrada en el percentil 60');

-- ---------------------------------------------------------------
-- Como A
-- ---------------------------------------------------------------
set local role authenticated;
select pg_temp.login('d0000000-0000-4000-8000-000000000001');

-- Perfil
select lives_ok($$ update public.profiles set onboarded_at = now() where id = auth.uid() $$,
  'perfil: A marca el onboarding como terminado');

-- Proyectos
select is((select count(*)::int from public.projects), 0, 'projects: A no ve los proyectos de B');
select is((select name from public.create_project('  Mi   app  ')), 'Mi app', 'create_project: crea con el nombre limpio');
select throws_ok($$ select public.create_project('Otro') $$, 'P0001', 'too_many_projects',
  'create_project: free tiene un solo proyecto');
select throws_ok($$ select public.create_project('   ') $$, '22023', 'invalid_request',
  'create_project: sin nombre no se crea');
select throws_ok($$ insert into public.projects (user_id, name) values (auth.uid(), 'Directo') $$, '42501', null,
  'projects: no se crean directo, solo con create_project()');
select lives_ok($$ update public.projects set name = 'Renombrado' $$, 'projects: A renombra el suyo');
select throws_ok($$ update public.projects set user_id = 'd0000000-0000-4000-8000-000000000002' $$, '42501', null,
  'projects: A no puede pasarle su proyecto a otro');
select results_eq(
  $$ select kind, max_count, used, remaining from public.credit_status() where kind = 'projects' $$,
  $$ values ('projects', 1, 1, 0) $$,
  'credit_status: el cupo de proyectos cuenta los que existen');

-- Chispas: guardar en un proyecto propio sí, en uno ajeno no
select lives_ok($$ update public.sparks set project_id = (select id from public.projects), status = 'saved' $$,
  'sparks: A guarda su chispa en su proyecto');
select throws_ok($$ update public.sparks set project_id = 'd0000000-0000-4000-8000-0000000006b1' $$, '23503', null,
  'sparks: A no puede guardar su chispa en un proyecto de B');
select throws_ok($$ update public.sparks set notified_at = now() $$, '42501', null,
  'sparks: A no puede marcar la push como enviada');

-- Feedback: mueve el centro de la banda
select lives_ok($$ update public.sparks set feedback = 'obvious', status = 'discarded' $$, 'sparks: A da feedback');

-- Push
select lives_ok($$ select public.register_push_token('token-de-a', 'ios', true) $$, 'register_push_token: A registra su token');
select is((select count(*)::int from public.push_tokens), 1, 'push_tokens: A ve solo el suyo');
select throws_ok($$ select public.register_push_token('x', 'windows') $$, '22023', 'invalid_request',
  'register_push_token: plataforma inválida');
select throws_ok($$ insert into public.push_tokens (token, user_id, platform) values ('t', auth.uid(), 'ios') $$, '42501', null,
  'push_tokens: no se insertan directo');

-- Captura con los parámetros nuevos
select lives_ok($$ select public.capture_concept('La foto me deja esta idea.', 'Fotos', 'image', p_local_asset_id => 'PH-123') $$,
  'capture_concept: guarda una imagen sin URL, con la foto local');
select lives_ok($$ select public.capture_concept('Un PDF con su idea.', 'Lecturas', 'pdf', 'https://ejemplo.com/a.pdf',
                                                  p_source_title => 'Paper', p_excerpt => repeat('x', 800)) $$,
  'capture_concept: guarda un PDF con URL, título y fragmento');
select is((select char_length(excerpt) from public.concepts where source_type = 'pdf'), 500,
  'capture_concept: el fragmento se corta a 500 caracteres');
select results_eq($$ select source_title, local_asset_id from public.concepts where source_type in ('pdf', 'image') order by source_type $$,
  $$ values (null::text, 'PH-123'::text), ('Paper', null) $$, 'capture_concept: guarda el título de la fuente y la foto local');
select throws_ok($$ select public.capture_concept('URL rara.', 'Lecturas', 'selection', 'javascript:alert(1)') $$, '22023', 'invalid_source',
  'capture_concept: una URL que no es http(s) no se acepta');
select throws_ok($$ select public.capture_concept('Audio.', 'Lecturas', 'audio') $$, '22023', 'invalid_source',
  'capture_concept: el audio todavía no se captura');

-- Mover un concepto de categoría
select is((select category_created from public.move_concept('d0000000-0000-4000-8000-0000000000a1', 'Recetas')), true,
  'move_concept: mueve a una categoría nueva y la crea');
select is((select c.name from public.concepts k join public.categories c on c.id = k.category_id
            where k.id = 'd0000000-0000-4000-8000-0000000000a1'), 'Recetas', 'move_concept: el concepto quedó en la categoría');
select throws_ok($$ select public.move_concept('d0000000-0000-4000-8000-0000000000b1', 'Robado') $$, 'P0002', 'not_found',
  'move_concept: A no puede mover un concepto de B');

-- Reportes de contenido IA
select lives_ok($$ insert into public.content_reports (spark_id, reason, note)
                   values ('d0000000-0000-4000-8000-0000000005a1', 'wrong', 'No tiene sentido') $$,
  'content_reports: A reporta su chispa');
select lives_ok($$ insert into public.content_reports (planner_message_id, reason)
                   select id, 'offensive' from public.planner_messages $$,
  'content_reports: A reporta un mensaje de su planificador');
select throws_ok($$ insert into public.content_reports (spark_id, reason) values ('d0000000-0000-4000-8000-0000000005b1', 'other') $$,
  '42501', null, 'content_reports: A no puede reportar una chispa de B');
select throws_ok($$ insert into public.content_reports (user_id, spark_id, reason)
                    values ('d0000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8000-0000000005a1', 'other') $$,
  '42501', null, 'content_reports: A no puede reportar a nombre de otro');
select is((select count(*)::int from public.content_reports), 2, 'content_reports: A ve solo los suyos');

-- Planificador: lectura propia, escritura solo del servidor
select is((select array_agg(content) from public.planner_messages), array['Plan de A.'], 'planner_messages: A ve solo los suyos');
select is((select count(*)::int from public.planner_threads), 1, 'planner_threads: A ve solo los suyos');
select throws_ok($$ insert into public.planner_messages (thread_id, user_id, role, content)
                    values ('d0000000-0000-4000-8000-0000000007a1', auth.uid(), 'assistant', 'inventado') $$, '42501', null,
  'planner_messages: A no puede escribir respuestas del planificador');

-- Biblioteca: lectura sí, escritura no
select ok((select count(*) from public.library_concepts) >= 40, 'library_concepts: A lee la biblioteca');
select throws_ok($$ update public.library_concepts set title = 'x' $$, '42501', null, 'library_concepts: A no puede editarla');

-- Tablas solo del servidor
select throws_ok($$ select * from public.app_config $$, '42501', null, 'app_config: A no la lee');
select throws_ok($$ select * from public.cost_alerts $$, '42501', null, 'cost_alerts: A no las lee');
select throws_ok($$ select * from public.llm_cost_daily $$, '42501', null, 'llm_cost_daily: A no lo lee');
select throws_ok($$ select * from public.spark_jobs $$, '42501', null, 'spark_jobs: A no los lee');
select throws_ok($$ select * from public.subscription_events $$, '42501', null, 'subscription_events: A no los lee');
select throws_ok($$ select * from public.analytics_outbox $$, '42501', null, 'analytics_outbox: A no la lee');
select throws_ok($$ select public.pick_spark_pair(auth.uid()) $$, '42501', null, 'pick_spark_pair: la app no puede llamarla');
select throws_ok($$ select public.create_spark(auth.uid(), 'd0000000-0000-4000-8000-0000000000a1', 'd0000000-0000-4000-8000-0000000000a2', 'extra', 't', 'b') $$,
  '42501', null, 'create_spark: la app no puede crear chispas');

-- ---------------------------------------------------------------
-- Pro e invitado
-- ---------------------------------------------------------------
select pg_temp.login('d0000000-0000-4000-8000-000000000003');
select is((select count(*)::int from (select public.create_project('P' || g) from generate_series(1, 3) g) x), 3,
  'create_project: pro crea varios');
select pg_temp.login('d0000000-0000-4000-8000-000000000004');
select lives_ok($$ select public.create_project('Del invitado') $$, 'create_project: el invitado tiene un proyecto');

-- ---------------------------------------------------------------
-- Como servidor: qué cambió de verdad
-- ---------------------------------------------------------------
reset role;
select is((select round(target_distance::numeric, 2) from public.profiles where id = 'd0000000-0000-4000-8000-000000000001'), 0.63,
  'feedback: "obvia" corre la banda hacia pares más lejanos');
update public.sparks set feedback = 'irrelevant' where id = 'd0000000-0000-4000-8000-0000000005a1';
select is((select round(target_distance::numeric, 2) from public.profiles where id = 'd0000000-0000-4000-8000-000000000001'), 0.57,
  'feedback: cambiar a "irrelevante" deshace la anterior y la corre hacia pares más cercanos');
update public.profiles set target_distance = 0.84 where id = 'd0000000-0000-4000-8000-000000000001';
update public.sparks set feedback = 'obvious' where id = 'd0000000-0000-4000-8000-0000000005a1';
select is((select round(target_distance::numeric, 2) from public.profiles where id = 'd0000000-0000-4000-8000-000000000001'), 0.85,
  'feedback: el centro nunca pasa de 0,85');
select ok(exists (select 1 from public.analytics_outbox
                   where distinct_id = 'd0000000-0000-4000-8000-000000000001' and event = 'spark_saved'),
  'analytics: guardar una chispa deja spark_saved en la bandeja');
select is((select user_id from public.push_tokens where token = 'token-de-b'), 'd0000000-0000-4000-8000-000000000002'::uuid,
  'push_tokens: el token de B sigue siendo de B');

select * from finish();
rollback;
