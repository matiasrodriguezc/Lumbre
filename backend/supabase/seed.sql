-- Datos de prueba para desarrollo local. Nunca se cargan en staging ni prod.
-- Son los mismos que MockLumbreAPI en la app de iOS, así las dos cosas muestran lo mismo.
--
-- Usuarios de prueba (contraseña de ambos: lumbre-dev-local):
--   A · ana@lumbre.test   11111111-1111-1111-1111-111111111111  (tiene bóveda y chispas)
--   B · beto@lumbre.test  22222222-2222-2222-2222-222222222222  (un solo concepto, para probar RLS)

-- Los dominios los carga la migración 20260927230000_dominios.sql (la lista cerrada de 25).
--
-- Los conceptos quedan sin embedding: después de `supabase db reset`, una llamada a /process los completa
-- (y también los de los dominios y la biblioteca). El cron 'procesar-pendientes' lo hace solo cada 5 minutos
-- si las Edge Functions están corriendo; para no esperar:
--   curl -X POST http://127.0.0.1:55521/functions/v1/process -H "Authorization: Bearer <SERVICE_ROLE_KEY>"

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token
) values
  ('00000000-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated',
   'ana@lumbre.test', extensions.crypt('lumbre-dev-local', extensions.gen_salt('bf')), now(),
   '{"provider": "email", "providers": ["email"]}', '{}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '22222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated',
   'beto@lumbre.test', extensions.crypt('lumbre-dev-local', extensions.gen_salt('bf')), now(),
   '{"provider": "email", "providers": ["email"]}', '{}', now(), now(), '', '', '', '');

insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at) values
  (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111',
   '{"sub": "11111111-1111-1111-1111-111111111111", "email": "ana@lumbre.test"}', 'email', now(), now(), now()),
  (gen_random_uuid(), '22222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222',
   '{"sub": "22222222-2222-2222-2222-222222222222", "email": "beto@lumbre.test"}', 'email', now(), now(), now());

-- El perfil lo crea el trigger al insertar el usuario; acá se completa.
insert into public.profiles (id, creative_profiles, spark_hour) values
  ('11111111-1111-1111-1111-111111111111', array['software', 'curiosity'], '08:00'),
  ('22222222-2222-2222-2222-222222222222', array['business'], '09:30')
on conflict (id) do update set creative_profiles = excluded.creative_profiles, spark_hour = excluded.spark_hour;

insert into public.concepts (id, user_id, domain, domain_confirmed, title, thesis, source_type, source_title, created_at) values
  ('a0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'marketing', true,
   'Escasez intencional', 'Limitar la oferta sube el valor percibido y la atención.', 'voice', null, now() - interval '2 hours'),
  ('a0000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'arquitectura', true,
   'Onda verde de semáforos', 'Sincronizar semáforos crea un flujo continuo a velocidad constante.', 'text', null, now() - interval '1 day'),
  ('a0000000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'ingenieria', true,
   'Separación ciclónica', 'Un flujo en espiral separa partículas por fuerza centrífuga, sin filtro.', 'link',
   'Cómo funcionan los ciclones industriales', now() - interval '2 days'),
  ('a0000000-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'tecnologia', true,
   'Code review', 'Revisar cambios en pares reduce errores y reparte el conocimiento del código.', 'selection',
   'Engineering practices', now() - interval '3 days'),
  ('a0000000-0000-0000-0000-000000000005', '11111111-1111-1111-1111-111111111111', 'cocina', true,
   'Fermentación lenta', 'El tiempo transforma ingredientes simples en sabores complejos sin agregar nada.', 'screenshot', null, now() - interval '5 days'),
  ('a0000000-0000-0000-0000-000000000006', '11111111-1111-1111-1111-111111111111', 'historia', true,
   'Ruinas como archivo', 'Lo que queda de una ciudad cuenta cómo vivía la gente mejor que sus documentos.', 'link',
   'Pompeya, capa por capa', now() - interval '8 days'),
  ('a0000000-0000-0000-0000-000000000007', '11111111-1111-1111-1111-111111111111', 'economia', true,
   'Interés compuesto', 'Pequeñas ganancias que se reinvierten crecen de forma exponencial con el tiempo.', 'scan', null, now() - interval '12 days'),
  ('a0000000-0000-0000-0000-000000000008', '11111111-1111-1111-1111-111111111111', 'biologia', true,
   'Micorrizas', 'Los hongos conectan las raíces de un bosque y reparten nutrientes entre árboles.', 'audio', null, now() - interval '20 days'),
  ('a0000000-0000-0000-0000-000000000009', '11111111-1111-1111-1111-111111111111', 'marketing', true,
   'Formato podcast', 'Una conversación larga genera confianza que un anuncio no logra.', 'audio', null, now() - interval '9 days'),
  ('b0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'economia', true,
   'Costo hundido', 'Lo ya invertido no debería pesar en la decisión de seguir.', 'text', null, now() - interval '1 day');

insert into public.sparks (user_id, concept_lo, concept_hi, mode, title, body, status, scheduled_for, created_at) values
  ('11111111-1111-1111-1111-111111111111', 'a0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000004',
   'daily', 'Semáforos × code review',
   'Si un PR se aprueba rápido, los siguientes del mismo autor entran en una “onda verde” con revisión prioritaria. Premia los PR chicos sin reglas nuevas.',
   'revealed', (now() at time zone 'America/Argentina/Buenos_Aires')::date, now()),
  ('11111111-1111-1111-1111-111111111111', 'a0000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000009',
   'daily', 'Podcast × ruinas',
   'Un episodio por capa de excavación: cada uno cuenta una época de la misma ciudad con lo que quedó enterrado.',
   'saved', (now() at time zone 'America/Argentina/Buenos_Aires')::date - 1, now() - interval '1 day'),
  ('11111111-1111-1111-1111-111111111111', 'a0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000007',
   'daily', 'Fermentación × interés compuesto',
   'Un newsletter que no se promociona: cada edición recupera y mejora una idea vieja en vez de buscar una nueva.',
   'revealed', (now() at time zone 'America/Argentina/Buenos_Aires')::date - 2, now() - interval '2 days');

-- Categorías de Ana y Beto: nombres cortos, como los escribiría un usuario, cada una con su dominio.
insert into public.categories (user_id, name, domain)
select distinct c.user_id, n.name, c.domain
from public.concepts c
join (values ('marketing', 'Marketing'), ('arquitectura', 'Urbanismo'), ('ingenieria', 'Ingeniería'),
             ('tecnologia', 'Software'), ('cocina', 'Cocina'), ('historia', 'Historia'),
             ('economia', 'Economía'), ('biologia', 'Biología')) as n (domain, name)
  on n.domain = c.domain;

update public.concepts c set category_id = cat.id
  from public.categories cat
 where cat.user_id = c.user_id and cat.domain = c.domain;

-- Las chispas del seed usan sus conceptos: el descanso de 3 días cuenta desde su fecha.
update public.concepts c set last_used_at = s.created_at
  from public.sparks s
 where c.id in (s.concept_lo, s.concept_hi)
   and (c.last_used_at is null or c.last_used_at < s.created_at);

-- Secretos para que pg_cron llame a las Edge Functions locales (ver 20261009170000_jobs.sql).
-- La URL es la de Kong dentro de la red de Docker de Supabase. La clave es la de servicio pública
-- de desarrollo local de la CLI (la misma en todas las máquinas); en remoto se cargan las reales a mano.
select vault.create_secret('http://kong:8000/functions/v1', 'lumbre_functions_url', 'URL de las Edge Functions (local)');
select vault.create_secret(
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU',
  'lumbre_service_key', 'Clave de servicio de desarrollo local');
