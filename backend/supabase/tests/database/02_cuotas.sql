-- Cuotas: límites por plan, cupos ganados, invitados, zona horaria, devolución y estado para la app.
-- Los límites que se prueban son los de la migración; si cambian en plan_limits, cambian acá.
begin;
create extension if not exists pgtap with schema extensions;
select plan(26);

-- ---------------------------------------------------------------
-- Datos
--   F  free, Buenos Aires       P  pro, Kiritimati (UTC+14)
--   G  invitado (anónimo)       N  sin perfil
--   L  free, solo conceptos de la biblioteca
-- ---------------------------------------------------------------
insert into auth.users (id, email, aud, role, is_anonymous) values
  ('f0000000-0000-4000-8000-000000000001', 'f@cuotas.test', 'authenticated', 'authenticated', false),
  ('f0000000-0000-4000-8000-000000000002', 'p@cuotas.test', 'authenticated', 'authenticated', false),
  ('f0000000-0000-4000-8000-000000000003', null, 'authenticated', 'authenticated', true),
  ('f0000000-0000-4000-8000-000000000004', 'n@cuotas.test', 'authenticated', 'authenticated', false),
  ('f0000000-0000-4000-8000-000000000005', 'l@cuotas.test', 'authenticated', 'authenticated', false);

-- El trigger ya creó los perfiles; se fijan plan y zona. N queda sin perfil a propósito.
insert into public.profiles (id, plan, timezone) values
  ('f0000000-0000-4000-8000-000000000001', 'free', 'America/Argentina/Buenos_Aires'),
  ('f0000000-0000-4000-8000-000000000002', 'pro', 'Pacific/Kiritimati'),
  ('f0000000-0000-4000-8000-000000000003', 'free', 'America/Argentina/Buenos_Aires'),
  ('f0000000-0000-4000-8000-000000000005', 'free', 'America/Argentina/Buenos_Aires')
on conflict (id) do update set plan = excluded.plan, timezone = excluded.timezone;
delete from public.profiles where id = 'f0000000-0000-4000-8000-000000000004';

insert into public.domains (slug, name_es, name_en, description)
values ('cuotas_test', 'Prueba', 'Test', 'Dominio de los tests de cuotas.');

-- Llama n veces y devuelve cuántas tuvieron cupo.
create function pg_temp.granted(p_user uuid, p_kind text, n int) returns int
language sql volatile as $$
  select count(*) filter (where ok)::int
  from (select public.consume_credit(p_user, p_kind) as ok from generate_series(1, n)) calls;
$$;

-- Guarda n conceptos de hoy para el usuario.
create function pg_temp.save_concepts(p_user uuid, n int, p_from_library boolean default false) returns void
language sql volatile as $$
  insert into public.concepts (user_id, domain, title, thesis, source_type, from_library)
  select p_user, 'cuotas_test', 'Concepto ' || g, 'Tesis ' || g, 'text', p_from_library
  from generate_series(1, n) g;
$$;

-- ---------------------------------------------------------------
-- Free
-- ---------------------------------------------------------------
select is(pg_temp.granted('f0000000-0000-4000-8000-000000000001', 'capture', 31), 30,
  'free: 30 capturas por día, la 31 no');
select is(pg_temp.granted('f0000000-0000-4000-8000-000000000001', 'distill', 6), 5,
  'free: 5 destilaciones por mes, la sexta no');
select is(public.consume_credit('f0000000-0000-4000-8000-000000000001', 'planner'), false,
  'free: sin planificador');
select is(public.consume_credit('f0000000-0000-4000-8000-000000000001', 'spark_extra'), false,
  'free: sin conceptos guardados hoy no hay chispa extra');

select pg_temp.save_concepts('f0000000-0000-4000-8000-000000000001', 3);
select is(pg_temp.granted('f0000000-0000-4000-8000-000000000001', 'spark_extra', 2), 1,
  'free: 3 conceptos guardados dan 1 chispa extra');

select pg_temp.save_concepts('f0000000-0000-4000-8000-000000000001', 6);
select is(pg_temp.granted('f0000000-0000-4000-8000-000000000001', 'spark_extra', 3), 1,
  'free: con 9 conceptos se gana solo 1 más, porque el techo es 2 por día');

select pg_temp.save_concepts('f0000000-0000-4000-8000-000000000005', 6, true);
select is(public.consume_credit('f0000000-0000-4000-8000-000000000005', 'spark_extra'), false,
  'free: los conceptos de la biblioteca no cuentan para ganar chispas');

-- ---------------------------------------------------------------
-- Pro
-- ---------------------------------------------------------------
select is(pg_temp.granted('f0000000-0000-4000-8000-000000000002', 'spark_extra', 11), 10,
  'pro: 10 chispas extra por día sin tener que ganarlas, la 11 no');
select is(pg_temp.granted('f0000000-0000-4000-8000-000000000002', 'planner_deep', 61), 60,
  'pro: 60 planes profundos por mes, el 61 no');
select is(public.consume_credit('f0000000-0000-4000-8000-000000000002', 'planner'), true,
  'pro: tiene planificador');
select is(
  (select period_start from public.usage_ledger
    where user_id = 'f0000000-0000-4000-8000-000000000002' and kind = 'spark_extra'),
  (now() at time zone 'Pacific/Kiritimati')::date,
  'el día se cuenta en la zona horaria del usuario');
select is(
  (select period_start from public.usage_ledger
    where user_id = 'f0000000-0000-4000-8000-000000000002' and kind = 'planner_deep'),
  date_trunc('month', now() at time zone 'Pacific/Kiritimati')::date,
  'el mes arranca el día 1 en la zona horaria del usuario');

-- ---------------------------------------------------------------
-- Invitado y casos borde
-- ---------------------------------------------------------------
select is(public.effective_plan('f0000000-0000-4000-8000-000000000003'), 'guest',
  'un usuario anónimo tiene plan guest aunque su perfil diga free');
select is(pg_temp.granted('f0000000-0000-4000-8000-000000000003', 'capture', 11), 10,
  'invitado: 10 capturas por día, la 11 no');
select is(public.consume_credit('f0000000-0000-4000-8000-000000000003', 'distill'), false,
  'invitado: sin destilación');
select pg_temp.save_concepts('f0000000-0000-4000-8000-000000000003', 3);
select is(public.consume_credit('f0000000-0000-4000-8000-000000000003', 'spark_extra'), false,
  'invitado: no gana chispas extra');
select is(public.consume_credit('f0000000-0000-4000-8000-000000000004', 'capture'), false,
  'sin perfil: no hay cupo (y no da error)');
select is(public.consume_credit('00000000-0000-4000-8000-00000000dead', 'capture'), false,
  'usuario inexistente: no hay cupo');
select is(public.consume_credit('f0000000-0000-4000-8000-000000000001', 'tipo_inventado'), false,
  'un tipo sin fila en plan_limits no tiene cupo');

insert into public.usage_ledger (user_id, kind, period, period_start, used)
values ('f0000000-0000-4000-8000-000000000005', 'capture', 'day', current_date - 1, 30);
select is(public.consume_credit('f0000000-0000-4000-8000-000000000005', 'capture'), true,
  'el uso de ayer no cuenta para hoy');

-- ---------------------------------------------------------------
-- Devolución
-- ---------------------------------------------------------------
select is(public.refund_credit('f0000000-0000-4000-8000-000000000001', 'capture'), true,
  'refund: devuelve una captura');
select is(pg_temp.granted('f0000000-0000-4000-8000-000000000001', 'capture', 2), 1,
  'refund: el crédito devuelto se puede usar una vez');
select is(public.refund_credit('f0000000-0000-4000-8000-000000000002', 'distill'), false,
  'refund: sin uso no hay nada que devolver (nunca queda negativo)');

-- ---------------------------------------------------------------
-- Lo que ve la app
-- ---------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', '{"sub": "f0000000-0000-4000-8000-000000000001", "role": "authenticated"}', true);

select results_eq(
  $$ select kind, available, used, remaining from public.credit_status() order by kind $$,
  $$ values ('capture', 30, 30, 0), ('distill', 5, 5, 0), ('spark_extra', 2, 2, 0) $$,
  'credit_status: free ve sus tres cupos con lo ganado y lo usado'
);
select throws_ok($$ select public.refund_credit(auth.uid(), 'capture') $$, '42501', null,
  'refund_credit: la app no puede llamarla');
select throws_ok($$ select public.effective_plan(auth.uid()) $$, '42501', null,
  'effective_plan: la app no puede llamarla');

reset role;
select * from finish();
rollback;
