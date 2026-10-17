// Gateway de IA (paso 23): reintentos con backoff, modelo de respaldo, topes diarios en dólares y registro de cada llamada.
// Corre sin red ni base: proveedor falso y un store en memoria.
//   deno test --allow-env --allow-read --allow-net supabase/functions/_tests/

import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import { AIGateway, backoffMs, type GatewayStore, type LlmCallRow } from "../_shared/ai/gateway.ts";
import { costUsd } from "../_shared/ai/pricing.ts";
import { LocalEmbeddings } from "../_shared/ai/embeddings.ts";
import {
  AIError,
  type ChatProvider,
  type CompletionRequest,
  type StreamChunk,
  type Usage,
} from "../_shared/ai/types.ts";

const USAGE: Usage = { inputTokens: 1000, outputTokens: 200, cachedTokens: 0, cacheWriteTokens: 0 };

function memoryStore(spend = { user_usd: 0, global_usd: 0, user_cap: 0.05 as number | null, global_cap: 20 as number | null }) {
  const calls: LlmCallRow[] = [];
  const store: GatewayStore = {
    logCall: (row) => {
      calls.push(row);
      return Promise.resolve();
    },
    spendToday: () => Promise.resolve(spend),
  };
  return { calls, store, spend };
}

/** Proveedor que responde según un guion: un error o un texto por intento. */
class ScriptedProvider implements ChatProvider {
  readonly name = "anthropic" as const;
  readonly seen: string[] = [];
  constructor(private script: Array<AIError | string>) {}
  complete(_req: CompletionRequest, model: string) {
    this.seen.push(model);
    const next = this.script.shift() ?? new AIError("fatal", "sin guion");
    if (next instanceof AIError) return Promise.reject(next);
    return Promise.resolve({ text: next, usage: USAGE });
  }
  async *stream(_req: CompletionRequest, model: string): AsyncIterable<StreamChunk> {
    this.seen.push(model);
    const next = this.script.shift() ?? new AIError("fatal", "sin guion");
    if (next instanceof AIError) throw next;
    for (const word of next.split(" ")) yield { delta: `${word} ` };
    yield { done: true, usage: USAGE };
  }
}

function request(overrides: Partial<CompletionRequest> = {}): CompletionRequest {
  return {
    feature: "spark",
    userId: "11111111-1111-1111-1111-111111111111",
    tier: "fast",
    promptVersion: "spark.v1",
    system: [{ text: "sistema", cache: true }],
    messages: [{ role: "user", content: "hola" }],
    maxTokens: 100,
    jsonSchema: { type: "object" },
    local: { kind: "summary", previous: null, messages: [] },
    ...overrides,
  };
}

const models = { fast: "claude-haiku-4-5", deep: "claude-sonnet-5", fallback: "claude-haiku-5-5" };
const noSleep = () => Promise.resolve();

Deno.test("reintenta los errores reintentables y registra cada intento", async () => {
  const { calls, store } = memoryStore();
  const provider = new ScriptedProvider([new AIError("retryable", "anthropic 529"), new AIError("retryable", "anthropic 500"), '{"title":"a","body":"b"}']);
  const ai = new AIGateway(provider, new LocalEmbeddings(), { store, sleep: noSleep, models });
  const result = await ai.complete(request());
  assertEquals(result.json, { title: "a", body: "b" });
  assertEquals(result.model, "claude-haiku-4-5");
  assertEquals(provider.seen, ["claude-haiku-4-5", "claude-haiku-4-5", "claude-haiku-4-5"]);
  assertEquals(calls.map((c) => c.feature), ["spark:error", "spark:error", "spark"]);
  assertEquals(calls[2].cost_usd, costUsd("claude-haiku-4-5", USAGE));
  assertEquals(calls[2].prompt_version, "spark.v1");
});

Deno.test("pasa al modelo de respaldo cuando el principal se agota", async () => {
  const { calls, store } = memoryStore();
  const provider = new ScriptedProvider([
    new AIError("retryable", "1"), new AIError("retryable", "2"), new AIError("retryable", "3"),
    '{"ok":true}',
  ]);
  const ai = new AIGateway(provider, new LocalEmbeddings(), { store, sleep: noSleep, models });
  const result = await ai.complete(request());
  assertEquals(result.model, "claude-haiku-5-5");
  assertEquals(provider.seen.at(-1), "claude-haiku-5-5");
  assertEquals(calls.length, 4);
});

Deno.test("un error no reintentable (o una negativa) va directo al respaldo", async () => {
  const { store } = memoryStore();
  const provider = new ScriptedProvider([new AIError("refusal", "refusal"), '{"ok":true}']);
  const ai = new AIGateway(provider, new LocalEmbeddings(), { store, sleep: noSleep, models });
  const result = await ai.complete(request());
  assertEquals(provider.seen, ["claude-haiku-4-5", "claude-haiku-5-5"]);
  assertEquals(result.model, "claude-haiku-5-5");
});

Deno.test("si fallan principal y respaldo, sube el último error", async () => {
  const { calls, store } = memoryStore();
  const provider = new ScriptedProvider(Array.from({ length: 5 }, () => new AIError("retryable", "caído")));
  const ai = new AIGateway(provider, new LocalEmbeddings(), { store, sleep: noSleep, models });
  await assertRejects(() => ai.complete(request()), AIError, "caído");
  assertEquals(provider.seen.length, 5); // 3 del principal + 2 del respaldo
  assert(calls.every((c) => c.feature === "spark:error"));
});

Deno.test("JSON inválido cuenta como reintentable", async () => {
  const { store } = memoryStore();
  const provider = new ScriptedProvider(["no es json", '{"ok":true}']);
  const ai = new AIGateway(provider, new LocalEmbeddings(), { store, sleep: noSleep, models });
  const result = await ai.complete(request());
  assertEquals(result.json, { ok: true });
});

Deno.test("tope diario por usuario: corta antes de llamar al modelo", async () => {
  const { calls, store } = memoryStore({ user_usd: 0.06, global_usd: 1, user_cap: 0.05, global_cap: 20 });
  const provider = new ScriptedProvider(['{"ok":true}']);
  const ai = new AIGateway(provider, new LocalEmbeddings(), { store, sleep: noSleep, models });
  const error = await assertRejects(() => ai.complete(request()), AIError);
  assertEquals(error.kind, "user_cap");
  assertEquals(provider.seen.length, 0);
  assertEquals(calls.length, 0);
});

Deno.test("tope global: corta para todos, también sin usuario (batch)", async () => {
  const { store } = memoryStore({ user_usd: 0, global_usd: 25, user_cap: 0.05, global_cap: 20 });
  const ai = new AIGateway(new ScriptedProvider(['{"ok":true}']), new LocalEmbeddings(), { store, sleep: noSleep, models });
  const error = await assertRejects(() => ai.complete(request({ userId: null })), AIError);
  assertEquals(error.kind, "global_cap");
});

Deno.test("stream: reintenta antes del primer pedazo y registra al cerrar", async () => {
  const { calls, store } = memoryStore();
  const provider = new ScriptedProvider([new AIError("retryable", "529"), "uno dos tres"]);
  const ai = new AIGateway(provider, new LocalEmbeddings(), { store, sleep: noSleep, models });
  let text = "";
  for await (const delta of ai.stream(request({ feature: "planner", jsonSchema: undefined }))) text += delta;
  assertEquals(text.trim(), "uno dos tres");
  assertEquals(calls.map((c) => c.feature), ["planner:error", "planner"]);
});

Deno.test("plan profundo usa el modelo deep", async () => {
  const { store } = memoryStore();
  const provider = new ScriptedProvider(["respuesta"]);
  const ai = new AIGateway(provider, new LocalEmbeddings(), { store, sleep: noSleep, models });
  await ai.complete(request({ tier: "deep", jsonSchema: undefined }));
  assertEquals(provider.seen, ["claude-sonnet-5"]);
});

Deno.test("embeddings: registra modelo y tokens, sin contenido", async () => {
  const { calls, store } = memoryStore();
  const ai = new AIGateway(new ScriptedProvider([]), new LocalEmbeddings(), { store, sleep: noSleep, models });
  const [vector] = await ai.embed(["Un texto secreto de la persona"], { feature: "embed", userId: null });
  assertEquals(vector.length, 1024);
  assertEquals(calls[0].model, "lumbre-local-hash-v1");
  assert(!JSON.stringify(calls).includes("secreto"));
});

Deno.test("backoff exponencial con jitter, acotado", () => {
  for (let attempt = 0; attempt < 4; attempt++) {
    for (let i = 0; i < 50; i++) {
      const ms = backoffMs(attempt, 400);
      assert(ms >= 0 && ms <= 400 * 2 ** attempt);
    }
  }
});

Deno.test("precios: caché al 10%, escritura al 125%, batch al 50%, modelo local gratis", () => {
  const usage = { inputTokens: 1_000_000, outputTokens: 1_000_000, cachedTokens: 1_000_000, cacheWriteTokens: 1_000_000 };
  // Haiku 4.5: 1 + 0,1 + 1,25 + 5
  assertEquals(costUsd("claude-haiku-4-5", usage), 7.35);
  assertEquals(costUsd("claude-haiku-4-5", usage, true), 3.675);
  assertEquals(costUsd("local", usage), 0);
});
