import LumbreCore
import LumbreDesign
import PDFKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Voz

/// Dictado con transcripción en vivo. Al parar, el texto queda editable y entra como `.voice`.
struct VoiceInput: View {
    @Bindable var form: CaptureForm
    let dictation: SpeechDictation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @State private var base = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            HStack(spacing: Space.s3) {
                Button {
                    Task { await toggle() }
                } label: {
                    Image(systemName: dictation.isListening ? "stop.fill" : "mic.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(dictation.isListening ? Palette.danger : Palette.ink)
                        .frame(width: 64, height: 64)
                        .background(Palette.surfaceAlt, in: Circle())
                        .overlay(Circle().strokeBorder(dictation.isListening ? Palette.danger : Palette.borderStrong, lineWidth: 2))
                        .symbolEffect(.pulse, options: .repeating, isActive: dictation.state == .listening && !reduceMotion)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(dictation.isListening ? Text("Parar el dictado") : Text("Dictar"))
                .accessibilityHint(Text("Lo que digas se transcribe en el teléfono"))

                VStack(alignment: .leading, spacing: Space.s1) {
                    Text(statusTitle)
                        .font(.headline)
                    Text(statusDetail)
                        .font(.footnote)
                        .foregroundStyle(Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if dictation.state == .denied {
                Button("Abrir Ajustes") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.lumbre(.secondary))
            }

            if dictation.isListening {
                Text(form.thesis.isEmpty ? String(localized: "Escuchando…") : form.thesis)
                    .font(.body)
                    .foregroundStyle(form.thesis.isEmpty ? Palette.inkMuted : Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                    .padding(Space.s3)
                    .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).strokeBorder(Palette.borderStrong, lineWidth: 1))
                    .accessibilityLabel(Text("Transcripción"))
                    .accessibilityValue(Text(form.thesis))
                    .accessibilityAddTraits(.updatesFrequently)
            } else {
                LumbreTextField("Lo que dictes aparece acá. Podés corregirlo.", text: $form.thesis, axis: .vertical, lines: 4...10)
                    .accessibilityLabel(Text("Transcripción"))
            }
        }
        .onDisappear { dictation.stop() }
    }

    private var statusTitle: String {
        switch dictation.state {
        case .idle: form.thesis.isEmpty ? String(localized: "Tocá y decí tu idea") : String(localized: "Tocá para seguir dictando")
        case .starting: String(localized: "Preparando el micrófono…")
        case .listening: String(localized: "Escuchando")
        case .denied: String(localized: "Falta el permiso")
        case .unavailable: String(localized: "El dictado no está disponible")
        }
    }

    private var statusDetail: String {
        switch dictation.state {
        case .denied:
            String(localized: "Para dictar, Lumbre necesita el micrófono y el reconocimiento de voz. Activalos en Ajustes.")
        case .unavailable:
            String(localized: "Probá en un rato o escribí la idea en Texto.")
        default:
            dictation.isOnDevice || dictation.state == .idle
                ? String(localized: "Se transcribe en el teléfono. El audio no se guarda.")
                : String(localized: "El audio no se guarda.")
        }
    }

    private func toggle() async {
        if !dictation.isListening {
            base = form.trimmedThesis
            dictation.onTranscript = { [form, base] text in
                form.thesis = base.isEmpty ? text : base + " " + text
            }
        }
        await dictation.toggle()
    }
}

// MARK: - Foto, escaneo y PDF

/// Elegir una foto (OCR en el teléfono), escanear una página o adjuntar un PDF.
struct PhotoInput: View {
    @Bindable var form: CaptureForm
    /// Se llama cuando falla algo antes de guardar (`capture_failed`).
    let onFailure: (_ reason: String, _ message: String) -> Void

    @State private var photoItem: PhotosPickerItem?
    @State private var isScanning = false
    @State private var isImportingPDF = false

    private static let pdfLimit = 20 * 1024 * 1024

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            if let attachment = form.attachment {
                preview(attachment)
            }
            sourceButtons
            if form.attachment != nil {
                textField
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await loadPhoto(item) }
        }
        .fullScreenCover(isPresented: $isScanning) {
            DocumentScanner { pages in
                isScanning = false
                Task { await loadScan(pages) }
            } onCancel: {
                isScanning = false
            }
            .ignoresSafeArea()
        }
        .fileImporter(isPresented: $isImportingPDF, allowedContentTypes: [.pdf]) { result in
            if case .success(let url) = result { loadPDF(url) }
        }
    }

    private var sourceButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Space.s2) { buttons }
            VStack(alignment: .leading, spacing: Space.s2) { buttons }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
            Label(form.attachment == nil ? LocalizedStringKey("Elegir foto") : LocalizedStringKey("Otra foto"), systemImage: "photo.on.rectangle")
        }
        .buttonStyle(.lumbre(.secondary))
        if DocumentScanner.isAvailable {
            Button {
                isScanning = true
            } label: {
                Label("Escanear página", systemImage: "doc.viewfinder")
            }
            .buttonStyle(.lumbre(.secondary))
        }
        if FeatureFlag.distillation.isEnabled {
            Button {
                isImportingPDF = true
            } label: {
                Label("PDF", systemImage: "doc.richtext")
            }
            .buttonStyle(.lumbre(.secondary))
            .accessibilityLabel(Text("Adjuntar un PDF"))
        }
    }

    @ViewBuilder
    private func preview(_ attachment: CaptureForm.Attachment) -> some View {
        HStack(alignment: .top, spacing: Space.s3) {
            Group {
                if let image = attachment.preview {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "doc.richtext")
                        .font(.title)
                        .foregroundStyle(Palette.inkMuted)
                }
            }
            .frame(width: 72, height: 96)
            .background(Palette.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).strokeBorder(Palette.border, lineWidth: 1))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Space.s1) {
                Text(title(for: attachment))
                    .font(.headline)
                    .lineLimit(2)
                if form.isRecognizing {
                    HStack(spacing: Space.s2) {
                        ProgressView()
                        Text("Leyendo el texto…")
                    }
                    .font(.footnote)
                    .foregroundStyle(Palette.inkMuted)
                } else {
                    Text(detail(for: attachment))
                        .font(.footnote)
                        .foregroundStyle(Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            Button {
                form.attachment = nil
                photoItem = nil
                form.thesis = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Palette.inkMuted)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Quitar adjunto"))
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var textField: some View {
        let isPDF = form.attachment?.kind == .pdf
        VStack(alignment: .leading, spacing: Space.s1) {
            Text(isPDF ? "¿Qué idea te deja esto?" : "Texto reconocido")
                .font(.headline)
            LumbreTextField(isPDF ? "En una línea, con tus palabras" : "Dejá solo la parte que te importa", text: $form.thesis, axis: .vertical, lines: 3...10)
                .accessibilityLabel(isPDF ? Text("¿Qué idea te deja esto?") : Text("Texto reconocido"))
        }
    }

    private func title(for attachment: CaptureForm.Attachment) -> String {
        switch attachment.kind {
        case .photo: String(localized: "Foto")
        case .scan: attachment.pageCount == 1 ? String(localized: "Página escaneada") : String(localized: "\(attachment.pageCount) páginas escaneadas")
        case .pdf: attachment.fileName ?? String(localized: "PDF")
        }
    }

    private func detail(for attachment: CaptureForm.Attachment) -> String {
        switch attachment.kind {
        case .pdf:
            String(localized: "\(attachment.pageCount) páginas. El archivo no se guarda: solo la idea.")
        case .photo, .scan:
            form.thesis.isEmpty
                ? String(localized: "No encontramos texto. Escribí qué idea te deja o conceptualizá la imagen.")
                : String(localized: "Texto sacado en el teléfono. La foto queda en tu fototeca.")
        }
    }

    // MARK: Carga

    private func loadPhoto(_ item: PhotosPickerItem) async {
        form.isRecognizing = true
        defer { form.isRecognizing = false }
        guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
            form.attachment = nil
            onFailure("unsupported_format", String(localized: "No pudimos abrir esa imagen. Probá con otra."))
            return
        }
        form.attachment = .init(kind: .photo, preview: image, jpeg: TextRecognition.jpegForUpload(image), pdf: nil,
                                fileName: nil, localAssetID: item.itemIdentifier, pageCount: 1)
        await recognize(kind: "screenshot") { try await TextRecognition.recognize(image) }
    }

    private func loadScan(_ pages: [UIImage]) async {
        guard let first = pages.first else { return }
        form.isRecognizing = true
        defer { form.isRecognizing = false }
        form.attachment = .init(kind: .scan, preview: first, jpeg: TextRecognition.jpegForUpload(first), pdf: nil,
                                fileName: nil, localAssetID: nil, pageCount: pages.count)
        await recognize(kind: "scan") { try await TextRecognition.recognize(pages: pages) }
    }

    private func recognize(kind: String, _ work: () async throws -> String) async {
        guard FeatureFlag.ocr.isEnabled else { return }
        let text = (try? await work()) ?? ""
        form.thesis = text
        Analytics.track(.ocrCompleted(kind: kind, success: !text.isEmpty, words: TextRecognition.wordCount(text)))
    }

    private func loadPDF(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), let document = PDFDocument(data: data) else {
            onFailure("unsupported_format", String(localized: "No pudimos abrir ese PDF. Probá con otro."))
            return
        }
        guard data.count <= Self.pdfLimit else {
            onFailure("too_large", String(localized: "El PDF pesa más de 20 MB. Probá con uno más liviano o escaneá solo las páginas que te importan."))
            return
        }
        let thumbnail = document.page(at: 0)?.thumbnail(of: CGSize(width: 144, height: 192), for: .mediaBox)
        photoItem = nil
        form.thesis = ""
        form.attachment = .init(kind: .pdf, preview: thumbnail, jpeg: nil, pdf: data,
                                fileName: url.deletingPathExtension().lastPathComponent, localAssetID: nil, pageCount: document.pageCount)
    }
}

// MARK: - Conceptualizar

/// Toggle de conceptualización con lo que queda de cupo. Violeta: es una función Pro (con pruebas en free).
struct DistillToggle: View {
    let title: LocalizedStringKey
    @Binding var isOn: Bool
    let access: DistillAccess
    let onPro: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Toggle(isOn: $isOn) {
                Label(title, systemImage: "wand.and.sparkles")
                    .font(.body.weight(.medium))
            }
            .tint(Palette.pro)
            .disabled(!access.canDistill)
            caption
        }
        .padding(Space.s3)
        .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    @ViewBuilder
    private var caption: some View {
        switch access {
        case .loading:
            Text("Revisando tus pruebas…")
                .font(.footnote)
                .foregroundStyle(Palette.inkMuted)
        case .pro:
            Text("Lumbre lee el contenido y saca de 1 a 3 neuronas.")
                .font(.footnote)
                .foregroundStyle(Palette.inkMuted)
        case .trials(let remaining, _) where remaining > 0:
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Space.s1) { trialsText(remaining); proButton }
                VStack(alignment: .leading, spacing: Space.s1) { trialsText(remaining); proButton }
            }
        case .trials:
            VStack(alignment: .leading, spacing: Space.s1) {
                Text("Usaste las pruebas de este mes. Escribí qué idea te deja esto y lo guardamos igual.")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                proButton
            }
        case .guest:
            Text("La conceptualización es con cuenta. Creala desde Perfil y probala gratis.")
                .font(.footnote)
                .foregroundStyle(Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        case .off:
            EmptyView()
        }
    }

    private func trialsText(_ remaining: Int) -> some View {
        Text(remaining == 1 ? "Te queda 1 prueba este mes." : "Te quedan \(remaining) pruebas este mes.")
            .font(.footnote)
            .foregroundStyle(Palette.inkMuted)
    }

    private var proButton: some View {
        Button("Ilimitado en Pro", action: onPro)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Palette.proText)
            .buttonStyle(.plain)
            .frame(minHeight: 32)
    }
}
