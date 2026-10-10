import LumbreCore
import LumbreDesign
import SwiftUI

@main
struct LumbreApp: App {
    @AppStorage("theme") private var theme: ThemePreference = .dark
    private let api = AppEnvironment.makeAPI()
    @State private var appModel = AppModel()

    init() {
        LumbreAppearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.api, api)
                .environment(appModel)
                .preferredColorScheme(theme.colorScheme)
                .tint(Palette.accentText)
        }
    }
}

extension EnvironmentValues {
    /// Backend de la app. Lo inyecta `LumbreApp` según `AppEnvironment`; las previews usan los datos de prueba.
    @Entry var api: any LumbreAPI = MockLumbreAPI()
    /// Cambia cada vez que se guarda algo, para que las pantallas vuelvan a cargar.
    @Entry var dataVersion: Int = 0
}
