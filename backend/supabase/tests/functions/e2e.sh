#!/usr/bin/env bash
# Edge Functions de punta a punta contra el stack local, como las usa la app (contrato en backend/openapi.yaml):
#   1. Un invitado guarda 6 conceptos de categorías distintas (/capture) y, cuando acepta la IA, Hoy le da su chispa diaria.
#   2. Como invitado no puede pedir chispas extra; crea su cuenta (email de Mailpit) y pasa a free.
#   3. Con 6 conceptos guardados hoy ganó extras: pide una (/spark). Busca en su bóveda (/search).
#   4. Pasa a Pro con /dev-plan y usa el planificador en streaming (/planner). Revoca el consentimiento: nada va a la IA.
#   5. Proyecto, push, reporte, export de sus datos y borrado de la cuenta (RPCs con su sesión).
#   6. Ana (seed) después de /process: Hoy, búsqueda y extra.
#   7. Funciones internas y webhook: sin clave no entran; con la clave de servicio responden.
# Uso: backend/supabase/tests/functions/e2e.sh
#   con `supabase start` y `supabase functions serve` corriendo (y LUMBRE_DEV_TOOLS=true en supabase/functions/.env).
set -euo pipefail
cd "$(dirname "$0")/../../.."

eval "$(supabase status -o env 2>/dev/null | grep -E '^(API_URL|ANON_KEY|SERVICE_ROLE_KEY|DB_URL|MAILPIT_URL|INBUCKET_URL)=')"
MAIL_URL="${MAILPIT_URL:-${INBUCKET_URL:-http://127.0.0.1:55524}}"
FN="$API_URL/functions/v1"
RUN="$(date +%s)"
EMAIL="e2e-funciones-$RUN@lumbre.test"
FAILED=0
TOKEN=""
USER_ID=""

check() { if [[ "$2" == "$3" ]]; then echo "ok   $1"; else echo "FALLÓ $1 (esperado: $3, obtenido: $2)"; FAILED=1; fi; }
check_true() { if [[ "$2" == "true" ]]; then echo "ok   $1"; else echo "FALLÓ $1 (obtenido: $2)"; FAILED=1; fi; }
auth() { curl -s "$API_URL/auth/v1/$1" -H "apikey: $ANON_KEY" -H "Content-Type: application/json" "${@:2}"; }
rest() { curl -s "$API_URL/rest/v1/$1" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" "${@:2}"; }
# Llama una Edge Function; deja el cuerpo en $BODY y el status en $STATUS.
call() {
  local out
  out="$(curl -s -w '\n%{http_code}' -X POST "$FN/$1" -H "apikey: $ANON_KEY" -H "Authorization: Bearer ${3:-$TOKEN}" \
    -H "Content-Type: application/json" -d "${2:-{\}}")"
  STATUS="${out##*$'\n'}"
  BODY="${out%$'\n'*}"
}
capture() {
  call capture "$(jq -nc --arg t "$1" --arg c "$2" --argjson d "${3:-false}" '{thesis: $t, category: $c, source_type: "text", distill: $d}')"
}
# La respuesta cumple el contrato (backend/openapi.yaml) para ese path y status.
valid() {
  if echo "$BODY" | deno run -A --quiet supabase/functions/_tests/validate-response.ts "$1" "${2:-200}" >/tmp/lumbre-contract.$$ 2>&1; then
    echo "ok   contrato: $1 $STATUS cumple el schema"
  else
    echo "FALLÓ contrato: $1 $STATUS no cumple el schema"; cat /tmp/lumbre-contract.$$; FAILED=1
  fi
  rm -f /tmp/lumbre-contract.$$
}
# Sube un archivo a capture-temp con la sesión del usuario (como la app). Deja el status en $STATUS.
upload() {
  STATUS="$(curl -s -o /dev/null -w '%{http_code}' -X POST "$API_URL/storage/v1/object/capture-temp/$1" -H "apikey: $ANON_KEY" \
    -H "Authorization: Bearer $TOKEN" -H "Content-Type: $2" --data-binary "@$3")"
}
in_storage() { psql "$DB_URL" -tAXc "select count(*) from storage.objects where bucket_id = 'capture-temp' and name = '$1'"; }
mail_link() {
  local id=""
  for _ in $(seq 1 20); do
    id="$(curl -s "$MAIL_URL/api/v1/search?query=to:$1" | jq -r '.messages[0].ID // empty')"
    [[ -n "$id" ]] && break
    sleep 0.5
  done
  curl -s "$MAIL_URL/api/v1/message/$id" | jq -r '.HTML' | grep -o 'href="[^"]*/auth/v1/verify[^"]*"' | head -1 | sed -e 's/^href="//' -e 's/"$//' -e 's/&amp;/\&/g'
}
cleanup() { psql "$DB_URL" -qXc "delete from auth.users where email = '$EMAIL' or id = '${USER_ID:-00000000-0000-0000-0000-000000000000}'" >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "== 1. Invitado: captura y chispa diaria"
# Con el stack cargado, Auth a veces tarda: se reintenta el alta.
for _ in 1 2 3; do
  R="$(auth signup -d '{"data": {"timezone": "America/Argentina/Buenos_Aires", "locale": "es-AR"}}')"
  [[ "$(echo "$R" | jq -r '.access_token // empty')" != "" ]] && break
done
TOKEN="$(echo "$R" | jq -r .access_token)"
REFRESH="$(echo "$R" | jq -r .refresh_token)"
USER_ID="$(echo "$R" | jq -r .user.id)"
check "entra como invitado" "$(echo "$R" | jq -r .user.is_anonymous)" "true"

capture "El tiempo transforma ingredientes simples en sabores complejos sin agregar nada." "Cocina"
check "capture: guarda el primer concepto" "$STATUS" "200"
check "capture: crea la categoría" "$(echo "$BODY" | jq -r .category_created)" "true"
check "capture: sin destilar" "$(echo "$BODY" | jq -r .distillation)" "none"
check "capture: devuelve el concepto con la forma del contrato" \
  "$(echo "$BODY" | jq -r '.concepts[0] | [has("id"), has("title"), has("status"), has("from_library"), has("category")] | all')" "true"
check_true "capture: la categoría quedó clasificada en un dominio" "$(echo "$BODY" | jq -r '.concepts[0].category.domain.slug != null')"
check "capture: la categoría Cocina cae en el dominio cocina (embedding)" "$(echo "$BODY" | jq -r '.concepts[0].category.domain.slug')" "cocina"
valid /capture
capture "Un flujo en espiral separa partículas por fuerza centrífuga, sin necesidad de filtro." "Ingeniería"
capture "Los silencios marcan el ritmo de una canción tanto como las notas que suenan." "Música"
capture "Pequeñas ganancias que se reinvierten crecen de forma exponencial con el paso del tiempo." "Finanzas"
capture "Los hongos conectan las raíces de un bosque y reparten nutrientes entre árboles distintos." "Naturaleza"
# Consentimiento para la IA (profiles.ai_consent_at): sin el "Acepto", Hoy no genera la diaria.
call today
check "today: sin consentimiento para la IA no genera la diaria" "$STATUS|$(echo "$BODY" | jq -r .spark)" "200|null"
rest "profiles?id=eq.$USER_ID" -X PATCH -d '{"ai_consent_at": "2001-01-01T00:00:00Z"}' >/dev/null
check "profiles: la app guarda el Acepto y la fecha la pone el servidor" \
  "$(rest "profiles?select=ai_consent_at&id=eq.$USER_ID" | jq -r '.[0].ai_consent_at[0:4]')" "$(date -u +%Y)"
LONG="Revisar los cambios de código en pares reduce errores y reparte el conocimiento del sistema entre todo el equipo. Cuando dos personas leen el mismo cambio aparecen preguntas que el autor no se hizo, y esas preguntas suelen esconder los errores más caros. Además, quien revisa aprende cómo funciona una parte que no conocía, así que el conocimiento deja de estar en una sola cabeza."
capture "$LONG" "Software" true
check "capture: el sexto concepto se guarda" "$STATUS" "200"
check "capture: un invitado no tiene destilación (la pide y no hay cupo)" "$(echo "$BODY" | jq -r .distillation)" "quota_exceeded"
call capture '{"category": "Links", "source_type": "link", "source_url": "https://ejemplo.invalid/nota"}'
check "capture: un link sin idea y sin destilación pide la tesis (422)" "$STATUS|$(echo "$BODY" | jq -r .error)" "422|needs_thesis"
call capture '{"thesis": "x", "category": "", "source_type": "text"}'
check "capture: sin categoría da invalid_category (400)" "$STATUS|$(echo "$BODY" | jq -r .error)" "400|invalid_category"
valid /capture 400

call today
check "today: responde" "$STATUS" "200"
valid /today
check "today: hay chispa diaria" "$(echo "$BODY" | jq -r '.spark.mode')" "daily"
check "today: la chispa está sin abrir" "$(echo "$BODY" | jq -r '.spark.status')" "pending"
check_true "today: la chispa tiene título y cuerpo" "$(echo "$BODY" | jq -r '(.spark.title | length) > 0 and (.spark.body | length) > 0')"
check_true "today: los dos conceptos son de categorías distintas" \
  "$(echo "$BODY" | jq -r '.spark.concept_a.category.id != .spark.concept_b.category.id')"
check "today: cuenta los conceptos" "$(echo "$BODY" | jq -r .concept_count)" "6"
check "today: la diaria está disponible (sin extras de invitado)" "$(echo "$BODY" | jq -r '.quota.available')" "1"
check_true "today: trae la próxima recarga y los días de pares" "$(echo "$BODY" | jq -r '(.quota.refills_at | length) > 0 and (.runway_days | type) == "number"')"
DAILY_ID="$(echo "$BODY" | jq -r .spark.id)"
call today
check "today: una segunda llamada devuelve la misma chispa" "$(echo "$BODY" | jq -r .spark.id)" "$DAILY_ID"

echo "== 2. Invitado sin extras; crea su cuenta"
call spark '{"mode": "extra"}'
check "spark: el invitado necesita cuenta (403)" "$STATUS|$(echo "$BODY" | jq -r .error)" "403|account_required"
call planner "{\"spark_id\": \"$DAILY_ID\", \"message\": \"Hola\", \"mode\": \"quick\"}"
check "planner: el invitado necesita cuenta (403)" "$STATUS|$(echo "$BODY" | jq -r .error)" "403|account_required"
auth user -X PUT -H "Authorization: Bearer $TOKEN" -d "{\"email\": \"$EMAIL\"}" >/dev/null
curl -s -o /dev/null "$(mail_link "$EMAIL")"
R="$(auth "token?grant_type=refresh_token" -d "{\"refresh_token\": \"$REFRESH\"}")"
TOKEN="$(echo "$R" | jq -r .access_token)"
check "vincula el email y deja de ser invitado" "$(echo "$R" | jq -r .user.is_anonymous)" "false"

echo "== 3. Free: chispa extra ganada y búsqueda"
call today
check "today: con 6 conceptos de hoy ganó 2 extras" "$(echo "$BODY" | jq -r '.quota.extra_remaining')" "2"
check "today: no le falta nada para la próxima extra (llegó al tope)" "$(echo "$BODY" | jq -r '.quota.concepts_until_extra')" "0"
call spark '{"mode": "extra"}'
check "spark: pide una extra" "$STATUS" "200"
valid /spark
check "spark: es extra y está sin abrir" "$(echo "$BODY" | jq -r '.spark.mode + "|" + .spark.status')" "extra|pending"
EXTRA_ID="$(echo "$BODY" | jq -r .spark.id)"
call spark "{\"mode\": \"pick\", \"concept_ids\": [\"$(echo "$BODY" | jq -r .spark.concept_a.id)\", \"$(echo "$BODY" | jq -r .spark.concept_b.id)\"]}"
check "spark: elegir conceptos es de Pro (402)" "$STATUS|$(echo "$BODY" | jq -r .error)" "402|pro_required"
call today
check "today: la extra aparece en extras" "$(echo "$BODY" | jq -r '.extras[0].id')" "$EXTRA_ID"
check "today: queda una extra" "$(echo "$BODY" | jq -r '.quota.extra_remaining')" "1"
call search '{"query": "fermentación de ingredientes y sabores"}'
check "search: responde" "$STATUS" "200"
check "search: lo más cercano es el de cocina" "$(echo "$BODY" | jq -r '.concepts[0].category.name')" "Cocina"
valid /search

echo "== 3b. Destilación, imágenes y PDFs (pasos 25 y 34)"
capture "$LONG Por eso conviene que cada cambio tenga al menos una persona que lo lea antes de llegar a producción." "Equipos" true
check "capture: un texto de 30+ palabras se destila (free tiene cupo)" "$STATUS|$(echo "$BODY" | jq -r .distillation)" "200|medium"
check "capture: confianza media queda como borrador destilado" "$(echo "$BODY" | jq -r '.concepts[0] | "\(.status)|\(.distilled)|\(.confidence)"')" "draft|true|medium"
FIXTURES="$(mktemp -d)"
printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==' | base64 -d > "$FIXTURES/punto.png"
printf '%%PDF-1.4\n1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj\n3 0 obj << /Type /Page /Parent 2 0 R >> endobj\ntrailer << /Root 1 0 R >>\n%%%%EOF\n' > "$FIXTURES/nota.pdf"
IMG="$USER_ID/$(uuidgen | tr 'A-Z' 'a-z').png"
upload "$IMG" image/png "$FIXTURES/punto.png"
check "storage: la app sube la imagen a su carpeta de capture-temp" "$STATUS" "200"
call capture "$(jq -nc --arg p "$IMG" '{thesis: "Una foto de una pizarra con un diagrama de flujo", category: "Fotos", source_type: "image", attachment: {path: $p, mime_type: "image/png"}, distill: true}')"
check "capture: imagen con su idea (el proveedor local no lee imágenes: confianza baja)" "$STATUS|$(echo "$BODY" | jq -r '.concepts[0].source_type')" "200|image"
check "capture: la imagen ya no está en Storage" "$(in_storage "$IMG")" "0"
check "capture: sin destilación útil no gasta el cupo de destilación (quedan 5 - 1)" \
  "$(rest "rpc/credit_status" -X POST -d '{}' | jq -r '.[] | select(.kind == "distill") | .remaining')" "4"
PDF="$USER_ID/$(uuidgen | tr 'A-Z' 'a-z').pdf"
upload "$PDF" application/pdf "$FIXTURES/nota.pdf"
call capture "$(jq -nc --arg p "$PDF" '{category: "Lecturas", source_type: "pdf", attachment: {path: $p, mime_type: "application/pdf"}, distill: true}')"
check "capture: un PDF sin idea que no se pudo destilar pide la tesis (422)" "$STATUS|$(echo "$BODY" | jq -r .error)" "422|needs_thesis"
check "capture: el PDF se borra también cuando falla" "$(in_storage "$PDF")" "0"
call capture "$(jq -nc '{thesis: "x", category: "Fotos", source_type: "image", attachment: {path: "22222222-2222-2222-2222-222222222222/ajena.png", mime_type: "image/png"}}')"
check "capture: no puede usar un archivo de la carpeta de otro (400)" "$STATUS|$(echo "$BODY" | jq -r .error)" "400|invalid_source"
ORPHAN="$USER_ID/$(uuidgen | tr 'A-Z' 'a-z').png"
upload "$ORPHAN" image/png "$FIXTURES/punto.png"
psql "$DB_URL" -qXc "update storage.objects set created_at = now() - interval '2 hours' where name = '$ORPHAN'" >/dev/null
call process '{}' "$SERVICE_ROLE_KEY"
check "process: borra los adjuntos huérfanos de más de una hora" "$STATUS|$(in_storage "$ORPHAN")|$(echo "$BODY" | jq -r '.stale_uploads >= 1')" "200|0|true"
rm -rf "$FIXTURES"
call search '{"query": ""}'
check "search: una consulta vacía es invalid_request" "$STATUS|$(echo "$BODY" | jq -r .error)" "400|invalid_request"

echo "== 4. Pro y planificador"
call planner "{\"spark_id\": \"$DAILY_ID\", \"message\": \"Hola\", \"mode\": \"quick\"}"
check "planner: free no tiene planificador (402)" "$STATUS|$(echo "$BODY" | jq -r .error)" "402|pro_required"
call dev-plan '{"plan": "pro"}'
check "dev-plan: pasa a Pro" "$STATUS|$(echo "$BODY" | jq -r .plan)" "200|pro"
SSE="$(curl -sN -X POST "$FN/planner" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "{\"spark_id\": \"$DAILY_ID\", \"message\": \"Armame un backlog\", \"mode\": \"quick\"}")"
check_true "planner: llegan varios eventos delta" "$([[ "$(echo "$SSE" | grep -c '^event: delta')" -gt 3 ]] && echo true || echo false)"
check_true "planner: termina con done y el id del mensaje" "$(echo "$SSE" | grep -A1 '^event: done' | grep -q '"message_id"' && echo true || echo false)"
check "planner: guardó la pregunta y la respuesta" "$(rest "planner_messages?select=role&order=id" | jq -r 'map(.role) | join(",")')" "user,assistant"
check_true "planner: la respuesta es el backlog" "$(rest "planner_messages?select=content&role=eq.assistant" | jq -r '.[0].content | startswith("Backlog")')"
SSE="$(curl -sN -X POST "$FN/planner" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "{\"spark_id\": \"$DAILY_ID\", \"message\": \"Hacé de abogado del diablo\", \"mode\": \"deep\"}")"
check_true "planner: el plan profundo también responde" "$(echo "$SSE" | grep -q '^event: done' && echo true || echo false)"
# Método de los tres cuartos (planner.v2): arranca en el Soñador y empuja a pensar más grande.
disney() {
  curl -sN -X POST "$FN/planner" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    -d "{\"spark_id\": \"$DAILY_ID\", \"message\": \"$1\", \"mode\": \"quick\", \"method\": \"disney\"}" > /dev/null
}
last_answer() { rest "planner_messages?select=content&role=eq.assistant&order=id.desc&limit=1" | jq -r '.[0].content'; }
disney "Empecemos por el Soñador"
check_true "planner disney: abre el cuarto del Soñador" "$(last_answer | grep -q '^\[\[room:dreamer\]\]' && echo true || echo false)"
disney "Todas las ciudades sincronizadas"
check_true "planner disney: empuja a pensar más grande" "$(last_answer | grep -q 'más grande' && echo true || echo false)"
disney "Pasemos al siguiente cuarto"
check_true "planner disney: pasa al Realista" "$(last_answer | grep -q '^\[\[room:realist\]\]' && echo true || echo false)"
# Lentes (planner_lens.v1): responden con su formato y no mueven el cuarto del método.
lens() {
  curl -sN -X POST "$FN/planner" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    -d "{\"spark_id\": \"$DAILY_ID\", \"message\": \"$2\", \"mode\": \"quick\", \"method\": \"disney\", \"lens\": \"$1\"}" > /dev/null
}
lens business_model "Convertila en un modelo de negocio."
check_true "planner lente: responde con el formato del modelo de negocio" \
  "$(last_answer | grep -q '^\[\[lens:business_model\]\]' && last_answer | grep -q '^\*\*El experimento\*\*' && echo true || echo false)"
disney "Pasos, gente y plata"
check_true "planner lente: el método sigue en el Realista" "$(last_answer | grep -q '^\[\[room:realist\]\]' && echo true || echo false)"
call planner "{\"spark_id\": \"$DAILY_ID\", \"message\": \"Hola\", \"mode\": \"quick\", \"lens\": \"poema\"}"
check "planner: una lente que no existe es invalid_request" "$STATUS|$(echo "$BODY" | jq -r .error)" "400|invalid_request"
# Cocina (del principio) y Equipos (de 3b, todavía sin chispa): de dominios distintos y nunca combinados.
by_category() { rest "concepts?select=id,category:categories!inner(name)&category.name=eq.$1&limit=1" | jq -r '.[0].id'; }
call spark "{\"mode\": \"pick\", \"concept_ids\": [\"$(by_category Cocina)\", \"$(by_category Equipos)\"]}"
check "spark: Pro elige dos conceptos" "$STATUS|$(echo "$BODY" | jq -r .spark.mode)" "200|pick"
# Revoca el consentimiento desde la app: nada más sale hacia la IA.
rest "profiles?id=eq.$USER_ID" -X PATCH -d '{"ai_consent_at": null}' >/dev/null
call spark '{"mode": "extra"}'
check "spark: sin consentimiento no pide la chispa (403)" "$STATUS|$(echo "$BODY" | jq -r .error)" "403|ai_consent_required"
call planner "{\"spark_id\": \"$DAILY_ID\", \"message\": \"Hola\", \"mode\": \"quick\"}"
check "planner: sin consentimiento no responde (403)" "$STATUS|$(echo "$BODY" | jq -r .error)" "403|ai_consent_required"
call planner "{\"spark_id\": \"$DAILY_ID\", \"message\": \"Convertila en un post.\", \"mode\": \"quick\", \"lens\": \"post\"}"
check "planner lente: sin consentimiento no responde (403)" "$STATUS|$(echo "$BODY" | jq -r .error)" "403|ai_consent_required"
DISTILL_LEFT="$(rest "rpc/credit_status" -X POST -d '{}' | jq -r '.[] | select(.kind == "distill") | .remaining')"
capture "$LONG Y sin revisión, los errores llegan a producción." "Equipos" true
check "capture: sin consentimiento guarda sin destilar" "$STATUS|$(echo "$BODY" | jq -r .distillation)|$(echo "$BODY" | jq -r '.concepts[0].distilled')" "200|consent_required|false"
check "capture: sin consentimiento no gasta la destilación" \
  "$(rest "rpc/credit_status" -X POST -d '{}' | jq -r '.[] | select(.kind == "distill") | .remaining')" "$DISTILL_LEFT"

echo "== 5. Lo que la app hace directo con su sesión"
PROJECT_ID="$(rest "rpc/create_project" -X POST -d '{"p_name": "Mi primer proyecto"}' | jq -r .id)"
check_true "create_project: crea el proyecto" "$([[ "$PROJECT_ID" =~ ^[0-9a-f-]{36}$ ]] && echo true || echo false)"
rest "sparks?id=eq.$DAILY_ID" -X PATCH -d "{\"status\": \"saved\", \"project_id\": \"$PROJECT_ID\"}" >/dev/null
call today
check "today: la chispa guardada queda en el proyecto" "$(echo "$BODY" | jq -r '.spark.status + "|" + .spark.project_name')" "saved|Mi primer proyecto"
check "register_push_token: registra el token" "$(rest "rpc/register_push_token" -X POST -o /dev/null -w '%{http_code}' -d '{"p_token": "e2e-token", "p_platform": "ios", "p_sandbox": true}')" "204"
check "content_reports: reporta la chispa" "$(rest "content_reports" -X POST -o /dev/null -w '%{http_code}' -d "{\"spark_id\": \"$EXTRA_ID\", \"reason\": \"wrong\"}")" "201"
EXPORT="$(rest "rpc/export_my_data" -X POST -d '{}')"
check "export_my_data: trae los 9 conceptos" "$(echo "$EXPORT" | jq -r '.concepts | length')" "9"
# Planificador: 2 turnos libres + 4 del método de los tres cuartos + 1 lente = 14 mensajes.
check_true "export_my_data: con chispas, proyecto y planificador" \
  "$(echo "$EXPORT" | jq -r '(.sparks | length) >= 3 and (.projects | length) == 1 and (.planner[0].messages | length) == 14')"
check "export_my_data: incluye el consentimiento (revocado)" "$(echo "$EXPORT" | jq -r '.profile | has("ai_consent_at")')|$(echo "$EXPORT" | jq -r .profile.ai_consent_at)" "true|null"
check_true "export_my_data: sin embeddings" "$(echo "$EXPORT" | jq -r '[.concepts[] | has("embedding")] | any | not')"
check "delete_my_account: borra la cuenta" "$(rest "rpc/delete_my_account" -X POST -o /dev/null -w '%{http_code}' -d '{}')" "204"
check "delete_my_account: no queda nada del usuario" \
  "$(psql "$DB_URL" -tAXc "select count(*) from auth.users where id = '$USER_ID'")|$(psql "$DB_URL" -tAXc "select count(*) from public.concepts where user_id = '$USER_ID'")" "0|0"
call today
check "today: con la cuenta borrada ya no entra (401)" "$STATUS" "401"

echo "== 6. Ana (seed), después de /process"
call process '{}' "$SERVICE_ROLE_KEY"
check "process: corre con la clave de servicio" "$STATUS" "200"
check "process: no quedan conceptos sin embedding" "$(psql "$DB_URL" -tAXc "select count(*) from public.concepts where embedding is null")" "0"
check "process: la biblioteca tiene embeddings" "$(psql "$DB_URL" -tAXc "select count(*) from public.library_concepts where embedding is null")" "0"
TOKEN="$(auth "token?grant_type=password" -d '{"email": "ana@lumbre.test", "password": "lumbre-dev-local"}' | jq -r .access_token)"
call today
check "Ana: tiene chispa diaria" "$STATUS|$(echo "$BODY" | jq -r '.spark.mode')" "200|daily"
check "Ana: ve sus 9 conceptos" "$(echo "$BODY" | jq -r .concept_count)" "9"
call search '{"query": "hongos y raíces del bosque"}'
check "Ana: la búsqueda encuentra las micorrizas" "$(echo "$BODY" | jq -r '.concepts[0].title')" "Micorrizas"

echo "== 7. Internas y webhook"
call process '{}' "$ANON_KEY"
check "process: sin la clave de servicio no entra (401)" "$STATUS" "401"
call daily-sparks '{}' "$SERVICE_ROLE_KEY"
check "daily-sparks: corre" "$STATUS" "200"
call daily-sparks '{"collect": true}' "$SERVICE_ROLE_KEY"
check "daily-sparks collect: corre" "$STATUS" "200"
call send-pushes '{}' "$SERVICE_ROLE_KEY"
check "send-pushes: corre" "$STATUS" "200"
WEBHOOK_SECRET="$(grep -E '^REVENUECAT_WEBHOOK_SECRET=' supabase/functions/.env 2>/dev/null | cut -d= -f2- || true)"
if [[ -n "$WEBHOOK_SECRET" ]]; then
  EVENT="{\"event\": {\"id\": \"e2e-$RUN\", \"type\": \"INITIAL_PURCHASE\", \"app_user_id\": \"22222222-2222-2222-2222-222222222222\", \"entitlement_ids\": [\"pro\"]}}"
  call revenuecat-webhook "$EVENT" "$WEBHOOK_SECRET"
  check "revenuecat-webhook: pasa a Beto a Pro" "$STATUS|$(psql "$DB_URL" -tAXc "select plan from public.profiles where id = '22222222-2222-2222-2222-222222222222'")" "200|pro"
  call revenuecat-webhook "$EVENT" "$WEBHOOK_SECRET"
  check "revenuecat-webhook: el mismo evento dos veces no hace nada" "$(echo "$BODY" | jq -r .status)" "duplicate"
  call revenuecat-webhook "{\"event\": {\"id\": \"e2e-exp-$RUN\", \"type\": \"EXPIRATION\", \"app_user_id\": \"22222222-2222-2222-2222-222222222222\", \"entitlement_ids\": [\"pro\"]}}" "$WEBHOOK_SECRET"
  check "revenuecat-webhook: al vencer vuelve a free" "$(psql "$DB_URL" -tAXc "select plan from public.profiles where id = '22222222-2222-2222-2222-222222222222'")" "free"
  call revenuecat-webhook "$EVENT" "secreto-equivocado"
  check "revenuecat-webhook: con otro secreto no entra (401)" "$STATUS" "401"
else
  echo "salteado: REVENUECAT_WEBHOOK_SECRET no está en supabase/functions/.env"
fi

exit "$FAILED"
