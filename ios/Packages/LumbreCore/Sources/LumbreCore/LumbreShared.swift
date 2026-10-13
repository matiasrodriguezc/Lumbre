import Foundation
import OSLog

/// Lo que comparten la app, el widget y la Share Extension a través del App Group.
/// Mientras el target no tenga el App Group en sus entitlements, todo queda en el contenedor de la app.
public enum LumbreShared {
    public static let appGroupID = "group.com.matiasrodriguezc.lumbre"

    /// Carpeta compartida: la del App Group si existe; si no, Application Support de la app.
    public static var containerURL: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? URL.applicationSupportDirectory.appending(path: "Lumbre", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    /// Store de SwiftData de la caché offline.
    public static var cacheStoreURL: URL { containerURL.appending(path: "Cache.store") }

    private static var todaySnapshotURL: URL { containerURL.appending(path: "today.json") }

    // MARK: - Chispa de hoy para el widget

    /// Lo mínimo que muestra el widget de la chispa de hoy.
    public struct TodaySnapshot: Codable, Hashable, Sendable {
        public struct ConceptSummary: Codable, Hashable, Sendable {
            public let title: String
            public let category: String?

            public init(title: String, category: String?) {
                self.title = title
                self.category = category
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
                conceptA: ConceptSummary(title: spark.conceptA.title, category: spark.conceptA.category?.name),
                conceptB: ConceptSummary(title: spark.conceptB.title, category: spark.conceptB.category?.name),
                status: spark.status,
                date: spark.scheduledFor ?? spark.createdAt
            )
        }
    }

    public static func writeTodaySnapshot(_ snapshot: TodaySnapshot) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: todaySnapshotURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            logger.error("No se pudo guardar la chispa para el widget: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    public static func readTodaySnapshot() -> TodaySnapshot? {
        guard let data = try? Data(contentsOf: todaySnapshotURL) else { return nil }
        return try? JSONDecoder().decode(TodaySnapshot.self, from: data)
    }

    /// Al cerrar sesión o si hoy no hay chispa.
    public static func clearTodaySnapshot() {
        try? FileManager.default.removeItem(at: todaySnapshotURL)
    }

    static let logger = Logger(subsystem: "com.matiasrodriguezc.lumbre", category: "core")
}
