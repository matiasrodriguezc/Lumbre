// POST /process — interna (pg_cron cada 5 minutos, con la clave de servicio).
//
// 1. Embebe los dominios y la biblioteca de conceptos invitados que no tengan vector del modelo actual.
// 2. Embebe los conceptos pendientes (sin vector, o con el de otro modelo: re-embebido gradual si se cambia de modelo).
// 3. Clasifica en un dominio las categorías que todavía no tienen y se lo pasa a sus conceptos.
// 4. Manda los eventos de la bandeja de analytics (los que dejan los triggers de la base).
// 5. Borra los adjuntos de capture-temp de más de una hora (subidos sin captura): nada queda guardado (plan.md §6).
// Procesa por tandas: lo que no entra en una corrida queda para la siguiente.

import { Analytics } from "../_shared/analytics.ts";
import { gateway } from "../_shared/ai/gateway.ts";
import { toPgVector } from "../_shared/ai/embeddings.ts";
import { classifyCategory, conceptEmbeddingText, domainVectors, embedConcepts } from "../_shared/data.ts";
import { describeError, handler, json } from "../_shared/http.ts";
import { admin, dbError, requireService, rpc } from "../_shared/supabase.ts";

const BATCH = 200;

Deno.serve(handler("process", async (req) => {
  requireService(req);
  const db = admin();
  const ai = gateway();
  const model = ai.embeddingModel;
  const result = { domains: 0, library: 0, concepts: 0, categories: 0, events: 0, stale_uploads: 0, errors: 0 };

  // 1. Dominios y biblioteca
  result.domains = (await domainVectors(db)).length;
  const { data: library, error: libraryError } = await db.from("library_concepts")
    .select("id,title,thesis,principle")
    .or(`embedding.is.null,embedding_model.neq."${model}"`)
    .limit(BATCH);
  if (libraryError) throw dbError(libraryError);
  if (library?.length) {
    const vectors = await ai.embed(library.map((c) => conceptEmbeddingText(c)), { feature: "embed", userId: null });
    for (let i = 0; i < library.length; i++) {
      const { error } = await db.from("library_concepts")
        .update({ embedding: toPgVector(vectors[i]), embedding_model: model }).eq("id", library[i].id);
      if (error) throw dbError(error);
    }
    result.library = library.length;
  }

  // 2. Conceptos pendientes, agrupados por usuario para registrar el costo de cada uno
  const { data: pending, error: pendingError } = await db.from("concepts")
    .select("id,user_id,title,thesis,principle,distilled")
    .or(`embedding.is.null,embedding_model.neq."${model}"`)
    .order("created_at")
    .limit(BATCH);
  if (pendingError) throw dbError(pendingError);
  const byUser = new Map<string, typeof pending>();
  for (const row of pending ?? []) byUser.set(row.user_id, [...(byUser.get(row.user_id) ?? []), row]);
  for (const [userId, rows] of byUser) {
    try {
      result.concepts += await embedConcepts(db, rows!, userId);
    } catch (error) {
      result.errors++;
      console.error(JSON.stringify({ fn: "process", level: "error", step: "embed", error: describeError(error) }));
    }
  }

  // 3. Categorías sin dominio que ya tienen conceptos
  const { data: categories, error: categoriesError } = await db.from("categories")
    .select("id,user_id,concepts!inner(id)")
    .is("domain", null)
    .limit(100);
  if (categoriesError) throw dbError(categoriesError);
  for (const category of categories ?? []) {
    try {
      if (await classifyCategory(db, category.id, category.user_id)) result.categories++;
    } catch (error) {
      result.errors++;
      console.error(JSON.stringify({ fn: "process", level: "error", step: "classify", error: describeError(error) }));
    }
  }

  // 4. Bandeja de analytics
  const { data: events, error: eventsError } = await db.from("analytics_outbox")
    .select("id,distinct_id,event,properties,created_at").order("id").limit(500);
  if (eventsError) throw dbError(eventsError);
  if (events?.length) {
    const analytics = new Analytics();
    for (const e of events) analytics.track(e.event, e.distinct_id, e.properties, e.created_at);
    const sent = await analytics.flush();
    if (sent === events.length) {
      const { error } = await db.from("analytics_outbox").delete().lte("id", events[events.length - 1].id);
      if (error) throw dbError(error);
      result.events = sent;
    }
  }

  // 5. Adjuntos temporales huérfanos
  try {
    const stale = await rpc<string[]>(db, "stale_capture_uploads", {});
    if (stale.length) {
      const { error } = await db.storage.from("capture-temp").remove(stale);
      if (error) throw new Error(error.message);
      result.stale_uploads = stale.length;
    }
  } catch (error) {
    result.errors++;
    console.error(JSON.stringify({ fn: "process", level: "error", step: "stale_uploads", error: describeError(error) }));
  }

  console.log(JSON.stringify({ fn: "process", ...result }));
  return json(result);
}));
