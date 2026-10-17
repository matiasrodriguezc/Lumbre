import AppIntents
import Foundation
import LumbreCore

/// "Importar notas a Lumbre" (paso 89, flag `import_notes`): la acción que usa el atajo de Apple Notes.
/// iOS no deja que otra app lea Notas en bloque; el atajo las busca ("Buscar notas") y se las pasa a esta acción,
/// que las convierte en texto. Cómo armar el atajo: ios/README.md.
///
/// Vive solo en la app (no en el widget): abre Lumbre con la vista previa, donde se eligen las notas y se mandan por
/// `/capture` con la cola offline. El texto de las notas es contenido del usuario: se trata como datos.
struct ImportNotesIntent: AppIntent {
    static let title: LocalizedStringResource = "Importar notas a Lumbre"
    static let description = IntentDescription("Abre Lumbre con estas notas para elegir cuáles suman neuronas a tu Red.")
    static let openAppWhenRun = true

    /// Las notas de "Buscar notas": Atajos pasa cada una como texto (el título es la primera línea).
    @Parameter(title: "Notas", description: "Las notas que encontró “Buscar notas”, o cualquier texto.")
    var notes: [String]

    /// Opcional: la categoría sugerida para todas (por ejemplo, el nombre de la carpeta de Notas).
    @Parameter(title: "Categoría", description: "Opcional. Si no, entran en “Notas importadas” y la cambiás en la vista previa.")
    var category: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Importar \(\.$notes) a Lumbre") {
            \.$category
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard FeatureFlag.importNotes.isEnabled else { throw IntentMessage.unavailable }
        let parsed = Self.notes(from: notes, category: category)
        guard !parsed.isEmpty else { throw ImportNotesIntentError.noNotes }
        try ImportInbox.post(parsed)
        return .result(dialog: IntentDialog(parsed.count == 1
            ? "Elegí en Lumbre si importás la nota."
            : "Elegí en Lumbre cuáles de las \(parsed.count) notas importás."))
    }

    /// Las notas con texto, hasta `NoteImport.maxIntentNotes`.
    static func notes(from texts: [String], category: String?) -> [ImportNote] {
        texts.prefix(NoteImport.maxIntentNotes).compactMap { NoteImport.plainNote($0, folder: category, source: .appleNotes) }
    }
}

enum ImportNotesIntentError: Error, CustomLocalizedStringResourceConvertible {
    case noNotes

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noNotes: "No llegó ninguna nota con texto. Revisá que “Buscar notas” encuentre algo."
        }
    }
}
