import Foundation
import OSLog
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Lo que comparten la app, el widget y la Share Extension a través del App Group.
/// Mientras el target no tenga el App Group en sus entitlements, todo queda en el contenedor de la app.
public enum LumbreShared {
    public static let appGroupID = "group.com.matiasrodriguezc.lumbre"

    /// Grupo de Keychain donde la app guarda la sesión para que la Share Extension y los App Intents la usen.
    /// Es el mismo App Group: iOS acepta un App Group como access group, así no hace falta otra capability.
    public static let keychainAccessGroup = appGroupID

    /// Carpeta compartida: la del App Group si existe; si no, Application Support de la app.
    public static var containerURL: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? URL.applicationSupportDirectory.appending(path: "Lumbre", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    /// Preferencias compartidas (App Group). Sin el App Group, las del proceso.
    public static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    /// Store de SwiftData de la caché offline.
    public static var cacheStoreURL: URL { containerURL.appending(path: "Cache.store") }

    private static var todaySnapshotURL: URL { containerURL.appending(path: "today.json") }

    private enum Key {
        static let nextSparkAt = "shared.nextSparkAt"
        static let noSparkOn = "shared.noSparkOn"
        static let needsMaterial = "shared.needsMaterial"
        static let categories = "shared.categories"
        static let backend = "shared.backend"
        static let theme = "shared.theme"
        static let flags = "shared.flags"
        static let lastCategory = "shared.lastCategory"
    }

    // MARK: - Chispa de hoy para el widget

    /// Lo mínimo que muestra el widget de la chispa de hoy.
    public struct TodaySnapshot: Codable, Hashable, Sendable {
        public struct ConceptSummary: Codable, Hashable, Sendable {
            public let title: String
            public let category: String?
            /// SF Symbol de la categoría (el del dominio, o una etiqueta).
            public let symbol: String?

            public init(title: String, category: String?, symbol: String? = nil) {
                self.title = title
                self.category = category
                self.symbol = symbol
            }
        }

        public let sparkID: UUID
        public let title: String
        public let body: String
        public let conceptA: ConceptSummary
        public let conceptB: ConceptSummary
        public let status: SparkStatus
        /// Día de la chispa (o cuándo se creó, si no es diaria).
        public let date: Date

        public init(sparkID: UUID, title: String, body: String, conceptA: ConceptSummary, conceptB: ConceptSummary, status: SparkStatus, date: Date) {
            self.sparkID = sparkID
            self.title = title
            self.body = body
            self.conceptA = conceptA
            self.conceptB = conceptB
            self.status = status
            self.date = date
        }

        public init(spark: Spark) {
            self.init(
                sparkID: spark.id,
                title: spark.title,
                body: spark.body,
                conceptA: ConceptSummary(title: spark.conceptA.title, category: spark.conceptA.category?.name, symbol: spark.conceptA.category?.symbol),
                conceptB: ConceptSummary(title: spark.conceptB.title, category: spark.conceptB.category?.name, symbol: spark.conceptB.category?.symbol),
                status: spark.status,
                date: spark.scheduledFor ?? spark.createdAt
            )
        }

        /// Todavía no se reveló: el widget muestra las dos neuronas sin la chispa, para no arruinar el reveal.
        public var isPending: Bool { status == .pending }

        /// Si es la chispa del día de `now` (el widget no muestra la de ayer como si fuera de hoy).
        public func isCurrent(at now: Date = .now, calendar: Calendar = .current) -> Bool {
            calendar.isDate(date, inSameDayAs: now)
        }
    }

    public static func writeTodaySnapshot(_ snapshot: TodaySnapshot) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: todaySnapshotURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            logger.error("No se pudo guardar la chispa para el widget: \(String(describing: type(of: error)), privacy: .public)")
        }
        reloadWidgets()
    }

    public static func readTodaySnapshot() -> TodaySnapshot? {
        guard let data = try? Data(contentsOf: todaySnapshotURL) else { return nil }
        return try? JSONDecoder().decode(TodaySnapshot.self, from: data)
    }

    /// Al cerrar sesión o si hoy no hay chispa.
    public static func clearTodaySnapshot() {
        try? FileManager.default.removeItem(at: todaySnapshotURL)
        reloadWidgets()
    }

    /// Guarda lo que devolvió Hoy: la chispa del día (o nada) y cuándo llega la próxima.
    public static func writeToday(_ state: TodayState) {
        defaults.set(state.quota.refillsAt, forKey: Key.nextSparkAt)
        // Sin chispa hoy, el widget no promete una: dice que faltan neuronas o que hoy no salió.
        defaults.set(state.spark == nil ? Date.now : nil, forKey: Key.noSparkOn)
        defaults.set(state.spark == nil && state.hasTooFewConcepts, forKey: Key.needsMaterial)
        if let spark = state.spark {
            writeTodaySnapshot(.init(spark: spark))
        } else {
            clearTodaySnapshot()
        }
    }

    /// El día en que Hoy cargó sin chispa (nil si la hubo).
    public static var noSparkOn: Date? {
        defaults.object(forKey: Key.noSparkOn) as? Date
    }

    /// En la última carga de Hoy faltaban neuronas para conectar.
    public static var needsMaterial: Bool {
        defaults.bool(forKey: Key.needsMaterial)
    }

    /// Próxima chispa diaria (la hora elegida por el usuario), según la última carga de Hoy.
    public static var nextSparkAt: Date? {
        defaults.object(forKey: Key.nextSparkAt) as? Date
    }

    // MARK: - Categorías para la Share Extension y los App Intents

    /// Nombres de las categorías del usuario, en el orden en que las devolvió el servidor.
    public static var categoryNames: [String] {
        get { defaults.stringArray(forKey: Key.categories) ?? [] }
        set { defaults.set(newValue, forKey: Key.categories) }
    }

    /// Última categoría elegida desde la Share Extension o un atajo.
    public static var lastCategory: String? {
        get { defaults.string(forKey: Key.lastCategory) }
        set { defaults.set(newValue, forKey: Key.lastCategory) }
    }

    // MARK: - Backend

    /// A qué backend habla la app, para que las extensiones manden al mismo. La clave publicable es pública por diseño.
    public struct Backend: Codable, Hashable, Sendable {
        public let url: URL
        public let publishableKey: String

        public init(url: URL, publishableKey: String) {
            self.url = url
            self.publishableKey = publishableKey
        }
    }

    /// nil con los datos de prueba (`-mock`): las extensiones solo encolan.
    public static var backend: Backend? {
        get {
            guard let data = defaults.data(forKey: Key.backend) else { return nil }
            return try? JSONDecoder().decode(Backend.self, from: data)
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Key.backend)
            } else {
                defaults.removeObject(forKey: Key.backend)
            }
        }
    }

    // MARK: - Tema y flags

    /// Tema elegido en Perfil (`light`, `dark` o `system`), para que el widget se vea igual que la app.
    public static var theme: String? {
        get { defaults.string(forKey: Key.theme) }
        set {
            guard newValue != theme else { return }
            defaults.set(newValue, forKey: Key.theme)
            reloadWidgets()
        }
    }

    /// Últimos valores remotos de los feature flags, para las extensiones (que no hablan con PostHog).
    static var flags: [String: Bool] {
        get { defaults.dictionary(forKey: Key.flags) as? [String: Bool] ?? [:] }
        set { defaults.set(newValue, forKey: Key.flags) }
    }

    // MARK: - Sesión

    /// Al cerrar sesión o borrar la cuenta: nada del usuario anterior queda a la vista de las extensiones.
    public static func clearUserData() {
        clearTodaySnapshot()
        defaults.removeObject(forKey: Key.nextSparkAt)
        defaults.removeObject(forKey: Key.noSparkOn)
        defaults.removeObject(forKey: Key.needsMaterial)
        defaults.removeObject(forKey: Key.categories)
        defaults.removeObject(forKey: Key.lastCategory)
    }

    /// Pide a WidgetKit que vuelva a leer el snapshot.
    public static func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    static let logger = Logger(subsystem: "com.matiasrodriguezc.lumbre", category: "core")
}
