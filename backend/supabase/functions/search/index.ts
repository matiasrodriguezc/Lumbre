// POST /search — búsqueda semántica en la bóveda (por idea, no por palabra).
// Embebe la consulta con el mismo modelo que los conceptos y busca con match_concepts() y el JWT del usuario:
// RLS deja solo sus conceptos. La consulta no se loguea ni va a analytics.

import { requireDeviceIntegrity } from "../_shared/attest/guard.ts";
import { gateway } from "../_shared/ai/gateway.ts";
import { toPgVector } from "../_shared/ai/embeddings.ts";
import { CONCEPT_COLUMNS } from "../_shared/data.ts";
import { ApiError, handler, json, readJson } from "../_shared/http.ts";
import { admin, dbError, requireUser, rpc } from "../_shared/supabase.ts";
import { cleanText } from "../_shared/text.ts";

const SEARCH_PER_HOUR = Number(Deno.env.get("LUMBRE_SEARCH_PER_HOUR") ?? 120);

Deno.serve(handler("search", async (req) => {
  const user = await requireUser(req);
  await requireDeviceIntegrity(req, "search", user.id);
  const body = await readJson<{ query?: unknown; limit?: unknown }>(req);
  if (typeof body.query !== "string" || !body.query.trim() || body.query.length > 200) throw new ApiError("invalid_request");
  const limit = body.limit === undefined ? 30 : Number(body.limit);
  if (!Number.isInteger(limit) || limit < 1) throw new ApiError("invalid_request");

  // Cada búsqueda embebe la consulta: tope anti-abuso por usuario (provisorio, 120 por hora; LUMBRE_SEARCH_PER_HOUR).
  const allowed = await rpc<boolean>(admin(), "hit_rate_limit", { p_key: `search:${user.id}`, p_max: SEARCH_PER_HOUR, p_window_seconds: 3600 });
  if (!allowed) throw new ApiError("rate_limited");

  const query = cleanText(body.query, 60) || body.query.trim();
  const [vector] = await gateway().embed([query], { feature: "search", userId: user.id, inputType: "query" });

  const { data, error } = await user.client
    .rpc("match_concepts", { p_query_embedding: toPgVector(vector), p_match_count: Math.min(limit, 50) })
    .select(CONCEPT_COLUMNS);
  if (error) throw dbError(error);
  return json({ concepts: data ?? [] });
}));
