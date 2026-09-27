# NavBar
Navegación principal flotante con cinco elementos: una barra con los cuatro destinos y, separado a su derecha, el botón circular Capturar.

- Destinos en la barra: Hoy, Bóveda, Proyectos, Perfil. Capturar (+) es una acción, no un destino: va en su propio botón flotante, alineado con la barra y del mismo alto.
- La barra y el botón flotan sobre el contenido con un margen de `space-3` a los bordes y al fondo de la pantalla; el contenido pasa por debajo. Dejá un inset inferior en los scrolls para que el último elemento quede accesible.
- **iOS:** `TabView` nativa. En iOS 26 la barra ya es flotante y de Liquid Glass; sumá `.tabBarMinimizeBehavior(.onScrollDown)`. El botón + es un botón circular con `.glassEffect(.regular.tint(accent).interactive())` dentro de un `GlassEffectContainer` compartido con la barra, así las dos piezas se funden cuando se tocan. Alternativa: un `Tab` con `role: .search`, que el sistema ya ubica separado a la derecha, pero semánticamente es búsqueda. En versiones sin Liquid Glass, `.ultraThinMaterial` con la misma forma.
- **Android:** barra flotante tipo floating toolbar de Material 3 Expressive, con fondo `surface-alt` y elevación, y el destino activo expandido en pill `accent-soft` con ícono y etiqueta; los inactivos solo ícono. El + es un `FloatingActionButton` `accent` / `on-accent`, a la derecha de la barra. La API del floating toolbar está en evolución: verificá la versión de material3.
- Activo: `accent-text`. Inactivo: `ink` en iOS (sobre el vidrio), `ink-muted` en Android. El + usa `on-accent` sobre `accent`.
- Las etiquetas siguen siendo obligatorias para accesibilidad aunque en Android no se vean en los inactivos (`contentDescription`).
