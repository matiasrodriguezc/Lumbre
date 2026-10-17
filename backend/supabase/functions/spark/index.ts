// POST /spark — chispa extra en tiempo real (contrato: { mode: extra | pick, concept_ids? }).
//
// - Descuenta `spark_extra` (free: las ganadas; pro: hasta 10 por día). Invitado: 403 account_required.
// - Sin consentimiento para la IA (profiles.ai_consent_at): 403 ai_consent_required, antes de cobrar.
// - pick (solo Pro): combina los dos conceptos elegidos, que tienen que ser suyos y de dominios (o categorías) distintos.
//   Una neurona que nació de una chispa no se combina con sus dos padres (paso 88): 400 invalid_request.
// - Si no hay par posible: devuelve el crédito y 409 not_enough_concepts. Si la IA falla: devuelve el crédito y 503.

import { requireDeviceIntegrity } from "../_shared/attest/guard.ts";
import { Analytics } from "../_shared/analytics.ts";
import { loadSpark } from "../_shared/data.ts";
import { ApiError, describeError, handler, json, readJson } from "../_shared/http.ts";
import { createSparkFromPair, type PickedPair, pickPair } from "../_shared/sparks.ts";
import {
  admin,
  background,
  consumeCredit,
  dbError,
  effectivePlan,
  planHasKind,
  refundCredit,
  requireAIConsent,
  requireUser,
} from "../_shared/supabase.ts";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

async function pickedPair(userId: string, ids: string[]): Promise<PickedPair | { existing: string }> {
  const { data, error } = await admin().from("concepts")
    .select("id,domain,category_id,status,embedding_model,origin_lo,origin_hi")
    .eq("user_id", userId)
    .in("id", ids);
  if (error) throw dbError(error);
  if ((data ?? []).length !== 2) throw new ApiError("not_found");
  const [a, b] = data!;
  const worldA = a.domain ?? (a.category_id ? `cat:${a.category_id}` : null);
  const worldB = b.domain ?? (b.category_id ? `cat:${b.category_id}` : null);
  if (worldA && worldA === worldB) throw new ApiError("invalid_request");
  if ([a.origin_lo, a.origin_hi].includes(b.id) || [b.origin_lo, b.origin_hi].includes(a.id)) {
    throw new ApiError("invalid_request");
  }

  const [lo, hi] = [a.id, b.id].sort();
  const { data: existing } = await admin().from("sparks").select("id")
    .eq("user_id", userId).eq("concept_lo", lo).eq("concept_hi", hi).maybeSingle();
  if (existing) return { existing: existing.id };
  return { concept_lo: lo, concept_hi: hi, distance: null, distance_percentile: null, uses_library: false, candidates_count: 1 };
}

Deno.serve(handler("spark", async (req) => {
  const user = await requireUser(req);
  await requireDeviceIntegrity(req, "spark", user.id);
  const body = await readJson<{ mode?: unknown; concept_ids?: unknown }>(req);
  const mode = body.mode;
  if (mode !== "extra" && mode !== "pick") throw new ApiError("invalid_request");
  let ids: string[] = [];
  if (mode === "pick") {
    if (!Array.isArray(body.concept_ids) || body.concept_ids.length !== 2 ||
      !body.concept_ids.every((id) => typeof id === "string" && UUID.test(id)) || body.concept_ids[0] === body.concept_ids[1]) {
      throw new ApiError("invalid_request");
    }
    ids = body.concept_ids as string[];
  }

  const plan = await effectivePlan(user.id);
  if (plan === "guest") throw new ApiError("account_required");
  if (mode === "pick" && plan !== "pro") throw new ApiError("pro_required");
  if (!(await planHasKind(plan, "spark_extra"))) throw new ApiError("pro_required");
  // Los dos conceptos van al modelo: sin el "Acepto", nada (403 ai_consent_required).
  await requireAIConsent(user.id);

  // Elegir el par antes de cobrar: un pick inválido no gasta nada.
  const picked = mode === "pick" ? await pickedPair(user.id, ids) : null;
  if (picked && "existing" in picked) {
    // Ese par ya fue chispa: se devuelve la que existe, sin cobrar.
    return json({ spark: await loadSpark(admin(), picked.existing) });
  }

  const analytics = new Analytics();
  if (!(await consumeCredit(user.id, "spark_extra"))) {
    analytics.track("quota_reached", user.id, { kind: "spark_extra", plan });
    await background(analytics.flush());
    throw new ApiError("quota_exceeded");
  }

  try {
    const pair = picked ?? await pickPair(user.id, "extra");
    if (!pair) {
      await refundCredit(user.id, "spark_extra");
      throw new ApiError("not_enough_concepts");
    }
    let created;
    try {
      created = await createSparkFromPair(user.id, pair, mode, analytics);
    } catch (error) {
      console.warn(JSON.stringify({ fn: "spark", level: "warn", error: describeError(error) }));
      await refundCredit(user.id, "spark_extra");
      throw new ApiError("ai_unavailable");
    }
    if (!created.id) {
      // Otra llamada usó el mismo par en el mismo instante.
      await refundCredit(user.id, "spark_extra");
      throw new ApiError("not_enough_concepts");
    }
    return json({ spark: await loadSpark(admin(), created.id) });
  } finally {
    await background(analytics.flush());
  }
}));
