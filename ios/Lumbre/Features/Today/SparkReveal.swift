import LumbreCore
import LumbreDesign
import SwiftUI

/// La chispa protagonista de Hoy. Si todavía no se vio, muestra el estado previo y hace el reveal:
/// el único momento coreografiado de la app (design/system/README.md, "Movimiento y háptica").
struct SparkHero: View {
    let spark: Spark
    /// `spark_revealed.entry`: `app`, `push` o `widget`.
    var entry = "app"
    var onChange: (Spark) -> Void = { _ in }
    /// Abre el planificador en la navegación de Hoy (el modal del reveal no tiene una propia).
    var onPlan: (Spark.ID) -> Void = { _ in }

    @Environment(\.api) private var api
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.neuralIdentity) private var neuralIdentity
    @AppStorage("hasSeenSpark") private var hasSeenSpark = false
    @State private var phase: Phase
    @State private var collisions = 0
    /// Identidad neuronal: el reveal pasa en un modal sobre el fondo desenfocado.
    @State private var isShowingReveal = false
    /// El toque en "Encender la chispa" con el flag `reveal_synapse`: el reloj de la coreografía del modal.
    @State private var revealStart: Date?

    enum Phase: Int, Comparable {
        case idle, approaching, collided, revealed
        static func < (lhs: Phase, rhs: Phase) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    init(spark: Spark, entry: String = "app", onPlan: @escaping (Spark.ID) -> Void = { _ in }, onChange: @escaping (Spark) -> Void = { _ in }) {
        self.spark = spark
        self.entry = entry
        self.onPlan = onPlan
        self.onChange = onChange
        _phase = State(initialValue: spark.isPending ? .idle : .revealed)
    }

    var body: some View {
        ZStack(alignment: .top) {
            if phase < .revealed {
                Group {
                    if neuralIdentity { neuralStage } else { stage }
                }
                .transition(.opacity)
            } else {
                SparkCard(a: SparkSide(spark.conceptA), b: SparkSide(spark.conceptB), title: spark.title, explanation: spark.body) {
                    SparkActions(spark: spark, onChange: onChange)
                }
                .transition(reduceMotion ? .opacity : .scale(scale: 0.94, anchor: .center).combined(with: .opacity))
            }
        }
        .sensoryFeedback(.success, trigger: collisions)
        .fullScreenCover(isPresented: $isShowingReveal) {
            if let revealStart {
                // El material y el velo van adentro del modal, en el mismo fundido que el panel.
                SynapseRevealModal(spark: spark, start: revealStart, isRevealed: phase == .revealed, onChange: onChange, onPlan: {
                    dismissRevealWithoutSliding()
                    Task {
                        try? await Task.sleep(for: .milliseconds(100))
                        onPlan(spark.id)
                    }
                }) { dismissRevealWithoutSliding() }
                    .presentationBackground(.clear)
            } else {
                SparkRevealModal(spark: spark, phase: phase, onChange: onChange, onPlan: {
                    isShowingReveal = false
                    // Deja que se cierre el modal antes de empujar el planificador.
                    Task {
                        try? await Task.sleep(for: .milliseconds(350))
                        onPlan(spark.id)
                    }
                }) { isShowingReveal = false }
                    .presentationBackground(.ultraThinMaterial)
            }
        }
    }

    // MARK: Estado previo y choque

    /// Identidad neuronal: sin tarjeta. Las dos neuronas con sus nombres, la sinapsis que se conecta al encender
    /// y el botón negro con el punto rosa (el rosa siempre sobre negro).
    private var neuralStage: some View {
        VStack(spacing: Space.s4) {
            SparkPairHeader(a: SparkSide(spark.conceptA), b: SparkSide(spark.conceptB))
            Synapse(phase >= .collided ? .lit : phase >= .approaching ? .reaching : .apart, full: true)
                .frame(maxWidth: 320)
                .frame(maxWidth: .infinity)
                .scaleEffect(phase >= .collided ? 1.08 : 1)
                .padding(.vertical, Space.s2)
            VStack(spacing: Space.s1) {
                Text(spark.mode == .daily ? "Tu chispa de hoy está lista" : "Tu chispa extra está lista")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                Text("Dos neuronas tuyas de mundos distintos están por conectarse.")
                    .font(.callout)
                    .foregroundStyle(Palette.inkMuted)
                    .multilineTextAlignment(.center)
            }
            .opacity(phase >= .collided ? 0 : 1)
            Button(action: ignite) {
                Label {
                    Text("Encender la chispa")
                } icon: {
                    Circle().fill(Palette.spark).frame(width: 10, height: 10)
                }
            }
            .buttonStyle(.lumbre(.primary, fullWidth: true))
            .disabled(phase > .idle)
            .opacity(phase > .idle ? 0 : 1)
            .accessibilityHint("Revela la chispa")
        }
        .padding(.vertical, Space.s2)
    }

    private var stage: some View {
        VStack(spacing: Space.s6) {
            VStack(spacing: Space.s1) {
                Text(spark.mode == .daily ? "Tu chispa de hoy está lista" : "Tu chispa extra está lista")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                Text("Dos neuronas tuyas de mundos distintos están por conectarse.")
                    .font(.callout)
                    .foregroundStyle(Palette.inkMuted)
                    .multilineTextAlignment(.center)
            }
            .opacity(phase >= .collided ? 0 : 1)

            collision

            Button(action: ignite) {
                Label {
                    Text("Encender la chispa")
                } icon: {
                    SparkStar().frame(width: 16, height: 16)
                }
            }
            .buttonStyle(.lumbre(.primary, fullWidth: true))
            .lumbreShadow(.glowSpark)
            .disabled(phase > .idle)
            .opacity(phase > .idle ? 0 : 1)
            .accessibilityHint("Revela la chispa")
        }
        .padding(Space.s5)
        .frame(maxWidth: .infinity)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).strokeBorder(Palette.border, lineWidth: 1))
    }

    /// Las dos tarjetas separadas; al encender se acercan, chocan y aparece la estrella.
    private var collision: some View {
        let gap: CGFloat = 36
        let travel = gap / 2 + 6
        return ZStack {
            HStack(spacing: gap) {
                tile(spark.conceptA)
                    .rotationEffect(.degrees(phase >= .approaching ? 3 : -2))
                    .offset(x: phase >= .approaching ? travel : 0)
                tile(spark.conceptB)
                    .rotationEffect(.degrees(phase >= .approaching ? -3 : 2))
                    .offset(x: phase >= .approaching ? -travel : 0)
            }
            .scaleEffect(phase >= .collided ? 0.9 : 1)
            .opacity(phase >= .collided ? 0 : 1)

            Text("×")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Palette.inkMuted)
                .opacity(phase >= .approaching ? 0 : 1)
                .accessibilityHidden(true)

            SparkStar()
                .fill(Palette.spark)
                .frame(width: 56, height: 56)
                .lumbreShadow(.glowSpark)
                .scaleEffect(phase >= .collided ? 1 : 0.1)
                .opacity(phase >= .collided ? 1 : 0)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    private func tile(_ concept: Concept) -> some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Label(concept.categoryName, systemImage: concept.categorySymbol)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Palette.inkMuted)
            Text(concept.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
        .padding(Space.s3)
        .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).strokeBorder(Palette.border, lineWidth: 1))
    }

    // MARK: Coreografía

    /// ~900 ms: acercamiento (340), choque con estrella y háptico (220), despliegue (340).
    /// Con Reducir movimiento: un fundido de 200 ms, sin escala ni rebote.
    private func ignite() {
        guard phase == .idle else { return }
        if neuralIdentity && FeatureFlag.revealSynapse.isEnabled {
            igniteSynapse()
            return
        }
        let motionReduced = reduceMotion
        let inModal = neuralIdentity
        if inModal {
            // Sin el deslizamiento de la hoja: el fondo se desenfoca y el panel aparece en el lugar.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { isShowingReveal = true }
        }
        Task { @MainActor in
            if inModal {
                try? await Task.sleep(for: .milliseconds(motionReduced ? 50 : 300))
            }
            if motionReduced {
                collisions += 1
                withAnimation(.easeInOut(duration: 0.2)) { phase = .revealed }
                try? await Task.sleep(for: .milliseconds(200))
            } else {
                withAnimation(.easeIn(duration: 0.34)) { phase = .approaching }
                try? await Task.sleep(for: .milliseconds(340))
                collisions += 1
                withAnimation(.spring(duration: 0.3, bounce: 0.4)) { phase = .collided }
                try? await Task.sleep(for: .milliseconds(220))
                withAnimation(.easeOut(duration: 0.34)) { phase = .revealed }
                try? await Task.sleep(for: .milliseconds(340))
            }
            AccessibilityNotification.Announcement(spark.accessibilitySummary).post()
            await finishReveal(motionReduced: motionReduced)
        }
    }

    /// La coreografía de design/reveal (900 ms desde el toque). El modal aparece en el mismo toque, sin espera,
    /// y anima solo con `SynapseRevealTimeline`; acá queda lo que no es animación: el háptico a los 650
    /// y, a los 900, el cierre habilitado, el anuncio, `spark_revealed` y `revealSpark`.
    /// Con Reducir movimiento: fundido de 200 ms y todo eso al final del fundido.
    private func igniteSynapse() {
        let motionReduced = reduceMotion
        revealStart = .now
        // Sin el deslizamiento de la hoja. Detrás del velo, el botón de Hoy se apaga y no se puede volver a tocar.
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            phase = .approaching
            isShowingReveal = true
        }
        Task { @MainActor in
            let clock = ContinuousClock()
            let start = clock.now
            if motionReduced {
                try? await clock.sleep(until: start + .seconds(SynapseRevealTimeline.reducedDuration))
                collisions += 1
            } else {
                try? await clock.sleep(until: start + .seconds(SynapseRevealTimeline.ignition))
                collisions += 1
                try? await clock.sleep(until: start + .seconds(SynapseRevealTimeline.duration))
            }
            withAnimation(.timingCurve(0, 0, 0.2, 1, duration: 0.2)) { phase = .revealed }
            // Prioridad alta: el foco que pasa al título no lo corta.
            var summary = AttributedString(spark.accessibilitySummary)
            summary.accessibilitySpeechAnnouncementPriority = .high
            AccessibilityNotification.Announcement(summary).post()
            await finishReveal(motionReduced: motionReduced)
        }
    }

    private func finishReveal(motionReduced: Bool) async {
        Analytics.track(.sparkRevealed(mode: spark.mode, isFirst: !hasSeenSpark, entry: entry, reduceMotion: motionReduced))
        hasSeenSpark = true
        var revealed = spark
        revealed.status = .revealed
        onChange(revealed)
        try? await api.revealSpark(id: spark.id)
    }

    /// El modal ya hizo su fundido de cierre: se va sin la animación de la hoja.
    private func dismissRevealWithoutSliding() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { isShowingReveal = false }
    }
}

#Preview("Por revelar") {
    ScrollView {
        SparkHero(spark: MockData.todaySpark)
            .padding()
    }
    .background(Palette.bg)
    .environment(AppModel())
    .preferredColorScheme(.light)
}

/// El reveal como lo único visible: un panel centrado sobre el fondo desenfocado. Las dos neuronas se conectan,
/// salta la chispa y aparecen la idea y sus acciones. Se cierra con la cruz o tocando afuera, ya revelada.
private struct SparkRevealModal: View {
    let spark: Spark
    let phase: SparkHero.Phase
    var onChange: (Spark) -> Void
    var onPlan: () -> Void
    var onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                panel
                    .frame(maxWidth: 440)
                    .padding(.horizontal, Space.s4)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background {
            // Tocar afuera cierra, pero solo cuando la chispa ya está a la vista.
            Palette.neuron.opacity(0.22)
                .ignoresSafeArea()
                .onTapGesture { if phase == .revealed { onClose() } }
                .accessibilityHidden(true)
        }
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: reduceMotion ? 0.2 : 0.25)) { isVisible = true }
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            HStack(alignment: .top) {
                Text(spark.mode == .daily ? "Tu chispa de hoy" : "Tu chispa extra")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.inkMuted)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 32, height: 32)
                        .background(Palette.surfaceAlt, in: Circle())
                }
                .accessibilityLabel(Text("Cerrar"))
                .opacity(phase == .revealed ? 1 : 0)
                .disabled(phase != .revealed)
            }
            SparkPairHeader(a: SparkSide(spark.conceptA), b: SparkSide(spark.conceptB))
            Synapse(phase >= .collided ? .lit : phase >= .approaching ? .reaching : .apart, full: true)
                .frame(maxWidth: 320)
                .frame(maxWidth: .infinity)
                .scaleEffect(phase == .collided ? 1.1 : 1)
                .padding(.vertical, Space.s2)
            if phase == .revealed {
                VStack(alignment: .leading, spacing: Space.s3) {
                    Text(spark.title)
                        .lumbreDisplay(.sparkHero)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(spark.body)
                        .font(.body)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                SparkActions(spark: spark, onChange: onChange, onPlan: onPlan)
                    .transition(.opacity)
            }
        }
        .padding(Space.s5)
        .background {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Palette.surface)
                .lumbreShadow(.glowSpark)
        }
        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).strokeBorder(Palette.border, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

// MARK: Coreografía de la sinapsis (flag `reveal_synapse`)

/// La línea de tiempo del reveal (design/reveal/README.md, §2 y §3), en segundos desde el toque.
/// Todo sale de un solo reloj, con las curvas exactas de la especificación.
enum SynapseRevealTimeline {
    /// Fin de la coreografía: cruz, toque afuera, escape, anuncio y `spark_revealed`.
    static let duration = 0.9
    /// La estrella, el `glow-spark`, el háptico y el título.
    static let ignition = 0.65
    /// Con Reducir movimiento: el fundido del modal entero.
    static let reducedDuration = 0.2
    /// Después de esto la estrella ya quedó quieta y el reloj se puede parar.
    static let settled = 1.0

    enum Curve {
        case fade, enter, reach, impulse, calm

        var unit: UnitCurve {
            switch self {
            case .fade: .bezier(startControlPoint: UnitPoint(x: 0, y: 0), endControlPoint: UnitPoint(x: 0.2, y: 1))
            case .enter: .bezier(startControlPoint: UnitPoint(x: 0.2, y: 0.8), endControlPoint: UnitPoint(x: 0.2, y: 1))
            case .reach: .bezier(startControlPoint: UnitPoint(x: 0.3, y: 0.7), endControlPoint: UnitPoint(x: 0.2, y: 1))
            case .impulse: .bezier(startControlPoint: UnitPoint(x: 0.4, y: 0), endControlPoint: UnitPoint(x: 1, y: 1))
            case .calm: .bezier(startControlPoint: UnitPoint(x: 0.4, y: 0), endControlPoint: UnitPoint(x: 0.2, y: 1))
            }
        }
    }

    /// El resorte de la estrella: llega a 1 a los ~210 ms, pasa un 7 % y vuelve.
    static let ignite = Spring(duration: 0.3, bounce: 0.35)

    /// Progreso de una pista que arranca en `start` y dura `length`, con su curva.
    static func track(_ t: Double, from start: Double, length: Double, _ curve: Curve) -> Double {
        curve.unit.value(at: linear(t, from: start, length: length))
    }

    static func linear(_ t: Double, from start: Double, length: Double) -> Double {
        min(max((t - start) / length, 0), 1)
    }

    static func synapse(at t: Double) -> SynapseProgress {
        guard t < settled else { return .end }
        let impulse = linear(t, from: 0.45, length: 0.2)
        // Aparece en los primeros 40 ms y se apaga en los últimos 40.
        let impulseOpacity = t <= 0.45 || t >= 0.65 ? 0 : min(impulse / 0.2, (1 - impulse) / 0.2, 1)
        let sinceIgnition = max(t - ignition, 0)
        return SynapseProgress(
            enter: track(t, from: 0, length: 0.25, .enter),
            reach: track(t, from: 0.15, length: 0.4, .reach),
            impulse: track(t, from: 0.45, length: 0.2, .impulse),
            impulseOpacity: impulseOpacity,
            star: 0.1 + ignite.value(target: 0.9, time: sinceIgnition),
            starOpacity: linear(t, from: ignition, length: 0.07)
        )
    }
}

/// El reveal con la coreografía de design/reveal: el modal (material, velo y panel) se funde mientras entran
/// las neuronas, se estiran las terminales, cruza un impulso y salta la chispa; después suben el título, el cuerpo
/// y las acciones. El panel nace con su tamaño final. Se cierra con un fundido, recién con la chispa a la vista.
private struct SynapseRevealModal: View {
    let spark: Spark
    let start: Date
    /// A los 900 ms (200 con Reducir movimiento): cruz, toque afuera, escape y VoiceOver.
    let isRevealed: Bool
    var onChange: (Spark) -> Void
    var onPlan: () -> Void
    var onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSettled = false
    @State private var isClosing = false
    @AccessibilityFocusState private var isTitleFocused: Bool

    /// Solo Debug: `-revealAt 450` congela el modal en ese instante (ms desde el toque), para revisar cada cuadro.
    private static var frozenAt: Double? {
        #if DEBUG
        UserDefaults.standard.object(forKey: "revealAt").map { _ in UserDefaults.standard.double(forKey: "revealAt") / 1000 }
        #else
        nil
        #endif
    }

    var body: some View {
        TimelineView(.animation(paused: isSettled)) { context in
            let t = isSettled ? SynapseRevealTimeline.settled : context.date.timeIntervalSince(start)
            content(at: Self.frozenAt ?? t)
        }
        .opacity(isClosing ? 0 : 1)
        .task {
            let remaining = SynapseRevealTimeline.settled - Date.now.timeIntervalSince(start)
            if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
            isSettled = true
        }
        .onChange(of: isRevealed) { _, revealed in
            if revealed { isTitleFocused = true }
        }
    }

    private func content(at t: Double) -> some View {
        typealias T = SynapseRevealTimeline
        let motion = !reduceMotion
        let modal = motion ? T.track(t, from: 0, length: 0.2, .fade) : T.track(t, from: 0, length: T.reducedDuration, .calm)
        return GeometryReader { proxy in
            ScrollView {
                panel(at: t, motion: motion)
                    .frame(maxWidth: 440)
                    .padding(.horizontal, Space.s4)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background {
            // Tocar afuera cierra, pero solo cuando la chispa ya está a la vista.
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Palette.neuron.opacity(0.22)
            }
            .ignoresSafeArea()
            .onTapGesture { if isRevealed { close(then: onClose) } }
            .accessibilityHidden(true)
        }
        .opacity(modal)
    }

    private func panel(at t: Double, motion: Bool) -> some View {
        typealias T = SynapseRevealTimeline
        let enter = motion ? T.track(t, from: 0, length: 0.25, .enter) : 1
        let glow = motion ? T.track(t, from: T.ignition, length: 0.25, .fade) : 1
        let title = motion ? T.track(t, from: T.ignition, length: 0.25, .enter) : 1
        let bodyText = motion ? T.track(t, from: 0.7, length: 0.2, .enter) : 1
        let actions = motion ? T.track(t, from: 0.75, length: 0.15, .fade) : 1
        let cross = motion ? T.track(t, from: T.duration, length: 0.1, .fade) : 1
        return VStack(alignment: .leading, spacing: Space.s4) {
            HStack(alignment: .top) {
                Text(spark.mode == .daily ? "Tu chispa de hoy" : "Tu chispa extra")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.inkMuted)
                Spacer()
                Button { close(then: onClose) } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        // El círculo es fijo: con texto de accesibilidad la cruz no puede crecer más que él.
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .foregroundStyle(Palette.ink)
                        .frame(width: 32, height: 32)
                        .background(Palette.surfaceAlt, in: Circle())
                        // Área tocable de 44 × 44 pt; el círculo de 32 queda alineado con el borde del panel.
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .padding(.top, -6)
                .padding(.trailing, -6)
                .accessibilityLabel(Text("Cerrar"))
                .opacity(cross)
                .disabled(!isRevealed)
                .accessibilityHidden(!isRevealed)
            }
            .frame(minHeight: 32, alignment: .top)
            SparkPairHeader(a: SparkSide(spark.conceptA), b: SparkSide(spark.conceptB), enter: enter)
                .accessibilityHidden(!isRevealed)
            SynapseReveal(motion ? T.synapse(at: t) : .end)
                .frame(maxWidth: 320)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.s2)
            VStack(alignment: .leading, spacing: Space.s3) {
                Text(spark.title)
                    .lumbreDisplay(.sparkHero)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($isTitleFocused)
                    .offset(y: 12 * (1 - title))
                    .opacity(title)
                Text(spark.body)
                    .font(.body)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .offset(y: 8 * (1 - bodyText))
                    .opacity(bodyText)
            }
            .accessibilityHidden(!isRevealed)
            SparkActions(spark: spark, onChange: onChange, onPlan: { close(then: onPlan) })
                .opacity(actions)
                // Se pueden tocar desde que se ven (750 ms); VoiceOver las encuentra a los 900.
                .allowsHitTesting(actions > 0)
                .accessibilityHidden(!isRevealed)
        }
        .padding(Space.s5)
        .background {
            ZStack {
                // El `glow-spark` en su propia capa: se enciende con la estrella, de 650 a 900.
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(Palette.surface)
                    .lumbreShadow(.glowSpark)
                    .opacity(glow)
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(Palette.surface)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).strokeBorder(Palette.border, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { if isRevealed { close(then: onClose) } }
    }

    /// Fundido de 200 ms, sin deslizar; después se va el modal.
    private func close(then action: @escaping () -> Void) {
        guard !isClosing else { return }
        withAnimation(.timingCurve(0, 0, 0.2, 1, duration: 0.2)) { isClosing = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            action()
        }
    }
}
