> **BORRADOR NO REVISADO POR UN ABOGADO.** No publicar. Versión 0.1, 2026-10-16. Los corchetes son datos a completar (ver `README.md`).

# Política de privacidad de Lumbre

Vigente desde [FECHA].

Lumbre es una app para guardar ideas y conectarlas. Para funcionar necesita guardar lo que escribís y mandarlo a una inteligencia artificial. Esta política explica qué datos se guardan, para qué, con quién se comparten, cuánto tiempo se conservan y cómo los controlás.

## 1. Quién es responsable

El responsable de tus datos es [TITULAR], [CUIT], con domicilio en [DOMICILIO], Argentina ("Lumbre", "nosotros"). Para cualquier consulta sobre tus datos: [EMAIL DE PRIVACIDAD].

Esta política se aplica a la app de Lumbre para iOS y Android, al sitio [DOMINIO], a la lista de espera y a la demo web.

## 2. Qué datos guardamos

**Tu cuenta.**
- Tu email, para que puedas entrar con un link o un código.
- Si entrás con Apple o Google, lo que esos servicios nos mandan: tu email (o el email privado de Apple), y a veces tu nombre y tu foto de perfil. No usamos el nombre ni la foto para nada.
- Si entrás como invitado, no te pedimos ningún dato: se crea una cuenta anónima.

**Tu perfil.** Los perfiles creativos que elegís, la hora a la que querés recibir la chispa, tu zona horaria, tu idioma y tu plan (gratis o Pro). No usamos tu ubicación: la zona horaria la toma la app del teléfono.

**Lo que guardás en Lumbre.**
- Tus neuronas: el texto de cada idea, el título, el principio y la categoría.
- La fuente: el tipo (texto, voz, link, imagen, PDF), el link y el título de la página, y el fragmento que hayas subrayado (hasta 500 caracteres).
- El texto completo de lo que capturaste, solo por 30 días (ver 6).
- Si guardás una foto o una captura, guardamos una referencia para volver a mostrarla en tu teléfono. La foto queda en tu teléfono.
- Una representación numérica de cada idea (un "embedding"), que sirve para buscar y para elegir qué ideas conectar. No se puede leer como texto.
- Tus chispas, si las guardaste o descartaste, y el motivo cuando tocás "No me sirve".
- Tus circuitos y tus conversaciones con el planificador.
- Los reportes que hagas sobre contenido generado por la IA.

**Archivos.** Si mandás una imagen o un PDF para destilar, se guarda en un almacenamiento temporal, se procesa y **se borra enseguida**, haya salido bien o no. No guardamos tus archivos, audios ni páginas completas.

**Voz.** El dictado por voz se transcribe en tu teléfono con las funciones del sistema. A Lumbre llega solo el texto.

**Uso de la app.** Eventos de uso como "guardó una neurona" o "abrió una chispa", con tu id de usuario, el tipo de acción, cantidades en rangos y datos técnicos (plataforma, versión, idioma, tema). **Nunca incluyen lo que escribís**: ni textos, ni títulos, ni links, ni búsquedas, ni mensajes.

**Errores.** Cuando la app falla, un informe técnico del error (dispositivo, sistema operativo, versión de la app, dónde falló), sin el contenido de tus notas.

**Notificaciones.** El token que Apple o Google le dan a tu teléfono para recibir la chispa del día.

**Compras.** Si te suscribís a Pro, el pago lo procesa Apple o Google. Nosotros no vemos tu tarjeta: recibimos de ellos (a través de RevenueCat) el tipo de suscripción, su estado y sus fechas.

**Uso de la IA.** Por cada llamada a la IA registramos la función, el modelo, la cantidad de tokens, el costo y cuánto tardó, para controlar costos y abusos. No registramos el contenido.

**Lista de espera y demo web.** Si te anotás en la lista de espera, guardamos tu email, tu código de referido, quién te invitó (si alguien lo hizo), tu idioma y de qué campaña llegaste. En la demo web, las dos ideas que pegás se mandan a la IA para armar la chispa y **no se guardan**; solo registramos que ese email ya usó la demo del día. Para frenar abusos guardamos tu IP en forma cifrada (un hash, que no permite recuperarla) por un día.

## 3. Para qué los usamos

| Para qué | Datos | Base legal |
|---|---|---|
| Darte el servicio: guardar tus ideas, destilarlas, generar chispas, buscar, el planificador, sincronizar entre dispositivos | Cuenta, perfil, lo que guardás | Ejecución del contrato (los términos) y tu consentimiento para la IA (sección 4) |
| Mandarte la chispa a la hora que elegiste | Token de push, hora, zona horaria | Ejecución del contrato; podés apagarlas en el teléfono |
| Cobrar y activar Pro | Compras | Ejecución del contrato |
| Aplicar los límites de cada plan y evitar abusos | Cupos, registro de llamadas a la IA, IP cifrada (web) | Interés legítimo en que el servicio funcione y no se abuse |
| Moderar contenido generado por IA | Reportes | Interés legítimo y obligaciones de las tiendas |
| Mejorar la app | Eventos de uso, errores | Interés legítimo (sin contenido, sin publicidad) |
| Avisarte del lanzamiento | Lista de espera | Tu consentimiento al anotarte |

No usamos tus datos para publicidad, no los vendemos, no hacemos perfiles para terceros y no te rastreamos entre apps o sitios. No entrenamos modelos de IA propios con tu contenido.

## 4. La inteligencia artificial

Lumbre usa **Claude**, de **Anthropic, PBC** (Estados Unidos), para:
- **Destilar:** convertir lo que guardás (un texto, un link, una imagen o un PDF) en una neurona con título, tesis y principio.
- **Generar chispas:** a partir de dos de tus neuronas y tu perfil creativo.
- **El planificador** (Pro): tus mensajes, la chispa, las dos neuronas que la originaron y tu perfil creativo.

Para buscar y emparejar ideas, el texto de cada neurona y de cada búsqueda se manda a un proveedor de embeddings, [PROVEEDOR DE EMBEDDINGS] (Estados Unidos), que lo convierte en números.

Antes de mandar tu contenido a la IA te pedimos permiso en la app. Si no aceptás, podés usar Lumbre para guardar ideas, pero no se destilan ni se generan chispas. Podés cambiar tu respuesta cuando quieras en Perfil › Privacidad y datos.

Se manda solo lo necesario para cada tarea. Según sus términos comerciales vigentes, Anthropic no usa los datos que recibe por su API para entrenar sus modelos y los conserva por un plazo limitado para seguridad. [VERIFICAR el texto y el plazo vigentes antes de publicar.]

El contenido que generan las chispas y el planificador lo produce una IA: puede ser impreciso, incompleto u obvio. Usalo como punto de partida, no como consejo profesional.

## 5. Con quién compartimos datos

Solo con proveedores que los tratan por cuenta nuestra, para dar el servicio, con contratos que los obligan a protegerlos:

| Proveedor | Para qué | Dónde |
|---|---|---|
| Supabase | Base de datos, autenticación y almacenamiento temporal | [REGIÓN DE PROD] |
| Anthropic | IA: destilación, chispas, planificador, demo web | Estados Unidos |
| [PROVEEDOR DE EMBEDDINGS] | Embeddings para búsqueda y emparejamiento | Estados Unidos |
| PostHog | Analítica de uso, sin contenido | Unión Europea |
| Sentry | Informes de errores | Estados Unidos |
| RevenueCat | Gestión de suscripciones | Estados Unidos |
| Apple y Google | Inicio de sesión, pagos y notificaciones | Estados Unidos |
| [PROVEEDOR DE EMAIL] | Emails de acceso y de la lista de espera | [PAÍS] |

Además, podemos revelar datos si una autoridad competente lo exige por ley, o para defender nuestros derechos ante un uso ilegal del servicio. Si Lumbre cambia de dueño, tus datos pasan al nuevo responsable con esta misma política, y te avisamos antes.

## 6. Cuánto tiempo los guardamos

| Dato | Plazo |
|---|---|
| Archivos para destilar (imágenes, PDFs) | Se borran apenas se procesan |
| Texto completo de cada captura | 30 días; después queda solo la neurona destilada |
| Cuenta y todo lo que guardaste | Hasta que lo borres o borres la cuenta |
| Cuentas de invitado | Se borran solas a los 30 días sin usarlas |
| Registros de uso de la IA y de suscripciones | Se conservan para contabilidad y control de costos, sin tu id después de borrar la cuenta |
| Informes de errores | Hasta 90 días |
| Lista de espera | Hasta [6 meses] después del lanzamiento, o hasta que pidas la baja |
| IP cifrada de la web | 1 día |
| Copias de seguridad | Hasta [7] días; lo borrado desaparece de ellas en ese plazo |

## 7. Tus derechos y cómo ejercerlos

Podés, cuando quieras:
- **Exportar tus datos** desde la app (Perfil › Privacidad y datos › Exportar mis datos): un archivo JSON con tu perfil, categorías, neuronas, chispas, circuitos y conversaciones del planificador.
- **Corregir** tus neuronas, categorías y perfil desde la app.
- **Borrar** una neurona, una chispa o un circuito desde la app.
- **Borrar tu cuenta** desde la app (Perfil › Privacidad y datos › Borrar cuenta) o desde [DOMINIO]/borrar-cuenta. Se borra tu cuenta y todo lo que guardaste, de inmediato y sin vuelta atrás; también tu perfil en la herramienta de analítica. Si tenés una suscripción, cancelala en tu cuenta de Apple o Google: borrar la cuenta no la cancela.
- **Retirar el consentimiento** para la IA desde la app.
- **Pedir acceso, rectificación, supresión, oposición o portabilidad**, o cualquier consulta, escribiendo a [EMAIL DE PRIVACIDAD]. Respondemos dentro de los 10 días hábiles para el acceso y 5 días hábiles para rectificación o supresión (Ley 25.326), y en todo caso dentro de un mes.

**Argentina.** El titular de los datos personales tiene la facultad de ejercer el derecho de acceso a los mismos en forma gratuita a intervalos no inferiores a seis meses, salvo que se acredite un interés legítimo al efecto, conforme lo establecido en el artículo 14, inciso 3 de la Ley 25.326. La Agencia de Acceso a la Información Pública, en su carácter de Órgano de Control de la Ley 25.326, tiene la atribución de atender las denuncias y reclamos que interpongan quienes resulten afectados en sus derechos por incumplimiento de las normas vigentes en materia de protección de datos personales. [Confirmar el texto exacto exigido con el abogado.]

**Unión Europea y Reino Unido.** Tenés además derecho a limitar el tratamiento y a presentar un reclamo ante la autoridad de protección de datos de tu país. [Representante en la UE, si corresponde: a definir con el abogado.]

## 8. Transferencias internacionales

Tus datos se tratan fuera de Argentina, en los países de la tabla de la sección 5. Al usar Lumbre y aceptar el uso de la IA, consentís estas transferencias. Para los proveedores en países sin un nivel de protección adecuado usamos las garantías que ofrecen (cláusulas contractuales tipo). [Revisar con el abogado: Disposición 60/2016 de la AAIP y cláusulas tipo de la UE.]

## 9. Seguridad

Todo viaja cifrado (HTTPS). Cada usuario solo puede leer sus propios datos (reglas de acceso en la base, probadas automáticamente). Las claves de la IA viven solo en nuestros servidores, nunca en la app. Los registros técnicos no incluyen el contenido de tus notas. La sesión se guarda en el llavero cifrado del teléfono. Ningún sistema es infalible: si hubiera una filtración que te afecte, te avisamos y avisamos a la autoridad según la ley.

## 10. Menores

Lumbre no está dirigida a menores de 16 años y no recolectamos a sabiendas datos de menores de esa edad. Si sabés que un menor nos dio sus datos, escribinos y los borramos.

## 11. Cambios

Si cambiamos esta política, publicamos la versión nueva con su fecha. Si el cambio es importante (por ejemplo, un proveedor de IA nuevo o un uso nuevo de tus datos), te avisamos en la app antes de que se aplique y, si hace falta, te pedimos el consentimiento de nuevo.

## 12. Contacto

[TITULAR] · [DOMICILIO] · [EMAIL DE PRIVACIDAD]
