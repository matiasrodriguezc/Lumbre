-- Planificador (paso 35) y reporte de contenido generado por IA (paso 33, requisito de Google Play).

-- ---------------------------------------------------------------
-- Planificador: un hilo por chispa
-- ---------------------------------------------------------------
-- El hilo guarda un resumen incremental (summary hasta el mensaje summary_upto) para no mandarle
-- al modelo toda la conversación en cada mensaje. Lo escribe solo la Edge Function del planificador.
create table public.planner_threads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  spark_id uuid not null unique references public.sparks (id) on delete cascade,
  summary text,
  -- Último planner_messages.id incluido en el resumen.
  summary_upto bigint,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index planner_threads_user_idx on public.planner_threads (user_id);

create table public.planner_messages (
  id bigint generated always as identity primary key,
  thread_id uuid not null references public.planner_threads (id) on delete cascade,
  user_id uuid not null references auth.users on delete cascade,
  role text not null check (role in ('user', 'assistant')),
  content text not null check (char_length(content) between 1 and 20000),
  mode text not null default 'quick' check (mode in ('quick', 'deep')),
  created_at timestamptz not null default now()
);

create index planner_messages_thread_idx on public.planner_messages (thread_id, id);
create index planner_messages_user_idx on public.planner_messages (user_id);

alter table public.planner_threads enable row level security;
alter table public.planner_messages enable row level security;

create policy "planner_threads: leer los propios" on public.planner_threads
  for select to authenticated using (user_id = (select auth.uid()));
create policy "planner_messages: leer los propios" on public.planner_messages
  for select to authenticated using (user_id = (select auth.uid()));
revoke all on public.planner_threads, public.planner_messages from anon;
revoke insert, update, delete on public.planner_threads, public.planner_messages from authenticated;

-- ---------------------------------------------------------------
-- Reportes de contenido generado por IA
-- ---------------------------------------------------------------
-- El usuario reporta una chispa o un mensaje del planificador, siempre suyos.
create table public.content_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  spark_id uuid references public.sparks (id) on delete cascade,
  planner_message_id bigint references public.planner_messages (id) on delete cascade,
  reason text not null check (reason in ('offensive', 'dangerous', 'wrong', 'other')),
  note text check (char_length(note) <= 500),
  created_at timestamptz not null default now(),
  check (spark_id is not null or planner_message_id is not null)
);

create index content_reports_user_idx on public.content_reports (user_id);
create index content_reports_spark_idx on public.content_reports (spark_id);
create index content_reports_message_idx on public.content_reports (planner_message_id);

alter table public.content_reports enable row level security;

create policy "content_reports: leer los propios" on public.content_reports
  for select to authenticated using (user_id = (select auth.uid()));
create policy "content_reports: reportar lo propio" on public.content_reports
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and (spark_id is null
         or exists (select 1 from public.sparks s where s.id = spark_id and s.user_id = (select auth.uid())))
    and (planner_message_id is null
         or exists (select 1 from public.planner_messages m
                     where m.id = planner_message_id and m.user_id = (select auth.uid())))
  );
revoke all on public.content_reports from anon;
revoke insert, update, delete on public.content_reports from authenticated;
-- user_id no se manda: lo pone el default con la sesión.
grant insert (spark_id, planner_message_id, reason, note) on public.content_reports to authenticated;
