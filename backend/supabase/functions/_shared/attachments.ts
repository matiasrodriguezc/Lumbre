// Imágenes y PDFs (paso 34, plan.md §6): límites antes de mandarlos al modelo.
//
// - El archivo vive solo en capture-temp mientras dura la captura; /capture lo borra siempre y /process barre lo que
//   haya quedado (una subida sin captura) a la hora.
// - Imágenes: la app las reduce antes de subirlas (lado largo de 1.568 px, unos 1.500 tokens). Acá solo se controla:
//   hasta 5 MB (límite de la API para una imagen) y hasta 8.000 px de lado.
// - PDFs: hasta 20 MB y MAX_PDF_PAGES páginas (provisorio: 30; el costo crece con cada página).
// Lo que se pasa de un límite no se destila: se guarda con la idea de la persona, sin gastar el cupo de destilación.

export const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
export const MAX_IMAGE_SIDE = 8000;
export const MAX_PDF_BYTES = 20 * 1024 * 1024;
export const MAX_PDF_PAGES = Number(Deno.env.get("LUMBRE_MAX_PDF_PAGES") ?? 30);

export type AttachmentMime = "image/jpeg" | "image/png" | "application/pdf";

export interface AttachmentCheck {
  ok: boolean;
  /** Por qué no se destila (para el log, sin contenido). */
  reason: "too_large" | "too_many_pages" | "image_too_big" | "not_a_pdf" | "not_an_image" | null;
  pages?: number;
  width?: number;
  height?: number;
}

/** Ancho y alto de un PNG (IHDR) o un JPEG (primer SOFn). Null si no se reconoce. */
export function imageSize(bytes: Uint8Array): { width: number; height: number } | null {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  // PNG: firma de 8 bytes, después IHDR con ancho y alto (big endian).
  if (bytes.length >= 24 && bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47) {
    return { width: view.getUint32(16), height: view.getUint32(20) };
  }
  // JPEG: segmentos FFxx hasta un SOF (C0–CF salvo C4, C8 y CC).
  if (bytes.length >= 4 && bytes[0] === 0xff && bytes[1] === 0xd8) {
    let i = 2;
    while (i + 9 < bytes.length) {
      if (bytes[i] !== 0xff) return null;
      const marker = bytes[i + 1];
      const length = view.getUint16(i + 2);
      if (marker >= 0xc0 && marker <= 0xcf && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc) {
        return { height: view.getUint16(i + 5), width: view.getUint16(i + 7) };
      }
      i += 2 + length;
    }
  }
  return null;
}

/**
 * Páginas de un PDF sin parsearlo entero: el mayor /Count de un nodo /Pages, o la cuenta de objetos /Type /Page.
 * Es una estimación (los PDF con object streams comprimidos pueden esconder los nodos): sirve para el tope.
 */
export function pdfPageCount(bytes: Uint8Array): number | null {
  const text = new TextDecoder("latin1").decode(bytes);
  if (!text.startsWith("%PDF-")) return null;
  let max = 0;
  for (const match of text.matchAll(/\/Type\s*\/Pages\b[^>]*?\/Count\s+(\d+)|\/Count\s+(\d+)[^>]*?\/Type\s*\/Pages\b/g)) {
    max = Math.max(max, Number(match[1] ?? match[2]));
  }
  const leaves = [...text.matchAll(/\/Type\s*\/Page(?![a-zA-Z])/g)].length;
  return Math.max(max, leaves);
}

export function checkAttachment(bytes: Uint8Array, mime: AttachmentMime): AttachmentCheck {
  if (mime === "application/pdf") {
    if (bytes.length > MAX_PDF_BYTES) return { ok: false, reason: "too_large" };
    const pages = pdfPageCount(bytes);
    if (pages === null) return { ok: false, reason: "not_a_pdf" };
    if (pages > MAX_PDF_PAGES) return { ok: false, reason: "too_many_pages", pages };
    return { ok: true, reason: null, pages };
  }
  if (bytes.length > MAX_IMAGE_BYTES) return { ok: false, reason: "too_large" };
  const size = imageSize(bytes);
  if (!size) return { ok: false, reason: "not_an_image" };
  if (size.width > MAX_IMAGE_SIDE || size.height > MAX_IMAGE_SIDE) return { ok: false, reason: "image_too_big", ...size };
  return { ok: true, reason: null, ...size };
}
