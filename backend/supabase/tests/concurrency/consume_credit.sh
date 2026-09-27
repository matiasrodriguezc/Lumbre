#!/usr/bin/env bash
# Concurrencia de consume_credit(): N llamadas simultáneas contra el techo de chispas extra de Pro.
# Tienen que entrar exactamente tantas como el techo, aunque la fila de uso todavía no exista.
# Uso: backend/supabase/tests/concurrency/consume_credit.sh   (con supabase start corriendo)
set -euo pipefail

DB_URL="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:55522/postgres}"
CALLS="${CALLS:-50}"
USER_ID="$(uuidgen | tr '[:upper:]' '[:lower:]')"

cleanup() { psql "$DB_URL" -qXc "delete from auth.users where id = '$USER_ID'" >/dev/null; }
trap cleanup EXIT

psql "$DB_URL" -qX -v ON_ERROR_STOP=1 >/dev/null <<SQL
insert into auth.users (id, email, aud, role)
values ('$USER_ID', 'concurrencia-$USER_ID@cuotas.test', 'authenticated', 'authenticated');
insert into public.profiles (id, plan) values ('$USER_ID', 'pro');
SQL

LIMIT="$(psql "$DB_URL" -tAXc "select max_count from public.plan_limits where plan = 'pro' and kind = 'spark_extra' and period = 'day'")"
GRANTED="$(seq "$CALLS" | xargs -P "$CALLS" -I{} psql "$DB_URL" -tAXc "select public.consume_credit('$USER_ID', 'spark_extra')" | grep -c '^t$' || true)"
USED="$(psql "$DB_URL" -tAXc "select used from public.usage_ledger where user_id = '$USER_ID' and kind = 'spark_extra'")"

echo "$CALLS llamadas simultáneas, techo $LIMIT: $GRANTED con cupo, used = $USED"
if [[ "$GRANTED" == "$LIMIT" && "$USED" == "$LIMIT" ]]; then
  echo "ok"
else
  echo "FALLÓ: se pasó o no llegó al techo"
  exit 1
fi
