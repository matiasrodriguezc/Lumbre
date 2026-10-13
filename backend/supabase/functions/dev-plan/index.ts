// POST /dev-plan — solo desarrollo local: cambia el plan del usuario sin pasar por la tienda.
// Responde 404 salvo con LUMBRE_DEV_TOOLS=true (en supabase/functions/.env, que no va al repo).
// Un invitado tiene plan guest por su sesión anónima: primero tiene que crear la cuenta (403 account_required).

import { ApiError, errorResponse, handler, json, readJson } from "../_shared/http.ts";
import { admin, dbError, requireUser } from "../_shared/supabase.ts";

Deno.serve(handler("dev-plan", async (req) => {
  if (Deno.env.get("LUMBRE_DEV_TOOLS") !== "true") return errorResponse("not_found");
  const user = await requireUser(req);
  const body = await readJson<{ plan?: unknown }>(req);
  if (body.plan !== "free" && body.plan !== "pro") throw new ApiError("invalid_request");
  if (user.isAnonymous) throw new ApiError("account_required");

  const { error } = await admin().from("profiles").update({ plan: body.plan }).eq("id", user.id);
  if (error) throw dbError(error);
  return json({ plan: body.plan });
}));
