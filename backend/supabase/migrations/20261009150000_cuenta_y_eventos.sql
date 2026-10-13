-- Cuenta y datos (paso 37): exportar, borrar la cuenta y vencer el texto crudo.
-- Eventos de servidor que nacen en la base (docs/analytics.md, fuente S).

-- ---------------------------------------------------------------
-- Bandeja de eventos de analytics
-- ---------------------------------------------------------------
-- Algunos eventos de servidor pasan por escrituras que la app hace directo con su sesión (guardar una chispa,
-- dar feedback, borrar un concepto). Los triggers los dejan acá y /process los manda a PostHog (o al log).
-- Nunca lleva contenido del usuario: solo slugs, cantidades e ids. Sin foreign key: sobrevive al borrado de la cuenta.
create table public.analytics_outbox (
  id bigint generated always as identity primary key,
  distinct_id uuid not null,
  event text not null,
  properties jsonb not null default '{}',
  created_at timestamptz not null default now()
);

alter table public.analytics_outbox enable row level security;
revoke all on public.analytics_outbox from anon, authenticated;

create or replace function public.track_event(p_user uuid, p_event text, p_properties jsonb default '{}')
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.analytics_outbox (distinct_id, event, properties)
  values (p_user, p_event, coalesce(p_properties, '{}'));
$$;

revoke execute on function public.track_event(uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.track_event(uuid, text, jsonb) to service_role;

-- Rango de días para las propiedades *_age_days_bucket.
create or replace function public.age_days_bucket(p_since timestamptz)
returns text
language sql
stable
set search_path = ''
as $$
  select case
    when p_since > now() - interval '1 day' then '0'
    when p_since > now() - interval '7 days' then '1-6'
    when p_since > now() - interval '30 days' then '7-29'
    when p_since > now() - interval '180 days' then '30-179'
    else '180+'
  end;
$$;

-- spark_saved (evento de la métrica norte) y spark_feedback_given.
create or replace function public.sparks_track_events()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'saved' and old.status is distinct from 'saved' then
    perform public.track_event(new.user_id, 'spark_saved', jsonb_build_object(
      'mode', new.mode,
      'has_project', new.project_id is not null,
      'is_first', not exists (select 1 from public.sparks s
                               where s.user_id = new.user_id and s.status = 'saved' and s.id <> new.id)));
  end if;
  if new.feedback is not null and new.feedback is distinct from old.feedback then
    perform public.track_event(new.user_id, 'spark_feedback_given', jsonb_build_object(
      'mode', new.mode,
      'reason', new.feedback,
      'distance_percentile', new.distance_percentile,
      'uses_library_concept', new.uses_library));
  end if;
  return new;
end;
$$;

revoke execute on function public.sparks_track_events() from public, anon, authenticated;

create trigger sparks_events
  after update of status, feedback on public.sparks
  for each row execute function public.sparks_track_events();

-- concept_deleted, salvo que se esté borrando la cuenta entera (ahí ya va account_deleted).
create or replace function public.concepts_track_delete()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (select 1 from auth.users where id = old.user_id) and not old.from_library then
    perform public.track_event(old.user_id, 'concept_deleted', jsonb_build_object(
      'source_type', old.source_type,
      'age_days_bucket', public.age_days_bucket(old.created_at)));
  end if;
  return old;
end;
$$;

revoke execute on function public.concepts_track_delete() from public, anon, authenticated;

create trigger concepts_deleted_event
  after delete on public.concepts
  for each row execute function public.concepts_track_delete();

-- project_created
create or replace function public.projects_track_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.track_event(new.user_id, 'project_created', jsonb_build_object('from', 'manual'));
  return new;
end;
$$;

revoke execute on function public.projects_track_insert() from public, anon, authenticated;

create trigger projects_created_event
  after insert on public.projects
  for each row execute function public.projects_track_insert();

-- ---------------------------------------------------------------
-- Exportar mis datos
-- ---------------------------------------------------------------
-- Todo lo del usuario de la sesión en un JSON: perfil, categorías, conceptos (sin el embedding),
-- chispas, proyectos, planificador y reportes. Obligatorio en las dos tiendas.
create or replace function public.export_my_data()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_data jsonb;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  select jsonb_build_object(
    'exported_at', now(),
    'user', (select jsonb_build_object('id', u.id, 'email', u.email, 'created_at', u.created_at,
                                       'is_guest', u.is_anonymous)
               from auth.users u where u.id = v_user),
    'profile', (select to_jsonb(p) from public.profiles p where p.id = v_user),
    'categories', coalesce((select jsonb_agg(to_jsonb(c) - 'normalized' order by c.created_at)
                              from public.categories c where c.user_id = v_user), '[]'),
    'concepts', coalesce((select jsonb_agg(to_jsonb(c) - 'embedding' order by c.created_at)
                            from public.concepts c where c.user_id = v_user), '[]'),
    'sparks', coalesce((select jsonb_agg(to_jsonb(s) order by s.created_at)
                          from public.sparks s where s.user_id = v_user), '[]'),
    'projects', coalesce((select jsonb_agg(to_jsonb(p) order by p.created_at)
                            from public.projects p where p.user_id = v_user), '[]'),
    'planner', coalesce((select jsonb_agg(jsonb_build_object(
                           'spark_id', t.spark_id,
                           'summary', t.summary,
                           'messages', coalesce((select jsonb_agg(jsonb_build_object(
                                          'id', m.id, 'role', m.role, 'content', m.content,
                                          'mode', m.mode, 'created_at', m.created_at) order by m.id)
                                        from public.planner_messages m where m.thread_id = t.id), '[]'))
                           order by t.created_at)
                           from public.planner_threads t where t.user_id = v_user), '[]'),
    'content_reports', coalesce((select jsonb_agg(to_jsonb(r) order by r.created_at)
                                   from public.content_reports r where r.user_id = v_user), '[]')
  ) into v_data;

  perform public.track_event(v_user, 'data_exported', '{}');
  return v_data;
end;
$$;

revoke execute on function public.export_my_data() from public, anon;
grant execute on function public.export_my_data() to authenticated;

-- ---------------------------------------------------------------
-- Borrar mi cuenta
-- ---------------------------------------------------------------
-- Borra el usuario de auth del que llama; todo lo suyo se va en cascada (mismo patrón que la limpieza de invitados).
-- Los adjuntos temporales de Storage se borran solos al procesarse. llm_calls queda con user_id null (costos agregados).
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_plan text;
  v_created timestamptz;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  v_plan := public.effective_plan(v_user);
  select created_at into v_created from auth.users where id = v_user;

  delete from auth.users where id = v_user;

  -- Después de borrar: así el evento no se pierde aunque algo del borrado falle y se revierta todo junto.
  perform public.track_event(v_user, 'account_deleted', jsonb_build_object(
    'plan', v_plan, 'age_days_bucket', public.age_days_bucket(v_created)));
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- ---------------------------------------------------------------
-- El texto crudo vence a los 30 días (plan.md §6)
-- ---------------------------------------------------------------
create or replace function public.purge_expired_raw_text()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count int;
begin
  update public.concepts
     set raw_text = null, raw_text_expires_at = null
   where raw_text_expires_at < now();
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke execute on function public.purge_expired_raw_text() from public, anon, authenticated;
grant execute on function public.purge_expired_raw_text() to service_role;

-- Todos los días a las 06:27 UTC (03:27 en Argentina), después de la limpieza de invitados.
select cron.schedule('vencer-texto-crudo', '27 6 * * *', $$ select public.purge_expired_raw_text() $$);
