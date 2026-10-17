// POST /capture — guarda un concepto y lo procesa (pasos 24 a 27 y 34; contrato en backend/openapi.yaml).
//
// 1. Valida y, si hay adjunto, lo lee de capture-temp (y lo borra siempre, también si algo falla).
// 2. Si se pidió destilar y hay con qué (link, archivo o texto de 30+ palabras), descuenta `distill` y destila.
//    Confianza alta: ready; media: draft; baja o inaccesible: se guarda con la tesis de la persona o 422 needs_thesis.
//    Si la IA falla, devuelve el crédito y guarda con la tesis. Sin consentimiento para la IA (profiles.ai_consent_at)
//    no destila ni cobra: distillation = consent_required.
// 3. Guarda cada concepto con capture_concept() y el JWT del usuario: valida, descuenta la captura y crea la
//    categoría en una transacción, igual que si la app llamara directo.
// 4. Embedding y dominio de la categoría. Si fallan, el concepto queda guardado y /process lo completa.

import { requireDeviceIntegrity } from "../_shared/attest/guard.ts";
import { Analytics } from "../_shared/analytics.ts";
import { type Attachment, distill, type DistilledConcept } from "../_shared/ai/tasks.ts";
import { checkAttachment, MAX_PDF_BYTES } from "../_shared/attachments.ts";
import { toBase64 } from "../_shared/bytes.ts";
import { CONCEPT_COLUMNS, classifyCategory, embedConcepts } from "../_shared/data.ts";
import { ApiError, describeError, handler, json, readJson } from "../_shared/http.ts";
import { readLink } from "../_shared/links.ts";
import { logModeration, moderate } from "../_shared/moderation.ts";
import {
  admin,
  background,
  consumeCredit,
  dbError,
  effectivePlan,
  hasAIConsent,
  refundCredit,
  requireUser,
  rpc,
  type UserContext,
} from "../_shared/supabase.ts";
import { cleanText, wordCount } from "../_shared/text.ts";

const SOURCE_TYPES = ["text", "voice", "selection", "screenshot", "scan", "link", "image", "pdf"] as const;
const MIME_TYPES = ["image/jpeg", "image/png", "application/pdf"] as const;

type Outcome = "none" | "high" | "medium" | "quota_exceeded" | "unavailable" | "consent_required";

interface CaptureBody {
  thesis?: unknown;
  category?: unknown;
  source_type?: unknown;
  source_url?: unknown;
  source_title?: unknown;
  excerpt?: unknown;
  local_asset_id?: unknown;
  attachment?: { path?: unknown; mime_type?: unknown } | null;
  distill?: unknown;
}

function optionalString(value: unknown, max: number, code: "invalid_thesis" | "invalid_source" | "invalid_request"): string | null {
  if (value === undefined || value === null) return null;
  if (typeof value !== "string") throw new ApiError(code);
  const trimmed = value.trim();
  if (trimmed.length > max) throw new ApiError(code);
  return trimmed || null;
}

function parse(body: CaptureBody, userId: string) {
  if (typeof body.category !== "string" || !body.category.trim() || body.category.trim().length > 40) {
    throw new ApiError("invalid_category");
  }
  const sourceType = body.source_type;
  if (typeof sourceType !== "string" || !(SOURCE_TYPES as readonly string[]).includes(sourceType)) throw new ApiError("invalid_source");
  const thesis = optionalString(body.thesis, 600, "invalid_thesis");
  const sourceUrl = optionalString(body.source_url, 2048, "invalid_source");
  if (sourceUrl && !/^https?:\/\/\S+$/i.test(sourceUrl)) throw new ApiError("invalid_source");
  if (sourceType === "link" && !sourceUrl) throw new ApiError("invalid_source");

  let attachment: { path: string; mimeType: (typeof MIME_TYPES)[number] } | null = null;
  if (body.attachment) {
    const path = body.attachment.path;
    const mime = body.attachment.mime_type;
    if (
      typeof path !== "string" || !path.startsWith(`${userId}/`) || path.includes("..") ||
      typeof mime !== "string" || !(MIME_TYPES as readonly string[]).includes(mime)
    ) {
      throw new ApiError("invalid_source");
    }
    attachment = { path, mimeType: mime as (typeof MIME_TYPES)[number] };
  }

  return {
    thesis,
    category: body.category.trim(),
    sourceType: sourceType as (typeof SOURCE_TYPES)[number],
    sourceUrl,
    sourceTitle: optionalString(body.source_title, 300, "invalid_request"),
    // El fragmento se corta a 500 (la app ya lo corta).
    excerpt: typeof body.excerpt === "string" ? body.excerpt.trim().slice(0, 500) || null : null,
    localAssetId: optionalString(body.local_asset_id, 200, "invalid_request"),
    attachment,
    distill: body.distill === true,
  };
}

type Input = ReturnType<typeof parse>;

/** Lee el adjunto. Null si se pasa de los límites para el modelo (paso 34): se guarda con la idea de la persona. */
async function readAttachment(path: string, mimeType: Attachment["mimeType"]): Promise<Attachment | null> {
  const { data, error } = await admin().storage.from("capture-temp").download(path);
  if (error || !data) throw new ApiError("invalid_source");
  if (data.size > MAX_PDF_BYTES) {
    console.log(JSON.stringify({ fn: "capture", attachment: "skipped", reason: "too_large", mime: mimeType }));
    return null;
  }
  const bytes = new Uint8Array(await data.arrayBuffer());
  const check = checkAttachment(bytes, mimeType);
  if (!check.ok) {
    console.log(JSON.stringify({ fn: "capture", attachment: "skipped", reason: check.reason, mime: mimeType, pages: check.pages ?? null }));
    return null;
  }
  return { mimeType, base64: toBase64(bytes) };
}

async function saveConcept(user: UserContext, input: Input, thesis: string) {
  const { data, error } = await user.client.rpc("capture_concept", {
    p_thesis: thesis,
    p_category: input.category,
    p_source_type: input.sourceType,
    p_source_url: input.sourceUrl,
    p_source_title: input.sourceTitle,
    p_excerpt: input.excerpt,
    p_local_asset_id: input.localAssetId,
  });
  if (error) throw dbError(error);
  const row = (data as Array<{ concept_id: string; category_id: string; category_created: boolean }>)[0];
  if (!row) throw new Error("capture_concept no devolvió fila");
  return row;
}

async function savedToday(userId: string): Promise<number> {
  const [clock] = await rpc<Array<{ local_date: string; timezone: string }>>(admin(), "user_clock", { p_user: userId });
  if (!clock) return 0;
  return await rpc<number>(admin(), "concepts_saved_since", { p_user: userId, p_start: clock.local_date, p_timezone: clock.timezone });
}

Deno.serve(handler("capture", async (req) => {
  const user = await requireUser(req);
  await requireDeviceIntegrity(req, "capture", user.id);
  const input = parse(await readJson<CaptureBody>(req), user.id);
  const analytics = new Analytics();

  try {
    const plan = await effectivePlan(user.id);
    const attachment = input.attachment ? await readAttachment(input.attachment.path, input.attachment.mimeType) : null;

    // ¿Hay algo para destilar? Los textos de menos de 30 palabras nunca se destilan.
    const longText = !input.sourceUrl && !input.attachment && wordCount(input.thesis) >= 30;
    const hasSource = input.sourceType === "link" || !!attachment || longText;
    let outcome: Outcome = "none";
    let distilled: DistilledConcept[] = [];
    let confidence: "high" | "medium" | null = null;
    let distillCharged = false;

    if (input.distill && hasSource && !(await hasAIConsent(user.id))) {
      // Sin el "Acepto" no sale nada hacia la IA: se guarda con la idea de la persona (o 422 needs_thesis).
      outcome = "consent_required";
    } else if (input.distill && hasSource) {
      const inputCheck = await moderate([input.thesis, input.excerpt].filter(Boolean).join(" "));
      logModeration("capture", "input", inputCheck);
      if (inputCheck.flagged) {
        outcome = "none";
      } else if (!(await consumeCredit(user.id, "distill"))) {
        outcome = "quota_exceeded";
        analytics.track("quota_reached", user.id, { kind: "distill", plan });
      } else {
        distillCharged = true;
        try {
          // Primero lo que llegó en la captura; la página completa solo completa.
          const link = input.sourceType === "link" && input.sourceUrl ? await readLink(input.sourceUrl) : null;
          const sourceText = link?.text || (longText ? cleanText(input.thesis ?? "", 2500) : null);
          const result = await distill({
            userThesis: longText ? null : input.thesis,
            excerpt: input.excerpt,
            sourceType: input.sourceType,
            sourceUrl: input.sourceUrl,
            sourceTitle: input.sourceTitle ?? link?.title ?? null,
            sourceText: sourceText || link?.description || null,
          }, attachment, user.id);
          if (result.confidence !== "low" && result.concepts.length > 0) {
            distilled = result.concepts;
            confidence = result.confidence;
            outcome = result.confidence;
          }
        } catch (error) {
          console.warn(JSON.stringify({ fn: "capture", level: "warn", distill: "failed", error: describeError(error) }));
          await refundCredit(user.id, "distill");
          distillCharged = false;
          outcome = "unavailable";
        }
      }
    }

    // Sin destilación útil (confianza baja o contenido inaccesible) no se cobra: la persona no recibió nada.
    if (distilled.length === 0 && distillCharged) {
      await refundCredit(user.id, "distill");
      distillCharged = false;
    }
    // Y hace falta su idea.
    if (distilled.length === 0 && !input.thesis) {
      if (outcome === "unavailable") throw new ApiError("ai_unavailable");
      if (hasSource || input.distill || input.attachment) throw new ApiError("needs_thesis");
      throw new ApiError("invalid_thesis");
    }

    const before = await savedToday(user.id);
    const saved: Array<{ concept_id: string; category_id: string; category_created: boolean }> = [];
    try {
      if (distilled.length === 0) {
        saved.push(await saveConcept(user, input, input.thesis!));
      } else {
        for (const concept of distilled) {
          const row = await saveConcept(user, input, concept.thesis);
          saved.push(row);
          const { error } = await admin().from("concepts").update({
            title: concept.title,
            principle: concept.principle || null,
            distilled: true,
            confidence,
            status: confidence === "high" ? "ready" : "draft",
            // El texto crudo es lo que escribió o subrayó la persona, nunca la página completa.
            raw_text: input.thesis ?? input.excerpt,
          }).eq("id", row.concept_id);
          if (error) throw dbError(error);
        }
      }
    } catch (error) {
      // Si no se guardó nada, la destilación no se cobra.
      if (saved.length === 0 && distillCharged) await refundCredit(user.id, "distill");
      throw error;
    }

    // Embedding y dominio: si fallan, /process los completa después.
    const ids = saved.map((s) => s.concept_id);
    const categoryId = saved[0].category_id;
    try {
      const { data: rows, error } = await admin().from("concepts").select("id,user_id,title,thesis,principle,distilled").in("id", ids);
      if (error) throw dbError(error);
      await embedConcepts(admin(), rows ?? [], user.id);
      await classifyCategory(admin(), categoryId, user.id);
    } catch (error) {
      console.warn(JSON.stringify({ fn: "capture", level: "warn", embed: "deferred", error: describeError(error) }));
    }

    const { data: concepts, error: loadError } = await admin().from("concepts").select(CONCEPT_COLUMNS).in("id", ids);
    if (loadError) throw dbError(loadError);
    // deno-lint-ignore no-explicit-any
    const ordered = ids.map((id) => (concepts as any[]).find((c) => c.id === id)).filter(Boolean);

    // Eventos (sin contenido).
    for (const concept of ordered) {
      analytics.track("concept_saved", user.id, {
        source_type: input.sourceType,
        distilled: concept.distilled,
        confidence: concept.confidence,
        domain: concept.category?.domain?.slug ?? null,
        status: concept.status,
        concepts_in_capture: ordered.length,
        is_seed: false,
        category_created: saved[0].category_created,
      });
    }
    if (saved[0].category_created) {
      const { count } = await admin().from("categories").select("id", { count: "exact", head: true }).eq("user_id", user.id);
      analytics.track("category_created", user.id, { categories_count: count ?? 0 });
    }
    if (plan === "free") {
      const after = before + saved.length;
      const earnedBefore = Math.min(2, Math.floor(before / 3));
      const earnedAfter = Math.min(2, Math.floor(after / 3));
      if (earnedAfter > earnedBefore) analytics.track("extra_spark_earned", user.id, { earned_today: earnedAfter });
    }

    return json({
      concept_id: saved[0].concept_id,
      category_id: categoryId,
      category_created: saved[0].category_created,
      concepts: ordered,
      distillation: outcome,
    });
  } finally {
    // El archivo nunca queda guardado.
    if (input.attachment) {
      const { error } = await admin().storage.from("capture-temp").remove([input.attachment.path]);
      if (error) console.warn(JSON.stringify({ fn: "capture", level: "warn", remove_failed: error.message }));
    }
    await background(analytics.flush());
  }
}));
