// Limpieza de texto antes de embeber o destilar (plan.md §5):
// sin emojis, sin URLs sueltas, sin espacios de más y cortado a unas 500 palabras.

const EMOJI = /[\p{Extended_Pictographic}\p{Emoji_Modifier}\u{FE0F}\u{200D}\u{20E3}]/gu;
const URL = /\b(?:https?:\/\/|www\.)[^\s<>()]+/giu;

export function cleanText(input: string, maxWords = 500): string {
  const text = input
    .normalize("NFC")
    .replace(EMOJI, " ")
    .replace(URL, " ")
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  return truncateWords(text, maxWords);
}

export function truncateWords(text: string, maxWords: number): string {
  const words = text.split(/\s+/).filter(Boolean);
  return words.length <= maxWords ? words.join(" ") : words.slice(0, maxWords).join(" ");
}

export function wordCount(text: string | null | undefined): number {
  return (text ?? "").split(/\s+/).filter(Boolean).length;
}

/** Minúsculas y sin acentos: para comparar y para el embedding local. */
export function foldText(text: string): string {
  return text.normalize("NFD").replace(/\p{Diacritic}/gu, "").toLowerCase();
}

/** Primera oración (hasta . ! ? o salto de línea), o el texto entero si no hay. */
export function firstSentence(text: string): string {
  const clean = text.replace(/\s+/g, " ").trim();
  const match = clean.match(/^(.{20,}?[.!?])(\s|$)/u);
  return (match ? match[1] : clean).trim();
}

/** Corta a n caracteres en un límite de palabra, con … si cortó. */
export function clip(text: string, max: number): string {
  const clean = text.replace(/\s+/g, " ").trim();
  if (clean.length <= max) return clean;
  const cut = clean.slice(0, max - 1);
  const space = cut.lastIndexOf(" ");
  return (space > max * 0.5 ? cut.slice(0, space) : cut).replace(/[\s,;:.]+$/u, "") + "…";
}

/** Bucket de largo para analytics (nunca el texto). */
export function lengthBucket(words: number): string {
  if (words < 30) return "<30";
  if (words < 200) return "30-199";
  if (words < 1000) return "200-999";
  return "1000+";
}

/** Hash FNV-1a de 32 bits: estable, para elegir variantes y para el embedding local. */
export function fnv1a(input: string, seed = 0x811c9dc5): number {
  let hash = seed >>> 0;
  for (let i = 0; i < input.length; i++) {
    hash ^= input.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash >>> 0;
}

/**
 * Contenido externo o de la persona que va dentro de un prompt delimitado con etiquetas (<contenido_externo>,
 * <concepto_a>…): se cambian < y > por ‹ y › para que el texto no pueda cerrar el bloque y "salir" a instrucciones.
 */
export function asPromptData(text: string): string {
  return text.replace(/</g, "‹").replace(/>/g, "›");
}
