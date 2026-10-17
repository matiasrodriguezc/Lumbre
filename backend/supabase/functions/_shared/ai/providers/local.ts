// Proveedor local: simula al modelo sin claves ni red. Determinístico (mismo pedido, misma respuesta)
// y creíble para probar la app de punta a punta. Cuesta 0, pero el gateway igual lo registra en llm_calls.
//
// - Destilación: título de las primeras palabras, tesis de la primera oración, principio con plantilla,
//   confianza según el largo del texto (baja si no hay texto: no puede leer imágenes ni PDFs).
// - Chispa: "A × B" y 1–2 oraciones que cruzan los principios con plantillas elegidas por hash del par.
// - Planificador: plantilla según el atajo (backlog, abogado del diablo, stack) o genérica, en streaming.
//   Con el método de los tres cuartos, recorre Soñador, Realista y Crítico según el estado del hilo y cierra con la síntesis.
//   Con una lente (modelo de negocio, trama, post), responde con su formato y la marca [[lens:…]].

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
  if (task.lens) return localLens(task);
  if (task.disney) return localDisney(task);
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

/** Lentes sin modelo: el formato de planner_lens.v1 con plantillas que usan la chispa y las dos neuronas. */
function localLens(task: Extract<CompletionRequest["local"], { kind: "planner" }>): string {
  const { spark, a, b, deep } = task;
  const mark = (lines: string[]) => `[[lens:${task.lens}]]\n\n${lines.join("\n")}`;
  switch (task.lens!) {
    case "business_model":
      return mark([
        `**Para quién**: quien hoy resuelve a mano lo que toca «${a.title}» y lo sufre cada semana.`,
        `**El problema**: ${lowerFirst(stripEnd(a.thesis))}, y hoy no hay una forma simple de aprovecharlo.`,
        `**La propuesta**: «${spark.title}», una forma de usar eso con la regla de «${b.title}».`,
        `**Por qué estas dos neuronas**: de «${a.title}» sale que ${lowerFirst(core(a))}; de «${b.title}», que ${lowerFirst(core(b))}. Juntas son difíciles de copiar.`,
        "**Cómo llega**: una comunidad donde ya estén esas personas, un contenido que muestre el cruce y el boca a boca de las primeras diez.",
        "**Cómo cobra**: suscripción mensual que paga quien lo usa. Precio: supuesto a validar.",
        "**Qué cuesta**: tu tiempo para armar la primera versión y para hablar con las primeras personas.",
        "**El experimento**: ofrecerlo a cinco personas esta semana, a mano, y ver si alguna paga o deja una seña.",
        ...(deep ? ["", "Si dos de cinco dicen que sí, armá la versión mínima; si nadie, cambiá el «para quién» antes que la propuesta."] : []),
      ]);
    case "plot":
      return mark([
        `**Logline**: alguien que vive según «${a.title}» descubre «${b.title}» y tiene que elegir entre los dos antes de perder lo que más quiere.`,
        `**El mundo**: un lugar chico donde ${lowerFirst(stripEnd(a.thesis))}.`,
        "**Protagonista**: quiere que todo siga igual; necesita, aunque no lo sepa, que algo cambie.",
        `**El conflicto**: ${lowerFirst(core(b))}, y eso choca con todo lo que conoce.`,
        "**Tres actos**:",
        `1. Planteo: la vida ordenada por «${a.title}» y la primera grieta.`,
        `2. Confrontación: prueba la regla de «${b.title}» y le sale caro.`,
        `3. Desenlace: encuentra la forma de hacer las dos cosas a la vez: «${spark.title}».`,
        `**El giro**: lo que parecía la amenaza era la otra mitad de la idea.`,
        "**Primera escena**: abre en un día cualquiera, con un gesto repetido mil veces. Esta vez, algo no encaja.",
        ...(deep ? ["", "Para la versión larga: un personaje secundario que encarne cada neurona y una escena donde discutan."] : []),
      ]);
    case "post":
      return mark([
        `**Gancho**: Junté «${shortTitle(a.title)}» con «${shortTitle(b.title)}» y no me lo esperaba.`,
        `**El post**: Hace un tiempo guardé una idea: ${lowerFirst(stripEnd(a.thesis))}.`,
        "",
        `Hace poco guardé otra que no tenía nada que ver: ${lowerFirst(stripEnd(b.thesis))}.`,
        "",
        `Cruzándolas salió esto: ${stripEnd(spark.body || spark.title)}.`,
        "",
        "Todavía no sé si funciona, pero esta semana lo voy a probar en chico.",
        "**Cierre**: ¿Qué dos ideas tuyas, que no tienen nada que ver, cruzarías?",
        "**Otros dos ganchos**:",
        "- Dos ideas que no tenían nada que ver, y una tercera que no puedo dejar de pensar.",
        `- ¿Qué pasa si mirás «${shortTitle(b.title)}» con los ojos de «${shortTitle(a.title)}»?`,
      ]);
  }
}

/** Tres cuartos de Disney sin modelo: avanza por cantidad de respuestas en cada cuarto, como pide el prompt. */
function localDisney(task: Extract<CompletionRequest["local"], { kind: "planner" }>): string {
  const state = task.disney!;
  const { spark, a, b } = task;
  const folded = task.message.normalize("NFD").replace(/\p{Diacritic}/gu, "").toLowerCase();
  const skip = /siguiente cuarto|pasemos|pasamos/.test(folded);
  // La respuesta de ahora cuenta para el cuarto actual.
  const answers = (room: "dreamer" | "realist" | "critic") => state.userTurns[room] + (state.current === room ? 1 : 0);
  const mark = (room: string, text: string) => `[[room:${room}]]\n\n${text}`;

  if (!state.current) {
    return mark("dreamer", `Entramos al cuarto del Soñador. Imaginá que «${spark.title}» funciona por completo: sin presupuesto, sin reglas y sin nadie que diga que no. ¿Cómo se ve? ¿Quién lo usa y qué cambia en su día?`);
  }
  if (state.current === "dreamer") {
    const n = answers("dreamer");
    if (!skip && n === 1) return mark("dreamer", `Me encanta. Ahora más grande: ¿qué pasa si en vez de unas pocas personas lo usa todo un país? ¿Qué parte de «${a.title}» se vuelve enorme?`);
    if (!skip && n === 2) return mark("dreamer", `Una vez más, sin techo: si dentro de diez años esto fuera lo que todos asocian con «${b.title}», ¿cómo sería?`);
    return mark("realist", "Pasamos al cuarto del Realista. Para volver real ese sueño: ¿cuáles son los pasos, qué gente hace falta, cuánta plata y qué es lo primero que tiene que pasar?");
  }
  if (state.current === "realist") {
    if (!skip && answers("realist") === 1) return mark("realist", "Bajemos lo primero a tierra: ¿qué podés hacer esta semana, con lo que ya tenés, para que eso pase?");
    return mark("critic", "Pasamos al cuarto del Crítico. Primera pregunta: ¿qué le falta a esto?");
  }
  if (state.current === "critic") {
    const n = answers("critic");
    if (!skip && n === 1) return mark("critic", "Segunda: ¿qué puede salir mal?");
    if (!skip && n === 2) return mark("critic", "Última: ¿quién odiaría esto, y por qué?");
  }
  if (state.current === "critic" || (state.current !== "plan" && skip)) {
    const least = (["dreamer", "realist", "critic"] as const)
      .reduce((min, room) => (state.userTurns[room] < state.userTurns[min] ? room : min), "dreamer" as "dreamer" | "realist" | "critic");
    const names = { dreamer: "Soñador", realist: "Realista", critic: "Crítico" };
    return mark("plan", [
      `**El sueño**: «${spark.title}» como lo que todos usan sin pensarlo.`,
      "",
      "**El plan**:",
      "1. Esta semana: probar la versión más chica con 3 personas.",
      `2. Armar el mecanismo central con lo de «${a.title}».`,
      `3. Sumar lo de «${b.title}» como el detalle que lo hace distinto.`,
      "4. Medir si vuelven solos.",
      "5. Decidir qué se corta y qué crece.",
      "",
      "**Los tres agujeros**:",
      "- Falta saber quién lo pide hoy. Arreglo: hablar con cinco personas antes de construir.",
      "- Puede salir caro. Arreglo: hacerlo a mano la primera vez.",
      "- Lo odiarían quienes viven del sistema actual. Arreglo: sumarlos como aliados desde el paso 1.",
      "",
      `**El cuarto que salteás**: el ${names[least]}. Volvé ahí la próxima vez antes de pasar al siguiente.`,
    ].join("\n"));
  }
  return mark("plan", `Sobre «${spark.title}»: elegí una sola cosa del plan para esta semana y medí si cambia algo.`);
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
