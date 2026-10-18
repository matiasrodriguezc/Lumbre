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
    /// Si está, "Planificar" llama a esto en vez de empujar la pantalla (por ejemplo, desde el modal del reveal,
    /// que no tiene navegación propia).
    var onPlan: (() -> Void)? = nil
    /// Un pedido de afuera (el swipe del reveal): abre la misma hoja, el mismo diálogo o el mismo guardado que los botones.
    var request: SparkActionRequest? = nil
    /// Cuando termina el `request`: `true` si guardó o mandó el motivo; `false` si se canceló o falló.
    var onRequestFinished: (Bool) -> Void = { _ in }
    /// Sin los botones: solo las hojas, los diálogos y los avisos, manejados por `request` (el reveal pone los suyos).
    var showsButtons = true

    @Environment(\.api) private var api
    @Environment(AppModel.self) private var appModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isChoosingProject = false
    @State private var isAskingFeedback = false
    @State private var isAskingReport = false
    @State private var isSharing = false
    @State private var isSaving = false
    @State private var notice: Notice?
    @State private var activeRequest: SparkActionRequest.Action?
    /// Eligió un circuito o un motivo en lo que abrió el `request` (la hoja y el diálogo se cierran igual al cancelar).
    @State private var requestChoseOption = false

    private enum Notice: Equatable {
        case saved, feedback, reported, failed(String)
    }

    var body: some View {
        VStack(spacing: Space.s2) {
            if showsButtons { buttons }
            if let notice {
                noticeView(notice)
            }
        }
        .animation(reduceMotion ? nil : .snappy, value: notice)
        .animation(reduceMotion ? nil : .snappy, value: spark.status)
        .confirmationDialog("¿Por qué no te sirve?", isPresented: $isAskingFeedback, titleVisibility: .visible) {
            ForEach(SparkFeedback.allCases, id: \.self) { reason in
                Button(reason.label) {
                    requestChoseOption = true
                    sendFeedback(reason)
                }
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
        .onChange(of: request) { _, request in
            if let request { perform(request.action) }
        }
        .onChange(of: isAskingFeedback) { _, isAsking in
            guard !isAsking, activeRequest == .dismiss else { return }
            // El botón del motivo corre después de que se cierra el diálogo: si no eligió ninguno, canceló.
            DispatchQueue.main.async {
                if !requestChoseOption { finishRequest(false) }
            }
        }
        .sheet(isPresented: $isChoosingProject, onDismiss: {
            if activeRequest == .save { finishRequest(requestChoseOption) }
        }) {
            SaveSparkSheet(spark: spark) { projectID, projectName in
                requestChoseOption = true
                var updated = spark
                updated.status = .saved
                updated.projectID = projectID
                updated.projectName = projectName
                notice = .saved
                onChange(updated)
            }
        }
        // Compartir no cierra nada: al volver de la hoja, la tarjeta sigue ahí.
        .sheet(isPresented: $isSharing, onDismiss: {
            if activeRequest == .share { finishRequest(false) }
        }) {
            ShareCardSheet(spark: spark)
        }
    }

    @ViewBuilder
    private var buttons: some View {
            saveRow
            pairLayout(spacing: Space.s2) {
                if FeatureFlag.planner.isEnabled {
                    planButton
                        .labelStyle(ActionLabelStyle())
                }
                if spark.status != .discarded {
                    Button("No me sirve") { isAskingFeedback = true }
                        .buttonStyle(.lumbre(.ghost, fullWidth: true))
                }
            }
            pairLayout(spacing: Space.s2) {
                if FeatureFlag.shareCard.isEnabled {
                    Button {
                        isSharing = true
                    } label: {
                        Label("Compartir", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.lumbre(.secondary))
                    .labelStyle(ActionLabelStyle())
                }
                Spacer(minLength: 0)
                moreMenu
            }
    }

    /// Dos acciones lado a lado; con tamaños de accesibilidad, una abajo de la otra: al lado, "Planificar",
    /// "Mover" y "Compartir" se cortan por sílabas (como `SparkPairHeader`).
    private func pairLayout(spacing: CGFloat, @ViewBuilder content: () -> some View) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
            : AnyLayout(HStackLayout(spacing: spacing))
        return layout { content() }
    }

    @ViewBuilder
    private var saveRow: some View {
        if spark.status == .saved {
            pairLayout(spacing: Space.s3) {
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
                        .accessibilityLabel("Mover a otro circuito")
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
            .labelStyle(ActionLabelStyle())
            .disabled(isSaving)
        }
    }

    @ViewBuilder
    private var planButton: some View {
        if appModel.isPro, let onPlan {
            Button(action: onPlan) {
                Label("Planificar", systemImage: "text.bubble")
            }
            .buttonStyle(.lumbre(.secondary, fullWidth: true))
        } else if appModel.isPro {
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

    private func perform(_ action: SparkActionRequest.Action) {
        activeRequest = action
        requestChoseOption = false
        switch action {
        case .save:
            if FeatureFlag.projects.isEnabled {
                isChoosingProject = true
            } else {
                saveWithoutProject()
            }
        case .dismiss:
            isAskingFeedback = true
        case .share:
            isSharing = true
        case .report:
            // Reportar no mueve la tarjeta: se libera enseguida y el diálogo sigue solo.
            activeRequest = nil
            onRequestFinished(false)
            isAskingReport = true
        }
    }

    private func finishRequest(_ succeeded: Bool) {
        guard activeRequest != nil else { return }
        activeRequest = nil
        onRequestFinished(succeeded)
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
                finishRequest(true)
            } catch {
                notice = .failed(error.localizedDescription)
                finishRequest(false)
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
                finishRequest(true)
            } catch {
                notice = .failed(error.localizedDescription)
                finishRequest(false)
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

/// Lo que el swipe del reveal le pide a `SparkActions`. Cada pedido es nuevo (su `id`), así el mismo lado se puede repetir.
struct SparkActionRequest: Equatable {
    enum Action: String {
        case save, dismiss, share, report
    }

    let action: Action
    let id = UUID()
}

/// Con tamaños de accesibilidad, el ícono va arriba del texto: al lado, "Planificar" y "Compartir" no entran en el
/// panel del reveal y se cortan por sílabas.
private struct ActionLabelStyle: LabelStyle {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: Space.s1) {
                configuration.icon
                configuration.title
            }
            .multilineTextAlignment(.center)
        } else {
            Label(configuration)
        }
    }
}
