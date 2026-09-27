> ⚠️ Síntesis de 12 entrevistas **simuladas** con personas sintéticas. Sirve para ensayar la guía y ordenar qué preguntar en las entrevistas reales. **No es evidencia de mercado y no cuenta para la compuerta de F0.**

# Síntesis de la ronda simulada · 27/9/2026

## Cómo se hizo y dónde está el sesgo

- Armé 12 personas (4 devs, 4 creadores, 4 emprendedores), cada una con "rasgos ocultos". Cada entrevista la escribió un agente distinto, que solo vio la guía y su persona, sin `plan.md` ni el pitch.
- **Varios rasgos los puse yo pensando en los riesgos del plan:** "me sobran ideas" (Sofía, Agustina, Florencia, Andrés), rechazo a la IA (Lucas, Javier, Valeria, Camila, Tomás) y notificaciones apagadas (Lucas, Javier, Florencia). Que esos dolores aparezcan no prueba nada: los sembré. Muestran que la guía los detecta, y ese era el objetivo.
- Lo que vale mirar es lo que **surgió sin que yo lo pusiera** (sección 4), y aun así es una hipótesis.

## 1. Matriz de hipótesis

| # | Persona | Segmento | H1 Fricción | H2 No vuelve | H3 Combinar | H4 Push diaria | H5 IA | H6 Paga | Beta | Presentó |
|---|---|---|---|---|---|---|---|---|---|---|
| 01 | Lucas | Devs | ❌ | ✅ | ❌ | ❌ | ❌ | ✅ débil | sí, curiosidad | 0 |
| 02 | Sofía | Devs | ❌ | — | ❌ | ✅ débil | ❌ | ✅ | sí, curiosidad | 0 |
| 03 | Nahuel | Devs | ❌ | ✅ | — | ✅ | ✅ | ❌ | sí, si es gratis | 0 |
| 04 | Javier | Devs | ❌ | — | ✅ | ❌ | ❌ | ✅ débil | sí, curiosidad | 0 |
| 05 | Valeria | Creadores | ❌ | ✅ | ✅ | — | ❌ | ✅ | sí | 0 |
| 06 | Camila | Creadores | ✅ débil | ✅ | ✅ | ❌ | ❌ | — | no | 0 |
| 07 | Agustina | Creadores | ❌ | ✅ | — | ✅ | — | — | sí, "pruebo todo" | 0 |
| 08 | Tomás | Creadores | ❌ | ✅ | ✅ | ❌ | ✅ | ❌ | sí, sin push | 0 |
| 09 | Florencia | Emprendedores | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | no | 0 |
| 10 | Diego | Emprendedores | — | ✅ | ❌ | ❌ | ✅ | ✅ (la empresa) | sí, si conecta Notion | 1 |
| 11 | Rocío | Emprendedores | ❌ | ✅ | ✅ | — | ✅ | — | sí, "abandono todo" | 1 |
| 12 | Andrés | Emprendedores | ❌ | ✅ | ❌ | ✅ | ✅ | ✅ dudoso | sí, entusiasta serial | 0 |
| | **✅** | | **1** | **10** | **5** | **4** | **5** | **6** | **10** | **2** |

Lectura rápida:
- **H1 cae:** a casi nadie le cuesta guardar. Anotan en segundos (WhatsApp, capturas, Keep, guardados de Instagram).
- **H2 es lo más fuerte:** 10 de 12 tienen un "cementerio" de cosas guardadas a las que no vuelven.
- **H3 y H5 quedan divididas**, y **H4 sale mal** (6 en contra): la push diaria es la apuesta más frágil del loop.
- **La beta no mide nada:** 10 de 12 dijeron que sí, casi todos "por curiosidad" o con condiciones. Solo 2 presentaron a alguien. Esa sí es la señal que vale, y es baja.

## 2. Dolores repetidos (4+ entrevistas y 2+ segmentos)

| Dolor | Entrevistas | Segmentos | Cita | ¿Lo sembré? |
|---|---|---|---|---|
| **Guardo todo y no vuelvo nunca** | 01, 03, 05, 06, 07, 08, 09, 10, 11, 12 | 3 | "Es como un cementerio bonito. Todo muy ordenadito y nadie lo visita." (Valeria) | En parte (3 de 10) |
| **Me sobran ideas; me cuesta elegir y ejecutar** | 02, 05, 07, 09, 10, 12 | 3 | "Me sobran ideas. Me falta vida." (Sofía) | Sí (4 de 6) |
| **Las ideas de la IA son genéricas o no son mías** | 01, 04, 05, 06, 07, 08 | 2 | "Todo el mundo le pide ideas a la misma máquina y todos terminamos haciendo el mismo video." (Valeria) | Sí (5 de 6) |
| **No quiero una app que me pida cosas todos los días** | 01, 02, 04, 05, 06, 08, 09, 11 | 3 | "Si me manda notificaciones en la mañana, lo borro." (Tomás) | En parte (3 de 8) |
| **Si no sé la palabra exacta, no lo encuentro** | 03, 07, 08, 12 | 3 | "Si sé la palabra, lo encuentro. Si no, no existe." (Nahuel) | No |

## 3. Qué pone en duda del plan

Son preguntas para las entrevistas reales y el prototipo, no decisiones.

| Supuesto de `plan.md` | Qué sugiere la ronda simulada | Cómo testearlo |
|---|---|---|
| El valor es "generar ideas nuevas" | El dolor más repetido es **usar lo que ya guardé**, no tener más ideas | Probar dos pitches en la sección 7: "ideas nuevas" contra "hacé algo con lo que ya guardaste" |
| La chispa llega **todos los días** con push | Varias personas quieren otra cadencia: semanal (Rocío, el lunes), a pedido cuando entra un encargo (Tomás) o en un widget sin interrupción (Sofía) | Preguntar cuándo necesitan una idea; en el prototipo, dejar elegir diaria, semanal o a pedido |
| La IA escribe la idea terminada | Tres personas, cada una por su lado, pidieron ver **dos fragmentos suyos tal cual** con una pregunta, sin idea generada | Mostrar las dos variantes de tarjeta en la sección 7 |
| Guardar tiene que ser muy fácil (Share Extension, OCR, voz) | Guardar ya es fácil; lo que falla es **encontrar y usar** | Mantener la captura, pero invertir más en búsqueda y en traer lo que ya tienen |
| Importar notas es de la 1.1 | Seis personas tienen su cementerio en otra app (Keep, Notion, Readwise, Evernote, Obsidian, audios de WhatsApp) y no quieren migrar a mano | Preguntar dónde está su cementerio y si lo conectarían |
| El modo problema es de la 1.1 | Tomás quiere cruzar **un encargo concreto** con lo que ya guardó | Preguntar por la última vez que necesitaron una idea con plazo |

## 4. Lo que surgió sin que lo sembrara

- **"Mostrame dos cosas mías tal cual."** Lucas, Javier y Valeria lo propusieron cada uno por su cuenta. Javier lo comparó con las Oblique Strategies. La colisión les interesa; que la IA la resuelva, no.
- **Readwise ya probó algo parecido.** Valeria apagó el repaso diario de Readwise porque le mandaba frases sueltas al azar. Antes de fijar la push diaria, conviene estudiar cómo usa la gente real ese repaso.
- **Las ideas que se descartan son otro cementerio.** Tomás: de las tres rutas que presenta por brief, dos quedan enterradas en el Doc, y una vez rescataron una y la vendieron a otro cliente.
- **Transcribir antes que combinar.** Camila valora leer sus 300 audios transcriptos, no que se los combinen.
- **Pesa la moneda, no el monto.** Nahuel paga Spotify en pesos sin pensarlo y dejó ChatGPT Plus por costar USD 20. Confirma los precios regionales.
- **Canal preferido.** Florencia solo lo usaría si le llegara por WhatsApp.

## 5. Cambios a la guía

Aplicados en `../guia.md` (versión 2):
1. **Sección 2:** preguntar de dónde salieron sus últimas 3 ideas usadas, para clasificar el origen (conversaciones, clientes, lecturas, combinación) en vez de preguntar por la combinación directamente.
2. **Sección 3:** preguntar dónde está su "cementerio" y si lo conectaría a otra app.
3. **Sección 4:** preguntar cuánto tiempo pasa ordenando y cuánto creando (sugerido por la entrevista de Lucas).
4. **Nueva pregunta de cadencia:** "¿Cuándo necesitás una idea nueva? ¿Todos los días, cuando entra un encargo, una vez por semana?"
5. **Sección 6:** preguntar por funciones de "repaso diario" que haya apagado (Readwise, recuerdos de Google Fotos) y por qué.
6. **Sección 7:** mostrar dos tarjetas (idea generada por la IA contra dos fragmentos tuyos con una pregunta) y dos pitches, y preguntar cuál prefiere y por qué.
7. **Compromiso más fuerte:** sumarse a la beta es gratis y todos dicen que sí. Se reemplaza por pedidos que cuestan algo: presentar a alguien durante la llamada, o mandar ahora 10 cosas que tenga guardadas para armar su primera chispa a mano.

## 6. Qué no cambia

- La compuerta de F0 sigue pidiendo **3 dolores repetidos en 12 entrevistas reales**. MAT-212 sigue abierto.
- Ninguna decisión de `plan.md` cambia por esta ronda.
