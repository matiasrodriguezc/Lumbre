# Posts para comunidades

Paso 68 (MAT-301). Un post por comunidad, adaptado a sus reglas. Regla general: contar la historia y lo aprendido, no vender; responder todo; nunca pedir votos. Antes de publicar, leer las reglas vigentes de cada lugar (algunas exigen karma o antigüedad, o un día fijo para autopromoción).

## Indie Hackers (en)

Sección: Product launches o un post en el foro principal. Lo que funciona ahí: números y decisiones.

**Título:** I built an app that turns two of your old notes into a new idea every morning. Here's what I learned about pairing ideas.

```
I'm a solo developer from Argentina working ~20 hours a week on Lumbre, an iPhone app for idea stacking: you save what inspires you, and every morning it connects two of your saved ideas from different domains into a "spark", a concrete new idea.

A few things I learned building it that might be useful to others:

1. Similarity is the wrong target. Pairing the most similar notes gives you "coffee × tea". Pairing the most distant ones gives you nonsense. What works is a middle band of distance relative to each user's own notes, and it moves with feedback ("obvious" pushes it out, "irrelevant" pulls it in).

2. Pairing is SQL, not AI. Embeddings in pgvector, a percentile band per user, pairs that never repeat and a 3-day rest per idea. The AI only writes the spark at the end. That keeps a daily spark at around [costo real] per user.

3. Distilling first matters more than the model. Each saved thing becomes one line with the underlying principle before it's embedded. Matching on principles instead of words is what makes "traffic lights × code review" possible.

4. Free has to be genuinely useful. Capture is unlimited and you get a spark a day. Pro (US$ 6.99/month or US$ 49.99/year) adds automatic distillation, more sparks and a planner.

Numbers so far: [waitlist], [beta D7], [descargas de la primera semana].

Stack: SwiftUI, Supabase (Postgres + pgvector + Edge Functions), Claude Haiku for distilling and sparks, RevenueCat.

It's live on the App Store: [link]. I'd love feedback on the onboarding, and happy to answer anything about the pairing logic or the costs.
```

## r/SideProject (en)

Reglas: el post tiene que aportar algo más que el link. Responder en los comentarios durante el día.

**Título:** I made an app that picks two of your saved notes from different worlds and turns them into a new idea every morning

```
Like a lot of people, I have hundreds of saved articles, screenshots and notes I never look at again. But my best ideas always came from two unrelated things colliding, so I built Lumbre to do that on purpose.

How it works:
- Save anything from any app (share sheet, voice, screenshots, book pages)
- It distills each one into a single line with the principle behind it
- Every morning, two of them from different domains connect into a "spark"

Example from my own notes: "Traffic lights in a green wave" × "Pull requests waiting for review" → staggered review windows so a PR never stops at a red light.

The hard part was making sparks neither obvious nor random. It pairs notes in a middle distance band that adapts to you when you tap "Not useful".

Free with a daily spark; iPhone only for now. Spanish and English.

[link]

Would love brutal feedback on the first five minutes.
```

## Comunidades dev de LATAM (es)

Dónde (verificar que sigan activas y sus reglas de autopromoción): Discord y Slack de comunidades como Midudev, Programadores Argentina / Argentina Programa, Platzi, Coderhouse, comunidades de iOS en español, r/argentina_dev o r/programacion, y grupos de indie hackers hispanos en X.

**Post largo (foros, Discord con canal de proyectos):**

```
Hola, soy [nombre], dev de [ciudad]. Hace unos meses empecé un proyecto propio y hoy salió en el App Store: Lumbre, una app para tener ideas.

La idea es simple: guardás lo que te inspira (un link, una frase, una captura, una nota de voz) y cada mañana la app conecta dos de tus ideas de mundos distintos y te da una chispa, una idea nueva y concreta.

Lo técnico, por si a alguien le sirve:
- SwiftUI con Liquid Glass, Supabase (Postgres + pgvector + Edge Functions)
- El emparejamiento es SQL puro: embeddings, una banda de distancia por usuario y pares que no se repiten. La IA (Claude) solo escribe la chispa al final, así cada chispa cuesta [costo].
- Todo en español primero, con voseo.

La hice sola/o, unas 20 horas por semana. Es gratis con una chispa por día.

Link: [link]

Me sirve mucho cualquier comentario, sobre todo de los primeros 5 minutos. Y si me dejan dos ideas acá abajo, les respondo con la chispa que sale.
```

**Versión corta (canales de "mostrá tu proyecto"):**

```
Lancé Lumbre en el App Store: guardás ideas desde cualquier app y cada mañana dos de mundos distintos se cruzan y te dan una idea nueva. SwiftUI + Supabase + pgvector, hecha en Argentina. Gratis. Feedback bienvenido: [link]
```

## Newsletters de creadores (es y en)

Mensaje para proponer una mención (no pagada) a newsletters de productividad, creatividad o herramientas:

```
Hola [nombre], leo [newsletter] desde [cuándo / qué edición me gustó].

Lancé Lumbre, una app de iPhone que cruza dos ideas que guardaste y te da una idea nueva cada mañana (idea stacking, pero automático). Creo que le puede servir a tu audiencia porque [razón concreta según el newsletter].

Si te interesa probarla, te paso un código de un año de Pro. Sin compromiso de mencionarla.

[nombre] · [link]
```
