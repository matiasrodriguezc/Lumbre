import LumbreCore
import LumbreDesign
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Perfil creativo

/// Edita los perfiles creativos (hasta dos) y los guarda en el servidor.
struct CreativeProfilesEditor: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.api) private var api
    @Environment(\.dismiss) private var dismiss
    @State private var selection: [CreativeProfile] = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s4) {
                Text("Elegí hasta dos. Son la lente con la que se eligen y escriben tus chispas.")
                    .font(.callout)
                    .foregroundStyle(Palette.inkMuted)
                CreativeProfilePicker(selection: $selection)
            }
            .padding(Space.s4)
        }
        .neuralBackground()
        .navigationTitle("Perfil creativo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Guardar") { Task { await save() } }
                        .disabled(selection.isEmpty || selection == appModel.profile?.creativeProfiles)
                }
            }
        }
        .onAppear {
            Analytics.screen("settings")
            selection = appModel.profile?.creativeProfiles ?? []
        }
        .alert("No se pudo guardar", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let profile = try await api.updateProfile(ProfileUpdate(creativeProfiles: selection))
            appModel.setProfile(profile)
            Analytics.track(.settingsChanged(setting: "profiles"))
            dismiss()
        } catch {
            errorMessage = ErrorContent(error).message
        }
    }
}

// MARK: - Privacidad y datos

/// Consentimiento para IA, exportar los datos y borrar la cuenta (obligatorio en ambas tiendas).
struct PrivacyView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.api) private var api
    @AppStorage("aiConsent") private var aiConsent: Bool?
    @State private var exportFile: JSONFile?
    @State private var isExporting = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Toggle("Chispas y conceptualización con IA", isOn: Binding(
                    get: { aiConsent ?? false },
                    set: { granted in AIConsent.record(granted, api: api) }
                ))
            } footer: {
                Text("Para conceptualizar tus ideas y encender las chispas, Lumbre manda el texto de tus ideas y tu perfil creativo a Claude, una IA de Anthropic. Sin este permiso podés guardar neuronas, pero no se conceptualizan ni se encienden chispas, y el planificador no responde.")
            }
            .listRowBackground(Palette.surface)

            Section {
                Button {
                    Task { await export() }
                } label: {
                    HStack {
                        Label("Exportar mis datos", systemImage: "square.and.arrow.up")
                        Spacer()
                        if isExporting { ProgressView() }
                    }
                }
                .foregroundStyle(Palette.ink)
                .disabled(isExporting)
            } footer: {
                Text("Un archivo JSON con tu perfil, categorías, neuronas, chispas, circuitos y conversaciones del planificador.")
            }
            .listRowBackground(Palette.surface)

            Section {
                Button(role: .destructive) {
                    isDeleting = true
                } label: {
                    Label("Borrar cuenta", systemImage: "trash")
                        .foregroundStyle(Palette.danger)
                }
            } footer: {
                Text("Borra tu cuenta y todo lo que guardaste. No se puede deshacer.")
            }
            .listRowBackground(Palette.surface)
        }
        .scrollContentBackground(.hidden)
        .neuralBackground()
        .navigationTitle("Privacidad y datos")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { Analytics.screen("privacy") }
        .fileExporter(isPresented: Binding(get: { exportFile != nil }, set: { if !$0 { exportFile = nil } }),
                      document: exportFile, contentType: .json, defaultFilename: exportFilename) { result in
            if case .failure(let error) = result {
                errorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $isDeleting) {
            DeleteAccountSheet()
        }
        .alert("Algo salió mal", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var exportFilename: String {
        "lumbre-datos-\(Date.now.formatted(.iso8601.year().month().day()))"
    }

    private func export() async {
        isExporting = true
        defer { isExporting = false }
        do {
            exportFile = JSONFile(data: try await api.exportData())
        } catch {
            Analytics.track(.errorShown(screen: "privacy", code: "export_failed"))
            errorMessage = ErrorContent(error).message
        }
    }
}

/// Documento JSON para `fileExporter`.
struct JSONFile: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Borrar cuenta

/// Confirmación fuerte: hay que escribir BORRAR. Después vuelve al onboarding.
struct DeleteAccountSheet: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.api) private var api
    @Environment(\.dismiss) private var dismiss
    @AppStorage("aiConsent") private var aiConsent: Bool?
    @State private var confirmation = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    private var confirmationWord: String { String(localized: "BORRAR") }
    private var isConfirmed: Bool {
        confirmation.trimmingCharacters(in: .whitespaces).compare(confirmationWord, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s4) {
                    Label {
                        Text("Esto no se puede deshacer")
                            .font(.headline)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Palette.danger)
                    }
                    .foregroundStyle(Palette.ink)

                    Text("Se borran tu cuenta, tus neuronas, chispas, circuitos y conversaciones del planificador, en todos tus dispositivos.")
                        .font(.body)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    if appModel.isPro {
                        Label("Borrar la cuenta no cancela tu suscripción a Pro. Cancelala en Ajustes > tu nombre > Suscripciones.", systemImage: "creditcard")
                            .font(.callout)
                            .foregroundStyle(Palette.ink)
                            .padding(Space.s3)
                            .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    }

                    Text("Si querés quedarte con una copia, exportá tus datos antes.")
                        .font(.callout)
                        .foregroundStyle(Palette.inkMuted)

                    VStack(alignment: .leading, spacing: Space.s2) {
                        Text("Para confirmar, escribí \(confirmationWord)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Palette.ink)
                        TextField(confirmationWord, text: $confirmation)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .focused($isFocused)
                            .padding(Space.s3)
                            .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .strokeBorder(isFocused ? Palette.focusRing : Palette.borderStrong, lineWidth: isFocused ? 2 : 1))
                            .accessibilityLabel(Text("Palabra de confirmación"))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Space.s4)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                Button(role: .destructive) {
                    Task { await deleteAccount() }
                } label: {
                    HStack(spacing: Space.s2) {
                        if isDeleting {
                            ProgressView().tint(Palette.danger)
                        } else {
                            Image(systemName: "trash")
                        }
                        Text("Borrar mi cuenta")
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Palette.danger)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).strokeBorder(Palette.danger, lineWidth: 1.5))
                    .contentShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!isConfirmed || isDeleting)
                .opacity(isConfirmed ? 1 : 0.4)
                .padding(.horizontal, Space.s4)
                .padding(.bottom, Space.s2)
            }
            .background(Palette.surface)
            .navigationTitle("Borrar cuenta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .disabled(isDeleting)
                }
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(Radius.lg)
        .interactiveDismissDisabled(isDeleting)
        .alert("No se pudo borrar la cuenta", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await api.deleteAccount()
            SparkReminder.cancel()
            Analytics.reset()
            AIConsent.clear()
            dismiss()
            appModel.reset()
        } catch {
            Analytics.track(.errorShown(screen: "privacy", code: "delete_failed"))
            errorMessage = ErrorContent(error).message
        }
    }
}

// MARK: - Desarrollo

#if DEBUG
/// Solo Debug: cambiar el plan sin pasar por la tienda y volver a ver el onboarding.
struct DevelopmentSection: View {
    let onPlanChanged: () async -> Void
    @Environment(AppModel.self) private var appModel
    @Environment(\.api) private var api
    @State private var isChanging = false
    @State private var errorMessage: String?

    var body: some View {
        Section {
            Picker("Plan", selection: Binding(
                get: { appModel.profile?.plan ?? .guest },
                set: { plan in Task { await setPlan(plan) } }
            )) {
                Text(verbatim: "Invitado").tag(Plan.guest)
                Text(verbatim: "Gratis").tag(Plan.free)
                Text(verbatim: "Pro").tag(Plan.pro)
            }
            .disabled(isChanging)
            Button {
                appModel.replayOnboarding()
            } label: {
                Text(verbatim: "Volver a ver el onboarding")
            }
            .foregroundStyle(Palette.ink)
            if let errorMessage {
                Text(verbatim: errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Palette.danger)
            }
        } header: {
            Text(verbatim: "Desarrollo")
        } footer: {
            Text(verbatim: "Solo en Debug. El plan real lo cambia el webhook de RevenueCat.")
        }
        .listRowBackground(Palette.surface)
    }

    private func setPlan(_ plan: Plan) async {
        isChanging = true
        defer { isChanging = false }
        do {
            try await api.setPlanForDevelopment(plan)
            errorMessage = nil
            await appModel.loadProfile(api: api)
            appModel.dataChanged()
            await onPlanChanged()
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
#endif

#Preview("Privacidad") {
    NavigationStack { PrivacyView() }
        .environment(AppModel.preview())
        .preferredColorScheme(.light)
}

#Preview("Borrar cuenta") {
    DeleteAccountSheet()
        .environment(AppModel.preview())
        .preferredColorScheme(.light)
}

#Preview("Perfil creativo") {
    NavigationStack { CreativeProfilesEditor() }
        .environment(AppModel.preview())
        .preferredColorScheme(.light)
}
