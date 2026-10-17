// Promedio del set de evaluación puntuado a mano (pasos 29 y 30). Objetivo de plan.md §5: 3,5 o más.
//
//   deno run --allow-read backend/eval/score.ts backend/eval/runs/<corrida>.csv
//
// Lee la planilla que dejó run.ts con "sorprende" y "sirve" completos (enteros de 1 a 5; acepta la exportación de
// Excel con punto y coma). Calcula, por perfil y en total: promedio de sorprende, de sirve y el promedio de los dos
// (el número de la compuerta). Las filas sin puntaje se cuentan aparte; un valor fuera de 1–5 es un error.
// Sale con código 0 si el promedio total llega a 3,5 y todo está puntuado; 1 si no.

import { parseCsv } from "./csv.ts";

export const TARGET = 3.5;

export interface Score {
  id: string;
  profile: string;
  surprise: number;
  useful: number;
  title: string;
}

export interface Summary {
  profile: string;
  scored: number;
  surprise: number;
  useful: number;
  average: number;
}

export function readScores(text: string): { scores: Score[]; missing: string[]; errors: string[] } {
  const [header, ...rows] = parseCsv(text);
  const col = (name: string) => header.findIndex((h) => h.trim().toLowerCase() === name);
  const [id, profile, surprise, useful, title] = ["id", "perfil", "sorprende", "sirve", "titulo_chispa"].map(col);
  if ([id, profile, surprise, useful].some((i) => i < 0)) throw new Error("faltan columnas: id, perfil, sorprende, sirve");
  const scores: Score[] = [];
  const missing: string[] = [];
  const errors: string[] = [];
  for (const row of rows) {
    const s = row[surprise]?.trim() ?? "";
    const u = row[useful]?.trim() ?? "";
    if (!s && !u) {
      missing.push(row[id]);
      continue;
    }
    const sv = Number(s.replace(",", "."));
    const uv = Number(u.replace(",", "."));
    if (![sv, uv].every((v) => Number.isInteger(v) && v >= 1 && v <= 5)) {
      errors.push(`${row[id]}: sorprende="${s}" sirve="${u}" (enteros de 1 a 5)`);
      continue;
    }
    scores.push({ id: row[id], profile: row[profile], surprise: sv, useful: uv, title: title >= 0 ? row[title] : "" });
  }
  return { scores, missing, errors };
}

function mean(values: number[]): number {
  return values.length ? values.reduce((a, b) => a + b, 0) / values.length : 0;
}

export function summarize(scores: Score[]): Summary[] {
  const groups = new Map<string, Score[]>();
  for (const s of scores) groups.set(s.profile, [...(groups.get(s.profile) ?? []), s]);
  const row = (profile: string, list: Score[]): Summary => ({
    profile,
    scored: list.length,
    surprise: mean(list.map((s) => s.surprise)),
    useful: mean(list.map((s) => s.useful)),
    average: mean(list.map((s) => (s.surprise + s.useful) / 2)),
  });
  return [...[...groups.entries()].sort().map(([p, l]) => row(p, l)), row("TOTAL", scores)];
}

if (import.meta.main) {
  const file = Deno.args[0];
  if (!file) {
    console.error("Uso: deno run --allow-read backend/eval/score.ts <planilla.csv>");
    Deno.exit(2);
  }
  const { scores, missing, errors } = readScores(await Deno.readTextFile(file));
  const fmt = (n: number) => n.toFixed(2).replace(".", ",");
  console.log("perfil       puntuados  sorprende  sirve  promedio");
  for (const s of summarize(scores)) {
    console.log(`${s.profile.padEnd(12)} ${String(s.scored).padStart(9)}  ${fmt(s.surprise).padStart(9)}  ${fmt(s.useful).padStart(5)}  ${fmt(s.average).padStart(8)}`);
  }
  const total = summarize(scores).at(-1)!;
  const worst = [...scores].sort((a, b) => (a.surprise + a.useful) - (b.surprise + b.useful)).slice(0, 10);
  if (worst.length) console.log(`\nLas 10 más flojas (para iterar el prompt):\n${worst.map((s) => `  ${s.id}  ${s.surprise}/${s.useful}  ${s.title}`).join("\n")}`);
  if (missing.length) console.log(`\nSin puntuar: ${missing.length} (${missing.slice(0, 5).join(", ")}${missing.length > 5 ? "…" : ""})`);
  if (errors.length) console.log(`\nValores inválidos:\n  ${errors.join("\n  ")}`);
  const pass = total.scored > 0 && total.average >= TARGET && missing.length === 0 && errors.length === 0;
  console.log(`\nPromedio ${fmt(total.average)} sobre ${total.scored}: ${pass ? "llega" : "no llega"} al objetivo de ${fmt(TARGET)}${missing.length || errors.length ? " (falta completar la planilla)" : ""}.`);
  Deno.exit(pass ? 0 : 1);
}
