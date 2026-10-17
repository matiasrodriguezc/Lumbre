-- Waitlist con referidos, límites de la web y demo de la chispa (pasos 5 y 6).
begin;
create extension if not exists pgtap with schema extensions;
select plan(37);

-- Hashes de token de prueba (64 hex).
create function pg_temp.h(n int) returns text language sql immutable as $$
  select lpad(to_hex(n), 64, '0');
$$;

-- La fila arranca vacía para estos tests.
delete from public.waitlist;

-- ---------------------------------------------------------------
-- Alta
-- ---------------------------------------------------------------
select is((public.waitlist_join(' Ana@Ejemplo.test ', pg_temp.h(1), pg_temp.h(1001))).created, true, 'join: anota un email nuevo');
select is((select email from public.waitlist where token_hash = pg_temp.h(1)), 'ana@ejemplo.test', 'join: guarda el email en minúscula y sin espacios');
select matches((select referral_code from public.waitlist where token_hash = pg_temp.h(1)), '^[a-z2-9]{7}$', 'join: genera un código de referido de 7 caracteres');
select is((public.waitlist_join('ana@ejemplo.test', pg_temp.h(2), pg_temp.h(1002))).created, false, 'join: un email repetido no crea otra fila');
select is((select token_hash from public.waitlist where email = 'ana@ejemplo.test'), pg_temp.h(1), 'join: un email repetido no cambia el link');
select is((public.waitlist_join('ana@ejemplo.test', pg_temp.h(2), pg_temp.h(1002))).position, 1, 'join: la primera persona está en el puesto 1');
select throws_ok($$ select public.waitlist_join('no-es-un-email', pg_temp.h(3), pg_temp.h(1003)) $$, '23514', null, 'join: rechaza un email inválido');

-- Beto y Caro llegan después; Caro con el código de Ana.
select public.waitlist_join('beto@ejemplo.test', pg_temp.h(4), pg_temp.h(1004));
select public.waitlist_join('caro@ejemplo.test', pg_temp.h(5), pg_temp.h(1005),
  (select upper(referral_code) from public.waitlist where email = 'ana@ejemplo.test'), 'en', 'demo', 'x', 'social', 'lanzamiento');
select is((select referred_by from public.waitlist where email = 'caro@ejemplo.test'),
  (select id from public.waitlist where email = 'ana@ejemplo.test'), 'join: guarda quién refirió (el código no distingue mayúsculas)');
select results_eq($$ select locale, source, utm_campaign from public.waitlist where email = 'caro@ejemplo.test' $$,
  $$ values ('en', 'demo', 'lanzamiento') $$, 'join: guarda idioma, origen y UTM');
select is((public.waitlist_join('dani@ejemplo.test', pg_temp.h(6), pg_temp.h(1006), 'zzzzzzz')).created, true, 'join: un código inexistente no frena el alta');
select is((select referred_by from public.waitlist where email = 'dani@ejemplo.test'), null, 'join: con código inexistente queda sin referidor');
select is((public.waitlist_join('eva@ejemplo.test', pg_temp.h(7), pg_temp.h(1007))).total, 5, 'join: devuelve el total de la fila');

-- ---------------------------------------------------------------
-- Confirmación y referidos
-- ---------------------------------------------------------------
select is((public.waitlist_status(pg_temp.h(5))).confirmed, false, 'status: sin confirmar todavía');
select is((select referrals_count from public.waitlist where email = 'ana@ejemplo.test'), 0, 'un referido sin confirmar no suma');
select is((public.waitlist_status(pg_temp.h(5), true)).confirmed, false, 'status con confirm: el token de la página no confirma (hace falta el del email)');
select is((public.waitlist_status(pg_temp.h(1005), true)).confirmed, true, 'status con confirm: el token del email confirma');
select is((select referrals_count from public.waitlist where email = 'ana@ejemplo.test'), 1, 'confirmar suma el referido a quien invitó');
select public.waitlist_status(pg_temp.h(1005), true);
select is((select referrals_count from public.waitlist where email = 'ana@ejemplo.test'), 1, 'confirmar dos veces no suma dos referidos');
select is(public.waitlist_status(pg_temp.h(99)), null, 'status: un token que no existe devuelve null');

-- Eva (llegó quinta) con un referido confirmado sube 10 puestos y queda segunda: Ana también tiene uno y llegó antes.
update public.waitlist set referrals_count = 1 where email = 'eva@ejemplo.test';
select is((public.waitlist_status(pg_temp.h(7))).position, 2, 'posición: cada referido confirmado sube puestos');
select is((public.waitlist_status(pg_temp.h(4))).position, 3, 'posición: los demás bajan en orden');
update public.app_config set value = '0' where key = 'waitlist_referral_boost';
select is((public.waitlist_status(pg_temp.h(7))).position, 5, 'posición: el boost sale de app_config');
update public.app_config set value = '10' where key = 'waitlist_referral_boost';

-- Link nuevo
select ok(public.waitlist_rotate_confirm((select id from public.waitlist where email = 'beto@ejemplo.test'), pg_temp.h(40)), 'rotate: cambia el link del email');
select is(public.waitlist_status(pg_temp.h(1004)), null, 'rotate: el link del email anterior deja de andar');
select is((public.waitlist_status(pg_temp.h(4))).position, 3, 'rotate: la página de la fila sigue andando');

-- ---------------------------------------------------------------
-- Demo de la chispa: una por email y por día, con máximo global
-- ---------------------------------------------------------------
select is(public.demo_spark_claim((select id from public.waitlist where email = 'beto@ejemplo.test')), 'ok', 'demo: la primera chispa del día entra');
select is(public.demo_spark_claim((select id from public.waitlist where email = 'beto@ejemplo.test')), 'used', 'demo: la segunda del mismo día no');
select public.demo_spark_release((select id from public.waitlist where email = 'beto@ejemplo.test'));
select is(public.demo_spark_claim((select id from public.waitlist where email = 'beto@ejemplo.test')), 'ok', 'demo: si falló la IA, se devuelve y puede volver a pedirla');
update public.app_config set value = '1' where key = 'web_demo_daily_max';
select is(public.demo_spark_claim((select id from public.waitlist where email = 'dani@ejemplo.test')), 'full', 'demo: respeta el máximo global del día');

-- ---------------------------------------------------------------
-- Límites por ventana
-- ---------------------------------------------------------------
select is(array[public.web_rate_hit('t', 'ip1', 3600, 2), public.web_rate_hit('t', 'ip1', 3600, 2), public.web_rate_hit('t', 'ip1', 3600, 2)],
  array[true, true, false], 'rate: corta al pasar el máximo de la ventana');

-- ---------------------------------------------------------------
-- Salir y limpieza
-- ---------------------------------------------------------------
select ok(public.waitlist_leave(pg_temp.h(40)), 'leave: borra la fila con su link');
select is((select count(*)::int from public.demo_sparks d where not exists (select 1 from public.waitlist w where w.id = d.waitlist_id)), 0,
  'leave: se lleva sus chispas de la demo');
update public.waitlist set created_at = now() - interval '31 days' where email in ('dani@ejemplo.test', 'caro@ejemplo.test');
select public.cleanup_web();
select results_eq($$ select email from public.waitlist where email in ('dani@ejemplo.test', 'caro@ejemplo.test') $$,
  $$ values ('caro@ejemplo.test') $$, 'cleanup: borra los emails sin confirmar de más de 30 días y deja los confirmados');

-- ---------------------------------------------------------------
-- Acceso: nada de esto se ve ni se llama sin el service role
-- ---------------------------------------------------------------
set local role anon;
select throws_ok($$ select * from public.waitlist $$, '42501', null, 'anon no lee la waitlist');
select throws_ok($$ select public.waitlist_join('x@y.test', repeat('a', 64), repeat('b', 64)) $$, '42501', null, 'anon no se anota directo en la base');
set local role authenticated;
select throws_ok($$ select * from public.demo_sparks $$, '42501', null, 'authenticated no lee las chispas de la demo');
select throws_ok($$ select public.web_rate_hit('t', 's', 60, 1) $$, '42501', null, 'authenticated no toca los límites');
reset role;

select * from finish();
rollback;
