#!/usr/bin/env bash
# Edge Functions de punta a punta contra el stack local, como las usa la app (contrato en backend/openapi.yaml):
#   1. Un invitado guarda 6 conceptos de categorías distintas (/capture) y Hoy le da su chispa diaria (/today).
#   2. Como invitado no puede pedir chispas extra; crea su cuenta (email de Mailpit) y pasa a free.
#   3. Con 6 conceptos guardados hoy ganó extras: pide una (/spark). Busca en su bóveda (/search).
#   4. Pasa a Pro con /dev-plan y usa el planificador en streaming (/planner).
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
capture "Un flujo en espiral separa partículas por fuerza centrífuga, sin necesidad de filtro." "Ingeniería"
capture "Los silencios marcan el ritmo de una canción tanto como las notas que suenan." "Música"
capture "Pequeñas ganancias que se reinvierten crecen de forma exponencial con el paso del tiempo." "Finanzas"
capture "Los hongos conectan las raíces de un bosque y reparten nutrientes entre árboles distintos." "Naturaleza"
LONG="Revisar los cambios de código en pares reduce errores y reparte el conocimiento del sistema entre todo el equipo. Cuando dos personas leen el mismo cambio aparecen preguntas que el autor no se hizo, y esas preguntas suelen esconder los errores más caros. Además, quien revisa aprende cómo funciona una parte que no conocía, así que el conocimiento deja de estar en una sola cabeza."
capture "$LONG" "Software" true
check "capture: el sexto concepto se guarda" "$STATUS" "200"
check "capture: un invitado no tiene destilación (la pide y no hay cupo)" "$(echo "$BODY" | jq -r .distillation)" "quota_exceeded"
call capture '{"category": "Links", "source_type": "link", "source_url": "https://ejemplo.invalid/nota"}'
check "capture: un link sin idea y sin destilación pide la tesis (422)" "$STATUS|$(echo "$BODY" | jq -r .error)" "422|needs_thesis"
call capture '{"thesis": "x", "category": "", "source_type": "text"}'
check "capture: sin categoría da invalid_category (400)" "$STATUS|$(echo "$BODY" | jq -r .error)" "400|invalid_category"

call today
check "today: responde" "$STATUS" "200"
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
call spark "{\"mode\": \"pick\", \"concept_ids\": [\"$(rest "concepts?select=id&order=created_at&limit=1" | jq -r '.[0].id')\", \"$(rest "concepts?select=id&order=created_at.desc&limit=1" | jq -r '.[0].id')\"]}"
check "spark: Pro elige dos conceptos" "$STATUS|$(echo "$BODY" | jq -r .spark.mode)" "200|pick"

echo "== 5. Lo que la app hace directo con su sesión"
PROJECT_ID="$(rest "rpc/create_project" -X POST -d '{"p_name": "Mi primer proyecto"}' | jq -r .id)"
check_true "create_project: crea el proyecto" "$([[ "$PROJECT_ID" =~ ^[0-9a-f-]{36}$ ]] && echo true || echo false)"
rest "sparks?id=eq.$DAILY_ID" -X PATCH -d "{\"status\": \"saved\", \"project_id\": \"$PROJECT_ID\"}" >/dev/null
call today
check "today: la chispa guardada queda en el proyecto" "$(echo "$BODY" | jq -r '.spark.status + "|" + .spark.project_name')" "saved|Mi primer proyecto"
check "register_push_token: registra el token" "$(rest "rpc/register_push_token" -X POST -o /dev/null -w '%{http_code}' -d '{"p_token": "e2e-token", "p_platform": "ios", "p_sandbox": true}')" "204"
check "content_reports: reporta la chispa" "$(rest "content_reports" -X POST -o /dev/null -w '%{http_code}' -d "{\"spark_id\": \"$EXTRA_ID\", \"reason\": \"wrong\"}")" "201"
EXPORT="$(rest "rpc/export_my_data" -X POST -d '{}')"
check "export_my_data: trae los 6 conceptos" "$(echo "$EXPORT" | jq -r '.concepts | length')" "6"
# Planificador: 2 turnos libres + 3 del método de los tres cuartos = 10 mensajes.
check_true "export_my_data: con chispas, proyecto y planificador" \
  "$(echo "$EXPORT" | jq -r '(.sparks | length) >= 3 and (.projects | length) == 1 and (.planner[0].messages | length) == 10')"
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
