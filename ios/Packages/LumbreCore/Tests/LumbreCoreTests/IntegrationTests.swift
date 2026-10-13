import Foundation
import Supabase
import Testing
@testable import LumbreCore

/// Prueba de punta a punta contra el Supabase local, con las Edge Functions servidas
/// (`cd backend && supabase start && supabase functions serve`). Es opt-in:
///
/// ```bash
/// cd ios/Packages/LumbreCore
/// TEST_RUNNER_LUMBRE_INTEGRATION=1 xcodebuild test -scheme LumbreCore \
///   -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:LumbreCoreTests/IntegrationTests
/// ```
///
/// (xcodebuild le pasa al simulador las variables con prefijo `TEST_RUNNER_` sin el prefijo.)
/// Sin la variable, o si el backend no responde, se saltea.
@Suite(.serialized, .enabled("Hace falta LUMBRE_INTEGRATION=1 y el backend local con las funciones servidas") {
    await LocalBackend.isReady()
})
struct IntegrationTests {
    let api = SupabaseLumbreAPI(
        url: LocalBackend.url,
        publishableKey: LocalBackend.publishableKey,
        devCredentials: nil,
        resetSession: false,
        authStorage: MemoryAuthStorage()
    )

    @Test func guestCapturesSearchesExportsAndDeletesTheAccount() async throws {
        // Invitado nuevo.
        let profile = try await api.profile()
        #expect(profile.isGuest)
        #expect(!profile.isOnboarded)
        #expect(try await api.concepts().isEmpty)

        let onboarded = try await api.updateProfile(ProfileUpdate(creativeProfiles: [.software, .curiosity], sparkTime: SparkTime(hour: 9), completeOnboarding: true))
        #expect(onboarded.isOnboarded)
        #expect(onboarded.creativeProfiles == [.software, .curiosity])
        #expect(onboarded.sparkTime == SparkTime(hour: 9))

        // Captura: la categoría se crea con el primer concepto y se reusa normalizada.
        let first = try await api.capture(thesis: "Limitar la oferta sube el valor percibido y la atención.", category: "Economía", source: .text)
        #expect(first.categoryCreated)
        let second = try await api.capture(thesis: "Sincronizar semáforos crea un flujo continuo a velocidad constante.", category: " economia ", source: .link(URL(string: "https://example.com/onda-verde")!))
        #expect(!second.categoryCreated)
        #expect(second.categoryID == first.categoryID)
        let third = try await api.capture(thesis: "Un flujo en espiral separa partículas por fuerza centrífuga.", category: "Ingeniería", source: .voice)

        let concepts = try await api.concepts()
        #expect(concepts.count == 3)
        #expect(concepts.first { $0.id == second.conceptID }?.sourceURL?.host() == "example.com")
        #expect(try await api.categories().map(\.name) == ["Economía", "Ingeniería"])

        // Correcciones directas con RLS y `move_concept()`.
        let edited = try await api.updateConcept(id: third.conceptID, ConceptUpdate(title: "Separación ciclónica", categoryName: "Física"))
        #expect(edited.title == "Separación ciclónica")
        #expect(edited.category?.name == "Física")

        // Hoy y búsqueda.
        let today = try await api.today()
        #expect(today.conceptCount == 3)
        _ = try await api.searchConcepts("semáforos")
        _ = try await api.credits()

        // Proyecto (un invitado tiene uno) y export.
        let project = try await api.createProject(name: "Tránsito")
        await #expect(throws: LumbreAPIError.tooManyProjects) { try await api.createProject(name: "Otro") }
        if let spark = today.spark {
            try await api.revealSpark(id: spark.id)
            try await api.saveSpark(id: spark.id, projectID: project.id)
            #expect(try await api.sparks(inProject: project.id).map(\.id) == [spark.id])
            #expect(try await api.plannerMessages(sparkID: spark.id).isEmpty)
        }
        #expect(try await api.projects().first?.name == "Tránsito")
        let markdown = try await api.exportProjectMarkdown(id: project.id)
        #expect(markdown.hasPrefix("# Tránsito"))

        let export = try JSONSerialization.jsonObject(with: try await api.exportData())
        #expect(export is [String: Any])

        // Borrar la cuenta deja la app sin sesión: el próximo pedido es un invitado nuevo, vacío.
        try await api.deleteAccount()
        let fresh = try await api.profile()
        #expect(fresh.isGuest)
        #expect(!fresh.isOnboarded)
        #expect(try await api.concepts().isEmpty)
        try await api.deleteAccount()
    }

    @Test func errorsComeBackAsLumbreErrors() async throws {
        await #expect(throws: LumbreAPIError.invalidThesis) {
            try await api.capture(thesis: "", category: "Algo", source: .text)
        }
        await #expect(throws: LumbreAPIError.invalidCategory) {
            try await api.capture(thesis: "Una idea", category: String(repeating: "x", count: 41), source: .text)
        }
        // El planificador es de Pro.
        let stream = api.sendPlannerMessage(sparkID: UUID(), text: "Hola", mode: .quick)
        await #expect(throws: LumbreAPIError.self) {
            for try await _ in stream {}
        }
        try await api.deleteAccount()
    }
}

enum LocalBackend {
    static let url = URL(string: "http://127.0.0.1:55521")!
    /// Clave publicable fija de la CLI de Supabase para el stack local.
    static let publishableKey = "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH"

    /// La variable está puesta y la función `today` responde (sin sesión devuelve 401, pero existe).
    static func isReady() async -> Bool {
        guard ProcessInfo.processInfo.environment["LUMBRE_INTEGRATION"] == "1" else { return false }
        var request = URLRequest(url: url.appending(path: "functions/v1/today"), timeoutInterval: 5)
        request.httpMethod = "POST"
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let status = (response as? HTTPURLResponse)?.statusCode else { return false }
        return ![404, 502, 503].contains(status)
    }
}

/// Sesión en memoria: los tests del paquete no tienen Keychain.
final class MemoryAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    func store(key: String, value: Data) throws { lock.withLock { values[key] = value } }
    func retrieve(key: String) throws -> Data? { lock.withLock { values[key] } }
    func remove(key: String) throws { lock.withLock { _ = values.removeValue(forKey: key) } }
}
