// Respuestas HTTP del contrato (backend/openapi.yaml): JSON en snake_case, errores { error: código } y CORS.

export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-lumbre-entry, x-lumbre-attest-key, x-lumbre-attest-time, x-lumbre-attestation, x-lumbre-assertion, x-lumbre-integrity-token",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/** Códigos de error del contrato y su status HTTP. */
export const errorStatus = {
  not_authenticated: 401,
  invalid_thesis: 400,
  invalid_category: 400,
  invalid_source: 400,
  invalid_request: 400,
  pro_required: 402,
  account_required: 403,
  attestation_failed: 403,
  ai_consent_required: 403,
  not_found: 404,
  not_enough_concepts: 409,
  needs_thesis: 422,
  quota_exceeded: 429,
  import_limit: 429,
  too_many_categories: 429,
  too_many_projects: 429,
  rate_limited: 429,
  ai_unavailable: 503,
  internal: 500,
} as const;

export type ErrorCode = keyof typeof errorStatus;

/** Error con código del contrato: lo que la app traduce. Nunca lleva texto del servidor ni del usuario. */
export class ApiError extends Error {
  constructor(public code: ErrorCode, message?: string) {
    super(message ?? code);
  }
}

export function isErrorCode(value: string): value is ErrorCode {
  return value in errorStatus;
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export function errorResponse(code: ErrorCode): Response {
  return json({ error: code }, errorStatus[code]);
}

/** Lee el cuerpo JSON; si no es un objeto, invalid_request. */
export async function readJson<T = Record<string, unknown>>(req: Request): Promise<T> {
  const text = await req.text();
  if (!text.trim()) return {} as T;
  try {
    const value = JSON.parse(text);
    if (value === null || typeof value !== "object" || Array.isArray(value)) throw new Error("no es un objeto");
    return value as T;
  } catch {
    throw new ApiError("invalid_request");
  }
}

/**
 * Envuelve un handler: CORS, solo POST, y traducción de errores a { error }.
 * Los errores inesperados se loguean sin el cuerpo del pedido (puede tener contenido del usuario).
 */
export function handler(name: string, fn: (req: Request) => Promise<Response>) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    if (req.method !== "POST") return errorResponse("invalid_request");
    try {
      return await fn(req);
    } catch (error) {
      if (error instanceof ApiError) return errorResponse(error.code);
      console.error(JSON.stringify({ fn: name, level: "error", error: describeError(error) }));
      return errorResponse("internal");
    }
  };
}

/** Descripción de un error para el log: tipo y mensaje técnico, nunca contenido del usuario. */
export function describeError(error: unknown): string {
  if (error instanceof Error) return `${error.name}: ${error.message}`.slice(0, 300);
  return String(error).slice(0, 300);
}

// ---------------------------------------------------------------
// Server-Sent Events (planificador)
// ---------------------------------------------------------------

export interface SseWriter {
  send(event: string, data: unknown): void;
  close(): void;
}

/** Abre una respuesta text/event-stream y corre `run` escribiendo eventos en ella. */
export function sseResponse(run: (sse: SseWriter) => Promise<void>): Response {
  const encoder = new TextEncoder();
  let closed = false;
  const stream = new ReadableStream<Uint8Array>({
    async start(controller) {
      const sse: SseWriter = {
        send(event, data) {
          if (closed) return;
          controller.enqueue(encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`));
        },
        close() {
          if (closed) return;
          closed = true;
          controller.close();
        },
      };
      try {
        await run(sse);
      } catch (error) {
        console.error(JSON.stringify({ fn: "sse", level: "error", error: describeError(error) }));
        sse.send("error", { error: error instanceof ApiError ? error.code : "internal" });
      } finally {
        sse.close();
      }
    },
    cancel() {
      closed = true;
    },
  });
  return new Response(stream, {
    headers: {
      ...corsHeaders,
      "Content-Type": "text/event-stream; charset=utf-8",
      "Cache-Control": "no-cache",
      "Connection": "keep-alive",
    },
  });
}
