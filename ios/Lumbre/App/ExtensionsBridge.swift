import LumbreCore
import LumbreDesign
import SwiftUI

/// Lo que une la app con el widget, la Share Extension y los App Intents (pasos 49 y 55):
///
/// - Abre los links `lumbre://` (widget, atajos) y los que dejan los App Intents en `DeepLinkInbox`.
///   Los del widget mandan `widget_tapped`.
/// - Vacía la cola offline al abrir la app: ahí esperan las capturas de la Share Extension y de Siri.
/// - Copia el tema al App Group para que el widget se vea igual que la app.
///
/// El snapshot de la chispa y las categorías los escribe `CachedLumbreAPI` al cargar Hoy y Capturar.
struct ExtensionsBridge: ViewModifier {
    @Environment(AppModel.self) private var appModel
    @Environment(\.api) private var api
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("theme") private var theme: ThemePreference = .light
    /// Solo Debug: la tarjeta para compartir que abre `-open share`.
    @State private var debugShareSpark: Spark?

    func body(content: Content) -> some View {
        content
            .onOpenURL { url in
                guard let link = LumbreDeepLink(url: url) else { return }
                if let tap = LumbreDeepLink.widgetTap(in: url) { Analytics.track(tap.event) }
                open(link)
            }
            .onReceive(NotificationCenter.default.publisher(for: DeepLinkInbox.didReceive)) { _ in
                consumeInbox()
            }
            .onChange(of: theme, initial: true) { _, theme in
                LumbreShared.theme = theme.rawValue
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                consumeInbox()
                if FeatureFlag.offlineQueue.isEnabled {
                    Task { await CaptureQueue.shared.startMonitoring(api: api) }
                }
            }
            .task {
                consumeInbox()
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-renderWidgetSnapshots") {
                    WidgetGallery.render()
                }
                if ProcessInfo.processInfo.arguments.contains("-checkExternalCapture") {
                    Task { await ExternalCaptureCheck.run() }
                }
                if let screen = UserDefaults.standard.string(forKey: "open") {
                    openDebugScreen(screen)
                }
                #endif
                await watchQueue()
            }
            #if DEBUG
            .sheet(item: $debugShareSpark) { ShareCardSheet(spark: $0) }
            #endif
    }

    #if DEBUG
    /// `-open <pantalla>` con `-mock` o `-mockPro`: abre una pantalla con los datos de prueba, para revisarla
    /// (por ejemplo con texto grande) sin tocar el simulador.
    private func openDebugScreen(_ screen: String) {
        let spark = MockData.recentSparks[0]
        switch screen {
        case "spark": appModel.open(.spark(spark.id))
        case "planner": appModel.open(.planner(spark.id))
        case "concept": appModel.open(.concept(MockData.concepts[2].id))
        case "draft": appModel.open(.concept(MockData.concepts[7].id))
        case "paywall": appModel.open(.paywall(trigger: "settings"))
        case "share": debugShareSpark = spark
        case "consent": appModel.presentAIConsent()
        default: break
        }
    }
    #endif

    private func open(_ link: LumbreDeepLink) {
        switch link {
        case .today: appModel.open(.today)
        case .spark(let id, let entry): appModel.open(.spark(id, entry: entry ?? "app"))
        case .capture(let entry): appModel.open(.capture(entry: entry))
        }
    }

    private func consumeInbox() {
        if let link = DeepLinkInbox.take() { open(link) }
    }

    /// Lo que mandó la cola (por ejemplo, lo compartido desde Safari) aparece en Hoy y en la Red sin recargar a mano.
    private func watchQueue() async {
        guard FeatureFlag.offlineQueue.isEnabled else { return }
        await CaptureQueue.shared.startMonitoring(api: api)
        for await update in await CaptureQueue.shared.updates() {
            if case .flushed = update { appModel.dataChanged() }
        }
    }
}

extension View {
    /// Engancha la app con el widget, la Share Extension y los App Intents. Va una vez, en la raíz.
    func extensionsBridge() -> some View {
        modifier(ExtensionsBridge())
    }
}
