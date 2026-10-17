# Prueba de carga del batch nocturno (paso 63)

Script: `supabase/tests/load/daily_batch.sh`. Siembra N usuarios sintéticos con K conceptos cada uno, todos con el día empezado y el consentimiento para IA aceptado, y llama a `/daily-sparks` y `/send-pushes` hasta que no queda nadie. Los crons quedan en pausa durante la prueba y los usuarios se borran al terminar.

Corre con el proveedor de IA `local`: mide el servidor (SQL, Edge Functions, inserciones), no la latencia del modelo. Con Anthropic, la diaria va por la Batches API (`spark_jobs`), así que la llamada solo encola y el tiempo del modelo queda fuera del cron.

## Resultado (2026-10-16, stack local en una Mac)

| Medida | Valor |
|---|---|
| Usuarios × conceptos | 1000 × 20 (20.000 conceptos) |
| `users_needing_daily_spark(200)` | 50 ms |
| `spark_pairs` por usuario | 2,0 ms |
| Llamadas a `/daily-sparks` | 6 (200 usuarios cada una, entre 2,2 y 3,5 s; 0 errores HTTP) |
| Chispas diarias creadas | 1000 de 1000 (0 errores por usuario) |
| Tiempo total del batch | 14 s |
| Push marcadas | 1000 en 3 s (3 llamadas, sin claves de APNs) |

La corrida de 5.000 usuarios (10x) no terminó: llenó el disco de la máquina y Postgres entró en recovery. Antes de caer había medido `users_needing_daily_spark(200)` en 113 ms y llamadas de 200 usuarios de 11 a 36 s, con una que cortó por el límite del worker (HTTP 546), todo con el sistema ya degradado. Con la base sana, una llamada de 200 tarda ~2,5 s, así que 5.000 usuarios serían 25 llamadas, unos 65 s de trabajo.

## Hallazgo y cambio

El cuello de botella era la frecuencia, no la velocidad: con el cron cada 15 minutos y 200 usuarios por llamada, el batch atendía unos **800 usuarios por hora**. 5.000 usuarios en la misma zona horaria tardaban más de 6 horas en tener su chispa.

La migración `20261016140000_chispas_diarias_cada_minuto.sql` pasa `chispas-diarias` a cada minuto: unos **12.000 usuarios por hora**. Una llamada sin pendientes tarda ~70 ms. Si dos llamadas se solaparan, `sparks_one_daily_idx` y el `unique (user_id, scheduled_for)` de `spark_jobs` impiden la chispa doble.

## Pendiente

- Repetir los 5.000 usuarios con disco libre (`USERS=5000`, necesita varios GB para la base y el WAL).
- Medir en staging con Anthropic real (paso 41): el tiempo de la Batches API y el costo por chispa en `llm_calls`.
- Si la base crece mucho, subir `p_limit` o paralelizar por zona horaria.
