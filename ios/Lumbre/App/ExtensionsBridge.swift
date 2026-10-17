import LumbreCore
import LumbreDesign
import SwiftUI

/// Lo que une la app con el widget, la Share Extension y los App Intents (pasos 49 y 55):
///
/// - Abre los links `lumbre://` (widget, atajos) y los que dejan los App Intents en `DeepLinkInbox`.
///   Los del widget mandan `widget_tapped`.
/// - Vacía la cola offline al abrir la app: ahí esperan las capturas de la Share Extension y de Siri.
/// - Abre la vista previa de importar con las notas que dejó el atajo de Apple Notes (`ImportNotesIntent`).
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
            .onReceive(NotificationCenter.default.publisher(for: ImportInbox.didReceive)) { _ in
                consumeImportInbox()
            }
            .onChange(of: theme, initial: true) { _, theme in
                LumbreShared.theme = theme.rawValue
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                consumeInbox()
                consumeImportInbox()
                if FeatureFlag.offlineQueue.isEnabled {
                    Task { await CaptureQueue.shared.startMonitoring(api: api) }
                }
            }
            .task {
                consumeInbox()
                consumeImportInbox()
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
                if let path = UserDefaults.standard.string(forKey: "importPath") {
                    openDebugImport(path)
                }
                if let count = UserDefaults.standard.string(forKey: "checkImportIntent").flatMap(Int.init) {
                    Task { await runDebugImportIntent(count: count) }
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
        case "import": appModel.presentImport()
        case "vault": appModel.selectedTab = .vault
        case "projects": appModel.selectedTab = .projects
        case "profile": appModel.selectedTab = .profile
        // Hoy con la chispa del día ya encendida (el aviso de pocos pares y los temas puente van debajo).
        case "revealed":
            Task {
                if let id = try? await api.today().spark?.id { try? await api.revealSpark(id: id) }
                appModel.dataChanged()
            }
        default: break
        }
    }

    /// `-importPath <carpeta o archivo .md>`: abre la vista previa de importar sin pasar por Archivos (el selector
    /// del simulador no se puede manejar desde la terminal). Una carpeta se lee como una bóveda de Obsidian.
    private func openDebugImport(_ path: String) {
        let url = URL(fileURLWithPath: path)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else { return }
        let scan = isDirectory.boolValue ? NoteImport.readFolder(url) : NoteImport.readFiles([url])
        appModel.presentImport(notes: scan.notes, origin: isDirectory.boolValue ? .obsidianFolder : .markdownFiles)
    }

    /// `-checkImportIntent <n>`: corre `ImportNotesIntent` con n notas de prueba, como si llegaran del atajo.
    private func runDebugImportIntent(count: Int) async {
        var intent = ImportNotesIntent()
        intent.notes = (1...max(1, count)).map { index in
            "Nota de Apple Notes \(index)\nEl cuerpo de la nota número \(index), con una idea que vale la pena guardar."
        }
        intent.category = "Apple Notes"
        _ = try? await intent.perform()
    }
    #endif

    /// Las notas que mandó el atajo de Apple Notes: abre la vista previa con ellas.
    private func consumeImportInbox() {
        guard FeatureFlag.importNotes.isEnabled else { return }
        let notes = ImportInbox.take()
        guard !notes.isEmpty else { return }
        appModel.presentImport(notes: notes, origin: .appleNotes)
    }

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
