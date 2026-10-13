import LumbreCore
import LumbreDesign
import SwiftUI

/// Planificador Pro: chat anclado a una chispa. Conoce el perfil, los dos conceptos y el proyecto.
struct PlannerView: View {
    let sparkID: Spark.ID
    /// `planner_opened.entry`: `spark_detail` o `project`.
    let entry: String

    @Environment(\.api) private var api
    @Environment(AppModel.self) private var appModel
    @State private var spark: Spark?
    @State private var messages: [PlannerMessage] = []
    @State private var credits: [Credit] = []
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var mode: PlannerMode = .quick
    @State private var draft = ""
    /// Mensaje del usuario que se está procesando y la respuesta que va llegando.
    @State private var pending: (question: String, answer: String)?
    @State private var streamTask: Task<Void, Never>?
    @State private var inlineError: String?
    @State private var reportingMessage: PlannerMessage?
    @State private var didReport = false
    @State private var didTrackOpen = false
    @FocusState private var isComposing: Bool

    private static let bottomID = "bottom"

    var body: some View {
        Group {
            if !appModel.isPro {
                lockedState
            } else if let loadError {
                ScrollView { LoadErrorView(error: loadError) { Task { await load() } } }
            } else {
                chat
            }
        }
        .neuralBackground()
        .navigationTitle("Planificar")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onAppear {
            Analytics.screen("planner")
            if !didTrackOpen {
                didTrackOpen = true
                Analytics.track(.plannerOpened(entry: entry))
            }
        }
        .onDisappear { streamTask?.cancel() }
        .confirmationDialog(
            "Reportar esta respuesta",
            isPresented: Binding(get: { reportingMessage != nil }, set: { if !$0 { reportingMessage = nil } }),
            titleVisibility: .visible,
            presenting: reportingMessage
        ) { message in
            ForEach(ReportReason.allCases, id: \.self) { reason in
                Button(reason.label) { report(message, reason: reason) }
            }
        } message: { _ in
            Text("La revisamos y ajustamos lo que genera Lumbre.")
        }
    }

    // MARK: Chat

    private var chat: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Space.s3) {
                    header
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, Space.s8)
                    } else if messages.isEmpty && pending == nil {
                        emptyHint
                    }
                    ForEach(messages) { message in
                        bubble(for: message)
                    }
                    if let pending {
                        ChatBubble(role: .user, text: pending.question)
                        ChatBubble(role: .planner, text: pending.answer.isEmpty ? "…" : pending.answer, isStreaming: true)
                            .accessibilityLabel(pending.answer.isEmpty ? Text("El planificador está escribiendo") : Text(pending.answer))
                    }
                    if let inlineError {
                        ActionNotice(text: "\(inlineError)", symbol: "exclamationmark.triangle.fill", color: Palette.danger)
                    }
                    if didReport {
                        ActionNotice(text: "Gracias por avisar. La vamos a revisar.")
                    }
                    Color.clear.frame(height: 1).id(Self.bottomID)
                }
                .padding(.horizontal, Space.s4)
                .padding(.vertical, Space.s3)
            }
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            .onChange(of: messages.count) { scrollToBottom(proxy) }
            .onChange(of: pending?.answer) { scrollToBottom(proxy, animated: false) }
            .safeAreaInset(edge: .bottom) { composer }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(spark?.title ?? MockData.todaySpark.title)
                .font(.headline)
                .foregroundStyle(Palette.ink)
            Group {
                if let projectName = spark?.projectName {
                    Text("Circuito: \(projectName)")
                } else {
                    Text("\(spark?.conceptA.title ?? "") × \(spark?.conceptB.title ?? "")")
                }
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(Palette.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.s3)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).strokeBorder(Palette.border, lineWidth: 1))
        .redacted(reason: spark == nil ? .placeholder : [])
        .accessibilityElement(children: .combine)
        .padding(.bottom, Space.s2)
    }

    private var emptyHint: some View {
        Text("Preguntá lo que quieras sobre esta idea o elegí un atajo: un backlog para arrancar, un abogado del diablo o el stack que usarías.")
            .font(.callout)
            .foregroundStyle(Palette.inkMuted)
            .padding(.vertical, Space.s2)
    }

    @ViewBuilder
    private func bubble(for message: PlannerMessage) -> some View {
        switch message.role {
        case .user:
            ChatBubble(role: .user, text: message.content)
        case .assistant:
            ChatBubble(role: .planner, text: message.content)
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = message.content
                    } label: {
                        Label("Copiar", systemImage: "doc.on.doc")
                    }
                    Button {
                        reportingMessage = message
                    } label: {
                        Label("Reportar", systemImage: "flag")
                    }
                }
                .accessibilityAction(named: "Reportar") { reportingMessage = message }
        }
    }

    // MARK: Composer

    private var composer: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s2) {
                    ForEach(PlannerPreset.allCases, id: \.self) { preset in
                        Button {
                            send(preset.prompt)
                        } label: {
                            LumbreChip(preset.label, variant: .select)
                        }
                        .buttonStyle(.plain)
                        .disabled(isStreaming || isLoading)
                    }
                }
            }
            .scrollClipDisabled()

            modePicker

            HStack(alignment: .bottom, spacing: Space.s2) {
                TextField("Escribí o preguntá…", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($isComposing)
                    .padding(.horizontal, Space.s3)
                    .padding(.vertical, Space.s2 + 2)
                    .frame(minHeight: 44)
                    .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Palette.borderStrong, lineWidth: 1))
                if isStreaming {
                    Button {
                        stop()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.body.weight(.bold))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 44, height: 44)
                            .background(Palette.surfaceAlt, in: Circle())
                            .overlay(Circle().strokeBorder(Palette.borderStrong, lineWidth: 1))
                    }
                    .accessibilityLabel("Detener respuesta")
                } else {
                    Button {
                        send(draft)
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.body.weight(.bold))
                            .foregroundStyle(Palette.onAccent)
                            .frame(width: 44, height: 44)
                            .background(Palette.accent, in: Circle())
                    }
                    .disabled(trimmedDraft.isEmpty || isLoading)
                    .opacity(trimmedDraft.isEmpty ? 0.4 : 1)
                    .accessibilityLabel("Enviar")
                }
            }
        }
        .padding(.horizontal, Space.s4)
        .padding(.top, Space.s3)
        .padding(.bottom, Space.s2)
        .background(Palette.bg.opacity(0.96))
        .overlay(alignment: .top) { Divider().overlay(Palette.border) }
    }

    private var modePicker: some View {
        HStack(spacing: Space.s2) {
            modeOption(.quick, title: "Rápido")
            modeOption(.deep, title: "Plan profundo")
            Spacer(minLength: Space.s2)
            if let quota = quotaText {
                quota
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Palette.inkMuted)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func modeOption(_ option: PlannerMode, title: LocalizedStringKey) -> some View {
        let selected = mode == option
        return Button {
            mode = option
        } label: {
            HStack(spacing: Space.s1) {
                Text(title)
                if option == .deep {
                    Text("Pro")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Palette.onPro)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Palette.pro, in: Capsule())
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(selected ? (option == .deep ? Palette.proText : Palette.ink) : Palette.inkMuted)
            .padding(.horizontal, Space.s3)
            .padding(.vertical, 6)
            .frame(minHeight: 32)
            .background {
                let shape = Capsule()
                if selected {
                    shape.fill(Palette.surfaceAlt).overlay(shape.strokeBorder(option == .deep ? Palette.pro : Palette.borderStrong, lineWidth: 1))
                } else {
                    shape.strokeBorder(Palette.border, lineWidth: 1)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// "Te quedan 280 · 58 profundos este mes".
    private var quotaText: Text? {
        let quick = credits.first { $0.kind == .planner }
        let deep = credits.first { $0.kind == .plannerDeep }
        switch mode {
        case .quick:
            guard let quick else { return nil }
            return Text("Te quedan \(quick.remaining) este mes")
        case .deep:
            guard let deep else { return nil }
            return Text("Te quedan \(deep.remaining) profundos")
        }
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isStreaming: Bool { pending != nil }

    // MARK: Lógica

    private var lockedState: some View {
        ContentUnavailableView {
            Label("El planificador es parte de Lumbre Pro", systemImage: "text.bubble")
        } description: {
            Text("Bajá cada idea a un plan: un backlog para arrancar, un abogado del diablo y el stack que usarías.")
        } actions: {
            Button("Ver Lumbre Pro") { appModel.presentPaywall(trigger: "planner") }
                .buttonStyle(.lumbre(.pro))
        }
    }

    private func load() async {
        do {
            async let spark = api.spark(id: sparkID)
            async let messages = api.plannerMessages(sparkID: sparkID)
            (self.spark, self.messages) = try await (spark, messages)
            loadError = nil
        } catch {
            loadError = error
        }
        isLoading = false
        await loadCredits()
    }

    private func loadCredits() async {
        if let credits = try? await api.credits() {
            self.credits = credits
        }
    }

    private func send(_ text: String) {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isStreaming else { return }
        draft = ""
        inlineError = nil
        didReport = false
        pending = (question, "")
        let mode = mode
        streamTask = Task {
            do {
                for try await chunk in api.sendPlannerMessage(sparkID: sparkID, text: question, mode: mode) {
                    pending?.answer += chunk
                }
                await finish()
            } catch is CancellationError {
                await finish(stopped: true)
            } catch LumbreAPIError.proRequired {
                pending = nil
                draft = question
                appModel.presentPaywall(trigger: "planner")
            } catch LumbreAPIError.quotaExceeded {
                pending = nil
                draft = question
                inlineError = mode == .deep
                    ? String(localized: "Llegaste al uso justo de plan profundo de este mes. Podés seguir en modo rápido.")
                    : String(localized: "Llegaste al uso justo del planificador de este mes. Se renueva el mes que viene.")
            } catch {
                if Task.isCancelled {
                    await finish(stopped: true)
                } else {
                    pending = nil
                    draft = question
                    inlineError = error.localizedDescription
                }
            }
            streamTask = nil
        }
    }

    private func stop() {
        streamTask?.cancel()
    }

    /// Recarga el hilo del servidor (con los ids para poder reportar). Si se frenó, deja lo que llegó.
    private func finish(stopped: Bool = false) async {
        let partial = pending
        if let fresh = try? await api.plannerMessages(sparkID: sparkID), !fresh.isEmpty, fresh.count > messages.count {
            messages = fresh
        } else if let partial {
            let base = (messages.map(\.id).max() ?? 0)
            messages.append(PlannerMessage(id: base + 1, role: .user, content: partial.question, mode: mode, createdAt: .now))
            if !partial.answer.isEmpty {
                let answer = stopped ? partial.answer + "\n\n" + String(localized: "_(Respuesta detenida)_") : partial.answer
                messages.append(PlannerMessage(id: base + 2, role: .assistant, content: answer, mode: mode, createdAt: .now))
            }
        }
        pending = nil
        await loadCredits()
    }

    private func report(_ message: PlannerMessage, reason: ReportReason) {
        Task {
            do {
                // Mientras no haya un endpoint propio, el reporte va con la chispa y el id del mensaje en la nota.
                try await api.reportSpark(id: sparkID, reason: reason, note: "planner_message:\(message.id)")
                Analytics.track(.aiContentReported(object: "planner_message", reason: reason))
                didReport = true
            } catch {
                inlineError = error.localizedDescription
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        if animated {
            withAnimation(.snappy) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
        } else {
            proxy.scrollTo(Self.bottomID, anchor: .bottom)
        }
    }
}

extension PlannerPreset {
    var label: String {
        switch self {
        case .backlog: String(localized: "Armá un backlog")
        case .devilsAdvocate: String(localized: "Abogado del diablo")
        case .stack: String(localized: "¿Qué stack usarías?")
        }
    }

    /// Mensaje predefinido que manda el atajo.
    var prompt: String {
        switch self {
        case .backlog: String(localized: "Armá un backlog de 5 tareas para arrancar con esta idea.")
        case .devilsAdvocate: String(localized: "Hacé de abogado del diablo: ¿por qué podría fallar esta idea?")
        case .stack: String(localized: "¿Qué stack usarías para construir esto?")
        }
    }
}

#Preview {
    NavigationStack {
        PlannerView(sparkID: MockData.recentSparks[0].id, entry: "spark_detail")
    }
    .environment(AppModel())
    .preferredColorScheme(.light)
}
