import LumbreCore
import LumbreDesign
import SwiftUI

/// Acciones de una chispa, en el orden de SparkCard: guardar, planificar, no me sirve; y abajo compartir y el menú ⋯.
/// Las usan Hoy y el detalle. Después de cada cambio llama `onChange` con la chispa actualizada.
struct SparkActions: View {
    let spark: Spark
    /// Agrega "Exportar a Markdown" al menú (en el detalle).
    var showsExport = false
    var onChange: (Spark) -> Void = { _ in }

    @Environment(\.api) private var api
    @Environment(AppModel.self) private var appModel
    @State private var isChoosingProject = false
    @State private var isAskingFeedback = false
    @State private var isAskingReport = false
    @State private var isSharing = false
    @State private var isSaving = false
    @State private var notice: Notice?

    private enum Notice: Equatable {
        case saved, feedback, reported, failed(String)
    }

    var body: some View {
        VStack(spacing: Space.s2) {
            saveRow
            HStack(spacing: Space.s2) {
                if FeatureFlag.planner.isEnabled {
                    planButton
                }
                if spark.status != .discarded {
                    Button("No me sirve") { isAskingFeedback = true }
                        .buttonStyle(.lumbre(.ghost, fullWidth: true))
                }
            }
            HStack(spacing: Space.s2) {
                if FeatureFlag.shareCard.isEnabled {
                    Button {
                        isSharing = true
                    } label: {
                        Label("Compartir", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.lumbre(.secondary))
                }
                Spacer(minLength: 0)
                moreMenu
            }
            if let notice {
                noticeView(notice)
            }
        }
        .animation(.snappy, value: notice)
        .animation(.snappy, value: spark.status)
        .confirmationDialog("¿Por qué no te sirve?", isPresented: $isAskingFeedback, titleVisibility: .visible) {
            ForEach(SparkFeedback.allCases, id: \.self) { reason in
                Button(reason.label) { sendFeedback(reason) }
            }
        } message: {
            Text("Con esto elegimos mejor las próximas chispas.")
        }
        .confirmationDialog("Reportar esta chispa", isPresented: $isAskingReport, titleVisibility: .visible) {
            ForEach(ReportReason.allCases, id: \.self) { reason in
                Button(reason.label) { report(reason) }
            }
        } message: {
            Text("La revisamos y ajustamos lo que genera Lumbre.")
        }
        .sheet(isPresented: $isChoosingProject) {
            SaveSparkSheet(spark: spark) { projectID, projectName in
                var updated = spark
                updated.status = .saved
                updated.projectID = projectID
                updated.projectName = projectName
                notice = .saved
                onChange(updated)
            }
        }
        .sheet(isPresented: $isSharing) {
            ShareCardSheet(spark: spark)
        }
    }

    @ViewBuilder
    private var saveRow: some View {
        if spark.status == .saved {
            HStack(spacing: Space.s3) {
                Label {
                    spark.statusLine
                } icon: {
                    Image(systemName: "bookmark.fill")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                if FeatureFlag.projects.isEnabled {
                    Button("Mover") { isChoosingProject = true }
                        .accessibilityLabel("Mover a otro proyecto")
                        .buttonStyle(.lumbre(.secondary))
                }
            }
        } else {
            Button {
                if FeatureFlag.projects.isEnabled {
                    isChoosingProject = true
                } else {
                    saveWithoutProject()
                }
            } label: {
                Label("Guardar idea", systemImage: "bookmark")
            }
            .buttonStyle(.lumbre(.primary, fullWidth: true))
            .disabled(isSaving)
        }
    }

    @ViewBuilder
    private var planButton: some View {
        if appModel.isPro {
            NavigationLink(value: SparkRoute.planner(spark.id, entry: "spark_detail")) {
                Label("Planificar", systemImage: "text.bubble")
            }
            .buttonStyle(.lumbre(.secondary, fullWidth: true))
        } else {
            Button {
                Analytics.track(.plannerOpened(entry: "spark_detail"))
                appModel.presentPaywall(trigger: "planner")
            } label: {
                Label("Planificar", systemImage: "text.bubble")
            }
            .buttonStyle(.lumbre(.secondary, fullWidth: true))
        }
    }

    private var moreMenu: some View {
        Menu {
            if showsExport {
                ShareLink(item: MarkdownDocument.spark(spark), preview: SharePreview(spark.title)) {
                    Label("Exportar a Markdown", systemImage: "doc.text")
                }
            }
            Button {
                isAskingReport = true
            } label: {
                Label("Reportar", systemImage: "flag")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.ink)
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Más acciones")
    }

    @ViewBuilder
    private func noticeView(_ notice: Notice) -> some View {
        switch notice {
        case .saved: ActionNotice(text: "Idea guardada")
        case .feedback: ActionNotice(text: "Gracias. Con esto elegimos mejor las próximas.")
        case .reported: ActionNotice(text: "Gracias por avisar. La vamos a revisar.")
        case .failed(let message): ActionNotice(text: "\(message)", symbol: "exclamationmark.triangle.fill", color: Palette.danger)
        }
    }

    private func saveWithoutProject() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await api.saveSpark(id: spark.id, projectID: nil)
                var updated = spark
                updated.status = .saved
                updated.projectID = nil
                updated.projectName = nil
                notice = .saved
                onChange(updated)
                appModel.dataChanged()
            } catch {
                notice = .failed(error.localizedDescription)
            }
        }
    }

    private func sendFeedback(_ feedback: SparkFeedback) {
        Task {
            do {
                try await api.sendFeedback(sparkID: spark.id, feedback: feedback)
                var updated = spark
                updated.status = .discarded
                updated.feedback = feedback
                notice = .feedback
                onChange(updated)
                appModel.dataChanged()
            } catch {
                notice = .failed(error.localizedDescription)
            }
        }
    }

    private func report(_ reason: ReportReason) {
        Task {
            do {
                try await api.reportSpark(id: spark.id, reason: reason, note: nil)
                Analytics.track(.aiContentReported(object: "spark", reason: reason))
                notice = .reported
            } catch {
                notice = .failed(error.localizedDescription)
            }
        }
    }
}
