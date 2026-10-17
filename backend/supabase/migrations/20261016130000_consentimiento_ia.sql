-- Consentimiento para mandar contenido a una IA de terceros (plan.md §10, App Store 5.1.2, GDPR art. 7.1).
-- Hasta ahora la respuesta vivía solo en el teléfono: el servidor destilaba, generaba chispas y respondía en el
-- planificador aunque la persona hubiera dicho "No acepto". Ahora vive en el perfil y las Edge Functions la respetan.

-- ---------------------------------------------------------------
-- Columna
-- ---------------------------------------------------------------
-- Fecha del "Acepto"; null = no respondió, no aceptó o lo revocó. La edita la app (RLS de columna).
alter table public.profiles add column ai_consent_at timestamptz;

comment on column public.profiles.ai_consent_at is
  'Cuándo aceptó que su contenido pase por una IA de terceros (null: no aceptó o lo revocó). La fecha la pone el servidor. '
  'Sin ella, /capture no destila, /spark y /planner responden 403 ai_consent_required, /today no genera la diaria y el '
  'batch nocturno la saltea.';

-- Respuestas que la app guardó en los metadatos de Auth mientras la columna no existía (SupabaseLumbreAPI.setAIConsent).
update public.profiles p
set ai_consent_at = case
    when u.raw_user_meta_data->>'ai_consent_at' ~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}'
      then least((u.raw_user_meta_data->>'ai_consent_at')::timestamptz, now())
    else now()
  end
from auth.users u
where u.id = p.id
  and u.raw_user_meta_data->>'ai_consent' = 'true';

grant update (ai_consent_at) on public.profiles to authenticated;

-- ---------------------------------------------------------------
-- La fecha la pone el servidor
-- ---------------------------------------------------------------
-- La app manda su hora al aceptar; se guarda la del servidor (el reloj del teléfono no prueba nada). Volver a aceptar
-- sin haber revocado conserva la primera fecha; revocar (null) la borra y aceptar de nuevo pone una nueva.
create or replace function public.stamp_ai_consent()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.ai_consent_at is distinct from old.ai_consent_at and new.ai_consent_at is not null then
    new.ai_consent_at := coalesce(old.ai_consent_at, now());
  end if;
  return new;
end;
$$;

revoke execute on function public.stamp_ai_consent() from public, anon, authenticated;

create trigger profiles_stamp_ai_consent
  before update of ai_consent_at on public.profiles
  for each row execute function public.stamp_ai_consent();

-- ---------------------------------------------------------------
-- Batch nocturno: sin consentimiento no hay chispa diaria
-- ---------------------------------------------------------------
create or replace function public.users_needing_daily_spark(p_limit int default 200)
returns table (user_id uuid, local_date date)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, d.local_date
  from public.profiles p
  cross join lateral (select (now() at time zone p.timezone)::date as local_date) d
  where p.ai_consent_at is not null
    and not exists (select 1 from public.sparks s
                     where s.user_id = p.id and s.mode = 'daily' and s.scheduled_for = d.local_date)
    and not exists (select 1 from public.spark_jobs j
                     where j.user_id = p.id and j.scheduled_for = d.local_date and j.status in ('pending', 'submitted'))
    and exists (select 1 from public.concepts c
                 where c.user_id = p.id and c.status = 'ready' and c.embedding is not null)
  order by p.id
  limit p_limit;
$$;

revoke execute on function public.users_needing_daily_spark(int) from public, anon, authenticated;
grant execute on function public.users_needing_daily_spark(int) to service_role;
