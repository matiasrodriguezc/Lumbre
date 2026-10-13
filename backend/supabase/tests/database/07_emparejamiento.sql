-- Emparejamiento con datos sintéticos: vectores armados a mano en un plano (ángulo θ → (cos θ, sin θ, 0, …)),
-- así la distancia coseno entre dos conceptos es 1 − cos(θa − θb) y se puede razonar sobre los percentiles.
-- Los conceptos usan el modelo 'test': la biblioteca solo entra cuando el test le pone ese modelo.
begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

create function pg_temp.vec(theta float8) returns extensions.vector language sql immutable as $$
  select (array[cos(theta), sin(theta)] || array_fill(0::float8, array[1022]))::extensions.vector(1024);
$$;

-- Crea un concepto listo con su vector.
create function pg_temp.concept(p_id uuid, p_user uuid, p_domain text, p_theta float8, p_category uuid default null)
returns void language sql as $$
  insert into public.concepts (id, user_id, domain, category_id, title, thesis, source_type, embedding, embedding_model)
  values (p_id, p_user, p_domain, p_category, 'C ' || left(p_id::text, 8), 'Tesis.', 'text', pg_temp.vec(p_theta), 'test');
$$;

-- Corre el emparejamiento n veces sin crear chispas y devuelve los pares elegidos.
create function pg_temp.picks(p_user uuid, n int, p_extra boolean default false)
returns table (lo uuid, hi uuid, pct int, lib boolean)
language sql volatile as $$
  select p.concept_lo, p.concept_hi, p.distance_percentile, p.uses_library
  -- El parámetro depende de g para que se ejecute una vez por fila (si no, Postgres la evalúa una sola vez).
  from generate_series(1, n) g, lateral public.pick_spark_pair(p_user, p_extra and g > 0) p;
$$;

insert into auth.users (id, email, aud, role) values
  ('70000000-0000-4000-8000-000000000001', 'dom@pares.test', 'authenticated', 'authenticated'),
  ('70000000-0000-4000-8000-000000000002', 'banda@pares.test', 'authenticated', 'authenticated'),
  ('70000000-0000-4000-8000-000000000003', 'lib@pares.test', 'authenticated', 'authenticated'),
  ('70000000-0000-4000-8000-000000000004', 'vacio@pares.test', 'authenticated', 'authenticated'),
  ('70000000-0000-4000-8000-000000000005', 'extra@pares.test', 'authenticated', 'authenticated'),
  ('70000000-0000-4000-8000-000000000006', 'cat@pares.test', 'authenticated', 'authenticated');

-- ---------------------------------------------------------------
-- Dominios distintos, descanso y pares que no se repiten (usuario D)
-- ---------------------------------------------------------------
-- A y B son casi iguales y del mismo dominio: serían el par más "cercano", pero no cruzan mundos.
select pg_temp.concept('70000000-0000-4000-8000-0000000000a1', '70000000-0000-4000-8000-000000000001', 'cocina', 0.00);
select pg_temp.concept('70000000-0000-4000-8000-0000000000a2', '70000000-0000-4000-8000-000000000001', 'cocina', 0.05);
select pg_temp.concept('70000000-0000-4000-8000-0000000000a3', '70000000-0000-4000-8000-000000000001', 'fisica', 1.20);
select pg_temp.concept('70000000-0000-4000-8000-0000000000a4', '70000000-0000-4000-8000-000000000001', 'musica', 2.00);

select is((select count(*)::int from pg_temp.picks('70000000-0000-4000-8000-000000000001', 30)
            where lo = '70000000-0000-4000-8000-0000000000a1' and hi = '70000000-0000-4000-8000-0000000000a2'), 0,
  'nunca empareja dos conceptos del mismo dominio');
select is((select candidates_count from public.pick_spark_pair('70000000-0000-4000-8000-000000000001')), 5,
  'cuenta los candidatos: 6 pares menos el del mismo dominio');
select ok((select bool_and(lo < hi) from pg_temp.picks('70000000-0000-4000-8000-000000000001', 10)),
  'devuelve el par ordenado (lo < hi)');

-- Descanso: el de física apareció ayer.
update public.concepts set last_used_at = now() - interval '1 day' where id = '70000000-0000-4000-8000-0000000000a3';
select is((select count(*)::int from pg_temp.picks('70000000-0000-4000-8000-000000000001', 30)
            where '70000000-0000-4000-8000-0000000000a3' in (lo, hi)), 0,
  'un concepto usado hace menos de 3 días descansa');
update public.concepts set last_used_at = now() - interval '4 days' where id = '70000000-0000-4000-8000-0000000000a3';
select ok((select count(*) from pg_temp.picks('70000000-0000-4000-8000-000000000001', 40)
            where '70000000-0000-4000-8000-0000000000a3' in (lo, hi)) > 0,
  'después de 3 días vuelve a estar disponible');

-- No repetir: la chispa A1–A4 ya existe (y se quita el descanso para aislar la regla).
select isnt(public.create_spark('70000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-0000000000a4',
                                '70000000-0000-4000-8000-0000000000a1', 'extra', 'T', 'B', 0.5, 50), null,
  'create_spark: crea la chispa con el par en cualquier orden');
select ok((select bool_and(last_used_at > now() - interval '1 minute') from public.concepts
            where id in ('70000000-0000-4000-8000-0000000000a1', '70000000-0000-4000-8000-0000000000a4')),
  'create_spark: marca el uso de los dos conceptos');
select is(public.create_spark('70000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-0000000000a1',
                              '70000000-0000-4000-8000-0000000000a4', 'extra', 'T', 'B'), null,
  'create_spark: el mismo par no se crea dos veces');
update public.concepts set last_used_at = null where user_id = '70000000-0000-4000-8000-000000000001';
select is((select count(*)::int from pg_temp.picks('70000000-0000-4000-8000-000000000001', 30)
            where lo = '70000000-0000-4000-8000-0000000000a1' and hi = '70000000-0000-4000-8000-0000000000a4'), 0,
  'un par que ya fue chispa no se repite');
select throws_ok($$ select public.create_spark('70000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-0000000000a1',
                                               '70000000-0000-4000-8000-0000000000b1', 'extra', 'T', 'B') $$,
  '22023', 'invalid_request', 'create_spark: no acepta conceptos de otro usuario');

-- Sin dominio todavía: cruza categorías distintas.
insert into public.categories (id, user_id, name) values
  ('70000000-0000-4000-8000-0000000000c1', '70000000-0000-4000-8000-000000000006', 'Una'),
  ('70000000-0000-4000-8000-0000000000c2', '70000000-0000-4000-8000-000000000006', 'Otra');
select pg_temp.concept('70000000-0000-4000-8000-0000000000f1', '70000000-0000-4000-8000-000000000006', null, 0.0, '70000000-0000-4000-8000-0000000000c1');
select pg_temp.concept('70000000-0000-4000-8000-0000000000f2', '70000000-0000-4000-8000-000000000006', null, 0.1, '70000000-0000-4000-8000-0000000000c1');
select pg_temp.concept('70000000-0000-4000-8000-0000000000f3', '70000000-0000-4000-8000-000000000006', null, 1.0, '70000000-0000-4000-8000-0000000000c2');
select is((select count(*)::int from pg_temp.picks('70000000-0000-4000-8000-000000000006', 30)
            where lo = '70000000-0000-4000-8000-0000000000f1' and hi = '70000000-0000-4000-8000-0000000000f2'), 0,
  'sin dominio, nunca empareja dos conceptos de la misma categoría');

-- ---------------------------------------------------------------
-- Banda media relativa al usuario (usuario N: 10 dominios, 45 pares)
-- ---------------------------------------------------------------
select pg_temp.concept(('70000000-0000-4000-8000-0000000001' || lpad(g::text, 2, '0'))::uuid,
                       '70000000-0000-4000-8000-000000000002',
                       (array['tecnologia', 'ingenieria', 'fisica', 'quimica', 'biologia',
                              'salud', 'psicologia', 'economia', 'negocios', 'marketing'])[g],
                       (g * g) * 0.031)
from generate_series(1, 10) g;

select ok((select bool_and(pct between 40 and 80) from pg_temp.picks('70000000-0000-4000-8000-000000000002', 40)),
  'con el centro en 0,6 elige siempre entre los percentiles 40 y 80');
update public.profiles set target_distance = 0.35 where id = '70000000-0000-4000-8000-000000000002';
select ok((select bool_and(pct between 15 and 55) from pg_temp.picks('70000000-0000-4000-8000-000000000002', 40)),
  'si el feedback baja el centro a 0,35, elige pares más cercanos (percentiles 15 a 55)');
select ok((select count(distinct (lo, hi)) from pg_temp.picks('70000000-0000-4000-8000-000000000002', 60)) > 3,
  'elige al azar entre los mejores, no siempre el mismo');
select ok(public.spark_runway_days('70000000-0000-4000-8000-000000000002') between 10 and 30,
  'spark_runway_days: cuenta los pares en la banda');

-- ---------------------------------------------------------------
-- Respaldo con la biblioteca (usuario L: un solo concepto)
-- ---------------------------------------------------------------
update public.profiles set creative_profiles = array['curiosity'] where id = '70000000-0000-4000-8000-000000000003';
select pg_temp.concept('70000000-0000-4000-8000-0000000002a1', '70000000-0000-4000-8000-000000000003', 'cocina', 0.0);
select is((select count(*)::int from public.pick_spark_pair('70000000-0000-4000-8000-000000000003')), 0,
  'sin par y sin biblioteca para su modelo de embeddings, no hay chispa');

update public.library_concepts set embedding = pg_temp.vec(0.9), embedding_model = 'test'
 where title in ('Entropía', 'Masa madre');
create temp table lib_pick as select * from public.pick_spark_pair('70000000-0000-4000-8000-000000000003');
select is((select uses_library from lib_pick), true, 'sin par posible, combina con un concepto de la biblioteca');
select results_eq(
  $$ select c.title, c.from_library, c.domain, cat.name
       from public.concepts c join public.categories cat on cat.id = c.category_id
      where c.user_id = '70000000-0000-4000-8000-000000000003' and c.from_library $$,
  $$ values ('Entropía', true, 'fisica', 'Física y astronomía') $$,
  'copia el concepto de su perfil (no el de otro dominio igual al suyo) a una categoría con el nombre del dominio');
select ok((select '70000000-0000-4000-8000-0000000002a1' in (lo_hi.concept_lo, lo_hi.concept_hi) from lib_pick lo_hi),
  'el par incluye el concepto del usuario');
select is((select count(*)::int from public.pick_spark_pair('70000000-0000-4000-8000-000000000003') where uses_library), 0,
  'la copia ya es suya: la próxima vez empareja sin volver a copiar');

-- Sin conceptos con embedding: nada.
insert into public.concepts (user_id, domain, title, thesis, source_type)
values ('70000000-0000-4000-8000-000000000004', 'cocina', 'Sin vector', 'Tesis.', 'text');
select is((select count(*)::int from public.pick_spark_pair('70000000-0000-4000-8000-000000000004')), 0,
  'sin conceptos con embedding no devuelve filas');

-- ---------------------------------------------------------------
-- Extra: sin pares descansados, no toca la chispa diaria de hoy (usuario E)
-- ---------------------------------------------------------------
update public.library_concepts set embedding = null, embedding_model = null where embedding_model = 'test';
select pg_temp.concept('70000000-0000-4000-8000-0000000003a1', '70000000-0000-4000-8000-000000000005', 'arte', 0.0);
select pg_temp.concept('70000000-0000-4000-8000-0000000003a2', '70000000-0000-4000-8000-000000000005', 'deporte', 0.8);
select pg_temp.concept('70000000-0000-4000-8000-0000000003a3', '70000000-0000-4000-8000-000000000005', 'juegos', 1.6);
select public.create_spark('70000000-0000-4000-8000-000000000005', '70000000-0000-4000-8000-0000000003a1',
                           '70000000-0000-4000-8000-0000000003a2', 'daily', 'Diaria', 'B', null, null, false,
                           (now() at time zone 'America/Argentina/Buenos_Aires')::date);
select is((select count(*)::int from public.pick_spark_pair('70000000-0000-4000-8000-000000000005', true)), 0,
  'extra: no usa los conceptos de la chispa diaria de hoy');
select ok((select count(*) = 1 from public.pick_spark_pair('70000000-0000-4000-8000-000000000005', false)),
  'diaria: antes que dejar Hoy vacía, acepta conceptos sin descanso');
select is(public.create_spark('70000000-0000-4000-8000-000000000005', '70000000-0000-4000-8000-0000000003a2',
                              '70000000-0000-4000-8000-0000000003a3', 'daily', 'Otra', 'B', null, null, false,
                              (now() at time zone 'America/Argentina/Buenos_Aires')::date), null,
  'create_spark: una sola chispa diaria por día');

select * from finish();
rollback;
