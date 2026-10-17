// Lo compartido por las páginas: llamadas a las Edge Functions, textos, flags, analytics y almacenamiento local.

import { config } from "./config.js";

// ---------------------------------------------------------------
// Textos (español primero; el inglés se suma con otra entrada)
// ---------------------------------------------------------------
const STRINGS = {
  es: {
    "error.network": "No hay conexión con Lumbre. Revisá tu internet y probá de nuevo.",
    "error.invalid_email": "Revisá el email: parece que le falta algo.",
    "error.invalid_ideas": "Escribí cada idea en una frase de al menos dos palabras.",
    "error.invalid_content": "Una de las ideas no se puede usar. Probá con otra.",
    "error.rate_limited": "Hubo muchos intentos desde esta conexión. Probá de nuevo en un rato.",
    "error.daily_limit": "Ya encendiste tu chispa de hoy. Mañana hay otra.",
    "error.demo_full": "Hoy se encendieron todas las chispas de la demo. Volvé mañana o anotate en la fila.",
    "error.ai_unavailable": "No pudimos encender la chispa. Probá de nuevo en un rato: no se te descontó la del día.",
    "error.disabled": "Esto está en pausa por ahora. Volvé en un rato.",
    "error.not_found": "No encontramos tu lugar en la fila. Puede que el link sea viejo: anotate de nuevo con tu email y te llega uno nuevo.",
    "error.invalid_request": "Algo no salió bien. Recargá la página y probá de nuevo.",
    "error.internal": "Algo falló de nuestro lado. Probá de nuevo en un rato.",
    "join.sending": "Anotando…",
    "join.check_email": "Listo. Revisá tu mail: ahí está tu link para ver tu puesto en la fila.",
    "demo.sending": "Encendiendo…",
    "demo.missing": "Completá las dos ideas y tu email.",
    "reveal.joined": (n) => `Estás en el puesto ${n} de la fila. Te mandamos un mail para confirmar tu lugar.`,
    "reveal.existing": "Ya estás en la fila de Lumbre. Mañana podés encender otra chispa.",
    "reveal.see_queue": "Ver mi puesto y mi link",
    "reveal.copy": "Copiar la chispa",
    "reveal.copied": "Chispa copiada",
    "share.copied": "Link copiado",
  },
};

const lang = document.documentElement.lang?.startsWith("en") ? "en" : "es";

export function t(key, ...args) {
  const value = (STRINGS[lang] ?? STRINGS.es)[key] ?? STRINGS.es[key] ?? key;
  return typeof value === "function" ? value(...args) : value;
}

export const locale = lang;

// ---------------------------------------------------------------
// Almacenamiento local (puede no estar: modo privado, bloqueado)
// ---------------------------------------------------------------
export const store = {
  get(key) {
    try { return localStorage.getItem(`lumbre.${key}`); } catch { return null; }
  },
  set(key, value) {
    try { localStorage.setItem(`lumbre.${key}`, value); } catch { /* sin almacenamiento */ }
  },
  remove(key) {
    try { localStorage.removeItem(`lumbre.${key}`); } catch { /* sin almacenamiento */ }
  },
};

// ---------------------------------------------------------------
// Edge Functions
// ---------------------------------------------------------------
export async function api(fn, body) {
  try {
    const response = await fetch(`${config.apiUrl}/${fn}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    let data = {};
    try { data = await response.json(); } catch { data = { error: "internal" }; }
    return { ok: response.ok, status: response.status, data };
  } catch {
    return { ok: false, status: 0, data: { error: "network" } };
  }
}

export function errorText(code) {
  const key = `error.${code}`;
  const text = t(key);
  return text === key ? t("error.internal") : text;
}

// ---------------------------------------------------------------
// Referidos y campaña: ?ref=código y utm_* quedan guardados para el alta
// ---------------------------------------------------------------
export function captureCampaign() {
  const params = new URLSearchParams(location.search);
  const ref = params.get("ref");
  if (ref && /^[a-z2-9]{7}$/i.test(ref)) store.set("ref", ref.toLowerCase());
  const utm = {};
  for (const key of ["source", "medium", "campaign"]) {
    const value = params.get(`utm_${key}`);
    if (value) utm[key] = value.slice(0, 100);
  }
  if (Object.keys(utm).length) store.set("utm", JSON.stringify(utm));
}

export function campaign() {
  let utm = {};
  try { utm = JSON.parse(store.get("utm") ?? "{}"); } catch { utm = {}; }
  return { ref: store.get("ref") ?? undefined, utm };
}

// ---------------------------------------------------------------
// Flags (PostHog opcional) y analytics sin cookies
// ---------------------------------------------------------------
const anonymousId = crypto.randomUUID ? crypto.randomUUID() : String(Math.random()).slice(2);

export async function loadFlags() {
  const flags = { ...config.flags };
  if (config.posthogKey) {
    try {
      const response = await fetch(`${config.posthogHost}/decide/?v=3`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ api_key: config.posthogKey, distinct_id: anonymousId }),
      });
      const data = await response.json();
      for (const key of Object.keys(flags)) {
        if (typeof data.featureFlags?.[key] === "boolean") flags[key] = data.featureFlags[key];
      }
    } catch { /* sin PostHog: valores por defecto */ }
  }
  for (const el of document.querySelectorAll("[data-flag]")) el.hidden = flags[el.dataset.flag] === false;
  for (const el of document.querySelectorAll("[data-flag-off]")) el.hidden = flags[el.dataset.flagOff] !== false;
  return flags;
}

/** Evento de la web (docs/analytics.md, fuente W). Sin clave de PostHog no sale nada. Nunca lleva emails ni ideas. */
export function track(event, properties = {}, distinctId = anonymousId) {
  if (!config.posthogKey) return;
  const body = JSON.stringify({
    api_key: config.posthogKey,
    event,
    distinct_id: distinctId,
    properties: { ...properties, platform: "web", $process_person_profile: false },
  });
  try {
    navigator.sendBeacon?.(`${config.posthogHost}/capture/`, new Blob([body], { type: "application/json" })) ||
      fetch(`${config.posthogHost}/capture/`, { method: "POST", body, keepalive: true });
  } catch { /* analytics nunca rompe la página */ }
}

// ---------------------------------------------------------------
// UI
// ---------------------------------------------------------------
const ICONS = {
  error: '<svg viewBox="0 0 18 18" aria-hidden="true"><circle cx="9" cy="9" r="8" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M9 5v5" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/><circle cx="9" cy="13" r="1.1" fill="currentColor"/></svg>',
  ok: '<svg viewBox="0 0 18 18" aria-hidden="true"><circle cx="9" cy="9" r="8" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M5.5 9.2l2.3 2.3 4.7-4.9" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  info: '<svg viewBox="0 0 18 18" aria-hidden="true"><circle cx="9" cy="9" r="8" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M9 8v5" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/><circle cx="9" cy="5" r="1.1" fill="currentColor"/></svg>',
};

/** Mensaje de estado con ícono y palabra (nunca solo color). */
export function setStatus(el, kind, text) {
  if (!el) return;
  if (!text) {
    el.hidden = true;
    el.textContent = "";
    return;
  }
  el.className = `status status--${kind}`;
  el.innerHTML = ICONS[kind] ?? "";
  const span = document.createElement("span");
  span.textContent = text;
  el.append(span);
  el.hidden = false;
}

export function busy(button, on, label) {
  button.disabled = on;
  button.setAttribute("aria-busy", on ? "true" : "false");
  const target = button.querySelector("[data-label]") ?? button;
  if (on) {
    button.dataset.idle = target.textContent;
    target.textContent = label;
  } else if (button.dataset.idle) {
    target.textContent = button.dataset.idle;
  }
}

export async function copyText(text) {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    const area = document.createElement("textarea");
    area.value = text;
    area.setAttribute("readonly", "");
    area.style.position = "fixed";
    area.style.opacity = "0";
    document.body.append(area);
    area.select();
    const ok = document.execCommand("copy");
    area.remove();
    return ok;
  }
}

/** Milisegundos desde que se mostró la página (el servidor descarta envíos de menos de 1,5 s). */
const shownAt = performance.now();
export function elapsedMs() {
  return Math.round(performance.now() - shownAt);
}
