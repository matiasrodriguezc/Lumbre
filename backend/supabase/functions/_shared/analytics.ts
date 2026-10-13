// Eventos de servidor (docs/analytics.md, fuente S).
//
// - Con POSTHOG_API_KEY se mandan en lote a la API de PostHog (nube de la UE por defecto).
// - Sin clave, se escriben en el log como una línea JSON por evento.
// - Nunca llevan contenido del usuario: solo slugs, cantidades en rangos e ids. Si PostHog falla,
//   se loguea y se sigue: un evento perdido no frena la respuesta al usuario.

export type Properties = Record<string, string | number | boolean | null | undefined>;

interface PendingEvent {
  event: string;
  distinct_id: string;
  properties: Properties;
  timestamp: string;
}

const POSTHOG_KEY = Deno.env.get("POSTHOG_API_KEY");
const POSTHOG_HOST = (Deno.env.get("POSTHOG_HOST") ?? "https://eu.i.posthog.com").replace(/\/$/, "");

// Propiedades que nunca pueden salir, aunque alguien las pase por error.
const FORBIDDEN = new Set(["text", "title", "thesis", "principle", "body", "content", "url", "source_url", "query", "message", "email", "note"]);

export class Analytics {
  private queue: PendingEvent[] = [];

  track(event: string, distinctId: string, properties: Properties = {}, timestamp?: string): void {
    const safe: Properties = { platform: "server" };
    for (const [key, value] of Object.entries(properties)) {
      if (!FORBIDDEN.has(key) && value !== undefined) safe[key] = value;
    }
    this.queue.push({ event, distinct_id: distinctId, properties: safe, timestamp: timestamp ?? new Date().toISOString() });
  }

  get size(): number {
    return this.queue.length;
  }

  /** Manda lo encolado. Devuelve cuántos eventos salieron (al log o a PostHog). */
  async flush(): Promise<number> {
    const batch = this.queue.splice(0, this.queue.length);
    if (batch.length === 0) return 0;
    if (!POSTHOG_KEY) {
      for (const e of batch) console.log(JSON.stringify({ analytics: e.event, distinct_id: e.distinct_id, properties: e.properties }));
      return batch.length;
    }
    try {
      const response = await fetch(`${POSTHOG_HOST}/batch/`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ api_key: POSTHOG_KEY, batch }),
        signal: AbortSignal.timeout(5000),
      });
      if (!response.ok) throw new Error(`posthog ${response.status}`);
      await response.body?.cancel();
      return batch.length;
    } catch (error) {
      console.error(JSON.stringify({ fn: "analytics", level: "error", error: String(error).slice(0, 200), dropped: batch.length }));
      return 0;
    }
  }
}

/** Bucket de cantidad de conceptos, como la propiedad de persona concepts_count_bucket. */
export function countBucket(n: number): string {
  if (n === 0) return "0";
  if (n < 10) return "1-9";
  if (n < 50) return "10-49";
  if (n < 200) return "50-199";
  return "200+";
}
