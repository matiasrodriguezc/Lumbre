# Encuesta de los 7 días

Para H8 (MAT-274). Se manda por email el día 7 desde el alta de cada persona (no el mismo día para todos). 3 minutos, 10 preguntas. Herramienta: cualquiera que no pida cuenta para responder (Tally, Google Forms). **No pedir el email adentro de la encuesta:** se manda con un parámetro `?t=[id de la waitlist]` en el link para cruzarla con la fila, nunca con el email ni con el id de usuario de la app.

Objetivo: saber si el loop funciona (¿la chispa sirve?, ¿vuelven?) y qué frena. Las preguntas 1, 3 y 5 son las que se miran primero.

## Email

**Asunto:** Una semana con Lumbre: 3 minutos

```
Hola,

Hace una semana que tenés Lumbre. ¿Me contás cómo te fue? Son 10 preguntas, 3 minutos:

[LINK DE LA ENCUESTA]

Lo que digas cambia qué hago la semana que viene. Si la dejaste de usar, me sirve todavía más saber por qué.

[Tu nombre]
```

## Preguntas (es)

1. **¿Qué tan decepcionado/a estarías si mañana no pudieras usar más Lumbre?**
   Muy decepcionado/a · Algo decepcionado/a · Nada decepcionado/a · Ya no la uso
   *(Prueba de Sean Ellis: si "Muy" pasa el 40%, hay algo.)*
2. **¿Cuántos días de esta semana abriste la chispa del día?**
   0 · 1–2 · 3–4 · 5–6 · Los 7
3. **Pensá en la mejor chispa que te tocó. ¿Qué hiciste con ella?**
   Nada · La guardé · La pensé un rato · La compartí · Empecé a hacer algo con ella
4. **En general, las chispas fueron…** (una por fila, de 1 a 5)
   Sorprendentes · Útiles · Fáciles de entender
5. **¿Qué casi te hace dejar de usarla?** (abierta)
6. **¿Desde dónde guardaste ideas?** (varias)
   Desde Lumbre · Compartir desde otra app · Captura de pantalla o escaneo · Dictado por voz · No guardé ninguna
7. **La hora de la chispa, ¿te quedó bien?**
   Sí · Me llega temprano · Me llega tarde · No me llegan las notificaciones · Las apagué
8. **Si Lumbre Pro costara [precio regional por mes], ¿lo pagarías?**
   Sí, ya · Probablemente · Probablemente no · No · Depende de… (abierta)
9. **¿Qué es lo único que cambiarías?** (abierta)
10. **¿Charlamos 15 minutos por videollamada?** Sí (te escribo para coordinar) · No, gracias

## Preguntas (en)

1. **How would you feel if you could no longer use Lumbre tomorrow?** Very disappointed · Somewhat disappointed · Not disappointed · I already stopped using it
2. **How many days this week did you open the daily spark?** 0 · 1–2 · 3–4 · 5–6 · All 7
3. **Think about the best spark you got. What did you do with it?** Nothing · Saved it · Thought about it for a while · Shared it · Started doing something with it
4. **Overall, the sparks were…** (1 to 5 each) Surprising · Useful · Easy to understand
5. **What almost made you stop using it?** (open)
6. **Where did you save ideas from?** (multiple) Inside Lumbre · Share from another app · Screenshot or scan · Voice dictation · I didn't save any
7. **Did the spark time work for you?** Yes · Too early · Too late · Notifications don't arrive · I turned them off
8. **If Lumbre Pro cost [regional monthly price], would you pay for it?** Yes, now · Probably · Probably not · No · It depends on… (open)
9. **What's the one thing you'd change?** (open)
10. **Up for a 15-minute video call?** Yes (I'll write to schedule) · No, thanks

## Cómo leerla

| Señal | Bien | Preocupante |
|---|---|---|
| P1 "Muy decepcionado/a" | ≥ 40% | < 20% |
| P2 5 días o más | ≥ 30% | < 15% (coincide con D7 < 10%) |
| P3 "Empecé a hacer algo" + "La compartí" | ≥ 20% | < 5%: las chispas no bajan a la acción |
| P4 Útiles (promedio) | ≥ 3,5 (mismo umbral que el set de evaluación) | < 3 |
| P6 "No guardé ninguna" | < 10% | > 25%: la captura tiene fricción |
| P7 "No me llegan" | 0 | Cualquier respuesta: bug de push |

Las respuestas abiertas se agrupan a mano en la plantilla de síntesis de `docs/entrevistas/plantilla-sintesis.md` (mismo formato: dolor, frecuencia, cita).
