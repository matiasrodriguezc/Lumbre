// POST /send-pushes — interna (pg_cron cada 5 minutos): avisa a quien le llegó la hora de su chispa diaria.
//
// - APNs con token JWT (ES256): APNS_KEY_ID, APNS_TEAM_ID, APNS_PRIVATE_KEY (.p8) y APNS_BUNDLE_ID.
//   El entorno (sandbox o producción) sale de cada token. Un token que APNs rechaza se borra.
// - Sin claves de APNs: solo loguea (sin contenido) y marca igual, para que el flujo se pueda probar en local.
// - Android (FCM) llega con la app de Android: por ahora sus tokens se loguean.
// El texto de la push es genérico: el contenido de la chispa no sale del servidor.

import { Analytics } from "../_shared/analytics.ts";
import { describeError, handler, json } from "../_shared/http.ts";
import { admin, dbError, requireService, rpc } from "../_shared/supabase.ts";

interface Due {
  spark_id: string;
  user_id: string;
  spark_hour: string;
  locale: string;
}

const COPY: Record<string, { title: string; body: string }> = {
  es: { title: "Tu chispa de hoy", body: "Dos ideas tuyas chocaron. Abrí Lumbre para verla." },
  en: { title: "Today's spark", body: "Two of your ideas collided. Open Lumbre to see it." },
};

function base64url(bytes: Uint8Array | string): string {
  const raw = typeof bytes === "string" ? new TextEncoder().encode(bytes) : bytes;
  let binary = "";
  for (const b of raw) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

let cachedJwt: { token: string; issuedAt: number } | null = null;

/** JWT de proveedor de APNs. Apple pide renovarlo entre 20 y 60 minutos: se reusa 40. */
async function apnsJwt(keyId: string, teamId: string, privateKeyPem: string): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt && now - cachedJwt.issuedAt < 40 * 60) return cachedJwt.token;
  const pem = privateKeyPem.replace(/\\n/g, "\n").replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const header = base64url(JSON.stringify({ alg: "ES256", kid: keyId }));
  const claims = base64url(JSON.stringify({ iss: teamId, iat: now }));
  const signature = new Uint8Array(
    await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(`${header}.${claims}`)),
  );
  const token = `${header}.${claims}.${base64url(signature)}`;
  cachedJwt = { token, issuedAt: now };
  return token;
}

interface Apns {
  keyId: string;
  teamId: string;
  privateKey: string;
  bundleId: string;
}

function apnsConfig(): Apns | null {
  const keyId = Deno.env.get("APNS_KEY_ID");
  const teamId = Deno.env.get("APNS_TEAM_ID");
  const privateKey = Deno.env.get("APNS_PRIVATE_KEY");
  const bundleId = Deno.env.get("APNS_BUNDLE_ID");
  return keyId && teamId && privateKey && bundleId ? { keyId, teamId, privateKey, bundleId } : null;
}

/** Devuelve "sent", "invalid" (token a borrar) o "failed". */
async function sendApns(apns: Apns, token: string, sandbox: boolean, due: Due): Promise<"sent" | "invalid" | "failed"> {
  const host = sandbox ? "https://api.sandbox.push.apple.com" : "https://api.push.apple.com";
  const copy = COPY[due.locale] ?? COPY.es;
  const response = await fetch(`${host}/3/device/${token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${await apnsJwt(apns.keyId, apns.teamId, apns.privateKey)}`,
      "apns-topic": apns.bundleId,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "apns-collapse-id": "daily-spark",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      aps: { alert: copy, sound: "default", "thread-id": "daily-spark" },
      type: "daily_spark",
      spark_id: due.spark_id,
      sent_at: new Date().toISOString(),
    }),
    signal: AbortSignal.timeout(10_000),
  });
  if (response.ok) {
    await response.body?.cancel();
    return "sent";
  }
  const reason = (await response.json().catch(() => ({}))) as { reason?: string };
  if (response.status === 410 || reason.reason === "BadDeviceToken" || reason.reason === "Unregistered") return "invalid";
  console.warn(JSON.stringify({ fn: "send-pushes", level: "warn", apns_status: response.status, reason: reason.reason ?? null }));
  return "failed";
}

Deno.serve(handler("send-pushes", async (req) => {
  requireService(req);
  const apns = apnsConfig();
  const analytics = new Analytics();
  const due = await rpc<Due[]>(admin(), "due_spark_pushes", { p_limit: 500 });
  const summary = { due: due.length, sent: 0, logged: 0, invalid_tokens: 0, failed: 0 };

  for (const item of due) {
    try {
      const { data: tokens, error } = await admin().from("push_tokens").select("token,platform,sandbox").eq("user_id", item.user_id);
      if (error) throw dbError(error);
      let delivered = false;
      for (const t of tokens ?? []) {
        if (t.platform === "ios" && apns) {
          const result = await sendApns(apns, t.token, t.sandbox, item);
          if (result === "sent") delivered = true;
          if (result === "invalid") {
            await admin().from("push_tokens").delete().eq("token", t.token);
            summary.invalid_tokens++;
          }
          if (result === "failed") summary.failed++;
        }
      }
      if (!apns || (tokens ?? []).every((t) => t.platform !== "ios")) {
        // Sin claves (o solo Android por ahora): se loguea sin contenido y se marca igual.
        console.log(JSON.stringify({ fn: "send-pushes", push: "logged", spark_id: item.spark_id, tokens: (tokens ?? []).length }));
        summary.logged++;
      } else if (delivered) {
        summary.sent++;
      }
      await admin().from("sparks").update({ notified_at: new Date().toISOString() }).eq("id", item.spark_id);
      if (delivered || !apns) {
        analytics.track("spark_notification_sent", item.user_id, { scheduled_hour: Number(item.spark_hour.slice(0, 2)) });
      }
    } catch (error) {
      summary.failed++;
      console.error(JSON.stringify({ fn: "send-pushes", level: "error", error: describeError(error) }));
    }
  }

  await analytics.flush();
  console.log(JSON.stringify({ fn: "send-pushes", ...summary }));
  return json(summary);
}));
