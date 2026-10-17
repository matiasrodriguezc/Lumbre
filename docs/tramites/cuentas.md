# Cuentas a crear, en orden

Para H1 (MAT-216). El orden importa: algunas tardan semanas y otras dependen de las anteriores. Todas las hacés vos: crear cuentas, aceptar términos y cargar datos de pago no lo puedo hacer yo.

**Antes de empezar, una decisión:** publicar como **persona** o como **organización** (pregunta 1 para el contador, `preguntas-contador.md`). Cambia cuatro cosas:
- Como organización hace falta el **D-U-N-S** para Apple y para Google Play, y en las tiendas aparece el nombre de la empresa.
- Como persona, en las tiendas aparece tu nombre y apellido, y Google Play exige a las cuentas personales nuevas una **prueba cerrada de 12+ testers por 14 días** antes de publicar (plan.md §10).
- La cuenta de Apple se puede migrar de persona a organización más adelante (con D-U-N-S); la de Google Play no se convierte: hay que transferir la app a otra cuenta.

## Orden

| # | Cuenta | Para qué | Cuánto tarda | Costo | Depende de |
|---|---|---|---|---|---|
| 0 | **D-U-N-S** (Dun & Bradstreet), solo si es organización | Apple Developer y Google Play como organización | **Hasta 30 días** (a veces 5). Pedirlo desde la herramienta de Apple, que es gratis | Gratis | Sociedad inscripta (CUIT, domicilio legal) |
| 1 | **Dominio** | Email propio, landing, URLs de privacidad y términos | Minutos | US$ 15–30/año | Que el abogado no descarte el nombre (ver `disponibilidad.md`) |
| 2 | **Email del dominio** (Google Workspace, Zoho o similar) | hola@, privacidad@ y soporte@; Apple pide un email de contacto y una URL de soporte | 1 día (verificación DNS) | US$ 0–7/mes | 1 |
| 3 | **Apple Developer Program** | TestFlight, App Store, Sign in with Apple, push (APNs), App Attest | 1–2 días como persona; con D-U-N-S, hasta 2 semanas | US$ 99/año | Apple ID con 2FA; 0 si es organización |
| 4 | **App Store Connect: acuerdos, impuestos y banco** | Acuerdo de Aplicaciones Pagas, formulario W-8BEN (o W-8BEN-E), cuenta bancaria. Sin esto no hay suscripciones | 1–3 días | — | 3, y la respuesta del contador |
| 5 | **Small Business Program** de Apple (H11) | Comisión del 15% en vez del 30% | 1–2 semanas | Gratis | 4. Pedirlo **antes de la primera venta**: no es retroactivo |
| 6 | **Reservar el nombre en App Store Connect** | Crear el registro de la app con el nombre elegido, aunque no se publique | Minutos | — | 3 y el nombre confirmado |
| 7 | **Google Play Console** | Publicar en Android, prueba cerrada, Play Integrity | Verificación de identidad: 2–7 días | US$ 25 una vez | Documento de identidad; D-U-N-S si es organización |
| 8 | **Perfil de pagos de Google** | Cobrar suscripciones en Play | 1–3 días | — | 7 |
| 9 | **Anthropic** (Console) | API de Claude: conceptualización, chispas, planificador, demo web | Minutos; cargar crédito | Uso (empezar con US$ 20–50) | Email del dominio |
| 10 | **Proveedor de embeddings** (probablemente Voyage AI) | Embeddings reales (paso 22) | Minutos | Uso; tiene capa gratis | — |
| 11 | **Proveedor de email transaccional** (Resend, Postmark o similar) | Links mágicos de Supabase Auth, confirmación de la waitlist, demo web | 1 día (DNS: SPF, DKIM) | Gratis al principio | 1 y 2 |
| 12 | **Supabase** (ya existe, organización Lumbre) | Staging y prod (paso 41); pasar a Pro antes de abrir la beta (backups diarios, sin pausa por inactividad) | Minutos | US$ 25/mes | Elegir la región de prod |
| 13 | **RevenueCat** | Suscripciones en iOS y Android, webhook al backend | Minutos | Gratis hasta US$ 2.500/mes de ingresos | 4 y 8 para conectar las tiendas |
| 14 | **PostHog** (nube de la UE) | Analytics y feature flags. Dos proyectos: dev/staging y prod | Minutos | Gratis hasta 1M eventos/mes | — |
| 15 | **Sentry** | Crashes y errores de iOS, Android y Edge Functions | Minutos | Gratis (plan Developer) | — |
| 16 | **GitHub: facturación** (H13) | Destrabar Actions (hoy bloqueado por un problema de facturación) | Minutos | Gratis para el uso actual | — |
| 17 | **Handles de redes** | Build in public (paso 7) | Minutos | Gratis | Nombre confirmado |
| 18 | **Product Hunt** (perfil de maker) | Lanzamiento iOS. Conviene crearlo semanas antes y participar, porque una cuenta nueva tiene poco alcance | Minutos | Gratis | — |

## Datos a tener a mano

- Documento, CUIT/CUIL y domicilio (o los de la sociedad).
- Una tarjeta para las suscripciones en dólares (Apple, Supabase, Anthropic).
- Cuenta bancaria que pueda recibir dólares de Apple y Google (lo define el contador).
- Teléfono con 2FA para Apple, Google y GitHub.
- Para Sign in with Apple y Google en Supabase: Services ID y clave de Apple, client IDs de Google (después de 3 y 7). Se cargan en `backend/supabase/.env` según `.env.example`.

## Cuando estén listas

Avisame y sigo con lo que destraban: 5 y 6 (landing y demo), 20b (Apple y Google), 22 (embeddings), 32 (push), 41 (entornos), 54 (paywall) y 59 (TestFlight).
