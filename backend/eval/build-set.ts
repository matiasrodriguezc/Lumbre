// Arma el set de evaluación de la chispa (paso 29, plan.md §5 "Calidad"): 100 pares por perfil creativo,
// cruzando conceptos del mismo perfil y de dominios distintos (como el emparejamiento real).
//
//   deno run --allow-read --allow-write backend/eval/build-set.ts            → backend/eval/set.v1.json
//
// Determinístico: con el mismo concepts.v1.json da siempre el mismo set. El set queda congelado en el repo (cada
// par lleva el texto completo de sus dos conceptos): si se cambia un concepto, se hace concepts.v2 y set.v2, así los
// puntajes viejos siguen siendo comparables.

import { fnv1a } from "../supabase/functions/_shared/text.ts";

export const PAIRS_PER_PROFILE = 100;
// Que ningún concepto domine el set: con 24 por perfil, 100 pares son 200 apariciones (unas 8,3 por concepto).
const MAX_USES = 10;

export interface EvalConcept {
  id: string;
  domain: string;
  source_type: string;
  title: string;
  thesis: string;
  principle: string;
}

export interface EvalPair {
  id: string;
  profile: string;
  a: EvalConcept;
  b: EvalConcept;
}

export interface EvalSet {
  version: string;
  concepts_version: string;
  description: string;
  pairs: EvalPair[];
}

export function buildSet(source: { version: string; profiles: Record<string, EvalConcept[]> }, version = "set.v1"): EvalSet {
  const pairs: EvalPair[] = [];
  for (const [profile, concepts] of Object.entries(source.profiles)) {
    const candidates: Array<[EvalConcept, EvalConcept, number]> = [];
    for (let i = 0; i < concepts.length; i++) {
      for (let j = i + 1; j < concepts.length; j++) {
        if (concepts[i].domain === concepts[j].domain) continue;
        candidates.push([concepts[i], concepts[j], fnv1a(`${version}:${concepts[i].id}:${concepts[j].id}`)]);
      }
    }
    candidates.sort((x, y) => x[2] - y[2]);
    const uses = new Map<string, number>();
    const chosen: EvalPair[] = [];
    for (const [x, y, hash] of candidates) {
      if (chosen.length === PAIRS_PER_PROFILE) break;
      if ((uses.get(x.id) ?? 0) >= MAX_USES || (uses.get(y.id) ?? 0) >= MAX_USES) continue;
      uses.set(x.id, (uses.get(x.id) ?? 0) + 1);
      uses.set(y.id, (uses.get(y.id) ?? 0) + 1);
      // El orden A/B también sale del hash (el prompt no debería depender de cuál va primero).
      const [a, b] = hash & 1 ? [y, x] : [x, y];
      chosen.push({ id: `${profile}-${String(chosen.length + 1).padStart(3, "0")}`, profile, a, b });
    }
    if (chosen.length < PAIRS_PER_PROFILE) throw new Error(`${profile}: solo ${chosen.length} pares posibles`);
    pairs.push(...chosen);
  }
  return {
    version,
    concepts_version: source.version,
    description: "Pares para evaluar el prompt de la chispa: se generan las chispas con run.ts y se puntúan a mano (sorprende y sirve, 1 a 5).",
    pairs,
  };
}

if (import.meta.main) {
  const dir = new URL(".", import.meta.url);
  const source = JSON.parse(await Deno.readTextFile(new URL("concepts.v1.json", dir)));
  const set = buildSet(source);
  await Deno.writeTextFile(new URL("set.v1.json", dir), JSON.stringify(set, null, 2) + "\n");
  const byProfile = Object.groupBy(set.pairs, (p) => p.profile);
  console.log(`set.v1.json: ${set.pairs.length} pares (${Object.entries(byProfile).map(([p, l]) => `${p} ${l!.length}`).join(", ")})`);
}
