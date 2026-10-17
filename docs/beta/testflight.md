# Notas de TestFlight

Para cargar en App Store Connect › TestFlight (H8, MAT-273). Los campos de "Test Information" se cargan una vez; "What to Test" va con cada build.

## Test Information

| Campo | Valor |
|---|---|
| Beta App Description | (abajo) |
| Feedback Email | beta@[DOMINIO] |
| Marketing URL | `https://[DOMINIO]` |
| Privacy Policy URL | `https://[DOMINIO]/privacidad` |
| Beta App Review: cuenta de acceso | No hace falta: se entra como invitado. Para probar Pro, la cuenta demo de `docs/lanzamiento/revision-app-store.md` |
| Notas para la revisión de la beta | Las mismas notas para el revisor, en versión corta (abajo) |

**Beta App Description (es):**

```
Lumbre es una app para tener ideas. Guardás lo que te inspira y cada mañana dos de tus ideas de mundos distintos se conectan y salta una chispa. Esta es una beta: puede haber errores, y tus comentarios deciden qué se arregla primero.
```

**Beta App Description (en):**

```
Lumbre is an app for having ideas. You save what inspires you and every morning two of your ideas from different worlds connect and a spark lights up. This is a beta: there may be bugs, and your feedback decides what gets fixed first.
```

**Notas para Beta App Review (en):**

```
Lumbre saves the user's ideas, condenses them with Claude (Anthropic) and pairs two of them daily into a new idea. No login is required: tap "Empezar" (Start) and continue as a guest. AI features ask for explicit consent first. During the beta all testers have Pro unlocked; no purchases are made in TestFlight.
```

## What to Test (build 1 de la beta externa)

**es:**

```
Gracias por probar Lumbre. Lo que más nos sirve esta semana:

1. El primer minuto: ¿se entiende qué hace la app antes de guardar nada?
2. Guardar ideas desde otras apps: compartí un link o un texto desde Safari, Instagram o Notas con el botón Compartir › Lumbre.
3. La chispa de cada mañana: ¿te llegó la notificación a la hora que elegiste? ¿La chispa te sirvió, fue obvia o no tuvo sentido? Si no te sirve, tocá "No me sirve" y elegí el motivo: es lo que ajusta las próximas.
4. El planificador: llevá una chispa a un plan y contanos si terminó en algo que harías.

Para reportar algo: sacá una captura de pantalla y TestFlight te ofrece mandarla con un comentario. Contá qué esperabas que pasara.

Lo que todavía no está: Android, widget de pantalla de inicio [ajustar según el build].
```

**en:**

```
Thanks for testing Lumbre. What helps us most this week:

1. The first minute: is it clear what the app does before you save anything?
2. Saving ideas from other apps: share a link or text from Safari, Instagram or Notes with Share › Lumbre.
3. The morning spark: did the notification arrive at the time you chose? Was the spark useful, obvious or nonsense? If it's not useful, tap "Not useful" and pick the reason: that tunes the next ones.
4. The planner: take a spark to a plan and tell us if it ended in something you'd actually do.

To report something: take a screenshot and TestFlight will offer to send it with a comment. Tell us what you expected to happen.

Not there yet: Android, home screen widget [adjust to the build].
```

## Builds siguientes

Plantilla corta para cada build nuevo:

```
Novedades de este build:
· [Cambio 1, en una línea, contado desde lo que nota la persona]
· [Cambio 2]
Arreglado: [lo que reportaron, agradeciendo si alguien lo mandó]
Esta semana mirá especialmente: [una cosa]
```

## Grupos

| Grupo | Quiénes | Cómo |
|---|---|---|
| Interno | Vos (y quien sume) | Sin revisión de Apple; cada build al instante (H7) |
| Beta externa · Tanda 1 | 30 de la waitlist | Link público con límite 30 |
| Beta externa · Tandas 2 y 3 | Hasta 100 en total | Subir el límite del link |

La propiedad de persona `is_internal = true` va solo para el grupo interno, así no ensucia el tablero de D1/D7 (`tablero-posthog.md`).
