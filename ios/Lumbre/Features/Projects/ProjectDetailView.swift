import LumbreCore
import LumbreDesign
import SwiftUI

/// Un proyecto con sus ideas guardadas y el export a Markdown.
struct ProjectDetailView: View {
    let project: Project

    @Environment(\.api) private var api
    @Environment(AppModel.self) private var appModel
    @Environment(\.dataVersion) private var dataVersion
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var sparks: [Spark] = []
    @State private var markdown: MarkdownDocument?
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var editor: ProjectEditor?
    @State private var isDeleting = false

    init(project: Project) {
        self.project = project
        _name = State(initialValue: project.name)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s3) {
                if let loadError {
                    LoadErrorView(error: loadError) { Task { await load() } }
                } else if !isLoading && sparks.isEmpty {
                    ContentUnavailableView {
                        Label("Todavía no hay ideas en este circuito", systemImage: "bookmark")
                    } description: {
                        Text("Cuando guardes una chispa, elegí este circuito para sumarla.")
                    } actions: {
                        Button("Ir a Hoy") { appModel.open(.today) }
                            .buttonStyle(.lumbre(.secondary))
                    }
                    .padding(.top, Space.s8)
                } else {
                    Text("\(sparks.count) ideas")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Palette.inkMuted)
                    ForEach(sparks) { spark in
                        NavigationLink(value: SparkRoute.detail(spark.id)) {
                            SparkRow(spark: spark, showsProject: false)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if appModel.isPro && FeatureFlag.planner.isEnabled {
                                NavigationLink(value: SparkRoute.planner(spark.id, entry: "project")) {
                                    Label("Planificar", systemImage: "text.bubble")
                                }
                            }
                        }
                    }
                    .redacted(reason: isLoading && sparks.isEmpty ? .placeholder : [])
                }
            }
            .padding(.horizontal, Space.s4)
            .padding(.bottom, Space.s8)
        }
        .neuralBackground()
        .navigationTitle(name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if let markdown {
                        ShareLink(item: markdown, preview: SharePreview(name)) {
                            Label("Exportar a Markdown", systemImage: "doc.text")
                        }
                    }
                    Button {
                        editor = .rename(Project(id: project.id, name: name, sparkCount: sparks.count, createdAt: project.createdAt))
                    } label: {
                        Label("Renombrar", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        isDeleting = true
                    } label: {
                        Label("Borrar circuito", systemImage: "trash")
                    }
                } label: {
                    Label("Más acciones", systemImage: "ellipsis")
                }
            }
        }
        .task(id: dataVersion) { await load() }
        .refreshable { await load() }
        .onAppear { Analytics.screen("project_detail") }
        .projectEditor($editor) { await load() }
        .confirmationDialog("¿Borrar este circuito?", isPresented: $isDeleting, titleVisibility: .visible) {
            Button("Borrar circuito", role: .destructive, action: delete)
        } message: {
            Text("Sus ideas quedan guardadas, sin circuito.")
        }
    }

    private func load() async {
        do {
            async let sparks = api.sparks(inProject: project.id)
            async let projects = api.projects()
            async let text = api.exportProjectMarkdown(id: project.id)
            let (loadedSparks, loadedProjects, loadedText) = try await (sparks, projects, text)
            self.sparks = loadedSparks
            if let current = loadedProjects.first(where: { $0.id == project.id }) {
                name = current.name
            }
            markdown = MarkdownDocument(title: name, text: loadedText, object: "project")
            loadError = nil
        } catch {
            loadError = error
        }
        isLoading = false
    }

    private func delete() {
        Task {
            do {
                try await api.deleteProject(id: project.id)
                appModel.dataChanged()
                dismiss()
            } catch {
                loadError = error
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProjectDetailView(project: MockData.project)
            .sparkDestinations()
    }
    .environment(AppModel())
    .preferredColorScheme(.light)
}
