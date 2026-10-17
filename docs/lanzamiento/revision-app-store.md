# Paquete de revisión de App Store

Paso 67 (MAT-299). Notas para el revisor, cómo se crea la cuenta demo con Pro y el checklist de `plan.md` §10 revisado ítem por ítem. Estado al **2026-10-16**. La cuenta real se crea cuando exista el entorno de prod (paso 41) y RevenueCat (H1).

## 1. Notas para el revisor

Van en App Store Connect › la versión › App Review Information › Notes (en inglés; máximo 4.000 caracteres).

```
Lumbre is a creativity app. Users save ideas (text, dictated voice, shared links, screenshots, images, PDFs). Our server condenses each one into a short "neuron" and every day pairs two neurons from different domains into a new idea, the "spark".

HOW TO TEST
1. Launch the app and tap "Empezar" (Start). The app is in Spanish by default and follows the device language (English is available).
2. A consent screen explains that content is sent to Claude, an AI by Anthropic. Tap "Acepto" (I agree). Declining keeps the app usable for saving ideas but disables AI features (guideline 5.1.2(i)).
3. You can continue as a guest, or sign in with the demo account below to see Pro features with existing content.
4. Today tab: the daily spark is generated on demand the first time, so you don't need to wait until the next morning.

DEMO ACCOUNT (Pro, with sample content)
Email: [REVIEW EMAIL]
Sign-in: enter the email, tap "Send code", then enter the code [REVIEW CODE]. This fixed code works only for this account and only during review.

SUBSCRIPTIONS
Lumbre Pro: monthly and yearly auto-renewable subscriptions (the yearly one has a 7-day free trial). The paywall appears only when tapping a Pro feature (e.g. the planner in a spark's detail, or Profile > Lumbre Pro). It shows price, period, how to cancel, Restore Purchases, and links to the Terms and Privacy Policy. Purchases can be tested with a sandbox account.

ACCOUNT DELETION
Profile > Privacidad y datos (Privacy and data) > Borrar cuenta (Delete account). It deletes the account and all data immediately. Data export is in the same screen.

AI-GENERATED CONTENT
Every spark and planner reply can be reported from its action menu ("Reportar"). Reports are stored and reviewed. External content (web pages, files) is treated as data, never as instructions to the model.

PRIVACY
No ads, no tracking, no IDFA. Uploaded images and PDFs are deleted right after processing. Analytics never include user content.

Contact during review: [NOMBRE], [EMAIL], [TELÉFONO].
```

Campos de App Review Information:

| Campo | Valor |
|---|---|
| Sign-in required | Sí (marcar), con la cuenta demo |
| User name | [REVIEW EMAIL] |
| Password | "Use code [REVIEW CODE] after tapping Send code" (el campo no puede ir vacío) |
| Contact | Nombre, teléfono y email reales; Apple llama si algo no anda |
| Attachment | Opcional: video de 30 s del flujo de entrada con la cuenta demo |

## 2. La cuenta demo con Pro

### El problema

Lumbre no usa contraseñas: se entra con un código de 6 dígitos que llega por email (y más adelante con Apple o Google). El revisor no tiene acceso al buzón de la cuenta demo, así que **hace falta una forma de entrar sin leer el email**. Esto no está en `plan.md`: queda como decisión provisoria.

### Opción recomendada (provisoria): código fijo solo para la cuenta de revisión

- Una Edge Function `review-sign-in` que recibe `{email, code}`, compara contra `REVIEW_EMAIL` y `REVIEW_CODE` (secretos del entorno de prod, nunca en la app) y, si coinciden, crea la sesión del usuario con la API de administración de Auth y la devuelve.
- La app, en el paso del código del `AccountSheet`, llama a esa función solo si el email es el de revisión (o siempre como intento previo, si se prefiere no dejar el email en el binario).
- Apagada por defecto: flag `review_sign_in_enabled` en `app_config`. Se prende al mandar a revisión y se apaga cuando la versión se aprueba. Límite de intentos por IP.
- Alternativas descartadas: un buzón compartido para el revisor (fricción y una contraseña más que cuidar) y activar contraseñas en la app (más superficie y otra pantalla).

Implementarlo es un cambio de backend e iOS (fuera de `docs/`); conviene sumarlo al paso 67 cuando se ejecute de verdad.

### Procedimiento para crearla (cuando exista prod)

1. **Usuario.** En el dashboard de Supabase de prod › Authentication › Add user: email `review@[DOMINIO]` (un alias real que llegue a tu buzón), con "Auto confirm user". Anotar el `id`.
2. **Perfil.** En el SQL Editor (service role):
   ```sql
   update public.profiles
      set creative_profiles = '{software,content}', spark_hour = '08:00',
          timezone = 'America/Los_Angeles', locale = 'en', onboarded_at = now(), plan = 'pro'
    where id = '<id>';
   ```
   La zona de Cupertino hace que la chispa del día esté disponible en el horario del revisor. `locale = 'en'` porque el revisor suele usar el teléfono en inglés.
3. **Pro en RevenueCat.** RevenueCat › Customers › buscar el `app_user_id` (el mismo `id`) › Grant promotional entitlement `pro`, duración "Lifetime" o 1 año. Así el paywall y el webhook coinciden con `profiles.plan`.
4. **Contenido.** Cargar 20 neuronas con las de `docs/build-in-public/chispas-del-dia.md` (dos por chispa, en inglés), con `capture_concept()` a nombre del usuario o por `/capture` con su sesión, y dejar que `/process` calcule embeddings y dominios. Guardar 3 chispas viejas (estado `saved`) para que la Red y el historial no estén vacíos, y armar un circuito con una conversación corta del planificador.
5. **Analytics.** En PostHog, la persona con ese `id` con `is_internal = true`, para que no cuente en los tableros.
6. **Secretos.** `supabase secrets set REVIEW_EMAIL=review@[DOMINIO] REVIEW_CODE=<6 dígitos al azar>` en prod. El código cambia en cada envío a revisión.
7. **Prueba.** Desde un iPhone limpio con el build de TestFlight: entrar con el email y el código, ver la chispa del día, abrir el planificador, abrir el paywall (debe decir que ya sos Pro), exportar datos. **No** probar "Borrar cuenta" con esta cuenta.
8. **Después de la aprobación:** apagar `review_sign_in_enabled` y rotar `REVIEW_CODE`.

## 3. Checklist de `plan.md` §10, ítem por ítem

### App Store

| Ítem | Estado | Dónde / qué falta |
|---|---|---|
| Sign in with Apple si se ofrece Google | **Pendiente, sin riesgo hoy** | Hoy la app solo ofrece email (`AccountSheet.swift`: "Pronto también con Apple y Google"), así que la regla 4.8 todavía no aplica. Apple y Google entran juntos en el paso 20b (H1): no publicar nunca un build con Google y sin Apple |
| Suscripciones con descripción, precio, período y cómo cancelar en el paywall | **Hecho en UI, falta conectarlo** | `PaywallView.swift` muestra precio, período, renovación automática y cómo cancelar. Falta RevenueCat y los productos en App Store Connect (paso 54, H1), con los precios localizados desde la tienda |
| Restaurar compras visible | **Hecho en UI** | Botón en `PaywallView.swift`; funciona de verdad con RevenueCat (paso 54) |
| Términos y privacidad enlazados en el paywall | **Hecho en UI, URLs mal** | Apuntan a `lumbre.app/terminos` y `/privacidad`, dominio de un tercero (`docs/tramites/disponibilidad.md`). Cambiar en `Brand.swift` cuando haya dominio |
| Consentimiento explícito antes de mandar datos a una IA de terceros | **Hecho, con mejoras propuestas** | `AIConsentSheet` en el onboarding e interruptor en Privacidad y datos. Texto mejorado en `docs/legal/consentimiento-ia.md`. Falta que el backend respete el "No acepto" (hoy la decisión vive solo en el teléfono) y guardar el consentimiento en el servidor |
| IA nombrada en la política de privacidad | **Borrador listo** | `docs/legal/privacidad.es.md` §4 nombra a Claude y Anthropic. Falta la revisión del abogado (H3) y publicarla en el dominio |
| Borrado de cuenta en la app | **Hecho** | Perfil › Privacidad y datos › Borrar cuenta (`DeleteAccountSheet`), con `delete_my_account()` en el backend. Falta borrar la persona en PostHog al borrar (paso 37/44) |
| Privacy manifest | **Hecho en parte** | `ios/Lumbre/Resources/PrivacyInfo.xcprivacy` existe. Le faltan Name, Device ID y los diagnósticos cuando entren Apple/Google y Sentry (ver `docs/tiendas/privacidad-app-store.md`) |
| Etiquetas de privacidad | **Respuestas listas** | `docs/tiendas/privacidad-app-store.md`. Se cargan en App Store Connect (H1) |
| Cuenta de prueba con Pro para el revisor | **Procedimiento listo** | Sección 2. Requiere prod (paso 41), RevenueCat (H1) y la función de entrada de revisión (decisión provisoria) |
| Notas de revisión | **Listas** | Sección 1 |
| Small Business Program pedido antes de facturar | **Pendiente (H11)** | Necesita la cuenta de Apple Developer y los acuerdos (ver `docs/tramites/cuentas.md`, pasos 3 a 5) |
| Postular la app para featuring | **Pitch listo** | `docs/lanzamiento/featuring-apple.md`. Se manda 6 a 8 semanas antes del lanzamiento |

Fuera del checklist pero que suelen frenar una revisión:

| Ítem | Estado |
|---|---|
| Permisos con texto claro (micrófono, reconocimiento de voz, cámara, fotos, notificaciones) | Revisar los `NS…UsageDescription` del build final en es y en |
| Funciona como invitado sin pedir datos | Hecho (sesión anónima) |
| Contenido generado reportable | Hecho: "Reportar" en chispas y en el planificador |
| Edad (cuestionario nuevo de Apple) | Responder en App Store Connect: contenido generado por IA "sí" |
| URL de soporte que funcione | Falta (necesita dominio) |
| Capturas y ficha | `docs/tiendas/fichas.md` y `capturas.md`; las imágenes en el paso 66 |

### Google Play (para el paso 86)

| Ítem | Estado |
|---|---|
| Prueba cerrada de 12+ testers por 14 días | Pendiente (H10). Solo si la cuenta es personal (ver `cuentas.md`) |
| Target SDK exigido | Pendiente (bloque H) |
| Data safety coherente con la política | Respuestas listas en `docs/tiendas/data-safety-play.md` |
| Reporte de contenido IA desde la app | Hecho en iOS; falta Android (pasos 78–79) |
| Permisos justificados | Pendiente (bloque H) |
| Borrado de cuenta en la app y **por web** | En la app, sí (iOS). **Falta la página web** `[DOMINIO]/borrar-cuenta` |
| App Bundle con Play App Signing; rollout escalonado | Pendiente (pasos 86 y 87) |

## 4. Antes de tocar "Enviar a revisión"

1. Build de producción (no Debug), apuntando a prod, sin `dev-plan` ni herramientas de desarrollo.
2. `review_sign_in_enabled` prendido y la cuenta demo probada desde un teléfono limpio.
3. Productos de suscripción en "Ready to Submit" y adjuntos a la versión.
4. Política, términos y soporte publicados en el dominio, revisados por el abogado.
5. Etiquetas de privacidad cargadas y coherentes con el manifest.
6. Lanzamiento por fases de 7 días activado (plan.md §9, F7).
