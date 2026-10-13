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

    @Environment(\.api) private var api
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.neuralIdentity) private var neuralIdentity
    @AppStorage("hasSeenSpark") private var hasSeenSpark = false
    @State private var phase: Phase
    @State private var collisions = 0

    enum Phase: Int, Comparable {
        case idle, approaching, collided, revealed
        static func < (lhs: Phase, rhs: Phase) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    init(spark: Spark, entry: String = "app", onChange: @escaping (Spark) -> Void = { _ in }) {
        self.spark = spark
        self.entry = entry
        self.onChange = onChange
        _phase = State(initialValue: spark.isPending ? .idle : .revealed)
    }

    var body: some View {
        ZStack(alignment: .top) {
            if phase < .revealed {
                stage
                    .transition(.opacity)
            } else {
                SparkCard(a: SparkSide(spark.conceptA), b: SparkSide(spark.conceptB), title: spark.title, explanation: spark.body) {
                    SparkActions(spark: spark, onChange: onChange)
                }
                .transition(reduceMotion ? .opacity : .scale(scale: 0.94, anchor: .center).combined(with: .opacity))
            }
        }
        .sensoryFeedback(.success, trigger: collisions)
    }

    // MARK: Estado previo y choque

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
    /// Con la identidad neuronal no se tocan: cada una estira su terminal, cruza el impulso y salta la chispa en la sinapsis.
    private var collision: some View {
        let gap: CGFloat = neuralIdentity ? 76 : 36
        let travel = neuralIdentity ? 0 : gap / 2 + 6
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

            if neuralIdentity {
                Synapse(phase >= .collided ? .lit : phase >= .approaching ? .reaching : .apart)
                    .frame(width: 72)
            } else {
                Text("×")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.inkMuted)
                    .opacity(phase >= .approaching ? 0 : 1)
                    .accessibilityHidden(true)
            }

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
        let motionReduced = reduceMotion
        Task { @MainActor in
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
            Analytics.track(.sparkRevealed(mode: spark.mode, isFirst: !hasSeenSpark, entry: entry, reduceMotion: motionReduced))
            hasSeenSpark = true
            var revealed = spark
            revealed.status = .revealed
            onChange(revealed)
            try? await api.revealSpark(id: spark.id)
        }
    }
}

#Preview("Por revelar") {
    ScrollView {
        SparkHero(spark: MockData.todaySpark)
            .padding()
    }
    .background(Palette.bg)
    .environment(AppModel())
    .preferredColorScheme(.dark)
}
