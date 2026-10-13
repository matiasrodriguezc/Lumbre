// Embeddings: siempre en el servidor y con un único modelo para todo (plan.md §5).
// El nombre del modelo se guarda junto al vector: si se cambia, /process re-embebe lo que tenga otro modelo.
//
// - local (default): hashing de palabras normalizadas (sin acentos, minúsculas, sin palabras vacías),
//   de su raíz aproximada y de trigramas de caracteres, a 1024 dimensiones con norma 1.
//   Textos que comparten palabras o raíces quedan cerca; no entiende sinónimos ni otros idiomas.
// - voyage (con VOYAGE_API_KEY): voyage-3.5, multilingüe, 1024 dimensiones.
// El modelo definitivo es una decisión pendiente (paso 22).

import { fnv1a, foldText } from "../text.ts";
import { AIError } from "./types.ts";

export const EMBEDDING_DIMENSIONS = 1024;
export const LOCAL_EMBEDDING_MODEL = "lumbre-local-hash-v1";

export type InputType = "document" | "query";

export interface EmbeddingProvider {
  readonly model: string;
  embed(texts: string[], inputType: InputType): Promise<{ vectors: number[][]; tokens: number }>;
}

const STOPWORDS = new Set(
  ("a al algo algun alguna algunas alguno algunos ante antes aqui asi aun cada como con contra cual cuando de del " +
    "desde donde dos el ella ellas ellos en entre era es esa esas ese eso esos esta estan estas este esto estos fue " +
    "ha hace hay la las le les lo los mas me mi mientras muy nada ni no nos o otra otras otro otros para pero poco por " +
    "porque que se sea segun ser si sin sobre solo son su sus tambien tan te tiene tienen todo todos tu un una uno unos " +
    "y ya the of and to in is it that for on with as are be by an or this from at").split(" "),
);

function addFeature(vector: Float64Array, feature: string, weight: number) {
  const hash = fnv1a(feature);
  const index = hash % EMBEDDING_DIMENSIONS;
  const sign = (fnv1a(feature, 0x9747b28c) & 1) === 0 ? 1 : -1;
  vector[index] += sign * weight;
}

export function localEmbedding(text: string): number[] {
  const vector = new Float64Array(EMBEDDING_DIMENSIONS);
  const tokens = foldText(text).split(/[^\p{L}\p{N}]+/u).filter((t) => t.length > 1 && !STOPWORDS.has(t));
  for (const token of tokens) {
    addFeature(vector, `w:${token}`, 1);
    // Raíz aproximada: "economia", "economico" y "economias" comparten "econo".
    if (token.length > 5) addFeature(vector, `s:${token.slice(0, 5)}`, 0.7);
    const padded = `^${token}$`;
    for (let i = 0; i + 3 <= padded.length; i++) addFeature(vector, `t:${padded.slice(i, i + 3)}`, 0.25);
  }
  let norm = 0;
  for (const value of vector) norm += value * value;
  norm = Math.sqrt(norm);
  if (norm === 0) {
    // Texto sin palabras útiles: un vector fijo, para no romper la norma.
    vector[0] = 1;
    norm = 1;
  }
  return Array.from(vector, (value) => Number((value / norm).toFixed(6)));
}

export class LocalEmbeddings implements EmbeddingProvider {
  readonly model = LOCAL_EMBEDDING_MODEL;
  embed(texts: string[]) {
    const tokens = texts.reduce((sum, t) => sum + Math.ceil(t.length / 4), 0);
    return Promise.resolve({ vectors: texts.map(localEmbedding), tokens });
  }
}

export class VoyageEmbeddings implements EmbeddingProvider {
  readonly model: string;
  constructor(private apiKey: string, model = "voyage-3.5") {
    this.model = model;
  }

  async embed(texts: string[], inputType: InputType) {
    const response = await fetch("https://api.voyageai.com/v1/embeddings", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${this.apiKey}` },
      body: JSON.stringify({ input: texts, model: this.model, input_type: inputType, output_dimension: EMBEDDING_DIMENSIONS }),
      signal: AbortSignal.timeout(20_000),
    });
    if (!response.ok) {
      await response.body?.cancel();
      throw new AIError(response.status === 429 || response.status >= 500 ? "retryable" : "fatal", `voyage ${response.status}`);
    }
    const body = await response.json() as { data: Array<{ embedding: number[]; index: number }>; usage?: { total_tokens?: number } };
    const vectors = body.data.sort((a, b) => a.index - b.index).map((d) => d.embedding);
    return { vectors, tokens: body.usage?.total_tokens ?? 0 };
  }
}

export function embeddingProvider(): EmbeddingProvider {
  const choice = Deno.env.get("LUMBRE_EMBEDDINGS");
  const voyageKey = Deno.env.get("VOYAGE_API_KEY");
  if (choice !== "local" && voyageKey) return new VoyageEmbeddings(voyageKey, Deno.env.get("LUMBRE_EMBEDDING_MODEL") ?? "voyage-3.5");
  return new LocalEmbeddings();
}

/** Formato de pgvector: "[0.1,0.2,…]". */
export function toPgVector(vector: number[]): string {
  return `[${vector.join(",")}]`;
}

export function fromPgVector(value: string | number[]): number[] {
  return Array.isArray(value) ? value : JSON.parse(value);
}

export function cosineSimilarity(a: number[], b: number[]): number {
  let dot = 0, na = 0, nb = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  return na && nb ? dot / Math.sqrt(na * nb) : 0;
}
