-- Categorías propias y capture_concept(): guardar desde la app, deduplicar nombres, cuota y aislamiento.
begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

insert into auth.users (id, email, aud, role) values
  ('c0000000-0000-4000-8000-000000000001', 'x@categorias.test', 'authenticated', 'authenticated'),
  ('c0000000-0000-4000-8000-000000000002', 'y@categorias.test', 'authenticated', 'authenticated');
insert into public.domains (slug, name_es, name_en, description)
values ('cat_test', 'Prueba', 'Test', 'Dominio de los tests de categorías.');

create function pg_temp.login(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
$$;
grant execute on function pg_temp.login(uuid) to authenticated;

-- ---------------------------------------------------------------
-- Guardar como X
-- ---------------------------------------------------------------
set local role authenticated;
select pg_temp.login('c0000000-0000-4000-8000-000000000001');

select is((select count(*)::int from public.categories), 0, 'un usuario nuevo arranca sin categorías');

select is(
  (select category_created from public.capture_concept('Limitar la oferta sube el valor percibido.', 'Economía')),
  true, 'guardar con una categoría nueva la crea');
select is(
  (select category_created from public.capture_concept('Los incentivos mueven más que las reglas.', '  economia ')),
  false, 'la misma categoría con otros acentos, mayúsculas o espacios no se duplica');
select is(
  (select category_created from public.capture_concept('El precio ancla la percepción.', 'ECONOMÍA')), false,
  'tampoco en mayúsculas');
select is((select array_agg(name) from public.categories), array['Economía'],
  'queda una sola categoría, con el nombre como se escribió la primera vez');
select is((select count(*)::int from public.concepts), 3, 'los tres conceptos quedaron guardados');
select ok((select bool_and(category_id is not null) from public.concepts), 'todos tienen categoría');

select lives_ok($$ select public.capture_concept('Un flujo en espiral separa partículas.', 'Ingeniería') $$,
  'guardar en otra categoría');
select is((select count(*)::int from public.categories), 2, 'ahora tiene dos categorías');

select results_eq(
  $$ select title, thesis from public.concepts where thesis like 'Un flujo%' $$,
  $$ values ('Un flujo en espiral separa partículas.', 'Un flujo en espiral separa partículas.') $$,
  'una tesis corta queda también como título');
select public.capture_concept(repeat('palabra ', 20), 'Ingeniería');
select ok((select title from public.concepts where thesis like 'palabra%') like '%…'
          and char_length((select title from public.concepts where thesis like 'palabra%')) <= 61,
  'una tesis larga se corta en una palabra y termina en …');

select lives_ok($$ select public.capture_concept('Un link con su idea.', 'Ingeniería', 'link', 'https://ejemplo.com/nota') $$,
  'guardar un link con su idea');
select throws_ok($$ select public.capture_concept('Link sin URL.', 'Ingeniería', 'link', null) $$, '22023', 'invalid_source',
  'un link sin URL no se guarda');
select throws_ok($$ select public.capture_concept('   ', 'Ingeniería') $$, '22023', 'invalid_thesis',
  'una tesis vacía no se guarda');
select throws_ok($$ select public.capture_concept(repeat('a', 601), 'Ingeniería') $$, '22023', 'invalid_thesis',
  'una tesis de más de 600 caracteres no se guarda');
select throws_ok($$ select public.capture_concept('Idea sin categoría.', ' ') $$, '22023', 'invalid_category',
  'sin categoría no se guarda');

-- RLS de categorías
select throws_ok($$ insert into public.categories (user_id, name) values (auth.uid(), 'Directa') $$, '42501', null,
  'las categorías no se crean directo: solo guardando un concepto');
select lives_ok($$ update public.categories set name = 'Economía conductual' where name = 'Economía' $$,
  'renombrar una categoría propia');
select throws_ok($$ update public.categories set name = 'ingenieria' where name = 'Economía conductual' $$, '23505', null,
  'renombrarla igual que otra propia choca con la existente');

-- ---------------------------------------------------------------
-- Y no ve ni usa lo de X
-- ---------------------------------------------------------------
select pg_temp.login('c0000000-0000-4000-8000-000000000002');
select is((select count(*)::int from public.categories), 0, 'Y no ve las categorías de X');
select is((select category_created from public.capture_concept('Otra persona, misma palabra.', 'Economía')), true,
  'Y crea su propia "Economía", separada de la de X');

-- ---------------------------------------------------------------
-- Como servidor
-- ---------------------------------------------------------------
reset role;

-- El dominio de la categoría pasa a los conceptos nuevos.
update public.categories set domain = 'cat_test'
 where user_id = 'c0000000-0000-4000-8000-000000000001' and name = 'Ingeniería';
set local role authenticated;
select pg_temp.login('c0000000-0000-4000-8000-000000000001');
select public.capture_concept('Con dominio asignado.', 'Ingeniería');
reset role;
select is((select domain from public.concepts where thesis = 'Con dominio asignado.'), 'cat_test',
  'un concepto nuevo hereda el dominio de su categoría');

-- La cuota de capturas se descuenta al guardar (X ya usó 7 de 30).
set local role authenticated;
select pg_temp.login('c0000000-0000-4000-8000-000000000001');
select throws_ok($$ select public.capture_concept('Una más: ' || g, 'Economía conductual') from generate_series(1, 24) g $$,
  'P0001', 'quota_exceeded', 'la captura 31 del día se rechaza por cuota');
reset role;

-- Borrar una categoría no borra sus conceptos.
delete from public.categories where user_id = 'c0000000-0000-4000-8000-000000000001' and name = 'Economía conductual';
select is(
  (select count(*)::int from public.concepts where user_id = 'c0000000-0000-4000-8000-000000000001' and category_id is null), 3,
  'borrar una categoría deja sus conceptos sin categoría, no los borra');

select * from finish();
rollback;
