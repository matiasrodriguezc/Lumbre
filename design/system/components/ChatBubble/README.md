# ChatBubble
Burbujas del planificador Pro, con respuestas rápidas.

- El consumidor provee: rol (usuario / planificador), texto (Markdown liviano), y opcionalmente acciones rápidas debajo del último mensaje del planificador.
- El planificador se identifica con su nombre en `pro-text` y la palabra Pro: es una función Pro.
- Con el método de los tres cuartos de Disney, arriba del chat va el indicador de cuartos (Soñador, Realista, Crítico, Plan) colgado de un axón, con el cuarto actual como neurona encendida, y las respuestas rápidas cambian por cuarto: "Más grande todavía", "Pasemos al Realista", "No sé cuánta plata", "Pasemos al Crítico", "Pasemos a la síntesis".
- Después de la síntesis (o sin el método): "Armá un backlog de 5 tareas", "Hacé de abogado del diablo", "¿Qué stack usarías?".
- Las respuestas traen una marca `[[room:…]]` en la primera línea; la app nunca la muestra.
- Streaming token a token; el usuario puede frenar la respuesta.
