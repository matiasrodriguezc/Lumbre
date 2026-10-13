import LumbreCore
import LumbreDesign
import SwiftUI

/// Error de carga con reintento. Da dirección, no disculpas: dice qué pasó y qué hacer.
/// Con `screen`, registra `error_shown` (el detalle técnico va a Sentry, nunca al evento).
struct LoadErrorView: View {
    let error: Error
    var screen: String? = nil
    let retry: () -> Void

    init(error: Error, screen: String? = nil, retry: @escaping () -> Void) {
        self.error = error
        self.screen = screen
        self.retry = retry
    }

    var body: some View {
        let content = ErrorContent(error)
        ContentUnavailableView {
            EmptyStateLabel(content.title, systemImage: content.symbol, illustration: content.illustration)
        } description: {
            Text(content.message)
        } actions: {
            Button("Reintentar", action: retry)
                .buttonStyle(.lumbre(.secondary))
        }
        .padding(.top, Space.s8)
        .onAppear {
            if let screen { Analytics.track(.errorShown(screen: screen, code: content.code)) }
        }
    }
}

/// Título, mensaje, ícono y código de analytics para un error.
struct ErrorContent {
    let title: LocalizedStringKey
    let message: String
    let symbol: String
    let code: String
    /// Ilustración de la identidad neuronal; solo para la falta de conexión.
    var illustration: NeuralIllustration.Kind? { symbol == "wifi.exclamationmark" ? .offline : nil }

    init(_ error: Error) {
        if let urlError = error as? URLError {
            title = "Sin conexión"
            message = String(localized: "Revisá tu conexión y probá de nuevo.")
            symbol = "wifi.exclamationmark"
            code = "network_\(urlError.code.rawValue)"
        } else if let apiError = error as? LumbreAPIError {
            title = apiError == .offline ? "Sin conexión" : "No se pudo cargar"
            message = apiError.errorDescription ?? String(localized: "Algo salió mal. Probá de nuevo.")
            symbol = apiError == .offline ? "wifi.exclamationmark" : "exclamationmark.triangle"
            code = String(describing: apiError)
        } else {
            title = "No se pudo cargar"
            message = String(localized: "Algo salió mal. Probá de nuevo en un rato.")
            symbol = "exclamationmark.triangle"
            code = "unexpected"
        }
    }
}

/// Estado vacío con dirección: qué falta y cómo conseguirlo.
struct EmptyStateView<Actions: View>: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let systemImage: String
    var illustration: NeuralIllustration.Kind? = nil
    @ViewBuilder var actions: () -> Actions

    init(_ title: LocalizedStringKey, message: LocalizedStringKey, systemImage: String, illustration: NeuralIllustration.Kind? = nil,
         @ViewBuilder actions: @escaping () -> Actions = { EmptyView() }) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.illustration = illustration
        self.actions = actions
    }

    var body: some View {
        ContentUnavailableView {
            EmptyStateLabel(title, systemImage: systemImage, illustration: illustration)
        } description: {
            Text(message)
        } actions: {
            actions()
        }
    }
}

/// Título de un estado vacío: con la identidad neuronal, la ilustración reemplaza al símbolo.
struct EmptyStateLabel: View {
    let title: LocalizedStringKey
    let systemImage: String
    var illustration: NeuralIllustration.Kind?

    @Environment(\.neuralIdentity) private var neuralIdentity

    init(_ title: LocalizedStringKey, systemImage: String, illustration: NeuralIllustration.Kind? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.illustration = illustration
    }

    var body: some View {
        if neuralIdentity, let illustration {
            VStack(spacing: Space.s3) {
                NeuralIllustration(illustration).frame(width: 180)
                Text(title)
            }
        } else {
            Label(title, systemImage: systemImage)
        }
    }
}

#Preview("Error") {
    LoadErrorView(error: URLError(.notConnectedToInternet)) {}
        .background(Palette.bg)
        .preferredColorScheme(.light)
}

#Preview("Vacío") {
    EmptyStateView("Todavía no hay neuronas", message: "Guardá una frase, un link o una nota de voz para tener material que combinar.", systemImage: "square.stack.3d.up") {
        Button("Capturar una idea") {}
            .buttonStyle(.lumbre(.primary))
    }
    .background(Palette.bg)
    .preferredColorScheme(.light)
}
