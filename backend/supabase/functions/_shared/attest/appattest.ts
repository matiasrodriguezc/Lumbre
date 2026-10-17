// App Attest del lado del servidor (paso 40, plan.md §5 "Cuotas y abuso").
// Sigue "Validating apps that connect to your server" de Apple:
//
// Atestación (la primera vez que la app usa una clave):
//   1. La cadena x5c (hoja e intermedio) firma hasta la raíz de App Attest de Apple y es válida hoy.
//   2. nonce = SHA256(authData || clientDataHash) y es igual a la extensión 1.2.840.113635.100.8.2 de la hoja.
//   3. SHA256(clave pública de la hoja) = keyId.
//   4. rpIdHash de authData = SHA256(App ID: "<team id>.<bundle id>").
//   5. El contador arranca en 0.
//   6. aaguid: "appattest" + ceros (producción) o "appattestdevelop" (desarrollo, si se permite).
//   7. credentialId = keyId.
// Aserción (cada pedido después):
//   1. nonce = SHA256(authenticatorData || clientDataHash).
//   2. La firma (ECDSA P-256 con SHA-256, en DER) sobre nonce verifica con la clave pública guardada.
//   3. rpIdHash = SHA256(App ID).
//   4. El contador es mayor que el guardado (una aserción repetida no pasa).
//
// El "challenge" lo pone la app (protocolo de ios/…/AppAttest.swift): clientDataHash = SHA256("<función>\n<segundos Unix>\n<cuerpo>").
// El servidor rechaza tiempos fuera de ±5 minutos y, con el contador, las aserciones repetidas. Provisorio: Apple
// recomienda un challenge de un solo uso pedido al servidor; con el contador y la ventana de tiempo alcanza para
// el lanzamiento y evita un viaje más por pedido.

import { CborError, type CborValue, decodeCbor, field } from "./cbor.ts";
import { derSignatureToRaw, readTlv } from "./der.ts";

/**
 * Raíz de App Attest de Apple (https://www.apple.com/certificateauthority/Apple_App_Attestation_Root_CA.pem).
 * SHA-256: 1C:B9:82:3B:A2:8B:A6:AD:2D:33:A0:06:94:1D:E2:AE:4F:51:3E:F1:D4:E8:31:B9:F7:E0:FA:7B:62:42:C9:32.
 * Su autofirma P-384 verifica (se chequea en los tests), así que el texto es exacto. Se puede reemplazar con
 * APPLE_APP_ATTEST_ROOT_PEM.
 */
export const APPLE_APP_ATTEST_ROOT_PEM = `-----BEGIN CERTIFICATE-----
MIICITCCAaegAwIBAgIQC/O+DvHN0uD7jG5yH2IXmDAKBggqhkjOPQQDAzBSMSYw
JAYDVQQDDB1BcHBsZSBBcHAgQXR0ZXN0YXRpb24gUm9vdCBDQTETMBEGA1UECgwK
QXBwbGUgSW5jLjETMBEGA1UECAwKQ2FsaWZvcm5pYTAeFw0yMDAzMTgxODMyNTNa
Fw00NTAzMTUwMDAwMDBaMFIxJjAkBgNVBAMMHUFwcGxlIEFwcCBBdHRlc3RhdGlv
biBSb290IENBMRMwEQYDVQQKDApBcHBsZSBJbmMuMRMwEQYDVQQIDApDYWxpZm9y
bmlhMHYwEAYHKoZIzj0CAQYFK4EEACIDYgAERTHhmLW07ATaFQIEVwTtT4dyctdh
NbJhFs/Ii2FdCgAHGbpphY3+d8qjuDngIN3WVhQUBHAoMeQ/cLiP1sOUtgjqK9au
Yen1mMEvRq9Sk3Jm5X8U62H+xTD3FE9TgS41o0IwQDAPBgNVHRMBAf8EBTADAQH/
MB0GA1UdDgQWBBSskRBTM72+aEH/pwyp5frq5eWKoTAOBgNVHQ8BAf8EBAMCAQYw
CgYIKoZIzj0EAwMDaAAwZQIwQgFGnByvsiVbpTKwSga0kP0e8EeDS4+sQmTvb7vn
53O5+FRXgeLhpJ06ysC5PrOyAjEAp5U4xDgEgllF7En3VcE3iexZZtKeYnpqtijV
oyFraWVIyd/dganmrduC1bmTBGwD
-----END CERTIFICATE-----`;

export const NONCE_EXTENSION_OID = "1.2.840.113635.100.8.2";
const AAGUID_PRODUCTION = new Uint8Array([...new TextEncoder().encode("appattest"), 0, 0, 0, 0, 0, 0, 0]);
const AAGUID_DEVELOPMENT = new TextEncoder().encode("appattestdevelop");

export class AttestationError extends Error {
  constructor(public reason: string) {
    super(reason);
    this.name = "AttestationError";
  }
}

export interface AttestedKey {
  /** Clave pública de la hoja, SPKI en base64. */
  publicKey: string;
  signCount: number;
  environment: "production" | "development";
  /** Recibo de Apple (base64): sirve para pedir la métrica de fraude más adelante. */
  receipt: string | null;
}

export interface AuthData {
  rpIdHash: Uint8Array;
  flags: number;
  signCount: number;
  aaguid: Uint8Array | null;
  credentialId: Uint8Array | null;
}

// ---------------------------------------------------------------
// Utilidades
// ---------------------------------------------------------------
export async function sha256(...parts: Uint8Array[]): Promise<Uint8Array<ArrayBuffer>> {
  const total = parts.reduce((n, p) => n + p.length, 0);
  const joined = new Uint8Array(total);
  let at = 0;
  for (const part of parts) {
    joined.set(part, at);
    at += part.length;
  }
  return new Uint8Array(await crypto.subtle.digest("SHA-256", joined));
}

export function equalBytes(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

export function fromBase64(value: string): Uint8Array<ArrayBuffer> {
  const normal = value.replace(/-/g, "+").replace(/_/g, "/");
  return Uint8Array.from(atob(normal + "=".repeat((4 - (normal.length % 4)) % 4)), (c) => c.charCodeAt(0));
}

export function toBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary);
}

/** clientDataHash del protocolo de la app: SHA256("<función>\n<tiempo>\n<cuerpo>"). */
export async function clientDataHash(fn: string, time: string, body: Uint8Array): Promise<Uint8Array<ArrayBuffer>> {
  return await sha256(new TextEncoder().encode(`${fn}\n${time}\n`), body);
}

export function parseAuthData(bytes: Uint8Array, withCredential: boolean): AuthData {
  if (bytes.length < 37) throw new AttestationError("auth_data_short");
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const out: AuthData = {
    rpIdHash: bytes.slice(0, 32),
    flags: bytes[32],
    signCount: view.getUint32(33),
    aaguid: null,
    credentialId: null,
  };
  if (withCredential) {
    if (bytes.length < 55) throw new AttestationError("auth_data_short");
    out.aaguid = bytes.slice(37, 53);
    const idLength = view.getUint16(53);
    if (bytes.length < 55 + idLength) throw new AttestationError("auth_data_short");
    out.credentialId = bytes.slice(55, 55 + idLength);
  }
  return out;
}

/** El nonce de la extensión de Apple: SEQUENCE { [1] EXPLICIT OCTET STRING }. */
export function nonceFromExtension(value: Uint8Array): Uint8Array {
  const seq = readTlv(value);
  if (seq.tag !== 0x30) throw new AttestationError("nonce_extension");
  let offset = 0;
  while (offset < seq.value.length) {
    const tagged = readTlv(seq.value, offset);
    if (tagged.tag === 0xa1) {
      const octets = readTlv(tagged.value);
      if (octets.tag !== 0x04) throw new AttestationError("nonce_extension");
      return octets.value.slice();
    }
    offset = tagged.end;
  }
  throw new AttestationError("nonce_extension");
}

function bytesField(map: CborValue | undefined, key: string): Uint8Array {
  const value = field(map, key);
  if (!(value instanceof Uint8Array)) throw new AttestationError(`missing_${key}`);
  return value;
}

function decode(bytes: Uint8Array): CborValue {
  try {
    return decodeCbor(bytes);
  } catch (error) {
    if (error instanceof CborError) throw new AttestationError("cbor");
    throw error;
  }
}

// ---------------------------------------------------------------
// Atestación
// ---------------------------------------------------------------
export interface AttestationInput {
  attestation: Uint8Array;
  /** keyId en base64, como lo manda la app. */
  keyId: string;
  clientDataHash: Uint8Array;
  /** "<team id>.<bundle id>" */
  appId: string;
  allowDevelopment: boolean;
  rootPem?: string;
  now?: Date;
}

export async function verifyAttestation(input: AttestationInput): Promise<AttestedKey> {
  // La librería de X.509 se carga solo acá: las aserciones (casi todos los pedidos) no la necesitan.
  const x509 = await import("npm:@peculiar/x509@1.12.3");
  const now = input.now ?? new Date();
  const object = decode(input.attestation);
  if (field(object, "fmt") !== "apple-appattest") throw new AttestationError("format");
  const statement = field(object, "attStmt");
  const authDataBytes = bytesField(object, "authData");
  const chain = field(statement, "x5c");
  if (!Array.isArray(chain) || chain.length < 2 || !chain.every((c) => c instanceof Uint8Array)) {
    throw new AttestationError("x5c");
  }
  const receipt = field(statement, "receipt");

  // 1. Cadena hasta la raíz de Apple
  const root = new x509.X509Certificate(input.rootPem ?? APPLE_APP_ATTEST_ROOT_PEM);
  const leaf = new x509.X509Certificate(new Uint8Array(chain[0] as Uint8Array));
  const intermediate = new x509.X509Certificate(new Uint8Array(chain[1] as Uint8Array));
  for (const cert of [leaf, intermediate]) {
    if (now < cert.notBefore || now > cert.notAfter) throw new AttestationError("certificate_expired");
  }
  if (!(await intermediate.verify({ publicKey: root.publicKey, signatureOnly: true }))) throw new AttestationError("chain");
  if (!(await leaf.verify({ publicKey: intermediate.publicKey, signatureOnly: true }))) throw new AttestationError("chain");

  // 2. Nonce
  const nonce = await sha256(authDataBytes, input.clientDataHash);
  const extension = leaf.getExtension(NONCE_EXTENSION_OID);
  if (!extension) throw new AttestationError("nonce_extension");
  if (!equalBytes(nonceFromExtension(new Uint8Array(extension.value)), nonce)) throw new AttestationError("nonce");

  // 3. keyId = SHA256(punto público sin comprimir)
  const spki = new Uint8Array(leaf.publicKey.rawData);
  const key = await crypto.subtle.importKey("spki", spki, { name: "ECDSA", namedCurve: "P-256" }, true, ["verify"]);
  const point = new Uint8Array(await crypto.subtle.exportKey("raw", key));
  const keyId = fromBase64(input.keyId);
  if (!equalBytes(await sha256(point), keyId)) throw new AttestationError("key_id");

  // 4–7. authData
  const auth = parseAuthData(authDataBytes, true);
  if (!equalBytes(auth.rpIdHash, await sha256(new TextEncoder().encode(input.appId)))) throw new AttestationError("app_id");
  if (auth.signCount !== 0) throw new AttestationError("counter");
  let environment: AttestedKey["environment"];
  if (equalBytes(auth.aaguid!, AAGUID_PRODUCTION)) environment = "production";
  else if (equalBytes(auth.aaguid!, AAGUID_DEVELOPMENT) && input.allowDevelopment) environment = "development";
  else throw new AttestationError("aaguid");
  if (!equalBytes(auth.credentialId!, keyId)) throw new AttestationError("credential_id");

  return {
    publicKey: toBase64(spki),
    signCount: 0,
    environment,
    receipt: receipt instanceof Uint8Array ? toBase64(receipt) : null,
  };
}

// ---------------------------------------------------------------
// Aserción
// ---------------------------------------------------------------
export interface AssertionInput {
  assertion: Uint8Array;
  clientDataHash: Uint8Array;
  /** SPKI en base64, de la atestación. */
  publicKey: string;
  previousCount: number;
  appId: string;
}

export async function verifyAssertion(input: AssertionInput): Promise<{ signCount: number }> {
  const object = decode(input.assertion);
  const signature = bytesField(object, "signature");
  const authenticatorData = bytesField(object, "authenticatorData");

  const nonce = await sha256(authenticatorData, input.clientDataHash);
  const key = await crypto.subtle.importKey("spki", fromBase64(input.publicKey), { name: "ECDSA", namedCurve: "P-256" }, false, ["verify"]);
  let raw: Uint8Array<ArrayBuffer>;
  try {
    raw = derSignatureToRaw(signature);
  } catch {
    throw new AttestationError("signature");
  }
  // Apple firma con ecdsaSignatureMessageX962SHA256 sobre el nonce: WebCrypto le aplica el SHA-256.
  if (!(await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, key, raw, nonce))) throw new AttestationError("signature");

  const auth = parseAuthData(authenticatorData, false);
  if (!equalBytes(auth.rpIdHash, await sha256(new TextEncoder().encode(input.appId)))) throw new AttestationError("app_id");
  if (auth.signCount <= input.previousCount) throw new AttestationError("counter");
  return { signCount: auth.signCount };
}
