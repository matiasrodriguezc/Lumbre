import LumbreCore
import LumbreDesign
import SwiftUI

@main
struct LumbreApp: App {
    @AppStorage("theme") private var theme: ThemePreference = .dark

    init() {
        LumbreAppearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(theme.colorScheme)
                .tint(Palette.accentText)
        }
    }
}

extension EnvironmentValues {
    /// Backend de la app. Hasta el paso 43 es el de prueba.
    @Entry var api: any LumbreAPI = MockLumbreAPI()
}
