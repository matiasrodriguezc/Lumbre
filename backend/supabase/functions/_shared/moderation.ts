// Moderación de entrada y salida (plan.md §5, paso 33).
//
// Hoy es una heurística local y barata: frases que piden daño grave o contenido sexual con menores.
// La interfaz es la misma que tendría un clasificador real (async, con categorías), así se puede
// cambiar por un modelo sin tocar las funciones. Nunca loguea el texto: solo la categoría.

import { foldText } from "./text.ts";

export type ModerationCategory = "violence" | "weapons" | "self_harm" | "sexual_minors" | "hate";

export interface ModerationResult {
  flagged: boolean;
  categories: ModerationCategory[];
}

// Patrones sobre el texto en minúscula y sin acentos. Son deliberadamente estrechos: una app de ideas
// recibe textos sobre guerras, enfermedades o drogas como tema, y eso no se bloquea.
const PATTERNS: Array<[ModerationCategory, RegExp]> = [
  ["weapons", /\b(como|how to)\s+(fabricar|hacer|armar|construir|build|make)\s+(una\s+|a\s+|an\s+)?(bomba|explosivo|arma quimica|bomb|explosive|nerve agent|pipe bomb)/],
  ["weapons", /\b(sintetizar|synthesize)\s+(sarin|vx|ricina|ricin|anthrax|antrax)\b/],
  ["violence", /\b(como|how to)\s+(matar|asesinar|kill|murder)\s+(a\s+)?(mi|una|un|alguien|someone|my|a)\b/],
  ["self_harm", /\b(como|how to)\s+(suicidarme|matarme|kill myself|commit suicide)\b/],
  ["sexual_minors", /\b(sexo|sexual|porno|desnud[oa]s?|nude|porn)\b.{0,40}\b(menor(es)?|niñ[oa]s?|nin[oa]s?|child(ren)?|minor)\b|\b(menor(es)?|niñ[oa]s?|nin[oa]s?|child(ren)?|minor)\b.{0,40}\b(sexo|sexual|porno|desnud[oa]s?|nude|porn)\b/],
  ["hate", /\b(exterminar|exterminate)\s+(a\s+)?(los|las|all)\s+\w+/],
];

export async function moderate(text: string): Promise<ModerationResult> {
  const folded = foldText(text);
  const categories = [...new Set(PATTERNS.filter(([, re]) => re.test(folded)).map(([c]) => c))];
  return await Promise.resolve({ flagged: categories.length > 0, categories });
}

export function logModeration(fn: string, direction: "input" | "output", result: ModerationResult): void {
  if (!result.flagged) return;
  console.warn(JSON.stringify({ fn, level: "warn", moderation: direction, categories: result.categories }));
}
