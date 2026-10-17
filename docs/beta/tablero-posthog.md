# Tablero de la beta en PostHog (D1/D7)

Para H8 y la compuerta F4 (MAT-273, MAT-274). Definición de cada insight con los eventos de `docs/analytics.md`; se arma en el proyecto de **prod** de PostHog cuando los primeros testers externos manden eventos. La compuerta: **D7 ≥ 15%; si D7 < 10%, no se arranca Android** (plan.md §9).

Nombre del tablero: **Beta iOS (F4)**.

## Filtros globales del tablero

- `platform = ios`
- Persona `is_internal != true` (saca tu cuenta y las de prueba).
- Cohorte **Beta externa**: personas con `signed_up` entre [fecha de la tanda 1] y [fecha de cierre de la beta] y `app_version` de los builds de TestFlight externo. Crearla como cohorte estática de PostHog al abrir cada tanda, con el nombre `beta-tanda-1`, `beta-tanda-2`, `beta-tanda-3`, y una dinámica `beta-externa` que las une.

**Acción de valor** (la misma de la métrica norte, `docs/analytics.md` §1): crear una Action de PostHog llamada `valor` que matchea `concept_saved` **o** `spark_revealed`. Todos los insights de retención la usan.

## Insights

| # | Insight | Tipo | Definición | Objetivo |
|---|---|---|---|---|
| 1 | **Retención D1 / D7** (el de la compuerta) | Retention | Evento inicial: `signed_up` (primera vez). Evento de retorno: Action `valor`. Período: día. Mostrar día 1 y día 7. Cohorte: `beta-externa`. Separar por `beta-tanda-n` | D1 ≥ 35%, **D7 ≥ 15%** |
| 2 | Primera semana con una idea guardada | Trends (fórmula) | Personas únicas de la cohorte con `spark_saved` en sus primeros 7 días / personas de la cohorte. En PostHog: Funnel `signed_up` → `spark_saved` con ventana de 7 días, mirar la conversión | ≥ 30% |
| 3 | Activación (24 h) | Funnel | `signed_up` → `spark_saved`, ventana 24 h | ≥ 40% |
| 4 | Onboarding | Funnel | `onboarding_started` → `onboarding_step_completed` (`step = profile`) → (`step = seeds`) → (`step = spark_hour`) → `push_permission_responded` → `spark_revealed` con `is_first = true`. Separar por `is_guest` | ≥ 75% llega a la primera chispa |
| 5 | Permiso de push | Trends | `push_permission_responded` con `granted = true` / total de `push_permission_responded` con `system_prompt_shown = true` | ≥ 55% |
| 6 | Norte semanal | Trends (fórmula) | A = total de `spark_saved` por semana; B = personas únicas con Action `valor` por semana; A / B | ≥ 2 |
| 7 | Push que se abre | Trends (fórmula) | `notification_opened` (`type = daily_spark`) / `spark_notification_sent`, por día. Breakdown por la persona `spark_hour` | Diagnóstico |
| 8 | Calidad de la chispa | Trends (fórmula) | `spark_feedback_given` / `spark_revealed`, por semana. Breakdown por `reason` | ≤ 25% |
| 9 | Captura desde afuera | Trends | `capture_submitted` con breakdown por `entry` (ver qué parte es `share_extension`) | Diagnóstico |
| 10 | Embudo de captura | Funnel | `capture_opened` → `capture_submitted` → `concept_saved`, breakdown por `source_type` | Diagnóstico |
| 11 | Usuarios activos por día | Trends | Personas únicas con Action `valor`, por día, cohorte `beta-externa` | Diagnóstico |
| 12 | Errores vistos | Trends | `error_shown`, breakdown por `screen` y `code`. Al lado, el link al proyecto de Sentry | Bajando semana a semana |
| 13 | Consentimiento para IA | Trends | `ai_consent_responded`, breakdown por `granted` | Diagnóstico: si muchos dicen que no, no hay chispas |

## Lectura semanal (los lunes)

1. Insight 1: D1 y D7 de cada tanda que ya cumplió 7 días.
2. Insights 2 y 8: ¿las chispas sirven?
3. Insight 4: el paso con más caída del onboarding.
4. Anotar en la síntesis de la beta: número, comparación con la semana anterior y un cambio para probar.

## Cuidado con los números chicos

Con 50 a 100 personas, cada persona mueve 1 o 2 puntos. Para la compuerta:
- Mirar D7 de las tres tandas juntas y no decidir con menos de 40 personas que cumplieron 7 días.
- Si D7 queda entre 10% y 15%, la decisión no es automática: cruzarla con la encuesta (pregunta 1) y las llamadas.

## Lo que hace falta para que exista

- Paso 44 (PostHog y Sentry en iOS) con los eventos de `docs/analytics.md`, y los eventos de servidor saliendo por `/process` con `POSTHOG_API_KEY` cargada.
- Que la persona tenga `is_internal` y `is_guest` como propiedades (sección 4 de `docs/analytics.md`).
- Proyecto de prod de PostHog en la UE (H1).
