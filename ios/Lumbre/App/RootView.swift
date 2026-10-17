import LumbreCore
import LumbreDesign
import SwiftUI

/// Arranque de la app: carga el perfil y decide entre el onboarding y las pestañas.
/// También presenta el paywall global y la sheet de Capturar.
struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.api) private var api
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasLoadedOnce = false
    @State private var linkError: String?

    var body: some View {
        @Bindable var appModel = appModel
        content
            .animation(.default, value: phase)
            .task(id: appModel.sessionVersion) { await load() }
            .onChange(of: scenePhase) { _, newPhase in
                // Al volver a primer plano el plan o la hora pueden haber cambiado (compra, otro dispositivo).
                guard newPhase == .active, hasLoadedOnce else { return }
                Task { await appModel.loadProfile(api: api) }
            }
            .sheet(isPresented: Binding(
                get: { appModel.paywallTrigger != nil && FeatureFlag.paywall.isEnabled },
                set: { if !$0 { appModel.paywallTrigger = nil } }
            )) {
                PaywallView(trigger: appModel.paywallTrigger ?? "settings")
            }
            .sheet(isPresented: Binding(
                get: { appModel.accountTrigger != nil },
                set: { if !$0 { appModel.accountTrigger = nil } }
            )) {
                CreateAccountSheet()
            }
            .sheet(isPresented: Binding(
                get: { appModel.isAskingAIConsent },
                set: { appModel.isAskingAIConsent = $0 }
            )) {
                AIConsentSheet { granted in
                    AIConsent.record(granted, api: api)
                    appModel.isAskingAIConsent = false
                    appModel.dataChanged()
                }
            }
            .onOpenURL { url in
                guard EmailAccount.isCallback(url) else { return }
                Task { await completeEmailLink(url) }
            }
            .alert("No pudimos entrar con el link", isPresented: Binding(get: { linkError != nil }, set: { if !$0 { linkError = nil } })) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(linkError ?? "")
            }
    }

    /// El link del email (`lumbre://auth-callback`) abierto en este teléfono: crea la cuenta o entra.
    private func completeEmailLink(_ url: URL) async {
        guard FeatureFlag.emailAccount.isEnabled else { return }
        do {
            let profile = try await api.completeEmailLink(url)
            appModel.accountTrigger = nil
            appModel.accountChanged(to: profile, purpose: .signIn)
        } catch {
            linkError = (error as? LumbreAPIError)?.errorDescription ?? LumbreAPIError.unexpected.errorDescription
        }
    }

    private enum Phase: Hashable {
        case loading, failed, onboarding, main
    }

    private var phase: Phase {
        if appModel.profile == nil {
            return appModel.profileError == nil ? .loading : .failed
        }
        return appModel.needsOnboarding ? .onboarding : .main
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            SplashView()
        case .failed:
            LoadErrorView(error: appModel.profileError ?? LumbreAPIError.unexpected, screen: "launch") {
                Task { await load() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.bg)
        case .onboarding:
            OnboardingView(profile: appModel.profile)
                .transition(.opacity)
        case .main:
            MainTabsView()
                .transition(.opacity)
        }
    }

    private func load() async {
        await appModel.loadProfile(api: api)
        hasLoadedOnce = true
        // Si la vez anterior no se pudo copiar el consentimiento a la cuenta (sin red), se reintenta.
        Task { await AIConsent.sync(api: api) }
        if let profile = appModel.profile, profile.isOnboarded {
            // El aviso local depende de la hora guardada en el servidor: se reprograma en cada arranque.
            await SparkReminder.schedule(at: profile.sparkTime)
        }
    }
}

/// Splash mientras carga el perfil: el símbolo y el wordmark sobre la red dormida.
private struct SplashView: View {
    @Environment(\.neuralIdentity) private var neuralIdentity

    var body: some View {
        VStack(spacing: Space.s4) {
            if neuralIdentity {
                LumbreMark(.long).frame(width: 150)
            }
            Wordmark()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            if neuralIdentity { NeuralNetworkBackground(.tall).ignoresSafeArea() }
        }
        .background(Palette.bg)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Lumbre, cargando"))
    }
}

/// Barra flotante con los cuatro destinos y el botón Capturar separado a la derecha.
/// En iOS 26 el sistema ubica la pestaña con `role: .search` aparte, en su propio círculo de Liquid Glass;
/// acá se usa ese lugar para Capturar y la selección se intercepta para abrir la sheet.
private struct MainTabsView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.neuralIdentity) private var neuralIdentity

    var body: some View {
        tabs
            .environment(\.dataVersion, appModel.dataVersion)
            .sheet(item: Binding(get: { appModel.captureEntry.map(CaptureEntry.init) }, set: { appModel.captureEntry = $0?.id })) { _ in
                CaptureSheet { appModel.dataChanged() }
            }
    }

    private var selectionBinding: Binding<AppTab> {
        Binding(
            get: { appModel.selectedTab },
            set: { newValue in
                if newValue == .capture {
                    appModel.presentCapture(entry: "fab")
                } else {
                    appModel.selectedTab = newValue
                }
            }
        )
    }

    @ViewBuilder
    private var tabs: some View {
        if #available(iOS 18, *) {
            TabView(selection: selectionBinding) {
                Tab(value: .today) { TodayView() } label: { tabLabel(.today) }
                Tab(value: .vault) { VaultView() } label: { tabLabel(.vault) }
                Tab(value: .projects) { ProjectsView() } label: { tabLabel(.projects) }
                Tab(value: .profile) { ProfileView() } label: { tabLabel(.profile) }
                Tab("Capturar", systemImage: "plus", value: .capture, role: .search) { Color.clear }
            }
            .modifier(MinimizeTabBarOnScroll())
        } else {
            TabView(selection: selectionBinding) {
                TodayView().tabItem { tabLabel(.today) }.tag(AppTab.today)
                VaultView().tabItem { tabLabel(.vault) }.tag(AppTab.vault)
                ProjectsView().tabItem { tabLabel(.projects) }.tag(AppTab.projects)
                ProfileView().tabItem { tabLabel(.profile) }.tag(AppTab.profile)
                Color.clear.tabItem { Label("Capturar", systemImage: "plus") }.tag(AppTab.capture)
            }
        }
    }
}

extension MainTabsView {
    /// Pestañas de la identidad neuronal: Hoy es una neurona, Red tus neuronas conectadas, Circuitos los proyectos
    /// y Perfil una cabeza con cerebro. Sin el flag, los símbolos del sistema de antes.
    @ViewBuilder
    func tabLabel(_ tab: AppTab) -> some View {
        switch tab {
        case .today: Label { Text("Hoy") } icon: { SectionIcon(.today) }
        case .vault: Label { Text("Red") } icon: { SectionIcon(.network) }
        case .projects: Label { Text("Circuitos") } icon: { SectionIcon(.circuit) }
        case .profile: Label("Perfil", systemImage: neuralIdentity ? "brain.head.profile" : "person.crop.circle")
        case .capture: Label("Capturar", systemImage: "plus")
        }
    }
}

private struct MinimizeTabBarOnScroll: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
    }
}

private struct CaptureEntry: Identifiable {
    let id: String
}

#Preview("App") {
    RootView()
        .environment(AppModel())
        .preferredColorScheme(.light)
        .tint(Palette.ink)
}

#Preview("Onboarding desde cero") {
    RootView()
        .environment(\.api, MockLumbreAPI(onboarded: false))
        .environment(AppModel())
        .preferredColorScheme(.light)
        .tint(Palette.ink)
}
