import AppIntents
import LumbreCore
import LumbreDesign
import SwiftUI
import WidgetKit

// Extensión de widgets de Lumbre (paso 55): la chispa de hoy, captura rápida y el control de captura.
// No habla con el servidor: lee el snapshot que deja la app en el App Group al cargar Hoy (`LumbreShared`).

@main
struct LumbreWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodaySparkWidget()
        QuickCaptureWidget()
        if #available(iOS 18, *) {
            CaptureControl()
        }
    }
}

// MARK: - Chispa de hoy

struct TodayEntry: TimelineEntry {
    let date: Date
    let state: TodayWidgetState
    let isEnabled: Bool
    let colorScheme: ColorScheme?
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, state: .empty, isEnabled: true, colorScheme: LumbreShared.widgetColorScheme)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(entry(at: .now))
    }

    /// Una entrada ahora y otras a la hora de la chispa y a medianoche, cuando cambia lo que corresponde mostrar.
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let now = Date.now
        let dates = [now] + TodayWidgetState.refreshDates(after: now, nextSparkAt: LumbreShared.nextSparkAt)
        completion(Timeline(entries: dates.map(entry(at:)), policy: .atEnd))
    }

    private func entry(at date: Date) -> TodayEntry {
        TodayEntry(date: date, state: .current(now: date), isEnabled: FeatureFlag.widgets.isEnabled,
                   colorScheme: LumbreShared.widgetColorScheme)
    }
}

struct TodaySparkWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "today-spark", provider: TodayProvider()) { entry in
            TodaySparkEntryView(entry: entry)
        }
        .configurationDisplayName(LocalizedStringResource("Chispa de hoy", table: "Extensions"))
        .description(LocalizedStringResource("Las dos neuronas que se conectaron hoy y la chispa que salió.", table: "Extensions"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
    }
}

private struct TodaySparkEntryView: View {
    let entry: TodayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        TodaySparkWidgetView(state: entry.state, family: family, isEnabled: entry.isEnabled)
            .widgetBackground()
            .themed(entry.colorScheme)
    }
}

// MARK: - Captura rápida

struct CaptureEntry: TimelineEntry {
    let date: Date
    let isEnabled: Bool
    let colorScheme: ColorScheme?
}

struct CaptureProvider: TimelineProvider {
    func placeholder(in context: Context) -> CaptureEntry {
        CaptureEntry(date: .now, isEnabled: true, colorScheme: LumbreShared.widgetColorScheme)
    }

    func getSnapshot(in context: Context, completion: @escaping (CaptureEntry) -> Void) {
        completion(CaptureEntry(date: .now, isEnabled: FeatureFlag.widgets.isEnabled, colorScheme: LumbreShared.widgetColorScheme))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CaptureEntry>) -> Void) {
        getSnapshot(in: context) { completion(Timeline(entries: [$0], policy: .never)) }
    }
}

struct QuickCaptureWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "quick-capture", provider: CaptureProvider()) { entry in
            QuickCaptureEntryView(entry: entry)
        }
        .configurationDisplayName(LocalizedStringResource("Guardar una idea", table: "Extensions"))
        .description(LocalizedStringResource("Abre Capturar para sumar una neurona a tu Red.", table: "Extensions"))
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

private struct QuickCaptureEntryView: View {
    let entry: CaptureEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        QuickCaptureWidgetView(family: family, isEnabled: entry.isEnabled)
            .widgetBackground()
            .themed(entry.colorScheme)
    }
}

// MARK: - Control (iOS 18): Centro de control, pantalla bloqueada y botón de acción

@available(iOS 18, *)
struct CaptureControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.matiasrodriguezc.lumbre.capture-control") {
            ControlWidgetButton(action: OpenCaptureIntent()) {
                Label(extensionsText("Capturar en Lumbre"), systemImage: "plus")
            }
        }
        .displayName(LocalizedStringResource("Capturar en Lumbre", table: "Extensions"))
        .description(LocalizedStringResource("Abre Lumbre listo para guardar una idea.", table: "Extensions"))
    }
}

// MARK: - Apariencia

private extension View {
    /// Fondo `bg` del tema; en la pantalla bloqueada el sistema pone el suyo.
    func widgetBackground() -> some View {
        containerBackground(for: .widget) { Palette.bg }
    }

    /// El tema de la app (gris por defecto), no el del sistema.
    @ViewBuilder
    func themed(_ scheme: ColorScheme?) -> some View {
        if let scheme {
            environment(\.colorScheme, scheme)
        } else {
            self
        }
    }
}
