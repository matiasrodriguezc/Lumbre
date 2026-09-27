-- Índices para las foreign keys que no tenían uno (aviso del advisor de Supabase).
-- Sin ellos, borrar un concepto recorre todas las chispas buscando las que lo usan,
-- y borrar o renombrar un dominio recorre todos los conceptos.
create index concepts_domain_idx on public.concepts (domain);
create index sparks_concept_lo_idx on public.sparks (concept_lo);
create index sparks_concept_hi_idx on public.sparks (concept_hi);
