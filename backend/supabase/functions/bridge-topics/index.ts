// POST /bridge-topics — temas puente de la semana (paso 92, contrato: BridgeTopics).
//
// Si la Red tiene mucho de dos dominios que casi no se cruzaron, sugiere 2 o 3 temas para leer que los unan.
// - La app la pide al abrir la Red y en Hoy cuando quedan pocos pares buenos, solo con el flag bridge_topics.
// - Solo Pro (decidido el 2026-10-17) y una llamada a la IA por semana como mucho (cupo bridge_topics de
//   plan_limits): la sugerencia de la semana queda guardada y se devuelve sin volver a llamar.
// - Sin sugerencia posible responde { bridge: null }: no es Pro (invitado o free), sin consentimiento, sin dos
//   dominios fuertes y poco cruzados, cupo de la semana ya usado, o la IA falló. Hoy y la Red no muestran nada.
// - Si la IA falla antes de responder se devuelve el cupo; si respondió algo inválido (links, obras), no:
//   así una respuesta mala no se repite toda la semana.
// - Los títulos de las neuronas van al modelo como datos (bridge.v1); los logs nunca llevan contenido.

import { requireDeviceIntegrity } from "../_shared/attest/guard.ts";
import { AIError } from "../_shared/ai/types.ts";
import { suggestBridgeTopics, type BridgeTopic } from "../_shared/ai/tasks.ts";
import { ApiError, describeError, handler, json } from "../_shared/http.ts";
import { admin, consumeCredit, dbError, effectivePlan, hasAIConsent, refundCredit, requireUser, rpc } from "../_shared/supabase.ts";

const BRIDGE_PER_HOUR = Number(Deno.env.get("LUMBRE_BRIDGE_PER_HOUR") ?? 60);
/** Títulos de ejemplo de cada dominio que van al modelo como contexto. */
const EXAMPLES_PER_DOMAIN = 5;

interface BridgeRow {
  id: string;
  domain_a: string;
  domain_b: string;
  topics: BridgeTopic[];
  created_at: string;
}

interface DomainRow {
  slug: string;
  name_es: string;
  name_en: string;
  symbol_ios: string | null;
}

async function domains(slugs: string[]): Promise<DomainRow[]> {
  const { data, error } = await admin().from("domains").select("slug,name_es,name_en,symbol_ios").in("slug", slugs);
  if (error) throw dbError(error);
  const bySlug = new Map((data as DomainRow[]).map((d) => [d.slug, d]));
  return slugs.map((slug) => bySlug.get(slug)!).filter(Boolean);
}

async function present(row: BridgeRow) {
  return {
    id: row.id,
    domains: await domains([row.domain_a, row.domain_b]),
    topics: row.topics,
    created_at: row.created_at,
  };
}

/** Los títulos más recientes de sus neuronas de ese dominio (sin borradores ni las de la biblioteca). */
async function examples(userId: string, domain: string): Promise<string[]> {
  const { data, error } = await admin().from("concepts").select("title")
    .eq("user_id", userId).eq("domain", domain).eq("status", "ready").eq("from_library", false)
    .order("created_at", { ascending: false }).limit(EXAMPLES_PER_DOMAIN);
  if (error) throw dbError(error);
  return (data as Array<{ title: string }>).map((c) => c.title);
}

Deno.serve(handler("bridge-topics", async (req) => {
  const user = await requireUser(req);
  await requireDeviceIntegrity(req, "bridge-topics", user.id);
  if (!(await rpc<boolean>(admin(), "hit_rate_limit", { p_key: `bridge:${user.id}`, p_max: BRIDGE_PER_HOUR, p_window_seconds: 3600 }))) {
    throw new ApiError("rate_limited");
  }
  // Solo Pro (el invitado y free no tienen el cupo); sin el "Acepto", los títulos de sus neuronas no van al modelo.
  if (user.isAnonymous || (await effectivePlan(user.id)) !== "pro" || !(await hasAIConsent(user.id))) return json({ bridge: null });

  const [current] = await rpc<BridgeRow[]>(admin(), "current_bridge_topics", { p_user: user.id });
  if (current) return json({ bridge: await present(current) });

  const [pair] = await rpc<Array<{ domain_a: string; domain_b: string }>>(admin(), "bridge_domain_pair", { p_user: user.id });
  if (!pair) return json({ bridge: null });

  // El cupo de la semana: si ya se usó (o lo tomó otro pedido simultáneo), no se vuelve a llamar.
  if (!(await consumeCredit(user.id, "bridge_topics"))) return json({ bridge: null });

  try {
    const { data: profile, error } = await admin().from("profiles").select("locale").eq("id", user.id).maybeSingle();
    if (error) throw dbError(error);
    const locale: "es" | "en" = profile?.locale === "en" ? "en" : "es";
    const [a, b] = await domains([pair.domain_a, pair.domain_b]);
    const name = (d: DomainRow) => locale === "en" ? d.name_en : d.name_es;
    const suggestion = await suggestBridgeTopics({
      a: { slug: a.slug, name: name(a), examples: await examples(user.id, a.slug) },
      b: { slug: b.slug, name: name(b), examples: await examples(user.id, b.slug) },
      locale,
    }, user.id);

    const { data: row, error: insertError } = await admin().from("bridge_topics").insert({
      user_id: user.id,
      domain_a: pair.domain_a,
      domain_b: pair.domain_b,
      topics: suggestion.topics,
      locale,
      prompt_version: suggestion.promptVersion,
      model: suggestion.model,
    }).select("id,domain_a,domain_b,topics,created_at").single();
    if (insertError) throw dbError(insertError);
    return json({ bridge: await present(row as BridgeRow) });
  } catch (error) {
    // Respuesta inválida o moderada: el cupo de la semana queda usado. Cualquier otra falla lo devuelve.
    const invalid = error instanceof AIError && error.kind === "fatal";
    if (!invalid) await refundCredit(user.id, "bridge_topics");
    console.error(JSON.stringify({ fn: "bridge-topics", level: "error", refunded: !invalid, error: describeError(error) }));
    return json({ bridge: null });
  }
}));
