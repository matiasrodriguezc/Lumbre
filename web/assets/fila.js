// Página de la fila: "estás en el puesto N, compartí tu link".
//
// El token llega por el fragmento (#t= desde la web, #c= desde el mail, que además confirma el email)
// o queda guardado en este navegador. El fragmento no viaja al servidor ni a los logs; igual se borra de la barra.

import { api, copyText, errorText, setStatus, store, track } from "./lumbre.js";

const $ = (selector) => document.querySelector(selector);
const show = (name) => {
  for (const key of ["loading", "entry", "missing", "left"]) $(`[data-${key}]`).hidden = key !== name;
};

const TOKEN = /^[A-Za-z0-9_-]{43}$/;
const hash = new URLSearchParams(location.hash.slice(1));
const fromMail = hash.get("c");
const fromWeb = hash.get("t");
let token = [fromMail, fromWeb, store.get("token")].find((value) => value && TOKEN.test(value)) ?? null;
if (location.hash) history.replaceState(null, "", location.pathname + location.search);

const siteRoot = new URL("./", location.href).href;

function render(entry) {
  $("[data-position]").textContent = entry.position.toLocaleString("es-AR");
  $("[data-total]").textContent = `de ${entry.total.toLocaleString("es-AR")} ${entry.total === 1 ? "persona" : "personas"}`;
  $("[data-referrals]").textContent = String(entry.referrals);
  $("[data-boost]").textContent = `${entry.boost} puestos`;
  $("[data-share-lead]").textContent =
    `Cada persona que se anote con tu link y confirme su email te sube ${entry.boost} puestos.`;

  const confirmStatus = $("[data-confirm-status]");
  if (entry.confirmed) {
    setStatus(confirmStatus, "ok", fromMail ? "Email confirmado. Tu lugar quedó guardado." : "Email confirmado.");
  } else {
    setStatus(confirmStatus, "info", "Falta confirmar tu email: abrí el mail que te mandamos. Sin confirmar, tu lugar se borra en 30 días.");
  }

  const url = `${siteRoot}?ref=${entry.referral_code}`;
  const text = "Me anoté en Lumbre: cada mañana conecta dos de tus ideas y salta una chispa nueva. Anotate con mi link:";
  $("[data-share-url]").value = url;
  $('[data-channel="whatsapp"]').href = `https://wa.me/?text=${encodeURIComponent(`${text} ${url}`)}`;
  $('[data-channel="x"]').href = `https://x.com/intent/post?text=${encodeURIComponent(text)}&url=${encodeURIComponent(url)}`;
  $('[data-channel="email"]').href = `mailto:?subject=${encodeURIComponent("Probá Lumbre")}&body=${encodeURIComponent(`${text}\n${url}`)}`;

  const shareStatus = $("[data-share-status]");
  $("[data-copy]").onclick = async () => {
    if (await copyText(url)) {
      setStatus(shareStatus, "ok", "Link copiado.");
      track("referral_link_copied", { channel: "copy" });
    }
  };
  for (const link of document.querySelectorAll("[data-channel]")) {
    link.onclick = () => track("referral_link_copied", { channel: link.dataset.channel });
  }
  const native = $("[data-native]");
  if (navigator.share) {
    native.hidden = false;
    native.onclick = () => navigator.share({ title: "Lumbre", text, url }).catch(() => {});
  }
  show("entry");
}

async function load() {
  if (!token) {
    show("missing");
    return;
  }
  const { ok, data } = await api("waitlist", { action: "status", token, confirm: Boolean(fromMail) });
  if (!ok) {
    if (data.error === "not_found") store.remove("token");
    $("[data-missing-text]").textContent = errorText(data.error);
    show("missing");
    return;
  }
  store.set("token", token);
  render(data.entry);
}

$("[data-leave]").addEventListener("click", async () => {
  if (!token || !confirm("¿Salir de la fila? Se borra tu email y perdés tu puesto.")) return;
  const { ok, data } = await api("waitlist", { action: "leave", token });
  if (!ok) {
    setStatus($("[data-share-status]"), "error", errorText(data.error));
    return;
  }
  store.remove("token");
  token = null;
  show("left");
});

// Un link del mail abierto sobre esta misma página solo cambia el fragmento: se vuelve a cargar.
addEventListener("hashchange", () => location.reload());

load();
