// POST /daily-sparks — interna: batch nocturno de chispas diarias por zona horaria (paso 32).
//
// Cada 15 minutos busca a los usuarios cuyo día local ya empezó y no tienen chispa diaria (ni un batch en curso).
// - Proveedor local: par + texto en el momento.
// - Anthropic: elige y reserva el par (spark_jobs + last_used_at) y manda todo en un batch de la Batches API (50% menos).
// Con { collect: true } (cada 10 minutos) levanta los resultados de los batches terminados y crea las chispas.
// Si un resultado falla, usa la plantilla local: Hoy nunca queda vacía.
// Los invitados también reciben su diaria: no consume cupos (tampoco de IA del usuario).
// Quien no aceptó mandar su contenido a la IA (profiles.ai_consent_at null) no entra: lo filtra users_needing_daily_spark().

import { Analytics } from "../_shared/analytics.ts";
import { gateway } from "../_shared/ai/gateway.ts";
import { SPARK_VERSION } from "../_shared/ai/prompts/spark.v1.ts";
import { localSpark } from "../_shared/ai/providers/local.ts";
import { checkSparkJson, sparkBatchItem } from "../_shared/ai/tasks.ts";
import type { BatchItem } from "../_shared/ai/types.ts";
import { conceptBriefs } from "../_shared/data.ts";
import { describeError, handler, json, readJson } from "../_shared/http.ts";
import { creativeProfiles, generateSpark, pickPair } from "../_shared/sparks.ts";
import { admin, dbError, requireService, rpc } from "../_shared/supabase.ts";

const USERS_PER_RUN = 200;

interface Job {
  id: string;
  user_id: string;
  scheduled_for: string;
  concept_lo: string;
  concept_hi: string;
  distance: number | null;
  distance_percentile: number | null;
  uses_library: boolean;
  batch_id: string | null;
}

async function createFromJob(job: Job, title: string, body: string, analytics: Analytics) {
  const id = await rpc<string | null>(admin(), "create_spark", {
    p_user: job.user_id,
    p_concept_a: job.concept_lo,
    p_concept_b: job.concept_hi,
    p_mode: "daily",
    p_title: title,
    p_body: body,
    p_distance: job.distance,
    p_distance_percentile: job.distance_percentile,
    p_uses_library: job.uses_library,
    p_scheduled_for: job.scheduled_for,
    p_status: "pending",
  });
  if (id) {
    analytics.track("spark_generated", job.user_id, {
      mode: "daily", batch: true, distance_percentile: job.distance_percentile, uses_library_concept: job.uses_library,
    });
  }
  return id;
}

async function collect(analytics: Analytics) {
  const ai = gateway();
  const summary = { batches: 0, created: 0, fallback: 0 };
  if (!ai.supportsBatch) return summary;

  const { data: jobs, error } = await admin().from("spark_jobs").select("*").eq("status", "submitted");
  if (error) throw dbError(error);
  const byBatch = new Map<string, Job[]>();
  for (const job of (jobs ?? []) as Job[]) byBatch.set(job.batch_id!, [...(byBatch.get(job.batch_id!) ?? []), job]);

  for (const [batchId, batchJobs] of byBatch) {
    if (!(await ai.batchEnded(batchId))) continue;
    summary.batches++;
    const jobsById = new Map(batchJobs.map((j) => [j.id, j]));
    const seen = new Set<string>();
    for await (const result of ai.batchResults(batchId, (customId) => ({
      feature: "spark", userId: jobsById.get(customId)?.user_id ?? null, promptVersion: SPARK_VERSION, tier: "fast",
    }))) {
      const job = jobsById.get(result.customId);
      if (!job) continue;
      seen.add(job.id);
      const briefs = await conceptBriefs(admin(), [job.concept_lo, job.concept_hi]);
      const a = briefs.get(job.concept_lo), b = briefs.get(job.concept_hi);
      if (!a || !b) {
        await admin().from("spark_jobs").update({ status: "failed", updated_at: new Date().toISOString() }).eq("id", job.id);
        continue;
      }
      let text: { title: string; body: string };
      try {
        if (result.error) throw new Error(result.error);
        text = await checkSparkJson(result.json, a, b);
      } catch {
        text = localSpark(a, b);
        summary.fallback++;
      }
      if (await createFromJob(job, text.title, text.body, analytics)) summary.created++;
      await admin().from("spark_jobs").update({ status: "done", updated_at: new Date().toISOString() }).eq("id", job.id);
    }
    // Lo que el batch no devolvió (no debería pasar) se resuelve con la plantilla local.
    for (const job of batchJobs.filter((j) => !seen.has(j.id))) {
      const briefs = await conceptBriefs(admin(), [job.concept_lo, job.concept_hi]);
      const a = briefs.get(job.concept_lo), b = briefs.get(job.concept_hi);
      if (a && b) {
        const text = localSpark(a, b);
        if (await createFromJob(job, text.title, text.body, analytics)) summary.created++;
        summary.fallback++;
      }
      await admin().from("spark_jobs").update({ status: "done", updated_at: new Date().toISOString() }).eq("id", job.id);
    }
  }
  return summary;
}

async function generate(analytics: Analytics) {
  const ai = gateway();
  const users = await rpc<Array<{ user_id: string; local_date: string }>>(admin(), "users_needing_daily_spark", { p_limit: USERS_PER_RUN });
  const summary = { users: users.length, created: 0, queued: 0, skipped: 0, errors: 0 };

  if (!ai.supportsBatch) {
    for (const { user_id, local_date } of users) {
      try {
        const created = await generateSpark(user_id, "daily", analytics, { scheduledFor: local_date });
        if (created?.id) summary.created++;
        else summary.skipped++;
      } catch (error) {
        summary.errors++;
        console.error(JSON.stringify({ fn: "daily-sparks", level: "error", error: describeError(error) }));
      }
    }
    return summary;
  }

  // Anthropic: elegir y reservar los pares, y mandar un solo batch.
  const items: BatchItem[] = [];
  const jobIds: string[] = [];
  for (const { user_id, local_date } of users) {
    try {
      const pair = await pickPair(user_id, "daily");
      if (!pair) {
        summary.skipped++;
        continue;
      }
      const { data: job, error } = await admin().from("spark_jobs").insert({
        user_id, scheduled_for: local_date, concept_lo: pair.concept_lo, concept_hi: pair.concept_hi,
        distance: pair.distance, distance_percentile: pair.distance_percentile, uses_library: pair.uses_library,
      }).select("id").single();
      if (error) {
        summary.skipped++;
        continue;
      }
      // Reserva: el descanso de 3 días corre desde ahora, aunque la chispa se cree al levantar el batch.
      await admin().from("concepts").update({ last_used_at: new Date().toISOString() }).in("id", [pair.concept_lo, pair.concept_hi]);
      const briefs = await conceptBriefs(admin(), [pair.concept_lo, pair.concept_hi]);
      items.push(sparkBatchItem(job.id, briefs.get(pair.concept_lo)!, briefs.get(pair.concept_hi)!, await creativeProfiles(user_id), user_id));
      jobIds.push(job.id);
    } catch (error) {
      summary.errors++;
      console.error(JSON.stringify({ fn: "daily-sparks", level: "error", error: describeError(error) }));
    }
  }
  if (items.length === 0) return summary;

  try {
    const batchId = await ai.submitBatch(items, "fast");
    await admin().from("spark_jobs").update({ batch_id: batchId, status: "submitted", updated_at: new Date().toISOString() }).in("id", jobIds);
    summary.queued = items.length;
  } catch (error) {
    // Sin batch, la diaria sale igual con la plantilla local.
    console.error(JSON.stringify({ fn: "daily-sparks", level: "error", batch: "submit_failed", error: describeError(error) }));
    const { data: jobs } = await admin().from("spark_jobs").select("*").in("id", jobIds);
    for (const job of (jobs ?? []) as Job[]) {
      const briefs = await conceptBriefs(admin(), [job.concept_lo, job.concept_hi]);
      const text = localSpark(briefs.get(job.concept_lo)!, briefs.get(job.concept_hi)!);
      if (await createFromJob(job, text.title, text.body, analytics)) summary.created++;
      await admin().from("spark_jobs").update({ status: "done", updated_at: new Date().toISOString() }).eq("id", job.id);
    }
  }
  return summary;
}

Deno.serve(handler("daily-sparks", async (req) => {
  requireService(req);
  const body = await readJson<{ collect?: unknown }>(req);
  const analytics = new Analytics();
  try {
    const result = body.collect === true ? { collect: await collect(analytics) } : { generate: await generate(analytics) };
    console.log(JSON.stringify({ fn: "daily-sparks", ...result }));
    return json(result);
  } finally {
    await analytics.flush();
  }
}));
