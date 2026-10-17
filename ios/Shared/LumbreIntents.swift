import AppIntents
import Foundation
import LumbreCore

// App Intents de Lumbre (paso 55). Viven en la app y en el widget: el control de captura y los widgets
// interactivos necesitan el tipo en los dos targets; los que abren la app corren siempre en la app.

/// "Guardar una idea en Lumbre": captura de texto sin abrir la app. Manda directo con la sesión compartida
/// o deja la captura en la cola offline, que manda la app.
struct SaveIdeaIntent: AppIntent {
    static let title = LocalizedStringResource("Guardar una idea en Lumbre", table: "Extensions")
    static let description = IntentDescription(LocalizedStringResource("Guarda una neurona en tu Red sin abrir la app.", table: "Extensions"))

    @Parameter(title: LocalizedStringResource("Idea", table: "Extensions"),
               inputOptions: String.IntentInputOptions(multiline: true),
               requestValueDialog: IntentDialog(LocalizedStringResource("¿Qué idea querés guardar?", table: "Extensions")))
    var idea: String

    @Parameter(title: LocalizedStringResource("Categoría", table: "Extensions"),
               requestValueDialog: IntentDialog(LocalizedStringResource("¿En qué categoría?", table: "Extensions")),
               optionsProvider: CategoryOptions())
    var category: String

    static var parameterSummary: some ParameterSummary {
        Summary("Guardar \(\.$idea) en \(\.$category)", table: "Extensions")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard FeatureFlag.appIntents.isEnabled else { throw IntentMessage.unavailable }
        let thesis = idea.trimmingCharacters(in: .whitespacesAndNewlines)
        let categoryName = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !thesis.isEmpty else { throw IntentMessage.emptyIdea }
        guard thesis.count <= SharedDraft.thesisLimit else { throw IntentMessage.tooLong }
        guard !categoryName.isEmpty else { throw IntentMessage.emptyCategory }

        let request = CaptureRequest(thesis: thesis, category: categoryName, source: .text)
        switch try await ExternalCapture.submit(request) {
        case .sent:
            LumbreShared.lastCategory = categoryName
            return .result(dialog: IntentDialog(LocalizedStringResource("Neurona guardada en tu Red.", table: "Extensions")))
        case .queued:
            LumbreShared.lastCategory = categoryName
            return .result(dialog: IntentDialog(LocalizedStringResource("Guardada. Se suma a tu Red la próxima vez que abras Lumbre.", table: "Extensions")))
        case .rejected(let error):
            throw IntentMessage.rejected(error.errorDescription ?? extensionsText("No pudimos guardarla. Probá de nuevo."))
        }
    }
}

/// Las categorías que el usuario ya tiene (las deja la app en el App Group). También se puede escribir una nueva.
struct CategoryOptions: DynamicOptionsProvider {
    func results() async throws -> [String] {
        LumbreShared.categoryNames
    }

    func defaultResult() async -> String? {
        LumbreShared.lastCategory
    }
}

/// "Ver la chispa de hoy": abre Lumbre en Hoy (o en el reveal, si todavía no se encendió).
struct OpenTodaySparkIntent: AppIntent {
    static let title = LocalizedStringResource("Ver la chispa de hoy", table: "Extensions")
    static let description = IntentDescription(LocalizedStringResource("Abre Lumbre en la chispa del día.", table: "Extensions"))
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let state = TodayWidgetState.current()
        DeepLinkInbox.post(state.sparkID.map(LumbreDeepLink.spark) ?? .today)
        return .result()
    }
}

/// Abre la sheet de Capturar. Lo usan el control del Centro de control y los atajos.
struct OpenCaptureIntent: AppIntent {
    static let title = LocalizedStringResource("Capturar en Lumbre", table: "Extensions")
    static let description = IntentDescription(LocalizedStringResource("Abre Lumbre listo para guardar una idea.", table: "Extensions"))
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        DeepLinkInbox.post(.capture(entry: "intent"))
        return .result()
    }
}

/// Mensajes de error que Siri y Atajos muestran tal cual.
enum IntentMessage: Error, CustomLocalizedStringResourceConvertible {
    case unavailable
    case emptyIdea
    case tooLong
    case emptyCategory
    case rejected(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .unavailable: LocalizedStringResource("Esto todavía no está disponible en Lumbre.", table: "Extensions")
        case .emptyIdea: LocalizedStringResource("Escribí la idea que querés guardar.", table: "Extensions")
        case .tooLong: LocalizedStringResource("La idea es muy larga: dejala en 600 caracteres o menos.", table: "Extensions")
        case .emptyCategory: LocalizedStringResource("Elegí una categoría.", table: "Extensions")
        case .rejected(let message): LocalizedStringResource(stringLiteral: message)
        }
    }
}
