// POST /today — todo lo que muestra Hoy (contrato: Today).
//
// - La chispa diaria del día local del usuario. Si el batch nocturno no la generó, se genera en el momento
//   (par por SQL + texto). La diaria no gasta cupos: tampoco la del invitado, que es el loop principal.
//   Con el proveedor local no cuesta nada; con Anthropic cuenta para el tope diario en dólares.
// - Cupo: la diaria cuenta como disponible mientras está pending o revealed, más las extra que quedan.
// - refills_at: la próxima hora de la chispa en su zona. concepts_until_extra: lo que falta hoy para ganar una extra (free).

import { Analytics } from "../_shared/analytics.ts";
import { loadSpark, loadSparks } from "../_shared/data.ts";
import { describeError, handler, json } from "../_shared/http.ts";
import { generateSpark } from "../_shared/sparks.ts";
import { admin, background, dbError, requireUser, rpc } from "../_shared/supabase.ts";

interface Clock {
  local_date: string;
  day_started_at: string;
  spark_due: boolean;
  next_spark_at: string;
  timezone: string;
  plan: "guest" | "free" | "pro";
}

interface Credit {
  kind: string;
  period: string;
  max_count: number;
  available: number;
  used: number;
  remaining: number;
}

Deno.serve(handler("today", async (req) => {
  const user = await requireUser(req);
  const analytics = new Analytics();
  const [clock] = await rpc<Clock[]>(admin(), "user_clock", { p_user: user.id });
  if (!clock) throw dbError({ message: "perfil inexistente" });

  const findDaily = async () =>
    (await loadSparks(admin(), (q) => q.eq("user_id", user.id).eq("mode", "daily").eq("scheduled_for", clock.local_date).limit(1)))[0] ?? null;

  let spark = await findDaily();
  if (!spark) {
    try {
      const created = await generateSpark(user.id, "daily", analytics, { scheduledFor: clock.local_date });
      // Si otra llamada la creó a la vez, se usa esa.
      spark = created?.id ? await loadSpark(admin(), created.id) : await findDaily();
    } catch (error) {
      console.error(JSON.stringify({ fn: "today", level: "error", generate: "failed", error: describeError(error) }));
      spark = await findDaily();
    }
  }

  // Extras y elegidas de hoy (día local), de la más nueva a la más vieja.
  const extras = await loadSparks(admin(), (q) =>
    q.eq("user_id", user.id).in("mode", ["extra", "pick"]).gte("created_at", clock.day_started_at).order("created_at", { ascending: false })
  );

  const { data: credits, error: creditsError } = await user.client.rpc("credit_status");
  if (creditsError) throw dbError(creditsError);
  const extra = (credits as Credit[]).find((c) => c.kind === "spark_extra");
  const { data: limit } = await admin().from("plan_limits")
    .select("earned_every,max_count").eq("plan", clock.plan).eq("kind", "spark_extra").maybeSingle();

  const savedToday = await rpc<number>(admin(), "concepts_saved_since", {
    p_user: user.id, p_start: clock.local_date, p_timezone: clock.timezone,
  });
  // Free: conceptos que faltan para la próxima extra; 0 si ya ganó el máximo del día o si no gana extras.
  let conceptsUntilExtra = 0;
  if (limit?.earned_every) {
    const earned = Math.floor(savedToday / limit.earned_every);
    if (earned < limit.max_count) conceptsUntilExtra = limit.earned_every - (savedToday % limit.earned_every);
  }

  const dailyAvailable = spark && (spark.status === "pending" || spark.status === "revealed") ? 1 : 0;
  const extraRemaining = extra?.remaining ?? 0;

  const [runway, countResult] = await Promise.all([
    rpc<number>(admin(), "spark_runway_days", { p_user: user.id }),
    admin().from("concepts").select("id", { count: "exact", head: true }).eq("user_id", user.id),
  ]);

  await background(analytics.flush());
  return json({
    spark,
    quota: {
      available: dailyAvailable + extraRemaining,
      total: 1 + (extra?.available ?? 0),
      refills_at: clock.next_spark_at,
      concepts_until_extra: conceptsUntilExtra,
      extra_remaining: extraRemaining,
    },
    extras,
    runway_days: runway ?? 0,
    concept_count: countResult.count ?? 0,
  });
}));
