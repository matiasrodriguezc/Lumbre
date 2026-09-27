> ⚠️ Entrevista simulada con una persona sintética. Sirve para ensayar la guía; no es evidencia de mercado.

# 01 Lucas · Devs

- **País:** Argentina (Buenos Aires)
- **Edad:** 32
- **Teléfono:** iPhone (iOS)
- **Qué crea:** backend en una fintech; side project: CLI open source de finanzas personales (~300 estrellas en GitHub)
- **Herramientas:** Obsidian (Zettelkasten, ~2.000 notas), Readwise, Kindle, atajo de iOS para capturar, GitHub Issues
- **Paga hoy por:** Readwise, ~US$ 8/mes con tarjeta en dólares

---

## Transcripción

### 0. Apertura

**E:** Gracias por el tiempo, Lucas. Estoy investigando cómo la gente tiene y guarda ideas. No te voy a vender nada y no hay respuestas correctas. ¿Te molesta si lo grabo? Es solo para mis notas.

**Lucas:** No, dale, grabá. Igual te aviso que si esto termina en "mirá mi app", te corto, eh. *(se ríe)*

### 1. Contexto

**E:** ¿A qué te dedicás? ¿Qué cosas creás?

**Lucas:** Soy backend en una fintech, hace tres años. Go, algo de Python, mucho Postgres. Y por fuera tengo una CLI de finanzas personales, open source. Le cargás los movimientos del banco y te arma reportes en la terminal. Tiene como trescientas estrellas, que para algo que hice un fin de semana está bien. Algunos la usan de verdad, me abren issues.

**E:** ¿En qué estás trabajando ahora que te entusiasme?

**Lucas:** En la CLI, quiero que soporte cuotas. Acá todo es en cuotas y ningún tool de afuera lo entiende: compraste una heladera en doce cuotas y para el tool gastaste todo en un mes. Eso me tiene enganchado.

### 2. La última idea buena

**E:** Contame la última vez que tuviste una idea que terminaste usando.

**Lucas:** El importador de Mercado Pago. Fue en marzo, más o menos. Quise ver cuánto gastaba en PedidosYa y bajé el CSV de Mercado Pago y era un desastre: columnas en castellano, los montos con coma, las devoluciones como filas aparte. Me dio bronca y dije "esto lo tiene que leer la CLI".

**E:** ¿Dónde estabas cuando se te ocurrió?

**Lucas:** En casa, un domingo a la noche, con la notebook. Estaba justamente haciendo las cuentas. Me dio 180 lucas de PedidosYa en febrero, así que también me sirvió para cortar un poco. *(se ríe)*

**E:** ¿Qué hiciste con la idea en ese momento? ¿Dónde la anotaste?

**Lucas:** Abrí un issue en mi propio repo. Todo lo que es de la CLI va a issues, no a notas. Le pegué tres filas del CSV de ejemplo, sin datos míos, y listo.

**E:** ¿Y después? ¿Cuánto tardaste en hacer algo?

**Lucas:** Dos fines de semana. El primero lo hice andar, el segundo escribí tests porque me daba vergüenza mergear sin tests en un repo que alguien mira. Salió en la versión 0.9, creo que en abril.

**E:** ¿Y alguna idea que se te haya perdido?

**Lucas:** *(piensa)* No, la verdad que no. Tengo un atajo en el iPhone que me agrega una línea a la nota diaria de Obsidian. Lo toco desde la pantalla de bloqueo y en dos segundos está. Anoto todo. Hasta boludeces.

**E:** ¿Ninguna? ¿Ni una vez?

**Lucas:** Capaz alguna en la ducha, pero después me acuerdo. No te voy a inventar una historia de "perdí la idea del millón". No me pasa. Mi problema no es anotar, anotar anoto de más.

### 3. Guardar

**E:** ¿Cuándo fue la última vez que guardaste algo que leíste, escuchaste o viste?

**Lucas:** El jueves. Un artículo sobre contabilidad de doble entrada en texto plano, lo de ledger y hledger. Lo leí en el Reader de Readwise, subrayé como seis párrafos y eso se sincroniza solo a Obsidian, a una carpeta de fuentes.

**E:** ¿Me mostrás ese lugar?

**Lucas:** Sí, comparto. *(comparte pantalla)* Esta es la bóveda. Acá están las fuentes, lo que baja de Readwise. Acá las notas permanentes, las del Zettelkasten, con ID de fecha. Y estos son los MOC, los mapas de contenido. Ves el grafo… bueno, el grafo es más lindo que útil, pero queda bien.

**E:** ¿Cuánto hay ahí?

**Lucas:** Dos mil y pico de notas. Permanentes serán unas seiscientas. El resto son fuentes y diarias.

**E:** ¿Cuándo fue la última vez que volviste a mirarlo?

**Lucas:** El domingo pasado. Me pasé la tarde migrando tags a MOCs, porque tenía tags duplicados, "finanzas", "finanzas-personales", "fin"… Lo dejé impecable. Estuve como cuatro horas.

**E:** *(silencio)*

**Lucas:** Sí, ya sé lo que vas a preguntar.

**E:** ¿Qué ibas a decir?

**Lucas:** Que cuatro horas ordenando un domingo es mucho. Me gusta, eh. Es como ordenar el taller. Me relaja.

### 4. Volver y combinar

**E:** ¿Cuándo fue la última vez que buscaste algo que habías guardado para usarlo?

**Lucas:** Para usarlo… *(piensa)* Hace un par de semanas busqué una nota sobre redondeo con decimales, porque en la CLI tenía un bug con los centavos. La encontré en diez segundos, la búsqueda de Obsidian es muy buena. Pero la nota decía lo mismo que la primera respuesta de Stack Overflow, así que tampoco me salvó.

**E:** En el último año, ¿qué salió de esas notas? Algo que hiciste gracias a ellas.

**Lucas:** *(pausa larga)* Posta… casi nada. Me da un poco de vergüenza decirlo. Tengo todo el sistema armado, leí el libro de Ahrens dos veces, y si me preguntás qué salió de ahí en un año… un par de posts que al final no publiqué. La CLI no salió de ahí. Salió de que me dio bronca un CSV.

**E:** ¿Por qué creés que pasa eso?

**Lucas:** Porque ordenar me gusta más que escribir. Ordenar es seguro, no hay nada que pueda salir mal. Escribir algo nuevo es otra cosa. No sé, no lo tengo muy pensado, recién me cae.

**E:** ¿Alguna vez te salió una idea de juntar dos cosas que no tenían nada que ver?

**Lucas:** Se supone que el Zettelkasten es para eso, lo de Luhmann, las conexiones inesperadas. Pero en concreto… *(piensa)* Una vez pensé que había conectado idempotencia de pagos con hábitos, lo de "hacer una vez aunque lo intentes dos". Pero no salió nada de eso, quedó en una nota. No te puedo decir que me haya pasado de verdad.

**E:** Cuando necesitás una idea nueva, para un feature por ejemplo, ¿qué hacés concretamente?

**Lucas:** Miro los issues que me abre la gente. Lo de las cuotas me lo pidió un pibe de Córdoba. O me pasa algo a mí, como lo del CSV. O leo Hacker News y veo qué hacen otros. Las ideas me salen de problemas, no de mis notas.

### 5. Herramientas y plata

**E:** ¿Qué apps o métodos usás para esto? ¿Desde cuándo?

**Lucas:** Obsidian desde 2020, más o menos cuando empezó la pandemia. Readwise desde 2022. Antes, en la facu, Evernote.

**E:** ¿Probaste otras y las dejaste?

**Lucas:** Notion, y lo dejé porque era lento y mis cosas no eran mías, estaban en su base de datos. Quiero Markdown en mi disco, y si mañana cierra la empresa, mis notas siguen ahí. Logseq lo usé dos meses; me gustaba la idea de los bloques, pero se me rompía la sincronización con el iPhone. Roam lo miré y cuando vi el precio ni lo instalé.

**E:** ¿Pagás alguna suscripción de notas, lectura, productividad o IA?

**Lucas:** Readwise. Son unos ocho dólares por mes, con la tarjeta en dólares. Con los impuestos que te cobran acá termina siendo más, pero bueno.

**E:** ¿Por qué esa sí?

**Lucas:** Porque hace algo que yo no puedo hacer con un script de un fin de semana: saca los subrayados del Kindle, que Amazon no te deja sacar fácil, y me los deja en Markdown. Si lo pudiera hacer yo, no pagaría. Obsidian Sync, por ejemplo, no lo pago: sincronizo con git.

**E:** ¿Y de IA?

**Lucas:** No pago nada. En el laburo la empresa nos paga Cursor. Para lo mío uso la versión gratis de Claude o de ChatGPT, según cuál se me cuelgue menos ese día.

### 6. Hábitos

**E:** ¿Qué apps abrís todos los días porque te llega una notificación?

**Lucas:** Slack del laburo. Y nada más.

**E:** ¿Nada más?

**Lucas:** Tengo todo apagado. WhatsApp sin sonido y sin globitos, lo abro cuando quiero. Instagram lo borré del teléfono. Mail, apagado. Mercado Pago me mandaba promos todos los días, lo silencié en dos semanas. Slack no lo puedo apagar porque estoy de guardia una semana por mes.

**E:** ¿Usás IA para pensar ideas? ¿Para qué exactamente, la última vez?

**Lucas:** Para pensar ideas no. Para código sí: una regex, una query de Postgres, explicarme un error. La última vez fue ayer, un parser de fechas. Para ideas una vez le pedí a ChatGPT features para la CLI y me tiró una lista que podría ser de cualquier app de finanzas del mundo. "Agregá gráficos", "agregá presupuestos". Gracias, genio.

**E:** ¿Y para tus notas?

**Lucas:** No. Hay plugins de Obsidian que te resumen las notas con IA y lo probé una vez y lo desinstalé a los diez minutos. Me molesta mucho. El valor de la nota está en que yo la escribí con mis palabras. Si una IA me resume el artículo, tengo un resumen, no una nota mía. Es como que otro te haga los ejercicios de la facu.

### 7. El concepto

**E:** Te muestro una pantalla y te leo algo. *(comparte la pantalla Hoy)* "Es una app donde guardás lo que leés, escuchás o pensás. La IA lo convierte en conceptos cortos, y cada mañana choca dos conceptos tuyos de mundos distintos y te propone una idea nueva." ¿Qué entendés que hace?

**Lucas:** Que es un Readwise con un ChatGPT arriba que te manda una push a la mañana con una idea mezclando dos cosas que guardaste.

**E:** ¿Qué te gusta y qué te molesta?

**Lucas:** Te digo lo que me molesta primero, porque es más. "La IA lo convierte en conceptos cortos": eso es exactamente lo que no quiero, lo que te conté recién. Yo ya convierto las cosas en conceptos cortos, eso es mi Zettelkasten. Si me lo hace la IA, me saca la parte que me gusta. Segundo: "cada mañana" es una notificación. Te lo digo así: la silencio el primer día. Y tercero, que la idea me la proponga la IA. Si la idea sale de la máquina, no es mía. Voy a sentir que estoy haciendo un tutorial.

**E:** ¿Por qué?

**Lucas:** Porque para mí pensar es el laburo. No quiero que me den la idea, quiero que me den un empujón. *(pausa)* Lo que sí me gusta, y me jode un poco admitirlo, es que apunta a lo que te dije antes. Tengo dos mil notas y no hago nada con ellas. Si algo me obligara a usar lo que ya tengo, en vez de seguir juntando, eso sí me interesa. Pero no así.

**E:** ¿En qué momento de tu semana lo usarías, si lo usaras? ¿En lugar de qué?

**Lucas:** El domingo, en lugar de ponerme a ordenar tags cuatro horas. *(se ríe)* Eso capaz sí. Pero nunca a la mañana: a la mañana abro Slack y miro si se prendió fuego algo.

**E:** ¿Qué tendría que pasar para que no lo borres a la semana?

**Lucas:** Que lea mi bóveda de Obsidian, local, sin subir mis notas a ningún lado, o por lo menos que me diga claramente qué sube. Que no reescriba nada mío. Que no me mande notificaciones, o que las pueda apagar sin que la app deje de tener sentido. Y que en vez de darme "la idea", me muestre las dos notas mías juntas con una pregunta, y yo escribo. Si me muestra dos notas mías que no conecté nunca, eso me interesa. Si me muestra un texto de IA, no.

**E:** ¿Te sumo a la lista para probar la beta?

**Lucas:** Dale, anotame. Pero te soy honesto: lo voy a probar más por curiosidad de cómo lo hicieron que porque crea que lo voy a usar. Y si no es local, lo desinstalo.

**E:** ¿Conocés a dos personas a las que les pase esto? ¿Me las presentás?

**Lucas:** Conozco a varios con Obsidian, del laburo y de un Discord. Pero son como yo, van a odiar la parte de la IA más que yo. No te los voy a presentar para que te digan que no. Si algún día tenés algo local y sin push, te paso el Discord.

### 8. Cierre

**E:** ¿Algo que no te pregunté y debería haberte preguntado?

**Lucas:** Preguntale a la gente cuánto tiempo pasa ordenando y cuánto creando. A mí nadie me lo había preguntado y me cayó la ficha hoy. Eso capaz te sirve más que lo de la app.

**E:** Gracias, Lucas. Te aviso cuando haya algo para probar.

**Lucas:** De nada. Y no me mandes push, eh. *(se ríe)*

---

## Síntesis

### Hechos (lo que hizo, no lo que opina)
- La última idea que usó (importador de CSV de Mercado Pago para su CLI, marzo) salió de un problema propio: gastó "180 lucas de PedidosYa en febrero" y el CSV era inservible. La anotó como issue en GitHub y la implementó en dos fines de semana (v0.9, abril).
- Captura con un atajo de iOS a la nota diaria de Obsidian. No pudo contar ninguna idea perdida.
- El jueves pasado guardó subrayados de un artículo sobre ledger/hledger con Readwise Reader, que sincroniza a Obsidian.
- La bóveda tiene más de 2.000 notas (~600 permanentes). El domingo pasado pasó unas 4 horas migrando tags a MOCs.
- En el último año casi no salió nada de sus notas: "un par de posts que al final no publiqué".
- Las ideas de features le vienen de issues de usuarios, de problemas propios y de Hacker News.
- Paga Readwise (~US$ 8/mes). No paga Obsidian Sync (usa git) ni IA (usa versiones gratis; la empresa le paga Cursor).
- Solo tiene activas las notificaciones de Slack del trabajo (hace guardia). Silenció Mercado Pago en dos semanas y borró Instagram.
- Usa IA para código (ayer, un parser de fechas). La única vez que la usó para ideas le dio una lista genérica. Desinstaló a los 10 minutos un plugin de Obsidian que resumía con IA.

### Dolores (con sus palabras)
- "Tengo dos mil notas y no hago nada con ellas."
- "Ordenar me gusta más que escribir. Ordenar es seguro."
- "Si una IA me resume el artículo, tengo un resumen, no una nota mía."

### Hipótesis
| | Señal | Evidencia |
|---|---|---|
| H1 Fricción al guardar | ❌ | "Mi problema no es anotar, anotar anoto de más." No perdió ninguna idea; captura en dos segundos con un atajo. |
| H2 No vuelve a lo guardado | ✅ | Vuelve a la bóveda seguido, pero para ordenarla, no para usarla. Del último año: "casi nada". |
| H3 Combinar le sirvió | ❌ | No pudo contar un caso real. "Las ideas me salen de problemas, no de mis notas." |
| H4 Acepta una push diaria | ❌ | Todo apagado salvo Slack del trabajo. Sobre el concepto: "la silencio el primer día". |
| H5 Acepta ideas de IA | ❌ | Usa IA solo para código. "Si la idea sale de la máquina, no es mía." Rechaza que la IA resuma. |
| H6 Pagaría | ✅ (débil) | Paga Readwise, pero solo por lo que "no puedo hacer con un script de un fin de semana". No paga sync ni IA. |

### Reacción al concepto
- **Qué entendió:** "un Readwise con un ChatGPT arriba que te manda una push a la mañana".
- **Qué le gustó:** que apunte a usar lo que ya guardó en vez de seguir juntando. Ver dos notas suyas que nunca conectó.
- **Qué le molestó:** que la IA convierta en conceptos (le saca "la parte que me gusta"), la push diaria, que la idea la proponga la IA, no saber si sus notas salen de su disco.
- **En lugar de qué lo usaría:** del domingo ordenando tags. Nunca a la mañana.
- **Condiciones para no borrarlo:** que lea la bóveda de Obsidian en local, que no reescriba nada suyo, que no mande push y que muestre dos notas suyas con una pregunta en vez de un texto generado.

### Compromiso
- [x] Se sumó a la beta (email: anotado). Por curiosidad técnica: "más por curiosidad de cómo lo hicieron que porque crea que lo voy a usar".
- [ ] Presentó a otras personas (cuántas: 0). Ofreció un Discord de usuarios de Obsidian solo si el producto es local y sin push.

### Lo que me sorprendió
- El dolor no fue perder ideas ni no encontrarlas, sino que ordenar reemplaza a crear, y le dio vergüenza reconocerlo. Lo único que le interesó del concepto fue justo eso, y lo que propone la app (que la IA procese y proponga) es lo que más rechaza. Sugirió preguntar en las próximas entrevistas cuánto tiempo pasa cada uno ordenando y cuánto creando.
