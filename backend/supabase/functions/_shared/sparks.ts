// Generar una chispa: elegir el par (SQL), escribir el texto (IA) y guardarla.
// Lo usan Hoy (si falta la diaria), la chispa extra y el batch nocturno con el proveedor local.

import type { Analytics } from "./analytics.ts";
import { writeSpark } from "./ai/tasks.ts";
import { conceptBriefs } from "./data.ts";
import { admin, rpc } from "./supabase.ts";
import { asPromptData } from "./text.ts";

export interface PickedPair {
  concept_lo: string;
  concept_hi: string;
  distance: number | null;
  distance_percentile: number | null;
  uses_library: boolean;
  candidates_count: number;
}

export async function pickPair(userId: string, mode: "daily" | "extra"): Promise<PickedPair | null> {
  const rows = await rpc<PickedPair[]>(admin(), "pick_spark_pair", { p_user: userId, p_exclude_daily: mode !== "daily" });
  return rows[0] ?? null;
}

/** Los perfiles creativos y, si lo escribió, el rol propio (va como un perfil más, delimitado como dato). */
export async function creativeProfiles(userId: string): Promise<string[]> {
  const { data } = await admin().from("profiles").select("creative_profiles, creative_role").eq("id", userId).maybeSingle();
  const profiles = (data?.creative_profiles as string[] | undefined) ?? [];
  const role = (data?.creative_role as string | null | undefined)?.trim();
  return role ? [...profiles, `rol propio «${asPromptData(role.slice(0, 200))}»`] : profiles;
}

export interface CreatedSpark {
  id: string | null;
  pair: PickedPair;
}

/**
 * Crea una chispa con un par ya elegido. Devuelve id null si otra llamada ganó la carrera
 * (la diaria ya existe o el par ya es chispa).
 * - daily: si la IA falla, usa la plantilla local (Hoy nunca queda vacía).
 * - extra / pick: si la IA falla, el error sube y la función devuelve el crédito.
 */
export async function createSparkFromPair(
  userId: string,
  pair: PickedPair,
  mode: "daily" | "extra" | "pick",
  analytics: Analytics,
  opts: { scheduledFor?: string | null; batch?: boolean } = {},
): Promise<CreatedSpark> {
  const briefs = await conceptBriefs(admin(), [pair.concept_lo, pair.concept_hi]);
  const a = briefs.get(pair.concept_lo)!;
  const b = briefs.get(pair.concept_hi)!;
  const text = await writeSpark(a, b, await creativeProfiles(userId), userId, { localFallback: mode === "daily" });
  const id = await rpc<string | null>(admin(), "create_spark", {
    p_user: userId,
    p_concept_a: pair.concept_lo,
    p_concept_b: pair.concept_hi,
    p_mode: mode,
    p_title: text.title,
    p_body: text.body,
    p_distance: pair.distance,
    p_distance_percentile: pair.distance_percentile,
    p_uses_library: pair.uses_library,
    p_scheduled_for: mode === "daily" ? opts.scheduledFor ?? null : null,
    p_status: "pending",
  });
  if (id) {
    analytics.track("spark_generated", userId, {
      mode,
      batch: opts.batch ?? false,
      distance_percentile: pair.distance_percentile,
      uses_library_concept: pair.uses_library,
      candidates_count: pair.candidates_count,
    });
  }
  return { id, pair };
}

/** Par + texto + guardado. Null si el usuario no tiene material para una chispa. */
export async function generateSpark(
  userId: string,
  mode: "daily" | "extra",
  analytics: Analytics,
  opts: { scheduledFor?: string | null } = {},
): Promise<CreatedSpark | null> {
  const pair = await pickPair(userId, mode);
  if (!pair) return null;
  return await createSparkFromPair(userId, pair, mode, analytics, opts);
}
