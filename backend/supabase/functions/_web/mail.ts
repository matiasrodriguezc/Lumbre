// Emails de la waitlist detrás de una interfaz: cambiar de proveedor es sumar un Mailer, no tocar las funciones.
//
// - mailpit: el buzón de prueba del stack local (http://127.0.0.1:55524). Es el default en local.
// - log: no manda nada; deja una línea en el log sin el email ni el link (solo el tipo de mail).
// El proveedor real se elige con las cuentas de H1 y se suma como otra clase.

export interface Mail {
  to: string;
  subject: string;
  text: string;
  html: string;
}

export interface Mailer {
  readonly name: string;
  send(mail: Mail): Promise<void>;
}

const FROM_EMAIL = Deno.env.get("LUMBRE_MAIL_FROM") ?? "hola@lumbre.local";
const FROM_NAME = Deno.env.get("LUMBRE_MAIL_FROM_NAME") ?? "Lumbre";

class MailpitMailer implements Mailer {
  readonly name = "mailpit";
  constructor(private baseUrl: string) {}

  async send(mail: Mail): Promise<void> {
    const response = await fetch(`${this.baseUrl.replace(/\/$/, "")}/api/v1/send`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        From: { Email: FROM_EMAIL, Name: FROM_NAME },
        To: [{ Email: mail.to }],
        Subject: mail.subject,
        Text: mail.text,
        HTML: mail.html,
        Tags: ["waitlist"],
      }),
      signal: AbortSignal.timeout(5000),
    });
    await response.body?.cancel();
    if (!response.ok) throw new Error(`mailpit ${response.status}`);
  }
}

class LogMailer implements Mailer {
  readonly name = "log";
  send(_mail: Mail): Promise<void> {
    console.log(JSON.stringify({ fn: "mail", provider: "log", sent: false }));
    return Promise.resolve();
  }
}

function isLocalStack(): boolean {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  return /^http:\/\/(kong|127\.0\.0\.1|localhost|host\.docker\.internal)(:\d+)?/.test(url);
}

let mailer: Mailer | null = null;

/** LUMBRE_MAIL_PROVIDER = mailpit | log. Sin la variable: mailpit en el stack local, log en cualquier otro lado. */
export function getMailer(): Mailer {
  if (mailer) return mailer;
  const choice = Deno.env.get("LUMBRE_MAIL_PROVIDER") || (isLocalStack() ? "mailpit" : "log");
  mailer = choice === "mailpit"
    ? new MailpitMailer(Deno.env.get("MAILPIT_URL") ?? "http://supabase_inbucket_lumbre:8025")
    : new LogMailer();
  return mailer;
}

// ---------------------------------------------------------------
// Plantillas
// ---------------------------------------------------------------
export interface WaitlistMailData {
  locale: "es" | "en";
  /** Link con el token de confirmación: confirma y muestra la fila. */
  link: string;
  /** Link para compartir (?ref=código). */
  shareLink: string;
  position: number;
  boost: number;
  confirmed: boolean;
}

const COPY = {
  es: {
    newSubject: "Confirmá tu lugar en la fila de Lumbre",
    againSubject: "Tu link de la fila de Lumbre",
    newIntro: (n: number) => `Estás en el puesto ${n} de la fila de Lumbre.`,
    againIntro: (n: number) => `Ya estabas en la fila de Lumbre: hoy estás en el puesto ${n}.`,
    confirm: "Confirmá tu email para guardar tu lugar:",
    see: "Desde este link ves tu puesto y tu link para compartir:",
    button: (confirmed: boolean) => confirmed ? "Ver mi puesto" : "Confirmar mi lugar",
    share: (boost: number) => `Cada persona que se anote con tu link y confirme su email te sube ${boost} puestos:`,
    ignore: "Si no fuiste vos, ignorá este mail: sin confirmar, el email se borra solo en 30 días.",
    leave: "¿Te querés bajar de la fila? Desde el mismo link podés salir y borrar tu email.",
  },
  en: {
    newSubject: "Confirm your spot in the Lumbre line",
    againSubject: "Your link to the Lumbre line",
    newIntro: (n: number) => `You're number ${n} in the Lumbre line.`,
    againIntro: (n: number) => `You were already in the Lumbre line: today you're number ${n}.`,
    confirm: "Confirm your email to keep your spot:",
    see: "This link shows your spot and your link to share:",
    button: (confirmed: boolean) => confirmed ? "See my spot" : "Confirm my spot",
    share: (boost: number) => `Every person who joins with your link and confirms moves you up ${boost} spots:`,
    ignore: "If this wasn't you, ignore this email: unconfirmed emails are deleted after 30 days.",
    leave: "Want out? The same link lets you leave the line and delete your email.",
  },
} as const;

function escapeHtml(text: string): string {
  return text.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]!));
}

export function waitlistMail(to: string, kind: "new" | "again", data: WaitlistMailData): Mail {
  const c = COPY[data.locale];
  const subject = kind === "new" ? c.newSubject : c.againSubject;
  const intro = kind === "new" ? c.newIntro(data.position) : c.againIntro(data.position);
  const action = data.confirmed ? c.see : c.confirm;

  const text = [
    intro,
    "",
    action,
    data.link,
    "",
    c.share(data.boost),
    data.shareLink,
    "",
    c.leave,
    data.confirmed ? "" : c.ignore,
    "",
    "Lumbre",
  ].join("\n").replace(/\n{3,}/g, "\n\n");

  // HTML simple y con estilos en línea (los clientes de mail no leen hojas de estilo). Paleta Gris neurona:
  // fondo gris, tinta negra, botón negro con texto claro; el rosa solo en el punto del wordmark.
  const p = (t: string, extra = "") =>
    `<p style="margin:0 0 16px;font:400 16px/1.5 -apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#0E0E10;${extra}">${t}</p>`;
  const html = `<!doctype html><html lang="${data.locale}"><body style="margin:0;padding:0;background:#E3E3DF">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#E3E3DF"><tr><td align="center" style="padding:32px 16px">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:520px">
<tr><td style="padding:0 0 24px;font:600 28px/1 Georgia,'Times New Roman',serif;color:#0E0E10">Lumbre<span style="color:#FF3EA5">.</span></td></tr>
<tr><td>
${p(escapeHtml(intro), "font-size:18px;font-weight:600")}
${p(escapeHtml(action))}
<p style="margin:0 0 24px"><a href="${escapeHtml(data.link)}" style="display:inline-block;background:#0E0E10;color:#F2F2EF;text-decoration:none;font:600 16px/1 -apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;padding:16px 22px;border-radius:999px">${escapeHtml(c.button(data.confirmed))}</a></p>
${p(escapeHtml(c.share(data.boost)))}
${p(`<a href="${escapeHtml(data.shareLink)}" style="color:#0E0E10">${escapeHtml(data.shareLink)}</a>`)}
${p(escapeHtml(c.leave), "color:#5A5A5E;font-size:14px")}
${data.confirmed ? "" : p(escapeHtml(c.ignore), "color:#5A5A5E;font-size:14px")}
</td></tr></table></td></tr></table></body></html>`;

  return { to, subject, text, html };
}
