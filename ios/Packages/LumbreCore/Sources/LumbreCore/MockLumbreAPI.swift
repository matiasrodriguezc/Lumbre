import Foundation

/// Backend de prueba con datos fijos, para ver la interfaz sin servidor.
/// Simula la latencia de la red para que se vean los estados de carga.
public struct MockLumbreAPI: LumbreAPI {
    private let latency: Duration

    public init(latency: Duration = .milliseconds(350)) {
        self.latency = latency
    }

    public func todaySpark() async throws -> Spark? {
        try await wait()
        return MockData.todaySpark
    }

    public func sparkQuota() async throws -> SparkQuota {
        try await wait()
        return MockData.quota
    }

    public func recentSparks() async throws -> [Spark] {
        try await wait()
        return MockData.recentSparks
    }

    public func concepts() async throws -> [Concept] {
        try await wait()
        return MockData.concepts
    }

    public func domains() async throws -> [Domain] {
        try await wait()
        let used = Set(MockData.concepts.map(\.domain))
        return MockData.domains.filter(used.contains)
    }

    public func saveSpark(id: Spark.ID) async throws {
        try await wait()
    }

    public func sendFeedback(sparkID: Spark.ID, feedback: SparkFeedback) async throws {
        try await wait()
    }

    public func capture(text: String, distill: Bool) async throws -> Concept {
        try await wait()
        return Concept(
            domain: MockData.domains[0],
            title: String(text.prefix(40)),
            thesis: text,
            sourceType: .text,
            createdAt: .now
        )
    }

    private func wait() async throws {
        try await Task.sleep(for: latency)
    }
}

public enum MockData {
    public static let domains: [Domain] = [
        Domain(slug: "urbanismo", name: "Urbanismo", symbol: "building.2"),
        Domain(slug: "tecnologia", name: "Software", symbol: "chevron.left.forwardslash.chevron.right"),
        Domain(slug: "ingenieria", name: "Ingeniería", symbol: "gearshape.2"),
        Domain(slug: "marketing", name: "Marketing", symbol: "megaphone"),
        Domain(slug: "historia", name: "Historia", symbol: "building.columns"),
        Domain(slug: "cocina", name: "Cocina", symbol: "fork.knife"),
        Domain(slug: "economia", name: "Economía", symbol: "chart.line.uptrend.xyaxis"),
        Domain(slug: "biologia", name: "Biología", symbol: "leaf"),
    ]

    private static func domain(_ slug: String) -> Domain {
        domains.first { $0.slug == slug }!
    }

    private static func daysAgo(_ days: Double) -> Date {
        Date.now.addingTimeInterval(-days * 86_400)
    }

    public static let concepts: [Concept] = [
        Concept(domain: domain("marketing"), title: "Escasez intencional",
                thesis: "Limitar la oferta sube el valor percibido y la atención.",
                sourceType: .voice, createdAt: daysAgo(0.1)),
        Concept(domain: domain("urbanismo"), title: "Onda verde de semáforos",
                thesis: "Sincronizar semáforos crea un flujo continuo a velocidad constante.",
                sourceType: .text, createdAt: daysAgo(1)),
        Concept(domain: domain("ingenieria"), title: "Separación ciclónica",
                thesis: "Un flujo en espiral separa partículas por fuerza centrífuga, sin filtro.",
                sourceType: .link, sourceTitle: "Cómo funcionan los ciclones industriales", createdAt: daysAgo(2)),
        Concept(domain: domain("tecnologia"), title: "Code review",
                thesis: "Revisar cambios en pares reduce errores y reparte el conocimiento del código.",
                sourceType: .selection, sourceTitle: "Engineering practices", createdAt: daysAgo(3)),
        Concept(domain: domain("cocina"), title: "Fermentación lenta",
                thesis: "El tiempo transforma ingredientes simples en sabores complejos sin agregar nada.",
                sourceType: .screenshot, createdAt: daysAgo(5)),
        Concept(domain: domain("historia"), title: "Ruinas como archivo",
                thesis: "Lo que queda de una ciudad cuenta cómo vivía la gente mejor que sus documentos.",
                sourceType: .link, sourceTitle: "Pompeya, capa por capa", createdAt: daysAgo(8)),
        Concept(domain: domain("economia"), title: "Interés compuesto",
                thesis: "Pequeñas ganancias que se reinvierten crecen de forma exponencial con el tiempo.",
                sourceType: .scan, createdAt: daysAgo(12)),
        Concept(domain: domain("biologia"), title: "Micorrizas",
                thesis: "Los hongos conectan las raíces de un bosque y reparten nutrientes entre árboles.",
                sourceType: .audio, createdAt: daysAgo(20)),
    ]

    public static let todaySpark = Spark(
        conceptA: concepts[1],
        conceptB: concepts[3],
        title: "Semáforos × code review",
        body: "Si un PR se aprueba rápido, los siguientes del mismo autor entran en una “onda verde” con revisión prioritaria. Premia los PR chicos sin reglas nuevas.",
        createdAt: .now
    )

    public static let recentSparks: [Spark] = [
        Spark(
            conceptA: Concept(domain: domain("marketing"), title: "Formato podcast",
                              thesis: "Una conversación larga genera confianza que un anuncio no logra.",
                              sourceType: .audio, createdAt: daysAgo(9)),
            conceptB: concepts[5],
            title: "Podcast × ruinas",
            body: "Un episodio por capa de excavación: cada uno cuenta una época de la misma ciudad con lo que quedó enterrado.",
            status: .saved,
            projectName: "Canal de YouTube",
            createdAt: daysAgo(1)
        ),
        Spark(
            conceptA: concepts[4],
            conceptB: concepts[6],
            title: "Fermentación × interés compuesto",
            body: "Un newsletter que no se promociona: cada edición recupera y mejora una idea vieja en vez de buscar una nueva.",
            status: .revealed,
            createdAt: daysAgo(2)
        ),
    ]

    public static let quota: SparkQuota = {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now))!
        return SparkQuota(
            available: 1,
            total: 1,
            refillsAt: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: tomorrow)!,
            conceptsUntilExtra: 3
        )
    }()
}
