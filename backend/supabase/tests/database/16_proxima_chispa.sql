-- La próxima chispa y el aviso: con la diaria de hoy ya hecha, la próxima es la de mañana; el aviso solo sale
-- si la chispa sigue por encender.
begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

insert into auth.users (id, email, aud, role) values
  ('16000000-0000-4000-8000-000000000001', 'p@proxima.test', 'authenticated', 'authenticated'),
  ('16000000-0000-4000-8000-000000000002', 'r@proxima.test', 'authenticated', 'authenticated');
-- Hora 00:00: el aviso de hoy ya corresponde.
update public.profiles set spark_hour = '00:00', timezone = 'America/Argentina/Buenos_Aires'
where id in ('16000000-0000-4000-8000-000000000001', '16000000-0000-4000-8000-000000000002');

insert into public.concepts (id, user_id, domain, title, thesis, source_type) values
  ('16000000-0000-4000-8000-0000000000a1', '16000000-0000-4000-8000-000000000001', 'cocina', 'A', 'Tesis.', 'text'),
  ('16000000-0000-4000-8000-0000000000a2', '16000000-0000-4000-8000-000000000001', 'fisica', 'B', 'Tesis.', 'text'),
  ('16000000-0000-4000-8000-0000000000b1', '16000000-0000-4000-8000-000000000002', 'cocina', 'C', 'Tesis.', 'text'),
  ('16000000-0000-4000-8000-0000000000b2', '16000000-0000-4000-8000-000000000002', 'fisica', 'D', 'Tesis.', 'text');
insert into public.sparks (id, user_id, concept_lo, concept_hi, title, body, mode, scheduled_for, status) values
  ('16000000-0000-4000-8000-0000000005a1', '16000000-0000-4000-8000-000000000001',
   '16000000-0000-4000-8000-0000000000a1', '16000000-0000-4000-8000-0000000000a2', 'A × B', 'Chispa.', 'daily',
   (now() at time zone 'America/Argentina/Buenos_Aires')::date, 'pending'),
  ('16000000-0000-4000-8000-0000000005b1', '16000000-0000-4000-8000-000000000002',
   '16000000-0000-4000-8000-0000000000b1', '16000000-0000-4000-8000-0000000000b2', 'C × D', 'Chispa.', 'daily',
   (now() at time zone 'America/Argentina/Buenos_Aires')::date, 'revealed');

select is(
  (select following_spark_at from public.user_clock('16000000-0000-4000-8000-000000000001')),
  (((now() at time zone 'America/Argentina/Buenos_Aires')::date + 1) + time '00:00') at time zone 'America/Argentina/Buenos_Aires',
  'following_spark_at es la hora de la chispa de mañana');
select ok(
  (select following_spark_at > now() and following_spark_at >= next_spark_at from public.user_clock('16000000-0000-4000-8000-000000000001')),
  'following_spark_at nunca es antes que next_spark_at');

select ok(
  exists (select 1 from public.due_spark_pushes() where spark_id = '16000000-0000-4000-8000-0000000005a1'),
  'la chispa por encender se avisa');
select ok(
  not exists (select 1 from public.due_spark_pushes() where spark_id = '16000000-0000-4000-8000-0000000005b1'),
  'la chispa que ya abrió no se avisa');

select * from finish();
rollback;
