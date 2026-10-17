#!/usr/bin/env bash
# Prueba de carga del batch nocturno (paso 63): N usuarios sintéticos con K conceptos cada uno, todos con el día
# empezado y sin chispa diaria, y se mide cuánto tarda en salir la chispa de todos y las push.
#
#   backend/supabase/tests/load/daily_batch.sh                 # 5.000 usuarios × 20 conceptos (10x, ver README)
#   USERS=500 CONCEPTS=20 backend/supabase/tests/load/daily_batch.sh
#
# Necesita `supabase start` y `supabase functions serve` (proveedor local de IA: mide el servidor, no al modelo).
# Los usuarios son load-<n>@carga.test y se borran al terminar (también si falla). Imprime un resumen en Markdown
# para pegar en backend/LOAD-TEST.md.
set -euo pipefail
cd "$(dirname "$0")/../../.."

USERS="${USERS:-5000}"
CONCEPTS="${CONCEPTS:-20}"
eval "$(supabase status -o env 2>/dev/null | grep -E '^(API_URL|SERVICE_ROLE_KEY|DB_URL)=')"
FN="$API_URL/functions/v1"
psql_q() { psql "$DB_URL" -X -q -tA -v ON_ERROR_STOP=1 "$@"; }
now_ms() { python3 -c 'import time; print(int(time.time() * 1000))'; }

cleanup() {
  psql_q -c "select cron.alter_job(jobid, active := true) from cron.job where jobname in ('chispas-diarias', 'chispas-diarias-resultados', 'enviar-pushes', 'procesar-pendientes')" >/dev/null || true
  psql_q -c "delete from auth.users where email like 'load-%@carga.test'" >/dev/null || true
}
trap cleanup EXIT

# Los crons quedan en pausa durante la prueba: así se mide lo que hace cada llamada, sin carreras con pg_cron.
psql_q -c "select cron.alter_job(jobid, active := false) from cron.job where jobname in ('chispas-diarias', 'chispas-diarias-resultados', 'enviar-pushes', 'procesar-pendientes')" >/dev/null
psql_q -c "delete from auth.users where email like 'load-%@carga.test'" >/dev/null

MODEL="$(psql_q -c "select coalesce((select embedding_model from public.library_concepts where embedding_model is not null limit 1), 'lumbre-local-hash-v1')")"
echo "== Datos: $USERS usuarios × $CONCEPTS conceptos (modelo de embeddings $MODEL)"
T0="$(now_ms)"
psql_q <<SQL >/dev/null
-- Usuarios en 4 zonas horarias, con la hora de la chispa ya pasada (así las push salen en la misma prueba) y el Acepto para la IA.
insert into auth.users (id, email, aud, role, raw_user_meta_data)
select gen_random_uuid(), 'load-' || n || '@carga.test', 'authenticated', 'authenticated',
       jsonb_build_object('timezone', (array['America/Argentina/Buenos_Aires', 'America/Mexico_City', 'Europe/Madrid', 'America/Bogota'])[1 + n % 4])
from generate_series(1, $USERS) n;
update public.profiles p set spark_hour = '00:00', ai_consent_at = now(), creative_profiles = array[(array['software', 'content', 'business', 'design', 'curiosity'])[1 + abs(hashtext(p.id::text)) % 5]]
  from auth.users u where u.id = p.id and u.email like 'load-%@carga.test';
insert into public.push_tokens (user_id, token, platform, sandbox)
select id, 'load-token-' || id, 'ios', true from auth.users where email like 'load-%@carga.test';

-- Conceptos listos, con dominio y un vector al azar (1024 dimensiones) del mismo modelo que la biblioteca.
insert into public.concepts (user_id, domain, title, thesis, principle, source_type, status, distilled, embedding, embedding_model)
select u.id,
       (select slug from public.domains order by slug offset (abs(hashtext(u.id::text || k)) % 25) limit 1),
       'Concepto ' || k, 'Tesis sintética ' || k || ' de la prueba de carga.', 'Principio sintético ' || k || '.',
       'text', 'ready', true,
       (select array_agg(random() - 0.5) from generate_series(1, 1024 + 0 * k))::extensions.vector(1024),
       '$MODEL'
from auth.users u cross join generate_series(1, $CONCEPTS) k
where u.email like 'load-%@carga.test';
SQL
SEED_S=$(( ($(now_ms) - T0) / 1000 ))
TOTAL_CONCEPTS="$(psql_q -c "select count(*) from public.concepts c join auth.users u on u.id = c.user_id where u.email like 'load-%@carga.test'")"
echo "sembrado en ${SEED_S} s ($TOTAL_CONCEPTS conceptos)"

echo "== SQL"
NEEDING_MS="$(psql_q -c "explain (analyze, format json) select * from public.users_needing_daily_spark(200)" | jq '.[0]["Execution Time"] | floor')"
PICK_MS="$(psql "$DB_URL" -X -q -c "do \$\$ declare t timestamptz := clock_timestamp(); u uuid; n int := 0; begin for u in select id from auth.users where email like 'load-%@carga.test' order by id limit 100 loop perform * from public.spark_pairs(u); n := n + 1; end loop; raise notice 'pick_ms=%', round(extract(epoch from clock_timestamp() - t) * 1000 / n, 1); end \$\$;" 2>&1 | grep -o 'pick_ms=[0-9.]*' | cut -d= -f2)"
echo "users_needing_daily_spark(200): ${NEEDING_MS} ms · spark_pairs por usuario: ${PICK_MS} ms"

echo "== /daily-sparks hasta que todos tengan su chispa"
T0="$(now_ms)"
CALLS=0; CREATED=0; ERRORS=0; MAX_CALL_MS=0; HTTP_ERRORS=0
while :; do
  C0="$(now_ms)"
  OUT="$(curl -s -w '\n%{http_code}' -X POST "$FN/daily-sparks" -H "Authorization: Bearer $SERVICE_ROLE_KEY" -H "Content-Type: application/json" -d '{}' --max-time 400)"
  CODE="${OUT##*$'\n'}"; BODY="${OUT%$'\n'*}"
  MS=$(( $(now_ms) - C0 )); CALLS=$((CALLS + 1)); (( MS > MAX_CALL_MS )) && MAX_CALL_MS=$MS
  if [[ "$CODE" != "200" ]]; then
    HTTP_ERRORS=$((HTTP_ERRORS + 1)); echo "llamada $CALLS: HTTP $CODE en ${MS} ms"
    (( HTTP_ERRORS > 5 )) && break
    continue
  fi
  USERS_RUN="$(echo "$BODY" | jq -r '.generate.users')"
  CREATED=$((CREATED + $(echo "$BODY" | jq -r '.generate.created')))
  ERRORS=$((ERRORS + $(echo "$BODY" | jq -r '.generate.errors')))
  echo "llamada $CALLS: $(echo "$BODY" | jq -c '.generate') en ${MS} ms"
  [[ "$USERS_RUN" == "0" ]] && break
  (( CALLS > 500 )) && break
done
BATCH_S=$(( ($(now_ms) - T0) / 1000 ))
WITH_SPARK="$(psql_q -c "select count(*) from public.sparks s join auth.users u on u.id = s.user_id where u.email like 'load-%@carga.test' and s.mode = 'daily'")"
LIBRARY="$(psql_q -c "select count(*) from public.sparks s join auth.users u on u.id = s.user_id where u.email like 'load-%@carga.test' and s.uses_library")"

echo "== /send-pushes (sin claves de APNs: registra y marca)"
T0="$(now_ms)"; PUSH_CALLS=0
while :; do
  OUT="$(curl -s -X POST "$FN/send-pushes" -H "Authorization: Bearer $SERVICE_ROLE_KEY" -H "Content-Type: application/json" -d '{}' --max-time 400)"
  PUSH_CALLS=$((PUSH_CALLS + 1))
  echo "push $PUSH_CALLS: $(echo "$OUT" | jq -c '.' 2>/dev/null || echo "$OUT")"
  [[ "$(echo "$OUT" | jq -r '.due // 0')" == "0" ]] && break
  (( PUSH_CALLS > 100 )) && break
done
PUSH_S=$(( ($(now_ms) - T0) / 1000 ))
NOTIFIED="$(psql_q -c "select count(*) from public.sparks s join auth.users u on u.id = s.user_id where u.email like 'load-%@carga.test' and s.notified_at is not null")"

cat <<MD

| Medida | Valor |
|---|---|
| Usuarios × conceptos | $USERS × $CONCEPTS ($TOTAL_CONCEPTS conceptos) |
| \`users_needing_daily_spark(200)\` | $NEEDING_MS ms |
| \`spark_pairs\` por usuario | $PICK_MS ms |
| Llamadas a /daily-sparks | $CALLS (la más lenta: $MAX_CALL_MS ms; errores HTTP: $HTTP_ERRORS) |
| Chispas diarias creadas | $WITH_SPARK de $USERS ($LIBRARY con concepto invitado; errores por usuario: $ERRORS) |
| Tiempo total del batch | $BATCH_S s |
| Push marcadas | $NOTIFIED en $PUSH_S s ($PUSH_CALLS llamadas) |
MD
