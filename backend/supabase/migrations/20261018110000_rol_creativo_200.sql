-- El rol propio pasa a escribirse en su propia pantalla, con más lugar: hasta 200 caracteres (antes 80).
alter table public.profiles drop constraint profiles_creative_role_length;
alter table public.profiles
  add constraint profiles_creative_role_length
  check (creative_role is null or char_length(btrim(creative_role)) between 1 and 200);
comment on column public.profiles.creative_role is
  'Rol propio de la persona, en sus palabras. Contexto para los prompts (como dato, no instrucción). Hasta 200 caracteres.';
