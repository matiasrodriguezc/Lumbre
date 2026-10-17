import ImageIO
import SwiftUI
import UIKit
import Vision
import VisionKit

/// OCR en el teléfono con Vision (español e inglés). Nada sale del teléfono.
enum TextRecognition {
    /// Texto reconocido en la imagen, en orden de lectura. Vacío si no hay texto.
    static func recognize(_ image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { return "" }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return try await recognize(cgImage, orientation: orientation)
    }

    /// Varias páginas escaneadas, separadas por una línea en blanco.
    static func recognize(pages: [UIImage]) async throws -> String {
        var texts: [String] = []
        for page in pages {
            let text = try await recognize(page)
            if !text.isEmpty { texts.append(text) }
        }
        return texts.joined(separator: "\n\n")
    }

    private static func recognize(_ image: CGImage, orientation: CGImagePropertyOrientation) async throws -> String {
        let box = UncheckedBox(image)
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = ["es-ES", "en-US"]
                let handler = VNImageRequestHandler(cgImage: box.value, orientation: orientation)
                do {
                    try handler.perform([request])
                    let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                    continuation.resume(returning: joinLines(lines))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Une las líneas de una página en párrafos: las cortadas con guion se pegan y el resto se separa con un espacio.
    static func joinLines(_ lines: [String]) -> String {
        var text = ""
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            if text.isEmpty {
                text = line
            } else if text.hasSuffix("-"), let last = text.dropLast().last, last.isLetter {
                text.removeLast()
                text += line
            } else {
                text += " " + line
            }
        }
        return text
    }

    /// JPEG para conceptualizar: lado mayor de hasta 1568 px (lo que la IA aprovecha sin gastar de más).
    static func jpegForUpload(_ image: UIImage, maxSide: CGFloat = 1568, quality: CGFloat = 0.8) -> Data? {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxSide / longest)
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }

    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
}

private struct UncheckedBox<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

/// Escáner de páginas de VisionKit. Solo existe con cámara (no en el simulador).
struct DocumentScanner: UIViewControllerRepresentable {
    static var isAvailable: Bool { VNDocumentCameraViewController.isSupported }

    let onFinish: ([UIImage]) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish, onCancel: onCancel)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onFinish: ([UIImage]) -> Void
        let onCancel: () -> Void

        init(onFinish: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onFinish = onFinish
            self.onCancel = onCancel
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            onFinish((0..<scan.pageCount).map(scan.imageOfPage(at:)))
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onCancel()
        }
    }
}
