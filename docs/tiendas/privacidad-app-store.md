# Etiquetas de privacidad de App Store

Paso 65, parte docs (MAT-296). Respuestas para App Store Connect › App Privacy, coherentes con `docs/legal/privacidad.es.md` y con el inventario de `docs/legal/README.md`. El `PrivacyInfo.xcprivacy` de `ios/` tiene que declarar los mismos tipos de dato (lo hace otro paso).

Criterio: ante la duda, se declara. Apple considera "recolectado" lo que sale del teléfono y queda accesible más tiempo que el necesario para responder el pedido en el momento. Declarar de más no trae rechazo; declarar de menos, sí.

## Pregunta inicial

**Do you or your third-party partners collect data from this app?** Yes.

## Tracking

**Do you or your third-party partners use data for tracking?** **No.**
Lumbre no cruza datos con otras empresas para publicidad ni usa el IDFA. PostHog es analítica propia, sin tracking entre apps. Por eso no hace falta el pedido de App Tracking Transparency.

## Tipos de dato

Para cada uno: **Linked to the user** = Yes (todo se asocia al id de la cuenta). **Used for tracking** = No.

| Categoría de Apple | Tipo | ¿Se declara? | Propósitos | Por qué |
|---|---|---|---|---|
| Contact Info | **Email Address** | Sí | App Functionality | Inicio de sesión (link mágico, Apple, Google) |
| Contact Info | **Name** | Sí | App Functionality | Supabase Auth guarda el nombre que mandan Apple o Google. No se usa, pero se recolecta |
| Contact Info | Phone, Physical Address, Other | No | — | — |
| Health & Fitness | — | No | — | — |
| Financial Info | — | No | — | El pago lo procesa Apple; no vemos la tarjeta |
| Location | Precise / Coarse | No | — | Solo zona horaria, que Apple no considera ubicación |
| Sensitive Info | — | No | — | No se pide. Si alguien escribe algo sensible en una nota, es User Content |
| Contacts | — | No | — | — |
| User Content | **Photos or Videos** | Sí | App Functionality | Las imágenes que se mandan a destilar se suben y se procesan en el servidor (se borran enseguida, pero salen del teléfono y pasan por Anthropic) |
| User Content | **Audio Data** | No (provisorio) | — | El dictado se transcribe en el teléfono. Pasa a **Sí** el día que la destilación de audios largos (Pro) suba audio al servidor |
| User Content | Emails or Text Messages | No | — | — |
| User Content | Gameplay Content | No | — | — |
| User Content | Customer Support | No (provisorio) | — | Pasa a Sí si se agrega un formulario de soporte dentro de la app |
| User Content | **Other User Content** | Sí | App Functionality | Neuronas, textos, links, PDFs, chispas, circuitos, mensajes del planificador y reportes de contenido |
| Browsing History | — | No | — | Los links los guarda el usuario a propósito: son User Content |
| Search History | — | No | — | La búsqueda se embebe y se responde en el momento; no se guarda |
| Identifiers | **User ID** | Sí | App Functionality, Analytics | Id de Supabase, también en PostHog, Sentry y RevenueCat |
| Identifiers | **Device ID** | Sí (provisorio, conservador) | Analytics, App Functionality | El id anónimo de instalación de PostHog/Sentry y el token de push. No es el IDFA |
| Purchases | **Purchase History** | Sí | App Functionality | Estado de la suscripción vía RevenueCat |
| Usage Data | **Product Interaction** | Sí | Analytics | Eventos de PostHog (sin contenido) |
| Usage Data | Advertising Data | No | — | — |
| Usage Data | Other Usage Data | No | — | — |
| Diagnostics | **Crash Data** | Sí | App Functionality, Analytics | Sentry |
| Diagnostics | **Performance Data** | Sí | App Functionality, Analytics | Sentry (tiempos, si se activa performance) |
| Diagnostics | **Other Diagnostic Data** | Sí | App Functionality, Analytics | Sentry (errores no fatales) |
| Surroundings, Body, Other Data | — | No | — | — |

## Cómo queda la tarjeta en la tienda

**Data Linked to You:** Contact Info, User Content, Identifiers, Purchases, Usage Data, Diagnostics.
**Data Used to Track You:** ninguno.

## Otros campos de App Store Connect

| Campo | Valor |
|---|---|
| Privacy Policy URL | `https://[DOMINIO]/privacidad` (hoy la app apunta a `lumbre.app`, que no es nuestro: ver `docs/tramites/disponibilidad.md`) |
| User Privacy Choices URL (opcional) | `https://[DOMINIO]/privacidad#tus-derechos` |
| Account deletion | En la app: Perfil › Privacidad y datos › Borrar cuenta |

## Coherencia con `PrivacyInfo.xcprivacy`

Para quien arme el manifest en `ios/`:
- `NSPrivacyTracking` = false; `NSPrivacyTrackingDomains` vacío.
- `NSPrivacyCollectedDataTypes`: los mismos tipos de la tabla marcados "Sí", con `Linked` = true, `Tracking` = false y los mismos propósitos (`NSPrivacyCollectedDataTypePurposeAppFunctionality`, `…Analytics`).
- Los SDK de terceros (supabase-swift, PostHog, Sentry, RevenueCat) traen su propio manifest; revisar que el reporte de privacidad de Xcode (Product › Archive › Generate Privacy Report) no muestre tipos que acá no están.
- Required reason APIs: `UserDefaults` (CA92.1, el consentimiento y las preferencias) y las que declare cada SDK.

### Diferencias con el manifest actual (revisado el 2026-10-16)

`ios/Lumbre/Resources/PrivacyInfo.xcprivacy` declara hoy Email Address, Other User Content, Photos or Videos, User ID, Purchase History y Product Interaction, todos vinculados, sin tracking. Coincide con esta tabla salvo en:

| Tipo | Acá | Manifest | Qué hacer |
|---|---|---|---|
| Name | Sí | No | Agregarlo cuando se activen Apple y Google (paso 20b): Auth guarda el nombre que mandan |
| Device ID | Sí (conservador) | No | Agregarlo cuando entren PostHog y Sentry (paso 44), o confirmar que sus SDK lo declaran en su propio manifest |
| Crash Data, Performance Data, Other Diagnostic Data | Sí | No | Agregarlos cuando entre Sentry (paso 44) |

Mientras Sentry y Apple/Google no estén en el build, el manifest actual es correcto para ese build; la etiqueta de App Store Connect se carga con la tabla completa para el build que va a revisión.
