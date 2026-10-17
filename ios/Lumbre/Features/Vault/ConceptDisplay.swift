import LumbreCore
import LumbreDesign
import SwiftUI

extension Concept {
    /// "De un link · hace 2 días"
    var sourceLine: Text {
        Text("\(sourceType.label) · \(createdAt, format: .relative(presentation: .named))")
    }

    var categoryName: String { category?.name ?? String(localized: "Sin categoría") }
    var categorySymbol: String { category?.symbol ?? "tag" }
    var isDraft: Bool { status == .draft }
}

extension SourceType {
    var label: String {
        switch self {
        case .text: return String(localized: "Texto")
        case .voice: return String(localized: "Nota de voz")
        case .selection: return String(localized: "Texto seleccionado")
        case .screenshot: return String(localized: "Captura de pantalla")
        case .scan: return String(localized: "Página escaneada")
        case .link: return String(localized: "De un link")
        case .image: return String(localized: "Imagen")
        case .pdf: return String(localized: "PDF")
        case .audio: return String(localized: "Audio")
        case .spark: return String(localized: "Nació de una chispa")
        }
    }

    var symbol: String {
        switch self {
        case .text: return "text.alignleft"
        case .voice: return "mic"
        case .selection: return "text.quote"
        case .screenshot: return "camera.viewfinder"
        case .scan: return "doc.viewfinder"
        case .link: return "link"
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .audio: return "waveform"
        case .spark: return "sparkles"
        }
    }
}

extension ConceptCard {
    /// Tarjeta de un concepto de la bóveda. Los borradores lo dicen en la línea de la fuente.
    init(_ concept: Concept) {
        let source = concept.isDraft
            ? Text("Borrador · ") + concept.sourceLine
            : concept.sourceLine
        self.init(category: concept.categoryName, categorySymbol: concept.categorySymbol, title: concept.title, thesis: concept.thesis, source: source)
    }
}

/// Misma comparación de categorías que el servidor: sin acentos, sin mayúsculas y con los espacios colapsados.
enum CategoryName {
    static func clean(_ name: String) -> String {
        name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func normalized(_ name: String) -> String {
        clean(name).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    static func same(_ a: String, _ b: String) -> Bool {
        let left = normalized(a)
        return !left.isEmpty && left == normalized(b)
    }
}
