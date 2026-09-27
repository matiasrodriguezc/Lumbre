#!/usr/bin/env bash
# Auth de punta a punta contra el stack local (API de Auth, REST y Mailpit), como lo va a usar la app:
#   1. Un invitado entra con sesión anónima y tiene plan guest.
#   2. El invitado vincula su email (link del mail), pasa a free y conserva lo que tenía.
#   3. Un usuario nuevo entra con email mágico y el link vuelve a la app (lumbre://auth-callback).
# Uso: backend/supabase/tests/auth/e2e.sh   (con supabase start corriendo)
set -euo pipefail
cd "$(dirname "$0")/../../.."

eval "$(supabase status -o env 2>/dev/null | grep -E '^(API_URL|ANON_KEY|DB_URL|MAILPIT_URL|INBUCKET_URL)=')"
MAIL_URL="${MAILPIT_URL:-${INBUCKET_URL:-http://127.0.0.1:55524}}"
RUN="$(date +%s)"
GUEST_EMAIL="invitado-$RUN@lumbre.test"
MAGIC_EMAIL="magico-$RUN@lumbre.test"
FAILED=0

json() { python3 -c "import json,sys; d=json.load(sys.stdin); print(eval(sys.argv[1], {}, {'d': d}))" "$1"; }
check() { if [[ "$2" == "$3" ]]; then echo "ok   $1"; else echo "FALLÓ $1 (esperado: $3, obtenido: $2)"; FAILED=1; fi; }
auth() { curl -s "$API_URL/auth/v1/$1" -H "apikey: $ANON_KEY" -H "Content-Type: application/json" "${@:2}"; }
rest() { curl -s "$API_URL/rest/v1/$1" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" "${@:2}"; }
# Link del último mail que llegó a una dirección.
mail_link() {
  local id=""
  for _ in $(seq 1 20); do
    id="$(curl -s "$MAIL_URL/api/v1/search?query=to:$1" | json "d['messages'][0]['ID'] if d['messages'] else ''")"
    [[ -n "$id" ]] && break
    sleep 0.5
  done
  curl -s "$MAIL_URL/api/v1/message/$id" | python3 -c "
import json, re, sys, html
d = json.load(sys.stdin)
print(html.unescape(re.search(r'href=\"([^\"]*/auth/v1/verify[^\"]*)\"', d['HTML']).group(1)))"
}
cleanup() { psql "$DB_URL" -qXc "delete from auth.users where email in ('$GUEST_EMAIL', '$MAGIC_EMAIL') or id = '${GUEST_ID:-00000000-0000-0000-0000-000000000000}'" >/dev/null; }
trap cleanup EXIT

echo "== 1. Invitado"
R="$(auth signup -d '{"data": {"timezone": "America/Bogota", "locale": "es-CO"}}')"
TOKEN="$(echo "$R" | json "d['access_token']")"
GUEST_ID="$(echo "$R" | json "d['user']['id']")"
check "entra como invitado (sesión anónima)" "$(echo "$R" | json "d['user']['is_anonymous']")" "True"
check "su perfil se creó con la zona horaria del teléfono" "$(rest "profiles?select=timezone" | json "d[0]['timezone']")" "America/Bogota"
check "tiene los cupos de invitado (10 capturas)" "$(rest "rpc/credit_status" -X POST -d '{}' | json "[r['available'] for r in d if r['kind']=='capture'][0]")" "10"
psql "$DB_URL" -qXc "insert into public.concepts (user_id, domain, title, thesis, source_type) values ('$GUEST_ID', 'cocina', 'Idea de invitado', 'La guardé antes de tener cuenta.', 'text')" >/dev/null

echo "== 2. El invitado vincula su email"
auth user -X PUT -H "Authorization: Bearer $TOKEN" -d "{\"email\": \"$GUEST_EMAIL\"}" >/dev/null
curl -s -o /dev/null "$(mail_link "$GUEST_EMAIL")"
USER="$(auth user -H "Authorization: Bearer $TOKEN")"
check "el mismo usuario deja de ser anónimo" "$(echo "$USER" | json "d['id'] + ' ' + str(d['is_anonymous'])")" "$GUEST_ID False"
R="$(auth "token?grant_type=refresh_token" -d "{\"refresh_token\": \"$(echo "$R" | json "d['refresh_token']")\"}")"
TOKEN="$(echo "$R" | json "d['access_token']")"
check "pasa a free (30 capturas)" "$(rest "rpc/credit_status" -X POST -d '{}' | json "[r['available'] for r in d if r['kind']=='capture'][0]")" "30"
check "conserva lo que guardó como invitado" "$(rest "concepts?select=title" | json "d[0]['title']")" "Idea de invitado"

echo "== 3. Email mágico"
auth "otp?redirect_to=lumbre://auth-callback" -d "{\"email\": \"$MAGIC_EMAIL\", \"create_user\": true, \"data\": {\"locale\": \"en\"}}" >/dev/null
LOCATION="$(curl -s -o /dev/null -w '%{redirect_url}' "$(mail_link "$MAGIC_EMAIL")")"
# Auth normaliza el redirect con una barra final; la app acepta las dos formas.
REDIRECT="${LOCATION%%#*}"
check "el link del mail vuelve a la app" "${REDIRECT%/}" "lumbre://auth-callback"
TOKEN="$(python3 -c "import sys, urllib.parse as u; print(dict(u.parse_qsl(sys.argv[1].split('#', 1)[1]))['access_token'])" "$LOCATION")"
check "entra con sesión y perfil propio en inglés" "$(rest "profiles?select=locale" | json "d[0]['locale']")" "en"
check "tiene plan free" "$(rest "rpc/credit_status" -X POST -d '{}' | json "[r['available'] for r in d if r['kind']=='capture'][0]")" "30"
check "no ve datos de otros usuarios" "$(rest "concepts?select=id" | json "len(d)")" "0"

exit "$FAILED"
