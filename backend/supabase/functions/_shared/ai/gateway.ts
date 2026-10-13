// Gateway de IA (paso 23, plan.md §5). Toda llamada a un modelo pasa por acá:
//
// - complete(), stream(), batch y embed() con la misma interfaz para cualquier proveedor.
// - Reintentos con backoff exponencial y jitter ante errores reintentables (429, 5xx, red).
// - Modelo de respaldo si el principal sigue fallando (o se niega a responder).
// - Tope diario en dólares por usuario y global (app_config), contra lo gastado hoy en llm_calls.
// - Registro de CADA llamada en llm_calls: función, modelo, versión de prompt, tokens, costo, latencia y batch.
//   Nunca se registra el contenido.
//
// Proveedor: Anthropic si hay ANTHROPIC_API_KEY (o LUMBRE_AI_PROVIDER=anthropic); si no, el local simulado.

import { admin } from "../supabase.ts";
import { costUsd } from "./pricing.ts";
import { AnthropicProvider } from "./providers/anthropic.ts";
import { LOCAL_MODEL, LocalProvider } from "./providers/local.ts";
import { embeddingProvider, type EmbeddingProvider, type InputType } from "./embeddings.ts";
import {
  AIError,
  type BatchItem,
  type BatchResult,
  type ChatProvider,
  type CompletionRequest,
  type CompletionResult,
  type Feature,
  type Tier,
  type Usage,
} from "./types.ts";

const MAX_ATTEMPTS = 3;
const FALLBACK_ATTEMPTS = 2;
const BASE_DELAY_MS = 400;

export interface Models {
  fast: string;
  deep: string;
  fallback: string;
}

export function configuredModels(): Models {
  return {
    fast: Deno.env.get("LUMBRE_MODEL_FAST") ?? "claude-haiku-4-5",
    deep: Deno.env.get("LUMBRE_MODEL_DEEP") ?? "claude-sonnet-5",
    fallback: Deno.env.get("LUMBRE_MODEL_FALLBACK") ?? "claude-haiku-5-5",
  };
}

function chooseProvider(): ChatProvider {
  const key = Deno.env.get("ANTHROPIC_API_KEY");
  const choice = Deno.env.get("LUMBRE_AI_PROVIDER");
  if (choice === "local" || !key) return new LocalProvider();
  return new AnthropicProvider(key);
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** Backoff exponencial con jitter completo: entre 0 y base·2^intento. */
export function backoffMs(attempt: number, base = BASE_DELAY_MS): number {
  return Math.round(Math.random() * base * 2 ** attempt);
}

interface CallLog {
  feature: Feature;
  userId: string | null;
  model: string;
  promptVersion: string | null;
  usage: Usage;
  latencyMs: number;
  batch: boolean;
  ok: boolean;
}

export class AIGateway {
  readonly provider: ChatProvider;
  readonly models: Models;
  private embeddings: EmbeddingProvider;

  constructor(provider?: ChatProvider, embeddings?: EmbeddingProvider) {
    this.provider = provider ?? chooseProvider();
    this.embeddings = embeddings ?? embeddingProvider();
    this.models = configuredModels();
  }

  get isLocal(): boolean {
    return this.provider.name === "local";
  }

  get embeddingModel(): string {
    return this.embeddings.model;
  }

  modelFor(tier: Tier): string {
    return this.isLocal ? LOCAL_MODEL : this.models[tier];
  }

  // ---------------------------------------------------------------
  // Topes diarios
  // ---------------------------------------------------------------
  async checkCaps(userId: string | null): Promise<void> {
    if (this.isLocal) return; // el proveedor local cuesta 0
    const { data, error } = await admin().rpc("llm_spend_today", { p_user: userId });
    if (error) throw new AIError("retryable", `caps: ${error.message}`);
    const row = (data as Array<{ user_usd: number; global_usd: number; user_cap: number | null; global_cap: number | null }>)[0];
    if (!row) return;
    if (row.global_cap !== null && Number(row.global_usd) >= Number(row.global_cap)) throw new AIError("global_cap", "global_cap");
    if (userId && row.user_cap !== null && Number(row.user_usd) >= Number(row.user_cap)) throw new AIError("user_cap", "user_cap");
  }

  // ---------------------------------------------------------------
  // Registro
  // ---------------------------------------------------------------
  private async log(entry: CallLog): Promise<void> {
    const { error } = await admin().from("llm_calls").insert({
      user_id: entry.userId,
      feature: entry.ok ? entry.feature : `${entry.feature}:error`,
      model: entry.model,
      prompt_version: entry.promptVersion,
      input_tokens: entry.usage.inputTokens + entry.usage.cacheWriteTokens,
      cached_tokens: entry.usage.cachedTokens,
      output_tokens: entry.usage.outputTokens,
      cost_usd: costUsd(entry.model, entry.usage, entry.batch),
      latency_ms: Math.round(entry.latencyMs),
      batch: entry.batch,
    });
    if (error) console.error(JSON.stringify({ fn: "gateway", level: "error", log_failed: error.message }));
  }

  /** Corre `call` con reintentos sobre el modelo principal y después sobre el de respaldo. */
  private async withRetries<T>(
    req: CompletionRequest,
    call: (model: string) => Promise<{ value: T; usage: Usage }>,
  ): Promise<{ value: T; model: string }> {
    await this.checkCaps(req.userId);
    const primary = this.modelFor(req.tier);
    const plan: Array<[string, number]> = [[primary, MAX_ATTEMPTS]];
    if (!this.isLocal && this.models.fallback !== primary) plan.push([this.models.fallback, FALLBACK_ATTEMPTS]);

    let lastError: AIError = new AIError("fatal", "sin intentos");
    for (const [model, attempts] of plan) {
      for (let attempt = 0; attempt < attempts; attempt++) {
        const started = performance.now();
        try {
          const { value, usage } = await call(model);
          await this.log({ feature: req.feature, userId: req.userId, model, promptVersion: req.promptVersion, usage, latencyMs: performance.now() - started, batch: false, ok: true });
          return { value, model };
        } catch (error) {
          lastError = error instanceof AIError ? error : new AIError("retryable", String(error).slice(0, 200));
          await this.log({ feature: req.feature, userId: req.userId, model, promptVersion: req.promptVersion, usage: { inputTokens: 0, outputTokens: 0, cachedTokens: 0, cacheWriteTokens: 0 }, latencyMs: performance.now() - started, batch: false, ok: false });
          console.warn(JSON.stringify({ fn: "gateway", level: "warn", feature: req.feature, model, attempt, kind: lastError.kind, error: lastError.message }));
          // Un error que no se arregla reintentando pasa directo al modelo de respaldo.
          if (lastError.kind !== "retryable") break;
          if (attempt + 1 < attempts) await sleep(backoffMs(attempt));
        }
      }
    }
    throw lastError;
  }

  // ---------------------------------------------------------------
  // complete / stream
  // ---------------------------------------------------------------
  async complete(req: CompletionRequest): Promise<CompletionResult> {
    const { value, model } = await this.withRetries(req, async (model) => {
      const { text, usage } = await this.provider.complete(req, model);
      let parsed: unknown = undefined;
      if (req.jsonSchema) {
        try {
          parsed = JSON.parse(text);
        } catch {
          throw new AIError("retryable", "json inválido");
        }
      }
      return { value: { text, json: parsed, usage }, usage };
    });
    return { text: value.text, json: value.json, model, usage: value.usage };
  }

  /**
   * Streaming: devuelve los pedazos de texto a medida que llegan. Solo se reintenta (y se pasa al modelo de respaldo)
   * si falla antes del primer pedazo; después, el error sube tal cual.
   */
  async *stream(req: CompletionRequest): AsyncGenerator<string, { model: string; usage: Usage }> {
    await this.checkCaps(req.userId);
    const primary = this.modelFor(req.tier);
    const models = this.isLocal || this.models.fallback === primary ? [primary] : [primary, this.models.fallback];

    let lastError: AIError = new AIError("fatal", "sin intentos");
    for (const model of models) {
      for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
        const started = performance.now();
        let emitted = false;
        try {
          for await (const chunk of this.provider.stream(req, model)) {
            if ("delta" in chunk) {
              emitted = true;
              yield chunk.delta;
            } else {
              await this.log({ feature: req.feature, userId: req.userId, model, promptVersion: req.promptVersion, usage: chunk.usage, latencyMs: performance.now() - started, batch: false, ok: true });
              return { model, usage: chunk.usage };
            }
          }
          throw new AIError("retryable", "el stream terminó sin cierre");
        } catch (error) {
          lastError = error instanceof AIError ? error : new AIError("retryable", String(error).slice(0, 200));
          await this.log({ feature: req.feature, userId: req.userId, model, promptVersion: req.promptVersion, usage: { inputTokens: 0, outputTokens: 0, cachedTokens: 0, cacheWriteTokens: 0 }, latencyMs: performance.now() - started, batch: false, ok: false });
          if (emitted) throw lastError;
          if (lastError.kind !== "retryable") break;
          if (attempt + 1 < MAX_ATTEMPTS) await sleep(backoffMs(attempt));
        }
      }
    }
    throw lastError;
  }

  // ---------------------------------------------------------------
  // Batches API
  // ---------------------------------------------------------------
  get supportsBatch(): boolean {
    return !!this.provider.submitBatch;
  }

  async submitBatch(items: BatchItem[], tier: Tier): Promise<string> {
    if (!this.provider.submitBatch) throw new AIError("fatal", "el proveedor no tiene batches");
    await this.checkCaps(null);
    return await this.provider.submitBatch(items, this.modelFor(tier));
  }

  async batchEnded(batchId: string): Promise<boolean> {
    return await this.provider.batchEnded!(batchId);
  }

  /** Levanta los resultados y registra cada uno en llm_calls como batch. */
  async *batchResults(
    batchId: string,
    meta: (customId: string) => { feature: Feature; userId: string | null; promptVersion: string; tier: Tier },
  ): AsyncGenerator<BatchResult> {
    for await (const result of this.provider.batchResults!(batchId)) {
      const info = meta(result.customId);
      const usage = result.usage ?? { inputTokens: 0, outputTokens: 0, cachedTokens: 0, cacheWriteTokens: 0 };
      await this.log({ feature: info.feature, userId: info.userId, model: this.modelFor(info.tier), promptVersion: info.promptVersion, usage, latencyMs: 0, batch: true, ok: !result.error });
      if (result.text !== undefined) {
        try {
          yield { ...result, json: JSON.parse(result.text) };
        } catch {
          yield { customId: result.customId, error: "json inválido" };
        }
      } else {
        yield result;
      }
    }
  }

  // ---------------------------------------------------------------
  // Embeddings
  // ---------------------------------------------------------------
  async embed(texts: string[], opts: { feature: Feature; userId: string | null; inputType?: InputType }): Promise<number[][]> {
    if (texts.length === 0) return [];
    const model = this.embeddings.model;
    for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
      const started = performance.now();
      try {
        const { vectors, tokens } = await this.embeddings.embed(texts, opts.inputType ?? "document");
        await this.log({ feature: opts.feature, userId: opts.userId, model, promptVersion: null, usage: { inputTokens: tokens, outputTokens: 0, cachedTokens: 0, cacheWriteTokens: 0 }, latencyMs: performance.now() - started, batch: false, ok: true });
        return vectors;
      } catch (error) {
        const aiError = error instanceof AIError ? error : new AIError("retryable", String(error).slice(0, 200));
        await this.log({ feature: opts.feature, userId: opts.userId, model, promptVersion: null, usage: { inputTokens: 0, outputTokens: 0, cachedTokens: 0, cacheWriteTokens: 0 }, latencyMs: performance.now() - started, batch: false, ok: false });
        if (aiError.kind !== "retryable" || attempt + 1 === MAX_ATTEMPTS) throw aiError;
        await sleep(backoffMs(attempt));
      }
    }
    throw new AIError("fatal", "embed");
  }
}

let shared: AIGateway | null = null;

export function gateway(): AIGateway {
  shared ??= new AIGateway();
  return shared;
}
