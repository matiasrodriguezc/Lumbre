// Valida una respuesta real contra el contrato (paso 39). Lo usa tests/functions/e2e.sh:
//   echo "$BODY" | deno run -A supabase/functions/_tests/validate-response.ts /today 200
// Sale con 0 si la respuesta cumple el schema de ese path y status; si no, imprime los errores y sale con 1.

import Ajv2020 from "npm:ajv@8.17.1/dist/2020.js";
import addFormats from "npm:ajv-formats@3.0.1";
import { parse } from "jsr:@std/yaml@1";

export async function responseValidator(path: string, status: string) {
  // deno-lint-ignore no-explicit-any
  const spec = parse(await Deno.readTextFile(new URL("../../../openapi.yaml", import.meta.url))) as any;
  const response = spec.paths[path]?.post?.responses?.[status];
  if (!response) throw new Error(`el contrato no tiene ${path} ${status}`);
  const resolved = response.$ref ? spec.components.responses[response.$ref.split("/").pop()] : response;
  const schema = resolved.content?.["application/json"]?.schema;
  if (!schema) throw new Error(`${path} ${status} no tiene schema JSON`);
  // deno-lint-ignore no-explicit-any
  const ajv = new (Ajv2020 as any)({ strict: false, allErrors: true });
  // deno-lint-ignore no-explicit-any
  (addFormats as any)(ajv);
  ajv.addSchema({ $id: "openapi", components: spec.components });
  const rewrite = (value: unknown): unknown =>
    Array.isArray(value)
      ? value.map(rewrite)
      : value && typeof value === "object"
      ? Object.fromEntries(Object.entries(value).map(([k, v]) => [k, k === "$ref" && typeof v === "string" ? `openapi${v}` : rewrite(v)]))
      : value;
  return ajv.compile(rewrite(schema));
}

if (import.meta.main) {
  const [path, status = "200"] = Deno.args;
  const validate = await responseValidator(path, status);
  const body = JSON.parse(await new Response(Deno.stdin.readable).text());
  if (validate(body)) Deno.exit(0);
  console.error(JSON.stringify(validate.errors, null, 2).slice(0, 2000));
  Deno.exit(1);
}
