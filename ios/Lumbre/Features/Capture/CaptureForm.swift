import Foundation
import LumbreCore
import Observation
import UIKit

/// Lo que el usuario está cargando en la sheet de Capturar. Arma el `CaptureRequest` final.
@MainActor
@Observable
final class CaptureForm {
    enum Kind: String, CaseIterable, Identifiable {
        case text, voice, link, photo
        var id: String { rawValue }

        var label: String {
            switch self {
            case .text: String(localized: "Texto")
            case .voice: String(localized: "Voz")
            case .link: String(localized: "Link")
            case .photo: String(localized: "Foto")
            }
        }

        /// Las que están prendidas por feature flag.
        static var available: [Kind] {
            allCases.filter { $0 != .voice || FeatureFlag.voiceCapture.isEnabled }
        }
    }

    /// Foto de la fototeca, páginas escaneadas o un PDF de Archivos.
    struct Attachment {
        enum Kind { case photo, scan, pdf }

        let kind: Kind
        let preview: UIImage?
        /// JPEG reducido (lado mayor ≤ 1568 px), para conceptualizar la imagen.
        let jpeg: Data?
        let pdf: Data?
        let fileName: String?
        /// Identificador de la foto en la fototeca, que queda en el teléfono.
        let localAssetID: String?
        let pageCount: Int
    }

    static let thesisLimit = 600

    var kind: Kind = .text
    var thesis = ""
    var link = ""
    var categoryName = ""
    var distill = false
    var attachment: Attachment?
    /// El OCR está corriendo.
    var isRecognizing = false
    /// La conceptualización no sacó una idea: hay que escribirla.
    var needsThesis = false

    var trimmedThesis: String { thesis.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedCategory: String { CategoryName.clean(categoryName) }
    var isThesisTooLong: Bool { thesis.count > Self.thesisLimit }

    var linkURL: URL? {
        let raw = link.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = raw.contains("://") ? raw : "https://" + raw
        guard !raw.isEmpty, let url = URL(string: candidate), url.scheme?.hasPrefix("http") == true,
              let host = url.host(), host.contains(".") else { return nil }
        return url
    }

    /// Link y adjuntos se pueden conceptualizar; texto y voz no (se guardan tal cual).
    var acceptsDistill: Bool {
        switch kind {
        case .text, .voice: false
        case .link: true
        case .photo: attachment?.kind == .pdf || attachment?.jpeg != nil
        }
    }

    /// Primer link que aparece en el texto, para sugerir pasar a Link.
    var linkInThesis: URL? {
        guard kind == .text, let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(thesis.startIndex..., in: thesis)
        return detector.firstMatch(in: thesis, range: range)?.url.flatMap { $0.scheme?.hasPrefix("http") == true ? $0 : nil }
    }

    /// Pasa el link del texto al campo Link y deja el resto como la idea.
    func moveLinkFromThesis() {
        guard let url = linkInThesis else { return }
        link = url.absoluteString
        thesis = thesis.replacingOccurrences(of: url.absoluteString, with: "")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        kind = .link
    }

    func willDistill(canDistill: Bool) -> Bool {
        acceptsDistill && distill && canDistill
    }

    func canSave(canDistill: Bool) -> Bool {
        guard !trimmedCategory.isEmpty, !isThesisTooLong, !isRecognizing else { return false }
        let hasThesis = !trimmedThesis.isEmpty
        switch kind {
        case .text, .voice:
            return hasThesis
        case .link:
            return linkURL != nil && (hasThesis || willDistill(canDistill: canDistill))
        case .photo:
            guard attachment != nil else { return false }
            return hasThesis || willDistill(canDistill: canDistill)
        }
    }

    func makeRequest(canDistill: Bool) -> CaptureRequest? {
        let thesis: String? = trimmedThesis.isEmpty ? nil : trimmedThesis
        let distill = willDistill(canDistill: canDistill)
        let category = trimmedCategory
        switch kind {
        case .text:
            return CaptureRequest(thesis: thesis, category: category, source: .text)
        case .voice:
            return CaptureRequest(thesis: thesis, category: category, source: .voice)
        case .link:
            guard let url = linkURL else { return nil }
            return CaptureRequest(thesis: thesis, category: category, source: .link(url), distill: distill)
        case .photo:
            guard let attachment else { return nil }
            switch attachment.kind {
            case .pdf:
                guard let data = attachment.pdf else { return nil }
                return CaptureRequest(thesis: thesis, category: category, source: .pdf(data), sourceTitle: attachment.fileName, distill: distill)
            case .photo, .scan:
                if distill, let jpeg = attachment.jpeg {
                    return CaptureRequest(thesis: thesis, category: category, source: .image(jpeg), localAssetID: attachment.localAssetID, distill: true)
                }
                return CaptureRequest(thesis: thesis, category: category, source: attachment.kind == .scan ? .scan : .screenshot,
                                      localAssetID: attachment.localAssetID)
            }
        }
    }

    var words: Int { TextRecognition.wordCount(thesis) }
}

/// Si el usuario puede conceptualizar ahora (Pro, pruebas del mes en free, nada para invitados).
enum DistillAccess: Equatable {
    case loading
    case pro
    case trials(remaining: Int, max: Int)
    case guest
    /// Feature flag apagado.
    case off

    var canDistill: Bool {
        switch self {
        case .pro: true
        case .trials(let remaining, _): remaining > 0
        case .loading, .guest, .off: false
        }
    }

    /// - Parameter aiConsent: lo que respondió en "Tus ideas y la IA". Sin un "Acepto", no se ofrece conceptualizar
    ///   (el contenido no sale hacia la IA desde la captura).
    static func resolve(isPro: Bool, isGuest: Bool, credits: [Credit]?, aiConsent: Bool?) -> DistillAccess {
        guard FeatureFlag.distillation.isEnabled, aiConsent == true else { return .off }
        if isGuest { return .guest }
        if isPro { return .pro }
        guard let credits else { return .loading }
        let credit = credits.first { $0.kind == .distill }
        return .trials(remaining: credit?.remaining ?? 0, max: credit?.max ?? 0)
    }
}
