import Testing
@testable import LumbreCore

@Suite struct MockLumbreAPITests {
    let api = MockLumbreAPI(latency: .zero)

    @Test func todaySparkCombinesTwoDifferentCategories() async throws {
        let spark = try #require(try await api.today().spark)
        #expect(spark.conceptA.category != spark.conceptB.category)
        #expect(spark.title.contains(" × "))
    }

    @Test func revealingTheDailySparkUsesItInTheCounter() async throws {
        let before = try await api.today()
        let spark = try #require(before.spark)
        #expect(spark.isPending)
        #expect(before.sparksToIgnite == 1 + before.quota.extraRemaining)
        try await api.revealSpark(id: spark.id)
        let after = try await api.today()
        // El mock (como `/today`) sigue contando la revelada en `quota.available`; el contador no.
        #expect(after.quota.available == before.quota.available)
        #expect(after.sparksToIgnite == after.quota.extraRemaining)
        // Si el servidor ya la descuenta, no se resta dos veces.
        let fixed = SparkQuota(available: after.quota.extraRemaining, total: after.quota.total, refillsAt: after.quota.refillsAt,
                               conceptsUntilExtra: after.quota.conceptsUntilExtra, extraRemaining: after.quota.extraRemaining)
        #expect(TodayState(spark: after.spark, quota: fixed, runwayDays: 10, conceptCount: 8).sparksToIgnite == after.quota.extraRemaining)
    }

    @Test func everyConceptBelongsToAKnownCategory() async throws {
        let categories = Set(try await api.categories())
        #expect(try await api.concepts().allSatisfy { $0.category.map(categories.contains) ?? false })
    }

    @Test func captureReusesAnExistingCategoryIgnoringAccentsAndCase() async throws {
        #expect(try await api.capture(thesis: "Idea", category: "ECONOMIA", source: .text).categoryCreated == false)
        #expect(try await api.capture(thesis: "Idea", category: "Astronomía", source: .text).categoryCreated == true)
    }

    @Test func capturedConceptsShowUpInTheVault() async throws {
        let result = try await api.capture(thesis: "Una idea nueva", category: "Música", source: .voice)
        #expect(try await api.concepts().contains { $0.id == result.conceptID })
    }

    @Test func guestStartsEmptyAndNotOnboarded() async throws {
        let guest = MockLumbreAPI(latency: .zero, onboarded: false)
        let profile = try await guest.profile()
        #expect(profile.isGuest && !profile.isOnboarded)
        #expect(try await guest.concepts().isEmpty)
    }

    @Test func plannerRequiresPro() async throws {
        let spark = try #require(try await api.today().spark)
        await #expect(throws: LumbreAPIError.proRequired) {
            for try await _ in api.sendPlannerMessage(sparkID: spark.id, text: "Hola", mode: .quick) {}
        }
        try await api.setPlanForDevelopment(.pro)
        var reply = ""
        for try await chunk in api.sendPlannerMessage(sparkID: spark.id, text: "Hola", mode: .quick) { reply += chunk }
        #expect(!reply.isEmpty)
        #expect(try await api.plannerMessages(sparkID: spark.id).count == 2)
    }

    @Test func freeHasOneProject() async throws {
        await #expect(throws: LumbreAPIError.tooManyProjects) { _ = try await api.createProject(name: "Otro") }
    }

    @Test func serverErrorsMapToFriendlyErrors() {
        #expect(LumbreAPIError(serverMessage: "quota_exceeded") == .quotaExceeded)
        #expect(LumbreAPIError(serverMessage: "pro_required") == .proRequired)
        #expect(LumbreAPIError(serverMessage: "algo_raro") == nil)
    }

    @Test func feedbackRawValuesMatchTheSchema() {
        #expect(SparkFeedback.allCases.map(\.rawValue) == ["obvious", "irrelevant", "already_had"])
    }

    @Test func sparkTimeRoundTripsPostgres() {
        #expect(SparkTime(postgres: "09:30:00") == SparkTime(hour: 9, minute: 30))
        #expect(SparkTime(hour: 7, minute: 5).postgres == "07:05:00")
    }

    @Test func eventsNeverCarryFreeText() {
        let event = AnalyticsEvent.captureSubmitted(entry: "fab", sourceType: .link, distillRequested: true, offline: false, words: 45)
        #expect(event.name == "capture_submitted")
        #expect(event.properties["length_bucket"] == .string("30-199"))
    }
}
