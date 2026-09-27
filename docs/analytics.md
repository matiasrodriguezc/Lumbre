# Lumbre: métricas y plan de eventos

Define qué se mide, cómo se calcula cada métrica y qué eventos mandan las apps, el backend y la web. iOS y Android usan **exactamente los mismos nombres** de eventos y propiedades. Los objetivos salen de `plan.md` §13.

Herramienta: PostHog para producto y experimentos, Sentry para errores y crashes, tabla `llm_calls` para costos de IA.

---

## 1. Métrica norte

**Ideas guardadas por usuario activo semanal.** Objetivo: 2 o más.

```
norte (semana) = chispas guardadas en la semana / usuarios activos en la semana
```

- **Idea guardada:** una chispa que pasa a `status = 'saved'` (evento `spark_saved`). Cuentan todos los modos: diaria, extra, elegir y problema. El tablero la muestra también separada por modo.
- **Usuario activo:** en el período agregó algo a la bóveda o vio al menos una chispa. Abrir la app sola no cuenta, y tampoco buscar o usar el planificador sin hacer ninguna de esas dos cosas.

Acciones de valor:

| Evento | Qué significa |
|---|---|
| `concept_saved` | Agregó información a la bóveda |
| `spark_revealed` | Vio una conexión (una chispa) |

Los invitados cuentan como activos igual que los usuarios con cuenta. El tablero los separa con la propiedad `is_guest`.

Esta misma definición de "activo" se usa en la retención, en los activos mensuales y en el porcentaje que inicia la prueba de Pro.

Por qué esta métrica: sube solo si funcionan las tres partes del loop. Hace falta que se capture (sin conceptos no hay pares), que la chispa sea buena (si no, no se guarda) y que haya hábito (si no, no hay semana activa).

## 2. Métricas de soporte

| Métrica | Cálculo | Objetivo | Fuente |
|---|---|---|---|
| Onboarding | `spark_revealed` con `is_first = true` / `onboarding_started` | ≥ 75% | PostHog, embudo |
| Activación | Usuarios con `spark_saved` dentro de las 24 h de `signed_up` / `signed_up` (incluye invitados) | ≥ 40% | PostHog, embudo con ventana de 24 h |
| Permiso de push | `push_permission_responded` con `granted = true` / los que vieron el pedido del sistema | ≥ 55% | PostHog |
| Retención D1 / D7 / D30 | % de la cohorte de alta con una acción de valor el día 1, 7 y 30 | 35% / 15% / 8% | PostHog, retención |
| Beta: primera semana | % de la cohorte con al menos un `spark_saved` en sus primeros 7 días | ≥ 30% | PostHog |
| Inicio de prueba | Usuarios que empezaron la prueba en el mes / activos del mes | ≥ 8% | RevenueCat → PostHog |
| Prueba a pago | Pruebas que pasan a pago / pruebas que terminaron | ≥ 40% | RevenueCat |
| Conversión a Pro | Pro pagos / usuarios dados de alta hace 90 días o más | ≥ 3% | RevenueCat |
| Calidad de la chispa | `spark_feedback_given` / `spark_revealed` | ≤ 25% | PostHog |
| Costo de IA | Suma de `llm_calls.cost_usd` del mes / activos del mes | ≤ US$ 0,15 | Postgres (tablero del paso 38) |

Métricas de diagnóstico, sin objetivo por ahora:
- **Categoría sugerida aceptada:** conceptos sin `concept_domain_changed` / `concept_saved`. Si baja del 80%, la lista de dominios o la clasificación están mal.
- **Feedback por percentil de distancia:** `spark_feedback_given` / `spark_revealed` según `distance_percentile`. Con esto se calibra la banda 40–80 del emparejamiento.
- **Push que se abre:** `notification_opened` / `spark_notification_sent`, según la hora elegida.
- **Captura desde afuera:** porcentaje de `capture_submitted` con `entry` igual a `share_extension` o `share_intent`. Si es bajo, la captura sigue teniendo fricción.

## 3. Convenciones

- **Nombres:** `objeto_accion` en snake_case, verbo en pasado y en inglés (`spark_revealed`, `concept_saved`). Las propiedades también van en snake_case. Los valores de enumeración son slugs en inglés (`obvious`, `share_extension`).
- **Una sola fuente por evento.** Lo que queda escrito en la base lo emite el **backend**, que tiene la verdad. Lo que pasa solo en la pantalla lo emite la **app**. Así nada se cuenta dos veces y los números no dependen de si la app estaba offline.
- **Identidad:** el `distinct_id` es el `user_id` de Supabase. Antes de la primera sesión, el SDK usa un id propio y al crearla se llama a `identify` para unir los dos. Un invitado ya tiene `user_id` (sesión anónima) y lo conserva al crear la cuenta, así que su historia no se corta. En PostHog nunca va el email.
- **Pantallas:** con `screen()` manual y los nombres de la sección 6. En SwiftUI y Compose la captura automática de pantallas no es confiable.
- **Eventos de ciclo de vida:** los del SDK (`Application Installed`, `Application Opened`, `Application Backgrounded`) quedan activados.

### Privacidad (no se negocia)

- **Nunca** va contenido del usuario en un evento: ni texto, ni título, ni tesis, ni URL, ni host de la URL, ni la búsqueda, ni los mensajes del planificador. Solo tipos, cantidades en rangos, slugs e ids.
- Autocapture y session replay **apagados** en las apps: podrían grabar lo que la persona escribe. En la web se permite autocapture, con los inputs enmascarados.
- No se usa el IDFA ni el AAID. PostHog es analítica propia, sin tracking entre apps, así que no hace falta el pedido de ATT. Esto hay que declararlo igual en las etiquetas de privacidad (paso 65).
- Borrar la cuenta borra también la persona en PostHog, por su API (paso 37).
- Hay un proyecto de PostHog para dev/staging y otro para prod. Tu cuenta y las de prueba llevan `is_internal = true` y se excluyen de los tableros.

## 4. Propiedades comunes

**En cada evento** (super properties, las pone el SDK o el cliente de eventos del backend):

| Propiedad | Valores |
|---|---|
| `platform` | `ios`, `android`, `web`, `server` |
| `app_version`, `build` | Versión y build de la app |
| `plan` | `free`, `trial`, `pro` |
| `locale` | `es`, `en` |
| `theme` | `dark`, `light` |

**En la persona** (se actualizan al abrir la app o cuando cambian):

| Propiedad | Valores |
|---|---|
| `plan` | `free`, `trial`, `pro` |
| `creative_profiles` | Lista de slugs: `software`, `content`, `business`, `design`, `curiosity` |
| `spark_hour` | Hora local, `"08:00"` |
| `timezone` | IANA, `America/Argentina/Buenos_Aires` |
| `signup_method` | `anonymous`, `apple`, `google`, `email` |
| `is_guest` | booleano: usa una sesión anónima y todavía no creó la cuenta |
| `concepts_count_bucket` | `0`, `1-9`, `10-49`, `50-199`, `200+` |
| `push_enabled` | booleano |
| `has_widget` | booleano (WidgetKit y Glance permiten saber si hay uno instalado) |
| `larger_text`, `reduce_motion` | booleanos de accesibilidad |
| `is_internal` | booleano |

## 5. Catálogo de eventos

Fuente: **A** = app (iOS y Android), **S** = servidor (Edge Functions o webhook), **W** = web.

### Onboarding y cuenta

| Evento | Fuente | Propiedades | Cuándo |
|---|---|---|---|
| `onboarding_started` | A | — | Se muestra la bienvenida |
| `onboarding_step_completed` | A | `step`: `welcome`, `profile`, `seeds`, `spark_hour`, `push`; `step_index` | Se avanza de paso |
| `seed_idea_added` | A | `index` (1–3), `input`: `text`, `voice` | Se carga una idea semilla |
| `spark_hour_set` | A | `hour`, `is_default`, `context`: `onboarding`, `settings` | Se elige o cambia la hora |
| `push_permission_prompted` | A | `context`: `onboarding`, `settings`, `today` | Se muestra el pedido previo con contexto |
| `push_permission_responded` | A | `granted`, `system_prompt_shown` | Responde al pedido del sistema |
| `guest_entered` | A | — | Toca "Entrar como invitado" |
| `signed_up` | S | `method`: `anonymous`, `apple`, `google`, `email` | Se crea el perfil (también para un invitado) |
| `account_prompt_shown` | A | `trigger` (se define en el paso 14) | Se le pide la cuenta a un invitado |
| `account_linked` | S | `method`: `apple`, `google`, `email`; `guest_age_days` | Un invitado crea su cuenta y conserva sus datos |
| `signed_in` | A | `method` | Vuelve a entrar en un dispositivo |
| `ai_consent_responded` | A | `granted` | Acepta o no que sus datos pasen por una IA de terceros (requisito de App Store) |
| `onboarding_completed` | A | `duration_s`, `profiles_count`, `seeds_count` | Termina el último paso |

### Captura

| Evento | Fuente | Propiedades | Cuándo |
|---|---|---|---|
| `capture_opened` | A | `entry`: `fab`, `widget`, `share_extension`, `share_intent`, `app_intent`, `earn_extra`, `empty_vault` | Se abre la sheet de Capturar |
| `capture_submitted` | A | `entry`, `source_type` (los del esquema: `text`, `voice`, `selection`, `screenshot`, `scan`, `link`, `image`, `pdf`, `audio`), `distill_requested`, `offline`, `length_bucket`: `<30`, `30-199`, `200-999`, `1000+` palabras | Toca Guardar (o entra a la cola offline) |
| `capture_failed` | A | `reason`: `rate_limited`, `network`, `unsupported_format`, `too_large`, `server_error` | La captura no se pudo guardar |
| `ocr_completed` | A | `kind`: `screenshot`, `scan`, `success`, `length_bucket` | Termina el OCR local |
| `offline_queue_flushed` | A | `count` | Se mandan capturas encoladas al volver la red |
| `concept_saved` | S | `source_type`, `distilled`, `confidence`: `high`, `medium`, `low`, `null`; `domain`, `status`: `draft`, `ready`; `concepts_in_capture` (1–3), `is_seed` | Se escribe un concepto en la base |
| `distill_fallback_shown` | A | `reason`: `low_confidence`, `inaccessible`, `free_quota` | Aparece "¿Qué idea te deja esto?" |
| `concept_draft_resolved` | A | `action`: `confirmed`, `edited`, `discarded` | Resuelve un borrador de confianza media |
| `concept_domain_changed` | A | `from`, `to`, `context`: `review`, `detail` | Cambia la categoría sugerida |
| `extra_spark_earned` | S | `earned_today` (1 o 2) | Guardar 3 conceptos le dio una chispa extra |

### Chispa

| Evento | Fuente | Propiedades | Cuándo |
|---|---|---|---|
| `spark_generated` | S | `mode`: `daily`, `extra`, `pick`, `problem`; `batch`, `distance_percentile` (0–100 respecto del propio usuario), `uses_library_concept`, `candidates_count` | Se genera una chispa |
| `spark_notification_sent` | S | `scheduled_hour` | Sale la push de la chispa diaria |
| `notification_opened` | A | `type`: `daily_spark`, `weekly_summary`; `minutes_after_sent` | Abre la app desde una push |
| `spark_revealed` | A | `mode`, `is_first`, `entry`: `push`, `widget`, `app`; `minutes_since_available`, `reduce_motion` | Termina el reveal |
| `spark_saved` | S | `mode`, `entry` (lo manda la app en la llamada), `is_first`, `has_project` | La chispa pasa a guardada. **Evento de la métrica norte** |
| `spark_feedback_given` | S | `mode`, `reason`: `obvious`, `irrelevant`, `already_had`; `distance_percentile`, `uses_library_concept` | "No me sirve" con motivo |
| `spark_extra_requested` | A | `mode`, `source`: `earned`, `pro` | Pide una chispa más |
| `spark_empty_state_shown` | A | `reason`: `used_today`, `no_candidates`, `few_concepts` | Hoy no tiene chispa para mostrar |
| `share_card_created` | A | `mode` | Se genera la tarjeta para historias |
| `spark_shared` | A | `activity_type` (el que devuelve la hoja del sistema, si lo da) | Termina de compartir |
| `ai_content_reported` | A | `object`: `spark`, `planner_message`; `reason` | Reporta contenido generado (requisito de Google Play) |

### Bóveda

| Evento | Fuente | Propiedades | Cuándo |
|---|---|---|---|
| `vault_searched` | A | `query_length_bucket`: `1-2`, `3-5`, `6+` palabras; `results_bucket`: `0`, `1-5`, `6+` | Ejecuta una búsqueda semántica (una vez por búsqueda, no por tecla) |
| `vault_filtered` | A | `domain` | Aplica un filtro de dominio |
| `concept_opened` | A | `entry`: `vault`, `search`, `spark_detail` | Abre el detalle de un concepto |
| `concept_deleted` | S | `source_type`, `age_days_bucket` | Borra un concepto |

### Planificador, proyectos y export

| Evento | Fuente | Propiedades | Cuándo |
|---|---|---|---|
| `planner_opened` | A | `entry`: `spark_detail`, `project` | Abre el planificador (con o sin Pro) |
| `planner_message_sent` | S | `mode`: `quick`, `deep`; `suggestion`: `backlog`, `devil_advocate`, `stack`, `none` | Se procesa un mensaje |
| `quota_reached` | S | `kind`: `capture`, `distill`, `spark_extra`, `planner`, `planner_deep` | `consume_credit()` devuelve false |
| `markdown_exported` | A | `object`: `spark`, `project` | Exporta a Markdown |
| `project_created` | S | `from`: `spark`, `manual` | Crea un proyecto (tablero en 1.1) |

### Pro

| Evento | Fuente | Propiedades | Cuándo |
|---|---|---|---|
| `paywall_shown` | A | `trigger`: `planner`, `distill`, `extra_sparks`, `problem_mode`, `graph`, `settings`; `variant` | Se muestra el paywall (solo al tocar algo Pro) |
| `paywall_dismissed` | A | `trigger`, `variant`, `seconds_visible` | Lo cierra sin comprar |
| `purchase_started` | A | `product`: `monthly`, `annual`; `trigger`, `variant` | Toca comprar |
| `purchase_restored` | A | `found` | Toca "Restaurar compras" |
| Eventos de suscripción | S | Los de la integración de RevenueCat con PostHog: prueba iniciada, conversión, renovación, cancelación, vencimiento, problema de cobro | Webhook de RevenueCat |

Para las suscripciones se usa la integración nativa de RevenueCat con PostHog en vez de eventos propios. Los nombres exactos se toman de su documentación al configurarla (paso 36).

### Widget, perfil y privacidad

| Evento | Fuente | Propiedades | Cuándo |
|---|---|---|---|
| `widget_tapped` | A | `action`: `open_spark`, `capture`; `size` | Entra a la app desde el widget |
| `settings_changed` | A | `setting`: `profiles`, `spark_hour`, `theme`, `push`, `language` | Cambia un ajuste |
| `data_exported` | S | — | Pide el export de sus datos |
| `account_deleted` | S | `plan`, `age_days_bucket` | Borra la cuenta (después se borra la persona en PostHog) |
| `error_shown` | A | `screen`, `code` | Se muestra un error al usuario. El detalle técnico va a Sentry |

### Web (landing y demo, pasos 5 y 6)

| Evento | Fuente | Propiedades | Cuándo |
|---|---|---|---|
| `waitlist_joined` | W | `referred`, `utm_source`, `utm_medium`, `utm_campaign` | Se anota en la waitlist |
| `referral_link_copied` | W | `channel`: `copy`, `whatsapp`, `x`, `email` | Comparte su link de referido |
| `demo_spark_generated` | W | `ideas_length_bucket` | Genera una chispa en la demo |
| `demo_daily_subscribed` | W | — | Se anota para recibir una chispa por día por email |

En la web el `distinct_id` es el id de la fila de la waitlist, nunca el email.

## 6. Nombres de pantalla

`onboarding_welcome`, `onboarding_profile`, `onboarding_seeds`, `onboarding_spark_hour`, `onboarding_push`, `today`, `spark_detail`, `earn_extra`, `share_card`, `capture`, `capture_distilling`, `capture_review`, `vault`, `concept_detail`, `projects`, `project_detail`, `planner`, `paywall`, `profile`, `settings`, `subscription`, `privacy`.

## 7. Embudos y tableros

Se arman en PostHog en el paso 44 y se validan con los primeros datos de TestFlight (paso 59).

1. **Norte y salud semanal:** norte, usuarios activos por semana, D1/D7/D30, chispas guardadas por modo.
2. **Onboarding:** `onboarding_started` → cada `onboarding_step_completed` → `push_permission_responded` → `spark_revealed` (`is_first`). Muestra dónde se cae la gente, separado entre cuenta e invitado.
3. **De invitado a cuenta:** `guest_entered` → `account_prompt_shown` → `account_linked`, y cuántos días tarda.
4. **Activación:** `signed_up` → `spark_saved` dentro de las 24 h.
5. **Captura:** `capture_opened` → `capture_submitted` → `concept_saved`, separado por `entry` y `source_type`. Incluye aceptación de categoría y borradores resueltos.
6. **Chispas y calidad:** feedback por motivo, por modo, por `distance_percentile` y según si usa un concepto de la biblioteca; apertura de push según la hora.
7. **Pro:** `paywall_shown` por `trigger` → `purchase_started` → prueba iniciada → pago.
8. **Beta (F4):** cohorte de TestFlight externo, D7 y porcentaje con al menos una idea guardada en la primera semana. Es la compuerta que decide si se hace Android.

El costo de IA no va en PostHog: sale de `llm_calls` en el tablero del paso 38.

## 8. Experimentos previstos

Con feature flags de PostHog, recién cuando haya volumen (F9):
- Hora por defecto de la chispa (`spark_hour_default`). Mide `notification_opened` y D7.
- Variante de paywall (`paywall_variant`). Mide `purchase_started` / `paywall_shown` y prueba a pago.
- Momento del pedido de push (`push_prompt_timing`). Mide `push_permission_responded` y D7.

## 9. Implementación

- **Catálogo tipado:** en el paso 44 este catálogo pasa a un archivo de definición del que se generan los tipos de Swift y Kotlin, igual que con `tokens.json`. Así ninguna app puede mandar un evento o una propiedad mal escrita.
- **Backend:** un módulo compartido de las Edge Functions manda los eventos de servidor a la API de PostHog en lote. No debe frenar la respuesta al usuario: si PostHog falla, se registra en Sentry y se sigue.
- **Cambios:** un evento nuevo o cambiado se agrega primero a este documento y después al código.

## 10. Decisiones tomadas

1. **Usuario activo** (27/9/2026): en la semana agregó algo a la bóveda o vio al menos una chispa (sección 1).
2. **Región de PostHog** (27/9/2026): nube de la UE. Simplifica GDPR y es compatible con la Ley 25.326.
3. **Cuenta en el onboarding** (27/9/2026): se puede crear en el onboarding o entrar como invitado con una sesión anónima y crearla después, sin perder datos. Qué puede hacer el invitado y cuándo se le pide la cuenta se define en el prototipo (paso 14); de eso sale el `trigger` de `account_prompt_shown`.
