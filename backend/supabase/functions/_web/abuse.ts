// Anti-abuso de la web: IP y email hasheados con sal, límites por ventana (web_rate_hit), honeypot y tiempo mínimo.
// Nunca se guarda ni se loguea una IP o un email en claro.

import { admin } from "../_shared/supabase.ts";
import { WebError } from "./http.ts";

/** IP del cliente: la primera de X-Forwarded-For (la pone el gateway de Supabase). */
export function clientIp(req: Request): string {
  const forwarded = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim();
  return forwarded || req.headers.get("x-real-ip")?.trim() || req.headers.get("cf-connecting-ip")?.trim() || "unknown";
}

export async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input));
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
}

/** Sal de los hashes de IP y email. Sin LUMBRE_RATE_SALT, se deriva de la clave de servicio (secreta y fija por entorno). */
function salt(): string {
  return Deno.env.get("LUMBRE_RATE_SALT") || `lumbre-web:${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "local"}`;
}

export async function subjectHash(kind: "ip" | "email", value: string): Promise<string> {
  return (await sha256Hex(`${salt()}:${kind}:${value}`)).slice(0, 32);
}

export interface Limit {
  bucket: string;
  windowSeconds: number;
  max: number;
}

/** Suma un intento a cada límite. Si alguno se pasó, 429 rate_limited. */
export async function enforce(subject: string, limits: Limit[]): Promise<void> {
  for (const limit of limits) {
    const { data, error } = await admin().rpc("web_rate_hit", {
      p_bucket: limit.bucket,
      p_subject: subject,
      p_window_seconds: limit.windowSeconds,
      p_max: limit.max,
    });
    if (error) throw new Error(`rate: ${error.message}`);
    if (data !== true) throw new WebError("rate_limited");
  }
}

/** Como enforce, pero dice si entra en vez de cortar. */
export async function allowed(subject: string, limit: Limit): Promise<boolean> {
  try {
    await enforce(subject, [limit]);
    return true;
  } catch (error) {
    if (error instanceof WebError) return false;
    throw error;
  }
}

/**
 * Bot evidente: llenó el campo trampa (oculto para personas) o mandó el formulario en menos de 1,5 s.
 * `elapsed_ms` lo mide la página desde que se mostró el formulario.
 */
export function looksLikeBot(body: Record<string, unknown>): boolean {
  const honeypot = typeof body.website === "string" ? body.website.trim() : "";
  const elapsed = typeof body.elapsed_ms === "number" ? body.elapsed_ms : null;
  return honeypot.length > 0 || (elapsed !== null && elapsed < 1500);
}

/** Flags del servidor en app_config (se cambian sin publicar). Caché de 60 s por worker. */
const flagCache = new Map<string, { value: unknown; at: number }>();

export async function configValue<T>(key: string, fallback: T): Promise<T> {
  const cached = flagCache.get(key);
  if (cached && Date.now() - cached.at < 60_000) return cached.value as T;
  const { data, error } = await admin().from("app_config").select("value").eq("key", key).maybeSingle();
  if (error) throw new Error(`config: ${error.message}`);
  const value = (data?.value ?? fallback) as T;
  flagCache.set(key, { value, at: Date.now() });
  return value;
}

export async function requireFlag(key: string): Promise<void> {
  if ((await configValue<boolean>(key, true)) !== true) throw new WebError("disabled");
}
