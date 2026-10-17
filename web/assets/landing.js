// Landing: alta en la fila y demo de la chispa con el reveal de la sinapsis.

import { api, busy, campaign, captureCampaign, copyText, elapsedMs, errorText, loadFlags, locale, setStatus, store, t } from "./lumbre.js";

captureCampaign();
loadFlags();
if (store.get("ref")) document.querySelector("[data-ref-note]")?.removeAttribute("hidden");

const EMAIL = /^[^@\s]+@[^@\s.]+(\.[^@\s.]+)+$/;

function validEmail(input) {
  const ok = EMAIL.test(input.value.trim());
  input.setAttribute("aria-invalid", ok ? "false" : "true");
  return ok;
}

// ---------------------------------------------------------------
// Fila
// ---------------------------------------------------------------
for (const form of document.querySelectorAll("[data-join]")) {
  const status = form.parentElement.querySelector("[data-status]");
  const email = form.elements.email;
  email.addEventListener("input", () => email.removeAttribute("aria-invalid"));

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (!validEmail(email)) {
      setStatus(status, "error", t("error.invalid_email"));
      email.focus();
      return;
    }
    const button = form.querySelector("button[type=submit]");
    busy(button, true, t("join.sending"));
    setStatus(status, null, "");
    const { ref, utm } = campaign();
    const { ok, data } = await api("waitlist", {
      action: "join",
      email: email.value.trim(),
      ref,
      locale,
      utm,
      website: form.elements.website.value,
      elapsed_ms: elapsedMs(),
    });
    busy(button, false);
    if (ok && data.status === "joined") {
      store.set("token", data.token);
      location.href = "fila.html";
      return;
    }
    if (ok) {
      setStatus(status, "ok", t("join.check_email"));
      form.reset();
      return;
    }
    setStatus(status, "error", errorText(data.error));
  });
}

// ---------------------------------------------------------------
// Demo
// ---------------------------------------------------------------
const EXAMPLES = [
  ["Un flujo de aire en espiral separa el polvo por fuerza centrífuga, sin necesidad de filtro.",
   "Las aspiradoras pierden fuerza a medida que se llena la bolsa."],
  ["Los podcasts funcionan porque se escuchan mientras hacés otra cosa.",
   "Las ruinas romanas se entienden mejor caminándolas que leyendo sobre ellas."],
  ["Las hormigas encuentran el camino más corto dejando rastros que se refuerzan con el uso.",
   "En las reuniones largas, las decisiones importantes se toman en los últimos cinco minutos."],
];

const demo = document.querySelector("[data-demo]");
if (demo) {
  const status = demo.querySelector("[data-status]");
  const { idea_a: ideaA, idea_b: ideaB, email } = demo.elements;
  const button = demo.querySelector("button[type=submit]");

  const updateCounter = (area) => {
    const counter = demo.querySelector(`[data-counter="${area.id}"]`);
    if (counter) counter.textContent = `${area.value.length}/500`;
    area.removeAttribute("aria-invalid");
  };
  for (const area of [ideaA, ideaB]) area.addEventListener("input", () => updateCounter(area));
  email.addEventListener("input", () => email.removeAttribute("aria-invalid"));

  for (const chip of demo.querySelectorAll("[data-example]")) {
    chip.addEventListener("click", () => {
      const [a, b] = EXAMPLES[Number(chip.dataset.example)];
      ideaA.value = a;
      ideaB.value = b;
      updateCounter(ideaA);
      updateCounter(ideaB);
      (email.value ? button : email).focus();
    });
  }

  demo.addEventListener("submit", async (event) => {
    event.preventDefault();
    const missing = [ideaA, ideaB].filter((area) => area.value.trim().split(/\s+/).filter(Boolean).length < 2);
    for (const area of missing) area.setAttribute("aria-invalid", "true");
    const emailOk = validEmail(email);
    if (missing.length || !emailOk) {
      setStatus(status, "error", missing.length ? t("error.invalid_ideas") : t("error.invalid_email"));
      (missing[0] ?? email).focus();
      return;
    }

    busy(button, true, t("demo.sending"));
    button.classList.add("is-loading");
    setStatus(status, null, "");
    const { ref, utm } = campaign();
    const { ok, data } = await api("demo-spark", {
      email: email.value.trim(),
      idea_a: ideaA.value,
      idea_b: ideaB.value,
      ref,
      locale,
      utm,
      website: demo.elements.website.value,
      elapsed_ms: elapsedMs(),
    });
    busy(button, false);
    button.classList.remove("is-loading");
    if (data.waitlist?.status === "joined") store.set("token", data.waitlist.token);

    if (!ok) {
      setStatus(status, "error", errorText(data.error));
      return;
    }
    openReveal(data, button);
  });
}

// ---------------------------------------------------------------
// Reveal: modal a pantalla completa, sinapsis de 900 ms
// ---------------------------------------------------------------
function openReveal(data, returnFocus) {
  const template = document.getElementById("reveal-template");
  const veil = template.content.firstElementChild.cloneNode(true);
  const panel = veil.querySelector(".panel");
  veil.querySelector("[data-a]").textContent = data.ideas.a;
  veil.querySelector("[data-b]").textContent = data.ideas.b;
  veil.querySelector("[data-title]").textContent = data.spark.title;
  veil.querySelector("[data-body]").textContent = data.spark.body;

  const after = veil.querySelector("[data-after]");
  const message = document.createElement("p");
  const actions = document.createElement("div");
  actions.className = "panel__actions";
  if (data.waitlist?.status === "joined") {
    message.textContent = t("reveal.joined", data.waitlist.entry.position);
    const link = document.createElement("a");
    link.className = "btn btn--primary btn--sm";
    link.href = "fila.html";
    link.textContent = t("reveal.see_queue");
    actions.append(link);
  } else {
    message.textContent = t("reveal.existing");
  }
  const copy = document.createElement("button");
  copy.type = "button";
  copy.className = "btn btn--secondary btn--sm";
  copy.textContent = t("reveal.copy");
  copy.addEventListener("click", async () => {
    if (await copyText(`${data.spark.title}\n${data.spark.body}\n\nLumbre`)) copy.textContent = t("reveal.copied");
  });
  actions.append(copy);
  after.append(message, actions);

  const reduced = matchMedia("(prefers-reduced-motion: reduce)").matches;
  let revealed = false;
  const previousOverflow = document.body.style.overflow;
  document.body.style.overflow = "hidden";
  document.body.append(veil);
  panel.focus();

  setTimeout(() => {
    revealed = true;
    panel.classList.add("is-revealed");
  }, reduced ? 200 : 900);

  const close = () => {
    if (!revealed) return;
    veil.classList.add("is-closing");
    setTimeout(() => {
      veil.remove();
      document.body.style.overflow = previousOverflow;
      returnFocus?.focus();
    }, reduced ? 0 : 160);
    document.removeEventListener("keydown", onKey);
  };
  const onKey = (event) => {
    if (event.key === "Escape") close();
    if (event.key === "Tab") trapFocus(event, panel);
  };
  document.addEventListener("keydown", onKey);
  veil.addEventListener("click", (event) => { if (event.target === veil) close(); });
  veil.querySelector("[data-close]").addEventListener("click", close);
}

function trapFocus(event, container) {
  const focusable = [...container.querySelectorAll("a[href], button:not([disabled])")].filter((el) => el.offsetParent !== null);
  if (!focusable.length) return;
  const first = focusable[0];
  const last = focusable[focusable.length - 1];
  if (event.shiftKey && (document.activeElement === first || document.activeElement === container)) {
    event.preventDefault();
    last.focus();
  } else if (!event.shiftKey && document.activeElement === last) {
    event.preventDefault();
    first.focus();
  }
}
