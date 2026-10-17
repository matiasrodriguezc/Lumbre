// Lectura de links (paso 26): Open Graph y texto principal de una página.
//
// - El contenido de la página es siempre DATOS, nunca instrucciones: se devuelve como texto plano y el prompt
//   de destilación lo delimita y lo dice explícito (prompts/distill.v1.ts).
// - Timeout, límite de tamaño y solo http(s) a hosts públicos (sin localhost ni redes privadas).
// - Primero se usa lo que llegó en la captura (fragmento, texto compartido): esto solo completa.

import { cleanText, truncateWords } from "./text.ts";

export interface LinkContent {
  url: string;
  title: string | null;
  description: string | null;
  siteName: string | null;
  /** Texto principal, limpio y cortado. Vacío si no se pudo leer. */
  text: string;
  /** false: la página no respondió, no es HTML o está detrás de un login. */
  accessible: boolean;
}

const TIMEOUT_MS = 8000;
const MAX_BYTES = 1_500_000;
const MAX_WORDS = 2500;
const MAX_REDIRECTS = 4;

export function isPrivateHost(hostname: string): boolean {
  const host = hostname.toLowerCase().replace(/^\[|\]$/g, "");
  if (host === "localhost" || host.endsWith(".localhost") || host.endsWith(".local") || host.endsWith(".internal")) return true;
  if (host.includes(":")) {
    // IPv6: loopback, sin especificar, únicas locales (fc00::/7) y de enlace (fe80::/10). IPv4 dentro de IPv6 (::ffff:a.b.c.d).
    const mapped = host.match(/^::ffff:(\d+\.\d+\.\d+\.\d+)$/);
    if (mapped) return isPrivateHost(mapped[1]);
    return host === "::1" || host === "::" || /^(fc|fd|fe8|fe9|fea|feb)[0-9a-f]*:/.test(host);
  }
  const ipv4 = host.match(/^(\d+)\.(\d+)\.(\d+)\.(\d+)$/);
  if (ipv4) {
    const [a, b] = [Number(ipv4[1]), Number(ipv4[2])];
    return a === 0 || a === 10 || a === 127 || (a === 169 && b === 254) || (a === 172 && b >= 16 && b <= 31) ||
      (a === 192 && b === 168) || (a === 100 && b >= 64 && b <= 127) || a >= 224;
  }
  // Sin punto (kong, db, host.docker.internal sin TLD público…): nunca es un sitio público.
  return !host.includes(".");
}

async function resolvesToPrivate(hostname: string): Promise<boolean> {
  const resolve = (Deno as unknown as { resolveDns?: (h: string, t: string) => Promise<string[]> }).resolveDns;
  if (!resolve) return false;
  try {
    const addresses = [
      ...(await resolve(hostname, "A").catch(() => [] as string[])),
      ...(await resolve(hostname, "AAAA").catch(() => [] as string[])),
    ];
    return addresses.some(isPrivateHost);
  } catch {
    return false;
  }
}

export async function isFetchableUrl(raw: string): Promise<boolean> {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    return false;
  }
  if (url.protocol !== "http:" && url.protocol !== "https:") return false;
  if (url.username || url.password) return false;
  if (isPrivateHost(url.hostname)) return false;
  return !(await resolvesToPrivate(url.hostname));
}

const ENTITIES: Record<string, string> = {
  amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " ", iexcl: "¡", iquest: "¿", laquo: "«", raquo: "»",
  ldquo: "“", rdquo: "”", lsquo: "‘", rsquo: "’", mdash: "—", ndash: "–", hellip: "…", middot: "·", deg: "°",
};
// Vocales con tilde, diéresis, eñe y cedilla (&aacute; &Ntilde; &uuml; …).
for (const [base, marks] of Object.entries({ a: "\u0301\u0300\u0308\u0302", e: "\u0301\u0300\u0308\u0302", i: "\u0301\u0300\u0308\u0302", o: "\u0301\u0300\u0308\u0302", u: "\u0301\u0300\u0308\u0302", n: "\u0303", c: "\u0327" })) {
  const names: Record<string, string> = { "\u0301": "acute", "\u0300": "grave", "\u0308": "uml", "\u0302": "circ", "\u0303": "tilde", "\u0327": "cedil" };
  for (const mark of marks) {
    ENTITIES[`${base}${names[mark]}`] = `${base}${mark}`.normalize("NFC");
    ENTITIES[`${base.toUpperCase()}${names[mark]}`] = `${base.toUpperCase()}${mark}`.normalize("NFC");
  }
}

function decodeEntities(text: string): string {
  return text.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (whole, entity: string) => {
    if (entity[0] === "#") {
      const code = entity[1].toLowerCase() === "x" ? parseInt(entity.slice(2), 16) : parseInt(entity.slice(1), 10);
      return Number.isFinite(code) && code > 0 && code < 0x110000 ? String.fromCodePoint(code) : " ";
    }
    return ENTITIES[entity] ?? ENTITIES[entity.toLowerCase()] ?? whole;
  });
}

function meta(html: string, key: string): string | null {
  const re = new RegExp(
    `<meta[^>]+(?:property|name)=["']${key}["'][^>]*content=["']([^"']*)["']|<meta[^>]+content=["']([^"']*)["'][^>]*(?:property|name)=["']${key}["']`,
    "i",
  );
  const match = html.match(re);
  const value = match ? (match[1] ?? match[2]) : null;
  return value ? decodeEntities(value).trim() || null : null;
}

/** Texto principal: <article> o <main> si hay; si no, el body sin navegación, scripts ni estilos. */
export function extractMainText(html: string): string {
  let body = html
    .replace(/<!--[\s\S]*?-->/g, " ")
    .replace(/<(script|style|noscript|svg|nav|header|footer|aside|form|iframe|template)\b[\s\S]*?<\/\1>/gi, " ");
  const article = body.match(/<article\b[\s\S]*?<\/article>/i) ?? body.match(/<main\b[\s\S]*?<\/main>/i);
  if (article) body = article[0];
  else body = body.match(/<body\b[\s\S]*<\/body>/i)?.[0] ?? body;
  const text = decodeEntities(
    body
      .replace(/<(br|\/p|\/div|\/li|\/h[1-6]|\/section)\b[^>]*>/gi, "\n")
      .replace(/<[^>]+>/g, " "),
  );
  return text.replace(/[ \t]+/g, " ").replace(/ ?\n ?/g, "\n").replace(/\n\s*\n+/g, "\n").trim();
}

export async function readLink(rawUrl: string): Promise<LinkContent> {
  const empty: LinkContent = { url: rawUrl, title: null, description: null, siteName: null, text: "", accessible: false };
  if (!(await isFetchableUrl(rawUrl))) return empty;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    // Los redirects se siguen a mano: cada salto se revisa antes de pedirlo, así un redirect a una red privada
    // nunca llega a hacerse (con redirect: "follow" el pedido ya habría salido).
    let current = rawUrl;
    let response: Response | null = null;
    for (let hop = 0; hop <= MAX_REDIRECTS; hop++) {
      if (hop > 0 && !(await isFetchableUrl(current))) return empty;
      response = await fetch(current, {
        signal: controller.signal,
        redirect: "manual",
        headers: {
          "User-Agent": "LumbreBot/1.0 (+https://lumbre.app/bot)",
          "Accept": "text/html,application/xhtml+xml;q=0.9,text/plain;q=0.8",
          "Accept-Language": "es,en;q=0.8",
        },
      });
      if (response.status < 300 || response.status >= 400) break;
      const location = response.headers.get("location");
      await response.body?.cancel();
      if (!location) return empty;
      current = new URL(location, current).toString();
      response = null;
    }
    if (!response) return empty;
    const type = response.headers.get("content-type") ?? "";
    if (!response.ok || !/text\/html|application\/xhtml|text\/plain/i.test(type)) {
      await response.body?.cancel();
      return empty;
    }

    // Lee hasta MAX_BYTES y corta.
    const reader = response.body!.getReader();
    const chunks: Uint8Array[] = [];
    let size = 0;
    while (size < MAX_BYTES) {
      const { done, value } = await reader.read();
      if (done) break;
      chunks.push(value);
      size += value.byteLength;
    }
    await reader.cancel().catch(() => {});
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) {
      bytes.set(chunk.subarray(0, Math.min(chunk.byteLength, size - offset)), offset);
      offset += chunk.byteLength;
    }
    const html = new TextDecoder("utf-8", { fatal: false }).decode(bytes);

    if (/text\/plain/i.test(type)) {
      return { ...empty, accessible: true, text: truncateWords(cleanText(html, MAX_WORDS), MAX_WORDS) };
    }
    const title = meta(html, "og:title") ?? decodeEntities(html.match(/<title[^>]*>([\s\S]*?)<\/title>/i)?.[1] ?? "").trim() ?? null;
    const description = meta(html, "og:description") ?? meta(html, "description");
    const siteName = meta(html, "og:site_name");
    const text = cleanText(extractMainText(html), MAX_WORDS);
    return {
      url: rawUrl,
      title: title || null,
      description,
      siteName,
      text,
      accessible: text.split(" ").length >= 30 || !!description,
    };
  } catch {
    return empty;
  } finally {
    clearTimeout(timer);
  }
}
