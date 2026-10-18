import LumbreCore
import LumbreDesign
import SwiftUI

enum ProjectRoute: Hashable {
    case detail(Project)
}

/// Proyectos: dónde se agrupan las ideas guardadas. 1 en free, ilimitados en Pro.
struct ProjectsView: View {
    @Environment(\.api) private var api
    @Environment(AppModel.self) private var appModel
    @Environment(\.dataVersion) private var dataVersion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var path = NavigationPath()
    @State private var projects: [Project] = []
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var editor: ProjectEditor?
    @State private var deleting: Project?
    @State private var actionError: String?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let loadError, projects.isEmpty {
                    ScrollView { LoadErrorView(error: loadError) { Task { await load() } } }
                } else if !isLoading && projects.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .neuralBackground()
            .navigationTitle("Circuitos")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: startCreating) {
                        Label("Nuevo circuito", systemImage: "folder.badge.plus")
                    }
                }
            }
            .navigationDestination(for: ProjectRoute.self) { route in
                switch route {
                case .detail(let project): ProjectDetailView(project: project)
                }
            }
            .sparkDestinations()
            .task(id: dataVersion) { await load() }
            .refreshable { await load() }
            // Con "tirar para actualizar" el rebote hace falta aunque el contenido entre.
            .scrollBounceBehavior(.always)
            .onAppear { Analytics.screen("projects") }
            .projectEditor($editor) { await load() }
            .confirmationDialog(
                "¿Borrar este circuito?",
                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                titleVisibility: .visible,
                presenting: deleting
            ) { project in
                Button("Borrar circuito", role: .destructive) { delete(project) }
            } message: { _ in
                Text("Sus ideas quedan guardadas, sin circuito.")
            }
        }
    }

    private var list: some View {
        List {
            Section {
                ForEach(projects) { project in
                    NavigationLink(value: ProjectRoute.detail(project)) {
                        ProjectRow(project: project)
                    }
                    .listRowBackground(Palette.surface)
                    .swipeActions(edge: .trailing) {
                        Button("Borrar", role: .destructive) { deleting = project }
                        Button("Renombrar") { editor = .rename(project) }
                    }
                    .contextMenu {
                        Button {
                            editor = .rename(project)
                        } label: {
                            Label("Renombrar", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            deleting = project
                        } label: {
                            Label("Borrar", systemImage: "trash")
                        }
                    }
                }
            } footer: {
                if !appModel.isPro && !projects.isEmpty {
                    Text("Con el plan gratis tenés un circuito. Con Pro, todos los que quieras.")
                }
            }
            if let actionError {
                Section {
                    Label(actionError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Palette.danger)
                }
                .listRowBackground(Palette.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .redacted(reason: isLoading && projects.isEmpty ? .placeholder : [])
    }

    private var emptyState: some View {
        ContentUnavailableView {
            EmptyStateLabel("Todavía no hay circuitos", systemImage: "square.grid.2x2", illustration: .emptyCircuits)
        } description: {
            Text("Un circuito junta las ideas que querés llevar adelante. Creá uno o guardá una chispa desde Hoy y elegí dónde sumarla.")
        } actions: {
            Button("Crear circuito", action: startCreating)
                .buttonStyle(.lumbre(.secondary))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func startCreating() {
        if !appModel.isPro && !projects.isEmpty {
            appModel.presentPaywall(trigger: "projects")
        } else {
            editor = .create
        }
    }

    private func load() async {
        do {
            projects = try await api.projects()
            loadError = nil
        } catch {
            loadError = error
        }
        isLoading = false
    }

    private func delete(_ project: Project) {
        Task {
            do {
                try await api.deleteProject(id: project.id)
                withAnimation(reduceMotion ? nil : .default) { projects.removeAll { $0.id == project.id } }
                actionError = nil
                appModel.dataChanged()
            } catch {
                actionError = error.localizedDescription
            }
        }
    }
}

private struct ProjectRow: View {
    let project: Project

    var body: some View {
        HStack(spacing: Space.s3) {
            SectionIcon(.circuit)
                .foregroundStyle(Palette.inkMuted)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                Text("\(project.sparkCount) ideas")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Palette.inkMuted)
            }
        }
        .padding(.vertical, Space.s1)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Crear y renombrar

enum ProjectEditor: Identifiable {
    case create
    case rename(Project)

    var id: String {
        switch self {
        case .create: "create"
        case .rename(let project): project.id.uuidString
        }
    }
}

extension View {
    /// Alerta con un campo para crear o renombrar un proyecto. `onDone` corre después de guardar.
    func projectEditor(_ editor: Binding<ProjectEditor?>, onDone: @escaping () async -> Void) -> some View {
        modifier(ProjectEditorModifier(editor: editor, onDone: onDone))
    }
}

private struct ProjectEditorModifier: ViewModifier {
    @Binding var editor: ProjectEditor?
    let onDone: () async -> Void

    @Environment(\.api) private var api
    @Environment(AppModel.self) private var appModel
    @State private var name = ""
    @State private var errorMessage: String?

    func body(content: Content) -> some View {
        content
            .alert(
                title,
                isPresented: Binding(get: { editor != nil }, set: { if !$0 { editor = nil } }),
                presenting: editor
            ) { current in
                TextField("Nombre del circuito", text: $name)
                Button("Cancelar", role: .cancel) {}
                Button(current.isCreate ? "Crear" : "Guardar") { save(current) }
            }
            .onChange(of: editor?.id) {
                if case .rename(let project) = editor { name = project.name } else { name = "" }
            }
            .alert("No pudimos guardar el circuito", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("Aceptar", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
    }

    private var title: LocalizedStringKey {
        if case .rename = editor { return "Renombrar circuito" }
        return "Nuevo circuito"
    }

    private func save(_ current: ProjectEditor) {
        let clean = name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !clean.isEmpty else { return }
        Task {
            do {
                switch current {
                case .create:
                    _ = try await api.createProject(name: clean)
                case .rename(let project):
                    try await api.renameProject(id: project.id, to: clean)
                }
                appModel.dataChanged()
                await onDone()
            } catch LumbreAPIError.tooManyProjects {
                appModel.presentPaywall(trigger: "projects")
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private extension ProjectEditor {
    var isCreate: Bool {
        if case .create = self { return true }
        return false
    }
}

#Preview {
    ProjectsView()
        .environment(AppModel())
        .preferredColorScheme(.light)
}
