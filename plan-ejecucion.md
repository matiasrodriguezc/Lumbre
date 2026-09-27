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
- [ ] **4. Paquete de trámites** · MAT-214, prep MAT-213, MAT-216, MAT-217
  Chequeo real de dominios, handles y nombre en tiendas (cierra MAT-214); brief para el abogado (INPI, USPTO, EUIPO, clases 9 y 42, alternativas); lista de cuentas en orden, con el D-U-N-S primero porque tarda; preguntas para el contador.
- [ ] **5. Landing con waitlist y referidos** · MAT-215 (parte 1), MAT-220
  Sitio en `/web` con la marca, tabla `waitlist` con código de referido y posición en la fila, email de confirmación.
  Necesita: H1 para publicarla (se puede construir en local antes).
- [ ] **6. Demo web de chispa** · MAT-215 (parte 2)
  Pegás dos ideas y aparece una chispa. Edge Function con un prompt v0, límite por email y por IP, una chispa por día por email.
  Necesita: H1 (clave de Anthropic y proveedor de email).
- [ ] **7. Kit de build in public** · prep MAT-219
  Calendario de 4 semanas, 20 "chispas del día" escritas, plantillas de post por red y plantilla visual.

**Compuerta F0:** Lumbre confirmado como marca, 150+ en la waitlist, 3 dolores repetidos en las entrevistas.

## B. Diseño (F1)

- [ ] **8. Wordmark en curvas y exportes del ícono** · MAT-222
  Wordmark pasado a trazos con Fraunces; PNG de iOS 1024 (claro, dark y tinted) y de Android (adaptive foreground/background y monochrome).
- [ ] **9. Tokens listos para Figma** · prep MAT-221
  `tokens.json` exportado como variables de Figma con modos oscuro y claro, más instrucciones de importación.
- [ ] **10. Copy es/en de todas las pantallas** · MAT-226
  Archivo de claves en `design/copy/` que después alimenta los String Catalogs y `strings.xml`.
- [ ] **11. Estados vacíos, error, offline y contenido inaccesible** · MAT-227
  Especificación, copy y mockups HTML de cada estado.
- [ ] **12. Coreografía del reveal** · MAT-225
  Tiempos, curvas y hápticos del reveal de 900 ms, más un prototipo HTML animado con la variante de Reducir movimiento.
- [ ] **13. Tarjeta para compartir y widget** · MAT-228, MAT-229
  Mockups HTML en tamaño real (historia 1080×1920; tamaños de widget de iOS y de Glance).
- [ ] **14. Prototipo navegable del loop** · MAT-223
  HTML clickeable: onboarding → Hoy → Capturar → Bóveda → detalle → paywall, con selector iOS/Android. Incluye los dos caminos de entrada (crear cuenta o entrar como invitado) y define qué puede hacer el invitado y cuándo se le pide la cuenta. Se publica para el test.
- [ ] **15. Kit de test del prototipo y del ícono** · prep MAT-224, MAT-210
  Guion de tareas, preguntas sobre el ícono solo y planilla de resultados.

**Compuerta F1:** 4 de 5 testers completan el onboarding y guardan una idea sin ayuda.

## C. Backend e IA (F2)

Todo arranca en local con Supabase CLI y Docker; los entornos remotos se conectan en el paso 41.

- [x] **16. Supabase local y migraciones** · MAT-230 (parte 1) · ✅ 2026-09-27: migración base con RLS reforzado (el usuario ya no puede cambiarse el plan, gastar cuota ajena ni insertar conceptos directo), seed con usuarios A y B, puertos 555xx para convivir con Ronda. `backend/db/schema.sql` quedó reemplazado.
  `supabase init` en `/backend`, `schema.sql` pasado a migraciones, seed y scripts de arranque. Renombrar `concepts.is_guest` a `from_library` para no confundirlo con el usuario invitado, y usar en `creative_profiles` los mismos slugs que `docs/analytics.md`.
- [x] **17. RLS y tests "usuario A no ve datos de B"** · MAT-232 · ✅ 2026-09-27: 35 tests de pgTAP en `backend/supabase/tests/database/01_rls.sql`, más una guarda que falla si una tabla nueva no tiene RLS. Verificado rompiendo permisos a propósito.
  pgTAP sobre cada tabla con datos de usuario.
- [ ] **18. Cuotas** · MAT-233
  `consume_credit()` atómico, `plan_limits` cargado con los valores de `plan.md` (más límites para invitados), `usage_ledger` y un test de concurrencia.
- [ ] **19. CI del backend** · MAT-254 (parte 1)
  GitHub Actions corre las migraciones y los tests en cada PR.
  Necesita: H2.
- [ ] **20. Auth** · MAT-231
  Sign in with Apple, Google y email mágico; sesión anónima para invitados y vinculación de la cuenta sin perder datos; creación del perfil al registrarse.
  Necesita: H1 (credenciales de Apple y Google) para probarlo contra los proveedores reales.
- [ ] **21. Lista cerrada de dominios** · MAT-234
  20 a 25 dominios con una descripción cada uno, pensada para embeberla; seed.
- [ ] **22. Elegir el modelo de embeddings** · MAT-235
  Comparar 2 o 3 candidatos multilingües con un set chico de pares es/en; decisión documentada.
  Necesita: H1 (claves).
- [ ] **23. Gateway de IA** · MAT-246, MAT-247 (parte 1)
  Módulo compartido de Edge Functions: reintentos, backoff, modelo de respaldo, tope diario en dólares y registro de cada llamada en `llm_calls`.
- [ ] **24. Endpoint de captura** · MAT-236
  Texto, voz, selección y OCR; limpieza del texto; límite de 30 por día.
- [ ] **25. Destilación** · MAT-237
  Haiku 4.5 con JSON estructurado y nivel de confianza (alta se guarda, media queda en borrador, baja cae a "¿Qué idea te deja esto?").
- [ ] **26. Lectura de links** · MAT-238
  Contenido más Open Graph, priorizando lo que llegó en la captura; el contenido externo se trata como datos.
- [ ] **27. Clasificación de dominio por embedding** · MAT-240
- [ ] **28. Emparejamiento** · MAT-241
  Banda media por usuario, pares únicos, descanso de 3 días y elección entre los 20 mejores; tests con datos sintéticos.
- [ ] **29. Set de evaluación y harness** · MAT-243 (parte 1)
  100 pares por perfil, un script que genera las chispas y una planilla para puntuar "sorprende" y "sirve".
- [ ] **30. Prompt de chispa** · MAT-243 (parte 2)
  Iterar el prompt con tus puntajes hasta un promedio de 3,5 o más; prompt versionado.
  Necesita: H6.
- [ ] **31. Biblioteca de conceptos invitados** · MAT-242
- [ ] **32. Batch nocturno y push** · MAT-244
  pg_cron por zona horaria, Batches API, pgmq, APNs y FCM.
  Necesita: H1 (claves de push).
- [ ] **33. Moderación y reporte de contenido IA** · MAT-249
- [ ] **34. Imágenes y PDFs** · MAT-239
- [ ] **35. Planificador (backend)** · MAT-245
  Streaming, Haiku o Sonnet según el modo, prompt caching y resumen incremental del hilo.
- [ ] **36. Webhook de RevenueCat** · MAT-248
- [ ] **37. Exportar datos, borrar cuenta y job de borrado** · MAT-252, MAT-251
- [ ] **38. Tablero de costos y alertas** · MAT-247 (parte 2)
- [ ] **39. Contrato OpenAPI y clientes generados** · MAT-250
- [ ] **40. App Attest y Play Integrity (verificación en el servidor)** · MAT-253 (parte 1)
- [ ] **41. Entornos remotos y deploy a staging** · MAT-230 (parte 2)
  Conectar dev, staging y prod; deploy a staging; medir el costo real por chispa en `llm_calls`.
  Necesita: H1.

**Compuerta F2:** evaluación ≥ 3,5 y chispa < US$ 0,005.

## D. iOS (F3)

Adelantado: se hace con datos de prueba. Las pantallas llaman a `LumbreAPI`; hoy responde `MockLumbreAPI` y en el paso 43 se cambia por el cliente real.

- [x] **42. Setup iOS** · MAT-255, MAT-272 (parte iOS) · ✅ 2026-09-27: proyecto con carpetas sincronizadas, LumbreDesign (tokens generados, tipografía, 5 componentes) y LumbreCore (modelos, `LumbreAPI`, mock, tests). Falta el archivo de Fraunces: usa New York como respaldo.
  Proyecto de Xcode, paquetes LumbreDesign y LumbreCore, generador de tokens a Swift, Fraunces incluida, String Catalog cargado con el copy del paso 10.
- [ ] **43. LumbreCore** · MAT-322, MAT-253 (parte iOS)
  Cliente de la API, auth (Apple, Google, email), sesión en Keychain, caché en SwiftData y App Attest.
- [ ] **44. Analytics y crashes** · MAT-270
  PostHog y Sentry con los eventos del paso 2. Va antes de las pantallas para que cada una se instrumente al construirse.
- [x] **45. TabView flotante y botón Capturar** · MAT-258 · ✅ 2026-09-27: Liquid Glass con Capturar separado a la derecha (lugar de la pestaña de búsqueda). Además quedaron versiones visuales con datos de prueba de Hoy, Bóveda, Perfil y la sheet de Capturar; sus pasos (47, 48, 51, 57) siguen abiertos para la funcionalidad completa.
- [ ] **46. Onboarding** · MAT-256
  Perfil, semillas, hora de la chispa, permiso de push y registro del token; crear cuenta o entrar como invitado.
- [ ] **47. Hoy con reveal y contador** · MAT-257
- [ ] **48. Sheet de Capturar y cola offline** · MAT-259
- [ ] **49. Share Extension** · MAT-260
- [ ] **50. OCR con VisionKit** · MAT-261
- [ ] **51. Bóveda con búsqueda y filtros** · MAT-262
- [ ] **52. Detalle de chispa y de concepto** · MAT-263
  Incluye el feedback "No me sirve" con motivo.
- [ ] **53. Planificador** · MAT-264
- [ ] **54. Paywall y RevenueCat** · MAT-265
  Necesita: H1 (RevenueCat y productos en App Store Connect).
- [ ] **55. Widget y App Intents** · MAT-266, MAT-267
- [ ] **56. Tarjeta para compartir** · MAT-268
- [ ] **57. Perfil y ajustes** · MAT-269
  Incluye exportar datos y borrar cuenta.
- [ ] **58. Accesibilidad** · MAT-271
  VoiceOver, Dynamic Type al máximo y Reducir movimiento en todas las pantallas.
- [ ] **59. fastlane y TestFlight interno** · MAT-254 (parte 2)
  Necesita: H1 (Apple Developer).

**Compuerta F3:** loop completo en TestFlight interno, sin crashes en 7 días de uso propio (H7).

## E. Beta iOS (F4)

- [ ] **60. Kit de beta** · prep MAT-273, MAT-274
  Invitación a la waitlist, notas de TestFlight, encuesta de los 7 días, guion de llamadas y tablero de D1/D7 en PostHog.
- [ ] **61. Iterar con datos reales** · MAT-275
  Prompts, onboarding y hora de la chispa, a partir de los datos y el feedback de la beta.
  Necesita: H8 (unas 2 semanas de beta).

**Compuerta F4:** D7 ≥ 15%. Si D7 < 10%, no se arranca Android hasta arreglar el loop.

## F. Endurecer (F6)

- [ ] **62. Revisión de seguridad** · MAT-293
  RLS, claves, App Attest, rate limits y logs sin contenido de notas. La parte de Android se repite en el paso 86.
- [ ] **63. Prueba de carga del batch (10x)** · MAT-294
- [ ] **64. Borradores de términos, privacidad y consentimiento para IA** · MAT-295
  Para que los revise el abogado (H3).
- [ ] **65. Privacy manifest, etiquetas de App Store y Data safety de Play** · MAT-296
- [ ] **66. Fichas de tienda es/en y capturas de iOS** · MAT-297
  Las capturas muestran el choque, no la lista. Las de Android se hacen en el paso 86.

**Compuerta F6:** checklist de deploy de App Store de `plan.md` §10 completo.

## G. Lanzamiento iOS (F7)

- [ ] **67. Paquete de revisión de App Store** · MAT-299
  Cuenta demo con Pro, notas para el revisor y el checklist revisado.
- [ ] **68. Kit de lanzamiento iOS** · MAT-301, prep MAT-300, MAT-302, MAT-303
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

Lo de la versión 1.1 en adelante (F9) se planifica aparte después del lanzamiento. Si falta tiempo, se recorta en el orden de `plan.md` §4.

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
| H12 | Publicar el build in public y ejecutar los lanzamientos | MAT-219, MAT-300, MAT-302, MAT-303, MAT-304 | — |

## Issues creados en el paso 1

- MAT-321 Monorepo, git y CLAUDE.md (F0 Validar)
- MAT-322 LumbreCore iOS: cliente de API, auth, sesión y caché (F3 iOS)
- MAT-323 Core Android: cliente de API, auth, sesión y Room (F5 Android)
- MAT-324 Analytics y crashes Android: PostHog y Sentry (F5 Android)
