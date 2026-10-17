// POST /demo-spark — la demo web de la chispa (paso 6). Pública (verify_jwt = false): la llama la landing sin sesión.
//
// { email, idea_a, idea_b, ref?, locale?, utm?, website (trampa), elapsed_ms }
//   → { spark: { title, body }, ideas: { a, b }, waitlist: { status: "joined", token, entry } | { status: "existing" } }
//
// - Pasa por el gateway de IA (_shared/ai): Anthropic si hay ANTHROPIC_API_KEY, si no el proveedor local determinístico.
//   Cuenta para el tope global en dólares; se registra en llm_calls como demo_spark, sin usuario.
// - Una chispa por email y por día (Buenos Aires), con un máximo global por día (app_config.web_demo_daily_max).
//   Si la IA falla, se devuelve la del día. Por IP: 5 por hora y 10 por día. Campo trampa y tiempo mínimo.
// - El email queda anotado en la waitlist (con el mail de confirmación si es nuevo).
// - Las ideas que pega la persona son datos, nunca instrucciones (van delimitadas, ver prompt.ts), no se guardan
//   y no van a los logs. Moderación de entrada y de salida.
// - Flag del servidor: app_config.web_demo_enabled.

import { Analytics } from "../_shared/analytics.ts";
import { gateway } from "../_shared/ai/gateway.ts";
import { checkSparkJson } from "../_shared/ai/tasks.ts";
import { type ConceptBrief, type Feature } from "../_shared/ai/types.ts";
import { logModeration, moderate } from "../_shared/moderation.ts";
import { admin } from "../_shared/supabase.ts";
import { clip, cleanText, fnv1a, lengthBucket, wordCount } from "../_shared/text.ts";
import { clientIp, enforce, looksLikeBot, requireFlag, subjectHash } from "../_web/abuse.ts";
import { readWebJson, WebError, webHandler, webJson, webLog } from "../_web/http.ts";
import { joinWaitlist, normalizeEmail, toPublic } from "../_web/waitlist.ts";
import { DEMO_SPARK_SCHEMA, DEMO_SPARK_SYSTEM, DEMO_SPARK_VERSION, demoUserText } from "./prompt.ts";

const MIN_CHARS = 8;
const MAX_CHARS = 500;
const STOPWORDS = new Set([
  "a", "al", "con", "de", "del", "el", "en", "es", "la", "las", "lo", "los", "por", "para", "que", "se", "su", "un", "una", "y", "o",
  "the", "of", "to", "and", "in", "is", "for", "on", "with",
]);

function readIdea(value: unknown): string {
  if (typeof value !== "string") throw new WebError("invalid_ideas");
  const idea = cleanText(value, 120);
  if (idea.length < MIN_CHARS || value.length > MAX_CHARS * 2 || wordCount(idea) < 2) throw new WebError("invalid_ideas");
  return clip(idea, MAX_CHARS);
}

/** Etiqueta corta de una idea para "A × B" cuando el modelo no la da (proveedor local). */
function label(idea: string): string {
  const words = idea.replace(/[.!?…:;,«»"]/gu, "").split(/\s+/).filter(Boolean);
  const kept = [words[0] ?? ""];
  for (const word of words.slice(1, 4)) {
    if (`${kept.join(" ")} ${word}`.length > 24) break;
    kept.push(word);
  }
  // Sin palabras sueltas al final ("Las ruinas romanas se").
  while (kept.length > 1 && STOPWORDS.has(kept[kept.length - 1].toLowerCase())) kept.pop();
  return clip(kept.join(" "), 28);
}

function brief(key: string, idea: string): ConceptBrief {
  return { id: `demo-${key}-${fnv1a(idea).toString(16)}`, title: label(idea), thesis: idea, principle: null };
}

Deno.serve(webHandler("demo-spark", async (req) => {
  await requireFlag("web_demo_enabled");
  const body = await readWebJson(req);
  const ip = await subjectHash("ip", clientIp(req));
  await enforce(ip, [
    { bucket: "demo_hour", windowSeconds: 3600, max: 5 },
    { bucket: "demo_day", windowSeconds: 86_400, max: 10 },
  ]);
  if (looksLikeBot(body)) {
    webLog("demo-spark", { event: "bot" });
    throw new WebError("invalid_request");
  }

  const email = normalizeEmail(body.email);
  const ideaA = readIdea(body.idea_a);
  const ideaB = readIdea(body.idea_b);
  const inputCheck = await moderate(`${ideaA}\n${ideaB}`);
  logModeration("demo-spark", "input", inputCheck);
  if (inputCheck.flagged) throw new WebError("invalid_content");

  // El email entra a la fila aunque después no haya chispa (ya usó la de hoy o se llegó al máximo).
  const { entry, token } = await joinWaitlist({
    email,
    referralCode: body.ref,
    locale: body.locale,
    source: "demo",
    utm: body.utm,
    resendIfExisting: false,
  });
  const waitlist = token
    ? { status: "joined", token, entry: await toPublic(entry) }
    : { status: "existing" };

  const { data: claim, error: claimError } = await admin().rpc("demo_spark_claim", { p_waitlist_id: entry.id });
  if (claimError) throw new Error(`demo_spark_claim: ${claimError.message}`);
  if (claim === "used") return webJson(req, { error: "daily_limit", waitlist }, 429);
  if (claim === "full") return webJson(req, { error: "demo_full", waitlist }, 503);

  const a = brief("a", ideaA);
  const b = brief("b", ideaB);
  let spark: { title: string; body: string };
  let labels = { a: a.title, b: b.title };
  try {
    const result = await gateway().complete({
      feature: "demo_spark" as Feature,
      userId: null,
      tier: "fast",
      promptVersion: DEMO_SPARK_VERSION,
      system: [{ text: DEMO_SPARK_SYSTEM, cache: true }],
      messages: [{ role: "user", content: demoUserText(ideaA, ideaB) }],
      maxTokens: 600,
      jsonSchema: DEMO_SPARK_SCHEMA as unknown as Record<string, unknown>,
      local: { kind: "spark", a, b },
    });
    const raw = (result.json ?? {}) as { label_a?: string; label_b?: string };
    if (raw.label_a?.trim() && raw.label_b?.trim()) labels = { a: clip(raw.label_a.trim(), 28), b: clip(raw.label_b.trim(), 28) };
    spark = await checkSparkJson(result.json, { ...a, title: labels.a }, { ...b, title: labels.b });
  } catch (error) {
    await admin().rpc("demo_spark_release", { p_waitlist_id: entry.id });
    console.error(JSON.stringify({ fn: "demo-spark", level: "error", event: "ai_failed", error: String(error).slice(0, 200) }));
    return webJson(req, { error: "ai_unavailable", waitlist }, 503);
  }

  const analytics = new Analytics();
  analytics.track("demo_spark_generated", entry.id, { ideas_length_bucket: lengthBucket(wordCount(ideaA) + wordCount(ideaB)) });
  await analytics.flush();
  webLog("demo-spark", { event: "generated", new_email: token !== null });

  // Las neuronas se muestran en el mismo orden que el título "A × B" (el proveedor local a veces las invierte).
  const ideas = spark.title.startsWith(`${labels.b} ×`) ? { a: labels.b, b: labels.a } : labels;
  return webJson(req, { spark, ideas, waitlist });
}));
