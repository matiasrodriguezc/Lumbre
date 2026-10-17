# Disponibilidad de "Lumbre": dominios, handles y tiendas

Chequeo hecho el **2026-10-13** (paso 4, MAT-214). Es una foto de ese día: un dominio o un handle libre hoy puede no estarlo mañana. Antes de comprar o crear, se vuelve a mirar.

Cómo se chequeó:
- **Dominios:** `dig` (NS y A), `whois` y RDAP de cada registro (Verisign para .com, Google Registry para .app y .dev, Identity Digital para .io). Para los ocupados, se miró qué publica el sitio.
- **Handles:** la página pública de cada perfil en el navegador, sin sesión (X, Instagram, TikTok, LinkedIn) y la API pública de GitHub y YouTube.
- **Tiendas:** API de búsqueda de iTunes (US, AR, MX, ES) y la búsqueda de Google Play (Argentina).

## Resumen

**El nombre exacto está tomado en casi todos lados, y hay tres productos llamados Lumbre que importan:**

1. **getlumbre.app** (registrado el 2026-06-13): "Lumbre — One line. Every day.", un diario de una línea por noche, **con waitlist para iOS**. Es una app de productividad/bienestar personal en la misma tienda y en categorías cercanas. Tiene además @getlumbre en X (desde enero de 2026) y en Instagram. Es el riesgo más alto: si publica antes, en el App Store habría dos "Lumbre".
2. **lumbre.ar**: "Lumbre — Un tutor de IA que no olvida nada", tutor de IA en español con currícula argentina. Es software con IA, en Argentina. Riesgo directo para la marca en clases 9, 41 y 42 en el INPI.
3. **holalumbre.com** (registrado el 2026-08-30 en Dattatec, Argentina): "Lumbre — Encendé tu inmobiliaria", SaaS de sitios para inmobiliarias. Usa el mismo juego de palabras ("Encendé"). Instagram @holalumbre.

Otros usos del nombre, de menor riesgo: Casa Lumbre (México, bebidas, con marcas también en clase 41 en EE. UU.), estudio creativo LUMBRE (LinkedIn), lumbreapp.com (terapeutas holísticos), "Lumbre - Icon Pack" en Google Play.

**Consecuencia para el producto:** la app usa hoy `https://lumbre.app/privacidad` y `https://lumbre.app/terminos` (`ios/Lumbre/Features/Shared/Brand.swift`), pero **lumbre.app está registrado por un tercero desde el 2026-01-07** (Porkbun, página de parking). Si no es tuyo, esas URLs hay que cambiarlas antes de cualquier build externo.

**Recomendación (provisoria, hasta el informe del abogado):** no comprar nada todavía salvo lo barato y defendible (abajo). Con tres "Lumbre" de software activos, uno con IA en Argentina y otro con waitlist en iOS, el abogado tiene que decir si Lumbre pasa antes de invertir en handles y marca. Si no pasa, Espurna y Chiribita tienen mejor disponibilidad que Hirameki.

## Dominios

| Dominio | Estado | Detalle |
|---|---|---|
| lumbre.app | Ocupado | Registrado 2026-01-07 (Porkbun), parking. ¿Es tuyo? Si no, está en uso en `Brand.swift` |
| lumbre.com | Ocupado | Desde 1999 (GoDaddy), redirige a una página de venta/parking |
| lumbre.com.ar | Ocupado | Tiene NS de Hostinger; no publica nada visible. NIC Argentina no respondió desde acá: confirmar en nic.ar |
| lumbre.ar | Ocupado | Tutor de IA argentino (ver arriba) |
| lumbre.io | Ocupado | Registrado 2026-02-17, sin sitio visible |
| lumbre.ai | Ocupado | Desde 2024, privacidad de whois |
| lumbre.co | Ocupado | Desde 2019, parking |
| lumbre.dev | Ocupado | Registrado 2026-04-22, sitio mínimo |
| lumbre.net | Ocupado | En venta en HugeDomains |
| lumbre.org | Ocupado | Hosting genérico |
| lumbre.es | Ocupado | Redirige a una empresa de chimeneas |
| getlumbre.com | Ocupado | Registrado 2026-05-21, parking |
| getlumbre.app | Ocupado | App de diario "Lumbre" con waitlist para iOS |
| lumbreapp.com | Ocupado | Terapeutas holísticos |
| holalumbre.com | Ocupado | SaaS inmobiliario argentino |
| lumbrelabs.com | Ocupado | — |
| **uselumbre.com** | **Libre** | |
| **trylumbre.com** | **Libre** | |
| **lumbrehq.com** | **Libre** | |
| **mylumbre.com** | **Libre** | |
| **getlumbreapp.com** | **Libre** | |
| **lumbreideas.com** | **Libre** | |
| **uselumbre.app** | **Libre** | |
| **trylumbre.app** | **Libre** | |
| **holalumbre.app** | **Libre** | |
| **lumbreideas.app** | **Libre** | |
| **lumbreapp.app** | **Libre** | |
| **getlumbre.io** | **Libre** | |
| **lumbreapp.io** | **Libre** | |
| lumbreapp.com.ar, getlumbre.com.ar | Probablemente libres | Sin DNS; confirmar en nic.ar (no respondió) |

### Alternativas de nombre (plan.md §2)

| Nombre | .com | .app | .io | Otros |
|---|---|---|---|---|
| Espurna | Ocupado | **Libre** | Ocupado | espurnaapp.com y getespurna.com libres |
| Hirameki | Ocupado | Ocupado | Ocupado | hiramekiapp.com y gethirameki.com libres; varias apps "Hirameki" en el App Store (HiramekiLab Inc., un curso de japonés) |
| Chiribita | Ocupado | **Libre** | **Libre** | chiribitaapp.com y getchiribita.com libres; ninguna app con ese nombre |

## Handles

| Red | lumbre | lumbreapp | getlumbre | Otros |
|---|---|---|---|---|
| X | Ocupado (cuenta personal desde 2011, sin posts) | **Libre** | Ocupado (desde ene. 2026, probablemente la app de diario) | **lumbrehq** y **lumbre_app** libres |
| Instagram | Ocupado (cuenta personal) | Ocupado ("Lumbre App") | Ocupado | **lumbre.app** "no disponible" (puede ser libre o una cuenta dada de baja); lumbre_app ocupado ("Lumbre App"); holalumbre y uselumbre ocupados |
| TikTok | Ocupado (cuenta personal chica) | **Libre** | **Libre** | **lumbre.app** libre |
| LinkedIn (página de empresa) | Ocupado (estudio creativo LUMBRE, 20 empleados) | Sin verificar (pide sesión) | Sin verificar (pide sesión) | Revisar con tu sesión |
| GitHub | Ocupado (usuario sin repos, desde 2018) | **Libre** | **Libre** | lumbre-app libre. El repo vive en `matiasrodriguezc/Lumbre`; una organización solo hace falta si se abre código |
| YouTube | **Libre** (@lumbre) | **Libre** | **Libre** | @uselumbre ocupado ("Use Lumbre") |

No hay un mismo handle libre en todas las redes. La combinación más pareja hoy:
- **lumbreapp:** libre en X, TikTok, GitHub y YouTube; ocupado en Instagram.
- **lumbre.app:** libre en TikTok y probablemente en Instagram; X no admite puntos.
- **lumbrehq:** libre en X y GitHub; en Instagram "no disponible"; falta mirar TikTok.

## Tiendas

| Tienda | Búsqueda "lumbre" | Conclusión |
|---|---|---|
| App Store (US, AR, MX, ES) | Ninguna app llamada "Lumbre". Aparecen La Pura Lumbre Radio, Lumbrera TV, Lumensia y apps de encendedor | El nombre está libre hoy, pero getlumbre.app anuncia una app iOS. Apple no permite dos apps con el mismo nombre exacto: el que la reserva primero en App Store Connect se la queda |
| Google Play (AR) | Casi todo son juegos de "Lumber" (leñador). Hay "Lumbre - Icon Pack" (Olivera Onias Design) | Play permite nombres repetidos, pero la búsqueda de "lumbre" está tapada por "lumber": la palabra sola no sirve para ASO; el título tiene que llevar "ideas" o "creatividad" |

## Qué hacer ahora (provisorio)

1. Confirmar si lumbre.app es tuyo. Si no, cambiar las URLs legales a un dominio propio en cuanto se compre.
2. Pasarle al abogado los tres homónimos de software (ver `brief-abogado.md`).
3. Si querés asegurar algo barato mientras tanto: `uselumbre.app` o `trylumbre.app` (unos US$ 15/año) y @lumbreapp en X y TikTok. No crear perfiles de marca hasta que el abogado responda.
4. Reservar el nombre en App Store Connect es posible recién con la cuenta de Apple Developer (H1): conviene hacerlo apenas exista, si Lumbre sigue en pie.
