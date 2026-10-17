import Foundation

/// Links profundos `lumbre://` que usan el widget, los App Intents y la Share Extension.
///
/// - `lumbre://today`: Hoy.
/// - `lumbre://spark/<id>?entry=widget`: esa chispa (si es la de hoy y no se reveló, Hoy hace el reveal).
///   `entry` va a `spark_revealed`; sin él, la app cuenta `app`.
/// - `lumbre://capture?entry=widget`: la sheet de Capturar; `entry` va al evento `capture_opened`.
///
/// Los del widget suman `size` (`?entry=widget&size=small`) para `widget_tapped` (`widgetURL(size:)`, `widgetTap(in:)`).
public enum LumbreDeepLink: Hashable, Sendable {
    case today
    case spark(UUID, entry: String? = nil)
    case capture(entry: String)

    public static let scheme = "lumbre"

    /// Valores de `spark_revealed.entry` que puede traer un link (docs/analytics.md).
    public static let sparkEntries: Set<String> = ["app", "push", "widget"]

    /// `entry` de `capture_opened` cuando el link no trae uno.
    public static let defaultCaptureEntry = "deeplink"

    public init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme else { return nil }
        // `lumbre://spark/<id>` llega con host "spark"; se acepta también `lumbre:///spark/<id>`.
        var parts = url.pathComponents.filter { $0 != "/" }
        if let host = url.host(), !host.isEmpty { parts.insert(host, at: 0) }
        guard let first = parts.first?.lowercased() else { return nil }
        switch first {
        case "today", "hoy":
            self = .today
        case "spark":
            guard parts.count > 1, let id = UUID(uuidString: parts[1]) else { self = .today; return }
            let entry = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "entry" }?.value
            self = .spark(id, entry: entry.flatMap { Self.sparkEntries.contains($0) ? $0 : nil })
        case "capture", "capturar":
            let entry = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "entry" }?.value
            self = .capture(entry: Self.cleanEntry(entry))
        default:
            return nil
        }
    }

    public var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        switch self {
        case .today:
            components.host = "today"
        case .spark(let id, let entry):
            components.host = "spark"
            components.path = "/" + id.uuidString.lowercased()
            if let entry { components.queryItems = [URLQueryItem(name: "entry", value: entry)] }
        case .capture(let entry):
            components.host = "capture"
            components.queryItems = [URLQueryItem(name: "entry", value: entry)]
        }
        return components.url!
    }

    // MARK: Widget

    /// Valores de `widget_tapped.size` en iOS (design/compartir/README.md §5).
    public static let widgetSizes: Set<String> = ["small", "medium", "large", "circular", "rectangular", "inline"]

    /// Lo que va a `widget_tapped`.
    public struct WidgetTap: Hashable, Sendable {
        /// `open_spark` o `capture`.
        public let action: String
        public let size: String

        public var event: AnalyticsEvent { .widgetTapped(action: action, size: size) }
    }

    /// El link como lo abre el widget: con `entry=widget` y el tamaño, para que la app mande `widget_tapped`.
    public func widgetURL(size: String) -> URL {
        let link: LumbreDeepLink = switch self {
        case .today: .today
        case .spark(let id, _): .spark(id, entry: "widget")
        case .capture: .capture(entry: "widget")
        }
        var components = URLComponents(url: link.url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "entry", value: "widget"), URLQueryItem(name: "size", value: size)]
        return components.url!
    }

    /// `widget_tapped` de un link que abrió el widget; nil si vino de otro lado o el tamaño no es conocido.
    /// Hoy (`lumbre://today`, el widget sin chispa) no cuenta: `action` solo acepta `open_spark` y `capture`
    /// (docs/analytics.md).
    public static func widgetTap(in url: URL) -> WidgetTap? {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard items.first(where: { $0.name == "entry" })?.value == "widget",
              let size = items.first(where: { $0.name == "size" })?.value, widgetSizes.contains(size)
        else { return nil }
        switch LumbreDeepLink(url: url) {
        case .spark: return WidgetTap(action: "open_spark", size: size)
        case .capture: return WidgetTap(action: "capture", size: size)
        case .today, nil: return nil
        }
    }

    /// Solo letras, números y guiones bajos (va tal cual a analytics).
    private static func cleanEntry(_ entry: String?) -> String {
        guard let entry, !entry.isEmpty, entry.count <= 32,
              entry.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") })
        else { return defaultCaptureEntry }
        return entry
    }
}
