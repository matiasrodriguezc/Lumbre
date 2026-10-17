// Integridad del dispositivo en los endpoints de IA (paso 40): App Attest (iOS) y Play Integrity (Android).
//
// Se prende por entorno con LUMBRE_ATTESTATION, así local y dev siguen andando sin credenciales:
// - off (default): no mira nada.
// - report: verifica y loguea el resultado (sin contenido), pero nunca bloquea. Para medir antes de exigir.
// - enforce: un pedido sin firma válida responde 403 attestation_failed (la app descarta la clave y crea otra).
//
// Variables: APP_ATTEST_APP_ID ("<team id>.<bundle id>"; si falta, APNS_TEAM_ID + APNS_BUNDLE_ID),
// APP_ATTEST_ALLOW_DEVELOPMENT (true por defecto: acepta claves del entorno de desarrollo de Apple),
// APPLE_APP_ATTEST_ROOT_PEM (opcional), PLAY_INTEGRITY_SERVICE_ACCOUNT (JSON), ANDROID_PACKAGE_NAME y
// PLAY_INTEGRITY_ALLOW_BASIC. Protocolo de headers: ios/Packages/LumbreCore/Sources/LumbreCore/AppAttest.swift.

import { ApiError } from "../http.ts";
import { admin, type SupabaseClient } from "../supabase.ts";
import {
  AttestationError,
  clientDataHash,
  fromBase64,
  verifyAssertion,
  verifyAttestation,
} from "./appattest.ts";
import { type ServiceAccount, verifyIntegrityToken } from "./playintegrity.ts";

export type AttestationMode = "off" | "report" | "enforce";

export const HEADERS = {
  keyId: "x-lumbre-attest-key",
  time: "x-lumbre-attest-time",
  attestation: "x-lumbre-attestation",
  assertion: "x-lumbre-assertion",
  integrityToken: "x-lumbre-integrity-token",
} as const;

const MAX_SKEW_SECONDS = 300;

export function attestationMode(): AttestationMode {
  const value = Deno.env.get("LUMBRE_ATTESTATION");
  return value === "report" || value === "enforce" ? value : "off";
}

export interface IntegrityResult {
  ok: boolean;
  platform: "ios" | "android" | null;
  reason: string | null;
}

export interface GuardDeps {
  db?: SupabaseClient;
  now?: Date;
  env?: (name: string) => string | undefined;
  fetchImpl?: typeof fetch;
}

function appId(env: (name: string) => string | undefined): string | null {
  const explicit = env("APP_ATTEST_APP_ID");
  if (explicit) return explicit;
  const team = env("APNS_TEAM_ID");
  const bundle = env("APNS_BUNDLE_ID");
  return team && bundle ? `${team}.${bundle}` : null;
}

async function sha256Hex(bytes: Uint8Array<ArrayBuffer>): Promise<string> {
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
  return [...digest].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** Verifica la firma del pedido. No lanza: devuelve el resultado con el motivo. */
export async function verifyRequest(req: Request, fn: string, userId: string, deps: GuardDeps = {}): Promise<IntegrityResult> {
  const env = deps.env ?? ((name: string) => Deno.env.get(name));
  const db = deps.db ?? admin();
  const now = deps.now ?? new Date();
  const time = req.headers.get(HEADERS.time);
  const keyId = req.headers.get(HEADERS.keyId);
  const token = req.headers.get(HEADERS.integrityToken);
  const platform = keyId ? "ios" : token ? "android" : null;
  if (!platform) return { ok: false, platform, reason: "missing" };
  if (!time || !/^\d{9,11}$/.test(time) || Math.abs(now.getTime() / 1000 - Number(time)) > MAX_SKEW_SECONDS) {
    return { ok: false, platform, reason: "stale" };
  }
  const body = new Uint8Array(await req.clone().arrayBuffer());

  try {
    if (platform === "android") {
      const raw = env("PLAY_INTEGRITY_SERVICE_ACCOUNT");
      const packageName = env("ANDROID_PACKAGE_NAME");
      if (!raw || !packageName) return { ok: false, platform, reason: "not_configured" };
      const message = new Uint8Array([...new TextEncoder().encode(`${fn}\n${time}\n`), ...body]);
      await verifyIntegrityToken({
        token: token!,
        requestHash: await sha256Hex(message),
        packageName,
        account: JSON.parse(raw) as ServiceAccount,
        allowBasic: env("PLAY_INTEGRITY_ALLOW_BASIC") === "true",
        now,
        fetchImpl: deps.fetchImpl,
      });
      return { ok: true, platform, reason: null };
    }

    const app = appId(env);
    if (!app) return { ok: false, platform, reason: "not_configured" };
    const hash = await clientDataHash(fn, time, body);
    const attestation = req.headers.get(HEADERS.attestation);
    const assertion = req.headers.get(HEADERS.assertion);

    if (attestation) {
      const { data: existing } = await db.from("attest_keys").select("key_id").eq("key_id", keyId!).maybeSingle();
      // Una clave se atestigua una sola vez: una atestación repetida es un replay.
      if (existing) return { ok: false, platform, reason: "key_exists" };
      const key = await verifyAttestation({
        attestation: fromBase64(attestation),
        keyId: keyId!,
        clientDataHash: hash,
        appId: app,
        allowDevelopment: env("APP_ATTEST_ALLOW_DEVELOPMENT") !== "false",
        rootPem: env("APPLE_APP_ATTEST_ROOT_PEM") || undefined,
        now,
      });
      const { error } = await db.from("attest_keys").insert({
        key_id: keyId!,
        platform: "ios",
        user_id: userId,
        public_key: key.publicKey,
        sign_count: 0,
        environment: key.environment,
        receipt: key.receipt,
      });
      if (error) return { ok: false, platform, reason: "key_exists" };
      return { ok: true, platform, reason: null };
    }

    if (assertion) {
      const { data: stored, error } = await db.from("attest_keys").select("public_key,sign_count").eq("key_id", keyId!).maybeSingle();
      if (error) throw new Error(`attest_keys: ${error.message}`);
      if (!stored) return { ok: false, platform, reason: "unknown_key" };
      const { signCount } = await verifyAssertion({
        assertion: fromBase64(assertion),
        clientDataHash: hash,
        publicKey: stored.public_key,
        previousCount: Number(stored.sign_count),
        appId: app,
      });
      // Actualización condicional: dos pedidos con el mismo contador no pasan los dos.
      const { data: updated } = await db.from("attest_keys")
        .update({ sign_count: signCount, user_id: userId, last_used_at: now.toISOString() })
        .eq("key_id", keyId!).lt("sign_count", signCount).select("key_id");
      if (!updated?.length) return { ok: false, platform, reason: "counter" };
      return { ok: true, platform, reason: null };
    }
    return { ok: false, platform, reason: "missing" };
  } catch (error) {
    if (error instanceof AttestationError) return { ok: false, platform, reason: error.reason };
    return { ok: false, platform, reason: "error" };
  }
}

/**
 * Para las funciones de IA, después de requireUser(). Con LUMBRE_ATTESTATION=off no hace nada; con report solo
 * loguea; con enforce, un pedido sin firma válida corta con 403 attestation_failed.
 */
export async function requireDeviceIntegrity(req: Request, fn: string, userId: string, deps: GuardDeps = {}): Promise<void> {
  const mode = deps.env ? (deps.env("LUMBRE_ATTESTATION") as AttestationMode | undefined) ?? "off" : attestationMode();
  if (mode !== "report" && mode !== "enforce") return;
  const result = await verifyRequest(req, fn, userId, deps);
  console.log(JSON.stringify({ fn: "attest", endpoint: fn, mode, platform: result.platform, ok: result.ok, reason: result.reason }));
  if (!result.ok && mode === "enforce") throw new ApiError("attestation_failed");
}
