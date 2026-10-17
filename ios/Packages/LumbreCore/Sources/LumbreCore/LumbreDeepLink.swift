import Foundation

/// Links profundos `lumbre://` que usan el widget, los App Intents y la Share Extension.
///
/// - `lumbre://today`: Hoy.
/// - `lumbre://spark/<id>`: esa chispa (si es la de hoy y no se reveló, Hoy hace el reveal).
/// - `lumbre://capture?entry=widget`: la sheet de Capturar; `entry` va al evento `capture_opened`.
public enum LumbreDeepLink: Hashable, Sendable {
    case today
    case spark(UUID)
    case capture(entry: String)

    public static let scheme = "lumbre"

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
            self = .spark(id)
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
        case .spark(let id):
            components.host = "spark"
            components.path = "/" + id.uuidString.lowercased()
        case .capture(let entry):
            components.host = "capture"
            components.queryItems = [URLQueryItem(name: "entry", value: entry)]
        }
        return components.url!
    }

    /// Solo letras, números y guiones bajos (va tal cual a analytics).
    private static func cleanEntry(_ entry: String?) -> String {
        guard let entry, !entry.isEmpty, entry.count <= 32,
              entry.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") })
        else { return defaultCaptureEntry }
        return entry
    }
}
