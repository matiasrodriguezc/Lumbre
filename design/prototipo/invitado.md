# Invitado: qué puede hacer y cuándo se le pide la cuenta

> **Propuesta, a confirmar con el usuario.** `plan.md` §4 deja esta definición al prototipo ("Qué puede hacer el invitado y en qué momento se le pide la cuenta se define en el prototipo") y `backend/README.md` tiene límites provisorios para el plan `guest`. Este documento propone la regla; el prototipo (`index.html`) la muestra funcionando. Nada de esto cambia el backend hasta que se confirme.

## Principio

El invitado tiene que poder **vivir el loop completo una vez** (guardar ideas, recibir su chispa, guardarla y compartirla) sin que le pidamos nada. La cuenta se pide **cuando hay algo que perder o algo que cuesta**: lo que gasta IA de pago, lo que cobra y lo que tiene que sobrevivir a un cambio de teléfono. Nunca se pide en medio del onboarding ni durante el reveal.

Es la opción conservadora en costo (el invitado no gasta IA más allá de la chispa diaria, que el backend ya le genera) y en conversión (la métrica de activación es llegar a la primera chispa: `plan.md` §13 pide ≥ 75% en el onboarding).

## Dos caminos de entrada

| Pantalla de bienvenida | Qué pasa |
|---|---|
| **Empezar** (principal) | Sesión anónima de Supabase (plan `guest`). Sigue el onboarding: consentimiento de IA, perfil, 3 ideas semilla, hora y avisos. Termina en Hoy con la primera chispa. |
| **Crear cuenta o entrar** (secundario) | Sheet de cuenta: Apple (iOS) / Google (Android) y email con código. Si el email no tiene cuenta, se crea (así ya funciona `AccountSheet.swift`). Cuenta nueva → sigue el mismo onboarding, ya con cuenta. Cuenta existente con onboarding hecho → va directo a Hoy con su red. |

Cambio de copy propuesto: el secundario hoy dice "Ya tengo cuenta", pero también crea cuentas; "Crear cuenta o entrar" cubre los dos casos. *A confirmar.*

## Qué puede hacer el invitado

| | Invitado | Free (con cuenta) | Pro |
|---|---|---|---|
| Capturar texto, voz, OCR, link o foto con su frase | **Sí, 10 por día** | 30 por día | 200 por día |
| Conceptualización automática (links, fotos, PDFs) | No: se cae a "¿Qué idea te deja esto?" | 3–5 pruebas por mes | 300 por mes |
| Chispa diaria con reveal y aviso | **Sí** | Sí | Sí |
| Chispas extra ganadas (3 neuronas = 1 extra) | No | Hasta 2 por día | Hasta 10 por día a pedido |
| Guardar la chispa, "No me sirve", compartir la tarjeta, widget | **Sí** | Sí | Sí |
| Red con búsqueda | **Sí** (la búsqueda embebe la consulta en el servidor, sin LLM) | Sí | Sí |
| Circuitos | **1** | 1 | Ilimitados |
| Planificador | No | No (es Pro) | Sí |
| Export a Markdown | **Sí** (es local) | Sí | Sí |
| Suscribirse a Pro | No: primero la cuenta | Sí | — |
| Exportar datos / borrar cuenta | Cerrar sesión borra todo (con aviso) | Sí | Sí |

Respecto de los límites provisorios del backend: se mantienen (10 capturas, nada de IA de pago, 1 circuito). Lo único que esta propuesta agrega es que **compartir, widget, búsqueda y export** quedan abiertos al invitado, porque no cuestan IA de pago y la tarjeta para compartir es el loop de crecimiento (`plan.md` §4).

## Cuándo se le pide la cuenta

### 1. Puertas (al tocar algo que la necesita)

Una hoja "Esto es con cuenta" con el motivo, **Crear cuenta** (principal) y **Ahora no**. Si crea la cuenta, se vuelve a la acción que quería hacer.

| Disparador | Texto de la hoja (`copy.json`) |
|---|---|
| Pedir otra chispa | `cuenta.gate.spark_extra` |
| Prender "Conceptualizar automáticamente" | `cuenta.gate.distill` |
| Planificar una chispa | `cuenta.gate.planner` |
| "Probar 7 días gratis" o suscribirse en el paywall | `cuenta.gate.pro` |
| La captura 11 del día | `cuenta.gate.limit` |

El paywall **sí** se le muestra al invitado (puede ver qué tiene Pro); la puerta aparece recién al tocar el botón de compra. El backend ya responde `403 account_required` en `/spark` y `/planner`: la app muestra esta hoja en vez de un error.

### 2. Recordatorios suaves (como mucho uno por día)

| Momento | Dónde | Cómo |
|---|---|---|
| Después de guardar su primera chispa | Hoy, arriba | Tarjeta con `cuenta.nudge.after_spark`, **Crear cuenta** y **Más tarde**. Una sola vez |
| Siempre | Perfil, primera sección | `cuenta.banner.title` + `cuenta.banner.body` + **Crear cuenta** (ya existe) |
| Al llegar a 10 neuronas | Toast después de guardar | "Tu red ya tiene 10 neuronas. Creá tu cuenta para no perderlas." (*a escribir si se confirma*) |
| Cerrar sesión | Alerta | `cuenta.signout_guest`: avisa que se pierde todo (ya existe) |

Nunca: en el onboarding, durante o justo después del reveal (hasta que se cierra el modal), ni más de un recordatorio suave por día.

### 3. Vencimiento

El job `limpiar-invitados` borra al invitado sin sesión en 30 días. Propuesta: si el invitado aceptó avisos, un push a los 25 días sin abrir la app ("Tu red se borra en 5 días si no creás una cuenta") — *requiere un tipo de push nuevo; a confirmar*. Sin avisos, no hay forma de avisarle: queda dicho en el banner de Perfil.

## Qué pasa al crear la cuenta

- Mismo usuario (`updateUser({ email })` o `linkIdentity()`): conserva neuronas, chispas, circuitos, perfil y hora. `effective_plan()` pasa a free y se habilitan las extras y las pruebas de conceptualización.
- Toast: **"Listo: tu red ya está en tu cuenta"** (`cuenta.created`).
- Si el email ya tiene una cuenta: aviso `cuenta.email_in_use` y la opción de entrar con esa cuenta, perdiendo lo del invitado (ya lo hace `AccountSheet.swift`).

## Métricas

Con los eventos de `docs/analytics.md` (`guest_entered`, alta de cuenta con su disparador): proporción de invitados que crean cuenta a los 7 días, por disparador (puerta o recordatorio), y si los invitados llegan a la primera chispa más que los que entran con cuenta. Si menos del 20% de los invitados activos crean cuenta en 7 días, revisar los recordatorios.

## Decisiones a confirmar

1. Botón secundario "Crear cuenta o entrar" en lugar de "Ya tengo cuenta".
2. Compartir la tarjeta, widget, búsqueda en la Red y export a Markdown abiertos al invitado.
3. El paywall visible para el invitado, con la puerta en el botón de compra.
4. El recordatorio después de la primera chispa guardada (una vez) y el de las 10 neuronas.
5. El push de vencimiento a los 25 días.
6. Límite de 10 capturas por día para el invitado (se mantiene el provisorio).
