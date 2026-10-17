import LumbreCore
import LumbreDesign
import SwiftUI

/// Detalle de un concepto: la idea, de dónde salió, en qué chispas apareció y qué se puede hacer con él.
struct ConceptDetailView: View {
    let conceptID: Concept.ID
    /// `concept_opened`: `vault`, `search` o `spark_detail`.
    let entry: String

    @Environment(\.api) private var api
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var concept: Concept?
    @State private var sparks: [Spark]?
    @State private var loadError: Error?
    @State private var isWorking = false
    @State private var isEditing = false
    @State private var isChangingCategory = false
    @State private var isPickingPartner = false
    @State private var confirmDelete = false
    @State private var errorMessage: String?
    @State private var tracked = false

    init(conceptID: Concept.ID, preview: Concept? = nil, entry: String) {
        self.conceptID = conceptID
        self.entry = entry
        _concept = State(initialValue: preview)
    }

    var body: some View {
        Group {
            if let concept {
                content(concept)
            } else if let loadError {
                LoadErrorView(error: loadError) { Task { await load() } }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .neuralBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .task { await load() }
        .onAppear {
            Analytics.screen("concept_detail")
            if !tracked {
                tracked = true
                Analytics.track(.conceptOpened(entry: entry))
            }
        }
        .sheet(isPresented: $isEditing) {
            if let concept {
                ConceptEditSheet(concept: concept) { title, thesis in
                    self.concept = try await api.updateConcept(id: conceptID, ConceptUpdate(title: title, thesis: thesis))
                    appModel.dataChanged()
                }
            }
        }
        .sheet(isPresented: $isChangingCategory) {
            CategoryChangeSheet(current: concept?.category?.name) { name in
                self.concept = try await api.updateConcept(id: conceptID, ConceptUpdate(categoryName: name))
                Analytics.track(.conceptCategoryChanged(context: "detail"))
                appModel.dataChanged()
            }
        }
        .sheet(isPresented: $isPickingPartner) {
            CombinePickerSheet(conceptID: conceptID) { spark in
                appModel.dataChanged()
                appModel.open(.spark(spark.id))
            }
        }
        .confirmationDialog("¿Borrar esta neurona?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Borrar neurona", role: .destructive) { delete() }
        } message: {
            Text("Sale de tu red y de las próximas chispas. No se puede deshacer.")
        }
        .alert("No se pudo guardar", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if concept != nil {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Editar") { isEditing = true }
                    .disabled(isWorking)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        isChangingCategory = true
                    } label: {
                        Label("Cambiar categoría", systemImage: "tag")
                    }
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Borrar neurona", systemImage: "trash")
                    }
                } label: {
                    Label("Más", systemImage: "ellipsis")
                }
                .disabled(isWorking)
            }
        }
    }

    // MARK: - Contenido

    private func content(_ concept: Concept) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s6) {
                header(concept)
                if concept.isDraft {
                    draftBanner
                }
                if let principle = concept.principle, !principle.isEmpty {
                    section("Principio") {
                        Text(principle)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                sourceSection(concept)
                sparksSection
                if FeatureFlag.pickMode.isEnabled {
                    combineButton
                }
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, Space.s4)
            .padding(.top, Space.s2)
            .padding(.bottom, Space.s10)
        }
        .refreshable { await load() }
    }

    private func header(_ concept: Concept) -> some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Button {
                isChangingCategory = true
            } label: {
                HStack(spacing: Space.s1) {
                    LumbreChip(concept.categoryName, systemImage: concept.categorySymbol)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.inkMuted)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Categoría: \(concept.categoryName)"))
            .accessibilityHint(Text("Cambiar categoría"))

            Text(concept.title)
                .lumbreDisplay(.title2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(concept.thesis)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            metadata(concept)
        }
    }

    private func metadata(_ concept: Concept) -> some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            Text("Guardado el \(concept.createdAt.formatted(date: .long, time: .omitted))")
            if concept.distilled {
                Label("Conceptualizado por Lumbre", systemImage: "wand.and.sparkles")
            }
            if concept.fromLibrary {
                Label("De la biblioteca de Lumbre", systemImage: "books.vertical")
            }
        }
        .font(.footnote)
        .foregroundStyle(Palette.inkMuted)
    }

    private var draftBanner: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Label {
                Text("Borrador. Lumbre no estaba del todo seguro de esta idea: confirmala o corregila.")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(Palette.warning)
            }
            .font(.callout)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Space.s2) { draftActions }
                VStack(spacing: Space.s2) { draftActions }
            }
        }
        .padding(Space.s4)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).strokeBorder(Palette.border, lineWidth: 1))
    }

    @ViewBuilder
    private var draftActions: some View {
        Button {
            confirm()
        } label: {
            if isWorking { ProgressView().tint(Palette.onAccent) } else { Text("Confirmar") }
        }
        .buttonStyle(.lumbre(.primary, fullWidth: true))
        .disabled(isWorking)
        Button("Editar") { isEditing = true }
            .buttonStyle(.lumbre(.secondary, fullWidth: true))
    }

    @ViewBuilder
    private func sourceSection(_ concept: Concept) -> some View {
        section("Fuente") {
            VStack(alignment: .leading, spacing: Space.s3) {
                Label(concept.sourceType.label, systemImage: concept.sourceType.symbol)
                    .font(.callout.weight(.medium))
                if let title = concept.sourceTitle, !title.isEmpty {
                    Text(title)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let url = concept.sourceURL {
                    Button {
                        openURL(url)
                    } label: {
                        Label(url.host() ?? url.absoluteString, systemImage: "safari")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(Palette.infoText)
                            .lineLimit(1)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("Abre el link en Safari"))
                }
                if let excerpt = concept.excerpt, !excerpt.isEmpty {
                    Text(excerpt)
                        .font(.callout)
                        .italic()
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, Space.s3)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(Palette.borderStrong).frame(width: 2)
                        }
                        .textSelection(.enabled)
                        .accessibilityLabel(Text("Fragmento subrayado: \(excerpt)"))
                }
            }
        }
    }

    @ViewBuilder
    private var sparksSection: some View {
        section("Chispas donde aparece") {
            if let sparks {
                if sparks.isEmpty {
                    Text("Todavía no se conectó con otra neurona. Cuando aparezca en una chispa, la vas a ver acá.")
                        .font(.callout)
                        .foregroundStyle(Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(spacing: Space.s2) {
                        ForEach(sparks) { spark in
                            sparkRow(spark)
                        }
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func sparkRow(_ spark: Spark) -> some View {
        Button {
            appModel.open(.spark(spark.id))
        } label: {
            HStack(spacing: Space.s3) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(spark.title)
                        .font(.headline)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                    Text(spark.createdAt, format: .relative(presentation: .named))
                        .font(.footnote)
                        .foregroundStyle(Palette.inkMuted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.inkMuted)
                    .accessibilityHidden(true)
            }
            .padding(Space.s3)
            .frame(minHeight: 44)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).strokeBorder(Palette.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Abre la chispa"))
    }

    private var combineButton: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Button {
                if appModel.isPro {
                    isPickingPartner = true
                } else {
                    appModel.presentPaywall(trigger: "extra_sparks")
                }
            } label: {
                Label("Combinar con…", systemImage: "plus.circle")
            }
            .buttonStyle(.lumbre(.pro, fullWidth: true))
            Text(appModel.isPro
                 ? "Elegí otra neurona y Lumbre enciende una chispa con las dos."
                 : "Con Lumbre Pro elegís qué neuronas se conectan.")
                .font(.footnote)
                .foregroundStyle(Palette.inkMuted)
        }
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.inkMuted)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Acciones

    private func load() async {
        do {
            async let loaded = api.concept(id: conceptID)
            async let related = api.sparks(withConcept: conceptID)
            concept = try await loaded
            sparks = (try? await related)?.sorted { $0.createdAt > $1.createdAt } ?? []
            loadError = nil
        } catch is CancellationError {
            return
        } catch {
            if concept == nil { loadError = error }
            if sparks == nil { sparks = [] }
        }
    }

    private func confirm() {
        isWorking = true
        Task {
            do {
                concept = try await api.updateConcept(id: conceptID, ConceptUpdate(confirm: true))
                Analytics.track(.conceptDraftResolved(action: "confirmed"))
                appModel.dataChanged()
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func delete() {
        isWorking = true
        Task {
            do {
                try await api.deleteConcept(id: conceptID)
                appModel.dataChanged()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isWorking = false
            }
        }
    }
}

#Preview("Detalle") {
    NavigationStack {
        ConceptDetailView(conceptID: MockData.concepts[2].id, preview: MockData.concepts[2], entry: "vault")
    }
    .environment(AppModel())
    .preferredColorScheme(.light)
    .tint(Palette.ink)
}

#Preview("Borrador") {
    NavigationStack {
        ConceptDetailView(conceptID: MockData.concepts[7].id, preview: MockData.concepts[7], entry: "vault")
    }
    .environment(AppModel())
    .preferredColorScheme(.light)
    .tint(Palette.ink)
}
