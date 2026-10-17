> **BORRADOR NO REVISADO POR UN ABOGADO.** Versión 0.1, 2026-10-16.

# Consentimiento para el uso de IA de terceros

Requisito de App Store (plan.md §10, guía 5.1.2(i)): pedir permiso explícito antes de mandar datos personales a una IA de terceros y nombrarla. Evento: `ai_consent_responded` (`docs/analytics.md`).

## Lo que muestra la app hoy

`ios/Lumbre/Features/Onboarding/WelcomeStepView.swift` (sheet `AIConsentSheet`, al empezar) y el interruptor de Perfil › Privacidad y datos (`ProfileSettingsViews.swift`).

> **Tus ideas y la IA**
> Para conceptualizar lo que guardás y encender las chispas, Lumbre manda el texto de tus ideas a Claude, una IA de Anthropic.
> · Solo se manda lo necesario para cada chispa: tus ideas y tu perfil creativo.
> · Podés cambiar esto cuando quieras en Perfil > Privacidad.
> · Si no aceptás, podés guardar ideas igual, pero las chispas y la conceptualización necesitan este permiso.
> [Leer la política de privacidad] · [Acepto] · [No acepto]

**Lo que está bien:** nombra a la IA y a la empresa, dice para qué, ofrece "No acepto" con el mismo peso y explica qué pasa si no aceptás; se puede cambiar después.

**Lo que falta, comparado con lo que el backend realmente hace:**
1. No menciona los **archivos** (imágenes y PDFs que se mandan a conceptualizar) ni el **planificador** (los mensajes van a la IA).
2. No menciona al **proveedor de embeddings**, que recibe el texto de cada idea y de cada búsqueda.
3. No dice que los datos se procesan **en Estados Unidos** (transferencia internacional, Ley 25.326 y GDPR).
4. No dice que Anthropic **no entrena** con estos datos, que es lo que más tranquiliza.
5. El footer del interruptor en Perfil dice "el texto de tus ideas y tu perfil creativo" y el sheet dice "el texto de tus ideas": conviene un solo texto.
6. El consentimiento se guarda solo en el teléfono (`@AppStorage("aiConsent")`). Para poder demostrarlo, guardarlo también en el servidor con fecha y versión del texto (cambio de app y backend, fuera de este paso).

## Texto propuesto (es)

**Título:** Tus ideas y la IA

**Cuerpo:** Para conceptualizar lo que guardás, encender las chispas y responder en el planificador, Lumbre manda tu contenido a Claude, una IA de Anthropic.

**Puntos:**
- Se manda solo lo necesario para cada tarea: el texto de tus ideas, los archivos que elijas conceptualizar, tus mensajes al planificador y tu perfil creativo.
- Se procesa en servidores de Estados Unidos. Anthropic no usa estos datos para entrenar sus modelos.
- Para buscar y conectar ideas, el texto de cada idea también pasa por un servicio de embeddings, que lo convierte en números.
- Si no aceptás, podés guardar ideas igual, pero no se conceptualizan ni se encienden chispas. Podés cambiarlo cuando quieras en Perfil › Privacidad y datos.

**Link:** Leer la política de privacidad
**Botones:** Acepto · No acepto

**Footer del interruptor en Perfil › Privacidad y datos:** Lumbre manda el texto de tus ideas, los archivos que elijas conceptualizar, tus mensajes al planificador y tu perfil creativo a Claude, una IA de Anthropic, en Estados Unidos. Sin este permiso podés guardar ideas, pero no se conceptualizan ni se encienden chispas.

## Proposed text (en)

**Title:** Your ideas and AI

**Body:** To conceptualize what you save, light up sparks and reply in the planner, Lumbre sends your content to Claude, an AI by Anthropic.

**Points:**
- Only what each task needs is sent: the text of your ideas, any files you choose to conceptualize, your planner messages and your creative profile.
- It's processed on servers in the United States. Anthropic doesn't use this data to train its models.
- To search and connect ideas, the text of each idea also goes through an embeddings service that turns it into numbers.
- If you decline, you can still save ideas, but they won't be conceptualized and no sparks will light up. You can change this anytime in Profile › Privacy and data.

**Link:** Read the privacy policy
**Buttons:** I agree · I don't agree

**Toggle footer in Profile › Privacy and data:** Lumbre sends the text of your ideas, files you choose to conceptualize, your planner messages and your creative profile to Claude, an AI by Anthropic, in the United States. Without this permission you can save ideas, but they won't be conceptualized and no sparks will light up.

## Notas para implementar (otro paso)

- Las claves nuevas van a `design/copy/` para que lleguen al String Catalog y a `strings.xml`.
- Si cambia el texto, sube la versión del consentimiento y se vuelve a pedir.
- La frase sobre el entrenamiento depende de los términos vigentes de Anthropic: verificarla antes de publicar.
