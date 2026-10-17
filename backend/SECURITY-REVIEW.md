# Revisión de seguridad del backend

Paso 62 (MAT-293), parte de backend. Revisado el 2026-10-16 sobre `main` más los cambios de esta revisión. La parte de Android se repite en el paso 86 y la de la web pública (`waitlist`, `demo-spark`, `_web/`) queda fuera: tiene su propio anti-abuso y no se tocó.

Alcance: RLS y funciones de la base, claves y secretos, Edge Functions (autenticación, entradas, lectura de links, adjuntos, prompts), consentimiento para la IA, integridad del dispositivo, límites anti-abuso y logs.

## Resumen

| # | Hallazgo | Severidad | Estado |
|---|---|---|---|
| 1 | Lectura de links: un redirect a una red privada se pedía antes de revisarlo (SSRF) | Alta | Arreglado |
| 2 | Lectura de links: los hosts que empiezan con `fc` o `fd` (`fcbarcelona.com`) se trataban como privados, y las IPv6 públicas también | Baja (funcional) | Arreglado |
| 3 | Prompts: el contenido externo podía cerrar su bloque delimitado (`</contenido_externo>`) | Media | Arreglado |
| 4 | Funciones de IA sin App Attest ni Play Integrity | Media | Arreglado (detrás de `LUMBRE_ATTESTATION`) |
| 5 | Búsqueda y Hoy sin límite de frecuencia | Media | Arreglado |
| 6 | Adjuntos subidos sin captura quedaban para siempre en `capture-temp` | Media (privacidad) | Arreglado |
| 7 | El bucket temporal aceptaba 50 MB, más de lo que se procesa | Baja | Arreglado (20 MB) |
| 8 | Ninguna guarda contra funciones `security definer` nuevas expuestas a la app | Media | Arreglado (test) |
| 9 | El test de concurrencia fallaba desde el paso 20a (el trigger ya crea el perfil): el CI no lo estaba corriendo | Baja | Arreglado |
| 10 | Cobro de destilación cuando no se destiló nada (confianza baja con tesis) | Baja (negocio) | Arreglado |
| 11 | El consentimiento para la IA vivía solo en el teléfono: el servidor destilaba, generaba chispas y respondía el planificador aunque la persona hubiera dicho "No acepto" | Alta (privacidad y App Store 5.1.2) | Arreglado |
| 12 | DNS rebinding entre la resolución y el pedido del link | Baja | Riesgo aceptado |
| 13 | Moderación heurística | Media | Pendiente de clasificador real |

## Lo que se revisó y está bien

**RLS.** Todas las tablas de `public` tienen RLS (guarda en `tests/database/01_rls.sql`). Lo que el usuario edita se habilita columna por columna; el resto es solo service role. Las tablas nuevas de esta revisión (`attest_keys`, `rate_limits`) no tienen ninguna política: solo el servidor. El consentimiento para la IA (`profiles.ai_consent_at`) es una columna más que edita solo la persona, con la fecha que pone un trigger. Se sumó una guarda para funciones: las `security definer` que puede llamar la app son una lista cerrada (`capture_concept`, `create_project`, `credit_status`, `delete_my_account`, `export_my_data`, `move_concept`, `register_push_token`), ninguna se puede llamar sin sesión y todas fijan `search_path`. Las siete usan `auth.uid()` y no reciben un id de usuario por parámetro. `match_concepts` es `security invoker` (RLS filtra).

**Cuotas.** `consume_credit()` y `refund_credit()` son solo service role; el descuento es atómico (probado con 50 llamadas simultáneas). Los invitados no tienen cupo de IA de pago; su chispa diaria cuenta para el tope global en dólares.

**Claves.** Ninguna clave de IA vive en las apps ni en el repo (`git grep` de `sk-ant-`, `sb_secret_`, claves privadas PEM y AWS: sin resultados). `supabase/.env` y `supabase/functions/.env` están en `.gitignore`. La única clave en el repo es la de servicio de demostración del stack local (`seed.sql`), que solo vale contra `supabase start`. Los secretos remotos van con `supabase secrets set` y los de los crons en Vault.

**Autenticación de las funciones.** Las de la app tienen `verify_jwt = true` y además validan el token con Auth (`requireUser`). Las internas (`process`, `daily-sparks`, `send-pushes`) exigen la clave de servicio con comparación de tiempo constante; el webhook, `REVENUECAT_WEBHOOK_SECRET` (sin secreto configurado rechaza todo). `dev-plan` responde 404 salvo `LUMBRE_DEV_TOOLS=true`. El test de contrato comprueba que `verify_jwt` de `config.toml` coincide con la seguridad de cada path y que las que no lo usan validan su propio secreto.

**Entradas.** Cada función valida tipos y largos antes de tocar la base, y la base vuelve a validar (`capture_concept`). Los adjuntos solo se leen de la carpeta del propio usuario (`<user_id>/…`, sin `..`). CORS abierto es correcto: la autenticación va por header, no por cookies.

**Webhook.** Idempotente por id de evento; solo cambia el plan de ids con forma de UUID; los eventos de otros entitlements no tocan el plan.

**Logs.** Revisadas todas las llamadas a `console.*` de las funciones: una línea JSON con función, nivel, códigos, cantidades e ids; nunca texto de conceptos, búsquedas, mensajes ni páginas. Los errores pasan por `describeError` (tipo y mensaje técnico, cortado a 300). El gateway reemplaza los errores de `JSON.parse` (que en V8 incluyen un pedazo del texto) por "json inválido". Analytics tiene una lista de propiedades prohibidas (`text`, `title`, `thesis`, `body`, `query`, `message`, `email`, `note`…). `llm_calls` guarda tokens y costo, nunca contenido.

**Datos.** Texto crudo a 30 días (job diario), adjuntos borrados siempre (y ahora también los huérfanos), invitados abandonados borrados a los 30 días, exportar y borrar la cuenta desde la app.

## Detalle de los arreglos

1. **SSRF por redirect** (`_shared/links.ts`). Con `redirect: "follow"`, `fetch` seguía un 302 a `169.254.169.254` o a `kong` y recién después se revisaba la URL final: el pedido ya había salido. Ahora los redirects se siguen a mano (hasta 4) y cada salto pasa por `isFetchableUrl` antes de pedirse. Test: `_tests/content.test.ts` ("un redirect a una red privada se corta antes de pedirlo").
2. **Hosts mal clasificados.** `startsWith("fc")` marcaba como privados dominios públicos y la regla "sin punto" bloqueaba toda IPv6 literal. Ahora el chequeo de IPv6 solo aplica a direcciones con `:`, incluye `::ffff:a.b.c.d` y el resto de los rangos privados de IPv4.
3. **Delimitadores de prompt** (`asPromptData` en `_shared/text.ts`). Lo que viene de afuera o de la bóveda (página, fragmento, tesis, títulos, conceptos de la chispa, contexto del planificador) cambia `<` y `>` por `‹` y `›` antes de entrar a un bloque delimitado, así no puede cerrarlo y "salir" a instrucciones. Los prompts ya decían que ese contenido son datos; esto lo hace cumplir.
4. **Integridad del dispositivo** (paso 40, `_shared/attest/`). App Attest (atestación con la cadena hasta la raíz de Apple, nonce, keyId, App ID, contador y entorno; aserciones con firma y contador creciente) y Play Integrity (token descifrado con la API de Google y veredictos exigidos). Se prende con `LUMBRE_ATTESTATION=report|enforce`; en local y dev queda en `off`.
5. **Límites de frecuencia.** `hit_rate_limit()` (ventana fija, atómica). `/search`: 120 por hora por usuario; `/today`: 300 por hora. Responden 429 `rate_limited`. Captura, chispas extra, destilación y planificador ya tenían cupos en `plan_limits`.
6. **Adjuntos huérfanos.** Si la app sube un archivo y nunca llama a `/capture`, quedaba en Storage. `/process` (cada 5 minutos) borra con la API de Storage lo de más de una hora (`stale_capture_uploads()`); la base no deja borrar `storage.objects` directo.
7. **Tamaño del bucket.** 20 MB: es el máximo que se le manda al modelo. Además `/capture` controla tamaño, lado de la imagen (8.000 px) y páginas del PDF (30) antes de llamar al modelo.
8. **Guarda de funciones** en `01_rls.sql` (ver arriba).
9. **Test de concurrencia.** Insertaba el perfil a mano y chocaba con el que crea el trigger; ahora hace upsert.
10. **Destilación no cobrada si no hubo destilación.** Con confianza baja (o un archivo que el modelo no pudo leer) se devuelve el crédito aunque la persona haya escrito su idea.
11. **Consentimiento para la IA en el servidor** (migración `20261016130000_consentimiento_ia.sql`). Nueva columna `profiles.ai_consent_at` (timestamptz; null = no aceptó o revocó), editable por la persona con RLS de columna. Un trigger pone la hora del servidor (la del teléfono no prueba nada) y conserva la primera fecha si vuelve a aceptar. Las respuestas que la app había dejado en `user_metadata.ai_consent` se migraron. Sin fecha: `/capture` guarda sin destilar ni cobrar (`distillation: consent_required`), `/spark` y `/planner` responden 403 `ai_consent_required` antes de cobrar, `/today` no genera la diaria y `users_needing_daily_spark()` saltea a la persona (tampoco entra al batch de Anthropic). Se exige también con el proveedor local, para que dev se comporte como producción. Tests: `tests/database/11_consentimiento_ia.sql`, `e2e.sh` (aceptar, revocar y sus efectos) y una guarda en `_tests/contract.test.ts`. La fecha queda en `export_my_data()`.

## Riesgos aceptados y pendientes

- **Consentimiento: versión del texto y embeddings.** Se guarda la fecha del "Acepto", no la versión del texto que se aceptó; si el texto cambia de fondo, sumar `ai_consent_version` y volver a preguntar. Los embeddings no piden consentimiento porque hoy son locales; si se pasa a Voyage (paso 22), el texto de cada concepto y cada búsqueda saldría a un tercero y habría que nombrarlo en el consentimiento o pedirlo también ahí. Una chispa diaria que ya estaba en un batch de Anthropic cuando la persona revocó se crea igual al levantar el batch (el contenido ya había salido).
- **DNS rebinding.** Se resuelve el host y después se pide; un DNS malicioso podría responder distinto la segunda vez. En Supabase las funciones corren fuera de la red de la base y no hay metadata de nube accesible; el riesgo es bajo. Si se mueve el backend, fijar la IP resuelta en el pedido.
- **Moderación** (`_shared/moderation.ts`): heurística estrecha a propósito (no bloquea temas, solo pedidos de daño grave). Antes del lanzamiento conviene un clasificador real detrás de la misma interfaz. El reporte de contenido IA desde la app ya existe (`content_reports`).
- **App Attest con challenge de la app.** El servidor acepta el tiempo que firma la app (±5 minutos) en vez de un challenge de un solo uso pedido al servidor; el contador de las aserciones impide repetirlas. Las atestaciones se aceptan una sola vez por clave. Provisorio.
- **Invitados y costo.** Un invitado recibe su chispa diaria con IA (con Anthropic cuesta). El freno es el límite de 10 sesiones anónimas por hora por IP y el tope global diario en dólares. Con `LUMBRE_ATTESTATION=enforce`, además, solo la app real puede pedirla.
- **Cuentas de servicio.** La clave de servicio está en Vault para los crons; quien tenga acceso al SQL Editor del proyecto la puede leer. Limitar el acceso al dashboard a quien opera.

## Checklist para cada entorno remoto (paso 41)

- [ ] `LUMBRE_DEV_TOOLS` sin definir.
- [ ] `REVENUECAT_WEBHOOK_SECRET` largo y aleatorio.
- [ ] `LUMBRE_ATTESTATION=report` al publicar la app; `enforce` cuando los logs de `attest` den `ok` para casi todos.
- [ ] `APP_ATTEST_ALLOW_DEVELOPMENT=false` en prod.
- [ ] Topes de `app_config` revisados (`user_daily_usd_cap`, `global_daily_usd_cap`).
- [ ] Ajustes de Auth del dashboard (ver `README.md`, sección Auth).
- [ ] Secretos de Vault de los crons cargados (`lumbre_functions_url`, `lumbre_service_key`).

## Cómo se verificó

```bash
cd backend
supabase test db                                   # pgTAP, incluidas las guardas de RLS y de funciones
deno test -A supabase/functions/_tests/ eval/      # links, prompts, adjuntos, App Attest, Play Integrity, contrato
supabase/tests/functions/e2e.sh                    # punta a punta (con supabase functions serve)
git grep -nE "sk-ant-|sb_secret_|BEGIN (EC |RSA )?PRIVATE KEY" -- . ':!*.md'
```
