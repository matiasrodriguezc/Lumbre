import LumbreCore
import LumbreDesign
import os
import SwiftUI

/// Consentimiento para mandar ideas a una IA de terceros (plan.md §10, App Store 5.1.2).
/// Vive en el teléfono (`@AppStorage("aiConsent")`, nil = todavía no respondió) y se copia a la cuenta con
/// `LumbreAPI.setAIConsent` para que el servidor también lo respete.
///
/// Sin un "Acepto" explícito la app no pide nada que use IA: ni conceptualizar, ni chispas extra o elegidas, ni el
/// planificador, ni la chispa del día (`/today` la genera si falta). Guardar ideas sigue andando.
enum AIConsent {
    static let storageKey = "aiConsent"
    /// Último valor que se copió a la cuenta, para no repetirlo en cada arranque.
    private static let syncedKey = "aiConsent.synced"
    private static let logger = Logger(subsystem: "com.matiasrodriguezc.lumbre", category: "consent")

    static var current: Bool? { UserDefaults.standard.object(forKey: storageKey) as? Bool }
    static var isGranted: Bool { current == true }

    /// Guarda la respuesta en el teléfono y en la cuenta.
    @MainActor
    static func record(_ granted: Bool, api: any LumbreAPI) {
        UserDefaults.standard.set(granted, forKey: storageKey)
        Analytics.track(.aiConsentResponded(granted: granted))
        Task { await sync(api: api) }
    }

    /// Copia a la cuenta lo que hay en el teléfono si cambió desde la última vez (o si la vez anterior falló).
    static func sync(api: any LumbreAPI) async {
        guard let value = current else { return }
        if UserDefaults.standard.object(forKey: syncedKey) as? Bool == value { return }
        do {
            try await api.setAIConsent(value)
            UserDefaults.standard.set(value, forKey: syncedKey)
        } catch {
            logger.notice("No se pudo guardar el consentimiento en la cuenta: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    /// Al cerrar sesión o borrar la cuenta: la próxima cuenta vuelve a preguntar.
    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: syncedKey)
    }
}

/// Aviso para cuando algo necesita IA y no hay permiso: explica y deja revisarlo.
struct AIConsentNeededView: View {
    var message: LocalizedStringKey = "Las chispas usan IA para conectar tus neuronas. Para encenderlas necesitamos tu permiso."
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Label {
                Text("Las chispas necesitan tu permiso")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
            } icon: {
                Image(systemName: "lock.shield")
                    .foregroundStyle(Palette.infoText)
            }
            .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(.callout)
                .foregroundStyle(Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            Text("Mientras tanto, podés seguir guardando neuronas.")
                .font(.callout)
                .foregroundStyle(Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            Button("Revisar el permiso") { appModel.presentAIConsent() }
                .buttonStyle(.lumbre(.secondary))
        }
        .padding(Space.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).strokeBorder(Palette.border, lineWidth: 1))
    }
}
