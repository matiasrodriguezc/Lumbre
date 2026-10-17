#!/usr/bin/env bash
# Tablero de costos de IA (paso 38): imprime el tablero, el mes, las señales del día y las alertas guardadas.
#
#   backend/scripts/costos.sh                 # base local (supabase start)
#   backend/scripts/costos.sh 30              # últimos 30 días
#   DB_URL='postgresql://postgres.<ref>:<clave>@aws-0-<región>.pooler.supabase.com:5432/postgres' backend/scripts/costos.sh
#
# Para el remoto, la cadena de conexión está en el dashboard (Connect → Session pooler). Solo lee: no cambia nada.
# Las mismas consultas se pueden pegar en el SQL Editor (ver backend/README.md, sección Costos).
set -euo pipefail

DB_URL="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:55522/postgres}"
DAYS="${1:-14}"
q() { psql "$DB_URL" -X -q -P pager=off -P footer=off -v ON_ERROR_STOP=1 -c "$1"; }

echo "== Por día (UTC), últimos $DAYS días"
q "select day as día, cost_usd as usd, calls as llamadas, error_calls as errores, batch_calls as batch, users as usuarios,
          usd_per_user as usd_por_usuario, sparks as chispas, usd_per_spark as usd_por_chispa,
          distills as destilaciones, usd_per_distill as usd_por_destilación,
          planner_messages as mensajes, usd_per_planner_message as usd_por_mensaje
     from public.llm_cost_dashboard($DAYS)"

echo "== Mes en curso (objetivo por usuario activo: app_config.active_user_month_target_usd)"
q "select month as mes, cost_usd as usd, users as usuarios, usd_per_user as usd_por_usuario, target_usd as objetivo,
          case when over_target then 'PASADO' else 'ok' end as estado
     from public.llm_cost_month()"

echo "== Por función y modelo, últimos 7 días"
q "select feature as función, model as modelo, sum(calls) as llamadas, sum(input_tokens) as tokens_entrada,
          sum(cached_tokens) as tokens_cache, sum(output_tokens) as tokens_salida, sum(cost_usd) as usd,
          round(avg(avg_latency_ms)) as ms_promedio
     from public.llm_cost_daily where day >= (now() at time zone 'UTC')::date - 6
    group by 1, 2 order by usd desc nulls last, llamadas desc"

echo "== Usuarios que más gastaron hoy (UTC)"
q "select user_id as usuario, count(*) as llamadas, sum(cost_usd) as usd
     from public.llm_calls where user_id is not null and created_at >= date_trunc('day', now() at time zone 'UTC') at time zone 'UTC'
    group by 1 order by usd desc nulls last limit 10"

echo "== Señales de hoy"
SIGNALS="$(psql "$DB_URL" -X -tA -F ' | ' -c "select signal, detail, value, threshold from public.llm_cost_signals()")"
if [[ -z "$SIGNALS" ]]; then echo "sin señales"; else echo "$SIGNALS"; fi

echo "== Alertas guardadas (job alertas-de-costo), últimos 14 días"
q "select day as día, scope as alcance, user_id as usuario, cost_usd as usd, cap_usd as tope
     from public.cost_alerts where day >= current_date - 14 order by day desc, cost_usd desc"

echo "== Topes vigentes (app_config)"
q "select key as clave, value as valor from public.app_config order by key"

[[ -z "$SIGNALS" ]]
