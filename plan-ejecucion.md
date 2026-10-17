# Lumbre: plan de ejecución del backlog

Cómo se trabaja el backlog de Linear (proyecto **Lumbre**, issues MAT-199 a MAT-320) de a **un paso por sesión**. Las decisiones de producto están en `plan.md`; si algo de acá lo contradice, manda `plan.md`.

## Cómo se ejecuta cada paso

1. Leer este archivo y tomar el **primer paso sin tildar** cuyo "Necesita" esté cumplido. Si está bloqueado por una tarea tuya (H1, H2…), avisar y proponer el siguiente paso desbloqueado.
2. Pasar sus issues a **In Progress** en Linear.
3. Hacer el trabajo y verificarlo contra "Listo cuando" (tests, build, preview o revisión del documento).
4. Commit en git (a partir del paso 1).
5. Comentar en cada issue qué se hizo y dónde quedó, y pasarlo a **Done**.
   - Los pasos marcados **prep** preparan material para una tarea tuya: el issue no se cierra, queda con el material en un comentario.
6. Tildar el paso acá con la fecha y una línea de notas. Fin de la sesión.

**Prioridad actual (27/9/2026):** el bloque D (iOS) se adelantó y se hace ahora con datos de prueba (`MockLumbreAPI`), para validar lo visual antes de tener backend. Se toman primero los pasos sin tildar del bloque D que no dependan del backend; el 43 (cliente real) y el 59 (TestFlight) esperan al bloque C y a H1. Los bloques A, B y C siguen pendientes en su orden.

Reglas:
- Un paso que resulta más grande de lo previsto se parte acá mismo (16a, 16b) en vez de estirar la sesión.
- Si un paso obliga a tomar una decisión que no está en `plan.md`, se pregunta antes de seguir.
- Cada bloque termina con una **compuerta** (el criterio de salida de la fase). El primer paso del bloque siguiente la revisa.

---

## A. Arranque (F0 Validar)

- [x] **1. Monorepo, git y CLAUDE.md** · MAT-321 · ✅ 2026-09-27: estructura armada, design system en `design/system/`, esquema en `backend/db/`, plan maestro y backlog en `docs/`; issues MAT-321 a MAT-324 creados; push a GitHub.
  Estructura `/ios`, `/android`, `/backend`, `/design`, `/web`, `/docs`; mover `design-system/` y `db/` a su lugar y actualizar las rutas del README; `CLAUDE.md` con las reglas del proyecto y un puntero a este plan; `.gitignore`; primer commit. Crear en Linear los issues que faltan (ver "Issues a crear").
  Listo cuando: el repo tiene su primer commit, las rutas del README funcionan y los issues nuevos existen.
- [x] **2. Métrica norte y plan de eventos** · MAT-218 · ✅ 2026-09-27: `docs/analytics.md` con la definición de activo, 10 métricas, ~50 eventos y reglas de privacidad; quedan 3 decisiones abiertas en su §10.
  `docs/analytics.md`: métrica norte, eventos con propiedades y nombres idénticos en iOS y Android, funnels de activación y de Pro.
- [x] **3. Kit de entrevistas** · prep MAT-212 · ✅ 2026-09-27: guía, reclutamiento y plantilla en `docs/entrevistas/`. Además, 12 entrevistas simuladas para ensayar la guía (no cuentan para la compuerta); la guía quedó en versión 2 con lo aprendido.
  Guion, filtro de reclutamiento (4 devs, 4 creadores, 4 emprendedores), mensaje de invitación y plantilla de síntesis.
- [x] **4. Paquete de trámites** · MAT-214, prep MAT-213, MAT-216, MAT-217 · ✅ 2026-10-16: Chequeo del 13/10 en `docs/tramites/`: el nombre está tomado en casi todos lados y hay tres Lumbre de software (diario iOS, tutor de IA argentino, SaaS inmobiliario); lumbre.app es de un tercero. Brief para el abogado, cuentas en orden y preguntas al contador listos.
  Chequeo real de dominios, handles y nombre en tiendas (cierra MAT-214); brief para el abogado (INPI, USPTO, EUIPO, clases 9 y 42, alternativas); lista de cuentas en orden, con el D-U-N-S primero porque tarda; preguntas para el contador.
- [ ] **5. Landing con waitlist y referidos** · MAT-215 (parte 1), MAT-220 · Adelantado el 2026-10-16: landing estática en `web/` con fila, referidos confirmados (+10 puestos), doble opt-in y anti-abuso, probada en local. Falta publicar (H1).
  Sitio en `/web` con la marca, tabla `waitlist` con código de referido y posición en la fila, email de confirmación.
  Necesita: H1 para publicarla (se puede construir en local antes).
- [ ] **6. Demo web de chispa** · MAT-215 (parte 2) · Adelantado el 2026-10-16: Edge Function `demo-spark` con el prompt `demo_spark.v0`, una chispa por email por día y límites por IP, probada en local. Faltan la clave de Anthropic y publicar (H1).
  Pegás dos ideas y aparece una chispa. Edge Function con un prompt v0, límite por email y por IP, una chispa por día por email.
  Necesita: H1 (clave de Anthropic y proveedor de email).
- [x] **7. Kit de build in public** · prep MAT-219 · ✅ 2026-10-16: `docs/build-in-public/`: calendario de 4 semanas, 20 chispas del día, plantillas por red y plantilla visual HTML con 3 formatos.
  Calendario de 4 semanas, 20 "chispas del día" escritas, plantillas de post por red y plantilla visual.

**Compuerta F0:** Lumbre confirmado como marca, 150+ en la waitlist, 3 dolores repetidos en las entrevistas.

## B. Diseño (F1)

- [x] **8. Wordmark en curvas y exportes del ícono** · MAT-222 · ✅ 2026-10-13: con la identidad neuronal nueva. Wordmark en curvas desde la Fraunces variable (ahora empaquetada en LumbreDesign); PNG de iOS en el AppIcon del proyecto y en `design/system/logo/exportes/`, Android adaptive + monochrome por densidad y Google Play 512. Todo sale de `design/system/identidad/generar.py`.
  Wordmark pasado a trazos con Fraunces; PNG de iOS 1024 (claro, dark y tinted) y de Android (adaptive foreground/background y monochrome).
- [x] **9. Tokens listos para Figma** · prep MAT-221 · ✅ 2026-10-16: `design/figma/`: plugin "Lumbre tokens" y JSON DTCG desde `tokens.json` (Gris/Grafito, tipografía iOS/Android). Falta importarlo en Figma (H5).
  `tokens.json` exportado como variables de Figma con modos oscuro y claro, más instrucciones de importación.
- [x] **10. Copy es/en de todas las pantallas** · MAT-226 · ✅ 2026-10-16: `design/copy/`: 621 textos es/en y `copy.py` para String Catalog y `strings.xml`. El catálogo de iOS estaba vacío (el copy vive en los .swift): se carga cuando la app lo adopte.
  Archivo de claves en `design/copy/` que después alimenta los String Catalogs y `strings.xml`.
- [x] **11. Estados vacíos, error, offline y contenido inaccesible** · MAT-227 · ✅ 2026-10-16: `design/estados/`: 67 estados con especificación, copy es/en y mockups iOS/Android.
  Especificación, copy y mockups HTML de cada estado.
- [x] **12. Coreografía del reveal** · MAT-225 · ✅ 2026-10-16: `design/reveal/`: línea de tiempo de 900 ms con háptico a los 650, prototipo animado con Reducir movimiento y las diferencias con `SparkReveal.swift`.
  Tiempos, curvas y hápticos del reveal de 900 ms, más un prototipo HTML animado con la variante de Reducir movimiento.
- [x] **13. Tarjeta para compartir y widget** · MAT-228, MAT-229 · ✅ 2026-10-16: `design/compartir/`: tarjeta 1080×1920 y widgets de iOS y Glance en tamaño real.
  Mockups HTML en tamaño real (historia 1080×1920; tamaños de widget de iOS y de Glance).
- [x] **14. Prototipo navegable del loop** · MAT-223 · ✅ 2026-10-16: `design/prototipo/`: loop clickeable iOS/Android con los dos caminos de entrada y panel para el test. Lo que puede hacer el invitado está en `invitado.md`, a confirmar.
  HTML clickeable: onboarding → Hoy → Capturar → Bóveda → detalle → paywall, con selector iOS/Android. Incluye los dos caminos de entrada (crear cuenta o entrar como invitado) y define qué puede hacer el invitado y cuándo se le pide la cuenta. Se publica para el test.
- [x] **15. Kit de test del prototipo y del ícono** · prep MAT-224, MAT-210 · ✅ 2026-10-16: `design/test/`: guion, test del ícono solo y planilla para 5 personas. El test lo corrés vos (H6).
  Guion de tareas, preguntas sobre el ícono solo y planilla de resultados.

**Compuerta F1:** 4 de 5 testers completan el onboarding y guardan una idea sin ayuda.

## C. Backend e IA (F2)

Todo arranca en local con Supabase CLI y Docker; los entornos remotos se conectan en el paso 41.

- [x] **16. Supabase local y migraciones** · MAT-230 (parte 1) · ✅ 2026-09-27: migración base con RLS reforzado (el usuario ya no puede cambiarse el plan, gastar cuota ajena ni insertar conceptos directo), seed con usuarios A y B, puertos 555xx para convivir con Ronda. `backend/db/schema.sql` quedó reemplazado.
  `supabase init` en `/backend`, `schema.sql` pasado a migraciones, seed y scripts de arranque. Renombrar `concepts.is_guest` a `from_library` para no confundirlo con el usuario invitado, y usar en `creative_profiles` los mismos slugs que `docs/analytics.md`.
- [x] **17. RLS y tests "usuario A no ve datos de B"** · MAT-232 · ✅ 2026-09-27: 35 tests de pgTAP en `backend/supabase/tests/database/01_rls.sql`, más una guarda que falla si una tabla nueva no tiene RLS. Verificado rompiendo permisos a propósito.
  pgTAP sobre cada tabla con datos de usuario.
- [x] **18. Cuotas** · MAT-233 · ✅ 2026-09-27: chispas extra ganadas (antes free las pedía sin ganarlas), plan `guest` por sesión anónima, `refund_credit()` y `credit_status()`. 26 tests de pgTAP y una prueba de 50 llamadas simultáneas, que falla con una versión no atómica.
  `consume_credit()` atómico, `plan_limits` cargado con los valores de `plan.md` (más límites para invitados), `usage_ledger` y un test de concurrencia.
- [x] **19. CI del backend** · MAT-254 (parte 1) · ✅ 2026-09-27: `.github/workflows/backend.yml` (Postgres desde cero, lint, pgTAP y concurrencia). Verificado en local desde una base vacía. En GitHub todavía no corre: la cuenta tiene Actions bloqueado por facturación (H13).
  GitHub Actions corre las migraciones y los tests en cada PR.
  Necesita: H2.
- [x] **20a. Auth: invitado, email mágico y perfil** · MAT-231 · ✅ 2026-09-27: sesión anónima con límites propios, vinculación de email sin perder datos, email mágico con vuelta a `lumbre://auth-callback`, perfil automático con zona e idioma del teléfono y limpieza diaria de invitados abandonados. 15 tests de pgTAP y una prueba de punta a punta con la API de Auth y Mailpit, que también corre en CI. Migración aplicada en `lumbre-dev`; faltan sus ajustes de Auth en el dashboard (H14).
- [ ] **20b. Auth: Apple y Google** · MAT-231
  Activar los dos proveedores con las credenciales y probar el flujo nativo (`signInWithIdToken`) y `linkIdentity()` para invitados. Ya están configurados en `config.toml` y apagados.
  Necesita: H1 (credenciales de Apple y Google).
- [x] **21. Lista cerrada de dominios** · MAT-234 · ✅ 2026-09-28: 25 dominios con descripciones para embeber e íconos de iOS y Android (verificados), en `20260927230000_dominios.sql`; `urbanismo` pasó a `arquitectura`. 6 tests de pgTAP. Aplicada en `lumbre-dev`.
  20 a 25 dominios con una descripción cada uno, pensada para embeberla; seed. Desde el 27/9 los dominios no se muestran: quedan por debajo de las categorías propias del usuario.
- [ ] **22. Elegir el modelo de embeddings** · MAT-235
  Comparar 2 o 3 candidatos multilingües con un set chico de pares es/en; decisión documentada.
  Necesita: H1 (claves).
- [x] **23. Gateway de IA** · MAT-246, MAT-247 (parte 1) · ✅ 2026-10-16: gateway en `_shared/ai/` con reintentos, respaldo, topes en dólares y `llm_calls`. Con Anthropic falta probarlo con clave (H1).
  Módulo compartido de Edge Functions: reintentos, backoff, modelo de respaldo, tope diario en dólares y registro de cada llamada en `llm_calls`.
- [x] **24. Endpoint de captura** · MAT-236 · ✅ 2026-10-16: `/capture` completo (valida, cobra, destila si se pide, embebe y clasifica); voz y OCR llegan como texto. Sin consentimiento para IA guarda sin destilar.
  Texto, voz, selección y OCR; limpieza del texto; límite de 30 por día. Adelantado el 27/9: `capture_concept()` en la base ya guarda textos y links con la categoría y la cuota. Falta la Edge Function que suma embedding y destilación.
- [x] **25. Destilación** · MAT-237 · ✅ 2026-10-16: `distill.v1` con confianza alta/media/baja y devolución del cupo si falla. Con Haiku real falta H1.
  Haiku 4.5 con JSON estructurado y nivel de confianza (alta se guarda, media queda en borrador, baja cae a "¿Qué idea te deja esto?").
- [x] **26. Lectura de links** · MAT-238 · ✅ 2026-10-16: `_shared/links.ts` con SSRF cerrado también en los redirects y contenido externo delimitado como datos.
  Contenido más Open Graph, priorizando lo que llegó en la captura; el contenido externo se trata como datos.
- [x] **27. Clasificación de dominio por embedding** · MAT-240 · ✅ 2026-10-16: categoría → dominio por embedding (60% nombre, 40% conceptos) y los conceptos lo heredan. La calidad final depende del paso 22.
  Clasifica cada categoría del usuario en un dominio (por el embedding de su nombre y sus conceptos), y el concepto lo hereda.
- [x] **28. Emparejamiento** · MAT-241 · ✅ 2026-10-16: `pick_spark_pair` con banda por usuario, pares únicos, descanso de 3 días y top 20; tests con vectores sintéticos.
  Banda media por usuario, pares únicos, descanso de 3 días y elección entre los 20 mejores; tests con datos sintéticos.
- [x] **29. Set de evaluación y harness** · MAT-243 (parte 1) · ✅ 2026-10-16: `backend/eval/`: 500 pares (100 por perfil), harness con el pedido de producción, planilla para puntuar y `score.ts`. Puntuar es el paso 30 (H6).
  100 pares por perfil, un script que genera las chispas y una planilla para puntuar "sorprende" y "sirve".
- [ ] **30. Prompt de chispa** · MAT-243 (parte 2)
  Iterar el prompt con tus puntajes hasta un promedio de 3,5 o más; prompt versionado. Sumar un autochequeo de coherencia (el "guardián del absurdo", 2026-10-17): si la chispa no se sostiene, se descarta y se genera otra.
  Necesita: H6.
- [x] **31. Biblioteca de conceptos invitados** · MAT-242 · ✅ 2026-10-16: biblioteca ampliada a ~30 conceptos por perfil, de al menos 14 dominios y sin el mundo propio del perfil.
- [ ] **32. Batch nocturno y push** · MAT-244 · Adelantado el 2026-10-16: `daily-sparks` por zona horaria (local o Batches API), cada minuto desde la prueba de carga, y `send-pushes` que sin claves registra. Faltan claves de APNs (H1), Anthropic real y FCM con Android. Usa `spark_jobs` en vez de pgmq (a confirmar).
  pg_cron por zona horaria, Batches API, pgmq, APNs y FCM.
  Necesita: H1 (claves de push).
- [ ] **33. Moderación y reporte de contenido IA** · MAT-249 · Adelantado el 2026-10-16: moderación heurística de entrada y salida y reportes en `content_reports`. Falta un clasificador real antes del lanzamiento.
- [x] **34. Imágenes y PDFs** · MAT-239 · ✅ 2026-10-16: adjuntos en `capture-temp` (20 MB) con límites antes del modelo, borrado siempre y huérfanos a la hora.
- [x] **35. Planificador (backend)** · MAT-245 · ✅ 2026-10-16: SSE, Haiku o Sonnet según el modo, prompt caching y resumen cada 10 mensajes; método Disney.
  Streaming, Haiku o Sonnet según el modo, prompt caching y resumen incremental del hilo.
- [x] **36. Webhook de RevenueCat** · MAT-248 · ✅ 2026-10-16: idempotente por evento, solo entitlement pro, rechaza sin secreto. Falta configurarlo en RevenueCat (H1).
- [x] **37. Exportar datos, borrar cuenta y job de borrado** · MAT-252, MAT-251 · ✅ 2026-10-16: `export_my_data()`, `delete_my_account()` y los jobs de retención (invitados, texto crudo, web).
- [x] **38. Tablero de costos y alertas** · MAT-247 (parte 2) · ✅ 2026-10-16: vistas `llm_cost_dashboard`/`month`/`signals`, `cost_alerts` diario y `scripts/costos.sh`. Las alertas no salen por mail ni Slack.
- [x] **39. Contrato OpenAPI y clientes generados** · MAT-250 · ✅ 2026-10-16: `openapi.yaml` al día, test de contrato en CI y `scripts/generate-clients.sh` (Swift y Kotlin). La app sigue con su cliente a mano.
- [x] **40. App Attest y Play Integrity (verificación en el servidor)** · MAT-253 (parte 1) · ✅ 2026-10-16: App Attest (atestación y aserciones) y Play Integrity en `_shared/attest/`, detrás de `LUMBRE_ATTESTATION=off/report/enforce`. Falta probar con dispositivo y Play (H1).
- [ ] **41. Entornos remotos y deploy a staging** · MAT-230 (parte 2) · Adelantado en parte el 2026-09-27: `lumbre-dev` (`udewtaksxfnnchuhydnr`) creado en São Paulo, con las 3 migraciones y datos de prueba; verificado por SQL y por la API pública. Faltan staging y prod.
  Conectar dev, staging y prod; deploy a staging; medir el costo real por chispa en `llm_calls`.
  Necesita: H1.

**Compuerta F2:** evaluación ≥ 3,5 y chispa < US$ 0,005.

## D. iOS (F3)

Adelantado: se hace con datos de prueba. Las pantallas llaman a `LumbreAPI`; hoy responde `MockLumbreAPI` y en el paso 43 se cambia por el cliente real.

- [x] **42. Setup iOS** · MAT-255, MAT-272 (parte iOS) · ✅ 2026-09-27: proyecto con carpetas sincronizadas, LumbreDesign (tokens generados, tipografía, 5 componentes) y LumbreCore (modelos, `LumbreAPI`, mock, tests). Falta el archivo de Fraunces: usa New York como respaldo.
  Proyecto de Xcode, paquetes LumbreDesign y LumbreCore, generador de tokens a Swift, Fraunces incluida, String Catalog cargado con el copy del paso 10.
- [ ] **43. LumbreCore** · MAT-322, MAT-253 (parte iOS) · Adelantado en parte el 2026-09-27: `SupabaseLumbreAPI` sobre supabase-swift, conectado a `lumbre-dev`, con sesión en Keychain, un solo login compartido y login de desarrollo en Debug. Faltan Apple, Google y email en la UI (con el onboarding), la caché en SwiftData, App Attest y el cliente de las Edge Functions. · Ampliado el 2026-10-16: App Attest del lado de la app, cuenta con email, consentimiento en la cuenta y sesión en el Keychain compartido. Faltan Apple y Google (H1).
  Cliente de la API, auth (Apple, Google, email), sesión en Keychain, caché en SwiftData y App Attest.
- [ ] **44. Analytics y crashes** · MAT-270
  PostHog y Sentry con los eventos del paso 2. Va antes de las pantallas para que cada una se instrumente al construirse.
- [x] **45. TabView flotante y botón Capturar** · MAT-258 · ✅ 2026-09-27: Liquid Glass con Capturar separado a la derecha (lugar de la pestaña de búsqueda). Además quedaron versiones visuales con datos de prueba de Hoy, Bóveda, Perfil y la sheet de Capturar; sus pasos (47, 48, 51, 57) siguen abiertos para la funcionalidad completa.
- [x] **46. Onboarding** · MAT-256 · ✅ 2026-10-16: cuenta con email (flag `account_email`), copy neuronal y consentimiento para IA en el recorrido. Apple y Google con el 20b.
  Perfil, semillas, hora de la chispa, permiso de push y registro del token; crear cuenta o entrar como invitado.
- [x] **47. Hoy con reveal y contador** · MAT-257 · ✅ 2026-10-16: reveal en modal con Reducir movimiento; sin consentimiento no pide la chispa. 2026-10-17: coreografía del paso 12 aplicada (900 ms, háptico a los 650, cierre con fundido, cruz de 44 pt, `entry` de push y widget; flag `reveal_synapse`) y el contador pasa a usado después del reveal.
- [x] **48. Sheet de Capturar y cola offline** · MAT-259 · ✅ 2026-10-16: ya estaba completo; sin consentimiento no ofrece destilar y las animaciones respetan Reducir movimiento.
- [x] **49. Share Extension** · MAT-260 · ✅ 2026-10-17: Share Extension con texto, links, selección de Safari, imagen y PDF. Probada en el simulador: desde Fotos aparece "Lumbre" en la hoja de compartir, pide la idea y la categoría, y la neurona llegó a la base local directo con la sesión compartida. Falta probarla en un dispositivo con el App Group firmado (H1).
- [x] **50. OCR con VisionKit** · MAT-261 · ✅ 2026-10-16: VisionKit y Vision ya estaban; revisado sin cambios.
- [x] **51. Bóveda con búsqueda y filtros** · MAT-262 · ✅ 2026-10-16: búsqueda, filtros, borradores y estados ya estaban; revisado en AX5.
- [x] **52. Detalle de chispa y de concepto** · MAT-263 · ✅ 2026-10-16: "No me sirve" con motivo ya estaba; la chispa elegida pide consentimiento y los títulos se apilan en AX5.
  Incluye el feedback "No me sirve" con motivo.
- [x] **53. Planificador** · MAT-264 · ✅ 2026-10-16: sin consentimiento no manda; `account_required` ofrece cuenta; scroll con Reducir movimiento.
- [ ] **54. Paywall y RevenueCat** · MAT-265
  Necesita: H1 (RevenueCat y productos en App Store Connect).
- [x] **55. Widget y App Intents** · MAT-266, MAT-267 · ✅ 2026-10-16: widget de la chispa de hoy y de captura (todos los tamaños, pantalla bloqueada y control de iOS 18), App Intents y atajos de Siri, links `lumbre://`. Falta probarlo en dispositivo.
- [x] **56. Tarjeta para compartir** · MAT-268 · ✅ 2026-10-16: 1080×1920 con la chispa centrada. 2026-10-17: margen de 340 y categoría en una línea (flag `share_card_safe_zones`) y formato feed 1080×1350 como segunda opción (flag `share_card_feed`).
- [x] **57. Perfil y ajustes** · MAT-269 · ✅ 2026-10-16: "Crear cuenta" con email; cerrar sesión y borrar la cuenta limpian el consentimiento.
  Incluye exportar datos y borrar cuenta.
- [ ] **58. Accesibilidad** · MAT-271 · Adelantado el 2026-10-16: AX5 revisado en Hoy, Red, Perfil y Capturar (dos cortes arreglados) y Reducir movimiento en Capturar, planificador y chispa. 2026-10-17: AX5 recorrido también en detalle, planificador, paywall y onboarding, y la app en inglés. Falta VoiceOver en dispositivo.
  VoiceOver, Dynamic Type al máximo y Reducir movimiento en todas las pantallas.
- [ ] **59. fastlane y TestFlight interno** · MAT-254 (parte 2)
  Necesita: H1 (Apple Developer).

**Compuerta F3:** loop completo en TestFlight interno, sin crashes en 7 días de uso propio (H7).

## E. Beta iOS (F4)

- [x] **60. Kit de beta** · prep MAT-273, MAT-274 · ✅ 2026-10-16: `docs/beta/`: invitación, notas de TestFlight, encuesta de los 7 días, guion de llamadas y tablero de D1/D7 definido.
  Invitación a la waitlist, notas de TestFlight, encuesta de los 7 días, guion de llamadas y tablero de D1/D7 en PostHog.
- [ ] **61. Iterar con datos reales** · MAT-275
  Prompts, onboarding y hora de la chispa, a partir de los datos y el feedback de la beta.
  Necesita: H8 (unas 2 semanas de beta).

**Compuerta F4:** D7 ≥ 15%. Si D7 < 10%, no se arranca Android hasta arreglar el loop.

## F. Endurecer (F6)

- [x] **62. Revisión de seguridad** · MAT-293 · ✅ 2026-10-16: parte de backend e iOS en `backend/SECURITY-REVIEW.md`: 11 hallazgos arreglados (incluido el consentimiento para IA en el servidor) y 3 riesgos anotados. Suite completa en verde. La de Android va en el 86.
  RLS, claves, App Attest, rate limits y logs sin contenido de notas. La parte de Android se repite en el paso 86.
- [x] **63. Prueba de carga del batch (10x)** · MAT-294 · ✅ 2026-10-17: 10x completo, 5.000 usuarios × 20 conceptos: 5.000 chispas en 56 s (27 llamadas de 200, 0 errores) y 5.000 push en 12 s. El cron pasó de 15 min a cada minuto (de ~800 a ~12.000 usuarios por hora). Ver `backend/LOAD-TEST.md`.
- [x] **64. Borradores de términos, privacidad y consentimiento para IA** · MAT-295 · ✅ 2026-10-16: `docs/legal/`: borradores es/en de privacidad, términos y consentimiento para IA, coherentes con el backend. Esperan al abogado (H3).
  Para que los revise el abogado (H3).
- [x] **65. Privacy manifest, etiquetas de App Store y Data safety de Play** · MAT-296 · ✅ 2026-10-16: `PrivacyInfo.xcprivacy` y las respuestas de App Privacy y Data safety en `docs/tiendas/`.
- [ ] **66. Fichas de tienda es/en y capturas de iOS** · MAT-297 · Adelantado el 2026-10-16: fichas es/en y guion de 7 capturas en `docs/tiendas/`. 2026-10-17: las 7 capturas de iOS en español (1320×2868) en `design/tiendas/capturas/es/`, compuestas con `componer.sh`. Falta el set en inglés, que necesita datos de prueba en inglés.
  Las capturas muestran el choque, no la lista. Las de Android se hacen en el paso 86.

**Compuerta F6:** checklist de deploy de App Store de `plan.md` §10 completo.

## G. Lanzamiento iOS (F7)

- [ ] **67. Paquete de revisión de App Store** · MAT-299 · Adelantado el 2026-10-16: notas para el revisor, procedimiento de la cuenta demo y checklist de §10 en `docs/lanzamiento/revision-app-store.md`. Falta crear la cuenta.
  Cuenta demo con Pro, notas para el revisor y el checklist revisado.
- [x] **68. Kit de lanzamiento iOS** · MAT-301, prep MAT-300, MAT-302, MAT-303 · ✅ 2026-10-16: `docs/lanzamiento/`: Product Hunt, comunidades, email a la waitlist, pitch de featuring y mensaje para los creadores.
  Product Hunt, posts para comunidades, email a la waitlist, pitch de featuring y mensaje para los 20 creadores.

**Compuerta F7:** crash-free > 99,5% y costos de IA dentro de lo previsto.

## H. Android (F5)

Android va después del lanzamiento de iOS en vez de solaparse como en `plan.md` §9: con una sola persona, solapar no ahorra tiempo, y el resultado de la beta decide si se hace Android. Si preferís el orden de `plan.md`, este bloque se mueve antes del F.
Necesita: H9 (Android Studio y SDK, que hoy no están instalados).

- [ ] **69. Setup Android** · MAT-276, MAT-272 (se cierra acá)
  Módulos Gradle, Hilt, ColorScheme generado desde `tokens.json`, `strings.xml` desde el copy del paso 10.
- [ ] **70. Core Android** · MAT-323, MAT-324, MAT-253 (parte Android)
  Cliente de la API, auth, almacenamiento cifrado, Room, PostHog, Sentry y Play Integrity.
- [ ] **71. Floating toolbar y FAB** · MAT-279
- [ ] **72. Onboarding** · MAT-277
- [ ] **73. Hoy con reveal** · MAT-278
- [ ] **74. Capturar e intent ACTION_SEND** · MAT-280
- [ ] **75. Cola offline con WorkManager** · MAT-281
- [ ] **76. OCR con ML Kit y Document Scanner** · MAT-282
- [ ] **77. Bóveda** · MAT-283
- [ ] **78. Detalle de chispa y de concepto** · MAT-284
- [ ] **79. Planificador** · MAT-285
- [ ] **80. Paywall con Play Billing** · MAT-286
- [ ] **81. Widget con Glance** · MAT-287
- [ ] **82. Tarjeta para compartir** · MAT-288
- [ ] **83. Perfil y ajustes** · MAT-289
- [ ] **84. Accesibilidad** · MAT-291
- [ ] **85. Baseline Profiles y gama media** · MAT-290
- [ ] **86. Preparación de Play** · prep MAT-292
  fastlane supply, capturas de Android, revisión de seguridad de la app Android e invitación para los 12+ testers.

**Compuerta F5:** paridad con iOS, arranque en frío < 1,5 s en gama media y prueba cerrada cumplida (H10).

## I. Lanzamiento Android (F8)

- [ ] **87. Kit de lanzamiento LATAM y rollout** · MAT-305, prep MAT-304
  Campaña con creadores regionales y prensa tech, y la guía de rollout 10% → 50% → 100% mirando Android Vitals.

**Compuerta F8:** ANR y crashes por debajo de los umbrales de Play Vitals.

## J. Ideas nuevas (agregadas el 2026-10-17)

Salen de una lista de ideas revisada el 2026-10-17; las elegidas están en `plan.md` §4 (versión 1.1). Van en orden de valor. Cada una detrás de su feature flag, con sus eventos en `docs/analytics.md`, en iOS primero (Android las toma al llegar a su paso). Las que no dependen de cuentas (88, 90, 93) se pueden adelantar antes del lanzamiento si sobra tiempo.

- [x] **88. La chispa guardada se vuelve neurona** · flag `spark_neuron` · ✅ 2026-10-17: migración `20261017100000_chispa_neurona.sql` (`save_spark()` con `p_as_neuron`, apagable con `app_config.spark_neuron_enabled`; dominio por cercanía al embeberse; `spark_pairs`/`create_spark` y `/spark` pick nunca la cruzan con sus padres; no cuenta para la extra), pgTAP `12_chispa_neurona.sql`, e2e, y en iOS "Nació de una chispa" con "Ver la chispa original". Falta verlo a ojo en el simulador.
  Al guardar una chispa se crea una neurona con su título y su cuerpo (embebidos en el servidor) y la referencia a sus dos neuronas de origen. El emparejamiento nunca la cruza con sus padres; no gasta cupo de captura ni suma para la chispa extra (si no, guardar chispas daría chispas). En la Red se ve con "Nació de una chispa" y desde ahí se llega a la chispa original. Migración, pgTAP y tests del emparejamiento.
  Listo cuando: una chispa guardada aparece en la Red, puede salir en una chispa nueva con otra neurona y nunca con sus padres.
- [x] **89. Importar notas: Markdown y Apple Notes** · flag `import_notes` · ✅ 2026-10-17: Red › Más › Importar notas (archivos `.md` o una bóveda de Obsidian) y `ImportNotesIntent` para el atajo de Apple Notes, con vista previa (elegir, descartar, categoría por carpeta, tesis editable); las largas se conceptualizan desde la nota entera con Acepto y cupo; cupo `import` de 50 en free e invitado y cada nota cuenta como captura (lo que sobra sigue mañana desde la cola, con aviso). Tests de LumbreCore, pgTAP, e2e de `/capture` y verificado en el simulador con `-mock`. Provisorio: 500 por tanda en Pro y que cuenten para la chispa extra (ios/README.md).
  Markdown: archivos `.md` sueltos o una carpeta de Obsidian (desde Archivos). Apple Notes: un atajo de Atajos que busca las notas y se las pasa a un App Intent de Lumbre (no hay API para leerlas en bloque). Cada nota entra por `/capture`, con la cola offline, y con los límites de §4: 50 en free, ilimitado en Pro. Vista previa antes de importar, con elegir y descartar.
  Decidido el 2026-10-17: las notas largas se conceptualizan con IA (gastan el cupo de conceptualización y necesitan el "Acepto"); si no hay cupo o consentimiento, la tesis es la primera línea, editable en la vista previa. Importar cuenta para el tope de 30 capturas por día: lo que pase del tope queda en la cola y sigue al día siguiente, con aviso.
- [x] **90. Lentes en el planificador** · flag `planner_lenses` · ✅ 2026-10-17: prompt `planner_lens.v1` como bloque aparte sobre planner.v2 (o v1), con la chispa delimitada; `/planner` con `lens`, respuestas con `[[lens:…]]` que no mueven los cuartos de Disney; evento `planner_lens_used` y `lens` en `planner_message_sent`; tests de Deno, e2e (las tres lentes, 400 y 403 sin consentimiento) y verificado en el simulador con `-mockPro`. El formato con el modelo real queda para cuando haya clave de Anthropic.
  Tres atajos más en el planificador (Pro): "Modelo de negocio", "Trama" y "Post". Cada uno es un pedido con su formato de salida, sobre `planner.v2`. Evento con la lente elegida.
  Listo cuando: los tres atajos responden con su formato y respetan el consentimiento para IA.
- [ ] **91. Perilla de distancia** · flag `distance_dial`
  Lineal, Serendipia (por defecto) y Caos al pedir una chispa a mano (extra y Pro); la diaria no cambia. Cada posición corre la banda de `pick_spark_pair` (provisorio: percentiles 20–50, 40–80 y 70–95, a calibrar con el set de evaluación). "Caos" se evalúa aparte con el harness del paso 29.
  Necesita: paso 30 (prompt de chispa evaluado).
- [x] **92. Temas puente** · flag `bridge_topics` · ✅ 2026-10-17: solo Pro; `bridge_domain_pair()` (5 neuronas propias por dominio y como mucho 1 chispa entre los dos, en `app_config`), cupo semanal `bridge_topics` por `consume_credit()`, Edge Function `bridge-topics` con `bridge.v1` que descarta links y obras, tarjeta en la Red y en Hoy (con pocos pares) y eventos `bridge_topics_shown` y `bridge_topic_tapped`. Probado con pgTAP, Deno, e2e y en el simulador con `-mockPro`; queda provisorio tocar un tema (buscar en la web con `x-web-search` o copiar) y los umbrales.
  Si la Red tiene mucho de dos dominios que casi no se cruzaron, Lumbre sugiere 2 o 3 temas para leer que los unan ("bioarte" entre biología y arte). Solo temas, nunca artículos ni links. Una llamada por semana como mucho; se puede sumar al resumen semanal. Se muestra en la Red, y en Hoy cuando quedan pocos pares buenos.
  Decidido el 2026-10-17: solo Pro.
- [x] **93. Swipe en el reveal** · flag `reveal_swipe` · ✅ 2026-10-17: gesto en `design/reveal/` (README §12 y prototipo); en iOS, `UIPanGestureRecognizer` en el scroll del modal (un `DragGesture` le ganaba al scroll en iOS 18), `SparkActionRequest` en `SparkActions`, acciones de VoiceOver y evento `spark_swiped`. Probado en el simulador en los dos sentidos y en AX5; quedan provisorios la rotación, los hápticos, que el swipe cierre el modal y el popover del motivo en iOS 26.
  En el modal, ya revelada (desde los 900 ms): deslizar a la derecha guarda (abre la elección de circuito si está `projects`) y a la izquierda abre "No me sirve" con su motivo. La tarjeta sigue al dedo, con umbral, háptico y vuelta si no llega al umbral; con Reducir movimiento, sin fling. Los botones se quedan y VoiceOver usa acciones (`accessibilityAction`). Primero el gesto en `design/reveal/`.
  Listo cuando: el swipe funciona en los dos sentidos, no choca con el scroll del panel en AX5 y VoiceOver puede hacer lo mismo sin gesto.

Lo demás de la versión 1.1 en adelante (F9) se planifica aparte después del lanzamiento. Si falta tiempo, se recorta en el orden de `plan.md` §4.

---

## Te toca a vos

Tareas que no puedo hacer yo. Se pueden hacer en paralelo a los pasos.

| # | Tarea | Issue | Desbloquea |
|---|---|---|---|
| H1 | Crear las cuentas: Apple Developer (D-U-N-S si es organización), Google Play, Supabase, Anthropic, RevenueCat, PostHog, Sentry y un proveedor de email | MAT-216 | 5, 6, 20, 22, 32, 41, 54, 59 |
| H2 | ~~Crear el repo en GitHub~~ Hecho: github.com/matiasrodriguezc/Lumbre | — | 19 |
| H3 | Búsqueda de marca con abogado y revisión de términos | MAT-213, MAT-295 | Compuerta F0, 64 |
| H4 | Consultar al contador | MAT-217 | 54 (precios y cobro) |
| H5 | Hacer las 12 entrevistas y armar el design system en Figma | MAT-212, MAT-221 | Compuertas F0 y F1 |
| H6 | Testear el prototipo y el ícono con 5 personas; puntuar el set de evaluación | MAT-224, MAT-210, MAT-243 | Compuerta F1, 30 |
| H7 | Usar la app 7 días en TestFlight interno | — | Compuerta F3 |
| H8 | Correr la beta con 50–100 personas, la encuesta y las llamadas | MAT-273, MAT-274 | 61 |
| H9 | Instalar Android Studio y el SDK | — | 69 en adelante |
| H10 | Prueba cerrada de Play con 12+ testers por 14 días | MAT-292 | Compuerta F5 |
| H11 | Pedir el Small Business Program de Apple | MAT-298 | Lanzamiento iOS |
| H13 | Resolver la facturación de GitHub (Actions está bloqueado: "account is locked due to a billing issue") y volver a correr el workflow Backend | — | 19 (que el CI corra en GitHub) |
| H14 | Ajustes de Auth de `lumbre-dev` en el dashboard: invitados, vinculación manual, redirect `lumbre://auth-callback` y rate limit (lista en `backend/README.md`, sección Auth) | — | Que el remoto acepte invitados y el link mágico de la app |
| H12 | Publicar el build in public y ejecutar los lanzamientos | MAT-219, MAT-300, MAT-302, MAT-303, MAT-304 | — |

## Issues creados en el paso 1

- MAT-321 Monorepo, git y CLAUDE.md (F0 Validar)
- MAT-322 LumbreCore iOS: cliente de API, auth, sesión y caché (F3 iOS)
- MAT-323 Core Android: cliente de API, auth, sesión y Room (F5 Android)
- MAT-324 Analytics y crashes Android: PostHog y Sentry (F5 Android)
