// Contrato OpenAPI (paso 39): backend/openapi.yaml tiene que coincidir con las Edge Functions reales.
//
// - Cada función de la app tiene su path y cada path tiene su función (las de la web pública quedan afuera).
// - Los códigos de error del contrato (x-error-codes) son exactamente los de _shared/http.ts, con el mismo status.
// - Cada error que una función puede lanzar (ApiError("…") en su código, más los de la base y la guarda de integridad)
//   está documentado en las respuestas de su path. 401 y 500 valen para todas (descriptos en info).
// - verify_jwt de config.toml coincide con la seguridad del path (token de usuario o secreto propio).
// - Los campos que lee cada función del cuerpo están en el schema del pedido.
// La forma de las respuestas se valida contra los schemas en tests/functions/e2e.sh (validate-response.ts).

import { assert, assertEquals } from "jsr:@std/assert@1";
import { parse } from "jsr:@std/yaml@1";
import { errorStatus } from "../_shared/http.ts";

const functionsDir = new URL("../", import.meta.url);
const backendDir = new URL("../../../", import.meta.url);
// deno-lint-ignore no-explicit-any
const spec = parse(await Deno.readTextFile(new URL("openapi.yaml", backendDir))) as any;
const config = await Deno.readTextFile(new URL("supabase/config.toml", backendDir));

/** Funciones de la web pública (landing y demo): tienen su propio contrato informal en web/, no son de la app. */
const WEB_FUNCTIONS = new Set(["waitlist", "demo-spark"]);
/** Las que usan requireDeviceIntegrity (paso 40). */
const ATTESTED = new Set(["capture", "today", "spark", "search", "planner"]);
/** Errores que vienen de la base (RPCs con el JWT del usuario) y no aparecen como ApiError en el código. */
const DB_ERRORS: Record<string, string[]> = {
  capture: ["quota_exceeded", "import_limit", "too_many_categories", "invalid_thesis", "invalid_category", "invalid_source"],
};

async function appFunctions(): Promise<string[]> {
  const names: string[] = [];
  for await (const entry of Deno.readDir(functionsDir)) {
    if (!entry.isDirectory || entry.name.startsWith("_") || WEB_FUNCTIONS.has(entry.name)) continue;
    try {
      await Deno.stat(new URL(`${entry.name}/index.ts`, functionsDir));
      names.push(entry.name);
    } catch {
      // carpeta sin index.ts: no es una función
    }
  }
  return names.sort();
}

const functions = await appFunctions();
const sources = Object.fromEntries(
  await Promise.all(functions.map(async (fn) => [fn, await Deno.readTextFile(new URL(`${fn}/index.ts`, functionsDir))])),
) as Record<string, string>;

Deno.test("cada función de la app tiene su path y cada path su función", () => {
  const paths = Object.keys(spec.paths).map((p) => p.replace(/^\//, "")).sort();
  assertEquals(paths, functions);
  for (const fn of functions) assert(spec.paths[`/${fn}`].post, `/${fn}: es POST`);
});

Deno.test("los códigos de error del contrato son los de _shared/http.ts", () => {
  assertEquals(spec.components.schemas.Error["x-error-codes"], { ...errorStatus });
  for (const code of Object.keys(errorStatus)) {
    assert(spec.components.schemas.Error.properties.error.description.includes(code), `descripción de Error: falta ${code}`);
  }
});

Deno.test("cada error que puede lanzar una función está en las respuestas de su path", () => {
  for (const fn of functions) {
    const source = sources[fn];
    const codes = new Set([...source.matchAll(/ApiError\("([a-z_]+)"\)/g)].map((m) => m[1]));
    if (source.includes("readJson")) codes.add("invalid_request");
    if (source.includes("requireDeviceIntegrity")) codes.add("attestation_failed");
    if (source.includes("requireAIConsent(")) codes.add("ai_consent_required");
    for (const code of DB_ERRORS[fn] ?? []) codes.add(code);
    const documented = Object.keys(spec.paths[`/${fn}`].post.responses ?? {});
    for (const code of codes) {
      const status = String(errorStatus[code as keyof typeof errorStatus]);
      if (status === "401" || status === "500") continue;
      assert(documented.includes(status), `/${fn}: lanza ${code} (${status}) y el contrato no lo documenta`);
    }
  }
});

Deno.test("la guarda de integridad está en las funciones de IA de la app", () => {
  for (const fn of functions) {
    assertEquals(sources[fn].includes("requireDeviceIntegrity(req,"), ATTESTED.has(fn), `/${fn}`);
  }
});

Deno.test("las funciones que mandan contenido del usuario a la IA piden su consentimiento", () => {
  // spark y planner cortan con 403; capture guarda sin destilar y today no genera la diaria.
  for (const fn of ["spark", "planner"]) assert(sources[fn].includes("await requireAIConsent(user.id)"), `/${fn}`);
  for (const fn of ["capture", "today"]) assert(sources[fn].includes("hasAIConsent(user.id)"), `/${fn}`);
});

Deno.test("verify_jwt de config.toml coincide con la seguridad del contrato", () => {
  for (const fn of functions) {
    const match = config.match(new RegExp(`\\[functions\\.${fn}\\]\\s*\\nverify_jwt\\s*=\\s*(true|false)`));
    assert(match, `config.toml: falta [functions.${fn}]`);
    const security = spec.paths[`/${fn}`].post.security ?? spec.security;
    const userToken = security.some((s: Record<string, unknown>) => "userToken" in s);
    assertEquals(match[1] === "true", userToken, `/${fn}: verify_jwt=${match[1]} y la seguridad es ${JSON.stringify(security)}`);
    if (!userToken) {
      assert(/requireService\(req\)|authorized\(req\)/.test(sources[fn]), `/${fn}: sin JWT tiene que validar su propio secreto`);
    }
  }
});

Deno.test("los campos que lee cada función del cuerpo están en el schema del pedido", () => {
  for (const fn of functions) {
    const fields = new Set([...sources[fn].matchAll(/\bbody\.([a-z_]+)/g)].map((m) => m[1]));
    // /capture lee el cuerpo por su interfaz CaptureBody.
    const iface = sources[fn].match(/interface CaptureBody \{([\s\S]*?)\n\}/);
    if (iface) for (const m of iface[1].matchAll(/^\s+([a-z_]+)\?:/gm)) fields.add(m[1]);
    fields.delete("event"); // webhook: el cuerpo es de RevenueCat
    const schema = spec.paths[`/${fn}`].post.requestBody?.content?.["application/json"]?.schema;
    const properties = Object.keys(schema?.properties ?? {});
    for (const field of fields) assert(properties.includes(field), `/${fn}: lee body.${field} y el contrato no lo tiene`);
  }
});
