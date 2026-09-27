import Foundation

/// Uno de los 20–25 dominios de la lista cerrada. El nombre llega del servidor en el idioma del usuario.
public struct Domain: Hashable, Sendable, Identifiable {
    public let slug: String
    public let name: String
    /// SF Symbol del dominio.
    public let symbol: String

    public var id: String { slug }

    public init(slug: String, name: String, symbol: String) {
        self.slug = slug
        self.name = name
        self.symbol = symbol
    }
}

/// Mismos valores que `concepts.source_type` en el esquema.
public enum SourceType: String, Sendable, CaseIterable {
    case text, voice, selection, screenshot, scan, link, image, pdf, audio
}

public struct Concept: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let domain: Domain
    public let title: String
    public let thesis: String
    public let sourceType: SourceType
    public let sourceTitle: String?
    public let createdAt: Date

    public init(id: UUID = UUID(), domain: Domain, title: String, thesis: String, sourceType: SourceType, sourceTitle: String? = nil, createdAt: Date) {
        self.id = id
        self.domain = domain
        self.title = title
        self.thesis = thesis
        self.sourceType = sourceType
        self.sourceTitle = sourceTitle
        self.createdAt = createdAt
    }
}

/// Mismos valores que `sparks.mode` en el esquema.
public enum SparkMode: String, Sendable {
    case daily, extra, pick, problem
}

/// Mismos valores que `sparks.status` en el esquema.
public enum SparkStatus: String, Sendable {
    case pending, revealed, saved, discarded
}

/// Mismos valores que `sparks.feedback` en el esquema.
public enum SparkFeedback: String, Sendable, CaseIterable {
    case obvious
    case irrelevant
    case alreadyHad = "already_had"
}

public struct Spark: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let conceptA: Concept
    public let conceptB: Concept
    public let title: String
    public let body: String
    public let mode: SparkMode
    public var status: SparkStatus
    /// Nombre del proyecto donde quedó guardada, si se guardó en uno.
    public var projectName: String?
    public let createdAt: Date

    public init(id: UUID = UUID(), conceptA: Concept, conceptB: Concept, title: String, body: String, mode: SparkMode = .daily, status: SparkStatus = .revealed, projectName: String? = nil, createdAt: Date) {
        self.id = id
        self.conceptA = conceptA
        self.conceptB = conceptB
        self.title = title
        self.body = body
        self.mode = mode
        self.status = status
        self.projectName = projectName
        self.createdAt = createdAt
    }
}

/// Chispas disponibles hoy.
public struct SparkQuota: Hashable, Sendable {
    public let available: Int
    public let total: Int
    /// Próxima recarga, en la hora elegida por el usuario.
    public let refillsAt: Date
    /// Conceptos que faltan guardar hoy para ganar una chispa extra.
    public let conceptsUntilExtra: Int

    public init(available: Int, total: Int, refillsAt: Date, conceptsUntilExtra: Int) {
        self.available = available
        self.total = total
        self.refillsAt = refillsAt
        self.conceptsUntilExtra = conceptsUntilExtra
    }
}
