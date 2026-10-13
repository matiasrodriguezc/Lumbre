// Proveedor Anthropic: Messages API con el SDK oficial (importado por npm: y solo si hay ANTHROPIC_API_KEY,
// así el proveedor local no depende de bajar el paquete).
//
// - Salida JSON estructurada (output_config.format) para destilación y chispas.
// - Streaming para el planificador.
// - Prompt caching: los bloques de system marcados con cache llevan cache_control.
// - Batches API para el batch nocturno de chispas diarias (50% menos).
// - Sin reintentos en el SDK: los hace el gateway, con backoff y modelo de respaldo.

import {
  AIError,
  type BatchItem,
  type BatchResult,
  type ChatProvider,
  type CompletionRequest,
  type ContentPart,
  type StreamChunk,
  type Usage,
} from "../types.ts";

// deno-lint-ignore no-explicit-any
type AnthropicModule = any;

let sdk: Promise<AnthropicModule> | null = null;

function loadSdk(): Promise<AnthropicModule> {
  sdk ??= import("npm:@anthropic-ai/sdk@0.129.0");
  return sdk;
}

function toBlocks(content: string | ContentPart[]) {
  if (typeof content === "string") return content;
  return content.map((part) => {
    switch (part.type) {
      case "text":
        return { type: "text", text: part.text, ...(part.cache ? { cache_control: { type: "ephemeral" } } : {}) };
      case "image":
        return { type: "image", source: { type: "base64", media_type: part.mediaType, data: part.data } };
      case "document":
        return { type: "document", source: { type: "base64", media_type: part.mediaType, data: part.data } };
    }
  });
}

/** Parámetros de messages.create para un pedido del gateway. */
export function toParams(req: CompletionRequest, model: string) {
  return {
    model,
    max_tokens: req.maxTokens,
    system: req.system.map((block) => ({
      type: "text",
      text: block.text,
      ...(block.cache ? { cache_control: { type: "ephemeral" } } : {}),
    })),
    messages: req.messages.map((m) => ({ role: m.role, content: toBlocks(m.content) })),
    ...(req.jsonSchema ? { output_config: { format: { type: "json_schema", schema: req.jsonSchema } } } : {}),
  };
}

// deno-lint-ignore no-explicit-any
function usageOf(usage: any): Usage {
  return {
    inputTokens: usage?.input_tokens ?? 0,
    outputTokens: usage?.output_tokens ?? 0,
    cachedTokens: usage?.cache_read_input_tokens ?? 0,
    cacheWriteTokens: usage?.cache_creation_input_tokens ?? 0,
  };
}

// deno-lint-ignore no-explicit-any
function textOf(message: any): string {
  if (message.stop_reason === "refusal") throw new AIError("refusal", "refusal");
  return (message.content ?? [])
    // deno-lint-ignore no-explicit-any
    .filter((block: any) => block.type === "text")
    // deno-lint-ignore no-explicit-any
    .map((block: any) => block.text)
    .join("");
}

/** Traduce los errores del SDK a errores del gateway: reintentables (429, 5xx, red) o no. */
function translate(Anthropic: AnthropicModule, error: unknown): AIError {
  if (error instanceof AIError) return error;
  if (error instanceof Anthropic.RateLimitError || error instanceof Anthropic.InternalServerError) {
    return new AIError("retryable", `anthropic ${error.status}`);
  }
  if (error instanceof Anthropic.APIConnectionError) return new AIError("retryable", "anthropic connection");
  if (error instanceof Anthropic.APIError) {
    const status = (error as { status?: number }).status ?? 0;
    return new AIError(status >= 500 || status === 408 || status === 409 ? "retryable" : "fatal", `anthropic ${status}`);
  }
  return new AIError("retryable", String(error).slice(0, 200));
}

export class AnthropicProvider implements ChatProvider {
  readonly name = "anthropic" as const;
  // deno-lint-ignore no-explicit-any
  private client: Promise<{ Anthropic: AnthropicModule; client: any }>;

  constructor(apiKey: string) {
    this.client = loadSdk().then((mod) => {
      const Anthropic = mod.default;
      return { Anthropic, client: new Anthropic({ apiKey, maxRetries: 0, timeout: 60_000 }) };
    });
  }

  async complete(req: CompletionRequest, model: string): Promise<{ text: string; usage: Usage }> {
    const { Anthropic, client } = await this.client;
    try {
      const message = await client.messages.create(toParams(req, model));
      return { text: textOf(message), usage: usageOf(message.usage) };
    } catch (error) {
      throw translate(Anthropic, error);
    }
  }

  async *stream(req: CompletionRequest, model: string): AsyncIterable<StreamChunk> {
    const { Anthropic, client } = await this.client;
    try {
      const stream = client.messages.stream(toParams(req, model));
      for await (const event of stream) {
        if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
          yield { delta: event.delta.text };
        }
      }
      const final = await stream.finalMessage();
      if (final.stop_reason === "refusal") throw new AIError("refusal", "refusal");
      yield { done: true, usage: usageOf(final.usage) };
    } catch (error) {
      throw translate(Anthropic, error);
    }
  }

  async submitBatch(items: BatchItem[], model: string): Promise<string> {
    const { Anthropic, client } = await this.client;
    try {
      const batch = await client.messages.batches.create({
        requests: items.map((item) => ({ custom_id: item.customId, params: toParams(item.request, model) })),
      });
      return batch.id as string;
    } catch (error) {
      throw translate(Anthropic, error);
    }
  }

  async batchEnded(batchId: string): Promise<boolean> {
    const { Anthropic, client } = await this.client;
    try {
      const batch = await client.messages.batches.retrieve(batchId);
      return batch.processing_status === "ended";
    } catch (error) {
      throw translate(Anthropic, error);
    }
  }

  async *batchResults(batchId: string): AsyncIterable<BatchResult> {
    const { Anthropic, client } = await this.client;
    try {
      // Los resultados llegan en cualquier orden: se identifican por custom_id.
      for await (const result of await client.messages.batches.results(batchId)) {
        if (result.result.type === "succeeded") {
          try {
            yield { customId: result.custom_id, text: textOf(result.result.message), usage: usageOf(result.result.message.usage) };
          } catch {
            yield { customId: result.custom_id, error: "refusal" };
          }
        } else {
          yield { customId: result.custom_id, error: result.result.type };
        }
      }
    } catch (error) {
      throw translate(Anthropic, error);
    }
  }
}
