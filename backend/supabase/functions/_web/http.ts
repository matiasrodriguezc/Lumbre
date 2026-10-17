// HTTP de las funciones públicas de la web (waitlist y demo-spark): sin sesión, con CORS y errores propios.
// Usa los helpers de _shared/http.ts; los códigos de acá son solo de la web y no están en el contrato de la app.

import { ApiError, corsHeaders, describeError } from "../_shared/http.ts";

export const webErrorStatus = {
  invalid_request: 400,
  invalid_email: 400,
  invalid_ideas: 400,
  invalid_content: 400,
  not_found: 404,
  rate_limited: 429,
  daily_limit: 429,
  demo_full: 503,
  disabled: 503,
  ai_unavailable: 503,
  internal: 500,
} as const;

export type WebErrorCode = keyof typeof webErrorStatus;

export class WebError extends Error {
  constructor(public code: WebErrorCode) {
    super(code);
  }
}

/** Orígenes permitidos: LUMBRE_WEB_ORIGINS (separados por coma). Sin la variable, cualquiera (local). */
function allowedOrigin(req: Request): string {
  const list = (Deno.env.get("LUMBRE_WEB_ORIGINS") ?? "").split(",").map((o) => o.trim()).filter(Boolean);
  if (list.length === 0) return "*";
  const origin = req.headers.get("Origin") ?? "";
  return list.includes(origin) ? origin : list[0];
}

export function webJson(req: Request, body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Access-Control-Allow-Origin": allowedOrigin(req),
      "Vary": "Origin",
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

export function webError(req: Request, code: WebErrorCode): Response {
  return webJson(req, { error: code }, webErrorStatus[code]);
}

/** Lee el cuerpo JSON (máximo 8 KB: nada de lo que manda la web pesa más). */
export async function readWebJson(req: Request): Promise<Record<string, unknown>> {
  const text = await req.text();
  if (text.length > 8192) throw new WebError("invalid_request");
  if (!text.trim()) return {};
  try {
    const value = JSON.parse(text);
    if (value === null || typeof value !== "object" || Array.isArray(value)) throw new Error("no es un objeto");
    return value as Record<string, unknown>;
  } catch {
    throw new WebError("invalid_request");
  }
}

/** CORS, solo POST y errores a { error }. Los inesperados se loguean sin el cuerpo (tiene emails e ideas). */
export function webHandler(name: string, fn: (req: Request) => Promise<Response>) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: { ...corsHeaders, "Access-Control-Allow-Origin": allowedOrigin(req), "Vary": "Origin" } });
    }
    if (req.method !== "POST") return webError(req, "invalid_request");
    try {
      return await fn(req);
    } catch (error) {
      if (error instanceof WebError) return webError(req, error.code);
      if (error instanceof ApiError && error.code in webErrorStatus) return webError(req, error.code as WebErrorCode);
      console.error(JSON.stringify({ fn: name, level: "error", error: describeError(error) }));
      return webError(req, "internal");
    }
  };
}

/** Una línea JSON por evento, sin emails ni texto de la persona. */
export function webLog(fn: string, fields: Record<string, string | number | boolean | null>): void {
  console.log(JSON.stringify({ fn, ...fields }));
}
