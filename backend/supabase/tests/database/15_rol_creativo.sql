-- Rol propio del perfil creativo: cada uno edita el suyo, hasta 80 caracteres, y nadie toca el de otro.
begin;
select plan(5);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000000a1', 'rol-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000000b1', 'rol-b@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);

update public.profiles set creative_role = 'Diseñadora de producto' where id = '00000000-0000-0000-0000-0000000000a1';
select is((select creative_role from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'),
          'Diseñadora de producto', 'cada uno puede escribir su rol');

select throws_ok(
  $$update public.profiles set creative_role = repeat('x', 81) where id = '00000000-0000-0000-0000-0000000000a1'$$,
  '23514', null, 'más de 80 caracteres no entra');

select throws_ok(
  $$update public.profiles set creative_role = '   ' where id = '00000000-0000-0000-0000-0000000000a1'$$,
  '23514', null, 'un rol en blanco no entra (se borra con null)');

update public.profiles set creative_role = 'Hackeado' where id = '00000000-0000-0000-0000-0000000000b1';
reset role;
select is((select creative_role from public.profiles where id = '00000000-0000-0000-0000-0000000000b1'),
          null, 'el rol de otro no se puede tocar');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
update public.profiles set creative_role = null where id = '00000000-0000-0000-0000-0000000000a1';
select is((select creative_role from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'),
          null, 'se puede borrar');

select * from finish();
rollback;
