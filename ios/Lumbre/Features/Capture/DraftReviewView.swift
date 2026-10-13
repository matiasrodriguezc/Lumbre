import LumbreCore
import LumbreDesign
import SwiftUI

/// Revisión de borradores de confianza media: Confirmar, Editar o Descartar cada uno.
struct DraftReviewView: View {
    let onDone: () -> Void

    @Environment(\.api) private var api
    @State private var drafts: [Concept]

    init(drafts: [Concept], onDone: @escaping () -> Void) {
        _drafts = State(initialValue: drafts)
        self.onDone = onDone
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s4) {
                Text(drafts.count == 1
                     ? "Lumbre no está del todo seguro de esta idea. Revisala antes de guardarla."
                     : "Lumbre no está del todo seguro de estas ideas. Revisalas antes de guardarlas.")
                    .font(.callout)
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(drafts) { draft in
                    DraftCard(concept: draft, isOnly: drafts.count == 1) { resolved in
                        withAnimation(.snappy) { drafts.removeAll { $0.id == resolved } }
                        if drafts.isEmpty { onDone() }
                    }
                }
            }
            .padding(Space.s4)
        }
        .background(Palette.surface)
        .navigationTitle("Revisá la neurona")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .onAppear { Analytics.screen("capture_review") }
    }
}

/// Un borrador con sus tres acciones.
private struct DraftCard: View {
    let concept: Concept
    /// Si es el único, Confirmar es la acción principal de la pantalla.
    let isOnly: Bool
    let onResolved: (Concept.ID) -> Void

    @Environment(\.api) private var api
    @Environment(AppModel.self) private var appModel
    @State private var current: Concept
    @State private var isEditing = false
    @State private var title = ""
    @State private var thesis = ""
    @State private var isWorking = false
    @State private var confirmDiscard = false
    @State private var changeCategory = false
    @State private var errorMessage: String?

    init(concept: Concept, isOnly: Bool, onResolved: @escaping (Concept.ID) -> Void) {
        self.concept = concept
        self.isOnly = isOnly
        self.onResolved = onResolved
        _current = State(initialValue: concept)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Button {
                changeCategory = true
            } label: {
                HStack(spacing: Space.s1) {
                    LumbreChip(current.categoryName, systemImage: current.categorySymbol)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.inkMuted)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Categoría: \(current.categoryName)"))
            .accessibilityHint(Text("Cambiar categoría"))

            if isEditing {
                field("Título", text: $title, lines: 1...2)
                field("Tesis", text: $thesis, lines: 2...6)
            } else {
                Text(current.title)
                    .font(.headline)
                Text(current.thesis)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let principle = current.principle {
                VStack(alignment: .leading, spacing: Space.s1) {
                    Text("Principio")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.inkMuted)
                    Text(principle)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            actions
        }
        .foregroundStyle(Palette.ink)
        .padding(Space.s4)
        .background(Palette.bg, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).strokeBorder(Palette.border, lineWidth: 1))
        .disabled(isWorking)
        .confirmationDialog("¿Descartar este borrador?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Descartar", role: .destructive) { discard() }
        } message: {
            Text("La neurona no se guarda en tu red.")
        }
        .sheet(isPresented: $changeCategory) {
            CategoryChangeSheet(current: current.category?.name) { name in
                current = try await api.updateConcept(id: current.id, ConceptUpdate(categoryName: name))
                Analytics.track(.conceptCategoryChanged(context: "review"))
                appModel.dataChanged()
            }
        }
        .alert("No se pudo guardar", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var actions: some View {
        if isEditing {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Space.s2) { editActions }
                VStack(spacing: Space.s2) { editActions }
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Space.s2) { reviewActions }
                VStack(spacing: Space.s2) { reviewActions }
            }
        }
    }

    @ViewBuilder
    private var reviewActions: some View {
        Button {
            resolve(action: "confirmed", update: ConceptUpdate(confirm: true))
        } label: {
            if isWorking { ProgressView() } else { Text("Confirmar") }
        }
        .buttonStyle(.lumbre(isOnly ? .primary : .secondary, fullWidth: true))
        Button("Editar") {
            title = current.title
            thesis = current.thesis
            isEditing = true
        }
        .buttonStyle(.lumbre(.secondary, fullWidth: true))
        Button("Descartar") { confirmDiscard = true }
            .buttonStyle(.lumbre(.secondary, fullWidth: true))
    }

    @ViewBuilder
    private var editActions: some View {
        Button("Guardar cambios") {
            let update = ConceptUpdate(title: clean(title), thesis: clean(thesis), confirm: true)
            resolve(action: "edited", update: update)
        }
        .buttonStyle(.lumbre(isOnly ? .primary : .secondary, fullWidth: true))
        .disabled(clean(title).isEmpty || clean(thesis).isEmpty || thesis.count > CaptureForm.thesisLimit)
        Button("Cancelar") { isEditing = false }
            .buttonStyle(.lumbre(.secondary, fullWidth: true))
    }

    private func field(_ label: LocalizedStringKey, text: Binding<String>, lines: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.inkMuted)
            LumbreTextField(label, text: text, axis: .vertical, lines: lines)
        }
    }

    private func clean(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resolve(action: String, update: ConceptUpdate) {
        isWorking = true
        Task {
            do {
                _ = try await api.updateConcept(id: current.id, update)
                Analytics.track(.conceptDraftResolved(action: action))
                appModel.dataChanged()
                onResolved(concept.id)
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func discard() {
        isWorking = true
        Task {
            do {
                try await api.deleteConcept(id: current.id)
                Analytics.track(.conceptDraftResolved(action: "discarded"))
                appModel.dataChanged()
                onResolved(concept.id)
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }
}

/// Cuando una destilación deja varios conceptos (hasta 3), se muestran antes de cerrar.
struct CaptureResultsView: View {
    let concepts: [Concept]
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s3) {
                Text("Guardamos \(concepts.count) neuronas")
                    .lumbreDisplay(.title2)
                    .accessibilityAddTraits(.isHeader)
                Text("Salieron de lo que capturaste. Ya están en tu red.")
                    .font(.callout)
                    .foregroundStyle(Palette.inkMuted)
                ForEach(concepts) { concept in
                    ConceptCard(concept)
                }
            }
            .padding(Space.s4)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Listo", action: onDone)
                .buttonStyle(.lumbre(.primary, fullWidth: true))
                .padding(.horizontal, Space.s4)
                .padding(.bottom, Space.s2)
        }
        .background(Palette.surface)
        .navigationBarBackButtonHidden()
    }
}

/// Se guardó sin destilar porque no quedaban pruebas: oferta de Pro, sin cortar el flujo.
struct SavedWithoutDistillView: View {
    let onPro: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            Label("Neurona guardada", systemImage: "checkmark.circle")
                .font(.headline)
                .foregroundStyle(Palette.success)
            Text("Lo guardamos sin destilar")
                .lumbreDisplay(.title2)
                .accessibilityAddTraits(.isHeader)
            Text("Usaste las pruebas de destilación de este mes. Con Lumbre Pro destilás links, fotos y PDFs sin límite.")
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button("Conocé Lumbre Pro", action: onPro)
                .buttonStyle(.lumbre(.pro, fullWidth: true))
            Button("Listo", action: onDone)
                .buttonStyle(.lumbre(.secondary, fullWidth: true))
        }
        .foregroundStyle(Palette.ink)
        .padding(Space.s4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.surface)
        .navigationBarBackButtonHidden()
    }
}
