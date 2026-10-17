import Foundation
import Testing
@testable import LumbreCore

/// Temas puente (paso 92): la respuesta de `/bridge-topics`, la regla del mock y los eventos.
@Suite struct BridgeTopicsTests {
    let decoder = LumbreJSON.decoder(dayTimeZone: TimeZone(identifier: "America/Argentina/Buenos_Aires")!)

    @Test func decodesTheWeeklySuggestion() throws {
        let json = """
        { "bridge": {
            "id": "e0000000-0000-4000-8000-000000000001",
            "domains": [
              { "slug": "arte", "name_es": "Arte", "name_en": "Art", "symbol_ios": "paintpalette" },
              { "slug": "biologia", "name_es": "Biología y naturaleza", "name_en": "Biology and nature", "symbol_ios": "leaf" }
            ],
            "topics": [
              { "title": "Bioarte", "why": "Obras hechas con materia viva." },
              { "title": "Biomimética", "why": "Diseñar copiando soluciones de la naturaleza." }
            ],
            "created_at": "2026-10-17T12:00:00.123456+00:00"
        } }
        """
        let bridge = try #require(try decoder.decode(BridgeEnvelopeDTO.self, from: Data(json.utf8)).bridge?.model)
        #expect(bridge.domains.map(\.slug) == ["arte", "biologia"])
        #expect(bridge.topics.map(\.title) == ["Bioarte", "Biomimética"])
        #expect(bridge.topics[0].why == "Obras hechas con materia viva.")
    }

    @Test func nullBridgeAndIncompleteSuggestionsShowNothing() throws {
        #expect(try decoder.decode(BridgeEnvelopeDTO.self, from: Data(#"{ "bridge": null }"#.utf8)).bridge == nil)
        let oneTopic = """
        { "bridge": { "id": "e0000000-0000-4000-8000-000000000002",
          "domains": [ { "slug": "arte", "name_es": "Arte", "name_en": "Art" }, { "slug": "cocina", "name_es": "Cocina", "name_en": "Cooking" } ],
          "topics": [ { "title": "Gastronomía molecular", "why": "Uno solo no alcanza." } ],
          "created_at": "2026-10-17T12:00:00Z" } }
        """
        #expect(try decoder.decode(BridgeEnvelopeDTO.self, from: Data(oneTopic.utf8)).bridge?.model == nil)
    }

    @Test func mockProGetsBiologyAndTechnologyTopics() async throws {
        let api = MockLumbreAPI(latency: .zero, plan: .pro)
        let bridge = try #require(try await api.bridgeTopics())
        #expect(Set(bridge.domains.map(\.slug)) == ["biologia", "tecnologia"])
        #expect((2...3).contains(bridge.topics.count))
        #expect(bridge.topics.allSatisfy { !$0.title.contains("http") && !$0.why.contains("http") })
        // La misma sugerencia toda la semana.
        #expect(try await api.bridgeTopics()?.id == bridge.id)
    }

    @Test func mockFreeAndGuestGetNothing() async throws {
        #expect(try await MockLumbreAPI(latency: .zero).bridgeTopics() == nil)
        #expect(try await MockLumbreAPI(latency: .zero, onboarded: false).bridgeTopics() == nil)
    }

    @Test func mockWithoutAIConsentGetsNothing() async throws {
        let api = MockLumbreAPI(latency: .zero, plan: .pro)
        try await api.setAIConsent(false)
        #expect(try await api.bridgeTopics() == nil)
    }

    @Test func domainsThatAlreadyCrossedAreNotABridge() {
        let concepts = MockData.concepts
        let bio = concepts.filter { $0.category?.domain?.slug == "biologia" && $0.status == .ready }
        let tech = concepts.filter { $0.category?.domain?.slug == "tecnologia" }
        #expect(MockData.bridgeTopics(concepts: concepts, sparks: []) != nil)
        let crossed = (0..<2).map { Spark(conceptA: bio[$0], conceptB: tech[$0], title: "Cruce", body: "Cuerpo.", createdAt: .now) }
        #expect(MockData.bridgeTopics(concepts: concepts, sparks: Array(crossed.prefix(1))) != nil, "una sola chispa: casi no se cruzaron")
        #expect(MockData.bridgeTopics(concepts: concepts, sparks: crossed) == nil, "dos chispas: ya se cruzaron")
    }

    @Test func fewConceptsPerDomainIsNotABridge() {
        let few = MockData.concepts.filter { $0.category?.domain?.slug != "biologia" || $0.title == "Micorrizas" }
        #expect(MockData.bridgeTopics(concepts: few, sparks: []) == nil)
    }

    @Test func eventsCarryOnlyScreenCountsAndDomainSlugs() {
        let shown = AnalyticsEvent.bridgeTopicsShown(screen: "vault", topicsCount: 3, domainA: "biologia", domainB: "tecnologia")
        #expect(shown.name == "bridge_topics_shown")
        #expect(shown.properties == ["screen": .string("vault"), "topics_count": .int(3), "domain_a": .string("biologia"), "domain_b": .string("tecnologia")])
        let tapped = AnalyticsEvent.bridgeTopicTapped(screen: "today", index: 2, action: "search")
        #expect(tapped.name == "bridge_topic_tapped")
        #expect(tapped.properties == ["screen": .string("today"), "index": .int(2), "action": .string("search")])
    }

    @Test func runwayOverrideLetsTodayAskForMoreConcepts() async throws {
        #expect(try await MockLumbreAPI(latency: .zero, runwayDays: 3).today().needsMoreConcepts)
    }
}
