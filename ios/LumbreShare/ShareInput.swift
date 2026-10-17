import Foundation
import ImageIO
import LumbreCore
import UIKit
import UniformTypeIdentifiers

/// Lee lo que otra app compartió (`NSExtensionItem`) y lo convierte en un `SharedDraft`.
///
/// Cuida la memoria de la extensión (unos 120 MB): las imágenes se leen como miniatura desde el archivo, sin
/// decodificarlas enteras, y los PDF de más de 20 MB no se cargan. Nada de lo leído va al log.
@MainActor
enum ShareInput {
    struct Result {
        var draft: SharedDraft
        var preview: UIImage?
        /// Había un PDF pero pesa más de lo que acepta Lumbre.
        var pdfTooLarge = false
    }

    static func read(_ items: [NSExtensionItem]) async -> Result {
        var text: String?
        var url: URL?
        var title: String?
        var pdf: Data?
        var fileName: String?
        var preview: UIImage?
        var hasImage = false
        var pdfTooLarge = false

        for item in items {
            if text == nil, let content = item.attributedContentText?.string, !content.isEmpty {
                text = content
            }
            if title == nil, let itemTitle = item.attributedTitle?.string, !itemTitle.isEmpty {
                title = itemTitle
            }
            for provider in item.attachments ?? [] {
                // Safari con el JavaScript de preprocesado: URL, título y selección.
                if provider.hasItemConformingToTypeIdentifier(UTType.propertyList.identifier),
                   let page = await loadPageInfo(provider) {
                    url = url ?? page.url
                    title = page.title ?? title
                    if let selection = page.selection { text = selection }
                    continue
                }
                if pdf == nil, !hasImage, provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                    switch await loadFile(provider, type: .pdf, limit: SharedDraft.pdfLimit) {
                    case .data(let data, let name):
                        pdf = data
                        fileName = name
                    case .tooLarge:
                        pdfTooLarge = true
                    case .none:
                        break
                    }
                    continue
                }
                if !hasImage, pdf == nil, provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    preview = await loadThumbnail(provider)
                    hasImage = true
                    continue
                }
                if url == nil, provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let shared = await loadURL(provider) {
                    if shared.isFileURL, UTType(filenameExtension: shared.pathExtension)?.conforms(to: .pdf) == true, pdf == nil {
                        if let data = readFile(shared, limit: SharedDraft.pdfLimit) {
                            pdf = data
                            fileName = shared.lastPathComponent
                        } else {
                            pdfTooLarge = true
                        }
                    } else if !shared.isFileURL {
                        url = shared
                    }
                    continue
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                   let plain = await loadText(provider) {
                    // El texto de un adjunto manda sobre el del ítem (que a veces es solo el título).
                    text = plain
                }
            }
        }
        let draft = SharedDraft(text: text, url: url, pageTitle: title, pdf: pdf, fileName: fileName, hasImage: hasImage)
        return Result(draft: draft, preview: preview, pdfTooLarge: pdfTooLarge)
    }

    // MARK: - Lectores

    private struct PageInfo: Sendable {
        let url: URL?
        let title: String?
        let selection: String?
    }

    private static func loadPageInfo(_ provider: NSItemProvider) async -> PageInfo? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.propertyList.identifier, options: nil) { item, _ in
                guard let dictionary = item as? NSDictionary,
                      let results = dictionary[NSExtensionJavaScriptPreprocessingResultsKey] as? NSDictionary
                else {
                    continuation.resume(returning: nil)
                    return
                }
                let selection = (results["selection"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: PageInfo(
                    url: (results["url"] as? String).flatMap(URL.init(string:)),
                    title: results["title"] as? String,
                    selection: selection?.isEmpty == false ? selection : nil
                ))
            }
        }
    }

    private static func loadURL(_ provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: NSURL.self) { object, _ in
                continuation.resume(returning: (object as? NSURL) as URL?)
            }
        }
    }

    private static func loadText(_ provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                continuation.resume(returning: (object as? NSString) as String?)
            }
        }
    }

    private enum FileResult: Sendable {
        case data(Data, String?)
        case tooLarge
    }

    /// El archivo temporal solo existe dentro del callback: se lee ahí.
    private static func loadFile(_ provider: NSItemProvider, type: UTType, limit: Int) async -> FileResult? {
        let suggestedName = provider.suggestedName
        return await withCheckedContinuation { continuation in
            _ = provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { file, _ in
                guard let file else {
                    continuation.resume(returning: nil)
                    return
                }
                if let data = readFile(file, limit: limit) {
                    continuation.resume(returning: .data(data, suggestedName.map { $0.lowercased().hasSuffix(".pdf") ? $0 : "\($0).pdf" } ?? file.lastPathComponent))
                } else {
                    continuation.resume(returning: .tooLarge)
                }
            }
        }
    }

    /// Miniatura de hasta 600 px, leída sin decodificar la imagen entera.
    private static func loadThumbnail(_ provider: NSItemProvider) async -> UIImage? {
        let cgImage: CGImage? = await withCheckedContinuation { continuation in
            _ = provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { file, _ in
                guard let file, let source = CGImageSourceCreateWithURL(file as CFURL, nil) else {
                    continuation.resume(returning: nil)
                    return
                }
                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 600,
                ]
                continuation.resume(returning: CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary))
            }
        }
        return cgImage.map(UIImage.init(cgImage:))
    }

    nonisolated private static func readFile(_ url: URL, limit: Int) -> Data? {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= limit else { return nil }
        // Lectura completa (no mapeada): el archivo temporal se borra al salir del callback.
        return try? Data(contentsOf: url)
    }
}
