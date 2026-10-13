// POST /revenuecat-webhook — webhook de RevenueCat, entitlement "pro" (paso 36).
//
// - Autorización: el valor configurado en RevenueCat como Authorization header (REVENUECAT_WEBHOOK_SECRET),
//   con o sin "Bearer ". Sin secreto configurado, rechaza todo.
// - Idempotente: cada evento se guarda una sola vez por id en subscription_events; un reintento no hace nada.
// - Pasa a pro con INITIAL_PURCHASE, RENEWAL, UNCANCELLATION, PRODUCT_CHANGE y TRANSFER; vuelve a free con EXPIRATION.
//   CANCELLATION y BILLING_ISSUE no cambian el plan hasta que vence.
// - app_user_id es el id del usuario de Supabase (la app hace logIn en RevenueCat con ese id).

import { errorResponse, handler, json, readJson } from "../_shared/http.ts";
import { admin, dbError, timingSafeEqual } from "../_shared/supabase.ts";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const TO_PRO = new Set(["INITIAL_PURCHASE", "RENEWAL", "UNCANCELLATION", "PRODUCT_CHANGE"]);
const ENTITLEMENT = "pro";

interface RevenueCatEvent {
  id?: string;
  type?: string;
  app_user_id?: string;
  original_app_user_id?: string;
  entitlement_ids?: string[] | null;
  transferred_from?: string[];
  transferred_to?: string[];
}

function authorized(req: Request): boolean {
  const secret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");
  if (!secret) return false;
  const header = (req.headers.get("Authorization") ?? "").trim();
  const value = header.replace(/^Bearer\s+/i, "");
  return timingSafeEqual(value, secret) || timingSafeEqual(header, secret);
}

async function setPlan(userId: string | undefined, plan: "free" | "pro"): Promise<boolean> {
  if (!userId || !UUID.test(userId)) return false;
  const { data, error } = await admin().from("profiles").update({ plan }).eq("id", userId).select("id");
  if (error) throw dbError(error);
  return (data ?? []).length > 0;
}

Deno.serve(handler("revenuecat-webhook", async (req) => {
  if (!authorized(req)) return errorResponse("not_authenticated");
  const body = await readJson<{ event?: RevenueCatEvent }>(req);
  const event = body.event;
  if (!event?.id || !event.type) return json({ status: "ignored" });

  const { data: inserted, error } = await admin().from("subscription_events")
    .upsert({ id: event.id, type: event.type, app_user_id: event.app_user_id ?? null }, { onConflict: "id", ignoreDuplicates: true })
    .select("id");
  if (error) throw dbError(error);
  if (!inserted?.length) return json({ status: "duplicate" });

  // Eventos de otros entitlements no tocan el plan.
  if (event.entitlement_ids && !event.entitlement_ids.includes(ENTITLEMENT) && event.type !== "TRANSFER") {
    return json({ status: "ignored" });
  }

  let planAfter: "free" | "pro" | null = null;
  if (TO_PRO.has(event.type)) {
    if (await setPlan(event.app_user_id, "pro")) planAfter = "pro";
  } else if (event.type === "EXPIRATION") {
    if (await setPlan(event.app_user_id, "free")) planAfter = "free";
  } else if (event.type === "TRANSFER") {
    // La suscripción pasa de unos ids a otros (por ejemplo, al restaurar compras con otra cuenta).
    for (const id of event.transferred_from ?? []) await setPlan(id, "free");
    for (const id of event.transferred_to ?? []) if (await setPlan(id, "pro")) planAfter = "pro";
  }

  if (planAfter) await admin().from("subscription_events").update({ plan_after: planAfter }).eq("id", event.id);
  console.log(JSON.stringify({ fn: "revenuecat-webhook", type: event.type, plan_after: planAfter }));
  return json({ status: "processed", plan: planAfter });
}));
