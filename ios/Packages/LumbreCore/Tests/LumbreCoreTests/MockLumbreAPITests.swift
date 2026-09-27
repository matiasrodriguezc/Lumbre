import Testing
@testable import LumbreCore

@Suite struct MockLumbreAPITests {
    let api = MockLumbreAPI(latency: .zero)

    @Test func todaySparkCombinesTwoDifferentDomains() async throws {
        let spark = try #require(try await api.todaySpark())
        #expect(spark.conceptA.domain != spark.conceptB.domain)
        #expect(spark.title.contains(" × "))
    }

    @Test func domainsOnlyIncludeTheOnesInUse() async throws {
        let used = Set(try await api.concepts().map(\.domain))
        #expect(Set(try await api.domains()) == used)
    }

    @Test func feedbackRawValuesMatchTheSchema() {
        #expect(SparkFeedback.allCases.map(\.rawValue) == ["obvious", "irrelevant", "already_had"])
    }
}
