// Genera las chispas del set de evaluación con el gateway de IA (paso 29) y deja una planilla para puntuar.
//
//   deno run -A backend/eval/run.ts                          # proveedor según el entorno (local sin ANTHROPIC_API_KEY)
//   ANTHROPIC_API_KEY=… deno run -A backend/eval/run.ts      # con el modelo real (cuesta: ~500 llamadas)
//   deno run -A backend/eval/run.ts --profile software --limit 20 --concurrency 4 --set set.v1.json
//
// Usa el mismo pedido que producción (sparkRequest: prompt spark.vN, schema JSON, perfil) y la misma validación
// y moderación (checkSparkJson), así lo que se puntúa es lo que verían las personas. No toca la base: el registro
// de llamadas queda en memoria y su resumen (tokens y costo) va al .meta.json de la corrida.
//
// Salida en backend/eval/runs/<fecha>_<prompt>_<modelo>.csv con las columnas sorprende y sirve vacías (1 a 5)
// y notas. Después: backend/eval/score.ts <planilla puntuada>.

import { AIGateway, type GatewayStore, type LlmCallRow } from "../supabase/functions/_shared/ai/gateway.ts";
import { LocalEmbeddings } from "../supabase/functions/_shared/ai/embeddings.ts";
import { SPARK_VERSION } from "../supabase/functions/_shared/ai/prompts/spark.v1.ts";
import { checkSparkJson, sparkRequest } from "../supabase/functions/_shared/ai/tasks.ts";
import type { EvalPair, EvalSet } from "./build-set.ts";
import { toCsv } from "./csv.ts";

export const SCORE_HEADER = ["id", "perfil", "neurona_a", "dominio_a", "neurona_b", "dominio_b", "titulo_chispa", "chispa", "sorprende", "sirve", "notas"];

function arg(name: string, fallback?: string): string | undefined {
  const i = Deno.args.indexOf(`--${name}`);
  return i >= 0 ? Deno.args[i + 1] : fallback;
}

export interface RunResult {
  pair: EvalPair;
  title: string;
  body: string;
  model: string;
  error: string | null;
}

export async function runSet(pairs: EvalPair[], ai: AIGateway, concurrency = 4): Promise<RunResult[]> {
  const results: RunResult[] = new Array(pairs.length);
  let next = 0;
  async function worker() {
    while (next < pairs.length) {
      const index = next++;
      const pair = pairs[index];
      const a = { id: pair.a.id, title: pair.a.title, thesis: pair.a.thesis, principle: pair.a.principle };
      const b = { id: pair.b.id, title: pair.b.title, thesis: pair.b.thesis, principle: pair.b.principle };
      try {
        const result = await ai.complete(sparkRequest(a, b, [pair.profile], null));
        const text = await checkSparkJson(result.json, a, b);
        results[index] = { pair, ...text, model: result.model, error: null };
      } catch (error) {
        results[index] = { pair, title: "", body: "", model: "", error: String(error).slice(0, 200) };
      }
    }
  }
  await Promise.all(Array.from({ length: Math.max(1, concurrency) }, worker));
  return results;
}

if (import.meta.main) {
  const dir = new URL(".", import.meta.url);
  const setFile = arg("set", "set.v1.json")!;
  const set = JSON.parse(await Deno.readTextFile(new URL(setFile, dir))) as EvalSet;
  const profile = arg("profile");
  const limit = Number(arg("limit", "0"));
  let pairs = set.pairs.filter((p) => !profile || p.profile === profile);
  if (limit > 0) {
    // Los primeros N de cada perfil, para una pasada rápida.
    const seen = new Map<string, number>();
    pairs = pairs.filter((p) => (seen.set(p.profile, (seen.get(p.profile) ?? 0) + 1).get(p.profile)! <= limit));
  }

  const calls: LlmCallRow[] = [];
  const store: GatewayStore = {
    logCall: (row) => (calls.push(row), Promise.resolve()),
    // Sin topes: la corrida es de una persona del equipo, no de un usuario.
    spendToday: () => Promise.resolve(null),
  };
  const ai = new AIGateway(undefined, new LocalEmbeddings(), { store });
  const started = performance.now();
  const results = await runSet(pairs, ai, Number(arg("concurrency", "4")));

  const model = ai.modelFor("fast");
  const stamp = new Date().toISOString().slice(0, 16).replace(/[:T]/g, "-");
  const name = `${stamp}_${SPARK_VERSION}_${model}${profile ? `_${profile}` : ""}`;
  await Deno.mkdir(new URL("runs/", dir), { recursive: true });
  await Deno.writeTextFile(new URL(`runs/${name}.csv`, dir), toCsv([
    SCORE_HEADER,
    ...results.map((r) => [r.pair.id, r.pair.profile, r.pair.a.title, r.pair.a.domain, r.pair.b.title, r.pair.b.domain, r.title, r.error ? `ERROR: ${r.error}` : r.body, "", "", ""]),
  ]));
  const ok = calls.filter((c) => !c.feature.endsWith(":error"));
  const meta = {
    set: set.version,
    prompt_version: SPARK_VERSION,
    provider: ai.provider.name,
    model,
    pairs: results.length,
    failed: results.filter((r) => r.error).length,
    fallback_model_used: results.filter((r) => r.model && r.model !== model).length,
    calls: calls.length,
    input_tokens: ok.reduce((n, c) => n + c.input_tokens, 0),
    cached_tokens: ok.reduce((n, c) => n + c.cached_tokens, 0),
    output_tokens: ok.reduce((n, c) => n + c.output_tokens, 0),
    cost_usd: Number(calls.reduce((n, c) => n + c.cost_usd, 0).toFixed(6)),
    usd_per_spark: Number((calls.reduce((n, c) => n + c.cost_usd, 0) / Math.max(1, ok.length)).toFixed(6)),
    seconds: Math.round((performance.now() - started) / 100) / 10,
    created_at: new Date().toISOString(),
  };
  await Deno.writeTextFile(new URL(`runs/${name}.meta.json`, dir), JSON.stringify(meta, null, 2) + "\n");
  console.log(`runs/${name}.csv: ${meta.pairs} chispas (${meta.failed} con error) con ${meta.provider}/${model}, US$ ${meta.cost_usd} (US$ ${meta.usd_per_spark} por chispa), ${meta.seconds} s`);
}
