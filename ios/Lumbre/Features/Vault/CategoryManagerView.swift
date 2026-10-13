import LumbreCore
import LumbreDesign
import SwiftUI

/// Renombrar y borrar categorías. Al borrar una, sus conceptos quedan sin categoría.
struct CategoryManagerView: View {
    /// Conceptos ya cargados por la Bóveda, para mostrar cuántos tiene cada categoría.
    let concepts: [Concept]

    @Environment(\.api) private var api
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var categories: [LumbreCore.Category] = []
    @State private var isLoading = true
    @State private var renaming: LumbreCore.Category?
    @State private var newName = ""
    @State private var deleting: LumbreCore.Category?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if !isLoading && categories.isEmpty {
                    ContentUnavailableView(
                        "Todavía no tenés categorías",
                        systemImage: "tag",
                        description: Text("Se crean a medida que guardás conceptos.")
                    )
                    .listRowBackground(Color.clear)
                }
                ForEach(categories) { category in
                    row(category)
                }
                .listRowBackground(Palette.surfaceAlt)
            }
            .scrollContentBackground(.hidden)
            .background(Palette.surface)
            .navigationTitle("Categorías")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
            .task { await load() }
            .alert("Renombrar categoría", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Nombre", text: $newName)
                Button("Cancelar", role: .cancel) {}
                Button("Guardar") {
                    if let renaming { rename(renaming) }
                }
                .disabled(CategoryName.clean(newName).isEmpty)
            } message: {
                Text("El cambio se ve en todos sus conceptos.")
            }
            .confirmationDialog(
                deleting.map { String(localized: "¿Borrar “\($0.name)”?") } ?? "",
                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                titleVisibility: .visible,
                presenting: deleting
            ) { category in
                Button("Borrar categoría", role: .destructive) { delete(category) }
            } message: { category in
                let count = count(of: category)
                Text(count == 0
                     ? "No tiene conceptos."
                     : count == 1 ? "Su concepto queda sin categoría. No se borra." : "Sus \(count) conceptos quedan sin categoría. No se borran.")
            }
            .alert("No se pudo cambiar", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ category: LumbreCore.Category) -> some View {
        HStack(spacing: Space.s3) {
            Image(systemName: category.symbol)
                .foregroundStyle(Palette.inkMuted)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.body)
                    .foregroundStyle(Palette.ink)
                Text(count(of: category) == 1 ? "1 concepto" : "\(count(of: category)) conceptos")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkMuted)
            }
            Spacer()
            Menu {
                renameButton(category)
                deleteButton(category)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(Palette.inkMuted)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(Text("Opciones de \(category.name)"))
        }
        .accessibilityElement(children: .combine)
        .swipeActions {
            deleteButton(category)
            renameButton(category).tint(Palette.signalBlue)
        }
        .accessibilityActions {
            renameButton(category)
            deleteButton(category)
        }
    }

    private func renameButton(_ category: LumbreCore.Category) -> some View {
        Button {
            newName = category.name
            renaming = category
        } label: {
            Label("Renombrar", systemImage: "pencil")
        }
    }

    private func deleteButton(_ category: LumbreCore.Category) -> some View {
        Button(role: .destructive) {
            deleting = category
        } label: {
            Label("Borrar", systemImage: "trash")
        }
    }

    private func count(of category: LumbreCore.Category) -> Int {
        concepts.filter { $0.category?.id == category.id }.count
    }

    private func load() async {
        categories = (try? await api.categories()) ?? []
        isLoading = false
    }

    private func rename(_ category: LumbreCore.Category) {
        let name = CategoryName.clean(newName)
        guard !name.isEmpty, name != category.name else { return }
        Task {
            do {
                try await api.renameCategory(id: category.id, to: name)
                await load()
                appModel.dataChanged()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func delete(_ category: LumbreCore.Category) {
        Task {
            do {
                try await api.deleteCategory(id: category.id)
                await load()
                appModel.dataChanged()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        CategoryManagerView(concepts: MockData.concepts)
    }
    .environment(AppModel())
    .preferredColorScheme(.dark)
}
