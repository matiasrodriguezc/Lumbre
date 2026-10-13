import LumbreCore
import LumbreDesign
import SwiftUI

/// Chips con las categorías del usuario y un campo para escribir una nueva.
/// "Economía", "economia" y "ECONOMÍA" cuentan como la misma (igual que el servidor).
struct CategoryPicker<Focus: Hashable>: View {
    let categories: [LumbreCore.Category]
    @Binding var name: String
    var focus: FocusState<Focus?>.Binding
    let focusValue: Focus

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text("Categoría")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if !categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.s2) {
                        ForEach(categories) { category in
                            let isOn = CategoryName.same(category.name, name)
                            Button {
                                name = category.name
                            } label: {
                                LumbreChip(category.name, systemImage: category.symbol, variant: isOn ? .on : .select)
                                    .frame(minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(isOn ? .isSelected : [])
                        }
                    }
                }
                .scrollClipDisabled()
            }
            LumbreTextField(categories.isEmpty ? "Por ejemplo: Marketing" : "O escribí una nueva", text: $name)
                .focused(focus, equals: focusValue)
                .submitLabel(.done)
                .textInputAutocapitalization(.sentences)
                .accessibilityLabel("Categoría")
            if isNew {
                Label("Se crea la categoría “\(CategoryName.clean(name))”", systemImage: "plus.circle")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Palette.inkMuted)
            } else if categories.isEmpty {
                Text("Todavía no tenés categorías: se crean a medida que guardás neuronas.")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkMuted)
            }
        }
    }

    private var isNew: Bool {
        !CategoryName.clean(name).isEmpty && !categories.contains { CategoryName.same($0.name, name) }
    }
}

/// Campo de texto con el estilo de los inputs del sistema de diseño (`surface-alt` y borde `border-strong`).
struct LumbreTextField: View {
    let prompt: LocalizedStringKey
    @Binding var text: String
    var axis: Axis = .horizontal
    var lines: ClosedRange<Int> = 1...1

    init(_ prompt: LocalizedStringKey, text: Binding<String>, axis: Axis = .horizontal, lines: ClosedRange<Int> = 1...1) {
        self.prompt = prompt
        _text = text
        self.axis = axis
        self.lines = lines
    }

    var body: some View {
        TextField(prompt, text: $text, axis: axis)
            .lineLimit(lines)
            .padding(Space.s3)
            .frame(minHeight: 44)
            .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).strokeBorder(Palette.borderStrong, lineWidth: 1))
    }
}

/// Sheet para mover un concepto a otra categoría (o a una nueva). La usan la revisión del borrador y el detalle.
struct CategoryChangeSheet: View {
    let current: String?
    let onPick: (String) async throws -> Void

    @Environment(\.api) private var api
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var categories: [LumbreCore.Category] = []
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var focus: Bool?

    var body: some View {
        NavigationStack {
            ScrollView {
                CategoryPicker(categories: categories, name: $name, focus: $focus, focusValue: true)
                    .padding(Space.s4)
            }
            .background(Palette.surface)
            .navigationTitle("Cambiar categoría")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Mover") { save() }
                            .disabled(CategoryName.clean(name).isEmpty || (current.map { CategoryName.same($0, name) } ?? false))
                    }
                }
            }
            .alert("No se pudo mover", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .presentationDetents([.medium, .large])
        .task {
            name = current ?? ""
            categories = (try? await api.categories()) ?? []
        }
    }

    private func save() {
        isSaving = true
        Task {
            do {
                try await onPick(CategoryName.clean(name))
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}
