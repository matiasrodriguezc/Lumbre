-- Temas puente (paso 92): detección de los dos dominios, cupo semanal y la sugerencia de la semana.
-- Crea sus propios datos dentro de la transacción y la revierte al final: no depende del seed.
begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

-- ---------------------------------------------------------------
-- Datos
--   A  free: biología 6, arte 5, cocina 2, sin chispas entre biología y arte
--   B  free: biología 4 listas + 2 borradores + 3 de la biblioteca, arte 5 (biología no llega a 5 propias)
--   C  pro: tecnología 10, biología 6, arte 6; tecnología y biología ya se cruzaron 3 veces
--   G  invitado
-- ---------------------------------------------------------------
insert into auth.users (id, email, aud, role, is_anonymous) values
  ('92000000-0000-4000-8000-00000000000a', 'a@puente.test', 'authenticated', 'authenticated', false),
  ('92000000-0000-4000-8000-00000000000b', 'b@puente.test', 'authenticated', 'authenticated', false),
  ('92000000-0000-4000-8000-00000000000c', 'c@puente.test', 'authenticated', 'authenticated', false),
  ('92000000-0000-4000-8000-00000000000d', null, 'authenticated', 'authenticated', true);

insert into public.profiles (id, plan, timezone) values
  ('92000000-0000-4000-8000-00000000000a', 'free', 'America/Argentina/Buenos_Aires'),
  ('92000000-0000-4000-8000-00000000000b', 'free', 'America/Argentina/Buenos_Aires'),
  ('92000000-0000-4000-8000-00000000000c', 'pro', 'Asia/Tokyo'),
  ('92000000-0000-4000-8000-00000000000d', 'free', 'America/Argentina/Buenos_Aires')
on conflict (id) do update set plan = excluded.plan, timezone = excluded.timezone;

-- Guarda n neuronas de un dominio.
create function pg_temp.concepts(p_user uuid, p_domain text, n int, p_status text default 'ready', p_library boolean default false)
returns void language sql as $$
  insert into public.concepts (user_id, domain, title, thesis, source_type, status, from_library)
  select p_user, p_domain, p_domain || ' ' || g, 'Tesis.', 'text', p_status, p_library from generate_series(1, n) g;
$$;

-- Una chispa entre la k-ésima neurona de cada dominio (k desde 0).
create function pg_temp.spark(p_user uuid, p_domain_a text, p_domain_b text, k int) returns void language sql as $$
  with a as (select id from public.concepts where user_id = p_user and domain = p_domain_a order by id offset k limit 1),
       b as (select id from public.concepts where user_id = p_user and domain = p_domain_b order by id offset k limit 1)
  insert into public.sparks (user_id, concept_lo, concept_hi, title, body, status)
  select p_user, least(a.id, b.id), greatest(a.id, b.id), 'Chispa', 'Cuerpo.', 'revealed' from a, b;
$$;

select pg_temp.concepts('92000000-0000-4000-8000-00000000000a', 'biologia', 6);
select pg_temp.concepts('92000000-0000-4000-8000-00000000000a', 'arte', 5);
select pg_temp.concepts('92000000-0000-4000-8000-00000000000a', 'cocina', 2);
select pg_temp.spark('92000000-0000-4000-8000-00000000000a', 'biologia', 'cocina', 0);

select pg_temp.concepts('92000000-0000-4000-8000-00000000000b', 'biologia', 4);
select pg_temp.concepts('92000000-0000-4000-8000-00000000000b', 'biologia', 2, 'draft');
select pg_temp.concepts('92000000-0000-4000-8000-00000000000b', 'biologia', 3, 'ready', true);
select pg_temp.concepts('92000000-0000-4000-8000-00000000000b', 'arte', 5);

select pg_temp.concepts('92000000-0000-4000-8000-00000000000c', 'tecnologia', 10);
select pg_temp.concepts('92000000-0000-4000-8000-00000000000c', 'biologia', 6);
select pg_temp.concepts('92000000-0000-4000-8000-00000000000c', 'arte', 6);
select pg_temp.spark('92000000-0000-4000-8000-00000000000c', 'tecnologia', 'biologia', k) from generate_series(0, 2) k;

-- ---------------------------------------------------------------
-- Detección
-- ---------------------------------------------------------------
select results_eq(
  $$ select domain_a, domain_b, concepts_a, concepts_b, crossings from public.bridge_domain_pair('92000000-0000-4000-8000-00000000000a') $$,
  $$ values ('arte', 'biologia', 5, 6, 0) $$,
  'dos dominios fuertes que nunca se cruzaron: arte y biología (cocina no llega al mínimo)'
);
select is((select count(*)::int from public.bridge_domain_pair('92000000-0000-4000-8000-00000000000b')), 0,
  'los borradores y las neuronas de la biblioteca no cuentan para "mucho"');
select results_eq(
  $$ select domain_a, domain_b from public.bridge_domain_pair('92000000-0000-4000-8000-00000000000c') $$,
  $$ values ('arte', 'tecnologia') $$,
  'entre varios dominios fuertes elige el par más grande y parejo que no se cruzó (no tecnología–biología)'
);

-- Una chispa entre los dos todavía es "casi no se cruzaron"; dos ya no.
select pg_temp.spark('92000000-0000-4000-8000-00000000000a', 'arte', 'biologia', 0);
select results_eq(
  $$ select domain_a, domain_b, crossings from public.bridge_domain_pair('92000000-0000-4000-8000-00000000000a') $$,
  $$ values ('arte', 'biologia', 1) $$,
  'con una sola chispa entre los dos sigue siendo un par puente'
);
select pg_temp.spark('92000000-0000-4000-8000-00000000000a', 'arte', 'biologia', 1);
select is((select count(*)::int from public.bridge_domain_pair('92000000-0000-4000-8000-00000000000a')), 0,
  'con dos chispas entre los dos ya se cruzaron: no hay par');

-- Los umbrales se cambian en app_config sin publicar versión.
update public.app_config set value = '3' where key = 'bridge_topics_max_crossings';
select is((select domain_a || '+' || domain_b from public.bridge_domain_pair('92000000-0000-4000-8000-00000000000a')), 'arte+biologia',
  'bridge_topics_max_crossings sube el tope de cruces');
update public.app_config set value = '1' where key = 'bridge_topics_max_crossings';
update public.app_config set value = '7' where key = 'bridge_topics_min_concepts';
select is((select count(*)::int from public.bridge_domain_pair('92000000-0000-4000-8000-00000000000c')), 0,
  'bridge_topics_min_concepts sube el mínimo de neuronas por dominio');
update public.app_config set value = '5' where key = 'bridge_topics_min_concepts';

-- ---------------------------------------------------------------
-- Cupo: una llamada por semana, free y Pro; el invitado no tiene
-- ---------------------------------------------------------------
select is(public.consume_credit('92000000-0000-4000-8000-00000000000a', 'bridge_topics'), true, 'free: la primera de la semana tiene cupo');
select is(public.consume_credit('92000000-0000-4000-8000-00000000000a', 'bridge_topics'), false, 'free: la segunda de la semana no');
select is(public.consume_credit('92000000-0000-4000-8000-00000000000c', 'bridge_topics'), true, 'pro: la primera de la semana tiene cupo');
select is(public.consume_credit('92000000-0000-4000-8000-00000000000c', 'bridge_topics'), false, 'pro: también una sola por semana');
select is(public.consume_credit('92000000-0000-4000-8000-00000000000d', 'bridge_topics'), false, 'invitado: sin cupo (nada de IA)');

select is(public.refund_credit('92000000-0000-4000-8000-00000000000a', 'bridge_topics'), true, 'si la IA falla se devuelve el cupo');
select is(public.consume_credit('92000000-0000-4000-8000-00000000000a', 'bridge_topics'), true, 'y se puede volver a pedir esa semana');

select is(extract(isodow from public.period_start('week', 'Asia/Tokyo'))::int, 1, 'la semana arranca el lunes, en la zona del usuario');
select is(
  (select period_start from public.usage_ledger where user_id = '92000000-0000-4000-8000-00000000000c' and kind = 'bridge_topics'),
  public.period_start('week', 'Asia/Tokyo'),
  'el cupo se cuenta por la semana local del usuario'
);
-- Lo usado la semana pasada no cuenta para esta.
update public.usage_ledger set period_start = period_start - 7
 where user_id = '92000000-0000-4000-8000-00000000000a' and kind = 'bridge_topics';
select is(public.consume_credit('92000000-0000-4000-8000-00000000000a', 'bridge_topics'), true, 'una semana nueva tiene cupo nuevo');

-- ---------------------------------------------------------------
-- La sugerencia de la semana
-- ---------------------------------------------------------------
insert into public.bridge_topics (user_id, domain_a, domain_b, topics, locale, prompt_version, model, created_at) values
  ('92000000-0000-4000-8000-00000000000a', 'arte', 'biologia',
   '[{"title": "Biomimética", "why": "Viejo."}, {"title": "Bioarte", "why": "Viejo."}]', 'es', 'bridge.v1', 'local', now() - interval '8 days');
select is((select count(*)::int from public.current_bridge_topics('92000000-0000-4000-8000-00000000000a')), 0,
  'la de una semana anterior ya no se muestra');
insert into public.bridge_topics (user_id, domain_a, domain_b, topics, locale, prompt_version, model) values
  ('92000000-0000-4000-8000-00000000000a', 'arte', 'biologia',
   '[{"title": "Bioarte", "why": "Arte con materia viva."}, {"title": "Biomimética", "why": "Diseño que copia la naturaleza."}]',
   'es', 'bridge.v1', 'local');
select is((select topics->0->>'title' from public.current_bridge_topics('92000000-0000-4000-8000-00000000000a')), 'Bioarte',
  'devuelve la de esta semana');
select is((select count(*)::int from public.current_bridge_topics('92000000-0000-4000-8000-00000000000c')), 0,
  'cada uno ve solo la suya');

select throws_ok($$ insert into public.bridge_topics (user_id, domain_a, domain_b, topics, locale, prompt_version, model)
  values ('92000000-0000-4000-8000-00000000000a', 'arte', 'biologia', '[{"title": "Bioarte", "why": "Uno solo."}]', 'es', 'bridge.v1', 'local') $$,
  '23514', null, 'nunca menos de 2 temas');
select throws_ok($$ insert into public.bridge_topics (user_id, domain_a, domain_b, topics, locale, prompt_version, model)
  values ('92000000-0000-4000-8000-00000000000a', 'biologia', 'arte', '[{"title": "a", "why": "a"}, {"title": "b", "why": "b"}]', 'es', 'bridge.v1', 'local') $$,
  '23514', null, 'el par de dominios se guarda ordenado');

-- ---------------------------------------------------------------
-- Lo que ve la app
-- ---------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', '{"sub": "92000000-0000-4000-8000-00000000000c", "role": "authenticated"}', true);
select results_eq(
  $$ select kind, period, max_count, remaining from public.credit_status() where kind = 'bridge_topics' $$,
  $$ values ('bridge_topics', 'week', 1, 0) $$,
  'credit_status: pro ve su cupo semanal de temas puente'
);
select throws_ok($$ select * from public.current_bridge_topics(auth.uid()) $$, '42501', null,
  'current_bridge_topics: la app no puede llamarla');
reset role;

select * from finish();
rollback;
