# Estados vacíos, error, offline y contenido inaccesible

Paso 11 de `plan-ejecucion.md` (MAT-227). Especificación y copy de cada estado; los mockups (iOS y Android, gris y grafito) están en `index.html`. Servilo con `python3 -m http.server 8765 -d design` y abrí http://127.0.0.1:8765/estados/.

Las claves de copy son las de `design/copy/copy.json` (paso 10). Lo que dice *nueva* ya está sumado ahí en la pantalla `estados` (ids `estados.*`, status `nuevo`), y los cambios a textos existentes quedaron como `propuesta` en la clave que cambia.

## Resumen

| Id | Estado | Forma | En la app |
|---|---|---|---|
| `empty.red` | Red vacía | Pantalla | cambia |
| `empty.search` | Búsqueda sin resultados | Inline | cambia |
| `empty.category` | Categoría sin neuronas | Inline | cambia |
| `empty.categories` | Sin categorías | Inline | en la app |
| `empty.circuitos` | Circuitos vacío | Pantalla | cambia |
| `empty.circuito` | Circuito sin ideas | Pantalla | cambia |
| `empty.hoy_material` | Hoy sin material | Pantalla | cambia |
| `empty.hoy_sin_par` | Hoy sin par bueno | Pantalla | cambia |
| `empty.hoy_usadas` | Chispas de hoy usadas | Inline | cambia |
| `empty.hoy_pocas_combinaciones` | Pocas combinaciones nuevas | Banner | en la app |
| `empty.hoy_descartada` | Chispa del día descartada | Inline | en la app |
| `empty.hoy_sin_permiso` | Hoy sin permiso de IA | Pantalla | nuevo |
| `empty.extra_sin_par` | Otra chispa sin par | Inline | cambia |
| `empty.neurona_sin_chispas` | Neurona sin chispas | Inline | en la app |
| `empty.combinar` | Combinar sin resultados | Inline | cambia |
| `error.load` | No se pudo cargar | Pantalla | en la app |
| `error.not_found` | Ya no existe | Pantalla | nuevo |
| `error.load_offline` | Sin conexión, sin caché | Pantalla | cambia |
| `error.save` | No se pudo guardar | Alerta | cambia |
| `error.unexpected` | Error inesperado | Alerta o toast | en la app |
| `error.share_card` | No se armó la tarjeta | Alerta | en la app |
| `error.quota_capture` | Capturas de hoy agotadas | Alerta | cambia |
| `error.quota_distill` | Conceptualizaciones del mes agotadas (free) | Pantalla en la sheet | cambia |
| `error.quota_distill_pro` | Uso justo de conceptualización (Pro) | Pantalla en la sheet | nuevo |
| `error.quota_spark_extra` | Chispas extra agotadas | Alerta | cambia |
| `error.quota_planner` | Planificador sin cupo | Inline | cambia |
| `error.quota_circuits` | Circuitos en free | Pie de lista + alerta | cambia |
| `error.too_many_categories` | Demasiadas categorías | Alerta | cambia |
| `error.account_required` | Función con cuenta (invitado) | Sheet | cambia |
| `error.store_prices` | Los planes no cargan | Inline | en la app |
| `error.store_failed` | La compra no se completó | Alerta | cambia |
| `error.store_unverified` | Compra sin verificar | Alerta | cambia |
| `error.store_pending` | Compra pendiente | Alerta | en la app |
| `error.store_nothing_to_restore` | Nada para restaurar | Alerta | cambia |
| `error.ai_spark` | La chispa no se encendió | Inline | cambia |
| `error.ai_distill` | No se pudo conceptualizar | Inline en la sheet / toast | cambia |
| `error.ai_planner` | La respuesta no llegó | Inline | cambia |
| `error.session_expired` | Sesión vencida | Sheet | nuevo |
| `error.invalid_link` | Link inválido | Inline en el campo | en la app |
| `error.thesis_too_long` | Idea demasiado larga | Inline en el campo | en la app |
| `error.dictation_permission` | Dictado sin permiso | Inline en la sheet | en la app |
| `offline.banner` | Banner sin conexión | Banner | nuevo |
| `offline.hoy_cache` | Hoy desde la caché | Pantalla con banner | nuevo |
| `offline.extra_spark` | Otra chispa sin conexión | Inline | nuevo |
| `offline.reveal` | Reveal sin conexión | Pantalla con banner | cambia |
| `offline.capture_queued` | Captura guardada en la cola | Toast | cambia |
| `offline.capture_failed_local` | No se pudo guardar en el teléfono | Alerta | cambia |
| `offline.queue_pending` | Capturas esperando conexión | Banner | en la app |
| `offline.queue_flushed` | Cola enviada | Toast | nuevo |
| `offline.queue_discarded` | Captura descartada de la cola | Alerta | cambia |
| `offline.search` | Búsqueda sin conexión | Inline | cambia |
| `offline.planner` | Planificador sin conexión | Inline | nuevo |
| `offline.write_failed` | Cambio sin conexión | Toast o alerta | cambia |
| `inaccessible.generic` | Sin idea: escribila vos | Inline en la sheet | en la app |
| `inaccessible.moderated` | Contenido rechazado por moderación | Inline en la sheet | cambia |
| `inaccessible.audio_no_speech` | Audio sin palabras | Inline en la sheet | nuevo |
| `inaccessible.paywall_link` | Link con muro de pago | Inline en la sheet | nuevo |
| `inaccessible.social_login` | Red social con login | Inline en la sheet | nuevo |
| `inaccessible.private_doc` | Documento privado | Inline en la sheet | nuevo |
| `inaccessible.unreachable` | La página no carga | Inline en la sheet | nuevo |
| `inaccessible.image_no_idea` | Imagen sin idea adentro | Inline en la sheet | nuevo |
| `inaccessible.ocr_no_text` | Foto sin texto reconocible | Inline en la sheet | cambia |
| `inaccessible.pdf_no_text` | PDF sin texto | Inline en la sheet | nuevo |
| `inaccessible.pdf_too_large` | PDF de más de 20 MB | Inline en el campo | cambia |
| `inaccessible.file_unreadable` | Archivo que no abre | Inline en el campo | cambia |
| `inaccessible.unsupported_format` | Formato no soportado | Inline en la Share Extension | nuevo |
| `inaccessible.draft_medium` | Borrador para confirmar (confianza media) | Pantalla en la sheet | en la app |

67 estados: vacíos 15, errores 26, offline 12, contenido inaccesible 14.

## Reglas generales

### Qué forma toma cada estado

- **Pantalla.** Cuando la pantalla entera no tiene qué mostrar: Red o Circuitos vacíos, Hoy sin chispa, un error de carga sin caché. Ocupa el área de contenido; el título grande, la barra y el + siguen ahí. Lleva ilustración solo si hay una `estado-*` que cuente ese momento de la red.
- **Inline.** Dentro de una pantalla que tiene otras cosas: resultados de búsqueda, una sección del detalle, un aviso en la sheet de Capturar, el error de un campo. Sin ilustración: ícono del sistema.
- **Banner.** Una condición que dura: sin conexión, capturas en la cola, pocas combinaciones. Arriba del contenido, no se cierra a mano y desaparece sola cuando se resuelve. Uno por pantalla; si compiten, gana sin conexión.
- **Toast / Snackbar.** Confirmación o falla leve de una acción de un toque, sin nada que se pierda. Unos 3 s (6 s con lector de pantalla). En Android puede llevar una acción (“Reintentar”). Nunca para algo que haya que leer dos veces.
- **Alerta / Diálogo.** Una acción falló y hay algo que decidir o el texto escrito está en juego. Un botón (“Entendido”) o dos (la salida + “Entendido”/“Ahora no”). Nunca para errores de carga.
- **Sheet.** Cuando la salida es otro flujo: crear la cuenta, volver a entrar. Se puede cerrar con un botón real, salvo la sesión vencida.

### Cómo se escriben

- El título dice qué pasa (“No se pudo cargar”, “Llegaste a las capturas de hoy”). El cuerpo dice qué hacer (“Probá de nuevo en un rato”).
- Sin disculpas: nada de “Ups”, “Lo sentimos”, “Perdón” ni signos de exclamación.
- Nunca culpar: “No pudimos sacar una idea de esto”, no “Tu link no sirve”. Los límites se dicen como límites, no como fallas.
- Nunca prometer lo que no pasó: si no leímos una página no decimos que la leímos; si un cambio no se encola, no decimos “lo mandamos cuando vuelva”.
- Si se devolvió un crédito, se dice (“No se descontó la prueba”). Si no estamos seguros de que se devolvió, no se dice.
- Lo escrito nunca se pierde: ante un error, la sheet queda abierta con el texto, y el cuerpo lo dice.
- Un solo botón principal. Los vacíos que crean algo (Capturar, Crear circuito) lo llevan como principal; los errores ponen “Reintentar” como secundario; la navegación (“Ir a Hoy”, “Volver”) va secundaria.
- Botones con verbo y nombre estable: “Reintentar”, “Capturar”, “Crear cuenta”, “Entendido” (no “Aceptar” ni “OK”).
- Vocabulario de la interfaz: neurona, Red, Circuitos, chispa, conceptualizar, encender. “Cola”, “servidor”, “IA” y los códigos de error no se muestran (la IA se nombra solo donde se pide permiso).
- Sentence case, voseo, sin emoji, números con cifras. En inglés, el mismo tono: directo, cálido, sin “Oops” ni “Sorry”.

### Color, íconos y tipografía

- En vacíos y errores no hay rosa. Lo único rosa que puede aparecer en estas pantallas es la sinapsis de una chispa que ya existe (Hoy desde la caché).
- En los vacíos de Hoy el contador se oculta, y cuando está va con la neurona dormida, sin núcleo rosa: no hay nada para encender.
- Falla: ícono en `danger` + título que lo dice. Límite o cupo: ícono neutro (`ink-muted`), nunca rojo. Sin conexión: ilustración o ícono neutro. Éxito: ícono en `success` + “Neurona guardada”.
- El color nunca va solo: todo estado lleva ícono y palabra. Los avisos van en `surface-alt` con texto `ink`; el color queda en el ícono.
- Fraunces solo en los títulos de pantalla. Los títulos de los estados van en la fuente del sistema (20 pt en pantalla, 17 pt inline).

### Ilustraciones

Solo en estados de pantalla (180–200 pt). Con la identidad neuronal apagada, el ícono del sistema.

| Archivo | Qué muestra | Dónde |
|---|---|---|
| `identidad/estado-red-vacia.svg` | Una neurona sola | `empty.red`, `empty.hoy_material` |
| `identidad/estado-sin-chispa.svg` | Dos que se buscan | `empty.hoy_sin_par`, `empty.hoy_sin_permiso`, `offline.reveal` |
| `identidad/estado-sin-circuitos.svg` | Una conexión abierta | `empty.circuitos`, `empty.circuito` |
| `identidad/estado-sin-conexion.svg` | Un axón cortado | `error.load_offline` |

### Accesibilidad

- Ilustraciones e íconos de estado son decorativos: ocultos a VoiceOver y TalkBack. La palabra lleva el significado.
- En pantalla, el título es encabezado y se lee junto con el cuerpo (iOS: ContentUnavailableView; Android: `semantics { heading() }` y merge).
- Lo que aparece sin que la persona lo pida (aviso inline, banner, toast) se anuncia una vez: AccessibilityNotification.Announcement en iOS, live region educada en Android.
- Errores de campo: el foco vuelve al campo y el error queda como su descripción.
- Toasts: 6 s con lector de pantalla. Si hay que hacer algo, alerta en lugar de toast.
- Dynamic Type y escala de fuente: nada con alto fijo; los botones crecen y los de dos en fila pasan a columna.
- Reducir movimiento: banners y toasts aparecen con un fundido, sin deslizar.

### iOS y Android

- iOS: ContentUnavailableView para vacíos y carga, `.alert`, sheets con detents, toast propio sobre la barra flotante, ProgressView para reintentos.
- Android: Column centrada para vacíos (no hay equivalente del sistema), AlertDialog y ModalBottomSheet de Material 3, Snackbar con acción, CircularProgressIndicator.
- Rutas y tienda: iOS dice Ajustes y cuenta de Apple; Android, Configuración y Google Play (reemplazos `android` de copy.json).
- El pulso (ImpulseLoader) es solo para conceptualizar y encender; cualquier otra espera, spinner del sistema.

### De cada código de error a su estado

| Código | Estado |
|---|---|
| `not_authenticated` 401 | `error.session_expired` |
| `invalid_thesis` 400 | `error.thesis_too_long` (se valida antes en el teléfono) |
| `invalid_category` 400 | Error del campo Categoría: “La categoría tiene que tener entre 1 y 40 caracteres.” |
| `invalid_source` 400 | `error.invalid_link` |
| `invalid_request` 400 | `inaccessible.moderated` (planificador) o `error.unexpected` |
| `pro_required` 402 | Abre el paywall: no es un estado |
| `account_required` 403 | `error.account_required` |
| `not_found` 404 | `error.not_found` |
| `not_enough_concepts` 409 | `empty.extra_sin_par`; en la diaria, `empty.hoy_sin_par` |
| `needs_thesis` 422 (+ `reason`) | `inaccessible.*` según el motivo; sin motivo, `inaccessible.generic` |
| `quota_exceeded` 429 | `error.quota_*` según la operación (capture, distill, spark_extra, planner) |
| `too_many_categories` 429 | `error.too_many_categories` |
| `too_many_projects` 429 | `error.quota_circuits` |
| `ai_unavailable` 503 | `error.ai_spark`, `error.ai_distill`, `error.ai_planner` |
| `internal` 500 | `error.load`, `error.save` o `error.unexpected` |
| Sin red (URLError) | `offline.*`; lectura sin caché: `error.load_offline` |
| StoreKit / Play Billing | `error.store_*` |

## Vacíos

Pantallas o secciones sin contenido todavía. Dicen qué falta y cómo conseguirlo; nunca piden perdón.

### `empty.red` · Red vacía

- **Forma:** Pantalla · **En la app:** cambia
- **Dónde:** Red, sin ninguna neurona (primer uso o después de borrar todas).
- **Lo dispara:** `concepts.isEmpty` y sin error de carga.
- **Ilustración:** estado-red-vacia · **Ícono iOS / Android:** square.stack.3d.up / stacks
- **Comportamiento:** “Capturar” abre la sheet de Capturar (`capture_opened`, entry `empty_vault`). La búsqueda queda visible pero sin chips de categoría.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | Todavía no hay neuronas | Todavía no hay neuronas | No neurons yet | igual | `comun.no_neurons_title` |
| Cuerpo | Guardá una frase, un link o una nota de voz para tener material que combinar. | Guardá una frase, un link o una nota de voz para tener material que conectar. | Save a quote, a link or a voice note so there's something to connect. | cambia | `comun.no_neurons_body (cambia)` |
| Principal | Capturar | Capturar | Capture | igual | `comun.capture` |

- **Por qué cambia:** “Conectar” es el verbo de la marca (dos neuronas se conectan) y es el texto de referencia de design/system/README.md; “combinar” queda para “Combinar con…”, que es otra función.
- **Accesibilidad:** La ilustración es decorativa (oculta a VoiceOver y TalkBack). Título como encabezado; título y cuerpo se leen juntos; el botón es el siguiente elemento.
- **iOS y Android:** iOS: ContentUnavailableView con EmptyStateLabel. Android: Column centrada en el área de contenido (no hay equivalente del sistema), mismo copy e ilustración.

### `empty.search` · Búsqueda sin resultados

- **Forma:** Inline · **En la app:** cambia
- **Dónde:** Red, con texto en la búsqueda.
- **Lo dispara:** `/search` devuelve una lista vacía.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** magnifyingglass / search
- **Comportamiento:** Reemplaza la lista debajo del campo. Con un chip de categoría elegido cambia el cuerpo y suma “Sacar el filtro”, que vuelve a Todos y repite la búsqueda.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | Nada por acá | No hay neuronas parecidas | No similar neurons | cambia | `comun.nothing_here (cambia)` |
| Cuerpo | Probá con otras palabras: la búsqueda entiende ideas, no solo coincidencias. | Probá con otras palabras: la búsqueda entiende ideas, no solo coincidencias. | Try other words: search understands ideas, not just matches. | igual | `red.no_results_semantic` |
| Cuerpo con filtro | Probá con otras palabras o sacá el filtro de categoría. | Probá con otras palabras o sacá el filtro de categoría. | Try other words or remove the category filter. | igual | `red.no_results_filtered` |
| Secundaria con filtro | — | Sacar el filtro | Remove filter | nuevo | nueva |

- **Por qué cambia:** El título tiene que decir qué pasó: “Nada por acá” es genérico y se repite en otras pantallas. “Parecidas” enseña que la búsqueda es por sentido.
- **Accesibilidad:** Al aparecer se anuncia el título (VoiceOver: anuncio; Android: live region educada). El ícono es decorativo.
- **iOS y Android:** iOS y Android: mismo componente dentro de la lista o del formulario.

### `empty.category` · Categoría sin neuronas

- **Forma:** Inline · **En la app:** cambia
- **Dónde:** Red, con un chip de categoría elegido.
- **Lo dispara:** La categoría existe pero se quedó sin neuronas (se movieron o se borraron).
- **Ilustración:** Ninguna · **Ícono iOS / Android:** tag / sell
- **Comportamiento:** “Ver todas” elige el chip Todos.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | Nada en esta categoría | Esta categoría no tiene neuronas | This category has no neurons | cambia | `red.empty_category (cambia)` |
| Cuerpo | Elegí otra o mirá todas las neuronas. | Elegí otra o mirá todas las neuronas. | Pick another one or see all neurons. | igual | `red.empty_category_body` |
| Secundaria | — | Ver todas | See all | nuevo | nueva |

- **Por qué cambia:** Título que dice qué pasa, y una acción para la salida que ya sugiere el cuerpo.
- **Accesibilidad:** Al aparecer se anuncia el título (VoiceOver: anuncio; Android: live region educada). El ícono es decorativo.
- **iOS y Android:** iOS y Android: mismo componente dentro de la lista o del formulario.

### `empty.categories` · Sin categorías

- **Forma:** Inline · **En la app:** en la app
- **Dónde:** Red › Categorías (sheet) y el selector de categoría de Capturar.
- **Lo dispara:** El usuario todavía no tiene categorías (arranca sin ninguna).
- **Ilustración:** Ninguna · **Ícono iOS / Android:** tag / sell
- **Comportamiento:** Sin acción: las categorías nacen al guardar. En el selector va como texto de ayuda debajo del campo.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | Todavía no tenés categorías | Todavía no tenés categorías | No categories yet | igual | `red.cat.none_title` |
| Cuerpo | Se crean a medida que guardás neuronas. | Se crean a medida que guardás neuronas. | They're created as you save neurons. | igual | `red.cat.none_body` |
| Ayuda del selector | Todavía no tenés categorías: se crean a medida que guardás neuronas. | Todavía no tenés categorías: se crean a medida que guardás neuronas. | No categories yet: they're created as you save neurons. | igual | `capturar.category.none_yet` |

- **Accesibilidad:** Al aparecer se anuncia el título (VoiceOver: anuncio; Android: live region educada). El ícono es decorativo.
- **iOS y Android:** iOS y Android: mismo componente dentro de la lista o del formulario. En Android la sheet es una ModalBottomSheet.

### `empty.circuitos` · Circuitos vacío

- **Forma:** Pantalla · **En la app:** cambia
- **Dónde:** Circuitos, sin ningún circuito.
- **Lo dispara:** `projects.isEmpty`.
- **Ilustración:** estado-sin-circuitos · **Ícono iOS / Android:** square.grid.2x2 / grid_view
- **Comportamiento:** “Crear circuito” abre el diálogo de nombre. Cambia el estilo: de secundario a principal.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | Todavía no hay circuitos | Todavía no hay circuitos | No circuits yet | igual | `circuitos.empty.title` |
| Cuerpo | Un circuito junta las ideas que querés llevar adelante. Creá uno o guardá una chispa desde Hoy y elegí dónde sumarla. | Un circuito junta las ideas que querés llevar adelante. Creá uno o guardá una chispa desde Hoy y elegí dónde sumarla. | A circuit gathers the ideas you want to move forward. Create one, or save a spark from Today and choose where to add it. | igual | `circuitos.empty.body` |
| Principal | Crear circuito | Crear circuito | Create circuit | igual | `circuitos.create` |

- **Por qué cambia:** El copy no cambia. El botón pasa a principal: es la única acción de la pantalla y crea algo (misma regla que la Red vacía).
- **Accesibilidad:** La ilustración es decorativa (oculta a VoiceOver y TalkBack). Título como encabezado; título y cuerpo se leen juntos; el botón es el siguiente elemento.
- **iOS y Android:** iOS: ContentUnavailableView con EmptyStateLabel. Android: Column centrada en el área de contenido (no hay equivalente del sistema), mismo copy e ilustración.

### `empty.circuito` · Circuito sin ideas

- **Forma:** Pantalla · **En la app:** cambia
- **Dónde:** Detalle de un circuito.
- **Lo dispara:** El circuito no tiene chispas guardadas.
- **Ilustración:** estado-sin-circuitos (hoy: ícono bookmark) · **Ícono iOS / Android:** bookmark / bookmark
- **Comportamiento:** “Ir a Hoy” cambia a la pestaña Hoy. Es navegación, así que queda secundario.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | Todavía no hay ideas acá | Todavía no hay ideas en este circuito | No ideas in this circuit yet | cambia | `circuitos.detail.empty_title (cambia)` |
| Cuerpo | Cuando guardes una chispa, elegí este circuito para sumarla. | Cuando guardes una chispa, elegí este circuito para sumarla. | When you save a spark, pick this circuit to add it. | igual | `circuitos.detail.empty_body` |
| Secundaria | Ir a Hoy | Ir a Hoy | Go to Today | igual | `circuitos.detail.go_today` |

- **Por qué cambia:** “Acá” no dice dónde, y VoiceOver lo lee sin el título de la pantalla. La ilustración de “una conexión abierta” cuenta justo esto.
- **Accesibilidad:** La ilustración es decorativa (oculta a VoiceOver y TalkBack). Título como encabezado; título y cuerpo se leen juntos; el botón es el siguiente elemento.
- **iOS y Android:** iOS: ContentUnavailableView con EmptyStateLabel. Android: Column centrada en el área de contenido (no hay equivalente del sistema), mismo copy e ilustración.

### `empty.hoy_material` · Hoy sin material

- **Forma:** Pantalla · **En la app:** cambia
- **Dónde:** Hoy, en el primer uso o con muy pocas neuronas.
- **Lo dispara:** `/today` sin chispa y `conceptCount < 4`. Con al menos una neurona, el respaldo de la biblioteca (plan.md §5) casi siempre arma un par, así que este estado es sobre todo del primer día.
- **Ilustración:** estado-red-vacia · **Ícono iOS / Android:** sparkles / auto_awesome
- **Comportamiento:** “Capturar neuronas” abre Capturar (entry `earn_extra`). Propuesta: el contador se oculta en los vacíos de Hoy, porque no hay nada que encender. El botón pasa a principal.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | Todavía no hay material para combinar | Todavía no hay material para conectar | Nothing to connect yet | cambia | `hoy.empty.no_material (cambia)` |
| Cuerpo | Guardá algunas neuronas de temas distintos: una frase, un link o una nota de voz. Con eso Lumbre enciende tu primera chispa. | Guardá algunas neuronas de temas distintos: una frase, un link o una nota de voz. Con eso Lumbre enciende tu primera chispa. | Save a few neurons on different topics: a quote, a link or a voice note. That's what Lumbre needs to light your first spark. | igual | `hoy.empty.no_material_body` |
| Principal | Capturar neuronas | Capturar neuronas | Capture neurons | igual | `comun.capture_neurons` |

- **Por qué cambia:** Mismo verbo que la Red vacía (“conectar”). Botón principal porque es la única acción y hace avanzar el loop.
- **Accesibilidad:** La ilustración es decorativa (oculta a VoiceOver y TalkBack). Título como encabezado; título y cuerpo se leen juntos; el botón es el siguiente elemento.
- **iOS y Android:** iOS: ContentUnavailableView con EmptyStateLabel. Android: Column centrada en el área de contenido (no hay equivalente del sistema), mismo copy e ilustración.
- **Analytics:** `spark_empty_state_shown` (reason `few_concepts`)

### `empty.hoy_sin_par` · Hoy sin par bueno

- **Forma:** Pantalla · **En la app:** cambia
- **Dónde:** Hoy.
- **Lo dispara:** `/today` sin chispa con 4 o más neuronas: no hay pares de dominios distintos en la banda (por ejemplo, todas del mismo tema).
- **Ilustración:** estado-sin-chispa · **Ícono iOS / Android:** sparkles / auto_awesome
- **Comportamiento:** Igual que `empty.hoy_material`: sin contador y con el botón como principal.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | Hoy no encontramos un buen par | Hoy no encontramos un buen par | We couldn't find a good pair today | igual | `hoy.empty.no_pair` |
| Cuerpo | Guardá neuronas de otros temas. Las conexiones entre mundos distintos dan las mejores chispas. | Guardá neuronas de otros temas. Las conexiones entre mundos distintos dan las mejores chispas. | Save neurons on other topics. Connections between different worlds make the best sparks. | igual | `hoy.empty.no_pair_body` |
| Principal | Capturar neuronas | Capturar neuronas | Capture neurons | igual | `comun.capture_neurons` |

- **Por qué cambia:** Solo cambia el estilo del botón (de secundario a principal).
- **Accesibilidad:** La ilustración es decorativa (oculta a VoiceOver y TalkBack). Título como encabezado; título y cuerpo se leen juntos; el botón es el siguiente elemento.
- **iOS y Android:** iOS: ContentUnavailableView con EmptyStateLabel. Android: Column centrada en el área de contenido (no hay equivalente del sistema), mismo copy e ilustración.
- **Analytics:** `spark_empty_state_shown` (reason `no_candidates`)

### `empty.hoy_usadas` · Chispas de hoy usadas

- **Forma:** Inline · **En la app:** cambia · **Provisorio**
- **Dónde:** Hoy, contador y sección “Otra chispa”.
- **Lo dispara:** La chispa del día ya se reveló y no quedan extras (`quota.available == 0`, `extraRemaining == 0`).
- **Ilustración:** Ninguna (la chispa sigue en pantalla) · **Ícono iOS / Android:** —
- **Comportamiento:** La chispa revelada queda visible. El texto de “Otra chispa” depende del plan: Pro, free o invitado. En los tres, el contador va con la neurona dormida (sin núcleo rosa).

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Contador | Usaste las chispas de hoy | Usaste las chispas de hoy | You've used today's sparks | igual | `hoy.meter.used` |
| Detalle | Se recarga mañana a las %@ | Se recarga mañana a las %@ | Refills tomorrow at %@ | igual | `hoy.refill.tomorrow` |
| Pro | Ya usaste las chispas extra de hoy. Mañana tenés más. | Ya usaste las chispas extra de hoy. Mañana tenés más. | You've used today's extra sparks. More tomorrow. | igual | `hoy.extra.used_pro` |
| Free | Cada 3 neuronas que guardás hoy ganás una chispa extra, hasta 2 por día. | Cada 3 neuronas que guardás hoy ganás una chispa extra, hasta 2 por día. | Every 3 neurons you save today earn you an extra spark, up to 2 a day. | igual | `hoy.extra.how_free` |
| Free, terciaria | Con Pro, hasta 10 por día | Con Pro, hasta 10 por día | With Pro, up to 10 a day | igual | `hoy.extra.pro_upsell` |
| Invitado | Creá tu cuenta para ganar chispas extra guardando neuronas. | Creá tu cuenta para ganar chispas extra guardando neuronas. | Create your account to earn extra sparks by saving neurons. | igual | `hoy.extra.guest` |
| Invitado, terciaria | — | Crear cuenta | Create account | nuevo | `comun.create_account` |

- **Por qué cambia:** Al invitado se le suma “Crear cuenta” como botón terciario: hoy el texto le pide crear la cuenta pero no le da cómo.
- **Accesibilidad:** El contador se lee como un solo elemento (estado + detalle). Al aparecer se anuncia el título (VoiceOver: anuncio; Android: live region educada). El ícono es decorativo.
- **iOS y Android:** iOS y Android: mismo componente dentro de la lista o del formulario.
- **Provisorio, a confirmar:** El botón “Crear cuenta” para el invitado depende de cuándo se le pide la cuenta (paso 14).

### `empty.hoy_pocas_combinaciones` · Pocas combinaciones nuevas

- **Forma:** Banner · **En la app:** en la app
- **Dónde:** Hoy, debajo de la chispa.
- **Lo dispara:** `needsMoreConcepts`: menos de 7 días de pares buenos (`spark_runway_days`).
- **Ilustración:** Ninguna · **Ícono iOS / Android:** tray.and.arrow.down / move_to_inbox
- **Comportamiento:** No se cierra a mano: desaparece cuando vuelve a haber pares. Si el contador ya ofrece Capturar (free ganando extras), el banner no repite el botón.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | Te quedan pocas combinaciones nuevas | Te quedan pocas combinaciones nuevas | You're running low on new combinations | igual | `hoy.runway.title` |
| Cuerpo | Guardá algunas neuronas más para que las chispas sigan sorprendiendo. | Guardá algunas neuronas más para que las chispas sigan sorprendiendo. | Save a few more neurons so your sparks keep surprising you. | igual | `hoy.runway.body` |
| Secundaria | Capturar neuronas | Capturar neuronas | Capture neurons | igual | `comun.capture_neurons` |

- **Accesibilidad:** Se anuncia una sola vez al aparecer, no en cada pantalla. Es un elemento combinado (título + cuerpo); el botón, si hay, es aparte.
- **iOS y Android:** iOS y Android: mismo componente dentro de la lista o del formulario.

### `empty.hoy_descartada` · Chispa del día descartada

- **Forma:** Inline · **En la app:** en la app
- **Dónde:** Hoy.
- **Lo dispara:** La chispa del día tiene `status = discarded` (“No me sirve”).
- **Ilustración:** Ninguna · **Ícono iOS / Android:** —
- **Comportamiento:** Debajo queda la fila de la chispa descartada, que abre el detalle.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | Ya usaste la chispa de hoy | Ya usaste la chispa de hoy | You've used today's spark | igual | `hoy.used.title` |
| Cuerpo | Marcaste que esta no te sirve. Con eso elegimos mejor la de mañana. | Marcaste que esta no te sirve. Con eso elegimos mejor la de mañana. | You marked this one as not useful. That helps us pick tomorrow's better. | igual | `hoy.used.discarded` |

- **Accesibilidad:** Al aparecer se anuncia el título (VoiceOver: anuncio; Android: live region educada). El ícono es decorativo.
- **iOS y Android:** iOS y Android: mismo componente dentro de la lista o del formulario.
- **Analytics:** `spark_empty_state_shown` (reason `used_today`)

### `empty.hoy_sin_permiso` · Hoy sin permiso de IA

- **Forma:** Pantalla · **En la app:** nuevo · **Provisorio**
- **Dónde:** Hoy.
- **Lo dispara:** La persona no aceptó (o apagó) mandar sus ideas a la IA en Perfil › Privacidad.
- **Ilustración:** estado-sin-chispa · **Ícono iOS / Android:** sparkles / auto_awesome
- **Comportamiento:** “Revisar el permiso” abre Perfil › Privacidad y datos. Las capturas siguen funcionando.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | — | Las chispas necesitan tu permiso | Sparks need your permission | nuevo | nueva |
| Cuerpo | — | Para encender chispas, Lumbre manda el texto de tus ideas a Claude, una IA de Anthropic. Lo activás en Perfil › Privacidad. | To light sparks, Lumbre sends the text of your ideas to Claude, an AI by Anthropic. You can turn it on in Profile › Privacy. | nuevo | nueva |
| Principal | — | Revisar el permiso | Review permission | nuevo | nueva |

- **Por qué cambia:** Hoy no hay estado para este caso: Hoy quedaría vacío sin explicar por qué.
- **Accesibilidad:** La ilustración es decorativa (oculta a VoiceOver y TalkBack). Título como encabezado; título y cuerpo se leen juntos; el botón es el siguiente elemento.
- **iOS y Android:** iOS: ContentUnavailableView con EmptyStateLabel. Android: Column centrada en el área de contenido (no hay equivalente del sistema), mismo copy e ilustración.
- **Analytics:** `spark_empty_state_shown` (reason nuevo: `no_consent`)
- **Provisorio, a confirmar:** plan.md no dice qué ve Hoy sin el consentimiento de IA. Opción conservadora: no se genera la chispa y se explica por qué, sin insistir.

### `empty.extra_sin_par` · Otra chispa sin par

- **Forma:** Inline · **En la app:** cambia
- **Dónde:** Hoy, sección “Otra chispa”, y “Combinar con…”.
- **Lo dispara:** `/spark` responde 409 `not_enough_concepts` (el crédito se devuelve).
- **Ilustración:** Ninguna · **Ícono iOS / Android:** tray.and.arrow.down / move_to_inbox
- **Comportamiento:** Aviso debajo del botón “Pedir otra chispa”, con Capturar neuronas. La chispa extra no se pierde.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Cuerpo | Guardá un par de neuronas más para tener material que conectar. | Guardá un par de neuronas más para tener material que conectar. | Save a couple more neurons so there's something to connect. | igual | `errores.api.need_more` |
| Secundaria | — | Capturar neuronas | Capture neurons | nuevo | `comun.capture_neurons` |

- **Por qué cambia:** Se suma la acción que pide el texto.
- **Accesibilidad:** Al aparecer se anuncia el título (VoiceOver: anuncio; Android: live region educada). El ícono es decorativo.
- **iOS y Android:** iOS y Android: mismo componente dentro de la lista o del formulario.

### `empty.neurona_sin_chispas` · Neurona sin chispas

- **Forma:** Inline · **En la app:** en la app
- **Dónde:** Detalle de neurona, sección “Chispas donde aparece”.
- **Lo dispara:** La neurona no apareció en ninguna chispa.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** —
- **Comportamiento:** Debajo: “Combinar con…” (Pro) o el texto “Con Lumbre Pro elegís qué neuronas se conectan.” (free).

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Cuerpo | Todavía no se conectó con otra neurona. Cuando aparezca en una chispa, la vas a ver acá. | Todavía no se conectó con otra neurona. Cuando aparezca en una chispa, la vas a ver acá. | It hasn't connected with another neuron yet. When it shows up in a spark, you'll see it here. | igual | `neurona.no_sparks` |

- **Accesibilidad:** Texto normal de la sección, sin anuncio.
- **iOS y Android:** iOS y Android: mismo componente dentro de la lista o del formulario.

### `empty.combinar` · Combinar sin resultados

- **Forma:** Inline · **En la app:** cambia
- **Dónde:** Sheet “Combinar con…” (Pro).
- **Lo dispara:** El filtro de la sheet no coincide con ninguna neurona.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** magnifyingglass / search
- **Comportamiento:** El filtro es literal y local (no es la búsqueda semántica).

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | Nada por acá | Ninguna neurona coincide | No neurons match | cambia | `comun.nothing_here (cambia)` |
| Cuerpo | Probá con otras palabras. | Probá con otras palabras. | Try other words. | igual | `neurona.try_other_words` |

- **Por qué cambia:** Mismo motivo que la búsqueda: el título dice qué pasó. Acá no decimos “parecidas” porque el filtro es por palabras.
- **Accesibilidad:** Al aparecer se anuncia el título (VoiceOver: anuncio; Android: live region educada). El ícono es decorativo.
- **iOS y Android:** iOS y Android: mismo componente dentro de la lista o del formulario.

## Errores

Algo falló o se llegó a un límite. El título dice qué pasó y el cuerpo, qué hacer. Los límites se dicen como límites, no como fallas.

### `error.load` · No se pudo cargar

- **Forma:** Pantalla · **En la app:** en la app
- **Dónde:** Hoy, Red, Circuitos, detalles y planificador, cuando la carga falla y no hay nada en caché.
- **Lo dispara:** 5xx (`internal`), respuesta que no se puede leer u otro error que no es de red.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** exclamationmark.triangle / error (en `danger`)
- **Comportamiento:** “Reintentar” vuelve a pedir; también tirar para actualizar. Si hay datos en caché, esta pantalla no aparece: se ven los datos. Registra `error_shown` con `screen` y `code`; el detalle técnico va a Sentry.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | No se pudo cargar | No se pudo cargar | Couldn't load | igual | `errores.load_failed` |
| Cuerpo | Algo salió mal. Probá de nuevo en un rato. | Algo salió mal. Probá de nuevo en un rato. | Something went wrong. Try again in a bit. | igual | `errores.later` |
| Secundaria | Reintentar | Reintentar | Try again | igual | `comun.retry` |

- **Accesibilidad:** El ícono es decorativo (oculta a VoiceOver y TalkBack). Título como encabezado; título y cuerpo se leen juntos; el botón es el siguiente elemento.
- **iOS y Android:** iOS: ContentUnavailableView con EmptyStateLabel. Android: Column centrada en el área de contenido (no hay equivalente del sistema), mismo copy e ilustración.
- **Analytics:** `error_shown` (`screen`, `code`)

### `error.not_found` · Ya no existe

- **Forma:** Pantalla · **En la app:** nuevo
- **Dónde:** Detalle de neurona, chispa o circuito abierto desde una push, el widget o un link.
- **Lo dispara:** 404 `not_found` (se borró en otro dispositivo o con la cuenta).
- **Ilustración:** Ninguna · **Ícono iOS / Android:** questionmark.folder / folder_off
- **Comportamiento:** “Volver” cierra el detalle. No se registra como error de Sentry.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | — | Esto ya no está en tu red | This is no longer in your network | nuevo | nueva |
| Cuerpo | — | Puede que se haya borrado desde otro dispositivo. | It may have been deleted on another device. | nuevo | nueva |
| Secundaria | — | Volver | Go back | nuevo | nueva |

- **Por qué cambia:** Hoy cae en “No se pudo cargar”, y reintentar no sirve de nada.
- **Accesibilidad:** El ícono es decorativo (oculta a VoiceOver y TalkBack). Título como encabezado; título y cuerpo se leen juntos; el botón es el siguiente elemento.
- **iOS y Android:** iOS: ContentUnavailableView con EmptyStateLabel. Android: Column centrada en el área de contenido (no hay equivalente del sistema), mismo copy e ilustración.
- **Analytics:** `error_shown` (code `not_found`)

### `error.load_offline` · Sin conexión, sin caché

- **Forma:** Pantalla · **En la app:** cambia
- **Dónde:** Cualquier pestaña o detalle, sin red y sin nada en caché (por ejemplo, el primer arranque).
- **Lo dispara:** `URLError` de red o `LumbreAPIError.offline` en una lectura.
- **Ilustración:** estado-sin-conexion · **Ícono iOS / Android:** wifi.exclamationmark / wifi_off
- **Comportamiento:** “Reintentar” vuelve a pedir; además se recarga sola cuando vuelve la red. La segunda oración del cuerpo va solo con el flag `offlineQueue` prendido.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | Sin conexión | Sin conexión | You're offline | igual | `errores.offline` |
| Cuerpo | Revisá tu conexión y probá de nuevo. (Si el error llega como `.offline`: “Sin conexión. Lo guardamos y lo mandamos cuando vuelva.”) | Revisá tu conexión y probá de nuevo. Lo que captures mientras tanto queda guardado en el teléfono. | Check your connection and try again. Anything you capture in the meantime stays saved on your phone. | cambia | nueva |
| Secundaria | Reintentar | Reintentar | Try again | igual | `comun.retry` |

- **Por qué cambia:** En una carga no hay nada que “guardar y mandar”: si el error llega como `.offline`, hoy la pantalla promete algo que no pasa. Y contar que Capturar sigue andando da dirección.
- **Accesibilidad:** La ilustración es decorativa (oculta a VoiceOver y TalkBack). Título como encabezado; título y cuerpo se leen juntos; el botón es el siguiente elemento.
- **iOS y Android:** iOS: ContentUnavailableView con EmptyStateLabel. Android: Column centrada en el área de contenido (no hay equivalente del sistema), mismo copy e ilustración.
- **Analytics:** `error_shown` (code `network_*` u `offline`)

### `error.save` · No se pudo guardar

- **Forma:** Alerta · **En la app:** cambia
- **Dónde:** Capturar, editar neurona, confirmar un borrador, mover de categoría, renombrar.
- **Lo dispara:** Error no previsto al escribir (5xx, `internal`).
- **Ilustración:** Ninguna · **Ícono iOS / Android:** —
- **Comportamiento:** La sheet no se cierra ni se vacía. “Entendido” cierra la alerta y deja todo como estaba. Mover y cambiar categoría usan el mismo cuerpo con su título (“No se pudo mover”, “No se pudo cambiar”).

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | No se pudo guardar | No se pudo guardar | Couldn't save | igual | `comun.save_failed` |
| Cuerpo | Algo salió mal. Probá de nuevo. | Lo que escribiste sigue acá. Probá de nuevo en un rato. | What you wrote is still here. Try again in a bit. | cambia | `comun.something_wrong_retry (cambia)` |
| Botón | Entendido | Entendido | Got it | igual | `comun.ok` |

- **Por qué cambia:** El miedo real ante un error al guardar es perder lo escrito: decirlo calma y da la dirección.
- **Accesibilidad:** Alerta del sistema: el lector la lee al abrirse y el foco queda en ella. El botón por defecto es el de la derecha (iOS) o el último (Android).
- **iOS y Android:** iOS: .alert con botones del sistema. Android: AlertDialog de Material 3, título en la fuente del sistema, botones de texto a la derecha.
- **Analytics:** `capture_failed` (reason `server_error`) en Capturar

### `error.unexpected` · Error inesperado

- **Forma:** Alerta o toast · **En la app:** en la app
- **Dónde:** Cualquier acción, cuando el error no tiene un estado propio.
- **Lo dispara:** `LumbreAPIError.unexpected` o un error desconocido.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** —
- **Comportamiento:** Si la acción tenía texto escrito, alerta (como `error.save`). Si fue un toque (guardar idea, No me sirve), toast. Siempre `error_shown` con code `unexpected` y el detalle a Sentry.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Texto | Algo salió mal. Probá de nuevo. | Algo salió mal. Probá de nuevo. | Something went wrong. Try again. | igual | `comun.something_wrong_retry` |

- **Accesibilidad:** Alerta del sistema: el lector la lee al abrirse y el foco queda en ella. El botón por defecto es el de la derecha (iOS) o el último (Android).
- **iOS y Android:** iOS: .alert con botones del sistema. Android: AlertDialog de Material 3, título en la fuente del sistema, botones de texto a la derecha. iOS: cápsula propia abajo, sobre la barra. Android: Snackbar del SnackbarHost, con acción opcional.
- **Analytics:** `error_shown` (code `unexpected`)

### `error.share_card` · No se armó la tarjeta

- **Forma:** Alerta · **En la app:** en la app
- **Dónde:** Compartir una chispa.
- **Lo dispara:** La imagen de la tarjeta no se pudo renderizar.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** —
- **Comportamiento:** “Entendido” vuelve a la chispa; el botón Compartir sigue disponible.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Texto | No pudimos armar la imagen. Probá de nuevo. | No pudimos armar la imagen. Probá de nuevo. | We couldn't make the image. Try again. | igual | `chispa.share.failed` |

- **Accesibilidad:** Alerta del sistema: el lector la lee al abrirse y el foco queda en ella. El botón por defecto es el de la derecha (iOS) o el último (Android).
- **iOS y Android:** iOS: .alert con botones del sistema. Android: AlertDialog de Material 3, título en la fuente del sistema, botones de texto a la derecha.

### `error.quota_capture` · Capturas de hoy agotadas

- **Forma:** Alerta · **En la app:** cambia · **Provisorio**
- **Dónde:** Capturar (también la Share Extension y el intent de compartir).
- **Lo dispara:** 429 `quota_exceeded` en `/capture`: 10 por día (invitado), 30 (free), 200 (Pro). El día se cuenta en la zona horaria del usuario.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** —
- **Comportamiento:** La sheet queda abierta con el texto. Es el tope anti-abuso: a free y Pro no se les ofrece nada. Al invitado sí: “Crear cuenta” abre la hoja de cuenta.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | No se pudo guardar | Llegaste a las capturas de hoy | You've reached today's captures | cambia | `comun.save_failed (cambia)` |
| Cuerpo | Llegaste al límite de hoy. Mañana podés seguir. | Mañana podés seguir guardando. Lo que escribiste sigue acá, por si querés copiarlo. | You can keep saving tomorrow. What you wrote is still here if you want to copy it. | cambia | `errores.api.quota (cambia)` |
| Botón | Entendido | Entendido | Got it | igual | `comun.ok` |
| Invitado, cuerpo | — | Llegaste a las 10 neuronas de hoy como invitado. Con una cuenta gratis guardás hasta 30 por día. | You've saved today's 10 neurons as a guest. A free account lets you save up to 30 a day. | nuevo | `cuenta.gate.limit` |
| Invitado, botones | — | Crear cuenta · Ahora no | Create account · Not now | nuevo | nueva |

- **Por qué cambia:** Es un límite, no una falla: el título dice cuál. `quota_exceeded` es el mismo código para todos los cupos; hoy la app siempre dice “de hoy”, que es falso para los del mes.
- **Accesibilidad:** Alerta del sistema: el lector la lee al abrirse y el foco queda en ella. El botón por defecto es el de la derecha (iOS) o el último (Android).
- **iOS y Android:** iOS: .alert con botones del sistema. Android: AlertDialog de Material 3, título en la fuente del sistema, botones de texto a la derecha.
- **Analytics:** `capture_failed` (reason `rate_limited`); servidor: `quota_reached` (kind `capture`)
- **Provisorio, a confirmar:** El texto del invitado sale de copy.json (`cuenta.gate.limit`, nuevo); qué ve el invitado se define en `design/prototipo/invitado.md` (propuesta del paso 14, a confirmar).

### `error.quota_distill` · Conceptualizaciones del mes agotadas (free)

- **Forma:** Pantalla en la sheet · **En la app:** cambia
- **Dónde:** Capturar, al guardar un link, foto o PDF con “Conceptualizar” prendido.
- **Lo dispara:** Free con las 5 pruebas del mes usadas: `distillation = quota_exceeded` en la respuesta de `/capture` (la neurona se guarda igual).
- **Ilustración:** Ninguna · **Ícono iOS / Android:** checkmark.circle / check_circle (en `success`, con “Neurona guardada”)
- **Comportamiento:** Antes de guardar, el interruptor ya avisa (texto del aviso). Si igual se llega al tope, se guarda sin conceptualizar y se muestra esta pantalla. “Conocé Lumbre Pro” abre el paywall (trigger `distill`).

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Aviso previo | Usaste las pruebas de este mes. Escribí qué idea te deja esto y lo guardamos igual. | Usaste las pruebas de este mes. Escribí qué idea te deja esto y lo guardamos igual. | You've used this month's trials. Write what idea it leaves you with and we'll save it anyway. | igual | `capturar.trials.used` |
| Título | Lo guardamos sin conceptualizar | Lo guardamos sin conceptualizar | We saved it without conceptualizing | igual | `capturar.draft.saved_raw` |
| Cuerpo | Usaste las pruebas de conceptualización de este mes. Con Lumbre Pro conceptualizás links, fotos y PDFs sin límite. | Usaste las pruebas de conceptualización de este mes. Con Lumbre Pro, los links, fotos y PDFs se conceptualizan solos. | You've used this month's conceptualization trials. With Lumbre Pro, links, photos and PDFs conceptualize on their own. | cambia | `capturar.draft.saved_raw_body (cambia)` |
| Principal | Conocé Lumbre Pro | Conocé Lumbre Pro | Meet Lumbre Pro | igual | `comun.meet_pro` |
| Terciaria | Listo | Listo | Done | igual | `comun.done` |
| Invitado (aviso) | La conceptualización es con cuenta. Creala desde Perfil y probala gratis. | La conceptualización es con cuenta. Creala desde Perfil y probala gratis. | Conceptualizing needs an account. Create one from Profile and try it for free. | igual | `capturar.trials.guest` |

- **Por qué cambia:** Pro tiene un uso justo de 300 conceptualizaciones por mes (`plan_limits`): “sin límite” no es cierto.
- **Accesibilidad:** La pantalla se anuncia por su título. Al aparecer se anuncia el título (VoiceOver: anuncio; Android: live region educada). El ícono es decorativo.
- **iOS y Android:** Dentro de la sheet de Capturar. iOS: aviso arriba del campo. Android: igual, dentro de la ModalBottomSheet; el teclado no tapa el aviso.
- **Analytics:** `distill_fallback_shown` (reason `free_quota`); `paywall_shown` (trigger `distill`)

### `error.quota_distill_pro` · Uso justo de conceptualización (Pro)

- **Forma:** Pantalla en la sheet · **En la app:** nuevo
- **Dónde:** Capturar.
- **Lo dispara:** Pro con las 300 conceptualizaciones del mes usadas.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** checkmark.circle / check_circle
- **Comportamiento:** Misma pantalla sin el botón de Pro: solo “Listo”.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | — | Lo guardamos sin conceptualizar | We saved it without conceptualizing | nuevo | `capturar.draft.saved_raw` |
| Cuerpo | — | Llegaste al uso justo de conceptualización de este mes. Se renueva el mes que viene. | You've reached this month's fair use for conceptualization. It renews next month. | nuevo | nueva |
| Principal | — | Listo | Done | nuevo | `comun.done` |

- **Por qué cambia:** Hoy un Pro vería el ofrecimiento de Pro. Usa la misma fórmula de “uso justo” que el planificador.
- **Accesibilidad:** Al aparecer se anuncia el título (VoiceOver: anuncio; Android: live region educada). El ícono es decorativo.
- **iOS y Android:** Dentro de la sheet de Capturar. iOS: aviso arriba del campo. Android: igual, dentro de la ModalBottomSheet; el teclado no tapa el aviso.
- **Analytics:** servidor: `quota_reached` (kind `distill`)

### `error.quota_spark_extra` · Chispas extra agotadas

- **Forma:** Alerta · **En la app:** cambia
- **Dónde:** “Combinar con…” (Pro) y “Pedir otra chispa”, si el cupo se agotó entre que se cargó Hoy y el toque.
- **Lo dispara:** 429 `quota_exceeded` en `/spark`.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** —
- **Comportamiento:** En Hoy normalmente no llega a pasar: el botón desaparece y queda el texto de `empty.hoy_usadas`. La alerta cubre la carrera y Combinar.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | No se pudo encender | Ya pediste las chispas de hoy | You've asked for all of today's sparks | cambia | `neurona.ignite_failed (cambia)` |
| Cuerpo | Ya pediste todas las chispas de hoy. Mañana podés seguir. | Mañana podés pedir más. | You can ask for more tomorrow. | cambia | `neurona.all_sparks_used (cambia)` |
| Botón | Entendido | Entendido | Got it | igual | `comun.ok` |

- **Por qué cambia:** El título dice qué pasó (un límite, no una falla) y el cuerpo deja de repetirlo.
- **Accesibilidad:** Alerta del sistema: el lector la lee al abrirse y el foco queda en ella. El botón por defecto es el de la derecha (iOS) o el último (Android).
- **iOS y Android:** iOS: .alert con botones del sistema. Android: AlertDialog de Material 3, título en la fuente del sistema, botones de texto a la derecha.
- **Analytics:** servidor: `quota_reached` (kind `spark_extra`)

### `error.quota_planner` · Planificador sin cupo

- **Forma:** Inline · **En la app:** cambia
- **Dónde:** Planificador (Pro), arriba del campo.
- **Lo dispara:** 429 `quota_exceeded` en `/planner` (300 rápidos o 60 profundos por mes).
- **Ilustración:** Ninguna · **Ícono iOS / Android:** clock / schedule (neutro, no `danger`)
- **Comportamiento:** Rápido agotado: campo deshabilitado. Profundo agotado: el selector vuelve a Rápido y se puede seguir.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Rápido | Llegaste al uso justo del planificador de este mes. Se renueva el mes que viene. | Llegaste al uso justo del planificador de este mes. Se renueva el mes que viene. | You've reached this month's fair use for the planner. It renews next month. | igual | `planificador.limit.all` |
| Profundo | Llegaste al uso justo de plan profundo de este mes. Podés seguir en modo rápido. | Llegaste al uso justo de plan profundo de este mes. Podés seguir en modo rápido. | You've reached this month's fair use for deep plans. You can keep going in quick mode. | igual | `planificador.limit.deep` |

- **Por qué cambia:** El copy queda. Cambia el ícono: hoy es un triángulo rojo (`danger`), pero un cupo no es una falla.
- **Accesibilidad:** Al aparecer se anuncia el título (VoiceOver: anuncio; Android: live region educada). El ícono es decorativo.
- **iOS y Android:** iOS y Android: mismo componente dentro de la lista o del formulario.
- **Analytics:** servidor: `quota_reached` (kind `planner` o `planner_deep`)

### `error.quota_circuits` · Circuitos en free

- **Forma:** Pie de lista + alerta · **En la app:** cambia · **Provisorio**
- **Dónde:** Circuitos (“Nuevo circuito”) y “Crear otro circuito” al guardar una chispa.
- **Lo dispara:** Free o invitado con 1 circuito. La app abre el paywall antes de llamar; si el servidor igual responde 429 `too_many_projects`, alerta.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** —
- **Comportamiento:** El pie de lista avisa siempre. Tocar “Nuevo circuito” abre el paywall (trigger `projects`). La alerta solo cubre la carrera.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Pie de lista | Con el plan gratis tenés un circuito. Con Pro, todos los que quieras. | Con el plan gratis tenés un circuito. Con Pro, todos los que quieras. | The free plan has one circuit. With Pro, as many as you want. | igual | `comun.free_one_circuit` |
| Título de la alerta | No pudimos guardar el circuito | No se pudo crear el circuito | Couldn't create the circuit | cambia | `circuitos.save_failed (cambia)` |
| Botones | Aceptar | Entendido · Conocé Lumbre Pro | Got it · Meet Lumbre Pro | cambia | `comun.accept (cambia)` |

- **Por qué cambia:** “Aceptar” es el único lugar de la app que no usa “Entendido”. Y el título dice qué acción falló.
- **Accesibilidad:** Alerta del sistema: el lector la lee al abrirse y el foco queda en ella. El botón por defecto es el de la derecha (iOS) o el último (Android).
- **iOS y Android:** iOS: .alert con botones del sistema. Android: AlertDialog de Material 3, título en la fuente del sistema, botones de texto a la derecha.
- **Analytics:** `paywall_shown` (trigger `projects`: falta en docs/analytics.md)
- **Provisorio, a confirmar:** Para el invitado, el segundo circuito pide primero la cuenta (`cuenta.gate.pro`), no el paywall; se define en `design/prototipo/invitado.md` (propuesta del paso 14, a confirmar).

### `error.too_many_categories` · Demasiadas categorías

- **Forma:** Alerta · **En la app:** cambia
- **Dónde:** Capturar o mover una neurona a una categoría nueva.
- **Lo dispara:** 429 `too_many_categories` (tope de 50).
- **Ilustración:** Ninguna · **Ícono iOS / Android:** —
- **Comportamiento:** La sheet queda abierta; el campo Categoría queda enfocado para elegir una existente.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | No se pudo guardar | No se pudo guardar | Couldn't save | igual | `comun.save_failed` |
| Cuerpo | Ya tenés 50 categorías. Usá una de las que tenés. | Ya tenés 50 categorías, el máximo. Elegí una de las que tenés o borrá alguna desde Red › Categorías. | You already have 50 categories, the maximum. Pick one you have or delete one from Network › Categories. | cambia | `errores.api.too_many_categories (cambia)` |
| Botón | Entendido | Entendido | Got it | igual | `comun.ok` |

- **Por qué cambia:** Dice que es un tope y dónde se resuelve.
- **Accesibilidad:** Alerta del sistema: el lector la lee al abrirse y el foco queda en ella. El botón por defecto es el de la derecha (iOS) o el último (Android).
- **iOS y Android:** iOS: .alert con botones del sistema. Android: AlertDialog de Material 3, título en la fuente del sistema, botones de texto a la derecha.

### `error.account_required` · Función con cuenta (invitado)

- **Forma:** Sheet · **En la app:** cambia · **Provisorio**
- **Dónde:** Invitado que toca Pedir otra chispa, Combinar con…, Planificar, Conceptualizar o Lumbre Pro.
- **Lo dispara:** 403 `account_required` (o la app lo sabe antes por el plan `guest`).
- **Ilustración:** Ninguna (neurona chica de marca) · **Ícono iOS / Android:** —
- **Comportamiento:** “Crear cuenta” abre el flujo de cuenta; al terminar, vuelve a la acción. “Ahora no” cierra. Mientras las cuentas no estén (H1), se muestra “Las cuentas llegan pronto”.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | (alerta genérica) | Esto es con cuenta | This needs an account | cambia | `cuenta.gate.title` |
| Cuerpo | Creá tu cuenta para usar esto. | Uno por función (copy.json `cuenta.gate.*`). Chispas extra: Las chispas extra se ganan guardando neuronas, y se guardan en tu cuenta. Creala gratis: lo que ya guardaste pasa con vos. | Extra sparks are earned by saving neurons, and they're kept in your account. Create one for free: what you've saved comes with you. | cambia | `errores.api.account_required (cambia)` |
| Principal | — | Crear cuenta | Create account | nuevo | `comun.create_account` |
| Terciaria | — | Ahora no | Not now | nuevo | `onboarding.push.not_now` |

- **Por qué cambia:** Una alerta genérica no explica por qué la función necesita cuenta ni que no se pierde nada. El copy por función ya está en el paso 10.
- **Accesibilidad:** Sheet modal: el foco va al título. “Ahora no” es un botón real (no solo deslizar).
- **iOS y Android:** iOS: sheet con detent .medium. Android: ModalBottomSheet.
- **Analytics:** `error_shown` (code `account_required`)
- **Provisorio, a confirmar:** Cuándo se le pide la cuenta al invitado se define en `design/prototipo/invitado.md` (propuesta del paso 14, a confirmar).

### `error.store_prices` · Los planes no cargan

- **Forma:** Inline · **En la app:** en la app
- **Dónde:** Paywall.
- **Lo dispara:** StoreKit o Play Billing no devuelven los productos.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** wifi.exclamationmark / wifi_off
- **Comportamiento:** En el lugar de los planes. “Reintentar” vuelve a pedirlos. El botón de compra no aparece.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Cuerpo | No pudimos cargar los planes. Revisá tu conexión y probá de nuevo. | No pudimos cargar los planes. Revisá tu conexión y probá de nuevo. | We couldn't load the plans. Check your connection and try again. | igual | `paywall.load_failed` |
| Secundaria | Reintentar | Reintentar | Try again | igual | `comun.retry` |

- **Accesibilidad:** Al aparecer se anuncia el título (VoiceOver: anuncio; Android: live region educada). El ícono es decorativo.
- **iOS y Android:** iOS y Android: mismo componente dentro de la lista o del formulario.

### `error.store_failed` · La compra no se completó

- **Forma:** Alerta · **En la app:** cambia
- **Dónde:** Paywall.
- **Lo dispara:** La compra falla por la tienda (no por cancelación).
- **Ilustración:** Ninguna · **Ícono iOS / Android:** —
- **Comportamiento:** Si la persona cancela, no se muestra nada. Nunca se muestra el texto crudo de la tienda.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | No se pudo completar | No se pudo completar la compra | Couldn't complete the purchase | cambia | `paywall.failed (cambia)` |
| Cuerpo | (texto de StoreKit: `error.localizedDescription`) | La tienda no respondió. Probá de nuevo en un rato. | The store didn't respond. Try again in a bit. | cambia | nueva |
| Botón | Entendido | Entendido | Got it | igual | `comun.ok` |

- **Por qué cambia:** El texto de StoreKit llega técnico, a veces en otro idioma, y no da dirección.
- **Accesibilidad:** Alerta del sistema: el lector la lee al abrirse y el foco queda en ella. El botón por defecto es el de la derecha (iOS) o el último (Android).
- **iOS y Android:** iOS: .alert con botones del sistema. Android: AlertDialog de Material 3, título en la fuente del sistema, botones de texto a la derecha.
- **Analytics:** `purchase_failed` si existe; si no, `error_shown` (code `store_failed`)

### `error.store_unverified` · Compra sin verificar

- **Forma:** Alerta · **En la app:** cambia
- **Dónde:** Paywall.
- **Lo dispara:** Transacción sin verificar.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** —

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | No se pudo completar | No se pudo verificar la compra | Couldn't verify the purchase | cambia | `paywall.failed (cambia)` |
| Cuerpo | La tienda no pudo verificar la compra. Probá de nuevo o tocá Restaurar compras. | La tienda no pudo verificar la compra. Probá de nuevo o tocá Restaurar compras. | The store couldn't verify the purchase. Try again or tap Restore purchases. | igual | `paywall.verify_failed` |

- **Por qué cambia:** El título dice qué pasó.
- **Accesibilidad:** Alerta del sistema: el lector la lee al abrirse y el foco queda en ella. El botón por defecto es el de la derecha (iOS) o el último (Android).
- **iOS y Android:** iOS: .alert con botones del sistema. Android: AlertDialog de Material 3, título en la fuente del sistema, botones de texto a la derecha.

### `error.store_pending` · Compra pendiente

- **Forma:** Alerta · **En la app:** en la app
- **Dónde:** Paywall.
- **Lo dispara:** La compra espera una aprobación (Ask to Buy, pago pendiente en Google Play).
- **Ilustración:** Ninguna · **Ícono iOS / Android:** —
- **Comportamiento:** Cuando se aprueba, el webhook pasa el plan a Pro solo.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | Compra pendiente | Compra pendiente | Purchase pending | igual | `paywall.pending` |
| Cuerpo | La compra espera una aprobación. Cuando se apruebe, Pro se activa solo. | La compra espera una aprobación. Cuando se apruebe, Pro se activa solo. | The purchase is waiting for approval. Once it's approved, Pro turns on by itself. | igual | `paywall.pending_body` |

- **Accesibilidad:** Alerta del sistema: el lector la lee al abrirse y el foco queda en ella. El botón por defecto es el de la derecha (iOS) o el último (Android).
- **iOS y Android:** iOS: .alert con botones del sistema. Android: AlertDialog de Material 3, título en la fuente del sistema, botones de texto a la derecha.

### `error.store_nothing_to_restore` · Nada para restaurar

- **Forma:** Alerta · **En la app:** cambia
- **Dónde:** Paywall, “Restaurar compras”.
- **Lo dispara:** La tienda no tiene una suscripción de Lumbre Pro para esa cuenta.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** —

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | No hay compras para restaurar | No hay compras para restaurar | Nothing to restore | igual | `paywall.nothing_to_restore` |
| Cuerpo | No encontramos una suscripción a Lumbre Pro en esta cuenta de Apple. | No encontramos una suscripción a Lumbre Pro en esta cuenta de Apple. (Android: “en esta cuenta de Google”.) | — | cambia | `paywall.not_found (cambia)` |

- **Accesibilidad:** Alerta del sistema: el lector la lee al abrirse y el foco queda en ella. El botón por defecto es el de la derecha (iOS) o el último (Android).
- **iOS y Android:** iOS: .alert con botones del sistema. Android: AlertDialog de Material 3, título en la fuente del sistema, botones de texto a la derecha. El texto de Android nombra la cuenta de Google (copy.json `android`).

### `error.ai_spark` · La chispa no se encendió

- **Forma:** Inline · **En la app:** cambia
- **Dónde:** Hoy (“Pedir otra chispa”); alerta con el mismo texto en “Combinar con…”.
- **Lo dispara:** 503 `ai_unavailable` en `/spark`: la IA falló o su salida no pasó la moderación. El servidor devuelve el crédito.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** exclamationmark.triangle / error (en `danger`)
- **Comportamiento:** Aviso debajo del botón con “Reintentar”. El contador no baja.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | — | No se pudo encender la chispa | Couldn't light the spark | nuevo | nueva |
| Cuerpo | Algo salió mal. Probá de nuevo. | No se descontó de tus chispas. Probá de nuevo en un rato. | It wasn't taken from your sparks. Try again in a bit. | cambia | `comun.something_wrong_retry (cambia)` |
| Secundaria | — | Reintentar | Try again | nuevo | `comun.retry` |

- **Por qué cambia:** `ai_unavailable` no está en `LumbreAPIError` y cae en el genérico. Decir que el crédito volvió evita que la persona crea que lo perdió.
- **Accesibilidad:** Al aparecer se anuncia el título (VoiceOver: anuncio; Android: live region educada). El ícono es decorativo.
- **iOS y Android:** iOS y Android: mismo componente dentro de la lista o del formulario.
- **Analytics:** `error_shown` (screen `today`, code `ai_unavailable`)

### `error.ai_distill` · No se pudo conceptualizar

- **Forma:** Inline en la sheet / toast · **En la app:** cambia
- **Dónde:** Capturar con “Conceptualizar” prendido.
- **Lo dispara:** Sin idea escrita: 503 `ai_unavailable`. Con idea escrita: se guarda con sus palabras y `distillation = unavailable`. En los dos casos se devuelve la prueba.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** exclamationmark.triangle / error (en `danger`)
- **Comportamiento:** Sin idea: aviso arriba, el interruptor se apaga y el foco va al campo. Con idea: la sheet se cierra con el toast.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Aviso (sin idea) | Algo salió mal. Probá de nuevo. | No pudimos conceptualizar esto ahora. Escribí qué idea te deja y lo guardamos, o probá de nuevo en un rato. No se descontó la prueba. | We couldn't conceptualize this right now. Write what idea it leaves you with and we'll save it, or try again in a bit. It didn't use a trial. | cambia | `comun.something_wrong_retry (cambia)` |
| Toast (con idea) | Neurona guardada | Neurona guardada, sin conceptualizar | Neuron saved, not conceptualized | cambia | `capturar.saved (cambia)` |

- **Por qué cambia:** Hoy la falla es genérica o silenciosa: la persona cree que se conceptualizó. “No se descontó la prueba” va solo en free.
- **Accesibilidad:** Al aparecer se anuncia el título (VoiceOver: anuncio; Android: live region educada). El ícono es decorativo. El error queda asociado al campo (accessibilityHint / supportingText con error) y el foco vuelve al campo.
- **iOS y Android:** Dentro de la sheet de Capturar. iOS: aviso arriba del campo. Android: igual, dentro de la ModalBottomSheet; el teclado no tapa el aviso.
- **Analytics:** `distill_fallback_shown` (reason nuevo: `unavailable`)

### `error.ai_planner` · La respuesta no llegó

- **Forma:** Inline · **En la app:** cambia · **Provisorio**
- **Dónde:** Planificador.
- **Lo dispara:** El stream manda `error: ai_unavailable` o `internal`.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** exclamationmark.triangle / error (en `danger`)
- **Comportamiento:** Debajo del último mensaje. “Reintentar” reenvía el mismo mensaje. Si llegó una parte, queda visible y se marca como cortada.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | (texto genérico del error) | La respuesta no llegó | The reply didn't come through | cambia | nueva |
| Cuerpo | — | Probá de nuevo. | Try again. | nuevo | nueva |
| Secundaria | — | Reintentar | Try again | nuevo | `comun.retry` |

- **Por qué cambia:** Hoy muestra `localizedDescription`. No decimos “no se descontó” porque el servidor no siempre devuelve el cupo (ver hallazgos).
- **Accesibilidad:** Al aparecer se anuncia el título (VoiceOver: anuncio; Android: live region educada). El ícono es decorativo.
- **iOS y Android:** iOS y Android: mismo componente dentro de la lista o del formulario.
- **Analytics:** `error_shown` (screen `planner`, code `ai_unavailable`)
- **Provisorio, a confirmar:** Si el servidor manda `refunded: true` en el evento de error, sumar “No se descontó de tu planificador.”

### `error.session_expired` · Sesión vencida

- **Forma:** Sheet · **En la app:** nuevo · **Provisorio**
- **Dónde:** Toda la app, con cuenta (no invitado).
- **Lo dispara:** 401 `not_authenticated` o refresh token inválido.
- **Ilustración:** Ninguna (neurona chica de marca) · **Ícono iOS / Android:** —
- **Comportamiento:** Sheet que no se descarta deslizando. “Entrar” abre el flujo de código por email. Las capturas en la cola se conservan y se mandan después de entrar.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | — | Tu sesión se cerró | You've been signed out | nuevo | nueva |
| Cuerpo | — | Entrá de nuevo con tu email para seguir. Tus neuronas, chispas y circuitos están guardados en tu cuenta. | Sign in again with your email to keep going. Your neurons, sparks and circuits are saved in your account. | nuevo | nueva |
| Principal | — | Entrar | Sign in | nuevo | `cuenta.sign_in` |

- **Por qué cambia:** Hoy no hay estado: las pantallas mostrarían “No se pudo cargar” sin salida.
- **Accesibilidad:** Sheet modal: el foco va al título.
- **iOS y Android:** iOS: sheet con detent .medium. Android: ModalBottomSheet.
- **Analytics:** `error_shown` (code `not_authenticated`)
- **Provisorio, a confirmar:** Para un invitado que pierde la sesión no hay forma de recuperar los datos; qué se le muestra se define en `design/prototipo/invitado.md` (propuesta del paso 14, a confirmar).

### `error.invalid_link` · Link inválido

- **Forma:** Inline en el campo · **En la app:** en la app
- **Dónde:** Capturar › Link.
- **Lo dispara:** Validación local o 400 `invalid_source`.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** exclamationmark.circle / error
- **Comportamiento:** Guardar queda deshabilitado hasta corregir.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Texto | Revisá el link: no parece válido. | Revisá el link: no parece válido. | Check the link: it doesn't look valid. | igual | `capturar.link_invalid` |

- **Accesibilidad:** El error queda asociado al campo (accessibilityHint / supportingText con error) y el foco vuelve al campo.
- **iOS y Android:** iOS y Android: mismo componente dentro de la lista o del formulario.

### `error.thesis_too_long` · Idea demasiado larga

- **Forma:** Inline en el campo · **En la app:** en la app
- **Dónde:** Capturar y Editar neurona.
- **Lo dispara:** Más de 600 caracteres (local; el servidor responde `invalid_thesis`).
- **Ilustración:** Ninguna · **Ícono iOS / Android:** —
- **Comportamiento:** Reemplaza al contador “N de 600 caracteres”. Guardar queda deshabilitado.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Texto | Te pasaste por %lld caracteres. Dejá solo la idea (hasta 600). | Te pasaste por %lld caracteres. Dejá solo la idea (hasta 600). | You're %lld characters over. Keep just the idea (up to 600). | igual | `capturar.over_limit` |
| Pista relacionada | Parece un link. Guardalo como link para que quede la fuente. | Parece un link. Guardalo como link para que quede la fuente. | Looks like a link. Save it as a link so the source is kept. | igual | `capturar.looks_like_link` |

- **Accesibilidad:** El error queda asociado al campo (accessibilityHint / supportingText con error) y el foco vuelve al campo.
- **iOS y Android:** iOS y Android: mismo componente dentro de la lista o del formulario.

### `error.dictation_permission` · Dictado sin permiso

- **Forma:** Inline en la sheet · **En la app:** en la app
- **Dónde:** Capturar › Voz.
- **Lo dispara:** Micrófono o reconocimiento de voz denegados.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** mic.slash / mic_off
- **Comportamiento:** “Abrir Ajustes” lleva a los permisos de la app. Si el dictado no está disponible (sin reconocimiento en el idioma, sin red en iOS viejos), se muestra el segundo texto sin botón.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | Falta el permiso | Falta el permiso | Permission needed | igual | `capturar.dictate.no_permission` |
| Cuerpo | Para dictar, Lumbre necesita el micrófono y el reconocimiento de voz. Activalos en Ajustes. | Para dictar, Lumbre necesita el micrófono y el reconocimiento de voz. Activalos en Ajustes. | To dictate, Lumbre needs the microphone and speech recognition. Turn them on in Settings. | igual | `capturar.dictate.permission_body` |
| Secundaria | Abrir Ajustes | Abrir Ajustes | Open Settings | igual | `capturar.dictate.open_settings` |
| No disponible, título | El dictado no está disponible | El dictado no está disponible | Dictation isn't available | igual | `capturar.dictate.unavailable` |
| No disponible, cuerpo | Probá en un rato o escribí la idea en Texto. | Probá en un rato o escribí la idea en Texto. | Try again in a bit or type the idea in Text. | igual | `capturar.dictate.unavailable_body` |

- **Accesibilidad:** Al aparecer se anuncia el título (VoiceOver: anuncio; Android: live region educada). El ícono es decorativo.
- **iOS y Android:** Android: solo pide el micrófono (“Para dictar, Lumbre necesita el micrófono. Activalo en Configuración.”) y el botón dice “Abrir Configuración”.

## Offline

Sin red, la app muestra lo último que cargó, guarda las capturas en el teléfono y avisa qué acciones esperan conexión.

### `offline.banner` · Banner sin conexión

- **Forma:** Banner · **En la app:** nuevo
- **Dónde:** Hoy, Red, Circuitos y los detalles, arriba del contenido.
- **Lo dispara:** El sistema dice que no hay red (NWPathMonitor / ConnectivityManager) y la pantalla muestra lo que tiene en caché.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** wifi.slash / wifi_off
- **Comportamiento:** Aparece después de 2 s sin red (para no parpadear). No se cierra a mano; al volver la red desaparece y la pantalla se recarga sola. Uno por pantalla; no va dentro de sheets.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | — | Sin conexión | You're offline | nuevo | `errores.offline` |
| Cuerpo | — | Ves lo último que se cargó. Lo que captures se guarda y se manda cuando vuelva. | You're seeing what last loaded. Anything you capture is saved and sent when you're back online. | nuevo | nueva |

- **Por qué cambia:** Hoy la caché muestra datos viejos sin avisar, y las acciones fallan recién al tocarlas.
- **Accesibilidad:** Se anuncia una sola vez al aparecer, no en cada pantalla. Es un elemento combinado (título + cuerpo); el botón, si hay, es aparte.
- **iOS y Android:** iOS y Android: mismo componente dentro de la lista o del formulario.

### `offline.hoy_cache` · Hoy desde la caché

- **Forma:** Pantalla con banner · **En la app:** nuevo · **Provisorio**
- **Dónde:** Hoy.
- **Lo dispara:** Sin red, con la respuesta de `/today` en la caché.
- **Ilustración:** Ninguna (se ve la chispa) · **Ícono iOS / Android:** —
- **Comportamiento:** La chispa revelada se ve completa. Guardar idea, Planificar y No me sirve quedan deshabilitados (no se encolan en v1).

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Banner | — | (el de `offline.banner`) | — | nuevo | nueva |

- **Accesibilidad:** Los botones deshabilitados se leen como “atenuado” / “desactivado” y tienen como pista el texto de abajo.
- **iOS y Android:** iOS y Android: mismo componente dentro de la lista o del formulario.
- **Provisorio, a confirmar:** Que las acciones sobre la chispa no se encolen es una decisión de alcance: la cola de v1 es solo para capturas.

### `offline.extra_spark` · Otra chispa sin conexión

- **Forma:** Inline · **En la app:** nuevo
- **Dónde:** Hoy, sección “Otra chispa”.
- **Lo dispara:** Sin red con extras disponibles.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** —
- **Comportamiento:** “Pedir otra chispa” queda deshabilitado con la nota debajo. Al volver la red se habilita solo.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Nota | — | Para encender otra chispa hace falta conexión. | Lighting another spark needs a connection. | nuevo | nueva |

- **Por qué cambia:** Antes de tocar se sabe que va a fallar: mejor decirlo que mostrar un error.
- **Accesibilidad:** La nota es la pista de accesibilidad del botón deshabilitado.
- **iOS y Android:** iOS y Android: mismo componente dentro de la lista o del formulario.

### `offline.reveal` · Reveal sin conexión

- **Forma:** Pantalla con banner · **En la app:** cambia · **Provisorio**
- **Dónde:** Hoy, con la chispa del día por revelar.
- **Lo dispara:** Sin red. Si el contenido de la chispa está en la caché, se revela igual y el estado `revealed` se manda al volver. Si no llegó al teléfono, este estado.
- **Ilustración:** estado-sin-chispa · **Ícono iOS / Android:** —
- **Comportamiento:** “Encender la chispa” deshabilitado, sin punto rosa (no hay nada que encender todavía). Al volver la red, la pantalla se recarga y el botón se habilita.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | — | Tu chispa de hoy te espera | Today's spark is waiting for you | nuevo | nueva |
| Cuerpo | — | Se enciende cuando vuelva la conexión. | It lights up when you're back online. | nuevo | nueva |
| Principal (deshabilitado) | Encender la chispa | Encender la chispa | Light the spark | igual | `reveal.ignite` |

- **Por qué cambia:** Hoy el reveal fallaría al tocar, en el momento más importante del día.
- **Accesibilidad:** La ilustración es decorativa (oculta a VoiceOver y TalkBack). Título como encabezado; título y cuerpo se leen juntos; el botón es el siguiente elemento.
- **iOS y Android:** iOS: ContentUnavailableView con EmptyStateLabel. Android: Column centrada en el área de contenido (no hay equivalente del sistema), mismo copy e ilustración.
- **Provisorio, a confirmar:** Revelar desde la caché sin red y mandar el estado después es una decisión técnica que no está en plan.md.

### `offline.capture_queued` · Captura guardada en la cola

- **Forma:** Toast · **En la app:** cambia
- **Dónde:** Capturar, Share Extension e intent de compartir.
- **Lo dispara:** Guardar falla por red con el flag `offlineQueue` prendido: la captura queda en disco.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** icloud.and.arrow.up / cloud_upload (hoy: checkmark)
- **Comportamiento:** La sheet se cierra a los 1,8 s. Si se pidió conceptualizar, se conceptualiza al mandarse; si para entonces no quedan pruebas, se guarda sin conceptualizar.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Toast | Guardado sin conexión: lo mandamos cuando vuelva | Guardado sin conexión: lo mandamos cuando vuelva | Saved offline: we'll send it when you're back online | igual | `capturar.offline_queued` |

- **Por qué cambia:** Cambia solo el ícono: el tilde dice “guardado en tu red” y todavía no lo está.
- **Accesibilidad:** Se anuncia al aparecer. Con VoiceOver o TalkBack activos dura 6 s en lugar de 3 s.
- **iOS y Android:** iOS: cápsula propia abajo, sobre la barra. Android: Snackbar del SnackbarHost, con acción opcional.
- **Analytics:** `capture_submitted` (offline `true`)

### `offline.capture_failed_local` · No se pudo guardar en el teléfono

- **Forma:** Alerta · **En la app:** cambia
- **Dónde:** Capturar.
- **Lo dispara:** Sin red y la cola no pudo escribir en disco (o la cola está apagada por flag).
- **Ilustración:** Ninguna · **Ícono iOS / Android:** —
- **Comportamiento:** La sheet queda abierta con el texto.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | No se pudo guardar | No se pudo guardar | Couldn't save | igual | `comun.save_failed` |
| Cuerpo | Sin conexión y no pudimos guardarlo en el teléfono. Probá de nuevo en un rato. | No hay conexión y no pudimos guardarlo en el teléfono. Lo que escribiste sigue acá: probá de nuevo en un rato. | There's no connection and we couldn't save it on your phone. What you wrote is still here: try again in a bit. | cambia | `capturar.offline_failed (cambia)` |
| Cuerpo, cola apagada | Sin conexión. Probá de nuevo cuando vuelva la red. | Sin conexión. Probá de nuevo cuando vuelva la red. | You're offline. Try again when you're back online. | igual | `capturar.offline_retry` |

- **Por qué cambia:** Igual que `error.save`: decir que el texto no se perdió.
- **Accesibilidad:** Alerta del sistema: el lector la lee al abrirse y el foco queda en ella. El botón por defecto es el de la derecha (iOS) o el último (Android).
- **iOS y Android:** iOS: .alert con botones del sistema. Android: AlertDialog de Material 3, título en la fuente del sistema, botones de texto a la derecha.
- **Analytics:** `capture_failed` (reason `network`)

### `offline.queue_pending` · Capturas esperando conexión

- **Forma:** Banner · **En la app:** en la app
- **Dónde:** Red, arriba de la lista. Propuesta: también en Hoy, arriba del contador.
- **Lo dispara:** La cola tiene una o más capturas.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** icloud.and.arrow.up / cloud_upload
- **Comportamiento:** Tocarlo reintenta: el ícono pasa a spinner del sistema y el banner se deshabilita mientras manda. Con el banner de sin conexión en pantalla, este va abajo y sin “Reintentar”.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título, una | 1 captura espera conexión | 1 captura espera conexión | 1 capture waiting for a connection | igual | `capturar.queue.one` |
| Título, varias | %lld capturas esperan conexión | %lld capturas esperan conexión | %lld captures waiting for a connection | igual | `capturar.queue.many` |
| Acción | Reintentar | Reintentar | Try again | igual | `comun.retry` |
| Pista de accesibilidad | Intenta mandarlas ahora | Intenta mandarlas ahora | Tries to send them now | igual | `capturar.queue.retry_hint` |

- **Accesibilidad:** Se anuncia una sola vez al aparecer, no en cada pantalla. Es un elemento combinado (título + cuerpo); el botón, si hay, es aparte.
- **iOS y Android:** iOS y Android: mismo componente dentro de la lista o del formulario. En Android, plurals.

### `offline.queue_flushed` · Cola enviada

- **Forma:** Toast · **En la app:** nuevo
- **Dónde:** Cualquier pestaña, con la app adelante.
- **Lo dispara:** Al volver la red se mandaron capturas de la cola.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** checkmark.circle / check_circle (en `success`)
- **Comportamiento:** Una vez por vaciado. Habla de capturas, no de neuronas: una captura conceptualizada puede dar hasta 3.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Una | — | Se guardó 1 captura que esperaba conexión | 1 capture that was waiting for a connection was saved | nuevo | nueva |
| Varias | — | Se guardaron %lld capturas que esperaban conexión | %lld captures that were waiting for a connection were saved | nuevo | nueva |

- **Por qué cambia:** Hoy la lista se recarga sin decir nada: la persona no sabe si lo que guardó offline llegó.
- **Accesibilidad:** Se anuncia al aparecer. Con VoiceOver o TalkBack activos dura 6 s en lugar de 3 s.
- **iOS y Android:** iOS: cápsula propia abajo, sobre la barra. Android: Snackbar del SnackbarHost, con acción opcional. En Android, plurals.
- **Analytics:** `offline_queue_flushed` (`count`)

### `offline.queue_discarded` · Captura descartada de la cola

- **Forma:** Alerta · **En la app:** cambia
- **Dónde:** Cualquier pestaña.
- **Lo dispara:** Al mandarse, el servidor rechazó una captura encolada por validación: `quota_exceeded`, `too_many_categories`, `invalid_source`, `invalid_thesis`.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** —
- **Comportamiento:** Muestra las primeras palabras para que se sepa cuál era. “Copiar texto” copia la idea completa al portapapeles. La cola guarda ese texto solo hasta que se cierra la alerta y nunca lo escribe en el log.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | No pudimos guardar una captura | No pudimos guardar una captura | We couldn't save a capture | igual | `capturar.queue.failed_title` |
| Cuerpo | Una captura que guardaste sin conexión no se pudo mandar y la sacamos de la cola. %@ | La guardaste sin conexión: “%1$@…”. %2$@ Copiá el texto para guardarla de nuevo. | You saved it offline: “%1$@…”. %2$@ Copy the text to save it again. | cambia | `capturar.queue.failed_body (cambia)` |
| Motivo (%2$@) | (el mensaje de error de la API) | Llegaste a las capturas de ese día. / Ya tenés 50 categorías. / El link no parece válido. | You'd reached that day's captures. / You already have 50 categories. / The link doesn't look valid. | cambia | nueva |
| Botones | Entendido | Entendido · Copiar texto | Got it · Copy text | cambia | `comun.ok (cambia)` |

- **Por qué cambia:** “Cola” es una palabra técnica, y sin decir cuál era ni darte el texto, la idea se pierde.
- **Accesibilidad:** Alerta del sistema: el lector la lee al abrirse y el foco queda en ella. El botón por defecto es el de la derecha (iOS) o el último (Android).
- **iOS y Android:** iOS: .alert con botones del sistema. Android: AlertDialog de Material 3, título en la fuente del sistema, botones de texto a la derecha.
- **Analytics:** log `discarded queued capture` (solo el código)

### `offline.search` · Búsqueda sin conexión

- **Forma:** Inline · **En la app:** cambia · **Provisorio**
- **Dónde:** Red, con texto en la búsqueda.
- **Lo dispara:** `/search` falla por red (la búsqueda por ideas pasa en el servidor).
- **Ilustración:** Ninguna · **Ícono iOS / Android:** wifi.slash / wifi_off
- **Comportamiento:** Reemplaza los resultados. “Reintentar” repite la búsqueda; al volver la red se repite sola. Los chips de categoría siguen andando sobre la caché.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | Sin conexión | La búsqueda necesita conexión | Search needs a connection | cambia | `errores.offline (cambia)` |
| Cuerpo | Revisá tu conexión y probá de nuevo. | Mientras tanto, mirá tus neuronas por categoría. | Meanwhile, browse your neurons by category. | cambia | `errores.offline_body (cambia)` |
| Secundaria | Reintentar | Reintentar | Try again | igual | `comun.retry` |

- **Por qué cambia:** Explica por qué la búsqueda no anda aunque las neuronas se vean, y ofrece lo que sí funciona.
- **Accesibilidad:** Al aparecer se anuncia el título (VoiceOver: anuncio; Android: live region educada). El ícono es decorativo.
- **iOS y Android:** iOS y Android: mismo componente dentro de la lista o del formulario.
- **Provisorio, a confirmar:** Un filtro local por palabras como respaldo sin red sería útil, pero no está en plan.md; queda como idea.

### `offline.planner` · Planificador sin conexión

- **Forma:** Inline · **En la app:** nuevo
- **Dónde:** Planificador, arriba del campo.
- **Lo dispara:** Sin red.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** wifi.slash / wifi_off
- **Comportamiento:** La conversación se puede leer; el campo y los atajos quedan deshabilitados. Si se corta en medio de una respuesta, pasa a `error.ai_planner`.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Texto | — | El planificador necesita conexión. Podés leer la conversación mientras tanto. | The planner needs a connection. You can read the conversation in the meantime. | nuevo | nueva |

- **Accesibilidad:** Al aparecer se anuncia el título (VoiceOver: anuncio; Android: live region educada). El ícono es decorativo.
- **iOS y Android:** iOS y Android: mismo componente dentro de la lista o del formulario.

### `offline.write_failed` · Cambio sin conexión

- **Forma:** Toast o alerta · **En la app:** cambia
- **Dónde:** Editar neurona, confirmar borrador, mover, renombrar, borrar, Guardar idea, No me sirve.
- **Lo dispara:** Escritura directa (PostgREST) sin red. Estas escrituras no se encolan.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** wifi.slash / wifi_off
- **Comportamiento:** Acción de un toque: toast (Android, con “Reintentar”). Si había texto escrito (editar), alerta y la sheet queda abierta.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Toast | Sin conexión. Lo guardamos y lo mandamos cuando vuelva. | Sin conexión: no se guardó el cambio | Offline: the change wasn't saved | cambia | `errores.api.offline (cambia)` |
| Alerta, cuerpo | Sin conexión. Lo guardamos y lo mandamos cuando vuelva. | No hay conexión. Lo que escribiste sigue acá: probá de nuevo cuando vuelva. | There's no connection. What you wrote is still here: try again when you're back online. | cambia | `errores.api.offline (cambia)` |
| Acción (Android) | — | Reintentar | Try again | nuevo | `comun.retry` |

- **Por qué cambia:** Hoy `LumbreAPIError.offline` promete una cola que solo existe para las capturas: el cambio se pierde y la app dice que lo guardó.
- **Accesibilidad:** Se anuncia al aparecer. Con VoiceOver o TalkBack activos dura 6 s en lugar de 3 s.
- **iOS y Android:** iOS: cápsula propia abajo, sobre la barra. Android: Snackbar del SnackbarHost, con acción opcional. iOS: .alert con botones del sistema. Android: AlertDialog de Material 3, título en la fuente del sistema, botones de texto a la derecha.
- **Analytics:** `error_shown` (code `offline`)

## Contenido inaccesible

Links, fotos, PDFs y audios de los que no se puede sacar una idea. El contenido externo es un dato: nunca decimos que leímos algo que no pudimos leer, y la salida siempre es “¿Qué idea te deja esto?”.

### `inaccessible.generic` · Sin idea: escribila vos

- **Forma:** Inline en la sheet · **En la app:** en la app
- **Dónde:** Capturar (link, foto, PDF, audio) con “Conceptualizar” prendido.
- **Lo dispara:** 422 `needs_thesis` sin motivo, o confianza baja (plan.md §5). Es la caída por defecto de toda la familia.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** exclamationmark.bubble / feedback
- **Comportamiento:** Aviso arriba de la sheet; el interruptor de conceptualizar se apaga, el foco va a “¿Qué idea te deja esto?” y se anuncia el aviso. La fuente queda adjunta y se guarda con la neurona. La prueba de conceptualización se devuelve.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Aviso | No pudimos sacar una idea de esto. Escribí qué idea te deja y lo guardamos con tus palabras. | No pudimos sacar una idea de esto. Escribí qué idea te deja y lo guardamos con tus palabras. | We couldn't get an idea out of this. Write what idea it leaves you with and we'll save it in your words. | igual | `capturar.no_idea_found` |
| Anuncio | No pudimos sacar una idea de esto. Escribí qué idea te deja. | No pudimos sacar una idea de esto. Escribí qué idea te deja. | We couldn't get an idea out of this. Write what idea it leaves you with. | igual | `capturar.no_idea_found_short` |

- **Accesibilidad:** Al aparecer se anuncia el título (VoiceOver: anuncio; Android: live region educada). El ícono es decorativo. El error queda asociado al campo (accessibilityHint / supportingText con error) y el foco vuelve al campo.
- **iOS y Android:** Dentro de la sheet de Capturar. iOS: aviso arriba del campo. Android: igual, dentro de la ModalBottomSheet; el teclado no tapa el aviso.
- **Analytics:** `distill_fallback_shown` (reason `low_confidence`)

### `inaccessible.moderated` · Contenido rechazado por moderación

- **Forma:** Inline en la sheet · **En la app:** cambia
- **Dónde:** Capturar; planificador.
- **Lo dispara:** La moderación de entrada marca el contenido (en Capturar, `outcome = none`; en el planificador, 400 `invalid_request`).
- **Ilustración:** Ninguna · **Ícono iOS / Android:** exclamationmark.bubble / feedback
- **Comportamiento:** En Capturar se usa el aviso de `inaccessible.generic`, sin dar el motivo: no acusamos a nadie. En el planificador, aviso debajo del mensaje y el campo queda con el texto para reescribirlo.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Capturar | No pudimos sacar una idea de esto. Escribí qué idea te deja y lo guardamos con tus palabras. | No pudimos sacar una idea de esto. Escribí qué idea te deja y lo guardamos con tus palabras. | We couldn't get an idea out of this. Write what idea it leaves you with and we'll save it in your words. | igual | `capturar.no_idea_found` |
| Planificador | (texto genérico del error) | No podemos responder a ese mensaje. Probá planteándolo de otra forma. | We can't reply to that message. Try putting it another way. | cambia | nueva |

- **Por qué cambia:** Nunca culpar: no decimos “tu contenido viola…”. El reporte de contenido generado sigue en la chispa y en el planificador.
- **Accesibilidad:** Al aparecer se anuncia el título (VoiceOver: anuncio; Android: live region educada). El ícono es decorativo.
- **iOS y Android:** Dentro de la sheet de Capturar. iOS: aviso arriba del campo. Android: igual, dentro de la ModalBottomSheet; el teclado no tapa el aviso.
- **Analytics:** log de moderación (solo categorías, sin texto)

### `inaccessible.audio_no_speech` · Audio sin palabras

- **Forma:** Inline en la sheet · **En la app:** nuevo · **Provisorio**
- **Dónde:** Capturar › audio largo (conceptualización Pro).
- **Lo dispara:** 422 `needs_thesis` con `reason` `no_speech`: música, silencio o ruido.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** waveform / graphic_eq
- **Comportamiento:** Aviso arriba de la sheet; el interruptor de conceptualizar se apaga, el foco va a “¿Qué idea te deja esto?” y se anuncia el aviso. La fuente queda adjunta y se guarda con la neurona. La prueba de conceptualización se devuelve. El audio no se guarda (plan.md §6).

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Aviso | — | En este audio no encontramos palabras para transcribir. Escribí qué idea te deja y la guardamos. | We didn't find any words to transcribe in this audio. Write what idea it leaves you with and we'll save it. | nuevo | nueva |

- **Accesibilidad:** Al aparecer se anuncia el título (VoiceOver: anuncio; Android: live region educada). El ícono es decorativo. El error queda asociado al campo (accessibilityHint / supportingText con error) y el foco vuelve al campo.
- **iOS y Android:** Dentro de la sheet de Capturar. iOS: aviso arriba del campo. Android: igual, dentro de la ModalBottomSheet; el teclado no tapa el aviso.
- **Analytics:** `distill_fallback_shown` (reason `inaccessible`)
- **Provisorio, a confirmar:** La captura de audios largos todavía no tiene pantalla en la app; el texto queda listo.

### `inaccessible.paywall_link` · Link con muro de pago

- **Forma:** Inline en la sheet · **En la app:** nuevo · **Provisorio**
- **Dónde:** Capturar › Link.
- **Lo dispara:** 422 `needs_thesis` con `reason` `paywall`: la página solo dio título y descripción y no alcanzó para una idea.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** exclamationmark.bubble / feedback
- **Comportamiento:** Aviso arriba de la sheet; el interruptor de conceptualizar se apaga, el foco va a “¿Qué idea te deja esto?” y se anuncia el aviso. La fuente queda adjunta y se guarda con la neurona. La prueba de conceptualización se devuelve. Si el título y la descripción alcanzan para una idea con confianza media, va a borrador (`inaccessible.draft_medium`).

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Aviso | — | Esta nota tiene muro de pago: solo pudimos leer el título. Escribí qué idea te deja y la guardamos con el link. | This article is behind a paywall: we could only read the title. Write what idea it leaves you with and we'll save it with the link. | nuevo | nueva |
| Variante: solo título y descripción (por ejemplo, un video sin transcripción) | — | Solo pudimos leer el título y la descripción. Escribí qué idea te deja y la guardamos con el link. | We could only read the title and description. Write what idea it leaves you with and we'll save it with the link. | nuevo | nueva |

- **Por qué cambia:** Decir qué se pudo leer (y qué no) en lugar de “no pudimos sacar una idea”.
- **Accesibilidad:** Al aparecer se anuncia el título (VoiceOver: anuncio; Android: live region educada). El ícono es decorativo. El error queda asociado al campo (accessibilityHint / supportingText con error) y el foco vuelve al campo.
- **iOS y Android:** Dentro de la sheet de Capturar. iOS: aviso arriba del campo. Android: igual, dentro de la ModalBottomSheet; el teclado no tapa el aviso.
- **Analytics:** `distill_fallback_shown` (reason `inaccessible`)
- **Provisorio, a confirmar:** Requiere que el servidor mande el motivo (`reason`) en el 422; la conceptualización ya lo devuelve en su JSON. Sin motivo, cae a `inaccessible.generic`.

### `inaccessible.social_login` · Red social con login

- **Forma:** Inline en la sheet · **En la app:** nuevo · **Provisorio**
- **Dónde:** Capturar › Link de Instagram, TikTok, Facebook o LinkedIn.
- **Lo dispara:** El host está en la lista de redes que piden login. Se sabe antes de guardar.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** lock / lock
- **Comportamiento:** Aparece al pegar el link, antes de guardar. El interruptor de conceptualizar queda deshabilitado (“No se puede conceptualizar este link.”), así no se gasta una prueba. El link se guarda como fuente.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Aviso | — | %@ no deja leer publicaciones sin iniciar sesión. Si tiene texto, copialo y pegalo; si no, escribí qué idea te deja. | %@ doesn't let us read posts without signing in. If it has text, copy and paste it; if not, write what idea it leaves you with. | nuevo | nueva |
| Nota del interruptor | — | No se puede conceptualizar este link. | This link can't be conceptualized. | nuevo | nueva |

- **Por qué cambia:** plan.md §5: de estas redes no se saca “casi nada”. Avisar antes ahorra la espera y la prueba.
- **Accesibilidad:** Al aparecer se anuncia el título (VoiceOver: anuncio; Android: live region educada). El ícono es decorativo.
- **iOS y Android:** Dentro de la sheet de Capturar. iOS: aviso arriba del campo. Android: igual, dentro de la ModalBottomSheet; el teclado no tapa el aviso.
- **Analytics:** `distill_fallback_shown` (reason `inaccessible`)
- **Provisorio, a confirmar:** Detectar por host y apagar la conceptualización antes de guardar es una decisión de comportamiento que no está en plan.md.

### `inaccessible.private_doc` · Documento privado

- **Forma:** Inline en la sheet · **En la app:** nuevo · **Provisorio**
- **Dónde:** Capturar › Link (Google Docs, Drive, Notion, Dropbox…).
- **Lo dispara:** 422 `needs_thesis` con `reason` `private` (401/403 o página de login).
- **Ilustración:** Ninguna · **Ícono iOS / Android:** lock / lock
- **Comportamiento:** Aviso arriba de la sheet; el interruptor de conceptualizar se apaga, el foco va a “¿Qué idea te deja esto?” y se anuncia el aviso. La fuente queda adjunta y se guarda con la neurona. La prueba de conceptualización se devuelve.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Aviso | — | Este documento es privado: Lumbre no puede abrirlo. Escribí qué idea te deja, o compartilo como PDF. | This document is private: Lumbre can't open it. Write what idea it leaves you with, or share it as a PDF. | nuevo | nueva |

- **Accesibilidad:** Al aparecer se anuncia el título (VoiceOver: anuncio; Android: live region educada). El ícono es decorativo. El error queda asociado al campo (accessibilityHint / supportingText con error) y el foco vuelve al campo.
- **iOS y Android:** Dentro de la sheet de Capturar. iOS: aviso arriba del campo. Android: igual, dentro de la ModalBottomSheet; el teclado no tapa el aviso.
- **Analytics:** `distill_fallback_shown` (reason `inaccessible`)
- **Provisorio, a confirmar:** Igual que el muro de pago: necesita `reason` en el 422.

### `inaccessible.unreachable` · La página no carga

- **Forma:** Inline en la sheet · **En la app:** nuevo · **Provisorio**
- **Dónde:** Capturar › Link.
- **Lo dispara:** 422 `needs_thesis` con `reason` `unreachable`: timeout de 8 s, 404, 5xx, más de 1,5 MB o host no público.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** wifi.slash / wifi_off
- **Comportamiento:** Aviso arriba de la sheet; el interruptor de conceptualizar se apaga, el foco va a “¿Qué idea te deja esto?” y se anuncia el aviso. La fuente queda adjunta y se guarda con la neurona. La prueba de conceptualización se devuelve.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Aviso | — | No pudimos abrir esta página. Escribí qué idea te deja y la guardamos con el link. No se descontó la prueba. | We couldn't open this page. Write what idea it leaves you with and we'll save it with the link. It didn't use a trial. | nuevo | nueva |

- **Por qué cambia:** “No se descontó la prueba” solo en free.
- **Accesibilidad:** Al aparecer se anuncia el título (VoiceOver: anuncio; Android: live region educada). El ícono es decorativo. El error queda asociado al campo (accessibilityHint / supportingText con error) y el foco vuelve al campo.
- **iOS y Android:** Dentro de la sheet de Capturar. iOS: aviso arriba del campo. Android: igual, dentro de la ModalBottomSheet; el teclado no tapa el aviso.
- **Analytics:** `distill_fallback_shown` (reason `inaccessible`)
- **Provisorio, a confirmar:** Necesita `reason` en el 422.

### `inaccessible.image_no_idea` · Imagen sin idea adentro

- **Forma:** Inline en la sheet · **En la app:** nuevo · **Provisorio**
- **Dónde:** Capturar › Foto con “Conceptualizar la imagen”.
- **Lo dispara:** 422 `needs_thesis` con `reason` `no_idea`: un paisaje, una foto personal.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** exclamationmark.bubble / feedback
- **Comportamiento:** Aviso arriba de la sheet; el interruptor de conceptualizar se apaga, el foco va a “¿Qué idea te deja esto?” y se anuncia el aviso. La fuente queda adjunta y se guarda con la neurona. La prueba de conceptualización se devuelve. Nunca describimos a las personas de la foto.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Aviso | — | En esta foto no encontramos una idea para guardar. Escribí qué te deja y la guardamos con la foto. | We didn't find an idea to save in this photo. Write what it leaves you with and we'll save it with the photo. | nuevo | nueva |

- **Accesibilidad:** Al aparecer se anuncia el título (VoiceOver: anuncio; Android: live region educada). El ícono es decorativo. El error queda asociado al campo (accessibilityHint / supportingText con error) y el foco vuelve al campo.
- **iOS y Android:** Dentro de la sheet de Capturar. iOS: aviso arriba del campo. Android: igual, dentro de la ModalBottomSheet; el teclado no tapa el aviso. La foto queda en la fototeca (iOS) o la galería (Android).
- **Analytics:** `distill_fallback_shown` (reason `low_confidence`)
- **Provisorio, a confirmar:** Necesita `reason` en el 422.

### `inaccessible.ocr_no_text` · Foto sin texto reconocible

- **Forma:** Inline en la sheet · **En la app:** cambia
- **Dónde:** Capturar › Foto, captura de pantalla o página escaneada.
- **Lo dispara:** El OCR del teléfono (VisionKit / ML Kit) no encontró texto.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** info.circle / info
- **Comportamiento:** Texto de ayuda debajo de la imagen, antes de guardar. Sin pruebas o como invitado, la variante sin “conceptualizá la imagen”.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Ayuda | No encontramos texto. Escribí qué idea te deja o conceptualizá la imagen. | No encontramos texto. Escribí qué idea te deja o conceptualizá la imagen. | We didn't find any text. Write what idea it leaves you with, or conceptualize the image. | igual | `capturar.no_text_found` |
| Sin conceptualización | — | No encontramos texto. Escribí qué idea te deja. | We didn't find any text. Write what idea it leaves you with. | nuevo | nueva |

- **Por qué cambia:** Sugerir conceptualizar cuando no se puede manda a un callejón.
- **Accesibilidad:** Al aparecer se anuncia el título (VoiceOver: anuncio; Android: live region educada). El ícono es decorativo.
- **iOS y Android:** Dentro de la sheet de Capturar. iOS: aviso arriba del campo. Android: igual, dentro de la ModalBottomSheet; el teclado no tapa el aviso.

### `inaccessible.pdf_no_text` · PDF sin texto

- **Forma:** Inline en la sheet · **En la app:** nuevo
- **Dónde:** Capturar › PDF sin conceptualización (free sin pruebas, invitado).
- **Lo dispara:** El PDF no tiene capa de texto (escaneado).
- **Ilustración:** Ninguna · **Ícono iOS / Android:** doc / description
- **Comportamiento:** Aviso debajo del adjunto. Con conceptualización (Pro o con pruebas) no aparece: la IA lee el PDF como imagen.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Aviso | — | Este PDF no tiene texto seleccionable. Escaneá las páginas que te importan con Escanear página, o escribí qué idea te deja. | This PDF has no selectable text. Scan the pages you care about with Scan page, or write what idea it leaves you with. | nuevo | nueva |

- **Por qué cambia:** Da una salida que funciona gratis (el escaneo con OCR en el teléfono).
- **Accesibilidad:** Al aparecer se anuncia el título (VoiceOver: anuncio; Android: live region educada). El ícono es decorativo.
- **iOS y Android:** Dentro de la sheet de Capturar. iOS: aviso arriba del campo. Android: igual, dentro de la ModalBottomSheet; el teclado no tapa el aviso.

### `inaccessible.pdf_too_large` · PDF de más de 20 MB

- **Forma:** Inline en el campo · **En la app:** cambia
- **Dónde:** Capturar › PDF.
- **Lo dispara:** El archivo elegido pesa más de 20 MB (se chequea en el teléfono, antes de subir).
- **Ilustración:** Ninguna · **Ícono iOS / Android:** exclamationmark.circle / error (en `danger`)
- **Comportamiento:** El adjunto no se agrega.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Texto | El PDF pesa más de 20 MB. Probá con uno más liviano. | El PDF pesa más de 20 MB. Probá con uno más liviano o escaneá solo las páginas que te importan. | The PDF is over 20 MB. Try a lighter one or scan just the pages you care about. | cambia | `capturar.pdf_too_big (cambia)` |

- **Por qué cambia:** Suma una salida que no depende de conseguir otro archivo.
- **Accesibilidad:** El error queda asociado al campo (accessibilityHint / supportingText con error) y el foco vuelve al campo.
- **iOS y Android:** iOS y Android: mismo componente dentro de la lista o del formulario.
- **Analytics:** `capture_failed` (reason `too_large`)

### `inaccessible.file_unreadable` · Archivo que no abre

- **Forma:** Inline en el campo · **En la app:** cambia
- **Dónde:** Capturar › Foto o PDF.
- **Lo dispara:** La imagen o el PDF están dañados, o el PDF tiene contraseña.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** exclamationmark.circle / error (en `danger`)
- **Comportamiento:** El adjunto no se agrega.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Imagen | No pudimos abrir esa imagen. Probá con otra. | No pudimos abrir esa imagen. Probá con otra. | We couldn't open that image. Try another one. | igual | `capturar.image_failed` |
| PDF | No pudimos abrir ese PDF. Probá con otro. | No pudimos abrir ese PDF. Probá con otro. | We couldn't open that PDF. Try another one. | igual | `capturar.pdf_failed` |
| PDF con contraseña | — | Este PDF tiene contraseña. Sacásela o probá con otro. | This PDF is password-protected. Remove the password or try another one. | nuevo | nueva |

- **Por qué cambia:** La contraseña es el caso más común y tiene arreglo.
- **Accesibilidad:** El error queda asociado al campo (accessibilityHint / supportingText con error) y el foco vuelve al campo.
- **iOS y Android:** iOS y Android: mismo componente dentro de la lista o del formulario.

### `inaccessible.unsupported_format` · Formato no soportado

- **Forma:** Inline en la Share Extension · **En la app:** nuevo
- **Dónde:** Share Extension (iOS) e intent de compartir (Android).
- **Lo dispara:** Llega un Word, un PowerPoint o un video (plan.md §4: no se soportan).
- **Ilustración:** Ninguna · **Ícono iOS / Android:** doc / description
- **Comportamiento:** La extensión se abre igual, con el aviso y el campo de la idea: se puede guardar la idea sin el archivo.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Aviso | — | Lumbre no lee archivos de Word, PowerPoint ni videos. Guardá un PDF o el link, o escribí qué idea te deja. | Lumbre doesn't read Word, PowerPoint or video files. Save a PDF or the link, or write what idea it leaves you with. | nuevo | nueva |

- **Por qué cambia:** Hoy no hay texto para este caso.
- **Accesibilidad:** Al aparecer se anuncia el título (VoiceOver: anuncio; Android: live region educada). El ícono es decorativo.
- **iOS y Android:** iOS: Share Extension compacta. Android: actividad del intent como bottom sheet.
- **Analytics:** `capture_failed` (reason `unsupported_format`)

### `inaccessible.draft_medium` · Borrador para confirmar (confianza media)

- **Forma:** Pantalla en la sheet · **En la app:** en la app
- **Dónde:** Capturar, después de conceptualizar; Red (sección de borradores) y detalle de neurona.
- **Lo dispara:** `distillation = medium`: la neurona se guarda con `status = draft`.
- **Ilustración:** Ninguna · **Ícono iOS / Android:** info.circle / info
- **Comportamiento:** Confirmar la pasa a `ready`; Editar abre el editor; Descartar pide confirmación y la borra. Los borradores no entran en las chispas hasta confirmarlos.

| Campo | En la app hoy | Propuesto (es) | en | Estado | Clave |
|---|---|---|---|---|---|
| Título | Revisá la neurona | Revisá la neurona | Check the neuron | igual | `capturar.draft.title` |
| Aviso, una | Lumbre no está del todo seguro de esta idea. Revisala antes de guardarla. | Lumbre no está del todo seguro de esta idea. Revisala antes de guardarla. | Lumbre isn't quite sure about this idea. Check it before saving. | igual | `capturar.draft.unsure_one` |
| Aviso, varias | Lumbre no está del todo seguro de estas ideas. Revisalas antes de guardarlas. | Lumbre no está del todo seguro de estas ideas. Revisalas antes de guardarlas. | Lumbre isn't quite sure about these ideas. Check them before saving. | igual | `capturar.draft.unsure_many` |
| Botones | Confirmar · Editar · Descartar | Confirmar · Editar · Descartar | Confirm · Edit · Discard | igual | nueva |
| Descartar, alerta | ¿Descartar este borrador? / La neurona no se guarda en tu red. | ¿Descartar este borrador? / La neurona no se guarda en tu red. | Discard this draft? / The neuron won't be saved to your network. | igual | nueva |
| Red, sección | Borradores para confirmar / Lumbre no estaba del todo seguro de estas ideas. Abrilas y confirmalas o corregilas. | Borradores para confirmar / Lumbre no estaba del todo seguro de estas ideas. Abrilas y confirmalas o corregilas. | Drafts to confirm / Lumbre wasn't quite sure about these ideas. Open them and confirm or fix them. | igual | nueva |

- **Accesibilidad:** Confirmar es la acción por defecto. El aviso se lee antes que la neurona.
- **iOS y Android:** iOS: sheet con detent .large. Android: ModalBottomSheet.
- **Analytics:** `concept_saved` (status `draft`, confidence `medium`)

## Hallazgos en la app y el backend

1. `LumbreAPIError.offline` dice “Sin conexión. Lo guardamos y lo mandamos cuando vuelva.” y se muestra también en cargas (`LoadErrorView`) y en escrituras que no se encolan (editar, mover, renombrar): promete algo que no pasa. Ver `error.load_offline` y `offline.write_failed`.
2. `ai_unavailable` (503) no está en `LumbreAPIError`: cae en “Algo salió mal. Probá de nuevo.” y no dice que el crédito se devolvió. Ver `error.ai_spark`, `error.ai_distill`.
3. `quota_exceeded` siempre muestra “Llegaste al límite de hoy”, también para cupos del mes (conceptualización, planificador). El texto tiene que salir de la operación, no del código.
4. “Con Lumbre Pro conceptualizás links, fotos y PDFs sin límite”: Pro tiene 300 por mes en `plan_limits`.
5. Circuitos usa “Aceptar” en la alerta; el resto de la app, “Entendido”.
6. El paywall muestra `error.localizedDescription` de StoreKit al usuario.
7. Backend, `/capture`: si la persona escribió su idea y la conceptualización sale con confianza baja, se guarda con sus palabras pero la prueba no se devuelve (el `refund_credit` solo corre cuando no hay tesis).
8. Backend, `/planner`: si la salida no pasa la moderación, manda `ai_unavailable` sin devolver el cupo.
9. Backend: el 422 `needs_thesis` no dice por qué. La conceptualización ya devuelve `reason` en su JSON (plan.md §5); pasarlo permite los textos específicos de `inaccessible.*`.
10. Capturar con `distillation = unavailable` y la idea escrita cierra con “Neurona guardada”: la persona cree que se conceptualizó.
11. `paywall_shown` con trigger `projects` (Circuitos) no está en la lista de `docs/analytics.md`. Faltan también `no_consent` en `spark_empty_state_shown` y `unavailable` en `distill_fallback_shown` si se adoptan estos estados.

## Decisiones provisorias

- `empty.hoy_usadas`: El botón “Crear cuenta” para el invitado depende de cuándo se le pide la cuenta (paso 14).
- `empty.hoy_sin_permiso`: plan.md no dice qué ve Hoy sin el consentimiento de IA. Opción conservadora: no se genera la chispa y se explica por qué, sin insistir.
- `error.quota_capture`: El texto del invitado sale de copy.json (`cuenta.gate.limit`, nuevo); qué ve el invitado se define en `design/prototipo/invitado.md` (propuesta del paso 14, a confirmar).
- `error.quota_circuits`: Para el invitado, el segundo circuito pide primero la cuenta (`cuenta.gate.pro`), no el paywall; se define en `design/prototipo/invitado.md` (propuesta del paso 14, a confirmar).
- `error.account_required`: Cuándo se le pide la cuenta al invitado se define en `design/prototipo/invitado.md` (propuesta del paso 14, a confirmar).
- `error.ai_planner`: Si el servidor manda `refunded: true` en el evento de error, sumar “No se descontó de tu planificador.”
- `error.session_expired`: Para un invitado que pierde la sesión no hay forma de recuperar los datos; qué se le muestra se define en `design/prototipo/invitado.md` (propuesta del paso 14, a confirmar).
- `offline.hoy_cache`: Que las acciones sobre la chispa no se encolen es una decisión de alcance: la cola de v1 es solo para capturas.
- `offline.reveal`: Revelar desde la caché sin red y mandar el estado después es una decisión técnica que no está en plan.md.
- `offline.search`: Un filtro local por palabras como respaldo sin red sería útil, pero no está en plan.md; queda como idea.
- `inaccessible.audio_no_speech`: La captura de audios largos todavía no tiene pantalla en la app; el texto queda listo.
- `inaccessible.paywall_link`: Requiere que el servidor mande el motivo (`reason`) en el 422; la conceptualización ya lo devuelve en su JSON. Sin motivo, cae a `inaccessible.generic`.
- `inaccessible.social_login`: Detectar por host y apagar la conceptualización antes de guardar es una decisión de comportamiento que no está en plan.md.
- `inaccessible.private_doc`: Igual que el muro de pago: necesita `reason` en el 422.
- `inaccessible.unreachable`: Necesita `reason` en el 422.
- `inaccessible.image_no_idea`: Necesita `reason` en el 422.
