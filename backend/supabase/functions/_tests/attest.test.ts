// App Attest y Play Integrity (paso 40). Apple no publica atestaciones de prueba firmadas por su raíz, así que los
// fixtures se generan acá con una cadena propia (raíz P-384 → intermedio → hoja P-256 con la extensión del nonce) y el
// verificador recibe esa raíz. La raíz real de Apple se valida aparte: su autofirma tiene que verificar.

import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import * as x509 from "npm:@peculiar/x509@1.12.3";
import {
  APPLE_APP_ATTEST_ROOT_PEM,
  AttestationError,
  clientDataHash,
  NONCE_EXTENSION_OID,
  sha256,
  toBase64,
  verifyAssertion,
  verifyAttestation,
} from "../_shared/attest/appattest.ts";
import { rawSignatureToDer } from "../_shared/attest/der.ts";
import { checkVerdict, decodeIntegrityToken, type IntegrityVerdict } from "../_shared/attest/playintegrity.ts";
import { requireDeviceIntegrity, verifyRequest } from "../_shared/attest/guard.ts";
import { ApiError } from "../_shared/http.ts";
import type { SupabaseClient } from "../_shared/supabase.ts";

x509.cryptoProvider.set(crypto);

const APP_ID = "ABCDE12345.app.lumbre.ios";
const NOW = new Date("2026-10-16T12:00:00Z");

// ---------------------------------------------------------------
// CBOR mínimo para armar los objetos como los arma Apple
// ---------------------------------------------------------------
function head(major: number, n: number): number[] {
  if (n < 24) return [(major << 5) | n];
  if (n < 256) return [(major << 5) | 24, n];
  if (n < 65536) return [(major << 5) | 25, n >> 8, n & 0xff];
  return [(major << 5) | 26, (n >>> 24) & 0xff, (n >>> 16) & 0xff, (n >>> 8) & 0xff, n & 0xff];
}
type Encodable = string | Uint8Array | Encodable[] | { [key: string]: Encodable };
function cbor(value: Encodable): Uint8Array {
  if (typeof value === "string") {
    const bytes = new TextEncoder().encode(value);
    return new Uint8Array([...head(3, bytes.length), ...bytes]);
  }
  if (value instanceof Uint8Array) return new Uint8Array([...head(2, value.length), ...value]);
  if (Array.isArray(value)) return new Uint8Array([...head(4, value.length), ...value.flatMap((v) => [...cbor(v)])]);
  const entries = Object.entries(value);
  return new Uint8Array([...head(5, entries.length), ...entries.flatMap(([k, v]) => [...cbor(k), ...cbor(v)])]);
}

// ---------------------------------------------------------------
// Fixtures: una "Apple" de prueba
// ---------------------------------------------------------------
const P384 = { name: "ECDSA", namedCurve: "P-384", hash: "SHA-384" } as const;
const P256 = { name: "ECDSA", namedCurve: "P-256" } as const;

async function testChain() {
  const rootKeys = await crypto.subtle.generateKey(P384, true, ["sign", "verify"]);
  const interKeys = await crypto.subtle.generateKey(P384, true, ["sign", "verify"]);
  const root = await x509.X509CertificateGenerator.createSelfSigned({
    serialNumber: "01", name: "CN=Raíz de prueba", notBefore: new Date("2025-01-01"), notAfter: new Date("2035-01-01"),
    keys: rootKeys, signingAlgorithm: P384,
  });
  const intermediate = await x509.X509CertificateGenerator.create({
    serialNumber: "02", subject: "CN=Intermedio de prueba", issuer: root.subject, notBefore: new Date("2025-01-01"),
    notAfter: new Date("2030-01-01"), publicKey: interKeys.publicKey, signingKey: rootKeys.privateKey, signingAlgorithm: P384,
  });
  return { root, intermediate, interKeys };
}

interface Device {
  keyId: string;
  keyPair: CryptoKeyPair;
  attestation: Uint8Array;
}

async function attestDevice(
  chain: Awaited<ReturnType<typeof testChain>>,
  hash: Uint8Array,
  opts: { aaguid?: string; appId?: string; counter?: number; tamperNonce?: boolean } = {},
): Promise<Device> {
  const keyPair = await crypto.subtle.generateKey(P256, true, ["sign", "verify"]);
  const point = new Uint8Array(await crypto.subtle.exportKey("raw", keyPair.publicKey));
  const keyIdBytes = await sha256(point);
  const aaguid = new Uint8Array(16);
  aaguid.set(new TextEncoder().encode(opts.aaguid ?? "appattestdevelop"));
  const authData = new Uint8Array([
    ...(await sha256(new TextEncoder().encode(opts.appId ?? APP_ID))),
    0x40,
    0, 0, 0, opts.counter ?? 0,
    ...aaguid,
    0, 32,
    ...keyIdBytes,
  ]);
  const nonce = await sha256(authData, opts.tamperNonce ? new Uint8Array([1]) : hash);
  const extension = new x509.Extension(NONCE_EXTENSION_OID, false, new Uint8Array([0x30, 0x24, 0xa1, 0x22, 0x04, 0x20, ...nonce]));
  const leaf = await x509.X509CertificateGenerator.create({
    serialNumber: "03", subject: "CN=Hoja", issuer: chain.intermediate.subject, notBefore: new Date("2026-01-01"),
    notAfter: new Date("2027-01-01"), publicKey: keyPair.publicKey, signingKey: chain.interKeys.privateKey,
    signingAlgorithm: P384, extensions: [extension],
  });
  const attestation = cbor({
    fmt: "apple-appattest",
    attStmt: { x5c: [new Uint8Array(leaf.rawData), new Uint8Array(chain.intermediate.rawData)], receipt: new Uint8Array([1, 2, 3]) },
    authData,
  });
  return { keyId: toBase64(keyIdBytes), keyPair, attestation };
}

async function assert_(device: Device, hash: Uint8Array, counter: number, appId = APP_ID): Promise<Uint8Array> {
  const authenticatorData = new Uint8Array([
    ...(await sha256(new TextEncoder().encode(appId))), 0x40,
    (counter >>> 24) & 0xff, (counter >>> 16) & 0xff, (counter >>> 8) & 0xff, counter & 0xff,
  ]);
  const nonce = await sha256(authenticatorData, hash);
  const raw = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, device.keyPair.privateKey, nonce));
  return cbor({ signature: rawSignatureToDer(raw), authenticatorData });
}

const chain = await testChain();
const rootPem = chain.root.toString("pem");
const body = new TextEncoder().encode('{"mode":"extra"}');
const hash = await clientDataHash("spark", "1792152000", body);

// ---------------------------------------------------------------
// Raíz de Apple
// ---------------------------------------------------------------
Deno.test("raíz de Apple: el PEM embebido es exacto (su autofirma P-384 verifica)", async () => {
  const root = new x509.X509Certificate(APPLE_APP_ATTEST_ROOT_PEM);
  assertEquals(root.subject, "CN=Apple App Attestation Root CA, O=Apple Inc., ST=California");
  assert(await root.verify({ publicKey: root.publicKey, signatureOnly: true }));
  const fingerprint = [...new Uint8Array(await crypto.subtle.digest("SHA-256", root.rawData))]
    .map((b) => b.toString(16).padStart(2, "0")).join("").toUpperCase();
  assertEquals(fingerprint, "1CB9823BA28BA6AD2D33A006941DE2AE4F513EF1D4E831B9F7E0FA7B6242C932");
});

// ---------------------------------------------------------------
// Atestación
// ---------------------------------------------------------------
Deno.test("atestación válida: devuelve la clave pública, contador 0 y el entorno", async () => {
  const device = await attestDevice(chain, hash);
  const key = await verifyAttestation({ attestation: device.attestation, keyId: device.keyId, clientDataHash: hash, appId: APP_ID, allowDevelopment: true, rootPem, now: NOW });
  assertEquals([key.signCount, key.environment, key.receipt], [0, "development", "AQID"]);
});

async function rejects(promise: () => Promise<unknown>, reason: string) {
  const error = await assertRejects(promise, AttestationError);
  assertEquals(error.reason, reason);
}

Deno.test("atestación: otra raíz (la de Apple real) rechaza la cadena de prueba", async () => {
  const device = await attestDevice(chain, hash);
  await rejects(() => verifyAttestation({ attestation: device.attestation, keyId: device.keyId, clientDataHash: hash, appId: APP_ID, allowDevelopment: true, now: NOW }), "chain");
});

Deno.test("atestación: el cuerpo del pedido no coincide (nonce)", async () => {
  const device = await attestDevice(chain, hash, { tamperNonce: true });
  await rejects(() => verifyAttestation({ attestation: device.attestation, keyId: device.keyId, clientDataHash: hash, appId: APP_ID, allowDevelopment: true, rootPem, now: NOW }), "nonce");
});

Deno.test("atestación: otra app, otro keyId, contador distinto de 0 o entorno de desarrollo no permitido", async () => {
  const other = await attestDevice(chain, hash, { appId: "OTRO.app.ajena" });
  await rejects(() => verifyAttestation({ attestation: other.attestation, keyId: other.keyId, clientDataHash: hash, appId: APP_ID, allowDevelopment: true, rootPem, now: NOW }), "app_id");
  const device = await attestDevice(chain, hash);
  const wrongId = toBase64(new Uint8Array(32));
  await rejects(() => verifyAttestation({ attestation: device.attestation, keyId: wrongId, clientDataHash: hash, appId: APP_ID, allowDevelopment: true, rootPem, now: NOW }), "key_id");
  const counted = await attestDevice(chain, hash, { counter: 1 });
  await rejects(() => verifyAttestation({ attestation: counted.attestation, keyId: counted.keyId, clientDataHash: hash, appId: APP_ID, allowDevelopment: true, rootPem, now: NOW }), "counter");
  await rejects(() => verifyAttestation({ attestation: device.attestation, keyId: device.keyId, clientDataHash: hash, appId: APP_ID, allowDevelopment: false, rootPem, now: NOW }), "aaguid");
  const prod = await attestDevice(chain, hash, { aaguid: "appattest" });
  const key = await verifyAttestation({ attestation: prod.attestation, keyId: prod.keyId, clientDataHash: hash, appId: APP_ID, allowDevelopment: false, rootPem, now: NOW });
  assertEquals(key.environment, "production");
});

Deno.test("atestación: certificado vencido y basura CBOR", async () => {
  const device = await attestDevice(chain, hash);
  await rejects(() => verifyAttestation({ attestation: device.attestation, keyId: device.keyId, clientDataHash: hash, appId: APP_ID, allowDevelopment: true, rootPem, now: new Date("2028-01-01") }), "certificate_expired");
  await rejects(() => verifyAttestation({ attestation: new Uint8Array([0xff, 0x00]), keyId: device.keyId, clientDataHash: hash, appId: APP_ID, allowDevelopment: true, rootPem, now: NOW }), "cbor");
});

// ---------------------------------------------------------------
// Aserción
// ---------------------------------------------------------------
Deno.test("aserción: firma válida y contador que sube; repetida o ajena no pasa", async () => {
  const device = await attestDevice(chain, hash);
  const key = await verifyAttestation({ attestation: device.attestation, keyId: device.keyId, clientDataHash: hash, appId: APP_ID, allowDevelopment: true, rootPem, now: NOW });
  const assertion = await assert_(device, hash, 1);
  assertEquals(await verifyAssertion({ assertion, clientDataHash: hash, publicKey: key.publicKey, previousCount: 0, appId: APP_ID }), { signCount: 1 });
  // La misma aserción otra vez (replay): el contador no subió.
  await rejects(() => verifyAssertion({ assertion, clientDataHash: hash, publicKey: key.publicKey, previousCount: 1, appId: APP_ID }), "counter");
  // Otro cuerpo: la firma no corresponde.
  const otherHash = await clientDataHash("spark", "1792152000", new TextEncoder().encode('{"mode":"pick"}'));
  await rejects(() => verifyAssertion({ assertion, clientDataHash: otherHash, publicKey: key.publicKey, previousCount: 0, appId: APP_ID }), "signature");
  // Otra clave.
  const stranger = await attestDevice(chain, hash);
  const strangerKey = await verifyAttestation({ attestation: stranger.attestation, keyId: stranger.keyId, clientDataHash: hash, appId: APP_ID, allowDevelopment: true, rootPem, now: NOW });
  await rejects(() => verifyAssertion({ assertion, clientDataHash: hash, publicKey: strangerKey.publicKey, previousCount: 0, appId: APP_ID }), "signature");
});

// ---------------------------------------------------------------
// Guarda de los endpoints (con una base en memoria)
// ---------------------------------------------------------------
function memoryDb() {
  const rows = new Map<string, Record<string, unknown>>();
  // deno-lint-ignore no-explicit-any
  const query = (): any => {
    const filters: Array<(r: Record<string, unknown>) => boolean> = [];
    let patch: Record<string, unknown> | null = null;
    let insert: Record<string, unknown> | null = null;
    const run = () => {
      if (insert) {
        if (rows.has(String(insert.key_id))) return { data: null, error: { message: "duplicate" } };
        rows.set(String(insert.key_id), { ...insert });
        return { data: null, error: null };
      }
      const matched = [...rows.values()].filter((r) => filters.every((f) => f(r)));
      if (patch) for (const r of matched) Object.assign(r, patch);
      return { data: matched.map((r) => ({ ...r })), error: null };
    };
    const builder = {
      select: () => builder,
      eq: (col: string, v: unknown) => (filters.push((r) => r[col] === v), builder),
      lt: (col: string, v: number) => (filters.push((r) => Number(r[col]) < v), builder),
      update: (p: Record<string, unknown>) => ((patch = p), builder),
      insert: (row: Record<string, unknown>) => ((insert = row), Promise.resolve(run())),
      maybeSingle: () => Promise.resolve({ data: run().data?.[0] ?? null, error: null }),
      then: (resolve: (v: unknown) => void) => resolve(run()),
    };
    return builder;
  };
  return { rows, client: { from: query } as unknown as SupabaseClient };
}

function signedRequest(headers: Record<string, string>, raw = body): Request {
  return new Request("http://localhost/functions/v1/spark", { method: "POST", body: raw, headers });
}

const env = (values: Record<string, string>) => (name: string) => values[name];
const time = String(Math.floor(NOW.getTime() / 1000));

Deno.test("guarda: off no mira nada; enforce sin firma corta con attestation_failed", async () => {
  await requireDeviceIntegrity(signedRequest({}), "spark", "u1", { env: env({}) });
  const error = await assertRejects(
    () => requireDeviceIntegrity(signedRequest({}), "spark", "u1", { env: env({ LUMBRE_ATTESTATION: "enforce" }), now: NOW }),
    ApiError,
  );
  assertEquals(error.code, "attestation_failed");
  // report: verifica y loguea, pero deja pasar.
  await requireDeviceIntegrity(signedRequest({}), "spark", "u1", { env: env({ LUMBRE_ATTESTATION: "report" }), now: NOW });
});

Deno.test("guarda: atestación y después aserciones, con el protocolo de la app de iOS", async () => {
  const db = memoryDb();
  const settings = env({ APP_ATTEST_APP_ID: APP_ID, APPLE_APP_ATTEST_ROOT_PEM: rootPem });
  const requestHash = await clientDataHash("spark", time, body);
  const device = await attestDevice(chain, requestHash);
  const first = await verifyRequest(signedRequest({
    "X-Lumbre-Attest-Key": device.keyId, "X-Lumbre-Attest-Time": time, "X-Lumbre-Attestation": toBase64(device.attestation),
  }), "spark", "u1", { db: db.client, env: settings, now: NOW });
  assertEquals(first, { ok: true, platform: "ios", reason: null });
  assertEquals(db.rows.get(device.keyId)?.environment, "development");

  // La misma atestación otra vez: replay.
  const again = await verifyRequest(signedRequest({
    "X-Lumbre-Attest-Key": device.keyId, "X-Lumbre-Attest-Time": time, "X-Lumbre-Attestation": toBase64(device.attestation),
  }), "spark", "u1", { db: db.client, env: settings, now: NOW });
  assertEquals(again.reason, "key_exists");

  const assertion = toBase64(await assert_(device, requestHash, 1));
  const ok = await verifyRequest(signedRequest({ "X-Lumbre-Attest-Key": device.keyId, "X-Lumbre-Attest-Time": time, "X-Lumbre-Assertion": assertion }), "spark", "u1", { db: db.client, env: settings, now: NOW });
  assertEquals(ok.ok, true);
  assertEquals(db.rows.get(device.keyId)?.sign_count, 1);
  const replay = await verifyRequest(signedRequest({ "X-Lumbre-Attest-Key": device.keyId, "X-Lumbre-Attest-Time": time, "X-Lumbre-Assertion": assertion }), "spark", "u1", { db: db.client, env: settings, now: NOW });
  assertEquals(replay.reason, "counter");
  // Mismo pedido firmado para otra función: no sirve.
  const wrongFn = await verifyRequest(signedRequest({ "X-Lumbre-Attest-Key": device.keyId, "X-Lumbre-Attest-Time": time, "X-Lumbre-Assertion": toBase64(await assert_(device, requestHash, 2)) }), "planner", "u1", { db: db.client, env: settings, now: NOW });
  assertEquals(wrongFn.reason, "signature");
  // Un tiempo de hace una hora no entra.
  const stale = await verifyRequest(signedRequest({ "X-Lumbre-Attest-Key": device.keyId, "X-Lumbre-Attest-Time": String(Number(time) - 3600), "X-Lumbre-Assertion": assertion }), "spark", "u1", { db: db.client, env: settings, now: NOW });
  assertEquals(stale.reason, "stale");
  // Clave desconocida y falta de configuración.
  const unknown = await verifyRequest(signedRequest({ "X-Lumbre-Attest-Key": toBase64(new Uint8Array(32)), "X-Lumbre-Attest-Time": time, "X-Lumbre-Assertion": assertion }), "spark", "u1", { db: db.client, env: settings, now: NOW });
  assertEquals(unknown.reason, "unknown_key");
  const unconfigured = await verifyRequest(signedRequest({ "X-Lumbre-Attest-Key": device.keyId, "X-Lumbre-Attest-Time": time, "X-Lumbre-Assertion": assertion }), "spark", "u1", { db: db.client, env: env({}), now: NOW });
  assertEquals(unconfigured.reason, "not_configured");
});

// ---------------------------------------------------------------
// Play Integrity
// ---------------------------------------------------------------
const GOOD: IntegrityVerdict = {
  requestDetails: { requestPackageName: "app.lumbre.android", requestHash: "abc123", timestampMillis: String(NOW.getTime() - 1000) },
  appIntegrity: { appRecognitionVerdict: "PLAY_RECOGNIZED", packageName: "app.lumbre.android" },
  deviceIntegrity: { deviceRecognitionVerdict: ["MEETS_DEVICE_INTEGRITY"] },
};
const CHECK = { requestHash: "abc123", packageName: "app.lumbre.android", now: NOW };

Deno.test("Play Integrity: veredicto bueno pasa; cada campo malo tiene su motivo", () => {
  checkVerdict(GOOD, CHECK);
  const cases: Array<[IntegrityVerdict, string]> = [
    [{ ...GOOD, requestDetails: { ...GOOD.requestDetails, requestPackageName: "otra.app" } }, "package"],
    [{ ...GOOD, requestDetails: { ...GOOD.requestDetails, requestHash: "otro" } }, "request_hash"],
    [{ ...GOOD, requestDetails: { ...GOOD.requestDetails, timestampMillis: String(NOW.getTime() - 3_600_000) } }, "stale"],
    [{ ...GOOD, appIntegrity: { appRecognitionVerdict: "UNRECOGNIZED_VERSION" } }, "app_not_recognized"],
    [{ ...GOOD, deviceIntegrity: { deviceRecognitionVerdict: ["MEETS_BASIC_INTEGRITY"] } }, "device_integrity"],
    [{ ...GOOD, deviceIntegrity: {} }, "device_integrity"],
  ];
  for (const [verdict, reason] of cases) {
    try {
      checkVerdict(verdict, CHECK);
      throw new Error(`pasó: ${reason}`);
    } catch (error) {
      assertEquals((error as AttestationError).reason, reason);
    }
  }
  checkVerdict({ ...GOOD, deviceIntegrity: { deviceRecognitionVerdict: ["MEETS_BASIC_INTEGRITY"] } }, { ...CHECK, allowBasic: true });
});

Deno.test("Play Integrity: firma el JWT de la cuenta de servicio y llama a decodeIntegrityToken", async () => {
  const keys = await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" }, true, ["sign", "verify"],
  );
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey("pkcs8", keys.privateKey));
  const pem = `-----BEGIN PRIVATE KEY-----\n${toBase64(pkcs8)}\n-----END PRIVATE KEY-----\n`;
  const calls: string[] = [];
  const fakeFetch = (async (input: string | URL | Request, init?: RequestInit) => {
    const url = String(input);
    calls.push(url);
    if (url.includes("oauth2")) {
      const assertion = new URLSearchParams(String(init?.body)).get("assertion")!;
      const [h, p, s] = assertion.split(".");
      const decode = (v: string) => Uint8Array.from(atob(v.replace(/-/g, "+").replace(/_/g, "/") + "==".slice((v.length + 2) % 4 === 0 ? 2 : 0)), (c) => c.charCodeAt(0));
      const valid = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", keys.publicKey, decode(s), new TextEncoder().encode(`${h}.${p}`));
      assert(valid, "el JWT tiene que estar firmado con la clave de la cuenta de servicio");
      return new Response(JSON.stringify({ access_token: "ya29.prueba", expires_in: 3600 }));
    }
    assertEquals((init?.headers as Record<string, string>).Authorization, "Bearer ya29.prueba");
    assertEquals(JSON.parse(String(init?.body)), { integrity_token: "token-de-prueba" });
    return new Response(JSON.stringify({ tokenPayloadExternal: GOOD }));
  }) as typeof fetch;
  const verdict = await decodeIntegrityToken({
    token: "token-de-prueba", requestHash: "abc123", packageName: "app.lumbre.android",
    account: { client_email: "lumbre@proyecto.iam.gserviceaccount.com", private_key: pem }, now: NOW, fetchImpl: fakeFetch,
  });
  assertEquals(verdict.appIntegrity?.appRecognitionVerdict, "PLAY_RECOGNIZED");
  assertEquals(calls, ["https://oauth2.googleapis.com/token", "https://playintegrity.googleapis.com/v1/app.lumbre.android:decodeIntegrityToken"]);
});
