import Testing
@testable import LumbreCore

/// Lentes del planificador: la marca `[[lens:…]]`, el formato de cada una y que no muevan el método de Disney.
@Suite struct PlannerLensTests {
    @Test func readsTheLensMarkerAndHidesIt() {
        let raw = "[[lens:business_model]]\n\n**Para quién**: …"
        #expect(PlannerLens.of(raw) == .businessModel)
        #expect(PlannerRoom.split(raw).room == nil)
        #expect(PlannerRoom.split(raw).text == "**Para quién**: …")
        #expect(PlannerLens.of("[[room:dreamer]]\n\nHola") == nil)
        #expect(PlannerLens.of("[[lens:poema]]\n\nHola") == nil)
        #expect(PlannerLens.of("[[lens:po") == nil)
    }

    @Test func onlyAnswersCarryALens() {
        let answer = PlannerMessage(id: 2, role: .assistant, content: "[[lens:post]]\n\n**Gancho**: …", createdAt: .now)
        let question = PlannerMessage(id: 1, role: .user, content: "[[lens:post]] hola", createdAt: .now)
        #expect(answer.lens == .post)
        #expect(answer.displayText == "**Gancho**: …")
        #expect(question.lens == nil)
    }

    @Test(arguments: [
        (PlannerLens.businessModel, ["Para quién", "El problema", "La propuesta", "Por qué estas dos neuronas", "Cómo llega", "Cómo cobra", "Qué cuesta", "El experimento"]),
        (PlannerLens.plot, ["Logline", "El mundo", "Protagonista", "El conflicto", "Tres actos", "El giro", "Primera escena"]),
        (PlannerLens.post, ["Gancho", "El post", "Cierre", "Otros dos ganchos"]),
    ])
    func mockAnswersEachLensWithItsFormat(lens: PlannerLens, sections: [String]) async throws {
        let api = MockLumbreAPI(latency: .zero, plan: .pro)
        let spark = try #require(try await api.today().spark)
        var reply = ""
        for try await chunk in api.sendPlannerMessage(sparkID: spark.id, text: "Lente", mode: .quick, method: .disney, lens: lens) {
            reply += chunk
        }
        #expect(PlannerLens.of(reply) == lens)
        var from = reply.startIndex
        for section in sections {
            let found = try #require(reply.range(of: "**\(section)**", range: from..<reply.endIndex), "\(section)")
            from = found.upperBound
        }
    }

    @Test func aLensInTheMiddleOfTheMethodKeepsTheRoom() async throws {
        let api = MockLumbreAPI(latency: .zero, plan: .pro)
        let spark = try #require(try await api.today().spark)
        func send(_ text: String, lens: PlannerLens? = nil) async throws -> String {
            var reply = ""
            for try await chunk in api.sendPlannerMessage(sparkID: spark.id, text: text, mode: .quick, method: .disney, lens: lens) {
                reply += chunk
            }
            return reply
        }
        _ = try await send("Empecemos")
        _ = try await send("Convertila en una trama", lens: .plot)
        // Primera respuesta del Soñador: empuja a pensarlo más grande, no pasa al segundo empujón.
        let next = try await send("Un país entero")
        #expect(PlannerRoom.split(next).room == .dreamer)
        #expect(next.contains("más grande"))
    }

    @Test func lensEventCarriesTheLensModeAndMethod() {
        let event = AnalyticsEvent.plannerLensUsed(lens: .businessModel, mode: .deep, method: .disney)
        #expect(event.name == "planner_lens_used")
        #expect(event.properties == ["lens": .string("business_model"), "mode": .string("deep"), "method": .string("disney")])
    }
}
