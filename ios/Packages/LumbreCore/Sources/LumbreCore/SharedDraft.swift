import Foundation

/// Lo que llegó a la Share Extension desde otra app, ya leído de los `NSItemProvider`.
/// Decide qué tipo de captura es y arma el `CaptureRequest` con la idea que escribe el usuario.
///
/// - Texto seleccionado en Safari (o cualquier texto que llega con una URL): `selection`, con el fragmento como
///   excerpt y la URL de origen (plan.md §4).
/// - Solo una URL web: `link`, con el título de la página.
/// - Texto suelto: `text`. Si es solo una URL, cuenta como link.
/// - PDF: viaja como fuente. Imagen: queda en la otra app y se guarda la idea (sin conceptualizar, como una foto en free).
public struct SharedDraft: Sendable, Equatable {
    public enum Kind: String, Sendable, Equatable {
        case text, selection, link, image, pdf
    }

    /// Mismo límite que la sheet de Capturar.
    public static let thesisLimit = 600
    /// Mismo límite que el servidor para el excerpt.
    public static let excerptLimit = 500
    /// Mismo límite que la sheet de Capturar para PDFs.
    public static let pdfLimit = 20 * 1024 * 1024

    public var text: String?
    public var url: URL?
    public var pageTitle: String?
    public var pdf: Data?
    public var fileName: String?
    public var hasImage: Bool

    public init(text: String? = nil, url: URL? = nil, pageTitle: String? = nil, pdf: Data? = nil, fileName: String? = nil, hasImage: Bool = false) {
        self.text = Self.clean(text)
        self.url = url.flatMap(Self.webURL)
        self.pageTitle = Self.clean(pageTitle)
        self.pdf = pdf
        self.fileName = Self.clean(fileName)
        self.hasImage = hasImage
        // Texto que es solo un link: es un link.
        if self.url == nil, let text = self.text, let link = Self.webURL(from: text) {
            self.url = link
            self.text = nil
        }
    }

    public var kind: Kind {
        if pdf != nil { return .pdf }
        if hasImage { return .image }
        if text != nil { return url != nil ? .selection : .text }
        if url != nil { return .link }
        return .text
    }

    /// Hay algo para guardar.
    public var isEmpty: Bool {
        text == nil && url == nil && pdf == nil && !hasImage
    }

    /// Idea propuesta: el texto compartido si entra en el límite. Lo más largo queda como fragmento y la idea se escribe.
    public var suggestedThesis: String {
        guard let text, text.count <= Self.thesisLimit, kind == .text || kind == .selection else { return "" }
        return text
    }

    /// Fragmento que acompaña a la idea (texto seleccionado o texto largo).
    public var excerpt: String? {
        guard let text, kind == .selection || (kind == .text && text.count > Self.thesisLimit) else { return nil }
        return String(text.prefix(Self.excerptLimit))
    }

    /// Lo que se muestra como fuente: el título de la página, el host del link o el nombre del archivo.
    public var sourceLabel: String? {
        switch kind {
        case .pdf: fileName
        case .link, .selection: pageTitle ?? url?.host()
        case .text, .image: nil
        }
    }

    /// Siempre con la idea escrita por el usuario: desde la extensión no se conceptualiza (provisorio, ver ios/README.md).
    public func request(thesis: String, category: String) -> CaptureRequest? {
        let thesis = thesis.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !thesis.isEmpty, thesis.count <= Self.thesisLimit, !category.isEmpty, !isEmpty else { return nil }
        switch kind {
        case .pdf:
            guard let pdf, pdf.count <= Self.pdfLimit else { return nil }
            return CaptureRequest(thesis: thesis, category: category, source: .pdf(pdf), sourceTitle: fileName)
        case .image:
            return CaptureRequest(thesis: thesis, category: category, source: .screenshot)
        case .selection:
            return CaptureRequest(thesis: thesis, category: category, source: .selection(url), sourceTitle: pageTitle, excerpt: excerpt)
        case .link:
            guard let url else { return nil }
            return CaptureRequest(thesis: thesis, category: category, source: .link(url), sourceTitle: pageTitle)
        case .text:
            if let excerpt {
                return CaptureRequest(thesis: thesis, category: category, source: .selection(nil), excerpt: excerpt)
            }
            return CaptureRequest(thesis: thesis, category: category, source: .text)
        }
    }

    // MARK: - Limpieza

    private static func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Solo http y https: un `file://` o un esquema de otra app no es una fuente que el servidor pueda leer.
    private static func webURL(_ url: URL) -> URL? {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https", url.host() != nil else { return nil }
        return url
    }

    private static func webURL(from text: String) -> URL? {
        guard !text.contains(where: \.isWhitespace), let url = URL(string: text) else { return nil }
        return webURL(url)
    }
}
