// Clientes de Supabase para las Edge Functions.
// - admin: service role, salta RLS. Solo para lo que la app no puede hacer (embeddings, chispas, cuotas).
// - del usuario: con su JWT, así RLS y las funciones con auth.uid() validan como si llamara la app.
//
// Se usa solo postgrest-js (mismo .from() y .rpc() que supabase-js) y fetch para Auth y Storage:
// supabase-js completo trae Realtime, Auth y Functions, y su arranque en frío se come el límite de CPU del worker.

import { PostgrestClient } from "npm:@supabase/postgrest-js@2.116.0";
import { ApiError } from "./http.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

interface StorageBucket {
  download(path: string): Promise<{ data: Blob | null; error: { message: string } | null }>;
  remove(paths: string[]): Promise<{ error: { message: string } | null }>;
}

export interface SupabaseClient {
  // deno-lint-ignore no-explicit-any
  from: PostgrestClient<any>["from"];
  // deno-lint-ignore no-explicit-any
  rpc: PostgrestClient<any>["rpc"];
  storage: { from(bucket: string): StorageBucket };
}

function makeClient(apiKey: string, token: string): SupabaseClient {
  const headers = { apikey: apiKey, Authorization: `Bearer ${token}` };
  // deno-lint-ignore no-explicit-any
  const rest = new PostgrestClient<any>(`${SUPABASE_URL}/rest/v1`, { headers });
  const storageUrl = `${SUPABASE_URL}/storage/v1/object`;
  return {
    from: rest.from.bind(rest),
    rpc: rest.rpc.bind(rest),
    storage: {
      from(bucket: string): StorageBucket {
        return {
          async download(path) {
            const response = await fetch(`${storageUrl}/${bucket}/${path.split("/").map(encodeURIComponent).join("/")}`, { headers });
            if (!response.ok) {
              await response.body?.cancel();
              return { data: null, error: { message: `storage ${response.status}` } };
            }
            return { data: await response.blob(), error: null };
          },
          async remove(paths) {
            const response = await fetch(`${storageUrl}/${bucket}`, {
              method: "DELETE",
              headers: { ...headers, "Content-Type": "application/json" },
              body: JSON.stringify({ prefixes: paths }),
            });
            await response.body?.cancel();
            return { error: response.ok ? null : { message: `storage ${response.status}` } };
          },
        };
      },
    },
  };
}

let adminClient: SupabaseClient | null = null;

export function admin(): SupabaseClient {
  adminClient ??= makeClient(SERVICE_KEY, SERVICE_KEY);
  return adminClient;
}

export interface UserContext {
  id: string;
  isAnonymous: boolean;
  /** Cliente con el JWT del usuario. */
  client: SupabaseClient;
}

function bearer(req: Request): string | null {
  const header = req.headers.get("Authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match ? match[1].trim() : null;
}

/** Valida el access token del usuario (también invitados). Sin sesión válida: 401 not_authenticated. */
export async function requireUser(req: Request): Promise<UserContext> {
  const token = bearer(req);
  if (!token) throw new ApiError("not_authenticated");
  const response = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { apikey: ANON_KEY, Authorization: `Bearer ${token}` },
  });
  if (!response.ok) {
    await response.body?.cancel();
    if (response.status >= 500) throw new Error(`auth ${response.status}`);
    throw new ApiError("not_authenticated");
  }
  const user = await response.json() as { id?: string; is_anonymous?: boolean };
  if (!user.id) throw new ApiError("not_authenticated");
  return { id: user.id, isAnonymous: user.is_anonymous === true, client: makeClient(ANON_KEY, token) };
}

/**
 * Funciones internas (las llama pg_cron): solo con la clave de servicio.
 * Acepta la clave de servicio clásica (JWT), la nueva (sb_secret_…) si está en el entorno,
 * y LUMBRE_CRON_SECRET si se configuró uno propio.
 */
export function requireService(req: Request): void {
  const token = bearer(req);
  const accepted = [SERVICE_KEY, Deno.env.get("SUPABASE_SECRET_KEY"), Deno.env.get("LUMBRE_CRON_SECRET")]
    .filter((value): value is string => !!value);
  if (!token || !accepted.some((key) => timingSafeEqual(key, token))) throw new ApiError("not_authenticated");
}

export function timingSafeEqual(a: string, b: string): boolean {
  const left = new TextEncoder().encode(a);
  const right = new TextEncoder().encode(b);
  let diff = left.length ^ right.length;
  for (let i = 0; i < Math.max(left.length, right.length); i++) diff |= (left[i] ?? 0) ^ (right[i] ?? 0);
  return diff === 0;
}

/** Ejecuta una RPC con service role y devuelve los datos; los errores de la base pasan como ApiError si traen un código. */
export async function rpc<T>(client: SupabaseClient, fn: string, args: Record<string, unknown> = {}): Promise<T> {
  const { data, error } = await client.rpc(fn, args);
  if (error) throw dbError(error);
  return data as T;
}

/** Traduce un error de PostgREST: si el mensaje es un código del contrato, lo usa; si no, error interno. */
export function dbError(error: { message?: string; code?: string }): Error {
  const message = error.message ?? "";
  const known = [
    "not_authenticated", "invalid_thesis", "invalid_category", "invalid_source", "invalid_request",
    "quota_exceeded", "too_many_categories", "too_many_projects", "not_found",
  ] as const;
  const code = known.find((k) => message === k);
  if (code) return new ApiError(code);
  return new Error(`db ${error.code ?? ""}: ${message}`.slice(0, 300));
}

/** Plan efectivo (guest si la sesión es anónima). */
export async function effectivePlan(userId: string): Promise<"guest" | "free" | "pro"> {
  return await rpc<"guest" | "free" | "pro">(admin(), "effective_plan", { p_user: userId });
}

/** consume_credit() con service role. */
export async function consumeCredit(userId: string, kind: string): Promise<boolean> {
  return await rpc<boolean>(admin(), "consume_credit", { p_user: userId, p_kind: kind });
}

export async function refundCredit(userId: string, kind: string): Promise<void> {
  try {
    await rpc<boolean>(admin(), "refund_credit", { p_user: userId, p_kind: kind });
  } catch (error) {
    console.error(JSON.stringify({ fn: "refund_credit", level: "error", kind, error: String(error).slice(0, 200) }));
  }
}

/** ¿El plan tiene alguna fila para este tipo de cupo? (para distinguir "es de Pro" de "se te acabó"). */
export async function planHasKind(plan: string, kind: string): Promise<boolean> {
  const { count, error } = await admin()
    .from("plan_limits")
    .select("kind", { count: "exact", head: true })
    .eq("plan", plan)
    .eq("kind", kind);
  if (error) throw dbError(error);
  return (count ?? 0) > 0;
}

/** Corre una tarea después de responder si el runtime lo permite (EdgeRuntime.waitUntil); si no, la espera. */
export function background(task: Promise<unknown>): Promise<void> | void {
  const runtime = (globalThis as { EdgeRuntime?: { waitUntil(p: Promise<unknown>): void } }).EdgeRuntime;
  const safe = task.catch((error) =>
    console.error(JSON.stringify({ fn: "background", level: "error", error: String(error).slice(0, 200) }))
  );
  if (runtime?.waitUntil) {
    runtime.waitUntil(safe);
    return;
  }
  return safe.then(() => {});
}
