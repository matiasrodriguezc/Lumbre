import LumbreCore
import LumbreDesign
import SwiftUI

/// Detalle de una chispa: la idea, los dos conceptos completos, dónde quedó guardada y las acciones.
struct SparkDetailView: View {
    let sparkID: Spark.ID

    @Environment(\.api) private var api
    @Environment(AppModel.self) private var appModel
    @Environment(\.dataVersion) private var dataVersion
    @State private var spark: Spark?
    @State private var loadError: Error?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s6) {
                if let loadError {
                    LoadErrorView(error: loadError) { Task { await load() } }
                } else if let spark {
                    content(spark)
                } else {
                    content(MockData.todaySpark)
                        .redacted(reason: .placeholder)
                        .disabled(true)
                }
            }
            .padding(.horizontal, Space.s4)
            .padding(.top, Space.s2)
            .padding(.bottom, Space.s8)
        }
        .neuralBackground()
        .navigationTitle("Chispa")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: dataVersion) { await load() }
        .onAppear { Analytics.screen("spark_detail") }
    }

    @ViewBuilder
    private func content(_ spark: Spark) -> some View {
        // Si está guardada, dónde lo dicen las acciones; acá va la fecha o el descarte.
        if spark.status != .saved {
            Label {
                spark.statusLine
            } icon: {
                Image(systemName: spark.statusSymbol)
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(Palette.inkMuted)
        }

        SparkCard(a: SparkSide(spark.conceptA), b: SparkSide(spark.conceptB), title: spark.title, explanation: spark.body) {
            SparkActions(spark: spark, showsExport: true) { self.spark = $0 }
        }

        VStack(alignment: .leading, spacing: Space.s3) {
            Text("Las dos neuronas")
                .font(.headline)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            SparkConceptCard(concept: spark.conceptA)
            SparkConceptCard(concept: spark.conceptB)
        }
    }

    private func load() async {
        do {
            var loaded = try await api.spark(id: sparkID)
            if loaded.isPending {
                // Abrir el detalle cuenta como verla: no vuelve a hacer el reveal en Hoy.
                try? await api.revealSpark(id: sparkID)
                loaded.status = .revealed
            }
            spark = loaded
            loadError = nil
        } catch {
            loadError = error
        }
    }
}

/// Concepto completo dentro del detalle: tesis, principio si lo hay y fuente con link. Abre su detalle en la Bóveda.
struct SparkConceptCard: View {
    let concept: Concept

    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Button {
                Analytics.track(.conceptOpened(entry: "spark_detail"))
                appModel.open(.concept(concept.id))
            } label: {
                summary
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Abre la neurona en tu red")

            source
        }
        .padding(Space.s4)
        .background {
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Palette.surface)
                .lumbreShadow(.elevCard)
        }
        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).strokeBorder(Palette.border, lineWidth: 1))
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            HStack(alignment: .top) {
                LumbreChip(concept.categoryName, systemImage: concept.categorySymbol)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.inkMuted)
                    .accessibilityHidden(true)
            }
            Text(concept.title)
                .font(.headline)
                .foregroundStyle(Palette.ink)
            Text(concept.thesis)
                .font(.callout)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let principle = concept.principle {
                principleView(principle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .contentShape(Rectangle())
    }

    private func principleView(_ principle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Principio")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.inkMuted)
            Text(principle)
                .font(.callout)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Space.s1)
    }

    @ViewBuilder
    private var source: some View {
        if let url = concept.sourceURL {
            Link(destination: url) {
                Label(concept.sourceTitle ?? url.host() ?? url.absoluteString, systemImage: "link")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Palette.infoText)
                    .multilineTextAlignment(.leading)
            }
        } else {
            concept.sourceLine
                .font(.footnote.weight(.medium))
                .foregroundStyle(Palette.inkMuted)
        }
    }
}

#Preview {
    NavigationStack {
        SparkDetailView(sparkID: MockData.recentSparks[0].id)
            .sparkDestinations()
    }
    .environment(AppModel())
    .preferredColorScheme(.dark)
}
