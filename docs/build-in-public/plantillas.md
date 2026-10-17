# Plantillas de post por red

Para el calendario de `calendario.md`. Lo que va entre corchetes se reemplaza. `[link]` es la landing con UTM de la red.

Voz (de `design/system/README.md`): voseo, directo y cálido, sentence case, sin emoji decorativos, "IA" lo menos posible. Neurona, Red, Circuitos y chispa son las palabras de la casa; "sinapsis", "axón" o "dendrita", no.

---

## X

### Chispa del día (todos los días hábiles)

Post con la imagen de la plantilla visual (formato X, 1600×900):

```
Chispa del día #[n]: [A] × [B]

[Neurona 1, una línea]
[Neurona 2, una línea]

→ [Título de la chispa]. [La chispa en una o dos oraciones.]
```

Respuesta propia, en el mismo hilo (solo los lunes y viernes, para no cansar):

```
Las armo así: dos ideas de mundos distintos y un principio que pasa de uno al otro. Estoy haciendo una app que te las arma con tus propias notas, cada mañana. Fila: [link]
```

Ejemplo, con la chispa 1:

```
Chispa del día #1: Onda verde × code review

Los semáforos coordinados dejan pasar una columna de autos sin frenar.
Un PR pasa más tiempo esperando revisión que siendo revisado.

→ Revisiones en onda verde. Ventanas fijas de revisión escalonadas en el día, para que un PR encuentre a alguien en verde cada dos horas. Lo que acelera no es revisar rápido: es no frenar.
```

### A. Hilo de presentación (semana 1, lunes)

```
1/ Voy a construir en público Lumbre, una app para tener ideas (no para guardarlas).

2/ El problema: guardamos cientos de notas, links y capturas. Casi nunca volvemos a leerlas, y menos a cruzarlas.

3/ El método: las ideas nuevas casi siempre son dos viejas que se cruzan. Se llama idea stacking.

4/ Cómo funciona: guardás lo que te inspira, Lumbre lo destila en una idea de una línea y cada mañana conecta dos de mundos distintos. Salta una chispa.

5/ Ejemplo de hoy: [chispa 1 en dos líneas]

6/ Voy a publicar una chispa por día y todo lo que pase: diseño, código, números y errores. Si querés probarla primero: [link]
```

### B. Post de proceso (lunes, miércoles y viernes a las 18)

```
[Qué hice hoy, en una línea concreta.]

[Por qué así y no de otra forma: la decisión y la alternativa descartada.]

[Una captura o un número.]

[Pregunta abierta para que respondan.]
```

Ejemplo:

```
Hoy decidí que la app no te muestre las ideas más parecidas entre sí, ni las más lejanas.

Las más parecidas dan obviedades ("café × té"). Las más lejanas, disparates. Las buenas están en la banda del medio, y esa banda es distinta para cada persona.

[captura del simulador]

¿Cuál fue la última idea que tuviste juntando dos cosas que no tenían nada que ver?
```

### C. Números de la semana (viernes)

```
Semana [n] de construir Lumbre en público:

· Fila: [total] personas (+[nuevas])
· Demo: [n] chispas generadas
· Lo que más funcionó: [post o chispa]
· Lo que no: [algo concreto]
· La semana que viene: [una cosa]

[link]
```

---

## LinkedIn

### L1. Post de origen (semana 1)

```
Tengo [n] notas guardadas en el teléfono. Volví a leer, como mucho, diez.

No me falta información. Me falta que se cruce.

Las ideas que más me sirvieron nunca salieron de una nota sola. Salieron de juntar dos que no tenían nada que ver: un artículo de urbanismo con un problema del trabajo, una receta con una forma de escribir.

Por eso estoy construyendo Lumbre: guardás lo que te inspira, cada idea queda destilada en una línea y cada mañana dos de mundos distintos se conectan. Lo que sale es la chispa del día.

Voy a contar todo el proceso acá. Si te interesa probarla antes: [link]

¿Dónde guardás vos las ideas que después no volvés a mirar?
```

### L2. Explicación del método (y cualquier post de proceso)

Estructura:
1. Primera línea que funcione sola (se corta en "ver más"): una observación concreta, no una frase hecha.
2. Dos o tres párrafos cortos con la historia o el razonamiento.
3. Un ejemplo real (una chispa).
4. Qué aprendí o qué decidí.
5. Pregunta al final. El link, en el primer comentario, no en el post.

### Mejor chispa de la semana (viernes)

```
La chispa de la semana: [A] × [B]

[Neurona 1]
[Neurona 2]

[Título]. [La chispa en dos oraciones.]

¿La probarías? ¿Con qué otra idea la cruzarías vos?
```

Con la imagen en formato feed (1080×1350).

---

## TikTok y Reels

Formato vertical 1080×1920, 20 a 40 segundos, subtítulos quemados siempre (la mitad lo ve sin sonido). Primeros 2 segundos: la frase gancho en pantalla.

### Guion 1. "Las ideas nuevas son dos viejas que se cruzan" (30 s)

| Tiempo | Imagen | Voz / texto en pantalla |
|---|---|---|
| 0–2 s | Cara a cámara | "Casi ninguna idea es nueva." |
| 2–8 s | Dos tarjetas en pantalla: "Semáforos en onda verde" y "Code review" | "Las buenas son dos ideas viejas de mundos distintos que se cruzan." |
| 8–20 s | Las tarjetas se acercan; aparece la chispa | "Los semáforos coordinados no te hacen frenar. ¿Y si los PR tampoco frenaran? Revisiones escalonadas: alguien en verde cada dos horas." |
| 20–27 s | Simulador con la app | "Estoy haciendo una app que hace esto con tus notas, cada mañana." |
| 27–30 s | Placa final con el wordmark | "Lumbre. Link en el perfil." |

### Guion 2. Chispa del día (20–25 s, se repite con cada chispa)

| Tiempo | Imagen | Texto |
|---|---|---|
| 0–2 s | Placa: "Chispa del día #[n]" | "[A] × [B]" |
| 2–8 s | Primera neurona | [Neurona 1] |
| 8–14 s | Segunda neurona | [Neurona 2] |
| 14–22 s | La chispa con el destello | "[Título]: [chispa en una oración]" |
| 22–25 s | Placa final | "¿Cuál cruzarías vos? Mañana, otra." |

Las placas salen de `plantilla-visual.html` en formato historia. Música: un loop suave sin letra de la biblioteca de la red.

### Guion 3. "Le pedí ideas a mis notas viejas" (35 s)

| Tiempo | Imagen | Voz |
|---|---|---|
| 0–2 s | Scroll rápido por cientos de notas | "Tengo 400 notas que nunca leí." |
| 2–10 s | Elegir dos al azar | "Agarré dos al azar: una de [tema] y otra de [tema]." |
| 10–25 s | Escribir la conexión en papel | "[Cómo se cruzan, en voz alta, sin cortar]." |
| 25–35 s | Cara a cámara | "Eso es lo que hace Lumbre todas las mañanas, solo. Estoy construyéndola en público." |

### Guion 4. El momento chispa (25 s)

| Tiempo | Imagen | Voz |
|---|---|---|
| 0–3 s | El reveal a velocidad real | "Diseñé el momento en que dos ideas se tocan." |
| 3–15 s | El mismo reveal en cámara lenta | "Las dos neuronas entran, estiran la punta, cruza un impulso y a los 650 milisegundos se enciende la chispa, con una vibración." |
| 15–25 s | Pantalla de Hoy | "Es la única animación de la app. Todo lo demás es quieto." |

### Guion 5. Probá la demo (25 s)

| Tiempo | Imagen | Voz |
|---|---|---|
| 0–2 s | Pantalla de la demo web | "Pegá dos ideas y mirá qué sale." |
| 2–18 s | Grabación de pantalla: pegar dos ideas de comentarios de seguidores | "Me pasaron [idea A] y [idea B]. Sale esto: [chispa]." |
| 18–25 s | Cara a cámara | "Probala con las tuyas. Link en el perfil." |
