// Alta en la waitlist, compartida por /waitlist (la landing) y /demo-spark (la demo también anota el email).

import { Analytics } from "../_shared/analytics.ts";
import { admin } from "../_shared/supabase.ts";
import { allowed, configValue, sha256Hex, subjectHash } from "./abuse.ts";
import { WebError, webLog } from "./http.ts";
import { getMailer, waitlistMail } from "./mail.ts";

export interface Entry {
  id: string;
  created: boolean;
  referral_code: string;
  position: number;
  total: number;
  referrals: number;
  confirmed: boolean;
}

/** Lo que ve el navegador. Nunca el email ni el id interno. */
export interface PublicEntry {
  referral_code: string;
  position: number;
  total: number;
  referrals: number;
  confirmed: boolean;
  boost: number;
}

export function siteUrl(): string {
  return (Deno.env.get("LUMBRE_SITE_URL") ?? "http://localhost:55580").replace(/\/$/, "");
}

export function shareLink(code: string): string {
  return `${siteUrl()}/?ref=${code}`;
}

export async function referralBoost(): Promise<number> {
  return Number(await configValue<number | string>("waitlist_referral_boost", 10)) || 10;
}

export async function toPublic(entry: Entry): Promise<PublicEntry> {
  return {
    referral_code: entry.referral_code,
    position: entry.position,
    total: entry.total,
    referrals: entry.referrals,
    confirmed: entry.confirmed,
    boost: await referralBoost(),
  };
}

const EMAIL = /^[^@\s]+@[^@\s.]+(\.[^@\s.]+)+$/;

export function normalizeEmail(raw: unknown): string {
  if (typeof raw !== "string") throw new WebError("invalid_email");
  const email = raw.trim().toLowerCase();
  if (email.length < 6 || email.length > 254 || !EMAIL.test(email)) throw new WebError("invalid_email");
  return email;
}

/** Token de 32 bytes aleatorios en base64url. */
export function newToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function isToken(value: unknown): value is string {
  return typeof value === "string" && /^[A-Za-z0-9_-]{43}$/.test(value);
}

export function hashToken(token: string): Promise<string> {
  return sha256Hex(token);
}

function shortText(value: unknown, max: number): string | null {
  if (typeof value !== "string") return null;
  const clean = value.replace(/[\u0000-\u001F\u007F]/g, "").trim();
  return clean ? clean.slice(0, max) : null;
}

export interface JoinInput {
  email: string;
  referralCode: unknown;
  locale: unknown;
  source: "landing" | "demo";
  utm: unknown;
  /** Si ya estaba, reenviarle su link por mail (la landing sí; la demo no, para no mandar un mail por chispa). */
  resendIfExisting: boolean;
}

export interface JoinResult {
  entry: Entry;
  /** Token de la página de la fila: solo si el email es nuevo. */
  token: string | null;
}

/**
 * Anota el email. Si es nuevo, manda el mail de confirmación y devuelve el token de su página.
 * Si ya estaba, no lo dice al navegador: le reenvía su link por mail (hasta 3 por día) y devuelve token null.
 */
export async function joinWaitlist(input: JoinInput): Promise<JoinResult> {
  const locale = input.locale === "en" ? "en" : "es";
  const utm = (input.utm && typeof input.utm === "object" ? input.utm : {}) as Record<string, unknown>;
  const code = typeof input.referralCode === "string" && /^[a-z2-9]{7}$/i.test(input.referralCode.trim())
    ? input.referralCode.trim().toLowerCase()
    : null;

  const token = newToken();
  const confirm = newToken();
  const { data, error } = await admin().rpc("waitlist_join", {
    p_email: input.email,
    p_token_hash: await hashToken(token),
    p_confirm_hash: await hashToken(confirm),
    p_referral_code: code,
    p_locale: locale,
    p_source: input.source,
    p_utm_source: shortText(utm.source, 100),
    p_utm_medium: shortText(utm.medium, 100),
    p_utm_campaign: shortText(utm.campaign, 100),
  });
  if (error) throw new Error(`waitlist_join: ${error.message}`);
  const entry = data as Entry;
  const boost = await referralBoost();

  if (entry.created) {
    await sendMail(input.email, "new", locale, confirm, entry, boost);
    const analytics = new Analytics();
    analytics.track("waitlist_joined", entry.id, {
      referred: code !== null,
      source: input.source,
      utm_source: shortText(utm.source, 100),
      utm_medium: shortText(utm.medium, 100),
      utm_campaign: shortText(utm.campaign, 100),
    });
    await analytics.flush();
    webLog("waitlist", { event: "joined", source: input.source, referred: code !== null });
    return { entry, token };
  }

  // Ya estaba: link nuevo por mail, con tope para que nadie use el formulario para llenarle el buzón a otro.
  if (input.resendIfExisting && await allowed(await subjectHash("email", input.email), { bucket: "waitlist_resend", windowSeconds: 86_400, max: 3 })) {
    const { error: rotateError } = await admin().rpc("waitlist_rotate_confirm", { p_id: entry.id, p_confirm_hash: await hashToken(confirm) });
    if (rotateError) throw new Error(`waitlist_rotate_confirm: ${rotateError.message}`);
    await sendMail(input.email, "again", locale, confirm, entry, boost);
  }
  webLog("waitlist", { event: "existing", source: input.source });
  return { entry, token: null };
}

async function sendMail(to: string, kind: "new" | "again", locale: "es" | "en", confirm: string, entry: Entry, boost: number) {
  const mailer = getMailer();
  try {
    await mailer.send(waitlistMail(to, kind, {
      locale,
      link: `${siteUrl()}/fila.html#c=${confirm}`,
      shareLink: shareLink(entry.referral_code),
      position: entry.position,
      boost,
      confirmed: entry.confirmed,
    }));
    webLog("waitlist", { event: "mail_sent", kind, provider: mailer.name });
  } catch (error) {
    // El alta queda igual: la persona puede pedir el link de nuevo anotándose otra vez.
    console.error(JSON.stringify({ fn: "waitlist", level: "error", event: "mail_failed", provider: mailer.name, error: String(error).slice(0, 200) }));
  }
}
