import Foundation
import Supabase
import Testing
@testable import LumbreCore

// Ejemplos con la forma de `backend/openapi.yaml` (components/schemas).
private enum Sample {
    static let concept = """
    {
      "id": "a0000000-0000-0000-0000-000000000001",
      "title": "Escasez intencional",
      "thesis": "Limitar la oferta sube el valor percibido y la atención.",
      "principle": null,
      "status": "draft",
      "distilled": true,
      "confidence": "medium",
      "source_type": "link",
      "source_url": "https://example.com/escasez",
      "source_title": "Escasez",
      "excerpt": null,
      "from_library": false,
      "created_at": "2026-10-09T21:11:05.123456+00:00",
      "category": {
        "id": "c0000000-0000-0000-0000-000000000001",
        "name": "Marketing",
        "domain": { "slug": "marketing", "name_es": "Marketing", "name_en": "Marketing", "symbol_ios": "megaphone" }
      }
    }
    """

    static let conceptWithoutCategory = """
    {
      "id": "a0000000-0000-0000-0000-000000000002",
      "title": "Onda verde",
      "thesis": "Sincronizar semáforos crea un flujo continuo.",
      "status": "ready",
      "distilled": false,
      "source_type": "text",
      "from_library": false,
      "created_at": "2026-10-08 10:00:00+00",
      "category": null
    }
    """

    static func spark(scheduledFor: String = "\"2026-10-09\"") -> String {
        """
        {
          "id": "b0000000-0000-0000-0000-000000000001",
          "title": "Semáforos escasos",
          "body": "¿Y si la onda verde fuera un recurso limitado?",
          "mode": "daily",
          "status": "pending",
          "feedback": null,
          "project_id": "d0000000-0000-0000-0000-000000000001",
          "project_name": "App de tránsito",
          "scheduled_for": \(scheduledFor),
          "created_at": "2026-10-09T03:00:00Z",
          "concept_a": \(concept),
          "concept_b": \(conceptWithoutCategory)
        }
        """
    }

    static let today = """
    {
      "spark": \(spark()),
      "quota": { "available": 2, "total": 3, "refills_at": "2026-10-10T11:00:00.000Z", "concepts_until_extra": 1, "extra_remaining": 1 },
      "extras": [],
      "runway_days": 12,
      "concept_count": 9
    }
    """
}

@Suite struct DTODecodingTests {
    let decoder = LumbreJSON.decoder(dayTimeZone: TimeZone(identifier: "America/Argentina/Buenos_Aires")!)

    @Test func conceptDecodesEveryField() throws {
        let concept = try decoder.decode(ConceptDTO.self, from: Data(Sample.concept.utf8)).model
        #expect(concept.title == "Escasez intencional")
        #expect(concept.status == .draft)
        #expect(concept.distilled)
        #expect(concept.confidence == .medium)
        #expect(concept.sourceType == .link)
        #expect(concept.sourceURL == URL(string: "https://example.com/escasez"))
        #expect(concept.category?.name == "Marketing")
        #expect(concept.category?.domain?.slug == "marketing")
        #expect(concept.category?.symbol == "megaphone")
        #expect(concept.createdAt.timeIntervalSince1970.rounded(.down) == 1_791_580_265)
    }

    @Test func conceptWithoutCategoryAndOptionalFields() throws {
        let concept = try decoder.decode(ConceptDTO.self, from: Data(Sample.conceptWithoutCategory.utf8)).model
        #expect(concept.category == nil)
        #expect(concept.confidence == nil)
        #expect(concept.principle == nil)
        #expect(concept.status == .ready)
    }

    @Test func sparkNeuronDecodesItsOrigin() throws {
        let json = """
        { "id": "8F0A3C1E-2B4D-4E6F-8A1B-3C5D7E9F0A2B", "title": "Masa madre cuántica", "thesis": "Una levadura que solo crece si nadie la mira.",
          "principle": null, "status": "ready", "distilled": false, "confidence": null, "source_type": "spark",
          "source_url": null, "source_title": null, "excerpt": null, "from_library": false,
          "origin_spark_id": "1A2B3C4D-5E6F-4A1B-8C2D-3E4F5A6B7C8D",
          "origin_lo": "2B3C4D5E-6F7A-4B2C-9D3E-4F5A6B7C8D9E", "origin_hi": "3C4D5E6F-7A8B-4C3D-8E4F-5A6B7C8D9E0F",
          "created_at": "2026-10-17T12:00:00.000Z", "category": null }
        """
        let concept = try decoder.decode(ConceptDTO.self, from: Data(json.utf8)).model
        #expect(concept.sourceType == .spark)
        #expect(concept.originSparkID == UUID(uuidString: "1A2B3C4D-5E6F-4A1B-8C2D-3E4F5A6B7C8D"))
        #expect(concept.originConceptIDs.count == 2)
        let parent = Concept(id: UUID(uuidString: "2B3C4D5E-6F7A-4B2C-9D3E-4F5A6B7C8D9E")!, category: nil, title: "P", thesis: "P", sourceType: .text, createdAt: .now)
        #expect(concept.isSparkRelative(of: parent) && parent.isSparkRelative(of: concept))
        // Una neurona de antes del paso 88 (sin las columnas) decodifica igual.
        let old = try decoder.decode(ConceptDTO.self, from: Data(Sample.conceptWithoutCategory.utf8)).model
        #expect(old.originSparkID == nil && old.originConceptIDs.isEmpty && !old.isSparkRelative(of: parent))
    }

    @Test func sparkDecodesConceptsProjectAndLocalDay() throws {
        let spark = try decoder.decode(SparkDTO.self, from: Data(Sample.spark().utf8)).model
        #expect(spark.conceptA.title == "Escasez intencional")
        #expect(spark.conceptB.title == "Onda verde")
        #expect(spark.status == .pending)
        #expect(spark.isPending)
        #expect(spark.projectName == "App de tránsito")
        // 2026-10-09 en Buenos Aires empieza a las 03:00 UTC.
        #expect(spark.scheduledFor == LumbreJSON.parseTimestamp("2026-10-09T03:00:00Z"))
    }

    @Test func sparkFromPostgrestHasNestedProjectAndMayLackText() throws {
        let json = """
        {
          "id": "b0000000-0000-0000-0000-000000000002", "title": null, "body": null,
          "mode": "extra", "status": "revealed", "feedback": "already_had", "project_id": null,
          "project": { "name": "Otro" }, "scheduled_for": null, "created_at": "2026-10-09T03:00:00Z",
          "concept_a": \(Sample.concept), "concept_b": \(Sample.conceptWithoutCategory)
        }
        """
        let spark = try decoder.decode(SparkDTO.self, from: Data(json.utf8)).model
        #expect(spark.title == "Escasez intencional × Onda verde")
        #expect(spark.feedback == .alreadyHad)
        #expect(spark.projectName == "Otro")
        #expect(spark.scheduledFor == nil)
        #expect(spark.mode == .extra)
    }

    @Test func todayDecodesQuotaAndCounts() throws {
        let today = try decoder.decode(TodayDTO.self, from: Data(Sample.today.utf8)).model
        #expect(today.spark?.title == "Semáforos escasos")
        #expect(today.quota.available == 2)
        #expect(today.quota.total == 3)
        #expect(today.quota.extraRemaining == 1)
        #expect(today.quota.conceptsUntilExtra == 1)
        #expect(today.quota.refillsAt == LumbreJSON.parseTimestamp("2026-10-10T11:00:00Z"))
        #expect(today.runwayDays == 12)
        #expect(!today.needsMoreConcepts)
        #expect(today.conceptCount == 9)
    }

    @Test func todayWithoutSpark() throws {
        let json = """
        { "spark": null, "quota": { "available": 0, "total": 1, "refills_at": "2026-10-10T11:00:00Z", "concepts_until_extra": 3, "extra_remaining": 0 },
          "extras": [], "runway_days": 0, "concept_count": 1 }
        """
        let today = try decoder.decode(TodayDTO.self, from: Data(json.utf8)).model
        #expect(today.spark == nil)
        #expect(today.needsMoreConcepts)
    }

    @Test func plannerMessageDecodes() throws {
        let json = """
        [{ "id": 12, "role": "user", "content": "¿Por dónde arranco?", "mode": "deep", "created_at": "2026-10-09T12:00:00.5+00:00" },
         { "id": 13, "role": "assistant", "content": "Por el problema.", "mode": null, "created_at": "2026-10-09T12:00:03+00:00" }]
        """
        let messages = try decoder.decode([PlannerMessageDTO].self, from: Data(json.utf8)).map(\.model)
        #expect(messages.map(\.id) == [12, 13])
        #expect(messages[0].role == .user)
        #expect(messages[0].mode == .deep)
        #expect(messages[1].mode == .quick)
        #expect(messages[0].createdAt.timeIntervalSince1970.truncatingRemainder(dividingBy: 1) == 0.5)
    }

    @Test func creditsSkipUnknownKinds() throws {
        let json = """
        [{ "kind": "capture", "period": "day", "max_count": 30, "available": 30, "used": 4, "remaining": 26 },
         { "kind": "projects", "period": "total", "max_count": 1, "available": 1, "used": 0, "remaining": 1 },
         { "kind": "algo_nuevo", "period": "day", "max_count": 1, "available": 1, "used": 0, "remaining": 1 }]
        """
        let credits = try decoder.decode([CreditDTO].self, from: Data(json.utf8)).compactMap(\.model)
        #expect(credits == [
            Credit(kind: .capture, period: "day", max: 30, remaining: 26),
            Credit(kind: .projects, period: "total", max: 1, remaining: 1),
        ])
    }

    @Test func projectCountComesFromPostgrestAggregate() throws {
        let json = """
        [{ "id": "d0000000-0000-0000-0000-000000000001", "name": "App", "created_at": "2026-10-01T00:00:00Z", "sparks": [{ "count": 3 }] }]
        """
        let projects = try decoder.decode([ProjectDTO].self, from: Data(json.utf8)).map(\.model)
        #expect(projects.first?.sparkCount == 3)
    }

    @Test func profileOfAnAnonymousUserIsGuest() throws {
        let json = """
        { "creative_profiles": ["software", "otro"], "spark_hour": "09:30:00", "timezone": "America/Argentina/Buenos_Aires",
          "locale": "es", "plan": "free", "onboarded_at": null }
        """
        let row = try decoder.decode(ProfileRowDTO.self, from: Data(json.utf8))
        let guest = row.model(email: nil, isAnonymous: true)
        #expect(guest.plan == .guest)
        #expect(!guest.isOnboarded)
        #expect(guest.creativeProfiles == [.software])
        #expect(guest.sparkTime == SparkTime(hour: 9, minute: 30))
        #expect(row.model(email: "ana@lumbre.test", isAnonymous: false).plan == .free)
    }

    @Test func captureResultKeepsDistillation() throws {
        let json = """
        { "concept_id": "a0000000-0000-0000-0000-000000000001", "category_id": "c0000000-0000-0000-0000-000000000001",
          "category_created": true, "concepts": [\(Sample.concept)], "distillation": "medium" }
        """
        let result = try decoder.decode(CaptureResultDTO.self, from: Data(json.utf8)).model
        #expect(result.categoryCreated)
        #expect(result.distillation == .medium)
        #expect(result.concepts.count == 1)
    }

    @Test func captureBodyIsSnakeCaseAndSkipsNils() throws {
        let request = CaptureRequest(thesis: "  Una idea  ", category: "Diseño", source: .selection(URL(string: "https://a.com")), localAssetID: "abc", distill: true)
        let body = CaptureBody(request, attachment: .init(path: "u/x.jpg", mimeType: "image/jpeg"))
        let json = try JSONSerialization.jsonObject(with: LumbreJSON.encoder().encode(body)) as? [String: Any]
        #expect(json?["thesis"] as? String == "Una idea")
        #expect(json?["source_type"] as? String == "selection")
        #expect(json?["source_url"] as? String == "https://a.com")
        #expect(json?["local_asset_id"] as? String == "abc")
        #expect((json?["attachment"] as? [String: String])?["mime_type"] == "image/jpeg")
        #expect(json?["excerpt"] == nil)
    }

    @Test func modelsRoundTripThroughTheCacheEncoding() throws {
        let original = try decoder.decode(TodayDTO.self, from: Data(Sample.today.utf8)).model
        let data = try LumbreJSON.encoder().encode(TodayDTO(original))
        let decoded = try decoder.decode(TodayDTO.self, from: data).model
        #expect(decoded.spark?.id == original.spark?.id)
        #expect(decoded.spark?.scheduledFor == original.spark?.scheduledFor)
        #expect(decoded.spark?.conceptA.category?.domain?.symbol == "megaphone")
        #expect(decoded.quota == original.quota)
    }
}

@Suite struct DateParsingTests {
    @Test(arguments: [
        "2026-10-09T21:11:05Z",
        "2026-10-09T21:11:05+00:00",
        "2026-10-09 21:11:05+00",
        "2026-10-09T18:11:05-03:00",
        "2026-10-09T21:11:05",
        "2026-10-09T21:11:05.000000+00:00",
    ])
    func timestampsInEveryFormat(text: String) {
        #expect(LumbreJSON.parseTimestamp(text) == Date(timeIntervalSince1970: 1_791_580_265))
    }

    @Test func fractionsWithManyDigits() throws {
        let date = try #require(LumbreJSON.parseTimestamp("2026-10-09T21:11:05.123456+00:00"))
        #expect(abs(date.timeIntervalSince1970 - 1_791_580_265.123456) < 0.000_01)
    }

    @Test func garbageIsRejected() {
        #expect(LumbreJSON.parseTimestamp("ayer") == nil)
        #expect(LumbreJSON.parseTimestamp("2026-10-09T21:11") == nil)
    }

    @Test func dayRoundTrip() throws {
        let zone = TimeZone(identifier: "Asia/Tokyo")!
        let date = try #require(LumbreJSON.parseDay("2026-10-09", timeZone: zone))
        #expect(LumbreJSON.day(date, timeZone: zone) == "2026-10-09")
    }
}

@Suite struct SSEParserTests {
    @Test func eventsSplitAcrossChunks() {
        var parser = SSEParser()
        var events: [SSEEvent] = []
        for chunk in ["eve", "nt: delta\nda", "ta: {\"text\":\"Hola\"}", "\n", "\nevent: done\ndata: {\"message_id\": 7}\n\n"] {
            events += parser.feed(Data(chunk.utf8))
        }
        #expect(events == [
            SSEEvent(event: "delta", data: "{\"text\":\"Hola\"}"),
            SSEEvent(event: "done", data: "{\"message_id\": 7}"),
        ])
    }

    @Test func severalEventsInOneChunkWithCRLFAndComments() {
        var parser = SSEParser()
        let chunk = ": ping\r\nevent: delta\r\ndata: {\"text\":\"a\"}\r\n\r\nevent: delta\r\ndata: {\"text\":\"b\"}\r\n\r\n"
        #expect(parser.feed(Data(chunk.utf8)).map(\.data) == ["{\"text\":\"a\"}", "{\"text\":\"b\"}"])
    }

    @Test func crlfSplitBetweenChunks() {
        var parser = SSEParser()
        var events = parser.feed(Data("event: delta\r".utf8))
        events += parser.feed(Data("\ndata: x\r".utf8))
        events += parser.feed(Data("\n\r\n".utf8))
        #expect(events == [SSEEvent(event: "delta", data: "x")])
    }

    @Test func multibyteCharacterSplitInHalf() {
        var parser = SSEParser()
        let bytes = Array("data: {\"text\":\"canción\"}\n\n".utf8)
        let cut = bytes.firstIndex(of: 0xC3)! + 1
        var events = parser.feed(Data(bytes[..<cut]))
        events += parser.feed(Data(bytes[cut...]))
        #expect(events == [SSEEvent(event: "message", data: "{\"text\":\"canción\"}")])
    }

    @Test func multilineDataAndPendingEventOnFinish() {
        var parser = SSEParser()
        #expect(parser.feed(Data("event: delta\ndata: uno\ndata: dos\n".utf8)).isEmpty)
        #expect(parser.finish() == [SSEEvent(event: "delta", data: "uno\ndos")])
    }

    @Test func plannerEventsMapToTextDoneAndErrors() throws {
        #expect(try PlannerEvent(SSEEvent(event: "delta", data: "{\"text\":\"Hola\"}")) == .text("Hola"))
        #expect(try PlannerEvent(SSEEvent(event: "done", data: "{\"message_id\":123}")) == .done(messageID: 123))
        #expect(try PlannerEvent(SSEEvent(event: "ping", data: "")) == .ignored)
        #expect(throws: LumbreAPIError.proRequired) { try PlannerEvent(SSEEvent(event: "error", data: "{\"error\":\"pro_required\"}")) }
        #expect(throws: LumbreAPIError.unexpected) { try PlannerEvent(SSEEvent(event: "error", data: "{\"error\":\"ai_unavailable\"}")) }
    }
}

@Suite struct ErrorMappingTests {
    @Test func edgeFunctionErrorCodes() {
        #expect(EdgeFunctions.error(status: 429, body: Data("{\"error\":\"too_many_projects\"}".utf8)) == .tooManyProjects)
        #expect(EdgeFunctions.error(status: 422, body: Data("{\"error\":\"needs_thesis\"}".utf8)) == .needsThesis)
        #expect(EdgeFunctions.error(status: 409, body: Data("{\"error\":\"not_enough_concepts\"}".utf8)) == .notEnoughConcepts)
        #expect(EdgeFunctions.error(status: 500, body: Data("{\"error\":\"internal\"}".utf8)) == .unexpected)
    }

    @Test func statusDecidesWhenTheBodyHasNoCode() {
        #expect(EdgeFunctions.error(status: 402, body: Data("<html>".utf8)) == .proRequired)
        #expect(EdgeFunctions.error(status: 429, body: Data()) == .quotaExceeded)
        #expect(EdgeFunctions.error(status: 502, body: Data()) == .unexpected)
    }

    @Test func postgrestMessagesMapToTheirCase() {
        let quota = PostgrestError(code: "P0001", message: "quota_exceeded")
        #expect(SupabaseLumbreAPI.map(quota) as? LumbreAPIError == .quotaExceeded)
        let unknown = PostgrestError(code: "42501", message: "permission denied for table concepts")
        #expect(SupabaseLumbreAPI.map(unknown) as? LumbreAPIError == .unexpected)
    }

    @Test func connectivityErrorsAreOffline() {
        #expect(SupabaseLumbreAPI.map(URLError(.notConnectedToInternet)) as? LumbreAPIError == .offline)
        #expect(SupabaseLumbreAPI.map(URLError(.cannotConnectToHost)) as? LumbreAPIError == .offline)
        let wrapped = NSError(domain: "Auth", code: 1, userInfo: [NSUnderlyingErrorKey: URLError(.networkConnectionLost)])
        #expect(SupabaseLumbreAPI.map(wrapped) as? LumbreAPIError == .offline)
        #expect(SupabaseLumbreAPI.map(URLError(.badServerResponse)) as? LumbreAPIError == .unexpected)
    }

    @Test func cancellationIsNotAnError() {
        #expect(SupabaseLumbreAPI.map(CancellationError()) is CancellationError)
        #expect(SupabaseLumbreAPI.map(URLError(.cancelled)) is CancellationError)
    }
}

@Suite struct CacheTests {
    @Test func offlineReturnsTheLastResponse() async throws {
        let backend = FlakyAPI()
        let api = CachedLumbreAPI(wrapping: backend, storage: .inMemory)

        let online = try await api.concepts()
        let today = try await api.today()
        let profile = try await api.profile()
        #expect(!online.isEmpty)

        await backend.setOffline(true)
        let cached = try await api.concepts()
        #expect(cached.map(\.id) == online.map(\.id))
        #expect(cached.first?.category?.name == online.first?.category?.name)
        #expect(try await api.today().spark?.id == today.spark?.id)
        #expect(try await api.profile() == profile)
    }

    @Test func offlineWithoutCacheStillFails() async {
        let backend = FlakyAPI()
        await backend.setOffline(true)
        let api = CachedLumbreAPI(wrapping: backend, storage: .inMemory)
        await #expect(throws: LumbreAPIError.offline) { try await api.projects() }
    }

    @Test func otherErrorsAreNotHidden() async throws {
        let backend = FlakyAPI()
        let api = CachedLumbreAPI(wrapping: backend, storage: .inMemory)
        _ = try await api.categories()
        await backend.setFailure(.unexpected)
        await #expect(throws: LumbreAPIError.unexpected) { try await api.categories() }
    }

    @Test func signOutClearsTheCache() async throws {
        let backend = FlakyAPI()
        let api = CachedLumbreAPI(wrapping: backend, storage: .inMemory)
        _ = try await api.recentSparks()
        try await api.signOut()
        await backend.setOffline(true)
        await #expect(throws: LumbreAPIError.offline) { try await api.recentSparks() }
    }

    @Test func signingInToAnotherAccountClearsTheCache() async throws {
        let backend = FlakyAPI()
        let api = CachedLumbreAPI(wrapping: backend, storage: .inMemory)
        _ = try await api.concepts()
        _ = try await api.verifyEmailCode(MockLumbreAPI.emailCode, email: "otra@lumbre.test", purpose: .signIn)
        await backend.setOffline(true)
        await #expect(throws: LumbreAPIError.offline) { try await api.concepts() }
    }

    @Test func creatingTheAccountKeepsTheCache() async throws {
        let backend = FlakyAPI()
        let api = CachedLumbreAPI(wrapping: backend, storage: .inMemory)
        let before = try await api.concepts()
        _ = try await api.verifyEmailCode(MockLumbreAPI.emailCode, email: "nueva@lumbre.test", purpose: .createAccount)
        await backend.setOffline(true)
        #expect(try await api.concepts().map(\.id) == before.map(\.id))
    }
}

/// `MockLumbreAPI` con un interruptor de red, para probar la caché.
private final class FlakyAPI: LumbreAPI {
    private actor State {
        var failure: LumbreAPIError?
        func set(_ failure: LumbreAPIError?) { self.failure = failure }
    }

    private let mock = MockLumbreAPI(latency: .zero)
    private let state = State()

    func setOffline(_ offline: Bool) async { await state.set(offline ? .offline : nil) }
    func setFailure(_ failure: LumbreAPIError?) async { await state.set(failure) }

    private func check() async throws {
        if let failure = await state.failure { throw failure }
    }

    func profile() async throws -> Profile { try await check(); return try await mock.profile() }
    func updateProfile(_ update: ProfileUpdate) async throws -> Profile { try await check(); return try await mock.updateProfile(update) }
    func credits() async throws -> [Credit] { try await check(); return try await mock.credits() }
    func signOut() async throws { try await check() }
    func deleteAccount() async throws { try await check() }
    func exportData() async throws -> Data { try await check(); return Data() }
    func registerPushToken(_ token: String, sandbox: Bool) async throws {}
    func setAIConsent(_ granted: Bool) async throws { try await check() }
    func requestEmailCode(_ email: String, purpose: EmailCodePurpose) async throws { try await check() }
    func verifyEmailCode(_ code: String, email: String, purpose: EmailCodePurpose) async throws -> Profile {
        try await check(); return try await mock.verifyEmailCode(code, email: email, purpose: purpose)
    }
    func completeEmailLink(_ url: URL) async throws -> Profile { try await check(); return try await mock.completeEmailLink(url) }
    func today() async throws -> TodayState { try await check(); return try await mock.today() }
    func revealSpark(id: Spark.ID) async throws {}
    func saveSpark(id: Spark.ID, projectID: Project.ID?) async throws {}
    func sendFeedback(sparkID: Spark.ID, feedback: SparkFeedback) async throws {}
    func requestSpark(pick: (Concept.ID, Concept.ID)?) async throws -> Spark { try await check(); return try await mock.requestSpark(pick: pick) }
    func recentSparks() async throws -> [Spark] { try await check(); return try await mock.recentSparks() }
    func spark(id: Spark.ID) async throws -> Spark { try await check(); return try await mock.spark(id: id) }
    func reportSpark(id: Spark.ID, reason: ReportReason, note: String?) async throws {}
    func concepts() async throws -> [Concept] { try await check(); return try await mock.concepts() }
    func searchConcepts(_ query: String) async throws -> [Concept] { try await check(); return [] }
    func concept(id: Concept.ID) async throws -> Concept { try await check(); return try await mock.concept(id: id) }
    func sparks(withConcept id: Concept.ID) async throws -> [Spark] { [] }
    func updateConcept(id: Concept.ID, _ update: ConceptUpdate) async throws -> Concept { try await mock.updateConcept(id: id, update) }
    func deleteConcept(id: Concept.ID) async throws {}
    func categories() async throws -> [LumbreCore.Category] { try await check(); return try await mock.categories() }
    func renameCategory(id: LumbreCore.Category.ID, to name: String) async throws {}
    func deleteCategory(id: LumbreCore.Category.ID) async throws {}
    func capture(_ request: CaptureRequest) async throws -> CaptureResult { try await check(); return try await mock.capture(request) }
    func projects() async throws -> [Project] { try await check(); return try await mock.projects() }
    func createProject(name: String) async throws -> Project { try await mock.createProject(name: name) }
    func renameProject(id: Project.ID, to name: String) async throws {}
    func deleteProject(id: Project.ID) async throws {}
    func sparks(inProject id: Project.ID) async throws -> [Spark] { [] }
    func exportProjectMarkdown(id: Project.ID) async throws -> String { "" }
    func plannerMessages(sparkID: Spark.ID) async throws -> [PlannerMessage] { [] }
    func sendPlannerMessage(sparkID: Spark.ID, text: String, mode: PlannerMode, method: PlannerMethod, lens: PlannerLens?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func setPlanForDevelopment(_ plan: Plan) async throws {}
}
