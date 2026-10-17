import Foundation
import LumbreCore

/// Textos compartidos entre la app y el widget (App Intents, vistas del widget): tabla `Extensions`,
/// aparte del catálogo de la app.
func extensionsText(_ key: String.LocalizationValue) -> String {
    String(localized: key, table: "Extensions")
}

/// Buzón de links profundos para los App Intents que abren la app (`openAppWhenRun`).
/// El intent corre en el proceso de la app, a veces antes de que exista la interfaz: deja el link acá
/// y `ExtensionsBridge` lo consume en cuanto puede.
@MainActor
enum DeepLinkInbox {
    static let didReceive = Notification.Name("com.matiasrodriguezc.lumbre.deepLinkInbox")

    private static var pending: LumbreDeepLink?

    static func post(_ link: LumbreDeepLink) {
        pending = link
        NotificationCenter.default.post(name: didReceive, object: nil)
    }

    static func take() -> LumbreDeepLink? {
        defer { pending = nil }
        return pending
    }
}
