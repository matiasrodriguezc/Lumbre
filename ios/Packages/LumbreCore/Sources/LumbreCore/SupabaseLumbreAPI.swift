import Foundation
import Supabase

/// Backend real: lee con la sesión del usuario y RLS; lo que crea contenido o gasta IA va por Edge Functions.
public struct SupabaseLumbreAPI: LumbreAPI {
    /// Credenciales del login de desarrollo. Solo se usan en Debug y nunca van al repo.
    public struct DevCredentials: Sendable {
        public let email: String
        public let password: String

        public init(email: String, password: String) {
            self.email = email
            self.password = password
        }
    }

    private let client: SupabaseClient
    private let session: SessionGate

    /// - Parameter resetSession: cierra la sesión guardada antes del primer pedido (para probar el primer login).
    public init(url: URL, publishableKey: String, devCredentials: DevCredentials? = nil, resetSession: Bool = false) {
        client = SupabaseClient(supabaseURL: url, supabaseKey: publishableKey)
        session = SessionGate(devCredentials: devCredentials, resetFirst: resetSession)
    }

    // MARK: - Lectura

    public func todaySpark() async throws -> Spark? {
        try await session.ensure(client)
        let rows: [SparkRow] = try await client.from("sparks")
            .select(SparkRow.columns)
            .eq("mode", value: SparkMode.daily.rawValue)
            .eq("scheduled_for", value: Self.localDay(.now))
            .limit(1)
            .execute()
            .value
        return rows.first?.model
    }

    public func recentSparks() async throws -> [Spark] {
        try await session.ensure(client)
        let rows: [SparkRow] = try await client.from("sparks")
            .select(SparkRow.columns)
            .lt("scheduled_for", value: Self.localDay(.now))
            .order("scheduled_for", ascending: false)
            .limit(10)
            .execute()
            .value
        return rows.map(\.model)
    }

    public func concepts() async throws -> [Concept] {
        try await session.ensure(client)
        let rows: [ConceptRow] = try await client.from("concepts")
            .select(ConceptRow.columns)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.map(\.model)
    }

    public func categories() async throws -> [Category] {
        try await session.ensure(client)
        let rows: [CategoryRow] = try await client.from("categories")
            .select(CategoryRow.columns)
            .order("name")
            .execute()
            .value
        return rows.map(\.model)
    }

    public func sparkQuota() async throws -> SparkQuota {
        try await session.ensure(client)
        async let credits: [CreditRow] = client.rpc("credit_status").execute().value
        async let profile: ProfileRow = client.from("profiles").select("spark_hour").single().execute().value
        async let today = todaySpark()
        async let savedToday = client.from("concepts")
            .select("id", head: true, count: .exact)
            .gte("created_at", value: ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: .now)))
            .execute()
            .count ?? 0

        let (creditRows, profileRow, todaysSpark, saved) = try await (credits, profile, today, savedToday)
        let extra = creditRows.first { $0.kind == "spark_extra" }
        // La chispa diaria cuenta como disponible mientras no se guardó ni se descartó.
        let daily = todaysSpark.map { $0.status == .pending || $0.status == .revealed ? 1 : 0 } ?? 0
        return SparkQuota(
            available: daily + (extra?.remaining ?? 0),
            total: 1 + (extra?.available ?? 0),
            refillsAt: Self.nextOccurrence(of: profileRow.sparkHour),
            conceptsUntilExtra: 3 - saved % 3
        )
    }

    // MARK: - Escritura

    public func saveSpark(id: Spark.ID) async throws {
        try await session.ensure(client)
        try await client.from("sparks").update(["status": SparkStatus.saved.rawValue]).eq("id", value: id).execute()
    }

    public func sendFeedback(sparkID: Spark.ID, feedback: SparkFeedback) async throws {
        try await session.ensure(client)
        try await client.from("sparks")
            .update(["status": SparkStatus.discarded.rawValue, "feedback": feedback.rawValue])
            .eq("id", value: sparkID)
            .execute()
    }

    public func signOut() async throws {
        try await client.auth.signOut(scope: .local)
    }

    /// Guarda con `capture_concept()`: descuenta la cuota, encuentra o crea la categoría e inserta el concepto.
    /// El embedding y la destilación se suman después, en el servidor (pasos 23 a 27).
    public func capture(thesis: String, category: String, source: CaptureSource) async throws -> CaptureResult {
        try await session.ensure(client)
        let params: CaptureParams
        switch source {
        case .text: params = CaptureParams(p_thesis: thesis, p_category: category, p_source_type: "text", p_source_url: nil)
        case .link(let url): params = CaptureParams(p_thesis: thesis, p_category: category, p_source_type: "link", p_source_url: url.absoluteString)
        }
        do {
            let rows: [CaptureRow] = try await client.rpc("capture_concept", params: params).execute().value
            guard let row = rows.first else { throw LumbreAPIError.unexpected }
            return CaptureResult(conceptID: row.conceptID, categoryID: row.categoryID, categoryCreated: row.categoryCreated)
        } catch let error as PostgrestError {
            throw LumbreAPIError(serverMessage: error.message) ?? error
        }
    }

    // MARK: - Fechas

    /// Día local como lo guarda `sparks.scheduled_for`.
    static func localDay(_ date: Date) -> String {
        date.formatted(.iso8601.year().month().day())
    }

    /// Próxima vez que llega la hora de la chispa ("08:00:00"), hoy o mañana.
    static func nextOccurrence(of time: String, after now: Date = .now, calendar: Calendar = .current) -> Date {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        let hour = parts.first ?? 8
        let minute = parts.dropFirst().first ?? 0
        let today = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
        return today > now ? today : calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }
}

public enum LumbreAPIError: LocalizedError, Equatable {
    case quotaExceeded
    case tooManyCategories
    case invalidThesis
    case invalidCategory
    case invalidSource
    case unexpected

    /// Traduce los errores que devuelve `capture_concept()` en el mensaje.
    init?(serverMessage: String) {
        switch serverMessage {
        case "quota_exceeded": self = .quotaExceeded
        case "too_many_categories": self = .tooManyCategories
        case "invalid_thesis": self = .invalidThesis
        case "invalid_category": self = .invalidCategory
        case "invalid_source": self = .invalidSource
        default: return nil
        }
    }

    public var errorDescription: String? {
        switch self {
        case .quotaExceeded: return String(localized: "Llegaste al límite de capturas de hoy. Mañana podés seguir guardando.")
        case .tooManyCategories: return String(localized: "Ya tenés 50 categorías. Usá una de las que tenés.")
        case .invalidThesis: return String(localized: "La idea tiene que tener entre 1 y 600 caracteres.")
        case .invalidCategory: return String(localized: "La categoría tiene que tener entre 1 y 40 caracteres.")
        case .invalidSource: return String(localized: "Revisá el link: no parece válido.")
        case .unexpected: return String(localized: "Algo salió mal. Probá de nuevo.")
        }
    }
}

/// Un solo inicio de sesión a la vez: varias pantallas cargan en paralelo y comparten el que está en curso.
/// (El actor solo no alcanza: mientras un llamado espera el login, otros entran y abrirían más sesiones.)
private actor SessionGate {
    let devCredentials: SupabaseLumbreAPI.DevCredentials?
    private var inFlight: Task<Void, Error>?
    private var resetFirst: Bool

    init(devCredentials: SupabaseLumbreAPI.DevCredentials?, resetFirst: Bool) {
        self.devCredentials = devCredentials
        self.resetFirst = resetFirst
    }

    /// Usa la sesión guardada en el Keychain; si no hay, entra con el login de desarrollo o como invitado.
    func ensure(_ client: SupabaseClient) async throws {
        if let inFlight {
            return try await inFlight.value
        }
        let reset = resetFirst
        resetFirst = false
        let task = Task { [devCredentials] in
            if reset {
                try? await client.auth.signOut(scope: .local)
            } else if (try? await client.auth.session) != nil {
                return
            }
            if let devCredentials {
                try await client.auth.signIn(email: devCredentials.email, password: devCredentials.password)
            } else {
                try await client.auth.signInAnonymously(data: [
                    "timezone": .string(TimeZone.current.identifier),
                    "locale": .string(Locale.current.language.languageCode?.identifier ?? "es"),
                ])
            }
        }
        inFlight = task
        defer { inFlight = nil }
        try await task.value
    }
}

// MARK: - Filas de PostgREST

private struct CategoryRow: Decodable {
    static let columns = "id,name,dom:domain(slug,name_es,name_en,symbol_ios)"

    let id: UUID
    let name: String
    let dom: DomainRow?

    var model: Category { Category(id: id, name: name, domain: dom?.model) }
}

private struct CaptureParams: Encodable, Sendable {
    let p_thesis: String
    let p_category: String
    let p_source_type: String
    let p_source_url: String?
}

private struct CaptureRow: Decodable {
    let conceptID: UUID
    let categoryID: UUID
    let categoryCreated: Bool

    enum CodingKeys: String, CodingKey {
        case conceptID = "concept_id"
        case categoryID = "category_id"
        case categoryCreated = "category_created"
    }
}

private struct DomainRow: Decodable {
    let slug: String
    let nameEs: String
    let nameEn: String
    let symbolIOS: String?

    enum CodingKeys: String, CodingKey {
        case slug
        case nameEs = "name_es"
        case nameEn = "name_en"
        case symbolIOS = "symbol_ios"
    }

    var model: Domain {
        let english = Locale.current.language.languageCode?.identifier == "en"
        return Domain(slug: slug, name: english ? nameEn : nameEs, symbol: symbolIOS ?? "circle.hexagongrid")
    }
}

private struct ConceptRow: Decodable {
    static let columns = "id,title,thesis,source_type,source_title,created_at,cat:categories!concepts_category_same_user(\(CategoryRow.columns))"

    let id: UUID
    let title: String
    let thesis: String
    let sourceType: String
    let sourceTitle: String?
    let createdAt: Date
    let cat: CategoryRow?

    enum CodingKeys: String, CodingKey {
        case id, title, thesis, cat
        case sourceType = "source_type"
        case sourceTitle = "source_title"
        case createdAt = "created_at"
    }

    var model: Concept {
        Concept(
            id: id,
            category: cat?.model,
            title: title,
            thesis: thesis,
            sourceType: SourceType(rawValue: sourceType) ?? .text,
            sourceTitle: sourceTitle,
            createdAt: createdAt
        )
    }
}

private struct SparkRow: Decodable {
    static let columns = "id,title,body,mode,status,created_at,a:concept_lo(\(ConceptRow.columns)),b:concept_hi(\(ConceptRow.columns))"

    let id: UUID
    let title: String?
    let body: String?
    let mode: String
    let status: String
    let createdAt: Date
    let a: ConceptRow
    let b: ConceptRow

    enum CodingKeys: String, CodingKey {
        case id, title, body, mode, status, a, b
        case createdAt = "created_at"
    }

    var model: Spark {
        Spark(
            id: id,
            conceptA: a.model,
            conceptB: b.model,
            title: title ?? "\(a.title) × \(b.title)",
            body: body ?? "",
            mode: SparkMode(rawValue: mode) ?? .daily,
            status: SparkStatus(rawValue: status) ?? .revealed,
            createdAt: createdAt
        )
    }
}

private struct CreditRow: Decodable {
    let kind: String
    let available: Int
    let remaining: Int
}

private struct ProfileRow: Decodable {
    let sparkHour: String

    enum CodingKeys: String, CodingKey {
        case sparkHour = "spark_hour"
    }
}
