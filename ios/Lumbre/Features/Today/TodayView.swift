import LumbreCore
import LumbreDesign
import SwiftUI

struct TodayView: View {
    @Environment(\.api) private var api
    @State private var spark: Spark?
    @State private var quota: SparkQuota?
    @State private var recent: [Spark] = []
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var isSaved = false
    @State private var isAskingFeedback = false
    @State private var isPlanning = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s6) {
                    if let loadError {
                        LoadErrorView(error: loadError) { Task { await load() } }
                    } else {
                        meter
                        sparkSection
                        if !recent.isEmpty {
                            recentSection
                        }
                    }
                }
                .padding(.horizontal, Space.s4)
                .padding(.bottom, Space.s8)
            }
            .background(Palette.bg)
            .navigationTitle("Hoy")
            .task { await load() }
            .refreshable { await load() }
            .confirmationDialog("¿Por qué no te sirve?", isPresented: $isAskingFeedback, titleVisibility: .visible) {
                ForEach(SparkFeedback.allCases, id: \.self) { reason in
                    Button(reason.label) { send(reason) }
                }
            } message: {
                Text("Con esto elegimos mejor las próximas chispas.")
            }
            .sheet(isPresented: $isPlanning) {
                PlaceholderSheet(title: "Planificar", message: "Acá vas a poder bajar esta idea a un plan con el planificador.")
            }
        }
    }

    @ViewBuilder
    private var meter: some View {
        let quota = quota ?? MockData.quota
        SparkMeter(
            available: quota.available,
            total: quota.total,
            status: Text(quota.available > 0 ? "Chispa disponible" : "Usaste la chispa de hoy"),
            detail: quota.available > 0
                ? refillText(quota.refillsAt)
                : Text("Guardá \(quota.conceptsUntilExtra) conceptos para ganar 1 extra")
        )
        .redacted(reason: isLoading ? .placeholder : [])
    }

    @ViewBuilder
    private var sparkSection: some View {
        if let spark = spark ?? (isLoading ? MockData.todaySpark : nil) {
            SparkCard(
                a: SparkSide(spark.conceptA),
                b: SparkSide(spark.conceptB),
                title: spark.title,
                explanation: spark.body
            ) {
                VStack(spacing: Space.s2) {
                    Button {
                        save(spark)
                    } label: {
                        Label(isSaved ? "Idea guardada" : "Guardar idea", systemImage: isSaved ? "checkmark" : "bookmark")
                    }
                    .buttonStyle(.lumbre(.primary, fullWidth: true))
                    .disabled(isSaved)

                    HStack(spacing: Space.s2) {
                        Button("Planificar") { isPlanning = true }
                            .buttonStyle(.lumbre(.secondary, fullWidth: true))
                        Button("No me sirve") { isAskingFeedback = true }
                            .buttonStyle(.lumbre(.ghost, fullWidth: true))
                    }
                }
            }
            .redacted(reason: isLoading ? .placeholder : [])
        } else {
            ContentUnavailableView(
                "Hoy no hay chispa",
                systemImage: "sparkles",
                description: Text("Guardá un par de conceptos más para tener material que combinar.")
            )
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text("Anteriores")
                .font(.headline)
                .foregroundStyle(Palette.ink)
            ForEach(recent) { spark in
                RecentSparkRow(spark: spark)
            }
        }
    }

    private func refillText(_ date: Date) -> Text {
        let time = date.formatted(date: .omitted, time: .shortened)
        if Calendar.current.isDateInToday(date) {
            return Text("Se recarga hoy a las \(time)")
        } else if Calendar.current.isDateInTomorrow(date) {
            return Text("Se recarga mañana a las \(time)")
        }
        return Text("Se recarga el \(date, format: .dateTime.weekday(.wide)) a las \(time)")
    }

    private func load() async {
        do {
            async let spark = api.todaySpark()
            async let quota = api.sparkQuota()
            async let recent = api.recentSparks()
            (self.spark, self.quota, self.recent) = try await (spark, quota, recent)
            loadError = nil
            isSaved = self.spark?.status == .saved
        } catch {
            loadError = error
        }
        isLoading = false
    }

    private func save(_ spark: Spark) {
        withAnimation(.snappy) { isSaved = true }
        Task {
            do {
                try await api.saveSpark(id: spark.id)
                quota = try await api.sparkQuota()
            } catch {
                withAnimation(.snappy) { isSaved = false }
            }
        }
    }

    private func send(_ feedback: SparkFeedback) {
        guard let spark else { return }
        Task { try? await api.sendFeedback(sparkID: spark.id, feedback: feedback) }
    }
}

private struct RecentSparkRow: View {
    let spark: Spark

    var body: some View {
        HStack(spacing: Space.s3) {
            Image(systemName: spark.status == .saved ? "bookmark.fill" : "sparkles")
                .foregroundStyle(Palette.inkMuted)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(spark.title)
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                Group {
                    if let project = spark.projectName {
                        Text("Guardada en “\(project)”")
                    } else {
                        Text(spark.createdAt, format: .relative(presentation: .named))
                    }
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(Palette.inkMuted)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.inkMuted)
        }
        .padding(Space.s4)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).strokeBorder(Palette.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

extension SparkSide {
    init(_ concept: Concept) {
        self.init(domain: concept.domain.name, domainSymbol: concept.domain.symbol, title: concept.title)
    }
}

extension SparkFeedback {
    var label: LocalizedStringKey {
        switch self {
        case .obvious: return "Es obvia"
        case .irrelevant: return "No tiene que ver conmigo"
        case .alreadyHad: return "Ya la había tenido"
        }
    }
}

#Preview {
    TodayView()
        .preferredColorScheme(.dark)
}
