// POST /search — búsqueda semántica en la bóveda (por idea, no por palabra).
// Embebe la consulta con el mismo modelo que los conceptos y busca con match_concepts() y el JWT del usuario:
// RLS deja solo sus conceptos. La consulta no se loguea ni va a analytics.

import { gateway } from "../_shared/ai/gateway.ts";
import { toPgVector } from "../_shared/ai/embeddings.ts";
import { CONCEPT_COLUMNS } from "../_shared/data.ts";
import { ApiError, handler, json, readJson } from "../_shared/http.ts";
import { dbError, requireUser } from "../_shared/supabase.ts";
import { cleanText } from "../_shared/text.ts";

Deno.serve(handler("search", async (req) => {
  const user = await requireUser(req);
  const body = await readJson<{ query?: unknown; limit?: unknown }>(req);
  if (typeof body.query !== "string" || !body.query.trim() || body.query.length > 200) throw new ApiError("invalid_request");
  const limit = body.limit === undefined ? 30 : Number(body.limit);
  if (!Number.isInteger(limit) || limit < 1) throw new ApiError("invalid_request");

  const query = cleanText(body.query, 60) || body.query.trim();
  const [vector] = await gateway().embed([query], { feature: "search", userId: user.id, inputType: "query" });

  const { data, error } = await user.client
    .rpc("match_concepts", { p_query_embedding: toPgVector(vector), p_match_count: Math.min(limit, 50) })
    .select(CONCEPT_COLUMNS);
  if (error) throw dbError(error);
  return json({ concepts: data ?? [] });
}));
