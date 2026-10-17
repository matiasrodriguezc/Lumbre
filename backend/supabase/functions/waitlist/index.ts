// POST /waitlist — la fila de la landing (paso 5). Pública (verify_jwt = false): la llama la web sin sesión.
//
// { action: "join", email, ref?, locale?, utm?: { source, medium, campaign }, website (trampa), elapsed_ms }
//   → { status: "joined", token, entry } si el email es nuevo (y le llega el mail de confirmación)
//   → { status: "check_email" } si ya estaba (le reenviamos su link) o si parece un bot (no se guarda nada)
// { action: "status", token, confirm? } → { entry }. Con confirm y el token del mail, confirma el email.
// { action: "leave", token } → { status: "left" }. Borra el email.
//
// Anti-abuso: 10 altas por hora y 30 por día por IP, 3 reenvíos por día por email, 60 consultas por hora por IP,
// campo trampa y tiempo mínimo. Flag del servidor: app_config.web_waitlist_enabled.
// Logs sin emails ni tokens.

import { admin } from "../_shared/supabase.ts";
import { clientIp, enforce, looksLikeBot, requireFlag, subjectHash } from "../_web/abuse.ts";
import { readWebJson, WebError, webHandler, webJson, webLog } from "../_web/http.ts";
import { type Entry, hashToken, isToken, joinWaitlist, normalizeEmail, toPublic } from "../_web/waitlist.ts";

Deno.serve(webHandler("waitlist", async (req) => {
  await requireFlag("web_waitlist_enabled");
  const body = await readWebJson(req);
  const ip = await subjectHash("ip", clientIp(req));

  switch (body.action) {
    case "join": {
      await enforce(ip, [
        { bucket: "waitlist_join_hour", windowSeconds: 3600, max: 10 },
        { bucket: "waitlist_join_day", windowSeconds: 86_400, max: 30 },
      ]);
      if (looksLikeBot(body)) {
        webLog("waitlist", { event: "bot" });
        return webJson(req, { status: "check_email" });
      }
      const email = normalizeEmail(body.email);
      const { entry, token } = await joinWaitlist({
        email,
        referralCode: body.ref,
        locale: body.locale,
        source: "landing",
        utm: body.utm,
        resendIfExisting: true,
      });
      if (!token) return webJson(req, { status: "check_email" });
      return webJson(req, { status: "joined", token, entry: await toPublic(entry) });
    }

    case "status": {
      await enforce(ip, [{ bucket: "waitlist_status_hour", windowSeconds: 3600, max: 60 }]);
      if (!isToken(body.token)) throw new WebError("invalid_request");
      const confirm = body.confirm === true;
      const { data, error } = await admin().rpc("waitlist_status", { p_token_hash: await hashToken(body.token), p_confirm: confirm });
      if (error) throw new Error(`waitlist_status: ${error.message}`);
      const entry = data as Entry | null;
      if (!entry?.id) throw new WebError("not_found");
      if (confirm) webLog("waitlist", { event: "status", confirmed: entry.confirmed });
      return webJson(req, { entry: await toPublic(entry) });
    }

    case "leave": {
      await enforce(ip, [{ bucket: "waitlist_status_hour", windowSeconds: 3600, max: 60 }]);
      if (!isToken(body.token)) throw new WebError("invalid_request");
      const { data, error } = await admin().rpc("waitlist_leave", { p_token_hash: await hashToken(body.token) });
      if (error) throw new Error(`waitlist_leave: ${error.message}`);
      if (data !== true) throw new WebError("not_found");
      webLog("waitlist", { event: "left" });
      return webJson(req, { status: "left" });
    }

    default:
      throw new WebError("invalid_request");
  }
}));
