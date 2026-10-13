import Foundation

/// Lo que las pantallas le piden al backend. Lo implementan `SupabaseLumbreAPI` (Supabase local o remoto)
/// y `MockLumbreAPI` (datos de prueba en memoria, para previews y `-mock`).
/// El contrato de las Edge Functions está en `backend/openapi.yaml`.
public protocol LumbreAPI: Sendable {
    // MARK: Sesión y perfil

    /// Perfil del usuario de la sesión. Si no hay sesión, entra como invitado.
    func profile() async throws -> Profile
    func updateProfile(_ update: ProfileUpdate) async throws -> Profile
    /// Cupos del plan efectivo (`credit_status()`).
    func credits() async throws -> [Credit]
    /// Cierra la sesión en este dispositivo.
    func signOut() async throws
    /// Borra la cuenta y todo lo suyo. No se puede deshacer.
    func deleteAccount() async throws
    /// Todos los datos del usuario en JSON (perfil, categorías, conceptos, chispas, proyectos y planificador).
    func exportData() async throws -> Data
    func registerPushToken(_ token: String, sandbox: Bool) async throws

    // MARK: Hoy y chispas

    /// Chispa del día (se genera si todavía no existe), cupo y extras de hoy.
    func today() async throws -> TodayState
    /// Marca la chispa como vista después del reveal.
    func revealSpark(id: Spark.ID) async throws
    /// Guarda la chispa, opcionalmente en un proyecto.
    func saveSpark(id: Spark.ID, projectID: Project.ID?) async throws
    func sendFeedback(sparkID: Spark.ID, feedback: SparkFeedback) async throws
    /// Pide una chispa extra (cupo `spark_extra`). En Pro, `pick` combina dos conceptos elegidos.
    func requestSpark(pick: (Concept.ID, Concept.ID)?) async throws -> Spark
    /// Chispas anteriores, de la más nueva a la más vieja.
    func recentSparks() async throws -> [Spark]
    func spark(id: Spark.ID) async throws -> Spark
    func reportSpark(id: Spark.ID, reason: ReportReason, note: String?) async throws

    // MARK: Bóveda

    func concepts() async throws -> [Concept]
    /// Búsqueda semántica: por idea, no por palabra.
    func searchConcepts(_ query: String) async throws -> [Concept]
    func concept(id: Concept.ID) async throws -> Concept
    /// Chispas en las que aparece el concepto.
    func sparks(withConcept id: Concept.ID) async throws -> [Spark]
    func updateConcept(id: Concept.ID, _ update: ConceptUpdate) async throws -> Concept
    func deleteConcept(id: Concept.ID) async throws
    /// Categorías del usuario, en orden alfabético. Un usuario nuevo no tiene ninguna.
    func categories() async throws -> [Category]
    func renameCategory(id: Category.ID, to name: String) async throws
    /// Borra la categoría; sus conceptos quedan sin categoría.
    func deleteCategory(id: Category.ID) async throws
    /// Guarda un concepto en la categoría indicada; si no existe, la crea.
    func capture(_ request: CaptureRequest) async throws -> CaptureResult

    // MARK: Proyectos y planificador

    func projects() async throws -> [Project]
    func createProject(name: String) async throws -> Project
    func renameProject(id: Project.ID, to name: String) async throws
    /// Borra el proyecto; sus chispas quedan guardadas sin proyecto.
    func deleteProject(id: Project.ID) async throws
    func sparks(inProject id: Project.ID) async throws -> [Spark]
    /// Proyecto con sus chispas, conceptos y planes, en Markdown.
    func exportProjectMarkdown(id: Project.ID) async throws -> String
    func plannerMessages(sparkID: Spark.ID) async throws -> [PlannerMessage]
    /// Manda un mensaje al planificador y devuelve la respuesta a medida que llega.
    /// Con `.disney`, las respuestas empiezan con la marca del cuarto (`PlannerRoom.split`).
    func sendPlannerMessage(sparkID: Spark.ID, text: String, mode: PlannerMode, method: PlannerMethod) -> AsyncThrowingStream<String, Error>

    // MARK: Desarrollo

    /// Solo con el backend local: cambia el plan sin pasar por la tienda.
    func setPlanForDevelopment(_ plan: Plan) async throws
}

extension LumbreAPI {
    /// Atajo para guardar texto (lo que usaba la sheet antes de los adjuntos).
    public func capture(thesis: String, category: String, source: CaptureSource) async throws -> CaptureResult {
        try await capture(CaptureRequest(thesis: thesis, category: category, source: source))
    }
}

public enum LumbreAPIError: LocalizedError, Equatable {
    case quotaExceeded
    case tooManyCategories
    case invalidThesis
    case invalidCategory
    case invalidSource
    case needsThesis
    case proRequired
    case notEnoughConcepts
    case tooManyProjects
    case accountRequired
    case offline
    case unexpected

    /// Traduce los códigos de error que devuelven las funciones de la base y las Edge Functions.
    public init?(serverMessage: String) {
        switch serverMessage {
        case "quota_exceeded": self = .quotaExceeded
        case "too_many_categories": self = .tooManyCategories
        case "invalid_thesis": self = .invalidThesis
        case "invalid_category": self = .invalidCategory
        case "invalid_source": self = .invalidSource
        case "needs_thesis": self = .needsThesis
        case "pro_required": self = .proRequired
        case "not_enough_concepts": self = .notEnoughConcepts
        case "too_many_projects": self = .tooManyProjects
        case "account_required": self = .accountRequired
        default: return nil
        }
    }

    public var errorDescription: String? {
        switch self {
        case .quotaExceeded: String(localized: "Llegaste al límite de hoy. Mañana podés seguir.")
        case .tooManyCategories: String(localized: "Ya tenés 50 categorías. Usá una de las que tenés.")
        case .invalidThesis: String(localized: "La idea tiene que tener entre 1 y 600 caracteres.")
        case .invalidCategory: String(localized: "La categoría tiene que tener entre 1 y 40 caracteres.")
        case .invalidSource: String(localized: "Revisá el link: no parece válido.")
        case .needsThesis: String(localized: "No pudimos sacar una idea de esto. ¿Qué idea te deja?")
        case .proRequired: String(localized: "Esto es parte de Lumbre Pro.")
        case .notEnoughConcepts: String(localized: "Guardá un par de neuronas más para tener material que conectar.")
        case .tooManyProjects: String(localized: "Con el plan gratis tenés un circuito. Con Pro, todos los que quieras.")
        case .accountRequired: String(localized: "Creá tu cuenta para usar esto.")
        case .offline: String(localized: "Sin conexión. Lo guardamos y lo mandamos cuando vuelva.")
        case .unexpected: String(localized: "Algo salió mal. Probá de nuevo.")
        }
    }
}

extension LumbreAPI {
    /// Chat libre del planificador (planner.v1).
    public func sendPlannerMessage(sparkID: Spark.ID, text: String, mode: PlannerMode) -> AsyncThrowingStream<String, Error> {
        sendPlannerMessage(sparkID: sparkID, text: text, mode: mode, method: .free)
    }
}
