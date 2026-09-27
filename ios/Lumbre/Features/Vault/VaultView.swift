import LumbreCore
import LumbreDesign
import SwiftUI

struct VaultView: View {
    @Environment(\.api) private var api
    @Environment(\.dataVersion) private var dataVersion
    @State private var concepts: [Concept] = []
    @State private var categories: [LumbreCore.Category] = []
    @State private var selectedCategory: LumbreCore.Category?
    @State private var query = ""
    @State private var isLoading = true
    @State private var loadError: Error?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Space.s3) {
                    if let loadError {
                        LoadErrorView(error: loadError) { Task { await load() } }
                    }
                    filters
                    if visibleConcepts.isEmpty && !isLoading && loadError == nil {
                        emptyState
                    }
                    ForEach(isLoading ? MockData.concepts : visibleConcepts) { concept in
                        ConceptCard(
                            category: concept.categoryName,
                            categorySymbol: concept.categorySymbol,
                            title: concept.title,
                            thesis: concept.thesis,
                            source: concept.sourceLine
                        )
                    }
                }
                .padding(.horizontal, Space.s4)
                .padding(.bottom, Space.s8)
                .redacted(reason: isLoading ? .placeholder : [])
            }
            .background(Palette.bg)
            .navigationTitle("Bóveda")
            .searchable(text: $query, prompt: "Buscar ideas, no palabras")
            .task(id: dataVersion) { await load() }
        }
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s2) {
                chip("Todos", systemImage: nil, isOn: selectedCategory == nil) { selectedCategory = nil }
                ForEach(categories) { category in
                    chip(category.name, systemImage: category.symbol, isOn: selectedCategory == category) {
                        selectedCategory = selectedCategory == category ? nil : category
                    }
                }
            }
        }
        .scrollClipDisabled()
    }

    private func chip(_ title: String, systemImage: String?, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            LumbreChip(title, systemImage: systemImage, variant: isOn ? .on : .select)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            query.isEmpty ? "Todavía no hay conceptos" : "Nada por acá",
            systemImage: "square.stack.3d.up",
            description: Text(query.isEmpty
                ? "Guardá una frase, un link o una nota de voz para tener material que combinar."
                : "Probá con otras palabras o sacá el filtro de categoría.")
        )
        .padding(.top, Space.s8)
    }

    /// Filtro local de prueba. La búsqueda semántica llega con el backend.
    private var visibleConcepts: [Concept] {
        concepts.filter { concept in
            (selectedCategory == nil || concept.category == selectedCategory)
                && (query.isEmpty
                    || concept.title.localizedStandardContains(query)
                    || concept.thesis.localizedStandardContains(query))
        }
    }

    private func load() async {
        do {
            async let concepts = api.concepts()
            async let categories = api.categories()
            (self.concepts, self.categories) = try await (concepts, categories)
            loadError = nil
        } catch {
            loadError = error
        }
        isLoading = false
    }
}

extension Concept {
    /// "De un link · hace 2 días"
    var sourceLine: Text {
        Text("\(sourceType.label) · \(createdAt, format: .relative(presentation: .named))")
    }

    var categoryName: String { category?.name ?? String(localized: "Sin categoría") }
    var categorySymbol: String { category?.symbol ?? "tag" }
}

extension SourceType {
    var label: String {
        switch self {
        case .text: return String(localized: "Texto")
        case .voice: return String(localized: "Nota de voz")
        case .selection: return String(localized: "Texto seleccionado")
        case .screenshot: return String(localized: "Captura de pantalla")
        case .scan: return String(localized: "Página escaneada")
        case .link: return String(localized: "De un link")
        case .image: return String(localized: "Imagen")
        case .pdf: return String(localized: "PDF")
        case .audio: return String(localized: "Audio")
        }
    }
}

#Preview {
    VaultView()
        .preferredColorScheme(.dark)
}
