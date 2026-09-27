import Foundation
import LumbreCore

/// A qué backend se conecta la app.
enum AppEnvironment {
    /// Proyecto `lumbre-dev` de Supabase. La clave publicable es pública por diseño: el acceso lo controla RLS.
    static let supabaseURL = URL(string: "https://udewtaksxfnnchuhydnr.supabase.co")!
    static let supabasePublishableKey = "sb_publishable_ADEMGV9zODm5gMuz4MDXmg_9Z0by8-m"

    /// Supabase por defecto. Con el argumento de arranque `-mock`, los datos de prueba sin red.
    static func makeAPI(arguments: [String] = ProcessInfo.processInfo.arguments) -> any LumbreAPI {
        if arguments.contains("-mock") {
            return MockLumbreAPI()
        }
        #if DEBUG
        // `-resetSession`: arranca sin sesión, para probar el primer login sin borrar el Keychain del simulador.
        let resetSession = arguments.contains("-resetSession")
        #else
        let resetSession = false
        #endif
        return SupabaseLumbreAPI(
            url: supabaseURL,
            publishableKey: supabasePublishableKey,
            devCredentials: devCredentials,
            resetSession: resetSession
        )
    }

    /// Login de desarrollo: `Resources/DevCredentials.plist` (fuera del repo) con `email` y `password`.
    /// Solo en Debug. Sin el archivo, la app entra como invitado.
    private static var devCredentials: SupabaseLumbreAPI.DevCredentials? {
        #if DEBUG
        guard
            let url = Bundle.main.url(forResource: "DevCredentials", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String],
            let email = plist["email"], let password = plist["password"]
        else { return nil }
        return .init(email: email, password: password)
        #else
        return nil
        #endif
    }
}
