import LumbreCore
import LumbreDesign
import SwiftUI

@main
struct LumbreApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("theme") private var theme: ThemePreference = .light

    init() {
        LumbreAppearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .extensionsBridge()
                .environment(\.api, appDelegate.api)
                .environment(\.purchases, appDelegate.purchases)
                .environment(appDelegate.appModel)
                .environment(\.neuralIdentity, FeatureFlag.neuralIdentity.isEnabled)
                .preferredColorScheme(theme.colorScheme)
                .tint(Palette.ink)
        }
    }

    /// Backend según `AppEnvironment` (`-mock`, `-mockGuest`, Supabase).
    static func makeAPI() -> any LumbreAPI {
        AppEnvironment.makeAPI()
    }

    /// StoreKit 2. En Debug, con `-mock` o `-mockGuest`, compras simuladas con los precios de plan.md §8
    /// (correr desde `simctl` no carga `Lumbre.storekit`; desde Xcode, el esquema sí).
    static func makePurchaseService(arguments: [String] = ProcessInfo.processInfo.arguments) -> any PurchaseService {
        #if DEBUG
        if arguments.contains("-mock") || arguments.contains("-mockGuest") {
            return PreviewPurchaseService()
        }
        #endif
        return StoreKitPurchaseService()
    }
}

extension EnvironmentValues {
    /// Backend de la app. Lo inyecta `LumbreApp` según `AppEnvironment`; las previews usan los datos de prueba.
    @Entry var api: any LumbreAPI = MockLumbreAPI()
    /// Cambia cada vez que se guarda algo, para que las pantallas vuelvan a cargar.
    @Entry var dataVersion: Int = 0
}
