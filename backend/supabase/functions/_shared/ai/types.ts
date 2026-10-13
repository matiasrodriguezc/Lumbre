// Tipos del gateway de IA. Los proveedores (local y Anthropic) reciben lo mismo y devuelven lo mismo.

export type Tier = "fast" | "deep";

/** Para qué es la llamada. Va a llm_calls.feature y al tablero de costos. */
export type Feature =
  | "distill"
  | "spark"
  | "planner"
  | "planner_summary"
  | "embed"
  | "search"
  | "classify";

export type ContentPart =
  | { type: "text"; text: string; cache?: boolean }
  | { type: "image"; mediaType: "image/jpeg" | "image/png"; data: string }
  | { type: "document"; mediaType: "application/pdf"; data: string };

export interface ChatMessage {
  role: "user" | "assistant";
  content: string | ContentPart[];
}

export interface ConceptBrief {
  id: string;
  title: string;
  thesis: string;
  principle: string | null;
}

/**
 * Lo que el proveedor local necesita para simular una respuesta creíble sin modelo.
 * El proveedor real lo ignora: usa system y messages.
 */
export type LocalTask =
  | { kind: "distill"; text: string; sourceTitle: string | null; hasAttachment: boolean }
  | { kind: "spark"; a: ConceptBrief; b: ConceptBrief }
  | {
    kind: "planner";
    preset: PlannerPreset | null;
    deep: boolean;
    message: string;
    spark: { title: string; body: string };
    a: ConceptBrief;
    b: ConceptBrief;
    project: string | null;
    /** Método de los tres cuartos (planner.v2): estado del hilo antes de este mensaje. */
    disney?: { current: "dreamer" | "realist" | "critic" | "plan" | null; userTurns: Record<"dreamer" | "realist" | "critic" | "plan", number> };
  }
  | { kind: "summary"; previous: string | null; messages: Array<{ role: string; content: string }> };

export type PlannerPreset = "backlog" | "devils_advocate" | "stack";

export interface CompletionRequest {
  feature: Feature;
  userId: string | null;
  tier: Tier;
  promptVersion: string;
  /** Bloques del system prompt. `cache: true` marca el final del prefijo fijo (prompt caching). */
  system: Array<{ text: string; cache?: boolean }>;
  messages: ChatMessage[];
  maxTokens: number;
  /** Si está, la respuesta es JSON que cumple este schema (salida estructurada). */
  jsonSchema?: Record<string, unknown>;
  local: LocalTask;
}

export interface Usage {
  inputTokens: number;
  outputTokens: number;
  /** Tokens leídos de la caché de prompts. */
  cachedTokens: number;
  /** Tokens escritos en la caché (se cobran un 25% más). */
  cacheWriteTokens: number;
}

export interface CompletionResult {
  text: string;
  json?: unknown;
  model: string;
  usage: Usage;
}

export type StreamChunk = { delta: string } | { done: true; usage: Usage };

export interface BatchItem {
  customId: string;
  request: CompletionRequest;
}

export interface BatchResult {
  customId: string;
  text?: string;
  json?: unknown;
  usage?: Usage;
  error?: string;
}

export interface ChatProvider {
  readonly name: "local" | "anthropic";
  complete(req: CompletionRequest, model: string): Promise<{ text: string; usage: Usage }>;
  stream(req: CompletionRequest, model: string): AsyncIterable<StreamChunk>;
  /** Batches API (50% menos). El proveedor local no la tiene: las chispas se generan en el momento. */
  submitBatch?(items: BatchItem[], model: string): Promise<string>;
  batchEnded?(batchId: string): Promise<boolean>;
  batchResults?(batchId: string): AsyncIterable<BatchResult>;
}

export type AIErrorKind = "retryable" | "fatal" | "refusal" | "user_cap" | "global_cap";

export class AIError extends Error {
  constructor(public kind: AIErrorKind, message: string) {
    super(message);
    this.name = "AIError";
  }
}

export function emptyUsage(): Usage {
  return { inputTokens: 0, outputTokens: 0, cachedTokens: 0, cacheWriteTokens: 0 };
}

/** Estimación de tokens para el proveedor local (aprox. 4 caracteres por token). */
export function estimateTokens(text: string): number {
  return Math.max(1, Math.ceil(text.length / 4));
}
