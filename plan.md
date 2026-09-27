# Lumbre: plan de producto

Documento de referencia del proyecto. Consolida todas las decisiones tomadas hasta el 27 de septiembre de 2026. Si algo acá contradice al plan maestro en HTML, manda este archivo.

- Plan maestro visual: `docs/plan-maestro.html` (también publicado en https://claude.ai/artifact/5iV97U3ZbfsQG7YLNhQRrv)
- Design system: carpeta `design/system/` (también publicado en https://claude.ai/artifact/9WfjY7YYfFwNrd92prTw3D)
- Esquema de base de datos: `backend/db/schema.sql`

---

## 1. Qué es Lumbre

Una app de creatividad por recombinación, basada en el método de *idea stacking*: las buenas ideas salen de combinar ideas existentes de formas nuevas.

El loop tiene cuatro pasos:

1. **Absorber.** El usuario guarda lo que lee, escucha o piensa, desde cualquier app.
2. **Destilar.** La IA convierte lo guardado en un concepto atómico: título, tesis, principio y dominio.
3. **Chocar.** Cada mañana, dos conceptos de dominios distintos chocan y aparece una chispa (la idea del día).
4. **Crear.** La idea baja a un proyecto, un plan y un export a las herramientas del usuario.

La app se llama **Lumbre**. Lo que genera cada día se llama **chispa**. De la chispa sale la lumbre.

## 2. Nombre

- **Chispa** se descartó: es una app de citas de Match Group (dueños de Tinder), activa desde 2017, con más de 7 millones de descargas, "Super Chispas" y mecánica de swipe.
- **Lumbre** es el nombre de trabajo. Es español, corto y cálido. Su relación con las ideas es indirecta ("encender una idea", "ser una lumbrera"); el tagline lo cierra: *Lumbre. Donde se encienden las ideas.*
- En inglés puede leerse como *lumber*; es aceptable si el foco inicial es hispano.
- **Pendiente:** búsqueda de marca con abogado en INPI, USPTO y EUIPO (clases 9 y 42), más tiendas, dominio y handles.
- Alternativas si Lumbre no pasa: **Espurna** (chispa en catalán), **Hirameki** (閃き, destello de inspiración en japonés), **Chiribita** (sinónimo de chispa en la RAE).

## 3. Identidad visual

### Logo
- Filamento de foco simplificado, inspirado en los filamentos LED en espiral: una varilla vertical `signal-blue` envuelta por una espiral de tres vueltas. Los tramos de atrás son `nebula-violet` y los de adelante `spark` (magenta).
- La historia: la varilla es un concepto, la espiral es otro; donde se tocan, se enciende la idea.
- Plano, sin degradés: la profundidad sale solo del cambio de color entre tramos.
- Se lee bien a 29px.
- Wordmark: "Lumbre" en Fraunces 600 con curvas blandas, seguido de un punto magenta.
- Archivos en `design/system/logo/`. El wordmark de los SVG depende de la fuente instalada: para el archivo final hay que pasarlo a curvas en Figma.
- Ícono de app: símbolo al 66% de alto sobre `night`, en cuadrado a sangre (cada sistema aplica su máscara). Falta exportar variantes dark y tinted de iOS y adaptive + monochrome de Android.
- Riesgo de lectura: una forma que envuelve una vara puede recordar al símbolo de medicina o a un "$". Validar el ícono solo con personas sin contexto.
- Versiones anteriores descartadas: estrella de cuatro puntas (época Chispa), dos llamas cruzadas y filamento con red de nodos. Quedan en `design/system/logo/anteriores/`.

### Paleta (Sunset Nebula)
| Token | Hex | Uso |
|---|---|---|
| night | #0A1633 | Fondo del modo oscuro (default), tinta del modo claro |
| signal-blue | #2D6CDF | Información, llama izquierda del logo |
| nebula-violet | #7E22CE | Todo lo Pro, llama derecha del logo |
| spark | #FF3EA5 | Solo el momento chispa: CTA principal, chispa del día, contador |
| cream | #FFF7ED | Fondo del modo claro, tinta del modo oscuro |

Reglas clave:
- Texto sobre magenta siempre en azul noche (5,52:1). Blanco sobre magenta no pasa accesibilidad (3,24:1).
- Magenta como texto: #FF6BB8 en oscuro, #C2106F en claro.
- Un solo elemento magenta protagonista por pantalla.
- Todo el texto cumple 4,5:1 en ambos temas.

### Tipografía
- **Fraunces** (serif variable, OFL) para la marca: wordmark, títulos de pantalla, título de la chispa y contador. Peso 600, eje SOFT en 100. El eje WONK en 1 solo para wordmark y título de la chispa. Mínimo 20pt, nunca en botones, chips, listas ni texto corrido. Números con `lining-nums tabular-nums`.
- **Fuente del sistema** (SF Pro en iOS, Roboto Flex/Roboto en Android) para todo lo demás. Garantiza Dynamic Type y la escala de fuente de Android.
- El contraste serif cálida + sans nativa es intencional: dos mundos que conviven y dan algo nuevo.

### Navegación
- Barra flotante con cuatro destinos (Hoy, Bóveda, Proyectos, Perfil) y, separado a su derecha, un botón + flotante para Capturar.
- **iOS:** `TabView` nativa, que en iOS 26 ya es flotante y de Liquid Glass, con `.tabBarMinimizeBehavior(.onScrollDown)`. El + es un botón circular con `.glassEffect` tintado en magenta dentro de un `GlassEffectContainer`. En versiones sin Liquid Glass, `.ultraThinMaterial` con la misma forma.
- **Android:** floating toolbar de Material 3 Expressive, destino activo expandido en pill con etiqueta, inactivos solo ícono, y FAB magenta separado. La API está en evolución: verificar la versión de material3.

## 4. Funcionalidades

### Versión 1.0
- **Onboarding con perfil creativo:** hasta dos perfiles (Software y apps, Contenido y escritura, Negocios, Diseño, Curiosidad libre), 3 ideas semilla, hora elegida para la chispa diaria y permiso de push con contexto. La cuenta se puede crear en el onboarding o se puede **entrar como invitado** para conocer la interfaz y crearla después; el invitado usa una sesión anónima de Supabase, así que al crear la cuenta no se pierde nada. Qué puede hacer el invitado y en qué momento se le pide la cuenta se define en el prototipo.
- **Captura de texto y voz ilimitada:** sheet global, Share Extension (iOS), intent de compartir (Android), cola offline. La voz dictada se transcribe en el teléfono y cuenta como texto. Rate limit anti-abuso de 30 capturas por día.
- **Texto seleccionado desde otra app:** llega el fragmento más la URL de origen.
- **Capturas de pantalla y escaneo de páginas de libro:** OCR en el teléfono (VisionKit / ML Kit Document Scanner), entran como texto, gratis.
- **Adjuntos en free:** link, imagen, PDF o audio quedan como fuente y el usuario escribe "¿Qué idea te deja esto?" en una línea.
- **Destilación automática (Pro, con 3 a 5 pruebas por mes en free):** la IA lee links, imágenes, PDFs y audios largos y saca de 1 a 3 conceptos.
- **Categoría sugerida:** por embedding, se confirma o cambia con un toque. Nunca categorización manual pura.
- **Chispa diaria:** 1 gratis por día, generada de noche, notificada a la hora elegida. Guardar 3 conceptos nuevos da 1 chispa extra, hasta 2 extra por día.
- **Feedback "No me sirve":** con motivo (obvia, irrelevante, ya la tuve), ajusta los próximos emparejamientos.
- **Tarjeta para compartir:** imagen vertical con la chispa y la marca, para historias. Es el loop de crecimiento.
- **Widget:** chispa del día y captura rápida (WidgetKit y Glance).
- **Bóveda ilimitada con búsqueda semántica.**
- **Más chispas a pedido (Pro):** hasta 10 por día.
- **Planificador (Pro):** chat anclado a cada idea con el contexto del perfil, los dos conceptos y el proyecto. Backlog, abogado del diablo, stack.
- **Export a Markdown.**
- **Exportar datos y borrar cuenta desde la app** (obligatorio en ambas tiendas).

### Versión 1.1
- **Modo problema (Pro):** el usuario escribe un problema y Lumbre elige conceptos de su bóveda para aplicarle.
- **Proyectos con tablero:** 1 en free, ilimitados en Pro.
- **Export a Notion, Linear y GitHub (Pro).**
- **Videos y podcasts por link (Pro):** transcripción cuando está disponible por vías permitidas.
- **Importar subrayados y notas:** Kindle, Apple Books, Readwise, Markdown, Notion, Apple Notes, Keep. Hasta 50 en free, ilimitado en Pro.
- **Resumen semanal.**

### Versión 2.0
- Grafo de conceptos (Pro).
- Reenvío de email y extensión de navegador.
- Modo de notas manuscritas.
- iPad, Mac y web de lectura.
- Lumbre para equipos.

### Recorte si falta tiempo (en este orden)
Grafo, proyectos con tablero, exports a terceros, modo problema. No se tocan: onboarding, captura, chispa diaria con push, bóveda, paywall + planificador y la tarjeta para compartir.

### Formatos que no se soportan
Archivos de video subidos (caros, y el valor está en el audio) y formatos de oficina (Word, PowerPoint).

## 5. Motor de IA

### Captura y destilación
- La destilación usa **Claude Haiku 4.5** con salida JSON estructurada:

```json
{
  "domain": "Ingeniería",
  "title": "Separación ciclónica",
  "thesis": "Un flujo en espiral separa partículas por fuerza centrífuga, sin filtro.",
  "principle": "Un movimiento rotatorio ordena elementos por su masa.",
  "confidence": "high",
  "reason": null
}
```

- El dominio sale de una **lista cerrada de 20–25 categorías** (Tecnología, Biología, Física, Economía, Psicología, Diseño, Historia, Arte, Música, Urbanismo, Cocina, Deporte, Negocios, etc.). Si fuera libre, "Ingeniería" e "Ingeniería mecánica" quedarían separadas y se rompería el cruce.
- **Confianza:** alta, se guarda directo; media, queda como borrador para confirmar; baja o contenido inaccesible, se cae al flujo de "¿Qué idea te deja esto?".
- **Textos de menos de 30 palabras** se embeben directo, sin destilar.
- **Qué aporta la destilación:** matches entre mundos distintos (se embebe el mecanismo, no las palabras), conceptos atómicos (un link puede dar 2 o 3), chispas más baratas y mejores (60 tokens en vez de 800 por concepto), categoría más precisa, una bóveda legible, idioma unificado y una diferencia visible para vender Pro.

### Qué se puede extraer de cada fuente
| Fuente | Resultado |
|---|---|
| Blogs, noticias sin muro, Wikipedia, docs, Substack gratis, GitHub | Contenido completo, buen concepto |
| Noticias con muro de pago | Solo título y descripción |
| YouTube | Título, descripción y transcripción si está disponible por vías permitidas |
| X, Reddit | Texto del post por APIs o embeds oficiales, si es público |
| Instagram, TikTok, Facebook, LinkedIn | Casi nada (login y bloqueo de bots) |
| Documentos privados | Nada |
| Imágenes | Casi siempre sí. El problema es cuando no hay idea adentro (un paisaje, una foto personal) |

- Siempre usar primero lo que llegó en la captura (texto compartido, fragmento).
- En iOS, la extensión de Safari puede leer la página tal como la ve el usuario.
- Imágenes: reducirlas antes de enviarlas; unos 1.000–1.500 tokens, menos de US$ 0,003 con Haiku.
- El contenido externo se trata siempre como datos, nunca como instrucciones (defensa contra prompt injection).
- Descargar transcripciones de YouTube o redes tiene restricciones en sus términos: usar APIs oficiales y revisar qué permiten.

### Embeddings
- Siempre en el servidor, con **un único modelo para todo** (usuarios, destilados y crudos). Los vectores de modelos distintos no se pueden comparar.
- No usar los embeddings nativos del teléfono: iOS y Android darían vectores incompatibles.
- Con destilación se embebe "principio + tesis"; sin destilación, el texto limpio (sin emojis, URLs sueltas ni espacios de más, cortado a unas 500 palabras).
- Sin destilación, el dominio se asigna por cercanía a los vectores de cada categoría.
- Se guarda el nombre del modelo junto al vector. Si se cambia de modelo, se re-embebe toda la base en un job nocturno.
- Van en **pgvector**, como columna de `concepts` en el mismo Postgres. No hace falta una base vectorial aparte.

### Emparejamiento
- Es SQL, sin LLM y sin costo de tokens.
- Pares de **dominios distintos** con distancia en una **banda media relativa a cada usuario** (por ejemplo, percentiles 40–80 de sus propias distancias). No la menor conexión: los pares más lejanos dan disparates y los más cercanos, obviedades. La banda se calibra con el feedback.
- El par nunca se repite: se guarda ordenado (id menor, id mayor) con restricción única.
- **Descanso por concepto:** 3 días sin aparecer en una chispa.
- De los 20 mejores candidatos se elige uno ponderando perfil, feedback y novedad.
- Con n conceptos hay n×(n−1)/2 pares; se agotan antes los pares buenos que los pares.
- Si quedan menos de 7 días de candidatos buenos, se pide al usuario capturar más (con el incentivo de la chispa extra).
- Respaldo para que Hoy nunca quede vacía: combinar un concepto del usuario con un **concepto invitado** de una biblioteca curada por perfil.

### Generación y planificador
- La chispa diaria se genera en un **batch nocturno por zona horaria** con la Batches API (50% menos) y se notifica a la hora elegida.
- Chispas extra y de Pro en tiempo real con Haiku 4.5.
- Planificador: Haiku 4.5 para respuestas rápidas, **Sonnet 5** para "plan profundo". Prompt caching del contexto fijo y resumen incremental del hilo.

### Cuotas y abuso
- Toda llamada de IA pasa por `consume_credit()`: chequea plan y límites y descuenta de forma atómica.
- Límites en la tabla `plan_limits`, ajustables sin publicar versión.
- Tope de gasto diario por usuario en dólares.
- App Attest (iOS) y Play Integrity (Android) en los endpoints de IA.
- Moderación de entrada y salida; reporte de contenido generado por IA desde la app (requisito de Play).
- Gateway con reintentos, backoff y modelo de respaldo.

### Calidad
Set de evaluación de 100 pares de conceptos por perfil, puntuados a mano en "sorprende" y "sirve" (1 a 5). Cada cambio de prompt o de modelo corre contra ese set. Objetivo: promedio de 3,5 o más.

## 6. Datos: qué se guarda

**Se guarda:** dominio, título, tesis, principio, embedding (con su modelo), tipo de fuente, URL y título de la fuente, fragmento subrayado (≤ 500 caracteres), texto crudo por 30 días y referencia a la foto en el teléfono del usuario.

**No se guarda:** audios, PDFs, videos ni páginas completas. Se procesan en un almacenamiento temporal y se borran apenas se extrae el concepto. Las imágenes quedan en el teléfono; sincronizarlas con miniaturas podría ser una función Pro futura.

Ventajas: almacenamiento casi nulo, privacidad ("no guardamos tus archivos") y menos riesgo de derechos de autor.

El esquema completo está en `backend/db/schema.sql`.

## 7. Arquitectura

| Capa | Elección |
|---|---|
| iOS | Swift 6, SwiftUI, Observation, SwiftData como caché, paquetes SPM (LumbreDesign, LumbreCore, uno por feature), Share Extension, Widget, App Intents. Mínimo: iOS actual y las dos anteriores |
| Android | Kotlin, Compose, Material 3, MVVM + flujo unidireccional, Coroutines/Flow, Hilt, Room + WorkManager, módulos Gradle por capa y feature, Baseline Profiles. minSdk 28 |
| Backend | Supabase: Postgres + pgvector + RLS, Auth (Apple, Google, email e invitado anónimo), Edge Functions, pg_cron + pgmq, Storage temporal. Tres entornos (dev, staging, prod) |
| IA | Claude Haiku 4.5, Sonnet 5 y Batches API; un modelo de embeddings multilingüe único |
| Pagos | RevenueCat sobre StoreKit 2 y Play Billing, entitlement "pro" |
| Observabilidad | Sentry, PostHog en la nube de la UE (analytics, feature flags, experimentos), tabla `llm_calls` con tablero de costos y alertas |
| Contrato | OpenAPI, del que se generan los clientes Swift y Kotlin |
| Tokens de diseño | `tokens.json` como fuente única, exportado a Swift y Kotlin en cada build |

Las apps son clientes finos: ninguna clave de IA vive en el binario. Kotlin Multiplatform queda como opción solo si la lógica de cliente crece.

## 8. Precios

| | Free | Pro |
|---|---|---|
| Precio | US$ 0 | US$ 6,99/mes o US$ 49,99/año (7 días de prueba en el anual) |
| Captura | Texto y voz ilimitados; adjuntos con tu frase | Todo, con destilación automática |
| Destilación automática | 3–5 pruebas por mes | Uso justo: 300/mes |
| Chispas | 1 por día + hasta 2 ganadas | Hasta 10 por día, con modos elegir y problema |
| Bóveda | Ilimitada | Ilimitada |
| Planificador | — | 300 mensajes/mes (60 de plan profundo) |
| Proyectos | 1 | Ilimitados |
| Export | Markdown | Markdown, Notion, Linear, GitHub |

- Precios regionales por país en App Store Connect y Google Play: en Argentina y LATAM, un nivel bastante más bajo que en EE. UU.
- Precios de API de referencia (septiembre de 2026): Haiku 4.5 US$ 1/5 y Sonnet 5 US$ 2/10 por millón de tokens de entrada/salida; Batches API 50% menos; lecturas de caché al 10%. Verificar antes de cerrar números.

### Costos por operación
| Operación | Costo aprox. |
|---|---|
| Chispa diaria (batch) | US$ 0,002 |
| Chispa extra (tiempo real) | US$ 0,004 |
| Destilar texto largo | US$ 0,002 |
| Destilar link | US$ 0,006 |
| Destilar imagen | < US$ 0,003 |
| Embedding | menos de una milésima de centavo |
| Buscar pares | US$ 0 (SQL) |
| Mensaje rápido del planificador | US$ 0,005 |
| Plan profundo | US$ 0,013 |

### Economía por usuario
- Free típico: ≈ US$ 0,06–0,08 por mes (casi todo es la chispa diaria).
- Pro típico: ≈ US$ 1,20 por mes. Pro al tope de uso justo: ≈ US$ 3,50.
- Ingreso neto por Pro, con la comisión del 15%: US$ 5,94 por mes (mensual) o US$ 3,54 (anual).
- Con 1.000 usuarios free (≈ US$ 70/mes de IA), unos 20 Pro cubren su costo.
- Costos fijos: Apple Developer US$ 99/año, Google Play US$ 25 una vez, Supabase Pro, dominio, email.
- Esto es orientativo: la forma de cobrar desde Argentina, la entidad que publica y los impuestos hay que confirmarlos con un contador.

## 9. Plan de trabajo

Supuesto: 1 dev, unas 20 horas por semana. Cada fase tiene un criterio de salida; si no se cumple, no se avanza.

| Fase | Semanas | Qué | Salida |
|---|---|---|---|
| 0. Validar | 1–2 | 12 entrevistas, búsqueda de marca de Lumbre, landing con waitlist y demo web, cuentas (Apple con D-U-N-S si es organización, Google, Supabase, Anthropic, RevenueCat, PostHog, Sentry), métrica norte | Lumbre confirmado, 150+ en waitlist, 3 dolores repetidos |
| 1. Diseño | 2–4 | Design system en Figma, logo final y exportes, prototipo navegable del loop en ambas plataformas, test con 5 personas, reveal de 900 ms, copy en español e inglés | 4 de 5 completan onboarding y guardan una idea |
| 2. Backend e IA | 3–6 | Esquema, RLS, auth, Edge Functions, `consume_credit()`, `plan_limits`, `llm_calls`, lista de dominios, prompts versionados, set de evaluación, batch nocturno, OpenAPI | Evaluación ≥ 3,5; chispa < US$ 0,005 |
| 3. iOS | 5–11 | Todas las pantallas, Share Extension, widget, App Intents, push, RevenueCat, analytics, accesibilidad, borrado de cuenta | Loop completo en TestFlight interno, sin crashes en 7 días |
| 4. Beta iOS | 10–12 | TestFlight con 50–100 de la waitlist, encuesta y llamadas, iterar prompts y onboarding | D7 ≥ 15%; si D7 < 10%, se frena Android |
| 5. Android | 11–17 | Paridad con Material 3, share intent, Glance, cola offline, pruebas en gama media, prueba cerrada de 12+ testers por 14 días | Paridad y arranque < 1,5 s en gama media |
| 6. Endurecer | 13–15 | Revisión de seguridad, prueba de carga del batch (10x), términos y privacidad, consentimiento para IA de terceros, fichas de tienda | Checklist de deploy completo |
| 7. Lanzamiento iOS | 15–16 | Revisión de App Store, lanzamiento por fases de 7 días, Product Hunt, email a la waitlist | Crash-free > 99,5% |
| 8. Lanzamiento Android | 18–19 | Rollout 10% → 50% → 100% | ANR y crashes bajo los umbrales de Play Vitals |
| 9. Operar | Continuo | Versión cada 2 semanas, 1.1 a los 45 días, experimentos, revisión mensual de costos | Conversión a Pro ≥ 3% a los 90 días |

## 10. Checklists de deploy

**App Store**
- Sign in with Apple si se ofrece Google.
- Suscripciones con descripción, precio, período y cómo cancelar en el paywall; restaurar compras visible.
- Consentimiento explícito antes de enviar datos personales a una IA de terceros, y la IA nombrada en la política de privacidad.
- Borrado de cuenta en la app; privacy manifest y etiquetas de privacidad.
- Cuenta de prueba con Pro para el revisor y notas de revisión.
- Small Business Program pedido antes de facturar; postular la app para featuring.

**Google Play**
- Prueba cerrada de 12+ testers por 14 días (cuentas personales nuevas).
- Target SDK exigido en la fecha de subida.
- Data safety coherente con la política de privacidad.
- Reporte de contenido generado por IA desde la app.
- Permisos justificados (micrófono, cámara, notificaciones).
- Borrado de cuenta en la app y por web.
- App Bundle con Play App Signing; rollout escalonado con Android Vitals.

## 11. Buenas prácticas
- Monorepo con `/ios`, `/android`, `/backend`, `/design`, `/web` y `/docs`.
- CI con GitHub Actions (lint, tests, build en cada PR) y fastlane para TestFlight y Play.
- Feature flags en PostHog para todo lo nuevo.
- RLS con tests automáticos de "usuario A no ve datos de B".
- Tokens de sesión en Keychain y almacenamiento cifrado de Android.
- Logs sin contenido de notas.
- String Catalogs (iOS) y strings.xml (Android) desde el día uno.
- VoiceOver, TalkBack, Dynamic Type hasta el máximo y Reducir movimiento respetado.
- Ley 25.326 en Argentina y GDPR si se vende en la UE: revisar con abogado.

## 12. Marketing
- **Posicionamiento:** "El método para tener ideas, en tu bolsillo." Primero devs indie y creadores hispanohablantes, después inglés. Competir en generar ideas, no en guardar notas.
- **Pre-lanzamiento:** build in public en X, LinkedIn, TikTok y Reels; serie diaria "chispa del día"; demo web como imán de emails; waitlist con referidos. Meta: 1.000 personas.
- **Lanzamiento iOS:** Product Hunt, Indie Hackers, r/SideProject, comunidades dev de LATAM, newsletters de creadores, códigos de oferta para 20 creadores. Meta: 2.000 descargas la primera semana.
- **Lanzamiento Android:** foco LATAM con creadores regionales y prensa tech.
- **Crecimiento:** tarjeta para compartir en cada chispa, referidos con una semana de Pro para ambos, pedido de reseña después de la tercera idea guardada, alianzas con cursos y bootcamps.
- **ASO:** ideas, creatividad, lluvia de ideas, brainstorming, segundo cerebro, notas con IA, inspiración. Capturas que muestren el choque.
- **Pago:** Apple Search Ads y Meta solo con conversión ≥ 3% y LTV conocido.

## 13. Métricas
| Métrica | Objetivo inicial |
|---|---|
| Norte: ideas guardadas por usuario activo semanal (activo: en la semana agregó algo a la bóveda o vio al menos una chispa; ver `docs/analytics.md`) | ≥ 2 |
| Activación: guarda su primera chispa en 24 h | ≥ 40% |
| Llega a la primera chispa en el onboarding | ≥ 75% |
| Acepta notificaciones | ≥ 55% |
| Retención D1 / D7 / D30 | 35% / 15% / 8% |
| Inicia la prueba de Pro | ≥ 8% de activos |
| Prueba a pago | ≥ 40% |
| Chispas con "No me sirve" | ≤ 25% |
| Costo de IA por usuario activo mensual | ≤ US$ 0,15 |

## 14. Riesgos
| Riesgo | Qué hacer |
|---|---|
| Marca de Lumbre sin verificar | Búsqueda con abogado en la fase 0; Espurna o Hirameki como alternativas |
| Chispas genéricas | Set de evaluación, principio subyacente, banda de distancia, ideas semilla, concepto invitado |
| Costos de IA | `plan_limits`, batch, caché, Haiku por defecto, tope diario en dólares |
| App de notas que muere | Push diaria, widget, resumen semanal, tarjeta para compartir |
| Contenido inaccesible (muros, logins) | Usar lo que llega en la captura, nivel de confianza, caída a "¿Qué idea te deja esto?" |
| Rechazo en tienda | Checklists de deploy, cuenta demo, notas de revisión |
| Tiempo personal | Lista de recorte, un foco por semana, Claude Code para el trabajo espejo entre apps |
| Dependencia de un proveedor | Gateway con modelo de respaldo y prompts desacoplados |

## 15. Pendientes
- [ ] Búsqueda de marca de Lumbre con abogado.
- [ ] Wordmark pasado a curvas con Fraunces instalada; exportes de ícono (iOS dark/tinted, Android adaptive/monochrome).
- [ ] Test del ícono solo (sin wordmark) con 5 personas: qué ven.
- [ ] Lista cerrada de dominios (20–25) con descripción de cada uno para los embeddings.
- [ ] Elegir el modelo de embeddings multilingüe.
- [ ] Prompt de destilación y set de evaluación de 100 pares.
- [ ] Biblioteca de conceptos invitados por perfil.
- [ ] Confirmar con contador cómo cobrar y quién publica en las tiendas.
