import Foundation
import SwiftData

/// Caché offline (plan.md §7): envuelve cualquier `LumbreAPI`, guarda la última respuesta de las lecturas
/// principales y, si un pedido falla por falta de red, devuelve lo último que tiene. Las escrituras pasan directo.
/// También deja la chispa de hoy en el App Group para el widget.
public struct CachedLumbreAPI: LumbreAPI {
    public enum Storage: Sendable {
        /// En `LumbreShared.cacheStoreURL` (App Group si existe).
        case shared
        case file(URL)
        /// Para tests y previews.
        case inMemory
    }

    private let base: any LumbreAPI
    /// nil si no se pudo abrir el store: entonces la caché no hace nada y todo pasa directo.
    private let cache: ResponseCache?
    private let writesWidgetSnapshot: Bool

    public init(wrapping base: any LumbreAPI, storage: Storage = .shared) {
        self.base = base
        cache = ResponseCache.open(storage)
        writesWidgetSnapshot = if case .inMemory = storage { false } else { true }
    }

    // MARK: Lecturas con caché

    public func profile() async throws -> Profile {
        try await cached("profile", ProfileDTO.self, encode: ProfileDTO.init, decode: \.model) { try await base.profile() }
    }

    public func today() async throws -> TodayState {
        let state = try await cached("today", TodayDTO.self, encode: TodayDTO.init, decode: \.model) { try await base.today() }
        if writesWidgetSnapshot {
            if let spark = state.spark {
                LumbreShared.writeTodaySnapshot(.init(spark: spark))
            } else {
                LumbreShared.clearTodaySnapshot()
            }
        }
        return state
    }

    public func recentSparks() async throws -> [Spark] {
        try await cached("recentSparks", [SparkDTO].self, encode: { $0.map(SparkDTO.init) }, decode: { $0.map(\.model) }) { try await base.recentSparks() }
    }

    public func concepts() async throws -> [Concept] {
        try await cached("concepts", [ConceptDTO].self, encode: { $0.map(ConceptDTO.init) }, decode: { $0.map(\.model) }) { try await base.concepts() }
    }

    public func categories() async throws -> [Category] {
        try await cached("categories", [CategoryDTO].self, encode: { $0.map(CategoryDTO.init) }, decode: { $0.map(\.model) }) { try await base.categories() }
    }

    public func projects() async throws -> [Project] {
        try await cached("projects", [ProjectDTO].self, encode: { $0.map(ProjectDTO.init) }, decode: { $0.map(\.model) }) { try await base.projects() }
    }

    /// Pide al backend; si responde, guarda la respuesta. Si no hay red, devuelve la última guardada.
    private func cached<Value: Sendable, DTO: Codable>(
        _ key: String,
        _ dto: DTO.Type,
        encode: (Value) -> DTO,
        decode: (DTO) -> Value,
        fetch: () async throws -> Value
    ) async throws -> Value {
        do {
            let value = try await fetch()
            if let cache, let data = try? LumbreJSON.encoder().encode(encode(value)) {
                await cache.store(data, for: key)
            }
            return value
        } catch LumbreAPIError.offline {
            guard let data = await cache?.load(key), let stored = try? LumbreJSON.decoder().decode(DTO.self, from: data) else {
                throw LumbreAPIError.offline
            }
            return decode(stored)
        }
    }

    // MARK: Sesión: al salir se borra lo guardado

    public func signOut() async throws {
        try await base.signOut()
        await clear()
    }

    public func deleteAccount() async throws {
        try await base.deleteAccount()
        await clear()
    }

    private func clear() async {
        await cache?.clear()
        if writesWidgetSnapshot { LumbreShared.clearTodaySnapshot() }
    }

    // MARK: Directo

    public func updateProfile(_ update: ProfileUpdate) async throws -> Profile { try await base.updateProfile(update) }
    public func credits() async throws -> [Credit] { try await base.credits() }
    public func exportData() async throws -> Data { try await base.exportData() }
    public func registerPushToken(_ token: String, sandbox: Bool) async throws { try await base.registerPushToken(token, sandbox: sandbox) }
    public func revealSpark(id: Spark.ID) async throws { try await base.revealSpark(id: id) }
    public func saveSpark(id: Spark.ID, projectID: Project.ID?) async throws { try await base.saveSpark(id: id, projectID: projectID) }
    public func sendFeedback(sparkID: Spark.ID, feedback: SparkFeedback) async throws { try await base.sendFeedback(sparkID: sparkID, feedback: feedback) }
    public func requestSpark(pick: (Concept.ID, Concept.ID)?) async throws -> Spark { try await base.requestSpark(pick: pick) }
    public func spark(id: Spark.ID) async throws -> Spark { try await base.spark(id: id) }
    public func reportSpark(id: Spark.ID, reason: ReportReason, note: String?) async throws { try await base.reportSpark(id: id, reason: reason, note: note) }
    public func searchConcepts(_ query: String) async throws -> [Concept] { try await base.searchConcepts(query) }
    public func concept(id: Concept.ID) async throws -> Concept { try await base.concept(id: id) }
    public func sparks(withConcept id: Concept.ID) async throws -> [Spark] { try await base.sparks(withConcept: id) }
    public func updateConcept(id: Concept.ID, _ update: ConceptUpdate) async throws -> Concept { try await base.updateConcept(id: id, update) }
    public func deleteConcept(id: Concept.ID) async throws { try await base.deleteConcept(id: id) }
    public func renameCategory(id: Category.ID, to name: String) async throws { try await base.renameCategory(id: id, to: name) }
    public func deleteCategory(id: Category.ID) async throws { try await base.deleteCategory(id: id) }
    public func capture(_ request: CaptureRequest) async throws -> CaptureResult { try await base.capture(request) }
    public func createProject(name: String) async throws -> Project { try await base.createProject(name: name) }
    public func renameProject(id: Project.ID, to name: String) async throws { try await base.renameProject(id: id, to: name) }
    public func deleteProject(id: Project.ID) async throws { try await base.deleteProject(id: id) }
    public func sparks(inProject id: Project.ID) async throws -> [Spark] { try await base.sparks(inProject: id) }
    public func exportProjectMarkdown(id: Project.ID) async throws -> String { try await base.exportProjectMarkdown(id: id) }
    public func plannerMessages(sparkID: Spark.ID) async throws -> [PlannerMessage] { try await base.plannerMessages(sparkID: sparkID) }
    public func sendPlannerMessage(sparkID: Spark.ID, text: String, mode: PlannerMode) -> AsyncThrowingStream<String, Error> {
        base.sendPlannerMessage(sparkID: sparkID, text: text, mode: mode)
    }
    public func setPlanForDevelopment(_ plan: Plan) async throws { try await base.setPlanForDevelopment(plan) }
}

// MARK: - Store

/// Una respuesta guardada: el JSON de los DTOs, por clave.
@Model
final class CachedResponse {
    @Attribute(.unique) var key: String
    var payload: Data
    var updatedAt: Date

    init(key: String, payload: Data, updatedAt: Date = .now) {
        self.key = key
        self.payload = payload
        self.updatedAt = updatedAt
    }
}

@ModelActor
actor ResponseCache {
    static func open(_ storage: CachedLumbreAPI.Storage) -> ResponseCache? {
        let configuration: ModelConfiguration = switch storage {
        case .shared: ModelConfiguration(url: LumbreShared.cacheStoreURL)
        case .file(let url): ModelConfiguration(url: url)
        case .inMemory: ModelConfiguration(isStoredInMemoryOnly: true)
        }
        do {
            let container = try ModelContainer(for: CachedResponse.self, configurations: configuration)
            return ResponseCache(modelContainer: container)
        } catch {
            LumbreShared.logger.error("No se pudo abrir la caché: \(String(describing: type(of: error)), privacy: .public)")
            return nil
        }
    }

    func store(_ payload: Data, for key: String) {
        if let existing = fetch(key) {
            existing.payload = payload
            existing.updatedAt = .now
        } else {
            modelContext.insert(CachedResponse(key: key, payload: payload))
        }
        try? modelContext.save()
    }

    func load(_ key: String) -> Data? {
        fetch(key)?.payload
    }

    func clear() {
        try? modelContext.delete(model: CachedResponse.self)
        try? modelContext.save()
    }

    private func fetch(_ key: String) -> CachedResponse? {
        var descriptor = FetchDescriptor<CachedResponse>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}
