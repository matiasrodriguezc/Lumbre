// Precios por modelo, en dólares por millón de tokens (plan.md §8 y precios de API de octubre de 2026).
// Verificar antes de cerrar números: si un modelo no está acá, el costo se registra como 0 y se avisa en el log.

import type { Usage } from "./types.ts";

interface Price {
  input: number;
  output: number;
}

export const PRICES: Record<string, Price> = {
  "claude-haiku-4-5": { input: 1, output: 5 },
  "claude-haiku-5-5": { input: 0.1, output: 0.5 },
  "claude-sonnet-5": { input: 2, output: 10 },
  "claude-sonnet-5-5": { input: 2, output: 10 },
  "claude-sonnet-4-6": { input: 3, output: 15 },
  "claude-opus-5-5": { input: 4, output: 20 },
  "voyage-3.5": { input: 0.06, output: 0 },
  "voyage-3.5-lite": { input: 0.02, output: 0 },
};

/** Lectura de caché al 10% de la entrada; escritura al 125%; Batches API al 50% de todo. */
export function costUsd(model: string, usage: Usage, batch = false): number {
  if (model.startsWith("local") || model.startsWith("lumbre-local")) return 0;
  const price = PRICES[model];
  if (!price) {
    console.warn(JSON.stringify({ fn: "pricing", level: "warn", unknown_model: model }));
    return 0;
  }
  const perToken = (n: number, usdPerMillion: number) => (n * usdPerMillion) / 1_000_000;
  const total = perToken(usage.inputTokens, price.input) +
    perToken(usage.cachedTokens, price.input * 0.1) +
    perToken(usage.cacheWriteTokens, price.input * 1.25) +
    perToken(usage.outputTokens, price.output);
  return Number((batch ? total * 0.5 : total).toFixed(6));
}
