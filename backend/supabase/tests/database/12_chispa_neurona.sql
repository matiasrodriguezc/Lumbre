-- La chispa guardada se vuelve neurona (paso 88, flag spark_neuron): save_spark() la crea, no gasta cupo ni suma
-- para la chispa extra, toma dominio al tener vector y el emparejamiento nunca la cruza con sus padres.
-- Mismos vectores de juguete que 07_emparejamiento: ángulo θ → (cos θ, sin θ, 0, …), modelo 'test'.
begin;
create extension if not exists pgtap with schema extensions;
select plan(36);

create function pg_temp.vec(theta float8) returns extensions.vector language sql immutable as $$
  select (array[cos(theta), sin(theta)] || array_fill(0::float8, array[1022]))::extensions.vector(1024);
$$;

create function pg_temp.concept(p_id uuid, p_user uuid, p_domain text, p_theta float8)
returns void language sql as $$
  insert into public.concepts (id, user_id, domain, title, thesis, source_type, embedding, embedding_model)
  values (p_id, p_user, p_domain, 'C ' || left(p_id::text, 8), 'Tesis.', 'text', pg_temp.vec(p_theta), 'test');
$$;

create function pg_temp.login(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
$$;
grant execute on function pg_temp.login(uuid) to authenticated;

-- Corre el emparejamiento n veces sin crear chispas.
create function pg_temp.picks(p_user uuid, n int, p_extra boolean default false)
returns table (lo uuid, hi uuid)
language sql volatile as $$
  select p.concept_lo, p.concept_hi
  from generate_series(1, n) g, lateral public.pick_spark_pair(p_user, p_extra and g > 0) p;
$$;

insert into auth.users (id, email, aud, role) values
  ('88000000-0000-4000-8000-000000000001', 'a@chispa-neurona.test', 'authenticated', 'authenticated'),
  ('88000000-0000-4000-8000-000000000002', 'b@chispa-neurona.test', 'authenticated', 'authenticated');

-- A: dos padres (cocina y física) y tres neuronas más. B: una chispa y un circuito.
select pg_temp.concept('88000000-0000-4000-8000-0000000000a1', '88000000-0000-4000-8000-000000000001', 'cocina', 0.0);
select pg_temp.concept('88000000-0000-4000-8000-0000000000a2', '88000000-0000-4000-8000-000000000001', 'fisica', 1.2);
select pg_temp.concept('88000000-0000-4000-8000-0000000000a3', '88000000-0000-4000-8000-000000000001', 'musica', 2.0);
select pg_temp.concept('88000000-0000-4000-8000-0000000000a4', '88000000-0000-4000-8000-000000000001', 'arte', 2.6);
select pg_temp.concept('88000000-0000-4000-8000-0000000000a5', '88000000-0000-4000-8000-000000000001', 'tecnologia', 3.0);
select pg_temp.concept('88000000-0000-4000-8000-0000000000b1', '88000000-0000-4000-8000-000000000002', 'cocina', 0.0);
select pg_temp.concept('88000000-0000-4000-8000-0000000000b2', '88000000-0000-4000-8000-000000000002', 'fisica', 1.2);

insert into public.sparks (id, user_id, concept_lo, concept_hi, mode, title, body, status) values
  ('88000000-0000-4000-8000-0000000005a1', '88000000-0000-4000-8000-000000000001',
   '88000000-0000-4000-8000-0000000000a1', '88000000-0000-4000-8000-0000000000a2', 'daily',
   '  Masa   madre cuántica ', 'Una levadura que solo crece si nadie la mira.', 'revealed'),
  ('88000000-0000-4000-8000-0000000005a2', '88000000-0000-4000-8000-000000000001',
   '88000000-0000-4000-8000-0000000000a3', '88000000-0000-4000-8000-0000000000a4', 'extra', 'Sin flag', 'Cuerpo.', 'revealed'),
  ('88000000-0000-4000-8000-0000000005a3', '88000000-0000-4000-8000-000000000001',
   '88000000-0000-4000-8000-0000000000a1', '88000000-0000-4000-8000-0000000000a3', 'extra', 'Servidor apagado', 'Cuerpo.', 'revealed'),
  ('88000000-0000-4000-8000-0000000005b1', '88000000-0000-4000-8000-000000000002',
   '88000000-0000-4000-8000-0000000000b1', '88000000-0000-4000-8000-0000000000b2', 'daily', 'De B', 'Cuerpo.', 'revealed');
insert into public.projects (id, user_id, name) values
  ('88000000-0000-4000-8000-0000000006a1', '88000000-0000-4000-8000-000000000001', 'Circuito de A'),
  ('88000000-0000-4000-8000-0000000006b1', '88000000-0000-4000-8000-000000000002', 'Circuito de B');
delete from public.analytics_outbox where distinct_id = '88000000-0000-4000-8000-000000000001';

-- ---------------------------------------------------------------
-- Guardar como A
-- ---------------------------------------------------------------
set local role authenticated;
select pg_temp.login('88000000-0000-4000-8000-000000000001');

create temp table neuron as
  select public.save_spark('88000000-0000-4000-8000-0000000005a1', null, true) as id;
select isnt((select id from neuron), null, 'save_spark: con p_as_neuron devuelve la neurona que nació de la chispa');
select results_eq(
  $$ select c.title, c.thesis, c.source_type, c.status, c.origin_spark_id, c.origin_lo, c.origin_hi,
            c.category_id is null, c.embedding is null, c.from_library
       from public.concepts c where c.id = (select id from neuron) $$,
  $$ values ('Masa madre cuántica'::text, 'Una levadura que solo crece si nadie la mira.'::text, 'spark'::text, 'ready'::text,
             '88000000-0000-4000-8000-0000000005a1'::uuid, '88000000-0000-4000-8000-0000000000a1'::uuid,
             '88000000-0000-4000-8000-0000000000a2'::uuid, true, true, false) $$,
  'la neurona lleva el título y el cuerpo de la chispa, sus dos padres y queda para embeber en el servidor');
select is((select status from public.sparks where id = '88000000-0000-4000-8000-0000000005a1'), 'saved',
  'save_spark: la chispa queda guardada');
select is((select count(*)::int from public.concepts where source_type = 'spark'), 1, 'A ve su neurona nueva en la Red');

select is(public.save_spark('88000000-0000-4000-8000-0000000005a1', '88000000-0000-4000-8000-0000000006a1', true),
          (select id from neuron), 'mover la chispa a un circuito devuelve la misma neurona');
select is((select count(*)::int from public.concepts where origin_spark_id = '88000000-0000-4000-8000-0000000005a1'), 1,
  'mover la chispa no crea otra neurona');
select is((select project_id from public.sparks where id = '88000000-0000-4000-8000-0000000005a1'),
          '88000000-0000-4000-8000-0000000006a1'::uuid, 'save_spark: guarda el circuito');

select is(public.save_spark('88000000-0000-4000-8000-0000000005a2', null, false), null,
  'con el flag de la app apagado guarda la chispa sin crear neurona');
select is((select status from public.sparks where id = '88000000-0000-4000-8000-0000000005a2'), 'saved',
  'con el flag apagado la chispa se guarda igual');

select throws_ok($$ select public.save_spark('88000000-0000-4000-8000-0000000005b1', null, true) $$,
  'P0002', 'not_found', 'save_spark: no guarda una chispa de otro usuario');
select throws_ok($$ select public.save_spark('88000000-0000-4000-8000-0000000005a3', '88000000-0000-4000-8000-0000000006b1', true) $$,
  'P0002', 'not_found', 'save_spark: no usa el circuito de otro usuario');
select throws_ok($$ select public.create_spark_neuron('88000000-0000-4000-8000-0000000005a3') $$,
  '42501', null, 'la app no puede crear neuronas de chispa directo');
select throws_ok($$ update public.concepts set origin_lo = null where id = (select id from neuron) $$,
  '42501', null, 'la app no puede cambiar los padres de la neurona');
reset role;

select throws_ok($$ select public.save_spark('88000000-0000-4000-8000-0000000005a3', null, true) $$,
  '28000', 'not_authenticated', 'save_spark: sin sesión no hace nada');

-- Servidor apagado: aunque la app lo pida, no hay neurona.
update public.app_config set value = 'false' where key = 'spark_neuron_enabled';
set local role authenticated;
select pg_temp.login('88000000-0000-4000-8000-000000000001');
select is(public.save_spark('88000000-0000-4000-8000-0000000005a3', null, true), null,
  'con app_config.spark_neuron_enabled en false no se crea la neurona');
reset role;
update public.app_config set value = 'true' where key = 'spark_neuron_enabled';

select results_eq(
  $$ select event, properties from public.analytics_outbox
      where distinct_id = '88000000-0000-4000-8000-000000000001' and event = 'spark_neuron_created' $$,
  $$ values ('spark_neuron_created'::text, '{"mode": "daily", "parent_is_spark_neuron": false}'::jsonb) $$,
  'spark_neuron_created: un evento por neurona, sin contenido');

-- ---------------------------------------------------------------
-- Cupos: no gasta captura ni suma para la chispa extra
-- ---------------------------------------------------------------
select is((select count(*)::int from public.usage_ledger
            where user_id = '88000000-0000-4000-8000-000000000001' and kind = 'capture'), 0,
  'la neurona de chispa no gasta cupo de captura');
select is(public.concepts_saved_since('88000000-0000-4000-8000-000000000001',
                                      (now() at time zone 'America/Argentina/Buenos_Aires')::date,
                                      'America/Argentina/Buenos_Aires'), 5,
  'concepts_saved_since no cuenta la neurona de chispa: guardar chispas no da chispas');

-- ---------------------------------------------------------------
-- Dominio por cercanía al tener vector
-- ---------------------------------------------------------------
update public.domains set embedding = pg_temp.vec(0.0), embedding_model = 'test' where slug = 'cocina';
update public.domains set embedding = pg_temp.vec(1.2), embedding_model = 'test' where slug = 'fisica';
update public.domains set embedding = pg_temp.vec(2.0), embedding_model = 'test' where slug = 'musica';
update public.domains set embedding = pg_temp.vec(2.6), embedding_model = 'test' where slug = 'arte';
-- θ = 1,7: queda en música, un mundo distinto de los dos padres (cocina y física), así solo la regla la separa de ellos.
update public.concepts set embedding = pg_temp.vec(1.7), embedding_model = 'test' where id = (select id from neuron);
select is((select domain from public.concepts where id = (select id from neuron)), 'musica',
  'al embeberse toma el dominio más cercano a su vector');
select is((select domain from public.concepts where id = '88000000-0000-4000-8000-0000000000a1'), 'cocina',
  'el dominio por cercanía es solo para las neuronas de chispa sin categoría');

-- ---------------------------------------------------------------
-- Emparejamiento: nunca con sus padres
-- ---------------------------------------------------------------
select is((select count(*)::int from public.spark_pairs('88000000-0000-4000-8000-000000000001') p
            where (select id from neuron) in (p.lo, p.hi)
              and ('88000000-0000-4000-8000-0000000000a1' in (p.lo, p.hi) or '88000000-0000-4000-8000-0000000000a2' in (p.lo, p.hi))), 0,
  'spark_pairs: la neurona nunca forma par con sus padres');
select is((select count(*)::int from public.spark_pairs('88000000-0000-4000-8000-000000000001') p
            where (select id from neuron) in (p.lo, p.hi)), 2,
  'spark_pairs: sí forma par con las otras de otro dominio (arte y tecnología)');

-- Música y tecnología descansan: quedan los dos padres, arte y la neurona. Los pares de la neurona con sus padres
-- serían candidatos (descansados, sin usar y de otro dominio) si no fuera por la regla.
update public.concepts set last_used_at = now()
 where id in ('88000000-0000-4000-8000-0000000000a3', '88000000-0000-4000-8000-0000000000a5');
select is((select count(*)::int from pg_temp.picks('88000000-0000-4000-8000-000000000001', 60)
            where (select id from neuron) in (lo, hi)
              and ('88000000-0000-4000-8000-0000000000a1' in (lo, hi) or '88000000-0000-4000-8000-0000000000a2' in (lo, hi))), 0,
  'pick_spark_pair (diaria): nunca la cruza con sus padres');
select is((select count(*)::int from pg_temp.picks('88000000-0000-4000-8000-000000000001', 60, true)
            where (select id from neuron) in (lo, hi)
              and ('88000000-0000-4000-8000-0000000000a1' in (lo, hi) or '88000000-0000-4000-8000-0000000000a2' in (lo, hi))), 0,
  'pick_spark_pair (extra): nunca la cruza con sus padres');

-- Con los padres también descansando, el único par que queda es la neurona con arte.
update public.concepts set last_used_at = now()
 where id in ('88000000-0000-4000-8000-0000000000a1', '88000000-0000-4000-8000-0000000000a2');
select results_eq(
  $$ select concept_lo, concept_hi, uses_library from public.pick_spark_pair('88000000-0000-4000-8000-000000000001') $$,
  $$ select least((select id from neuron), '88000000-0000-4000-8000-0000000000a4'::uuid),
            greatest((select id from neuron), '88000000-0000-4000-8000-0000000000a4'::uuid), false $$,
  'la neurona de chispa sale en una chispa nueva con otra neurona');

select throws_ok(format($$ select public.create_spark('88000000-0000-4000-8000-000000000001', %L,
                                                      '88000000-0000-4000-8000-0000000000a2', 'pick', 'T', 'B') $$,
                        (select id from neuron)),
  '22023', 'invalid_request', 'create_spark: rechaza la neurona con uno de sus padres');
select ok(public.is_spark_parent('88000000-0000-4000-8000-0000000000a1', (select id from neuron)),
  'is_spark_parent: en cualquier orden');
select ok(not public.is_spark_parent('88000000-0000-4000-8000-0000000000a4', (select id from neuron)),
  'is_spark_parent: falso para una neurona que no es padre');

-- Una chispa de la neurona con arte, guardada, da una nieta: sus padres son la neurona y arte.
create temp table child_spark as
  select public.create_spark('88000000-0000-4000-8000-000000000001', (select id from neuron),
                             '88000000-0000-4000-8000-0000000000a4', 'extra', 'Nieta', 'Cuerpo de la nieta.') as id;
select isnt((select id from child_spark), null, 'create_spark: la neurona se combina con otra que no es su padre');
set local role authenticated;
select pg_temp.login('88000000-0000-4000-8000-000000000001');
create temp table grandchild as select public.save_spark((select id from child_spark), null, true) as id;
reset role;
select results_eq(
  $$ select origin_lo, origin_hi from public.concepts where id = (select id from grandchild) $$,
  $$ select least((select id from neuron), '88000000-0000-4000-8000-0000000000a4'::uuid),
            greatest((select id from neuron), '88000000-0000-4000-8000-0000000000a4'::uuid) $$,
  'una chispa de una neurona de chispa también se vuelve neurona, con sus dos padres');
select is((select properties ->> 'parent_is_spark_neuron' from public.analytics_outbox
            where distinct_id = '88000000-0000-4000-8000-000000000001' and event = 'spark_neuron_created'
            order by id desc limit 1), 'true',
  'spark_neuron_created: marca si uno de los padres ya era neurona de chispa');

-- ---------------------------------------------------------------
-- Borrados
-- ---------------------------------------------------------------
-- Borrar un padre borra la chispa (cascade); la neurona queda, sin la referencia.
delete from public.concepts where id = '88000000-0000-4000-8000-0000000000a2';
select results_eq(
  $$ select source_type, origin_spark_id, origin_lo, origin_hi from public.concepts where id = (select id from neuron) $$,
  $$ values ('spark'::text, null::uuid, '88000000-0000-4000-8000-0000000000a1'::uuid, null::uuid) $$,
  'si se borra un padre la neurona queda, sin la chispa ni ese padre');
select is((select count(*)::int from public.spark_pairs('88000000-0000-4000-8000-000000000001') p
            where (select id from neuron) in (p.lo, p.hi) and '88000000-0000-4000-8000-0000000000a1' in (p.lo, p.hi)), 0,
  'sin la chispa, el padre que queda sigue sin cruzarse con ella');
-- Borrar la neurona borra las chispas que la usan; la nieta queda.
delete from public.concepts where id = (select id from neuron);
select is((select count(*)::int from public.concepts where id = (select id from grandchild)), 1,
  'borrar una neurona de chispa no borra las neuronas que nacieron de ella');
select lives_ok($$ delete from auth.users where id = '88000000-0000-4000-8000-000000000001' $$,
  'borrar la cuenta borra todo, con las referencias cruzadas entre neuronas y chispas');
select is((select count(*)::int from public.concepts where user_id = '88000000-0000-4000-8000-000000000001'), 0,
  'no queda ninguna neurona de la cuenta borrada');

select * from finish();
rollback;
