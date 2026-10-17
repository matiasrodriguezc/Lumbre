# Brief para el abogado: marca y documentos legales

Para mandar junto con el primer contacto (H3, MAT-213 y MAT-295). Escrito para alguien que no conoce el proyecto.

---

## 1. Qué es

**Lumbre** es una app móvil (iOS y Android) de creatividad. La persona guarda ideas que lee o se le ocurren; una IA las resume en "neuronas" (título, tesis y principio) y cada mañana conecta dos de dominios distintos para proponer una idea nueva, la "chispa". Modelo freemium con suscripción Pro (US$ 6,99 por mes o US$ 49,99 por año), cobrada por App Store y Google Play.

- Titular: [persona humana o sociedad, según lo que defina el contador].
- Mercado inicial: Argentina y LATAM hispanohablante; después Estados Unidos y España (inglés y español).
- Lanzamiento estimado: iOS en [mes]; Android unos meses después.
- Tagline: "Lumbre. Donde se encienden las ideas."

## 2. Búsqueda de marca

**Signo:** LUMBRE (denominativa). Después, mixta con el logo (una neurona plana con un punto magenta).

**Oficinas:** INPI (Argentina), USPTO (Estados Unidos) y EUIPO (Unión Europea). Si el costo lo permite, sumar IMPI (México) por ser el segundo mercado hispano.

**Clases:**
- **9:** software y aplicaciones móviles descargables para capturar, organizar y combinar ideas; software con inteligencia artificial para generar ideas.
- **42:** software como servicio (SaaS); plataforma en línea con IA para generar y organizar ideas; diseño y desarrollo de software.
- A evaluar: **41** (servicios educativos y de formación, por el método creativo y los contenidos) y **35** (si se vende a equipos más adelante).

**Antecedentes encontrados en una búsqueda informal el 2026-10-13** (no reemplaza la búsqueda profesional; detalle en `disponibilidad.md`):

| Quién | Qué hace | Por qué preocupa |
|---|---|---|
| lumbre.ar | "Lumbre", tutor de IA en español con currícula argentina | Software con IA en Argentina, clases 9, 41 y 42 |
| getlumbre.app | "Lumbre", diario personal de una línea por día, con waitlist para iOS. Cuenta @getlumbre desde enero de 2026 | App móvil en la misma tienda y en una categoría cercana (productividad, bienestar). Puede haber presentado marca |
| holalumbre.com | "Lumbre", SaaS de sitios web para inmobiliarias, Argentina (dominio de agosto de 2026) | Software (clase 42) en Argentina |
| Casa Lumbre, S.A.P.I. de C.V. | Bebidas (México), con marcas registradas en EE. UU., algunas en clase 41 | Titular activo con muchas marcas que contienen LUMBRE |
| Estudio creativo LUMBRE | Motion graphics y branding | Clase 41/42 si está registrada |
| lumbreapp.com | Plataforma de terapeutas holísticos | Clase 44, en principio lejana |

**Preguntas:**
1. ¿Hay marcas registradas o en trámite para LUMBRE (o parecidas: LUMBRERA, LUMBRA, LUMBER) en las clases 9, 42 y 41 en INPI, USPTO y EUIPO?
2. Con los antecedentes de la tabla, ¿es registrable LUMBRE en Argentina? ¿Y en EE. UU. y la UE? ¿Qué probabilidad hay de oposición?
3. Si un tercero usa Lumbre sin registro (por ejemplo, la app de diario), ¿qué pesa más: el uso previo o el registro? ¿Cambia algo si publican en el App Store antes que nosotros?
4. ¿Conviene presentar ya en Argentina para ganar prioridad (Convenio de París, 6 meses) y después extender?
5. Costo y plazo estimado por oficina y por clase.
6. Si LUMBRE no pasa, búsqueda rápida de las alternativas en el mismo orden de preferencia: **Espurna** (chispa en catalán), **Chiribita** (sinónimo de chispa, RAE), **Hirameki** (閃き, destello de inspiración en japonés). Hirameki ya tiene varias apps con ese nombre en el App Store.

## 3. Documentos para revisar

Borradores en `docs/legal/` (es y en), escritos a partir de lo que la app realmente guarda y hace:
- Política de privacidad.
- Términos y condiciones (incluye suscripciones y contenido generado por IA).
- Texto del consentimiento para el uso de IA de terceros (pantalla de la app).
- Respuestas de los formularios de privacidad de App Store y Google Play (`docs/tiendas/`), que tienen que coincidir con la política.

**Lo que hace falta que el abogado defina o confirme:**
1. Encuadre de la **Ley 25.326** y su reglamentación: ¿hay que inscribir la base de datos en el Registro Nacional de Bases de Datos (AAIP)? ¿Qué datos de contacto y plazos de respuesta corresponden (10 días hábiles para el acceso, 5 para rectificación y supresión)?
2. **Transferencia internacional:** los datos van a Supabase (servidores en Brasil, EE. UU. o la UE según el entorno), Anthropic (EE. UU.), PostHog (UE), Sentry (EE. UU.), RevenueCat (EE. UU.) y un proveedor de embeddings (a definir, probablemente Voyage AI, EE. UU.). ¿Alcanza con el consentimiento y las cláusulas de los proveedores, o hace falta algo más (cláusulas modelo de la AAIP, Disposición 60/2016)?
3. **GDPR**, si se vende en la UE: base legal de cada tratamiento (contrato, consentimiento, interés legítimo), si hace falta un representante en la UE (art. 27) y si el consentimiento para IA está bien planteado.
4. **Edad mínima:** el borrador pone 16 años (provisorio, para cubrir el máximo del GDPR). ¿Está bien? ¿Cambia algo para las compras de menores?
5. **Contenido generado por IA:** límites de responsabilidad por las chispas y el planificador (ideas, no consejo profesional), y la propiedad de lo generado.
6. **Defensa del consumidor (Ley 24.240):** botón de arrepentimiento y botón de baja, en suscripciones que cobra Apple o Google. ¿Alcanza con remitir a la tienda?
7. **Jurisdicción y ley aplicable:** el borrador pone ley argentina y tribunales de la Ciudad de Buenos Aires, sin quitar los derechos del consumidor de su domicilio. Confirmar.
8. **Identidad del titular** en los documentos (razón social, CUIT, domicilio), según lo que salga del contador.

## 4. Datos útiles

- Qué se guarda y por cuánto tiempo: `docs/legal/README.md` (inventario de datos).
- La app no usa publicidad, no rastrea entre apps y no vende datos.
- Los archivos (imágenes, PDFs, audios) se borran apenas se procesan; el texto crudo de cada nota, a los 30 días; las cuentas de invitado sin uso, a los 30 días.
- Exportar datos y borrar la cuenta se hace desde la app.
