import LumbreCore
import LumbreDesign
import SwiftUI

/// Editar título y tesis de un concepto.
struct ConceptEditSheet: View {
    let concept: Concept
    let onSave: (_ title: String, _ thesis: String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var thesis: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(concept: Concept, onSave: @escaping (_ title: String, _ thesis: String) async throws -> Void) {
        self.concept = concept
        self.onSave = onSave
        _title = State(initialValue: concept.title)
        _thesis = State(initialValue: concept.thesis)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s4) {
                    field("Título", text: $title, lines: 1...3)
                    field("Tesis", text: $thesis, lines: 3...10)
                    if thesis.count > CaptureForm.thesisLimit {
                        Label("La tesis puede tener hasta 600 caracteres.", systemImage: "exclamationmark.circle")
                            .font(.footnote)
                            .foregroundStyle(Palette.danger)
                    }
                    if concept.principle != nil {
                        Text("El principio lo saca la conceptualización y no se edita.")
                            .font(.footnote)
                            .foregroundStyle(Palette.inkMuted)
                    }
                }
                .padding(Space.s4)
            }
            .foregroundStyle(Palette.ink)
            .background(Palette.surface)
            .navigationTitle("Editar neurona")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Guardar") { save() }
                            .disabled(!canSave)
                    }
                }
            }
            .alert("No se pudo guardar", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    private var cleanTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var cleanThesis: String { thesis.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canSave: Bool {
        !cleanTitle.isEmpty && !cleanThesis.isEmpty && thesis.count <= CaptureForm.thesisLimit
            && (cleanTitle != concept.title || cleanThesis != concept.thesis)
    }

    private func field(_ label: LocalizedStringKey, text: Binding<String>, lines: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            Text(label)
                .font(.headline)
            LumbreTextField(label, text: text, axis: .vertical, lines: lines)
        }
    }

    private func save() {
        isSaving = true
        Task {
            do {
                try await onSave(cleanTitle, cleanThesis)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

/// Pro: elegir otro concepto para encender una chispa con los dos (`requestSpark(pick:)`).
struct CombinePickerSheet: View {
    let conceptID: Concept.ID
    let onSpark: (Spark) -> Void

    @Environment(\.api) private var api
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var concepts: [Concept]?
    @State private var filter = ""
    @State private var requesting: Concept.ID?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let concepts {
                    List(visible(concepts)) { concept in
                        Button {
                            combine(with: concept)
                        } label: {
                            HStack(spacing: Space.s3) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(concept.title)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(Palette.ink)
                                    Label(concept.categoryName, systemImage: concept.categorySymbol)
                                        .font(.footnote)
                                        .foregroundStyle(Palette.inkMuted)
                                }
                                Spacer(minLength: 0)
                                if requesting == concept.id { ProgressView() }
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Palette.surfaceAlt)
                    }
                    .scrollContentBackground(.hidden)
                    .overlay {
                        if visible(concepts).isEmpty {
                            ContentUnavailableView("Nada por acá", systemImage: "magnifyingglass",
                                                   description: Text("Probá con otras palabras."))
                        }
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Palette.surface)
            .searchable(text: $filter, placement: .navigationBarDrawer(displayMode: .always), prompt: "Filtrar neuronas")
            .navigationTitle("Combinar con…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .disabled(requesting != nil)
            .task {
                concepts = ((try? await api.concepts()) ?? []).filter { $0.id != conceptID }
            }
            .alert("No se pudo encender", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .interactiveDismissDisabled(requesting != nil)
    }

    private func visible(_ concepts: [Concept]) -> [Concept] {
        let text = filter.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return concepts }
        return concepts.filter { $0.title.localizedStandardContains(text) || $0.categoryName.localizedStandardContains(text) }
    }

    private func combine(with other: Concept) {
        guard AIConsent.isGranted else {
            dismiss()
            appModel.presentAIConsent()
            return
        }
        requesting = other.id
        Task {
            do {
                let spark = try await api.requestSpark(pick: (conceptID, other.id))
                Analytics.track(.sparkExtraRequested(mode: .pick, source: "pro"))
                dismiss()
                onSpark(spark)
            } catch LumbreAPIError.proRequired {
                dismiss()
                appModel.presentPaywall(trigger: "extra_sparks")
            } catch LumbreAPIError.quotaExceeded {
                errorMessage = String(localized: "Ya pediste todas las chispas de hoy. Mañana podés seguir.")
            } catch {
                errorMessage = error.localizedDescription
            }
            requesting = nil
        }
    }
}
