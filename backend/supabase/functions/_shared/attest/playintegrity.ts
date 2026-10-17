// Play Integrity del lado del servidor (paso 40). La app de Android (paso 70) pide un token estándar con
// requestHash = SHA-256 en hexadecimal de "<función>\n<segundos Unix>\n<cuerpo>" (el mismo mensaje que App Attest;
// provisorio hasta que exista el cliente) y lo manda en X-Lumbre-Integrity-Token junto con X-Lumbre-Attest-Time.
//
// El servidor lo descifra con la API de Google (decodeIntegrityToken), autenticado con una cuenta de servicio
// (PLAY_INTEGRITY_SERVICE_ACCOUNT, el JSON entero) y el paquete ANDROID_PACKAGE_NAME, y exige:
// - el paquete y el requestHash del pedido, y una marca de tiempo de menos de 5 minutos;
// - appRecognitionVerdict PLAY_RECOGNIZED (la app instalada desde Play, sin modificar);
// - MEETS_DEVICE_INTEGRITY (o MEETS_BASIC_INTEGRITY si PLAY_INTEGRITY_ALLOW_BASIC=true).

import { AttestationError } from "./appattest.ts";

export interface ServiceAccount {
  client_email: string;
  private_key: string;
  token_uri?: string;
}

export interface IntegrityVerdict {
  requestDetails?: { requestPackageName?: string; requestHash?: string; timestampMillis?: string };
  appIntegrity?: { appRecognitionVerdict?: string; packageName?: string; versionCode?: string };
  deviceIntegrity?: { deviceRecognitionVerdict?: string[] };
  accountDetails?: { appLicensingVerdict?: string };
}

export interface IntegrityInput {
  token: string;
  /** SHA-256 en hexadecimal del mensaje del pedido. */
  requestHash: string;
  packageName: string;
  account: ServiceAccount;
  allowBasic?: boolean;
  now?: Date;
  fetchImpl?: typeof fetch;
}

const SCOPE = "https://www.googleapis.com/auth/playintegrity";
const MAX_AGE_MS = 5 * 60 * 1000;

function base64url(bytes: Uint8Array | string): string {
  const raw = typeof bytes === "string" ? new TextEncoder().encode(bytes) : bytes;
  let binary = "";
  for (const b of raw) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

let cachedToken: { email: string; token: string; expiresAt: number } | null = null;

/** Token de OAuth de la cuenta de servicio (JWT RS256 firmado con su clave), reusado hasta 5 minutos antes de vencer. */
export async function googleAccessToken(account: ServiceAccount, fetchImpl: typeof fetch = fetch, now = new Date()): Promise<string> {
  if (cachedToken && cachedToken.email === account.client_email && cachedToken.expiresAt - 300_000 > now.getTime()) {
    return cachedToken.token;
  }
  const pem = account.private_key.replace(/\\n/g, "\n").replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const iat = Math.floor(now.getTime() / 1000);
  const tokenUri = account.token_uri ?? "https://oauth2.googleapis.com/token";
  const unsigned = `${base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }))}.${
    base64url(JSON.stringify({ iss: account.client_email, scope: SCOPE, aud: tokenUri, iat, exp: iat + 3600 }))
  }`;
  const signature = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned)));
  const response = await fetchImpl(tokenUri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: `${unsigned}.${base64url(signature)}` }),
    signal: AbortSignal.timeout(10_000),
  });
  if (!response.ok) {
    await response.body?.cancel();
    throw new AttestationError(`google_oauth_${response.status}`);
  }
  const body = await response.json() as { access_token: string; expires_in: number };
  cachedToken = { email: account.client_email, token: body.access_token, expiresAt: now.getTime() + body.expires_in * 1000 };
  return body.access_token;
}

export async function decodeIntegrityToken(input: IntegrityInput): Promise<IntegrityVerdict> {
  const fetchImpl = input.fetchImpl ?? fetch;
  const accessToken = await googleAccessToken(input.account, fetchImpl, input.now);
  const response = await fetchImpl(
    `https://playintegrity.googleapis.com/v1/${encodeURIComponent(input.packageName)}:decodeIntegrityToken`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${accessToken}` },
      body: JSON.stringify({ integrity_token: input.token }),
      signal: AbortSignal.timeout(10_000),
    },
  );
  if (!response.ok) {
    await response.body?.cancel();
    throw new AttestationError(response.status === 400 ? "integrity_token" : `play_integrity_${response.status}`);
  }
  const body = await response.json() as { tokenPayloadExternal?: IntegrityVerdict };
  if (!body.tokenPayloadExternal) throw new AttestationError("integrity_token");
  return body.tokenPayloadExternal;
}

/** Revisa el veredicto contra el pedido. Lanza AttestationError con el motivo si algo no da. */
export function checkVerdict(verdict: IntegrityVerdict, input: Omit<IntegrityInput, "token" | "account" | "fetchImpl">): void {
  const now = (input.now ?? new Date()).getTime();
  const details = verdict.requestDetails ?? {};
  if (details.requestPackageName !== input.packageName) throw new AttestationError("package");
  if ((details.requestHash ?? "").toLowerCase() !== input.requestHash.toLowerCase()) throw new AttestationError("request_hash");
  const timestamp = Number(details.timestampMillis ?? 0);
  if (!timestamp || Math.abs(now - timestamp) > MAX_AGE_MS) throw new AttestationError("stale");
  if (verdict.appIntegrity?.appRecognitionVerdict !== "PLAY_RECOGNIZED") throw new AttestationError("app_not_recognized");
  const device = verdict.deviceIntegrity?.deviceRecognitionVerdict ?? [];
  const okDevice = device.includes("MEETS_DEVICE_INTEGRITY") || device.includes("MEETS_STRONG_INTEGRITY") ||
    (input.allowBasic === true && device.includes("MEETS_BASIC_INTEGRITY"));
  if (!okDevice) throw new AttestationError("device_integrity");
}

export async function verifyIntegrityToken(input: IntegrityInput): Promise<IntegrityVerdict> {
  const verdict = await decodeIntegrityToken(input);
  checkVerdict(verdict, input);
  return verdict;
}
