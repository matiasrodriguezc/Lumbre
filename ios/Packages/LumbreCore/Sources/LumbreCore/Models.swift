import Foundation

// MARK: - Perfil

/// Mismos slugs que `profiles.creative_profiles` y `docs/analytics.md`.
public enum CreativeProfile: String, Sendable, CaseIterable, Identifiable, Codable {
    case software, content, business, design, curiosity
    public var id: String { rawValue }
}

/// Plan efectivo: `guest` si la sesión es anónima; si no, el de `profiles.plan`.
public enum Plan: String, Sendable, Codable {
    case guest, free, pro
}

/// Hora local de la chispa diaria (`profiles.spark_hour`).
public struct SparkTime: Hashable, Sendable, Codable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int = 0) {
        self.hour = hour
        self.minute = minute
    }

    /// "08:00:00", como lo guarda Postgres.
    public init?(postgres: String) {
        let parts = postgres.split(separator: ":").compactMap { Int($0) }
        guard let hour = parts.first, (0..<24).contains(hour) else { return nil }
        self.init(hour: hour, minute: parts.dropFirst().first ?? 0)
    }

    public var postgres: String { String(format: "%02d:%02d:00", hour, minute) }

    public static let `default` = SparkTime(hour: 8)
}

public struct Profile: Hashable, Sendable {
    public var creativeProfiles: [CreativeProfile]
    public var sparkTime: SparkTime
    public var timezone: String
    public var locale: String
    public let plan: Plan
    /// Email de la cuenta; nil para invitados.
    public let email: String?
    /// Terminó el onboarding (`profiles.onboarded_at`).
    public var isOnboarded: Bool

    public init(creativeProfiles: [CreativeProfile], sparkTime: SparkTime, timezone: String, locale: String, plan: Plan, email: String?, isOnboarded: Bool) {
        self.creativeProfiles = creativeProfiles
        self.sparkTime = sparkTime
        self.timezone = timezone
        self.locale = locale
        self.plan = plan
        self.email = email
        self.isOnboarded = isOnboarded
    }

    public var isGuest: Bool { plan == .guest }
    public var isPro: Bool { plan == .pro }
}

/// Cambios del perfil que puede hacer el usuario. Los nil no se tocan.
public struct ProfileUpdate: Sendable, Equatable {
    public var creativeProfiles: [CreativeProfile]?
    public var sparkTime: SparkTime?
    public var timezone: String?
    public var locale: String?
    /// true marca el onboarding como terminado.
    public var completeOnboarding: Bool

    public init(creativeProfiles: [CreativeProfile]? = nil, sparkTime: SparkTime? = nil, timezone: String? = nil, locale: String? = nil, completeOnboarding: Bool = false) {
        self.creativeProfiles = creativeProfiles
        self.sparkTime = sparkTime
        self.timezone = timezone
        self.locale = locale
        self.completeOnboarding = completeOnboarding
    }
}

/// Mismos valores que `plan_limits.kind`.
public enum CreditKind: String, Sendable, Codable {
    case capture, distill
    case sparkExtra = "spark_extra"
    case planner
    case plannerDeep = "planner_deep"
    case projects
    /// Notas importadas (paso 89): 50 en total en free, un tope técnico por día en Pro.
    case importNotes = "import"
}

/// Un cupo del usuario, como lo devuelve `credit_status()`.
public struct Credit: Hashable, Sendable {
    public let kind: CreditKind
    /// "day", "month" o "total".
    public let period: String
    public let max: Int
    public let remaining: Int

    public init(kind: CreditKind, period: String, max: Int, remaining: Int) {
        self.kind = kind
        self.period = period
        self.max = max
        self.remaining = remaining
    }
}

// MARK: - Bóveda

/// Uno de los 25 dominios de la lista cerrada. El nombre llega del servidor en el idioma del usuario.
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

/// Categoría propia del usuario. Se crea al guardar un concepto; por debajo puede tener un dominio.
public struct Category: Hashable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    /// Dominio de la lista cerrada, para el emparejamiento. Null hasta que se clasifica.
    public let domain: Domain?

    public init(id: UUID = UUID(), name: String, domain: Domain? = nil) {
        self.id = id
        self.name = name
        self.domain = domain
    }

    /// Ícono: el del dominio si ya tiene uno; si no, una etiqueta.
    public var symbol: String { domain?.symbol ?? "tag" }
}

/// Mismos valores que `concepts.source_type` en el esquema.
public enum SourceType: String, Sendable, CaseIterable, Codable {
    case text, voice, selection, screenshot, scan, link, image, pdf, audio
    /// La neurona nació de una chispa guardada (flag `spark_neuron`).
    case spark
}

/// Mismos valores que `concepts.status`: un borrador es una conceptualización de confianza media que falta confirmar.
public enum ConceptStatus: String, Sendable, Codable {
    case draft, ready
}

public enum Confidence: String, Sendable, Codable {
    case high, medium, low
}

public struct Concept: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var category: Category?
    public var title: String
    public var thesis: String
    /// El mecanismo de fondo. Solo si se conceptualizó.
    public var principle: String?
    public var status: ConceptStatus
    public let distilled: Bool
    public let confidence: Confidence?
    public let sourceType: SourceType
    public let sourceURL: URL?
    public let sourceTitle: String?
    /// Fragmento subrayado (≤ 500 caracteres).
    public let excerpt: String?
    /// Copiado de la biblioteca de conceptos invitados.
    public let fromLibrary: Bool
    /// La chispa guardada de la que nació (`sourceType == .spark`). Nil si esa chispa ya no existe.
    public let originSparkID: Spark.ID?
    /// Las dos neuronas de esa chispa: nunca se combina con ellas.
    public let originConceptIDs: [UUID]
    public let createdAt: Date

    public init(id: UUID = UUID(), category: Category?, title: String, thesis: String, principle: String? = nil, status: ConceptStatus = .ready, distilled: Bool = false, confidence: Confidence? = nil, sourceType: SourceType, sourceURL: URL? = nil, sourceTitle: String? = nil, excerpt: String? = nil, fromLibrary: Bool = false, originSparkID: Spark.ID? = nil, originConceptIDs: [UUID] = [], createdAt: Date) {
        self.id = id
        self.category = category
        self.title = title
        self.thesis = thesis
        self.principle = principle
        self.status = status
        self.distilled = distilled
        self.confidence = confidence
        self.sourceType = sourceType
        self.sourceURL = sourceURL
        self.sourceTitle = sourceTitle
        self.excerpt = excerpt
        self.fromLibrary = fromLibrary
        self.originSparkID = originSparkID
        self.originConceptIDs = originConceptIDs
        self.createdAt = createdAt
    }

    /// True si una de las dos nació de una chispa de la otra: el servidor no las combina.
    public func isSparkRelative(of other: Concept) -> Bool {
        originConceptIDs.contains(other.id) || other.originConceptIDs.contains(id)
    }
}

/// Correcciones del usuario a un concepto. Los nil no se tocan.
public struct ConceptUpdate: Sendable, Equatable {
    public var title: String?
    public var thesis: String?
    /// Mueve el concepto a esta categoría (la crea si no existe).
    public var categoryName: String?
    /// Confirma un borrador.
    public var confirm: Bool

    public init(title: String? = nil, thesis: String? = nil, categoryName: String? = nil, confirm: Bool = false) {
        self.title = title
        self.thesis = thesis
        self.categoryName = categoryName
        self.confirm = confirm
    }
}

// MARK: - Captura

/// De dónde sale lo que se guarda.
public enum CaptureSource: Sendable, Equatable {
    case text
    /// Dictado: el teléfono lo transcribe y llega como texto.
    case voice
    /// Texto seleccionado en otra app, con la URL de origen si la hay.
    case selection(URL?)
    /// Texto sacado con OCR de una captura de pantalla.
    case screenshot
    /// Texto sacado con OCR de una página escaneada.
    case scan
    case link(URL)
    /// Imagen (JPEG ya reducido). Solo se conceptualiza con IA; el archivo se borra al procesarse.
    case image(Data)
    case pdf(Data)

    public var sourceType: SourceType {
        switch self {
        case .text: .text
        case .voice: .voice
        case .selection: .selection
        case .screenshot: .screenshot
        case .scan: .scan
        case .link: .link
        case .image: .image
        case .pdf: .pdf
        }
    }
}

public struct CaptureRequest: Sendable, Equatable {
    /// La idea en palabras del usuario. Puede faltar en links, imágenes y PDFs si se pide conceptualizar.
    public var thesis: String?
    public var category: String
    public var source: CaptureSource
    public var sourceTitle: String?
    /// Fragmento subrayado (se corta a 500 caracteres).
    public var excerpt: String?
    /// Identificador de la foto en la fototeca, que queda en el teléfono.
    public var localAssetID: String?
    /// Pedir conceptualización automática (Pro, o las pruebas del mes en free).
    public var distill: Bool
    /// Viene de importar notas (paso 89): gasta el cupo `import` en vez del de capturas y no se conceptualiza.
    public var importSource: ImportSource?

    public init(thesis: String?, category: String, source: CaptureSource, sourceTitle: String? = nil, excerpt: String? = nil, localAssetID: String? = nil, distill: Bool = false, importSource: ImportSource? = nil) {
        self.thesis = thesis
        self.category = category
        self.source = source
        self.sourceTitle = sourceTitle
        self.excerpt = excerpt
        self.localAssetID = localAssetID
        self.distill = importSource == nil && distill
        self.importSource = importSource
    }
}

/// Qué pasó con la conceptualización al guardar.
public enum DistillationOutcome: String, Sendable, Codable {
    /// No se pidió o no hacía falta (texto corto).
    case none
    /// Confianza alta: quedó guardado directo.
    case high
    /// Confianza media: quedó como borrador para confirmar.
    case medium
    /// No se pudo sacar una idea: hay que escribir "¿Qué idea te deja esto?".
    case needsThesis = "needs_thesis"
    /// Sin cupo de conceptualización este mes.
    case quotaExceeded = "quota_exceeded"
    /// La IA no respondió; se guardó sin conceptualizar.
    case unavailable
}

/// Resultado de guardar un concepto.
public struct CaptureResult: Sendable, Equatable {
    public let conceptID: UUID
    public let categoryID: UUID
    /// La categoría no existía y se creó con este concepto.
    public let categoryCreated: Bool
    /// Conceptos que quedaron (1 a 3 si se conceptualizó un link o un archivo).
    public let concepts: [Concept]
    public let distillation: DistillationOutcome

    public init(conceptID: UUID, categoryID: UUID, categoryCreated: Bool, concepts: [Concept] = [], distillation: DistillationOutcome = .none) {
        self.conceptID = conceptID
        self.categoryID = categoryID
        self.categoryCreated = categoryCreated
        self.concepts = concepts
        self.distillation = distillation
    }
}

// MARK: - Chispas

/// Mismos valores que `sparks.mode` en el esquema.
public enum SparkMode: String, Sendable, Codable {
    case daily, extra, pick, problem
}

/// Mismos valores que `sparks.status` en el esquema.
public enum SparkStatus: String, Sendable, Codable {
    case pending, revealed, saved, discarded
}

/// Mismos valores que `sparks.feedback` en el esquema.
public enum SparkFeedback: String, Sendable, CaseIterable, Codable {
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
    public var feedback: SparkFeedback?
    /// Proyecto donde quedó guardada, si se guardó en uno.
    public var projectID: UUID?
    public var projectName: String?
    /// Día local en que se muestra (solo las diarias).
    public let scheduledFor: Date?
    public let createdAt: Date

    public init(id: UUID = UUID(), conceptA: Concept, conceptB: Concept, title: String, body: String, mode: SparkMode = .daily, status: SparkStatus = .revealed, feedback: SparkFeedback? = nil, projectID: UUID? = nil, projectName: String? = nil, scheduledFor: Date? = nil, createdAt: Date) {
        self.id = id
        self.conceptA = conceptA
        self.conceptB = conceptB
        self.title = title
        self.body = body
        self.mode = mode
        self.status = status
        self.feedback = feedback
        self.projectID = projectID
        self.projectName = projectName
        self.scheduledFor = scheduledFor
        self.createdAt = createdAt
    }

    /// Todavía no se mostró: Hoy hace el reveal.
    public var isPending: Bool { status == .pending }
}

/// Chispas disponibles hoy.
public struct SparkQuota: Hashable, Sendable {
    public let available: Int
    public let total: Int
    /// Próxima recarga, en la hora elegida por el usuario.
    public let refillsAt: Date
    /// Conceptos que faltan guardar hoy para ganar una chispa extra (free).
    public let conceptsUntilExtra: Int
    /// Chispas extra que se pueden pedir ahora.
    public let extraRemaining: Int

    public init(available: Int, total: Int, refillsAt: Date, conceptsUntilExtra: Int, extraRemaining: Int = 0) {
        self.available = available
        self.total = total
        self.refillsAt = refillsAt
        self.conceptsUntilExtra = conceptsUntilExtra
        self.extraRemaining = extraRemaining
    }
}

/// Todo lo que muestra Hoy en un solo pedido.
public struct TodayState: Hashable, Sendable {
    public let spark: Spark?
    public let quota: SparkQuota
    /// Chispas extra pedidas hoy (además de la diaria).
    public let extras: [Spark]
    /// Días de pares buenos que quedan. Con menos de 7 se pide capturar más.
    public let runwayDays: Int
    public let conceptCount: Int

    public init(spark: Spark?, quota: SparkQuota, extras: [Spark] = [], runwayDays: Int, conceptCount: Int) {
        self.spark = spark
        self.quota = quota
        self.extras = extras
        self.runwayDays = runwayDays
        self.conceptCount = conceptCount
    }

    public var needsMoreConcepts: Bool { runwayDays < 7 }

    /// Chispas que quedan para encender hoy (el contador de Hoy): la diaria si sigue por encender y las extras que
    /// todavía se pueden pedir. `quota.available` cuenta también la diaria ya revelada, así que después del reveal
    /// el contador seguiría en "1 chispa para encender".
    public var sparksToIgnite: Int {
        min(quota.available, (spark?.isPending == true ? 1 : 0) + quota.extraRemaining)
    }
}

/// Motivo para reportar contenido generado por IA (requisito de Play).
public enum ReportReason: String, Sendable, CaseIterable, Codable {
    case offensive, dangerous, wrong, other
}

// MARK: - Proyectos y planificador

public struct Project: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public let sparkCount: Int
    public let createdAt: Date

    public init(id: UUID = UUID(), name: String, sparkCount: Int = 0, createdAt: Date) {
        self.id = id
        self.name = name
        self.sparkCount = sparkCount
        self.createdAt = createdAt
    }
}

public enum PlannerMode: String, Sendable, Codable, CaseIterable {
    /// Haiku: respuestas rápidas.
    case quick
    /// Sonnet: plan profundo.
    case deep
}

public enum PlannerRole: String, Sendable, Codable {
    case user, assistant
}

public struct PlannerMessage: Identifiable, Hashable, Sendable {
    public let id: Int
    public let role: PlannerRole
    public let content: String
    public let mode: PlannerMode
    public let createdAt: Date

    public init(id: Int, role: PlannerRole, content: String, mode: PlannerMode = .quick, createdAt: Date) {
        self.id = id
        self.role = role
        self.content = content
        self.mode = mode
        self.createdAt = createdAt
    }
}

/// Cómo trabaja el planificador: chat libre (planner.v1) o el método de los tres cuartos de Walt Disney (planner.v2).
public enum PlannerMethod: String, Sendable {
    case free
    case disney
}

/// Cuartos del método de Disney. Cada respuesta del planificador empieza con una marca `[[room:…]]` que la app oculta.
public enum PlannerRoom: String, Sendable, CaseIterable {
    case dreamer, realist, critic, plan

    /// Separa la marca del texto. Mientras la marca llega a medias en el streaming, el texto visible queda vacío.
    public static func split(_ raw: String) -> (room: PlannerRoom?, text: String) {
        let trimmed = raw.drop { $0.isWhitespace }
        guard trimmed.hasPrefix("[[") else { return (nil, raw) }
        guard let close = trimmed.range(of: "]]") else { return (nil, "") }
        let tag = trimmed[trimmed.index(trimmed.startIndex, offsetBy: 2)..<close.lowerBound]
        let room = tag.hasPrefix("room:") ? PlannerRoom(rawValue: String(tag.dropFirst(5))) : nil
        let text = trimmed[close.upperBound...].drop { $0.isWhitespace }
        return (room, String(text))
    }
}

/// Lentes del planificador (planner_lens.v1): convierten la chispa en un modelo de negocio, una trama o un post.
/// La respuesta empieza con la marca `[[lens:…]]` en vez de la del cuarto (`PlannerRoom.split` también la oculta).
public enum PlannerLens: String, Sendable, CaseIterable {
    case businessModel = "business_model"
    case plot
    case post

    /// La lente que marca una respuesta, si tiene marca.
    public static func of(_ raw: String) -> PlannerLens? {
        let trimmed = raw.drop { $0.isWhitespace }
        guard trimmed.hasPrefix("[[lens:"), let close = trimmed.range(of: "]]") else { return nil }
        return PlannerLens(rawValue: String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 7)..<close.lowerBound]))
    }
}

extension PlannerMessage {
    /// Cuarto del método al que pertenece la respuesta, si tiene marca.
    public var room: PlannerRoom? { PlannerRoom.split(content).room }
    /// Lente con la que se pidió la respuesta, si tiene marca.
    public var lens: PlannerLens? { role == .assistant ? PlannerLens.of(content) : nil }
    /// El texto para mostrar, sin la marca del cuarto.
    public var displayText: String { role == .assistant ? PlannerRoom.split(content).text : content }
}

/// Atajos del planificador (plan.md §4: backlog, abogado del diablo, stack).
public enum PlannerPreset: String, Sendable, CaseIterable {
    case backlog
    case devilsAdvocate = "devils_advocate"
    case stack
}
