#if DEBUG
import LumbreCore
import LumbreDesign
import OSLog
import SwiftUI
import WidgetKit

/// Solo Debug: renderiza los widgets a PNG para revisarlos sin agregarlos a mano a la pantalla de inicio.
/// La app lo corre con `-renderWidgetSnapshots` y deja las imágenes en `<App Group>/WidgetSnapshots/`.
@MainActor
enum WidgetGallery {
    static func render() {
        let folder = LumbreShared.containerURL.appending(path: "WidgetSnapshots", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: folder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let snapshot = LumbreShared.TodaySnapshot(
            sparkID: UUID(),
            title: "Un podcast que se recorre como una ruina",
            body: "Ordená los episodios como capas de una excavación: cada uno destapa algo del anterior y el oyente arma el mapa.",
            conceptA: .init(title: "Estratigrafía", category: "Historia"),
            conceptB: .init(title: "Episodios encadenados", category: "Podcast"),
            status: .revealed, date: .now
        )
        let pending = LumbreShared.TodaySnapshot(
            sparkID: snapshot.sparkID, title: snapshot.title, body: snapshot.body,
            conceptA: snapshot.conceptA, conceptB: snapshot.conceptB, status: .pending, date: .now
        )
        let next = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now.addingTimeInterval(86_400))!
        let states: [(String, TodayWidgetState)] = [
            ("spark", .spark(snapshot)), ("pending", .pending(pending)), ("waiting", .waiting(next)), ("empty", .empty),
        ]
        let families: [(String, WidgetFamily, CGSize)] = [
            ("small", .systemSmall, CGSize(width: 170, height: 170)),
            ("medium", .systemMedium, CGSize(width: 364, height: 170)),
            ("large", .systemLarge, CGSize(width: 364, height: 382)),
            ("rect", .accessoryRectangular, CGSize(width: 172, height: 76)),
        ]
        for scheme in [ColorScheme.light, .dark] {
            for (stateName, state) in states {
                for (familyName, family, size) in families {
                    save(TodaySparkWidgetView(state: state, family: family), family: family, size: size, scheme: scheme,
                         to: folder.appending(path: "today-\(familyName)-\(stateName)-\(scheme == .light ? "gris" : "grafito").png"))
                }
            }
            save(QuickCaptureWidgetView(family: .systemSmall), family: .systemSmall, size: CGSize(width: 170, height: 170), scheme: scheme,
                 to: folder.appending(path: "capture-small-\(scheme == .light ? "gris" : "grafito").png"))
        }
        Logger(subsystem: "com.matiasrodriguezc.lumbre", category: "widgets").notice("Widgets renderizados en \(folder.path(), privacy: .public)")
    }

    private static func save(_ view: some View, family: WidgetFamily, size: CGSize, scheme: ColorScheme, to url: URL) {
        let isAccessory = [.accessoryRectangular, .accessoryInline, .accessoryCircular].contains(family)
        let framed = view
            .padding(isAccessory ? 4 : 16)
            .frame(width: size.width, height: size.height)
            .background(isAccessory ? Color.black.opacity(0.85) : Palette.bg)
            .foregroundStyle(isAccessory ? Color.white : Palette.ink)
            .clipShape(RoundedRectangle(cornerRadius: isAccessory ? 12 : 22, style: .continuous))
            .padding(8)
            .background(Color(white: 0.5))
            .environment(\.colorScheme, scheme)
        let renderer = ImageRenderer(content: framed)
        renderer.scale = 3
        if let data = renderer.uiImage?.pngData() {
            try? data.write(to: url)
        }
    }
}

/// Solo Debug: `-checkExternalCapture` guarda una neurona de prueba por el mismo camino que la Share Extension
/// y Siri (sesión prestada del Keychain compartido, o la cola) y anota en el log cómo salió. Usar con el backend local.
enum ExternalCaptureCheck {
    static func run() async {
        let logger = Logger(subsystem: "com.matiasrodriguezc.lumbre", category: "extensions-check")
        // Espera a que la app termine de entrar y guarde la sesión.
        try? await Task.sleep(for: .seconds(4))
        if let backend = LumbreShared.backend {
            let borrowed = SupabaseLumbreAPI.borrowingSharedSession(url: backend.url, publishableKey: backend.publishableKey)
            do {
                let profile = try await borrowed.profile()
                logger.notice("Sesión prestada: perfil leído (invitado: \(profile.isGuest, privacy: .public))")
            } catch {
                logger.error("Sesión prestada: \(String(describing: error), privacy: .public)")
            }
        } else {
            logger.notice("Sin backend compartido")
        }
        let request = CaptureRequest(thesis: "Prueba de captura externa", category: "Pruebas", source: .text)
        do {
            let outcome = try await ExternalCapture.submit(request)
            logger.notice("Captura externa: \(String(describing: outcome), privacy: .public)")
        } catch {
            logger.error("Captura externa falló: \(String(describing: type(of: error)), privacy: .public)")
        }
    }
}
#endif
