// Configuración de la web. Lo único que cambia entre local y producción. No hay claves secretas acá:
// las Edge Functions son públicas (verify_jwt = false) y validan su propio anti-abuso.

const LOCAL = ["localhost", "127.0.0.1", "[::1]"].includes(location.hostname) || location.hostname.endsWith(".localhost");

export const config = {
  // Edge Functions de Supabase. En producción, la URL del proyecto de prod (paso 41).
  apiUrl: LOCAL ? "http://127.0.0.1:55521/functions/v1" : "https://PROYECTO.supabase.co/functions/v1",

  // PostHog (opcional). Sin clave, no se carga nada ni se manda ningún evento.
  posthogKey: "",
  posthogHost: "https://eu.i.posthog.com",

  // Valores por defecto de los flags de la web. Con PostHog, se pisan con los flags web_waitlist y web_demo_spark.
  // El servidor tiene además sus propios interruptores en app_config (web_waitlist_enabled, web_demo_enabled).
  flags: {
    web_waitlist: true,
    web_demo_spark: true,
  },
};
