import LumbreCore
import LumbreDesign
import SwiftUI

/// "Guardar idea": sin proyecto, en uno existente o en uno nuevo. Si la chispa ya estaba guardada, la mueve.
struct SaveSparkSheet: View {
    let spark: Spark
    let onSaved: (Project.ID?, String?) -> Void

    @Environment(\.api) private var api
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var projects: [Project] = []
    @State private var isLoading = true
    @State private var newName = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @FocusState private var isNaming: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    destinationRow(name: Text("Sin circuito"), detail: Text("Queda en tus ideas guardadas"), systemImage: "bookmark", projectID: nil, projectName: nil)
                    ForEach(projects) { project in
                        destinationRow(
                            name: Text(project.name),
                            detail: Text("^[\(project.sparkCount) idea](inflect: true)"),
                            systemImage: nil,
                            projectID: project.id,
                            projectName: project.name
                        )
                    }
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                } header: {
                    Text("Dónde la guardás")
                }

                Section {
                    if canCreateProject {
                        HStack(spacing: Space.s2) {
                            TextField("Nombre del circuito", text: $newName)
                                .focused($isNaming)
                                .submitLabel(.done)
                                .onSubmit(createAndSave)
                            Button("Crear", action: createAndSave)
                                .disabled(trimmedName.isEmpty || isWorking)
                        }
                    } else {
                        Button {
                            dismissThenPaywall()
                        } label: {
                            HStack {
                                Text("Crear otro circuito")
                                    .foregroundStyle(Palette.ink)
                                Spacer()
                                Text("Pro")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Palette.proText)
                            }
                        }
                    }
                } header: {
                    Text("Nuevo circuito")
                } footer: {
                    if !canCreateProject {
                        Text("Con el plan gratis tenés un circuito. Con Pro, todos los que quieras.")
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Palette.danger)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.surface)
            .navigationTitle(spark.status == .saved ? "Mover idea" : "Guardar idea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .disabled(isWorking)
            .task { await load() }
        }
        .presentationDetents([.medium, .large])
    }

    private var trimmedName: String {
        newName.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private var canCreateProject: Bool {
        appModel.isPro || projects.isEmpty
    }

    /// `systemImage` nil: el ícono de circuito.
    private func destinationRow(name: Text, detail: Text, systemImage: String?, projectID: Project.ID?, projectName: String?) -> some View {
        let isCurrent = spark.status == .saved && spark.projectID == projectID
        return Button {
            save(projectID: projectID, projectName: projectName)
        } label: {
            HStack(spacing: Space.s3) {
                Group {
                    if let systemImage { Image(systemName: systemImage) } else { SectionIcon(.circuit) }
                }
                .foregroundStyle(Palette.inkMuted)
                .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    name.foregroundStyle(Palette.ink)
                    detail.font(.footnote).foregroundStyle(Palette.inkMuted)
                }
                Spacer(minLength: 0)
                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                }
            }
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private func load() async {
        do {
            projects = try await api.projects()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func save(projectID: Project.ID?, projectName: String?) {
        isWorking = true
        errorMessage = nil
        Task {
            defer { isWorking = false }
            do {
                try await api.saveSpark(id: spark.id, projectID: projectID)
                onSaved(projectID, projectName)
                appModel.dataChanged()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func createAndSave() {
        let name = trimmedName
        guard !name.isEmpty, !isWorking else { return }
        isWorking = true
        errorMessage = nil
        Task {
            do {
                let project = try await api.createProject(name: name)
                isWorking = false
                save(projectID: project.id, projectName: project.name)
            } catch LumbreAPIError.tooManyProjects {
                isWorking = false
                dismissThenPaywall()
            } catch {
                isWorking = false
                errorMessage = error.localizedDescription
            }
        }
    }

    /// El paywall se presenta desde la raíz: primero se cierra esta sheet.
    private func dismissThenPaywall() {
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            appModel.presentPaywall(trigger: "projects")
        }
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            SaveSparkSheet(spark: MockData.recentSparks[1]) { _, _ in }
        }
        .environment(AppModel())
        .preferredColorScheme(.light)
}
