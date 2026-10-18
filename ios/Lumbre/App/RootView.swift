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
    /// El splash queda hasta que el punto termina su recorrido (solo al abrir; con el flag `splash_dot`).
    @State private var splashDone = !FeatureFlag.splashDot.isEnabled

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
            .sheet(item: $appModel.importRequest) { request in
                ImportNotesView(request: request)
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
        if !splashDone { return .loading }
        if appModel.profile == nil {
            return appModel.profileError == nil ? .loading : .failed
        }
        return appModel.needsOnboarding ? .onboarding : .main
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            SplashView { splashDone = true }
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
/// Con el flag `splash_dot`, arranca con la neurona y su núcleo rosa; el punto baja hasta la línea del nombre y
/// corre a la derecha escribiendo "Lumbre" a su paso, hasta quedar como el punto del wordmark.
private struct SplashView: View {
    var onFinished: () -> Void = {}

    @Environment(\.neuralIdentity) private var neuralIdentity
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now
    @State private var textFrame: CGRect = .zero
    @ScaledMetric(relativeTo: .largeTitle) private var dotSize: CGFloat = 8

    private static let markWidth: CGFloat = 150
    /// Recorrido: quieto, baja (0,30 → 0,62 s), corre escribiendo (0,62 → 1,25 s) y llega.
    private static let hold = 0.30, dropEnd = 0.62, writeEnd = 1.25, duration = 1.4

    /// Solo Debug: `-splashAt 800` congela el splash en ese instante (ms) y no sigue, para revisar cada cuadro.
    private static var frozenAt: Double? {
        #if DEBUG
        UserDefaults.standard.object(forKey: "splashAt").map { _ in UserDefaults.standard.double(forKey: "splashAt") / 1000 }
        #else
        nil
        #endif
    }

    var body: some View {
        if neuralIdentity && FeatureFlag.splashDot.isEnabled {
            TimelineView(.animation(paused: reduceMotion)) { context in
                animated(t: Self.frozenAt ?? (reduceMotion ? Self.duration : context.date.timeIntervalSince(start)))
            }
            .task {
                guard Self.frozenAt == nil else { return }
                try? await Task.sleep(for: .seconds(reduceMotion ? 0.3 : Self.duration))
                onFinished()
            }
        } else {
            VStack(spacing: Space.s4) {
                if neuralIdentity {
                    LumbreMark(.long).frame(width: Self.markWidth)
                }
                Wordmark()
            }
            .splashBackground(neuralIdentity: neuralIdentity)
            .task { onFinished() }
        }
    }

    private func animated(t: Double) -> some View {
        let drop = ease(progress(t, from: Self.hold, to: Self.dropEnd))
        let write = ease(progress(t, from: Self.dropEnd, to: Self.writeEnd))
        return VStack(spacing: Space.s4) {
            LumbreMark(.long).frame(width: Self.markWidth)
            Text(verbatim: "Lumbre")
                .lumbreDisplay(.sparkHero)
                .foregroundStyle(Palette.ink)
                // El nombre aparece detrás del punto, de izquierda a derecha.
                .mask(alignment: .leading) {
                    Rectangle().frame(width: max(textFrame.width * write, 0))
                }
                // Lugar del punto final (lo dibuja la capa de arriba).
                .padding(.trailing, dotSize + 2)
                .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .named("splash")) }) { textFrame = $0 }
        }
        .overlay {
            GeometryReader { _ in
                dot(drop: drop, write: write)
            }
        }
        .coordinateSpace(.named("splash"))
        .splashBackground(neuralIdentity: true)
    }

    /// El punto: del núcleo del símbolo al final del nombre, achicándose al tamaño del punto del wordmark.
    private func dot(drop: Double, write: Double) -> some View {
        let mark = LumbreMark.longNucleus(width: Self.markWidth)
        let markTop: CGFloat = textFrame.minY - Space.s4 - mark.height
        let markLeft: CGFloat = textFrame.midX - Self.markWidth / 2
        let nucleus = CGPoint(x: markLeft + mark.center.x, y: markTop + mark.center.y)
        let textWidth: CGFloat = textFrame.width - dotSize - 2
        // La línea de base aproximada del nombre: el punto se apoya ahí, como en el wordmark.
        let lineY: CGFloat = textFrame.maxY - dotSize / 2 - textFrame.height * 0.2
        let landingX: CGFloat = textFrame.minX
        let finalX: CGFloat = textFrame.minX + textWidth + 2 + dotSize / 2
        let x: CGFloat
        let y: CGFloat
        if write > 0 {
            x = landingX + (finalX - landingX) * write
            y = lineY
        } else {
            x = nucleus.x + (landingX - nucleus.x) * drop
            // Al bajar hace un arco corto hacia arriba, como si saltara.
            y = nucleus.y + (lineY - nucleus.y) * drop - 18 * sin(.pi * drop)
        }
        let startSize: CGFloat = mark.radius * 2
        let size: CGFloat = startSize + (dotSize - startSize) * drop
        return Circle()
            .fill(Palette.spark)
            .frame(width: size, height: size)
            .position(x: x, y: y)
            .opacity(textFrame == .zero ? 0 : 1)
            .accessibilityHidden(true)
    }

    private func progress(_ t: Double, from a: Double, to b: Double) -> Double { min(max((t - a) / (b - a), 0), 1) }
    private func ease(_ u: Double) -> Double { u < 0.5 ? 4 * u * u * u : 1 - pow(-2 * u + 2, 3) / 2 }
}

private extension View {
    func splashBackground(neuralIdentity: Bool) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
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
