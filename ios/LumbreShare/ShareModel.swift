import Foundation
import LumbreCore
import Observation
import UIKit

/// Estado de la Share Extension: lee lo compartido, sugiere la categoría y guarda (directo o en la cola de la app).
@MainActor
@Observable
final class ShareModel {
    enum Phase: Equatable {
        case loading
        case editing
        case saving
        /// Guardada: el mensaje que se muestra antes de cerrar.
        case done(String)
        /// No hay nada que guardar, o el flag está apagado.
        case unavailable(String)
    }

    private(set) var phase: Phase = .loading
    private(set) var draft = SharedDraft()
    private(set) var preview: UIImage?
    private(set) var categories: [String] = LumbreShared.categoryNames
    var thesis = ""
    var category = LumbreShared.lastCategory ?? ""
    var errorMessage: String?

    func load(_ items: [NSExtensionItem]) async {
        guard FeatureFlag.shareExtension.isEnabled else {
            phase = .unavailable(String(localized: "Compartir con Lumbre todavía no está disponible."))
            return
        }
        let result = await ShareInput.read(items)
        draft = result.draft
        preview = result.preview
        if result.pdfTooLarge && draft.isEmpty {
            phase = .unavailable(String(localized: "El PDF pesa más de 20 MB. Probá con uno más liviano o escaneá solo las páginas que te importan."))
            return
        }
        guard !draft.isEmpty else {
            phase = .unavailable(String(localized: "No pudimos leer lo que compartiste."))
            return
        }
        thesis = draft.suggestedThesis
        phase = .editing
    }

    var trimmedThesis: String { thesis.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedCategory: String { category.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
    var isThesisTooLong: Bool { thesis.count > SharedDraft.thesisLimit }

    var canSave: Bool {
        phase == .editing && draft.request(thesis: thesis, category: trimmedCategory) != nil
    }

    /// La categoría escrita no existe todavía (sin distinguir mayúsculas ni tildes, igual que el servidor).
    var createsCategory: Bool {
        !trimmedCategory.isEmpty && !categories.contains { Self.same($0, trimmedCategory) }
    }

    func isSelected(_ name: String) -> Bool {
        Self.same(name, trimmedCategory)
    }

    func save() async -> Bool {
        guard let request = draft.request(thesis: thesis, category: trimmedCategory) else { return false }
        errorMessage = nil
        phase = .saving
        do {
            switch try await ExternalCapture.submit(request) {
            case .sent:
                LumbreShared.lastCategory = request.category
                phase = .done(String(localized: "Neurona guardada"))
                return true
            case .queued:
                LumbreShared.lastCategory = request.category
                phase = .done(String(localized: "Guardada. Se suma a tu Red cuando abras Lumbre."))
                return true
            case .rejected(let error):
                errorMessage = error.errorDescription ?? String(localized: "No pudimos guardarla. Probá de nuevo.")
            }
        } catch {
            errorMessage = String(localized: "No pudimos guardarla en el teléfono. Probá de nuevo.")
        }
        phase = .editing
        return false
    }

    private static func same(_ a: String, _ b: String) -> Bool {
        let fold: (String) -> String = {
            $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
                .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }
        return fold(a) == fold(b)
    }
}
