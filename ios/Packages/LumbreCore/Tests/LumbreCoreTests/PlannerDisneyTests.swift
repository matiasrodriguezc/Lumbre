import Testing
@testable import LumbreCore

/// El método de los tres cuartos: la marca del cuarto y el recorrido Soñador → Realista → Crítico → síntesis.
@Suite struct PlannerDisneyTests {
    @Test func splitsTheRoomMarkerFromTheText() {
        let (room, text) = PlannerRoom.split("[[room:critic]]\n\nSegunda: ¿qué puede salir mal?")
        #expect(room == .critic)
        #expect(text == "Segunda: ¿qué puede salir mal?")
    }

    @Test func hidesAHalfArrivedMarkerWhileStreaming() {
        #expect(PlannerRoom.split("[[room:dre").text.isEmpty)
        #expect(PlannerRoom.split("[[room:dre").room == nil)
    }

    @Test func leavesTextWithoutMarkerAlone() {
        let (room, text) = PlannerRoom.split("Backlog para arrancar")
        #expect(room == nil)
        #expect(text == "Backlog para arrancar")
    }

    @Test func userMessagesShowAsTyped() {
        let message = PlannerMessage(id: 1, role: .user, content: "[[room:plan]] hola", createdAt: .now)
        #expect(message.displayText == "[[room:plan]] hola")
    }

    @Test func mockWalksTheThreeRoomsAndEndsWithTheSynthesis() async throws {
        let api = MockLumbreAPI(latency: .zero, plan: .pro)
        let spark = try #require(try await api.today().spark)
        let answers = ["Empecemos", "Un país entero", "Diez años", "Lo usan todos",
                       "Pasos y plata", "Esta semana pruebo", "Falta demanda", "Que sea caro", "Los que viven del sistema"]
        var rooms: [PlannerRoom?] = []
        for answer in answers {
            var reply = ""
            for try await chunk in api.sendPlannerMessage(sparkID: spark.id, text: answer, mode: .quick, method: .disney) {
                reply += chunk
            }
            rooms.append(PlannerRoom.split(reply).room)
        }
        #expect(rooms == [.dreamer, .dreamer, .dreamer, .realist, .realist, .critic, .critic, .critic, .plan])
        let synthesis = try await api.plannerMessages(sparkID: spark.id).last?.displayText ?? ""
        #expect(synthesis.contains("**El sueño**"))
        #expect(synthesis.contains("**El cuarto que salteás**"))
    }

    @Test func askingForTheNextRoomSkipsAhead() async throws {
        let api = MockLumbreAPI(latency: .zero, plan: .pro)
        let spark = try #require(try await api.today().spark)
        for try await _ in api.sendPlannerMessage(sparkID: spark.id, text: "Empecemos", mode: .quick, method: .disney) {}
        var reply = ""
        for try await chunk in api.sendPlannerMessage(sparkID: spark.id, text: "Pasemos al siguiente cuarto", mode: .quick, method: .disney) {
            reply += chunk
        }
        #expect(PlannerRoom.split(reply).room == .realist)
    }
}
