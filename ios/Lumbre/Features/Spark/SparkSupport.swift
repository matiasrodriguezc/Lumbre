import LumbreCore
import LumbreDesign
import SwiftUI
import UniformTypeIdentifiers

/// Destinos que se apilan desde Hoy, Proyectos o el detalle: una chispa o su planificador.
enum SparkRoute: Hashable {
    case detail(Spark.ID)
    /// `entry` es el de `planner_opened`: `spark_detail` o `project`.
    case planner(Spark.ID, entry: String)
}

extension View {
    /// Registra los destinos de chispa en el `NavigationStack` que la contiene.
    func sparkDestinations() -> some View {
        navigationDestination(for: SparkRoute.self) { route in
            switch route {
            case .detail(let id): SparkDetailView(sparkID: id)
            case .planner(let id, let entry): PlannerView(sparkID: id, entry: entry)
            }
        }
    }
}

extension SparkSide {
    init(_ concept: Concept) {
        self.init(category: concept.categoryName, categorySymbol: concept.categorySymbol, title: concept.title)
    }
}

extension SparkFeedback {
    var label: LocalizedStringKey {
        switch self {
        case .obvious: "Es obvia"
        case .irrelevant: "No tiene que ver conmigo"
        case .alreadyHad: "Ya la había tenido"
        }
    }
}

extension ReportReason {
    var label: LocalizedStringKey {
        switch self {
        case .offensive: "Es ofensiva"
        case .dangerous: "Es peligrosa"
        case .wrong: "Dice algo falso"
        case .other: "Otro motivo"
        }
    }
}

extension Spark {
    /// "Guardada en “Canal de YouTube”", "Guardada", "No te sirvió" o la fecha.
    var statusLine: Text {
        switch status {
        case .saved:
            if let projectName { return Text("Guardada en “\(projectName)”") }
            return Text("Guardada")
        case .discarded:
            return Text("Marcaste que no te sirve")
        case .pending, .revealed:
            return Text(scheduledFor ?? createdAt, format: .relative(presentation: .named))
        }
    }

    var statusSymbol: String {
        switch status {
        case .saved: "bookmark.fill"
        case .discarded: "hand.thumbsdown"
        case .pending, .revealed: "sparkles"
        }
    }

    /// Lo que lee VoiceOver: la chispa como una unidad.
    var accessibilitySummary: String {
        String(localized: "Chispa: \(title). \(body) Combina \(conceptA.title), de \(conceptA.categoryName), con \(conceptB.title), de \(conceptB.categoryName).")
    }
}

/// "Se recarga mañana a las 8:00".
func refillText(_ date: Date) -> Text {
    let time = date.formatted(date: .omitted, time: .shortened)
    if Calendar.current.isDateInToday(date) {
        return Text("Se recarga hoy a las \(time)")
    } else if Calendar.current.isDateInTomorrow(date) {
        return Text("Se recarga mañana a las \(time)")
    }
    return Text("Se recarga el \(date, format: .dateTime.weekday(.wide)) a las \(time)")
}

// MARK: - Export a Markdown

extension UTType {
    static let lumbreMarkdown = UTType("net.daringfireball.markdown") ?? UTType(filenameExtension: "md", conformingTo: .plainText) ?? .plainText
}

/// Un `.md` para la hoja de compartir. Cuenta `markdown_exported` cuando el destino lo pide.
struct MarkdownDocument: Transferable {
    let title: String
    let text: String
    /// `spark` o `project`.
    let object: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .lumbreMarkdown) { document in
            let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appending(path: document.filename)
            try Data(document.text.utf8).write(to: url, options: .atomic)
            Analytics.track(.markdownExported(object: document.object))
            return SentTransferredFile(url)
        }
    }

    var filename: String {
        let forbidden = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let clean = title.components(separatedBy: forbidden).joined(separator: " ")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return (clean.isEmpty ? "Lumbre" : String(clean.prefix(80))) + ".md"
    }

    static func spark(_ spark: Spark) -> MarkdownDocument {
        MarkdownDocument(title: spark.title, text: MarkdownExport.spark(spark).joined(separator: "\n"), object: "spark")
    }
}

// MARK: - Avisos

/// Confirmación breve debajo de una acción ("Idea guardada"). Siempre con ícono y palabra.
struct ActionNotice: View {
    let text: LocalizedStringKey
    var symbol = "checkmark.circle.fill"
    var color = Palette.success

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.footnote.weight(.medium))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity)
    }
}
