# Web

Landing con la fila (waitlist con referidos) y la demo web de la chispa. Pasos 5 y 6 de `plan-ejecucion.md`.

HTML, CSS y JS sin build: lo que está en esta carpeta es exactamente lo que se publica. Tema gris (Gris neurona), Fraunces solo para marca y títulos, fuente del sistema para todo lo demás.

## Páginas

| Archivo | Qué es |
|---|---|
| `index.html` | Landing: hero con la fila, cómo funciona, demo de la chispa (con el reveal de la sinapsis) y cierre con la fila |
| `fila.html` | "Estás en el puesto N": confirma el email (link del mail), muestra el puesto, el link para compartir y permite salir de la fila |
| `privacidad.html` | Aviso de privacidad (texto provisorio hasta la revisión legal) |
| `404.html` | Página no encontrada (Netlify, Vercel y Cloudflare Pages la usan solas) |
| `_headers` | CSP y caché para Netlify y Cloudflare Pages |
| `assets/config.js` | URL de las Edge Functions, PostHog opcional y valores por defecto de los flags |
| `assets/lumbre.js` | Lo compartido: llamadas a la API, textos, flags, analytics y almacenamiento local |
| `assets/landing.js`, `assets/fila.js` | La lógica de cada página |
| `assets/tokens.css`, `assets/img/`, `assets/fonts/` | Copias del design system (ver "Actualizar los assets") |
| `scripts/` | `sync-assets.sh` y `og.py`. No hace falta publicarlos |

## Backend

Dos Edge Functions públicas (`verify_jwt = false`), sin ninguna clave en el front:

| Función | Qué hace |
|---|---|
| `waitlist` | `join` (anota y manda el mail de confirmación), `status` (puesto; con el token del mail, confirma) y `leave` (borra el email) |
| `demo-spark` | Dos ideas → una chispa por el gateway de IA (`_shared/ai`), una por email y por día, y el email entra a la fila |

- Base: `backend/supabase/migrations/20261014100000_waitlist.sql` (tablas `waitlist`, `demo_sparks`, `web_rate_limits`, todo solo service role) y sus tests en `tests/database/09_waitlist.sql`.
- Lo compartido entre las dos funciones está en `backend/supabase/functions/_web/` (HTTP, anti-abuso, mails y alta).
- **Fila:** orden de llegada; cada referido que confirma su email sube `waitlist_referral_boost` puestos (10) a quien lo invitó.
- **Tokens:** cada persona tiene dos. El de su página vuelve al navegador al anotarse; el de confirmación viaja solo por mail. Confirmar exige el del mail. En la base se guarda solo el sha256 de cada uno. Los links usan el fragmento (`fila.html#c=…`), que no llega a los servidores ni a los logs.
- **Email repetido:** la web no dice si estaba (responde "revisá tu mail") y le reenvía su link por mail, hasta 3 por día.
- **Anti-abuso:** por IP (hasheada con sal) 10 altas por hora y 30 por día, 60 consultas por hora, 5 chispas por hora y 10 por día; campo trampa y tiempo mínimo de 1,5 s; máximo global de chispas por día (`web_demo_daily_max`, 500); tope diario en dólares del gateway.
- **Demo:** las ideas van delimitadas en el prompt (`demo-spark/prompt.ts`, versión `demo_spark.v0`) y se tratan como datos; moderación de entrada y salida; no se guardan ni se loguean. Se registra en `llm_calls` como `demo_spark`, sin usuario.
- **Flags:** en el servidor, `app_config.web_waitlist_enabled` y `web_demo_enabled` (se cambian sin publicar). En la web, `web_waitlist` y `web_demo_spark` de PostHog (si hay clave), con los valores por defecto de `config.js`.
- **Limpieza diaria** (`limpiar-web`, 06:37 UTC): ventanas de límites de más de 2 días, chispas de la demo de más de 30 y emails sin confirmar de más de 30.
- **Analytics** (`docs/analytics.md`, fuente W): `waitlist_joined` y `demo_spark_generated` salen del servidor con el id de la fila; `referral_link_copied` sale de la web solo si hay clave de PostHog, sin cookies. Nunca el email.

## Correrlo en local

1. Stack de Supabase y funciones (ver `backend/README.md`):

   ```bash
   cd backend && supabase start
   cd backend && supabase functions serve   # en otra terminal
   ```

2. El sitio, desde la raíz del repo (o el servidor `web` de `.claude/launch.json`):

   ```bash
   python3 -m http.server 55580 --bind 127.0.0.1 --directory web
   ```

3. Abrir http://localhost:55580. Los mails llegan a Mailpit: http://127.0.0.1:55524. El link del mail apunta a `http://localhost:55580/fila.html#c=…` (cambiar con `LUMBRE_SITE_URL`).

En local las funciones mandan los mails a Mailpit solas (detectan el stack local) y la chispa sale del proveedor `local` del gateway (determinístico y sin costo). Para probar los límites otra vez: `delete from web_rate_limits;` en la base local.

## Variables de entorno (Edge Functions)

Van en `backend/supabase/functions/.env` en local y con `supabase secrets set` en remoto. Todas opcionales.

| Variable | Default | Para qué |
|---|---|---|
| `LUMBRE_SITE_URL` | `http://localhost:55580` | Base de los links de los mails (`/fila.html#c=…` y `/?ref=…`) |
| `LUMBRE_WEB_ORIGINS` | (vacío: cualquiera) | Orígenes permitidos por CORS, separados por coma. En prod, el dominio de la web |
| `LUMBRE_MAIL_PROVIDER` | `mailpit` en local, `log` en remoto | Proveedor de mails. `log` no manda nada (solo deja una línea sin datos) |
| `MAILPIT_URL` | `http://supabase_inbucket_lumbre:8025` | Mailpit dentro de la red de Docker del stack |
| `LUMBRE_MAIL_FROM`, `LUMBRE_MAIL_FROM_NAME` | `hola@lumbre.local`, `Lumbre` | Remitente |
| `LUMBRE_RATE_SALT` | derivada de la clave de servicio | Sal de los hashes de IP y email de los límites |
| `ANTHROPIC_API_KEY` | — | Con clave, la demo usa Anthropic (`LUMBRE_MODEL_FAST`); sin clave, el proveedor local |
| `POSTHOG_API_KEY` | — | Eventos de servidor; sin clave van al log |

## Publicar (cuando estén las cuentas de H1)

Hosting estático: Cloudflare Pages, Netlify o Vercel, con `web/` como carpeta de salida y sin comando de build.

1. **Dominio** (MAT-214): apuntarlo al hosting.
2. **Supabase de prod** (paso 41): `supabase db push` (aplica la migración) y `supabase functions deploy waitlist demo-spark` (con `verify_jwt = false`, ya en `config.toml`).
3. **`assets/config.js`**: `apiUrl` con el ref del proyecto de prod. **`_headers`**: el mismo ref en `connect-src`. **`index.html`**: `og:image` con la URL absoluta (`https://<dominio>/assets/img/og.png`).
4. **Secretos:** `LUMBRE_SITE_URL=https://<dominio>`, `LUMBRE_WEB_ORIGINS=https://<dominio>`, `ANTHROPIC_API_KEY`, `POSTHOG_API_KEY` y una `LUMBRE_RATE_SALT` propia.
5. **Proveedor de email:** sumar su clase en `functions/_web/mail.ts` (la interfaz es `Mailer.send`), elegirlo con `LUMBRE_MAIL_PROVIDER`, verificar el dominio (SPF, DKIM, DMARC) y poner un remitente real en `LUMBRE_MAIL_FROM`.
6. **PostHog (opcional):** `posthogKey` en `config.js` y crear los flags `web_waitlist` y `web_demo_spark`.
7. Revisar el texto de privacidad con el abogado (MAT-213).

## Actualizar los assets

Tokens, logos, la red del hero, el ícono, la fuente (Fraunces recortada a latín, peso 600 y SOFT 100) y la imagen para compartir salen del design system:

```bash
web/scripts/sync-assets.sh   # requiere Pillow y fonttools
```
