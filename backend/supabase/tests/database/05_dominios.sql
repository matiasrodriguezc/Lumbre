-- La lista cerrada de dominios: tamaño, datos completos y descripciones útiles para embeber.
begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

select ok((select count(*) from public.domains) between 20 and 25, 'la lista cerrada tiene entre 20 y 25 dominios');
select is((select count(*)::int from public.domains where slug !~ '^[a-z]+$'), 0, 'los slugs son palabras en minúscula sin acentos');
select is((select count(*)::int from public.domains
            where coalesce(name_es, '') = '' or coalesce(name_en, '') = ''
               or coalesce(symbol_ios, '') = '' or coalesce(symbol_android, '') = ''), 0,
  'todos tienen nombre en español e inglés e íconos de iOS y Android');
select is((select count(*)::int from public.domains where char_length(description) < 120), 0,
  'todas las descripciones tienen al menos 120 caracteres (se embeben para clasificar)');
select is((select count(*)::int from (select lower(name_es) from public.domains group by 1 having count(*) > 1) d), 0,
  'no hay dos dominios con el mismo nombre');
select ok(not exists (select 1 from public.domains where slug = 'urbanismo'), 'el provisorio urbanismo pasó a arquitectura');

select * from finish();
rollback;
