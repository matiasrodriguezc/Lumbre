import LumbreCore
import LumbreDesign
import SwiftUI

/// Sheet global de Capturar: texto, voz, link o foto (con OCR en el teléfono), categoría y, si se pide, destilación.
/// La abre `RootView` cuando `appModel.captureEntry` no es nil.
struct CaptureSheet: View {
    /// Pasos después de guardar.
    enum Step: Hashable {
        case review([Concept])
        case results([Concept])
        case savedWithoutDistill
    }

    private enum Field: Hashable { case thesis, link, category }

    /// Se llama después de guardar, para que las pantallas vuelvan a cargar. Sin él, avisa con `appModel.dataChanged()`.
    private let onSaved: (() -> Void)?

    init(onSaved: (() -> Void)? = nil) {
        self.onSaved = onSaved
    }

    @Environment(\.api) private var api
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.neuralIdentity) private var neuralIdentity
    @AppStorage("capture.lastCategory") private var lastCategory = ""
    @State private var form = CaptureForm()
    @State private var dictation = SpeechDictation()
    @State private var categories: [LumbreCore.Category] = []
    @State private var credits: [Credit]?
    @State private var path: [Step] = []
    @State private var isSaving = false
    @State private var confirmation: String?
    @State private var errorMessage: String?
    @State private var entry = "fab"
    @State private var loggedFreeQuotaFallback = false
    @FocusState private var focus: Field?

    private var access: DistillAccess {
        DistillAccess.resolve(isPro: appModel.isPro, isGuest: appModel.isGuest, credits: credits)
    }

    var body: some View {
        NavigationStack(path: $path) {
            editor
                .navigationDestination(for: Step.self) { step in
                    switch step {
                    case .review(let drafts):
                        DraftReviewView(drafts: drafts) { finish(String(localized: "Neurona guardada")) }
                    case .results(let concepts):
                        CaptureResultsView(concepts: concepts) { close() }
                    case .savedWithoutDistill:
                        SavedWithoutDistillView(onPro: { openPaywall() }, onDone: { close() })
                    }
                }
        }
        .overlay { confirmationToast }
        .presentationDetents([.large])
        .presentationCornerRadius(Radius.lg)
        .interactiveDismissDisabled(isSaving || dictation.isListening)
        .task { await load() }
        .alert("No se pudo guardar", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Editor

    private var editor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s5) {
                Picker("Tipo", selection: $form.kind) {
                    ForEach(CaptureForm.Kind.available) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                if form.needsThesis {
                    notice(
                        "No pudimos sacar una idea de esto. Escribí qué idea te deja y lo guardamos con tus palabras.",
                        systemImage: "exclamationmark.bubble"
                    )
                }

                input

                if form.acceptsDistill && access != .off {
                    DistillToggle(title: distillTitle, isOn: $form.distill, access: access) { openPaywall() }
                }

                CategoryPicker(categories: categories, name: $form.categoryName, focus: $focus, focusValue: .category)
            }
            .padding(Space.s4)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            saveButton
                .padding(.horizontal, Space.s4)
                .padding(.bottom, Space.s2)
                .background(Palette.surface)
        }
        .foregroundStyle(Palette.ink)
        .background(Palette.surface)
        .overlay { if isSaving && form.willDistill(canDistill: access.canDistill) { distillingOverlay } }
        .navigationTitle("Nueva neurona")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { close() }
                    .disabled(isSaving)
            }
        }
        .onChange(of: form.kind) { _, kind in
            dictation.stop()
            form.needsThesis = false
            if kind == .link || kind == .text { focus = kind == .link ? .link : .thesis }
            logFreeQuotaFallbackIfNeeded()
        }
        .onChange(of: form.attachment?.pageCount) { logFreeQuotaFallbackIfNeeded() }
    }

    @ViewBuilder
    private var input: some View {
        switch form.kind {
        case .text:
            VStack(alignment: .leading, spacing: Space.s3) {
                LumbreTextField("¿Qué idea te quedó dando vueltas?", text: $form.thesis, axis: .vertical, lines: 4...10)
                    .focused($focus, equals: .thesis)
                    .accessibilityLabel(Text("Idea"))
                thesisCounter
                if form.linkInThesis != nil {
                    linkSuggestion
                }
            }
        case .voice:
            VStack(alignment: .leading, spacing: Space.s3) {
                VoiceInput(form: form, dictation: dictation)
                thesisCounter
            }
        case .link:
            VStack(alignment: .leading, spacing: Space.s3) {
                LumbreTextField("https://", text: $form.link)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .link)
                    .accessibilityLabel(Text("Link"))
                if !form.link.isEmpty && form.linkURL == nil {
                    Label("Revisá el link: no parece válido.", systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(Palette.inkMuted)
                }
                VStack(alignment: .leading, spacing: Space.s1) {
                    Text("¿Qué idea te deja esto?")
                        .font(.headline)
                    LumbreTextField(thesisPrompt, text: $form.thesis, axis: .vertical, lines: 2...6)
                        .focused($focus, equals: .thesis)
                        .accessibilityLabel(Text("¿Qué idea te deja esto?"))
                    thesisCounter
                }
            }
        case .photo:
            VStack(alignment: .leading, spacing: Space.s3) {
                PhotoInput(form: form) { reason, message in
                    Analytics.track(.captureFailed(reason: reason))
                    errorMessage = message
                }
                if form.attachment != nil { thesisCounter }
            }
        }
    }

    private var thesisPrompt: LocalizedStringKey {
        form.willDistill(canDistill: access.canDistill) ? "Opcional: si la escribís, la destilación la usa" : "En una línea, con tus palabras"
    }

    private var distillTitle: LocalizedStringKey {
        switch form.kind {
        case .photo: form.attachment?.kind == .pdf ? "Destilar el PDF" : "Destilar la imagen"
        default: "Destilar automáticamente"
        }
    }

    @ViewBuilder
    private var thesisCounter: some View {
        if form.thesis.count > CaptureForm.thesisLimit - 100 {
            let over = form.isThesisTooLong
            Label {
                Text(over
                     ? "Te pasaste por \(form.thesis.count - CaptureForm.thesisLimit) caracteres. Dejá solo la idea (hasta 600)."
                     : "\(form.thesis.count) de 600 caracteres")
            } icon: {
                Image(systemName: over ? "exclamationmark.circle" : "character.cursor.ibeam")
            }
            .font(.footnote)
            .foregroundStyle(over ? Palette.danger : Palette.inkMuted)
        }
    }

    private var linkSuggestion: some View {
        HStack(spacing: Space.s3) {
            Image(systemName: "link")
                .foregroundStyle(Palette.infoText)
                .accessibilityHidden(true)
            Text("Parece un link. Guardalo como link para que quede la fuente.")
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Pasar a Link") {
                withAnimation(.snappy) { form.moveLinkFromThesis() }
            }
            .font(.footnote.weight(.semibold))
            .buttonStyle(.lumbre(.secondary))
        }
        .padding(Space.s3)
        .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    private func notice(_ text: LocalizedStringKey, systemImage: String) -> some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage).foregroundStyle(Palette.warning)
        }
        .font(.callout)
        .padding(Space.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    private var saveButton: some View {
        Button {
            Task { await save() }
        } label: {
            if isSaving {
                ProgressView().tint(Palette.onAccent)
            } else {
                Text("Guardar neurona")
            }
        }
        .buttonStyle(.lumbre(.primary, fullWidth: true))
        .disabled(!form.canSave(canDistill: access.canDistill) || isSaving || dictation.isListening)
        .accessibilityLabel(isSaving ? Text("Guardando") : Text("Guardar neurona"))
    }

    private var distillingOverlay: some View {
        VStack(spacing: Space.s3) {
            if neuralIdentity {
                ImpulseLoader()
            } else {
                ProgressView()
                    .controlSize(.large)
            }
            Text("Destilando…")
                .font(.headline)
            Text("Lumbre lee el contenido y saca las neuronas. Puede tardar unos segundos.")
                .font(.callout)
                .foregroundStyle(Palette.inkMuted)
                .multilineTextAlignment(.center)
        }
        .padding(Space.s6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.surface.opacity(0.94))
        .accessibilityElement(children: .combine)
        .onAppear { Analytics.screen("capture_distilling") }
    }

    @ViewBuilder
    private var confirmationToast: some View {
        if let confirmation {
            VStack {
                Spacer()
                Label(confirmation, systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, Space.s5)
                    .padding(.vertical, Space.s3)
                    .background(Palette.surfaceAlt, in: Capsule())
                    .overlay(Capsule().strokeBorder(Palette.border, lineWidth: 1))
                    .padding(.horizontal, Space.s4)
                    .padding(.bottom, Space.s10 + Space.s8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.scrim.opacity(0.3))
            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            .accessibilityAddTraits(.isStaticText)
        }
    }

    // MARK: - Carga

    private func load() async {
        entry = appModel.captureEntry ?? "fab"
        Analytics.track(.captureOpened(entry: entry))
        Analytics.screen("capture")
        if form.categoryName.isEmpty { form.categoryName = lastCategory }
        form.distill = appModel.isPro
        focus = .thesis
        if FeatureFlag.offlineQueue.isEnabled {
            await CaptureQueue.shared.startMonitoring(api: api)
        }
        let api = api
        let needsCredits = !appModel.isGuest && !appModel.isPro
        async let categories = try? api.categories()
        async let credits: [Credit]? = needsCredits ? try? api.credits() : []
        self.categories = await categories ?? []
        self.credits = await credits
        logFreeQuotaFallbackIfNeeded()
    }

    /// Con las pruebas agotadas, link y adjuntos piden "¿Qué idea te deja esto?" (`distill_fallback_shown`).
    private func logFreeQuotaFallbackIfNeeded() {
        guard !loggedFreeQuotaFallback, case .trials(let remaining, _) = access, remaining == 0, form.acceptsDistill else { return }
        loggedFreeQuotaFallback = true
        Analytics.track(.distillFallbackShown(reason: "free_quota"))
    }

    // MARK: - Guardar

    private func save() async {
        guard let request = form.makeRequest(canDistill: access.canDistill) else { return }
        dictation.stop()
        focus = nil
        isSaving = true
        defer { isSaving = false }
        do {
            let result = try await api.capture(request)
            submitted(request, offline: false)
            lastCategory = request.category
            savedSomething()
            handle(result)
        } catch LumbreAPIError.needsThesis {
            showNeedsThesis()
        } catch let error where CaptureQueue.isConnectivityError(error) && FeatureFlag.offlineQueue.isEnabled {
            await enqueue(request)
        } catch {
            fail(error)
        }
    }

    private func handle(_ result: CaptureResult) {
        switch result.distillation {
        case .needsThesis:
            showNeedsThesis()
        case .medium:
            let drafts = result.concepts.filter(\.isDraft)
            if drafts.isEmpty {
                finish(String(localized: "Neurona guardada"))
            } else {
                path.append(.review(drafts))
            }
        case .quotaExceeded:
            credits = credits.map { $0.map { $0.kind == .distill ? Credit(kind: .distill, period: $0.period, max: $0.max, remaining: 0) : $0 } }
            path.append(.savedWithoutDistill)
        case .none, .high, .unavailable:
            if result.concepts.count > 1 {
                path.append(.results(result.concepts))
            } else {
                finish(String(localized: "Neurona guardada"))
            }
        }
    }

    private func showNeedsThesis() {
        Analytics.track(.distillFallbackShown(reason: "low_confidence"))
        withAnimation(.snappy) {
            form.needsThesis = true
            form.distill = false
        }
        focus = .thesis
        AccessibilityNotification.Announcement(String(localized: "No pudimos sacar una idea de esto. Escribí qué idea te deja.")).post()
    }

    private func enqueue(_ request: CaptureRequest) async {
        do {
            try await CaptureQueue.shared.enqueue(request)
            await CaptureQueue.shared.startMonitoring(api: api)
            submitted(request, offline: true)
            lastCategory = request.category
            finish(String(localized: "Guardado sin conexión: lo mandamos cuando vuelva"), delay: .milliseconds(1800))
        } catch {
            Analytics.track(.captureFailed(reason: "network"))
            errorMessage = String(localized: "Sin conexión y no pudimos guardarlo en el teléfono. Probá de nuevo en un rato.")
        }
    }

    private func submitted(_ request: CaptureRequest, offline: Bool) {
        Analytics.track(.captureSubmitted(entry: entry, sourceType: request.source.sourceType, distillRequested: request.distill,
                                          offline: offline, words: form.words))
    }

    private func fail(_ error: Error) {
        let reason: String
        switch error as? LumbreAPIError {
        case .quotaExceeded: reason = "rate_limited"
        case .offline: reason = "network"
        default: reason = CaptureQueue.isConnectivityError(error) ? "network" : "server_error"
        }
        Analytics.track(.captureFailed(reason: reason))
        switch error as? LumbreAPIError {
        case .proRequired:
            openPaywall()
        case .some(let apiError):
            errorMessage = apiError.errorDescription
        case .none:
            errorMessage = CaptureQueue.isConnectivityError(error)
                ? String(localized: "Sin conexión. Probá de nuevo cuando vuelva la red.")
                : String(localized: "Algo salió mal. Probá de nuevo.")
        }
    }

    private func savedSomething() {
        if let onSaved { onSaved() } else { appModel.dataChanged() }
    }

    /// Muestra el aviso y cierra.
    private func finish(_ message: String, delay: Duration = .milliseconds(1000)) {
        withAnimation(reduceMotion ? nil : .snappy) { confirmation = message }
        AccessibilityNotification.Announcement(message).post()
        Task {
            try? await Task.sleep(for: delay)
            close()
        }
    }

    private func close() {
        dictation.stop()
        dismiss()
    }

    /// El paywall se abre después de cerrar la sheet, para no apilar dos sheets.
    private func openPaywall() {
        close()
        let appModel = appModel
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            appModel.presentPaywall(trigger: "distill")
        }
    }
}

#Preview("Capturar") {
    Color.clear.sheet(isPresented: .constant(true)) {
        CaptureSheet()
    }
    .environment(AppModel())
    .preferredColorScheme(.light)
    .tint(Palette.ink)
}
