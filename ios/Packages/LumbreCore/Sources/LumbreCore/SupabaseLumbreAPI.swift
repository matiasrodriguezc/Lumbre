import Foundation
import OSLog
import Supabase

/// Backend real (Supabase local o remoto): lee y edita directo con la sesión del usuario y RLS;
/// lo que crea contenido o gasta IA va por las Edge Functions (`backend/openapi.yaml`).
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
    private let functions: EdgeFunctions

    /// - Parameters:
    ///   - resetSession: cierra la sesión guardada antes del primer pedido (para probar el primer login).
    ///   - keychainAccessGroup: guarda la sesión en ese grupo de Keychain para que la usen la Share Extension y los
    ///     App Intents (`LumbreShared.keychainAccessGroup`). Si el proceso no tiene el entitlement, queda en el Keychain propio.
    public init(url: URL, publishableKey: String, devCredentials: DevCredentials? = nil, resetSession: Bool = false, keychainAccessGroup: String? = nil) {
        var storage: (any AuthLocalStorage)?
        if let keychainAccessGroup, SharedKeychain.isAvailable(group: keychainAccessGroup) {
            SharedKeychain.migrateSession(key: SharedKeychain.storageKey(for: url), to: keychainAccessGroup)
            storage = KeychainLocalStorage(accessGroup: keychainAccessGroup)
        }
        self.init(url: url, publishableKey: publishableKey, devCredentials: devCredentials, resetSession: resetSession, authStorage: storage)
    }

    /// Para la Share Extension y los App Intents: usa la sesión que guardó la app en el Keychain compartido, sin renovarla
    /// ni abrir otra (la app es la única dueña del refresh token, que el servidor rota). Si no hay sesión o le quedan
    /// menos de cinco minutos, cada pedido falla con `.offline` y el que llama encola la captura para que la mande la app.
    public static func borrowingSharedSession(url: URL, publishableKey: String, keychainAccessGroup: String = LumbreShared.keychainAccessGroup) -> SupabaseLumbreAPI {
        SupabaseLumbreAPI(url: url, publishableKey: publishableKey, devCredentials: nil, resetSession: false,
                          authStorage: KeychainLocalStorage(accessGroup: keychainAccessGroup), mode: .borrowed)
    }

    /// - Parameter authStorage: dónde guarda Auth la sesión. nil = el Keychain (lo normal); los tests usan memoria.
    init(url: URL, publishableKey: String, devCredentials: DevCredentials?, resetSession: Bool, authStorage: (any AuthLocalStorage)?, mode: SessionMode = .owner) {
        let storageKey = SharedKeychain.storageKey(for: url)
        let autoRefresh = mode == .owner
        let auth: SupabaseClientOptions.AuthOptions = if let authStorage {
            .init(storage: authStorage, storageKey: storageKey, autoRefreshToken: autoRefresh, emitLocalSessionAsInitialSession: true)
        } else {
            .init(storageKey: storageKey, autoRefreshToken: autoRefresh, emitLocalSessionAsInitialSession: true)
        }
        let client = SupabaseClient(supabaseURL: url, supabaseKey: publishableKey, options: SupabaseClientOptions(auth: auth))
        self.client = client
        session = SessionGate(devCredentials: devCredentials, resetFirst: resetSession, mode: mode)
        // App Attest solo en la app (dueña de la sesión, Keychain real); los tests usan memoria y la extensión toma prestada la sesión.
        let attests = mode == .owner && (authStorage == nil || authStorage is KeychainLocalStorage)
        functions = EdgeFunctions(supabaseURL: url, publishableKey: publishableKey, attestor: attests ? .shared : nil) {
            try await client.auth.session.accessToken
        }
    }

    // MARK: - Sesión y perfil

    public func profile() async throws -> Profile {
        try await perform {
            do {
                return try await loadProfile()
            } catch let error as PostgrestError where error.code == "PGRST116" {
                // La sesión guardada es de un usuario que ya no existe (por ejemplo, después de `supabase db reset`):
                // se descarta y se entra de nuevo.
                try await session.restart(client)
                return try await loadProfile()
            }
        }
    }

    private func loadProfile() async throws -> Profile {
        let user = try await client.auth.session.user
        let data = try await client.from("profiles")
            .select(QueryColumns.profile)
            .eq("id", value: user.id)
            .single()
            .execute()
            .data
        return try decode(ProfileRowDTO.self, data).model(email: user.email, isAnonymous: user.isAnonymous)
    }

    public func updateProfile(_ update: ProfileUpdate) async throws -> Profile {
        try await perform {
            var values: [String: AnyJSON] = [:]
            if let value = update.creativeProfiles { values["creative_profiles"] = .array(value.prefix(2).map { .string($0.rawValue) }) }
            if let value = update.sparkTime { values["spark_hour"] = .string(value.postgres) }
            if let value = update.timezone { values["timezone"] = .string(value) }
            if let value = update.locale { values["locale"] = .string(value) }
            if update.completeOnboarding { values["onboarded_at"] = .string(LumbreJSON.timestamp(.now)) }
            if !values.isEmpty {
                let userID = try await client.auth.session.user.id
                try await client.from("profiles").update(values).eq("id", value: userID).execute()
            }
            return try await loadProfile()
        }
    }

    public func credits() async throws -> [Credit] {
        try await perform {
            let data = try await client.rpc("credit_status").execute().data
            return try decode([CreditDTO].self, data).compactMap(\.model)
        }
    }

    public func signOut() async throws {
        await session.signOut(client)
    }

    public func deleteAccount() async throws {
        try await perform {
            try await client.rpc("delete_my_account").execute()
        }
        await session.signOut(client)
    }

    public func exportData() async throws -> Data {
        try await perform {
            try await client.rpc("export_my_data").execute().data
        }
    }

    public func registerPushToken(_ token: String, sandbox: Bool) async throws {
        try await perform {
            try await client.rpc("register_push_token", params: PushTokenParams(p_token: token, p_platform: "ios", p_sandbox: sandbox)).execute()
        }
    }

    /// `profiles.ai_consent_at`: la fecha del "Acepto", o null si no aceptó o lo revocó (las Edge Functions no mandan
    /// nada a la IA sin esa fecha). Mientras la columna no exista en la base (PGRST204), queda en los metadatos de Auth
    /// (`user_metadata.ai_consent`) para no perder la respuesta, y falla para que `AIConsent.sync` reintente.
    public func setAIConsent(_ granted: Bool) async throws {
        try await perform {
            let userID = try await client.auth.session.user.id
            let value: AnyJSON = granted ? .string(LumbreJSON.timestamp(.now)) : .null
            do {
                try await client.from("profiles").update(["ai_consent_at": value]).eq("id", value: userID).execute()
            } catch let error as PostgrestError where error.code == "PGRST204" {
                try await client.auth.update(user: UserAttributes(data: [
                    "ai_consent": .bool(granted),
                    "ai_consent_at": value,
                ]))
                // Falla igual para que la app lo vuelva a intentar (y llegue a `profiles` cuando exista la columna).
                throw LumbreAPIError.unexpected
            }
        }
    }

    // MARK: - Cuenta con email

    public func requestEmailCode(_ email: String, purpose: EmailCodePurpose) async throws {
        guard let email = EmailAccount.normalized(email) else { throw LumbreAPIError.invalidEmail }
        try await perform {
            switch purpose {
            case .createAccount:
                // El mismo usuario anónimo pasa a tener email: conserva sus neuronas, chispas y circuitos.
                try await client.auth.update(user: UserAttributes(email: email), redirectTo: EmailAccount.callbackURL)
            case .signIn:
                try await client.auth.signInWithOTP(email: email, redirectTo: EmailAccount.callbackURL, shouldCreateUser: true, data: SessionGate.deviceMetadata)
            }
        }
    }

    public func verifyEmailCode(_ code: String, email: String, purpose: EmailCodePurpose) async throws -> Profile {
        guard let email = EmailAccount.normalized(email) else { throw LumbreAPIError.invalidEmail }
        guard let code = EmailAccount.normalizedCode(code) else { throw LumbreAPIError.invalidCode }
        return try await perform {
            switch purpose {
            case .createAccount:
                try await client.auth.verifyOTP(email: email, token: code, type: .emailChange)
                // El token nuevo trae `is_anonymous = false`: con eso `effective_plan()` pasa de guest a free.
                _ = try? await client.auth.refreshSession()
            case .signIn:
                try await client.auth.verifyOTP(email: email, token: code, type: .email)
            }
            return try await loadProfile()
        }
    }

    public func completeEmailLink(_ url: URL) async throws -> Profile {
        try await perform {
            try await client.auth.session(from: url)
            _ = try? await client.auth.refreshSession()
            return try await loadProfile()
        }
    }

    // MARK: - Hoy y chispas

    public func today() async throws -> TodayState {
        try await perform {
            let today: TodayDTO = try await functions.call("today", body: EmptyBody(), timeout: 90)
            return today.model
        }
    }

    public func revealSpark(id: Spark.ID) async throws {
        try await perform {
            // Solo una pendiente pasa a vista: si ya se guardó o descartó, no se toca.
            try await client.from("sparks")
                .update(["status": AnyJSON.string(SparkStatus.revealed.rawValue)])
                .eq("id", value: id)
                .eq("status", value: SparkStatus.pending.rawValue)
                .execute()
        }
    }

    public func saveSpark(id: Spark.ID, projectID: Project.ID?) async throws {
        try await perform {
            try await client.from("sparks")
                .update([
                    "status": AnyJSON.string(SparkStatus.saved.rawValue),
                    "project_id": projectID.map { AnyJSON.string($0.uuidString) } ?? .null,
                ])
                .eq("id", value: id)
                .execute()
        }
    }

    public func sendFeedback(sparkID: Spark.ID, feedback: SparkFeedback) async throws {
        try await perform {
            try await client.from("sparks")
                .update(["status": AnyJSON.string(SparkStatus.discarded.rawValue), "feedback": .string(feedback.rawValue)])
                .eq("id", value: sparkID)
                .execute()
        }
    }

    public func requestSpark(pick: (Concept.ID, Concept.ID)?) async throws -> Spark {
        let body = SparkRequestBody(mode: pick == nil ? "extra" : "pick", conceptIds: pick.map { [$0.0, $0.1] })
        return try await perform {
            let response: SparkEnvelopeDTO = try await functions.call("spark", body: body, timeout: 90)
            return response.spark.model
        }
    }

    public func recentSparks() async throws -> [Spark] {
        try await perform {
            let data = try await client.from("sparks")
                .select(QueryColumns.spark)
                .order("created_at", ascending: false)
                .limit(60)
                .execute()
                .data
            // La diaria de hoy la muestra Hoy.
            let today = Calendar.current
            return try decode([SparkDTO].self, data).map(\.model).filter { spark in
                !(spark.mode == .daily && spark.scheduledFor.map(today.isDateInToday) == true)
            }
        }
    }

    public func spark(id: Spark.ID) async throws -> Spark {
        try await perform {
            let data = try await client.from("sparks").select(QueryColumns.spark).eq("id", value: id).single().execute().data
            return try decode(SparkDTO.self, data).model
        }
    }

    public func reportSpark(id: Spark.ID, reason: ReportReason, note: String?) async throws {
        try await perform {
            try await client.from("content_reports")
                .insert(ReportRow(spark_id: id, reason: reason.rawValue, note: note.map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500)) }?.nilIfEmpty))
                .execute()
        }
    }

    // MARK: - Bóveda

    public func concepts() async throws -> [Concept] {
        try await perform {
            let data = try await client.from("concepts")
                .select(QueryColumns.concept)
                .order("created_at", ascending: false)
                .execute()
                .data
            return try decode([ConceptDTO].self, data).map(\.model)
        }
    }

    public func searchConcepts(_ query: String) async throws -> [Concept] {
        let query = String(query.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        guard !query.isEmpty else { return [] }
        return try await perform {
            let response: ConceptListDTO = try await functions.call("search", body: SearchBody(query: query, limit: 30))
            return response.concepts.map(\.model)
        }
    }

    public func concept(id: Concept.ID) async throws -> Concept {
        try await perform {
            try await loadConcept(id)
        }
    }

    private func loadConcept(_ id: Concept.ID) async throws -> Concept {
        let data = try await client.from("concepts").select(QueryColumns.concept).eq("id", value: id).single().execute().data
        return try decode(ConceptDTO.self, data).model
    }

    public func sparks(withConcept id: Concept.ID) async throws -> [Spark] {
        try await perform {
            let data = try await client.from("sparks")
                .select(QueryColumns.spark)
                .or("concept_lo.eq.\(id.uuidString),concept_hi.eq.\(id.uuidString)")
                .order("created_at", ascending: false)
                .execute()
                .data
            return try decode([SparkDTO].self, data).map(\.model)
        }
    }

    public func updateConcept(id: Concept.ID, _ update: ConceptUpdate) async throws -> Concept {
        try await perform {
            var values: [String: AnyJSON] = [:]
            if let title = update.title { values["title"] = .string(title) }
            if let thesis = update.thesis { values["thesis"] = .string(thesis) }
            if update.confirm { values["status"] = .string(ConceptStatus.ready.rawValue) }
            if !values.isEmpty {
                try await client.from("concepts").update(values).eq("id", value: id).execute()
            }
            if let name = update.categoryName {
                try await client.rpc("move_concept", params: MoveConceptParams(p_concept: id, p_category: name)).execute()
            }
            return try await loadConcept(id)
        }
    }

    public func deleteConcept(id: Concept.ID) async throws {
        try await perform {
            try await client.from("concepts").delete().eq("id", value: id).execute()
        }
    }

    public func categories() async throws -> [Category] {
        try await perform {
            let data = try await client.from("categories").select(QueryColumns.category).execute().data
            return try decode([CategoryDTO].self, data).map(\.model)
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    public func renameCategory(id: Category.ID, to name: String) async throws {
        try await perform {
            try await client.from("categories").update(["name": AnyJSON.string(name)]).eq("id", value: id).execute()
        }
    }

    public func deleteCategory(id: Category.ID) async throws {
        try await perform {
            try await client.from("categories").delete().eq("id", value: id).execute()
        }
    }

    /// Con un adjunto, primero lo sube a `capture-temp/<user_id>/<uuid>.<ext>`; la función lo procesa y lo borra.
    public func capture(_ request: CaptureRequest) async throws -> CaptureResult {
        try await perform {
            var attachment: CaptureBody.Attachment?
            switch request.source {
            case .image(let data), .pdf(let data):
                let kind = Attachment(source: request.source, data: data)
                let userID = try await client.auth.session.user.id
                let path = "\(userID.uuidString.lowercased())/\(UUID().uuidString.lowercased()).\(kind.fileExtension)"
                try await client.storage.from("capture-temp").upload(path, data: data, options: FileOptions(contentType: kind.mimeType))
                attachment = .init(path: path, mimeType: kind.mimeType)
            default:
                break
            }
            let body = CaptureBody(request, attachment: attachment)
            let result: CaptureResultDTO = try await functions.call("capture", body: body, timeout: request.distill ? 120 : 60)
            return result.model
        }
    }

    // MARK: - Proyectos y planificador

    public func projects() async throws -> [Project] {
        try await perform {
            let data = try await client.from("projects")
                .select(QueryColumns.project)
                .order("created_at")
                .execute()
                .data
            return try decode([ProjectDTO].self, data).map(\.model)
        }
    }

    public func createProject(name: String) async throws -> Project {
        try await perform {
            let data = try await client.rpc("create_project", params: CreateProjectParams(p_name: name)).execute().data
            // La RPC puede devolver la fila o solo el id.
            if let row = try? decode(ProjectDTO.self, data) { return row.model }
            if let rows = try? decode([ProjectDTO].self, data), let row = rows.first { return row.model }
            let id = try decode(UUID.self, data)
            let row = try await client.from("projects").select(QueryColumns.project).eq("id", value: id).single().execute().data
            return try decode(ProjectDTO.self, row).model
        }
    }

    public func renameProject(id: Project.ID, to name: String) async throws {
        try await perform {
            try await client.from("projects").update(["name": AnyJSON.string(name)]).eq("id", value: id).execute()
        }
    }

    public func deleteProject(id: Project.ID) async throws {
        try await perform {
            try await client.from("projects").delete().eq("id", value: id).execute()
        }
    }

    public func sparks(inProject id: Project.ID) async throws -> [Spark] {
        try await perform {
            try await loadSparks(inProject: id)
        }
    }

    private func loadSparks(inProject id: Project.ID) async throws -> [Spark] {
        let data = try await client.from("sparks")
            .select(QueryColumns.spark)
            .eq("project_id", value: id)
            .order("created_at", ascending: false)
            .execute()
            .data
        return try decode([SparkDTO].self, data).map(\.model)
    }

    /// Se arma en el teléfono: el proyecto, sus chispas y el hilo del planificador de cada una.
    public func exportProjectMarkdown(id: Project.ID) async throws -> String {
        try await perform {
            async let nameData = client.from("projects").select("name").eq("id", value: id).single().execute().data
            let sparks = try await loadSparks(inProject: id)
            let name = try decode(SparkDTO.ProjectName.self, try await nameData).name
            let plans = try await withThrowingTaskGroup(of: (Spark.ID, [PlannerMessage]).self) { group in
                for spark in sparks {
                    group.addTask { (spark.id, try await loadPlannerMessages(sparkID: spark.id)) }
                }
                return try await group.reduce(into: [Spark.ID: [PlannerMessage]]()) { $0[$1.0] = $1.1 }
            }
            return MarkdownExport.project(name: name, sparks: sparks, plans: plans)
        }
    }

    public func plannerMessages(sparkID: Spark.ID) async throws -> [PlannerMessage] {
        try await perform {
            try await loadPlannerMessages(sparkID: sparkID)
        }
    }

    private func loadPlannerMessages(sparkID: Spark.ID) async throws -> [PlannerMessage] {
        let data = try await client.from("planner_messages")
            .select(QueryColumns.plannerMessage)
            .eq("thread.spark_id", value: sparkID)
            .order("id")
            .execute()
            .data
        return try decode([PlannerMessageDTO].self, data).map(\.model)
    }

    /// Streaming por SSE: emite cada `delta` y termina con `done`. Cancelar el stream corta la conexión.
    public func sendPlannerMessage(sparkID: Spark.ID, text: String, mode: PlannerMode, method: PlannerMethod) -> AsyncThrowingStream<String, Error> {
        let body = PlannerBody(sparkId: sparkID, message: text, mode: mode.rawValue, method: method.rawValue)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await perform {
                        try await functions.events("planner", body: body) { event in
                            switch try PlannerEvent(event) {
                            case .text(let text):
                                continuation.yield(text)
                                return true
                            case .done:
                                return false
                            case .ignored:
                                return true
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Desarrollo

    public func setPlanForDevelopment(_ plan: Plan) async throws {
        guard plan != .guest else { throw LumbreAPIError.unexpected }
        try await perform {
            try await functions.send("dev-plan", body: ["plan": plan.rawValue])
        }
    }

    // MARK: - Soporte

    /// Asegura la sesión, corre el pedido y traduce los errores a `LumbreAPIError`.
    private func perform<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            try await session.ensure(client)
            return try await operation()
        } catch {
            throw Self.map(error)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        try LumbreJSON.decoder().decode(type, from: data)
    }

    /// Sin red → `.offline`. Los códigos del servidor (Edge Functions y mensajes de PostgREST) → su caso.
    /// Lo demás → `.unexpected`, y se anota el tipo en el log (nunca el contenido).
    static func map(_ error: any Error) -> any Error {
        switch error {
        case is LumbreAPIError, is CancellationError:
            return error
        case _ where isOffline(error):
            return LumbreAPIError.offline
        case let error as URLError where error.code == .cancelled:
            return CancellationError()
        case let error as PostgrestError:
            if let mapped = LumbreAPIError(serverMessage: error.message) { return mapped }
            logger.error("PostgREST: \(error.code ?? "sin código", privacy: .public)")
            return LumbreAPIError.unexpected
        case let error as AuthError:
            switch error.errorCode {
            case .emailExists, .userAlreadyExists: return LumbreAPIError.emailInUse
            case .otpExpired: return LumbreAPIError.invalidCode
            case .validationFailed: return LumbreAPIError.invalidEmail
            case .overEmailSendRateLimit, .overRequestRateLimit: return LumbreAPIError.quotaExceeded
            default:
                logger.error("Auth: \(error.errorCode.rawValue, privacy: .public)")
                return LumbreAPIError.unexpected
            }
        case let error as StorageError:
            logger.error("Storage: \(error.statusCode ?? "sin estado", privacy: .public)")
            return LumbreAPIError.unexpected
        default:
            logger.error("Error inesperado: \(String(describing: type(of: error)), privacy: .public)")
            return LumbreAPIError.unexpected
        }
    }

    /// Errores de conectividad, también cuando vienen envueltos (Auth y Storage a veces envuelven el URLError).
    static func isOffline(_ error: any Error) -> Bool {
        let offlineCodes: Set<URLError.Code> = [
            .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost,
            .timedOut, .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff, .callIsActive,
        ]
        var current: (any Error)? = error
        var depth = 0
        while let candidate = current, depth < 5 {
            if let urlError = candidate as? URLError, offlineCodes.contains(urlError.code) { return true }
            let nsError = candidate as NSError
            if nsError.domain == NSURLErrorDomain, offlineCodes.contains(URLError.Code(rawValue: nsError.code)) { return true }
            current = nsError.userInfo[NSUnderlyingErrorKey] as? any Error
            depth += 1
        }
        return false
    }

    static let logger = Logger(subsystem: "com.matiasrodriguezc.lumbre", category: "api")

    // MARK: - Fechas

    /// Día local como lo guarda `sparks.scheduled_for`.
    static func localDay(_ date: Date) -> String {
        LumbreJSON.day(date)
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

// MARK: - Sesión

/// Quién maneja la sesión.
enum SessionMode: Sendable {
    /// La app: entra, renueva el token y guarda la sesión.
    case owner
    /// Extensiones y atajos: usan la sesión guardada tal como está, sin renovarla ni crear otra.
    case borrowed
}

/// Un solo inicio de sesión a la vez: varias pantallas cargan en paralelo y comparten el que está en curso.
/// (El actor solo no alcanza: mientras un llamado espera el login, otros entran y abrirían más sesiones.)
private actor SessionGate {
    private let devCredentials: SupabaseLumbreAPI.DevCredentials?
    private let mode: SessionMode
    private var inFlight: Task<Void, Error>?
    private var resetFirst: Bool
    /// Después de cerrar sesión o borrar la cuenta, el próximo pedido entra como invitado nuevo, no con el login de desarrollo.
    private var useDevCredentials = true

    /// Margen mínimo de vigencia del access token para usar una sesión prestada: así nunca hace falta renovarla a mitad del pedido.
    static let borrowedMargin: TimeInterval = 300

    init(devCredentials: SupabaseLumbreAPI.DevCredentials?, resetFirst: Bool, mode: SessionMode = .owner) {
        self.devCredentials = devCredentials
        self.resetFirst = resetFirst
        self.mode = mode
    }

    /// Usa la sesión guardada en el Keychain; si no hay, entra con el login de desarrollo o como invitado.
    /// Con una sesión prestada, solo la usa si sigue vigente; si no, `.offline` (el que llama encola).
    func ensure(_ client: SupabaseClient) async throws {
        if mode == .borrowed {
            guard let current = client.auth.currentSession,
                  Date(timeIntervalSince1970: current.expiresAt).timeIntervalSinceNow > Self.borrowedMargin
            else { throw LumbreAPIError.offline }
            return
        }
        if let inFlight {
            return try await inFlight.value
        }
        let reset = resetFirst
        resetFirst = false
        let credentials = useDevCredentials ? devCredentials : nil
        let task = Task {
            if reset {
                try? await client.auth.signOut(scope: .local)
            } else {
                do {
                    _ = try await client.auth.session
                    return
                } catch AuthError.sessionMissing {
                    // Primera vez, o después de cerrar sesión.
                } catch let AuthError.api(_, _, _, response) where (400..<500).contains(response.statusCode) {
                    // El servidor ya no acepta la sesión guardada (usuario borrado, refresh token vencido).
                }
                // Cualquier otro error (sin red, servidor caído) se propaga: entrar de nuevo
                // crearía otro invitado y se perdería la bóveda del actual.
            }
            try await Self.signIn(client, credentials: credentials)
        }
        inFlight = task
        defer { inFlight = nil }
        try await task.value
    }

    /// Descarta la sesión guardada y entra de nuevo.
    func restart(_ client: SupabaseClient) async throws {
        guard mode == .owner else { throw LumbreAPIError.offline }
        try? await client.auth.signOut(scope: .local)
        try await ensure(client)
    }

    /// Cierra la sesión en este dispositivo. No falla: si el servidor no responde, igual se borra la local.
    func signOut(_ client: SupabaseClient) async {
        guard mode == .owner else { return }
        useDevCredentials = false
        try? await client.auth.signOut(scope: .local)
    }

    private static func signIn(_ client: SupabaseClient, credentials: SupabaseLumbreAPI.DevCredentials?) async throws {
        if let credentials {
            try await client.auth.signIn(email: credentials.email, password: credentials.password)
        } else {
            try await client.auth.signInAnonymously(data: deviceMetadata)
        }
    }

    /// Zona horaria e idioma del teléfono: el trigger `on_auth_user_created` arma el perfil con esto.
    static var deviceMetadata: [String: AnyJSON] {
        [
            "timezone": .string(TimeZone.current.identifier),
            "locale": .string(Locale.current.language.languageCode?.identifier == "en" ? "en" : "es"),
        ]
    }
}

// MARK: - Consultas de PostgREST

/// Los `select` usan alias para devolver la misma forma que las Edge Functions (los DTOs).
enum QueryColumns {
    static let domain = "slug,name_es,name_en,symbol_ios"
    static let category = "id,name,domain:domains(\(domain))"
    static let concept = "id,title,thesis,principle,status,distilled,confidence,source_type,source_url,source_title,excerpt,from_library,created_at,"
        + "category:categories!concepts_category_same_user(\(category))"
    static let spark = "id,title,body,mode,status,feedback,project_id,scheduled_for,created_at,project:projects(name),"
        + "concept_a:concepts!sparks_concept_lo_fkey(\(concept)),concept_b:concepts!sparks_concept_hi_fkey(\(concept))"
    static let project = "id,name,created_at,sparks(count)"
    static let plannerMessage = "id,role,content,mode,created_at,thread:planner_threads!inner(spark_id)"
    static let profile = "creative_profiles,spark_hour,timezone,locale,plan,onboarded_at"
}

// MARK: - Cuerpos y parámetros

private struct PushTokenParams: Encodable, Sendable {
    let p_token: String
    let p_platform: String
    let p_sandbox: Bool
}

private struct CreateProjectParams: Encodable, Sendable {
    let p_name: String
}

private struct MoveConceptParams: Encodable, Sendable {
    let p_concept: UUID
    let p_category: String
}

private struct ReportRow: Encodable, Sendable {
    let spark_id: UUID
    let reason: String
    let note: String?
}

private struct SparkRequestBody: Encodable, Sendable {
    let mode: String
    let conceptIds: [UUID]?
}

private struct SearchBody: Encodable, Sendable {
    let query: String
    let limit: Int
}

private struct PlannerBody: Encodable, Sendable {
    let sparkId: UUID
    let message: String
    let mode: String
    let method: String
}

/// Cuerpo de `POST /capture`.
struct CaptureBody: Encodable, Sendable {
    struct Attachment: Encodable, Sendable {
        let path: String
        let mimeType: String
    }

    let thesis: String?
    let category: String
    let sourceType: String
    let sourceUrl: String?
    let sourceTitle: String?
    let excerpt: String?
    let localAssetId: String?
    let attachment: Attachment?
    let distill: Bool

    init(_ request: CaptureRequest, attachment: Attachment?) {
        thesis = request.thesis?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        category = request.category.trimmingCharacters(in: .whitespacesAndNewlines)
        sourceType = request.source.sourceType.rawValue
        sourceUrl = switch request.source {
        case .link(let url): url.absoluteString
        case .selection(let url): url?.absoluteString
        default: nil
        }
        sourceTitle = request.sourceTitle
        excerpt = request.excerpt.map { String($0.prefix(500)) }
        localAssetId = request.localAssetID
        self.attachment = attachment
        distill = request.distill
    }
}

/// Tipo del archivo que se sube a `capture-temp`.
private struct Attachment {
    let mimeType: String
    let fileExtension: String

    init(source: CaptureSource, data: Data) {
        if case .pdf = source {
            (mimeType, fileExtension) = ("application/pdf", "pdf")
        } else if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            (mimeType, fileExtension) = ("image/png", "png")
        } else {
            (mimeType, fileExtension) = ("image/jpeg", "jpg")
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
