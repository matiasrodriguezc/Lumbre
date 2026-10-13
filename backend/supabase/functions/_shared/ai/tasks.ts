// Tareas de IA de Lumbre sobre el gateway: destilar, escribir la chispa y resumir el hilo del planificador.
// Arman el pedido con el prompt versionado y la tarea para el proveedor local.

import { moderate, logModeration } from "../moderation.ts";
import { clip } from "../text.ts";
import { gateway } from "./gateway.ts";
import { localSpark } from "./providers/local.ts";
import { DISTILL_SCHEMA, DISTILL_SYSTEM, DISTILL_VERSION, DOMAIN_SLUGS, type DistillInput, distillUserText } from "./prompts/distill.v1.ts";
import { SPARK_SCHEMA, SPARK_SYSTEM, SPARK_VERSION, sparkUserText } from "./prompts/spark.v1.ts";
import { SUMMARY_SYSTEM, SUMMARY_VERSION } from "./prompts/planner.v1.ts";
import { AIError, type BatchItem, type CompletionRequest, type ConceptBrief, type ContentPart } from "./types.ts";

// ---------------------------------------------------------------
// Destilación
// ---------------------------------------------------------------
export interface DistilledConcept {
  domain: string | null;
  title: string;
  thesis: string;
  principle: string;
}

export interface Distillation {
  concepts: DistilledConcept[];
  confidence: "high" | "medium" | "low";
  reason: string | null;
}

export interface Attachment {
  mimeType: "image/jpeg" | "image/png" | "application/pdf";
  base64: string;
}

export async function distill(input: DistillInput, attachment: Attachment | null, userId: string): Promise<Distillation> {
  const content: ContentPart[] = [];
  if (attachment?.mimeType === "application/pdf") content.push({ type: "document", mediaType: "application/pdf", data: attachment.base64 });
  else if (attachment) content.push({ type: "image", mediaType: attachment.mimeType, data: attachment.base64 });
  content.push({ type: "text", text: distillUserText(input) });

  const localText = [input.userThesis, input.excerpt, input.sourceText].filter(Boolean).join(" ");
  const result = await gateway().complete({
    feature: "distill",
    userId,
    tier: "fast",
    promptVersion: DISTILL_VERSION,
    system: [{ text: DISTILL_SYSTEM, cache: true }],
    messages: [{ role: "user", content }],
    maxTokens: 1500,
    jsonSchema: DISTILL_SCHEMA as unknown as Record<string, unknown>,
    local: { kind: "distill", text: localText, sourceTitle: input.sourceTitle, hasAttachment: !!attachment },
  });

  const raw = result.json as { concepts?: DistilledConcept[]; confidence?: string; reason?: string | null };
  const confidence = raw.confidence === "high" || raw.confidence === "medium" ? raw.confidence : "low";
  const concepts = (raw.concepts ?? [])
    .filter((c) => c && c.title?.trim() && c.thesis?.trim())
    .slice(0, 3)
    .map((c) => ({
      domain: c.domain && (DOMAIN_SLUGS as readonly string[]).includes(c.domain) ? c.domain : null,
      title: clip(c.title.replace(/^["«]|["»]$/g, ""), 120),
      thesis: clip(c.thesis, 600),
      principle: clip(c.principle ?? "", 600),
    }));

  // Moderación de salida: un concepto destilado inaceptable no se guarda.
  const safe: DistilledConcept[] = [];
  for (const concept of concepts) {
    const check = await moderate(`${concept.title} ${concept.thesis} ${concept.principle}`);
    logModeration("distill", "output", check);
    if (!check.flagged) safe.push(concept);
  }
  return { concepts: safe, confidence: safe.length ? confidence : "low", reason: safe.length ? raw.reason ?? null : raw.reason ?? "no_concepts" };
}

// ---------------------------------------------------------------
// Chispa
// ---------------------------------------------------------------
export interface SparkText {
  title: string;
  body: string;
  model: string;
}

export function sparkRequest(a: ConceptBrief, b: ConceptBrief, profiles: string[], userId: string | null): CompletionRequest {
  return {
    feature: "spark",
    userId,
    tier: "fast",
    promptVersion: SPARK_VERSION,
    system: [{ text: SPARK_SYSTEM, cache: true }],
    messages: [{ role: "user", content: sparkUserText(a, b, profiles) }],
    maxTokens: 600,
    jsonSchema: SPARK_SCHEMA as unknown as Record<string, unknown>,
    local: { kind: "spark", a, b },
  };
}

/** Valida y limpia la respuesta del modelo. Si no sirve (vacía o moderada), lanza para reintentar o caer al respaldo. */
export async function checkSparkJson(json: unknown, a: ConceptBrief, b: ConceptBrief): Promise<{ title: string; body: string }> {
  const value = json as { title?: string; body?: string } | null;
  const title = clip(value?.title?.trim() || `${a.title} × ${b.title}`, 80);
  const body = clip(value?.body?.trim() ?? "", 600);
  if (!body) throw new AIError("retryable", "chispa vacía");
  const check = await moderate(`${title} ${body}`);
  logModeration("spark", "output", check);
  if (check.flagged) throw new AIError("fatal", "moderated");
  return { title, body };
}

/**
 * Escribe el texto de la chispa. Con `localFallback`, si la IA falla, usa la plantilla local
 * (para que Hoy nunca quede vacía); sin él, el error sube y la función devuelve el crédito.
 */
export async function writeSpark(
  a: ConceptBrief,
  b: ConceptBrief,
  profiles: string[],
  userId: string | null,
  opts: { localFallback?: boolean } = {},
): Promise<SparkText> {
  try {
    const result = await gateway().complete(sparkRequest(a, b, profiles, userId));
    return { ...(await checkSparkJson(result.json, a, b)), model: result.model };
  } catch (error) {
    if (!opts.localFallback) throw error;
    console.warn(JSON.stringify({ fn: "spark", level: "warn", fallback: "local", error: String(error).slice(0, 200) }));
    return { ...localSpark(a, b), model: "local" };
  }
}

export function sparkBatchItem(customId: string, a: ConceptBrief, b: ConceptBrief, profiles: string[], userId: string): BatchItem {
  return { customId, request: sparkRequest(a, b, profiles, userId) };
}

// ---------------------------------------------------------------
// Resumen incremental del planificador
// ---------------------------------------------------------------
export async function summarizeThread(
  previous: string | null,
  messages: Array<{ role: string; content: string }>,
  userId: string,
): Promise<string> {
  const transcript = messages.map((m) => `${m.role === "user" ? "Persona" : "Planificador"}: ${m.content}`).join("\n\n");
  const result = await gateway().complete({
    feature: "planner_summary",
    userId,
    tier: "fast",
    promptVersion: SUMMARY_VERSION,
    system: [{ text: SUMMARY_SYSTEM }],
    messages: [{
      role: "user",
      content: [
        previous ? `Resumen anterior:\n${previous}` : "No hay resumen anterior.",
        "<mensajes>",
        transcript,
        "</mensajes>",
        "Escribí el resumen actualizado.",
      ].join("\n"),
    }],
    maxTokens: 600,
    local: { kind: "summary", previous, messages },
  });
  return clip(result.text, 3000);
}
