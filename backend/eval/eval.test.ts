// El set de evaluación y el harness (paso 29): el set es estable, cruza dominios y el puntaje se calcula bien.
//   deno test -A backend/eval/

import { assert, assertEquals } from "jsr:@std/assert@1";
import { AIGateway } from "../supabase/functions/_shared/ai/gateway.ts";
import { LocalEmbeddings } from "../supabase/functions/_shared/ai/embeddings.ts";
import { LocalProvider } from "../supabase/functions/_shared/ai/providers/local.ts";
import { buildSet, type EvalSet, PAIRS_PER_PROFILE } from "./build-set.ts";
import { parseCsv, toCsv } from "./csv.ts";
import { runSet, SCORE_HEADER } from "./run.ts";
import { readScores, summarize } from "./score.ts";

const dir = new URL(".", import.meta.url);
const concepts = JSON.parse(await Deno.readTextFile(new URL("concepts.v1.json", dir)));
const frozen = JSON.parse(await Deno.readTextFile(new URL("set.v1.json", dir))) as EvalSet;
const PROFILES = ["software", "content", "business", "design", "curiosity"];

Deno.test("set.v1: 100 pares por perfil, de dominios distintos, sin repetir", () => {
  for (const profile of PROFILES) {
    const pairs = frozen.pairs.filter((p) => p.profile === profile);
    assertEquals(pairs.length, PAIRS_PER_PROFILE, profile);
    assert(pairs.every((p) => p.a.domain !== p.b.domain), `${profile}: todos cruzan dominios`);
    const keys = new Set(pairs.map((p) => [p.a.id, p.b.id].sort().join("|")));
    assertEquals(keys.size, PAIRS_PER_PROFILE, `${profile}: sin pares repetidos`);
  }
});

Deno.test("set.v1 está congelado: build-set.ts da exactamente el mismo archivo", () => {
  assertEquals(buildSet(concepts), frozen);
});

Deno.test("concepts.v1: 24 por perfil, textos cortos y slugs de la lista cerrada", async () => {
  const sql = await Deno.readTextFile(new URL("../supabase/migrations/20260927230000_dominios.sql", dir));
  for (const profile of PROFILES) {
    const list = concepts.profiles[profile];
    assertEquals(list.length, 24);
    for (const c of list) {
      assert(sql.includes(`'${c.domain}'`), `${c.id}: dominio ${c.domain}`);
      assert(c.thesis.length <= 200 && c.principle.length <= 160, c.id);
    }
  }
});

Deno.test("run: genera una chispa por par con el proveedor local y la planilla se lee de vuelta", async () => {
  const ai = new AIGateway(new LocalProvider(), new LocalEmbeddings(), { store: { logCall: () => Promise.resolve(), spendToday: () => Promise.resolve(null) } });
  const pairs = frozen.pairs.slice(0, 6);
  const results = await runSet(pairs, ai, 3);
  assertEquals(results.map((r) => r.pair.id), pairs.map((p) => p.id));
  assert(results.every((r) => !r.error && r.body.length > 0 && r.title.includes("×")));
  const csv = toCsv([SCORE_HEADER, ...results.map((r) => [r.pair.id, r.pair.profile, r.pair.a.title, r.pair.a.domain, r.pair.b.title, r.pair.b.domain, r.title, `Línea "con comillas", y coma\nsegunda`, "", "", ""])]);
  const rows = parseCsv(csv);
  assertEquals(rows.length, 7);
  assertEquals(rows[1][7], `Línea "con comillas", y coma\nsegunda`);
});

Deno.test("score: promedios por perfil y total, filas sin puntaje y valores inválidos", () => {
  const csv = [
    "id;perfil;neurona_a;dominio_a;neurona_b;dominio_b;titulo_chispa;chispa;sorprende;sirve;notas",
    "software-001;software;A;x;B;y;T1;C;4;5;",
    "software-002;software;A;x;B;y;T2;C;2;3;floja",
    "design-001;design;A;x;B;y;T3;C;5;4;",
    "design-002;design;A;x;B;y;T4;C;;;",
    "design-003;design;A;x;B;y;T5;C;6;1;",
  ].join("\n");
  const { scores, missing, errors } = readScores(csv);
  assertEquals(missing, ["design-002"]);
  assertEquals(errors.length, 1);
  const summary = summarize(scores);
  assertEquals(summary.map((s) => s.profile), ["design", "software", "TOTAL"]);
  assertEquals(summary[1].average, 3.5);
  assertEquals(summary[2], { profile: "TOTAL", scored: 3, surprise: 11 / 3, useful: 4, average: (4.5 + 2.5 + 4.5) / 3 });
});
