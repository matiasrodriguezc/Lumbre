import Foundation
import LumbreCore

/// A qué backend se conecta la app.
///
/// - Debug: el Supabase local (`cd backend && supabase start`) por defecto; `-remote` usa `lumbre-dev`.
/// - Release: siempre `lumbre-dev` (staging y prod llegan con el paso 41).
/// - `-mock` y `-mockGuest`: los datos de prueba, sin red.
///
/// El cliente real va envuelto en `CachedLumbreAPI`: sin red, las pantallas muestran lo último que cargaron.
enum AppEnvironment {
    enum Backend {
        case local, remote

        var url: URL {
            switch self {
            case .local: URL(string: "http://127.0.0.1:55521")!
            case .remote: URL(string: "https://udewtaksxfnnchuhydnr.supabase.co")!
            }
        }

        /// Las claves publicables son públicas por diseño: el acceso lo controla RLS.
        /// La local es la fija de la CLI de Supabase (`supabase status`), igual en todas las máquinas.
        var publishableKey: String {
            switch self {
            case .local: "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH"
            case .remote: "sb_publishable_ADEMGV9zODm5gMuz4MDXmg_9Z0by8-m"
            }
        }
    }

    /// Argumentos de arranque (esquema → Run → Arguments, o `xcrun simctl launch … <arg>`):
    /// `-mock`, `-mockPro`, `-mockGuest`, `-remote`, `-resetSession` y `-seedUser` (ver `ios/README.md`).
    static func makeAPI(arguments: [String] = ProcessInfo.processInfo.arguments) -> any LumbreAPI {
        if let mock = makeMockAPI(arguments: arguments) {
            // Sin backend, la Share Extension y los atajos solo encolan; el widget igual muestra la chispa de prueba.
            LumbreShared.backend = nil
            return CachedLumbreAPI(wrapping: mock, storage: .inMemory, sharesWithExtensions: true)
        }
        #if DEBUG
        let backend: Backend = arguments.contains("-remote") ? .remote : .local
        // `-resetSession`: arranca sin sesión, para probar el primer login sin borrar el Keychain del simulador.
        let resetSession = arguments.contains("-resetSession")
        #else
        let backend = Backend.remote
        let resetSession = false
        #endif
        let api = SupabaseLumbreAPI(
            url: backend.url,
            publishableKey: backend.publishableKey,
            devCredentials: devCredentials(for: backend, arguments: arguments),
            resetSession: resetSession,
            keychainAccessGroup: LumbreShared.keychainAccessGroup
        )
        // Las extensiones mandan al mismo backend con la sesión que la app deja en el Keychain compartido.
        LumbreShared.backend = .init(url: backend.url, publishableKey: backend.publishableKey)
        // La caché del backend local va aparte, para no mezclar usuarios de dos bases distintas.
        let storage: CachedLumbreAPI.Storage = backend == .local
            ? .file(LumbreShared.containerURL.appending(path: "Cache-local.store"))
            : .shared
        return CachedLumbreAPI(wrapping: api, storage: storage)
    }

    private static func makeMockAPI(arguments: [String]) -> MockLumbreAPI? {
        // `-mockRunwayDays 3`: pocos pares buenos en Hoy (el aviso de capturar más y los temas puente).
        let runway = arguments.firstIndex(of: "-mockRunwayDays").flatMap { arguments.indices.contains($0 + 1) ? Int(arguments[$0 + 1]) : nil }
        if arguments.contains("-mockGuest") { return MockLumbreAPI(onboarded: false) }
        if arguments.contains("-mockPro") { return MockLumbreAPI(plan: .pro, runwayDays: runway) }
        if arguments.contains("-mock") { return MockLumbreAPI(runwayDays: runway) }
        return nil
    }

    /// Login de desarrollo, solo en Debug. Sin credenciales, la app entra como invitado.
    /// - Remoto: `Resources/DevCredentials.plist` (fuera del repo) con `email` y `password`.
    /// - Local: con `-seedUser`, Ana, la usuaria de `backend/supabase/seed.sql` (su contraseña está en el seed y solo existe en local).
    private static func devCredentials(for backend: Backend, arguments: [String]) -> SupabaseLumbreAPI.DevCredentials? {
        #if DEBUG
        switch backend {
        case .local:
            guard arguments.contains("-seedUser") else { return nil }
            return .init(email: "ana@lumbre.test", password: "lumbre-dev-local")
        case .remote:
            guard
                let url = Bundle.main.url(forResource: "DevCredentials", withExtension: "plist"),
                let data = try? Data(contentsOf: url),
                let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String],
                let email = plist["email"], let password = plist["password"]
            else { return nil }
            return .init(email: email, password: password)
        }
        #else
        return nil
        #endif
    }
}
