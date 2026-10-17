# Legal: borradores para revisar (paso 64)

> **BORRADORES NO REVISADOS POR UN ABOGADO.** No publicar ni enlazar desde la app ni la web hasta que los revise el abogado (H3, MAT-295). Están escritos a partir de lo que el código guarda y hace al 2026-10-16; si el backend cambia, se actualizan acá primero.

| Archivo | Qué es |
|---|---|
| `privacidad.es.md` / `privacy.en.md` | Política de privacidad (app, landing y demo web) |
| `terminos.es.md` / `terms.en.md` | Términos y condiciones, con suscripciones y contenido generado por IA |
| `consentimiento-ia.md` | Texto de la pantalla de consentimiento para IA de terceros (es y en), comparado con lo que hoy muestra la app |

Las respuestas de los formularios de privacidad de las tiendas están en `docs/tiendas/` y tienen que coincidir con la política.

## Lugares a completar

Todo lo que está entre corchetes en los documentos:
- `[TITULAR]`, `[CUIT]`, `[DOMICILIO]`: lo define el contador (persona o sociedad).
- `[DOMINIO]`: el dominio definitivo. **Ojo:** la app apunta hoy a `lumbre.app/privacidad` y `lumbre.app/terminos`, y `lumbre.app` está registrado por un tercero (ver `docs/tramites/disponibilidad.md`).
- `[EMAIL DE PRIVACIDAD]`: por ejemplo privacidad@[DOMINIO].
- `[FECHA]`: fecha de entrada en vigencia.
- `[REGIÓN DE PROD]`: la región del proyecto de Supabase de producción (paso 41). Dev está en São Paulo.

## Inventario de datos (fuente de la política)

Sacado de `backend/README.md` y de las migraciones de `backend/supabase/migrations/`.

| Dato | Dónde | Para qué | Cuánto tiempo |
|---|---|---|---|
| Email | Supabase Auth | Entrar (link mágico, Apple, Google) | Hasta borrar la cuenta |
| Nombre y foto de perfil, si los manda Apple o Google | Supabase Auth (identidades) | Lo guarda Auth al entrar con esos proveedores; la app no los usa | Hasta borrar la cuenta |
| Id de usuario | Toda la base, PostHog, Sentry, RevenueCat | Identificar la cuenta | Hasta borrar la cuenta; en PostHog se borra la persona por API |
| Perfil: perfiles creativos, hora de la chispa, zona horaria, idioma, plan | `profiles` | Funcionamiento | Hasta borrar la cuenta |
| Preferencia aprendida de distancia entre ideas | `profiles.target_distance` | Ajustar las chispas con el feedback | Hasta borrar la cuenta |
| Neuronas: tesis (hasta 600 caracteres), título, principio, dominio, categoría | `concepts`, `categories` | El contenido del usuario | Hasta que la borre o borre la cuenta |
| Fuente: tipo, URL, título (hasta 300), fragmento (hasta 500) | `concepts` | Mostrar de dónde salió | Ídem |
| Texto crudo de lo capturado | `concepts.raw_text` | Destilar y reprocesar | **30 días** (job diario `vencer-texto-crudo`) |
| Referencia a la foto en el teléfono | `concepts.local_asset_id` | Volver a mostrarla en ese teléfono. La foto no sale del teléfono salvo para destilarla | Ídem neuronas |
| Embedding (vector numérico) y modelo | `concepts` | Búsqueda y emparejamiento | Ídem neuronas; no se exporta |
| Adjuntos (imagen JPEG/PNG o PDF) | Storage `capture-temp` | Destilar | **Se borran apenas se procesan**, salga bien o mal |
| Chispas: el par, título, texto, estado, feedback | `sparks` | La chispa del día y el historial | Hasta borrar la cuenta |
| Circuitos: nombre | `projects` | Organizar | Ídem |
| Planificador: mensajes (hasta 20.000 caracteres) y resumen | `planner_threads`, `planner_messages` | Conversación con la IA | Ídem |
| Reportes de contenido IA: motivo y nota | `content_reports` | Moderación (requisito de Play) | Ídem (se borran con la cuenta) |
| Token de push | `push_tokens` | Mandar la chispa | Hasta borrarlo o borrar la cuenta |
| Cupos usados | `usage_ledger` | Límites del plan | Ídem |
| Registro de llamadas a la IA: función, modelo, tokens, costo, latencia | `llm_calls` | Costos y abuso | Se conserva; al borrar la cuenta pierde el id de usuario |
| Eventos de suscripción (tipo, id de RevenueCat) | `subscription_events` | Aplicar el plan Pro | Se conserva (seudónimo) |
| Eventos de uso, sin contenido | PostHog (UE), `analytics_outbox` | Métricas de producto | PostHog: hasta borrar la cuenta (se borra la persona); la bandeja local queda sin contenido |
| Diagnóstico de errores y cuelgues | Sentry | Arreglar errores | Según el plan de Sentry (90 días por defecto) |
| Compras | Apple, Google y RevenueCat | Cobrar y validar Pro | Lo maneja cada uno |
| Consentimiento para IA | En la cuenta (`profiles.ai_consent_at`, con la hora del servidor) y en el teléfono | Saber si se puede mandar contenido a la IA | Hasta cambiarlo o borrar la cuenta |
| Waitlist: email, código de referido, quién te invitó, idioma, origen, UTM, confirmación | `waitlist` | Avisar del lanzamiento y la fila | Hasta el lanzamiento + [plazo a definir] o hasta que pida la baja |
| Demo web: las dos ideas | No se guardan | Generar la chispa de la demo | Solo durante la llamada |
| IP (en forma de hash) | `web_rate_limits` | Límite anti-abuso de la web | [plazo a definir; ventana de 1 día] |
| Invitados (sesión anónima) | Toda la base | Probar la app sin cuenta | Se borran solos a los **30 días sin sesión** |
| Copias de seguridad | Supabase | Recuperación ante fallas | Según el plan (7 días en Pro) |

**Proveedores que tratan datos por cuenta de Lumbre:**

| Proveedor | Qué recibe | País |
|---|---|---|
| Supabase | Todo lo de la base y los adjuntos temporales | [REGIÓN DE PROD]; empresa de EE. UU. |
| Anthropic (Claude) | Texto de las neuronas, adjuntos para destilar, perfil creativo, las dos neuronas de cada chispa, mensajes del planificador, las ideas de la demo web | EE. UU. |
| Proveedor de embeddings (a definir en el paso 22; hoy el código soporta Voyage AI) | Texto de cada neurona y de cada búsqueda | EE. UU. |
| PostHog | Eventos sin contenido, id de usuario | UE |
| Sentry | Diagnóstico de errores | EE. UU. |
| RevenueCat | Id de usuario, compras | EE. UU. |
| Apple (APNs) y Google (FCM) | Token de push y el texto de la notificación | EE. UU. |
| Proveedor de email (a definir) | Email, para los links de acceso y la waitlist | A definir |

**Lo que no se hace:** publicidad, venta de datos, rastreo entre apps (sin IDFA ni AAID), autocapture o grabación de sesión en la app, contenido del usuario en logs o en analytics, entrenamiento de modelos propios con los datos.

## Decisiones provisorias en los borradores

1. **Edad mínima: 16 años.** Cubre el máximo del GDPR sin pedir permiso de los padres. A confirmar con el abogado.
2. **Ley y jurisdicción:** Argentina, tribunales ordinarios de la Ciudad de Buenos Aires, sin perjuicio de los derechos del consumidor.
3. **Anthropic:** se afirma que, según sus términos comerciales, no usa los datos de la API para entrenar. Verificar el texto vigente de sus términos antes de publicar, y evaluar pedir retención cero.
4. **Waitlist:** se borra [6 meses] después del lanzamiento si la persona no crea cuenta. El plazo es una propuesta.
5. **El consentimiento para IA se guarda en el servidor** (`profiles.ai_consent_at`, desde el 2026-10-16) y las Edge Functions lo respetan: sin él no se destila, no se generan chispas y el planificador no responde. Para demostrarlo (GDPR, art. 7.1) falta guardar también la versión del texto aceptado.
