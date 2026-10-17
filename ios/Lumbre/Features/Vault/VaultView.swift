import LumbreCore
import LumbreDesign
import SwiftUI

/// Lo que se abre desde la Bóveda.
enum VaultRoute: Hashable {
    /// `entry` es el de `concept_opened`: `vault`, `search` o `spark_detail`.
    case concept(Concept.ID, preview: Concept?, entry: String)
}

/// Todo lo guardado como conceptos: borradores para confirmar arriba, filtros por categoría y búsqueda por idea.
struct VaultView: View {
    @Environment(\.api) private var api
    @Environment(\.dataVersion) private var dataVersion
    @Environment(AppModel.self) private var appModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var path: [VaultRoute] = []
    @State private var concepts: [Concept] = []
    @State private var categories: [LumbreCore.Category] = []
    @State private var selectedCategoryID: LumbreCore.Category.ID?
    @State private var query = ""
    @State private var searchResults: [Concept]?
    @State private var isSearching = false
    @State private var searchError: Error?
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var pendingCaptures = 0
    @State private var capturesWaitForQuota = false
    @State private var showCategories = false

    var body: some View {
        NavigationStack(path: $path) {
            content
                .neuralBackground()
                .navigationTitle("Red")
                .searchable(text: $query, prompt: "Buscar ideas, no palabras")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                showCategories = true
                            } label: {
                                Label("Categorías", systemImage: "tag")
                            }
                            if FeatureFlag.importNotes.isEnabled {
                                Button {
                                    appModel.presentImport()
                                } label: {
                                    Label("Importar notas", systemImage: "square.and.arrow.down")
                                }
                            }
                        } label: {
                            Label("Más", systemImage: "ellipsis")
                        }
                    }
                }
                .navigationDestination(for: VaultRoute.self) { route in
                    switch route {
                    case let .concept(id, preview, entry):
                        ConceptDetailView(conceptID: id, preview: preview, entry: entry)
                    }
                }
        }
        .task(id: dataVersion) { await load() }
        .task(id: query) { await search() }
        .onAppear { Analytics.screen("vault") }
        .onChange(of: appModel.pendingRoute, initial: true) { _, route in
            guard case .concept(let id) = route else { return }
            appModel.pendingRoute = nil
            path = [.concept(id, preview: concepts.first { $0.id == id }, entry: "spark_detail")]
        }
        .captureQueueMonitoring(pendingCount: $pendingCaptures, isWaitingForQuota: $capturesWaitForQuota)
        .sheet(isPresented: $showCategories) {
            CategoryManagerView(concepts: concepts)
        }
    }

    // MARK: - Contenido

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Space.s3) {
                if pendingCaptures > 0 {
                    PendingCapturesBanner(count: pendingCaptures, isWaitingForQuota: capturesWaitForQuota)
                }
                if let loadError {
                    LoadErrorView(error: loadError) { Task { await load() } }
                }
                if !categories.isEmpty {
                    filters
                }
                if isSearchActive {
                    searchContent
                } else {
                    listContent
                }
            }
            .padding(.horizontal, Space.s4)
            .padding(.bottom, Space.s8)
        }
        .refreshable { await load() }
    }

    @ViewBuilder
    private var listContent: some View {
        if isLoading {
            ForEach(MockData.concepts.prefix(4)) { concept in
                ConceptCard(concept)
            }
            .redacted(reason: .placeholder)
            .accessibilityHidden(true)
        } else if concepts.isEmpty && loadError == nil {
            emptyVault
        } else {
            let filtered = filter(concepts)
            let drafts = filtered.filter(\.isDraft)
            let ready = filtered.filter { !$0.isDraft }
            if !drafts.isEmpty {
                sectionHeader("Borradores para confirmar",
                              detail: "Lumbre no estaba del todo seguro de estas ideas. Abrilas y confirmalas o corregilas.")
                ForEach(drafts) { concept in
                    conceptLink(concept, entry: "vault")
                }
                if !ready.isEmpty {
                    sectionHeader("Neuronas", detail: nil)
                }
            }
            ForEach(ready) { concept in
                conceptLink(concept, entry: "vault")
            }
            if filtered.isEmpty {
                ContentUnavailableView(
                    "Esta categoría no tiene neuronas",
                    systemImage: "tag",
                    description: Text("Elegí otra o mirá todas las neuronas.")
                )
                .padding(.top, Space.s8)
            }
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        if let searchError {
            LoadErrorView(error: searchError) { Task { await search(debounce: false) } }
        } else if let results = searchResults.map(filter) {
            if results.isEmpty {
                ContentUnavailableView(
                    "Nada por acá",
                    systemImage: "magnifyingglass",
                    description: Text(selectedCategoryID == nil
                        ? "Probá con otras palabras: la búsqueda entiende ideas, no solo coincidencias."
                        : "Probá con otras palabras o sacá el filtro de categoría.")
                )
                .padding(.top, Space.s8)
            } else {
                ForEach(results) { concept in
                    conceptLink(concept, entry: "search")
                }
            }
        } else if isSearching {
            HStack(spacing: Space.s2) {
                ProgressView()
                Text("Buscando ideas parecidas…")
                    .font(.callout)
                    .foregroundStyle(Palette.inkMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, Space.s8)
        }
    }

    private func conceptLink(_ concept: Concept, entry: String) -> some View {
        NavigationLink(value: VaultRoute.concept(concept.id, preview: concept, entry: entry)) {
            ConceptCard(concept)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Abre la neurona"))
    }

    private func sectionHeader(_ title: LocalizedStringKey, detail: LocalizedStringKey?) -> some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            if let detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, Space.s2)
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s2) {
                chip(String(localized: "Todos"), systemImage: nil, isOn: selectedCategoryID == nil) { selectedCategoryID = nil }
                ForEach(categories) { category in
                    chip(category.name, systemImage: category.symbol, isOn: selectedCategoryID == category.id) {
                        if selectedCategoryID == category.id {
                            selectedCategoryID = nil
                        } else {
                            selectedCategoryID = category.id
                            Analytics.track(.vaultFiltered(domain: category.domain?.slug ?? "unclassified"))
                        }
                    }
                }
            }
        }
        .scrollClipDisabled()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Filtrar por categoría"))
    }

    private func chip(_ title: String, systemImage: String?, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .snappy) { action() }
        } label: {
            LumbreChip(title, systemImage: systemImage, variant: isOn ? .on : .select)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emptyVault: some View {
        ContentUnavailableView {
            EmptyStateLabel("Todavía no hay neuronas", systemImage: "square.stack.3d.up", illustration: .emptyVault)
        } description: {
            Text("Guardá una frase, un link o una nota de voz para tener material que conectar.")
        } actions: {
            Button("Capturar") {
                appModel.presentCapture(entry: "empty_vault")
            }
            .buttonStyle(.lumbre(.primary))
        }
        .padding(.top, Space.s8)
    }

    // MARK: - Datos

    private var isSearchActive: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func filter(_ list: [Concept]) -> [Concept] {
        guard let selectedCategoryID else { return list }
        return list.filter { $0.category?.id == selectedCategoryID }
    }

    private func load() async {
        do {
            async let concepts = api.concepts()
            async let categories = api.categories()
            let (loadedConcepts, loadedCategories) = try await (concepts, categories)
            self.concepts = loadedConcepts.sorted { $0.createdAt > $1.createdAt }
            self.categories = loadedCategories
            if let selectedCategoryID, !loadedCategories.contains(where: { $0.id == selectedCategoryID }) {
                self.selectedCategoryID = nil
            }
            loadError = nil
        } catch is CancellationError {
            return
        } catch {
            loadError = error
        }
        isLoading = false
        if isSearchActive { await search(debounce: false) }
    }

    /// Búsqueda semántica con debounce: un pedido (y un `vault_searched`) por búsqueda, no por tecla.
    private func search(debounce: Bool = true) async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            searchResults = nil
            searchError = nil
            isSearching = false
            return
        }
        if debounce {
            searchResults = nil
            do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
        }
        isSearching = true
        defer { isSearching = false }
        do {
            let results = try await api.searchConcepts(text)
            guard !Task.isCancelled else { return }
            searchResults = results
            searchError = nil
            Analytics.track(.vaultSearched(words: TextRecognition.wordCount(text), results: results.count))
        } catch is CancellationError {
            return
        } catch {
            searchError = error
        }
    }
}

#Preview("Red") {
    VaultView()
        .environment(AppModel())
        .preferredColorScheme(.light)
        .tint(Palette.ink)
}

#Preview("Red vacía") {
    VaultView()
        .environment(\.api, MockLumbreAPI(onboarded: false))
        .environment(AppModel())
        .preferredColorScheme(.light)
        .tint(Palette.ink)
}
