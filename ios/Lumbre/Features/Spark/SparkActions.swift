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

    /// Una sola acción principal según el estado, y lo demás abajo:
    /// - sin guardar: Guardar idea; abajo Planificar, Compartir y el menú;
    /// - guardada: la línea "Guardada en … · Cambiar" y Planificar (el paso siguiente); abajo Compartir y el menú;
    /// - descartada: Guardar idea igual; abajo Compartir y el menú.
    /// "No me sirve", Reportar y Exportar van en el menú: son acciones de una vez, no del día a día.
    @ViewBuilder
    private var buttons: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            if spark.status == .saved { savedLine }
            if spark.status == .saved && FeatureFlag.planner.isEnabled {
                planButton(.primary)
                    .labelStyle(ActionLabelStyle())
            } else if spark.status != .saved {
                saveButton
            }
            pairLayout(spacing: Space.s2) {
                if spark.status != .saved && FeatureFlag.planner.isEnabled {
                    planButton(.secondary)
                        .labelStyle(ActionLabelStyle())
                }
                if FeatureFlag.shareCard.isEnabled {
                    Button {
                        isSharing = true
                    } label: {
                        Label("Compartir", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.lumbre(.secondary, fullWidth: true))
                    .labelStyle(ActionLabelStyle())
                }
                moreMenu
            }
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

    /// Dónde quedó guardada y, al lado, el link para cambiar de circuito.
    private var savedLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s2) {
            Label {
                spark.statusLine
            } icon: {
                Image(systemName: "bookmark.fill")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Palette.ink)
            if FeatureFlag.projects.isEnabled {
                Text("·").foregroundStyle(Palette.inkMuted).accessibilityHidden(true)
                Button("Cambiar") { isChoosingProject = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .underline()
                    .accessibilityLabel("Mover a otro circuito")
            }
            Spacer(minLength: 0)
        }
    }

    private var saveButton: some View {
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

    @ViewBuilder
    private func planButton(_ role: LumbreButtonStyle.Variant) -> some View {
        if appModel.isPro, let onPlan {
            Button(action: onPlan) {
                Label("Planificar", systemImage: "text.bubble")
            }
            .buttonStyle(.lumbre(role, fullWidth: true))
        } else if appModel.isPro {
            NavigationLink(value: SparkRoute.planner(spark.id, entry: "spark_detail")) {
                Label("Planificar", systemImage: "text.bubble")
            }
            .buttonStyle(.lumbre(role, fullWidth: true))
        } else {
            Button {
                Analytics.track(.plannerOpened(entry: "spark_detail"))
                appModel.presentPaywall(trigger: "planner")
            } label: {
                Label("Planificar", systemImage: "text.bubble")
            }
            .buttonStyle(.lumbre(role, fullWidth: true))
        }
    }

    private var moreMenu: some View {
        Menu {
            if showsExport {
                ShareLink(item: MarkdownDocument.spark(spark), preview: SharePreview(spark.title)) {
                    Label("Exportar a Markdown", systemImage: "doc.text")
                }
            }
            if spark.status != .saved && spark.status != .discarded {
                Button {
                    isAskingFeedback = true
                } label: {
                    Label("No me sirve", systemImage: "hand.thumbsdown")
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
