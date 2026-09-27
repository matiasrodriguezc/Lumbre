import Testing
@testable import LumbreCore

@Suite struct MockLumbreAPITests {
    let api = MockLumbreAPI(latency: .zero)

    @Test func todaySparkCombinesTwoDifferentCategories() async throws {
        let spark = try #require(try await api.todaySpark())
        #expect(spark.conceptA.category != spark.conceptB.category)
        #expect(spark.title.contains(" × "))
    }

    @Test func everyConceptBelongsToAKnownCategory() async throws {
        let categories = Set(try await api.categories())
        #expect(try await api.concepts().allSatisfy { $0.category.map(categories.contains) ?? false })
    }

    @Test func captureReusesAnExistingCategoryIgnoringAccentsAndCase() async throws {
        #expect(try await api.capture(thesis: "Idea", category: "ECONOMIA", source: .text).categoryCreated == false)
        #expect(try await api.capture(thesis: "Idea", category: "Astronomía", source: .text).categoryCreated == true)
    }

    @Test func serverErrorsMapToFriendlyErrors() {
        #expect(LumbreAPIError(serverMessage: "quota_exceeded") == .quotaExceeded)
        #expect(LumbreAPIError(serverMessage: "algo_raro") == nil)
    }

    @Test func feedbackRawValuesMatchTheSchema() {
        #expect(SparkFeedback.allCases.map(\.rawValue) == ["obvious", "irrelevant", "already_had"])
    }
}
