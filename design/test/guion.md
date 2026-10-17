# Kit de test: prototipo e ícono

Paso 15 de `plan-ejecucion.md` (prep de MAT-224 y MAT-210). Material para que el test con 5 personas lo corra el usuario. Duración: **30 minutos por persona**. Se prueba primero el ícono solo (sin que la persona vea la marca) y después el prototipo del loop.

| Archivo | Para qué |
|---|---|
| `guion.md` | Este guion: preparación, tareas, preguntas y criterio |
| `icono.html` | Las pantallas para mostrar el ícono solo (pantalla de inicio, tamaño chico y grande, claro y oscuro) |
| `resultados.csv` | La planilla: una fila por persona, una columna por dato |
| `../prototipo/index.html` | El prototipo. Tiene el panel con el registro de lo que hace cada persona |

## Criterio de salida

**Compuerta F1** (`plan.md` §9): **4 de 5 personas completan el onboarding y guardan una idea sin ayuda.**

- *Completa el onboarding:* llega a Hoy desde la bienvenida (perfil, ideas semilla, hora y avisos, con cualquier respuesta).
- *Guarda una idea:* guarda al menos una neurona desde Capturar (+) fuera del onboarding. Las ideas semilla no cuentan para esto.
- *Sin ayuda:* durante esa tarea no hubo ninguna intervención del moderador más allá de leer la consigna. Si la persona pregunta y el moderador responde algo que la destraba ("probá el +", "está abajo"), cuenta como **con ayuda**. Repetir la consigna textual no cuenta como ayuda.
- Si no se cumple: no se avanza a construir el resto (regla de `plan-ejecucion.md`). Se corrigen los problemas de mayor severidad en el prototipo y se repite con 3 personas nuevas.

**Ícono** (propuesta de criterio, *a confirmar*): el ícono pasa si **al menos 3 de 5** lo describen, sin ayuda y en la primera mirada, como algo del orden de neurona, cerebro, conexión o idea, y **como mucho 1** lo lee como animal (estrella de mar, insecto, araña) u otro símbolo que confunda (virus, signo médico, "$"). Si no pasa, se revisa la forma en `design/system/identidad/generar.py` antes de publicar (plan.md §3, riesgo de lectura).

## Participantes

- 5 personas de la waitlist, que **no** hayan participado de las entrevistas de F0 ni hayan visto la marca. Mezcla: 2 devs o gente de producto, 2 creadores de contenido, 1 emprendedor o emprendedora. Reclutamiento y mensaje de invitación: reusar `docs/entrevistas/reclutamiento.md`.
- Al menos 2 con Android y 2 con iPhone. El prototipo se usa en la plataforma de su teléfono (selector arriba).
- Presencial o por videollamada con pantalla compartida. Si es remoto, la persona abre el link del prototipo en su compu y comparte la pantalla.

## Preparación (10 minutos antes)

1. Servir el prototipo: `python3 -m http.server 8765 -d design` y abrir `http://127.0.0.1:8765/prototipo/` (o el link publicado si ya está). Para remoto, publicarlo antes (por ejemplo, como artifact o en el hosting de la landing).
2. Elegir la plataforma de la persona y el tema **Gris**. Tocar **Empezar de cero**. Dejar **Reducir movimiento** como esté en su equipo.
3. Si la persona va a manejar el prototipo en su pantalla: **Ocultar panel** (el moderador sigue el registro en su copia o lo pide al final con "Copiar registro").
4. Tener abierta `test/icono.html` en otra pestaña, todavía sin mostrar.
5. Tener `resultados.csv` abierto en una planilla y un cronómetro.
6. Pedir permiso para grabar la pantalla y la voz. Sin grabación, tomar notas literales.

## Guion

### 1. Bienvenida (2 min)

> Gracias por venir. Vamos a probar una app que todavía no existe: lo que vas a ver es un prototipo, así que hay cosas que no funcionan del todo. No te estamos evaluando a vos, estamos evaluando el diseño: si algo no se entiende, es culpa del diseño. Te voy a pedir que pienses en voz alta, que digas lo que mirás, lo que esperás que pase y lo que te sorprende. Yo no te voy a poder ayudar mucho, porque quiero ver cómo te arreglarías solo o sola. ¿Te parece bien que grabe la pantalla y el audio? Solo lo vemos nosotros.

### 2. Ícono solo (5 min), antes de ver nada de la app

Abrir `icono.html`. No decir el nombre de la app ni de qué se trata.

1. **Pantalla de inicio, 5 segundos.** Mostrar la vista "Pantalla de inicio" (el ícono a tamaño real entre otros genéricos, sin nombre debajo). Contar 5 segundos y ocultar.
   > ¿Qué viste? ¿Te acordás de algún ícono en particular?
   (Anotar si menciona el de Lumbre espontáneamente y cómo lo describe.)
2. **El ícono grande.** Mostrar la vista "Solo".
   > ¿Qué ves en este dibujo? Describilo como se lo contarías a alguien por teléfono.
   > Si fuera el ícono de una app, ¿de qué sería esa app?
   > ¿Con qué palabra lo nombrarías?
3. **Chico.** Mostrar la vista "Chico" (29 y 40 pt, como en Ajustes o en Spotlight).
   > ¿Y acá? ¿Cambia lo que ves?
4. **Oscuro y tintado.** Mostrar la vista "Variantes".
   > ¿Alguna se ve rara o se lee distinto?
5. Recién ahora, una pista:
   > La app se llama Lumbre y sirve para guardar ideas y combinarlas. ¿Te cierra el dibujo con eso? ¿Qué le cambiarías?

No corregir ni explicar qué es (una neurona) hasta el final de la sesión.

### 3. Tareas en el prototipo (15 min)

Leer cada consigna tal cual. Arrancar el cronómetro al terminar de leerla y pararlo cuando se cumple el criterio de éxito o cuando la persona abandona. Si pasan **3 minutos** trabado o trabada, o pide ayuda dos veces, se ayuda, se anota "con ayuda" y se sigue.

Después de cada tarea: **"Del 1 al 7, ¿qué tan fácil o difícil fue?"** (1 = muy difícil, 7 = muy fácil). Anotar en la columna `SEQ`.

| # | Consigna (se lee en voz alta) | Éxito | Qué mirar |
|---|---|---|---|
| T1 | "Acabás de bajar esta app. Empezá a usarla como lo harías en tu teléfono, hasta que llegues a la pantalla principal." | Llega a Hoy (el registro marca `onboarding_completed`) | ¿Entiende la propuesta de la bienvenida? ¿Elige "Empezar" o "Crear cuenta o entrar", y por qué? ¿Cómo reacciona al consentimiento de IA? ¿Cuántas ideas semilla escribe y cuánto tarda? ¿Acepta los avisos? |
| T2 | "Pensá en algo que leíste, escuchaste o pensaste esta semana y que te quedó dando vueltas. Guardalo en la app." | Guarda una neurona desde Capturar (`neuron_saved`) | ¿Encuentra el +? ¿Entiende "neurona"? ¿Usa categoría? ¿Prueba Link o Voz? |
| T3 | "Ahora buscá eso que acabás de guardar y abrilo." | Abre su neurona en la Red (`neuron_opened`) | ¿Va a Red sin dudar? ¿Entiende que Red es donde están sus ideas? ¿Usa la búsqueda? |
| T4 | "La app dice que hoy tenés algo esperándote. Encontralo y fijate qué es." | Enciende la chispa (`spark_revealed`) | ¿Entiende qué es una chispa antes de encenderla? Después: "¿Qué te está diciendo esta pantalla?" |
| T5 | "Si esa idea te gustara, ¿cómo harías para no perderla?" | Guarda la chispa (`spark_saved`) | ¿Confunde "Guardar idea" con capturar? ¿Entiende Circuitos? |
| T6 | "Imaginá que querés más de lo que te da la app gratis. ¿Dónde te fijarías qué incluye la versión paga?" | Abre el paywall (`paywall_viewed`) | ¿Por dónde llega (Perfil, Planificar, Combinar, "Con Pro…")? ¿Se entiende qué incluye y el precio? Si entró como invitado e intenta comprar: ¿cómo toma la hoja "Esto es con cuenta"? |

T1 y T2 definen la compuerta. T3 a T6 son diagnóstico.

### 4. Preguntas finales (6 min)

1. Con tus palabras, ¿para qué sirve esta app?
2. ¿Qué es una "neurona" acá? ¿Y la "Red"? ¿Y un "Circuito"? (Anotar si lo dice bien, a medias o mal.)
3. ¿Qué es una "chispa"? ¿Te gustaría recibir una todas las mañanas? ¿A qué hora?
4. Entraste sin cuenta (o con cuenta): ¿por qué elegiste eso? ¿En qué momento te parecería razonable que te pidan crear una cuenta? ¿Cuándo te molestaría?
5. ¿Qué fue lo más confuso?
6. ¿Qué fue lo que más te gustó?
7. Del 0 al 10, ¿qué tan probable es que la uses si existiera? ¿Por qué ese número?
8. (Recién ahora, si no salió antes) El ícono es una neurona. ¿Lo habías visto así?

### 5. Cierre (1 min)

> Eso es todo, muchas gracias. Lo que nos dijiste nos ayuda un montón. Cuando la app esté lista, te avisamos primero.

Después de la sesión: tocar **Copiar registro** en el panel y pegarlo en la columna `registro` de la planilla. Completar la fila mientras está fresco (no más de 10 minutos).

## Qué anotar de cada problema

En `problemas` de la planilla, uno por línea con este formato: `pantalla · qué pasó · severidad`.

| Severidad | Cuándo |
|---|---|
| 3, bloqueante | Impide completar la tarea sin ayuda |
| 2, grave | La completa, pero con un desvío largo, un error o mucha duda |
| 1, menor | Duda breve, comentario negativo, algo cosmético |

## Síntesis (después de las 5)

1. Contar cuántas personas tienen `onboarding_sin_ayuda = sí` **y** `guardo_idea_sin_ayuda = sí`. Si son 4 o 5: compuerta F1 cumplida.
2. Ícono: contar `icono_lectura` = `neurona` (o equivalente: cerebro, conexión, idea) y las lecturas negativas. Aplicar el criterio de arriba.
3. Agrupar los problemas repetidos (2 o más personas) y ordenarlos por severidad.
4. Vocabulario: cuántas entendieron neurona, Red, Circuito y chispa.
5. Invitado: qué respondieron en la pregunta 4 y si alguna persona se frenó en la hoja de cuenta. Sirve para confirmar `prototipo/invitado.md`.
6. Dejar la síntesis como comentario en MAT-224 (prototipo) y MAT-210 (ícono), con la planilla adjunta.
