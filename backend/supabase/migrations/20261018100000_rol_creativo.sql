-- Rol propio en el perfil creativo (decidido el 2026-10-18): además de elegir hasta dos perfiles, la persona puede
-- escribir su rol con sus palabras ("diseñadora de producto en una fintech"). Solo se usa como contexto en los
-- prompts de la chispa y del planificador, delimitado como dato. Hasta 80 caracteres; null si no lo puso.

alter table public.profiles
  add column creative_role text
  constraint profiles_creative_role_length check (creative_role is null or char_length(btrim(creative_role)) between 1 and 80);

comment on column public.profiles.creative_role is
  'Rol propio de la persona, en sus palabras. Contexto para los prompts (como dato, no instrucción). Hasta 80 caracteres.';

-- Cada uno edita el suyo (RLS de la tabla: solo su fila).
grant update (creative_role) on public.profiles to authenticated;
