import LumbreCore
import LumbreDesign
import SwiftUI

/// Planificador Pro: chat anclado a una chispa. Conoce el perfil, las dos neuronas y el circuito.
/// Con el flag `planner_disney`, guía con el método de los tres cuartos de Walt Disney: Soñador, Realista, Crítico y síntesis.
/// Con el flag `planner_lenses`, suma tres lentes: la chispa como modelo de negocio, trama o post (planner_lens.v1).
struct PlannerView: View {
    let sparkID: Spark.ID
    /// `planner_opened.entry`: `spark_detail` o `project`.
    let entry: String

    @Environment(\.api) private var api
    @Environment(AppModel.self) private var appModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
                    if usesDisney && (!messages.isEmpty || pending != nil) {
                        RoomStepper(current: currentRoom)
                            .padding(.bottom, Space.s2)
                    }
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, Space.s8)
                    } else if messages.isEmpty && pending == nil {
                        if usesDisney { disneyIntro } else { emptyHint }
                        if usesDisney && usesLenses { lensIntro }
                    }
                    ForEach(messages) { message in
                        bubble(for: message)
                    }
                    if let pending {
                        ChatBubble(role: .user, text: pending.question)
                        let visible = PlannerRoom.split(pending.answer).text
                        ChatBubble(role: .planner, text: visible.isEmpty ? "…" : visible, isStreaming: true)
                            .accessibilityLabel(visible.isEmpty ? Text("El planificador está escribiendo") : Text(visible))
                    }
                    if let inlineError {
                        ActionNotice(text: "\(inlineError)", symbol: "exclamationmark.triangle.fill", color: Palette.danger)
                    }
                    if didReport {
                        ActionNotice(text: "Gracias por avisar. La vamos a revisar.")
                    }
                    if isLargeText {
                        VStack(alignment: .leading, spacing: Space.s2) {
                            quickReplyButtons
                            modePicker
                        }
                        .padding(.top, Space.s2)
                    }
                    Color.clear.frame(height: 1).id(Self.bottomID)
                }
                .padding(.horizontal, Space.s4)
                .padding(.vertical, Space.s3)
            }
            .scrollDismissesKeyboard(.interactively)
            // Sin `defaultScrollAnchor(.bottom)`: con pocos mensajes pegaba el hilo abajo y dejaba un hueco arriba.
            // Arranca arriba y baja al último mensaje solo si el hilo no entra en la pantalla.
            .onAppear { scrollToBottom(proxy, animated: false) }
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
        Text(usesLenses
             ? "Preguntá lo que quieras sobre esta idea o elegí un atajo: un backlog para arrancar, un abogado del diablo, el stack que usarías o una lente para verla como modelo de negocio, trama o post."
             : "Preguntá lo que quieras sobre esta idea o elegí un atajo: un backlog para arrancar, un abogado del diablo o el stack que usarías.")
            .font(.callout)
            .foregroundStyle(Palette.inkMuted)
            .padding(.vertical, Space.s2)
    }

    @ViewBuilder
    private func bubble(for message: PlannerMessage) -> some View {
        switch message.role {
        case .user:
            ChatBubble(role: .user, text: message.displayText)
        case .assistant:
            if let lens = message.lens {
                Text("Lente: \(lens.title)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.inkMuted)
                    .padding(.bottom, -Space.s2)
            }
            ChatBubble(role: .planner, text: message.displayText)
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

    /// Con tamaños de accesibilidad, los atajos y el modo bajan al final del chat y en la barra queda solo el campo:
    /// con todo abajo, la barra tapaba casi toda la pantalla y "Plan profundo" se cortaba por sílabas.
    private var isLargeText: Bool { dynamicTypeSize.isAccessibilitySize }

    /// Con tamaños de accesibilidad, el largo se cortaba en "pr…".
    private var placeholder: LocalizedStringKey { isLargeText ? "Preguntá…" : "Escribí o preguntá…" }

    private var composer: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            if !isLargeText {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.s2) { quickReplyButtons }
                }
                .scrollClipDisabled()

                modePicker
            }

            HStack(alignment: .bottom, spacing: Space.s2) {
                TextField(placeholder, text: $draft, axis: .vertical)
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

    private var quickReplyButtons: some View {
        Group {
            ForEach(quickReplies, id: \.label) { reply in
                Button {
                    send(reply.prompt)
                } label: {
                    LumbreChip(reply.label, variant: .select)
                }
                .buttonStyle(.plain)
                .disabled(isStreaming || isLoading)
            }
            ForEach(composerLenses, id: \.self) { lens in
                Button {
                    send(lens.prompt, lens: lens)
                } label: {
                    LumbreChip(lens.title, systemImage: "eyeglasses", variant: .select)
                }
                .buttonStyle(.plain)
                .disabled(isStreaming || isLoading)
                .accessibilityLabel(Text("Lente: \(lens.title)"))
            }
        }
    }

    private var modePicker: some View {
        let layout = isLargeText
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.s2))
            : AnyLayout(HStackLayout(spacing: Space.s2))
        return layout {
            modeOption(.quick, title: "Rápido")
            modeOption(.deep, title: "Plan profundo")
            if !isLargeText {
                Spacer(minLength: Space.s2)
            }
            if let quota = quotaText {
                quota
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Palette.inkMuted)
                    .multilineTextAlignment(isLargeText ? .leading : .trailing)
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

    // MARK: Método de los tres cuartos

    private var usesDisney: Bool { FeatureFlag.disneyPlanner.isEnabled }

    /// Cuarto de la última respuesta con marca (o de la que está llegando).
    private var currentRoom: PlannerRoom? {
        if let pending, let room = PlannerRoom.split(pending.answer).room { return room }
        return messages.last { $0.role == .assistant && $0.room != nil }?.room
    }

    /// Atajos del composer: en los cuartos, los del método; antes de empezar, ninguno (arranca con el botón del Soñador);
    /// con un hilo que no entró al método, la entrada al Soñador y los de siempre; después de la síntesis o sin el método,
    /// los de siempre.
    private var quickReplies: [(label: String, prompt: String)] {
        let presets = PlannerPreset.allCases.map { (label: $0.label, prompt: $0.prompt) }
        guard usesDisney else { return presets }
        switch currentRoom {
        case nil:
            // Un hilo que empezó sin el método (o con una lente) puede entrar al Soñador desde acá.
            let start = (label: String(localized: "Entrar al cuarto del Soñador"), prompt: String(localized: "Empecemos por el Soñador."))
            return messages.isEmpty ? [] : [start] + presets
        case .dreamer: return [
            (String(localized: "Más grande todavía"), String(localized: "Llevalo más grande todavía.")),
            (String(localized: "Pasemos al Realista"), String(localized: "Pasemos al siguiente cuarto: el Realista.")),
        ]
        case .realist: return [
            (String(localized: "No sé cuánta plata"), String(localized: "Todavía no sé cuánta plata haría falta.")),
            (String(localized: "Pasemos al Crítico"), String(localized: "Pasemos al siguiente cuarto: el Crítico.")),
        ]
        case .critic: return [
            (String(localized: "Pasemos a la síntesis"), String(localized: "Pasemos al siguiente cuarto: la síntesis.")),
        ]
        case .plan: return presets
        }
    }

    // MARK: Lentes

    private var usesLenses: Bool { FeatureFlag.plannerLenses.isEnabled }

    /// Las lentes van donde van los atajos de siempre: sin el método, después de la síntesis o si el hilo empezó
    /// sin el método. En los cuartos no aparecen, para no sacar a la persona del método (el servidor igual no lo avanza).
    /// Con el método y el hilo vacío, están en la intro (`lensIntro`).
    private var composerLenses: [PlannerLens] {
        guard usesLenses else { return [] }
        guard usesDisney else { return PlannerLens.allCases }
        switch currentRoom {
        case nil: return messages.isEmpty ? [] : PlannerLens.allCases
        case .plan: return PlannerLens.allCases
        case .dreamer, .realist, .critic: return []
        }
    }

    private var lensIntro: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text("O mirala con una lente")
                .font(.headline)
                .foregroundStyle(Palette.ink)
            Text("Un modelo de negocio, una trama o un post, cada uno con su formato.")
                .font(.callout)
                .foregroundStyle(Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Space.s2) { lensIntroButtons }
                VStack(alignment: .leading, spacing: Space.s2) { lensIntroButtons }
            }
        }
        .padding(.top, Space.s4)
    }

    private var lensIntroButtons: some View {
        ForEach(PlannerLens.allCases, id: \.self) { lens in
            Button {
                send(lens.prompt, lens: lens)
            } label: {
                LumbreChip(lens.title, systemImage: "eyeglasses", variant: .select)
            }
            .buttonStyle(.plain)
            .disabled(isStreaming || isLoading)
            .accessibilityLabel(Text("Lente: \(lens.title)"))
        }
    }

    private var disneyIntro: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text("Tres cuartos, de a uno")
                .lumbreDisplay(.title2)
                .foregroundStyle(Palette.ink)
            Text("Vamos a pasar esta chispa por el método de Walt Disney. No se entra al cuarto siguiente hasta terminar el actual.")
                .font(.callout)
                .foregroundStyle(Palette.inkMuted)
            VStack(alignment: .leading, spacing: 0) {
                roomLine("Soñador", "Cómo se ve si funciona por completo, sin presupuesto ni reglas. Y después, más grande.")
                roomLine("Realista", "Los pasos, la gente, la plata y lo primero que tiene que pasar.")
                roomLine("Crítico", "Qué falta, qué puede salir mal y quién lo odiaría.")
                roomLine("Síntesis", "El sueño en una frase, el plan en cinco pasos, los tres agujeros y el cuarto que salteás.")
            }
            Button {
                send(String(localized: "Empecemos por el Soñador."))
            } label: {
                Label {
                    Text("Entrar al cuarto del Soñador")
                } icon: {
                    Circle().fill(Palette.spark).frame(width: 10, height: 10)
                }
            }
            .buttonStyle(.lumbre(.primary, fullWidth: true))
            .disabled(isLoading)
            Text("Cada respuesta usa una consulta del planificador.")
                .font(.footnote)
                .foregroundStyle(Palette.inkMuted)
        }
        .padding(.vertical, Space.s2)
    }

    private func roomLine(_ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline).foregroundStyle(Palette.ink)
            Text(detail).font(.callout).foregroundStyle(Palette.inkMuted).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Space.s2)
        .axonRow(spacing: 0) {
            Circle().fill(Palette.ink).frame(width: 12, height: 12)
        }
    }

    // MARK: Lógica

    private var lockedState: some View {
        ContentUnavailableView {
            Label("El planificador es parte de Lumbre Pro", systemImage: "text.bubble")
        } description: {
            Text(usesDisney
                 ? "Bajá cada idea a un plan con el método de los tres cuartos de Walt Disney: soñarla en grande, hacerla real y buscarle los agujeros."
                 : "Bajá cada idea a un plan: un backlog para arrancar, un abogado del diablo y el stack que usarías.")
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

    private func send(_ text: String, lens: PlannerLens? = nil) {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isStreaming else { return }
        // Sin el "Acepto" no sale nada hacia la IA, tampoco una lente (el servidor responde 403 ai_consent_required).
        guard AIConsent.isGranted else {
            appModel.presentAIConsent()
            return
        }
        let method: PlannerMethod = usesDisney ? .disney : .free
        if let lens {
            Analytics.track(.plannerLensUsed(lens: lens, mode: mode, method: method))
        }
        draft = ""
        inlineError = nil
        didReport = false
        pending = (question, "")
        let mode = mode
        streamTask = Task {
            do {
                for try await chunk in api.sendPlannerMessage(sparkID: sparkID, text: question, mode: mode, method: method, lens: lens) {
                    pending?.answer += chunk
                }
                await finish()
            } catch is CancellationError {
                await finish(stopped: true)
            } catch LumbreAPIError.proRequired {
                pending = nil
                draft = question
                appModel.presentPaywall(trigger: "planner")
            } catch LumbreAPIError.accountRequired {
                pending = nil
                draft = question
                appModel.presentAccount(trigger: "planner")
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
            withAnimation(reduceMotion ? nil : .snappy) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
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

/// Los cuatro pasos del método colgados de un axón: los hechos en negro, el actual es una neurona con el núcleo rosa.
private struct RoomStepper: View {
    let current: PlannerRoom?

    var body: some View {
        let rooms = PlannerRoom.allCases
        let index = current.flatMap { rooms.firstIndex(of: $0) }
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(rooms.enumerated()), id: \.offset) { i, room in
                VStack(spacing: Space.s1) {
                    ZStack {
                        if i == index {
                            MiniNeuron(isLit: true).frame(width: 30, height: 30)
                        } else {
                            Circle()
                                .fill((index ?? -1) > i ? Palette.ink : Palette.border)
                                .frame(width: 12, height: 12)
                        }
                    }
                    .frame(height: 30)
                    Text(room.title)
                        .font(.caption.weight(i == index ? .semibold : .regular))
                        .foregroundStyle(i == index ? Palette.ink : Palette.inkMuted)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(alignment: .top) {
            Rectangle()
                .fill(Palette.border)
                .frame(height: 2)
                .padding(.horizontal, Space.s10)
                .padding(.top, 14)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(current.map { Text("Cuarto actual: \($0.title)") } ?? Text("El método todavía no arrancó"))
    }
}

extension PlannerLens {
    var title: String {
        switch self {
        case .businessModel: String(localized: "Modelo de negocio")
        case .plot: String(localized: "Trama")
        case .post: String(localized: "Post")
        }
    }

    /// Mensaje que manda la lente (el formato lo pide el servidor con `lens`, no este texto).
    var prompt: String {
        switch self {
        case .businessModel: String(localized: "Convertí esta chispa en un modelo de negocio.")
        case .plot: String(localized: "Convertí esta chispa en una trama.")
        case .post: String(localized: "Convertí esta chispa en un post.")
        }
    }
}

extension PlannerRoom {
    var title: String {
        switch self {
        case .dreamer: String(localized: "Soñador")
        case .realist: String(localized: "Realista")
        case .critic: String(localized: "Crítico")
        case .plan: String(localized: "Plan")
        }
    }
}
