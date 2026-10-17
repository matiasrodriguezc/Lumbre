import LumbreCore
import LumbreDesign
import SwiftUI

/// Lo que une la app con el widget, la Share Extension y los App Intents (pasos 49 y 55):
///
/// - Abre los links `lumbre://` (widget, atajos) y los que dejan los App Intents en `DeepLinkInbox`.
/// - Vacía la cola offline al abrir la app: ahí esperan las capturas de la Share Extension y de Siri.
/// - Copia el tema al App Group para que el widget se vea igual que la app.
///
/// El snapshot de la chispa y las categorías los escribe `CachedLumbreAPI` al cargar Hoy y Capturar.
struct ExtensionsBridge: ViewModifier {
    @Environment(AppModel.self) private var appModel
    @Environment(\.api) private var api
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("theme") private var theme: ThemePreference = .light

    func body(content: Content) -> some View {
        content
            .onOpenURL { url in
                if let link = LumbreDeepLink(url: url) { open(link) }
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
                #endif
                await watchQueue()
            }
    }

    private func open(_ link: LumbreDeepLink) {
        switch link {
        case .today: appModel.open(.today)
        case .spark(let id): appModel.open(.spark(id))
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
