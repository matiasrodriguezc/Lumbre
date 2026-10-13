import LumbreCore
import LumbreDesign
import StoreKit
import SwiftUI
import UserNotifications

/// Perfil y ajustes: cuenta, suscripción, perfil creativo, hora de la chispa, cupos, apariencia y privacidad.
struct ProfileView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.api) private var api
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("theme") private var theme: ThemePreference = .dark

    @State private var credits: [Credit] = []
    @State private var creditsError: Error?
    @State private var sparkTime = Date.now
    @State private var sparkTimeSave: Task<Void, Never>?
    @State private var pushStatus: UNAuthorizationStatus?
    @State private var isShowingAccount = false
    @State private var isConfirmingSignOut = false
    @State private var isManagingSubscription = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let profile = appModel.profile {
                    if profile.isGuest {
                        guestAccountSection
                    } else if let email = profile.email {
                        Section("Cuenta") {
                            LabeledContent("Email", value: email)
                        }
                        .listRowBackground(Palette.surface)
                    }
                    subscriptionSection(profile)
                    creativeSection(profile)
                    creditsSection
                    appearanceSection
                    privacySection
                    sessionSection(profile)
                    #if DEBUG
                    DevelopmentSection(onPlanChanged: { await loadCredits() })
                    #endif
                    versionFooter
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.bg)
            .navigationTitle("Perfil")
            .navigationDestination(for: ProfileDestination.self) { destination in
                switch destination {
                case .creativeProfiles: CreativeProfilesEditor()
                case .privacy: PrivacyView()
                }
            }
            .task(id: "\(appModel.profile?.plan.rawValue ?? "-")-\(appModel.dataVersion)") { await loadCredits() }
            .task { await refreshPushStatus() }
            .onAppear {
                Analytics.screen("profile")
                syncSparkTime()
            }
            .onChange(of: appModel.profile?.sparkTime) { _, _ in syncSparkTime() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refreshPushStatus() } }
            }
            .onChange(of: theme) { _, _ in Analytics.track(.settingsChanged(setting: "theme")) }
            .sheet(isPresented: $isShowingAccount) {
                AccountComingSoonSheet(continueTitle: "Entendido")
            }
            .manageSubscriptionsSheet(isPresented: $isManagingSubscription)
            .confirmationDialog("¿Cerrar sesión?", isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
                Button("Cerrar sesión", role: .destructive) { Task { await signOut() } }
            } message: {
                if appModel.isGuest {
                    Text("Usás Lumbre como invitado: si cerrás sesión, perdés tus ideas, chispas y proyectos.")
                } else {
                    Text("Tus ideas quedan guardadas en tu cuenta. Vas a poder volver a entrar cuando quieras.")
                }
            }
            .alert("Algo salió mal", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: Cuenta

    private var guestAccountSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Space.s3) {
                Text("Creá tu cuenta para no perder tus ideas")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                Text("Hoy usás Lumbre como invitado. Con una cuenta, tus ideas quedan a salvo si cambiás o perdés el teléfono.")
                    .font(.callout)
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Crear cuenta") { isShowingAccount = true }
                    .buttonStyle(.lumbre(.primary))
            }
            .padding(.vertical, Space.s2)
            .onAppear { Analytics.track(.accountPromptShown(trigger: "profile")) }
        }
        .listRowBackground(Palette.surface)
    }

    // MARK: Suscripción

    @ViewBuilder
    private func subscriptionSection(_ profile: Profile) -> some View {
        Section("Suscripción") {
            LabeledContent("Plan") {
                PlanBadge(plan: profile.plan)
            }
            if profile.isPro {
                Button("Administrar suscripción") { isManagingSubscription = true }
                    .foregroundStyle(Palette.ink)
            } else if FeatureFlag.paywall.isEnabled {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lumbre Pro")
                        .font(.headline)
                        .foregroundStyle(Palette.ink)
                    Text("Hasta 10 chispas por día, destilación automática y el planificador")
                        .font(.footnote)
                        .foregroundStyle(Palette.inkMuted)
                }
                Button {
                    appModel.presentPaywall(trigger: "settings")
                } label: {
                    Label("Probar 7 días gratis", systemImage: "arrow.up.circle")
                        .foregroundStyle(Palette.proText)
                }
            }
        }
        .listRowBackground(Palette.surface)
    }

    // MARK: Perfil creativo y hora

    private func creativeSection(_ profile: Profile) -> some View {
        Section {
            NavigationLink(value: ProfileDestination.creativeProfiles) {
                LabeledContent("Perfil creativo", value: profile.creativeProfiles.summary)
            }
            DatePicker("Hora de la chispa", selection: $sparkTime, displayedComponents: .hourAndMinute)
                .onChange(of: sparkTime) { _, newValue in scheduleSparkTimeSave(newValue) }
            pushRow
        } header: {
            Text("Tu chispa")
        } footer: {
            Text("La chispa del día te espera a esta hora. El perfil creativo es la lente con la que se eligen las ideas.")
        }
        .listRowBackground(Palette.surface)
    }

    @ViewBuilder
    private var pushRow: some View {
        switch pushStatus {
        case .authorized, .provisional, .ephemeral:
            LabeledContent("Avisos", value: String(localized: "Activados"))
        case .denied:
            Button {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
            } label: {
                LabeledContent("Avisos") {
                    Text("Activalos en Ajustes")
                        .foregroundStyle(Palette.infoText)
                }
            }
            .foregroundStyle(Palette.ink)
        case .notDetermined:
            Button {
                Task { await enablePush() }
            } label: {
                LabeledContent("Avisos") {
                    Text("Activar")
                        .foregroundStyle(Palette.infoText)
                }
            }
            .foregroundStyle(Palette.ink)
        default:
            EmptyView()
        }
    }

    // MARK: Cupos

    private var creditsSection: some View {
        Section {
            if let creditsError, credits.isEmpty {
                Button {
                    Task { await loadCredits() }
                } label: {
                    Label {
                        Text("No pudimos cargar tus cupos. Tocá para reintentar.")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(Palette.warning)
                    }
                }
                .foregroundStyle(Palette.ink)
                .accessibilityHint(Text(ErrorContent(creditsError).message))
            } else if credits.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(visibleCredits, id: \.kind) { credit in
                    CreditRow(credit: credit)
                }
                if !appModel.isPro && !credits.contains(where: { $0.kind == .planner }) {
                    LabeledContent("Planificador") {
                        Text("Con Pro")
                            .foregroundStyle(Palette.proText)
                    }
                }
            }
        } header: {
            Text("Tus cupos")
        }
        .listRowBackground(Palette.surface)
    }

    private var visibleCredits: [Credit] {
        let order: [CreditKind] = [.capture, .distill, .sparkExtra, .planner, .plannerDeep]
        return order.compactMap { kind in credits.first { $0.kind == kind } }
    }

    // MARK: Apariencia

    private var appearanceSection: some View {
        Section {
            Picker("Tema", selection: $theme) {
                ForEach(ThemePreference.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            } label: {
                LabeledContent("Idioma", value: currentLanguageName)
            }
            .foregroundStyle(Palette.ink)
        } header: {
            Text("Apariencia")
        } footer: {
            Text("Lumbre usa el idioma del teléfono. Lo cambiás en Ajustes > Lumbre > Idioma.")
        }
        .listRowBackground(Palette.surface)
    }

    private var currentLanguageName: String {
        let code = Bundle.main.preferredLocalizations.first ?? "es"
        return Locale.current.localizedString(forLanguageCode: code)?.localizedCapitalized ?? code
    }

    // MARK: Privacidad

    private var privacySection: some View {
        Section("Privacidad") {
            NavigationLink(value: ProfileDestination.privacy) {
                Label("Privacidad y datos", systemImage: "lock.shield")
                    .foregroundStyle(Palette.ink)
            }
            Button { openURL(LegalLinks.privacy) } label: {
                Label("Política de privacidad", systemImage: "doc.text")
            }
            .foregroundStyle(Palette.ink)
            Button { openURL(LegalLinks.terms) } label: {
                Label("Términos y condiciones", systemImage: "doc.plaintext")
            }
            .foregroundStyle(Palette.ink)
        }
        .listRowBackground(Palette.surface)
    }

    // MARK: Sesión

    private func sessionSection(_ profile: Profile) -> some View {
        Section {
            Button {
                isConfirmingSignOut = true
            } label: {
                HStack {
                    Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                    Spacer()
                    if isWorking { ProgressView() }
                }
            }
            .foregroundStyle(Palette.ink)
            .disabled(isWorking)
        }
        .listRowBackground(Palette.surface)
    }

    private var versionFooter: some View {
        Section {
        } footer: {
            let info = Bundle.main.infoDictionary
            let version = info?["CFBundleShortVersionString"] as? String ?? "–"
            let build = info?["CFBundleVersion"] as? String ?? "–"
            Text("Lumbre \(version) (\(build))")
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: Acciones

    private func loadCredits() async {
        do {
            credits = try await api.credits()
            creditsError = nil
        } catch {
            creditsError = error
        }
    }

    private func refreshPushStatus() async {
        pushStatus = await PushPermission.status()
    }

    private func enablePush() async {
        Analytics.track(.pushPermissionPrompted(context: "settings"))
        let result = await PushPermission.request()
        Analytics.track(.pushPermissionResponded(granted: result.granted, systemPromptShown: result.systemPromptShown))
        if result.granted {
            Analytics.track(.settingsChanged(setting: "push"))
            if let time = appModel.profile?.sparkTime { await SparkReminder.schedule(at: time) }
        }
        await refreshPushStatus()
    }

    private func syncSparkTime() {
        guard let time = appModel.profile?.sparkTime else { return }
        let date = Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: .now) ?? .now
        if !Calendar.current.isDate(date, equalTo: sparkTime, toGranularity: .minute) {
            sparkTime = date
        }
    }

    /// Guarda la hora en el servidor un momento después de que deja de mover la rueda, y reprograma el aviso.
    private func scheduleSparkTimeSave(_ date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let time = SparkTime(hour: components.hour ?? 8, minute: components.minute ?? 0)
        guard time != appModel.profile?.sparkTime else { return }
        sparkTimeSave?.cancel()
        sparkTimeSave = Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            do {
                let profile = try await api.updateProfile(ProfileUpdate(sparkTime: time, timezone: TimeZone.current.identifier))
                appModel.setProfile(profile)
                await SparkReminder.schedule(at: profile.sparkTime)
                Analytics.track(.sparkHourSet(hour: time.hour, isDefault: time == .default, context: "settings"))
                Analytics.track(.settingsChanged(setting: "spark_hour"))
            } catch {
                errorMessage = ErrorContent(error).message
                syncSparkTime()
            }
        }
    }

    private func signOut() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await api.signOut()
            SparkReminder.cancel()
            Analytics.reset()
            appModel.reset()
        } catch {
            errorMessage = ErrorContent(error).message
        }
    }
}

enum ProfileDestination: Hashable {
    case creativeProfiles
    case privacy
}

/// Plan actual. El violeta significa Pro y nada más.
struct PlanBadge: View {
    let plan: Plan

    var body: some View {
        switch plan {
        case .pro:
            Text("Pro")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.onPro)
                .padding(.horizontal, Space.s2)
                .padding(.vertical, 2)
                .background(Palette.pro, in: Capsule())
        case .free:
            Text("Gratis").foregroundStyle(Palette.inkMuted)
        case .guest:
            Text("Invitado").foregroundStyle(Palette.inkMuted)
        }
    }
}

/// Un cupo: cuánto queda de cuánto, y en qué período.
private struct CreditRow: View {
    let credit: Credit

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            LabeledContent {
                Text("\(credit.remaining) de \(credit.max)")
                    .monospacedDigit()
            } label: {
                Text(title)
            }
            ProgressView(value: Double(credit.remaining), total: Double(max(credit.max, 1)))
                .tint(Palette.infoText)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text("Te quedan \(credit.remaining) de \(credit.max)"))
    }

    private var title: LocalizedStringKey {
        switch credit.kind {
        case .capture: "Capturas de hoy"
        case .distill: "Destilaciones del mes"
        case .sparkExtra: "Chispas extra de hoy"
        case .planner: "Planificador este mes"
        case .plannerDeep: "Planes profundos este mes"
        case .projects: "Proyectos"
        }
    }
}

extension ThemePreference {
    var label: LocalizedStringKey {
        switch self {
        case .dark: return "Oscuro"
        case .light: return "Claro"
        case .system: return "Como el sistema"
        }
    }
}

#Preview("Free") {
    ProfileView()
        .environment(AppModel.preview())
        .preferredColorScheme(.dark)
        .tint(Palette.accentText)
}

#Preview("Invitado") {
    ProfileView()
        .environment(\.api, MockLumbreAPI(onboarded: false))
        .environment(AppModel.preview(api: MockLumbreAPI(onboarded: false)))
        .preferredColorScheme(.light)
        .tint(Palette.accentText)
}

extension AppModel {
    /// Para previews: un AppModel con el perfil del mock ya cargado.
    static func preview(api: any LumbreAPI = MockLumbreAPI(latency: .zero)) -> AppModel {
        let model = AppModel()
        Task { await model.loadProfile(api: api) }
        return model
    }
}
