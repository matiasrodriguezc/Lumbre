// Lectura de conceptos y chispas con la forma del contrato (Concept, Spark), embeddings y clasificación de dominio.

import { gateway } from "./ai/gateway.ts";
import { cosineSimilarity, fromPgVector, toPgVector } from "./ai/embeddings.ts";
import type { ConceptBrief } from "./ai/types.ts";
import { dbError, type SupabaseClient } from "./supabase.ts";
import { cleanText } from "./text.ts";

// ---------------------------------------------------------------
// Forma del contrato
// ---------------------------------------------------------------
const DOMAIN_COLUMNS = "slug,name_es,name_en,symbol_ios";
export const CONCEPT_COLUMNS =
  `id,title,thesis,principle,status,distilled,confidence,source_type,source_url,source_title,excerpt,from_library,origin_spark_id,created_at,` +
  `category:categories(id,name,domain:domains(${DOMAIN_COLUMNS}))`;
export const SPARK_COLUMNS =
  `id,title,body,mode,status,feedback,project_id,scheduled_for,created_at,project:projects(name),` +
  `concept_a:concepts!sparks_concept_lo_fkey(${CONCEPT_COLUMNS}),concept_b:concepts!sparks_concept_hi_fkey(${CONCEPT_COLUMNS})`;

// deno-lint-ignore no-explicit-any
type Row = Record<string, any>;

export function toSpark(row: Row) {
  const { project, ...rest } = row;
  return { ...rest, project_name: project?.name ?? null };
}

export async function loadSparks(client: SupabaseClient, filter: (q: Row) => Row) {
  const query = filter(client.from("sparks").select(SPARK_COLUMNS));
  const { data, error } = await query;
  if (error) throw dbError(error);
  return (data as Row[]).map(toSpark);
}

export async function loadSpark(client: SupabaseClient, id: string) {
  const sparks = await loadSparks(client, (q) => q.eq("id", id).limit(1));
  return sparks[0] ?? null;
}

export async function loadConcepts(client: SupabaseClient, ids: string[]) {
  if (ids.length === 0) return [];
  const { data, error } = await client.from("concepts").select(CONCEPT_COLUMNS).in("id", ids);
  if (error) throw dbError(error);
  const byId = new Map((data as Row[]).map((c) => [c.id, c]));
  return ids.map((id) => byId.get(id)).filter(Boolean);
}

export async function conceptBriefs(client: SupabaseClient, ids: string[]): Promise<Map<string, ConceptBrief>> {
  const { data, error } = await client.from("concepts").select("id,title,thesis,principle").in("id", ids);
  if (error) throw dbError(error);
  return new Map((data as ConceptBrief[]).map((c) => [c.id, c]));
}

// ---------------------------------------------------------------
// Embeddings de conceptos
// ---------------------------------------------------------------
/**
 * Con destilación se embebe principio + tesis; sin destilación, el texto limpio (plan.md §5).
 * Una neurona que nació de una chispa (paso 88) embebe su título y su cuerpo.
 */
export function conceptEmbeddingText(
  c: { title: string; thesis: string; principle: string | null; distilled?: boolean; source_type?: string },
): string {
  if (c.source_type === "spark") return cleanText(`${c.title}. ${c.thesis}`);
  if (c.principle) return cleanText(`${c.principle} ${c.thesis}`);
  return cleanText(c.thesis);
}

/** Embebe conceptos (sin embedding o con otro modelo) y los guarda. Devuelve cuántos actualizó. */
export async function embedConcepts(admin: SupabaseClient, rows: Row[], userId: string | null): Promise<number> {
  const ai = gateway();
  let done = 0;
  for (let i = 0; i < rows.length; i += 64) {
    const chunk = rows.slice(i, i + 64);
    const vectors = await ai.embed(chunk.map(conceptEmbeddingText), { feature: "embed", userId: userId ?? chunk[0]?.user_id ?? null });
    for (let j = 0; j < chunk.length; j++) {
      const { error } = await admin.from("concepts")
        .update({ embedding: toPgVector(vectors[j]), embedding_model: ai.embeddingModel })
        .eq("id", chunk[j].id);
      if (error) throw dbError(error);
      done++;
    }
  }
  return done;
}

// ---------------------------------------------------------------
// Dominios: embeddings de la lista cerrada y clasificación de categorías (paso 27)
// ---------------------------------------------------------------
let domainCache: { model: string; vectors: Array<{ slug: string; vector: number[] }> } | null = null;

/** Embebe los dominios que no tienen vector (o tienen el de otro modelo) y devuelve todos. */
export async function domainVectors(admin: SupabaseClient): Promise<Array<{ slug: string; vector: number[] }>> {
  const ai = gateway();
  if (domainCache?.model === ai.embeddingModel) return domainCache.vectors;
  const { data, error } = await admin.from("domains").select("slug,name_es,name_en,description,embedding,embedding_model");
  if (error) throw dbError(error);
  const rows = data as Row[];
  const stale = rows.filter((d) => !d.embedding || d.embedding_model !== ai.embeddingModel);
  if (stale.length) {
    const vectors = await ai.embed(stale.map((d) => `${d.name_es}. ${d.name_en}. ${d.description}`), { feature: "embed", userId: null });
    for (let i = 0; i < stale.length; i++) {
      const { error: updateError } = await admin.from("domains")
        .update({ embedding: toPgVector(vectors[i]), embedding_model: ai.embeddingModel })
        .eq("slug", stale[i].slug);
      if (updateError) throw dbError(updateError);
      stale[i].embedding = vectors[i];
    }
  }
  const vectors = rows.map((d) => ({ slug: d.slug as string, vector: fromPgVector(d.embedding) }));
  domainCache = { model: ai.embeddingModel, vectors };
  return vectors;
}

function nearestDomain(vector: number[], domains: Array<{ slug: string; vector: number[] }>): string | null {
  let best: string | null = null;
  let bestScore = -Infinity;
  for (const domain of domains) {
    const score = cosineSimilarity(vector, domain.vector);
    if (score > bestScore) {
      bestScore = score;
      best = domain.slug;
    }
  }
  return best;
}

/**
 * Clasifica una categoría sin dominio por el embedding de su nombre y de sus conceptos,
 * y se lo pasa a sus conceptos que todavía no tienen. Devuelve el dominio asignado.
 */
export async function classifyCategory(admin: SupabaseClient, categoryId: string, userId: string | null): Promise<string | null> {
  const ai = gateway();
  const { data: category, error } = await admin.from("categories").select("id,name,domain").eq("id", categoryId).maybeSingle();
  if (error) throw dbError(error);
  if (!category) return null;
  if (category.domain) return category.domain;

  const { data: concepts, error: conceptsError } = await admin.from("concepts")
    .select("embedding,embedding_model")
    .eq("category_id", categoryId)
    .not("embedding", "is", null)
    .order("created_at", { ascending: false })
    .limit(20);
  if (conceptsError) throw dbError(conceptsError);

  const [nameVector] = await ai.embed([category.name], { feature: "classify", userId });
  const vector = [...nameVector];
  const same = (concepts as Row[]).filter((c) => c.embedding_model === ai.embeddingModel).map((c) => fromPgVector(c.embedding));
  if (same.length) {
    // El nombre pesa 60% y el promedio de sus conceptos 40%.
    for (let i = 0; i < vector.length; i++) {
      const mean = same.reduce((sum, v) => sum + v[i], 0) / same.length;
      vector[i] = 0.6 * vector[i] + 0.4 * mean;
    }
  }
  const domain = nearestDomain(vector, await domainVectors(admin));
  if (!domain) return null;

  const { error: updateError } = await admin.from("categories").update({ domain }).eq("id", categoryId).is("domain", null);
  if (updateError) throw dbError(updateError);
  const { error: conceptsUpdateError } = await admin.from("concepts").update({ domain }).eq("category_id", categoryId).is("domain", null);
  if (conceptsUpdateError) throw dbError(conceptsUpdateError);
  return domain;
}
