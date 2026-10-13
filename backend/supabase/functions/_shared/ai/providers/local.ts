// Proveedor local: simula al modelo sin claves ni red. Determinístico (mismo pedido, misma respuesta)
// y creíble para probar la app de punta a punta. Cuesta 0, pero el gateway igual lo registra en llm_calls.
//
// - Destilación: título de las primeras palabras, tesis de la primera oración, principio con plantilla,
//   confianza según el largo del texto (baja si no hay texto: no puede leer imágenes ni PDFs).
// - Chispa: "A × B" y 1–2 oraciones que cruzan los principios con plantillas elegidas por hash del par.
// - Planificador: plantilla según el atajo (backlog, abogado del diablo, stack) o genérica, en streaming.

import { clip, firstSentence, fnv1a, wordCount } from "../../text.ts";
import {
  type ChatProvider,
  type CompletionRequest,
  type ConceptBrief,
  estimateTokens,
  type StreamChunk,
  type Usage,
} from "../types.ts";

export const LOCAL_MODEL = "local";

function stripEnd(text: string): string {
  return text.trim().replace(/[.!?…\s]+$/u, "");
}

function lowerFirst(text: string): string {
  if (!text) return text;
  // No baja siglas ni nombres propios evidentes (dos mayúsculas seguidas).
  if (/^[A-ZÁÉÍÓÚÑ]{2}/u.test(text)) return text;
  return text[0].toLowerCase() + text.slice(1);
}

function core(concept: ConceptBrief): string {
  return stripEnd(concept.principle ?? concept.thesis);
}

function shortTitle(title: string): string {
  return clip(title.replace(/…$/u, ""), 28);
}

// ---------------------------------------------------------------
// Destilación
// ---------------------------------------------------------------
const PRINCIPLES = [
  (t: string) => `Detrás de «${t}» hay un mecanismo simple que funciona fuera de su contexto original.`,
  (t: string) => `Lo que hace funcionar «${t}» es una regla que se puede copiar en otro sistema.`,
  (t: string) => `«${t}» muestra que un cambio chico en el lugar justo reordena todo lo demás.`,
  (t: string) => `En «${t}», la restricción es lo que produce el resultado, no un obstáculo.`,
];

export function localDistill(task: Extract<CompletionRequest["local"], { kind: "distill" }>) {
  const text = task.text.trim();
  const words = wordCount(text);
  if (words === 0) {
    return { concepts: [], confidence: "low", reason: task.hasAttachment ? "local_cannot_read_files" : "empty" };
  }
  const sentence = clip(firstSentence(text), 240);
  const titleSource = task.sourceTitle?.trim() || sentence;
  const title = clip(stripEnd(titleSource).split(/\s+/).slice(0, 7).join(" "), 60);
  const principle = PRINCIPLES[fnv1a(title) % PRINCIPLES.length](title);
  const confidence = words >= 120 ? "high" : words >= 30 ? "medium" : "low";
  return {
    concepts: [{ domain: null, title, thesis: /[.!?]$/u.test(sentence) ? sentence : `${sentence}.`, principle }],
    confidence,
    reason: confidence === "low" ? "too_short" : null,
  };
}

// ---------------------------------------------------------------
// Chispa
// ---------------------------------------------------------------
const SPARKS = [
  (a: ConceptBrief, b: ConceptBrief) =>
    `Llevá «${a.title}» al terreno de «${b.title}»: ${lowerFirst(core(a))}. ¿Qué pasaría si eso se aplicara a que ${lowerFirst(stripEnd(b.thesis))}?`,
  (a: ConceptBrief, b: ConceptBrief) =>
    `${core(b)}. Mirá «${a.title}» con esa regla y buscá la parte que se podría diseñar igual.`,
  (a: ConceptBrief, b: ConceptBrief) =>
    `Un experimento: tratá «${b.title}» como si fuera «${a.title}». Si ${lowerFirst(core(a))}, la versión nueva aprovecha eso desde el día uno.`,
  (a: ConceptBrief, b: ConceptBrief) =>
    `«${a.title}» y «${b.title}» comparten algo: ${lowerFirst(core(a))}. Probá armar algo chico que use las dos ideas a la vez.`,
  (a: ConceptBrief, b: ConceptBrief) =>
    `Si ${lowerFirst(stripEnd(a.thesis))}, ¿qué versión de «${b.title}» se apoyaría en eso en vez de pelearlo?`,
  (a: ConceptBrief, b: ConceptBrief) =>
    `De «${a.title}» sacá que ${lowerFirst(core(a))}; de «${b.title}», que ${lowerFirst(core(b))}. La chispa está en hacer las dos cosas en el mismo lugar.`,
];

export function localSpark(a: ConceptBrief, b: ConceptBrief) {
  // El orden del par no cambia la plantilla, pero sí cuál concepto va primero según el hash.
  const hash = fnv1a([a.id, b.id].sort().join(":"));
  const [first, second] = hash & 1 ? [b, a] : [a, b];
  const body = SPARKS[hash % SPARKS.length](first, second);
  return { title: `${shortTitle(first.title)} × ${shortTitle(second.title)}`, body: clip(body, 420) };
}

// ---------------------------------------------------------------
// Planificador
// ---------------------------------------------------------------
export function localPlanner(task: Extract<CompletionRequest["local"], { kind: "planner" }>): string {
  const { spark, a, b, project, deep } = task;
  const where = project ? ` dentro de «${project}»` : "";
  switch (task.preset) {
    case "backlog": {
      const items = [
        `Escribir en una frase qué problema resuelve «${spark.title}» y para quién.`,
        `Armar la versión mínima que use «${a.title}» como mecanismo central.`,
        `Sumar lo de «${b.title}» como el detalle que la hace distinta.`,
        `Probarlo con 3 personas y anotar qué entienden sin explicación.`,
        `Decidir qué se corta antes de seguir.`,
      ];
      if (deep) items.push("Definir una métrica de éxito para la primera semana.", "Listar los riesgos y cómo detectar cada uno temprano.");
      return `Backlog para «${spark.title}»${where}:\n${items.map((item, i) => `${i + 1}. ${item}`).join("\n")}`;
    }
    case "devils_advocate":
      return [
        `Hago de abogado del diablo con «${spark.title}»:`,
        `- ¿Por qué alguien cambiaría lo que hace hoy por esto? Si la respuesta es "porque es nuevo", no alcanza.`,
        `- «${a.title}» funciona en su contexto original por razones que quizás acá no están. ¿Cuáles se pierden?`,
        `- Lo de «${b.title}» puede sumar complejidad sin sumar valor. ¿Qué pasa si lo sacás?`,
        deep ? `- El riesgo más grande no es técnico: es que nadie lo pida. Buscá una señal de demanda antes de construir.` : "",
      ].filter(Boolean).join("\n");
    case "stack":
      return [
        `Un stack simple para «${spark.title}»:`,
        `- Prototipo: una página o una app de una sola pantalla, sin cuentas.`,
        `- Datos: una tabla con lo mínimo; nada de servicios aparte hasta que haga falta.`,
        `- Medición: un solo evento que diga si la idea se usó.`,
        deep ? `- Después: automatizar lo que hoy hacés a mano solo cuando se repita tres veces.` : "",
      ].filter(Boolean).join("\n");
    default:
      return [
        `Sobre «${spark.title}»${where}: el punto fuerte es que ${lowerFirst(core(a))}.`,
        `Para avanzar, elegí una sola cosa concreta para probar esta semana y medí si cambia algo.`,
        deep ? `Si funciona, sumá lo de «${b.title}» como segunda capa y revisá qué parte se puede simplificar.` : "",
      ].filter(Boolean).join(" ");
  }
}

function localSummary(task: Extract<CompletionRequest["local"], { kind: "summary" }>): string {
  const points = task.messages
    .filter((m) => m.role === "user")
    .map((m) => clip(firstSentence(m.content), 120));
  const previous = task.previous ? `${task.previous} ` : "";
  return clip(`${previous}Se habló de: ${points.join("; ")}.`, 1500);
}

// ---------------------------------------------------------------
// Proveedor
// ---------------------------------------------------------------
function respond(req: CompletionRequest): string {
  const task = req.local;
  switch (task.kind) {
    case "distill":
      return JSON.stringify(localDistill(task));
    case "spark":
      return JSON.stringify(localSpark(task.a, task.b));
    case "planner":
      return localPlanner(task);
    case "summary":
      return localSummary(task);
  }
}

function usageFor(req: CompletionRequest, output: string): Usage {
  const input = req.system.map((s) => s.text).join("\n") +
    req.messages.map((m) => typeof m.content === "string" ? m.content : m.content.map((p) => p.type === "text" ? p.text : "").join(" ")).join("\n");
  return { inputTokens: estimateTokens(input), outputTokens: estimateTokens(output), cachedTokens: 0, cacheWriteTokens: 0 };
}

export class LocalProvider implements ChatProvider {
  readonly name = "local" as const;

  complete(req: CompletionRequest): Promise<{ text: string; usage: Usage }> {
    const text = respond(req);
    return Promise.resolve({ text, usage: usageFor(req, text) });
  }

  async *stream(req: CompletionRequest): AsyncIterable<StreamChunk> {
    const text = respond(req);
    // Palabra por palabra, como llegaría del modelo.
    const pieces = text.match(/\S+\s*/gu) ?? [];
    for (const piece of pieces) {
      yield { delta: piece };
      await new Promise((resolve) => setTimeout(resolve, 12));
    }
    yield { done: true, usage: usageFor(req, text) };
  }
}
